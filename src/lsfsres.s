; lsfsres - dump FileSystem.resource entries
; Copyright (C) 2026  Jaroslav Pulchart
; This file is part of FAT95, a free FAT compatible file system for Amiga.
;
; This tool is free software; you can redistribute it and/or
; modify it under the terms of the GNU Lesser General Public
; License as published by the Free Software Foundation; either
; version 2.1 of the License, or (at your option) any later version.
;
; This tool is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; Lesser General Public License for more details.

; --- Includes ---
	include	"lsfsres_version.i"

;--- exec.library ------------------------------------------

CALLEXEC macro
	move.l	ExecBase(a4),a6
	jsr	\1(a6)
	endm

_AbsExecBase	= 4

OpenLibrary	= -552
CloseLibrary	= -414
OpenResource	= -498
Forbid		= -132
Permit		= -138

;--- dos.library -------------------------------------------

CALLDOS	macro
	move.l	DosBase(a4),a6
	jsr	\1(a6)
	endm

Output		= -60
Write		= -48
VPrintf		= -954

LF		= 10
CR		= 13

;--- struct offsets (from NDK Include_I/resources/filesysres.i) ---
; Node (LN_SIZE = 14):
;   LN_SUCC      = 0
;   LN_PRED      = 4
;   LN_TYPE      = 8
;   LN_PRI       = 9
;   LN_NAME      = 10
; List (LH_SIZE = 14):
;   LH_HEAD      = 0
;   LH_TAIL      = 4
;   LH_TAILPRED  = 8
LN_SUCC		= 0
LN_NAME		= 10
LH_HEAD		= 0

; FileSysResource (after LN_SIZE=14):
;   fsr_Creator        = 14
;   fsr_FileSysEntries = 18  (LH structure)
fsr_FileSysEntries = 18

; FileSysEntry (after LN_SIZE=14):
fse_DosType	= 14
fse_Version	= 18
fse_PatchFlags	= 22
fse_SegList	= 54

;--- ROM address ranges (byte addresses, after BPTR<<2) ----
; Main Kickstart ROM:   $00F80000 .. $01000000
; Extended (E0) ROM:    $00E00000 .. $00E80000
ROM_MAIN_LO	= $00F80000
ROM_MAIN_HI	= $01000000
ROM_EXT_LO	= $00E00000
ROM_EXT_HI	= $00E80000

;--- global vars (stack frame) -----------------------------
; LINK allocates `VarsSize` bytes below a4. Offsets below are arranged
; so the larger buffers (Argv, NameBuf) live further from a4 than the
; scalar pointers above them — no overlap.

ExecBase	= -4		;long
DosBase		= -8		;long
FSResource	= -12		;long
EntryCount	= -16		;long
Argv		= -48		;8 longs (Argv+0..Argv+28), bytes -48..-17
; NameBuf splits into two regions used by RenderDosType (first 5 bytes)
; and the name copy (offset +8 onwards). Widened to 88 bytes total so
; names get up to ~78 chars (okish for typical AmigaOS IDStrs
; without truncating across the version banner).
NameBuf		= -136		;88 bytes, bytes -136..-49
VarsSize	= 136

;*** entry point *******************************************
; a0 <- command line (ignored)
; d0 <- length      (ignored)

Start:
	link.w	a4,#-VarsSize
	movem.l	d2-d7/a2-a3/a6,-(sp)

	move.l	(_AbsExecBase).w,ExecBase(a4)
	clr.l	EntryCount(a4)

	moveq.l	#36,d0			;need V36+ for VPrintf and FS.resource
	lea	DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	beq.w	s_end_nodos

	lea	FSRName(pc),a1
	CALLEXEC OpenResource
	move.l	d0,FSResource(a4)
	bne.s	s_haveres

	lea	NoResStr(pc),a0
	bsr.w	WriteStr
	bra.w	s_closedos

s_haveres:
	lea	HeaderStr(pc),a0
	bsr.w	WriteStr

	CALLEXEC Forbid

	move.l	FSResource(a4),a2
	lea	fsr_FileSysEntries(a2),a3	;list header
	move.l	LH_HEAD(a3),a3			;a3 = first node (or tail sentinel)

s_loop:
	tst.l	LN_SUCC(a3)
	beq.w	s_done

	;--- print one entry ---
	addq.l	#1,EntryCount(a4)

	;Argv layout for the format string below:
	; [0] = entry index            (%ld)
	; [1] = DosType                 (%08lx)
	; [2] = pointer to 4-char ASCII (%s)
	; [3] = Version                 (%08lx)
	; [4] = PatchFlags              (%04lx)  -- low 16 bits printed
	; [5] = SegList byte address    (%08lx)
	; [6] = pointer to "[ROM]"/"[RAM]" (%s)
	; [7] = pointer to Name string  (%s)

	move.l	EntryCount(a4),Argv(a4)
	move.l	fse_DosType(a3),Argv+4(a4)

	;build 4-char ASCII rendering of the DosType into NameBuf+0..NameBuf+5
	;(reuse the start of NameBuf as scratch; we copy the actual name later
	; into NameBuf+8..NameBuf+39)
	lea	NameBuf(a4),a0
	move.l	fse_DosType(a3),d0
	bsr.w	RenderDosType			;writes 4 bytes + NUL
	move.l	a0,Argv+8(a4)			;a0 returned = pointer to start of ASCII

	move.l	fse_Version(a3),Argv+12(a4)
	move.l	fse_PatchFlags(a3),Argv+16(a4)

	;SegList: stored as BPTR; convert to byte address
	move.l	fse_SegList(a3),d0
	lsl.l	#2,d0
	move.l	d0,Argv+20(a4)

	;decide [ROM] vs [RAM]
	cmp.l	#ROM_MAIN_LO,d0
	bcs.s	s_check_ext
	cmp.l	#ROM_MAIN_HI,d0
	bcs.s	s_rom
