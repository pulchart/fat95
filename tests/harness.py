#!/usr/bin/env python3
"""Run assembled handler routines with mocked device and Exec calls.

Requires vasm and amitools (vamos backend). No disk devices are opened.
Run: python3 -m unittest discover -s tests -v
Set FAT95_TEST_CPU=68020 to test the 68020 build (default: 68000).

Status: library, imported by every suite. No disk device is ever opened.
"""
import re

from amitools.binfmt.Relocate import Relocate
from amitools.vamos.machine import Machine

# Re-exported so every suite can keep importing them from here. Bind the names,
# never reach for toolchain.CPU at a use site: audit_selector.py rebinds
# harness.CPU to sweep both CPU tiers and Handler reads that module global.
from toolchain import ROOT, CPU, VASM, assemble, load
BASE, GLOBALS, REQUEST, BUFFER, WINDOW, BB, STACK = (
    0x10000, 0x20000, 0x21000, 0x22000, 0x24000, 0x48000, 0x90000
)


def constants():
    result = {}
    for line in (ROOT / 'src/fat95.s').read_text().splitlines():
        match = re.match(r'^(\w+)\s*=\s*([^;]+)', line)
        if match:
            name, expr = match.groups()
            expr = re.sub(r'\$([\da-fA-F]+)', r'0x\1', expr)
            expr = re.sub(r'%([01]+)', r'0b\1', expr)
            # Only evaluate arithmetic constant declarations from this source.
            if re.fullmatch(r'[\w\s+*/()<>|&~^-]+', expr):
                try:
                    result[name] = int(eval(expr, {'__builtins__': {}}, result))
                except (NameError, SyntaxError, TypeError):
                    pass
    return result


C = constants()


