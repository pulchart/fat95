#!/usr/bin/env python3
"""ACTION_FORMAT on FAT12, FAT16 and FAT32 images: fsck.fat accepts the result and the boot sectors carry the boot code stub.

Status: handler-in-the-loop tier, run by make test-amifuse. Needs amifuse, dosfstools and a prior make fat95-020; nasm is optional and adds a byte comparison against tools/bootstub.asm.
Run: python3 tests/amifuse_format.py"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from amifuse_bridge import RawFatBridge
from amifuse_images import PROFILES, create_image, inspect_image
from toolchain import ROOT

DOSTYPE_FAT = 0x46415400
MESSAGE = b'Not a bootable disk\r\n'
STUB_OFFSET = {12: 0x3E, 16: 0x3E, 32: 0x5A}
FSINFO_BLOCK, BACKUP_BOOT, EXT_BOOT, EXT_BOOT_BACKUP = 1, 6, 2, 8


def format_image(image, driver):
    """Inhibit, format and release the volume through DOS packets."""
    b = RawFatBridge(image, driver)
    try:
        b.launcher.send_inhibit(b.state, True)
        b._run_until_replies()
        _, name = b.launcher.alloc_bstr('FMTTEST', label='FormatVolName')
        b.launcher.send_format(b.state, name, DOSTYPE_FAT)
        reply = b._run_until_replies(max_iters=2000, cycles=2_000_000)[-1]
        assert reply[2] != 0, f'format failed: {reply[2:]}'
        b.launcher.send_inhibit(b.state, False)
        b._run_until_replies()
        b.shutdown_handler()
    finally:
        b.close()


def stub_bytes():
    """Raw stub from tools/bootstub.asm, or None without nasm."""
    if not shutil.which('nasm'):
        return None
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / 'stub.bin'
        subprocess.run([sys.executable, '-I', str(ROOT / 'tools/bootstub.py'), '--bin', str(out)],
                       check=True, capture_output=True)
        return out.read_bytes()


def sector(data, number):
    return data[number * 512:(number + 1) * 512]


def check_boot_sector(boot, bits, stub):
    """Signature, stub at the code offset, message text and zero padding."""
    assert boot[510:512] == b'\x55\xaa', boot[510:512]
    start = STUB_OFFSET[bits]
    assert boot[0] == 0xEB and boot[1] == start - 2 and boot[2] == 0x90, boot[:3]
    assert boot[start] == 0xFA, 'boot code does not start at the BPB end'
    assert MESSAGE in boot[start:], 'message missing'
    end = boot.index(MESSAGE, start) + len(MESSAGE) + len(b'Press a key to reboot\r\n') + 1
    assert not any(boot[end:510]), 'bytes after the stub are not zero'
    if stub is not None:
        assert boot[start:start + len(stub)] == stub, 'boot code differs from tools/bootstub.asm'


def case(profile, driver):
    bits = PROFILES[profile][0]
    with tempfile.TemporaryDirectory() as d:
        image = Path(d) / 'disk.img'
        create_image(image, profile)
        format_image(image, driver)
        fsck = subprocess.run(['fsck.fat', '-n', str(image)], capture_output=True, text=True, timeout=60)
        assert fsck.returncode == 0, fsck.stdout + fsck.stderr
        assert inspect_image(image).fat_bits == bits
        data = image.read_bytes()[:16 * 512]
        check_boot_sector(sector(data, 0), bits, stub_bytes())
        if bits == 32:
            assert sector(data, BACKUP_BOOT) == sector(data, 0), 'backup boot sector differs'
            tail = b'\x00' * 508 + b'\x00\x00\x55\xaa'
            assert sector(data, EXT_BOOT) == tail, 'extended boot sector'
            assert sector(data, EXT_BOOT_BACKUP) == tail, 'backup extended boot sector'
            assert sector(data, FSINFO_BLOCK)[:4] == b'RRaA'


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--driver', type=Path, default=ROOT / 'dist/l/68020/fat95')
    args = ap.parse_args()
    for profile in PROFILES:
        case(profile, args.driver)
        print(f'format {profile}: ok')


if __name__ == '__main__':
    sys.exit(main())
