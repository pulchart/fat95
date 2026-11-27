; fat95 installer
; Copyright (C) 2013  Torsten Jager <t.jager@gmx.de>
; This file is part of FAT95, a free FAT compatible file system for Amiga.
;
; This tool is free software; you can redistribute it and/or
; modify it under the terms of the GNU Lesser General Public
; License as published by the Free Software Foundation; either
; version 2.1 of the License, or (at your option) any later version.
;
; This tool is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
; Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public
; License along with this library; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

; --- Includes ---
	include	"install95_version.i"

;--- from exec.library -------------------------------------

CALLEXEC macro
	move.l	ExecBase(a4),a6
	jsr	\1(a6)
	endm

_AbsExecBase	= 4

Forbid		= -132
Permit		= -138
AllocMem	= -198
FreeMem		= -210
OpenLibrary	= -552
CloseLibrary	= -414
FindTask	= -294
WaitPort	= -384
GetMsg		= -372
ReplyMsg	= -378

MEMF_PUBLIC	= 1

;struct Resident
RT_MatchWord	= 0
RT_MatchTag	= 2
RT_EndSkip	= 6
RT_Flags	= 10
RT_Version	= 11
RT_Type		= 12
RT_Priority	= 13
RT_Name		= 14
RT_IDString	= 18
RT_Init		= 22
RT_Sizeof	= 26

RTC_MATCHWORD	= $4afc

;--- from dos.library --------------------------------------

CALLDOS	macro
	move.l	DosBase(a4),a6
	jsr	\1(a6)
	endm

Open		= -30
Close		= -36
Read		= -42
Write		= -48
Output		= -60
Lock		= -84
UnLock		= -90
CurrentDir	= -126
IoErr		= -132
VFPrintf	= -354
SameLock	= -420
PrintFault	= -474
ReadArgs	= -798
FreeArgs	= -858
DoPkt		= -240
NameFromLock	= -402
SetFileSize	= -456
GetDeviceProc	= -642
FreeDeviceProc	= -648

;struct Process
PR_MsgPort	= 92
PR_CLI		= 172

MODE_READWRITE	= 1004
MODE_OLDFILE	= 1005
MODE_NEWFILE	= 1006

SHARED_LOCK	= -2

OFFSET_BEGINNING = -1
OFFSET_CURRENT	 = 0
OFFSET_END	 = 1

TAB		= 9
LF		= 10

;struct DevProc
DVP_Port	= 0
DVP_Lock	= 4
DVP_Flags	= 8
DVP_DevNode	= 12
DVP_Sizeof	= 16

ACTION_DIE	= 5
ACTION_END	= 1007

;--- from Workbench ----------------------------------------

;struct WBStartupMsg
SM_Message	= 0
SM_Process	= 20
SM_Segment	= 24
SM_NumArgs	= 28
SM_ToolWindow	= 32
SM_ArgList	= 36
SM_Sizeof	= 40

;struct SM_ArgList
WA_Lock		= 0
WA_Name		= 4
WA_Sizeof	= 8

;--- global Vars -------------------------------------------

RDArgs		= -4
Mode		= -8
ExecBase	= -12
DosBase		= -16
Result		= -20
StartupMsg	= -24
OldDir		= -28
File2		= -32
File3		= -36
Size3		= -40
SizeOffs	= -44
HunkOffs	= -48
HunkSize	= -52
NumHunks	= -56
Buffer		= -60
BufSize		= -64
TextBuffer	= -68
TextSize	= -72
ChunkOffs	= -76
TailOffset	= -80
TailSize	= -84
HandlerName	= -88
LangName	= -92
ArgArray	= -108
StringBuffer	= -400
VarsSize	= -400

;*** here we go!!! ****************************************

; a0 <- &Parameters
; d0 <- length thereof

Start:
	link.w	a4,#VarsSize
	movem.l	d1-d5/a0-a1/a6,-(sp)
	move.l	(_AbsExecBase).w,ExecBase(a4)
	clr.l	Result(a4)
	moveq.l	#0,d2
	sub.l	a1,a1
	CALLEXEC FindTask
	move.l	d0,a0
	tst.l	PR_CLI(a0)
	bne.s	s_1

	moveq.l	#PR_MsgPort,d3
	add.l	d0,d3
	move.l	d3,a0
	CALLEXEC WaitPort
	move.l	d3,a0
	CALLEXEC GetMsg
	move.l	d0,d2
s_1:
	move.l	d2,StartupMsg(a4)
	moveq.l	#36,d0
	lea	DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	beq.w	s_end

	lea	Fat95Name(pc),a0
	move.l	a0,HandlerName(a4)
	clr.l	RDArgs(a4)
	tst.l	StartupMsg(a4)
	bne.s	s_3

;- - read the command line  - - - - - - - - - - - - - - - -

	lea	ArgArray(a4),a0
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)
	lea	ArgTemplate(pc),a0
	move.l	a0,d1
	lea	ArgArray(a4),a0
	move.l	a0,d2
	moveq.l	#0,d3
	CALLDOS	ReadArgs
	move.l	d0,RDArgs(a4)
	beq.w	s_argerr

	move.l	ArgArray+8(a4),LangName(a4)
	move.l	ArgArray+12(a4),d0
	beq.s	s_a1

	move.l	d0,HandlerName(a4)	;HANDLER
