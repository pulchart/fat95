; make fat95 partition bootable tool V3.18
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

FILE_VERSION	= 3
FILE_REVISION	= 18

;--- from exec.library -------------------------------------

CALLEXEC macro
	move.l	ExecBase(a4),a6
	jsr	\1(a6)
	endm

_AbsExecBase	= 4

AllocMem	= -198
FreeMem		= -210
AddHead		= -240
Remove		= -252
FindTask	= -294
Wait		= -318
Signal		= -324
AllocSignal	= -330
FreeSignal	= -336
PutMsg		= -366
GetMsg		= -372
WaitPort	= -384
CloseLibrary	= -414
OpenDevice	= -444
CloseDevice	= -450
DoIO		= -456
SendIO		= -462
CheckIO		= -468
WaitIO		= -474
TypeOfMem	= -534
OpenLibrary	= -552
CopyMem		= -624

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

;struct Interrupt
IS_Data		= 14
IS_Code		= 18
IS_Sizeof	= 22

;memory type
MEMF_PUBLIC	= 1
MEMF_CLEAR	= $10000

;struct Library
LIB_Version	= 20

;Device Vectors
BeginIO		= -30

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
Examine		= -102
DoPkt		= -240
ExamineFH	= -390
GetDeviceProc	= -642
FreeDeviceProc	= -648

ModeOldfile	= 1005
ModeNewfile	= 1006

LF		= 10

;struct DevProc
DVP_Port	= 0
DVP_Lock	= 4
DVP_Flags	= 8
DVP_DevNode	= 12
DVP_Sizeof	= 16

;struct DosList
DL_Name		= 40

ACTION_END		= 1007
ACTION_GET_DISK_FSSM	= 4201
ACTION_FREE_DISK_FSSM	= 4202

;struct DosPacket
DP_Message	=  0
DP_MsgPort	=  4
DP_Type		=  8
DP_Res1		= 12
DP_Res2		= 16
DP_Arg1		= 20
DP_Arg2		= 24
DP_Arg3		= 28
DP_Arg4		= 32
DP_Arg5		= 36
DP_Sizeof	= 48

;struct FileSysStartupMsg
FSSM_Unit	= 0
FSSM_Device	= 4
FSSM_Environ	= 8
FSSM_Flags	= 12
FSSM_Sizeof	= 16

;struct DosEnvec
DE_TableSize	= 0
DE_SizeBlock	= 4			;in Langworten
DE_SecOrg	= 8
DE_Surfaces	= 12
DE_SectorPerBlock = 16
DE_BlocksPerTrack = 20
DE_Reserved	= 24
DE_PreAlloc	= 28
DE_Interleave	= 32
DE_LowCyl	= 36
DE_HighCyl	= 40
DE_NumBuffers	= 44
DE_BufMemType	= 48
DE_MaxTransfer	= 52
DE_Mask		= 56
DE_BootPri	= 60
DE_DosType	= 64
DE_Baud		= 68
DE_Control	= 72
DE_BootBlocks	= 76
DE_Sizeof	= 80

;struct FileLock
FL_Link		= 0
FL_Key		= 4
FL_Access	= 8
FL_Task		= 12
FL_Volume	= 16
FL_Sizeof	= 20

;FL_Access values
SHARED_LOCK	= -2
EXCLUSIVE_LOCK	= -1

;struct FileHandle
FH_Arg1		= 36

;DiskType
ID_NONE		= -1			;no Disk
ID_BUSY		= `BUSY`		;inhibited
ID_BAD		= `BAD`<<8		;unreadable
ID_NDOS		= `NDOS`		;readable but incomprehensible
ID_DOS		= `DOS`<<8		;valid

;DiskState
ID_WRITE_PROT	= 80			;read only
ID_VALIDATING	= 81
ID_VALIDATED	= 82

;struct DeviceNode = struct DosList
DOL_Handler	= 16
DOL_StackSize	= 20
DOL_Priority	= 24
DOL_Startup	= 28
DOL_SegList	= 32
DOL_GlobVec	= 36

