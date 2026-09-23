"""Helper outputs, saved registers and condition codes.

Run: make test"""
import struct
import tempfile
import unittest
from pathlib import Path

from harness import C, CPU, GLOBALS, Handler, load


class HelperContracts(unittest.TestCase):
    """Date conversion, file attributes and cache initialization contracts."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        binary = Path(cls.temp.name) / 'handler.hunk'
        cls.image = load(binary)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.h = Handler(self.image)
        self.addCleanup(self.h.close)

    def call(self, name, *args):
        h = self.h
        shim = 0x58000
        code = b''.join(b'\x2f\x3c' + struct.pack('>I', arg) for arg in reversed(args))
        code += b'\x4e\xb9' + struct.pack('>I', h.syms[name])
        code += b'\xde\xfc' + struct.pack('>H', 4 * len(args)) + b'\x4e\x75'
        h.mem.w_block(shim, code)
        h.syms['helper_call'] = shim
        return h.run('helper_call')

    @staticmethod
    def protection(flags):
        return ((5 if flags & 1 else 0) | (128 if flags & 2 else 0)
                | (32 if flags & 4 else 0) | (0 if flags & 32 else 16))

    def test_give_file_info_all_attribute_bytes(self):
        """GiveFileInfo maps all 256 MS-DOS attribute bytes to the same AmigaDOS protection bits and returns with a2 and a3 untouched."""
        h = self.h
        entry, fib = 0x52000, 0x54000
        h.set('BlocksPerCluster', 1, 1)
        for flags in range(256):
            with self.subTest(flags=flags):
                h.mem.w_block(entry, bytes(C['XMSDE_Sizeof']))
                h.mem.w_block(entry, b'FILE    TXT')
                h.mem.w8(entry + C['MSDE_Flags'], flags)
                h.mem.w_block(fib, b'\xa5' * 260)
                self.call('GiveFileInfo', entry, fib)
                self.assertEqual(h.mem.r32(fib + C['FIB_Protection']),
                                 self.protection(flags))
                self.assertEqual(h.cpu.r_reg(10), 0x1357000a)
                self.assertEqual(h.cpu.r_reg(11), 0x1357000b)

    def test_examine_all_all_attribute_bytes(self):
        """ExamineAll skips the volume label for every attribute byte carrying bit 3, emits one record with the same protection bits for all the others, and never writes past the buffer."""
        h = self.h
        directory, control, target = 0x52000, 0x54000, 0x56000
        h.mem.w8(directory + C['XL_MSDE'] + C['MSDE_Flags'], 0x10)
        h.stub('Cluster2Block', lambda: h.result(32))
        for flags in range(256):
            with self.subTest(flags=flags):
                h.mem.w_block(control, bytes(C['EAC_Sizeof']))
                h.mem.w_block(target, b'\xa5' * 1024)
                reads = []
                def read_entry():
                    if reads:
                        h.result(0)
                        return
                    buf = h.mem.r32(h.cpu.r_sp() + 8)
                    h.mem.w_block(buf, bytes(C['XMSDE_Sizeof']))
                    h.mem.w_block(buf, b'FILE    TXT')
                    h.mem.w8(buf + C['MSDE_Flags'], flags)
                    reads.append(buf)
                    h.result(1)
                h.stub('ReadXMSDE', read_entry)
                self.assertEqual(self.call('ExamineAll', directory, target, 1024,
                                           4, control), 0)
                self.assertEqual(h.mem.r32(control + C['EAC_Entries']),
                                 0 if flags & 8 else 1)
                if not flags & 8:
                    self.assertEqual(h.mem.r32(target + C['ED_Prot']),
                                     self.protection(flags))
                self.assertEqual(h.mem.r8(target + 1023), 0xa5)

    def test_cache_init_list_sentinels_counters_registers_and_ccr(self):
        """CacheInit empties both buffer lists to their sentinel form and zeroes the in-use counters, carrying d0, d1 and a1 through with the other registers and the condition codes untouched."""
        h = self.h
        for name in ('SingleBuf', 'BufList', 'FAT32List'):
            h.set(name, 0xa5a5a5a5)
        h.set('NormBufsUsed', 123, 2)
        h.set('DirBufsUsed', 456, 2)
        h.run('CacheInit', d0=0x12345678, d1=0x23456789, a1=0x34567890)
        self.assertEqual(h.get('SingleBuf'), 0)
        self.assertEqual(h.get('NormBufsUsed', 2), 0)
        self.assertEqual(h.get('DirBufsUsed', 2), 0)
        for name in ('BufList', 'FAT32List'):
            addr = GLOBALS + C[name]
            self.assertEqual([h.mem.r32(addr + n) for n in (0, 4, 8)],
                             [addr + 4, 0, addr])
        self.assertEqual(h.cpu.r_reg(8), GLOBALS + C['FAT32List'])
        for reg, value in ((0, 0x12345678), (1, 0x23456789), (9, 0x34567890)):
            self.assertEqual(h.cpu.r_reg(reg), value)
        for reg in (2, 3, 4, 5, 6, 7, 10, 11, 13):
            self.assertEqual(h.cpu.r_reg(reg), 0x13570000 + reg)
        self.assertEqual(h.cpu.r_sr() & 15, 0)

    def test_ms_date_string_all_packed_dates(self):
        """All 65536 dates yield ten DD.MM.YYYY bytes; a1 advances and saved registers survive."""
        h = self.h
        target = 0x56000
        for value in range(65536):
            h.mem.w_block(target, b'\xa5' * 12)
            h.run('MSDate2Str', d0=value, a1=target)
            expected = f'{value & 31:02}.{(value >> 5) & 15:02}.{1980 + (value >> 9):04}'
            self.assertEqual(bytes(h.mem.r_block(target, 12)),
                             expected.encode() + b'\xa5\xa5', value)
            self.assertEqual(h.cpu.r_reg(9), target + 10)
            for reg in (2, 3, 4, 5, 6, 7, 10, 11, 13):
                self.assertEqual(h.cpu.r_reg(reg), 0x13570000 + reg)