s_a1:
	moveq.l	#'w',d0
	move.l	ArgArray(a4),d1		;WRITE
	tst.l	ArgArray+4(a4)		;READ
	beq.s	s_a2

	moveq.l	#'r',d0
	tst.l	d1
	bne.w	s_help			;both
	bra.s	s_a3
s_a2:
	tst.l	d1
	beq.w	s_help			;neither
s_a3:
	move.l	d0,Mode(a4)
s_3:
	move.l	#128<<10,d0
	move.l	d0,BufSize(a4)
	moveq.l	#MEMF_PUBLIC,d1
	CALLEXEC AllocMem
	move.l	d0,Buffer(a4)
	beq.w	s_nomem

;- - read fat95 Object - - - - - - - - - - - - - - - - - - -

	move.l	StartupMsg(a4),d0
	beq.s	s_robj1

	move.l	d0,a0
	move.l	SM_NumArgs(a0),d0
	subq.l	#2,d0
	bcs.s	s_robj1

	move.l	SM_ArgList(a0),a0
	move.l	WA_Lock(a0),d2
	move.l	WA_Name(a0),d0
	beq.s	s_robj1

	move.l	d0,a0
	lea	StringBuffer(a4),a1
	move.l	a1,d3
	bsr.w	StrCopy
	move.l	d3,a0
	bsr.w	FilePart		;from same dir..
	lea	Fat95Name2(pc),a0
	move.l	d0,a1
	bsr.w	StrCopy			;..as install95..
	move.l	d2,d1
	CALLDOS	CurrentDir
	move.l	d0,OldDir(a4)
	move.l	d3,d1
	move.l	#MODE_OLDFILE,d2
	CALLDOS	Open			;..do install..
	move.l	d0,File3(a4)
	move.l	OldDir(a4),d1
	CALLDOS	CurrentDir
	move.l	File3(a4),d0
	bne.s	s_robj2
s_robj1:
	move.l	HandlerName(a4),d1	;..or take Module in l:..
	move.l	#MODE_OLDFILE,d2
	CALLDOS	Open			;..and adapt it
	move.l	d0,File3(a4)
	beq.w	s_nofile3
s_robj2:
	move.l	d0,d1
	move.l	Buffer(a4),d2
	move.l	BufSize(a4),d3
	lsr.l	#1,d3
	move.l	d2,d0
	add.l	d3,d0
	move.l	d0,TextBuffer(a4)
	CALLDOS	Read
	move.l	d0,Size3(a4)
	move.l	File3(a4),d1
	CALLDOS	Close
	clr.l	File3(a4)
	move.l	Size3(a4),d0
	ble.w	s_nofile3

	lsl.l	#1,d0
	cmp.l	BufSize(a4),d0
	beq.w	s_toolarge3		;buffer overflow

;- - go to last Hunk - - - - - - - - - - - - - - - - - - - -

	move.l	Buffer(a4),a0
	move.l	Size3(a4),d2
	moveq.l	#5*4,d0
	sub.l	d0,d2
	bmi.w	s_bogus3		;too short for head

	cmp.l	#1011,(a0)+
	bne.w	s_bogus3		;not an object file

	tst.l	(a0)+
	bne.w	s_bogus3		;resident libraries???

	move.l	(a0)+,d0
	ble.w	s_bogus3		;invalid Hunk count

	move.l	d0,NumHunks(a4)
	addq.l	#8,a0
	lsl.l	#2,d0
	sub.l	d0,d2
	bmi.w	s_bogus3		;too short for Hunk length table

	subq.l	#4,d0
	add.l	d0,a0
	move.l	a0,d0
	sub.l	Buffer(a4),d0
	move.l	d0,SizeOffs(a4)
	move.l	(a0)+,d0
	lsl.l	#2,d0
	beq.w	s_bogus3		;last Hunk empty

	move.l	d0,HunkSize(a4)
	move.l	NumHunks(a4),d3
	moveq.l	#1,d0
	cmp.l	d0,d3
	beq.w	s_single		;all in 1 Code Hunk (v3.17+)
	bra.s	s_hsnext
s_hunkskip:
	subq.l	#8,d2
	bmi.w	s_bogus3		;too short for Hunk head

	move.l	(a0)+,d0
	sub.l	#1001,d0
	beq.s	s_hs1			;a Code Hunk

	subq.l	#1002-1001,d0
	bne.w	s_bogus3		;no data Hunk
s_hs1:
	move.l	(a0)+,d0
	lsl.l	#2,d0
	sub.l	d0,d2
	bmi.w	s_bogus3		;too short for Hunk body

	add.l	d0,a0
