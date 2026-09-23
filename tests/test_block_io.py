"""Block I/O encodes offsets, splits requests and rejects short transfers.

The real read/write routines run; only the device call is replaced. No large
image or payload transfer is needed to inspect the requests above 4 GiB.
"""
import tempfile
import unittest
from pathlib import Path

from harness import Handler, C, GLOBALS, BUFFER, load


class BlockIOTests(unittest.TestCase):
    """Device requests preserve addresses, lengths and failure status."""

    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.image = load(Path(tmp.name) / 'handler.hunk')

    def transfer(self, write, start, count, size=512, maximum=512,
                 scsi=False, legacy=False, short_at=None):
        h = Handler(self.image)
        requests = []
        try:
            h.set('FATType', 0, 2)  # FAT12: isolate transfer from dirty markers.
            h.set('BlockSize', size, 2)
            h.set('BlockShift', size.bit_length() - 1, 2)
            h.set('BlockMask', size - 1)
            h.set('CmdFlags', 4 if scsi else 0, 2)
            h.set('ReadCmd', 2 if legacy else 0xc000, 2)
            h.set('WriteCmd', 3 if legacy else 0xc001, 2)
            h.mem.w32(GLOBALS + C['EnvecBuf'] + C['DE_MaxTransfer'], maximum)

            def device():
                req = h.cpu.r_reg(9)
                command = h.mem.r16(req + C['IO_Command'])
                if scsi:
                    request = h.mem.r32(req + C['IO_Data'])
                    cdb = h.mem.r32(request + C['SCSI_Command'])
                    length = h.mem.r32(request + C['SCSI_Length'])
                    record = (command, bytes(h.mem.r_block(cdb, 10)), length,
                              h.mem.r32(request + C['SCSI_Data']))
                    actual = request + C['SCSI_Actual']
                else:
                    length = h.mem.r32(req + C['IO_Length'])
                    offset = (h.mem.r32(req + C['IO_Actual']) << 32 |
                              h.mem.r32(req + C['IO_Offset']))
                    record = (command, offset, length, h.mem.r32(req + C['IO_Data']))
                    actual = req + C['IO_Actual']
                requests.append(record)
                h.mem.w32(actual, length - size if len(requests) == short_at else length)
                h.result(0)

            h.stub('SafeDoIO', device)
            args = dict(d0=start, d1=count)
            args['a0' if write else 'a1'] = BUFFER
            done = h.run('_Write' if write else '_Read', **args)
            return done, requests, h.get('WriteFault', 2)
        finally:
            h.close()

    def test_td64_requests_cross_four_gib(self):
        """TD64 preserves the high offset across 4 GiB for 512–4096-byte blocks."""
        for write in (False, True):
            for size in (512, 1024, 4096):
                with self.subTest(write=write, size=size):
                    start = (1 << 32) // size - 1
                    done, requests, _ = self.transfer(write, start, 3, size, size)
                    expected = [(0xc001 if write else 0xc000, (start+i)*size,
                                 size, BUFFER+i*size) for i in range(3)]
                    self.assertEqual((done, requests), (3, expected))

    def test_td64_large_lba_keeps_all_offset_bits(self):
        """Large LBAs retain every high-offset bit instead of wrapping at 4 GiB."""
        for write in (False, True):
            done, requests, _ = self.transfer(write, 0x12345678, 1)
            self.assertEqual(done, 1)
            self.assertEqual(requests[0][1], 0x12345678 * 512)

    def test_maxtransfer_uses_whole_blocks(self):
        """Legacy requests round MaxTransfer down and advance the buffer and LBA."""
        for write in (False, True):
            done, requests, _ = self.transfer(write, 17, 5, maximum=1535, legacy=True)
            cmd = 3 if write else 2
            self.assertEqual((done, requests), (5, [
                (cmd, 17*512, 1024, BUFFER),
                (cmd, 19*512, 1024, BUFFER+1024),
                (cmd, 21*512, 512, BUFFER+2048)]))

    def test_short_second_request_fails_whole_transfer(self):
        """A short later transfer stops I/O and fails the whole block request."""
        for write in (False, True):
            done, requests, fault = self.transfer(write, 17, 5, maximum=1024, short_at=2)
            self.assertEqual((done, len(requests)), (0, 2))
            if write:
                self.assertEqual(fault, 1)

    def test_scsi_ten_byte_count_does_not_wrap(self):
        """READ10/WRITE10 split 65536 blocks into 65535 and one, retaining the LBA."""
        for write in (False, True):
            done, requests, _ = self.transfer(write, 0x12345678, 65536,
                                              maximum=65536*512, scsi=True)
            expected = []
            for lba, count, buffer in [(0x12345678, 65535, BUFFER),
                                       (0x12355677, 1, BUFFER+65535*512)]:
                cdb = (bytes([0x2a if write else 0x28, 0]) + lba.to_bytes(4, 'big') +
                       b'\0' + count.to_bytes(2, 'big') + b'\0')
                expected.append((C['HD_SCSICMD'], cdb, count*512, buffer))
            self.assertEqual((done, requests), (65536, expected))


if __name__ == '__main__':
    unittest.main()
