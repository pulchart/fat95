#!/usr/bin/env python3
"""install95 reads its arguments with ReadArgs and writes or reads the language of a fat95 file.

Real assembled code from src/install95.s on a real fat95 build, mocked exec and dos.library.

Status: library, collected by unittest like any other test file.
Run: make test
"""

import tempfile
import unittest
from pathlib import Path

from amitools.binfmt.BinFmt import BinFmt
from amitools.binfmt.Relocate import Relocate
from amitools.vamos.machine import Machine
from toolchain import ROOT, assemble

BASE, STACK, EXEC, DOS = 0x10000, 0x200000, 0x300000, 0x320000
TASK, STRINGS, RDA, BUF = 0x340000, 0x341000, 0x350000, 0x400000
OUT, LOCK0 = 0x1000, 0x2000
MODE_OLDFILE, MODE_NEWFILE = 1005, 1006
ERROR_TOO_MANY_ARGS = 118
LOCALE = ROOT / "dist/locale"

EXEC_LVO = {"FindTask": 294, "OpenLibrary": 552, "CloseLibrary": 414,
            "AllocMem": 198, "FreeMem": 210}  # fmt: skip
DOS_LVO = {"ReadArgs": 798, "FreeArgs": 858, "IoErr": 132, "PrintFault": 474,
           "Output": 60, "VFPrintf": 354, "Open": 30, "Close": 36, "Read": 42,
           "Write": 48, "Lock": 84, "UnLock": 90, "SameLock": 420}  # fmt: skip


class Fake:
    """One CLI run of install95; files maps lower-case names to their bytes."""

    def __init__(self, image, files, args):
        self.m = Machine.from_name("68000", ram_size=8192)
        self.mem, self.cpu = self.m.get_mem(), self.m.get_cpu()
        self.mem.w_block(BASE, bytes(Relocate(image).relocate_one_block(BASE)))
        seg = image.get_segments()[0]
        self.start = BASE + next(
            s.offset for s in seg.get_symtab().get_symbols() if s.name.decode() == "Start"
        )
        self.files = {k.lower(): bytes(v) for k, v in files.items()}
        self.args = args  # None: ReadArgs fails
        self.calls, self.opened, self.handles, self.locks = [], [], {}, {}
        self.printed, self.faults, self.alloc = b"", [], []
        self.freed_args = 0
        self.mem.w32(4, EXEC)
        self.mem.w32(TASK + 172, 1)  # pr_CLI
        for name, lvo in EXEC_LVO.items():
            self.trap(EXEC - lvo, name)
        for name, lvo in DOS_LVO.items():
            self.trap(DOS - lvo, name)

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

    def cstr(self, addr):
        return self.mem.r_cstr(addr)

    # exec
    def FindTask(self):
        return TASK

    def OpenLibrary(self):
        return DOS

    def CloseLibrary(self):
        return 0

    def AllocMem(self):
        self.alloc.append(self.reg(0))
        return BUF

    def FreeMem(self):
        assert (self.reg(9), self.reg(0)) == (BUF, self.alloc[-1])
        self.alloc.append(-self.reg(0))
        return 0

    # dos
    def ReadArgs(self):
        self.template = self.cstr(self.reg(1))
        if self.args is None:
            return 0
        array, at = self.reg(2), STRINGS
        for i, key in enumerate(("WRITE", "READ", "LANGUAGE", "HANDLER")):
            value = self.args.get(key)
            if isinstance(value, str):
                self.mem.w_cstr(at, value)
                value, at = at, at + len(value) + 1
            self.mem.w32(array + 4 * i, 0xFFFFFFFF if value is True else value or 0)
        return RDA

    def FreeArgs(self):
        assert self.reg(1) == RDA
        self.freed_args += 1
        return 0

    def IoErr(self):
        return ERROR_TOO_MANY_ARGS

    def PrintFault(self):
        self.faults.append((self.reg(1), self.cstr(self.reg(2))))
        return 0

    def Output(self):
        return OUT

    def VFPrintf(self):
        assert self.reg(1) == OUT
        text = self.cstr(self.reg(2)).replace("%s", self.cstr(self.mem.r32(self.reg(3))))
        self.printed += text.encode()
        return len(text)

    def Open(self):
        name, mode = self.cstr(self.reg(1)).lower(), self.reg(2)
        self.opened.append((name, mode))
        if mode == MODE_OLDFILE and name not in self.files:
            return 0
        if mode == MODE_NEWFILE:
            self.files[name] = b""
        fh = 0x3000 + 0x10 * len(self.opened)
        self.handles[fh] = [name, 0]
        return fh

    def Close(self):
        del self.handles[self.reg(1)]
        return 0

    def Read(self):
        h = self.handles[self.reg(1)]
        data = self.files[h[0]][h[1] : h[1] + self.reg(3)]
        self.mem.w_block(self.reg(2), data)
        h[1] += len(data)
        return len(data)

    def Write(self):
        data = bytes(self.mem.r_block(self.reg(2), self.reg(3)))
        if self.reg(1) == OUT:
            self.printed += data
        else:
            h = self.handles[self.reg(1)]
            self.files[h[0]] += data
        return len(data)

    def Lock(self):
        name = self.cstr(self.reg(1)).lower()
        if name not in self.files:
            return 0
        lock = LOCK0 + 4 * len(self.calls)
        self.locks[lock] = name
        return lock

    def UnLock(self):
        del self.locks[self.reg(1)]
        return 0

    def SameLock(self):
        return 0 if self.locks[self.reg(1)] == self.locks[self.reg(2)] else -1

    def run(self):
        self.m.prepare(self.start, STACK)
        status = self.m.execute(200000000)
        assert self.m.was_exit(status)
        assert self.cpu.r_sp() == STACK, "stack"
        assert not self.handles and not self.locks, "left open"
        assert sum(self.alloc) == 0, "memory"
        assert self.freed_args == (self.args is not None), "FreeArgs"
        return self.reg(0)

    def close(self):
        if self.m:
            self.m.cleanup()
            self.m = None