s_hssub:
	subq.l	#4,d2
	bmi.w	s_bogus3		;too short for Hunk Subtype

	move.l	(a0)+,d0
	sub.l	#1010,d0
	beq.s	s_hsnext		;end of Hunk

	addq.l	#1010-1004,d0
	bne.w	s_bogus3		;no relocation table
s_hsreloc:
	subq.l	#4,d2
	bmi.w	s_bogus3		;too short for table size

	move.l	(a0)+,d0
	beq.s	s_hssub			;no more tables

	addq.l	#1,d0
	lsl.l	#2,d0
	sub.l	d0,d2
	bmi.w	s_bogus3		;too short for Table

	add.l	d0,a0
	bra.s	s_hsreloc		;next Table
s_hsnext:
	subq.l	#1,d3
	bgt.s	s_hunkskip

;- - validate Hunk - - - - - - - - - - - - - - - - - - - - -

	move.l	a0,d0
	sub.l	Buffer(a4),d0
	move.l	d0,HunkOffs(a4)		;Hunk found!
	subq.l	#8,d2
	bmi.w	s_bogus3		;too short for Hunk head

	move.l	(a0)+,d0
	cmp.l	#1002,d0
	bne.w	s_bogus3		;no data Hunk

	move.l	(a0)+,d0
	lsl.l	#2,d0
	sub.l	d0,d2
	bmi.w	s_bogus3		;too short for Hunk body

	cmp.l	HunkSize(a4),d0
	bne.w	s_bogus3		;Hunk length mismatch

	add.l	d0,a0
	move.l	a0,d0
	sub.l	Buffer(a4),d0
	move.l	d0,TailOffset(a4)
	moveq.l	#4,d0
	move.l	d0,TailSize(a4)
	subq.l	#4,d2
	bmi.w	s_bogus3		;too short Hunk end

	move.l	(a0)+,d0
	cmp.l	#1010,d0
	bne.w	s_bogus3		;no Hunk end

	move.l	HunkOffs(a4),d0
	addq.l	#8,d0
	move.l	d0,ChunkOffs(a4)
	add.l	Buffer(a4),d0
	move.l	d0,a0
	cmp.l	#'loca',(a0)
	bne.w	s_bogus3		;no ID
	bra.w	s_switch

;- - new mode - all in 1 Code-Hunk - - - - - - - - - - - - -

s_single:
	move.l	a0,d0
	sub.l	Buffer(a4),d0
	move.l	d0,HunkOffs(a4)		;Hunk found!
	subq.l	#8,d2
	bmi.w	s_bogus3		;too short for Hunk head

	move.l	(a0)+,d0
	cmp.l	#1001,d0
	bne.w	s_bogus3		;not a Code Hunk

	move.l	(a0)+,d0
	lsl.l	#2,d0
	sub.l	d0,d2
	bmi.w	s_bogus3		;too short for Hunk body

	cmp.l	HunkSize(a4),d0
	bne.w	s_bogus3		;Hunk length mismatch

	add.l	d0,a0
	move.l	a0,d0
	sub.l	Buffer(a4),d0
	move.l	d0,TailOffset(a4)
	move.l	d2,TailSize(a4)
	subq.l	#4,d2
	bmi.w	s_bogus3		;too short for Hunk end

	add.l	d2,a0
	move.l	(a0)+,d0
	cmp.l	#1010,d0
	bne.w	s_bogus3		;no Hunk end

	move.l	HunkOffs(a4),d0
	addq.l	#8,d0
	move.l	Buffer(a4),a0
	add.l	d0,a0			;&Code begin
	cmp.w	#RTC_MATCHWORD,2(a0)
	bne.w	s_bogus3		;no Resident Tag

	move.l	2+RT_Sizeof(a0),d1	;Offset of Locale section
	cmp.l	HunkSize(a4),d1
	bcc.w	s_bogus3		;behind end of Hunk????

	add.l	d1,a0
	add.l	d0,d1
	move.l	d1,ChunkOffs(a4)
	cmp.l	#'loca',(a0)
	bne.w	s_bogus3		;no ID

;- - mode switch - - - - - - - - - - - - - - - - - - - - - -

s_switch:
	tst.l	StartupMsg(a4)
	bne.w	s_writewb

	cmp.b	#'w',Mode+3(a4)
	beq.w	s_writetext

;= = Object -> Text = = = = = = = = = = = = = = = = = = = =

;s_readtext:
	move.l	TextBuffer(a4),a1	;&target
	lea	FileHeadStr(pc),a0
	bsr.w	StrCopy
s_rchunk:
	move.l	Buffer(a4),a0
	add.l	ChunkOffs(a4),a0	;&source
	move.l	(a0)+,d0
	beq.w	s_rwrite		;no further sections

	move.l	(a0)+,d1		;section length
	addq.l	#8,d1
	add.l	d1,ChunkOffs(a4)	;Offset of next section
	cmp.l	#'loca',d0
	beq.s	s_rloca

	cmp.l	#'unic',d0
	beq.s	s_runic

	cmp.l	#'oem ',d0
	beq.s	s_roem
	bra.s	s_rchunk

;- - read user interface texts - - - - - - - - - - - - - - -

