"""Long names: characters outside the code page as escapes such as ^880 (written here with %, as Control n% sets it), ^^ for a ^ that would read as one; Control -n shows them as _.

Run: make test"""

import random
import tempfile
import unittest
from pathlib import Path

from harness import C, Handler, load

B32 = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
TABLES, ENTRY = 0x60000, 0x62000
UPPER_CACHE = {}


def escape(cp):
    """Reference encoder, the escape for a code point of 0x80 or more."""
    if cp < 0x800:
        return "%" + B32[8 | cp >> 10] + B32[cp >> 5 & 31] + B32[cp & 31]
    if cp < 0x10000:
        return "%" + B32[12 | cp >> 14] + B32[cp >> 9 & 31] + B32[cp >> 4 & 31] + B32[cp << 1 & 31]
    return (
        "%"
        + B32[16 | cp >> 19]
        + B32[cp >> 14 & 31]
        + B32[cp >> 9 & 31]
        + B32[cp >> 4 & 31]
        + B32[cp << 1 & 31]
    )


def unescape(text):
    """Reference decoder: (code point, characters used behind the %) or None."""

    def digit(i):
        if i >= len(text):
            return None
        c = text[i]
        if c in B32:
            return B32.index(c)
        if c in B32.lower():
            return B32.lower().index(c)
        return None

    first = digit(0)
    if first is None or not 2 <= first >> 2 <= 4:
        return None
    size = first >> 2
    shifts = {2: (10, 5, 0), 3: (14, 9, 4), 4: (19, 14, 9, 4)}[size]
    value = (first & 3) << shifts[0]
    for i, shift in enumerate(shifts[1:], 1):
        d = digit(i)
        if d is None:
            return None
        value |= d << shift
    if size > 2:
        d = digit(size)
        if d is None or d & 1:
            return None
        value |= d >> 1
    if (
        value < (0x80, 0x800, 0x10000)[size - 2]
        or 0xD800 <= value < 0xE000
        or value in (0xFFFE, 0xFFFF)
        or value > 0x10FFFF
    ):
        return None
    return value, size + 1


def decode(text):
    """Reference decoder of a whole name: its code points, %% as one %, a % that starts no escape as itself."""
    out, i = [], 0
    while i < len(text):
        if text[i : i + 2] == "%%":
            out.append(0x25)
            i += 2
            continue
        found = unescape(text[i + 1 :]) if text[i] == "%" else None
        if found:
            out.append(found[0])
            i += 1 + found[1]
        else:
            out.append(ord(text[i]))
            i += 1
    return out


def show(cps, local=None):
    """Reference encoder of a whole name: a character of the code page (Latin-1 without one) as itself, any other as its escape, a % as %% where the text behind it starts with % or reads as an escape."""
    text = ""
    for cp in reversed(cps):
        if cp == 0x25:
            piece = "%%" if text.startswith("%") or unescape(text) else "%"
        elif cp < 0x80 or (local is None and cp < 0x100):
            piece = chr(cp)
        elif local is not None and cp in local:
            piece = chr(local[cp])
        else:
            piece = escape(cp)
        text = piece + text
    return text


def utf16(cps):
    """UTF-16 code units of code points."""
    out = []
    for cp in cps:
        if cp < 0x10000:
            out.append(cp)
        else:
            out += [0xD800 | (cp - 0x10000) >> 10, 0xDC00 | (cp - 0x10000) & 0x3FF]
    return out


# characters next to a % that matter: %, escape digits, a non-digit, characters outside Latin-1
PCT_POOL = (
    [0x25] * 6
    + [ord(c) for c in "0158AGKMVamv"]
    + [0x2E, 0x20, 0x7A, 0xE9, 0x100, 0x416, 0x2013, 0x1F600]
)


# local 0x80..0x83 are U+0104, U+00E9, U+0141 and U+2013, every other value once
TABLE = (
    list(range(0x80))
    + [0x104, 0xE9, 0x141, 0x2013]
    + [u for u in range(0x84, 0x100) if u != 0xE9]
    + [0x1001]
)


def samples():
    rng = random.Random(7)
    cps = list(range(0x80, 0x2000)) + [
        0x7FF,
        0x800,
        0xD7FF,
        0xE000,
        0xFFFD,
        0x10000,
        0x1F600,
        0x10FFFF,
    ]
    cps += [rng.randrange(0x2000, 0x110000) for _ in range(3000)]
    return [cp for cp in cps if not 0xD800 <= cp < 0xE000 and cp not in (0xFFFE, 0xFFFF)]


def inverse_table(table):
    """InvCodePage as InvertCodePage builds it: page numbers by high byte, '_' in unused slots."""
    pages = {}
    for unit in table:
        pages.setdefault(unit >> 8, len(pages) + 1)
    inverse = bytearray(256 + 256 * len(pages))
    inverse[256:] = b"_" * (256 * len(pages))
    for unit_high, page in pages.items():
        inverse[unit_high] = page
    for local, unit in enumerate(table):
        inverse[pages[unit >> 8] * 256 + (unit & 255)] = local
    return bytes(inverse)


def form(cp, size):
    """Digits (without the %) of cp in the form with `size` digits behind the class digit; may be overlong or out of range."""
    if size == 2:
        return B32[8 | cp >> 10] + B32[cp >> 5 & 31] + B32[cp & 31]
    if size == 3:
        return B32[12 | cp >> 14] + B32[cp >> 9 & 31] + B32[cp >> 4 & 31] + B32[cp << 1 & 31]
    return (
        B32[16 | cp >> 19]
        + B32[cp >> 14 & 31]
        + B32[cp >> 9 & 31]
        + B32[cp >> 4 & 31]
        + B32[cp << 1 & 31]
    )


