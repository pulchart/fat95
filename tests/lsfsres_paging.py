#!/usr/bin/env python3
"""lsfsres lists FileSystem.resource, so it walks the list under Forbid and prints from a copy; the pause between screenfuls must not reach the shell with the console left in RAW mode, and must not happen at all when either stream is redirected. Real assembled code from src/lsfsres.s, mocked dos.library and exec.

Status: gated, run by make test. Exit 0 means correct.
Run from the repository root: python3 tests/lsfsres_paging.py
Frame variable offsets are recovered from the vasm -L listing, so a layout change does not invalidate it."""
import re,sys,tempfile
from pathlib import Path
from amitools.binfmt.BinFmt import BinFmt
from amitools.binfmt.Relocate import Relocate
from amitools.vamos.machine import Machine
from toolchain import ROOT,assemble
BASE,EXEC,DOS,STACK=0x10000,0x300000,0x320000,0x200000
FRAME=0x180000                  # a4 points here, vars live below it
RES,LIST,SNAP=0x340000,0x340020,0x400000
FH_IN,FH_OUT=0x360000,0x360100  # struct FileHandle, fh_Type at 8
EXEC_LVO={'OpenLibrary':552,'CloseLibrary':414,'OpenResource':498,
          'Forbid':132,'Permit':138,'AllocVec':684,'FreeVec':690,'RawDoFmt':522}
DOS_LVO={'Read':42,'Write':48,'Input':54,'Output':60,'WaitForChar':204,
         'IsInteractive':216,'SetMode':426,'VPrintf':954}
NEED=('PageLines','PageLeft','PageCols','PagePos','PageBuf','PagePtr','ConsoleI','ConsoleO','KeyBuf','VarsSize',
      'RecSize','rec_Name')

def build(tmp):
    obj=tmp/'lsfsres'; lst=tmp/'lsfsres.lst'
    assemble(obj,'src/lsfsres.s',cpu='68000',listing=lst)
    eq={}
    for line in lst.read_text(errors='replace').splitlines():
        m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s+E:([0-9A-Fa-f]{8})\s*$',line)
        if m:
            v=int(m.group(2),16)
            eq[m.group(1)]=v-0x100000000 if v>=0x80000000 else v   # frame offsets
    for n in NEED: assert n in eq,'missing equate '+n
    return BinFmt().load_image(str(obj)),eq

