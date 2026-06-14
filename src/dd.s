; DiskDump raw block transfer tool
; Copyright (C) 2009  Torsten Jager <t.jager@gmx.de>
; Copyright (C) 2026  Jaroslav Pulchart <jaroslav.pulchart@gmail.com>
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
VFPrintf	= -354
ReadArgs	= -798
FreeArgs	= -858
StrToLong	= -816

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
CMD_RESET	= 1
CMD_READ	= 2
CMD_WRITE	= 3
CMD_UPDATE	= 4
CMD_CLEAR	= 5
CMD_STOP	= 6
CMD_START	= 7
CMD_FLUSH	= 8
TD_MOTOR	= 9
TD_SEEK		= 10
TD_FORMAT	= 11
TD_REMOVE	= 12
TD_CHANGENUM	= 13
TD_CHANGESTATE	= 14
TD_PROTSTATUS	= 15
TD_RAWREAD	= 16
TD_RAWWRITE	= 17
TD_GETDRIVETYPE	= 18
TD_GETNUMTRACKS	= 19
TD_ADDCHANGEINT	= 20
TD_REMCHANGEINT	= 21
TD_GETGEOMETRY	= 22
TD_EJECT	= 23
TD_SEEK64	= 26
TD_FORMAT64	= 27
ETD_READ	= $8002
ETD_WRITE	= $8003
ETD_UPDATE	= $8004

;NSD and TD64 commands
NSCMD_DEVICEQUERY  = $4000
NSCMD_TD_READ64	   = $c000
NSCMD_TD_WRITE64   = $c001
NSCMD_TD_SEEK64	   = $c002
NSCMD_TD_FORMAT64  = $c003
TD_READ64	   = 24
TD_WRITE64	   = 25

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
DV_ReadCmd	= 32		;word: CMD_READ / NSCMD_TD_READ64 / HD_SCSICMD
DV_WriteCmd	= 34		;word: CMD_WRITE / NSCMD_TD_WRITE64 / HD_SCSICMD
DV_CmdFlags	= 36		;byte of per-bit flags:
				;  bit 0 - NSD query succeeded
				;  bit 2 - NSCMD_TD_READ64 advertised
				;  bit 3 - classic TD_READ64 advertised
				;  bit 4 - HD_SCSICMD advertised
				;  bit 7 - force SCSI (non-power-of-2 block size)
				;Command selection reads bit 2 and bit 7.
				;Bits 3 and 4 are capability flags shown by INSPECT.
DV_pad		= 37
DV_Sizeof	= 40

;--- global vars -------------------------------------------

RDArgs		= -4			;struct RDArgs* for FreeArgs at exit
CmdLine		= -8			;raw CLI command-line pointer (a0 at Start)
Result		= -12
ExecBase	= -16
DosBase		= -20
SourceVec	= -60
DestVec		= -100
NumBlocks	= -104
StartBlock	= -108
BlockBuffer	= -112
BBufSize	= -116
DriveGeometry	= -148
FileSize	= -152
BlockShift	= -154
;SCSIFlag deleted, replaced by per-DV DV_CmdFlags bit 7
FillByte	= -157
FillFlag	= -158
ForceCmd	= -159			;byte: 0=AUTO 1=CMD 2=TD64 3=NSCMD 4=SCSI (CMD= override)
InspectFlag	= -160			;non-zero -> INSPECT mode (probe + print, no transfer)
DoneBlocks	= -164
BlockSize	= -168
BufBlocks	= -172
CustomSize	= -176
ConsoleI	= -180
ConsoleO	= -184
TimerDevice	= -188
RTime		= -196
WTime		= -204
QueryResult	= -220			;16-byte NSDeviceQueryResult buffer
StringBuf	= -732
ArgArray	= -780			;12 longs for ReadArgs (zeroed before call)
Vars_Sizeof	= -780

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
	move.l	a0,CmdLine(a4)		;raw CLI command line for `?` detection

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

	moveq.l	#0,d0			;open any version, we check lib_Version ourselves
	lea	s_DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	beq.w	s_end			;no dos.library at all, silent exit

	;dd 2.x uses ReadArgs/FreeArgs/VFPrintf, all V36+
	move.l	d0,a0
	cmp.w	#36,20(a0)		;lib_Version
	bcc.s	s_dos_ok

	;older Kickstart: print explanation and exit cleanly
	CALLDOS	Output
	move.l	d0,d1
	beq.s	s_dos_old_close
	lea	s_old_dos_msg(pc),a0
	move.l	a0,d2
	moveq.l	#s_old_dos_msg_end-s_old_dos_msg,d3
	CALLDOS	Write
s_dos_old_close:
	bra.w	s_closedos
s_dos_ok:

	CALLDOS	Input
	move.l	d0,ConsoleI(a4)
	CALLDOS	Output
	move.l	d0,ConsoleO(a4)

	move.l	ExecBase(a4),a0
	add.w	#EXB_DeviceList,a0
	lea	TimerName(pc),a1
	CALLEXEC FindName
	move.l	d0,TimerDevice(a4)

;- - early `?` check: bypass ReadArgs's interactive prompt - -

	move.l	CmdLine(a4),a0
	beq.s	s_help_done
s_help_skip:
	move.b	(a0)+,d0
	cmp.b	#' ',d0
	beq.s	s_help_skip
	cmp.b	#'?',d0
	bne.s	s_help_done
	move.b	(a0),d0			;byte after '?'
	cmp.b	#' ',d0
	bhi.s	s_help_done		;'?' part of longer token; ignore
	bsr.w	PrintHelp
	bra.w	s_closedos
s_help_done:

;- - evaluate parameters via ReadArgs - - - - - - - - - - -

	clr.l	RDArgs(a4)
	lea	ArgArray(a4),a0
	moveq.l	#11,d0			;ArgArray has 12 slots
s_argclr:
	clr.l	(a0)+
	dbra	d0,s_argclr

	lea	ArgTemplate(pc),a0
	move.l	a0,d1
	lea	ArgArray(a4),a0
	move.l	a0,d2
	moveq.l	#0,d3			;rdargs = NULL -> auto-alloc
	CALLDOS	ReadArgs
	move.l	d0,RDArgs(a4)
	beq.w	s_argerr		;parse failed, DOS already printed why

	bsr.w	ParseForceCmd		;CMD= override -> ForceCmd; d0!=0 if bad value
	tst.l	d0
	bne.w	s_cmderr

	;INSPECT mode: probe a device, print capabilities, exit.
	;No SRC/DST needed; INSPECT carries the device name.
	move.l	ArgArray+36(a4),d0	;INSPECT (slot 9)
	beq.s	s_args_check_help
	;set SourceVec for s_open: name + unit, mark as device
	lea	SourceVec(a4),a3
	move.l	d0,DV_Name(a3)
	moveq.l	#0,d1			;default unit 0
	move.l	ArgArray+8(a4),d0	;UNIT slot (optional)
	beq.s	s_inspect_set
	move.l	d0,a2
	move.l	(a2),d1
