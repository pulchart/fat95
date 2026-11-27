#!/usr/bin/env python3
"""Show the state of a fat95 handler from a debug95 dump.

On the Amiga, debug95 writes the handler globals of a mounted volume to a
file:

    debug95 CF0: RAM:cf0.dump

This tool reads that file with the layout of src/fat95_vars.i:

    parse_debug95.py cf0.dump               summary
    parse_debug95.py --all cf0.dump         every field
    parse_debug95.py --diff a.dump b.dump   fields that differ
    parse_debug95.py --check                check the layout only

A dump of another fat95 build needs the layout of that build, given with
--vars as its fat95_vars.i, or as its fat95.s for releases before the file
existed.

The summary comes from the lines ;@show <format> <group> <label> = <field or
expression> at the end of fat95_vars.i, its groups in the order they first
appear. The formats are dec, hex, yesno, text, id (a DOS ID such as FAT\\1),
bytes, doserr, ioerr, enum (value = name pairs in the field comment) and flags
(a ;<field> block of ;$<bit> lines).
"""

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VARS = ROOT / "src/fat95_vars.i"

# struct DosEnvec offsets used by the layout (dos/filehandler.h)
DOSENVEC = {"DE_NumBuffers": 44, "DE_BufMemType": 48, "DE_DosType": 64}

# dos/dos.h
DOS_ERRORS = {
    103: "no free store", 105: "task table full", 114: "bad template",
    115: "bad number", 116: "required arg missing", 117: "key needs arg",
    118: "too many args", 119: "unmatched quotes", 120: "line too long",
    121: "file not object", 122: "invalid resident library",
    201: "no default dir", 202: "object in use", 203: "object exists",
    204: "dir not found", 205: "object not found", 206: "bad stream name",
    207: "object too large", 209: "action not known",
    210: "invalid component name", 211: "invalid lock",
    212: "object wrong type", 213: "disk not validated",
    214: "disk write protected", 215: "rename across devices",
    216: "directory not empty", 217: "too many levels",
    218: "device not mounted", 219: "seek error", 220: "comment too big",
    221: "disk full", 222: "delete protected", 223: "write protected",
    224: "read protected", 225: "not a DOS disk", 226: "no disk",
    232: "no more entries", 233: "is soft link", 234: "object linked",
    235: "bad hunk", 236: "not implemented", 240: "record not locked",
    241: "lock collision", 242: "lock timeout", 243: "unlock error",
}  # fmt: skip

# exec/errors.h and devices/trackdisk.h
IO_ERRORS = {
    -1: "open fail", -2: "aborted", -3: "no command", -4: "bad length",
    -5: "bad address", -6: "unit busy", -7: "self test",
    20: "not specified", 21: "no sector header", 22: "bad sector preamble",
    23: "bad sector ID", 24: "bad header sum", 25: "bad sector sum",
    26: "too few sectors", 27: "bad sector header", 28: "write protected",
    29: "disk changed", 30: "seek error", 31: "no memory",
    32: "bad unit number", 33: "bad drive type", 34: "drive in use",
    35: "post reset",
}  # fmt: skip

FORMATS = {"dec", "hex", "yesno", "text", "id", "bytes", "doserr", "ioerr", "enum", "flags"}
SIZES = {"b": 1, "w": 2, "l": 4}
END = "VarsSizeof"

ASSIGN = re.compile(r"^(\w+)\s*=\s*([^;]*?)\s*(?:;(.*))?$")
SHOW = re.compile(r"^;@show\s+(\w+)\s+(\w+)\s+(.+?)\s*=\s*(.+)$")
BIT = re.compile(r"^;\$([0-9a-fA-F]+)\s+(.*)$")
ACCESS = re.compile(r"^\s+(?:\w+\.([bwl])|ZCLR([BWL]))\s+(.*)$")
PAIR = re.compile(r"(-?\d+)\s*=\s*([^,]+)")

EXPR = re.compile(r"[\w\s+*/()-]+")