class Handler:
    """One run of the handler: the relocated image in emulated memory, a mocked device and Exec, and the card as a dict.

    Create one per test. Only one vamos Machine may be live at a time, so close
    it before building the next; the unittest files do that through addCleanup.

    The injection flags stay in force until the test clears them, they are not
    consumed by one request. `fail` is 'read', 'write' or 'flush' and makes
    every matching request fail, `short` makes every transfer report fewer
    bytes than asked, `retry` makes the device report a change the caller may
    retry through, and `swap_on` is the request kind during which the card is
    replaced. `disk` maps LBA to bytearray and `events` records the request
    kind and LBA in the order the handler issued them.
    """
    def __init__(self, image):
        self.m = Machine.from_name(CPU)
        self.cpu, self.mem = self.m.get_cpu(), self.m.get_mem()
        self.mem.w_block(BASE, bytes(Relocate(image).relocate_one_block(BASE)))
        self.syms = {s.name.decode(): BASE + s.offset
                     for s in image.get_segments()[0].get_symtab().get_symbols()}
        self.events = []
        self.disk = {}
        self.fail = None
        self.swap_on = None
        self.short = False
        self.retry = False
        self.stub('SafeDoIO', self.io)
        self.stub('DoRequest', self.requester)
        self.stub('DiskMotorOff', lambda: self.result(0))
        self.stub('DoTimer', lambda: self.result(0))
        self.set('DiskRequest', REQUEST)
        self.set_if('CleanBuffer', BUFFER)
        self.set_if('CleanBufferSize', 512)
        self.set('BlockSize', 512, 2)
        self.set('BlockShift', 9, 2)
        self.set('BlockMask', 511)
        self.set('ReadCmd', 2, 2)
        self.set('WriteCmd', 3, 2)
        self.set('UpdateCmd', 4, 2)
        self.set('CmdFlags', 8, 2)
        self.mem.w32(GLOBALS + C['EnvecBuf'] + C['DE_MaxTransfer'], 65536)
        self.set('FATType', 0xffff, 2)
        self.set('FATStartBlock', 32, 2)
        self.set('BlocksPerFAT', 128)
        self.set('NumFATCopies', 2, 1)
        self.set('FirstBlock', 2048)
        self.set('FATBuffer', WINDOW)
        self.set('FATBNum', 32)
        self.set_if('MountGeneration', 7)
        self.set_if('MediaGeneration', 7)
        self.set_if('MountedClean', 1, 2)
        self.set('PhysFlags', 2, 2)
        self.set('DiskState', C['ID_VALIDATED'])
        head = GLOBALS + C['FAT32List']
        self.mem.w32(head, WINDOW)
        self.mem.w32(head + 4, 0)
        self.mem.w32(head + 8, WINDOW)
        self.mem.w32(WINDOW, head + 4)
        self.mem.w32(WINDOW + 4, head)
        self.mem.w32(WINDOW + C['F32B_Start'], 0)
        for lba in (2080, 2208):
            sector = bytearray((i * 37 + lba) % 256 for i in range(512))
            sector[4:8] = (0xafffffff).to_bytes(4, 'little')
            self.disk[lba] = sector
        self.mem.w_block(WINDOW + C['F32B_Data'], bytes(self.disk[2080]))

    def close(self):
        """Tear the emulated machine down. Safe to call twice."""
        if self.m is not None:
            self.m.cleanup()
            self.m = None

    def set(self, name, value, size=4):
        """Write a global by its name from src/fat95.s, size in bytes."""
        getattr(self.mem, f'w{size * 8}')(GLOBALS + C[name], value)

    def set_if(self, name, value, size=4):
        """Set a global only if this build defines it (design-specific)."""
        if name in C:
            self.set(name, value, size)
        return name in C

    def has(self, *names):
        """True when this build defines every named global or routine, for design-specific tests."""
        return all(n in C or n in self.syms for n in names)

    def get(self, name, size=4):
        """Read a global by its name from src/fat95.s, size in bytes."""
        return getattr(self.mem, f'r{size * 8}')(GLOBALS + C[name])

    def result(self, value):
        """Put a return value in d0, for a stub standing in for a routine."""
        self.cpu.w_reg(0, value & 0xffffffff)

    def stub(self, name, fn):
        """Replace the routine `name` with a python callable for the rest of this run."""
        self.trap(self.syms[name], fn)

    def trap(self, address, fn):
        """Replace the code at `address` with a trap into `fn`, followed by rts."""
        tid = self.m.get_traps().alloc(lambda opcode, pc: fn())
        self.mem.w16(address, 0xa000 | tid)
        self.mem.w16(address + 2, 0x4e75)

    def requester(self):
        """Mocked DoRequest: reports a media change when `retry` is set."""
        if self.retry:
            self.set_if('MediaGeneration', 8)
            self.set('DiskChanged', 0, 2)
        self.result(1 if self.retry else 0)

    def io(self):
        """Mocked SafeDoIO: serves the request from `disk`, records it in `events`, and applies the injection flags."""
        req = self.cpu.r_reg(9)
        cmd = self.mem.r16(req + C['IO_Command'])
        length = self.mem.r32(req + C['IO_Length'])
        lba = self.mem.r32(req + C['IO_Offset']) // 512
        ptr = self.mem.r32(req + C['IO_Data'])
        kind = {2: 'read', 3: 'write', 4: 'flush'}[cmd]
        self.events.append((kind, lba))
        if self.swap_on == kind:
            self.set_if('MediaGeneration', 8)
        if self.fail == kind:
            self.result(20)
            self.mem.w32(req + C['IO_Actual'], 0)
            return
        if kind == 'read':
            data = b''.join(self.disk.get(i, bytes(512))
                            for i in range(lba, lba + length // 512))
            self.mem.w_block(ptr, data)
        elif kind == 'write':
            for offset in range(0, length, 512):
                self.disk[lba + offset // 512] = bytearray(
                    self.mem.r_block(ptr + offset, 512))
        self.mem.w32(req + C['IO_Actual'], 0 if self.short else length)
        self.result(0)

    def run(self, name, d0=0, d1=0, a0=0, a1=0, a2=None):
        """Call a routine by name and return d0.

        d0, d1, a0, a1 and a2 seed the registers. The scratch registers are
        seeded with 0x13570000 plus their number so a test can assert they came
        back unchanged, and a4 always points at the globals.
        """
        for i in range(16):
            self.cpu.w_reg(i, 0)
        saved = {reg: 0x13570000 + reg for reg in (2, 3, 4, 5, 6, 7, 10, 11, 13)}
        for reg, value in saved.items():
            self.cpu.w_reg(reg, value)
        for reg, value in ((0, d0), (1, d1), (8, a0), (9, a1), (12, GLOBALS)):
            self.cpu.w_reg(reg, value)
        if a2 is not None:
            self.cpu.w_reg(10, a2)
        self.m.prepare(self.syms[name], STACK)
        for _ in range(200):
            result = self.m.execute(10000)
            if self.m.was_exit(result):
                assert self.cpu.r_sp() == STACK, (name, hex(self.cpu.r_sp()))
                if name in ('MarkVolumeDirty', 'SetFATClean', 'MarkFSInfoUnknown',
                            'UpdateFSInfo', 'WriteBBuf', 'WriteFAT',
                            'UpdateDisk', '_Read', '_Write', 'ReadFAT', 'ScanDisk',
                            'MoveFATWindow', 'ReadSingle'):
                    for reg, value in saved.items():
                        assert self.cpu.r_reg(reg) == value, (name, 'register', reg)
                return self.cpu.r_reg(0)
        raise AssertionError(f'{name} did not return, PC={self.cpu.r_pc():x}')

    def exec_memory(self):
        """Make AllocMem and FreeVec answer, for routines that allocate."""
        self.set('ExecBase', 0x70000)
        if not hasattr(self, 'next_alloc'):
            self.next_alloc = 0x62000
        def allocate():
            address = self.next_alloc
            self.next_alloc += max(0x1000, (self.cpu.r_reg(0) + 4095) & ~4095)
            assert self.next_alloc < 0x70000, 'mock allocation space exhausted'
            self.result(address)
        self.trap(0x70000 + C['AllocMem'], allocate)
        self.trap(0x70000 + C['FreeMem'], lambda: self.result(0))

    def prepare_close(self):
        """Put the globals in the state CloseDisk expects, so a test can drive an unmount."""
        self.exec_memory()
        for name in ('_sreq_diepend', 'MarkAbsentViaPtable', 'TouchVolumeNode',
                     'CloseXLock', 'ChangeReport'):
            self.stub(name, lambda: self.result(0))
        self.set('VolumeNode', 0x50000)
        head = GLOBALS + C['BufList']
        self.mem.w32(head, head + 4)
        self.mem.w32(head + 4, 0)
        self.mem.w32(head + 8, head)

    def fsinfo(self, free=125):
        """Lay out a FAT32 card with a valid FSInfo sector carrying `free` clusters."""
        self.exec_memory()
        self.set('FSInfoBlock', 1)
        self.set('LastCluster', 127)
        data = bytearray(512)
        data[0:4] = b'RRaA'
        data[484:488] = b'rrAa'
        data[488:492] = free.to_bytes(4, 'little')
        data[492:496] = (3).to_bytes(4, 'little')
        data[510:512] = b'\x55\xaa'
        self.disk[2049] = data

    def prepare_check(self):
        """Put the globals in the state ScanDisk expects, so a test can drive a scan."""
        self.exec_memory()
        self.set('LastCluster', 127)
        self.set('RootCluster', 2)
        self.set('RootDirEnd', 288)
        self.set('BlocksPerCluster', 1, 1)
        self.set('FreeClusters', 125)
        self.set('NextFreeCluster', 3)
        self.set('TimeRequest', 0x61000)
        self.stub('OpenProgWindow', lambda: self.result(0))
        self.stub('SPrintF', lambda: self.result(0))
        self.trap(0x70000 + C['WaitIO'], lambda: self.result(0))
        self.trap(0x70000 + C['DoIO'], lambda: self.result(0))
        def root():
            self.cpu.w_reg(8, BB)
            self.result(BB + C['BB_Data'])
        self.stub('ReadDirBlock', root)
        for lba in (2080, 2208):
            self.disk[lba] = bytearray(512)
            for offset in (0, 4, 8):
                self.disk[lba][offset:offset + 4] = (0x0fffffff).to_bytes(4, 'little')
        self.mem.w_block(WINDOW + C['F32B_Data'], bytes(self.disk[2080]))

    def evict_single(self, block):
        """Point the one-entry ReadSingle cache at another, clean block."""
        buf = self.get('SingleBuf')
        assert buf, 'SingleBuf not allocated yet'
        self.mem.w32(buf + C['BB_BlockNum'], block)
        self.mem.w16(buf + C['BB_OpenCnt'], 0)
        self.mem.w32(buf + C['BB_DirtyFlags'], 0)

    def dirty_single(self, block):
        """Leave the one-entry ReadSingle cache holding another dirty block."""
        buf = self.get('SingleBuf')
        assert buf, 'SingleBuf not allocated yet'
        self.mem.w32(buf + C['BB_BlockNum'], block)
        self.mem.w32(buf + C['BB_Blocks'], 1)
        self.mem.w16(buf + C['BB_OpenCnt'], 0x8000)
        self.mem.w32(buf + C['BB_DirtyFlags'], 0x80000000)

    def dirty_buffer_multi(self, blocks=2):
        """A buffer spanning several blocks, all dirty, as a cluster does."""
        self.mem.w32(BB + C['BB_BlockNum'], 2300)
        self.mem.w32(BB + C['BB_Blocks'], blocks)
        self.mem.w16(BB + C['BB_OpenCnt'], 0x8000)
        self.mem.w32(BB + C['BB_DirtyFlags'],
                     ((1 << blocks) - 1) << (32 - blocks))
        self.mem.w_block(BB + C['BB_Data'], b'x' * (512 * blocks))

    def dirty_buffer(self):
        """Mark one block dirty in the multi-block buffer, the ordinary pending-metadata state."""
        self.mem.w32(BB + C['BB_BlockNum'], 2300)
        self.mem.w32(BB + C['BB_Blocks'], 1)
        self.mem.w16(BB + C['BB_OpenCnt'], 0x8000)
        self.mem.w32(BB + C['BB_DirtyFlags'], 0x80000000)
        self.mem.w_block(BB + C['BB_Data'], b'x' * 512)


