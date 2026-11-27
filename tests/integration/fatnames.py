"""Long names for the names scenario: writes VFAT long names into the root
directory of a FAT16 volume and reads them back, with the escapes fat95
shows for characters outside its code page."""

import struct

B32 = "0123456789ABCDEFGHIJKLMNOPQRSTUV"

# long name, contents; mtools writes the data under a short alias first
FILES = [
    ("aĀ.txt", b"a with macron\n"),
    ("a880.txt", b"plain a880\n"),
    ("r中.txt", b"renamed later\n"),
    ("c\U0001f600.txt", b"emoji\n"),
    ("p^880.txt", b"caret in the name\n"),
    ("příliš.txt", b"czech\n"),
]


def escape(cp, esc="^"):
    """The escape fat95 shows for a code point of 0x80 or more."""
    if cp < 0x800:
        return esc + B32[8 | cp >> 10] + B32[cp >> 5 & 31] + B32[cp & 31]
    if cp < 0x10000:
        return esc + B32[12 | cp >> 14] + B32[cp >> 9 & 31] + B32[cp >> 4 & 31] + B32[cp << 1 & 31]
    return esc + "".join(
        B32[x] for x in (16 | cp >> 19, cp >> 14 & 31, cp >> 9 & 31, cp >> 4 & 31, cp << 1 & 31)
    )


def shown(name, esc="^", table=None):
    """A long name as fat95 lists it, as a str of Amiga characters: a character
    of the code page (table, Latin-1 without one) as itself, the rest as
    escapes, an escape character as two where it would read as one."""
    text = ""
    for ch in reversed(name):
        cp = ord(ch)
        if ch == esc:
            piece = esc * 2 if text.startswith(esc) or reads_as_escape(text[:6]) else esc
        elif cp < 0x80 or (table is None and cp < 0x100):
            piece = ch
        elif table is not None and cp in table:
            piece = chr(table[cp])
        else:
            piece = escape(cp, esc)
        text = piece + text
    return text


def reads_as_escape(text):
    """Whether text starts with the digits of an escape."""
    if not text or text[0].upper() not in B32:
        return False
    size = B32.index(text[0].upper()) >> 2
    return (
        2 <= size <= 4 and len(text) >= size + 1 and all(c.upper() in B32 for c in text[: size + 1])
    )


class Fat16:
    """The root directory and the data of a FAT16 volume at offset in path."""

    def __init__(self, path, offset=0):
        self.path, self.offset = path, offset
        with open(path, "rb") as f:
            f.seek(offset)
            bs = f.read(512)
        self.bps, self.spc, res, nfats, self.rootents, _, _, fatsz = struct.unpack_from(
            "<HBHBHHBH", bs, 11
        )
        self.fat = offset + res * self.bps
        self.root = self.fat + nfats * fatsz * self.bps
        self.data = self.root + self.rootents * 32

    def _root(self):
        with open(self.path, "rb") as f:
            f.seek(self.root)
            return bytearray(f.read(self.rootents * 32))

    def entries(self):
        """(long name or short name, short entry bytes) of every live object in the root."""
        out, parts = [], []
        raw = self._root()
        for i in range(0, len(raw), 32):
            e = raw[i : i + 32]
            if e[0] == 0:
                break
            if e[0] == 0xE5:
                parts = []
                continue
            if e[11] == 0x0F:
                units = (
                    struct.unpack_from("<5H", e, 1)
                    + struct.unpack_from("<6H", e, 14)
                    + struct.unpack_from("<2H", e, 28)
                )
                parts.insert(0, units)
                continue
            if e[11] & 0x08:  # volume label
                parts = []
                continue
            if parts:
                units = [u for p in parts for u in p]
                units = units[: units.index(0)] if 0 in units else units
                name = struct.pack("<%dH" % len(units), *units).decode("utf-16-le")
            else:
                base, ext = e[:8].decode("latin-1").rstrip(), e[8:11].decode("latin-1").rstrip()
                base = base.lower() if e[12] & 0x08 else base
                ext = ext.lower() if e[12] & 0x10 else ext
                name = base + ("." + ext if ext else "")
            out.append((name, bytes(e)))
            parts = []
        return out

    def read(self, entry):
        """The contents of the file a short entry describes."""
        cluster, size = (
            struct.unpack_from("<H", entry, 26)[0],
            struct.unpack_from("<I", entry, 28)[0],
        )
        out = b""
        with open(self.path, "rb") as f:
            while 2 <= cluster < 0xFFF8 and len(out) < size:
                f.seek(self.data + (cluster - 2) * self.spc * self.bps)
                out += f.read(self.spc * self.bps)
                f.seek(self.fat + cluster * 2)
                cluster = struct.unpack("<H", f.read(2))[0]
        return out[:size]

    def files(self):
        """{name: contents} of the files in the root."""
        return {name: self.read(e) for name, e in self.entries() if not e[11] & 0x10}

    def add_long_names(self, names):
        """Put a long name in front of each short entry of names ({short name: long name})."""
        raw = self._root()
        new = bytearray()
        for i in range(0, len(raw), 32):
            e = raw[i : i + 32]
            if e[0] == 0:
                break
            short = e[:11].decode("latin-1")
            if short in names:
                new += lfn_entries(names[short], bytes(e[:11]))
            new += e
        if len(new) > len(raw):
            raise ValueError("root directory full")
        new += bytes(len(raw) - len(new))
        with open(self.path, "r+b") as f:
            f.seek(self.root)
            f.write(new)


