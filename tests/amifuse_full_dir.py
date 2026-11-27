#!/usr/bin/env python3
"""A new object in a directory whose last slot holds a locked entry: open for writing, open for update, CreateDir and Rename create it on FAT12, FAT16 and FAT32 and leave the last entry alone, also when a free slot moves that entry, when the new group starts a new cluster and in a full FAT12/16 root; renaming that last entry keeps its data. fsck.fat and a Python parser read the result back.

Status: handler-in-the-loop tier. Needs amifuse, dosfstools, mtools and the built handler (make fat95-020).
Run: python3 tests/amifuse_full_dir.py"""

import argparse
import os
from pathlib import Path
import tempfile
from amifuse_bridge import RawFatBridge, dirty_memory, okay
from amifuse_fat_names import check_disk, make_image
from toolchain import ROOT

LAST = b"contents of the last entry\n"
NEW = b"written through the new handle\n"


def last_slot(image):
    """The short name in the last slot of the first cluster of directory D."""
    data = Path(image).read_bytes()

    def u16(at):
        return int.from_bytes(data[at : at + 2], "little")

    sector, per_cluster, reserved, copies = u16(11), data[13], u16(14), data[16]
    fat_sectors = u16(22) or int.from_bytes(data[36:40], "little")
    root_sectors = (u16(17) * 32 + sector - 1) // sector
    first_data = reserved + copies * fat_sectors + root_sectors
    size = sector * per_cluster

    def cluster(n):
        at = (first_data + (n - 2) * per_cluster) * sector
        return data[at : at + size]

    if root_sectors:
        root = data[(first_data - root_sectors) * sector : first_data * sector]
    else:
        root = cluster(int.from_bytes(data[44:48], "little"))
    at = next(i for i in range(0, len(root), 32) if root[i : i + 11] == b"D          ")
    entry = root[at : at + 32]
    raw = cluster(
        int.from_bytes(entry[26:28], "little") | int.from_bytes(entry[20:22], "little") << 16
    )
    return raw[-32:-21]