def evaluate(expr, env):
    """An integer expression of names, numbers and + - * / ( ); env maps the names."""
    text = re.sub(r"\$([0-9a-fA-F]+)", r"0x\1", expr)
    if not EXPR.fullmatch(text):
        raise ValueError("unsupported expression %r" % expr)
    try:
        return int(eval(text.replace("/", "//"), {"__builtins__": {}}, env))
    except NameError as e:
        raise KeyError("unknown name %s" % e.name) from None
    except SyntaxError, TypeError:
        raise ValueError("unsupported expression %r" % expr) from None


def names_in(expr):
    return re.findall(r"[A-Za-z_]\w*", re.sub(r"\$[0-9a-fA-F]+", "", expr))


@dataclass
class Field:
    name: str
    offset: int
    size: int
    line: int
    comment: str = ""
    parent: str = ""
    pairs: dict = field(default_factory=dict)
    bits: list = field(default_factory=list)
    widths: set = field(default_factory=set)  # wider accesses the comment allows


@dataclass
class Show:
    fmt: str
    group: str
    label: str
    expr: str
    line: int


class Layout:
    """The fields of fat95_vars.i (or of the globals block of a fat95.s)."""

    def __init__(self, path):
        self.path = Path(path)
        self.fields = {}
        self.shows = []
        self.errors = []
        self.total = 0
        self._parse(self._lines())

    @property
    def alloc(self):
        """Bytes the handler allocates, and debug95 dumps."""
        return (self.total + 15) & ~15

    def error(self, line, text):
        self.errors.append("%s:%d: %s" % (self.path, line, text))

    def _lines(self):
        lines = list(enumerate(self.path.read_text(encoding="latin-1").splitlines(), 1))
        if self.path.suffix != ".s":
            return lines
        # a whole fat95.s: the globals block only
        first = next((i for i, (_, s) in enumerate(lines) if s.startswith("DebugSize")), None)
        last = next((i for i, (_, s) in enumerate(lines) if s.startswith(END)), None)
        if first is None or last is None:
            raise SystemExit("%s has no DebugSize .. %s block" % (self.path, END))
        return lines[first : last + 1]

    def _parse(self, lines):
        top = []  # (name, offset, explicit size, line, comment) in file order
        members = []
        current = None  # field whose comment continues
        bits_of = None  # field name of an open ;<field> block
        bits = {}
        for no, raw in lines:
            if not raw.isascii():
                self.error(no, "non-ASCII text")
            s = raw.strip()
            if not s:
                current = bits_of = None
                continue
            if s.startswith(";@show"):
                m = SHOW.match(s)
                if not m:
                    self.error(no, "expected ;@show <format> <group> <label> = <expression>")
                else:
                    self.shows.append(Show(*m.groups(), no))
                continue
            if raw.startswith(";"):
                m = BIT.match(raw)
                if bits_of and m:
                    bits[bits_of].append([int(m[1], 16), m[2].strip()])
                elif bits_of and bits[bits_of] and re.match(r"^;\s", raw):
                    bits[bits_of][-1][1] += " " + s[1:].strip()
                else:
                    name = s[1:].strip()
                    bits_of = name if re.fullmatch(r"\w+", name) else None
                    if bits_of:
                        bits[bits_of] = []
                current = None
                continue
            if s.startswith(";"):  # indented: the comment of the field above goes on
                if current:
                    current[4] += " " + s[1:].strip()
                continue
            m = ASSIGN.match(raw)
            if not m:
                self.error(no, "expected <name> = <offset>")
                continue
            name, expr, comment = m[1], m[2], (m[3] or "").strip()
            bits_of = None
            if name in self.fields or any(t[0] == name for t in top + members):
                self.error(no, "%s is defined twice" % name)
                continue
            size = re.match(r"^\.([bwl])\b", comment)
            entry = [name, expr, SIZES[size[1]] if size else None, no, comment]
            current = entry
            if name == END:
                try:
                    self.total = evaluate(expr, {})
                except (KeyError, ValueError) as e:
                    self.error(no, str(e))
                continue
            (members if names_in(expr) else top).append(entry)

        self._place(top, members)
        for name, table in bits.items():
            if name in self.fields:
                self.fields[name].bits = [tuple(b) for b in table]
        self._check_shows()

    def _place(self, top, members):
        if not self.total:
            self.error(1, "no %s line" % END)
        prev = None
        for i, (name, expr, size, no, comment) in enumerate(top):
            try:
                offset = evaluate(expr, {})
            except (KeyError, ValueError) as e:
                self.error(no, str(e))
                continue
            if prev is not None and offset <= prev[1]:
                self.error(no, "%s at %d does not come after %s at %d" % (name, offset, *prev))
                continue
            nxt = next((evaluate(t[1], {}) for t in top[i + 1 :]), self.total)
            gap = nxt - offset
            if size and size > gap:
                self.error(
                    no, "%s (%d bytes at %d) overlaps the field at %d" % (name, size, offset, nxt)
                )
            if offset + (size or gap) > self.total:
                self.error(no, "%s ends beyond %s (%d)" % (name, END, self.total))
            self.fields[name] = Field(name, offset, size or max(gap, 0), no, comment)
            prev = (name, offset)

        offsets = DOSENVEC | {n: f.offset for n, f in self.fields.items()}
        for name, expr, size, no, comment in members:
            try:
                offset = evaluate(expr, offsets)
            except (KeyError, ValueError) as e:
                self.error(no, str(e))
                continue
            parent = next((n for n in names_in(expr) if n in self.fields), "")
            f = Field(name, offset, size or 4, no, comment, parent)
            if parent:
                p = self.fields[parent]
                if not (p.offset <= offset and offset + f.size <= p.offset + p.size):
                    self.error(no, "%s lies outside %s" % (name, parent))
            self.fields[name] = f
        for f in self.fields.values():
            f.pairs = {int(v): t.strip() for v, t in PAIR.findall(f.comment)}
            listed = re.match(r"^((?:\.[bwl]\s+)*\.[bwl])\b", f.comment)
            f.widths = {SIZES[w] for w in re.findall(r"\.([bwl])", listed[1])} if listed else set()
        if "DebugSize" in self.fields and self.fields["DebugSize"].offset != 0:
            self.error(self.fields["DebugSize"].line, "debug95 reads DebugSize at offset 0")
        if "DebugVersion" in self.fields and self.fields["DebugVersion"].offset != 4:
            self.error(self.fields["DebugVersion"].line, "DebugVersion belongs at offset 4")
        self.fields = dict(
            sorted(self.fields.items(), key=lambda kv: (kv[1].offset, bool(kv[1].parent)))
        )

    def check_source(self, path):
        """Accesses in a source that read or write past their field."""
        path = Path(path)
        for no, raw in enumerate(path.read_text(encoding="latin-1").splitlines(), 1):
            m = ACCESS.match(raw.split(";")[0])
            if not m:
                continue
            width = SIZES[(m[1] or m[2]).lower()]
            for a in re.finditer(r"\b([A-Za-z_]\w*)(?:\+(\d+))?\(a4\)", m[3]):
                f = self.fields.get(a[1])
                start = int(a[2] or 0)
                if f and start + width > f.size and width not in f.widths:
                    self.errors.append(
                        "%s:%d: %d-byte access at %s+%d, the field has %d bytes"
                        % (path, no, width, f.name, start, f.size)
                    )

    def _check_shows(self):
        for s in self.shows:
            if s.fmt not in FORMATS:
                self.error(s.line, "unknown format %s" % s.fmt)
            missing = [n for n in names_in(s.expr) if n not in self.fields]
            if missing:
                self.error(s.line, "unknown field %s" % ", ".join(missing))
                continue
            try:
                evaluate(s.expr, dict.fromkeys(self.fields, 1))
            except ValueError as e:
                self.error(s.line, str(e))
                continue
            single = self.fields.get(s.expr)
            if s.fmt in ("text", "enum", "flags", "id") and not single:
                self.error(s.line, "%s needs a single field" % s.fmt)
            elif s.fmt == "enum" and not single.pairs:
                self.error(s.line, "%s has no value = name pairs in its comment" % s.expr)
            elif s.fmt == "flags" and not single.bits:
                self.error(s.line, "%s has no ;%s block of ;$<bit> lines" % (s.expr, s.expr))