def lfn_entries(name, short11):
    """The VFAT entries of a long name for the short entry short11, last part first."""
    units = list(
        struct.unpack("<%dH" % (len(name.encode("utf-16-le")) // 2), name.encode("utf-16-le"))
    )
    if len(units) % 13:
        units.append(0)
    units += [0xFFFF] * (-len(units) % 13)
    check = 0
    for c in short11:
        check = ((check & 1) << 7) + (check >> 1) + c & 0xFF
    count = len(units) // 13
    out = b""
    for n in range(count, 0, -1):
        part = units[(n - 1) * 13 : n * 13]
        out += (
            bytes([n | (0x40 if n == count else 0)])
            + struct.pack("<5H", *part[:5])
            + bytes([0x0F, 0, check])
            + struct.pack("<6H", *part[5:11])
            + b"\0\0"
            + struct.pack("<2H", *part[11:])
        )
    return out


def populate(image, offset):
    """FILES with their long names in the root of the FAT16 volume at offset."""
    import os
    import subprocess
    import tempfile

    env = dict(os.environ, MTOOLS_SKIP_CHECK="1")
    alias = {}
    with tempfile.TemporaryDirectory() as tmp:
        for i, (name, data) in enumerate(FILES, 1):
            src = os.path.join(tmp, "f")
            with open(src, "wb") as f:
                f.write(data)
            subprocess.run(["mcopy", "-i", "%s@@%d" % (image, offset), src, "::F%d.TXT" % i], check=True,
                           capture_output=True, env=env)  # fmt: skip
            alias["F%-7dTXT" % i] = name
    Fat16(image, offset).add_long_names(alias)


def locale_sections(data):
    """The sections of a language file as install95 sees them: no comments,
    texts as written, number pairs as values, each section sorted."""
    out, section = {}, None
    for line in data.split(b"\n"):
        line = line.strip()
        if not line or line.startswith(b";"):
            continue
        if line.startswith(b"["):
            section = line.decode("latin-1").lower()
            out.setdefault(section, [])
            continue
        if b"=" in line:
            key, text = line.split(b"=", 1)
            out[section].append((int(key), text.strip()))
        else:
            out[section].append(tuple(int(x, 0) for x in line.split()))
    return {k: sorted(v) for k, v in out.items()}


def code_page(data):
    """{unicode: Amiga character} of the [unicode] section; others map 1:1."""
    pairs = locale_sections(data).get("[unicode]", [])
    remapped = {a for a, _ in pairs}
    table = {u: a for a, u in pairs}
    for a in range(0x80, 0x100):
        if a not in remapped and a not in table:
            table.setdefault(a, a)
    return table
