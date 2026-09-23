"""Reproducible FAT fixtures and the independent oracle that checks them: a pure-Python FAT parser plus fsck.fat and mtools. Images are unpartitioned regular files; never pass a device path.

Status: library for the handler-in-the-loop tier."""
from dataclasses import dataclass
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import tempfile


PROFILES = {
    'fat12_720': (12, 720 * 1024),
    'fat12_1440': (12, 1440 * 1024),
    'fat16_32m': (16, 32 * 1024 * 1024),
    'fat32_128m': (32, 128 * 1024 * 1024),
}


@dataclass(frozen=True)
class Volume:
    fat_bits: int
    sector_size: int
    sectors_per_cluster: int
    reserved_sectors: int
    fat_count: int
    sectors_per_fat: int
    total_sectors: int
    cluster_count: int
    free_clusters: int
    clean_bits: tuple
    fat_copies_equal: bool
    fsinfo: tuple  # (sector, valid signatures, free count, next-free hint)

    @property
    def cluster_size(self):
        return self.sector_size * self.sectors_per_cluster


def _regular(path):
    path = Path(path)
    if not path.is_file() or path.is_symlink():
        raise ValueError(f'Expected regular image file: {path}')
    return path


def inspect_image(path):
    """Read geometry, FAT allocation and markers without mounting or writing."""
    with _regular(path).open('rb') as image:
        boot = image.read(512)
        u16 = lambda offset: struct.unpack_from('<H', boot, offset)[0]
        u32 = lambda offset: struct.unpack_from('<I', boot, offset)[0]
        sector, spc, reserved, copies = u16(11), boot[13], u16(14), boot[16]
        if boot[510:512] != b'\x55\xaa' or sector != 512 or not spc or not copies:
            raise ValueError('Invalid or unsupported FAT boot sector')
        total, fat_size = u16(19) or u32(32), u16(22) or u32(36)
        root_sectors = (u16(17) * 32 + sector - 1) // sector
        clusters = (total - reserved - copies * fat_size - root_sectors) // spc
        bits = 12 if clusters < 4085 else 16 if clusters < 65525 else 32
        fats = []
        for index in range(copies):
            image.seek((reserved + index * fat_size) * sector)
            fat = image.read(fat_size * sector)
            if len(fat) != fat_size * sector:
                raise ValueError('Truncated FAT')
            fats.append(fat)
        def entry(cluster):
            if bits == 12:
                offset = cluster + cluster // 2
                value = struct.unpack_from('<H', fats[0], offset)[0]
                return (value >> 4 if cluster & 1 else value) & 0xfff
            fmt, mask = ('<H', 0xffff) if bits == 16 else ('<I', 0xfffffff)
            return struct.unpack_from(fmt, fats[0], cluster * (bits // 8))[0] & mask
        free = sum(entry(cluster) == 0 for cluster in range(2, clusters + 2))
        clean = () if bits == 12 else tuple(bool(fat[3 if bits == 16 else 7] &
                                               (0x80 if bits == 16 else 8)) for fat in fats)
        infos = []
        if bits == 32:
            primary, backup = u16(48), u16(50)
            locations = [primary] if 0 < primary < reserved else []
            if backup not in (0, 0xffff) and 0 < 1 + backup < reserved:
                locations.append(1 + backup)
            for location in locations:
                image.seek(location * sector)
                info = image.read(sector)
                valid = (info[:4] == b'RRaA' and info[484:488] == b'rrAa'
                         and info[508:512] == b'\0\0\x55\xaa')
                infos.append((location, valid, *struct.unpack_from('<II', info, 488)))
        return Volume(bits, sector, spc, reserved, copies, fat_size, total,
                      clusters, free, clean, all(fat == fats[0] for fat in fats), tuple(infos))


def create_image(path, profile='fat12_720', dirty=False, fsinfo='valid'):
    """Create exclusively; refuse overwrites, devices and unsupported variants."""
    bits, size = PROFILES[profile]
    if fsinfo not in ('valid', 'unknown'):
        raise ValueError('fsinfo must be valid or unknown')
    if bits == 12 and dirty:
        raise ValueError('FAT12 has no clean bit')
    if bits != 32 and fsinfo != 'valid':
        raise ValueError('Only FAT32 has FSInfo')
    path = Path(path)
    with path.open('xb') as image:
        image.truncate(size)
    subprocess.run(['mkfs.fat', '--invariant', '-F', str(bits), '-S', '512',
                    '-f', '2', '-i', '95fa0095', '-n', 'FAT95TEST', str(path)],
                   check=True, capture_output=True, timeout=30)
    volume = inspect_image(path)
    if volume.fat_bits != bits:
        raise AssertionError(f'Expected FAT{bits}, got FAT{volume.fat_bits}')
    with path.open('r+b') as image:
        if dirty:
            offset, mask = (3, 0x80) if bits == 16 else (7, 8)
            for index in range(volume.fat_count):
                position = (volume.reserved_sectors + index * volume.sectors_per_fat) * 512 + offset
                image.seek(position)
                value = image.read(1)[0]
                image.seek(position)
                image.write(bytes([value & ~mask]))
        if bits == 32:
            for location, valid, _, _ in volume.fsinfo:
                if not valid:
                    raise AssertionError('mkfs created invalid FSInfo')
                image.seek(location * 512 + 488)
                image.write(struct.pack('<II', volume.free_clusters if fsinfo == 'valid'
                                        else 0xffffffff, 0xffffffff))
    return inspect_image(path)


def file_sha256(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def verify_image(path, expected_files=None, check_fsck=True):
    """Check unmounted image; expected_files maps DOS paths to exact bytes.

    fsck exit 1 is an error here, including an expected dirty-volume warning.
    Set check_fsck=False to collect its output while checking dirty fixtures.
    """
    path = _regular(path).resolve()
    result = subprocess.run(['fsck.fat', '-n', str(path)], capture_output=True,
                            text=True, timeout=60)
    report = {'fsck_returncode': result.returncode,
              'fsck_output': result.stdout + result.stderr, 'files': {}}
    if check_fsck and result.returncode:
        raise AssertionError(report['fsck_output'])
    for name, expected in (expected_files or {}).items():
        with tempfile.TemporaryDirectory(prefix='fat95-mtools-') as temp:
            target = Path(temp) / 'content'
            subprocess.run(['mcopy', '-i', str(path), '::/' + name.lstrip('/'), str(target)],
                           check=True, capture_output=True, timeout=60,
                           env={**os.environ, 'MTOOLS_SKIP_CHECK': '1'})
            actual = target.read_bytes()
            if actual != expected:
                raise AssertionError(f'Content mismatch: {name} ({len(actual)} vs {len(expected)} bytes)')
            report['files'][name] = hashlib.sha256(actual).hexdigest()
    report['volume'] = inspect_image(path)
    return report
