#!/usr/bin/env python3
"""Behaviour contracts for the FAT32 fast mount, observed through the device.

Checks I/O events and card contents. Run: make test
"""
import tempfile
import unittest
from pathlib import Path

from harness import BASE, BB, BUFFER, C, CPU, GLOBALS, WINDOW, Handler, load
FSINFO_LBA = 2049                       # FirstBlock 2048 + FSInfoBlock 1
FAT_LBA = (2080, 2208)                  # both FAT copies

# Allocation invalidation uses FSInfo when available, otherwise FAT[1].
MARKER_LBA = frozenset({FSINFO_LBA} if 'FSInfoUnknown' in C else set(FAT_LBA))
METADATA_LBA = 2300                     # the dirty_buffer() block


class Contracts(unittest.TestCase):
    """Behaviour contracts C1-C12 for the FAT32 fast mount, asserted only on the device I/O stream and the resulting card content, so the same file measures a clean-bit design and an FSInfo-only design."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        path = Path(cls.temp.name) / 'fat95.hunk'
        cls.image = load(path)

    def setUp(self):
        self.h = Handler(self.image)
        self.addCleanup(self.h.close)

    def writes(self, h=None):
        return [lba for kind, lba in (h or self.h).events if kind == 'write']

    def assertRetriedOrClosed(self):
        """After a marker failure the handler may retry or fail closed.

        What it may not do is carry on as if the marker were down. Both
        policies are acceptable; only claiming success is not.
        """
        w = self.writes()
        if MARKER_LBA & set(w):
            return                          # retried, and the marker is down
        self.assertEqual(w, [], 'metadata written with no marker down')

    def remount(self, disk):
        """Mount a fresh handler on this card image.

        Only one vamos Machine can be live at a time, so the current handler
        is torn down first; the card image is plain Python and survives it.
        """
        image = {k: bytearray(v) for k, v in disk.items()}
        self.h.close()
        h = self.h = Handler(self.image)
        h.fsinfo()
        h.disk = image
        h.mem.w_block(WINDOW + C['F32B_Data'], bytes(h.disk.get(2080, bytes(512))))
        h.events.clear()
        h.run('ReadFAT')
        return h

    # --- C1: a read-only session must not touch the card ------------------
    def test_c1_read_only_session_writes_nothing(self):
        """C1: mounting, reading the FAT and closing again issues no write at all, so a read-only session cannot wear or corrupt the card."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.prepare_close()
        h.run('CloseDisk')
        self.assertEqual(self.writes(), [])

    # --- C2/C3: the mount gate --------------------------------------------
    def test_c2_usable_count_skips_the_fat(self):
        """C2: a usable stored free-cluster count mounts the volume validated with no background job, which is what the fast mount is for."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        self.assertEqual(h.get('DiskState'), C['ID_VALIDATED'])
        self.assertEqual(h.get('BackgroundJob'), 0)
        self.assertEqual(h.get('FreeClusters'), 125)

    def test_c3_unusable_count_falls_back_to_the_scan(self):
        """C3: a stored count of 0xffffffff means unknown, so the mount stays validating and schedules the scan instead of trusting it."""
        h = self.h
        h.fsinfo(free=0xffffffff)
        h.run('ReadFAT')
        self.assertEqual(h.get('DiskState'), C['ID_VALIDATING'])
        self.assertNotEqual(h.get('BackgroundJob'), 0)

    # --- C4: the marker reaches the card, flushed, before the data --------
    def test_c4_durable_marker_precedes_every_metadata_write(self):
        """C4: the durable 'counts are not valid' marker reaches the card and is flushed before any metadata write, so an interrupted session can never look clean."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.events.clear()
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        seq = [(kind, lba) for kind, lba in h.events if kind != 'read']
        marked = flushed = False
        for kind, lba in seq:
            if kind == 'flush':
                flushed = marked
            elif lba in MARKER_LBA:
                marked = True
            elif lba in (2080, 2208):
                continue  # clean-bit markers; payload unchanged (test_dirty_bits)
            else:
                self.assertTrue(marked, f'metadata at {lba} preceded the marker')
                self.assertTrue(flushed, f'metadata at {lba} raced the marker')

    # --- C5: a crash after the first write must not leave a usable count --
    def test_c5_crash_after_first_write_forces_a_scan(self):
        """C5: a card pulled after the first metadata write mounts validating, because the marker is down and the stored count must not be believed."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)          # first metadata write, then "power loss"
        again = self.remount(h.disk)
        self.assertEqual(again.get('DiskState'), C['ID_VALIDATING'],
                         'a pulled card was left claiming a usable count')
        self.assertNotEqual(again.get('BackgroundJob'), 0)

    # --- C6: a clean close must leave the next mount on the fast path -----
    def test_c6_clean_close_restores_the_fast_path(self):
        """C6: a clean unmount republishes the count and lifts the marker, so the next mount is validated with no scan."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        h.prepare_close()
        h.run('CloseDisk')
        again = self.remount(h.disk)
        self.assertEqual(again.get('DiskState'), C['ID_VALIDATED'],
                         'a clean unmount did not restore the fast path')
        self.assertEqual(again.get('BackgroundJob'), 0)

    # --- C7: a volume that arrived dirty must leave dirty -----------------
    def test_c7_dirty_volume_leaves_dirty(self):
        """C7: a volume that arrived dirty is still dirty at close, so the handler never grants a clean state it did not verify itself."""
        h = self.h
        h.fsinfo()
        for lba in FAT_LBA:
            h.disk[lba][7] &= ~8           # clear the clean-shutdown flag
        h.mem.w_block(WINDOW + C['F32B_Data'], bytes(h.disk[2080]))
        h.run('ReadFAT')
        self.assertEqual(h.get('DiskState'), C['ID_VALIDATING'])
        h.run('ScanFAT32')                 # writes are only allowed after it
        self.assertEqual(h.get('DiskState'), C['ID_VALIDATED'])
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        h.prepare_close()
        h.run('CloseDisk')
        for lba in FAT_LBA:
            self.assertEqual(h.disk[lba][7] & 8, 0,
                             'we granted a clean state we never verified')

    # --- C8: write protection and soft lock -------------------------------
    def test_c8_write_protected_volume_is_never_written(self):
        """C8: with the medium write-protected, publishing a changed free count issues no write."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.set('PhysFlags', 0, 2)
        h.set('FreeClusters', 99)
        h.events.clear()
        h.run('UpdateFSInfo')
        self.assertEqual(self.writes(), [])

    def test_c8_soft_locked_volume_is_never_written(self):
        """C8: with the volume soft-locked, publishing a changed free count issues no write."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.set('SoftLocked', 1, 2)
        h.set('FreeClusters', 99)
        h.events.clear()
        h.run('UpdateFSInfo')
        self.assertEqual(self.writes(), [])

    # --- C9: a marker that cannot be stored must not read as stored -------
    def test_c9_unreadable_marker_is_not_recorded_as_down(self):
        """C9: a marker sector that cannot be read is not written, and the next attempt either retries it or fails closed; proceeding as if the marker were down is what it may not do."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.evict_single(9999)
        h.fail = 'read'
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        self.assertFalse(MARKER_LBA & set(self.writes()))
        h.fail = None
        h.events.clear()
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        self.assertRetriedOrClosed()

    def test_c9_marker_failure_stops_further_writes(self):
        """C9: after a marker failure Ok2Write refuses the volume and an error is recorded, so it cannot keep accepting writes it is unable to invalidate."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.set('RootXLock', 0x50000)
        self.assertNotEqual(h.run('Ok2Write', d0=0), 0, 'writable to begin with')
        h.evict_single(9999)
        h.fail = 'read'
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        h.fail = None
        self.assertEqual(h.run('Ok2Write', d0=0), 0,
                         'the volume kept accepting writes it cannot invalidate')
        self.assertIn(h.get('ErrorNum', 2), (214, 225))

    def test_c9_multiblock_marker_failure_retains_all_pending_blocks(self):
        """C9: when the marker fails with two blocks pending, neither block is written and both stay flagged dirty in the buffer, so nothing is silently dropped."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.evict_single(9999)
        h.fail = 'read'
        h.dirty_buffer_multi(2)
        h.events.clear()
        self.assertEqual(h.run('WriteBBuf', a0=BB), 0)
        self.assertEqual(self.writes(), [])
        self.assertNotIn(2300, h.disk)
        self.assertNotIn(2301, h.disk)
        self.assertEqual(h.mem.r32(BB + C['BB_DirtyFlags']), 0xc0000000)

    def test_c9_strict_no_metadata_while_the_marker_is_not_down(self):
        """C9: no pending metadata reaches the card while the marker write is failing."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.evict_single(9999)
        h.fail = 'read'
        h.events.clear()
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        self.assertNotIn(METADATA_LBA, self.writes(),
                         'metadata reached the card with no marker down')

    def test_c9_failed_marker_write_is_not_recorded_as_down(self):
        """C9: a marker write that failed is not remembered as done, so the next write attempt retries it or fails closed."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.fail = 'write'
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        h.fail = None
        h.events.clear()
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        self.assertRetriedOrClosed()

    def test_c9_failed_count_store_leaves_the_card_needing_a_scan(self):
        """C9: a free-count store that failed is not recorded as published, so the next mount still scans."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)          # marker down, card says "unknown"
        h.fail = 'write'
        h.run('UpdateFSInfo')              # publishing the real count fails
        h.fail = None
        again = self.remount(h.disk)
        self.assertEqual(again.get('DiskState'), C['ID_VALIDATING'],
                         'a failed count store was recorded as published')

    # --- C10: invented FAT content must never reach the card --------------
    def test_c10_failed_fat_read_never_writes_invented_entries(self):
        """C10: a FAT window that could not be read is never written back, so a read error cannot push invented 'everything allocated' content onto the card."""
        h = self.h
        h.mem.w32(WINDOW + C['F32B_Start'], -1 & 0xffffffff)
        h.set('NewFlags', 8, 2)
        h.fail = 'read'
        h.run('MoveFATWindow', d0=2, d1=0xffffffff)
        h.fail = None
        h.events.clear()
        h.run('WriteFAT')
        for lba in FAT_LBA:
            self.assertNotIn(lba, self.writes(),
                             'invented "everything full" content reached the card')

    # --- own regression, not a shared contract: a marker kept in its own
    #     buffer never evicts anything, so this shape cannot arise there ---
    @unittest.skipUnless('FSInfoUnknown' in C, 'shared-cache marker only')
    def test_marker_does_not_recurse_through_a_foreign_dirty_single_buffer(self):
        """Own regression, shared-cache marker only: writing the marker evicts a foreign dirty block instead of recursing, the evicted block goes out before the marker, and the metadata goes out last."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.dirty_single(2400)               # one-entry cache busy and dirty
        h.events.clear()
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)          # harness asserts the stack unwinds
        w = self.writes()
        self.assertIn(2400, w, 'the evicted block was dropped')
        self.assertTrue(MARKER_LBA & set(w))
        self.assertEqual(w[-1], METADATA_LBA, 'metadata must go out last')
        # The evicted block goes out before the marker. Only the blocks
        # ReadSingle can hold end up here, and none of them carries
        # allocation state, so this cannot make a stale count look usable.
        self.assertLess(w.index(2400), min(w.index(m) for m in MARKER_LBA & set(w)))

    # --- own regression: a scan that failed must not publish its count ----
    def test_aborted_scan_does_not_publish_a_partial_count(self):
        """Own regression: a scan stopped by a read error does not publish the partial count it had reached."""
        h = self.h
        h.fsinfo(free=0xffffffff)
        h.run('ReadFAT')
        self.assertEqual(h.get('DiskState'), C['ID_VALIDATING'])
        h.fail = 'read'
        h.run('ScanFAT32')
        h.fail = None
        h.events.clear()
        h.run('UpdateDisk', d0=0xffffffff)
        self.assertNotIn(FSINFO_LBA, self.writes(),
                         'a scan stopped by a read error published its count')


    # --- C12: a mount that produced no volume must not keep its buffers --
    def test_c12_failed_mount_keeps_no_buffers_for_the_next_medium(self):
        """C12: a mount that produced no volume writes nothing out and drops both caches, so one card's blocks cannot reach the next one."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.prepare_close()
        h.dirty_single(2400)               # one-entry cache holds card A data
        h.dirty_buffer()
        h.set('VolumeNode', 0)             # mount produced no volume
        h.events.clear()
        h.run('CloseDisk')
        self.assertEqual(self.writes(), [],
                         'blocks of an unnamed medium were written out')
        self.assertEqual(h.get('SingleBuf'), 0,
                         'the one-entry cache survived into the next insertion')
        self.assertEqual(h.get('FATBuffer'), 0,
                         'the FAT window survived into the next insertion')

    def test_c12_failed_probe_keeps_no_buffers_for_the_next_medium(self):
        """C12: a probe that found no disk writes nothing out and drops both caches."""
        h = self.h
        h.fsinfo()
        h.run('ReadFAT')
        h.prepare_close()
        h.dirty_single(2400)
        h.set('VolumeNode', 0)
        h.set('PhysFlags', 0, 2)           # GetDiskParams found no disk
        h.events.clear()
        h.run('CloseDisk')
        self.assertEqual(self.writes(), [],
                         'blocks of an unnamed medium were written out')
        self.assertEqual(h.get('SingleBuf'), 0,
                         'the one-entry cache survived a failed probe')
        self.assertEqual(h.get('FATBuffer'), 0,
                         'the FAT window survived a failed probe')


if __name__ == '__main__':
    unittest.main()
