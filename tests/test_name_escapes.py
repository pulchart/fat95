"""Long names: characters outside the code page as %-escapes.

Run: make test"""
import random
import tempfile
import unittest
from pathlib import Path

from harness import C, Handler, load

B32 = '0123456789ABCDEFGHIJKLMNOPQRSTUV'
TABLES, ENTRY = 0x60000, 0x62000


def escape(cp):
    """Reference encoder, the escape for a code point of 0x80 or more."""
    if cp < 0x800:
        return '%' + B32[8 | cp >> 10] + B32[cp >> 5 & 31] + B32[cp & 31]
    if cp < 0x10000:
        return '%' + B32[12 | cp >> 14] + B32[cp >> 9 & 31] + B32[cp >> 4 & 31] + B32[cp << 1 & 31]
    return '%' + B32[16 | cp >> 19] + B32[cp >> 14 & 31] + B32[cp >> 9 & 31] + B32[cp >> 4 & 31] + B32[cp << 1 & 31]


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
    if (value < (0x80, 0x800, 0x10000)[size - 2] or 0xd800 <= value < 0xe000
            or value in (0xfffe, 0xffff) or value > 0x10ffff):
        return None
    return value, size + 1


def decode(text):
    """Reference decoder of a whole name: its code points, a % that starts no escape as itself."""
    out, i = [], 0
    while i < len(text):
        found = unescape(text[i + 1:]) if text[i] == '%' else None
        if found:
            out.append(found[0])
            i += 1 + found[1]
        else:
            out.append(ord(text[i]))
            i += 1
    return out


# local 0x80..0x83 are U+0104, U+00E9, U+0141 and U+2013, every other value once
TABLE = (list(range(0x80)) + [0x104, 0xe9, 0x141, 0x2013]
         + [u for u in range(0x84, 0x100) if u != 0xe9] + [0x1001])


def samples():
    rng = random.Random(7)
    cps = list(range(0x80, 0x2000)) + [0x7ff, 0x800, 0xd7ff, 0xe000, 0xfffd, 0x10000, 0x1f600, 0x10ffff]
    cps += [rng.randrange(0x2000, 0x110000) for _ in range(3000)]
    return [cp for cp in cps if not 0xd800 <= cp < 0xe000 and cp not in (0xfffe, 0xffff)]


def inverse_table(table):
    """InvCodePage as InvertCodePage builds it: page numbers by high byte, '_' in unused slots."""
    pages = {}
    for unit in table:
        pages.setdefault(unit >> 8, len(pages) + 1)
    inverse = bytearray(256 + 256 * len(pages))
    inverse[256:] = b'_' * (256 * len(pages))
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
    return (B32[16 | cp >> 19] + B32[cp >> 14 & 31] + B32[cp >> 9 & 31]
            + B32[cp >> 4 & 31] + B32[cp << 1 & 31])


