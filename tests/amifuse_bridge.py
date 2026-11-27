"""Raw-FAT adapter between AmiFUSE's HandlerBridge and the fat95 handler, with the observer that records what reaches the device. Patches nothing on disk; the changes are made to the imported objects at runtime.

Status: library for the handler-in-the-loop tier. Pinned to amifuse 1.0.0."""

import contextlib
import os
import time
from pathlib import Path
from amifuse.emu_thread import route_methods_through_emu
from amifuse.fuse_fs import HandlerBridge
from amifuse.rdb_inspect import ADFInfo
from amifuse.scsi_device import ScsiDevice, IORequestStruct
from amifuse_images import inspect_image

_original_io = ScsiDevice.BeginIO


def _observed_io(self, ctx, request):
    observer = getattr(self.backend, "_fat95_io_observer", None)
    if observer:
        observer(IORequestStruct(ctx.mem, request))
    return _original_io(self, ctx, request)


ScsiDevice.BeginIO = _observed_io


class RawFatBridge(HandlerBridge):
    def __init__(self, image, driver, **kwargs):
        self.expect_managed = kwargs.pop("expect_managed", False)
        control = kwargs.pop("control", None)
        volume = inspect_image(image)
        sectors = volume.total_sectors
        heads, spt = (2, 9 if sectors == 1440 else 18) if sectors in (1440, 2880) else (1, 1)
        geometry = ADFInfo(
            0x46415400, sectors == 2880, sectors // (heads * spt), heads, spt, 512, sectors
        )
        super().__init__(Path(image), Path(driver), read_only=False, adf_info=geometry, **kwargs)
        self.last_reply = None
        self.exited = False
        self.initial_stack_size = self.state.stack.get_size()
        self.io_counts = dict(read=0, write=0, update=0)
        self.payload_checks = 0
        self.observer_error = None
        self._volume = volume
        # Observe post-startup requests only; fixture mounting is not measured.
        self.backend._fat95_io_observer = self._observe_io
        if control:
            self.control(control)

    def control(self, options):
        """Change Control options at runtime, as filenote "!control <options>" does."""
        self.packet(28, 0, 0, self._alloc_bstr("")[1], self._alloc_bstr("!control " + options)[1])

    def _observe_io(self, request):
        command = request.command.val
        kind = {2: "read", 3: "write", 4: "update"}.get(command)
        if kind:
            self.io_counts[kind] += 1
        v = self._volume
        if command != 3 or not self.expect_managed or v.fat_bits == 12:
            return
        headers = [v.reserved_sectors + i * v.sectors_per_fat for i in range(v.fat_count)]
        if request.length.val == 512 and request.offset.val in [s * 512 for s in headers]:
            return  # Marker sectors are updated one copy at a time.
        offset, mask = (3, 0x80) if v.fat_bits == 16 else (7, 8)
        for sector in headers:
            header = self.backend.read_blocks(sector, 1)
            if header[offset] & mask:
                self.observer_error = (
                    f"Payload write before dirty marker: "
                    f"offset={request.offset.val}, "
                    f"length={request.length.val}, FAT sector={sector}"
                )
                raise AssertionError(self.observer_error)
        self.payload_checks += 1

    def snapshot(self):
        return dict(
            crashed=self.state.crashed,
            exited=self.state.exited,
            error=repr(self.state.last_error) if self.state.last_error else None,
            error_pc=self.state.last_error_pc,
            stack_lower=self.state.stack.get_lower(),
            stack_upper=self.state.stack.get_upper(),
        )

    def _run_until_replies(self, *args, **kwargs):
        replies = super()._run_until_replies(*args, **kwargs)
        if getattr(self, "observer_error", None):
            raise AssertionError(self.observer_error)
        if self.state.crashed:
            raise AssertionError(f"Handler crashed: {self.snapshot()}")
        if not replies:
            raise AssertionError(f"No DOS packet reply: {self.snapshot()}")
        self.last_reply = replies[-1]
        return replies

    def _run_until_reply(self, pkt_addr, label, **wait):
        answer = super()._run_until_reply(pkt_addr, label, **wait)
        if answer is not None:
            self.last_reply = (0, pkt_addr, *answer)
        return answer

    def _answer(self, sent, label):
        reply = self._run_until_reply(sent[0], label)
        if reply is None:
            raise AssertionError(f"No reply to {label}: {self.snapshot()}")
        return reply

    def packet(self, kind, *args):
        reply = self._answer(self.launcher.send_packet(self.state, kind, list(args)), "packet")
        if reply[0] == 0:
            raise AssertionError(f"Packet {kind} failed: {reply}")
        return reply

    def flush_volume(self, wait_pending=True):
        self.packet(27)
        self.backend.sync()

    def close_file(self, handle):
        reply = self._answer(self.launcher.send_end_handle(self.state, handle), "close")
        self._free_fh(handle)
        if not reply[0]:
            raise AssertionError(f"Close failed: {reply}")

    def put(self, path, data):
        opened = self.open_file(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC)
        if not opened:
            raise AssertionError(f"Open failed: {path}")
        handle, lock = opened
        try:
            for offset in range(0, len(data), 32768):
                block = data[offset : offset + 32768]
                count = self.write_handle(handle, block)
                if count != len(block):
                    raise AssertionError(f"Short write {path}: {count}/{len(block)}")
        finally:
            try:
                self.close_file(handle)
            finally:
                if lock:
                    self.free_lock(lock)

    def read_file(self, path, size, offset):
        opened = self.open_file(path, os.O_RDONLY)
        if not opened:
            raise AssertionError(f"Read open failed: {path}")
        handle, lock = opened
        try:
            if offset:
                reply = self._answer(
                    self.launcher.send_seek_handle(self.state, handle, offset, -1), "seek"
                )
                assert reply[0] >= 0, reply
            data = self.read_handle(handle, size)
            assert data is not None, (path, self.last_reply)
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
            self.launcher.run(max_cycles=200000)
            if self.state.crashed:
                raise AssertionError(f"Shutdown crash: {self.snapshot()}")
            if self.state.exited:
                self.exited = True
                self.backend.sync()
                return
            time.sleep(0.002)
        raise AssertionError(f"Handler did not exit after ACTION_DIE: {self.snapshot()}")