class Dump:
    """A debug95 file read with a layout."""

    def __init__(self, path, layout):
        self.path = Path(path)
        self.layout = layout
        self.data = self.path.read_bytes()
        if len(self.data) < 8:
            raise SystemExit("%s: %d bytes, not a debug95 dump" % (self.path, len(self.data)))
        self.size = int.from_bytes(self.data[0:4], "big")
        v = int.from_bytes(self.data[4:6], "big")
        self.version = "%d.%d" % (v >> 8, v & 0xFF)

    def warnings(self):
        out = []
        if self.size != len(self.data):
            out.append(
                "%s holds %d bytes, its header says %d" % (self.path, len(self.data), self.size)
            )
        if self.size != self.layout.alloc:
            out.append(
                "%s comes from a fat95 build with %d bytes of globals, %s describes %d. "
                "Pass the layout of that build with --vars."
                % (self.path, self.size, self.layout.path, self.layout.alloc)
            )
        return out

    def raw(self, f):
        b = self.data[f.offset : f.offset + f.size]
        return b if len(b) == f.size else None

    def number(self, f, signed=False):
        b = self.raw(f)
        if b is None or f.size not in (1, 2, 4):
            return None
        return int.from_bytes(b, "big", signed=signed)

    def expr(self, text):
        """The value of an expression over the fields, None past the end of the dump."""
        values = {n: self.number(f) for n, f in self.layout.fields.items()}
        if any(values[n] is None for n in names_in(text)):
            return None
        return evaluate(text, values)

    def show(self, s):
        """The text of one summary entry, a list of lines."""
        f = self.layout.fields.get(s.expr)
        if f and s.fmt == "text":
            b = self.raw(f)
            return ['"%s"' % b.split(b"\0")[0].decode("latin-1")] if b is not None else ["n/a"]
        signed = s.fmt in ("enum", "id", "ioerr")
        v = self.number(f, signed) if f else self.expr(s.expr)
        if v is None:
            return ["n/a"]
        return render(s.fmt, v, f)