;struct VolumeNode = struct DosList
DOL_Next	= 0
DOL_Type	= 4			; = DLT_VOLUME
DOL_Task	= 8
DOL_Lock	= 12
DOL_VolumeDate	= 16
DOL_LockList	= 28
DOL_DiskType	= 32
DOL_Unused	= 36
DOL_Name	= 40
DOL_Sizeof	= 44

;DOL_Type value
DLT_VOLUME	= 2

;DOS error codes for ErrorNum
;0	OK
;103	no mem
;115	invalid count
;202	Object in use
;203	Object already exists
;205	not found
;209	unknown DosPacket command
;212	wrong type
;213	Disk not validated
;214	Disk read only
;216	dir not empty
;218	Disk not inserted
;219	invalid
;221	Disk full
;222	file not deletable
;223	file read only
;225	Disk malformatted
;226	no Disk
;232	no further dir entries

;struct DateStamp
DS_Days		=  0
DS_Mins		=  4
DS_Ticks	=  8
DS_Sizeof	= 12

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

TRUE		= -1
FALSE		= 0

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
IO_Sizeof	= 56

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
INQUIRY		= $12
READCAPACITY	= $25
READ10		= $28
WRITE10		= $2a

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
ReplyPort	= -40
IORequest	= -44
StartupMsg	= -48
BufSize		= -52
Buffer		= -56
BlockSize	= -60
HostID		= -64
FileHandle	= -68
DosType		= -72
TotalSectors	= -76
TrackSize	= -80
PartStart	= -84
FatStart	= -88
FatSize		= -92
StringBuffer	= -400
VarsSize	= -400

;*** here we go !! *****************************************

; a0 <- &command line
; d0 <- length thereof

Start:
	link.w	a4,#VarsSize
	movem.l	d1-d5/a0-a2/a6,-(sp)
	move.l	(_AbsExecBase).w,ExecBase(a4)
	move.l	a0,ArgV(a4)
	move.l	d0,ArgC(a4)
	clr.l	Result(a4)
	moveq.l	#36,d0
	lea	DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	beq.w	s_end

;- - evaluate parameters  - - - - - - - - - - - - - - - - -

	move.l	ArgV(a4),a0
	lea	StringBuffer(a4),a1
	bsr.w	GetDosParams
	move.l	d0,ArgC(a4)
	subq.l	#1,d0
	bmi.w	s_noparams

	move.l	StringBuffer(a4),DeviceName(a4)
	lea	DefFileName(pc),a0
	subq.l	#1,d0
	bmi.s	s_p1

	move.l	StringBuffer+4(a4),a0
s_p1:
	move.l	a0,FileName(a4)

;- - get resources  - - - - - - - - - - - - - - - - - - - -

	bsr.w	AllocMsgPort
	move.l	d0,ReplyPort(a4)
	beq.w	s_closelib

	moveq.l	#IO_Sizeof,d0
	move.l	ReplyPort(a4),a0
	bsr.w	AllocMsg
	move.l	d0,IORequest(a4)
	beq.w	s_closeport

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
	beq.w	s_noinfo

	btst	#0,d0
	bne.w	s_noinfo		;odd Adress???

	move.l	DevProc(a4),a0
	move.l	DVP_Port(a0),d1
	move.l	#ACTION_GET_DISK_FSSM,d2
	moveq.l	#0,d3
	moveq.l	#0,d4
	moveq.l	#0,d5
	CALLDOS	DoPkt
	move.l	d0,StartupMsg(a4)
	beq.w	s_noinfo

	move.l	StartupMsg(a4),a0
	move.l	FSSM_Unit(a0),d0
	move.l	FSSM_Flags(a0),d1
	move.l	FSSM_Device(a0),a0
	add.l	a0,a0
	add.l	a0,a0
	addq.l	#1,a0
	move.l	IORequest(a4),a1
	CALLEXEC OpenDevice
	tst.b	d0
	bne.w	s_nodevice

	move.l	StartupMsg(a4),a0
	move.l	FSSM_Environ(a0),d0
	lsl.l	#2,d0
	move.l	d0,a0			;&DosEnvec
	move.l	DE_BlocksPerTrack(a0),d0
	move.l	DE_Surfaces(a0),d1
	bsr.w	UMul32
	move.l	d0,d2			;Blocks/Cylinder
	move.l	DE_LowCyl(a0),d0
	move.l	d2,d1
	bsr.w	UMul32
	move.l	d0,FatStart(a4)		;Begin and..
	moveq.l	#1,d0
	add.l	DE_HighCyl(a0),d0
	sub.l	DE_LowCyl(a0),d0
	move.l	d2,d1
	bsr.w	UMul32
	move.l	d0,FatSize(a4)		;..length of partition
	move.l	DE_SizeBlock(a0),d0
	lsl.l	#2,d0
	move.l	d0,BlockSize(a4)
	lsl.l	#6,d0
	move.l	d0,BufSize(a4)
	move.l	DE_BufMemType(a0),d1
	bset	#16,d1			;|= MEMF_CLEAR
	CALLEXEC AllocMem
	move.l	d0,Buffer(a4)
	beq.w	s_nomem