s_inspect_set:
	move.l	d1,DV_Unit(a3)
	moveq.l	#-1,d0
	move.l	d0,DV_File(a3)		;mark as device for s_open
	clr.l	DestVec+DV_File(a4)	;DestVec inactive
	st.b	InspectFlag(a4)		;non-zero: INSPECT mode
	bra.w	s_args_done

s_args_check_help:
	;HELP set, or required SRC/DST missing: print help and bail
	move.l	ArgArray+32(a4),d0	;HELP (slot 8): switch sets ptr non-NULL
	bne.s	s_arghelp
	move.l	ArgArray+0(a4),d0	;SRC
	beq.s	s_arghelp
	move.l	ArgArray+4(a4),d0	;DST
	bne.s	s_args_ok
s_arghelp:
	bsr.w	PrintHelp
	bra.w	s_closedos
s_args_ok:

	;SRC and DST present: populate DV slots
	lea	SourceVec(a4),a3
	move.l	ArgArray+0(a4),DV_Name(a3)
	lea	DestVec(a4),a3
	move.l	ArgArray+4(a4),DV_Name(a3)

	;classify SRC (device vs file vs FILL:) and assign unit
	lea	SourceVec(a4),a3
	move.l	DV_Name(a3),a0
	bsr.w	CheckDevName
	tst.w	d0
	beq.s	s_src_file
	move.l	ArgArray+24(a4),d0	;US (slot 6)
	bne.s	s_src_unit
	move.l	ArgArray+8(a4),d0	;UNIT (slot 2)
	beq.w	s_argmissunit
s_src_unit:
	move.l	d0,a0
	move.l	(a0),DV_Unit(a3)
	moveq.l	#-1,d0
	bra.s	s_src_done
s_src_file:
	moveq.l	#0,d0
s_src_done:
	move.l	d0,DV_File(a3)

	;same for DST
	lea	DestVec(a4),a3
	move.l	DV_Name(a3),a0
	bsr.w	CheckDevName
	tst.w	d0
	beq.s	s_dst_file
	move.l	ArgArray+28(a4),d0	;UD (slot 7)
	bne.s	s_dst_unit
	move.l	ArgArray+8(a4),d0	;UNIT (slot 2)
	beq.w	s_argmissunit
s_dst_unit:
	move.l	d0,a0
	move.l	(a0),DV_Unit(a3)
	moveq.l	#-1,d0
	bra.s	s_dst_done
s_dst_file:
	moveq.l	#0,d0
s_dst_done:
	move.l	d0,DV_File(a3)

	;default numerics
	moveq.l	#0,d0
	move.l	d0,StartBlock(a4)
	moveq.l	#-2,d0
	ror.l	#1,d0
	move.l	d0,NumBlocks(a4)
	clr.l	CustomSize(a4)

	;deref optional positional numerics if given
	move.l	ArgArray+12(a4),d0	;START (slot 3)
	beq.s	s_arg_ns
	move.l	d0,a0
	move.l	(a0),StartBlock(a4)
s_arg_ns:
	move.l	ArgArray+16(a4),d0	;COUNT (slot 4)
	beq.s	s_arg_nc
	move.l	d0,a0
	move.l	(a0),NumBlocks(a4)
s_arg_nc:
	move.l	ArgArray+20(a4),d0	;BS (slot 5)
	beq.w	s_pdone
	move.l	d0,a0
	move.l	(a0),CustomSize(a4)
	bra.w	s_pdone

s_argmissunit:
	move.l	ConsoleO(a4),d4
	beq.s	s_argclose
	move.l	d4,d1
	lea	NoUnitStr(pc),a0
	move.l	a0,d2
	moveq.l	#NoUnitEnd-NoUnitStr,d3
	CALLDOS	Write
s_argclose:
	bra.w	s_closedos
s_argerr:
	bra.w	s_closedos		;ReadArgs already printed an error
s_cmderr:
	move.l	ConsoleO(a4),d1
	beq.w	s_closedos
	lea	CmdErrStr(pc),a0
	move.l	a0,d2
	moveq.l	#CmdErrEnd-CmdErrStr,d3
	CALLDOS	Write
	bra.w	s_closedos

NoUnitStr:
	dc.b	'dd: device named but no UNIT/US/UD given',10
NoUnitEnd:
CmdErrStr:
	dc.b	'dd: unknown CMD value (AUTO|CMD|TD64|NSCMD|SCSI)',10
CmdErrEnd:
	even
s_pdone:
s_args_done:

;- - open devices - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#2,d4
	tst.b	InspectFlag(a4)
	beq.s	s_open_init		;normal: process SourceVec then DestVec
	moveq.l	#1,d4			;INSPECT: SourceVec only
s_open_init:
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
	addq.l	#5,a0			;skip "FILL:"
	move.l	a0,d1			;d1 = value string
	clr.l	-(sp)			;d2 -> scratch long
	move.l	sp,d2
	CALLDOS	StrToLong
	move.l	(sp)+,d0		;parsed value
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
	;(geometry/readcapacity fall-through point; no MODESENSE dump)

;- - probe NSD - - - - - - - - - - - - - - - - - - - - - - -
;Sets DV_CmdFlags bit0 when the device has usable NSD, else leaves it 0.
;Buffer is pre-zeroed; the reply is accepted only when io_Actual >= 16
;(filled through the SupportedCommands field).

