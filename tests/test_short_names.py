"""8.3 names: Amiga characters from $A0 through the [oem] table, 64 entries as before or 96 with $E0..$FF.

Run: make test"""

import tempfile
import unittest
from pathlib import Path

from harness import Handler, load

CHUNK, NAME, OUT = 0x60000, 0x61000, 0x61100


def table64():
    """A 64-entry table: $A0..$DF onto distinct bytes from $80."""
    return bytes(0x80 + i for i in range(64))


def table96():
    """The same plus $E0..$FF: $E0..$FE as $C0..$DE, $FF onto $FF of its own."""
    return table64() + table64()[32:63] + b"\xff"


class ShortNames(unittest.TestCase):
    """MakeShortName, Char2MS and StrPc2Amiga against the table built by InvertCodePage."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.image = load(Path(cls.temp.name) / "handler.hunk")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.h = Handler(self.image)
        self.addCleanup(self.h.close)
        self.h.exec_memory()
        self.h.set("CodePage", 0)

    def load_table(self, data):
        """Put an oem chunk in memory and let InvertCodePage build the tables from it."""
        h = self.h
        h.mem.w_block(CHUNK, b"oem " + len(data).to_bytes(4, "big") + data)
        h.set("OemPage", CHUNK + 8)
        h.run("InvertCodePage")

    def short(self, name):
        self.h.mem.w_block(NAME, name + b"\0")
        self.assertEqual(self.h.run("MakeShortName", a0=NAME, a1=OUT), 0, name)
        return bytes(self.h.mem.r_block(OUT, 11))

    def test_64_entries_fold_the_upper_range(self):
        """With 64 entries $E0..$FF take the entry $20 below, as before the table grew."""
        self.load_table(table64())
        self.assertEqual(self.short(b"\xe9.txt"), bytes([0x80 + 0xC9 - 0xA0]) + b"       TXT")
        self.assertEqual(self.short(b"\xff.txt"), bytes([0x80 + 0xDF - 0xA0]) + b"       TXT")

    def test_96_entries_map_the_upper_range(self):
        """With 96 entries $E0..$FF have their own entries: $FF no longer lands on the entry of $DF."""
        self.load_table(table96())
        self.assertEqual(self.short(b"\xe9.txt"), bytes([0x80 + 0xC9 - 0xA0]) + b"       TXT")
        self.assertEqual(self.short(b"\xff.txt"), b"\xff       TXT")

    def test_no_table_keeps_the_char(self):
        """Without a table a char from $A0 stays, $E0..$FF in upper case."""
        self.h.set("OemPage", 0)
        self.assertEqual(self.short(b"\xe9.txt"), b"\xc9       TXT")
        self.assertEqual(self.short(b"\xa9.txt"), b"\xa9       TXT")

    def test_char2ms(self):
        """Char2MS maps through the table, and without one gives the upper case Amiga char instead of the char minus $A0."""
        self.load_table(table96())
        self.assertEqual(self.h.run("Char2MS", d0=0xFF) & 0xFF, 0xFF)
        self.assertEqual(self.h.run("Char2MS", d0=0xE9) & 0xFF, 0x80 + 0xC9 - 0xA0)
        self.h.set("OemPage", 0)
        self.assertEqual(self.h.run("Char2MS", d0=0xE9) & 0xFF, 0xC9)

    def test_inverse_takes_the_lowest_char(self):
        """StrPc2Amiga turns an OEM byte back into the lowest Amiga char that maps to it, the upper case one."""
        self.load_table(table96())
        self.h.mem.w_block(NAME, bytes([0x80 + 0xC9 - 0xA0, 0xFF, 0x41, 0]))
        self.h.run("StrPc2Amiga", a0=NAME)
        self.assertEqual(bytes(self.h.mem.r_block(NAME, 3)), b"\xc9\xffA")


if __name__ == "__main__":
    unittest.main()
