#!/usr/bin/env python3
"""debug95 asks the handler with a packet of its own and waits at most ten seconds or until Ctrl-C.

Real assembled code from src/debug95.s, mocked exec and dos.library.

Status: library, collected by unittest like any other test file.
Run: make test
"""

import tempfile
import unittest
from pathlib import Path

from amitools.binfmt.BinFmt import BinFmt
from amitools.binfmt.Relocate import Relocate
from amitools.vamos.machine import Machine
from toolchain import assemble

BASE, EXEC, DOS, STACK = 0x10000, 0x300000, 0x320000, 0x200000
ARGS, PORT, PKT, HPORT, DEVPROC = 0x340000, 0x341000, 0x342000, 0x343000, 0x344000
GLOBALS, FH, OUT = 0x350000, 0x360000, 0x361000
SIGBIT = 20
DUMP = bytes(range(64))  # DebugSize 0x00010203 is too large, set below

EXEC_LVO = {"OpenLibrary": 552, "CloseLibrary": 414, "CreateMsgPort": 666,
            "DeleteMsgPort": 672, "GetMsg": 372, "FreeSignal": 336}  # fmt: skip
DOS_LVO = {"GetDeviceProc": 642, "FreeDeviceProc": 648, "AllocDosObject": 228,
           "FreeDosObject": 234, "SendPkt": 246, "CheckSignal": 792, "Delay": 198,
           "Open": 30, "Write": 48, "Close": 36, "Output": 60}  # fmt: skip


class Fake:
    """One run of debug95 FA0: RAM:x.dump; answer_at and break_at count the looks for the answer."""

    def __init__(self, image, answer_at=None, break_at=None):
        self.m = Machine.from_name("68000", ram_size=8192)
        self.mem, self.cpu = self.m.get_mem(), self.m.get_cpu()
        self.mem.w_block(BASE, bytes(Relocate(image).relocate_one_block(BASE)))
        seg = image.get_segments()[0]
        self.start = BASE + next(
            s.offset for s in seg.get_symtab().get_symbols() if s.name.decode() == "Start"
        )
        self.answer_at, self.break_at = answer_at, break_at
        self.looks = self.breaks = 0
        self.calls = []
        self.written = []
        self.printed = b""
        self.mem.w32(4, EXEC)
        for name, lvo in EXEC_LVO.items():
            self.trap(EXEC - lvo, name)
        for name, lvo in DOS_LVO.items():
            self.trap(DOS - lvo, name)
        self.mem.w32(DEVPROC, HPORT)  # DVP_Port
        dump = bytearray(DUMP)
        dump[0:4] = len(dump).to_bytes(4, "big")  # DebugSize
        self.mem.w_block(GLOBALS, bytes(dump))
        self.dump = bytes(dump)

    def trap(self, addr, name):
        fn = getattr(self, name)

        def call(op, pc):
            self.calls.append(name)
            self.cpu.w_reg(0, fn() & 0xFFFFFFFF)

        tid = self.m.get_traps().alloc(call)
        self.mem.w16(addr, 0xA000 | tid)
        self.mem.w16(addr + 2, 0x4E75)

    def reg(self, n):
        return self.cpu.r_reg(n)

    # exec
    def OpenLibrary(self):
        return DOS

    def CloseLibrary(self):
        return 0

    def CreateMsgPort(self):
        self.mem.w8(PORT + 14, 0)  # MP_FLAGS PA_SIGNAL
        self.mem.w8(PORT + 15, SIGBIT)
        return PORT

    def DeleteMsgPort(self):
        self.deleted = self.reg(8)
        return 0

    def GetMsg(self):
        self.looks += 1
        if self.answer_at == self.looks:
            self.mem.w32(PKT + 12, GLOBALS)  # dp_Res1
            return PKT - 20  # the message in front of the packet
        return 0

    def FreeSignal(self):
        self.freed_signal = self.reg(0)
        return 0

    # dos
    def GetDeviceProc(self):
        return DEVPROC

    def FreeDeviceProc(self):
        return 0

    def AllocDosObject(self):
        assert self.reg(1) == 3, "DOS_STDPKT"
        return PKT

    def FreeDosObject(self):
        self.freed_packet = (self.reg(1), self.reg(2))
        return 0

    def SendPkt(self):
        self.sent = (self.reg(1), self.reg(2), self.reg(3))
        self.sent_type = self.mem.r32(PKT + 8)
        self.sent_arg1 = self.mem.r32(PKT + 20)
        return 0

    def CheckSignal(self):
        self.breaks += 1
        return 0x1000 if self.break_at == self.breaks else 0

    def Delay(self):
        assert self.reg(1) == 10
        return 0

    def Open(self):
        return FH

    def Write(self):
        data = bytes(self.mem.r_block(self.reg(2), self.reg(3)))
        if self.reg(1) == OUT:
            self.printed += data
        else:
            self.written.append(data)
        return self.reg(3)

    def Close(self):
        return 0

    def Output(self):
        return OUT

    def run(self):
        line = b"FA0: RAM:x.dump\n"
        self.mem.w_block(ARGS, line)
        self.cpu.w_reg(8, ARGS)
        self.cpu.w_reg(0, len(line))
        self.m.prepare(self.start, STACK)
        status = self.m.execute(4000000)
        assert self.m.was_exit(status)
        assert self.cpu.r_sp() == STACK, "stack"
        return self.reg(0)

    def close(self):
        self.m.cleanup()


