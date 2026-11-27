#!/usr/bin/env python3
"""FAT long names with characters outside the code page: the built handler shows them as %-escapes and lists, opens, edits, creates, renames and deletes the right file or directory on FAT12, FAT16 and FAT32; a Python parser and fsck.fat read the result back.

Status: handler-in-the-loop tier. Needs amifuse, dosfstools, mtools and the built handler (make fat95-020).
Run: python3 tests/amifuse_fat_names.py"""

import argparse
import datetime
import os
from pathlib import Path
import re
import subprocess
import tempfile
from amifuse_bridge import RawFatBridge, dirty_memory, escaped, okay
from toolchain import ROOT

ENV = {**os.environ, "LANG": "C.UTF-8", "MTOOLS_SKIP_CHECK": "1", "MTOOLSRC": os.devnull}
OFFSET_END = 1


def mtools(image, *args, **kw):
    return subprocess.run(args[:1] + ("-i", str(image)) + args[1:], env=ENV, check=True, **kw)


def make_image(path, bits, files):
    """A FAT image of bits 12, 16 or 32 holding the files (name -> bytes) with the names mtools writes as UTF-16."""
    with open(path, "wb") as image:
        image.truncate((8 if bits == 12 else 64) * 1024 * 1024)
    subprocess.run(
        ["mkfs.fat", "--invariant", "-F", str(bits), "-S", "512", str(path)],
        check=True,
        capture_output=True,
    )
    for name, data in files.items():
        source = Path(path).with_suffix(".src")
        source.write_bytes(data)
        mtools(path, "mcopy", str(source), "::/" + name)
        source.unlink()


