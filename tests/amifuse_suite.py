#!/usr/bin/env python3
"""Packet-level matrix: the built 68020 handler is driven with real DOS packets against real FAT12, FAT16 and FAT32 images, and every result is read back in Python. Each case runs in a timed child process.

Status: handler-in-the-loop tier, run by make test-amifuse. Needs amifuse, dosfstools, mtools and a prior make fat95-020.
Run: python3 tests/amifuse_suite.py --cycles 1
Set FAT95_BASELINE_DRIVER to a second handler binary for an A/B run."""
import argparse
from dataclasses import asdict
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import time
import traceback
from amifuse_images import PROFILES, create_image, inspect_image, verify_image, file_sha256

from toolchain import ROOT, RUNS

# The A/B baseline is a second handler binary to compare against, named by
# FAT95_BASELINE_DRIVER. Without it the matrix runs the current driver alone.
DEFAULT_DRIVERS = {'current': ROOT/'dist/l/68020/fat95'}
_baseline = os.environ.get('FAT95_BASELINE_DRIVER')
if _baseline and Path(_baseline).exists():
    DEFAULT_DRIVERS = {'baseline': Path(_baseline), **DEFAULT_DRIVERS}

def payload(size, seed=95):
    return random.Random(seed).randbytes(size)

def okay(result):
    assert result[0] != 0, result
    return result[0]

def packet_lifecycle(b, cluster_size, expected):
    """Seek modes, resize boundaries and live references preserve file contents."""
    name = 'RESIZE.BIN'
    data = payload(cluster_size * 3 + 17)
    b.put('/'+name, data)
    handles = []
    def opened(path, flags):
        item = b.open_file(path, flags)
        assert item, (path, b.last_reply)
        handles.append(item)
        return item[0]
    def seek(handle, offset, mode, previous):
        b.seek_handle(handle, offset, mode)
        assert b.last_reply[2:] == (previous, 0), b.last_reply
    try:
        h = opened('/'+name, os.O_RDWR)
        other = opened('/'+name, os.O_RDONLY)
        seek(h, cluster_size - 1, -1, 0)
        assert b.read_handle(h, 3) == data[cluster_size-1:cluster_size+2]
        seek(h, -2, 0, cluster_size + 2)
        assert b.read_handle(h, 2) == data[cluster_size:cluster_size+2]
        seek(h, -1, 1, cluster_size + 2)
        assert b.read_handle(h, 2) == data[-1:]
        assert b.read_handle(h, 1) == b'' and b.last_reply[2:] == (0, 0)
        b.seek_handle(h, 1, 1)
        assert b.last_reply[2:] == (-1, 219), b.last_reply
        seek(h, 0, 0, len(data))  # failed seek preserves the position

        # Neither deletion nor shutdown may invalidate a live file handle.
        assert b.delete_object(0, name) == (0, 202)
        b.launcher.send_packet(b.state, 5, [])
        assert b._run_until_replies()[-1][2:] == (0, 202)
        assert b.read_handle(other, 7) == data[:7]
        seek(other, 0, 1, 7)
        assert b.set_handle_size(h, 0) == len(data), b.last_reply
        seek(other, cluster_size + 1, -1, len(data))
        assert b.set_handle_size(h, 0) == cluster_size + 1, b.last_reply
        b.close_file(other)
        _, lock = handles.pop()
        if lock:b.free_lock(lock)
        for size in (cluster_size, cluster_size - 1, 0):
            assert b.set_handle_size(h, size) == size, b.last_reply
        grown = cluster_size * 2 + 1
        assert b.set_handle_size(h, grown) == grown, b.last_reply
        seek(h, 0, -1, 0)
        # Newly allocated bytes need not be initialized; write them before checking.
        replacement = payload(grown, 96)
        assert b.write_handle(h, replacement) == grown
        expected[name] = replacement
    finally:
        for handle, lock in reversed(handles):
            try:b.close_file(handle)
            finally:
                if lock:b.free_lock(lock)

def nested_and_names(b, expected):
    """Nested mkdir/rename and VFAT entry boundaries survive remount and fsck."""
    parent = okay(b.create_dir(0, 'Parent'))
    try:
        child = okay(b.create_dir(parent, 'Child'))
        b.free_lock(child)
    finally:b.free_lock(parent)
    b.put('/Parent/Child/KEEP.TXT', b'nested content')
    okay(b.rename_object(0, 'Parent/Child', 0, 'Moved'))
    okay(b.delete_object(0, 'Parent'))
    expected['Moved/KEEP.TXT'] = b'nested content'
    # 13 UTF-16 characters fit each VFAT LFN entry; fat95 supports 104.
    for length in (12, 13, 14, 26, 27, 103, 104):
        name = 'N' * (length - 4) + '.txt'
        content = bytes([length])
        b.put('/'+name, content)
        assert b.read_file('/'+name, 2, 0) == content
        expected[name] = content