class Arguments(unittest.TestCase):
    """WRITE or READ, the language file and HANDLER, with the guards around them."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        tool, handler = Path(cls.temp.name) / "install95", Path(cls.temp.name) / "fat95"
        assemble(tool, "src/install95.s", cpu="68000")
        cls.image = BinFmt().load_image(str(tool))
        cls.handler = assemble(handler, extra=("-nosym",)).read_bytes()
        cls.english = (LOCALE / "english").read_bytes()
        cls.polski = (LOCALE / "polski").read_bytes()

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def fake(self, args, **files):
        files = {"l:fat95": self.handler, "locale/english": self.english,
                 "locale/polski": self.polski, **files}  # fmt: skip
        f = Fake(self.image, files, args)
        self.addCleanup(f.close)
        return f

    def test_template(self):
        """ReadArgs gets the template with the short switches of the old w and r."""
        f = self.fake({"WRITE": True, "LANGUAGE": "locale/english"})
        f.run()
        self.assertEqual(f.template, "W=WRITE/S,R=READ/S,LANGUAGE/A,HANDLER/K")

    def test_write_then_read(self):
        """WRITE puts the language into L:fat95 and READ gives its texts back."""
        f = self.fake({"WRITE": True, "LANGUAGE": "locale/polski"})
        self.assertEqual(f.run(), 0)
        self.assertNotEqual(f.files["l:fat95"], self.handler)
        f.close()
        g = self.fake({"READ": True, "LANGUAGE": "ram:x"}, **{"l:fat95": f.files["l:fat95"]})
        self.assertEqual(g.run(), 0)
        text = g.files["ram:x"].decode("latin-1")
        self.assertTrue(text.startswith(";fat95 locale file"))
        self.assertIn("1 = Poniechaj", text)
        self.assertEqual(g.printed, b"")

    def test_read_into_the_handler_is_refused(self):
        """READ into the handler file itself, under any spelling, fails and leaves it as it was."""
        f = self.fake({"READ": True, "LANGUAGE": "L:FAT95"})
        self.assertEqual(f.run(), 10)
        self.assertEqual(f.printed, b'the language file cannot be "l:fat95".\n')
        self.assertEqual(f.files["l:fat95"], self.handler)
        self.assertNotIn(MODE_NEWFILE, [mode for _, mode in f.opened])

    def test_read_over_another_file(self):
        """READ replaces an existing language file that is not the handler file."""
        f = self.fake({"READ": True, "LANGUAGE": "ram:x"}, **{"ram:x": b"old"})
        self.assertEqual(f.run(), 0)
        self.assertTrue(f.files["ram:x"].startswith(b";fat95 locale file"))
        self.assertIn("SameLock", f.calls)

    def test_handler_keyword(self):
        """HANDLER names the fat95 file to change, L:fat95 stays as it was."""
        f = self.fake({"WRITE": True, "LANGUAGE": "locale/english", "HANDLER": "ram:h"},
                      **{"ram:h": self.handler})  # fmt: skip
        self.assertEqual(f.run(), 0)
        self.assertNotEqual(f.files["ram:h"], self.handler)
        self.assertEqual(f.files["l:fat95"], self.handler)
        self.assertNotIn(("l:fat95", MODE_NEWFILE), f.opened)

    def test_missing_handler_is_named(self):
        """A missing handler file is reported by its name."""
        f = self.fake({"WRITE": True, "LANGUAGE": "locale/english", "HANDLER": "ram:none"})
        self.assertEqual(f.run(), 10)
        self.assertEqual(f.printed, b'file "ram:none" not found.\n')

    def test_one_mode_required(self):
        """Neither or both of WRITE and READ print the usage before any file is touched."""
        for args in ({}, {"WRITE": True, "READ": True}):
            with self.subTest(args=args):
                f = self.fake({**args, "LANGUAGE": "locale/english"})
                self.assertEqual(f.run(), 10)
                self.assertIn(b"usage: install95 WRITE|READ", f.printed)
                self.assertEqual((f.opened, f.alloc), ([], []))
                f.close()

    def test_bad_arguments_print_the_fault(self):
        """A failing ReadArgs prints the DOS fault, returns 10 and frees nothing."""
        f = self.fake(None)
        self.assertEqual(f.run(), 10)
        self.assertEqual(f.faults, [(ERROR_TOO_MANY_ARGS, "install95")])
        self.assertEqual(f.opened, [])


if __name__ == "__main__":
    unittest.main()
