; DiskDump raw block transfer tool
; Copyright (C) 2009  Torsten Jager <t.jager@gmx.de>
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
	include	"dd_version.i"

;--- from exec.library -------------------------------------

CALLEXEC macro
	move.l	ExecBase(a4),a6
	jsr	\1(a6)
	endm

CALLSAME macro
	jsr	\1(a6)			;same library as CALLxxx
	endm

_AbsExecBase	= 4

AllocMem	= -198
FreeMem		= -210
FindName	= -276
FindTask	= -294
SetSignal	= -306
Wait		= -318
AllocSignal	= -330
FreeSignal	= -336
GetMsg		= -372
WaitPort	= -384
CloseLibrary	= -414
OpenDevice	= -444
CloseDevice	= -450
DoIO		= -456
OpenLibrary	= -552

;struct Node
LN_Succ		=  0
LN_Pred		=  4
LN_Type		=  8
LN_Pri		=  9
LN_Name		= 10
LN_Sizeof	= 14

;LN_Type
NT_PROCESS	= 13

;struct MsgPort
MP_Flags	= 14
MP_SigBit	= 15
MP_SigTask	= 16
MP_MsgList	= 20
MP_Sizeof	= 34

;struct Message
MN_ReplyPort	= 14
MN_Length	= 18

;memory type
MEMF_PUBLIC	= 1
MEMF_CLEAR	= $10000

;struct ExecBase
EXB_MemList	= 322
EXB_ResourceList = 336
EXB_DeviceList	= 350
EXB_LibList	= 378
EXB_PortList	= 392

;--- from dos.library --------------------------------------

CALLDOS	macro
	move.l	DosBase(a4),a6
	jsr	\1(a6)
	endm

Open		= -30
Close		= -36
Input		= -54
Output		= -60
Read		= -42
Write		= -48
IoErr		= -132
ExamineFH	= -390

MODE_READWRITE	= 1004
MODE_OLDFILE	= 1005
MODE_NEWFILE	= 1006

;struct FileInfoBlock
FIB_DiskKey	 =   0
FIB_DirEntryType =   4
FIB_Name	 =   8
FIB_Protection	 = 116
FIB_EntryType	 = 120
FIB_Size	 = 124
FIB_NumBlocks	 = 128
FIB_Date	 = 132
FIB_Comment	 = 144
FIB_Private	 = 220			;internal use only!!
FIB_OwnerUID	 = 224
FIB_OwnerGID	 = 226
FIB_Sizeof	 = 260

LF		 = 10
CR		 = 13

SIGBREAKB_CTRL_C = 12

;--- from trackdisk/mfm.device -----------------------------

;struct TrackdiskRequest
IO_Device	= 20
IO_Unit		= 24
IO_Command	= 28
IO_Flags	= 30
IO_Error	= 31
IO_Actual	= 32
IO_Length	= 36
IO_Data		= 40
IO_Offset	= 44
IO_SimpleSizeof	= 48

IO_ChangeNum	= 48
IO_SecLabel	= 52

IO_SCSI		= 56
IO_SCommand	= 88
IO_Sizeof	= 104

;IO_Flags
IOF_QUICK	= 1

;struct DriveGeometry
DG_SectorSize	= 0
DG_TotalSectors	= 4
DG_Cylinders	= 8
DG_CylSectors	= 12
DG_Heads	= 16
DG_TrackSectors	= 20
DG_BufMemType	= 24
DG_DeviceType	= 28
DG_Flags	= 29
DG_Reserved	= 30
DG_Sizeof	= 32

;standard commands
CMD_READ	= 2
CMD_WRITE	= 3
CMD_UPDATE	= 4
CMD_CLEAR	= 5
TD_MOTOR	= 9
TD_CHANGENUM	= 13
TD_CHANGESTATE	= 14
TD_PROTSTATUS	= 15
TD_GETDRIVETYPE	= 18
TD_ADDCHANGEINT	= 20
TD_REMCHANGEINT	= 21
TD_GETGEOMETRY	= 22
ETD_READ	= $8002
ETD_WRITE	= $8003
ETD_UPDATE	= $8004

;NSD and TD64 commands
NSCMD_DEVICEQUERY  = $4000
NSCMD_TD_READ64	   = $c000
NSCMD_TD_WRITE64   = $c001

;struct NSDeviceQueryResult
QR_DevQueryFormat  = 0
QR_SizeAvailable   = 4
QR_DeviceType	   = 8
QR_DeviceSubType   = 10
QR_SupportedCmds   = 12
QR_Sizeof	   = 16

;QR_DeviceType
NSDEVTYPE_TRACKDISK = 5

;error codes
IOERR_OPENFAIL	   = -1
IOERR_ABORTED	   = -2
IOERR_NOCMD	   = -3
IOERR_BADLENGTH	   = -4
TDERR_NOTSPECIFIED = 20
TDERR_NOSECHDR	   = 21
TDERR_WRITEPROT	   = 28
TDERR_DISKCHANGED  = 29
TDERR_NOMEM	   = 31
TDERR_BADUNITNUM   = 32
TDERR_DRIVEINUSE   = 34

;--- from scsi.device --------------------------------------

;struct SCSICmd
SCSI_Data	 = 0
SCSI_Length	 = 4
SCSI_Actual	 = 8
SCSI_Command	 = 12
SCSI_CmdLength	 = 16
SCSI_CmdActual	 = 18
SCSI_Flags	 = 20
SCSI_Status	 = 21
SCSI_SenseData	 = 22
SCSI_SenseLength = 26
SCSI_SenseActual = 28
SCSI_Sizeof	 = 30

