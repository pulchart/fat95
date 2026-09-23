"""Failed FAT access stops mutation and reports failure to file operations."""
import struct
import tempfile
import unittest
from pathlib import Path

from harness import C, GLOBALS, Handler, WINDOW, load


class MutationFaultTests(unittest.TestCase):
    """Unreadable FAT windows must not become successful deletes or resizes."""
    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.image = load(Path(tmp.name) / 'handler.hunk')

    def setUp(self):
        self.h = h = Handler(self.image)
        self.addCleanup(h.close)
        self.reads = []
        h.set('LastCluster', 5000)
        h.set('FreeClusters', 10)
        h.set('NextFreeCluster', 4096)

        def read():
            self.reads.append(h.cpu.r_reg(0))
            h.result(0)
        h.stub('_Read', read)

    def file(self):
        h = self.h
        handle, lock = 0x52000, 0x53000
        tail = GLOBALS + C['FileList'] + 4
        h.set('FileList', handle)
        h.mem.w32(handle, tail)
        h.mem.w32(tail, 0)
        h.mem.w32(handle + C['XFH_XLock'], lock)
        h.mem.w32(handle + C['XFH_Cluster'], 4096)
        h.mem.w16(lock + C['XL_OpenCnt'], 1)
        h.mem.w32(lock + C['XL_Volume'], h.get('VolumeNode'))
        h.mem.w32(lock + C['XL_FilePos'], 1024)
        h.mem.w32(lock + C['XL_FileChain'], 4096)
        h.mem.w32(lock + C['XL_MSDE'] + C['MSDE_FSize'], 1024)
        h.mem.w16(lock + C['XL_MSDE'] + C['MSDE_1L'], 4096)
        h.set('ClusterShift', 0, 2)
        h.set('ClusterMask', 511)
        return handle, lock

    def resize(self, handle, size):
        h, shim = self.h, 0x58000
        code = b''.join(b'\x2f\x3c' + struct.pack('>I', value)
                        for value in (0xffffffff, size, handle))
        code += b'\x4e\xb9' + struct.pack('>I', h.syms['SetFileSize'])
        code += b'\xde\xfc\x00\x0c\x4e\x75'
        h.mem.w_block(shim, code)
        h.syms['resize_call'] = shim
        return h.run('resize_call')

    def unchanged_allocation(self):
        h = self.h
        self.assertEqual(h.get('FreeClusters'), 10)
        self.assertEqual(h.get('NextFreeCluster'), 4096)
        self.assertEqual(h.get('NewFlags', 2), 0)
        self.assertEqual(h.get('ErrorNum', 2), 225)
        self.assertEqual(len(self.reads), 2)

    def test_free_chain_stops_before_failed_entry(self):
        """An unreadable first link frees nothing and returns false."""
        self.assertEqual(self.h.run('FreeChain', d0=4096), 0)
        self.unchanged_allocation()

    def test_failed_free_keeps_an_unset_allocation_hint(self):
        """A first-link failure preserves NextFreeCluster=0 instead of publishing -1."""
        h = self.h
        h.set('NextFreeCluster', 0)
        self.assertEqual(h.run('FreeChain', d0=4096), 0)
        self.assertEqual(h.get('NextFreeCluster'), 0)
        self.assertEqual(h.get('FreeClusters'), 10)

    def test_free_chain_counts_only_the_successfully_freed_prefix(self):
        """A later read error retains prefix accounting without claiming rollback."""
        h = self.h
        address = WINDOW + C['F32B_Data'] + 4095 * 4
        h.mem.w_block(address, (4096).to_bytes(4, 'little'))
        # Let eviction finish; the subsequent window read fails on both copies.
        def flush():
            h.mem.w32(WINDOW + C['F32B_Flags'], 0)
            h.set('NewFlags', 0, 2)
            h.result(0xffffffff)
        h.stub('WriteFAT', flush)
        self.assertEqual(h.run('FreeChain', d0=4095), 0)
        self.assertEqual(h.mem.r32(address), 0)
        self.assertEqual(h.get('FreeClusters'), 11)
        self.assertEqual(h.get('NextFreeCluster'), 4095)
        self.assertEqual(h.get('ErrorNum', 2), 225)
        self.assertEqual(len(self.reads), 2)

    def test_delete_keeps_object_metadata_after_failed_free(self):
        """FreeObj fails without clearing the file size, first cluster or append hint."""
        h = self.h
        _, lock = self.file()
        h.stub('TouchXLock', lambda: h.result(0xffffffff))
        before = bytes(h.mem.r_block(lock, C['XL_Sizeof']))
        self.assertEqual(h.run('FreeObj', a0=lock), 0)
        self.assertEqual(bytes(h.mem.r_block(lock, C['XL_Sizeof'])), before)
        self.unchanged_allocation()

    def check_resize_failure(self, size):
        h = self.h
        handle, lock = self.file()
        before = bytes(h.mem.r_block(lock, C['XL_Sizeof']))
        fh_before = bytes(h.mem.r_block(handle, C['XFH_Sizeof']))
        self.assertEqual(self.resize(handle, size), 0xffffffff)
        self.assertEqual(bytes(h.mem.r_block(lock, C['XL_Sizeof'])), before)
        self.assertEqual(bytes(h.mem.r_block(handle, C['XFH_Sizeof'])), fh_before)
        self.unchanged_allocation()

    def test_zero_truncate_preserves_metadata_on_read_error(self):
        """Truncate-to-zero keeps metadata when the first FAT lookup fails."""
        self.check_resize_failure(0)

    def test_partial_truncate_does_not_cut_at_a_failed_lookup(self):
        """Boundary lookup failure writes no false EOC and reports the read error."""
        self.check_resize_failure(512)

    def test_growth_does_not_report_old_size_as_success_on_read_error(self):
        """Growth reports failure, rather than partial disk-full success, on read error."""
        self.check_resize_failure(1536)

    def test_disk_full_growth_still_returns_the_partially_allocated_size(self):
        """Disk full after one new cluster retains the established partial-resize result."""
        h = self.h
        handle, lock = self.file()
        calls = []
        def extend():
            calls.append(h.cpu.r_reg(0))
            if len(calls) == 1:h.result(4097)
            else:
                h.set('ErrorNum', 221, 2)
                h.result(0xffffffff)
        h.stub('ExtendChain', extend)
        self.assertEqual(self.resize(handle, 2048), 1536)
        self.assertEqual(calls, [4096, 4097])
        self.assertEqual(h.mem.r32(lock + C['XL_MSDE'] + C['MSDE_FSize']), 1536)
        self.assertEqual(h.mem.r32(lock + C['XL_FileChain']), 4097)
        self.assertEqual(h.mem.r16(handle + C['XFH_Changed']), 1)
        self.assertEqual(h.get('ErrorNum', 2), 221)
        self.assertEqual(h.get('WriteFault', 2), 0)

    def test_missing_fat_does_not_turn_stale_disk_full_into_partial_resize(self):
        """Missing FAT during growth returns failure even after an earlier disk-full error."""
        h = self.h
        handle, lock = self.file()
        h.set('FATBuffer', 0)
        h.set('ErrorNum', 221, 2)
        self.assertEqual(self.resize(handle, 1536), 0xffffffff)
        self.assertEqual(h.mem.r32(lock + C['XL_MSDE'] + C['MSDE_FSize']), 1024)
        self.assertEqual(h.mem.r16(handle + C['XFH_Changed']), 0)
        self.assertEqual(h.get('ErrorNum', 2), 225)
        self.assertEqual(h.get('WriteFault', 2), 1)

    def test_allocation_rejects_media_change_before_marking_new_cluster(self):
        """A generation change after lookup prevents marking and restores the free count."""
        h = self.h
        def read():
            count = h.cpu.r_reg(1)
            h.mem.w_block(h.cpu.r_reg(9), bytes(count * 512))
            h.set('MediaGeneration', h.get('MountGeneration') + 1)
            h.result(count)
        h.stub('_Read', read)
        self.assertEqual(h.run('ExtendChain', d0=0), 0xffffffff)
        self.assertEqual(h.get('FreeClusters'), 10)
        self.assertEqual(h.get('NextFreeCluster'), 4096)
        self.assertEqual(h.get('NewFlags', 2), 0)
        self.assertEqual(h.get('ErrorNum', 2), 225)

    def test_failed_predecessor_write_reports_failure_after_allocating_cluster(self):
        """A failed predecessor-window reload reports failure; the allocated cluster stays counted."""
        h = self.h
        address = WINDOW + C['F32B_Data']
        h.mem.w_block(address + 4095 * 4, (0xfffffff).to_bytes(4, 'little'))
        def read():
            self.reads.append(h.cpu.r_reg(0))
            if len(self.reads) == 1:
                count = h.cpu.r_reg(1)
                h.mem.w_block(h.cpu.r_reg(9), bytes(count * 512))
                h.result(count)
            else:h.result(0)
        def flush():
            h.mem.w32(WINDOW + C['F32B_Flags'], 0)
            h.set('NewFlags', 0, 2)
            h.result(0xffffffff)
        h.stub('_Read', read)
        h.stub('WriteFAT', flush)
        self.assertEqual(h.run('ExtendChain', d0=4095), 0xffffffff)
        self.assertEqual(h.get('FreeClusters'), 9)
        self.assertEqual(h.get('NextFreeCluster'), 4096)
        self.assertEqual(h.get('ErrorNum', 2), 225)
        self.assertEqual(h.get('WriteFault', 2), 1)
        self.assertEqual(len(self.reads), 3)

    def test_entry_write_failure_latches_and_replaces_stale_disk_full(self):
        """A refused mutation invalidates scan success and replaces stale disk-full status."""
        h = self.h
        h.set('MediaGeneration', h.get('MountGeneration') + 1)
        for kind in (0, 1, 0xffff):
            with self.subTest(fat_type=kind):
                h.set('FATType', kind, 2)
                h.set('WriteFault', 0, 2)
                h.set('ErrorNum', 221, 2)
                h.set('CheckComplete', 1, 2)
                self.assertEqual(h.run('PutFATEntry', d0=2, d1=0), 0)
                self.assertEqual(h.get('WriteFault', 2), 1)
                self.assertEqual(h.get('CheckComplete', 2), 0)
                self.assertEqual(h.get('ErrorNum', 2), 225)
                self.assertEqual(h.get('NewFlags', 2), 0)


if __name__ == '__main__':
    unittest.main()