class NameEscapes(unittest.TestCase):
    """The escape routines against an independent model of the escape rules."""

    SWAP = None  # a subclass swaps % with its escape character in all names

    def swap(self, data):
        return data.translate(self.SWAP) if self.SWAP else data

    def swap_unit(self, unit):
        if self.SWAP:
            return {0x25: self.SWAP[0x25], self.SWAP[0x25]: 0x25}.get(unit, unit)
        return unit

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
        self.h.set("EscChar", ord("%"), 1)

    def text(self, address, size):
        return self.swap(bytes(self.h.mem.r_block(address, size)))

    def put(self, address, data):
        self.h.mem.w_block(address, self.swap(data) + b"\0")

    def set_codepage(self, table):
        """Install a code page, one Unicode value per local character, and its inverse."""
        h = self.h
        forward = b"".join(unit.to_bytes(2, "big") for unit in table)
        h.mem.w_block(TABLES, forward)
        h.mem.w_block(TABLES + 0x1000, inverse_table(table))
        h.set("CodePage", TABLES)
        h.set("InvCodePage", TABLES + 0x1000)
        return TABLES + 0x1000

    def add_units(self, units, inverse=0):
        """Feed code units to ExAddUnit; return (name, last result, pending high surrogate)."""
        h = self.h
        h.mem.w_block(ENTRY, bytes(C["XMSDE_Sizeof"]))
        end, state, result = ENTRY + C["XMSDE_FullName"], 0, 1
        for unit in units:
            result = h.run(
                "ExAddUnit",
                d0=self.swap_unit(unit),
                regs={7: state, 9: end, 11: ENTRY, 14: inverse},
            )
            state, end = h.cpu.r_reg(7), h.cpu.r_reg(9)
            if not result:
                break
        return (
            self.text(ENTRY + C["XMSDE_FullName"], end - ENTRY - C["XMSDE_FullName"]),
            result,
            state & 0xFFFF,
        )

    def next_units(self, text, table=0):
        """The code units ExNextUnit reads from a name, up to its end."""
        h = self.h
        self.put(ENTRY, text)
        units, cursor, pending = [], ENTRY, 0
        while pending or cursor < ENTRY + len(text):
            unit = h.run("ExNextUnit", regs={9: cursor, 4: pending, 14: table}) & 0xFFFF
            units.append(self.swap_unit(unit))
            cursor, pending = h.cpu.r_reg(9), h.cpu.r_reg(4) & 0xFFFF
        self.assertEqual(cursor, ENTRY + len(text), text)
        return units

    def test_escape_matches_the_reference_form(self):
        """ExPutEscape writes the same characters as the reference encoder for 0x80 and above, in all three lengths."""
        for cp in samples():
            h = self.h
            h.mem.w_block(ENTRY, bytes(16))
            done = h.run("ExPutEscape", d0=cp, regs={9: ENTRY, 11: ENTRY - C["XMSDE_FullName"]})
            want = escape(cp).encode()
            self.assertEqual(done, 1, hex(cp))
            self.assertEqual(self.text(ENTRY, len(want)), want, hex(cp))
            self.assertEqual(h.cpu.r_reg(9), ENTRY + len(want), hex(cp))

    def test_escape_stops_at_the_end_of_the_name(self):
        """ExPutEscape writes nothing and returns 0 when the escape does not fit the 104 bytes of name."""
        h = self.h
        for cp, length in ((0x100, 4), (0x1234, 5), (0x1F600, 6)):
            for used in (104 - length, 104 - length + 1):
                h.mem.w_block(ENTRY, bytes(200))
                start = ENTRY + C["XMSDE_FullName"]
                done = h.run("ExPutEscape", d0=cp, regs={9: start + used, 11: ENTRY})
                self.assertEqual(done, int(used == 104 - length), (hex(cp), used))
                self.assertEqual(h.cpu.r_reg(9), start + used + length * done, (hex(cp), used))
                self.assertEqual(self.text(start + used, 1), bytes([37 * done]), (hex(cp), used))

    def test_parse_is_the_inverse_and_rejects_what_the_rules_reject(self):
        """ExParseEscape returns the code point and moves past the escape, or returns -1 and leaves a1 alone, exactly like the reference decoder on valid, odd-cased, overlong, truncated and random digit strings."""
        rng = random.Random(11)
        cases = [escape(cp)[1:] for cp in samples()[:400]]
        cases += [escape(cp)[1:].lower() for cp in samples()[:100]]
        cases += [
            "".join(rng.choice(B32 + B32.lower() + "WXYZ-%") for _ in range(rng.randrange(1, 7)))
            for _ in range(3000)
        ]
        cases += ["", "0", "55", "80", "88", "8800", "C00", "G00", "8x0"]
        for text in cases:
            h = self.h
            self.put(ENTRY, text.encode())
            got = h.run("ExParseEscape", a1=ENTRY)
            want = unescape(text)
            if want is None:
                self.assertEqual(got, 0xFFFFFFFF, text)
                self.assertEqual(h.cpu.r_reg(9), ENTRY, text)
            else:
                self.assertEqual(got, want[0], text)
                self.assertEqual(h.cpu.r_reg(9), ENTRY + want[1], text)

    def test_count_units(self):
        """ExCountUnits counts a valid escape as one unit, an escape above 0xFFFF as two, %% as one and a stray % as itself."""
        for name, units in (
            ("plain.txt", 9),
            ("%880.txt", 5),
            ("a%90Mb", 3),
            ("%%880", 4),
            ("%%%880", 2),
            ("%880%882", 2),
            ("x%1P0.y", 7),
            ("%55", 3),
            ("%", 1),
            ("", 0),
            ("%%", 1),
            ("a%%%", 3),
            ("%%%%", 2),
            (escape(0x1F600) + "z", 3),
            ("%8", 2),
        ):
            self.put(ENTRY, name.encode())
            self.assertEqual(self.h.run("ExCountUnits", a0=ENTRY), units, name)

    def test_units_to_name_without_a_code_page(self):
        """ExAddUnit keeps Latin-1 characters, escapes the rest, joins surrogate pairs into one escape and hides names it cannot show."""
        name, result, pending = self.add_units([0x41, 0xE9, 0x100, 0x416, 0xD83D, 0xDE00, 0x7A])
        want = "A\xe9" + escape(0x100) + escape(0x416) + escape(0x1F600) + "z"
        self.assertEqual((name, result, pending), (want.encode("latin-1"), 1, 0))
        self.assertEqual(self.add_units([0x41, 0xD83D])[2], 0xD83D)
        for units in ([0xDE00], [0xD83D, 0x41], [0x41, 0], [0xFFFE], [0xD83D, 0xD83D]):
            self.assertEqual(self.add_units(units)[1], 0, units)

    def test_name_longer_than_the_limit_is_hidden(self):
        """ExAddUnit accepts 104 bytes of name and fails on the 105th, escapes included."""
        self.assertEqual(self.add_units([0x61] * 104)[1:], (1, 0))
        self.assertEqual(self.add_units([0x61] * 105)[1], 0)
        self.assertEqual(self.add_units([0x61] * 100 + [0x100])[1], 1)
        self.assertEqual(self.add_units([0x61] * 101 + [0x100])[1], 0)

    def test_units_to_name_with_a_code_page(self):
        """With a code page ExAddUnit maps through the inverse table and escapes a character that is missing, also when its page exists and the slot holds the filler '_'."""
        inverse = self.set_codepage(TABLE)
        name, result, _ = self.add_units(
            [0x41, 0x104, 0xE9, 0x141, 0x5F, 0x100, 0x2013, 0x1234], inverse
        )
        self.assertEqual(result, 1)
        self.assertEqual(
            name, b"A\x80\x81\x82_" + escape(0x100).encode() + b"\x83" + escape(0x1234).encode()
        )

    def test_name_to_units_with_a_code_page(self):
        """ExNextUnit turns code page characters above 0x7F into their Unicode value without the bit that 2*index leaves in the low byte, and decodes escapes including a surrogate pair."""
        self.set_codepage(TABLE)
        text = b"A\x80\x81\x82%880%1P0z".replace(b"%1P0", escape(0x1F600).encode())
        h = self.h
        self.put(ENTRY, text)
        units, cursor, pending = [], ENTRY, 0
        for _ in range(8):
            units.append(
                self.swap_unit(
                    h.run("ExNextUnit", regs={9: cursor, 4: pending, 14: TABLES}) & 0xFFFF
                )
            )
            cursor, pending = h.cpu.r_reg(9), h.cpu.r_reg(4) & 0xFFFF
        self.assertEqual(units, [0x41, 0x104, 0xE9, 0x141, 0x100, 0xD83D, 0xDE00, 0x7A])
        self.assertEqual(cursor, ENTRY + len(text))

    def test_percent_shows_as_two_where_it_would_read_as_an_escape(self):
        """ExAddUnit writes a % as %% only when the text behind it starts with % or reads as an escape, so U+0025 U+0038 U+0038 U+0030 and U+0100 show differently."""
        for cps, want in (
            ([0x25, 0x38, 0x38, 0x30], "%%880"),
            ([0x100], "%880"),
            ([0x25, 0x100], "%%%880"),
            ([0x31, 0x30, 0x30, 0x25, 0x2E], "100%."),
            ([0x25, 0x25], "%%%"),
            ([0x61, 0x25, 0x25, 0x62], "a%%%b"),
            ([0x25, 0x38, 0x38], "%88"),
            ([0x25, 0x38, 0x38, 0x31], "%%881"),
            ([0x25, 0x43, 0x30, 0x30, 0x31], "%C001"),
            ([0x25, 0x47, 0x30, 0x30, 0x30, 0x30], "%G0000"),
            ([0x25, 0x47, 0x30, 0x30, 0x30, 0x31], "%G0001"),
            ([0x25, 0x1F600], "%%" + escape(0x1F600)),
            ([0x25] * 3 + [0x38, 0x38, 0x30], "%%%%%%880"),
        ):
            self.assertEqual(want, show(cps), cps)
            self.assertEqual(self.add_units(utf16(cps))[:2], (want.encode(), 1), want)

    def test_shown_names_read_back_as_their_units(self):
        """For random names with % runs, digits and characters outside the code page, ExAddUnit writes the reference text, ExNextUnit and ExCountUnits read it back as the same units, with and without a code page."""
        rng = random.Random(23)
        for local in (None, {u: i for i, u in enumerate(TABLE[:0x100]) if i >= 0x80}):
            inverse = self.set_codepage(TABLE) if local is not None else 0
            for _ in range(400):
                cps = [rng.choice(PCT_POOL) for _ in range(rng.randrange(1, 14))]
                want = show(cps, local)
                name, result, _ = self.add_units(utf16(cps), inverse)
                self.assertEqual((name.decode("latin-1"), result), (want, 1), cps)
                back = {v: k for k, v in local.items()} if local else {}
                self.assertEqual([back.get(c, c) for c in decode(want)], cps, want)
                self.assertEqual(self.next_units(name, TABLES if local else 0), utf16(cps), want)
                self.put(ENTRY, name)
                self.assertEqual(self.h.run("ExCountUnits", a0=ENTRY), len(utf16(cps)), want)

    def test_typed_names_mean_what_the_reference_decodes(self):
        """Typed text with %, %% and escapes: ExNextUnit and ExCountUnits agree with the reference decoder, and the units shown again give the canonical text."""
        rng = random.Random(29)
        parts = [
            "%",
            "%%",
            "%%%",
            "880",
            "90M",
            "%880",
            "%90m",
            escape(0x1F600),
            "8",
            "G00",
            "x",
            ".",
        ]
        for _ in range(500):
            text = "".join(rng.choice(parts) for _ in range(rng.randrange(1, 7)))
            cps = decode(text)
            self.assertEqual(self.next_units(text.encode()), utf16(cps), text)
            self.put(ENTRY, text.encode())
            self.assertEqual(self.h.run("ExCountUnits", a0=ENTRY), len(utf16(cps)), text)
            canonical = show(cps)
            self.assertEqual(decode(canonical), cps, text)
            self.assertEqual(self.add_units(utf16(cps))[0], canonical.encode("latin-1"), text)

    def test_percent_doubling_needs_room(self):
        """A % that becomes %% needs one more byte of the 104: a name that fits only with a single % is hidden."""
        self.assertEqual(self.add_units([0x61] * 103 + [0x25]), (b"a" * 103 + b"%", 1, 0))
        self.assertEqual(self.add_units([0x61] * 100 + [0x25, 0x38, 0x38, 0x30])[1], 0)
        self.assertEqual(
            self.add_units([0x61] * 99 + [0x25, 0x38, 0x38, 0x30])[:2], (b"a" * 99 + b"%%880", 1)
        )

    def test_short_name_shows_its_percent_like_a_long_name(self):
        """ExShowPct doubles the % of an 8.3 name where the reference encoder does, in place, and leaves a0 behind the 0."""
        rng = random.Random(31)
        cases = [
            "%880.TXT",
            "100%.TXT",
            "%%X.TXT",
            "A%%B.TXT",
            "%%%%%%%%.%%%",
            "%%%%%880",
            "%G00",
            "ABC",
        ]
        cases += [
            "".join(rng.choice("%%%08AGKV.X") for _ in range(rng.randrange(1, 12)))
            for _ in range(300)
        ]
        for text in cases:
            self.put(ENTRY, text.encode())
            self.h.run("ExShowPct", a0=ENTRY)
            want = show([ord(c) for c in text]).encode()
            self.assertEqual(self.text(ENTRY, len(want) + 1), want + b"\0", text)
            self.assertEqual(self.h.cpu.r_reg(8), ENTRY + len(want) + 1, text)
            self.assertLessEqual(len(want), 21, text)

    def test_short_name_listing_doubles_its_percent(self):
        """GetBName shows an 8.3 name with its spaces trimmed and its % doubled where the reference encoder does, with the length byte to match, in at most 21 characters."""
        rng = random.Random(37)
        cases = [
            "README  TXT",
            "%880    TXT",
            "AB%%    %  ",
            "NOEXT      ",
            "A B     TXT",
            "A!      $  ",
            "%%%%%%%%%%%",
            "%       %%%",
            "%C00    ",
            "%%X     TXT",
        ]
        cases += ["".join(rng.choice("%% 08ACGX!") for _ in range(11)) for _ in range(300)]
        for raw in cases:
            raw = raw.ljust(11)
            if raw[0] == " ":
                continue
            self.h.mem.w_block(ENTRY, bytes(C["XMSDE_Sizeof"]))
            self.h.mem.w_block(ENTRY, self.swap(raw.encode()))
            self.h.run("GetBName", a0=ENTRY, a1=ENTRY + 0x200)
            base, ext = raw[:8].rstrip(" "), raw[8:].rstrip(" ")
            want = show([ord(c) for c in base + ("." + ext if ext else "")]).encode()
            self.assertEqual(
                self.text(ENTRY + 0x200, len(want) + 2), bytes([len(want)]) + want + b"\0", raw
            )
            self.assertLessEqual(len(want), 21, raw)

    def test_created_name_is_stored_as_listed(self):
        """ExShowName stores a typed name (up to 0 or /) as the text a listing shows for its units, with its length, so %%, lower-case escape digits and escapes of code page characters take their listed form; registers kept."""
        rng = random.Random(41)
        parts = [
            "%",
            "%%",
            "%%%",
            "880",
            "90m",
            "%880",
            "%90m",
            "%875",
            escape(0x1F600).lower(),
            "G00",
            "x",
            ".",
            "\xe9",
        ]
        for local in (None, {u: i for i, u in enumerate(TABLE[:0x100]) if i >= 0x80}):
            if local is not None:
                self.set_codepage(TABLE)
            back = {v: k for k, v in local.items()} if local else {}
            for _ in range(300):
                text = "".join(rng.choice(parts) for _ in range(rng.randrange(1, 8)))
                tail = rng.choice(("", "/next"))
                cps = [back.get(c, c) for c in decode(text)]
                want = show(cps, local).encode("latin-1")
                self.h.mem.w_block(ENTRY, bytes(C["XMSDE_Sizeof"]))
                self.put(ENTRY + 0x200, text.encode("latin-1") + tail.encode())
                regs = self.sentinels({8: ENTRY + 0x200, 9: ENTRY}, ())
                self.h.run("ExShowName", regs=regs)
                self.assert_preserved(regs, (), text)
                start = ENTRY + C["XMSDE_FullName"]
                self.assertEqual(self.text(start, len(want) + 1), want + b"\0", text)
                self.assertEqual(self.h.mem.r8(ENTRY + C["XMSDE_FNLength"]), len(want), text)

    def test_short_name_from_a_typed_percent(self):
        """MakeShortName takes %% as one % and an escape as a character outside 8.3, so %%880.txt and %880.txt get different short names."""
        for text, want in (
            ("%%880.txt", b"%880    TXT"),
            ("%880.txt", b"_~1     TXT"),
            ("100%.txt", b"100%    TXT"),
            ("a%%%880", b"A%_~1      "),
            ("%8.txt", b"%8      TXT"),
        ):
            self.put(ENTRY, text.encode())
            self.assertEqual(self.h.run("MakeShortName", a0=ENTRY, a1=ENTRY + 0x100), 0, text)
            self.assertEqual(self.text(ENTRY + 0x100, 11), want, text)
            self.assertEqual(self.h.cpu.r_reg(8), ENTRY + len(text), text)

    def test_parse_limits_of_every_form(self):
        """ExParseEscape agrees with the reference decoder at every limit: smallest and largest code point of each form, the form below and above, surrogate and noncharacter edges, 0x10FFFF and 0x110000, in all forms that can hold the value, upper and lower case."""
        edge = [
            0x7E,
            0x7F,
            0x80,
            0x81,
            0x7FF,
            0x800,
            0x801,
            0xD7FE,
            0xD7FF,
            0xD800,
            0xD801,
            0xDBFF,
            0xDC00,
            0xDFFE,
            0xDFFF,
            0xE000,
            0xE001,
            0xFFFC,
            0xFFFD,
            0xFFFE,
            0xFFFF,
            0x10000,
            0x10001,
            0x1FFFFF - 1,
            0x10FFFE,
            0x10FFFF,
            0x110000,
            0x110001,
            0x1FFFFF,
        ]
        cases = []
        for cp in edge:
            for size, limit in ((2, 0x1000), (3, 0x10000), (4, 0x200000)):
                if cp < limit:
                    cases.append(form(cp, size))
                    cases.append(form(cp, size).lower())
        # a digit string longer than the longest form, and a first digit of class 5..7 and 0..1
        cases += [
            "K200000",
            "K000000",
            "K000200",
            "L000000",
            "O00000V",
            "S000000",
            "V000000",
            "0",
            "00",
            "1V",
            "1VV",
            "4",
            "40",
            "400",
            "4000",
            "40000",
        ]
        cases += [B32[c] + "VVVVV" for c in range(32)]
        cases += [B32[c] + "00000" for c in range(32)]
        cases += [B32[c] + "000" for c in range(32)]
        for text in cases:
            self.put(ENTRY, text.encode())
            got = self.h.run("ExParseEscape", a1=ENTRY)
            want = unescape(text)
            if want is None:
                self.assertEqual(got, 0xFFFFFFFF, text)
                self.assertEqual(self.h.cpu.r_reg(9), ENTRY, text)
            else:
                self.assertEqual(got, want[0], text)
                self.assertEqual(self.h.cpu.r_reg(9), ENTRY + want[1], text)

    def test_parse_rejects_the_characters_next_to_the_digit_ranges(self):
        """ExParseEscape does not read ':' '@' '[' '`' '{' and other neighbours of 0-9, A-V, a-v as digits, in any position."""
        for bad in ":;<=>?@[\\]^_`{|}~/ \x00\x80\xb0\xc1\xe1\xff":
            for good in (escape(0x100), escape(0x1234), escape(0x1F600)):
                for pos in range(1, len(good)):
                    text = good[1:pos] + bad + good[pos + 1 :]
                    self.put(ENTRY, text.encode("latin-1"))
                    self.assertEqual(self.h.run("ExParseEscape", a1=ENTRY), 0xFFFFFFFF, repr(text))
                    self.assertEqual(self.h.cpu.r_reg(9), ENTRY, repr(text))

    def test_add_unit_surrogate_and_range_edges(self):
        """ExAddUnit at the edges of the surrogate ranges: first and last pair, 0xD800 pending, 0xDC00 alone, a second unit just below/above the low range, 0xD7FF and 0xE000 as characters, 0xFFFD ok and 0xFFFF hidden."""
        ok = [
            ([0xD800, 0xDC00], escape(0x10000).encode(), 0),
            ([0xDBFF, 0xDFFF], escape(0x10FFFF).encode(), 0),
            ([0xD7FF], escape(0xD7FF).encode(), 0),
            ([0xE000], escape(0xE000).encode(), 0),
            ([0xFFFD], escape(0xFFFD).encode(), 0),
            ([0xD800], b"", 0xD800),
            ([0xDBFF], b"", 0xDBFF),
            ([0x80, 0xFF], b"\x80\xff", 0),
        ]
        for units, name, pending in ok:
            self.assertEqual(self.add_units(units), (name, 1, pending), [hex(u) for u in units])
        for units in (
            [0xDC00],
            [0xDFFF],
            [0xD800, 0xDBFF],
            [0xD800, 0xE000],
            [0xDBFF, 0xDBFF],
            [0xD800, 0x41],
            [0xFFFF],
            [0xFFFE],
        ):
            self.assertEqual(self.add_units(units)[1], 0, [hex(u) for u in units])

    def test_add_unit_pair_to_escape_values(self):
        """Every pair edge gives the escape of the right code point (low, high and middle values of the 10+10 bit split)."""
        for high, low in (
            (0xD800, 0xDC00),
            (0xD800, 0xDFFF),
            (0xDBFF, 0xDC00),
            (0xDBFF, 0xDFFF),
            (0xD801, 0xDC01),
            (0xD9AB, 0xDD23),
            (0xDB40, 0xDC00),
        ):
            cp = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
            self.assertEqual(self.add_units([high, low]), (escape(cp).encode(), 1, 0), hex(cp))

    def test_add_unit_hides_an_ascii_character_missing_from_the_code_page(self):
        """With a code page that lacks an ASCII character, ExAddUnit hides the name instead of writing an escape for a value below 0x80."""
        table = list(TABLE)
        table[0x41] = 0x1002
        inverse = self.set_codepage(table)
        self.assertEqual(self.add_units([0x41], inverse)[1], 0)
        self.assertEqual(self.add_units([0x42], inverse)[:2], (b"B", 1))

    def test_add_unit_code_page_filler_and_page_lookup(self):
        """With a code page, a character whose page exists but whose slot holds the filler, or whose page does not exist, is escaped, also if its low byte looks like '_' or like a high byte that has a page."""
        inverse = self.set_codepage(TABLE)
        for unit in (0x80, 0x15F, 0x205F, 0x105F, 0x3000, 0x3001, 0x3010, 0x3020, 0x5F00, 0x5F01):
            self.assertEqual(
                self.add_units([unit], inverse)[:2], (escape(unit).encode(), 1), hex(unit)
            )
        self.assertEqual(self.add_units([0x5F], inverse)[:2], (b"_", 1))

    MAPPED = (
        list(range(0x61, 0x7B))
        + [u for u in range(0xE0, 0xFF) if u != 0xF7]
        + [0xFF]
        + list(range(0x101, 0x130, 2))
        + list(range(0x3B1, 0x3CA))
        + list(range(0x430, 0x460))
        + list(range(0x561, 0x587))
        + list(range(0xFF41, 0xFF5B))
    )

    def upper(self, unit, cache=None):
        if cache is None:
            cache = UPPER_CACHE
        if unit > 0xFFFF:
            return unit
        if unit not in cache:
            cache[unit] = self.h.run("UpperUnit", d0=unit)
        return cache[unit]

    def test_upper_unit(self):
        """UpperUnit maps the lower case letters of Latin, Greek, Cyrillic, Armenian and full-width ASCII to their Unicode upper case and never maps a unit anywhere else."""
        units = (
            list(range(0x600))
            + list(range(0x1E00, 0x1F00))
            + list(range(0x2160, 0x2190))
            + list(range(0x24C0, 0x24F0))
            + list(range(0xFF20, 0xFF60))
            + [0xD800, 0xFFFE, 0xFFFF]
        )
        for unit in units:
            got = self.h.run("UpperUnit", d0=unit)
            if unit in self.MAPPED:
                self.assertEqual(got, ord(chr(unit).upper()), hex(unit))
            elif got != unit:
                self.assertEqual(chr(got), chr(unit).upper(), hex(unit))

    def write_units(self, units, rng, local=None, typed=False):
        """Amiga text for code units: a byte when the code page (Latin-1 without one) has the unit, else an escape, sometimes with lower-case digits; typed text sometimes has %% where % would do."""
        out = ""
        for unit in reversed(units):
            if unit == 0x25:
                piece = (
                    "%%"
                    if out.startswith("%") or unescape(out) or (typed and rng.random() < 0.5)
                    else "%"
                )
            elif unit < 0x80:
                piece = chr(unit)
            elif local is not None and unit in local:
                piece = chr(local[unit])
            elif local is None and unit < 0x100:
                piece = chr(unit)
            else:
                piece = escape(unit)
                piece = piece.lower() if rng.random() < 0.3 else piece
            out = piece + out
        return out.encode("latin-1")

    def same_rest(self, disk, wanted, keep_units=False):
        """Call ExSameRest the way LocateObj does, at the first byte pair that differs other than by ASCII case; None when the names never get there. keep_units leaves the wanted name and its units from the call before."""
        h = self.h
        stop = wanted.find(b"/")
        component = wanted if stop < 0 else wanted[:stop]
        for i in range(min(len(disk), len(component))):
            a, b = disk[i], component[i]
            if a == b or (a | 32 == b | 32 and 0x61 <= a | 32 <= 0x7A):
                continue
            self.put(ENTRY, disk)
            if keep_units:
                self.assertEqual(self.text(ENTRY + 0x200, len(wanted)), wanted)
            else:
                self.put(ENTRY + 0x200, wanted)
                h.set("WantedStart", 0)
            return h.run(
                "ExSameRest",
                a0=ENTRY + i + 1,
                a1=ENTRY + 0x200 + i + 1,
                a2=ENTRY,
                regs={14: ENTRY + 0x200},
            )
        if len(disk) < len(component) and b"%" in component:  # the disk name ends first
            self.put(ENTRY, disk)
            if not keep_units:
                self.put(ENTRY + 0x200, wanted)
                h.set("WantedStart", 0)
            i = len(disk)
            return h.run(
                "ExSameRest",
                a0=ENTRY + i + 1,
                a1=ENTRY + 0x200 + i + 1,
                a2=ENTRY,
                regs={14: ENTRY + 0x200},
            )
        return None

    def test_same_rest_is_a_case_blind_compare(self):
        """ExSameRest finds two names equal exactly when their code units are equal after UpperUnit, whether the difference lies inside an escape, in a %% where the disk name shows %, in a byte from 0x80 or behind an escape, with or without a code page."""
        rng = random.Random(17)
        pool = [
            0x41,
            0x61,
            0x5B,
            0x7B,
            0x40,
            0x60,
            0x2E,
            0x25,
            0x31,
            0xE9,
            0xC9,
            0xD7,
            0xF7,
            0xFF,
            0x178,
            0xDF,
            0x100,
            0x101,
            0x131,
            0x49,
            0x17F,
            0x53,
            0x3A3,
            0x3C2,
            0x3C3,
            0xB5,
            0x39C,
            0x3BC,
            0x416,
            0x436,
            0x417,
            0x450,
            0x400,
            0x104,
            0x105,
            0x1E00,
            0x1E01,
            0xFF21,
            0xFF41,
            0x24B6,
            0x24D0,
            0x2160,
            0x2170,
            0x1F600,
            0x1F601,
            0x25,
            0x25,
            0x25,
            0x38,
            0x30,
            0x4D,
            0x6D,
        ]
        for local in (None, {u: i for i, u in enumerate(TABLE[:0x100]) if i >= 0x80}):
            if local is not None:
                self.set_codepage(TABLE)
            checked = 0
            for _ in range(1500):
                units = [rng.choice(pool) for _ in range(rng.randrange(1, 6))]
                if rng.random() < 0.6:
                    other = [rng.choice((u, self.upper(u))) for u in units]
                else:
                    other = list(units)
                    other[rng.randrange(len(other))] = rng.choice(pool)
                if rng.random() < 0.1:
                    other.append(0x7A)
                elif rng.random() < 0.1:
                    units.append(rng.choice((0x7A, 0x1F600)))
                disk = self.write_units(units, rng, local)
                wanted = self.write_units(other, rng, local, typed=True) + (
                    b"/next" if rng.random() < 0.3 else b""
                )
                got = self.same_rest(disk, wanted)
                if got is None:
                    continue
                checked += 1
                back = {v: k for k, v in local.items()} if local else {}

                def meaning(text, back=back):
                    text = text.split(b"/")[0].decode("latin-1")
                    return [self.upper(back.get(u, u)) for u in decode(text)]

                want = meaning(disk) == meaning(wanted)
                self.assertEqual(got, int(want), (disk, wanted))
            self.assertGreater(checked, 800)

    def test_same_rest_keeps_the_wanted_units_for_the_next_entry(self):
        """ExSameRest converts the wanted name once and compares it with every following disk name like a fresh conversion would."""
        rng = random.Random(19)
        h = self.h
        wanted = escape(0x436) + "big " + escape(0x101) + ".txt"
        disks = [
            escape(cp) + "BIG " + escape(other) + ".TXT"
            for cp in (0x416, 0x436, 0x417, 0x100)
            for other in (0x100, 0x101, 0x102)
        ]
        rng.shuffle(disks)
        self.put(ENTRY + 0x200, wanted.encode())
        h.set("WantedStart", 0)
        for disk in disks:
            want = disk.startswith((escape(0x416), escape(0x436))) and escape(0x102) not in disk
            got = self.same_rest(disk.encode(), wanted.encode(), keep_units=True)
            self.assertEqual(want if got is None else got, int(want), disk)
        self.assertEqual(h.get("WantedStart"), ENTRY + 0x200)

    def sentinels(self, regs, outputs):
        regs = dict(regs)
        for r in (1, 2, 3, 4, 5, 6, 7, 8, 10, 13):
            if r not in regs and r not in outputs:
                regs[r] = 0xA5000000 + r
        return regs

    def assert_preserved(self, regs, outputs, label):
        for r, value in regs.items():
            if r not in outputs:
                self.assertEqual(self.h.cpu.r_reg(r), value, (label, "register", r))

    def test_escape_routines_keep_the_registers_the_callers_use(self):
        """ExPutEscape and ExAddUnit (also with a % waiting) leave d1-d6 and a0, a2-a6 alone (rxms_conv keeps its counters in d3/d5), ExParseEscape leaves d1-d7 and a0, a2-a6 (ExNextUnit keeps the pending surrogate in d4), on success and on failure; UpperUnit, ExCutEscape and ExSameRest change only their result."""
        h = self.h
        inverse = self.set_codepage(TABLE)
        for cp, used in ((0x100, 0), (0x1234, 0), (0x1F600, 0), (0x100, 102)):
            h.mem.w_block(ENTRY, bytes(200))
            regs = self.sentinels({9: ENTRY + C["XMSDE_FullName"] + used, 11: ENTRY}, (0, 9))
            h.run("ExPutEscape", d0=cp, regs=regs)
            self.assert_preserved(regs, (0, 9), ("ExPutEscape", hex(cp), used))
        for unit, pending, table in (
            (0x41, 0, 0),
            (0x100, 0, 0),
            (0x1234, 0, inverse),
            (0x41, 0, inverse),
            (0xD83D, 0, 0),
            (0xDE00, 0xD83D, 0),
            (0xDE00, 0, 0),
        ):
            h.mem.w_block(ENTRY, bytes(200))
            regs = self.sentinels(
                {7: pending, 9: ENTRY + C["XMSDE_FullName"], 11: ENTRY, 14: table}, (0, 7, 9)
            )
            h.run("ExAddUnit", d0=unit, regs=regs)
            self.assert_preserved(regs, (0, 7, 9), ("ExAddUnit", hex(unit), pending))
        name = ENTRY + C["XMSDE_FullName"]
        for text, unit, pending in (
            (b"%88", 0x30, 0),
            (b"%", 0x25, 0),
            (b"%", 0x100, 0),
            (b"%", 0x41, 0),
            (b"%", 0xDC00, 0xD800),
            (b"%", 0xD800, 0),
        ):
            h.mem.w_block(ENTRY, bytes(200))
            h.mem.w_block(name, self.swap(text))
            regs = self.sentinels(
                {7: C["XMSDE_FullName"] << 16 | pending, 9: name + len(text), 11: ENTRY, 14: 0},
                (0, 7, 9),
            )
            self.assertEqual(
                h.run("ExAddUnit", d0=self.swap_unit(unit), regs=regs), 1, (text, hex(unit))
            )
            self.assert_preserved(regs, (0, 7, 9), ("ExAddUnit", text, hex(unit)))
        for text in (
            "880",
            "C00",
            escape(0x1F600)[1:],
            "8x0",
            "8",
            "",
            "1",
            "K200000",
            "C01",
            "VVVVV",
        ):
            self.put(ENTRY, text.encode())
            regs = self.sentinels({9: ENTRY}, (0, 9))
            h.run("ExParseEscape", regs=regs)
            self.assert_preserved(regs, (0, 9), ("ExParseEscape", text))
        for unit in (0x30, 0x61, 0x416, 0x436, 0x1E05, 0xFF41):
            regs = self.sentinels({}, (0,))
            h.run("UpperUnit", d0=unit, regs=regs)
            self.assert_preserved(regs, (0,), ("UpperUnit", hex(unit)))
        for text, cut in (("ab%90M", 5), ("ab%Zq", 4), ("abcdefg", 6)):
            self.put(ENTRY, text[:cut].encode())
            regs = self.sentinels({9: ENTRY + cut}, (0, 9))
            h.run("ExCutEscape", d0=ord(text[cut]), regs=regs)
            self.assert_preserved(regs, (0, 9), ("ExCutEscape", text))
        for disk, wanted, at in (
            (b"a%90M", b"a%91M", 4),
            (b"ab", b"ac", 2),
            (b"a\xe9", b"a\xc9", 2),
        ):
            self.put(ENTRY, disk)
            self.put(ENTRY + 0x200, wanted)
            h.set("WantedStart", 0)
            regs = self.sentinels(
                {8: ENTRY + at, 9: ENTRY + 0x200 + at, 10: ENTRY, 14: ENTRY + 0x200}, (0,)
            )
            h.run("ExSameRest", regs=regs)
            self.assert_preserved(regs, (0,), ("ExSameRest", disk))

    def cut(self, text, cut):
        """Call ExCutEscape on text cut after `cut` bytes, as LocateObj does at the 104-byte limit; return the kept length."""
        start = ENTRY + 0x200 - C["MAXNAMELEN"]
        self.h.mem.w_block(start, b"\0" * C["MAXNAMELEN"])
        self.put(ENTRY + 0x200 - cut, text[:cut].encode())
        self.h.run("ExCutEscape", d0=self.swap(text[cut].encode())[0], regs={9: ENTRY + 0x200})
        return self.h.cpu.r_reg(9) - (ENTRY + 0x200 - cut)

    def test_cut_keeps_no_part_of_an_escape(self):
        """ExCutEscape moves the end of a name cut inside an escape or a %% back to its first %, so the kept text means the same characters as the start of the full name; a % that starts no escape stays."""
        rng = random.Random(13)
        parts = [escape(cp) for cp in samples()[::40]] + [
            "%",
            "%Z",
            "%8",
            "%9x",
            "%%",
            "%%%",
            "%%880",
            "a",
            "b9",
            "Q",
        ]
        for text, cut, want in (
            ("c" * 102 + "%9x", 104, 104),
            ("c" * 101 + "%90!", 104, 104),
            ("c" * 101 + "%90M", 104, 101),
            ("c" * 103 + "%%", 104, 103),
            ("c" * 102 + "%%%", 104, 104),
            ("c" * 101 + "%%%8", 104, 103),
            ("c" * 100 + "%%%880", 104, 102),
            ("c" * 101 + "%%880", 104, 104),
            ("%" * 105, 104, 104),
            ("c" + "%" * 104, 104, 103),
            ("c" + "%" * 103 + "x", 104, 104),
            ("c" + "%" * 103 + "8", 104, 103),
        ):
            self.assertEqual(self.cut(text, cut), want, text)
        for _ in range(3000):
            text = "".join(rng.choice(parts) for _ in range(rng.randrange(2, 8))) + "zzzzzz"
            cut = rng.randrange(1, len(text) - 1)
            end = self.cut(text, cut)
            kept = text[:end]
            self.assertTrue(cut - 5 <= end <= cut, (text, cut, end))
            self.assertEqual(decode(kept), decode(text)[: len(decode(kept))], (text, cut, end))
            if end < cut:
                # only the first % of a split %%, or of what may be an escape up to the cut byte, goes
                run = len(kept) - len(kept.rstrip("%"))
                self.assertEqual((text[end], run % 2), ("%", 0), (text, cut, end))
                pair = end + 1 == cut and text[cut] == "%"
                digits = all(c in B32 + B32.lower() for c in text[end + 1 : cut + 1])
                self.assertTrue(
                    pair or (digits and 2 <= B32.index(text[end + 1].upper()) >> 2 <= 4),
                    (text, cut, end),
                )
            else:
                whole = decode(text)
                self.assertEqual(decode(kept), whole[: len(decode(kept))], (text, cut, end))