def size_text(n):
    if n < 1024:
        return "%d bytes" % n
    for unit in ("KiB", "MiB", "GiB", "TiB"):
        n /= 1024
        if n < 1024 or unit == "TiB":
            return ("%.1f" % n).rstrip("0").rstrip(".") + " " + unit
    return None


def id_text(v):
    """A DOS ID as three letters and the last byte, FAT\\1 or DOS."""
    b = (v & 0xFFFFFFFF).to_bytes(4, "big")
    if not all(32 <= c < 127 for c in b[:3]):
        return "0x%08X" % (v & 0xFFFFFFFF)
    last = b[3]
    return b[:3].decode() + (chr(last) if 32 <= last < 127 else "\\%d" % last if last else "")


def render(fmt, v, f=None):
    """Lines for value v of field f in a format."""
    if fmt == "dec":
        return [str(v)]
    if fmt == "hex":
        return ["0x%0*X" % (2 * (f.size if f else 4), v)]
    if fmt == "yesno":
        return ["yes" if v else "no"]
    if fmt == "bytes":
        return [size_text(v)]
    if fmt == "doserr":
        return ["none"] if v == 0 else ["%d %s" % (v, DOS_ERRORS.get(v, "unknown error"))]
    if fmt == "ioerr":
        return ["none"] if v == 0 else ["%d %s" % (v, IO_ERRORS.get(v, "unknown error"))]
    if fmt == "enum":
        return [f.pairs.get(v, str(v))]
    if fmt == "id":
        return [f.pairs.get(v) or id_text(v)]
    if fmt == "flags":
        names = [t for bit, t in f.bits if v & bit]
        rest = v & ~sum(bit for bit, _ in f.bits)
        if rest:
            names.append("unknown bits 0x%X" % rest)
        return names or ["none"]
    return [str(v)]


def field_value(dump, f):
    """One field for --all and --diff."""
    if f.size not in (1, 2, 4):
        b = dump.raw(f)
        if b is None:
            return "n/a"
        head = " ".join("%02X" % c for c in b[:16])
        return head + (" ..." if len(b) > 16 else "")
    v = dump.number(f)
    if v is None:
        return "n/a"
    text = "0x%0*X" % (2 * f.size, v) + (" (%d)" % v if v > 9 else "")
    if f.bits:
        return text + " " + ", ".join(render("flags", v, f))
    name = f.pairs.get(dump.number(f, signed=True))
    return text + " " + name if name else text