;SCSI_Flags
SCSIF_WRITE	= 0
SCSIF_READ	= 1
SCSIF_AUTOSENSE	= 2

;command
HD_SCSICMD	= 28

;SCSI commands
READCAPACITY	= $25
READ10		= $28
WRITE10		= $2a
MODESENSE10	= $5a

;--- from timer.device -------------------------------------

;Function
GetSysTime	= -66

;struct TimeRequest
TR_Seconds	= 32
TR_Micros	= 36
TR_Sizeof	= 40

;commands
TR_ADDREQUEST	= 9
TR_GETSYSTIME	= 10

;units
UNIT_VBLANK	= 1

;--- private data structures --------------------------------

;struct DevVec
DV_Name		= 0
DV_Unit		= 4
DV_ReplyPort	= 8
DV_IORequest	= 12
DV_File		= 16
DV_BufMemType	= 20
DV_BlockSize	= 24
DV_NumBlocks	= 28
DV_Sizeof	= 32

;--- global vars -------------------------------------------

ArgC		= -4
ArgV		= -8
Result		= -12
ExecBase	= -16
DosBase		= -20
SourceVec	= -52
DestVec		= -84
NumBlocks	= -88
StartBlock	= -92
BlockBuffer	= -96
BBufSize	= -100
DriveGeometry	= -132
FileSize	= -136
BlockShift	= -138
SCSIFlag	= -140
FillByte	= -141
FillFlag	= -142
unused1		= -144
DoneBlocks	= -148
BlockSize	= -152
BufBlocks	= -156
CustomSize	= -160
ConsoleI	= -164
ConsoleO	= -168
TimerDevice	= -172
RTime		= -180
WTime		= -188
StringBuf	= -512
Vars_Sizeof	= -512

;--- +++ TEST +++ TEST +++ ---------------------------------

;	lea	testargs(pc),a0
;	moveq.l	#tae-testargs,d0
;	bra.s	Start

;testargs:
;	dc.b	'scsi.device 0 ram:0 0 2000', LF
;tae:
;	even

;--- here we go!! ------------------------------------------

Start:
	link.w	a4,#Vars_Sizeof
	movem.l	d1-d7/a0-a6,-(sp)
	move.l	a0,ArgV(a4)
	lea	StringBuf(a4),a1
	bsr.w	GetDosParams
	move.l	d0,ArgC(a4)

;- - get resources  - - - - - - - - - - - - - - - - - - - -

	moveq.l	#10,d0
	move.l	d0,Result(a4)
	move.l	(_AbsExecBase).w,ExecBase(a4)
	moveq.l	#(DosBase-WTime)/4,d0
	lea	WTime(a4),a1
s_nullvars:
	clr.l	(a1)+
	subq.w	#1,d0
	bgt.s	s_nullvars

	moveq.l	#36,d0
	lea	s_DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	beq.w	s_end

	CALLDOS	Input
	move.l	d0,ConsoleI(a4)
	CALLDOS	Output
	move.l	d0,ConsoleO(a4)

	move.l	ExecBase(a4),a0
	add.w	#EXB_DeviceList,a0
	lea	TimerName(pc),a1
	CALLEXEC FindName
	move.l	d0,TimerDevice(a4)

;- - evaluate parameters  - - - - - - - - - - - - - - - - -

	moveq.l	#2,d2
	move.l	ArgC(a4),d3
	lea	StringBuf(a4),a2
	lea	SourceVec(a4),a3
	clr.l	CustomSize(a4)
s_pvec:
	subq.l	#1,d3
	bmi.s	s_perror

	move.l	(a2)+,a0
	move.l	a0,DV_Name(a3)
	bsr.w	CheckDevName
	tst.w	d0
	beq.s	s_pfile

	subq.l	#1,d3
	bmi.s	s_perror

	move.l	(a2)+,a0
	bsr.w	Str2Num
	move.l	d0,DV_Unit(a3)
	moveq.l	#-1,d0
	bra.s	s_pnext
s_pfile:
	moveq.l	#0,d0
s_pnext:
	move.l	d0,DV_File(a3)
	lea	DestVec(a4),a3
	subq.w	#1,d2
	bgt.s	s_pvec

	moveq.l	#0,d0
	move.l	d0,StartBlock(a4)
	moveq.l	#-2,d0
	ror.l	#1,d0
	move.l	d0,NumBlocks(a4)
s_pnums:
	subq.l	#1,d3
	bmi.s	s_pdone

	move.l	(a2)+,a0
	bsr.w	Str2Num
	move.l	d0,StartBlock(a4)
	subq.l	#1,d3
	bmi.s	s_pdone

	move.l	(a2)+,a0
	bsr.w	Str2Num
	move.l	d0,NumBlocks(a4)
	subq.l	#1,d3
	bmi.s	s_pdone

	move.l	(a2)+,a0
	bsr.w	Str2Num
	move.l	d0,CustomSize(a4)
	bra.s	s_pdone
s_perror:
	move.l	ConsoleO(a4),d4
	beq.w	s_closedos

	move.l	d4,d1
	lea	HelpText(pc),a0
	move.l	a0,d2
	move.l	#TextEnd-HelpText,d3
	CALLDOS Write
	bra.w	s_closedos