;- - eval MBR - - - - - - - - - - - - - - - - - - - - - - -

	move.l	d0,a2
	move.l	IORequest(a4),a1
	move.w	#CMD_READ,IO_Command(a1)
	move.l	BlockSize(a4),IO_Length(a1)
	clr.l	IO_Offset(a1)
	clr.l	IO_Actual(a1)
	move.l	a2,IO_Data(a1)
	movem.l	d2-d7/a2-a5,-(sp)
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a5
	tst.b	d0
	bne.w	s_readerror

	cmp.w	#$55aa,510(a2)
	bne.w	s_nombr

	lea	446(a2),a0
	moveq.l	#-1,d2
	moveq.l	#4,d3
s_mbrscan:
	tst.b	4(a0)
	beq.s	s_mbrsnext

	move.l	8(a0),d0
	rol.w	#8,d0
	swap	d0
	rol.w	#8,d0
	cmp.l	d2,d0
	bcc.s	s_mbrsnext

	move.l	d0,d2
s_mbrsnext:
	add.w	#16,a0
	subq.w	#1,d3
	bgt.s	s_mbrscan

	move.l	d2,PartStart(a4)

;- - get general disk info  - - - - - - - - - - - - - - - -

	moveq.l	#7,d0
	move.l	d0,HostID(a4)

	add.l	BlockSize(a4),a2	;&DriveGeometry
	move.l	IORequest(a4),a1
	move.w	#TD_GETGEOMETRY,IO_Command(a1)
	move.l	a2,IO_Data(a1)
	moveq.l	#DG_Sizeof,d0
	move.l	d0,IO_Length(a1)
	movem.l	d2-d7/a2-a5,-(sp)
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a5
	move.l	IORequest(a4),a1
	move.l	IO_Actual(a1),96(a2)
	move.l	DG_TotalSectors(a2),TotalSectors(a4)

	lea	DG_Sizeof(a2),a0	;&SCSICmd
	move.l	IORequest(a4),a1
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	move.l	a0,IO_Data(a1)
	lea	112(a2),a1		;&ReadCapacityData
	move.l	a1,(a0)+		;SCSI_Data
	moveq.l	#8,d0
	move.l	d0,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	lea	64(a2),a1		;&command line
	move.l	a1,(a0)+		;SCSI_Command
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CamdActual
	move.b	#READCAPACITY,(a1)+
	clr.b	(a1)+
	clr.l	(a1)+
	clr.l	(a1)
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.l	(a0)			;SCSI_SenseLength und SCSI_SenseActual
	move.l	IORequest(a4),a1
	movem.l	d2-d7/a2-a5,-(sp)
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a5
	move.l	IORequest(a4),a1
	move.l	IO_Actual(a1),100(a2)

	lea	DG_Sizeof(a2),a0	;&SCSICmd
	move.l	IORequest(a4),a1
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	move.l	a0,IO_Data(a1)
	lea	128(a2),a1		;&InquiryData
	move.l	a1,(a0)+		;SCSI_Data
	moveq.l	#0,d0
	not.b	d0
	move.l	d0,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	lea	64(a2),a1		;&command line
	move.l	a1,(a0)+		;SCSI_Command
	move.b	#INQUIRY,(a1)+
	clr.b	(a1)+
	clr.w	(a1)+
	move.b	d0,(a1)+
	clr.b	(a1)
	moveq.l	#6,d0
	move.w	d0,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.l	(a0)+			;SCSI_SenseLength, SCSI_SenseActual
	move.l	IORequest(a4),a1
	movem.l	d2-d7/a2-a5,-(sp)
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a5
	move.l	IORequest(a4),a1
	move.l	IO_Actual(a1),104(a2)

