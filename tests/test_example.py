#!/usr/bin/env python3
"""The smallest complete test in the suite, kept as the worked example.

tests/README.md points a new contributor here. It is collected and run like any
other test, so it cannot drift from what actually works. Copy it, rename it,
and drive the routine you care about.

Status: library, collected by unittest like any other test file.
Run: make test
"""
import tempfile
import unittest
from pathlib import Path

from harness import Handler, load


class Example(unittest.TestCase):
    """Drives one routine and reads the result out of emulated memory."""

    @classmethod
    def setUpClass(cls):
        # Assemble src/fat95.s once for the whole class: it is the slow part.
        cls.temp = tempfile.TemporaryDirectory()
        cls.image = load(Path(cls.temp.name) / 'fat95.hunk')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        # One Handler per test. Only one machine may be live, so close it.
        self.h = Handler(self.image)
        self.addCleanup(self.h.close)

    def test_ms_date_renders_a_packed_date(self):
        """MSDate2Str writes a packed FAT date as DD.MM.YYYY and leaves a1 past it."""
        target = 0x56000
        packed = (1 << 9) | (3 << 5) | 14          # 1981-03-14, FAT epoch is 1980
        self.h.run('MSDate2Str', d0=packed, a1=target)
        self.assertEqual(bytes(self.h.mem.r_block(target, 10)), b'14.03.1981')
        self.assertEqual(self.h.cpu.r_reg(9), target + 10)


if __name__ == '__main__':
    unittest.main()