# The methods above run on the emulation thread, as HandlerBridge's own do.
route_methods_through_emu(RawFatBridge)


def okay(result):
    assert result[0] != 0, result
    return result[0]


DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUV"


def escape_value(text):
    """The code point of the escape at the start of text (behind its %), or None."""
    digits = [DIGITS.find(c.upper()) if c.upper() in DIGITS else -1 for c in text[:5]]
    if not digits or not 2 <= digits[0] >> 2 <= 4:
        return None
    size = digits[0] >> 2
    if len(digits) <= size or -1 in digits[: size + 1]:
        return None
    value = digits[0] & 3
    for d in digits[1 : size + 1]:
        value = value << 5 | d
    if size > 2:
        if value & 1:
            return None
        value >>= 1
    if (
        value < (0x80, 0x800, 0x10000)[size - 2]
        or 0xD800 <= value < 0xE000
        or value in (0xFFFE, 0xFFFF)
        or value > 0x10FFFF
    ):
        return None
    return value


def escaped(text, esc="%"):
    """What the handler shows for a name: a character outside Latin-1 as esc and its code point in base 32, an esc as two where the text behind it starts with esc or reads as an escape."""
    out = ""
    for char in reversed(text):
        cp = ord(char)
        if char == esc:
            piece = esc * 2 if out.startswith(esc) or escape_value(out) is not None else esc
        elif cp < 0x100:
            piece = char
        elif cp < 0x800:
            piece = esc + DIGITS[8 | cp >> 10] + DIGITS[cp >> 5 & 31] + DIGITS[cp & 31]
        elif cp < 0x10000:
            piece = (
                esc
                + DIGITS[12 | cp >> 14]
                + DIGITS[cp >> 9 & 31]
                + DIGITS[cp >> 4 & 31]
                + DIGITS[cp << 1 & 31]
            )
        else:
            piece = (
                esc
                + DIGITS[16 | cp >> 19]
                + DIGITS[cp >> 14 & 31]
                + DIGITS[cp >> 9 & 31]
                + DIGITS[cp >> 4 & 31]
                + DIGITS[cp << 1 & 31]
            )
        out = piece + out
    return out


MEMF_CLEAR = 0x10000


@contextlib.contextmanager
def dirty_memory():
    """Memory from AllocMem without MEMF_CLEAR holds garbage, as on a real machine."""
    from amitools.vamos.lib.ExecLibrary import ExecLibrary

    original = ExecLibrary.AllocMem

    def alloc(self, ctx):
        size, flags = ctx.cpu.r_reg(0), ctx.cpu.r_reg(1)
        addr = original(self, ctx)
        if addr and not flags & MEMF_CLEAR:
            ctx.mem.clear_block(addr, (size + 3) & ~3, 0xA5)
        return addr

    ExecLibrary.AllocMem = alloc
    try:
        yield
    finally:
        ExecLibrary.AllocMem = original