def prepared(tmp, bits, driver):
    """Bridge on an image whose directory D is full, last in its last slot (each name takes two slots)."""
    image = Path(tmp) / ("fat%d.img" % bits)
    make_image(image, bits, {"mv.txt": b"moved file\n"})
    data = image.read_bytes()
    slots = int.from_bytes(data[11:13], "little") * data[13] // 32
    want = {"mv.txt": b"moved file\n", "D": None}
    b = RawFatBridge(image, driver)
    b.free_lock(okay(b.create_dir(0, "D")))
    for i in range((slots - 2) // 2 - 1):  # . and .. take the first two slots
        name = "f%03d" % i
        b.put("/D/" + name, name.encode())
        want["D/" + name] = name.encode()
    b.put("/D/last", LAST)
    want["D/last"] = LAST
    b.flush_volume()
    assert last_slot(image) == b"LAST       ", last_slot(image)
    d, _ = b.locate(0, "D")
    return image, b, d, want


def stop(b, failed):
    """Shut the handler down; a failure there must not hide the one of the case."""
    try:
        b.shutdown_handler()
    except AssertionError:
        if not failed:
            raise
    finally:
        b.close()


def case(driver, bits, op):
    with tempfile.TemporaryDirectory() as tmp:
        image, b, d, want = prepared(tmp, bits, driver)
        failed = True
        try:
            op(b, d, want)
            b.free_lock(d)
            b.flush_volume()
            failed = False
        finally:
            stop(b, failed)
        check_disk(image, want)


def new_file(b, d, want):
    """MODE_NEWFILE beside the last entry, open for writing."""
    held = b.open_file("/D/last", os.O_WRONLY)
    assert held, b.last_reply
    b._neg_cache.clear()
    b.put("/D/new", NEW)
    b.close_file(held[0])
    b.free_lock(held[1])
    want["D/new"] = NEW


def update_file(b, d, want):
    """MODE_READWRITE of a new name beside the last entry, shared lock."""
    lock = okay(b.locate(d, "last"))
    b._neg_cache.clear()
    opened = b.open_file("/D/new", os.O_RDWR | os.O_CREAT)
    assert opened, b.last_reply
    assert b.write_handle(opened[0], NEW) == len(NEW)
    b.close_file(opened[0])
    b.free_lock(opened[1])
    b.free_lock(lock)
    want["D/new"] = NEW


def create_dir(b, d, want):
    """CreateDir beside the locked last entry."""
    lock = okay(b.locate(d, "last"))
    b.free_lock(okay(b.create_dir(d, "sub")))
    b.free_lock(lock)
    want["D/sub"] = None


def rename_in(b, d, want):
    """Rename from the root into D beside the locked last entry."""
    lock = okay(b.locate(d, "last"))
    okay(b.rename_object(0, "mv.txt", d, "moved"))
    b.free_lock(lock)
    want["D/moved"] = want.pop("mv.txt")


def rename_last(b, d, want):
    """Rename of the last entry itself."""
    okay(b.rename_object(d, "last", d, "renamed"))
    want["D/renamed"] = want.pop("D/last")


def exclusive_dir(b, d, want):
    """CreateDir beside the last entry under an exclusive lock."""
    b.launcher.send_locate(b.state, d, b._alloc_bstr("last")[1], -1)
    lock = b._run_until_replies()[-1][2]
    assert lock, b.last_reply
    b.free_lock(okay(b.create_dir(d, "sub")))
    b.free_lock(lock)
    want["D/sub"] = None


def update_new(b, d, lock, name, want):
    b._neg_cache.clear()
    opened = b.open_file("/" + name, os.O_RDWR | os.O_CREAT)
    assert opened, b.last_reply
    assert b.write_handle(opened[0], NEW) == len(NEW)
    b.close_file(opened[0])
    b.free_lock(opened[1])
    b.free_lock(lock)
    want[name] = NEW


def moved_last(b, d, want):
    """A deleted slot early in D: the scan moves the locked last entry down."""
    okay(b.delete_object(d, "f000"))
    want.pop("D/f000")
    update_new(b, d, okay(b.locate(d, "last")), "D/new", want)


def new_cluster(b, d, want):
    """A deleted slot early in D and a new name of three slots: its group starts a new cluster."""
    okay(b.delete_object(d, "f000"))
    want.pop("D/f000")
    update_new(b, d, okay(b.locate(d, "last")), "D/a_rather_long_new_name", want)


OPS = (
    new_file,
    update_file,
    create_dir,
    rename_in,
    rename_last,
    exclusive_dir,
    moved_last,
    new_cluster,
)


def root_full(driver, bits):
    """A FAT12/16 root filled to its last slot, one slot freed, the last entry locked: a new file opened for update."""
    with tempfile.TemporaryDirectory() as tmp:
        image = Path(tmp) / ("root%d.img" % bits)
        make_image(image, bits, {})
        b = RawFatBridge(image, driver)
        failed = True
        try:
            want, i = {}, 0
            while True:
                name = "r%03d" % i
                opened = b.open_file("/" + name, os.O_WRONLY | os.O_CREAT | os.O_TRUNC)
                if not opened:
                    break
                b.write_handle(opened[0], name.encode())
                b.close_file(opened[0])
                b.free_lock(opened[1])
                want[name] = name.encode()
                i += 1
            b.flush_volume()
            data = image.read_bytes()
            sector, reserved, copies = int.from_bytes(data[11:13], "little"), data[14], data[16]
            root = (reserved + copies * int.from_bytes(data[22:24], "little")) * sector
            end = root + int.from_bytes(data[17:19], "little") * 32
            assert data[end - 32 : end - 28] == b"R%03d" % (i - 1), data[end - 32 : end - 21]
            okay(b.delete_object(0, "r000"))
            want.pop("r000")
            update_new(b, 0, okay(b.locate(0, "r%03d" % (i - 1))), "new", want)
            b.flush_volume()
            failed = False
        finally:
            stop(b, failed)
        check_disk(image, want)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--driver", type=Path, default=ROOT / "dist/l/68020/fat95")
    args = ap.parse_args()
    with dirty_memory():
        for bits in (12, 16, 32):
            for op in OPS:
                case(args.driver, bits, op)
                print(f"{op.__name__} FAT{bits}: ok")
        for bits in (12, 16):
            root_full(args.driver, bits)
            print(f"root_full FAT{bits}: ok")


if __name__ == "__main__":
    main()
