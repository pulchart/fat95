"""Media removal and replacement under a running handler: the handler process is kept alive while the card is pulled, swapped or made to fail.

Status: handler-in-the-loop tier, run by make test-amifuse. Each case has a 60-second timeout.
Run: python3 tests/amifuse_media.py --suite"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import traceback
import time
from amifuse_bridge import RawFatBridge
from amifuse_images import create_image, inspect_image, file_sha256, verify_image
from toolchain import ROOT, RUNS
from amifuse.scsi_device import ScsiDevice, IORequestStruct
from amifuse.startup_runner import _snapshot_block_state, _restore_block_state

_active = None
_previous = ScsiDevice.BeginIO

def media_io(self, ctx, address):
    device = self
    control = getattr(device.backend, '_media_control', None) or _active
    if control is None:
        return _previous(device,ctx,address)
    device.backend._media_control = control
    control.backend = device.backend
    request = IORequestStruct(ctx.mem,address)
    command = request.command.val
    if command == 20:
        control.interrupt = request.data.val
    if command == 21:
        control.interrupt = 0
    if command in (2,3,4):
        control.events.append(dict(command=command,image=str(device.backend.image),
                                   offset=request.offset.val,length=request.length.val,
                                   present=control.present))
        if (command == control.fail_command and control.remaining is not None
                and (not control.payload_only or request.length.val >= 4096)
                and (command != 4 or control.seen_payload)):
            if control.remaining == 0:
                control.remaining = None
                control.injected += 1
                if control.remove_on_failure:
                    control.present = False
                    control.generation += 1
                    control.pending = True
                request.flags.val |= 1
                request.error.val = 29 if control.remove_on_failure else 20
                actual = 0
                if command == 3 and control.partial and request.length.val >= 1024:
                    actual = (request.length.val // 1024) * 512
                    device.backend.write_blocks(request.offset.val // 512,
                        bytes(ctx.mem.r_block(request.data.val,actual)),actual // 512)
                    device.backend.sync()
                request.actual.val = actual
                control.events[-1]['actual'] = actual
                control.events[-1]['failed'] = True
                return 0
            control.remaining -= 1
        if not control.present:
            request.flags.val |= 1
            request.error.val = 29
            request.actual.val = 0
            control.events[-1]['failed'] = True
            return 0
    if command in (13,14):
        request.flags.val |= 1
        request.error.val = 0
        request.actual.val = control.generation if command == 13 else int(not control.present)
        return 0
    result = _previous(device,ctx,address)
    if command == 3 and request.length.val >= 4096 and not request.error.val:
        control.seen_payload = True
    return result

ScsiDevice.BeginIO = media_io

class MediaBridge(RawFatBridge):
    def _run_until_replies(self, *args, **kwargs):
        if self.state.pc <= 0x1000:
            raise AssertionError(f'Unexpected handler exit; disallow upstream restart: {self.snapshot()}')
        return super()._run_until_replies(*args, **kwargs)

    def finish_background(self):
        deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            info=self.get_disk_info()
            if info and info['num_blocks_used'] < info['num_blocks']:
                return info
            for _ in range(20):
                rs=self.launcher.run_burst(self.state,max_cycles=200000)
                assert not self.state.crashed and not (getattr(rs,'done',False) and not rs.error), self.snapshot()
            time.sleep(.01)
        raise AssertionError(f'Background scan did not finish: {self.snapshot()}')

class MediaControl:
    def __init__(self):
        self.present=True
        self.generation=0
        self.interrupt=0
        self.pending=False
        self.events=[]
        self.injected=0
        self.remaining=None
        self.fail_command=3
        self.remove_on_failure=True
        self.payload_only=False
        self.partial=True
        self.seen_payload=False

    def arm(self, after=0, command=3, remove=True, payload_only=True):
        self.remaining=after
        self.fail_command=command
        self.remove_on_failure=remove
        self.payload_only=payload_only
        self.seen_payload=False

    def deliver_interrupt(self, bridge):
        """Execute the registered m68k interrupt while the CPU is between bursts.

        No direct writes to handler globals. I/O failure is returned first;
        notification is deliberately delayed until the packet returns.
        """
        assert self.interrupt, 'Handler did not register TD_ADDCHANGEINT'
        mem=bridge.mem
        code=mem.r32(self.interrupt+18)
        data=mem.r32(self.interrupt+14)
        cpu=bridge.vh.machine.cpu
        saved=[cpu.r_reg(i) for i in range(16)]
        pc,sr=cpu.r_pc(),cpu.r_sr()
        block=_snapshot_block_state()
        stack=bridge.vh.alloc.alloc_memory(4096,label='media-interrupt-stack')
        try:
            result=bridge.vh.machine.run(code,sp=stack.addr+4092,set_regs={9:data},
                                        max_cycles=10000,name='media-change-interrupt')
            assert result.done and not result.error, result
        finally:
            for i,value in enumerate(saved):cpu.w_reg(i,value)
            cpu.w_pc(pc);cpu.w_sr(sr)
            _restore_block_state(block)
            bridge.vh.alloc.free_memory(stack)
        self.pending=False

    def insert(self, bridge, image):
        assert not self.present
        volume=inspect_image(image)
        backend=bridge.backend
        backend.close()
        backend.image=Path(image)
        backend.adf_info=type(backend.adf_info)(0x46415400,False,volume.total_sectors,1,1,512,volume.total_sectors)
        backend.open()
        bridge._volume=volume  # observer geometry only, never handler globals
        self.present=True
        self.generation+=1
        self.deliver_interrupt(bridge)


def run(directory, old_profile="fat32_128m", same=False, scenario="remove-write"):
    global _active
    directory.mkdir(parents=True,exist_ok=True)
    old,new=directory/'old.img',directory/'new.img'
    create_image(old,old_profile)
    create_image(new,'fat16_32m' if old_profile!='fat16_32m' else 'fat32_128m')
    before_new=file_sha256(new)
    control=MediaControl();_active=control
    bridge=None
    try:
        bridge=MediaBridge(old,ROOT/'dist/l/68020/fat95')
        identity=(id(bridge),bridge.state.process_addr)
        bridge.put('/SAFE.TXT',b'keep old data')
        bridge.flush_volume()
        handle,lock=bridge.open_file('/BROKEN.BIN',os.O_WRONLY|os.O_CREAT|os.O_TRUNC)
        if scenario == 'flush-error':
            control.arm(command=4,remove=False,payload_only=False)
            written=bridge.write_handle(handle,bytes(range(256))*256)
            assert written == 65536, written
            bridge.launcher.send_flush(bridge.state)
            reply=bridge._run_until_replies()[-1]
            result=reply[2]
        else:
            control.arm(remove=scenario=='remove-write')
            result=bridge.write_handle(handle,bytes(range(256))*256)
        print('INJECTED',scenario,result,bridge.last_reply,control.injected,flush=True)
        assert control.injected==1 and result == 0 and bridge.last_reply[3]==225
        if control.present:
            # A plain error leaves the medium present and writes latched off.
            bridge.launcher.send_flush(bridge.state)
            assert bridge._run_until_replies()[-1][2] == 0
            control.present=False;control.generation+=1;control.pending=True
        if control.pending:control.deliver_interrupt(bridge)
        # Release old references before mounting replacement; failure to close is recorded.
        bridge.launcher.send_end_handle(bridge.state,handle)
        close_reply=bridge._run_until_replies()[-1]
        bridge._free_fh(handle)
        if lock:bridge.free_lock(lock)
        print('ABSENT_CLOSE',close_reply,flush=True)
        assert file_sha256(new)==before_new
        # Publish Python's backing-file buffers for consistent host-side snapshots.
        # This is not a successful emulated CMD_UPDATE or a durability assertion.
        bridge.backend.sync()
        old_after_failure=file_sha256(old)
        target=old if same else new
        previous=inspect_image(old)
        assert previous.clean_bits == (() if previous.fat_bits==12 else (False,False)), previous
        control.insert(bridge,target)
        info=bridge.finish_background()
        print('NEW_INFO',info,flush=True)
        assert identity==(id(bridge),bridge.state.process_addr)
        assert file_sha256(new)==before_new, 'Old buffered writes touched replacement'
        if same:
            assert bridge.read_file('/SAFE.TXT',14,0)==b'keep old data'
        else:
            assert bridge.locate(0,'SAFE.TXT')==(0,205)
            assert file_sha256(old)==old_after_failure, 'Detached old image changed'
        bridge.put('/NEW.TXT',b'only new data')
        assert bridge.read_file('/NEW.TXT',14,0)==b'only new data'
        bridge.shutdown_handler()
        bridge.close();bridge=None
        if not same:
            assert file_sha256(old)==old_after_failure, 'Late write changed detached old image'
        report=verify_image(target,{'NEW.TXT':b'only new data'},check_fsck=not same)
        if not same:
            assert previous.cluster_size != report['volume'].cluster_size
        assert report['volume'].clean_bits == (() if report['volume'].fat_bits==12 else
                                              (not same,not same)), report['volume']
        old_report=verify_image(old,{'SAFE.TXT':b'keep old data'},check_fsck=False)
        (directory/'result.json').write_text(json.dumps(dict(status='passed',scenario=scenario,same_media=same,old_clean=previous.clean_bits,
            old_cluster_size=previous.cluster_size,new_cluster_size=report['volume'].cluster_size,
            process_addr=identity[1],old_fsck={k:old_report[k] for k in ('fsck_returncode','fsck_output')},
            target_fsck={k:report[k] for k in ('fsck_returncode','fsck_output')},events=control.events),indent=2)+'\n')
        print('PASS',directory)
    except BaseException:
        (directory/'failure.json').write_text(json.dumps(dict(error=traceback.format_exc(),
            machine=bridge.snapshot() if bridge else None,events=control.events),indent=2)+'\n')
        raise
    finally:
        _active=None
        if bridge:bridge.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--suite',action='store_true')
    parser.add_argument('--old-profile',default='fat32_128m',choices=['fat12_720','fat16_32m','fat32_128m'])
    parser.add_argument('--same',action='store_true')
    parser.add_argument('--scenario',default='remove-write',choices=['remove-write','write-error','flush-error'])
    args=parser.parse_args()
    root=RUNS;root.mkdir(parents=True,exist_ok=True)
    if args.suite:
        directory=args.output or Path(tempfile.mkdtemp(prefix='media-matrix-',dir=root))
        directory=directory.resolve();directory.mkdir(parents=True,exist_ok=True)
        results=[]
        for profile in ['fat12_720','fat16_32m','fat32_128m']:
            for scenario in ['remove-write','write-error','flush-error']:
                for same in [False,True]:
                    name=f'{profile}-{scenario}-'+('same' if same else 'different')
                    folder=directory/name;folder.mkdir()
                    command=[sys.executable,'-u',__file__,'--output',str(folder),
                             '--old-profile',profile,'--scenario',scenario]
                    if same:command.append('--same')
                    with (folder/'run.log').open('w') as log:
                        try:
                            child=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=60)
                            status='passed' if child.returncode==0 else 'failed'
                        except subprocess.TimeoutExpired:status='timeout'
                    results.append(dict(case=name,status=status))
                    print(name,status,flush=True)
        (directory/'summary.json').write_text(json.dumps(results,indent=2)+'\n')
        print(directory)
        if any(item['status']!='passed' for item in results):raise SystemExit(1)
    else:
        run(args.output or Path(tempfile.mkdtemp(prefix='media-',dir=root)),args.old_profile,args.same,args.scenario)
