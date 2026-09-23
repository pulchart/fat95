"""Real FUSE mount, write, unmount and remount of the built handler, one run per image profile.

Status: handler-in-the-loop tier. Needs /dev/fuse, mount permission and fusermount3. Images and logs stay in tests/.amifuse-runs.
Run: python3 tests/amifuse_fuse.py --suite --driver dist/l/68020/fat95"""
import argparse
from contextlib import contextmanager
from dataclasses import asdict
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import traceback

from amifuse_images import PROFILES, create_image, file_sha256, verify_image
from toolchain import RUNS


def make_filesystem(bridge, mountpoint=None):
    from amifuse.fuse_fs import AmigaFuseFS, _parse_fib
    from amitools.vamos.libstructs.dos import FileHandleStruct, FileInfoBlockStruct

    class FatFuse(AmigaFuseFS):
        def __init__(self, bridge):
            super().__init__(bridge, mountpoint=mountpoint)
            self.destroyed = False
            self.shutdown_errors = []

        def fsync(self, path, fdatasync, fh):
            self.bridge.flush_volume()
            return 0

        def getattr(self, path, fh=None):
            """Use actual open-file metadata, never upstream's size-zero fallback.

            AmiFUSE returns synthetic st_size=0 for every active file handle
            on writable mounts, even existing nonempty files. Linux then
            reports EOF without calling read. ACTION_EXAMINE_FH obtains the
            handler's metadata without acquiring a conflicting pathname lock.
            """
            self._check_handler_alive()
            with self._fh_lock:
                entry = self._fh_cache.get(fh)
                if entry is None and path not in self._pending_deletes:
                    entry = next((item for item in self._fh_cache.values()
                                  if item.get('path') == path and not item.get('closed')
                                  and 'fh_addr' in item), None)
            if entry is None or 'fh_addr' not in entry:
                return super().getattr(path, fh)
            with entry['lock'], self.bridge._lock:
                if entry.get('closed'):
                    raise RuntimeError('getattr on closed file handle')
                fib = self.bridge.vh.alloc.alloc_memory(FileInfoBlockStruct.get_size(),
                                                        label='FAT95-FUSE-ExamineFH')
                try:
                    self.bridge.mem.w_block(fib.addr, bytes(FileInfoBlockStruct.get_size()))
                    handle = FileHandleStruct(self.bridge.mem, entry['fh_addr'])
                    self.bridge.packet(1034, handle.args.val, fib.addr >> 2)
                    info = _parse_fib(self.bridge.mem, fib.addr)
                    return self._stat_from_fib(info, path, int(time.time()))
                finally:
                    self.bridge.vh.alloc.free_memory(fib)

        def destroy(self, path):
            if self.destroyed:
                return
            self.destroyed = True
            for operation in (self.bridge.shutdown_handler, self.bridge.close):
                try:
                    operation()
                except Exception:
                    error = traceback.format_exc()
                    self.shutdown_errors.append(error)
                    print(error, file=sys.stderr, flush=True)

    return FatFuse(bridge)


def mount_image(image, driver, mountpoint):
    from amifuse.fuse_fs import FUSE
    from amifuse_bridge import RawFatBridge
    if FUSE is None:
        raise RuntimeError('AmiFUSE cannot import FUSE')
    fs = make_filesystem(RawFatBridge(image, driver), mountpoint)
    try:
        FUSE(fs, str(mountpoint), foreground=True, nothreads=True,
             attr_timeout=0, entry_timeout=0, negative_timeout=0)
    finally:
        fs.destroy(str(mountpoint))
    if fs.shutdown_errors:
        raise RuntimeError('Handler shutdown failed; see log')


def unmount(mountpoint):
    if os.path.ismount(mountpoint):
        subprocess.run(['fusermount3', '-u', str(mountpoint)], check=True,
                       capture_output=True, timeout=15)


