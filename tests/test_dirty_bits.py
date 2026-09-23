"""Dirty-marker I/O ordering per FAT type, and what each failing step must do. No device is opened.

Run: make test"""
import tempfile
import unittest
from pathlib import Path
from harness import Handler, C, CPU, WINDOW, BUFFER, load


class DirtyBitTests(unittest.TestCase):
    """Dirty-marker transactions: the order in which the clean marks and the payload reach the card, and what every failing step must do. The card is a dict in the harness, no device is touched."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        path = Path(cls.temp.name) / 'dirty.hunk'
        cls.image = load(path)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def make_handler(self, fat=32, dirty=False):
        h = Handler(self.image)
        h.exec_memory()
        self.addCleanup(h.close)
        h.set('FATType', {12: 0, 16: 1, 32: 0xffff}[fat], 2)
        # FSInfo disabled here: these tests isolate dirty-bit transactions.
        h.set('FSInfoBlock', 0)
        for lba in (2080, 2208):
            if fat == 16:
                h.disk[lba][2:4] = (0x7fff if dirty else 0xffff).to_bytes(2, 'little')
            elif dirty:
                h.disk[lba][7] &= ~8
        if fat == 16:
            h.mem.w_block(WINDOW, bytes(h.disk[2080]))
        else:
            h.mem.w_block(WINDOW + C['F32B_Data'], bytes(h.disk[2080]))
        h.run('InitDirtyState')
        h.events.clear()
        h.mem.w_block(BUFFER, b'x' * 512)
        return h

    def clean(self, h, fat=32):
        offset, bit = (3, 0x80) if fat == 16 else (7, 8)
        return [bool(h.disk[lba][offset] & bit) for lba in (2080, 2208)]

    def writes(self, h):
        return [lba for kind, lba in h.events if kind == 'write']

    def test_first_direct_write_marks_both_copies_and_flushes_first(self):
        """The first write of a cycle marks both FAT copies dirty and flushes them before the payload goes out; a second write in the same cycle carries the payload alone."""
        h = self.make_handler()
        original = {lba: bytes(h.disk[lba]) for lba in (2080, 2208)}
        self.assertNotEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(self.writes(h), [2080, 2208, 2300])
        data_index = h.events.index(('write', 2300))
        self.assertEqual(sum(kind == 'flush' for kind, _ in h.events[:data_index]), 1)
        self.assertEqual(self.clean(h), [False, False])
        for lba in (2080, 2208):
            expected = bytearray(original[lba])
            expected[7] &= ~8
            self.assertEqual(h.disk[lba], expected)
        h.events.clear()
        self.assertNotEqual(h.run('_Write', d0=2301, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.events, [('write', 2301)])

    def test_flush_restores_clean_only_after_data_barrier(self):
        """UpdateDisk restores the clean marks between two barriers and closes the cycle, so clean is published only once the payload is durable."""
        h = self.make_handler()
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.events.clear()
        self.assertNotEqual(h.run('UpdateDisk', d0=1), 0)
        writes = [i for i, event in enumerate(h.events) if event[0] == 'write']
        self.assertEqual(self.writes(h), [2080, 2208])
        self.assertTrue(any(kind == 'flush' for kind, _ in h.events[:writes[0]]))
        self.assertTrue(any(kind == 'flush' for kind, _ in h.events[writes[-1] + 1:]))
        self.assertEqual(self.clean(h), [True, True])
        self.assertEqual(h.get('DirtyCycle', 2), 0)

    def test_incoming_dirty_card_never_becomes_clean(self):
        """A card that arrived dirty stays dirty through a write and a flush; the handler never cleans a state it did not verify."""
        h = self.make_handler(dirty=True)
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.run('UpdateDisk', d0=1)
        self.assertEqual(self.clean(h), [False, False])
        self.assertEqual(self.writes(h), [2080, 2208, 2300])

    def test_fat12_has_no_marker_io(self):
        """FAT12 carries no dirty marker, so a write and a flush produce the payload write alone."""
        h = self.make_handler(fat=12)
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.run('UpdateDisk', d0=1)
        self.assertEqual(self.writes(h), [2300])

    def test_fat16_updates_cached_marker_without_other_changes(self):
        """The FAT16 marker flips exactly one bit of the cached first sector and the flush puts it back, leaving every other byte alone."""
        h = self.make_handler(fat=16)
        before = bytes(h.mem.r_block(WINDOW, 512))
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        expected = bytearray(before)
        expected[3] &= ~0x80
        self.assertEqual(bytes(h.mem.r_block(WINDOW, 512)), bytes(expected))
        self.assertEqual(self.clean(h, 16), [False, False])
        h.run('UpdateDisk', d0=1)
        self.assertEqual(bytes(h.mem.r_block(WINDOW, 512)), before)
        self.assertEqual(self.clean(h, 16), [True, True])

    def test_fat32_updates_cached_marker_without_other_changes(self):
        """The FAT32 marker flips exactly one bit of the cached FAT32 sector and the flush puts it back, leaving every other byte alone."""
        h = self.make_handler()
        address = WINDOW + C['F32B_Data']
        before = bytes(h.mem.r_block(address, 512))
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        expected = bytearray(before)
        expected[7] &= ~8
        self.assertEqual(bytes(h.mem.r_block(address, 512)), bytes(expected))
        h.run('UpdateDisk', d0=1)
        self.assertEqual(bytes(h.mem.r_block(address, 512)), before)

    def test_marker_write_failure_blocks_data(self):
        """A marker write that fails blocks the payload and latches the write fault, so no metadata reaches a card that does not know it is dirty."""
        h = self.make_handler()
        h.fail = 'write'
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertNotIn(2300, self.writes(h))
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_marker_barrier_failure_blocks_data(self):
        """A barrier that fails after the marker write blocks the payload and leaves both copies dirty, because the marker is not known to be durable."""
        h = self.make_handler()
        h.fail = 'flush'
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertNotIn(2300, self.writes(h))
        self.assertEqual(h.get('WriteFault', 2), 1)
        self.assertEqual(self.clean(h), [False, False])

    def test_swap_after_initialization_blocks_all_old_card_writes(self):
        """A media generation bump between mount and write stops every I/O, so blocks meant for the old card cannot land on the new one."""
        h = self.make_handler()
        h.set('MediaGeneration', 8)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.events, [])

    def test_read_only_session_never_writes_marker(self):
        """A flush with nothing written issues no I/O at all: a read-only session never marks the card."""
        h = self.make_handler()
        h.run('UpdateDisk', d0=1)
        self.assertEqual(h.events, [])

    def test_second_copy_failure_blocks_data_and_latches_fault(self):
        """A failure on the second FAT copy blocks the payload and latches the fault, with the first copy already marked."""
        h = self.make_handler()
        original_io = h.io
        def fail_second():
            req = h.cpu.r_reg(9)
            if (h.mem.r16(req + C['IO_Command']) == 3 and
                    h.mem.r32(req + C['IO_Offset']) // 512 == 2208):
                h.fail = 'write'
            original_io()
        h.stub('SafeDoIO', fail_second)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(self.writes(h), [2080, 2208])
        self.assertEqual(h.get('WriteFault', 2), 1)
        self.assertEqual(self.clean(h), [False, True])

    def test_swap_during_marker_read_never_writes_new_card(self):
        """A card swap noticed during the marker read aborts before any write, so the new card is left untouched."""
        h = self.make_handler()
        h.swap_on = 'read'
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(self.writes(h), [])

    def test_short_marker_write_blocks_data(self):
        """A marker write the device truncates counts as a failure: the payload is blocked and the fault latched."""
        h = self.make_handler()
        original_io = h.io
        def short_write():
            req = h.cpu.r_reg(9)
            h.short = h.mem.r16(req + C['IO_Command']) == 3
            original_io()
        h.stub('SafeDoIO', short_write)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertNotIn(2300, self.writes(h))
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_data_barrier_failure_never_restores_clean(self):
        """A barrier that fails before the clean marks are rewritten leaves them dirty and writes nothing."""
        h = self.make_handler()
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.events.clear()
        h.fail = 'flush'
        self.assertEqual(h.run('UpdateDisk', d0=1), 0)
        self.assertEqual(self.writes(h), [])
        self.assertEqual(self.clean(h), [False, False])

    def test_clean_copy_failure_returns_failed_flush_without_payload_retry(self):
        """A failure while restoring the clean marks reports a failed flush, leaves both copies dirty, latches the fault and blocks the next write instead of retrying the payload."""
        h = self.make_handler()
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.events.clear()
        h.fail = 'write'
        self.assertEqual(h.run('UpdateDisk', d0=1), 0)
        self.assertEqual(self.writes(h), [2080])
        self.assertEqual(self.clean(h), [False, False])
        self.assertEqual(h.get('WriteFault', 2), 1)
        h.fail = None
        h.events.clear()
        self.assertEqual(h.run('_Write', d0=2301, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.events, [])

    def test_clean_final_barrier_failure_keeps_cycle_pending_and_faulted(self):
        """A failing final barrier leaves the cycle pending and the fault latched, so the clean state is not claimed."""
        h = self.make_handler()
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.events.clear()
        original_io = h.io
        def fail_final_flush():
            if self.writes(h) == [2080, 2208]:
                h.fail = 'flush'
            original_io()
        h.stub('SafeDoIO', fail_final_flush)
        self.assertEqual(h.run('UpdateDisk', d0=1), 0)
        self.assertEqual(h.get('DirtyCycle', 2), 2)
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_first_fat_sector_pending_allocation_survives_marker_writes(self):
        """A pending allocation in the first FAT sector survives both marker writes and the clean restore, so marking dirty never overwrites FAT content."""
        h = self.make_handler()
        address = WINDOW + C['F32B_Data']
        h.mem.w_block(address + 12, (0x0fffffff).to_bytes(4, 'little'))
        h.mem.w32(WINDOW + C['F32B_Flags'], 1)
        h.set('NewFlags', 8, 2)
        self.assertNotEqual(h.run('WriteFAT'), 0)
        for lba in (2080, 2208):
            self.assertEqual(h.disk[lba][12:16], (0x0fffffff).to_bytes(4, 'little'))
        self.assertEqual(self.clean(h), [False, False])
        self.assertNotEqual(h.run('UpdateDisk', d0=1), 0)
        for lba in (2080, 2208):
            self.assertEqual(h.disk[lba][12:16], (0x0fffffff).to_bytes(4, 'little'))
        self.assertEqual(self.clean(h), [True, True])

    def test_crash_before_flush_remount_observes_dirty(self):
        """A machine lost between the write and the flush leaves the card dirty, and the fresh mount refuses clean eligibility."""
        h = self.make_handler()
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        saved = {lba: bytearray(data) for lba, data in h.disk.items()}
        h.close()  # No handler flush: simulate loss of process/machine state.
        fresh = Handler(self.image)
        self.addCleanup(fresh.close)
        fresh.exec_memory()
        fresh.disk = saved
        self.assertNotEqual(fresh.run('InitDirtyState'), 0)
        self.assertEqual(fresh.get('DirtyEligible', 2), 0)

    def test_new_mount_initialization_discards_old_cycle_eligibility(self):
        """InitDirtyState discards the eligibility, cycle and in-flight state of the previous medium."""
        h = self.make_handler()
        h.set('DirtyEligible', 1, 2)
        h.set('DirtyCycle', 2, 2)
        h.set('DirtyIO', 1, 2)
        for lba in (2080, 2208):
            h.disk[lba][7] &= ~8
        self.assertNotEqual(h.run('InitDirtyState'), 0)
        self.assertEqual(h.get('DirtyReady', 2), 1)
        self.assertEqual(h.get('DirtyEligible', 2), 0)
        self.assertEqual(h.get('DirtyCycle', 2), 0)
        self.assertEqual(h.get('DirtyIO', 2), 0)

    def test_failed_mount_probe_cannot_retain_old_clean_eligibility(self):
        """A probe whose read failed still mounts, but without clean eligibility and without a latched fault, and it refuses the first write rather than leaving it unmarked."""
        h = self.make_handler()
        h.set('DirtyCycle', 1, 2)
        h.fail = 'read'
        self.assertNotEqual(h.run('InitDirtyState'), 0)
        self.assertEqual(h.get('DirtyReady', 2), 1)
        self.assertEqual(h.get('DirtyEligible', 2), 0)
        self.assertEqual(h.get('DirtyCycle', 2), 0)
        self.assertEqual(h.get('WriteFault', 2), 0)
        h.events.clear()
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(self.writes(h), [])
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_mixed_clean_copies_are_never_promoted_to_clean(self):
        """With one FAT copy clean and one dirty the volume is not eligible, and a write and flush leave both copies dirty."""
        h = self.make_handler()
        h.disk[2208][7] &= ~8
        self.assertNotEqual(h.run('InitDirtyState'), 0)
        self.assertEqual(h.get('DirtyEligible', 2), 0)
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.run('UpdateDisk', d0=1)
        self.assertEqual(self.clean(h), [False, False])

    def test_fsinfo_publication_failure_never_sets_clean(self):
        """An FSInfo write that failed leaves both markers dirty and latches the fault, so a count that never landed is not treated as published."""
        h = self.make_handler()
        h.fsinfo()
        h.run('_Write', d0=2300, d1=1, a0=BUFFER)
        h.set('FSInfoDirty', 1, 2)
        h.set('FreeClusters', 124)
        h.set('NextFreeCluster', 4)
        h.events.clear()
        original_io = h.io
        def fail_fsinfo():
            req = h.cpu.r_reg(9)
            if (h.mem.r16(req + C['IO_Command']) == 3 and
                    h.mem.r32(req + C['IO_Offset']) // 512 == 2049):
                h.fail = 'write'
            original_io()
        h.stub('SafeDoIO', fail_fsinfo)
        self.assertEqual(h.run('UpdateDisk', d0=1), 0)
        self.assertEqual(self.clean(h), [False, False])
        self.assertEqual(self.writes(h), [2049])
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_unsupported_update_blocks_managed_payload(self):
        """Without the device UPDATE command the marker cannot be made durable, so the managed payload is blocked and the fault latched."""
        h = self.make_handler()
        h.set('CmdFlags', 0, 2)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertNotIn(2300, self.writes(h))
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_device_rejecting_update_blocks_managed_payload(self):
        """A device answering IOERR_NOCMD to UPDATE has the capability flag cleared, the payload blocked and the fault latched."""
        h = self.make_handler()
        original_io = h.io
        def reject_update():
            req = h.cpu.r_reg(9)
            original_io()
            if h.mem.r16(req + C['IO_Command']) == 4:
                h.result(C['IOERR_NOCMD'])
        h.stub('SafeDoIO', reject_update)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertNotIn(2300, self.writes(h))
        self.assertEqual(h.get('CmdFlags', 2) & 8, 0)
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_fat12_keeps_unsupported_update_behavior(self):
        """FAT12 has no marker to flush, so a device without UPDATE still writes the payload and latches no fault."""
        h = self.make_handler(fat=12)
        h.set('CmdFlags', 0, 2)
        self.assertNotEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertNotEqual(h.run('UpdateDisk', d0=1), 0)
        self.assertEqual(h.events, [('write', 2300)])
        self.assertEqual(h.get('WriteFault', 2), 0)

    def test_physical_protection_blocks_marker_and_payload(self):
        """A physically write-protected medium takes no I/O at all and keeps its clean marks."""
        h = self.make_handler()
        h.set('PhysFlags', 0, 2)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.events, [])
        self.assertEqual(self.clean(h), [True, True])

    def test_software_protection_blocks_marker_and_payload(self):
        """A soft-locked volume takes no I/O at all and keeps its clean marks."""
        h = self.make_handler()
        h.set('SoftLocked', 1, 2)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.events, [])
        self.assertEqual(self.clean(h), [True, True])

    def test_close_after_swap_clears_all_marker_state_without_writes(self):
        """Closing after a media swap writes nothing to the new card and clears every marker state field."""
        h = self.make_handler()
        h.prepare_close()
        h.set('DirtyCycle', 1, 2)
        h.set('DirtyIO', 1, 2)
        h.set('MediaGeneration', 8)
        h.run('CloseDisk')
        self.assertEqual(h.events, [])
        for field in ('DirtyReady', 'DirtyEligible', 'DirtyCycle', 'DirtyIO'):
            self.assertEqual(h.get(field, 2), 0, field)

    def test_failed_mount_close_clears_all_marker_state(self):
        """Closing a mount that produced no volume writes nothing and clears every marker state field."""
        h = self.make_handler()
        h.prepare_close()
        h.set('VolumeNode', 0)
        h.set('PhysFlags', 0, 2)
        h.set('DirtyCycle', 2, 2)
        h.set('DirtyIO', 1, 2)
        h.run('CloseDisk')
        self.assertEqual(h.events, [])
        for field in ('DirtyReady', 'DirtyEligible', 'DirtyCycle', 'DirtyIO'):
            self.assertEqual(h.get(field, 2), 0, field)

    def test_secondary_probe_failure_allows_mount_but_not_unmarked_writes(self):
        """An unreadable second FAT copy still mounts and scans, but the first write is refused rather than written with only one copy marked."""
        h = self.make_handler()
        h.fsinfo()
        original_io = h.io
        def bad_secondary():
            from harness import REQUEST
            command = h.mem.r16(REQUEST + C['IO_Command'])
            lba = h.mem.r32(REQUEST + C['IO_Offset']) // 512
            h.fail = 'read' if command == 2 and lba == 2208 else None
            original_io()
        h.stub('SafeDoIO', bad_secondary)
        self.assertNotEqual(h.run('ReadFAT'), 0)
        self.assertEqual(h.get('WriteFault', 2), 0)
        self.assertEqual(h.get('DirtyEligible', 2), 0)
        self.assertNotEqual(h.get('BackgroundJob'), 0)
        h.run('ScanFAT32')
        self.assertNotEqual(h.get('FreeClusters'), 0xffffffff)
        h.events.clear()
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertNotIn(2300, self.writes(h))
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_recovered_probe_failure_never_earns_clean(self):
        """A probe that failed once never earns clean afterwards, even when the following I/O succeeds."""
        h = self.make_handler()
        h.fail = 'read'
        self.assertNotEqual(h.run('InitDirtyState'), 0)
        h.fail = None
        self.assertNotEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        h.run('UpdateDisk', d0=1)
        self.assertEqual(self.clean(h), [False, False])
        self.assertEqual(h.get('DirtyEligible', 2), 0)

    def test_probe_allocation_failure_allows_mount_without_clean_eligibility(self):
        """An AllocMem failure during the probe still mounts, with no I/O, no fault and no clean eligibility."""
        h = self.make_handler()
        h.trap(0x70000 + C['AllocMem'], lambda: h.result(0))
        self.assertNotEqual(h.run('InitDirtyState'), 0)
        self.assertEqual(h.get('DirtyReady', 2), 1)
        self.assertEqual(h.get('DirtyEligible', 2), 0)
        self.assertEqual(h.get('WriteFault', 2), 0)
        self.assertEqual(h.events, [])

    def test_probe_media_change_is_not_degraded_to_unknown(self):
        """A media change during the probe is reported as a change with the fault latched, not degraded to an unknown marker state."""
        h = self.make_handler()
        h.swap_on = 'read'
        self.assertEqual(h.run('InitDirtyState'), 0)
        self.assertEqual(h.get('DirtyReady', 2), 0)
        self.assertEqual(h.get('DirtyEligible', 2), 0)
        self.assertEqual(h.get('WriteFault', 2), 1)