s_rloca:
	move.l	a0,d2
	move.b	#LF,(a1)+
	lea	LocaStr(pc),a0
	bsr.w	StrCopy
	move.b	#LF,(a1)+
	move.l	d2,a0
s_rline:
	moveq.l	#0,d0
	move.b	(a0)+,d0
	beq.s	s_rchunk

	bsr.w	Num2Str			;Text #
	move.b	#' ',(a1)+
	move.b	#'=',(a1)+
	move.b	#' ',(a1)+
	bsr.w	StrCopy			;text
	move.b	#LF,(a1)+
	bra.s	s_rline

;- - read unicode table  - - - - - - - - - - - - - - - - - -

s_runic:
	move.l	a0,d2
	move.b	#LF,(a1)+
	lea	UnicStr(pc),a0
	bsr.w	StrCopy
	move.b	#LF,(a1)+
	move.l	d2,a0
	moveq.l	#0,d2
s_ruline:
	move.w	(a0)+,d3
	cmp.w	d2,d3
	beq.s	s_runext		;skip 1:1 mappings

	move.w	d2,d0
	moveq.l	#2,d1
	bsr.w	Num2Hex			;the Amiga char
	move.b	#TAB,(a1)+
	move.w	d3,d0
	moveq.l	#4,d1
	bsr.w	Num2Hex			;the Unicode char
	move.b	#LF,(a1)+
s_runext:
	addq.w	#1,d2
	cmp.w	#256,d2
	bcs.s	s_ruline
	bra.w	s_rchunk

;- - read OEM table  - - - - - - - - - - - - - - - - - - - -

s_roem:
	move.l	a0,d2
	move.b	#LF,(a1)+
	lea	OemStr(pc),a0
	bsr.w	StrCopy
	move.b	#LF,(a1)+
	move.l	d2,a0
	move.w	#$a0,d2
	move.w	-2(a0),d4		;64 or 96 entries
	add.w	d2,d4
s_roline:
	move.b	(a0)+,d3
	cmp.w	#$e0,d2
	bcs.s	s_rolow

	cmp.b	-33(a0),d3
	beq.s	s_ronext		;skip the entry $20 below
	bra.s	s_roput
s_rolow:
	cmp.b	d2,d3
	beq.s	s_ronext		;skip 1:1 mappings
s_roput:

	move.w	d2,d0
	moveq.l	#2,d1
	bsr.w	Num2Hex			;the Amiga char
	move.b	#TAB,(a1)+
	move.w	d3,d0
	moveq.l	#2,d1
	bsr.w	Num2Hex			;the OEM char
	move.b	#LF,(a1)+
s_ronext:
	addq.w	#1,d2
	cmp.w	d4,d2
	bcs.s	s_roline
	bra.w	s_rchunk

;- - print log - - - - - - - - - - - - - - - - - - - - - - -

s_rwrite:
	clr.b	(a1)
	move.l	a1,d0
	sub.l	TextBuffer(a4),d0
	move.l	d0,TextSize(a4)
	bsr.w	SameAsHandler
	bne.w	s_samefile

	move.l	LangName(a4),d1
	move.l	#MODE_NEWFILE,d2
	CALLDOS	Open
	move.l	d0,File2(a4)
	beq.w	s_nowrite2

	move.l	d0,d1
	move.l	TextBuffer(a4),d2
	move.l	TextSize(a4),d3
	CALLDOS	Write
	move.l	d0,-(sp)
	move.l	File2(a4),d1
	CALLDOS	Close
	clr.l	File2(a4)
	move.l	(sp)+,d0
	cmp.l	TextSize(a4),d0
	bne.w	s_nowrite2
s_rend:
	bra.w	s_freebuf

;= = Text -> Object = = = = = = = = = = = = = = = = = = = =
;- - read Text file - - - - - - - - - - - - - - - - - - - -

s_writewb:
	move.l	StartupMsg(a4),a0
	move.l	SM_NumArgs(a0),d0
	subq.l	#2,d0
	bcs.w	s_wend			;no WB Document

	move.l	SM_ArgList(a0),a0
	move.l	WA_Sizeof+WA_Lock(a0),d1
	move.l	WA_Sizeof+WA_Name(a0),d3
	CALLDOS CurrentDir
	move.l	d0,OldDir(a4)
	move.l	d3,d1
	move.l	#MODE_OLDFILE,d2
	CALLDOS	Open
	move.l	d0,d2
	move.l	OldDir(a4),d1
	CALLDOS	CurrentDir
	move.l	d2,d0
	bra.s	s_w1

s_writetext:
	move.l	LangName(a4),d1
	move.l	#MODE_OLDFILE,d2
	CALLDOS	Open
