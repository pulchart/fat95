; Alter size of file tool V1.02
; Copyright (C) 2001  Torsten Jager <t.jager@gmx.de>
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
;
; You should have received a copy of the GNU Lesser General Public
; License along with this library; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

; --- Includes ---
	include	"setfilesize_version.i"

;--- from exec.library -------------------------------------

CALLEXEC macro
	move.l	ExecBase(a4),a6
	jsr	\1(a6)
	endm

_AbsExecBase	= 4

OpenLibrary	= -552
CloseLibrary	= -414

;--- from dos.library --------------------------------------

CALLDOS	macro
	move.l	DosBase(a4),a6
	jsr	\1(a6)
	endm

Open		= -30
Close		= -36
Write		= -48
Output		= -60
DoPkt		= -240
SetFileSize	= -456
GetDeviceProc	= -642
FreeDeviceProc	= -648

ModeReadwrite	= 1004
ModeNewfile	= 1006

OFFSET_BEGINNING = -1
OFFSET_CURRENT	 = 0
OFFSET_END	 = 1

LF		= 10

;struct DevProc
DVP_Port	= 0
DVP_Lock	= 4
DVP_Flags	= 8
DVP_DevNode	= 12
DVP_Sizeof	= 16

ACTION_DIE	= 5
ACTION_END	= 1007

;--- global vars -------------------------------------------

ArgV		= -4
ArgC		= -8
ExecBase	= -12
DosBase		= -16
Result		= -20
File		= -24
Size		= -28
Mode		= -32
StringBuffer	= -400
VarsSize	= -400

;*** here we go !! *****************************************

; a0 <- &command line parameters
; d0 <- length thereof

Start:
	link.w	a4,#VarsSize
	movem.l	d1-d5/a0-a1/a6,-(sp)
	move.l	(_AbsExecBase).w,ExecBase(a4)
	move.l	a0,ArgV(a4)
	clr.l	Result(a4)
	lea	StringBuffer(a4),a1
	bsr.w	GetDosParams
	move.l	d0,ArgC(a4)
	moveq.l	#36,d0
	lea	DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	beq.w	s_end

	move.l	StringBuffer(a4),d1
	beq.w	s_help

	tst.l	StringBuffer+4(a4)
	beq.w	s_help

	move.l	#ModeReadwrite,d2
	CALLDOS	Open
	move.l	d0,File(a4)
	beq.w	s_nofile

	move.l	StringBuffer+4(a4),a0
	move.b	(a0)+,d0
	moveq.l	#OFFSET_END,d1
	moveq.l	#1,d2
	cmp.b	#'+',d0
	beq.s	s_number

	moveq.l	#-1,d2
	cmp.b	#'-',d0
	beq.s	s_number

	moveq.l	#OFFSET_BEGINNING,d1
	moveq.l	#1,d2
	subq.l	#1,a0
s_number:
	move.l	d1,Mode(a4)
	bsr.w	Str2Num
	tst.l	d2
	bpl.s	s_n1

	neg.l	d0
s_n1:
	move.l	d0,Size(a4)
	move.l	File(a4),d1
	move.l	Size(a4),d2
	move.l	Mode(a4),d3
	CALLDOS	SetFileSize
	move.l	d0,Size(a4)
	bmi.s	s_nosize
s_closefile:
	move.l	File(a4),d1
	CALLDOS	Close
	move.l	Size(a4),d0
	bmi.s	s_closelib

	lea	StringBuffer(a4),a1
	lea	New1Str(pc),a0
	bsr.w	StrCopy
	bsr.w	Num2Str
	lea	New2Str(pc),a0
	bsr.w	StrCopy
	lea	StringBuffer(a4),a0
	bsr.s	ReportError
s_closelib:
	move.l	DosBase(a4),a1
	CALLEXEC CloseLibrary
s_end:
	move.l	Result(a4),d0
	movem.l	(sp)+,d1-d5/a0-a1/a6
	unlk	a4
	rts

s_help:
	lea	HelpStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closelib

s_nofile:
	lea	NoFileStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closelib

s_nosize:
	lea	NoSizeStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closefile

;--- report error ------------------------------------------
; a0 <- &Text

ReportError:
	move.l	a0,d2
	moveq.l	#-1,d3
	sub.l	a0,d3
re_loop:
	tst.b	(a0)+
	bne.s	re_loop

	add.l	a0,d3
	CALLDOS	Output
	move.l	d0,d1
	beq.s	re_end

	CALLDOS	Write
re_end:
	moveq.l	#10,d0
	move.l	d0,Result(a4)
	rts

;--- extract command line parameters -----------------------
; a0 <- &command line
; a1 <- &buffer
; d0 -> # Parameters found

GetDosParams:
	movem.l	a1-a2,-(sp)
	lea	40(a1),a2		;&string target
gdp_par:
	move.l	a2,(a1)+		;vector field..
	moveq.l	#0,d2
gdp_char:
	move.b	(a0)+,d0
	cmp.b	#' ',d0
	beq.s	gdp_spc
	bcs.s	gdp_pend

	cmp.b	#'"',d0
	beq.s	gdp_cite
gdp_write:
	or.w	#1,d2
	move.b	d0,(a2)+		;..and strings
	bra.s	gdp_char

gdp_spc:
	btst	#0,d2
	beq.s	gdp_char

	btst	#1,d2
	beq.s	gdp_pend
	bra.s	gdp_write

gdp_cite:
	btst	#0,d2
	bne.s	gdp_c1

	or.w	#3,d2
	bra.s	gdp_char
gdp_c1:
	cmp.b	#' '+1,(a0)
	bcc.s	gdp_write

	move.b	(a0)+,d0
gdp_pend:
	clr.b	(a2)+
	cmp.b	#' ',d0
	beq.s	gdp_par

	btst	#0,d2
	bne.s	gdp_p1

	subq.l	#4,a1
gdp_p1:
	clr.l	(a1)
	move.l	a1,d0
	sub.l	(sp),d0
	lsr.l	#2,d0
	movem.l	(sp)+,a1-a2
	rts

;--- copy string -------------------------------------------
; a0 <-  &source
; a1 <-> &dest

StrCopy:
	move.b	(a0)+,(a1)+
	bne.s	StrCopy

	subq.l	#1,a1			;to be resumed...
	rts

;--- string -> num -----------------------------------------
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
	move.l	a1,a0		;remember buffer start
n2s_loop1:
	moveq.l	#10,d1
	bsr.s	UDivMod32
	or.b	#'0',d1
	move.b	d1,(a1)+	;append digit
	tst.l	d0
	bne.s	n2s_loop1

	move.l	a1,d2		;remember buffer end
	move.l	a1,d1
	sub.l	a0,d1		;# digits
	asr.w	#1,d1
	beq.s	n2s_end		;just 1
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

		dc.b	'$VER: '
		VER_STRING
		dc.b	LF, 0
		dc.b	'(c) Torsten Jager', 0
DosName:	dc.b	'dos.library', 0
HelpStr:	dc.b	'usage: SetFileSize <file> '
		dc.b	'<new size>|+<addbytes>|-<cutbytes>', LF, 0
NoFileStr:	dc.b	'could not open file.', LF, 0
NoSizeStr:	dc.b	'file resizing failed.', LF, 0
New1Str:	dc.b	'new file size is ', 0
New2Str:	dc.b	' bytes.', LF, 0
		even

;*** That's all folks!! ************************************
	end
