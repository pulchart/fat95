"""Scratch-register clear loops: GetDefVolName and ExamineAll must zero the record they own and nothing past it.

Run: make test"""
import struct
import tempfile
import unittest
from pathlib import Path
from harness import C, CPU, Handler, load

class ClearPaths(unittest.TestCase):
    """Scratch-buffer clear loops: each must zero the record it owns and stop there. Assembles src/fat95.s once for the CPU tier under test."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        path = Path(cls.temp.name) / 'handler.hunk'
        cls.image = load(path)

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
        h.syms['test_call'] = shim
        return h.run('test_call')

    def test_default_name_clear_loop_preserves_surrounding_bytes(self):
        """GetDefVolName clears only up to the longword-rounded end of the record it fills, so the byte past that end keeps its previous value."""
        h = self.h
        target = 0x56000
        h.mem.w_block(target, b'\xa5' * C['XMSDE_Sizeof'])
        h.set('SerialNum', 0x1234abcd)
        self.call('GetDefVolName', target)
        self.assertEqual(bytes(h.mem.r_block(target, 12)), b'1234-ABCD  (')
        end = 12 + ((C['XMSDE_FullName'] + 1 - 12 + 3) // 4) * 4
        expected = bytearray(end - 12)
        expected[C['MSDE_Date'] - 12:C['MSDE_Date'] - 10] = b'\x00\x21'
        self.assertEqual(bytes(h.mem.r_block(target + 12, end - 12)), expected)
        self.assertEqual(h.mem.r8(target + end), 0xa5)

    def test_exall_clears_each_entry_for_short_and_full_records(self):
        """ExamineAll zeroes every field of each record it emits, for short and full record types alike, and never writes past the buffer the caller gave it."""
        h = self.h
        directory, control, target = 0x52000, 0x54000, 0x56000
        h.mem.w8(directory + C['XL_MSDE'] + C['MSDE_Flags'], 0x10)
        h.stub('Cluster2Block', lambda: h.result(32))
        for record_type in (1, 2, 7):
            with self.subTest(record_type=record_type):
                entries = []
                h.mem.w_block(control, bytes(C['EAC_Sizeof']))
                h.mem.w_block(target, b'\xa5' * 1024)
                def read_entry():
                    if len(entries) == 2:
                        h.result(0)
                        return
                    buf = h.mem.r32(h.cpu.r_sp() + 8)
                    h.mem.w_block(buf, bytes(C['XMSDE_Sizeof']))
                    h.mem.w_block(buf, f'FILE{len(entries)}   TXT'.encode())
                    h.mem.w8(buf + C['MSDE_Flags'], 0x20)
                    entries.append(buf)
                    h.result(1)
                h.stub('ReadXMSDE', read_entry)
                self.assertEqual(self.call('ExamineAll', directory, target, 1024,
                                           record_type, control), 0)
                self.assertEqual(h.mem.r32(control + C['EAC_Entries']), 2)
                nxt = h.mem.r32(target + C['ED_Next'])
                self.assertGreater(nxt, target)
                self.assertEqual(h.mem.r32(nxt + C['ED_Next']), 0)
                if record_type == 7:
                    for item in (target, nxt):
                        self.assertEqual(h.mem.r32(item + C['ED_Comment']), 0)
                        self.assertEqual(h.mem.r32(item + C['ED_OwnerUID']), 0)
                self.assertEqual(h.mem.r8(target + 1024 - 1), 0xa5)