s_onsd_probe:
	lea	QueryResult(a4),a0	;zero the 16-byte result buffer
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)
	move.l	DV_IORequest(a3),a1
	move.w	#NSCMD_DEVICEQUERY,IO_Command(a1)
	lea	QueryResult(a4),a0
	move.l	a0,IO_Data(a1)
	moveq.l	#QR_Sizeof,d0
	move.l	d0,IO_Length(a1)
	clr.l	IO_Actual(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.w	s_onsd_end		;query failed -> no NSD
	move.l	DV_IORequest(a3),a1
	move.l	IO_Actual(a1),d1	;bytes the device actually filled
	moveq.l	#QR_Sizeof,d0
	cmp.l	d1,d0			;io_Actual >= 16 ?
	bhi.w	s_onsd_end		;< 16: struct not filled through cmd list
	move.l	QueryResult+QR_SizeAvailable(a4),d0
	cmp.l	d1,d0			;SizeAvailable >= io_Actual ?
	bcs.w	s_onsd_end		;inconsistent -> reject
	cmp.w	#NSDEVTYPE_TRACKDISK,QueryResult+QR_DeviceType(a4)
	bne.w	s_onsd_end		;not a trackdisk-style device
	move.l	QueryResult+QR_SupportedCmds(a4),d0
	beq.s	s_onsd_end		;no command list
	move.l	d0,a0
	moveq.l	#0,d1
s_onsd_scan:
	move.w	(a0)+,d0
	beq.s	s_onsd_done
	cmp.w	#NSCMD_TD_READ64,d0
	bne.s	s_onsd_s1
	or.b	#4,d1			;bit2: NSCMD_TD64
	bra.s	s_onsd_scan
s_onsd_s1:
	cmp.w	#TD_READ64,d0
	bne.s	s_onsd_s2
	or.b	#8,d1			;bit3: classic TD64
	bra.s	s_onsd_scan
s_onsd_s2:
	cmp.w	#HD_SCSICMD,d0
	bne.s	s_onsd_scan
	or.b	#16,d1			;bit4: HD_SCSICMD
	bra.s	s_onsd_scan
s_onsd_done:
	or.b	#1,d1			;bit 0: NSD usable
	move.b	d1,DV_CmdFlags(a3)
s_onsd_end:

s_onext:
	lea	DestVec(a4),a3
	subq.w	#1,d4
	bgt.w	s_open
	bra.w	s_odone
s_onofile:
	move.l	ConsoleO(a4),d1
	beq.w	s_closedev
	move.l	DV_Name(a3),-(sp)	;arg1: file name
	lea	fo_nofile(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp
	bra.w	s_closedev
s_onodevice:
	move.l	ConsoleO(a4),d1
	beq.w	s_closedev
	move.l	DV_IORequest(a3),a0
	move.b	IO_Error(a0),d0
	ext.w	d0
	ext.l	d0
	move.l	d0,-(sp)		;arg3: error code (signed)
	move.l	DV_Name(a3),-(sp)	;arg2: device name
	move.l	DV_Unit(a3),-(sp)	;arg1: unit
	lea	fo_nodev(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	lea	12(sp),sp
	bra.w	s_closedev
s_oerror:
	bra.w	s_closedev
s_odone:

;- - INSPECT mode: print device info and exit - - - - - - -

	tst.b	InspectFlag(a4)
	beq.s	s_buffers
	bsr.w	PrintInspect
	bra.w	s_closedev

;- - get buffers  - - - - - - - - - - - - - - - - - - - - -

s_buffers:
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
	or.b	#$80,SourceVec+DV_CmdFlags(a4)	;..always use SCSI mode
	or.b	#$80,DestVec+DV_CmdFlags(a4)
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

	move.l	ConsoleO(a4),d1
	beq.s	s_w6

	move.l	BlockSize(a4),-(sp)	;arg1: detected block size
	lea	fw_sizewarn(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp
	lea	StringBuf(a4),a0
	move.l	a0,d2			;read the y/n response into StringBuf
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

	or.b	#$80,SourceVec+DV_CmdFlags(a4)
	or.b	#$80,DestVec+DV_CmdFlags(a4)
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
	sne	d2			;d2 = $ff if range > 4 Gbyte, else 0

;- - pick I/O command set per device - - - - - - - - - - - -
;
; Command selection per side (SRC = read path, DST = write path).
; The same decision diagram is documented in docs/dd.md.
;
;   real .device ? --- no ---> DOS Read/Write (file, FILL:, RSPEED:)
;         |
;        yes
;         |
;   forced SCSI (bit 7) ? --- yes ---> HD_SCSICMD
;         |                            (set when block size is not 2^n)
;         no
;         |
;   range > 4 GiB ? --- no ---> CMD_READ / CMD_WRITE
;         |
;        yes
;         |
;   NSD advertises NSCMD_TD_READ64 ?
;         |
;         +-- yes --> NSCMD_TD_READ64 / NSCMD_TD_WRITE64
;         |
;         +-- no  --> TD_READ64 / TD_WRITE64
;
; Runtime fallback (s_t2/s_t4): on IOERR_NOCMD (-3) the swath is retried
; with the next command down the ladder (see NextCmd) --
;     NSCMD_TD_READ64  -> TD_READ64  -> HD_SCSICMD -> report -3
;     NSCMD_TD_WRITE64 -> TD_WRITE64 -> HD_SCSICMD -> report -3
; CMD_READ/CMD_WRITE and HD_SCSICMD have no successor.
;
; A CMD= override (ForceCmd) pins both sides to one command, skips the
; selection below, and disables the fallback (strict; see s_t2err/s_t4err).

	tst.b	ForceCmd(a4)		;CMD= override active?
	beq.s	s_w8_auto
	moveq.l	#0,d0
	move.b	ForceCmd(a4),d0		;1..4
	cmp.b	#1,d0			;CMD (32-bit byte offset) ?
	bne.s	s_w8_force_idx
	tst.b	d2			;..and range > 4 GiB ?
	bne.w	s_cmd32err		;reject: CMD_READ/WRITE would wrap
s_w8_force_idx:
	subq.l	#1,d0
	add.l	d0,d0
	add.l	d0,d0			;index * 4 (two words per entry)
	lea	ForceCmdTab(pc),a0
	move.w	0(a0,d0.l),d1		;forced read command
	move.w	2(a0,d0.l),d2		;forced write command
	move.w	d1,SourceVec+DV_ReadCmd(a4)
	move.w	d2,SourceVec+DV_WriteCmd(a4)
	move.w	d1,DestVec+DV_ReadCmd(a4)
	move.w	d2,DestVec+DV_WriteCmd(a4)
	bra.w	s_wdone
s_w8_auto:
	move.l	SourceVec+DV_IORequest(a4),d0
	beq.s	s_w8_dst		;source not a real device
	move.w	#CMD_READ,SourceVec+DV_ReadCmd(a4)
	move.w	#CMD_WRITE,SourceVec+DV_WriteCmd(a4)
	move.b	SourceVec+DV_CmdFlags(a4),d0
	btst	#7,d0			;forced SCSI?
	bne.s	s_w8_src_scsi
	tst.b	d2
	beq.s	s_w8_dst		;<=4G: keep CMD_READ/WRITE
	btst	#2,d0			;NSCMD-TD64 advertised?
	beq.s	s_w8_src_td64		;no -> classic TD64 default
	move.w	#NSCMD_TD_READ64,SourceVec+DV_ReadCmd(a4)
	move.w	#NSCMD_TD_WRITE64,SourceVec+DV_WriteCmd(a4)
	bra.s	s_w8_dst
s_w8_src_td64:
	move.w	#TD_READ64,SourceVec+DV_ReadCmd(a4)
	move.w	#TD_WRITE64,SourceVec+DV_WriteCmd(a4)
	bra.s	s_w8_dst
s_w8_src_scsi:
	move.w	#HD_SCSICMD,SourceVec+DV_ReadCmd(a4)
	move.w	#HD_SCSICMD,SourceVec+DV_WriteCmd(a4)

s_w8_dst:
	move.l	DestVec+DV_IORequest(a4),d0
	beq.s	s_wdone			;dest not a real device
	move.w	#CMD_READ,DestVec+DV_ReadCmd(a4)
	move.w	#CMD_WRITE,DestVec+DV_WriteCmd(a4)
	move.b	DestVec+DV_CmdFlags(a4),d0
	btst	#7,d0
	bne.s	s_w8_dst_scsi
	tst.b	d2
	beq.s	s_wdone
	btst	#2,d0
	beq.s	s_w8_dst_td64
	move.w	#NSCMD_TD_READ64,DestVec+DV_ReadCmd(a4)
	move.w	#NSCMD_TD_WRITE64,DestVec+DV_WriteCmd(a4)
	bra.s	s_wdone
s_w8_dst_td64:
	move.w	#TD_READ64,DestVec+DV_ReadCmd(a4)
	move.w	#TD_WRITE64,DestVec+DV_WriteCmd(a4)
	bra.s	s_wdone
s_w8_dst_scsi:
	move.w	#HD_SCSICMD,DestVec+DV_ReadCmd(a4)
	move.w	#HD_SCSICMD,DestVec+DV_WriteCmd(a4)
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

;- - announce picked command set per side - - - - -  - - - -

	;source: print only when it is a real device (DV_File == -1)
	move.l	SourceVec+DV_File(a4),d0
	bpl.s	s_fdone_dst
	move.w	SourceVec+DV_ReadCmd(a4),d0
	bsr.w	CmdToStr
	move.l	a0,-(sp)			;arg3: cmd name
	move.l	SourceVec+DV_Unit(a4),-(sp)	;arg2: unit
	move.l	SourceVec+DV_Name(a4),-(sp)	;arg1: device name
	move.l	ConsoleO(a4),d1
	lea	fu_read(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	lea	12(sp),sp
s_fdone_dst:
	move.l	DestVec+DV_File(a4),d0
	bpl.s	s_fdone_done
	move.w	DestVec+DV_WriteCmd(a4),d0
	bsr.w	CmdToStr
	move.l	a0,-(sp)
	move.l	DestVec+DV_Unit(a4),-(sp)
	move.l	DestVec+DV_Name(a4),-(sp)
	move.l	ConsoleO(a4),d1
	lea	fu_write(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	lea	12(sp),sp
s_fdone_done:

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

	move.l	ConsoleO(a4),d1
	beq.s	s_t0

	move.l	d4,-(sp)		;arg1: current block #
	lea	ft_progress(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf		;report progress
	addq.l	#4,sp
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
	move.w	SourceVec+DV_ReadCmd(a4),d0
	cmp.w	#HD_SCSICMD,d0
	beq.s	s_ts2

	move.w	d0,IO_Command(a1)	;CMD_READ or NSCMD_TD_READ64
	move.l	d2,IO_Data(a1)
	move.l	d3,IO_Length(a1)
	move.l	d4,d0			;block #
	rol.l	d7,d0			;rotate byte-offset high bits into low
	moveq.l	#0,d1
	bset	d7,d1
	subq.l	#1,d1			;d1 = BlockMask = (1<<BlockShift)-1
	and.l	d0,d1			;d1 = high 32 bits of byte offset
	move.l	d1,IO_Actual(a1)	;TD64 HighOffset (0 for CMD_READ)
	eor.l	d1,d0			;d0 = low 32 bits
	move.l	d0,IO_Offset(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	beq.s	s_t3
	bra.w	s_t2err
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
	bne.w	s_t2err
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
	move.w	DestVec+DV_WriteCmd(a4),d0
	cmp.w	#HD_SCSICMD,d0
	beq.s	s_ts4

	move.w	d0,IO_Command(a1)	;CMD_WRITE or NSCMD_TD_WRITE64
	move.l	d2,IO_Data(a1)
	move.l	d3,IO_Length(a1)
	move.l	d4,d0			;block #
	rol.l	d7,d0
	moveq.l	#0,d1
	bset	d7,d1
	subq.l	#1,d1			;d1 = BlockMask = (1<<BlockShift)-1
	and.l	d0,d1			;d1 = high 32 bits of byte offset
	move.l	d1,IO_Actual(a1)	;TD64 HighOffset (0 for CMD_WRITE)
	eor.l	d1,d0			;d0 = low 32 bits
	move.l	d0,IO_Offset(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	beq.s	s_t5
	bra.w	s_t4err
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
	bne.w	s_t4err
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
	bra.w	s_closedev
s_tbreak:
	move.l	ConsoleO(a4),d4
	beq.w	s_closedev

	move.l	d4,d1
	lea	BreakText(pc),a0
	move.l	a0,d2
	moveq.l	#BTEnd-BreakText,d3
	CALLDOS	Write
	bra.w	s_closedev
s_cmd32err:
	move.l	ConsoleO(a4),d1
	beq.w	s_closedev
	lea	Cmd32Str(pc),a0
	move.l	a0,d2
	moveq.l	#Cmd32End-Cmd32Str,d3
	CALLDOS	Write
	bra.w	s_closedev
s_t2err:
	;read I/O failed (d0 = io_Error). If the command is unsupported, step
	;down the ladder (NSCMD_TD_READ64 -> TD_READ64 -> HD_SCSICMD) and retry.
	;A CMD= override is honored strictly: no downgrade, report the error.
	tst.b	ForceCmd(a4)
	bne.w	s_treaderr
	cmp.l	#IOERR_NOCMD,d0
	bne.w	s_treaderr		;genuine error: report d0 as-is
	move.w	SourceVec+DV_ReadCmd(a4),d0
	bsr.w	NextCmd
	bne.s	s_t2edn
	moveq.l	#IOERR_NOCMD,d0		;ladder exhausted: report -3
	bra.w	s_treaderr
s_t2edn:
	move.l	d0,d1			;d1 = successor command
	move.w	SourceVec+DV_ReadCmd(a4),d0	;d0 = old command
	move.w	d1,SourceVec+DV_ReadCmd(a4)	;commit successor
	bsr.w	PrintFallback		;notice: d0=old, d1=new
	bra.w	s_t2			;retry this swath read
s_t4err:
	;write I/O failed (d0 = io_Error): same ladder on DestVec.
	;A CMD= override is honored strictly: no downgrade, report the error.
	tst.b	ForceCmd(a4)
	bne.w	s_twriteerr
	cmp.l	#IOERR_NOCMD,d0
	bne.w	s_twriteerr
	move.w	DestVec+DV_WriteCmd(a4),d0
	bsr.w	NextCmd
	bne.s	s_t4edn
	moveq.l	#IOERR_NOCMD,d0
	bra.w	s_twriteerr
s_t4edn:
	move.l	d0,d1
	move.w	DestVec+DV_WriteCmd(a4),d0
	move.w	d1,DestVec+DV_WriteCmd(a4)
	bsr.w	PrintFallback
	bra.w	s_t4			;retry this swath write
s_treaderr:
	lea	fe_read(pc),a1
	bra.s	s_tereport
s_twriteerr:
	lea	fe_write(pc),a1
s_tereport:
	move.l	ConsoleO(a4),d1
	beq.s	s_closedev

	move.l	d0,-(sp)		;arg2: error code (signed)
	move.l	DV_Name(a3),-(sp)	;arg1: device name
	move.l	a1,d2			;format (read or write)
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#8,sp

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
	tst.b	InspectFlag(a4)
	bne.w	s_closedos		;INSPECT: skip transfer summary
	move.l	ConsoleO(a4),d1
	beq.w	s_closedos

	move.l	BlockSize(a4),-(sp)	;arg2: bytes per block
	move.l	DoneBlocks(a4),-(sp)	;arg1: blocks done
	lea	fr_done(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#8,sp

	move.l	DoneBlocks(a4),d0
	move.l	BlockSize(a4),d1
	bsr.w	UMul32
	move.l	d0,d4			;total bytes transferred
	lea	RTime(a4),a0
	bsr.w	TimeMsecs
	move.l	d0,d1
	beq.s	s_rep1

	move.l	d4,d0
	bsr.w	UDivMod32		;d0 = kbyte/sec
	move.l	d0,-(sp)		;arg1: read speed
	move.l	ConsoleO(a4),d1
	lea	fr_rspeed(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp
s_rep1:
	lea	WTime(a4),a0
	bsr.w	TimeMsecs
	move.l	d0,d1
	beq.s	s_closedos

	move.l	d4,d0
	bsr.w	UDivMod32		;d0 = kbyte/sec
	move.l	d0,-(sp)		;arg1: write speed
	move.l	ConsoleO(a4),d1
	lea	fr_wspeed(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp

;- - free resources - - - - - - - - - - - - - - - - - - - -

s_closedos:
	move.l	RDArgs(a4),d1
	beq.s	s_end_norda
	CALLDOS	FreeArgs
	clr.l	RDArgs(a4)
s_end_norda:
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
s_old_dos_msg:
	dc.b	'dd requires Kickstart 2.0+ (V36+)',13,10
s_old_dos_msg_end:
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

;--- parse CMD= override value -----------------------------
; Reads the CMD/K value (ArgArray slot 11) and sets ForceCmd(a4):
;   0=AUTO (also when not given) 1=CMD 2=TD64 3=NSCMD 4=SCSI.
; d0 -> 0 = ok, -1 = unrecognised value.

ParseForceCmd:
	clr.b	ForceCmd(a4)
	move.l	ArgArray+44(a4),d0	;CMD value string, or NULL
	beq.s	pfc_ok			;not given -> AUTO
	movem.l	d2/a2-a3,-(sp)
	move.l	d0,a2			;a2 = input value
	lea	ForceNameTab(pc),a3
pfc_next:
	move.b	(a3)+,d2		;kind ($ff = end of table)
	cmp.b	#$ff,d2
	beq.s	pfc_unknown
	move.l	a2,a0			;input
	move.l	a3,a1			;table name
pfc_cmp:
	move.b	(a0)+,d0
	and.b	#$df,d0			;case-fold input
	move.b	(a1)+,d1
	and.b	#$df,d1			;case-fold table (digits fold consistently)
	cmp.b	d0,d1
	bne.s	pfc_skip
	tst.b	d1
	bne.s	pfc_cmp
	move.b	d2,ForceCmd(a4)		;full match
	moveq.l	#0,d0
	movem.l	(sp)+,d2/a2-a3
	rts
pfc_skip:
	tst.b	(a3)+			;skip rest of this name to next entry
	bne.s	pfc_skip
	bra.s	pfc_next
pfc_unknown:
	movem.l	(sp)+,d2/a2-a3
	moveq.l	#-1,d0
	rts
pfc_ok:
	moveq.l	#0,d0
	rts

ForceNameTab:
	dc.b	0,'AUTO',0
	dc.b	1,'CMD',0
	dc.b	2,'TD64',0
	dc.b	3,'NSCMD',0
	dc.b	4,'SCSI',0
	dc.b	$ff
	even

; read/write command pairs for ForceCmd 1..4 (CMD/TD64/NSCMD/SCSI)
ForceCmdTab:
	dc.w	CMD_READ,CMD_WRITE
	dc.w	TD_READ64,TD_WRITE64
	dc.w	NSCMD_TD_READ64,NSCMD_TD_WRITE64
	dc.w	HD_SCSICMD,HD_SCSICMD

ArgTemplate:
	dc.b	'SRC,DST,UNIT/N,START/N,COUNT/N,BS/N,US=UNITSRC/N/K,UD=UNITDST/N/K,HELP=H/S,INSPECT=I/K,VERBOSE=V/S,CMD/K',0
	even

;--- command-word → name lookup ----------------------------
; Used by INSPECT printer and the per-transfer "via <cmd>" line.
; Terminated with a 0-word entry.

CmdNames:
	dc.w	CMD_RESET
	dc.l	cn_cmd_reset
	dc.w	CMD_READ
	dc.l	cn_cmd_read
	dc.w	CMD_WRITE
	dc.l	cn_cmd_write
	dc.w	CMD_UPDATE
	dc.l	cn_cmd_update
	dc.w	CMD_CLEAR
	dc.l	cn_cmd_clear
	dc.w	CMD_STOP
	dc.l	cn_cmd_stop
	dc.w	CMD_START
	dc.l	cn_cmd_start
	dc.w	CMD_FLUSH
	dc.l	cn_cmd_flush
	dc.w	TD_MOTOR
	dc.l	cn_td_motor
	dc.w	TD_SEEK
	dc.l	cn_td_seek
	dc.w	TD_FORMAT
	dc.l	cn_td_format
	dc.w	TD_REMOVE
	dc.l	cn_td_remove
	dc.w	TD_CHANGENUM
	dc.l	cn_td_chgnum
	dc.w	TD_CHANGESTATE
	dc.l	cn_td_chgstate
	dc.w	TD_PROTSTATUS
	dc.l	cn_td_protstat
	dc.w	TD_GETDRIVETYPE
	dc.l	cn_td_getdtype
	dc.w	TD_ADDCHANGEINT
	dc.l	cn_td_addci
	dc.w	TD_REMCHANGEINT
	dc.l	cn_td_remci
	dc.w	TD_GETGEOMETRY
	dc.l	cn_td_getgeo
	dc.w	ETD_READ
	dc.l	cn_etd_read
	dc.w	ETD_WRITE
	dc.l	cn_etd_write
	dc.w	ETD_UPDATE
	dc.l	cn_etd_update
	dc.w	NSCMD_DEVICEQUERY
	dc.l	cn_nsq
	dc.w	NSCMD_TD_READ64
	dc.l	cn_ns_r64
	dc.w	NSCMD_TD_WRITE64
	dc.l	cn_ns_w64
	dc.w	NSCMD_TD_SEEK64
	dc.l	cn_ns_s64
	dc.w	NSCMD_TD_FORMAT64
	dc.l	cn_ns_f64
	dc.w	TD_READ64
	dc.l	cn_td_read64
	dc.w	TD_WRITE64
	dc.l	cn_td_write64
	dc.w	TD_SEEK64
	dc.l	cn_td_seek64
	dc.w	TD_FORMAT64
	dc.l	cn_td_fmt64
	dc.w	TD_RAWREAD
	dc.l	cn_td_rawread
	dc.w	TD_RAWWRITE
	dc.l	cn_td_rawwrite
	dc.w	TD_GETNUMTRACKS
	dc.l	cn_td_getntrk
	dc.w	TD_EJECT
	dc.l	cn_td_eject
	dc.w	HD_SCSICMD
	dc.l	cn_scsi
	dc.w	0			;terminator
cn_cmd_reset:	dc.b	'CMD_RESET',0
cn_cmd_read:	dc.b	'CMD_READ',0
cn_cmd_write:	dc.b	'CMD_WRITE',0
cn_cmd_update:	dc.b	'CMD_UPDATE',0
cn_cmd_clear:	dc.b	'CMD_CLEAR',0
cn_cmd_stop:	dc.b	'CMD_STOP',0
cn_cmd_start:	dc.b	'CMD_START',0
cn_cmd_flush:	dc.b	'CMD_FLUSH',0
cn_td_motor:	dc.b	'TD_MOTOR',0
cn_td_seek:	dc.b	'TD_SEEK',0
cn_td_format:	dc.b	'TD_FORMAT',0
cn_td_remove:	dc.b	'TD_REMOVE',0
cn_td_chgnum:	dc.b	'TD_CHANGENUM',0
cn_td_chgstate:	dc.b	'TD_CHANGESTATE',0
cn_td_protstat:	dc.b	'TD_PROTSTATUS',0
cn_td_getdtype:	dc.b	'TD_GETDRIVETYPE',0
cn_td_addci:	dc.b	'TD_ADDCHANGEINT',0
cn_td_remci:	dc.b	'TD_REMCHANGEINT',0
cn_td_getgeo:	dc.b	'TD_GETGEOMETRY',0
cn_etd_read:	dc.b	'ETD_READ',0
cn_etd_write:	dc.b	'ETD_WRITE',0
cn_etd_update:	dc.b	'ETD_UPDATE',0
cn_nsq:		dc.b	'NSCMD_DEVICEQUERY',0
cn_ns_r64:	dc.b	'NSCMD_TD_READ64',0
cn_ns_w64:	dc.b	'NSCMD_TD_WRITE64',0
cn_ns_s64:	dc.b	'NSCMD_TD_SEEK64',0
cn_ns_f64:	dc.b	'NSCMD_TD_FORMAT64',0
cn_td_read64:	dc.b	'TD_READ64',0
cn_td_write64:	dc.b	'TD_WRITE64',0
cn_td_seek64:	dc.b	'TD_SEEK64',0
cn_td_fmt64:	dc.b	'TD_FORMAT64',0
cn_td_rawread:	dc.b	'TD_RAWREAD',0
cn_td_rawwrite:	dc.b	'TD_RAWWRITE',0
cn_td_getntrk:	dc.b	'TD_GETNUMTRACKS',0
cn_td_eject:	dc.b	'TD_EJECT',0
cn_scsi:	dc.b	'HD_SCSICMD',0
cn_unknown:	dc.b	'unknown',0
	even

;--- lookup command word -> name string --------------------
; d0 <- command word
; a0 -> string pointer

CmdToStr:
	movem.l	d1/a1,-(sp)
	lea	CmdNames(pc),a1
cts_loop:
	move.w	(a1)+,d1
	beq.s	cts_unknown
	move.l	(a1)+,a0
	cmp.w	d0,d1
	bne.s	cts_loop
	bra.s	cts_end
cts_unknown:
	lea	cn_unknown(pc),a0
cts_end:
	movem.l	(sp)+,d1/a1
	rts

;--- format word as "$XXXX" --------------------------------
; d0 <- word
; a0 -> HexBuf (NUL-terminated)

WordToHex:
	movem.l	d0-d2/a1,-(sp)
	lea	HexBuf(pc),a1
	move.b	#'$',(a1)+
	moveq.l	#3,d2			;4 nibbles, high first
wth_loop:
	rol.w	#4,d0			;next nibble into low 4 bits
	move.w	d0,d1
	and.w	#$0f,d1
	cmp.b	#10,d1
	bcs.s	wth_dig
	addq.b	#7,d1			;A..F
wth_dig:
	add.b	#'0',d1
	move.b	d1,(a1)+
	dbra	d2,wth_loop
	clr.b	(a1)
	movem.l	(sp)+,d0-d2/a1
	lea	HexBuf(pc),a0
	rts
HexBuf:	dc.b	0,0,0,0,0,0		;"$XXXX",0
	even

;--- next fallback command ---------------------------------
; Steps a >4 GiB read/write command down the support ladder when a device
; rejects it with IOERR_NOCMD. CMD_READ/WRITE and HD_SCSICMD have no
; successor (HD_SCSICMD is the last resort).
; d0 <- current command word
; d0 -> successor command word, or 0 if none

NextCmd:
	cmp.w	#NSCMD_TD_READ64,d0
	bne.s	nc_1
	move.w	#TD_READ64,d0
	rts
nc_1:
	cmp.w	#NSCMD_TD_WRITE64,d0
	bne.s	nc_2
	move.w	#TD_WRITE64,d0
	rts
nc_2:
	cmp.w	#TD_READ64,d0
	beq.s	nc_scsi
	cmp.w	#TD_WRITE64,d0
	beq.s	nc_scsi
	moveq.l	#0,d0
	rts
nc_scsi:
	move.w	#HD_SCSICMD,d0
	rts

;--- print command fallback notice -------------------------
; Tells the user the chosen command was unsupported and which one is
; tried next, so the up-front "via <cmd>" line is not silently stale.
; Preserves all transfer registers.
; d0 <- old command word, d1 <- new command word

PrintFallback:
	movem.l	d0-d7/a0-a6,-(sp)
	move.l	ConsoleO(a4),d2
	beq.s	pf_ret
	bsr.w	CmdToStr		;old name -> a0 (d0/d1 preserved)
	move.l	a0,a2			;a2 = old name
	move.w	d1,d0
	bsr.w	CmdToStr		;new name -> a0
	move.l	a0,-(sp)		;arg2 = new name
	move.l	a2,-(sp)		;arg1 = old name
	move.l	ConsoleO(a4),d1
	lea	fb_note(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#8,sp
pf_ret:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

;--- print ">4GiB methods:" capability summary -------------
; Reads DV_CmdFlags(a3) (a3 = SourceVec) and lists the advertised
; >4 GiB-capable commands, comma-separated, or "(none)".

pi_methods:
	move.b	DV_CmdFlags(a3),d5	;capability bits
	move.l	ConsoleO(a4),d1
	beq.s	pim_ret			;no console
	lea	fi_meth_lbl(pc),a0	;label, no newline
	move.l	a0,d2
	moveq.l	#0,d3
	CALLDOS	VFPrintf
	moveq.l	#0,d4			;0 = nothing printed yet
	btst	#2,d5			;NSCMD_TD64
	beq.s	pim_1
	lea	cn_cap_nscmd(pc),a0
	bsr.s	pim_tok
pim_1:
	btst	#3,d5			;classic TD64
	beq.s	pim_2
	lea	cn_cap_td64(pc),a0
	bsr.s	pim_tok
pim_2:
	btst	#4,d5			;HD_SCSICMD
	beq.s	pim_3
	lea	cn_cap_scsi(pc),a0
	bsr.s	pim_tok
pim_3:
	tst.b	d4
	bne.s	pim_nl
	lea	cn_cap_none(pc),a0	;none advertised
	bsr.s	pim_tok
pim_nl:
	move.l	ConsoleO(a4),d1
	lea	fi_meth_nl(pc),a0	;just a newline
	move.l	a0,d2
	moveq.l	#0,d3
	CALLDOS	VFPrintf
pim_ret:
	rts

pim_tok:				;a0 = token; first plain, rest ", "-prefixed
	move.l	a0,-(sp)		;arg = token
	tst.b	d4
	bne.s	pim_tsep
	lea	fi_meth_t1(pc),a0	;"%s"
	bra.s	pim_temit
pim_tsep:
	lea	fi_meth_t2(pc),a0	;", %s"
pim_temit:
	move.l	a0,d2
	move.l	ConsoleO(a4),d1
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp
	moveq.l	#1,d4			;mark "something printed"
	rts

;--- print help banner -------------------------------------
; (no input/output)

PrintHelp:
	move.l	ConsoleO(a4),d1
	beq.s	ph_end
	lea	HelpBanner(pc),a0
	move.l	a0,d2
	move.l	#HelpEnd-HelpBanner,d3
	CALLDOS	Write
ph_end:
	rts

;(PrintCmdUsed removed - now inlined at s_fdone using VFPrintf)

;--- print INSPECT result ----------------------------------
; SourceVec must be populated by s_open (DV_BlockSize, DV_NumBlocks,
; DV_CmdFlags) and DriveGeometry/QueryResult fields by TD_GETGEOMETRY
; + NSD probe.

PrintInspect:
	movem.l	d2-d3/a3,-(sp)
	move.l	ConsoleO(a4),d0
	beq.w	pi_end
	lea	SourceVec(a4),a3

	;header: "<name> unit <n>:"
	move.l	DV_Unit(a3),-(sp)
	move.l	DV_Name(a3),-(sp)
	move.l	ConsoleO(a4),d1
	lea	fi_hdr(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#8,sp

	;sector size
	move.l	DV_BlockSize(a3),-(sp)
	move.l	ConsoleO(a4),d1
	lea	fi_sect(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp

	;total sectors
	move.l	DV_NumBlocks(a3),-(sp)
	move.l	ConsoleO(a4),d1
	lea	fi_total(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp

	;cylinders
	move.l	DriveGeometry+DG_Cylinders(a4),-(sp)
	move.l	ConsoleO(a4),d1
	lea	fi_cyl(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp

	;heads
	move.l	DriveGeometry+DG_Heads(a4),-(sp)
	move.l	ConsoleO(a4),d1
	lea	fi_heads(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp

	;sec/track
	move.l	DriveGeometry+DG_TrackSectors(a4),-(sp)
	move.l	ConsoleO(a4),d1
	lea	fi_spt(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#4,sp

	;NSD present? if not, show nothing here: the "for >4 GiB:" line
	;below still reveals the command dd would use.
	move.b	DV_CmdFlags(a3),d0
	btst	#0,d0
	beq.w	pi_after_nsd
	;NSD present: print the ">4GiB methods:" summary; the full command
	;list follows only with VERBOSE.
	bsr.w	pi_methods		;">4GiB methods:" summary (reads DV_CmdFlags)
	move.l	ArgArray+40(a4),d0	;VERBOSE switch (slot 10)
	beq.w	pi_after_nsd		;not verbose: skip the command list
	move.l	ConsoleO(a4),d1
	lea	fi_cmds(pc),a0
	move.l	a0,d2
	moveq.l	#0,d3
	CALLDOS	VFPrintf
	;walk SupportedCommands list, print "$HEX (name)" per entry
	move.l	QueryResult+QR_SupportedCmds(a4),a3	;temporarily use a3 as iterator
	move.l	a3,d0
	beq.w	pi_after_nsd
pi_walk:
	move.w	(a3)+,d0
	beq.w	pi_after_nsd
	move.w	d0,d4			;keep command word across calls
	move.l	a3,-(sp)		;save iterator
	bsr.w	CmdToStr		;d4 -> a0 = name (or "unknown")
	move.l	a0,-(sp)		;arg2: name
	move.w	d4,d0
	bsr.w	WordToHex		;d4 -> a0 = "$XXXX"
	move.l	a0,-(sp)		;arg1: hex string
	move.l	ConsoleO(a4),d1
	lea	fi_cmdline(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#8,sp
	move.l	(sp)+,a3		;restore iterator
	bra.w	pi_walk
pi_after_nsd:
	lea	SourceVec(a4),a3	;restore a3 (may have been used as iterator)

	;for <=4 GiB: CMD_READ / CMD_WRITE
	move.w	#CMD_WRITE,d0
	bsr.w	CmdToStr
	move.l	a0,-(sp)		;arg2: CMD_WRITE name
	move.w	#CMD_READ,d0
	bsr.w	CmdToStr
	move.l	a0,-(sp)		;arg1: CMD_READ name
	move.l	ConsoleO(a4),d1
	lea	fi_lo(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#8,sp

	;for >4 GiB: depends on CmdFlags bit 2
	move.b	DV_CmdFlags(a3),d0
	btst	#2,d0
	beq.s	pi_hi_td64
	move.w	#NSCMD_TD_WRITE64,d0
	bsr.w	CmdToStr
	move.l	a0,-(sp)
	move.w	#NSCMD_TD_READ64,d0
	bra.s	pi_hi_emit
pi_hi_td64:
	move.w	#TD_WRITE64,d0
	bsr.w	CmdToStr
	move.l	a0,-(sp)
	move.w	#TD_READ64,d0
pi_hi_emit:
	bsr.w	CmdToStr
	move.l	a0,-(sp)
	move.l	ConsoleO(a4),d1
	lea	fi_hi(pc),a0
	move.l	a0,d2
	move.l	sp,d3
	CALLDOS	VFPrintf
	addq.l	#8,sp
pi_end:
	movem.l	(sp)+,d2-d3/a3
	rts

;--- format strings ----------------------------------------
fi_hdr:		dc.b	'%s unit %ld:',13,10,0
fi_sect:	dc.b	'  sector size:    %ld',13,10,0
fi_total:	dc.b	'  total sectors:  %ld',13,10,0
fi_cyl:		dc.b	'  cylinders:      %ld',13,10,0
fi_heads:	dc.b	'  heads:          %ld',13,10,0
fi_spt:		dc.b	'  sec/track:      %ld',13,10,0
fi_cmds:	dc.b	'  commands:',13,10,0
fi_meth_lbl:	dc.b	'  >4GiB methods:  ',0
fi_meth_t1:	dc.b	'%s',0
fi_meth_t2:	dc.b	', %s',0
fi_meth_nl:	dc.b	13,10,0
cn_cap_nscmd:	dc.b	'NSCMD_TD64',0
cn_cap_td64:	dc.b	'TD64',0
cn_cap_scsi:	dc.b	'HD_SCSI',0
cn_cap_none:	dc.b	'(none)',0
fi_cmdline:	dc.b	'                  %s (%s)',13,10,0
fi_lo:		dc.b	'  for <=4 GiB:    %s / %s',13,10,0
fi_hi:		dc.b	'  for  >4 GiB:    %s / %s',13,10,0
fu_read:	dc.b	'read:  %s unit %ld via %s',13,10,0
fu_write:	dc.b	'write: %s unit %ld via %s',13,10,0
fo_nofile:	dc.b	'could not open file "%s".',10,0
fo_nodev:	dc.b	'opening unit %ld of %s failed (%ld).',10,0
fw_sizewarn:	dc.b	'WARNING: device reports a different block size (%ld)',10
		dc.b	'Continue anyway? (y/n): ',0
ft_progress:	dc.b	'%ld',13,0
fe_read:	dc.b	'%s read error (%ld).',10,0
fe_write:	dc.b	'%s write error (%ld).',10,0
fb_note:	dc.b	'  %s not supported, falling back to %s',10,0
fr_done:	dc.b	'%ld blocks of %ld bytes each transferred.',10,0
fr_rspeed:	dc.b	'Read speed:  %ld kbyte/sec',10,0
fr_wspeed:	dc.b	'Write speed: %ld kbyte/sec',10,0
	even

HelpBanner:
	dc.b	'dd '
	VER_NUMBER
	dc.b	' - raw block transfer tool',13,10,13,10
	dc.b	'Usage: dd SRC DST [UNIT] [START] [COUNT] [BS] [US n] [UD n] [CMD x]',13,10
	dc.b	'       dd INSPECT device.name [UNIT n] [VERBOSE]  (probe device, print capabilities)',13,10
	dc.b	'       dd ? or HELP   (this help; ? also opens the ReadArgs prompt)',13,10,13,10
	dc.b	'Template: SRC,DST,UNIT/N,START/N,COUNT/N,BS/N,US=UNITSRC/N/K,UD=UNITDST/N/K,HELP=H/S,INSPECT=I/K,VERBOSE=V/S,CMD/K',13,10,13,10
	dc.b	'Args:',13,10
	dc.b	'  SRC, DST  Source and destination. Either:',13,10
	dc.b	'            - a device name (e.g. compactflash.device) plus UNIT or US/UD',13,10
	dc.b	'            - a file path (e.g. RAM:dump, DH0:foo)',13,10
	dc.b	'            - FILL:      infinite zero bytes (FILL:NN for value NN)',13,10
	dc.b	'            - RSPEED:    DST only (read-only throughput benchmark)',13,10
	dc.b	'            - RWSPEED:   DST only (read+write throughput benchmark)',13,10
	dc.b	'  UNIT      Device unit. Applies to whichever of SRC/DST is a device.',13,10
	dc.b	'  US, UD    Per-side unit. Use when both SRC and DST are devices.',13,10
	dc.b	'  START     First block to transfer (default 0).',13,10
	dc.b	'  COUNT     Number of blocks (default: entire disk or file).',13,10
	dc.b	'  BS        Block size in bytes (default: detected from device).',13,10
	dc.b	'  VERBOSE   With INSPECT: also list the full SupportedCommands set.',13,10
	dc.b	'  CMD       Force the transfer command: AUTO|CMD|TD64|NSCMD|SCSI (default AUTO).',13,10,13,10
	dc.b	'Examples:',13,10
	dc.b	'  dd FILL: scsi.device 0                      ; wipe whole device',13,10
	dc.b	'  dd FILL: scsi.device 0 0 1048576 512        ; wipe 512 MiB at LBA 0',13,10
	dc.b	'  dd compactflash.device RAM:dump 0 1000 200  ; read 200 blocks @ LBA 1000',13,10
	dc.b	'  dd RAM:dump scsi.device 1 0 200             ; write file back to scsi:1',13,10
	dc.b	'  dd compactflash.device scsi.device US 0 UD 1 START 0 COUNT 1000',13,10
	dc.b	'  dd compactflash.device RAM:dump UNIT 0 START 1000 COUNT 200',13,10
HelpEnd:
	even

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
BreakText:
	dc.b	'** Break **', LF
BTEnd:
	dc.b	0
Cmd32Str:
	dc.b	'dd: CMD=CMD cannot reach past 4 GiB; use TD64, NSCMD or SCSI',LF
Cmd32End:
	even

;*** that's it!!!! *****************************************
	end