;- - track or LBA mode calculations - - - - - - - - - - - -

	moveq.l	#63,d2			;typically 63,..
s_try:
	move.l	d2,TrackSize(a4)
	move.l	PartStart(a4),d0
	move.l	d2,d1
	bsr.w	UDivMod32
	tst.l	d1
	bne.s	s_t1

	move.l	FatStart(a4),d0
	move.l	d2,d1
	bsr.w	UDivMod32
	tst.l	d1
	bne.s	s_t1

	move.l	FatSize(a4),d0
	move.l	d2,d1
	bsr.w	UDivMod32
	tst.l	d1
	beq.s	s_rdb
s_t1:
	move.l	d2,d0
	moveq.l	#32,d2			;..32 Blocks/Track or..
	cmp.l	d2,d0
	bne.s	s_try

	moveq.l	#1,d0
	move.l	d0,TrackSize(a4)	;..LBA mode
s_rdb:

;- - rigid disk block - - - - - - - - - - - - - - - - - - -

	add.l	BlockSize(a4),a2	;&RDSK
	move.l	a2,a1			;&target
	move.l	#`RDSK`,(a1)+		;ID
	moveq.l	#64,d0
	move.l	d0,(a1)+		;SummedLongs
	addq.l	#8,a1			;ChkSum, HostID
	move.l	BlockSize(a4),(a1)+	;BlockBytes
	moveq.l	#$12,d0
	move.l	d0,(a1)+		;Flags
	moveq.l	#-1,d1
	move.l	d1,(a1)+		;BadBlockList
	moveq.l	#3,d0
	move.l	d0,(a1)+		;PartitionList
	moveq.l	#4,d0
	move.l	d0,(a1)+		;FileSysHeaderList
	move.l	d1,(a1)+		;DriveInit
	move.l	d1,(a1)+		;res1 * 6
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	move.l	TotalSectors(a4),d0
	move.l	TrackSize(a4),d1
	move.l	d1,d2			;Blocks/Track oder 1 (LBA)
	bsr.w	UDivMod32
	move.l	d0,(a1)+		;Cyls
	move.l	d2,(a1)+		;Secs
	moveq.l	#1,d1
	move.l	d1,(a1)+		;Heads
	move.l	d1,(a1)+		;Interleave
	addq.l	#1,d0
	move.l	d0,(a1)+		;Park
	lea	96(a2),a1
	moveq.l	#0,d0
	move.l	d0,(a1)+		;WritePrecomp
	move.l	d0,(a1)+		;ReducedWrite
	move.l	d0,(a1)+		;StepRate
	lea	128(a2),a1
	moveq.l	#2,d0
	move.l	d0,(a1)+		;RDBBlockLow
	move.l	PartStart(a4),d0
	subq.l	#1,d0
	move.l	d0,(a1)+		;RDBBlockHi
	addq.l	#1,d0
	move.l	d2,d1
	bsr.w	UDivMod32
	move.l	d0,(a1)+		;LoCyl
	move.l	TotalSectors(a4),d0
	move.l	d2,d1
	bsr.w	UDivMod32
	subq.l	#1,d0
	move.l	d0,(a1)+		;HiCyl
	move.l	d2,(a1)+		;CylBlocks
	moveq.l	#0,d0
	move.l	d0,(a1)+		;AutoParkSecs
	lea	160(a2),a1
	move.l	Buffer(a4),a0
	add.l	BlockSize(a4),a0	;&DriveGeometry
	add.w	#128+8,a0		;&InquiryData.Vendor
	moveq.l	#(8+16+4)/4,d0
