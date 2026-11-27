; fat95 debug tool
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
	include	"debug95_version.i"

;---from exec.library --------------------------------------

CALLEXEC macro
	move.l	ExecBase(a4),a6
	jsr	\1(a6)
	endm

_AbsExecBase	= 4

OpenLibrary	= -552
CloseLibrary	= -414
FreeSignal	= -336
GetMsg		= -372
CreateMsgPort	= -666
DeleteMsgPort	= -672

MP_FLAGS	= 14
MP_SIGBIT	= 15
PA_IGNORE	= 2

;--- from dos.library --------------------------------------

CALLDOS	macro
	move.l	DosBase(a4),a6
	jsr	\1(a6)
	endm

Open		= -30
Close		= -36
Write		= -48
Output		= -60
Delay		= -198
AllocDosObject	= -228
FreeDosObject	= -234
SendPkt		= -246
GetDeviceProc	= -642
FreeDeviceProc	= -648
CheckSignal	= -792

DOS_STDPKT	= 3
SIGBREAKF_CTRL_C = $1000
dp_Type		= 8
dp_Res1		= 12
dp_Arg1		= 20

ModeNewfile	= 1006

LF		= 10

;struct DevProc
DVP_Port	= 0
DVP_Lock	= 4
DVP_Flags	= 8
DVP_DevNode	= 12
DVP_Sizeof	= 16

ACTION_END	= 1007

WAIT_TICKS	= 10			;between two looks for the answer
WAIT_LOOKS	= 50			;10 seconds in all

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
Packet		= -40
ReplyPort	= -44
Looks		= -48
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

	bsr	AskHandler
	move.l	d0,DebugSource(a4)
	beq.s	s_noinfo
	moveq.l	#-1,d1
	cmp.l	d1,d0
	beq.s	s_freedev		;no answer, reported

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
	bsr	ReportError
	bra.s	s_freedev

s_noinfo:
	lea	NoInfoStr(pc),a0
	bsr	ReportError
	bra.s	s_freedev

s_nodev:
	lea	NoDevStr(pc),a0
	bsr	ReportError
	bra.s	s_closelib

s_noparams:
	lea	HelpStr(pc),a0
	bsr	ReportError
	bra.s	s_closelib

;--- ask the handler for its debug info -------------------
; d0 -> &debug info, 0 when the handler has none, -1 when it did
;	not answer within WAIT_LOOKS or on Ctrl-C (reported)

AskHandler:
	CALLEXEC CreateMsgPort
	move.l	d0,ReplyPort(a4)
	beq.w	ah_nomem
	moveq.l	#DOS_STDPKT,d1
	moveq.l	#0,d2
	CALLDOS	AllocDosObject
	move.l	d0,Packet(a4)
	beq.w	ah_noport

	move.l	d0,a0
	move.l	#ACTION_END,dp_Type(a0)
	clr.l	dp_Arg1(a0)		;top secret!!!
	move.l	d0,d1
	move.l	DevProc(a4),a0
	move.l	DVP_Port(a0),d2
	move.l	ReplyPort(a4),d3
	CALLDOS	SendPkt
	move.l	#WAIT_LOOKS,Looks(a4)
ah_look:
	move.l	ReplyPort(a4),a0
	CALLEXEC GetMsg
	tst.l	d0
	bne.s	ah_answer
	move.l	#SIGBREAKF_CTRL_C,d1
	CALLDOS	CheckSignal
	lea	BreakStr(pc),a0
	tst.l	d0
	bne.s	ah_giveup
	lea	NoAnswerStr(pc),a0
	subq.l	#1,Looks(a4)
	beq.s	ah_giveup
	moveq.l	#WAIT_TICKS,d1
	CALLDOS	Delay
	bra.s	ah_look

ah_answer:
	move.l	Packet(a4),a0
	move.l	dp_Res1(a0),-(sp)
	moveq.l	#DOS_STDPKT,d1
	move.l	a0,d2
	CALLDOS	FreeDosObject
	move.l	ReplyPort(a4),a0
	CALLEXEC DeleteMsgPort
	move.l	(sp)+,d0
	rts

; The packet is still out: keep it and the port, which a late answer
; reaches without signalling, but give the signal bit back.
ah_giveup:
	bsr	ReportError
	move.l	ReplyPort(a4),a1
	move.b	#PA_IGNORE,MP_FLAGS(a1)
	moveq.l	#0,d0
	move.b	MP_SIGBIT(a1),d0
	CALLEXEC FreeSignal
	moveq.l	#-1,d0
	rts

ah_noport:
	move.l	ReplyPort(a4),a0
	CALLEXEC DeleteMsgPort
ah_nomem:
	moveq.l	#0,d0
	rts

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

		VER_STRING
DosName:	dc.b	'dos.library',0
HelpStr:	dc.b	'usage: fat95debug <device> <logfile>',LF,0
NoDevStr:	dc.b	'device not found.',LF,0
NoFileStr:	dc.b	'could not open log file.',LF,0
NoInfoStr:	dc.b	'debug info not available.',LF,0
NoAnswerStr:	dc.b	'no answer from the handler.',LF,0
BreakStr:	dc.b	'***Break',LF,0
		even

;*** that's it!!!! *****************************************
	end