@contextmanager
def mounted(image, driver, mountpoint, logfile):
    with logfile.open('w') as log:
        process = subprocess.Popen([sys.executable, '-u', __file__, '--mount',
                                    '--image', str(image), '--driver', str(driver),
                                    '--mountpoint', str(mountpoint)], stdout=log,
                                   stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 30
            while not os.path.ismount(mountpoint):
                if process.poll() is not None:
                    raise RuntimeError(f'Mount exited {process.returncode}: {logfile}')
                if time.monotonic() > deadline:
                    raise TimeoutError(f'Mount timeout: {logfile}')
                time.sleep(0.05)
            yield mountpoint
        finally:
            try:
                unmount(mountpoint)
            finally:
                try:
                    status = process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                    raise TimeoutError(f'Handler shutdown timeout: {logfile}')
            if status:
                raise RuntimeError(f'Mount exited {status}: {logfile}')


def payload(size, seed=95):
    return bytes((index * 37 + seed) & 255 for index in range(size))


def write_synced(path, data):
    with path.open('wb') as file:
        assert file.write(data) == len(data)
        file.flush()
        os.fsync(file.fileno())


def exercise(profile, driver, directory):
    image, mountpoint = directory / 'disk.img', directory / 'mount'
    mountpoint.mkdir()
    volume = create_image(image, profile)
    sizes = sorted({0, 1, 511, 512, 513, volume.cluster_size - 1,
                    volume.cluster_size, volume.cluster_size + 1,
                    volume.cluster_size * 3 + 17})
    expected = {f'Files/Boundary {size}.bin': payload(size) for size in sizes}
    deleted = 'Files/delete me.bin'
    with mounted(image, driver, mountpoint, directory / 'write.log'):
        (mountpoint / 'Files').mkdir()
        (mountpoint / 'Empty directory').mkdir()
        for name, data in expected.items():
            write_synced(mountpoint / name, data)
            assert (mountpoint / name).read_bytes() == data, name
        source = 'Files/Boundary 513.bin'
        copied = 'Files/Copied long filename.bin'
        shutil.copyfile(mountpoint / source, mountpoint / copied)
        assert (mountpoint / copied).read_bytes() == expected[source]
        expected[copied] = expected[source]
        destination = 'Files/Renamed long filename.bin'
        (mountpoint / source).rename(mountpoint / destination)
        expected[destination] = expected.pop(source)
        assert not (mountpoint / source).exists()
        write_synced(mountpoint / destination, payload(1025, 96))
        expected[destination] = payload(1025, 96)
        write_synced(mountpoint / deleted, payload(257))
        (mountpoint / deleted).unlink()
        (mountpoint / 'Empty directory').rmdir()
        assert not (mountpoint / deleted).exists()
    first = verify_image(image, expected)
    with mounted(image, driver, mountpoint, directory / 'remount.log'):
        for name, data in expected.items():
            assert (mountpoint / name).read_bytes() == data, name
        assert not (mountpoint / deleted).exists()
        assert not (mountpoint / 'Empty directory').exists()
    final = verify_image(image, expected)
    for report in (first, final):
        if not report['volume'].fat_copies_equal:
            raise AssertionError('FAT copies differ')
        report['volume'] = asdict(report['volume'])
    result = {'profile': profile, 'driver_sha256': file_sha256(driver),
              'after_write': first, 'after_remount': final}
    (directory / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'PASS {profile}', flush=True)


def suite(driver, profiles, output, timeout):
    from amifuse import __version__
    output.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix='fuse-', dir=output)).resolve()
    print(f'Artifacts: {run}', flush=True)
    summary = {'amifuse_version': __version__, 'driver': str(driver),
               'driver_sha256': file_sha256(driver), 'profiles': {}}
    failures = []
    for profile in profiles:
        directory = run / profile
        directory.mkdir()
        with (directory / 'worker.log').open('w') as log:
            process = subprocess.Popen([sys.executable, '-u', __file__, '--worker',
                                        '--profile', profile, '--driver', str(driver),
                                        '--output', str(directory)], stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                status = process.wait(timeout=timeout)
                summary['profiles'][profile] = {'status': status}
                if status:
                    failures.append(profile)
            except subprocess.TimeoutExpired:
                summary['profiles'][profile] = {'status': 'timeout'}
                failures.append(profile)
                try:
                    unmount(directory / 'mount')
                except Exception as error:
                    summary['profiles'][profile]['unmount_error'] = str(error)
                finally:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=5)
        print(f'{profile}: {summary["profiles"][profile]["status"]}', flush=True)
    (run / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    if failures:
        raise RuntimeError(f'Failed profiles: {", ".join(failures)}; logs: {run}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--suite', action='store_true')
    modes.add_argument('--mount', action='store_true')
    modes.add_argument('--worker', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--driver', type=Path, required=True)
    parser.add_argument('--image', type=Path)
    parser.add_argument('--mountpoint', type=Path)
    parser.add_argument('--profile', choices=PROFILES, action='append')
    parser.add_argument('--output', type=Path, default=RUNS)
    parser.add_argument('--timeout', type=int, default=600)
    args = parser.parse_args()
    driver = args.driver.resolve(strict=True)
    if args.suite:
        suite(driver, args.profile or list(PROFILES), args.output, args.timeout)
    elif args.worker:
        if not args.profile or len(args.profile) != 1:
            parser.error('--worker requires exactly one --profile')
        exercise(args.profile[0], driver, args.output.resolve())
    else:
        if args.image is None or args.mountpoint is None:
            parser.error('--mount requires --image and --mountpoint')
        mount_image(args.image.resolve(strict=True), driver, args.mountpoint.resolve(strict=True))


if __name__ == '__main__':
    main()