class Fake:
    """One run of the tool against a scripted console."""
    def __init__(self,image,eq,reply=b'',keys=b'',interactive=True,same_type=True,
                 entries=(),nomem=False):
        self.m=Machine.from_name('68000',ram_size=8192)
        self.mem=self.m.get_mem();self.cpu=self.m.get_cpu();self.eq=eq
        self.mem.w_block(BASE,bytes(Relocate(image).relocate_one_block(BASE)))
        self.syms={s.name.decode():BASE+s.offset
                   for s in image.get_segments()[0].get_symtab().get_symbols()}
        self.reply=bytearray(reply+keys);self.interactive=interactive
        self.nomem=nomem;self.raw=[];self.written=bytearray();self.rows=[]
        self.allocated=None;self.freed=[]
        self.mem.w32(4,EXEC)
        for name,lvo in EXEC_LVO.items():self.trap(EXEC-lvo,getattr(self,'x_'+name))
        for name,lvo in DOS_LVO.items():self.trap(DOS-lvo,getattr(self,'d_'+name))
        self.mem.w32(FH_IN+8,0x1111);self.mem.w32(FH_OUT+8,0x1111 if same_type else 0x2222)
        self.build_list(entries)
    def trap(self,addr,fn):
        tid=self.m.get_traps().alloc(lambda op,pc,f=fn:f())
        self.mem.w16(addr,0xa000|tid);self.mem.w16(addr+2,0x4e75)
    def build_list(self,entries):
        # FileSysResource: fsr_FileSysEntries (a List) at 18. An empty Exec
        # list has lh_Head pointing at its own lh_Tail, which reads as NULL.
        head,tail=RES+18,RES+22
        self.mem.w32(tail,0);self.mem.w32(RES+26,0)
        node=LIST+0x100
        self.mem.w32(head,tail if not entries else node)
        for i,(dostype,version,patch,seg,name) in enumerate(entries):
            nxt=node+0x100 if i+1<len(entries) else tail
            self.mem.w32(node+0,nxt)                          # ln_Succ
            self.mem.w32(node+10,node+0x80)                   # ln_Name
            self.mem.w_block(node+0x80,name+b'\0')
            self.mem.w32(node+14,dostype);self.mem.w32(node+18,version)
            self.mem.w32(node+22,patch);self.mem.w32(node+54,seg>>2)
            node=nxt
    def ret(self,v=0):self.cpu.w_reg(0,v&0xffffffff)
    # --- exec ---
    def x_OpenLibrary(self):self.ret(DOS)
    def x_CloseLibrary(self):self.ret()
    def x_OpenResource(self):self.ret(RES)
    def x_Forbid(self):self.ret()
    def x_Permit(self):self.ret()
    def x_AllocVec(self):
        if self.nomem:return self.ret(0)
        self.allocated=self.cpu.r_reg(0);self.mem.w_block(SNAP,bytes(self.allocated))
        self.ret(SNAP)
    def x_FreeVec(self):self.freed.append(self.cpu.r_reg(9));self.ret()
    def x_RawDoFmt(self):
        # RawDoFmt(a0 format, a1 longword arguments, a2 PutChProc, a3 PutChData).
        # The tool's PutChProc keeps its write cursor in the longword a3 points
        # at; store the bytes the same way. Like exec, a3 comes back unchanged.
        # Arguments are read now, while the scratch buffers still hold this
        # entry's strings.
        fmt=self.cpu.r_reg(8);argv=self.cpu.r_reg(9);dst=self.cpu.r_reg(11)
        out=b''
        while self.mem.r8(fmt):out+=bytes([self.mem.r8(fmt)]);fmt+=1
        text=out.decode('latin-1');vals=[];i=0
        def conv(m):
            nonlocal i
            flags,width,kind=m.group(1),m.group(2),m.group(3)
            raw=self.mem.r32(argv+4*i) if argv else 0;i+=1
            v=self.string(raw) if kind=='s' else raw;vals.append(v)
            spec='%'+flags+width+('s' if kind=='s' else ('X' if kind=='x' else 'd'))
            return spec%v
        rendered=re.sub(r'%(-?0?)(\d*)l?([dxs])',conv,text)
        data=rendered.encode('latin-1')+b'\0'
        cur=self.mem.r32(dst)
        self.mem.w_block(cur,data);self.mem.w32(dst,cur+len(data))
        self.rows.append((text,vals))
    # --- dos ---
    def d_Input(self):self.ret(FH_IN>>2)
    def d_Output(self):self.ret(FH_OUT>>2)
    def d_IsInteractive(self):self.ret(-1 if self.interactive else 0)
    def d_SetMode(self):self.raw.append(self.cpu.r_reg(2));self.ret(-1)
    def d_WaitForChar(self):self.ret(-1 if self.reply else 0)
    def d_Read(self):
        if not self.reply:return self.ret(0)
        self.mem.w8(self.cpu.r_reg(2),self.reply.pop(0));self.ret(1)
    def d_Write(self):
        n=self.cpu.r_reg(3)
        self.written+=bytes(self.mem.r_block(self.cpu.r_reg(2),n));self.ret(n)
    def d_VPrintf(self):
        # the tool renders the DosType and the version into one scratch buffer,
        # so a %s has to be read now, not after the run
        fmt=self.cpu.r_reg(1);argv=self.cpu.r_reg(2);out=b''
        while self.mem.r8(fmt):out+=bytes([self.mem.r8(fmt)]);fmt+=1
        text=out.decode('latin-1');vals=[]
        for i,conv in enumerate(re.findall(r'%[-0-9.]*(?:ld|lx|s)',text)):
            raw=self.mem.r32(argv+4*i)
            vals.append(self.string(raw) if conv.endswith('s') else raw)
        self.rows.append((text,vals));self.ret(0)
    def string(self,addr):
        out=b''
        while self.mem.r8(addr):out+=bytes([self.mem.r8(addr)]);addr+=1
        return out.decode('latin-1')
    def call(self,label,setup=None,reset=True,keep=True):
        for r in range(16):self.cpu.w_reg(r,0x5a5a0000+r)
        self.saved={r:0x5a5a0000+r for r in (*range(2,8),10,11,12,13,14)}
        self.cpu.w_reg(8+4,FRAME)                 # a4 = frame pointer
        self.mem.w32(FRAME-4,EXEC);self.mem.w32(FRAME-8,DOS)
        if reset:
            for off in ('PageLines','PageLeft','ConsoleI','ConsoleO'):
                self.mem.w32(FRAME+self.eq[off],0)
        if setup:setup(self)
        self.m.prepare(self.syms[label],STACK)
        st=self.m.execute(4000000);assert self.m.was_exit(st),label
        if keep:                     # d2-d7/a2-a6 belong to the caller
            for r,v in self.saved.items():
                if r in (8+4,):continue                    # a4 is the frame
                assert self.cpu.r_reg(r)==v,(label,'clobbered reg',r)
        assert self.cpu.r_sp()==STACK,(label,'stack')
        return self.cpu.r_reg(0)
    def var(self,name):return self.mem.r32(FRAME+self.eq[name])
    def close(self):self.m.cleanup()