def offline(image, expected, initial, dirty):
    report = verify_image(image, expected, check_fsck=False)
    v = report['volume']
    assert v.fat_copies_equal, 'FAT copies disagree'
    assert v.clean_bits == ((not dirty,) * v.fat_count if v.fat_bits != 12 else ()), v
    output = report['fsck_output']
    # Dirty warning is expected; never blanket-accept all fsck exit-1 results.
    if dirty:
        allowed = ('fsck.fat ', 'Dirty bit is set.', 'Fs was not properly unmounted',
                   ' Automatically removing dirty bit.', 'Leaving filesystem unchanged.',
                   str(image))
        for line in output.splitlines():
            if line.strip() and not any(line.startswith(s) for s in allowed):
                raise AssertionError(f'Unexpected fsck diagnostic: {line}')
        assert report['fsck_returncode'] in (0, 1), output
    else:
        assert report['fsck_returncode'] == 0, output
    if v.fat_bits == 32:
        primary = v.fsinfo[0]
        assert primary[1] and primary[2] == v.free_clusters, v
        # fat95 only publishes primary FSInfo; backup is intentionally untouched.
        assert v.fsinfo[1:] == initial.fsinfo[1:], (v.fsinfo, initial.fsinfo)
    report['volume'] = asdict(v)
    return report