class NameEscapes(unittest.TestCase):
    """The escape routines against an independent model of the escape rules."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.image = load(Path(cls.temp.name) / 'handler.hunk')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.h = Handler(self.image)
        self.addCleanup(self.h.close)

    def text(self, address, size):
        return bytes(self.h.mem.r_block(address, size))

    def put(self, address, data):
        self.h.mem.w_block(address, data + b'\0')

    def set_codepage(self, table):
        """Install a code page, one Unicode value per local character, and its inverse."""
        h = self.h
        forward = b''.join(unit.to_bytes(2, 'big') for unit in table)
        h.mem.w_block(TABLES, forward)
        h.mem.w_block(TABLES + 0x1000, inverse_table(table))
        h.set('CodePage', TABLES)
        h.set('InvCodePage', TABLES + 0x1000)
        return TABLES + 0x1000

    def add_units(self, units, inverse=0):
        """Feed code units to ExAddUnit; return (name, last result, pending high surrogate)."""
        h = self.h
        h.mem.w_block(ENTRY, bytes(C['XMSDE_Sizeof']))
        end, pending, result = ENTRY + C['XMSDE_FullName'], 0, 1
        for unit in units:
            result = h.run('ExAddUnit', d0=unit,
                           regs={7: pending, 9: end, 11: ENTRY, 14: inverse})
            pending, end = h.cpu.r_reg(7) & 0xffff, h.cpu.r_reg(9)
            if not result:
                break
        return self.text(ENTRY + C['XMSDE_FullName'], end - ENTRY - C['XMSDE_FullName']), result, pending

    def test_escape_matches_the_reference_form(self):
        """ExPutEscape writes the same characters as the reference encoder for 0x80 and above, in all three lengths."""
        for cp in samples():
            h = self.h
            h.mem.w_block(ENTRY, bytes(16))
            done = h.run('ExPutEscape', d0=cp, regs={9: ENTRY, 11: ENTRY - C['XMSDE_FullName']})
            want = escape(cp).encode()
            self.assertEqual(done, 1, hex(cp))
            self.assertEqual(self.text(ENTRY, len(want)), want, hex(cp))
            self.assertEqual(h.cpu.r_reg(9), ENTRY + len(want), hex(cp))

    def test_escape_stops_at_the_end_of_the_name(self):
        """ExPutEscape writes nothing and returns 0 when the escape does not fit the 104 bytes of name."""
        h = self.h
        for cp, length in ((0x100, 4), (0x1234, 5), (0x1f600, 6)):
            for used in (104 - length, 104 - length + 1):
                h.mem.w_block(ENTRY, bytes(200))
                start = ENTRY + C['XMSDE_FullName']
                done = h.run('ExPutEscape', d0=cp, regs={9: start + used, 11: ENTRY})
                self.assertEqual(done, int(used == 104 - length), (hex(cp), used))
                self.assertEqual(h.cpu.r_reg(9), start + used + length * done, (hex(cp), used))
                self.assertEqual(self.text(start + used, 1), bytes([37 * done]), (hex(cp), used))

    def test_parse_is_the_inverse_and_rejects_what_the_rules_reject(self):
        """ExParseEscape returns the code point and moves past the escape, or returns -1 and leaves a1 alone, exactly like the reference decoder on valid, odd-cased, overlong, truncated and random digit strings."""
        rng = random.Random(11)
        cases = [escape(cp)[1:] for cp in samples()[:400]]
        cases += [escape(cp)[1:].lower() for cp in samples()[:100]]
        cases += [''.join(rng.choice(B32 + B32.lower() + 'WXYZ-%') for _ in range(rng.randrange(1, 7)))
                  for _ in range(3000)]
        cases += ['', '0', '55', '80', '88', '8800', 'C00', 'G00', '8x0']
        for text in cases:
            h = self.h
            self.put(ENTRY, text.encode())
            got = h.run('ExParseEscape', a1=ENTRY)
            want = unescape(text)
            if want is None:
                self.assertEqual(got, 0xffffffff, text)
                self.assertEqual(h.cpu.r_reg(9), ENTRY, text)
            else:
                self.assertEqual(got, want[0], text)
                self.assertEqual(h.cpu.r_reg(9), ENTRY + want[1], text)

    def test_count_units(self):
        """ExCountUnits counts a valid escape as one unit, an escape above 0xFFFF as two and a stray % as itself."""
        for name, units in (('plain.txt', 9), ('%880.txt', 5), ('a%90Mb', 3), ('%%880', 2),
                            ('%880%882', 2), ('x%1P0.y', 7), ('%55', 3), ('%', 1), ('', 0),
                            (escape(0x1f600) + 'z', 3), ('%8', 2)):
            self.put(ENTRY, name.encode())
            self.assertEqual(self.h.run('ExCountUnits', a0=ENTRY), units, name)

    def test_units_to_name_without_a_code_page(self):
        """ExAddUnit keeps Latin-1 characters, escapes the rest, joins surrogate pairs into one escape and hides names it cannot show."""
        name, result, pending = self.add_units([0x41, 0xe9, 0x100, 0x416, 0xd83d, 0xde00, 0x7a])
        want = 'A\xe9' + escape(0x100) + escape(0x416) + escape(0x1f600) + 'z'
        self.assertEqual((name, result, pending), (want.encode('latin-1'), 1, 0))
        self.assertEqual(self.add_units([0x41, 0xd83d])[2], 0xd83d)
        for units in ([0xde00], [0xd83d, 0x41], [0x41, 0], [0xfffe], [0xd83d, 0xd83d]):
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
        name, result, _ = self.add_units([0x41, 0x104, 0xe9, 0x141, 0x5f, 0x100, 0x2013, 0x1234], inverse)
        self.assertEqual(result, 1)
        self.assertEqual(name, b'A\x80\x81\x82_' + escape(0x100).encode() + b'\x83' + escape(0x1234).encode())

    def test_name_to_units_with_a_code_page(self):
        """ExNextUnit turns code page characters above 0x7F into their Unicode value without the bit that 2*index leaves in the low byte, and decodes escapes including a surrogate pair."""
        self.set_codepage(TABLE)
        text = b'A\x80\x81\x82%880%1P0z'.replace(b'%1P0', escape(0x1f600).encode())
        h = self.h
        self.put(ENTRY, text)
        units, cursor, pending = [], ENTRY, 0
        for _ in range(8):
            units.append(h.run('ExNextUnit', regs={9: cursor, 4: pending, 14: TABLES}) & 0xffff)
            cursor, pending = h.cpu.r_reg(9), h.cpu.r_reg(4) & 0xffff
        self.assertEqual(units, [0x41, 0x104, 0xe9, 0x141, 0x100, 0xd83d, 0xde00, 0x7a])
        self.assertEqual(cursor, ENTRY + len(text))

    def test_parse_limits_of_every_form(self):
        """ExParseEscape agrees with the reference decoder at every limit: smallest and largest code point of each form, the form below and above, surrogate and noncharacter edges, 0x10FFFF and 0x110000, in all forms that can hold the value, upper and lower case."""
        edge = [0x7e, 0x7f, 0x80, 0x81, 0x7ff, 0x800, 0x801, 0xd7fe, 0xd7ff, 0xd800, 0xd801, 0xdbff, 0xdc00,
                0xdffe, 0xdfff, 0xe000, 0xe001, 0xfffc, 0xfffd, 0xfffe, 0xffff, 0x10000, 0x10001,
                0x1fffff - 1, 0x10fffe, 0x10ffff, 0x110000, 0x110001, 0x1fffff]
        cases = []
        for cp in edge:
            for size, limit in ((2, 0x1000), (3, 0x10000), (4, 0x200000)):
                if cp < limit:
                    cases.append(form(cp, size))
                    cases.append(form(cp, size).lower())
        # a digit string longer than the longest form, and a first digit of class 5..7 and 0..1
        cases += ['K200000', 'K000000', 'K000200', 'L000000', 'O00000V', 'S000000', 'V000000', '0', '00', '1V', '1VV',
                  '4', '40', '400', '4000', '40000']
        cases += [B32[c] + 'VVVVV' for c in range(32)]
        cases += [B32[c] + '00000' for c in range(32)]
        cases += [B32[c] + '000' for c in range(32)]
        for text in cases:
            self.put(ENTRY, text.encode())
            got = self.h.run('ExParseEscape', a1=ENTRY)
            want = unescape(text)
            if want is None:
                self.assertEqual(got, 0xffffffff, text)
                self.assertEqual(self.h.cpu.r_reg(9), ENTRY, text)
            else:
                self.assertEqual(got, want[0], text)
                self.assertEqual(self.h.cpu.r_reg(9), ENTRY + want[1], text)

    def test_parse_rejects_the_characters_next_to_the_digit_ranges(self):
        """ExParseEscape does not read ':' '@' '[' '`' '{' and other neighbours of 0-9, A-V, a-v as digits, in any position."""
        for bad in ':;<=>?@[\\]^_`{|}~/ \x00\x80\xb0\xc1\xe1\xff':
            for good in (escape(0x100), escape(0x1234), escape(0x1f600)):
                for pos in range(1, len(good)):
                    text = good[1:pos] + bad + good[pos + 1:]
                    self.put(ENTRY, text.encode('latin-1'))
                    self.assertEqual(self.h.run('ExParseEscape', a1=ENTRY), 0xffffffff, repr(text))
                    self.assertEqual(self.h.cpu.r_reg(9), ENTRY, repr(text))

    def test_add_unit_surrogate_and_range_edges(self):
        """ExAddUnit at the edges of the surrogate ranges: first and last pair, 0xD800 pending, 0xDC00 alone, a second unit just below/above the low range, 0xD7FF and 0xE000 as characters, 0xFFFD ok and 0xFFFF hidden."""
        ok = [
            ([0xd800, 0xdc00], escape(0x10000).encode(), 0),
            ([0xdbff, 0xdfff], escape(0x10ffff).encode(), 0),
            ([0xd7ff], escape(0xd7ff).encode(), 0),
            ([0xe000], escape(0xe000).encode(), 0),
            ([0xfffd], escape(0xfffd).encode(), 0),
            ([0xd800], b'', 0xd800),
            ([0xdbff], b'', 0xdbff),
            ([0x80, 0xff], b'\x80\xff', 0),
        ]
        for units, name, pending in ok:
            self.assertEqual(self.add_units(units), (name, 1, pending), [hex(u) for u in units])
        for units in ([0xdc00], [0xdfff], [0xd800, 0xdbff], [0xd800, 0xe000], [0xdbff, 0xdbff],
                      [0xd800, 0x41], [0xffff], [0xfffe]):
            self.assertEqual(self.add_units(units)[1], 0, [hex(u) for u in units])

    def test_add_unit_pair_to_escape_values(self):
        """Every pair edge gives the escape of the right code point (low, high and middle values of the 10+10 bit split)."""
        for high, low in ((0xd800, 0xdc00), (0xd800, 0xdfff), (0xdbff, 0xdc00), (0xdbff, 0xdfff),
                          (0xd801, 0xdc01), (0xd9ab, 0xdd23), (0xdb40, 0xdc00)):
            cp = 0x10000 + ((high - 0xd800) << 10) + (low - 0xdc00)
            self.assertEqual(self.add_units([high, low]), (escape(cp).encode(), 1, 0), hex(cp))

    def test_add_unit_hides_an_ascii_character_missing_from_the_code_page(self):
        """With a code page that lacks an ASCII character, ExAddUnit hides the name instead of writing an escape for a value below 0x80."""
        table = list(TABLE)
        table[0x41] = 0x1002
        inverse = self.set_codepage(table)
        self.assertEqual(self.add_units([0x41], inverse)[1], 0)
        self.assertEqual(self.add_units([0x42], inverse)[:2], (b'B', 1))

    def test_add_unit_code_page_filler_and_page_lookup(self):
        """With a code page, a character whose page exists but whose slot holds the filler, or whose page does not exist, is escaped, also if its low byte looks like '_' or like a high byte that has a page."""
        inverse = self.set_codepage(TABLE)
        for unit in (0x80, 0x15f, 0x205f, 0x105f, 0x3000, 0x3001, 0x3010, 0x3020, 0x5f00, 0x5f01):
            self.assertEqual(self.add_units([unit], inverse)[:2], (escape(unit).encode(), 1), hex(unit))
        self.assertEqual(self.add_units([0x5f], inverse)[:2], (b'_', 1))


    MAPPED = (list(range(0x61, 0x7b)) + [u for u in range(0xe0, 0xff) if u != 0xf7] + [0xff]
              + list(range(0x101, 0x130, 2)) + list(range(0x3b1, 0x3ca)) + list(range(0x430, 0x460))
              + list(range(0x561, 0x587)) + list(range(0xff41, 0xff5b)))

    def upper(self, unit, cache={}):
        if unit > 0xffff:
            return unit
        if unit not in cache:
            cache[unit] = self.h.run('UpperUnit', d0=unit)
        return cache[unit]

    def test_upper_unit(self):
        """UpperUnit maps the lower case letters of Latin, Greek, Cyrillic, Armenian and full-width ASCII to their Unicode upper case and never maps a unit anywhere else."""
        units = (list(range(0x600)) + list(range(0x1e00, 0x1f00)) + list(range(0x2160, 0x2190))
                 + list(range(0x24c0, 0x24f0)) + list(range(0xff20, 0xff60)) + [0xd800, 0xfffe, 0xffff])
        for unit in units:
            got = self.h.run('UpperUnit', d0=unit)
            if unit in self.MAPPED:
                self.assertEqual(got, ord(chr(unit).upper()), hex(unit))
            elif got != unit:
                self.assertEqual(chr(got), chr(unit).upper(), hex(unit))

    def write_units(self, units, rng, local=None):
        """Amiga text for code units: a byte when the code page (Latin-1 without one) has the unit, else an escape, sometimes with lower-case digits."""
        out = ''
        for unit in units:
            if unit < 0x80:
                out += chr(unit)
            elif local is not None and unit in local:
                out += chr(local[unit])
            elif local is None and unit < 0x100:
                out += chr(unit)
            else:
                e = escape(unit)
                out += e.lower() if rng.random() < 0.3 else e
        return out.encode('latin-1')

    def same_rest(self, disk, wanted, keep_units=False):
        """Call ExSameRest the way LocateObj does, at the first byte pair that differs other than by ASCII case; None when the names never get there. keep_units leaves the wanted name and its units from the call before."""
        h = self.h
        stop = wanted.find(b'/')
        component = wanted if stop < 0 else wanted[:stop]
        for i in range(min(len(disk), len(component))):
            a, b = disk[i], component[i]
            if a == b or (a | 32 == b | 32 and 0x61 <= a | 32 <= 0x7a):
                continue
            self.put(ENTRY, disk)
            if keep_units:
                self.assertEqual(h.mem.r_block(ENTRY + 0x200, len(wanted)), wanted)
            else:
                self.put(ENTRY + 0x200, wanted)
                h.set('WantedStart', 0)
            return h.run('ExSameRest', a0=ENTRY + i + 1, a1=ENTRY + 0x200 + i + 1, a2=ENTRY,
                         regs={14: ENTRY + 0x200})
        return None

    def test_same_rest_is_a_case_blind_compare(self):
        """ExSameRest finds two names equal exactly when their code units are equal after UpperUnit, whether the difference lies inside an escape, in a byte from 0x80 or behind an escape, with or without a code page."""
        rng = random.Random(17)
        pool = [0x41, 0x61, 0x5b, 0x7b, 0x40, 0x60, 0x2e, 0x25, 0x31, 0xe9, 0xc9, 0xd7, 0xf7, 0xff, 0x178, 0xdf,
                0x100, 0x101, 0x131, 0x49, 0x17f, 0x53, 0x3a3, 0x3c2, 0x3c3, 0xb5, 0x39c, 0x3bc, 0x416, 0x436,
                0x417, 0x450, 0x400, 0x104, 0x105, 0x1e00, 0x1e01, 0xff21, 0xff41, 0x24b6, 0x24d0, 0x2160, 0x2170,
                0x1f600, 0x1f601]
        h = self.h
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
                    other.append(0x7a)
                elif rng.random() < 0.1:
                    units.append(rng.choice((0x7a, 0x1f600)))
                disk = self.write_units(units, rng, local)
                wanted = self.write_units(other, rng, local) + (b'/next' if rng.random() < 0.3 else b'')
                got = self.same_rest(disk, wanted)
                if got is None:
                    continue
                checked += 1
                back = {v: k for k, v in local.items()} if local else {}
                def meaning(text):
                    text = text.split(b'/')[0].decode('latin-1')
                    return [self.upper(back.get(u, u)) for u in decode(text)]
                want = meaning(disk) == meaning(wanted)
                self.assertEqual(got, int(want), (disk, wanted))
            self.assertGreater(checked, 800)


    def test_same_rest_keeps_the_wanted_units_for_the_next_entry(self):
        """ExSameRest converts the wanted name once and compares it with every following disk name like a fresh conversion would."""
        rng = random.Random(19)
        h = self.h
        wanted = escape(0x436) + 'big ' + escape(0x101) + '.txt'
        disks = [escape(cp) + 'BIG ' + escape(other) + '.TXT' for cp in (0x416, 0x436, 0x417, 0x100)
                 for other in (0x100, 0x101, 0x102)]
        rng.shuffle(disks)
        self.put(ENTRY + 0x200, wanted.encode())
        h.set('WantedStart', 0)
        for disk in disks:
            want = disk.startswith((escape(0x416), escape(0x436))) and escape(0x102) not in disk
            got = self.same_rest(disk.encode(), wanted.encode(), keep_units=True)
            self.assertEqual(want if got is None else got, int(want), disk)
        self.assertEqual(h.get('WantedStart'), ENTRY + 0x200)

    def sentinels(self, regs, outputs):
        regs = dict(regs)
        for r in (1, 2, 3, 4, 5, 6, 7, 8, 10, 13):
            if r not in regs and r not in outputs:
                regs[r] = 0xa5000000 + r
        return regs

    def assert_preserved(self, regs, outputs, label):
        for r, value in regs.items():
            if r not in outputs:
                self.assertEqual(self.h.cpu.r_reg(r), value, (label, 'register', r))

    def test_escape_routines_keep_the_registers_the_callers_use(self):
        """ExPutEscape and ExAddUnit leave d1-d6 and a0, a2-a6 alone (rxms_conv keeps its counters in d3/d5), ExParseEscape leaves d1-d7 and a0, a2-a6 (ExNextUnit keeps the pending surrogate in d4), on success and on failure; UpperUnit, ExCutEscape and ExSameRest change only their result."""
        h = self.h
        inverse = self.set_codepage(TABLE)
        for cp, used in ((0x100, 0), (0x1234, 0), (0x1f600, 0), (0x100, 102)):
            h.mem.w_block(ENTRY, bytes(200))
            regs = self.sentinels({9: ENTRY + C['XMSDE_FullName'] + used, 11: ENTRY}, (0, 9))
            h.run('ExPutEscape', d0=cp, regs=regs)
            self.assert_preserved(regs, (0, 9), ('ExPutEscape', hex(cp), used))
        for unit, pending, table in ((0x41, 0, 0), (0x100, 0, 0), (0x1234, 0, inverse), (0x41, 0, inverse),
                                     (0xd83d, 0, 0), (0xde00, 0xd83d, 0), (0xde00, 0, 0)):
            h.mem.w_block(ENTRY, bytes(200))
            regs = self.sentinels({7: pending, 9: ENTRY + C['XMSDE_FullName'], 11: ENTRY, 14: table}, (0, 7, 9))
            h.run('ExAddUnit', d0=unit, regs=regs)
            self.assert_preserved(regs, (0, 7, 9), ('ExAddUnit', hex(unit), pending))
        for text in ('880', 'C00', escape(0x1f600)[1:], '8x0', '8', '', '1', 'K200000', 'C01', 'VVVVV'):
            self.put(ENTRY, text.encode())
            regs = self.sentinels({9: ENTRY}, (0, 9))
            h.run('ExParseEscape', regs=regs)
            self.assert_preserved(regs, (0, 9), ('ExParseEscape', text))
        for unit in (0x30, 0x61, 0x416, 0x436, 0x1e05, 0xff41):
            regs = self.sentinels({}, (0,))
            h.run('UpperUnit', d0=unit, regs=regs)
            self.assert_preserved(regs, (0,), ('UpperUnit', hex(unit)))
        for text, cut in (('ab%90M', 5), ('ab%Zq', 4), ('abcdefg', 6)):
            self.put(ENTRY, text[:cut].encode())
            regs = self.sentinels({9: ENTRY + cut}, (0, 9))
            h.run('ExCutEscape', d0=ord(text[cut]), regs=regs)
            self.assert_preserved(regs, (0, 9), ('ExCutEscape', text))
        for disk, wanted, at in ((b'a%90M', b'a%91M', 4), (b'ab', b'ac', 2), (b'a\xe9', b'a\xc9', 2)):
            self.put(ENTRY, disk)
            self.put(ENTRY + 0x200, wanted)
            h.set('WantedStart', 0)
            regs = self.sentinels({8: ENTRY + at, 9: ENTRY + 0x200 + at, 10: ENTRY, 14: ENTRY + 0x200}, (0,))
            h.run('ExSameRest', regs=regs)
            self.assert_preserved(regs, (0,), ('ExSameRest', disk))


    def test_cut_keeps_no_part_of_an_escape(self):
        """ExCutEscape moves the end of a name cut inside an escape back to its %, so the kept text means the same characters as the start of the full name; a % that starts no escape stays."""
        rng = random.Random(13)
        parts = [escape(cp) for cp in samples()[::40]] + ['%', '%Z', '%8', '%9x', '%%', 'a', 'b9', 'Q']
        h = self.h
        for text, cut, want in (('c' * 102 + '%9x', 104, 104), ('c' * 101 + '%90!', 104, 104),
                                ('c' * 101 + '%90M', 104, 101)):
            self.put(ENTRY, text[:cut].encode())
            h.run('ExCutEscape', d0=ord(text[cut]), regs={9: ENTRY + cut})
            self.assertEqual(h.cpu.r_reg(9) - ENTRY, want, text)
        for _ in range(1500):
            text = ''.join(rng.choice(parts) for _ in range(rng.randrange(2, 8))) + 'zzzzzz'
            cut = rng.randrange(1, len(text) - 1)
            self.put(ENTRY, text[:cut].encode())
            h.run('ExCutEscape', d0=ord(text[cut]), regs={9: ENTRY + cut})
            end = h.cpu.r_reg(9) - ENTRY
            kept = text[:end]
            self.assertTrue(cut - 5 <= end <= cut, (text, cut, end))
            self.assertEqual(decode(kept), decode(text)[:len(decode(kept))], (text, cut, end))
            if end < cut:
                self.assertEqual(text[end], '%', (text, cut, end))
                self.assertIsNone(unescape(text[end + 1:cut]), (text, cut, end))
                self.assertTrue(all(c in B32 + B32.lower() for c in text[end + 1:cut + 1]),
                                (text, cut, end))
            else:
                last = text.rfind('%', 0, cut)
                whole = unescape(text[last + 1:]) if last >= 0 else None
                self.assertFalse(whole and last + 1 + whole[1] > cut, (text, cut))

if __name__ == '__main__':
    unittest.main()
