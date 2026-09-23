"""File handles follow the replacement chain after truncate-to-zero and growth."""
import struct
import tempfile
import unittest
from pathlib import Path

from harness import C, GLOBALS, Handler, load


class ResizeTests(unittest.TestCase):
    """Resizing preserves the cluster state of every live handle."""
    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.image = load(Path(tmp.name) / 'handler.hunk')

    def test_truncate_at_eof_then_extend_retargets_handles(self):
        """Truncation resets both handles; growth points both at the new chain."""
        h = Handler(self.image)
        self.addCleanup(h.close)
        handle, other, lock, shim = 0x52000, 0x52100, 0x53000, 0x58000
        tail = GLOBALS + C['FileList'] + 4
        h.set('FileList', handle)
        h.mem.w32(tail, 0)
        h.mem.w32(handle, other)
        h.mem.w32(other, tail)
        for item in (handle, other):
            h.mem.w32(item + C['XFH_XLock'], lock)
            h.mem.w32(item + C['XFH_Cluster'], 5)
        h.mem.w32(handle + C['XFH_CurrentPos'], 17)
        h.mem.w32(lock + C['XL_Volume'], h.get('VolumeNode'))
        h.mem.w32(lock + C['XL_MSDE'] + C['MSDE_FSize'], 17)
        h.mem.w16(lock + C['XL_MSDE'] + C['MSDE_1L'], 5)
        h.set('FATType', 0, 2)
        h.set('ClusterShift', 0, 2)
        h.set('ClusterMask', 511)
        freed = []
        def free_chain():
            freed.append(h.cpu.r_reg(0))
            h.result(0xffffffff)
        h.stub('FreeChain', free_chain)
        h.stub('ExtendChain', lambda: h.result(7))

        def resize(size):
            code = b''.join(b'\x2f\x3c' + struct.pack('>I', value)
                            for value in (0xffffffff, size, handle))
            code += b'\x4e\xb9' + struct.pack('>I', h.syms['SetFileSize'])
            code += b'\xde\xfc\x00\x0c\x4e\x75'
            h.mem.w_block(shim, code)
            h.syms['resize_call'] = shim
            return h.run('resize_call')

        self.assertEqual(resize(0), 0)
        self.assertEqual(freed, [5])
        self.assertEqual(resize(17), 17)
        for item in (handle, other):
            self.assertEqual(h.mem.r32(item + C['XFH_CurrentPos']), 0)
            self.assertEqual(h.mem.r32(item + C['XFH_Cluster']), 7)


if __name__ == '__main__':
    unittest.main()