def string_at(f,addr):
    out=b''
    while f.mem.r8(addr):out+=bytes([f.mem.r8(addr)]);addr+=1
    return out.decode('latin-1')

def rows_test(image,eq):
    """The window bounds report is trusted only when it is complete."""
    cases=[(b'1;1;25;80 r',25,-1),          # the third field is the height
           (b'1;1;9;80 r',9,-1),
           (b'1;25 r',0,0),                 # too short to trust
           (b'',0,0),                       # console stayed silent
           (b'1;1;9999;80 r',9999,-1)]      # absurd, PageBegin rejects it
    n=0
    for reply,rows,want in cases:
        f=Fake(image,eq,reply=reply)
        try:
            assert f.call('PageRows',seed_streams)&0xffffffff==want&0xffffffff,(reply,rows)
            assert f.var('PageLines')==rows,(reply,f.var('PageLines'))
            if want:assert f.var('PageCols')==80,f.var('PageCols')   # the fourth is the width
            assert bytes(f.written[:4])==b'\x1b[ q','no window status request'
        finally:f.close()
        n+=1
    return n

def seed_streams(f):
    """PageBegin does not open them: the tool owns Input()/Output()."""
    f.mem.w32(FRAME+f.eq['ConsoleI'],FH_IN>>2)
    f.mem.w32(FRAME+f.eq['ConsoleO'],FH_OUT>>2)

def begin_test(image,eq):
    """A height is used only when it is plausible, and only on one console."""
    cases=[(b'1;1;25;80 r',True,True,24),   # 25 rows, one kept for the prompt
           (b'1;1;5;80 r',True,True,4),
           (b'1;1;4;80 r',True,True,0),     # too short after the prompt line
           (b'1;1;9999;80 r',True,True,0),
           (b'1;1;25;29 r',True,True,0),    # the prompt would wrap
           (b'1;1;25;30 r',True,True,24),
           (b'1;1;25;80 r',False,True,0),   # redirected
           (b'1;1;25;80 r',True,False,0)]   # ">SER:" is a different handler
    n=0
    for reply,inter,same,rows in cases:
        f=Fake(image,eq,reply=reply,interactive=inter,same_type=same)
        try:
            f.call('PageBegin',seed_streams)
            assert f.var('PageLines')==rows,(reply,inter,same,f.var('PageLines'))
            assert f.var('PageLeft')==rows
            if rows:assert f.raw==[1],f.raw          # RAW, and left in RAW
            elif inter and same:assert f.raw==[1,0],f.raw   # asked, then cooked
            else:assert f.raw==[],f.raw              # never touched the console
        finally:f.close()
        n+=1
    return n

