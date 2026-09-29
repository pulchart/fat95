"""Partition selection from DosType bytes and device-name suffixes."""
import tempfile
import unittest
from pathlib import Path

from harness import C, Handler, load


class SelectorTests(unittest.TestCase):
    """Selection validates names without changing saved registers."""
    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.image = load(Path(tmp.name) / 'handler.hunk')

    def setUp(self):
        self.h = h = Handler(self.image)
        self.addCleanup(h.close)
        h.set('DeviceNode', 0x51000)
        h.mem.w32(0x51000 + C['DOL_Name'], 0x52000 >> 2)

    def select(self, name, expected, dos_type=0x464154ff):
        h = self.h
        h.set('DosType', dos_type)
        h.set('PartitionSelector', 77, 1)
        h.mem.w_block(0x52000, bytes([len(name)]) + name.encode('ascii'))
        self.assertEqual(h.run('SetPartSelector'), 218 if expected is None else 0)
        self.assertEqual(h.get('PartitionSelector', 1),
                         77 if expected is None else expected)
        self.assertEqual(bool(h.cpu.r_sr() & 4), expected is not None)
        for reg in (2, 3, 4, 5, 6, 7, 10, 11, 13):
            self.assertEqual(h.cpu.r_reg(reg), 0x13570000 + reg)

    def test_device_name_uses_only_the_trailing_number(self):
        """Name selectors cover 0..254; absent digits select the first partition."""
        for number in range(255):
            with self.subTest(number=number):
                self.select('CF' + str(number), number + 1)
        for name in ('', 'CF', '255x', '999999x', 'CF1.', 'CF1.x'):
            with self.subTest(name=name):self.select(name, 1)
        for name, expected in [('0000000000000', 1), ('x255x0', 1),
                               ('999999x254', 255), ('CF000001', 2)]:
            with self.subTest(name=name):self.select(name, expected)

    def test_registration_suffix_does_not_select_a_partition(self):
        """A trailing dot-number suffix is ignored when resolving the partition."""
        for name, expected in [('CF0.1', 1), ('CF254.999', 255),
                               ('CF255.1', None), ('CF.1', 1), ('.1', 1)]:
            with self.subTest(name=name):self.select(name, expected)

    def test_out_of_range_names_fail_without_replacing_the_selector(self):
        """Values above 254, including overflowing digit runs, reject the mount."""
        for name in ('255', 'CF255', 'CF256', 'CF4294967296', 'CF' + '9' * 250):
            with self.subTest(name=name):self.select(name, None)

    def test_dos_type_byte_ignores_the_device_name(self):
        """Non-marker DosTypes select their low byte regardless of the device name."""
        for number in range(255):
            with self.subTest(number=number):
                self.select('CF99999999999999', number, 0x46415400 | number)


if __name__ == '__main__':
    unittest.main()


RES, ENTRIES, DEVICE = 0x60000, 0x61000, 0x5f000
FAT, DOS = 0x46415400, 0x444f5301


class PickTests(unittest.TestCase):
    """The selector picks the partition.resource entry with that index."""
    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.image = load(Path(tmp.name) / 'handler.hunk')

    def pick(self, selector, entries):
        """entries: (index, dostype, present, unit, start). Returns FirstBlock or None."""
        h = Handler(self.image)
        try:
            return self._pick(h, selector, entries)
        finally:
            h.close()

    def _pick(self, h, selector, entries):
        h.set('ExecBase', 0x70000)
        h.trap(0x70000 + C['OpenResource'], lambda: h.result(RES))
        h.trap(0x70000 + C['Forbid'], lambda: None)
        h.trap(0x70000 + C['Permit'], lambda: None)
        h.mem.w_block(DEVICE, b'compactflash.device\0')
        h.set('DevName', DEVICE)
        h.set('UnitNumber', 0)
        h.set('PartitionSelector', selector, 1)
        h.set('FirstBlock', 0xdead)
        h.mem.w16(RES + 18, 98)
        h.mem.w16(RES + C['PRES_Layout'], 5)
        head, tail = RES + C['PRES_PartList'], RES + C['PRES_PartList'] + 4
        nodes = [ENTRIES + i * 0x100 for i in range(len(entries))]
        h.mem.w32(head, nodes[0] if nodes else tail)
        h.mem.w32(tail, 0)
        for node, succ, (index, dostype, present, unit, start) in zip(
                nodes, nodes[1:] + [tail], entries):
            h.mem.w_block(node, bytes(0x100))
            h.mem.w32(node, succ)
            h.mem.w32(node + C['PENT_Device'], DEVICE)
            h.mem.w32(node + C['PENT_Unit'], unit)
            h.mem.w32(node + C['PENT_PartIndex'], index)
            h.mem.w8(node + C['PENT_Flags'], 1 << C['PEB_PRESENT'] if present else 0)
            h.mem.w32(node + C['PENT_StartLBA'], start)
            h.mem.w32(node + C['PENT_BlockCount'], 100)
            h.mem.w32(node + C['PENT_DosType'], dostype)
        found = h.run('svp_pick')
        return h.get('FirstBlock') if found else None

    # primary FAT, primary non-FAT, then the first MBR logical at index 4
    CARD = [(0, FAT, 1, 0, 1000), (1, DOS, 1, 0, 2000), (4, FAT, 1, 0, 5000)]

    def test_selector_is_index_plus_one(self):
        """CF<n> and FAT\\<n+1> both reach pe_PartIndex n."""
        for selector, want in ((1, 1000), (5, 5000), (2, None), (3, None), (6, None)):
            with self.subTest(selector=selector):
                self.assertEqual(self.pick(selector, self.CARD), want)

    def test_selector_zero_takes_the_lowest_index(self):
        """FAT\\0 on partitioned media falls back to the lowest FAT index."""
        self.assertEqual(self.pick(0, list(reversed(self.CARD))), 1000)
        self.assertEqual(self.pick(0, self.CARD[1:]), 5000)

    def test_absent_and_other_unit_entries_are_skipped(self):
        """A removed card's entry or another unit's never answers the index."""
        self.assertIsNone(self.pick(5, [(4, FAT, 0, 0, 5000)]))
        self.assertIsNone(self.pick(5, [(4, FAT, 1, 1, 5000)]))
        self.assertEqual(self.pick(5, [(4, FAT, 0, 0, 7), (4, FAT, 1, 0, 5000)]), 5000)


class RegistrationTests(unittest.TestCase):
    """A ROM-resident fat95 registers one FileSysEntry per DosType it serves."""
    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.image = load(Path(tmp.name) / 'handler.hunk')

    def test_init_registers_fat0_to_fat12_and_the_device_scheme(self):
        """FAT\\0..FAT\\12 cover partition indexes 0..11, then 0x464154FF."""
        h = Handler(self.image)
        self.addCleanup(h.close)
        seen = []
        h.stub('RegisterFS', lambda: (seen.append(h.cpu.r_reg(0)), h.result(0)))
        h.run('InitCode')
        self.assertEqual(seen, [0x46415400 | n for n in range(13)] + [0x464154ff])