s_check_ext:
	cmp.l	#ROM_EXT_LO,d0
	bcs.s	s_ram
	cmp.l	#ROM_EXT_HI,d0
	bcs.s	s_rom
s_ram:
	lea	RamTag(pc),a0
	bra.s	s_locset
s_rom:
	lea	RomTag(pc),a0
s_locset:
	move.l	a0,Argv+24(a4)

	;Name: copy LN_NAME into NameBuf+8, truncating at LF/CR/NUL.
	;Handlers that follow the AmigaOS convention put a short node
	;name here. fat95 puts its descriptive banner with a trailing
	; LF before the NUL), so we stop at LF/CR to avoid staircase
	; artifacts on `lsfsres >ser:`
	move.l	LN_NAME(a3),d0
	beq.s	s_noname
	move.l	d0,a0
	lea	NameBuf+8(a4),a1
	move.l	a1,Argv+28(a4)
	moveq.l	#78,d1			;max chars to copy (fits in 88-8=80)
s_ncpy:
	move.b	(a0)+,d2
	beq.s	s_ncpy_done		;NUL -> stop
	cmp.b	#LF,d2
	beq.s	s_ncpy_done		;LF -> stop (avoid staircase on ser:)
	cmp.b	#CR,d2
	beq.s	s_ncpy_done		;CR -> stop
	move.b	d2,(a1)+
	subq.l	#1,d1
	bne.s	s_ncpy
s_ncpy_done:
	clr.b	(a1)
	bra.s	s_print
s_noname:
	lea	UnnamedStr(pc),a0
	move.l	a0,Argv+28(a4)

s_print:
	lea	EntryFmt(pc),a0
	move.l	a0,d1
	lea	Argv(a4),a0
	move.l	a0,d2
	CALLDOS	VPrintf

	move.l	LN_SUCC(a3),a3
	bra.w	s_loop

s_done:
	CALLEXEC Permit

	;--- summary line ---
	move.l	EntryCount(a4),Argv(a4)
	lea	SummaryFmt(pc),a0
	move.l	a0,d1
	lea	Argv(a4),a0
	move.l	a0,d2
	CALLDOS	VPrintf

s_closedos:
	move.l	DosBase(a4),a1
	CALLEXEC CloseLibrary

s_end_nodos:
	moveq.l	#0,d0
	movem.l	(sp)+,d2-d7/a2-a3/a6
	unlk	a4
	rts

;--- helpers ------------------------------------------------

; WriteStr: write 0-terminated string in a0 to stdout
WriteStr:
	movem.l	d0-d3/a0-a1,-(sp)
	move.l	a0,d2
	moveq.l	#0,d3
ws_len:
	tst.b	(a0)+
	beq.s	ws_have
	addq.l	#1,d3
	bra.s	ws_len
ws_have:
	CALLDOS	Output
	move.l	d0,d1
	beq.s	ws_end
	CALLDOS	Write
ws_end:
	movem.l	(sp)+,d0-d3/a0-a1
	rts

; RenderDosType: 4-byte DosType in d0 -> ASCII at NameBuf(a4)
; Non-printable bytes (< 32 or > 126) are rendered as '.'
; Returns a0 = pointer to start of ASCII (5 bytes incl. NUL)
RenderDosType:
	movem.l	d0-d2/a1,-(sp)
	lea	NameBuf(a4),a1
	moveq.l	#3,d2			;4 bytes, MSB first
rd_loop:
	rol.l	#8,d0
	move.b	d0,d1
	cmp.b	#32,d1
	bcs.s	rd_dot
	cmp.b	#126,d1
	bhi.s	rd_dot
	bra.s	rd_emit
rd_dot:
	moveq.l	#'.',d1
rd_emit:
	move.b	d1,(a1)+
	dbf	d2,rd_loop
	clr.b	(a1)
	lea	NameBuf(a4),a0
	movem.l	(sp)+,d0-d2/a1
	rts

;--- texts --------------------------------------------------

	VER_STRING
DosName:	dc.b	'dos.library',0
FSRName:	dc.b	'FileSystem.resource',0
; CR+LF line endings so the output is readable on both CON: and SER:
NoResStr:	dc.b	'FileSystem.resource not available (need V36+).',CR,LF,0
HeaderStr:	dc.b	'#: DosType (ascii) Version  Patch SegList  Loc   Name',CR,LF
		dc.b	'----------------------------------------------------------',CR,LF,0
EntryFmt:	dc.b	'%2ld: %08lx (%s)    %08lx %04lx  %08lx %s   %s',CR,LF,0
SummaryFmt:	dc.b	'----------------------------------------------------------',CR,LF
		dc.b	'Total: %ld entries in FileSystem.resource.',CR,LF,0
RomTag:		dc.b	'[ROM]',0
RamTag:		dc.b	'[RAM]',0
UnnamedStr:	dc.b	'(unnamed)',0
		even

;*** end ***************************************************
	end