class Wait(unittest.TestCase):
    """The packet goes out with SendPkt and debug95 looks for the answer every 10 ticks."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        obj = Path(cls.temp.name) / "debug95"
        assemble(obj, "src/debug95.s", cpu="68000")
        cls.image = BinFmt().load_image(str(obj))

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def fake(self, **kw):
        f = Fake(self.image, **kw)
        self.addCleanup(f.close)
        return f

    def test_answer_writes_the_dump(self):
        """An answer on the third look writes DebugSize bytes from dp_Res1 and frees the packet and the port."""
        f = self.fake(answer_at=3)
        self.assertEqual(f.run(), 0)
        self.assertEqual(f.sent, (PKT, HPORT, PORT))
        self.assertEqual((f.sent_type, f.sent_arg1), (1007, 0))
        self.assertEqual(f.written, [f.dump])
        self.assertEqual(f.calls.count("Delay"), 2)
        self.assertEqual(f.freed_packet, (3, PKT))
        self.assertEqual(f.deleted, PORT)

    def test_no_answer_gives_up(self):
        """Without an answer debug95 gives up after 50 looks, keeps the packet and port and frees the signal bit."""
        f = self.fake()
        self.assertEqual(f.run(), 10)
        self.assertEqual(f.looks, 50)
        self.assertEqual(f.calls.count("Delay"), 49)
        self.assertIn(b"no answer from the handler.", f.printed)
        self.assertEqual(f.written, [])
        self.assertNotIn("FreeDosObject", f.calls)
        self.assertNotIn("DeleteMsgPort", f.calls)
        self.assertEqual(f.mem.r8(PORT + 14), 2)  # PA_IGNORE
        self.assertEqual(f.freed_signal, SIGBIT)

    def test_ctrl_c_stops_the_wait(self):
        """Ctrl-C on the second look prints ***Break and leaves the packet out like a timeout."""
        f = self.fake(break_at=2)
        self.assertEqual(f.run(), 10)
        self.assertEqual(f.looks, 2)
        self.assertEqual(f.calls.count("Delay"), 1)
        self.assertIn(b"***Break", f.printed)
        self.assertNotIn("DeleteMsgPort", f.calls)
        self.assertEqual(f.mem.r8(PORT + 14), 2)
        self.assertEqual(f.freed_signal, SIGBIT)


if __name__ == "__main__":
    unittest.main()
