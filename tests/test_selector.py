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
