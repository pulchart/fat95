#!/usr/bin/env python3
"""tools/parse_debug95.py reads debug95 dumps with the layout of src/fat95_vars.i.

Status: library, collected by unittest like any other test file.
Run: make test
"""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from toolchain import ROOT, VASM

sys.path.insert(0, str(ROOT / "tools"))
import parse_debug95 as pd


def layout_with(old, new):
    """A layout from fat95_vars.i with one text replaced, in a temporary file."""
    text = pd.VARS.read_text()
    assert old in text, old
    temp = tempfile.TemporaryDirectory()
    path = Path(temp.name) / "fat95_vars.i"
    path.write_text(text.replace(old, new))
    layout = pd.Layout(path)
    temp.cleanup()
    return layout


class Layout(unittest.TestCase):
    """The layout parser against the assembler and its own checks."""

    def test_layout_is_clean(self):
        """src/fat95_vars.i and the field accesses of src/fat95.s pass the check that make runs before it assembles the handler."""
        layout = pd.Layout(pd.VARS)
        layout.check_source(ROOT / "src/fat95.s")
        self.assertEqual(layout.errors, [])

    def test_offsets_match_the_assembler(self):
        """Each field offset and VarsSizeof the parser reads equals the value vasm assembles from the same file."""
        layout = pd.Layout(pd.VARS)
        names = [*layout.fields, pd.END]
        lines = ["%s = %d" % kv for kv in pd.DOSENVEC.items()]
        lines += ['\tinclude "%s"' % pd.VARS] + ["\tdc.l\t%s" % n for n in names]
        with tempfile.TemporaryDirectory() as d:
            src, out = Path(d) / "vars.s", Path(d) / "vars.bin"
            src.write_text("\n".join(lines) + "\n")
            subprocess.run([str(VASM), "-quiet", "-Fbin", "-o", str(out), str(src)], check=True)
            data = out.read_bytes()
        got = [int.from_bytes(data[i * 4 : i * 4 + 4], "big") for i in range(len(names))]
        want = [f.offset for f in layout.fields.values()] + [layout.total]
        self.assertEqual(dict(zip(names, got, strict=True)), dict(zip(names, want, strict=True)))

    def test_check_finds_an_overlap(self):
        """A field whose .l size runs into the next field fails the check."""
        layout = layout_with("ReadCmd\t\t=  72", "ReadCmd\t\t=  72\t\t;.l\nReadX\t\t=  74")
        self.assertTrue(any("overlaps" in e for e in layout.errors), layout.errors)

    def test_check_finds_a_field_out_of_order(self):
        """An offset below the one of the field above fails the check."""
        layout = layout_with("TimeRequest\t=  48", "TimeRequest\t=  38")
        self.assertTrue(any("does not come after" in e for e in layout.errors), layout.errors)

    def test_check_finds_a_wide_access(self):
        """A longword access to a word field fails the check unless the field comment lists .l too."""
        layout = layout_with("ReadCmd\t\t=  72\t\t;.w .l,", "ReadCmd\t\t=  72\t\t;")
        layout.check_source(ROOT / "src/fat95.s")
        self.assertTrue(any("access at ReadCmd" in e for e in layout.errors), layout.errors)

    def test_check_finds_a_bad_summary_line(self):
        """A summary line with an unknown format or field fails the check."""
        layout = layout_with("= UnitNumber", "= UnitNum")
        self.assertTrue(any("unknown field UnitNum" in e for e in layout.errors), layout.errors)
        layout = layout_with(";@show dec\tDevice", ";@show decimal\tDevice")
        self.assertTrue(any("unknown format decimal" in e for e in layout.errors), layout.errors)


class Summary(unittest.TestCase):
    """The summary decodes the values of a dump."""

    def test_summary_decodes_a_dump(self):
        """Type, name, sizes, flags and error codes of a dump show as text."""
        layout = pd.Layout(pd.VARS)
        data = bytearray(layout.alloc)

        def put(name, value):
            f = layout.fields[name]
            data[f.offset : f.offset + f.size] = value.to_bytes(f.size, "big", signed=value < 0)

        put("DebugSize", layout.alloc)
        put("DebugVersion", 0x0403)
        put("BlockSize", 512)
        put("TotalBlocks", 2 * 1024 * 1024)
        put("ClusterSize", 4096)
        put("FreeClusters", 1024)
        put("FATType", -1)
        put("CmdFlags", 0x0002)
        put("ErrorNum", 226)
        f = layout.fields["LastVolName"]
        data[f.offset : f.offset + 5] = b"CARD\0"
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "cf0.dump"
            path.write_bytes(data)
            dump = pd.Dump(path, layout)
            shown = {s.label: dump.show(s) for s in layout.shows}
        self.assertEqual(dump.warnings(), [])
        self.assertEqual(shown["type"], ["FAT32"])
        self.assertEqual(shown["name"], ['"CARD"'])
        self.assertEqual(shown["size"], ["1 GiB"])
        self.assertEqual(shown["free"], ["4 MiB"])
        self.assertEqual(shown["features"], ["TD64 commands available"])
        self.assertEqual(shown["last DOS error"], ["226 no disk"])

    def test_other_build_is_named(self):
        """A dump whose size differs from the layout warns that it needs the layout of its own build."""
        layout = pd.Layout(pd.VARS)
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "old.dump"
            path.write_bytes((912).to_bytes(4, "big") + bytes(908))
            warnings = pd.Dump(path, layout).warnings()
        self.assertTrue(any("--vars" in w for w in warnings), warnings)


if __name__ == "__main__":
    unittest.main()
