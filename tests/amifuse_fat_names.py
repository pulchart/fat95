#!/usr/bin/env python3
"""FAT long names with characters outside the code page: the built handler shows them as %-escapes and opens, creates, renames and deletes the right file; a Python parser and fsck.fat read the result back.

Status: handler-in-the-loop tier. Needs amifuse, dosfstools, mtools and the built handler (make fat95-020).
Run: python3 tests/amifuse_fat_names.py"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
from amifuse_bridge import RawFatBridge, dirty_memory, escaped, okay
from toolchain import ROOT

ENV = {**os.environ, 'LANG': 'C.UTF-8', 'MTOOLS_SKIP_CHECK': '1', 'MTOOLSRC': os.devnull}


def mtools(image, *args, **kw):
    return subprocess.run(args[:1] + ('-i', str(image)) + args[1:], env=ENV, check=True, **kw)


def make_image(path, bits, files):
    """A FAT image of bits 16 or 32 holding the files (name -> bytes) with the names mtools writes as UTF-16."""
    with open(path, 'wb') as image:
        image.truncate(64 * 1024 * 1024)
    subprocess.run(['mkfs.fat', '--invariant', '-F', str(bits), '-S', '512', str(path)],
                   check=True, capture_output=True)
    for name, data in files.items():
        source = Path(path).with_suffix('.src')
        source.write_bytes(data)
        mtools(path, 'mcopy', str(source), '::/' + name)
        source.unlink()


def on_disk(image):
    """Files in the root directory (long name -> contents), read by a small parser that checks every long name checksum."""
    data = Path(image).read_bytes()
    u16 = lambda at: int.from_bytes(data[at:at + 2], 'little')
    u32 = lambda at: int.from_bytes(data[at:at + 4], 'little')
    sector, per_cluster, reserved, copies = u16(11), data[13], u16(14), data[16]
    fat_sectors = u16(22) or u32(36)
    root_sectors = (u16(17) * 32 + sector - 1) // sector
    fat32 = u16(17) == 0
    first_data = reserved + copies * fat_sectors + root_sectors

    def chain(cluster):
        while 2 <= cluster < 0x0ffffff8:
            yield cluster
            at = reserved * sector + cluster * (4 if fat32 else 2)
            cluster = (u32(at) & 0x0fffffff) if fat32 else u16(at)

    def cluster_data(cluster):
        start = (first_data + (cluster - 2) * per_cluster) * sector
        return data[start:start + per_cluster * sector]

    if fat32:
        raw = b''.join(cluster_data(c) for c in chain(u32(44)))
    else:
        start = (reserved + copies * fat_sectors) * sector
        raw = data[start:start + root_sectors * sector]
    files, pieces = {}, {}
    for at in range(0, len(raw), 32):
        entry = raw[at:at + 32]
        if entry[0] == 0:
            break
        if entry[0] == 0xe5:
            pieces = {}
            continue
        if entry[11] == 0x0f:
            pieces[entry[0] & 0x1f] = (entry[13], entry[1:11] + entry[14:26] + entry[28:32])
            continue
        if entry[11] & 0x08:
            continue
        if pieces:
            check = 0
            for byte in entry[:11]:
                check = ((check >> 1) + ((check & 1) << 7) + byte) & 0xff
            assert {c for c, _ in pieces.values()} == {check}, 'long name checksum'
            text = b''.join(units for _, (_, units) in sorted(pieces.items())).decode('utf-16-le')
            name = text.split('\0', 1)[0]
        else:
            base, ext = entry[:8].decode('latin-1').rstrip(), entry[8:11].decode('latin-1').rstrip()
            name = (base.lower() if entry[12] & 8 else base) + ('.' + (ext.lower() if entry[12] & 16 else ext) if ext else '')
        first = int.from_bytes(entry[26:28], 'little') | (int.from_bytes(entry[20:22], 'little') << 16)
        size = int.from_bytes(entry[28:32], 'little')
        content = b''.join(cluster_data(c) for c in chain(first))[:size] if size else b''
        files[name] = content
        pieces = {}
    return files


def case_names(driver, bits):
    """Names outside Latin-1 are unique %-escapes that open, write, create, rename and delete the right file on FAT16 and FAT32, and fsck.fat finds nothing wrong."""
    names = {'_Aa.txt': b'real underscore', 'Aa.txt': b'ascii', 'Name with spaces.txt': b'spaces',
             '\u0100a.txt': b'a macron', '\u0416-two.txt': b'zhe',
             'a' * 30 + '\u0100' * 10 + '.dat': b'long'}
    with tempfile.TemporaryDirectory() as d:
        image = Path(d) / 'un.img'
        make_image(image, bits, names)
        assert {k: v for k, v in on_disk(image).items()} == {k: v for k, v in names.items()}
        b = RawFatBridge(image, driver)
        try:
            shown = sorted(e['name'] for e in b.list_dir_path('/'))
            assert shown == sorted(escaped(n) for n in names), shown
            for name, data in names.items():
                assert b.read_file('/' + escaped(name), 100, 0) == data, name
            assert b.read_file('/%90m-two.txt', 100, 0) == b'zhe'
            b.put('/' + escaped('\u0102a.txt'), b'a breve')  # '_a.txt' for both without escapes
            b.put('/' + escaped('\u0102a.txt'), b'changed')
            names['\u0102a.txt'] = b'changed'
            assert b.read_file('/' + escaped('\u0100a.txt'), 100, 0) == b'a macron'
            b.put('/' + escaped('\u0416-new.txt'), b'new zhe')
            names['\u0416-new.txt'] = b'new zhe'
            b.put('/' + escaped('x\U0001f680y.bin'), b'rocket')
            names['x\U0001f680y.bin'] = b'rocket'
            okay(b.rename_object(0, escaped('\u0416-two.txt'), 0, 'plain.txt'))
            names['plain.txt'] = names.pop('\u0416-two.txt')
            okay(b.rename_object(0, 'Aa.txt', 0, escaped('\u03b1\u2013.txt')))
            names['\u03b1\u2013.txt'] = names.pop('Aa.txt')
            okay(b.delete_object(0, escaped('\u0100a.txt')))
            del names['\u0100a.txt']
            b.flush_volume()
            shown = sorted(e['name'] for e in b.list_dir_path('/'))
            assert shown == sorted(escaped(n) for n in names), shown
        finally:
            b.shutdown_handler()
            b.close()
        check = subprocess.run(['fsck.fat', '-n', str(image)], capture_output=True, text=True)
        assert check.returncode == 0, check.stdout + check.stderr
        assert on_disk(image) == names, sorted(set(on_disk(image).items()) ^ set(names.items()))


CASES = [lambda driver: case_names(driver, 16), lambda driver: case_names(driver, 32)]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--driver', type=Path, default=ROOT / 'dist/l/68020/fat95')
    args = ap.parse_args()
    with dirty_memory():
        for bits, case in zip((16, 32), CASES):
            case(args.driver)
            print(f'case_names FAT{bits}: ok')


if __name__ == '__main__':
    main()