def case(args):
    from amifuse_bridge import RawFatBridge
    image = args.out/'disk.img'
    initial = create_image(image, args.profile, dirty=args.dirty, fsinfo=args.fsinfo)
    expected = {}
    b = None
    try:
        if args.scenario == 'full':
            filler = args.out/'filler.bin'
            with filler.open('wb') as f:
                f.truncate((initial.free_clusters - 16) * initial.cluster_size)
            subprocess.run(['mcopy','-i',str(image),str(filler),'::/FILLER.BIN'],check=True,
                           capture_output=True,timeout=60)
            initial = inspect_image(image)  # mtools updates its own FSInfo backup.
        b = RawFatBridge(image, args.driver, expect_managed=args.managed)
        stack = b.initial_stack_size
        io_counts = dict(read=0,write=0,update=0)
        payload_checks = 0
        def collect(bridge):
            nonlocal payload_checks
            for key,value in bridge.io_counts.items():io_counts[key]+=value
            payload_checks += bridge.payload_checks
        if args.scenario == 'full':
            h, lock = b.open_file('/FULL.BIN', os.O_WRONLY|os.O_CREAT|os.O_TRUNC)
            written = 0
            block = payload(initial.cluster_size)
            try:
                for _ in range(32):
                    n = b.write_handle(h, block)
                    if n != len(block):
                        assert n in (-1, 0) and b.last_reply[3] == 221, b.last_reply
                        break
                    written += n
                else:
                    raise AssertionError('Expected disk full')
            finally:
                try:
                    b.close_file(h)
                finally:
                    if lock:b.free_lock(lock)
            assert written == initial.free_clusters * initial.cluster_size, (written, initial)
            okay(b.delete_object(0,'FULL.BIN'))
            b.put('/REUSED.BIN', block)
            expected['REUSED.BIN'] = block
        else:
            nested_and_names(b, expected)
            packet_lifecycle(b, initial.cluster_size, expected)
            lock = okay(b.create_dir(0,'Long directory name'))
            b.free_lock(lock)
            sizes = sorted({0,1,511,512,513,initial.cluster_size-1,initial.cluster_size,
                            initial.cluster_size+1,65537})
            for i, size in enumerate(sizes):
                name = f'Long directory name/Boundary file {i}.bin'
                data = payload(size, i)
                b.put('/'+name,data)
                assert b.read_file('/'+name,size+1,0)==data, name
                expected[name] = data
            b.put('/RENAME.TXT',payload(513))
            okay(b.rename_object(0,'RENAME.TXT',0,'RENAMED.TXT'))
            assert b.read_file('/RENAMED.TXT',514,0) == payload(513)
            assert b.locate(0,'RENAME.TXT') == (0,205)
            b.put('/RENAMED.TXT',b'overwritten')
            assert b.read_file('/RENAMED.TXT',12,0)==b'overwritten'
            okay(b.delete_object(0,'RENAMED.TXT'))
            assert b.locate(0,'RENAMED.TXT') == (0,205)
        b.flush_volume()
        b.shutdown_handler(); collect(b); b.close(); b=None
        report = offline(image, expected, initial, args.dirty)
        for cycle in range(args.cycles if args.scenario == 'matrix' else 1):
            b = RawFatBridge(image,args.driver,expect_managed=args.managed)
            assert b.locate(0,'CYCLE.BIN') == (0,205)
            assert b.locate(0,'RENAMED.TXT') == (0,205)
            for name,data in expected.items():
                assert b.read_file('/'+name,len(data)+1,0)==data, (cycle,name)
            data = payload(4097, cycle)
            b.put('/CYCLE.BIN', data)
            assert b.read_file('/CYCLE.BIN',4098,0)==data
            okay(b.delete_object(0,'CYCLE.BIN'))
            b.flush_volume()
            b.shutdown_handler();collect(b);b.close();b=None
        report = offline(image, expected, initial, args.dirty)
        for deleted in ('CYCLE.BIN', 'RENAMED.TXT', 'RENAME.TXT', 'FULL.BIN'):
            listing = subprocess.run(['mdir','-i',str(image),'::/'+deleted],
                                     capture_output=True,text=True,timeout=30,
                                     env={**os.environ,'MTOOLS_SKIP_CHECK':'1'})
            assert listing.returncode == 1 and 'File "::/' + deleted + '" not found' in listing.stderr, listing
        if args.scenario == 'full':
            extracted = args.out/'filler-readback.bin'
            subprocess.run(['mcopy','-i',str(image),'::/FILLER.BIN',str(extracted)],
                           check=True,capture_output=True,timeout=60)
            assert file_sha256(extracted) == file_sha256(filler), 'Filler content changed'
        if args.managed and initial.fat_bits != 12:
            assert payload_checks > 0, 'Dirty-before-payload observer was not exercised'
        report.update(io_counts=io_counts,payload_checks=payload_checks,status='passed',cycles=args.cycles if args.scenario=='matrix' else 1,
                      stack_bytes=stack, driver_sha256=file_sha256(args.driver),seed=95)
        (args.out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
    except BaseException:
        failure = dict(status='failed',error=traceback.format_exc(),seed=95)
        if b:
            failure['machine']=b.snapshot()
        (args.out/'result.json').write_text(json.dumps(failure,indent=2)+'\n')
        raise
    finally:
        if b:b.close()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--worker',action='store_true')
    p.add_argument('--out',type=Path)
    p.add_argument('--driver',type=Path)
    p.add_argument('--profile',choices=PROFILES)
    p.add_argument('--cycles',type=int,default=100)
    p.add_argument('--timeout',type=int,default=300)
    p.add_argument('--dirty',action='store_true')
    p.add_argument('--managed',action='store_true',help='Require dirty markers before payload writes for custom driver')
    p.add_argument('--fsinfo',choices=['valid','unknown'],default='valid')
    p.add_argument('--scenario',choices=['matrix','full'],default='matrix')
    args=p.parse_args()
    if args.worker:
        case(args);return
    from amifuse import __version__
    out=args.out or RUNS/time.strftime('%Y%m%d-%H%M%S')
    out.mkdir(parents=True,exist_ok=False)
    results=[]
    drivers={'custom':args.driver} if args.driver else DEFAULT_DRIVERS
    for name,driver in drivers.items():
        for profile in ([args.profile] if args.profile else PROFILES):
            variants=[('matrix',False,'valid'),('full',False,'valid')]
            if profile.startswith(('fat16','fat32')):variants.append(('matrix',True,'valid'))
            if profile.startswith('fat32'):variants.extend([('matrix',False,'unknown'),('matrix',True,'unknown')])
            for scenario,dirty,fsinfo in variants:
                label=f'{name}-{profile}-{scenario}-{"dirty" if dirty else "clean"}-{fsinfo}'
                folder=out/label;folder.mkdir()
                command=[sys.executable,__file__,'--worker','--out',str(folder),
                         '--driver',str(driver.resolve()),'--profile',profile,'--scenario',scenario,
                         '--fsinfo',fsinfo,'--cycles',str(args.cycles if not dirty and fsinfo=='valid' else 1)]
                if dirty:command.append('--dirty')
                if name=='current' or args.managed:command.append('--managed')
                start=time.monotonic()
                with (folder/'run.log').open('w') as log:
                    try:
                        proc=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=args.timeout)
                        status='passed' if proc.returncode==0 else 'failed'
                    except subprocess.TimeoutExpired:status='timeout'
                results.append(dict(case=label,status=status,seconds=round(time.monotonic()-start,2)))
                print(label,status,flush=True)
    (out/'summary.json').write_text(json.dumps(dict(amifuse=__version__,results=results),indent=2)+'\n')
    print(out)
    if any(r['status']!='passed' for r in results):raise SystemExit(1)

if __name__=='__main__':main()
