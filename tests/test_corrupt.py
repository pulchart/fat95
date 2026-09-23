"""Malformed FAT entries and stale free-space metadata, using assembled routines."""
import tempfile
import unittest
from pathlib import Path

from harness import C, Handler, WINDOW, load


class CorruptFATTests(unittest.TestCase):
    """FAT marker decoding, corrupt append chains and bounded free-cluster scans."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.image = load(Path(cls.temp.name) / 'fat95.hunk')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.h = Handler(self.image)
        self.addCleanup(lambda: self.h.close())

    def fat(self, bits, entries):
        self.h.close()
        self.h = Handler(self.image)
        h = self.h
        h.set('FATType', {12: 0, 16: 1, 32: 0xffff}[bits], 2)
        h.set('FATBuffer', WINDOW)
        h.set('LastCluster', 9)
        h.set('FreeClusters', 1)
        h.set('NextFreeCluster', 2)
        data = bytearray(512)
        for cluster, value in entries.items():
            if bits == 12:
                offset = cluster * 3 // 2
                packed = int.from_bytes(data[offset:offset + 2], 'little')
                shift = 4 if cluster & 1 else 0
                packed = (packed & ~(0xfff << shift)) | ((value & 0xfff) << shift)
                data[offset:offset + 2] = packed.to_bytes(2, 'little')
            else:
                width = bits // 8
                offset = cluster * width
                data[offset:offset + width] = value.to_bytes(width, 'little')
        address = WINDOW + C['F32B_Data'] if bits == 32 else WINDOW
        h.mem.w_block(address, bytes(data))
        return address, bytes(data)

    def test_bad_cluster_and_end_markers_decode_without_following_them(self):
        """FAT12/16/32 bad and end markers become negative sentinels, with no I/O."""
        for bits in (12, 16, 32):
            mask = (1 << min(bits, 28)) - 1
            for low in range(7, 16):
                with self.subTest(bits=bits, marker=low):
                    # Both FAT12 nibble positions; FAT32 upper flag bits ignored.
                    value = (mask & ~15) | low
                    if bits == 32:
                        value |= 0xa0000000
                    address, before = self.fat(bits, {2: value, 3: value})
                    for cluster in (2, 3):
                        self.assertEqual(self.h.run('NextCluster', d0=cluster),
                                         0xfffffff0 | low)
                    self.assertEqual(bytes(self.h.mem.r_block(address, 512)), before)
                    self.assertEqual(self.h.events, [])

    def test_stale_free_count_cannot_spin_on_full_fat(self):
        """An allocation scan stops when FAT is full despite FreeClusters claiming space."""
        for bits in (12, 16, 32):
            with self.subTest(bits=bits):
                end = (1 << min(bits, 28)) - 1
                address, before = self.fat(bits, {i: end for i in range(2, 10)})
                self.assertEqual(self.h.run('ExtendChain', d0=0), 0xffffffff)
                self.assertEqual(self.h.get('ErrorNum', 2), 221)
                self.assertEqual(self.h.get('FreeClusters'), 1)
                self.assertEqual(bytes(self.h.mem.r_block(address, 512)), before)
                self.assertEqual(self.h.events, [])

    def test_allocation_watchdog_still_finds_last_available_cluster(self):
        """The bounded scan reaches the last data cluster instead of rejecting early."""
        for bits in (12, 16, 32):
            with self.subTest(bits=bits):
                end = (1 << min(bits, 28)) - 1
                self.fat(bits, {i: end for i in range(2, 9)})
                self.assertEqual(self.h.run('ExtendChain', d0=0), 9)
                self.assertEqual(self.h.get('FreeClusters'), 0)
                self.assertEqual(self.h.run('NextCluster', d0=9), 0xffffffff)
                self.assertEqual(self.h.events, [])

    def test_corrupt_append_chain_stops_without_mutating_fat(self):
        """Cycles, free/reserved/bad entries and out-of-volume links reject append."""
        for bits in (12, 16, 32):
            end = (1 << min(bits, 28)) - 1
            cases = {'self-cycle': {2: 2}, 'two-cycle': {2: 3, 3: 2},
                     'free': {2: 0}, 'reserved-one': {2: 1},
                     'outside-volume': {2: 10}, 'bad-cluster': {2: end - 8},
                     'reserved-marker': {2: end - 15}}
            for name, entries in cases.items():
                with self.subTest(bits=bits, case=name):
                    address, before = self.fat(bits, entries)
                    self.assertEqual(self.h.run('ExtendChain', d0=2), 0xffffffff)
                    self.assertEqual(self.h.get('ErrorNum', 2), 225)
                    self.assertEqual(self.h.get('FreeClusters'), 1)
                    self.assertEqual(self.h.get('NextFreeCluster'), 2)
                    self.assertEqual(self.h.get('NewFlags', 2), 0)
                    self.assertEqual(bytes(self.h.mem.r_block(address, 512)), before)
                    self.assertEqual(self.h.events, [])

    def test_valid_append_reaches_free_cluster_after_long_chain(self):
        """A valid chain visits every allocated cluster and appends the remaining free one."""
        for bits in (12, 16, 32):
            with self.subTest(bits=bits):
                end = (1 << min(bits, 28)) - 1
                self.fat(bits, {**{i: i + 1 for i in range(2, 8)}, 8: end})
                self.assertEqual(self.h.run('ExtendChain', d0=2), 9)
                self.assertEqual(self.h.run('NextCluster', d0=8), 9)
                self.assertEqual(self.h.run('NextCluster', d0=9), 0xffffffff)
                self.assertEqual(self.h.get('FreeClusters'), 0)
                self.assertEqual(self.h.events, [])

    def test_maximal_valid_chain_reaches_allocation_scan(self):
        """A chain using every data cluster reaches disk-full handling, not corruption."""
        for bits in (12, 16, 32):
            with self.subTest(bits=bits):
                end = (1 << min(bits, 28)) - 1
                address, before = self.fat(bits, {**{i: i + 1 for i in range(2, 9)}, 9: end})
                self.assertEqual(self.h.run('ExtendChain', d0=2), 0xffffffff)
                self.assertEqual(self.h.get('ErrorNum', 2), 221)
                self.assertEqual(self.h.get('FreeClusters'), 1)
                self.assertEqual(bytes(self.h.mem.r_block(address, 512)), before)
                self.assertEqual(self.h.events, [])

    def test_fat_read_failure_is_not_an_end_marker(self):
        """Missing FAT returns a latched read failure, never stale disk-full status."""
        for error in (0, 218, 221):
            with self.subTest(error=error):
                self.h.set('FATBuffer', 0)
                self.h.set('ErrorNum', error, 2)
                self.assertEqual(self.h.run('GetFATEntry', d0=2),
                                 C['FAT_READ_ERROR'] & 0xffffffff)
                self.assertEqual(self.h.get('ErrorNum', 2), 225)
                self.assertEqual(self.h.get('WriteFault', 2), 1)

    def test_failed_fat_window_cannot_start_or_extend_a_chain(self):
        """Permanent or transient FAT32 lookup failure changes no allocation state."""
        for start in (0, 4096):
            for transient in (False, True):
                with self.subTest(start=start, transient=transient):
                    self.h.close()
                    self.h = h = Handler(self.image)
                    h.set('LastCluster', 5000)
                    h.set('FreeClusters', 10)
                    h.set('NextFreeCluster', 4096)
                    address = WINDOW + C['F32B_Data']
                    before = bytes(h.mem.r_block(address, 16384))
                    reads = []

                    def read():
                        reads.append(h.cpu.r_reg(0))
                        if len(reads) <= 2 or not transient:
                            h.result(0)  # Both FAT copies fail.
                        else:
                            count = h.cpu.r_reg(1)
                            h.mem.w_block(h.cpu.r_reg(9), bytes(count * 512))
                            h.result(count)  # Later reads would expose free entries.

                    h.stub('_Read', read)
                    self.assertEqual(h.run('ExtendChain', d0=start), 0xffffffff)
                    self.assertEqual(len(reads), 2)
                    self.assertEqual(h.get('ErrorNum', 2), 225)
                    self.assertEqual(h.get('WriteFault', 2), 1)
                    self.assertEqual(h.get('FreeClusters'), 10)
                    self.assertEqual(h.get('NextFreeCluster'), 4096)
                    self.assertEqual(h.get('NewFlags', 2), 0)
                    self.assertEqual(h.mem.r32(WINDOW + C['F32B_Flags']), 0)
                    self.assertEqual(bytes(h.mem.r_block(address, 16384)), before)
                    self.assertEqual(h.events, [])


if __name__ == '__main__':
    unittest.main()