s_w1:
	move.l	d0,File2(a4)
	beq.w	s_notext2

	move.l	d0,d1
	move.l	TextBuffer(a4),d2
	move.l	BufSize(a4),d3
	lsr.l	#1,d3
	subq.l	#1,d3
	CALLDOS	Read
	move.l	d0,TextSize(a4)
	move.l	File2(a4),d1
	CALLDOS	Close
	clr.l	File2(a4)
	move.l	TextSize(a4),d0
	bmi.w	s_notext2

	move.l	TextBuffer(a4),a0
	clr.b	(a0,d0.l)		;avoid file length check
	move.l	BufSize(a4),d0
	lsr.l	#1,d0
	move.l	Buffer(a4),a0
	move.l	a0,a1
	add.l	d0,a1
	add.l	TailOffset(a4),a0
	move.l	TailSize(a4),d1
	add.l	d1,a0
s_wl1:
	move.l	-(a0),-(a1)		;save tail to end of buffer
	subq.l	#4,d1
	bgt.s	s_wl1

;- - transfer user interface texts - - - - - - - - - - - - -

	move.l	TextBuffer(a4),a0
	lea	LocaStr(pc),a1
	bsr.w	StrScan
	tst.w	d0
	beq.s	s_wlskip		;section missing, keep texts

	move.l	Buffer(a4),a1
	add.l	ChunkOffs(a4),a1
	addq.l	#8,a1
s_wlline:
	bsr.w	NextLine
	move.b	(a0),d0
	beq.s	s_wldone

	cmp.b	#'[',d0
	beq.s	s_wldone

	bsr.w	Str2Num
	tst.b	d0
	beq.s	s_wlline		;invalid Text #

	bsr.w	StrCue
	move.b	(a0)+,d1
	beq.s	s_wldone

	cmp.b	#'=',d1
	bne.s	s_wlline		;nothing assigned

	move.b	d0,(a1)+
	bsr.w	StrCue
s_wltext:
	move.b	(a0)+,d0
	cmp.b	#' ',d0
	bcs.s	s_wlnext

	move.b	d0,(a1)+		;transfer to end of line
	bra.s	s_wltext
s_wlnext:
	subq.l	#1,a0
	clr.b	(a1)+
	bra.s	s_wlline
s_wldone:
	clr.b	(a1)+
	move.l	Buffer(a4),a0
	add.l	ChunkOffs(a4),a0
	move.l	a1,d0
	sub.l	a0,d0
	subq.l	#8-3,d0
	and.w	#$fffc,d0
	move.l	#'loca',(a0)+
	move.l	d0,(a0)			;mark section length
	bra.s	s_wlend
s_wlskip:
	move.l	Buffer(a4),a0
	add.l	ChunkOffs(a4),a0
	move.l	4(a0),d0
s_wlend:
	addq.l	#8,d0
	add.l	d0,ChunkOffs(a4)

;- - build unicode table - - - - - - - - - - - - - - - - - -

s_wunic:
	move.l	TextBuffer(a4),a0
	lea	UnicStr(pc),a1
	bsr.w	StrScan
	tst.w	d0
	beq.s	s_woem			;no section, no Table

	move.l	Buffer(a4),a1
	add.l	ChunkOffs(a4),a1
	move.l	#'unic',(a1)+
	moveq.l	#64,d0
	lsl.l	#3,d0
	move.l	d0,(a1)+
	addq.l	#8,d0
	add.l	d0,ChunkOffs(a4)
	move.l	a1,d3
	moveq.l	#0,d2
s_wuinit:
	move.w	d2,(a1)+		;default to 1:1
	addq.w	#1,d2
	cmp.w	#256,d2
	bcs.s	s_wuinit

	move.l	d3,a1
s_wuline:
	bsr.w	NextLine
	move.b	(a0),d0
	beq.s	s_wudone		;end of Text

	cmp.b	#'[',d0
	beq.s	s_wudone		;end of section

	bsr.w	Str2Num
	move.l	d0,d2
	beq.s	s_wuline		;invalid Amiga char

	cmp.w	#256,d0
	bcc.s	s_wuline		;dito

	bsr.w	StrCue
	bsr.w	Str2Num
	move.l	d0,d3
	beq.s	s_wuline		;invalid Unicode char

	lsl.w	#1,d2
	move.w	d3,(a1,d2.w)		;write char
	bra.s	s_wuline
s_wudone:

;- - build OEM table - - - - - - - - - - - - - - - - - - - -

s_woem:
	move.l	TextBuffer(a4),a0
	lea	OemStr(pc),a1
	bsr.w	StrScan
	tst.w	d0
	beq.s	s_wwrite		;no section, no Table

	move.l	Buffer(a4),a1
	add.l	ChunkOffs(a4),a1
	move.l	#'oem ',(a1)+
	moveq.l	#96,d0
	move.l	d0,(a1)+
	addq.l	#8,d0
	add.l	d0,ChunkOffs(a4)
	move.l	a1,d3
	move.w	#$a0,d2
s_woinit:
	move.b	d2,(a1)+		;default to 1:1
	addq.w	#1,d2
	cmp.w	#$e0,d2
	bcs.s	s_woinit
s_woinit2:
	clr.b	(a1)+			;$e0..$ff: not named yet
	addq.w	#1,d2
	cmp.w	#$100,d2
	bcs.s	s_woinit2

	move.l	d3,a1