def scan(image):
    """Every file and directory (path -> (attributes, time, date, contents or None)), read by a small parser that checks every long name checksum."""
    data = Path(image).read_bytes()

    def u16(at):
        return int.from_bytes(data[at : at + 2], "little")

    def u32(at):
        return int.from_bytes(data[at : at + 4], "little")

    sector, per_cluster, reserved, copies = u16(11), data[13], u16(14), data[16]
    fat_sectors = u16(22) or u32(36)
    root_sectors = (u16(17) * 32 + sector - 1) // sector
    fat32 = u16(17) == 0
    first_data = reserved + copies * fat_sectors + root_sectors
    fat12 = not fat32 and ((u16(19) or u32(32)) - first_data) // per_cluster < 4085
    fat = reserved * sector

    def chain(cluster):
        while 2 <= cluster < (0xFF8 if fat12 else 0xFFF8 if not fat32 else 0x0FFFFFF8):
            yield cluster
            if fat32:
                cluster = u32(fat + cluster * 4) & 0x0FFFFFFF
            elif fat12:
                pair = u16(fat + cluster * 3 // 2)
                cluster = pair >> 4 if cluster & 1 else pair & 0xFFF
            else:
                cluster = u16(fat + cluster * 2)

    def cluster_data(cluster):
        start = (first_data + (cluster - 2) * per_cluster) * sector
        return data[start : start + per_cluster * sector]

    def walk(raw, prefix, found):
        pieces = {}
        for at in range(0, len(raw), 32):
            entry = raw[at : at + 32]
            if entry[0] == 0:
                break
            if entry[0] == 0xE5:
                pieces = {}
                continue
            if entry[11] == 0x0F:
                pieces[entry[0] & 0x1F] = (entry[13], entry[1:11] + entry[14:26] + entry[28:32])
                continue
            if entry[11] & 0x08 or entry[0] == 0x2E:
                pieces = {}
                continue
            if pieces:
                check = 0
                for byte in entry[:11]:
                    check = ((check >> 1) + ((check & 1) << 7) + byte) & 0xFF
                assert {c for c, _ in pieces.values()} == {check}, "long name checksum"
                text = b"".join(units for _, (_, units) in sorted(pieces.items())).decode(
                    "utf-16-le"
                )
                name = text.split("\0", 1)[0]
            else:
                base, ext = (
                    entry[:8].decode("latin-1").rstrip(),
                    entry[8:11].decode("latin-1").rstrip(),
                )
                name = (base.lower() if entry[12] & 8 else base) + (
                    "." + (ext.lower() if entry[12] & 16 else ext) if ext else ""
                )
            first = int.from_bytes(entry[26:28], "little") | (
                int.from_bytes(entry[20:22], "little") << 16
            )
            stamp = (
                entry[11],
                int.from_bytes(entry[22:24], "little"),
                int.from_bytes(entry[24:26], "little"),
            )
            path = prefix + name
            if entry[11] & 0x10:
                found[path] = stamp + (None,)
                walk(b"".join(cluster_data(c) for c in chain(first)), path + "/", found)
            else:
                size = int.from_bytes(entry[28:32], "little")
                content = b"".join(cluster_data(c) for c in chain(first))[:size] if size else b""
                found[path] = stamp + (content,)
            pieces = {}
        return found

    if fat32:
        raw = b"".join(cluster_data(c) for c in chain(u32(44)))
    else:
        start = (reserved + copies * fat_sectors) * sector
        raw = data[start : start + root_sectors * sector]
    return walk(raw, "", {})


def on_disk(image):
    """Files and directories (path -> contents, None for a directory)."""
    return {path: entry[3] for path, entry in scan(image).items()}


def shown_tree(b, path=""):
    """Files and directories as the handler lists them (path -> contents, None for a directory)."""
    tree = {}
    for e in b.list_dir_path(path or "/"):
        full = path + "/" + e["name"]
        if e["dir_type"] > 0:
            tree[full[1:]] = None
            tree.update(shown_tree(b, full))
        else:
            tree[full[1:]] = b.read_file(full, e["size"] + 1, 0)
    return tree


def as_shown(want):
    return {escaped(path): data for path, data in want.items()}


def mkdir(b, path):
    lock = okay(b.create_dir(0, escaped(path)))
    b.free_lock(lock)


def edit_in_place(b, want, name):
    """Overwrite the middle, append at the end and cut a file that already exists, through one handle opened by its escaped name."""
    handle, lock = b.open_file("/" + escaped(name), os.O_RDWR)
    try:
        assert b.write_handle_at(handle, 1000, b"X" * 100) == 100
        b.seek_handle(handle, 0, OFFSET_END)
        assert b.write_handle(handle, b"tail") == 4
        assert b.set_handle_size(handle, 2500) >= 0
    finally:
        b.close_file(handle)
        if lock:
            b.free_lock(lock)
    data = want[name]
    want[name] = (data[:1000] + b"X" * 100 + data[1100:] + b"tail")[:2500]
    assert b.read_file("/" + escaped(name), 4000, 0) == want[name]


def directories(b, want):
    """Directories with escaped names: create, nest, fill, list, move a file in, rename, delete."""
    one, nested = "\u0414ir one", "\u0414ir one/\u03c8 nested"
    mkdir(b, one)
    mkdir(b, nested)
    want[one] = want[nested] = None
    for path, data in (
        ("/\u0444.bin", b"ef"),
        ("/\u03c8 nested/\U0001f600 deep.txt", b"deep"),
        ("/plain.txt", b"plain"),
    ):
        b.put("/" + escaped(one + path), data)
        want[one + path] = data
    shown = sorted(e["name"] for e in b.list_dir_path("/" + escaped(one)))
    assert shown == sorted(escaped(n) for n in ("\u0444.bin", "\u03c8 nested", "plain.txt")), shown
    assert b.read_file("/" + escaped(nested + "/\U0001f600 deep.txt"), 100, 0) == b"deep"
    okay(b.rename_object(0, escaped("\u0416-move.txt"), 0, escaped(one + "/\u0416-moved.txt")))
    want[one + "/\u0416-moved.txt"] = want.pop("\u0416-move.txt")
    okay(b.rename_object(0, escaped(nested), 0, escaped(one + "/\u03a9 renamed")))
    for path in [p for p in want if p == nested or p.startswith(nested + "/")]:
        want[one + "/\u03a9 renamed" + path[len(nested) :]] = want.pop(path)
    mkdir(b, "\u00dc \u0113 empty")
    okay(b.delete_object(0, escaped("\u00dc \u0113 empty")))
    okay(b.delete_object(0, escaped(one + "/\u0444.bin")))
    del want[one + "/\u0444.bin"]
    okay(b.rename_object(0, escaped(one), 0, escaped("\u0414ir two")))
    for path in [p for p in want if p == one or p.startswith(one + "/")]:
        want["\u0414ir two" + path[len(one) :]] = want.pop(path)


def literal_percent(b, want):
    """A % that does not start a valid escape stands for itself, one that would shows as %%: such names from the disk open and rename, the handler creates them, lower-case escape digits create the character."""
    for name in (
        "100% done.txt",
        "%ZZ name.txt",
        "%8 short.txt",
        "a%%b long.txt",
        "%880 only ascii.txt",
    ):
        assert b.read_file("/" + escaped(name), 100, 0) == want[name], name
    for name, data in (("50% off.txt", b"fifty"), ("%G00 literal.txt", b"g"), ("x%9.txt", b"nine")):
        b.put("/" + name, data)
        want[name] = data
    b.put("/%91m-lower.txt", b"small zhe")
    want["\u0436-lower.txt"] = b"small zhe"
    okay(b.rename_object(0, "100% done.txt", 0, "100% " + escaped("\u0416.txt")))
    want["100% \u0416.txt"] = want.pop("100% done.txt")


def examine_name(b, lock):
    """The name ACTION_EXAMINE_OBJECT returns for a lock."""
    from amifuse.fuse_fs import _parse_fib

    fib = b._alloc_fib()
    b.launcher.send_examine(b.state, lock, fib.addr)
    okay(b._run_until_replies()[-1][2:])
    return _parse_fib(b.mem, fib.addr)["name"]


def percent_pairs(b, want, tail):
    """A literal % name and the character its text would read as list apart and open their own file; %% opens, creates and renames the literal name, a % that starts no escape stays single; a new directory examines under the name the listing shows."""
    literal, char = "%880" + tail, "\u0100" + tail
    shown = {e["name"] for e in b.list_dir_path("/")}
    assert {"%%880" + tail, "%880" + tail, "100%" + tail, "a%%%b" + tail} <= shown, shown
    assert b.read_file("/%%880" + tail, 100, 0) == want[literal]
    assert b.read_file("/%880" + tail, 100, 0) == want[char]
    assert b.read_file("/%%880" + tail.upper(), 100, 0) == want[literal]
    assert b.read_file("/100%%" + tail, 100, 0) == want["100%" + tail]  # %% where % would do
    assert b.read_file("/a%%%%b" + tail, 100, 0) == want["a%%b" + tail]
    b.put("/%%880" + tail, b"literal again")
    want[literal] = b"literal again"
    assert b.read_file("/%880" + tail, 100, 0) == want[char]
    b.put("/%%881 new.txt", b"new literal")
    want["%881 new.txt"] = b"new literal"
    b.put("/%%%880 mixed.txt", b"mixed")
    want["%\u0100 mixed.txt"] = b"mixed"
    b.put("/ends in %", b"end")
    want["ends in %"] = b"end"
    assert b.read_file("/ends in %%", 100, 0) == b"end"
    b.put("/ends in %%", b"end again")
    want["ends in %"] = b"end again"
    for typed, name in (
        ("x%%y dir", "x%y dir"),
        ("%90m%%" + tail, "\u0416%" + tail),
        ("%%%%880 dir", "%%880 dir"),
    ):
        lock = okay(b.create_dir(0, typed))
        try:
            assert examine_name(b, lock) == escaped(name), (typed, examine_name(b, lock))
        finally:
            b.free_lock(lock)
        assert escaped(name) in {e["name"] for e in b.list_dir_path("/")}, name
        want[name] = None
    okay(b.rename_object(0, "%%880" + tail, 0, "%%%%%880 renamed.txt"))
    want["%%\u0100 renamed.txt"] = want.pop(literal)
    assert b.open_file("/%%880" + tail, os.O_RDONLY) is None
    assert b.read_file("/" + escaped(char), 100, 0) == want[char]


def percent_start(tail):
    """Names for percent_pairs: a literal %880, the character it reads as, a % before a dot, two literal %."""
    return {
        "%880" + tail: b"literal",
        "\u0100" + tail: b"a macron",
        "100%" + tail: b"hundred",
        "a%%b" + tail: b"two",
    }


def case_percent(driver, bits):
    """A long name with a literal %880 and one with the character it reads as, and the 8.3 name %880.TXT, each list and open distinctly; %% creates and renames literal names."""
    start = percent_start(" pair.txt")
    short = {"%880.txt": b"short", "%%x.txt": b"short pair"}
    want = dict(start)
    with tempfile.TemporaryDirectory() as d:
        image = Path(d) / "pct.img"
        make_image(image, bits, start | short)
        assert on_disk(image) == start | short
        b = RawFatBridge(image, driver)
        try:
            assert {"%%880.TXT", "%%%X.TXT"} <= {e["name"] for e in b.list_dir_path("/")}
            assert b.read_file("/%%880.txt", 100, 0) == b"short"
            assert b.open_file("/%880.txt", os.O_RDONLY) is None
            assert b.read_file("/%%%x.txt", 100, 0) == b"short pair"
            percent_pairs(b, want, " pair.txt")
            b.flush_volume()
        finally:
            b.shutdown_handler()
            b.close()
        b = RawFatBridge(image, driver)
        try:
            tree = shown_tree(b)
            assert {
                k: v for k, v in tree.items() if k not in ("%%880.TXT", "%%%X.TXT")
            } == as_shown(want), tree
        finally:
            b.shutdown_handler()
            b.close()
        check_disk(image, want | short)


CASE_START = {
    "\u0416 big.txt": b"zhe",
    "\u0100 macron.txt": b"a macron",
    "a[1] long.txt": b"square",
    "x\u00d7 long.txt": b"times",
    "\u00ff long.txt": b"y diaeresis",
    "\u00c9t\u00e9 long.txt": b"ete",
    "\u00ff" + "a" * 36: b"37 bytes",
}  # the length byte before the name is a %


def case_blind(b, want):
    """Names match regardless of case beyond ASCII: the other case opens, overwrites, renames and deletes the file and a new directory of that name fails with 203; characters that only share bit 5 are different names."""
    for name, other in (
        ("\u0416 big.txt", "\u0436 BIG.txt"),
        ("\u0100 macron.txt", "\u0101 MACRON.txt"),
        ("\u00c9t\u00e9 long.txt", "\u00e9T\u00c9 LONG.txt"),
        ("\u00ff long.txt", "\u0178 LONG.txt"),
    ):
        assert b.read_file("/" + escaped(other), 100, 0) == want[name], other
    assert b.read_file("/%91m big.txt", 100, 0) == want["\u0416 big.txt"]
    assert b.read_file("/" + escaped("\u0178" + "a" * 36), 100, 0) == b"37 bytes"
    mkdir(b, "\u0416 sub")
    b.put("/" + escaped("\u0416 sub/\u00ff" + "a" * 36), b"in sub")
    assert b.read_file("/" + escaped("\u0436 SUB/\u0178" + "a" * 36), 100, 0) == b"in sub"
    want["\u0416 sub"] = None
    want["\u0416 sub/\u00ff" + "a" * 36] = b"in sub"
    assert b.create_dir(0, escaped("\u0436 big.txt")) == (0, 203)
    b.put("/" + escaped("\u0436 BIG.txt"), b"overwritten")
    want["\u0416 big.txt"] = b"overwritten"
    okay(b.rename_object(0, escaped("\u0416 big.txt"), 0, escaped("\u0436 big.txt")))
    want["\u0436 big.txt"] = want.pop("\u0416 big.txt")
    okay(b.delete_object(0, escaped("\u0101 MACRON.txt")))
    del want["\u0100 macron.txt"]
    for name in ("a{1} long.txt", "x\u00f7 long.txt", "\u00df long.txt"):
        assert b.open_file("/" + name, os.O_RDONLY) is None, name
        b.put("/" + name, name.encode("utf-8"))
        want[name] = name.encode("utf-8")


def name_limit(b, want):
    """A name of exactly 104 bytes with an escape is created and opened by that name; a longer one is cut before an escape the limit splits, and a % that starts no escape stays."""
    name = "c" * 100 + "\u0416"
    assert len(escaped(name)) == 104
    b.put("/" + escaped(name), b"104")
    want[name] = b"104"
    assert b.read_file("/" + escaped(name), 100, 0) == b"104"
    for name, kept in (
        ("c" * 101 + escaped("\u0416"), "c" * 101),
        ("d" * 100 + escaped("\U0001f600"), "d" * 100),
        ("e" * 103 + "%Zq", "e" * 103 + "%"),
    ):
        b.put("/" + name, kept[:1].encode())
        want[kept] = kept[:1].encode()
        assert b.read_file("/" + name, 100, 0) == want[kept]
    folder = "f" * 102 + escaped("\u0416")
    mkdir(b, "f" * 102 + "\u0416")
    b.put("/" + folder + "/inner.txt", b"inner")
    want["f" * 102] = None
    want["f" * 102 + "/inner.txt"] = b"inner"


def attributes(b, name):
    """Protection bits and a date set through the escaped name reach the entry."""
    _, bname = b._alloc_bstr(escaped(name))
    b.launcher.send_packet(b.state, 21, [0, 0, bname, 5])  # ACTION_SET_PROTECT: no write, no delete
    okay(b._run_until_replies()[-1][2:])
    stamp = b.vh.alloc.alloc_memory(12, label="stamp")
    for offset, value in zip((0, 4, 8), STAMP, strict=True):
        b.mem.w32(stamp.addr + offset, value)
    b.launcher.send_packet(b.state, 34, [0, 0, bname, stamp.addr])  # ACTION_SET_DATE
    okay(b._run_until_replies()[-1][2:])
    assert b.stat_path("/" + escaped(name))["protection"] & 5 == 5


STAMP = (17000, 60 * 13 + 7, 50 * 21)  # days, minutes, ticks


def fat_stamp(days, minutes, ticks):
    day = datetime.date(1978, 1, 1) + datetime.timedelta(days=days)
    return (
        (minutes // 60) << 11 | (minutes % 60) << 5 | ticks // 50 // 2,
        (day.year - 1980) << 9 | day.month << 5 | day.day,
    )


def check_disk(image, want):
    check = subprocess.run(["fsck.fat", "-n", str(image)], capture_output=True, text=True)
    assert check.returncode == 0, check.stdout + check.stderr
    found = on_disk(image)
    assert found == want, sorted(set(found.items()) ^ set(want.items()))


def case_names(driver, bits):
    """Names outside Latin-1 are unique %-escapes that open, write, create, rename and delete the right file, and fsck.fat finds nothing wrong."""
    names = {
        "_Aa.txt": b"real underscore",
        "Aa.txt": b"ascii",
        "Name with spaces.txt": b"spaces",
        "\u0100a.txt": b"a macron",
        "\u0416-two.txt": b"zhe",
        "a" * 30 + "\u0100" * 10 + ".dat": b"long",
    }
    with tempfile.TemporaryDirectory() as d:
        image = Path(d) / "un.img"
        make_image(image, bits, names)
        assert on_disk(image) == names
        b = RawFatBridge(image, driver)
        try:
            shown = sorted(e["name"] for e in b.list_dir_path("/"))
            assert shown == sorted(escaped(n) for n in names), shown
            for name, data in names.items():
                assert b.read_file("/" + escaped(name), 100, 0) == data, name
            assert b.read_file("/%90m-two.txt", 100, 0) == b"zhe"
            b.put("/" + escaped("\u0102a.txt"), b"a breve")  # '_a.txt' for both without escapes
            b.put("/" + escaped("\u0102a.txt"), b"changed")
            names["\u0102a.txt"] = b"changed"
            assert b.read_file("/" + escaped("\u0100a.txt"), 100, 0) == b"a macron"
            b.put("/" + escaped("\u0416-new.txt"), b"new zhe")
            names["\u0416-new.txt"] = b"new zhe"
            b.put("/" + escaped("x\U0001f680y.bin"), b"rocket")
            names["x\U0001f680y.bin"] = b"rocket"
            okay(b.rename_object(0, escaped("\u0416-two.txt"), 0, "plain.txt"))
            names["plain.txt"] = names.pop("\u0416-two.txt")
            okay(b.rename_object(0, "Aa.txt", 0, escaped("\u03b1\u2013.txt")))
            names["\u03b1\u2013.txt"] = names.pop("Aa.txt")
            okay(b.delete_object(0, escaped("\u0100a.txt")))
            del names["\u0100a.txt"]
            b.flush_volume()
            shown = sorted(e["name"] for e in b.list_dir_path("/"))
            assert shown == sorted(escaped(n) for n in names), shown
        finally:
            b.shutdown_handler()
            b.close()
        check_disk(image, names)


def case_work(driver, bits):
    """Directories, edits in place, literal % names, the 104-byte limit and attributes with escaped names; a remount lists the same tree."""
    start = {
        "\u0416-move.txt": b"move me",
        "\u0416-data.bin": bytes(range(256)) * 12,
        "\u0416-attr.txt": b"attributes",
        "100% done.txt": b"hundred",
        "%ZZ name.txt": b"zz",
        "%8 short.txt": b"eight",
        "a%%b long.txt": b"two percent",
        "%880 only ascii.txt": b"ascii percent",
        "a" * 100 + "\u0416": b"fits",
    } | CASE_START
    want = dict(start)
    with tempfile.TemporaryDirectory() as d:
        image = Path(d) / "work.img"
        make_image(image, bits, start)
        b = RawFatBridge(image, driver)
        try:
            assert shown_tree(b) == as_shown(want)
            edit_in_place(b, want, "\u0416-data.bin")
            directories(b, want)
            literal_percent(b, want)
            name_limit(b, want)
            case_blind(b, want)
            attributes(b, "\u0416-attr.txt")
            b.flush_volume()
        finally:
            b.shutdown_handler()
            b.close()
        b = RawFatBridge(image, driver)
        try:
            assert shown_tree(b) == as_shown(want)
        finally:
            b.shutdown_handler()
            b.close()
        check_disk(image, want)
        attr, time, date, _ = scan(image)["\u0416-attr.txt"]
        assert attr & 1, hex(attr)
        assert (time, date) == fat_stamp(*STAMP), (hex(time), hex(date))


def case_long_name(driver, bits):
    """A long name above 104 bytes with its escapes shows as the short name, which opens and renames it."""
    with tempfile.TemporaryDirectory() as d:
        image = Path(d) / "long.img"
        make_image(image, bits, {"a" * 101 + "\u0416": b"too long", "fits long.txt": b"fits"})
        b = RawFatBridge(image, driver)
        try:
            shown = sorted(e["name"] for e in b.list_dir_path("/"))
            assert (
                len(shown) == 2
                and shown[1] == "fits long.txt"
                and re.fullmatch(r"AAAAAA~\d", shown[0])
            ), shown
            assert b.read_file("/" + shown[0], 100, 0) == b"too long"
            okay(b.rename_object(0, shown[0], 0, "short.txt"))
            b.flush_volume()
        finally:
            b.shutdown_handler()
            b.close()
        check_disk(image, {"short.txt": b"too long", "fits long.txt": b"fits"})


CASES = [
    (case, bits)
    for bits in (12, 16, 32)
    for case in (case_names, case_work, case_long_name, case_percent)
]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--driver", type=Path, default=ROOT / "dist/l/68020/fat95")
    args = ap.parse_args()
    with dirty_memory():
        for case, bits in CASES:
            case(args.driver, bits)
            print(f"{case.__name__} FAT{bits}: ok")


if __name__ == "__main__":
    main()