s_rdskl1:
	move.l	(a0)+,(a1)+		;Vendor, Product, Version
	subq.w	#1,d0
	bgt.s	s_rdskl1

	;add checksum later, when RDSK complete

;- - partition block  - - - - - - - - - - - - - - - - - - -

	add.l	BlockSize(a4),a2	;&PART
	move.l	a2,a1
	move.l	#`PART`,(a1)+		;ID
	moveq.l	#64,d0
	move.l	d0,(a1)+		;SummedLongs
	addq.l	#8,a1			;ChkSum, HostID
	moveq.l	#-1,d0
	move.l	d0,(a1)+		;Next
	moveq.l	#1,d0
	move.l	d0,(a1)+		;Flags: (1 = bootable, 2 = don`t mount)
	moveq.l	#0,d0
	move.l	d0,(a1)+		;2*res1
	move.l	d0,(a1)+
	move.l	StartupMsg(a4),a0
	move.l	FSSM_Flags(a0),(a1)+	;DevFlags
	move.l	DevProc(a4),a0
	move.l	DVP_DevNode(a0),a0
	move.l	DL_Name(a0),d0
	lsl.l	#2,d0
	move.l	d0,a0
	moveq.l	#0,d0
	move.b	(a0),d0
	addq.w	#5,d0
	lsr.w	#2,d0
s_ploop1:
	move.l	(a0)+,(a1)+		;DevName
	subq.w	#1,d0
	bgt.s	s_ploop1

	lea	128(a2),a1
	move.l	StartupMsg(a4),a0
	move.l	FSSM_Environ(a0),d0
	lsl.l	#2,d0
	move.l	d0,a0			;&DosEnvec
	move.l	64(a0),DosType(a4)
	move.l	(a0)+,d1
	move.l	d1,(a1)+		;DosEnvec
s_ploop2:
	move.l	(a0)+,(a1)+
	subq.w	#1,d1
	bgt.s	s_ploop2

	move.l	FatStart(a4),d0
	move.l	d2,d1
	bsr.w	UDivMod32
	move.l	d0,128+DE_LowCyl(a2)
	move.l	FatStart(a4),d0
	add.l	FatSize(a4),d0
	move.l	d2,d1
	bsr.w	UDivMod32
	subq.l	#1,d0
	move.l	d0,128+DE_HighCyl(a2)	;convert to LBA
	moveq.l	#1,d0
	move.l	d0,128+DE_Surfaces(a2)
	move.l	d2,128+DE_BlocksPerTrack(a2)
	clr.l	128+DE_Control(a2)	;String cannot be passed that way

	move.l	a2,a1
	bsr.w	CheckSum

;- - file system header block - - - - - - - - - - - - - - -

	add.l	BlockSize(a4),a2	;&FSHD
	move.l	a2,a1
	move.l	#`FSHD`,(a1)+		;ID
	moveq.l	#64,d0
	move.l	d0,(a1)+		;SummedLongs
	addq.l	#8,a1			;ChkSum, HostID
	moveq.l	#-1,d0
	move.l	d0,(a1)+		;Next
	moveq.l	#0,d0
	move.l	d0,(a1)+		;Flags
	move.l	d0,(a1)+		;2*res1
	move.l	d0,(a1)+
	move.l	DosType(a4),(a1)+	;DosType
	move.l	DebugSource(a4),a0
	moveq.l	#0,d0
	move.b	4(a0),d0
	move.w	d0,(a1)+		;FS_Version
	move.b	5(a0),d0
	move.w	d0,(a1)+		;FS_Revision
	move.l	#$190,d0		;"patch fields 4 (StackSize),..
	move.l	d0,(a1)			;..7 (SegList) and 8 (GlobVec)"
	move.l	#4096,20(a1)		;DeviceNode.StackSize
	moveq.l	#5,d0
	move.l	d0,32(a1)		;DeviceNode.SegList (here: Block #)
	moveq.l	#-1,d0
	move.l	d0,36(a1)		;DeviceNode.GlobalVector
	;---------------
	move.l	a2,a1
	bsr.w	CheckSum

;- - load seg blocks  - - - - - - - - - - - - - - - - - - -

	add.l	BlockSize(a4),a2	;&LSEG
	move.l	FileName(a4),d1
	move.l	#ModeOldfile,d2
	CALLDOS	Open
	move.l	d0,FileHandle(a4)
	beq.w	s_nofile

	move.l	FileHandle(a4),d1
	move.l	a2,d2
	CALLDOS	ExamineFH
	tst.l	d0
	beq.w	s_nofile

	move.l	FIB_Size(a2),d4		;file length
	moveq.l	#-20,d5
	add.l	BlockSize(a4),d5	;space per LSEG Block
	moveq.l	#5,d6			;start at Block #5
s_floop:
	addq.l	#1,d6
	sub.l	d5,d4
	bgt.s	s_f1

	move.l	BlockSize(a4),d0
	lsl.l	#1,d0
	move.l	Buffer(a4),a1
	add.l	d0,a1			;RDSK
	move.l	d6,d0
	subq.l	#1,d0
	move.l	d0,152(a1)		;HighRDSKBlock
	bsr.w	CheckSum		;all done
	moveq.l	#-1,d6			;this is the last Block
	add.l	d4,d5
	moveq.l	#0,d4
s_f1:
	move.l	a2,a1
	move.l	#`LSEG`,(a1)+		;ID
	move.l	d5,d0
	lsr.l	#2,d0
	addq.l	#5,d0
	move.l	d0,(a1)+		;SummedLongs
	addq.l	#8,a1			;CheckSum, HostID
	move.l	d6,(a1)+		;Next
	move.l	FileHandle(a4),d1
	move.l	a1,d2
	move.l	d5,d3
	CALLDOS	Read
	move.l	a2,a1
	bsr.w	CheckSum
	add.l	BlockSize(a4),a2
	tst.l	d4
	bgt.s	s_floop
s_closefile:
	move.l	FileHandle(a4),d1
	CALLDOS	Close

;- - debug: file output - - - - - - - - - - - - - - - - - -

	lea	OutputName(pc),a0
	move.l	a0,d1
	move.l	#ModeNewfile,d2
	CALLDOS	Open
	move.l	d0,d4
	beq.s	s_testend

	move.l	d4,d1
	move.l	Buffer(a4),d2
	move.l	a2,d3
	sub.l	d2,d3
	CALLDOS	Write
	move.l	d4,d1
	CALLDOS	Close
s_testend:

;- - write to disk  - - - - - - - - - - - - - - - - - - - -

	move.l	BlockSize(a4),d3
	move.l	d3,d0
	lsl.l	#1,d0
	move.l	Buffer(a4),a2
	add.l	d0,a2			;&RDSK
	move.l	152(a2),d2		;HighRDSKBlock
	move.l	132(a2),d0		;RDBBlockHigh
	cmp.l	d2,d0
	bcs.w	s_nodiskspace

	move.l	IORequest(a4),a1
	move.w	#CMD_WRITE,IO_Command(a1)
	move.l	d3,d0
	lsl.l	#1,d0
	move.l	d0,IO_Offset(a1)
	clr.l	IO_Actual(a1)
	move.l	d2,d0
	subq.l	#1,d0			;+1-2
	move.l	d3,d1
	bsr.w	UMul32
	move.l	d0,IO_Length(a1)
	move.l	a2,IO_Data(a1)
	movem.l	d2-d7/a2-a5,-(sp)
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a5

	move.l	IORequest(a4),a1
	move.w	#CMD_UPDATE,IO_Command(a1)
	movem.l	d2-d7/a2-a5,-(sp)
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a5

;- - shut down  - - - - - - - - - - - - - - - - - - - - - -

s_freebuffer:
	move.l	BufSize(a4),d0
	move.l	Buffer(a4),a1
	CALLEXEC FreeMem
s_closedevice:
	move.l	IORequest(a4),a1
	CALLEXEC CloseDevice
s_freefssm:
	move.l	DevProc(a4),a0
	move.l	DVP_Port(a0),d1
	move.l	#ACTION_FREE_DISK_FSSM,d2
	move.l	StartupMsg(a4),d3
	moveq.l	#0,d4
	moveq.l	#0,d5
	CALLDOS	DoPkt
s_freedev:
	move.l	DevProc(a4),d1
	CALLDOS	FreeDeviceProc
s_freeio:
	move.l	IORequest(a4),a1
	bsr.w	FreeMsg
s_closeport:
	move.l	ReplyPort(a4),a1
	bsr.w	FreeMsgPort
s_closelib:
	move.l	DosBase(a4),a1
	CALLEXEC CloseLibrary
s_end:
	move.l	Result(a4),d0
	movem.l	(sp)+,d1-d5/a0-a2/a6
	unlk	a4
	rts

;- - error handling - - - - - - - - - - - - - - - - - - - -

s_nodiskspace:
	lea	NoDiskSpaceStr(pc),a0
	bsr.s	ReportError
	bra.s	s_freebuffer

s_nombr:
	lea	NoMBRStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closedevice

s_readerror:
	lea	ReadErrStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closedevice

s_nomem:
	lea	NoMemStr(pc),a0
	bsr.s	ReportError
	bra.s	s_closedevice

s_nodevice:
	bra.s	s_freefssm

s_nofile:
	lea	NoFileStr(pc),a0
	bsr.s	ReportError
	bra.w	s_freebuffer

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

;--- report errors -----------------------------------------
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

;--- set checksum ------------------------------------------
; a1 <- &Block

CheckSum:
	move.l	HostID(a4),12(a1)
	moveq.l	#0,d0
	move.l	d0,8(a1)
	move.l	4(a1),d1
	move.l	a1,a0
cs_loop:
	sub.l	(a0)+,d0
	subq.l	#1,d1
	bgt.s	cs_loop

	move.l	d0,8(a1)
	rts

;--- get parameters ----------------------------------------
; a0 <- &command line
; a1 <- &target buffer
; d0 -> # Parameters

GetDosParams:
	movem.l	a1-a2,-(sp)
	lea	40(a1),a2		;&strings
gdp_par:
	move.l	a2,(a1)+		;Vector field..
	moveq.l	#0,d2
gdp_char:
	move.b	(a0)+,d0
	cmp.b	#` `,d0
	beq.s	gdp_spc
	bcs.s	gdp_pend

	cmp.b	#`"`,d0
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
	cmp.b	#` `+1,(a0)
	bcc.s	gdp_write

	move.b	(a0)+,d0
gdp_pend:
	clr.b	(a2)+
	cmp.b	#` `,d0
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

;*** Exec supplements **************************************
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

		dc.b	`$VER: boot95 3.18 (01.03.2013)`,LF,0
DosName:	dc.b	`dos.library`,0
HelpStr:	dc.b	`Usage: boot95 <device> [<filesystem>]`,LF,0
DefFileName:	dc.b	`L:fat95`,0
OutputName:	dc.b	`ram:boot95.log`,0
NoDevStr:	dc.b	`Device not found.`,LF,0
NoFileStr:	dc.b	`Could not get source file.`,LF,0
NoInfoStr:	dc.b	`Debug info not available.`,LF,0
NoMemStr:	dc.b	`Not enough memory.`,LF,0
ReadErrStr:	dc.b	`Read error in block 0.`,LF,0
NoMBRStr:	dc.b	`PC master boot record not found.`,LF,0
NoDiskSpaceStr:	dc.b	`Not enough disk space for RDSK chain.`,LF,0
		even

;*** Das war`s!!! ******************************************
	end