class NameEscapesCaret(NameEscapes):
    """The same tests with ^, the default escape character; % is then a plain character."""

    SWAP = bytes.maketrans(b"%^", b"^%")

    def setUp(self):
        super().setUp()
        self.h.set("EscChar", ord("^"), 1)


class ControlEscape(unittest.TestCase):
    """Control +n<char> sets the escape character, from a fixed set only, -n turns escapes off."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.image = load(Path(cls.temp.name) / "handler.hunk")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def options(self, text):
        h = Handler(self.image)  # one machine at a time, closed before the next
        try:
            h.mem.w_block(ENTRY, text.encode() + b"\0")
            self.assertEqual(h.run("SetOptions", a0=ENTRY), 0xFFFFFFFF, text)
            return chr(h.get("EscChar", 1)), h.get("CmdFlags", 2)
        finally:
            h.close()

    def test_control_sets_the_escape_character(self):
        """n or +n takes the next character when it is one of % ! $ @ ^ `, keeps the old one otherwise; -n takes none and turns escapes off; other options around it still apply."""
        q = 1 << 12
        for text, esc, quiet in (
            ("n%", "%", False),
            ("+n`", "`", False),
            ("+qn!", "!", True),
            ("n% +q", "%", True),
            ("n#q", "^", True),
            ("nA", "^", False),
            ("n", "^", False),
            ("n!n%", "%", False),
            ("-n", "\0", False),
            ("-n+q", "\0", True),
            ("-qn", "\0", False),
            ("-n!", "\0", False),
            ("-n+n$", "$", False),
            ("e%", "^", False),
        ):
            got, flags = self.options(text)
            self.assertEqual((got, bool(flags & q)), (esc, quiet), text)


class EscapesOff(unittest.TestCase):
    """Control -n: no escape character, characters outside the code page show as _ and every typed character stands for itself."""

    SWAP = None
    setUpClass = classmethod(NameEscapes.setUpClass.__func__)
    tearDownClass = classmethod(NameEscapes.tearDownClass.__func__)
    swap, swap_unit = NameEscapes.swap, NameEscapes.swap_unit
    text, put = NameEscapes.text, NameEscapes.put
    add_units, next_units = NameEscapes.add_units, NameEscapes.next_units

    def setUp(self):
        self.h = Handler(self.image)
        self.addCleanup(self.h.close)
        self.h.set("EscChar", 0, 1)

    def test_units_outside_the_code_page_show_as_underscore(self):
        """ExAddUnit puts _ for a character outside Latin-1 and for a surrogate pair, keeps Latin-1, and still hides what it cannot show."""
        units = [0x41, 0xE9, 0x100, 0x416, 0xD83D, 0xDE00, 0x5E, 0x25]
        name, result, pending = self.add_units(units)
        self.assertEqual((name, result, pending), (b"A\xe9___^%", 1, 0))
        for units in ([0xDE00], [0xD83D, 0x41], [0x41, 0], [0xFFFE]):
            self.assertEqual(self.add_units(units)[1], 0, units)
        self.assertEqual(self.add_units([0x61] * 103 + [0x100])[1], 1)
        self.assertEqual(self.add_units([0x61] * 104 + [0x100])[1], 0)

    def test_typed_escapes_are_plain_characters(self):
        """ExNextUnit and ExCountUnits read ^880, %880 and ^^ character by character."""
        for name in ("^880.txt", "%880.txt", "a^^b", "%%", "^"):
            self.assertEqual(self.next_units(name.encode()), [ord(c) for c in name], name)
            self.put(ENTRY, name.encode())
            self.assertEqual(self.h.run("ExCountUnits", a0=ENTRY), len(name), name)


if __name__ == "__main__":
    unittest.main()