s_woline:
	bsr.w	NextLine
	move.b	(a0),d0
	beq.s	s_wodone		;end of Text

	cmp.b	#'[',d0
	beq.s	s_wodone		;end of section

	bsr.w	Str2Num
	move.l	d0,d2
	sub.w	#$a0,d2
	bmi.s	s_woline		;invalid Amiga char

	cmp.w	#$60,d2
	bcc.s	s_woline		;dito

	bsr.w	StrCue
	bsr.w	Str2Num
	move.l	d0,d3
	beq.s	s_woline		;invalid OEM char

	move.b	d3,(a1,d2.w)		;write char
	bra.s	s_woline
s_wodone:
	lea	64(a1),a0		;$e0..$ff not named: the upper case..
	moveq.l	#32-1,d0
s_wofill:
	tst.b	(a0)
	bne.s	s_wofnext

	move.b	-32(a0),(a0)		;..is the entry $20 below
s_wofnext:
	addq.l	#1,a0
	dbf	d0,s_wofill

;- - write object - - - - - - - - - - - - - - - - - - - - -

s_wwrite:
	move.l	Buffer(a4),a0
	move.l	a0,a1
	add.l	ChunkOffs(a4),a0
	clr.l	(a0)+			;"end of sections"
	addq.l	#4,ChunkOffs(a4)
	move.l	BufSize(a4),d0
	lsr.l	#1,d0
	add.l	d0,a1
	move.l	TailSize(a4),d1
	sub.l	d1,a1
s_wwl1:
	move.l	(a1)+,(a0)+		;restore tail
	subq.l	#4,d1
	bgt.s	s_wwl1

	move.l	Buffer(a4),a1
	sub.l	a1,a0
	move.l	a0,Size3(a4)		;new file lenght
	move.l	ChunkOffs(a4),d0
	move.l	HunkOffs(a4),d1
	sub.l	d1,d0
	subq.l	#8,d0			;new Hunk length..
	move.l	a1,a0
	add.l	d1,a0			;&Hunk
	move.l	NumHunks(a4),d2
	subq.l	#1,d2
	bne.s	s_ww1

	move.l	d0,8+2+RT_EndSkip(a0)
s_ww1:
	lsr.l	#2,d0			;..in longwords..
	move.l	d0,4(a0)		;..into Hunk head..
	add.l	SizeOffs(a4),a1
	moveq.l	#3,d1
	ror.l	#2,d1
	and.l	(a1),d1
	or.l	d0,d1
	move.l	d0,(a1)			;..and file head
	move.l	HandlerName(a4),d1
	move.l	#MODE_NEWFILE,d2
	CALLDOS	Open
	move.l	d0,File3(a4)
	beq.w	s_nowrite3

	move.l	d0,d1
	move.l	Buffer(a4),d2
	move.l	Size3(a4),d3
	CALLDOS	Write			;overwrite object file
	move.l	d0,-(sp)
	move.l	File3(a4),d1
	CALLDOS	Close
	clr.l	File3(a4)
	move.l	(sp)+,d0
	cmp.l	Size3(a4),d0
	bne.w	s_nowrite3
s_wend:

;- - and party  - - - - - - - - - - - - - - - - - - - - - -

s_freebuf:
	move.l	Buffer(a4),a1
	move.l	BufSize(a4),d0
	CALLEXEC FreeMem
s_closelib:
	move.l	RDArgs(a4),d1
	beq.s	s_cl1

	CALLDOS	FreeArgs
s_cl1:
	move.l	DosBase(a4),a1
	CALLEXEC CloseLibrary
s_end:
	move.l	StartupMsg(a4),d2
	beq.s	s_exit

	CALLEXEC Forbid
	move.l	d2,a1
	CALLEXEC ReplyMsg
s_exit:
	move.l	Result(a4),d0
	movem.l	(sp)+,d1-d5/a0-a1/a6
	unlk	a4
	rts

s_help:
	lea	HelpStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closelib

s_nomem:
	lea	NoMemStr(pc),a0
	bsr.w	ReportError
	bra.w	s_closelib

s_argerr:
	CALLDOS	IoErr
	move.l	d0,d1
	lea	ProgName(pc),a0
	move.l	a0,d2
	CALLDOS	PrintFault
	moveq.l	#10,d0
	move.l	d0,Result(a4)
	bra.s	s_closelib

