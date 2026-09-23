"""Raw-FAT adapter between AmiFUSE's HandlerBridge and the fat95 handler, with the observer that records what reaches the device. Patches nothing on disk; the changes are made to the imported objects at runtime.

Status: library for the handler-in-the-loop tier. Pinned to amifuse 0.6.0."""
import os
import time
from pathlib import Path
from amifuse.fuse_fs import HandlerBridge
from amifuse.rdb_inspect import ADFInfo
from amifuse.scsi_device import ScsiDevice, IORequestStruct
from amifuse_images import inspect_image

_original_io = ScsiDevice.BeginIO

def _trackdisk_query(self, ctx, request):
    observer = getattr(self.backend, '_fat95_io_observer', None)
    if observer:
        observer(IORequestStruct(ctx.mem, request))
    result = _original_io(self, ctx, request)
    ior = IORequestStruct(ctx.mem, request)
    if ior.command.val == 0x4000 and ior.actual.val == 16 and not ior.error.val:
        # NDK devices/newstyle.h: NSDEVTYPE_TRACKDISK = 5 (upstream uses 0).
        ctx.mem.w16(ior.data.val + 8, 5)
    return result

ScsiDevice.BeginIO = _trackdisk_query

class RawFatBridge(HandlerBridge):
    def __init__(self, image, driver, **kwargs):
        self.expect_managed = kwargs.pop('expect_managed', False)
        volume = inspect_image(image)
        sectors = volume.total_sectors
        heads, spt = (2, 9 if sectors == 1440 else 18) if sectors in (1440, 2880) else (1, 1)
        geometry = ADFInfo(0x46415400, sectors == 2880, sectors // (heads * spt),
                           heads, spt, 512, sectors)
        super().__init__(Path(image), Path(driver), read_only=False,
                         adf_info=geometry, **kwargs)
        self.last_reply = None
        self.exited = False
        self.initial_stack_size = self.state.stack.get_size()
        self.io_counts = dict(read=0, write=0, update=0)
        self.payload_checks = 0
        self.observer_error = None
        self._volume = volume
        # Observe post-startup requests only; fixture mounting is not measured.
        self.backend._fat95_io_observer = self._observe_io

    def _observe_io(self, request):
        command = request.command.val
        kind = {2: 'read', 3: 'write', 4: 'update'}.get(command)
        if kind:
            self.io_counts[kind] += 1
        v = self._volume
        if command != 3 or not self.expect_managed or v.fat_bits == 12:
            return
        headers = [v.reserved_sectors + i * v.sectors_per_fat
                   for i in range(v.fat_count)]
        if request.length.val == 512 and request.offset.val in [s * 512 for s in headers]:
            return  # Marker sectors are updated one copy at a time.
        offset, mask = (3, 0x80) if v.fat_bits == 16 else (7, 8)
        for sector in headers:
            header = self.backend.read_blocks(sector, 1)
            if header[offset] & mask:
                self.observer_error = (f'Payload write before dirty marker: '
                                       f'offset={request.offset.val}, '
                                       f'length={request.length.val}, FAT sector={sector}')
                raise AssertionError(self.observer_error)
        self.payload_checks += 1

    def snapshot(self):
        return dict(pc=self.state.pc, sp=self.state.sp, crashed=self.state.crashed,
                    registers=self.state.regs, stack_lower=self.state.stack.get_lower(),
                    stack_upper=self.state.stack.get_upper())

    def _run_until_replies(self, *args, **kwargs):
        replies = super()._run_until_replies(*args, **kwargs)
        if getattr(self, 'observer_error', None):
            raise AssertionError(self.observer_error)
        if self.state.crashed:
            raise AssertionError(f'Handler crashed: {self.snapshot()}')
        if not replies:
            raise AssertionError(f'No DOS packet reply: {self.snapshot()}')
        self.last_reply = replies[-1]
        return replies

    def packet(self, kind, *args):
        self.launcher.send_packet(self.state, kind, list(args))
        reply = self._run_until_replies()[-1]
        if reply[2] == 0:
            raise AssertionError(f'Packet {kind} failed: {reply[2:]}')
        return reply[2:]

    def flush_volume(self):
        self.packet(27)
        self.backend.sync()

    def close_file(self, handle):
        self.launcher.send_end_handle(self.state, handle)
        reply = self._run_until_replies()[-1]
        self._free_fh(handle)
        if not reply[2]:
            raise AssertionError(f'Close failed: {reply[2:]}')

    def put(self, path, data):
        opened = self.open_file(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC)
        if not opened:
            raise AssertionError(f'Open failed: {path}')
        handle, lock = opened
        try:
            for offset in range(0, len(data), 32768):
                block = data[offset:offset+32768]
                count = self.write_handle(handle, block)
                if count != len(block):
                    raise AssertionError(f'Short write {path}: {count}/{len(block)}')
        finally:
            try:
                self.close_file(handle)
            finally:
                if lock:
                    self.free_lock(lock)

    def read_file(self, path, size, offset):
        opened = self.open_file(path, os.O_RDONLY)
        if not opened:
            raise AssertionError(f'Read open failed: {path}')
        handle, lock = opened
        try:
            if offset:
                self.launcher.send_seek_handle(self.state, handle, offset, -1)
                reply = self._run_until_replies()[-1]
                assert reply[2] >= 0, reply
            data = self.read_handle(handle, size)
            assert self.last_reply[2] >= 0 and self.last_reply[3] == 0, self.last_reply
            assert len(data) == self.last_reply[2], self.last_reply
            return data
        finally:
            try:
                self.close_file(handle)
            finally:
                if lock:
                    self.free_lock(lock)

    def shutdown_handler(self):
        if self.exited:
            return
        self.flush_volume()
        self.packet(5)  # ACTION_DIE; acknowledge alone is insufficient.
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            rs = self.launcher.run_burst(self.state, max_cycles=200000)
            if self.state.crashed:
                raise AssertionError(f'Shutdown crash: {self.snapshot()}')
            if getattr(rs, 'done', False) and not getattr(rs, 'error', None):
                self.exited = True
                self.backend.sync()
                return
            time.sleep(.002)
        raise AssertionError(f'Handler did not exit after ACTION_DIE: {self.snapshot()}')
