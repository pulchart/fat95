"""Media generation, cache retention, scan completion and volume locking across the whole handler.

Run: make test"""
import tempfile
import unittest
from pathlib import Path
from harness import Handler, C, CPU, GLOBALS, WINDOW, BB, BUFFER, load

class IntegrationTests(unittest.TestCase):
    """Whole-handler behaviour across a media change, a cache eviction, a scan and a lock: what survives, what is discarded, and what must never reach the card."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        path = Path(cls.temp.name) / 'fat95.hunk'
        cls.image = load(path)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.h = Handler(self.image)
        self.h.fsinfo()
        self.addCleanup(self.h.close)

    def test_stale_generation_blocks_io_even_without_change_flag(self):
        """A stale media generation blocks I/O on its own, without waiting for the device to report a change."""
        h = self.h
        h.set('MediaGeneration', 8)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.events, [])

    def test_retry_cannot_adopt_new_card_change_number(self):
        """A retry after a write failure keeps the original change number, so it cannot resume onto a card that was swapped in meanwhile."""
        h = self.h
        h.fail, h.retry = 'write', True
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.events, [('write', 2300)])

    def test_short_write_is_failure(self):
        """A device that transfers fewer bytes than asked is a write failure and latches the fault."""
        h = self.h
        h.short = True
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_fat_failure_retains_window(self):
        """A FAT write that failed keeps the window and its pending flag, so the change is retried instead of lost."""
        h = self.h
        h.set('FSInfoUnknown', 1, 2)
        h.set('NewFlags', 8, 2)
        h.mem.w32(WINDOW + C['F32B_Flags'], 1)
        h.fail = 'write'
        self.assertEqual(h.run('WriteFAT'), 0)
        self.assertEqual(h.mem.r32(WINDOW + C['F32B_Flags']), 1)
        self.assertNotEqual(h.get('NewFlags', 2) & 8, 0)

    def test_one_dirty_copy_disables_fast_mount(self):
        """One dirty FAT copy is enough to refuse clean eligibility, and the probe that finds it only reads."""
        h = self.h
        h.disk[2208][7] &= ~8
        h.exec_memory()
        self.assertNotEqual(h.run('InitDirtyState'), 0)
        self.assertEqual(h.get('DirtyEligible', 2), 0)
        self.assertTrue(all(kind == 'read' for kind, _ in h.events))

    def test_close_after_swap_never_flushes_old_buffers(self):
        """Closing after a media swap writes no buffer of the old card and drops the FAT window."""
        h = self.h
        h.prepare_close()
        h.dirty_buffer()
        head = GLOBALS + C['BufList']
        h.mem.w32(head, BB)
        h.mem.w32(head + 8, BB)
        h.mem.w32(BB, head + 4)
        h.mem.w32(BB + 4, head)
        h.set('NewFlags', 12, 2)
        h.set('MediaGeneration', 8)
        h.run('CloseDisk')
        self.assertEqual(h.events, [])
        self.assertEqual(h.get('FATBuffer'), 0)

    def test_failed_single_buffer_eviction_keeps_original_slot(self):
        """A one-entry cache eviction that failed keeps the original block and its dirty flag, and does not read the replacement over it."""
        h = self.h
        h.dirty_buffer()
        h.set('SingleBuf', BB)
        h.fail = 'write'
        self.assertEqual(h.run('ReadSingle', d0=1), 0)
        self.assertEqual(h.mem.r32(BB + C['BB_BlockNum']), 2300)
        self.assertEqual(h.mem.r32(BB + C['BB_DirtyFlags']), 0x80000000)
        self.assertNotIn(('read', 2049), h.events)

    def test_failed_fat_eviction_keeps_original_window(self):
        """A FAT window eviction that failed keeps the original window position and its pending flag."""
        h = self.h
        h.mem.w32(WINDOW + C['F32B_Flags'], 1)
        h.set('NewFlags', 8, 2)
        h.fail = 'write'
        self.assertEqual(h.run('MoveFATWindow', d0=4096), 0)
        self.assertEqual(h.mem.r32(WINDOW + C['F32B_Start']), 0)
        self.assertEqual(h.mem.r32(WINDOW + C['F32B_Flags']), 1)

    def test_failed_fat_read_never_invents_writable_entries(self):
        """A FAT read that failed leaves the window marked invalid instead of presenting invented entries as usable."""
        h = self.h
        h.fail = 'read'
        self.assertEqual(h.run('MoveFATWindow', d0=4096, d1=0xffffffff), 0)
        self.assertEqual(h.mem.r32(WINDOW + C['F32B_Start']), 0xffffffff)
        self.assertEqual(h.mem.r32(WINDOW + C['F32B_Flags']), 0)

    def test_update_disk_reports_flush_failure(self):
        """UpdateDisk reports a failed barrier to the caller and latches the write fault."""
        h = self.h
        h.set('NewFlags', 2, 2)
        h.fail = 'flush'
        self.assertEqual(h.run('UpdateDisk', d0=0xffffffff), 0)
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_failed_mount_close_discards_cache_without_volume_node(self):
        """A close with no volume node writes nothing and drops both the one-entry cache and the FAT window."""
        h = self.h
        h.prepare_close()
        h.set('VolumeNode', 0)
        h.dirty_buffer()
        h.set('SingleBuf', BB)
        h.set('SingleSize', 552)
        h.set('MediaGeneration', 8)
        h.run('CloseDisk')
        self.assertEqual(h.events, [])
        self.assertEqual(h.get('SingleBuf'), 0)
        self.assertEqual(h.get('FATBuffer'), 0)

    def test_no_media_close_discards_remaining_cache(self):
        """A close with no medium present writes nothing and drops both the one-entry cache and the FAT window."""
        h = self.h
        h.prepare_close()
        h.set('VolumeNode', 0)
        h.set('PhysFlags', 0, 2)
        h.dirty_buffer()
        h.set('SingleBuf', BB)
        h.set('SingleSize', 552)
        h.set('MediaGeneration', 8)
        h.run('CloseDisk')
        self.assertEqual(h.events, [])
        self.assertEqual(h.get('SingleBuf'), 0)
        self.assertEqual(h.get('FATBuffer'), 0)

    def test_failed_update_stops_motor_on_same_medium(self):
        """A failed update on the same medium still stops the motor and clears the idle work flags."""
        h = self.h
        h.stub('DiskMotorOff', lambda: h.events.append(('motor_off', 0)))
        h.set('WriteFault', 1, 2)
        h.set('NewFlags', 1, 2)
        self.assertEqual(h.run('UpdateDisk'), 0)
        self.assertEqual(h.events, [('motor_off', 0)])
        self.assertEqual(h.get('NewFlags', 2), 0)

    def test_failed_update_does_not_stop_replacement_motor(self):
        """A failed update after a swap leaves the replacement medium's motor alone."""
        h = self.h
        h.stub('DiskMotorOff', lambda: h.events.append(('motor_off', 0)))
        h.set('MediaGeneration', 8)
        h.set('NewFlags', 1, 2)
        self.assertEqual(h.run('UpdateDisk'), 0)
        self.assertEqual(h.events, [])
        self.assertEqual(h.get('NewFlags', 2), 0)

    def test_unlock_does_not_hide_latched_write_fault(self):
        """Unlocking clears the soft lock but leaves the latched write fault and the write-protected state visible."""
        h = self.h
        h.stub('s_return', lambda: None)
        h.run('LatchWriteFault')
        h.set('SoftLocked', 0xffff, 2)
        h.set('PassKey', 0)
        packet = 0x51000
        h.mem.w32(packet + C['DP_Arg1'], 0)
        h.mem.w32(packet + C['DP_Arg2'], 0)
        h.run('Action1023', a2=packet)
        self.assertEqual(h.get('SoftLocked', 2), 0)
        self.assertEqual(h.get('DiskState'), C['ID_WRITE_PROT'])
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_failed_flush_clears_idle_work_without_clearing_dirty_buffers(self):
        """A flush that failed clears the idle work flags but keeps the buffers flagged dirty, so their content is not dropped."""
        h = self.h
        h.dirty_buffer()
        h.set('WriteFault', 1, 2)
        h.set('NewFlags', 15, 2)
        self.assertEqual(h.run('UpdateDisk'), 0)
        self.assertEqual(h.get('NewFlags', 2), 0)
        self.assertEqual(h.mem.r32(BB + C['BB_DirtyFlags']), 0x80000000)

    def test_manual_diskchange_flushes_same_medium(self):
        """A manual disk change on the same medium flushes the pending buffer and leaves the card marked clean."""
        h = self.h
        h.prepare_close()
        h.stub('OpenDisk', lambda: h.result(0))
        h.dirty_buffer()
        head = GLOBALS + C['BufList']
        h.mem.w32(head, BB)
        h.mem.w32(head + 8, BB)
        h.mem.w32(BB, head + 4)
        h.mem.w32(BB + 4, head)
        h.set('NewFlags', 4, 2)
        h.run('IdentifyDisk')
        self.assertIn(('write', 2300), h.events)
        self.assertEqual(h.disk[2080][7] & 8, 8)

    def test_failed_eviction_does_not_reclassify_file_buffer(self):
        """An eviction that failed leaves the buffer's kind, the per-kind counters and its place on the list as they were."""
        h = self.h
        h.prepare_close()
        h.dirty_buffer()
        head = GLOBALS + C['BufList']
        h.mem.w32(head, BB)
        h.mem.w32(head + 8, BB)
        h.mem.w32(BB, head + 4)
        h.mem.w32(BB + 4, head)
        h.set('NormBufsUsed', 1, 2)
        h.set('NormBufsNum', 1, 2)
        h.set('DirBufsUsed', 0, 2)
        h.set('BlocksPerCluster', 1, 1)
        h.set('FSInfoUnknown', 1, 2)
        h.fail = 'write'
        self.assertEqual(h.run('ReadBlocks', d0=300, d1=C['RB_DIRREAD']), 0)
        self.assertEqual(h.mem.r16(BB + C['BB_Flags']) & 2, 0)
        self.assertEqual(h.get('DirBufsUsed', 2), 0)
        self.assertEqual(h.mem.r32(head), BB)

    def test_fat_reserved_entry_unchanged_through_metadata_and_close(self):
        """The reserved FAT entry is byte-identical after a metadata write and a close, across all four FAT-copy writes."""
        h = self.h
        before = {lba: bytes(h.disk[lba][4:8]) for lba in (2080, 2208)}
        h.run('ReadFAT')
        h.dirty_buffer()
        self.assertNotEqual(h.run('WriteBBuf', a0=BB), 0)
        h.prepare_close()
        h.run('CloseDisk')
        for lba, entry in before.items():
            self.assertEqual(h.disk[lba][4:8], entry)
        self.assertEqual(sum(kind == 'write' and lba in before
                             for kind, lba in h.events), 4)

    def test_fat_write_preserves_reserved_entry_in_each_copy(self):
        """A FAT write carries the changed entry into both copies and leaves the reserved entry untouched in each."""
        h = self.h
        before = bytes(h.disk[2080][4:8])
        h.set('NewFlags', 8, 2)
        h.mem.w32(WINDOW + C['F32B_Flags'], 1)
        h.mem.w_block(WINDOW + C['F32B_Data'] + 8, b'link')
        self.assertNotEqual(h.run('WriteFAT'), 0)
        for lba in (2080, 2208):
            self.assertEqual(h.disk[lba][4:8], before)
            self.assertEqual(h.disk[lba][8:12], b'link')

    def test_swap_during_marker_read_blocks_metadata(self):
        """A swap noticed during the marker read stops after that read and leaves the buffer dirty."""
        h = self.h
        h.swap_on = 'read'
        h.dirty_buffer()
        self.assertEqual(h.run('WriteBBuf', a0=BB), 0)
        self.assertEqual([kind for kind, _ in h.events], ['read'])
        self.assertEqual(h.mem.r32(BB + C['BB_DirtyFlags']), 0x80000000)

    def test_foreign_single_eviction_failure_retains_both_buffers(self):
        """When evicting a foreign one-entry block fails, that block and the pending multi-block buffer both keep their content and dirty flags, and no payload is written."""
        h = self.h
        h.run('ReadFAT')
        h.dirty_single(2400)
        single = h.get('SingleBuf')
        h.dirty_buffer_multi(2)
        h.fail = 'write'
        h.events.clear()
        self.assertEqual(h.run('WriteBBuf', a0=BB), 0)
        self.assertEqual(h.mem.r32(single + C['BB_BlockNum']), 2400)
        self.assertEqual(h.mem.r32(single + C['BB_DirtyFlags']), 0x80000000)
        self.assertEqual(h.mem.r32(BB + C['BB_DirtyFlags']), 0xc0000000)
        self.assertNotIn(('write', 2300), h.events)
        self.assertNotIn(('write', 2301), h.events)

    def test_open_resets_prior_medium_state_on_failed_probe(self):
        """A failed probe on open resets every per-medium state field and records the new mount generation, without touching the device."""
        h = self.h
        for name in ('FSInfoUnknown', 'FSInfoDirty', 'WriteFault',
                     'CheckComplete', 'ScanActive'):
            h.set(name, 1, 2)
        h.set('ReadFailures', 2)
        h.set('MediaGeneration', 8)
        h.stub('GetDiskParams', lambda: h.result(0))
        h.run('OpenDisk')
        for name in ('FSInfoUnknown', 'FSInfoDirty', 'WriteFault',
                     'CheckComplete', 'ScanActive'):
            self.assertEqual(h.get(name, 2), 0, name)
        self.assertEqual(h.get('ReadFailures'), 0)
        self.assertEqual(h.get('FSInfoBlock'), 0)
        self.assertEqual(h.get('MountGeneration'), 8)
        self.assertEqual(h.events, [])

    def test_scan_read_failure_does_not_publish_partial_count(self):
        """A scan stopped by a read failure does not complete, and the partial count it reached is never published."""
        h = self.h
        h.prepare_check()
        def unreadable():
            h.set('ReadFailures', 1)
            h.result(0)
        h.stub('ReadDirBlock', unreadable)
        h.run('ScanDisk')
        self.assertEqual(h.get('CheckComplete', 2), 0)
        h.fail = None
        h.events.clear()
        h.run('UpdateDisk', d0=0xffffffff)
        self.assertNotIn(('write', 2049), h.events)

    def test_scan_directory_buffer_failure_does_not_complete(self):
        """A scan that cannot obtain a directory buffer does not complete and records no read failure."""
        h = self.h
        h.prepare_check()
        h.stub('ReadDirBlock', lambda: h.result(0))
        h.run('ScanDisk')
        self.assertEqual(h.get('CheckComplete', 2), 0)
        self.assertEqual(h.get('ReadFailures'), 0)

    def test_scan_allocation_failure_does_not_complete(self):
        """A scan that cannot allocate does not complete and issues no I/O."""
        h = self.h
        h.trap(0x70000 + C['AllocMem'], lambda: h.result(0))
        h.run('ScanDisk')
        self.assertEqual(h.get('CheckComplete', 2), 0)
        self.assertEqual(h.events, [])

    def test_interrupted_scan_does_not_complete(self):
        """A scan the user aborts does not complete, so its count is not treated as known."""
        h = self.h
        h.prepare_check()
        def escape():
            h.mem.w16(h.cpu.r_reg(13) + C['SD_LASTKEY'], C['KEY_ESC'])
        h.stub('sd_text', escape)
        h.run('ScanDisk')
        self.assertEqual(h.get('CheckComplete', 2), 0)

    def test_update_publishes_count_after_metadata_barrier(self):
        """UpdateDisk marks, writes the metadata, publishes the real count behind a barrier and ends with a final flush."""
        h = self.h
        h.run('ReadFAT')
        h.prepare_close()
        h.dirty_buffer()
        head = GLOBALS + C['BufList']
        h.mem.w32(head, BB)
        h.mem.w32(head + 8, BB)
        h.mem.w32(BB, head + 4)
        h.mem.w32(BB + 4, head)
        h.set('NewFlags', 4, 2)
        h.events.clear()
        self.assertNotEqual(h.run('UpdateDisk', d0=0xffffffff), 0)
        writes = [(i, lba) for i, (kind, lba) in enumerate(h.events)
                  if kind == 'write']
        self.assertEqual([lba for _, lba in writes], [2080, 2208, 2049, 2300, 2049, 2080, 2208])
        metadata_index, publish_index = writes[3][0], writes[4][0]
        self.assertTrue(any(kind == 'flush' for kind, _ in
                            h.events[metadata_index + 1:publish_index]))
        self.assertEqual(h.events[-1][0], 'flush')
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 125)

    def test_successful_scan_publishes_count_without_touching_reserved_entry(self):
        """A completed scan publishes its count and leaves the reserved FAT entry of both copies untouched."""
        h = self.h
        h.prepare_check()
        before = {lba: bytes(h.disk[lba][4:8]) for lba in (2080, 2208)}
        h.run('ScanDisk')
        self.assertEqual(h.get('CheckComplete', 2), 1)
        self.assertEqual(h.get('ScanActive', 2), 0)
        h.run('UpdateDisk', d0=0xffffffff)
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 125)
        for lba, entry in before.items():
            self.assertEqual(h.disk[lba][4:8], entry)

    def test_new_check_recovers_prior_plain_read_failure(self):
        """A new scan clears the read-failure count an earlier one left and publishes its result without a write fault."""
        h = self.h
        h.prepare_check()
        h.set('ReadFailures', 3)
        h.run('ScanDisk')
        self.assertEqual(h.get('ReadFailures'), 0)
        self.assertEqual(h.get('CheckComplete', 2), 1)
        self.assertEqual(h.get('WriteFault', 2), 0)
        h.run('UpdateDisk', d0=0xffffffff)
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 125)

    def test_prior_plain_read_failure_does_not_block_known_count(self):
        """An earlier plain read failure does not stop a count the handler actually knows from being published."""
        h = self.h
        h.run('ReadFAT')
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        h.set('ReadFailures', 1)
        self.assertNotEqual(h.run('UpdateDisk', d0=0xffffffff), 0)
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 125)
        self.assertEqual(h.get('WriteFault', 2), 0)

    def test_diskstatus_keeps_faulted_volume_write_protected(self):
        """DiskStatus on a faulted volume issues only the change-state and protection queries and keeps reporting write-protected although the medium itself is writable."""
        h = self.h
        commands = []
        def status_io():
            req = h.cpu.r_reg(9)
            cmd = h.mem.r16(req + C['IO_Command'])
            commands.append(cmd)
            self.assertIn(cmd, (C['TD_CHANGESTATE'], C['TD_PROTSTATUS']))
            h.mem.w32(req + C['IO_Actual'], 0)
            h.result(0)
        h.stub('SafeDoIO', status_io)
        h.run('LatchWriteFault')
        self.assertEqual(h.run('DiskStatus'), 3)  # physical medium remains writable
        self.assertEqual(commands, [C['TD_CHANGESTATE'], C['TD_PROTSTATUS']])
        self.assertEqual(h.get('DiskState'), C['ID_WRITE_PROT'])
        self.assertEqual(h.get('WriteFault', 2), 1)

    def prepare_pending_softlock(self):
        h = self.h
        h.run('ReadFAT')
        h.dirty_buffer()
        h.run('WriteBBuf', a0=BB)
        h.run('UpdateDisk', d0=0xffffffff)
        self.assertEqual(h.get('FSInfoUnknown', 2), 0)
        h.prepare_close()
        h.dirty_buffer()
        h.mem.w_block(BB + C['BB_Data'], b'y' * 512)
        head = GLOBALS + C['BufList']
        h.mem.w32(head, BB)
        h.mem.w32(head + 8, BB)
        h.mem.w32(BB, head + 4)
        h.mem.w32(BB + 4, head)
        h.set('NewFlags', 4, 2)
        h.stub('s_return', lambda: None)
        packet = 0x51000
        h.mem.w32(packet + C['DP_Arg1'], 1)
        h.mem.w32(packet + C['DP_Arg2'], 0x12345678)
        h.events.clear()
        return packet

    def test_softlock_flushes_accepted_metadata_before_locking(self):
        """A soft lock that is accepted flushes the pending metadata behind a barrier and stores the key, leaving the following close with nothing to write."""
        h = self.h
        packet = self.prepare_pending_softlock()
        self.assertNotEqual(h.run('Action1023', a2=packet), 0)
        self.assertEqual(h.get('SoftLocked', 2), 0xffff)
        self.assertEqual(h.get('PassKey'), 0x12345678)
        self.assertEqual(h.disk[2300], b'y' * 512)
        writes = [(i, lba) for i, (kind, lba) in enumerate(h.events)
                  if kind == 'write']
        self.assertEqual([lba for _, lba in writes], [2080, 2208, 2049, 2300, 2049, 2080, 2208])
        self.assertTrue(any(kind == 'flush' for kind, _ in
                            h.events[writes[2][0] + 1:writes[3][0]]))
        h.events.clear()
        h.run('CloseDisk')
        self.assertEqual(h.disk[2300], b'y' * 512)
        self.assertFalse(any(kind == 'write' for kind, _ in h.events))

    def test_softlock_failed_flush_retains_accepted_metadata(self):
        """A soft lock whose flush failed is not applied: the fault latches, the buffer stays dirty and the payload is not written."""
        h = self.h
        packet = self.prepare_pending_softlock()
        h.fail = 'write'
        self.assertEqual(h.run('Action1023', a2=packet), 0)
        self.assertEqual(h.get('SoftLocked', 2), 0)
        self.assertEqual(h.get('WriteFault', 2), 1)
        self.assertEqual(h.mem.r32(BB + C['BB_DirtyFlags']), 0x80000000)
        self.assertEqual(h.disk[2300], b'x' * 512)
        self.assertNotIn(('write', 2300), h.events)

    def device_protection(self, protected):
        h = self.h
        def io():
            req = h.cpu.r_reg(9)
            cmd = h.mem.r16(req + C['IO_Command'])
            if cmd in (C['TD_CHANGESTATE'], C['TD_PROTSTATUS']):
                h.mem.w32(req + C['IO_Actual'], int(protected and cmd == C['TD_PROTSTATUS']))
                h.result(0)
            else:
                h.io()
        h.stub('SafeDoIO', io)

    def test_diskstatus_refreshes_physical_writability(self):
        """DiskStatus re-reads the device protection and promotes the volume back to writable when the medium is."""
        h = self.h
        h.set('PhysFlags', 9, 2)
        h.run('ReadFAT')
        self.device_protection(False)
        self.assertEqual(h.run('DiskStatus'), 3)
        self.assertEqual(h.get('PhysFlags', 2), 11)
        self.assertEqual(h.get('DiskState'), C['ID_VALIDATED'])

    def test_promoted_volume_flushes_accepted_fat_change(self):
        """A volume promoted back to writable accepts a FAT change and flushes it to both copies with no fault."""
        h = self.h
        h.set('PhysFlags', 1, 2)
        h.run('ReadFAT')
        self.device_protection(False)
        h.run('DiskStatus')
        h.set('RootXLock', 0x50000)
        self.assertNotEqual(h.run('Ok2Write'), 0)
        h.mem.w32(WINDOW + C['F32B_Start'], 0)
        h.mem.w32(WINDOW + C['F32B_Flags'], 1)
        h.set('NewFlags', 8, 2)
        h.events.clear()
        self.assertNotEqual(h.run('UpdateDisk', d0=0xffffffff), 0)
        self.assertIn(('write', 2080), h.events)
        self.assertIn(('write', 2208), h.events)
        self.assertEqual(h.get('WriteFault', 2), 0)

    def test_diskstatus_records_physical_protection_only(self):
        """DiskStatus records physical protection in the device flags and reports the volume write-protected."""
        h = self.h
        h.set('PhysFlags', 11, 2)
        self.device_protection(True)
        self.assertEqual(h.run('DiskStatus'), 1)
        self.assertEqual(h.get('PhysFlags', 2), 9)
        self.assertEqual(h.get('DiskState'), C['ID_WRITE_PROT'])

    def test_softlock_does_not_clear_physical_writability(self):
        """A soft lock leaves the physical writability flag set, so lifting the lock needs no fresh probe."""
        h = self.h
        h.set('PhysFlags', 9, 2)
        h.set('SoftLocked', 1, 2)
        self.device_protection(False)
        self.assertEqual(h.run('DiskStatus'), 3)
        self.assertEqual(h.get('PhysFlags', 2), 11)
        self.assertEqual(h.get('DiskState'), C['ID_WRITE_PROT'])

    def test_unreported_transfer_length_fails_closed(self):
        """A driver reporting no error but no transferred length is treated as a failure: the fault latches, the volume goes write-protected, nothing is written and the buffer stays dirty."""
        h = self.h
        def no_length_io():
            h.result(0)  # driver reports no error but leaves io_Actual untouched
        h.stub('SafeDoIO', no_length_io)
        self.assertEqual(h.run('_Write', d0=2300, d1=1, a0=BUFFER), 0)
        self.assertEqual(h.get('WriteFault', 2), 1)
        self.assertEqual(h.get('DiskState'), C['ID_WRITE_PROT'])
        self.assertNotIn(2300, h.disk)
        h.stub('SafeDoIO', h.io)
        h.dirty_buffer()
        self.assertEqual(h.run('WriteBBuf', a0=BB), 0)
        self.assertEqual(h.events, [])
        self.assertEqual(h.mem.r32(BB + C['BB_DirtyFlags']), 0x80000000)

    def test_idle_flush_publishes_once_per_batch(self):
        """The idle flush publishes the count once per batch of metadata rather than once per block, and an idle flush with nothing pending issues no I/O at all."""
        h = self.h
        self.prepare_pending_softlock()
        h.run('UpdateDisk', d0=0)
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 0xffffffff)
        self.assertEqual([lba for kind, lba in h.events if kind == 'write'], [2080, 2208, 2049, 2300])
        self.assertNotEqual(h.run('UpdateDisk', d0=0), 0)
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 125)
        self.assertEqual(h.get('FSInfoDirty', 2), 0)
        self.assertEqual(h.get('FSInfoUnknown', 2), 0)
        self.assertEqual(h.get('NewFlags', 2), 0)
        self.assertEqual([lba for kind, lba in h.events if kind == 'write'], [2080, 2208, 2049, 2300, 2049, 2080, 2208])
        h.events.clear()
        h.run('UpdateDisk', d0=0)
        self.assertEqual(h.events, [])
        h.dirty_buffer()
        h.set('NewFlags', 4, 2)
        h.run('UpdateDisk', d0=0)
        self.assertEqual([kind for kind, _ in h.events if kind != 'read'][:4], ['write', 'write', 'flush', 'write'])
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 0xffffffff)

    def test_idle_flush_publishes_completed_scan_count(self):
        """The idle flush publishes the count a completed scan produced and clears the pending flag."""
        h = self.h
        h.run('ReadFAT')
        h.set('FSInfoDirty', 1, 2)
        h.set('FreeClusters', 124)
        h.set('NewFlags', 2, 2)
        self.assertNotEqual(h.run('UpdateDisk', d0=0), 0)
        self.assertEqual(int.from_bytes(h.disk[2049][488:492], 'little'), 124)
        self.assertEqual(h.get('FSInfoDirty', 2), 0)