TEXT=0x170000                    # PageText input lives here

def page_text(f,text,lines,left,cols=0,reset=True):
    """Call PageText on text with the pager state given."""
    def seed(f):
        f.mem.w_block(TEXT,text)
        if reset:
            f.mem.w32(FRAME+f.eq['PageLines'],lines);f.mem.w32(FRAME+f.eq['PageLeft'],left)
            f.mem.w32(FRAME+f.eq['PageCols'],cols)
        seed_streams(f);f.cpu.w_reg(8,TEXT);f.cpu.w_reg(0,len(text))
    return f.call('PageText',seed,reset=False)

PROMPT=b'\x1b[3;7m-- more -- (any key, Q quits)\x1b[23;27m'

def line_test(image,eq):
    """A page that fills exactly asks nothing; the next line asks first, and Q stops."""
    n=0
    f=Fake(image,eq)
    try:
        assert page_text(f,b'a\nb\nc\n',3,3)!=0
        assert bytes(f.written)==b'a\nb\nc\n',bytes(f.written)   # no trailing prompt
        assert f.var('PageLeft')==0
    finally:f.close()
    n+=1
    for key,more in ((b'\r',True),(b'q',False),(b'Q',False),(b'x',True)):
        f=Fake(image,eq,keys=key)
        try:
            r=page_text(f,b'a\nb\nc\nd\n',3,3)
            text=b'-- more -- (any key, Q quits)'
            erase=b'\r'+b' '*len(text)+b'\r'
            want=b'a\nb\nc\n'+PROMPT+erase+(b'd\n' if more else b'')
            assert bytes(f.written)==want,bytes(f.written)
            assert (r!=0)==more,(key,r)
            if more:assert f.var('PageLeft')==2,'a fresh page, one line used'
        finally:f.close()
        n+=1
    # a last line without LF counts all its characters: 121 at 30 columns is
    # five rows, more than the four a 5-row window leaves
    f=Fake(image,eq,keys=b'\r')
    try:
        page_text(f,b'x'*121,4,4,30)
        assert bytes(f.written).count(PROMPT)==1,bytes(f.written)
    finally:f.close()
    n+=1
    # a tool whose console said nothing scrolls, and asks nothing
    f=Fake(image,eq)
    try:
        assert page_text(f,b'a\n'*50,0,0)!=0 and bytes(f.written)==b'a\n'*50
    finally:f.close()
    return n+1

def wrap_test(image,eq):
    """A line wider than the window counts as the rows it wraps onto."""
    n=0
    line=b'x'*43+b'\n'                  # 3 rows at 20 columns, 1 when width is unknown
    for count,cols,prompts in ((3,20,0),(4,20,1),(9,0,0),(10,0,1),(9,20,2)):
        f=Fake(image,eq,keys=b'\r'*4)
        try:
            page_text(f,line*count,9,9,cols)
            assert bytes(f.written).count(PROMPT)==prompts,(count,cols,bytes(f.written))
        finally:f.close()
        n+=1
    return n

