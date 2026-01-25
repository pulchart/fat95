; fat95 debug tool v3.18
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
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public
; License along with this library; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

; --- Includes ---
	include	"debug95_version.i"

;---from exec.library --------------------------------------

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
GetDeviceProc	= -642
FreeDeviceProc	= -648

ModeNewfile	= 1006

LF		= 10

;struct DevProc
DVP_Port	= 0
DVP_Lock	= 4
DVP_Flags	= 8
DVP_DevNode	= 12
DVP_Sizeof	= 16

ACTION_END	= 1007

;--- global vars -------------------------------------------

ArgV		= -4
ArgC		= -8
ExecBase	= -12
DosBase		= -16
DevProc		= -20
DeviceName	= -24
FileName	= -28
DebugSource	= -32
Result		= -36
StringBuffer	= -256
VarsSize	= -256

;*** here we go !! *****************************************

; a0 <- &command line
; d0 <- length thereof

Start:
	link.w	a4,#VarsSize
	movem.l	d1-d5/a0-a1/a6,-(sp)
	move.l	(_AbsExecBase).w,ExecBase(a4)
	move.l	a0,ArgV(a4)
	move.l	d0,ArgC(a4)
	clr.l	Result(a4)
	moveq.l	#36,d0
	lea	DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	beq.w	s_end

	move.l	ArgV(a4),a0
	move.l	ArgC(a4),d0
	lea	StringBuffer(a4),a1
	move.l	a1,DeviceName(a4)
	clr.l	FileName(a4)
s_ploop:
	subq.l	#1,d0
	bmi.s	s_pend

	move.b	(a0)+,d1
	cmp.b	#' ',d1
	beq.s	s_pbreak
	bcs.s	s_pend
s_pwrite:
	move.b	d1,(a1)+
	bra.s	s_ploop
s_pbreak:
	tst.l	FileName(a4)
	bne.s	s_pwrite

	clr.b	(a1)+
	move.l	a1,FileName(a4)
	bra.s	s_ploop
s_pend:
	clr.b	(a1)
	tst.l	FileName(a4)
	beq.w	s_noparams

	move.l	DeviceName(a4),d1
	moveq.l	#0,d2
	CALLDOS	GetDeviceProc
	move.l	d0,DevProc(a4)
	beq.w	s_nodev

	move.l	d0,a0
	move.l	DVP_Port(a0),d1
	move.l	#ACTION_END,d2
	moveq.l	#0,d3			;top secret!!!
	moveq.l	#0,d4
	moveq.l	#0,d5
	CALLDOS	DoPkt
	move.l	d0,DebugSource(a4)
	beq.s	s_noinfo

	btst	#0,d0
	bne.s	s_noinfo		;odd Adress???

	move.l	FileName(a4),d1
	move.l	#ModeNewfile,d2
	CALLDOS	Open
	move.l	d0,d4
	beq.s	s_nofile

	move.l	d4,d1
	move.l	DebugSource(a4),d2
	move.l	d2,a0
	move.l	(a0),d3
	CALLDOS	Write
	move.l	d4,d1
	CALLDOS	Close
s_freedev:
	move.l	DevProc(a4),d1
	CALLDOS	FreeDeviceProc
s_closelib:
	move.l	DosBase(a4),a1
	CALLEXEC CloseLibrary
s_end:
	move.l	Result(a4),d0
	movem.l	(sp)+,d1-d5/a0-a1/a6
	unlk	a4
	rts

s_nofile:
	lea	NoFileStr(pc),a0
	bsr.s	ReportError
	bra.s	s_freedev

s_noinfo:
	lea	NoInfoStr(pc),a0
	bsr.s	ReportError
	bra.s	s_freedev

s_nodev:
	lea	NoDevStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closelib

s_noparams:
	lea	HelpStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closelib

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

;--- Texts -------------------------------------------------

		dc.b	'$VER: '
		VER_STRING
		dc.b	LF,0
DosName:	dc.b	'dos.library',0
HelpStr:	dc.b	'usage: fat95debug <device> <logfile>',LF,0
NoDevStr:	dc.b	'device not found.',LF,0
NoFileStr:	dc.b	'could not open log file.',LF,0
NoInfoStr:	dc.b	'debug info not available.',LF,0
		even

;*** that's it!!!! *****************************************
	end