s_nofile3:
	lea	NoFile3Str(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuf

s_toolarge3:
	lea	TooLarge3Str(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuf

s_bogus3:
	lea	Bogus3Str(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuf

s_nowrite3:
	lea	NoWrite3Str(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuf

s_notext2:
	lea	NoText2Str(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuf

s_nowrite2:
	lea	NoWrite2Str(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuf

s_samefile:
	lea	SameFileStr(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuf


;--- report error ------------------------------------------
; a0 <- &Text, %s is the handler file

ReportError:
	move.l	a0,d2
	CALLDOS	Output
	move.l	d0,d1
	beq.s	re_end

	lea	HandlerName(a4),a0
	move.l	a0,d3
	CALLDOS	VFPrintf
re_end:
	moveq.l	#10,d0
	move.l	d0,Result(a4)
	rts

;--- language file is the handler file ---------------------
; d0 -> 1 and Z clear when LangName and HandlerName are one file

SameAsHandler:
	movem.l	d2-d4,-(sp)
	moveq.l	#0,d4
	move.l	LangName(a4),d1
	moveq.l	#SHARED_LOCK,d2
	CALLDOS	Lock
	move.l	d0,d3
	beq.s	sah_end

	move.l	HandlerName(a4),d1
	moveq.l	#SHARED_LOCK,d2
	CALLDOS	Lock
	move.l	d0,d2
	beq.s	sah_un1

	move.l	d3,d1
	CALLDOS	SameLock
	tst.l	d0
	bne.s	sah_un2

	moveq.l	#1,d4
sah_un2:
	move.l	d2,d1
	CALLDOS	UnLock
sah_un1:
	move.l	d3,d1
	CALLDOS	UnLock
sah_end:
	move.l	d4,d0
	movem.l	(sp)+,d2-d4
	rts

;--- copy string -------------------------------------------
; a0 <-  &source
; a1 <-> &dest

StrCopy:
	move.b	(a0)+,(a1)+
	bne.s	StrCopy

	subq.l	#1,a1			;to be resumed...
	rts

;--- skip spaces -------------------------------------------
; a0 <-> &source

StrCue:
	move.l	d0,-(sp)
scu_loop:
	move.b	(a0)+,d0
	beq.s	scu_end

	cmp.b	#TAB,d0
	beq.s	scu_loop

	cmp.b	#' ',d0
	beq.s	scu_loop
scu_end:
	subq.l	#1,a0
	move.l	(sp)+,d0
	rts

;--- find beginning of line --------------------------------
; a0 <-> &text

NextLine:
	move.l	d0,-(sp)
nli_loop:
	move.b	(a0)+,d0
	beq.s	nli_end

	cmp.b	#LF,d0			;after newline..
	bne.s	nli_loop
nli_cue:
	bsr.s	StrCue			;..the first printable char
	move.b	(a0)+,d0
	cmp.b	#LF,d0
	beq.s	nli_cue			;skip empty line

	cmp.b	#';',d0
	beq.s	nli_loop		;skip comment
nli_end:
	subq.l	#1,a0
	move.l	(sp)+,d0
	rts

;--- parse word ----------------------------------------
; a0 <-> &text
; a1 <-  &pattern
; d0  -> success

StrScan:
	movem.l	d1/a1,-(sp)
	bsr.s	StrCue
ssc_line:
	tst.b	(a0)
	beq.s	ssc_notfound

	move.l	a0,d1
	move.l	4(sp),a1
ssc_char:
	move.b	(a1)+,d0
	beq.s	ssc_found

	cmp.b	(a0)+,d0
	beq.s	ssc_char

	move.l	d1,a0
	bsr.s	NextLine
	bra.s	ssc_line
ssc_found:
	moveq.l	#-1,d0
	bra.s	ssc_end
ssc_notfound:
	moveq.l	#0,d0
ssc_end:
	movem.l	(sp)+,d1/a1
	rts

;--- find file name ----------------------------------------
; a0 <- &path name
; d0 -> &file name

FilePart:
	movem.l	d1/a0,-(sp)
fp_mark:
	move.l	a0,d0
fp_loop:
	move.b	(a0)+,d1
	cmp.b	#'/',d1
	beq.s	fp_mark

	cmp.b	#':',d1
	beq.s	fp_mark

	tst.b	d1
	bne.s	fp_loop

	movem.l	(sp)+,d1/a0
	rts

;--- string -> number --------------------------------------
; a0 <-> &string
; d0  -> value

Str2Num:
	move.l	d2,-(sp)
	moveq.l	#0,d0
	moveq.l	#0,d2			;"decimal mode"
s2n_char:
	move.b	(a0)+,d2
	btst	#6,d2
	beq.s	s2n_c1

	and.b	#$df,d2			;toUpper
s2n_c1:
	sub.b	#'0',d2
	bcs.s	s2n_hcheck

	tst.l	d2
	bmi.s	s2n_hchar

	cmp.b	#10,d2
	bcc.s	s2n_hcheck

	lsl.l	#1,d0
	move.l	d0,d1
	lsl.l	#2,d1
	add.l	d1,d0
	add.l	d2,d0
	bra.s	s2n_char
s2n_hchar:
	cmp.b	#10,d2
	bcs.s	s2n_hadd

	subq.b	#'A'-'9'-1,d2
	bcs.s	s2n_end

	cmp.b	#16,d2
	bcc.s	s2n_end
s2n_hadd:
	lsl.l	#4,d0
	or.b	d2,d0
	bra.s	s2n_char
s2n_hcheck:
	cmp.b	#'X'-'0',d2
	beq.s	s2n_hswitch

	cmp.b	#'$'-'0',d2
	bne.s	s2n_end
s2n_hswitch:
	moveq.l	#0,d0
	moveq.l	#-1,d2			;"hex mode"
	bra.s	s2n_char
s2n_end:
	subq.l	#1,a0
	move.l	(sp)+,d2
	rts

;--- num -> string -----------------------------------------
; d0 <-  value
; a1 <-> &String

Num2Str:
	movem.l	d0-d2/a0,-(sp)
	move.l	a1,a0		;remember start of buffer
n2s_loop1:
	moveq.l	#10,d1
	bsr.s	UDivMod32
	or.b	#'0',d1
	move.b	d1,(a1)+	;append digit
	tst.l	d0
	bne.s	n2s_loop1

	move.l	a1,d2		;remember end of buffer
	move.l	a1,d1
	sub.l	a0,d1		;# digits
	asr.w	#1,d1
	beq.s	n2s_end		;just 1 digit
n2s_loop2:
	move.b	-(a1),d0
	move.b	(a0),(a1)
	move.b	d0,(a0)+
	subq.w	#1,d1
	bne.s	n2s_loop2	;reverse order of digits
n2s_end:
	move.l	d2,a1
	clr.b	(a1)		;terminate string
	movem.l	(sp)+,d0-d2/a0
	rts

;--- num -> Hex --------------------------------------------
; d0 <-  value
; d1 <-  # digits
; a1 <-> &target

Num2Hex:
	movem.l	d1-d2,-(sp)
	move.b	#'0',(a1)+
	move.b	#'x',(a1)+
	lsl.w	#2,d1
	ror.l	d1,d0
n2h_loop:
	rol.l	#4,d0
	moveq.l	#15,d2
	and.l	d0,d2
	add.w	#'0',d2
	cmp.w	#'9'+1,d2
	bcs.s	n2h_put

	add.w	#'a'-'9'-1,d2
n2h_put:
	move.b	d2,(a1)+
	subq.w	#4,d1
	bgt.s	n2h_loop

	movem.l	(sp)+,d1-d2
	rts

;*** longword math *****************************************
; d0 *= d1

UMul32:
	movem.l	d1-d3,-(sp)
	move.w	d1,d2
	mulu.w	d0,d2
	move.l	d1,d3
	swap	d3
	mulu.w	d0,d3
	swap	d3
	clr.w	d3
	add.l	d3,d2
	swap	d0
	mulu.w	d1,d0
	swap	d0
	clr.w	d0
	add.l	d2,d0
	movem.l	(sp)+,d1-d3
	rts

;d0 /= d1, d1 = d0 mod d1

UDivMod32:
	movem.l	d2/d3,-(sp)
	swap	d1
	tst.w	d1
	bne.s	udm32_long		;Divisor > $ffff

	swap	d1
	move.w	d1,d3
	move.w	d0,d2
	clr.w	d0
	swap	d0
	divu.w	d3,d0
	move.l	d0,d1
	swap	d0
	move.w	d2,d1
	divu.w	d3,d1
	move.w	d1,d0
	clr.w	d1
	swap	d1
	movem.l	(sp)+,d2/d3
	rts

udm32_long:
	swap	d1
	move.l	d1,d3
	move.l	d0,d1
	clr.w	d1
	swap	d1
	swap	d0
	clr.w	d0
	moveq.l	#15,d2
udm32_loop:
	add.l	d0,d0
	addx.l	d1,d1
	cmp.l	d1,d3
	bhi.s	udm32_next

	sub.l	d3,d1
	addq.w	#1,d0
udm32_next:
	dbf	d2,udm32_loop

	movem.l	(sp)+,d2/d3
	rts

;--- Texts -------------------------------------------------

		VER_STRING
DosName:	dc.b	'dos.library', 0
Fat95Name:	dc.b	'l:'
Fat95Name2:	dc.b	'fat95',0
ProgName:	dc.b	'install95', 0
ArgTemplate:	dc.b	'W=WRITE/S,R=READ/S,LANGUAGE/A,HANDLER/K', 0
HelpStr:	dc.b	'usage: install95 WRITE|READ <language> [HANDLER <file>]', LF, 0
NoMemStr:	dc.b	'not enough memory.', LF, 0
NoFile3Str:	dc.b	'file "%s" not found.', LF, 0
TooLarge3Str:	dc.b	'file "%s" too large.', LF, 0
Bogus3Str:	dc.b	'file "%s" is incompatible.', LF, 0
NoWrite3Str:	dc.b	'cannot write "%s".', LF, 0
NoText2Str:	dc.b	'cannot read the language file.', LF, 0
NoWrite2Str:	dc.b	'cannot write the language file.', LF, 0
SameFileStr:	dc.b	'the language file cannot be "%s".', LF, 0
FileHeadStr:	dc.b	';fat95 locale file', LF, 0
InstStr:	dc.b	'[installer]',0
LocaStr:	dc.b	'[locale]', 0
UnicStr:	dc.b	'[unicode]',0
OemStr:		dc.b	'[oem]',0
		even

;*** that's it!!!! *****************************************
	end