def narrow_test(image,eq):
    """In a narrow window every entry wraps; nothing may scroll off before the pause."""
    # 14 rows by 66 columns, as on the 0.1 report: each entry line is wider
    # than the window, so it takes two rows and the header used to scroll away
    entries=[(0x46415400+i,0x00040000,0x190,0x00e5f6a0,b'fat95 4.0 (10.09.2026) [68000]')
             for i in range(8)]
    f=Fake(image,eq,reply=b'1;1;14;66 r',keys=b'\r'*8,entries=entries)
    try:
        f.call('Start')
        text=bytes(f.written).decode('latin-1').replace('\x1b[ q','')
        page=text.split('\x1b[3;7m')[0]               # up to the first prompt
        rows=sum(max(1,-(-len(l)//66)) for l in page.split('\n')[:-1])
        assert '\x1b[3;7m' in text,'no pause in a full window'
        assert rows<=13,(rows,page)                    # 14 rows, one kept for the prompt
        assert page.startswith(' #: DosType'),page[:40]
    finally:f.close()
    return 1

def pages(text,cols):
    """Screen rows written between pauses, the erased prompt removed."""
    prompt='\x1b[3;7m-- more -- (any key, Q quits)\x1b[23;27m'
    erase='\r'+' '*29+'\r'
    out=[]
    for page in text.replace('\x1b[ q','').split(prompt):
        page=page.replace(erase,'')
        lines=page.split('\n')
        rows=sum(max(1,-(-len(l)//cols)) for l in lines[:-1])
        rows+=-(-len(lines[-1])//cols)
        out.append(rows)
    return out

def tall_test(image,eq):
    """A line taller than a whole page goes out a page at a time; Q stops it all."""
    entries=[(0x46415400+i,0x00040000,0x190,0x00e5f6a0,b'n'*78) for i in range(3)]
    f=Fake(image,eq,reply=b'1;1;5;30 r',keys=b'\r'*40,entries=entries)
    try:
        f.call('Start')
        text=bytes(f.written).decode('latin-1')
        rows=pages(text,30)
        assert len(rows)>3 and max(rows)<=4,rows       # 5 rows, one for the prompt
        assert 'Total: 3' in text,text[-80:]
    finally:f.close()
    f=Fake(image,eq,reply=b'1;1;5;30 r',keys=b'q',entries=entries)
    try:
        f.call('Start')
        text=bytes(f.written).decode('latin-1')
        after=text.split('(any key, Q quits)')
        assert len(after)==2,len(after)                # one pause, then nothing
        assert after[1].strip('\x1b[23;27m\r ')=='',repr(after[1])
        assert f.raw and f.raw[-1]==0,'console handed back cooked'
    finally:f.close()
    return 2

def list_test(image,eq):
    """The whole tool: two entries copied out of the list and printed."""
    entries=[(0x444f5301,0x00280000,0x180,0x00f80000,b'fat95 1.2\nbanner'),
             (0x46415401,0x00010002,0x000,0x00081000,b'x'*90)]   # longer than the column
    f=Fake(image,eq,reply=b'1;1;25;80 r',keys=b'\r'*8,entries=entries)
    try:
        f.call('Start')
        assert f.allocated==2*eq['RecSize'],f.allocated
        assert f.freed==[SNAP],f.freed
        assert len(f.rows)==3,f.rows                  # two entries and a summary
        for i,(fmt,args) in enumerate(f.rows[:2]):
            dostype,version,patch,seg,name=entries[i]
            assert args[0]==i+1 and args[1]==dostype
            # the version longword is rendered as major.revision
            assert args[3]=='%d.%d'%(version>>16,version&0xffff),args[3]
            assert args[4]==patch and args[5]==seg
            assert args[6]==('[ROM]' if seg>=0xf80000 else '[RAM]')
            # the name is copied, cut at the LF fat95 leaves in its banner, and
            # a name that goes on past the column ends in dots
            want=name.split(b'\n')[0].decode()
            if len(want)>78:want=want[:75]+'...'
            assert args[7]==want,args[7]
        assert f.rows[2][1][0]==2,'summary counts both'
        # every label must sit over the column it names
        fmt,args=f.rows[0]
        line=(fmt.replace('%2ld','%2d').replace('%08lx','%08X').replace('%04lx','%04X')
                 .rstrip('\n'))%tuple(args)
        text=bytes(f.written).decode('latin-1').replace('\x1b[ q','')  # the query
        header=text.split('\n')[0]
        for label,field in (('DosType','%08X'%args[1]),('Version',args[3]),
                            ('Patch','%04X'%args[4]),('SegList','%08X'%args[5]),
                            ('Loc',args[6]),('Name',args[7])):
            assert header.index(label)==line.index(field,3),(label,header,line)
        rule=text.split('\n')[1]
        assert len(rule)==len(header),(len(rule),len(header))
        # the entries and the summary reach the console, not only the header
        assert text.count('\n')==6,repr(text)
        assert 'fat95 1.2' in text and 'Total: 2 entries' in text,repr(text)
        assert f.raw and f.raw[-1]==0,'console handed back cooked'
    finally:f.close()
    # out of memory says so and lists nothing
    f=Fake(image,eq,entries=entries,nomem=True)
    try:
        f.call('Start')
        assert not f.rows and b'Out of memory' in bytes(f.written),bytes(f.written)
    finally:f.close()
    # an empty resource still prints the header and the summary
    f=Fake(image,eq,entries=())
    try:
        f.call('Start')
        assert f.allocated is None and len(f.rows)==1 and f.rows[0][1][0]==0
    finally:f.close()
    return 3

def dd_inspect_test(image,eq):
    """dd INSPECT shares paging.i: every field reaches the console, and Q stops it."""
    with tempfile.TemporaryDirectory() as t:
        p=Path(t);obj=p/'dd';lst=p/'dd.lst'
        assemble(obj,'src/dd.s',cpu='68000',listing=lst)
        deq={}
        for line in lst.read_text(errors='replace').splitlines():
            m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s+E:([0-9A-Fa-f]{8})\s*$',line)
            if m:
                v=int(m.group(2),16);deq[m.group(1)]=v-0x100000000 if v>=0x80000000 else v
        dd=BinFmt().load_image(str(obj))
    def seed(f):
        seed_streams(f)
        for name,val in (('ExecBase',EXEC),('DosBase',DOS),('PagePos',0),('PageLines',0)):
            f.mem.w32(FRAME+deq[name],val)
        src=FRAME+deq['SourceVec']
        f.mem.w32(src+deq['DV_Name'],0x150000);f.mem.w_block(0x150000,b'compactflash.device\0')
        f.mem.w32(src+deq['DV_BlockSize'],512);f.mem.w32(src+deq['DV_NumBlocks'],123456)
    f=Fake(dd,deq,reply=b'1;1;25;80 r')
    try:
        f.call('PrintInspect',seed,keep=False)
        text=bytes(f.written).decode('latin-1')
        for field in ('compactflash.device unit 0:','sector size:    512','total sectors:  123456',
                      'cylinders:','heads:','sec/track:','buf mem type:','device type:','read/write via:'):
            assert field in text,(field,text)
        assert PROMPT.decode('latin-1') not in text,'a full report fits 25 rows'
    finally:f.close()
    f=Fake(dd,deq,reply=b'1;1;5;40 r',keys=b'q')
    try:
        f.call('PrintInspect',seed,keep=False)
        text=bytes(f.written).decode('latin-1')
        rest=text.split('(any key, Q quits)')
        assert len(rest)==2 and 'read/write via' not in rest[1],repr(text)
        assert f.raw==[1,0],f.raw
    finally:f.close()
    return 2

def main():
    bad=[];total=0
    with tempfile.TemporaryDirectory() as t:
        image,eq=build(Path(t))
        for name,fn in (('window bounds report',rows_test),
                        ('pausing decided once',begin_test),
                        ('line countdown',line_test),
                        ('wrapped lines',wrap_test),
                        ('narrow window',narrow_test),
                        ('taller than a page',tall_test),
                        ('dd INSPECT',dd_inspect_test),
                        ('resource listed from a copy',list_test)):
            try:
                n=fn(image,eq);total+=n
                print(f'  {name:28} ok  {n} case(s)')
            except AssertionError as e:
                print(f'  {name:28} FAIL {e}');bad.append(name)
    print(f'{total} lsfsres case(s), {len(bad)} failed',file=sys.stderr)
    sys.exit(1 if bad else 0)
if __name__=='__main__':main()