s_pdone:

;- - open devices - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#2,d4
	lea	SourceVec(a4),a3
s_open:
	tst.l	DV_File(a3)
	bmi.s	s_odevice

	cmp.w	#1,d4
	beq.s	s_onew

	move.l	#MODE_OLDFILE,d2
	move.l	DV_Name(a3),a0
	bsr.w	FillCheck
	subq.w	#1,d0
	bne.s	s_ofile

	move.l	DV_Name(a3),a0
	addq.l	#5,a0
	bsr.w	Str2Num
	move.b	d0,FillByte(a4)
	move.b	#1,FillFlag(a4)
	bra.w	s_onext
s_onew:
	move.l	#MODE_NEWFILE,d2
	move.l	DV_Name(a3),a0
	bsr.w	FillCheck
	cmp.w	#2,d0
	bcs.s	s_ofile

	move.b	d0,FillFlag(a4)
	bra.w	s_onext
s_ofile:
	move.l	DV_Name(a3),d1
	CALLDOS	Open
	move.l	d0,DV_File(a3)
	beq.w	s_onofile
	bra.w	s_onext
s_odevice:
	bsr.w	AllocMsgPort
	move.l	d0,DV_ReplyPort(a3)
	beq.w	s_oerror

	move.l	d0,a0
	moveq.l	#IO_Sizeof,d0
	bsr.w	AllocMsg
	move.l	d0,DV_IORequest(a3)
	beq.w	s_oerror

	move.l	DV_Name(a3),a0
	move.l	d0,a1
	move.l	DV_Unit(a3),d0
	moveq.l	#0,d1
	movem.l	d2-d7/a2-a6,-(sp)
	CALLEXEC OpenDevice
	movem.l	(sp)+,d2-d7/a2-a6
	tst.b	d0
	bne.w	s_onodevice

	move.l	DV_IORequest(a3),a1
	move.w	#TD_GETGEOMETRY,IO_Command(a1)
	moveq.l	#DG_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	DriveGeometry(a4),a0
	move.l	a0,IO_Data(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	s_oreadcapacity

	move.l	DriveGeometry+DG_BufMemType(a4),d0
	move.l	d0,DV_BufMemType(a3)
	move.l	DriveGeometry+DG_SectorSize(a4),d0
	move.l	d0,DV_BlockSize(a3)
	move.l	DriveGeometry+DG_TotalSectors(a4),d1
	move.l	d1,DV_NumBlocks(a3)
	bra.s	s_omodesense
s_oreadcapacity:
	move.l	DV_IORequest(a3),a1
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	IO_SCSI(a1),a0
	move.l	a0,IO_Data(a1)
	move.l	BlockBuffer(a4),(a0)+	;SCSI_Data = &target
	moveq.l	#8,d0
	move.l	d0,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	moveq.l	#IO_SCommand,d1
	add.l	a1,d1
	move.l	d1,(a0)+		;SCSI_Command
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.w	(a0)+			;SCSI_SenseLength
	clr.w	(a0)			;SCSI_SenseActual
	move.l	d1,a0
	move.b	#READCAPACITY,(a0)+	;command line
	clr.b	(a0)+
	clr.l	(a0)+
	clr.l	(a0)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	s_omodesense

	move.l	BlockBuffer(a4),a0
	move.l	(a0)+,d0
	addq.l	#1,d0
	move.l	d0,DV_NumBlocks(a3)
	move.l	(a0),DV_BlockSize(a3)
s_omodesense:
	move.l	DV_IORequest(a3),a1
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	IO_SCSI(a1),a0
	move.l	a0,IO_Data(a1)
	move.l	BlockBuffer(a4),(a0)+	;SCSI_Data = &target
	move.l	BBufSize(a4),d0
	move.l	d0,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	moveq.l	#IO_SCommand,d1
	add.l	a1,d1
	move.l	d1,(a0)+		;SCSI_Command
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.w	(a0)+			;SCSI_SenseLength
	clr.w	(a0)			;SCSI_SenseActual
	move.l	d1,a0
	move.b	#MODESENSE10,(a0)+	;command line
	clr.b	(a0)+
	move.b	#$3f,(a0)+		;all param pages
	clr.b	(a0)+
	clr.b	(a0)+
	clr.b	(a0)+
	clr.b	(a0)+
	ror.w	#8,d0
	move.b	d0,(a0)+
	ror.w	#8,d0
	move.b	d0,(a0)+
	clr.b	(a0)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	s_onext

	lea	MSName(pc),a0
	move.l	a0,d1
	move.l	#MODE_NEWFILE,d2
	CALLDOS	Open
	move.l	d0,d5
	ble.s	s_onext

	move.l	d5,d1
	move.l	BlockBuffer(a4),a0
	move.l	a0,d2
	moveq.l	#2,d3
	add.w	(a0),d3
	CALLDOS	Write
	move.l	d5,d1
	CALLDOS	Close
s_onext:
	lea	DestVec(a4),a3
	subq.w	#1,d4
	bgt.w	s_open
	bra.w	s_odone
s_onofile:
	lea	StringBuf(a4),a1
	move.l	a1,d2
	lea	NoFileStr1(pc),a0
	bsr.w	StrCopy
	move.l	DV_Name(a3),a0
	bsr.w	StrCopy
	lea	NoFileStr2(pc),a0
	bsr.w	StrCopy
	bra.s	s_oreport
s_onodevice:
	lea	StringBuf(a4),a1
	move.l	a1,d2
	lea	NoDevStr1(pc),a0
	bsr.w	StrCopy
	move.l	DV_Unit(a3),d0
	bsr.w	Num2Str
	lea	NoDevStr2(pc),a0
	bsr.w	StrCopy
	move.l	DV_Name(a3),a0
	bsr.w	StrCopy
	lea	NoDevStr3(pc),a0
	bsr.w	StrCopy
	move.l	DV_IORequest(a3),a0
	move.b	IO_Error(a0),d0
	ext.w	d0
	ext.l	d0
	bsr.w	SNum2Str
	lea	NoDevStr4(pc),a0
	bsr.w	StrCopy
s_oreport:
	move.l	a1,d3
	sub.l	d2,d3
	move.l	ConsoleO(a4),d1
	beq.s	s_oerror

	CALLDOS	Write
s_oerror:
	bra.w	s_closedev
s_odone:

;- - get buffers  - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#2,d0
	cmp.b	#2,FillFlag(a4)
	bcs.s	s_b1

	lsl.l	#3,d0
s_b1:
	swap	d0
	move.l	d0,BBufSize(a4)
	moveq.l	#MEMF_PUBLIC,d1
	or.l	SourceVec+DV_BufMemType(a4),d1
	or.l	DestVec+DV_BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,BlockBuffer(a4)
	beq.w	s_closedev
	
;- - determine transfer window  - - - - - - - - - - - - - -

s_window:
	move.l	SourceVec+DV_BlockSize(a4),d2
	move.l	SourceVec+DV_NumBlocks(a4),d1
	bne.s	s_w1

	move.l	DestVec+DV_BlockSize(a4),d2
	move.l	DestVec+DV_NumBlocks(a4),d1
	beq.s	s_w3
s_w1:
	move.l	StartBlock(a4),d0
	cmp.l	d1,d0
	bcs.s	s_w2

	move.l	d1,d0
	subq.l	#1,d0
	move.l	d0,StartBlock(a4)
s_w2:
	add.l	NumBlocks(a4),d0
	sub.l	d1,d0
	bcs.s	s_w3

	sub.l	d0,NumBlocks(a4)
s_w3:
	move.l	d2,d0
	bsr.w	Log2
	tst.l	d0			;when Block size unknown..
	bne.s	s_w4

	moveq.l	#9,d0
	moveq.l	#0,d1
	bset	d0,d1
	bra.s	s_w5			;..assume 512
s_w4:
	moveq.l	#0,d1
	bset	d0,d1
	cmp.l	d1,d2			;when not a power of 2..
	beq.s	s_w5

	move.l	d2,d1
	move.w	#-1,SCSIFlag(a4)	;..always use SCSI mode
s_w5:
	move.l	d1,BlockSize(a4)
	move.w	d0,BlockShift(a4)
	move.l	BBufSize(a4),d0
	bsr.w	UDivMod32
	move.l	d0,BufBlocks(a4)
	move.l	CustomSize(a4),d0
	beq.s	s_w6			;auto Block size

	cmp.l	BBufSize(a4),d0
	bcc.s	s_w6			;>= 32kbyte??

	cmp.l	BlockSize(a4),d0
	beq.s	s_w6			;no change

	lea	StringBuf(a4),a1
	move.l	a1,d2
	lea	SizeWarnStr1(pc),a0
	bsr.w	StrCopy
	move.l	BlockSize(a4),d0
	bsr.w	Num2Str
	lea	SizeWarnStr2(pc),a0
	bsr.w	StrCopy
	move.l	a1,d3
	sub.l	d2,d3
	move.l	ConsoleO(a4),d1
	beq.s	s_w6

	CALLDOS	Write
	moveq.l	#10,d3
	move.l	ConsoleI(a4),d1
	beq.s	s_w6

	CALLDOS	Read
	tst.l	d0
	ble.s	s_w6

	moveq.l	#$ffffffdf,d1
	and.b	StringBuf(a4),d1
	cmp.b	#'Y',d1
	bne.w	s_closedev

	move.w	#-1,SCSIFlag(a4)
	move.l	CustomSize(a4),d2	;user Block size
	bra.w	s_w3
s_w6:
	move.l	SourceVec+DV_File(a4),d1
	ble.s	s_w7

	move.l	BlockBuffer(a4),d2
	CALLDOS	ExamineFH
	tst.l	d0
	beq.s	s_w7

	move.l	BlockBuffer(a4),a0
	move.l	FIB_Size(a0),d0
	move.l	d0,FileSize(a4)
	move.l	BlockSize(a4),d1
	bsr.w	UDivMod32
	move.l	NumBlocks(a4),d1
	cmp.l	d1,d0
	bcc.s	s_w7

	move.l	d0,NumBlocks(a4)	;limit to file size
s_w7:
	cmp.b	#2,FillFlag(a4)
	bcs.s	s_w8			;when benchmarking..

	move.l	BBufSize(a4),d0
	move.l	BlockSize(a4),d1
	bsr.w	UDivMod32
	move.l	NumBlocks(a4),d1
	cmp.l	d1,d0
	bcc.s	s_w8

	move.l	d0,NumBlocks(a4)	;..limit to buffer length
s_w8:
	moveq.l	#32,d0
	sub.w	BlockShift(a4),d0
	move.l	StartBlock(a4),d1
	add.l	NumBlocks(a4),d1
	subq.l	#1,d1			;# last Block..
	lsr.l	d0,d1
	beq.s	s_wdone			;..still within first 4 Gbyte

	moveq.l	#-1,d0
	move.w	d0,SCSIFlag(a4)
s_wdone:

;- - prepare fill mode  - - - - - - - - - - - - - - - - - -

	cmp.b	#1,FillFlag(a4)
	bne.s	s_f2

	move.l	BlockBuffer(a4),a1
	moveq.l	#4,d1
s_f1:
	lsl.l	#8,d0
	move.b	FillByte(a4),d0
	subq.w	#1,d1
	bgt.s	s_f1

	move.l	BBufSize(a4),d1
s_fill:
	move.l	d0,(a1)+
	subq.l	#4,d1
	bgt.s	s_fill
	bra.s	s_fdone
s_f2:
	cmp.b	#3,FillFlag(a4)
	bne.s	s_fdone

	lea	SourceVec(a4),a0
	lea	DestVec(a4),a1
	moveq.l	#DV_Sizeof,d0
s_f3:
	move.l	(a0)+,(a1)+
	subq.l	#4,d0
	bgt.s	s_f3
s_fdone:

;- - transfer data  - - - - - - - - - - - - - - - - - - - -

	move.l	StartBlock(a4),d4	;Block #
	move.l	NumBlocks(a4),d6	;total Blocks
	move.w	BlockShift(a4),d7
s_tswath:
	move.l	#1<<SIGBREAKB_CTRL_C,d2
	moveq.l	#0,d0
	move.l	d2,d1
	CALLEXEC SetSignal
	and.l	d2,d0
	bne.w	s_tbreak		;user stop

	lea	StringBuf(a4),a1
	move.l	a1,d2
	move.l	d4,d0
	bsr.w	Num2Str
	move.b	#CR,(a1)+
	clr.b	(a1)
	move.l	a1,d3
	sub.l	d2,d3
	move.l	ConsoleO(a4),d1
	beq.s	s_t0

	CALLDOS	Write			;report progress
s_t0:
	lea	StringBuf(a4),a0
	move.l	TimerDevice(a4),a6
	jsr	GetSysTime(a6)
	lea	StringBuf(a4),a0
	lea	RTime(a4),a1
	bsr.w	TimeSub
	lea	SourceVec(a4),a3
	move.l	d6,d5
	move.l	BufBlocks(a4),d0
	cmp.l	d5,d0
	bcc.s	s_t1

	move.l	d0,d5			;Blocks/portion
s_t1:
	move.l	d5,d0
	move.l	BlockSize(a4),d1
	bsr.w	UMul32
	move.l	d0,d3			;Bytes/portion
	move.l	BlockBuffer(a4),d2	;&dest = &source
	move.l	SourceVec+DV_File(a4),d1
	bmi.s	s_t2
	beq.w	s_t3

	CALLDOS	Read
	cmp.l	d0,d3
	beq.w	s_t3

	CALLDOS	IoErr
	bra.w	s_treaderr
s_t2:
	move.l	SourceVec+DV_IORequest(a4),a1
	tst.w	SCSIFlag(a4)
	bmi.s	s_ts2

	move.w	#CMD_READ,IO_Command(a1)
	move.l	d2,IO_Data(a1)
	move.l	d3,IO_Length(a1)
	move.l	d4,d0
	lsl.l	d7,d0
	move.l	d0,IO_Offset(a1)
	clr.l	IO_Actual(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	beq.s	s_t3
	bra.w	s_treaderr
s_ts2:
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	IO_SCSI(a1),a0
	move.l	a0,IO_Data(a1)
	move.l	d2,(a0)+		;SCSI_Data = &dest
	move.l	d3,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	moveq.l	#IO_SCommand,d1
	add.l	a1,d1
	move.l	d1,(a0)+		;SCSI_Command
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.w	(a0)+			;SCSI_SenseLength
	clr.w	(a0)			;SCSI_SenseActual
	move.l	d1,a0
	move.b	#READ10,(a0)+		;command line
	clr.b	(a0)+
	move.l	d4,(a0)+
	clr.b	(a0)+
	rol.w	#8,d5
	move.b	d5,(a0)+
	rol.w	#8,d5
	move.b	d5,(a0)+
	clr.b	(a0)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.w	s_treaderr
s_t3:
	lea	StringBuf(a4),a0
	move.l	TimerDevice(a4),a6
	jsr	GetSysTime(a6)
	lea	StringBuf(a4),a0
	lea	RTime(a4),a1
	bsr.w	TimeAdd
	lea	StringBuf(a4),a0
	lea	WTime(a4),a1
	bsr.w	TimeSub
	lea	DestVec(a4),a3
	move.l	DestVec+DV_File(a4),d1
	bmi.s	s_t4
	beq.w	s_t5

	CALLDOS	Write
	cmp.l	d0,d3
	beq.w	s_t5

	CALLDOS	IoErr
	bra.w	s_twriteerr
s_t4:
	move.l	DestVec+DV_IORequest(a4),a1
	tst.w	SCSIFlag(a4)
	bmi.s	s_ts4

	move.w	#CMD_WRITE,IO_Command(a1)
	move.l	d2,IO_Data(a1)
	move.l	d3,IO_Length(a1)
	move.l	d4,d0
	lsl.l	d7,d0
	move.l	d0,IO_Offset(a1)
	clr.l	IO_Actual(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	beq.s	s_t5
	bra.w	s_twriteerr
s_ts4:
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	IO_SCSI(a1),a0
	move.l	a0,IO_Data(a1)
	move.l	d2,(a0)+		;SCSI_Data = &source
	move.l	d3,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	moveq.l	#IO_SCommand,d1
	add.l	a1,d1
	move.l	d1,(a0)+		;SCSI_Command
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_WRITE,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.w	(a0)+			;SCSI_SenseLength
	clr.w	(a0)			;SCSI_SenseActual
	move.l	d1,a0
	move.b	#WRITE10,(a0)+		;command line
	clr.b	(a0)+
	move.l	d4,(a0)+
	clr.b	(a0)+
	rol.w	#8,d5
	move.b	d5,(a0)+
	rol.w	#8,d5
	move.b	d5,(a0)+
	clr.b	(a0)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	s_twriteerr
s_t5:
	lea	StringBuf(a4),a0
	move.l	TimerDevice(a4),a6
	jsr	GetSysTime(a6)
	lea	StringBuf(a4),a0
	lea	WTime(a4),a1
	bsr.w	TimeAdd
	add.l	d5,DoneBlocks(a4)
	add.l	d5,d4
	sub.l	d5,d6
	bgt.w	s_tswath

	clr.l	Result(a4)		;success
	bra.s	s_closedev
s_tbreak:
	move.l	ConsoleO(a4),d4
	beq.s	s_closedev

	move.l	d4,d1
	lea	BreakText(pc),a0
	move.l	a0,d2
	moveq.l	#BTEnd-BreakText,d3
	CALLDOS	Write
	bra.s	s_closedev
s_treaderr:
	lea	ReadErrStr1(pc),a0
	bra.s	s_tereport
s_twriteerr:
	lea	WriteErrStr(pc),a0
s_tereport:
	lea	StringBuf(a4),a1
	move.l	a1,d2
	move.l	a0,d1
	move.l	DV_Name(a3),a0
	bsr.w	StrCopy
	move.l	d1,a0
	bsr.w	StrCopy
	bsr.w	SNum2Str
	lea	ReadErrStr2(pc),a0
	bsr.w	StrCopy
	move.l	a1,d3
	sub.l	d2,d3
	move.l	ConsoleO(a4),d1
	beq.s	s_closedev

	CALLDOS	Write

;- - close devices  - - - - - - - - - - - - - - - - - - - -

s_closedev:
	moveq.l	#2,d4
	cmp.b	#3,FillFlag(a4)
	beq.s	s_cnext

	lea	SourceVec(a4),a3
s_cvec:
	move.l	DV_File(a3),d1
	ble.s	s_c1

	CALLDOS	Close
	clr.l	DV_File(a3)
s_c1:
	move.l	DV_IORequest(a3),d0
	beq.s	s_c4

	move.l	d0,a1
	tst.l	IO_Device(a1)
	ble.s	s_c3

	cmp.w	#1,d4
	bne.s	s_c2

	move.w	#CMD_UPDATE,IO_Command(a1)
	bsr.w	SafeDoIO		;update dest disk
	move.l	DV_IORequest(a3),a1
s_c2:
	move.w	#TD_MOTOR,IO_Command(a1)
	clr.l	IO_Length(a1)
	bsr.w	SafeDoIO		;Motor off
	move.l	DV_IORequest(a3),a1
	CALLEXEC CloseDevice
	move.l	DV_IORequest(a3),a1
s_c3:
	bsr.w	FreeMsg
	clr.l	DV_IORequest(a3)
s_c4:
	move.l	DV_ReplyPort(a3),d0
	beq.s	s_cnext

	move.l	d0,a1
	bsr.w	FreeMsgPort
s_cnext:
	lea	DestVec(a4),a3
	subq.w	#1,d4
	bgt.s	s_cvec

;- - free buffer  - - - - - - - - - - - - - - - - - - - - -

s_freebuf:
	move.l	BBufSize(a4),d0
	move.l	BlockBuffer(a4),a1
	CALLEXEC FreeMem

;- - report result  - - - - - - - - - - - - - - - - - - - -

s_report:
	lea	StringBuf(a4),a1
	move.l	DoneBlocks(a4),d0
	bsr.w	Num2Str
	lea	Done1Text(pc),a0
	bsr.w	StrCopy
	move.l	BlockSize(a4),d0
	bsr.w	Num2Str
	lea	Done2Text(pc),a0
	bsr.w	StrCopy
	move.l	DoneBlocks(a4),d0
	move.l	BlockSize(a4),d1
	bsr.w	UMul32
	move.l	d0,d4
	lea	RTime(a4),a0
	bsr.w	TimeMsecs
	move.l	d0,d1
	beq.s	s_rep1

	move.l	d4,d0
	bsr.w	UDivMod32
	lea	ReadSpeedStr(pc),a0
	bsr.w	StrCopy
	bsr.w	Num2Str
	lea	KbpsStr(pc),a0
	bsr.w	StrCopy
s_rep1:
	lea	WTime(a4),a0
	bsr.w	TimeMsecs
	move.l	d0,d1
	beq.s	s_rep2

	move.l	d4,d0
	bsr.w	UDivMod32
	lea	WriteSpeedStr(pc),a0
	bsr.w	StrCopy
	bsr.w	Num2Str
	lea	KbpsStr(pc),a0
	bsr.w	StrCopy
s_rep2:
	move.l	a1,d3
	move.l	ConsoleO(a4),d4
	beq.s	s_closedos

	move.l	d4,d1
	lea	StringBuf(a4),a1
	move.l	a1,d2
	sub.l	d2,d3
	CALLDOS	Write

;- - free resources - - - - - - - - - - - - - - - - - - - -

s_closedos:
	move.l	DosBase(a4),a1
	CALLEXEC CloseLibrary
s_end:
	move.l	Result(a4),d0
	movem.l	(sp)+,d1-d7/a0-a6
	unlk	a4
	rts

s_DosName:
	dc.b	'dos.library',0
	even

;*** string ops ********************************************
;--- check for ".device" -----------------------------------
; a0 <- &Name
; d0 -> -1 (y), 0 (n)

CheckDevName:
	move.l	a2,-(sp)
cdn_search:
	move.b	(a0)+,d0
	beq.s	cdn_no

	cmp.b	#'.',d0
	bne.s	cdn_search

	move.l	a0,a1
	lea	cdn_test(pc),a2
cdn_check:
	moveq.l	#$ffffffdf,d0
	and.b	(a1)+,d0
	move.b	(a2)+,d1
	cmp.b	d0,d1
	bne.s	cdn_search

	tst.b	d0
	bne.s	cdn_check

	moveq.l	#-1,d0
cdn_end:
	move.l	(sp)+,a2
	rts

cdn_no:
	moveq.l	#0,d0
	bra.s	cdn_end

cdn_test:
	dc.b	'DEVICE',0
	even

;--- check for "fill:" etc. --------------------------------
; a0 <-> &String
; d0  -> 0 (normal), 1 (FILL:), 2 (RSPEED:), 3 (RWSPEED)

FillCheck:
	movem.l	d2/a2,-(sp)
	move.l	a0,a2
	moveq.l	#3,d0
fch_test:
	move.l	a2,a0
	lea	fch_name(pc),a1
	move.l	d0,d1
	subq.l	#1,d1
	mulu.w	#10,d1
	add.l	d1,a1
fch_loop:
	move.b	(a1)+,d1
	beq.s	fch_end

	moveq.l	#$ffffffdf,d2
	and.b	(a0)+,d2
	cmp.b	d1,d2
	beq.s	fch_loop

	subq.l	#1,d0
	bgt.s	fch_test
fch_end:
	movem.l	(sp)+,d2/a2
	rts

fch_name:
	dc.b	'FILL',':'&$df,0,0,0,0,0
	dc.b	'RSPEED',':'&$df,0,0,0
	dc.b	'RWSPEED',':'&$df,0,0
	even

;--- copy string -------------------------------------------
; a0 <-  &src
; a1 <-> &dest

StrCopy:
	move.b	(a0)+,(a1)+
	bne.s	StrCopy

	subq.l	#1,a1			;to be resumed
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
; d0 <-  num
; a1 <-> &String

SNum2Str:
	tst.l	d0
	bpl.s	Num2Str

	move.b	#'-',(a1)+
	neg.l	d0
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
	sub.l	a0,d1		;# of digits
	asr.w	#1,d1
	beq.s	n2s_end		;just 1
n2s_loop2:
	move.b	-(a1),d0
	move.b	(a0),(a1)
	move.b	d0,(a0)+
	subq.w	#1,d1
	bne.s	n2s_loop2	;reverse order
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

;--- dual logarithm ----------------------------------------
; d0 -> ld(d0)

Log2:
	move.l	d1,-(sp)
	moveq.l	#-1,d1
lg2_loop:
	addq.l	#1,d1
	lsr.l	#1,d0
	bne.s	lg2_loop

	move.l	d1,d0
	move.l	(sp)+,d1
	rts

;--- time math ---------------------------------------------
; *a1 += *a0

TimeAdd:
	move.l	(a0),d0
	add.l	d0,(a1)
	move.l	4(a0),d0
	add.l	4(a1),d0
	move.l	#1000000,d1
	cmp.l	d1,d0
	bcs.s	ta_1

	sub.l	d1,d0
	addq.l	#1,(a1)
ta_1:
	move.l	d0,4(a1)
	rts

; *a1 -= *a0

TimeSub:
	move.l	(a0),d0
	sub.l	d0,(a1)
	move.l	4(a1),d0
	sub.l	4(a0),d0
	bcc.s	ts_1

	add.l	#1000000,d0
	subq.l	#1,(a1)
ts_1:
	move.l	d0,4(a1)
	rts

; a0 <- &time
; d0 -> Milliseconds

TimeMsecs:
	move.l	d2,-(sp)
	move.l	(a0),d0
	move.l	#1000,d1
	bsr.w	UMul32
	move.l	d0,d2
	move.l	4(a0),d0
	move.l	#1000,d1
	bsr.w	UDivMod32
	add.l	d2,d0
	move.l	(sp)+,d2
	rts

;--- get parameters ----------------------------------------
; a0 <- &command line
; a1 <- &target buffer
; d0 -> # Parameters

GetDosParams:
	movem.l	a1-a2,-(sp)
	lea	40(a1),a2		;&strings
gdp_par:
	move.l	a2,(a1)+		;Vectors..
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

;*** exec supplements **************************************
;--- use device --------------------------------------------

SafeDoIO:
	movem.l	d2-d7/a2-a6,-(sp)
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a6
	rts

;--- make empty list ---------------------------------------
; a0 <- &List

InitList:
	move.l	a0,(a0)
	addq.l	#4,(a0)
	clr.l	4(a0)
	move.l	a0,8(a0)
	rts

;--- new MsgPort -------------------------------------------
; -> struct MsgPort *port or 0

AllocMsgPort:
	movem.l	d2-d3/a6,-(sp)
	moveq.l	#0,d2
	moveq.l	#-1,d0
	CALLEXEC AllocSignal
	move.l	d0,d3
	bmi.s	amp_end

	moveq.l	#MP_Sizeof,d0
	move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
	CALLEXEC AllocMem
	move.l	d0,d2
	beq.s	amp_frees

	sub.l	a1,a1
	CALLEXEC FindTask
	move.l	d2,a0
	move.l	d0,MP_SigTask(a0)
	move.b	d3,MP_SigBit(a0)
	add.w	#MP_MsgList,a0
	bsr.s	InitList
amp_end:
	move.l	d2,d0
	movem.l	(sp)+,d2-d3/a6
	rts

amp_frees:
	move.l	d3,d0
	CALLEXEC FreeSignal
	bra.s	amp_end

;--- free MsgPort ------------------------------------------
; a1 <- struct MsgPort *mp;

FreeMsgPort:
	move.l	a2,-(sp)
	move.l	a1,d0
	beq.s	fmp_end

	move.l	a1,a2
	moveq.l	#0,d0
	move.b	MP_SigBit(a2),d0
	CALLEXEC FreeSignal
	moveq.l	#MP_Sizeof,d0
	move.l	a2,a1
	CALLEXEC FreeMem
fmp_end:
	move.l	(sp)+,a2
	rts

;--- new Message -------------------------------------------
; d0 <- ULONG size;
; a0 <- struct MsgPort *ReplyPort;
; -> struct Message *msg or 0

AllocMsg:
	movem.l	d2-d3,-(sp)
	move.l	d0,d2
	move.l	a0,d3
	beq.s	amsg_error

	move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
	CALLEXEC AllocMem
	tst.l	d0
	beq.s	amsg_end

	move.l	d0,a0
	move.l	d3,MN_ReplyPort(a0)
	move.w	d2,MN_Length(a0)
amsg_end:
	movem.l	(sp)+,d2-d3
	rts

amsg_error:
	moveq.l	#0,d0
	bra.s	amsg_end

;--- free Message ------------------------------------------
; a1 <- struct Message *msg;

FreeMsg:
	move.l	a1,d0
	beq.s	fmsg_end

	moveq.l	#0,d0
	move.w	MN_Length(a1),d0
	CALLEXEC FreeMem
fmsg_end:
	rts

;--- Texts -------------------------------------------------

	VER_STRING
TimerName:
	dc.b	'timer.device',0
SizeWarnStr1:
	dc.b	'WARNING: device reports a different block size (',0
SizeWarnStr2:
	dc.b	')',LF
	dc.b	'Continue anyway? (y/n): ',0
BreakText:
	dc.b	'** Break **', LF
BTEnd:
	dc.b	0
MSName:
	dc.b	'ram:ModeSenseData',0
Done1Text:
	dc.b	' blocks of ', 0
Done2Text:
	dc.b	' bytes each transferred.', LF, 0
NoFileStr1:
	dc.b	'could not open file "',0
NoFileStr2:
	dc.b	'".',LF,0
NoDevStr1:
	dc.b	'opening unit ',0
NoDevStr2:
	dc.b	' of ',0
NoDevStr3:
	dc.b	' failed (',0
NoDevStr4:
	dc.b	').',LF,0
ReadErrStr1:
	dc.b	' read error (',0
ReadErrStr2:
	dc.b	').',LF,0
WriteErrStr:
	dc.b	' write error (',0
ReadSpeedStr:
	dc.b	'Read speed:  ',0
WriteSpeedStr:
	dc.b	'Write speed: ',0
KbpsStr:
	dc.b	' kbyte/sec',LF,0
HelpText:
 dc.b 'usage: dd <source> <destination> [<start> [<length> [<block size>]]]',LF
 dc.b LF
 dc.b '  <source>      - Where to read blocks from. Either',LF
 dc.b '                  <name>.device <unit number>, or <filename>.',LF
 dc.b '                  FILL: acts as an infinite file of all zeroes.',LF
 dc.b '                  FILL:255 supplies 0xff bytes etc.',LF
 dc.b LF
 dc.b '  <destination> - Where to write blocks to.',LF
 dc.b '                  RSPEED: performs a read speed test,',LF
 dc.b '                  RWSPEED: checks both read and write speed.',LF
 dc.b "                  FILL: doesn't make much sense here ;^)",LF
 dc.b LF
 dc.b '  <start>       - Number of first block to transfer.',LF
 dc.b '                  Defaults to 0 (start of disk).',LF
 dc.b LF
 dc.b '  <length>      - Count of blocks to transfer.',LF
 dc.b '                  Defaults to disk or file size.',LF
 dc.b LF
 dc.b '  <block size>  - Custom block size in bytes.',LF
 dc.b '                  Use with extreme care.',LF
 dc.b LF
TextEnd:
	dc.b	0
	even

;*** that's it!!!! *****************************************
	end