def header(dump):
    return "fat95 %s handler state, %s (%d bytes)" % (dump.version, dump.path.name, len(dump.data))


def summary_lines(dump):
    lay = dump.layout
    out = [header(dump)]
    if not lay.shows:
        return [*out, "%s has no ;@show lines, see --all" % lay.path]
    groups = list(dict.fromkeys(s.group for s in lay.shows))
    gw = max(len(g) for g in groups)
    lw = max(len(s.label) for s in lay.shows)
    for g in groups:
        out.append("")
        name = g
        for s in (s for s in lay.shows if s.group == g):
            for i, text in enumerate(dump.show(s)):
                out.append("%-*s  %-*s  %s" % (gw, name, lw, s.label if i == 0 else "", text))
                name = ""
    return out


def print_all(dump):
    print(header(dump))
    nw = max(len(n) for n in dump.layout.fields)
    for f in dump.layout.fields.values():
        name = ("  " + f.name) if f.parent else f.name
        print(
            (
                "%4d %4d  %-*s  %-23s %s"
                % (f.offset, f.size, nw + 2, name, field_value(dump, f), f.comment)
            ).rstrip()
        )


def print_diff(a, b):
    nw = max(len(n) for n in a.layout.fields)
    same = True
    for f in a.layout.fields.values():
        ra, rb = a.raw(f), b.raw(f)
        if ra == rb:
            continue
        same = False
        if f.size in (1, 2, 4) or ra is None or rb is None:
            change = "%s -> %s" % (field_value(a, f), field_value(b, f))
        else:  # a buffer: where it starts to differ
            at = [i for i in range(f.size) if ra[i] != rb[i]]
            part = slice(at[0], at[0] + 8)
            change = "%d bytes differ, from +%d %s -> %s" % (
                len(at),
                at[0],
                ra[part].hex(" ").upper(),
                rb[part].hex(" ").upper(),
            )
        print("%4d  %-*s  %s" % (f.offset, nw, f.name, change))
    if same:
        print("no field differs")


def main():
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        epilog="On the Amiga: debug95 <volume> <file>, for example debug95 CF0: RAM:cf0.dump",
    )
    ap.add_argument("dump", nargs="*", type=Path, help="debug95 output file")
    ap.add_argument(
        "--vars",
        type=Path,
        default=VARS,
        help="layout: fat95_vars.i or fat95.s (default %(default)s)",
    )
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument(
        "--all", action="store_true", help="every field with offset, size and comment"
    )
    mode.add_argument("--diff", action="store_true", help="fields that differ between two dumps")
    mode.add_argument("--check", action="store_true", help="check the layout and exit")
    ap.add_argument(
        "--source",
        type=Path,
        help="with --check: also check the field accesses of this source, such as src/fat95.s",
    )
    a = ap.parse_args()

    if not a.vars.exists():
        ap.error("no layout %s" % a.vars)
    layout = Layout(a.vars)
    if a.check:
        if a.source:
            layout.check_source(a.source)
        for e in layout.errors:
            print(e, file=sys.stderr)
        return 1 if layout.errors else 0
    if layout.errors:
        print(
            "%s has %d layout errors, see --check" % (layout.path, len(layout.errors)),
            file=sys.stderr,
        )
    if not layout.shows and a.vars.resolve() != VARS and VARS.exists():
        # an older layout: the summary of this one, for the fields it has
        layout.shows = [
            s for s in Layout(VARS).shows if all(n in layout.fields for n in names_in(s.expr))
        ]
    if len(a.dump) != (2 if a.diff else 1):
        ap.error("--diff takes two dumps" if a.diff else "give one dump")
    dumps = []
    for p in a.dump:
        if not p.exists():
            ap.error("no file %s" % p)
        d = Dump(p, layout)
        for w in d.warnings():
            print("warning: " + w, file=sys.stderr)
        dumps.append(d)
    if a.diff:
        print_diff(*dumps)
    elif a.all:
        print_all(dumps[0])
    else:
        print("\n".join(summary_lines(dumps[0])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
