; FAT95 file system handler for AmigaOS
; Copyright (C) 2013  Torsten Jager <t.jager@gmx.de>
; This file is part of FAT95, a free FAT compatible file system for Amiga.
;
; This handler is free software; you can redistribute it and/or
; modify it under the terms of the GNU Lesser General Public
; License as published by the Free Software Foundation; either
; version 2.1 of the License, or (at your option) any later version.
;
; This handler is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; Lesser General Public License for more details.
;
; You should have received a copy of the GNU Lesser General Public
; License along with this library; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

; --- Includes ---
	include	"fat95_version.i"

;--- from exec.library -------------------------------------

CALLEXEC macro
	move.l	ExecBase(a4),a6
	jsr	\1(a6)
	endm

CALLSAME macro
	jsr	\1(a6)			;same library as last CALLxxx
	endm

; --- 32-bit math: inline on 68020+, bsr to helper on 68000 ---
; The helper bodies (UMul32 / UDivMod32 / Log2) are compiled out of
; the 020+ binary via `ifnd __68020__` below.

UMUL32	macro				;d0 = d0 * d1 (u32)
	ifd	__68020__
	mulu.l	d1,d0
	else
	bsr.w	UMul32
	endif
	endm

UDIVMOD32 macro				;d0 = d0/d1, d1 = d0 mod d1 (u32)
	ifd	__68020__
	divul.l	d1,d1:d0
	else
	bsr.w	UDivMod32
	endif
	endm

LOG2	macro				;d0 = log2(d0), d0 != 0
	ifd	__68020__
	bfffo	d0{0:32},d0
	eori.w	#31,d0
	else
	bsr.w	Log2
	endif
	endm

_AbsExecBase	= 4

Forbid		= -132
Permit		= -138
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
ReplyMsg	= -378
WaitPort	= -384
CloseLibrary	= -414
OpenDevice	= -444
CloseDevice	= -450
DoIO		= -456
SendIO		= -462
CheckIO		= -468
WaitIO		= -474
OpenResource	= -498
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
MEMF_NORM	= 0
MEMF_PUBLIC	= 1
MEMF_CLEAR	= $10000

;struct Library
LIB_Version	= 20

;device vectors
BeginIO		= -30

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

;--- from utility.library ----------------------------------

;struct Hook
H_MinNode	= 0
H_Entry		= 8
H_SubEntry	= 12
H_Data		= 16
H_Sizeof	= 20

;Tags
TAG_DONE	= 0

;--- from graphics.library ---------------------------------

CALLGRAF macro
	move.l	GrafBase(a4),a6
	jsr	\1(a6)
	endm

Text		= -60
SetFont		= -66
Move		= -240
RectFill	= -306
SetAPen		= -342
GetScreenDrawInfo = -690
FreeScreenDrawInfo = -696

;struct RastPort
RP_APen		= 25
RP_BPen		= 26
RP_Font		= 52
RP_TxHeight	= 58
RP_TxBaseline	= 62

;struct DrawInfo
DRI_NumPens	= 2
DRI_Pens	= 4

;DRI_Pens
TEXTPEN		= 4
SHINEPEN	= 6
SHADOWPEN	= 8
FILLPEN		= 10
FILLTEXTPEN	= 12
BACKGROUNDPEN	= 14

;--- from intuition.library --------------------------------

CALLINT	macro
	move.l	IntBase(a4),a6
	jsr	\1(a6)
	endm

CloseWindow	= -72
LockPubScreen	= -510
UnlockPubScreen	= -516
OpenWindowTagList = -606

;OpenWindow Tags
WA_Left		= $80000064
WA_Top		= $80000065
WA_Width	= $80000066
WA_Height	= $80000067
WA_IDCMP	= $8000006a
WA_Flags	= $8000006b
WA_Title	= $8000006e
WA_CustomScreen	= $80000070
WA_Activate	= $80000089

;struct screen
SCR_Width	= 12
SCR_Height	= 14
SCR_BarHeight	= 30
SCR_WBorTop	= 35
SCR_WBorLeft	= 36
SCR_WBorRight	= 37
SCR_WBorBottom	= 38
SCR_RastPort	= 84

;struct Window
WIN_Width	= 8
WIN_Height	= 10
WIN_Flags	= 24
WIN_Screen	= 46
WIN_RastPort	= 50
WIN_BorderLeft	= 54
WIN_BorderTop	= 55
WIN_BorderRight	= 56
WIN_IDCMPFlags	= 82
WIN_UserPort	= 86

;WIN_Flags
WFLG_DRAGBAR	   = 2
WFLG_DEPTHGADGET   = 4
WFLG_CLOSEGADGET   = 8
WFLG_SMART_REFRESH = 0
WFLG_ACTIVATE	   = $1000

;WIN_IDCMPFlags
IDCMP_GADGETDOWN  = $20
IDCMP_GADGETUP	  = $40
IDCMP_CLOSEWINDOW = $200
IDCMP_RAWKEY	  = $400
IDCMP_VANILLAKEY  = $200000

;struct IntuiMessage
IM_Message	= 0
IM_Class	= 20
IM_Code		= 24
IM_Qualifier	= 26
IM_IAddress	= 28
IM_MouseX	= 32
IM_MouseY	= 34
IM_Seconds	= 36
IM_Micros	= 40
IM_IDCMPWindow	= 44
IM_Sizeof	= 48

;struct IntuiText
IT_X		= 4
IT_Y		= 6
IT_TextFont	= 8
IT_String	= 12
IT_Next		= 16
IT_Sizeof	= 20

CR		= 13
LF		= 10

KEY_ESC		= 27

;--- from dos.library --------------------------------------

CALLDOS	macro
	move.l	DosBase(a4),a6
	jsr	\1(a6)
	endm

UnloadSeg	= -156
DateStamp	= -192
MatchPatternNoCase = -972

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
DE_SizeBlock	= 4			;in longwords
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
ID_NONE		= -1			;no disk inserted
ID_BUSY		= "BUSY"		;inhibited
ID_BAD		= "BAD"<<8		;unreadable
ID_NDOS		= "NDOS"		;readable but incomprehensible
ID_DOS		= "DOS"<<8		;valid

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

;DOL_Type values
DLT_VOLUME	= 2

;DOS error codes for ErrorNum
;0	OK
;103	insufficient memory
;115	invalid count
;202	object still in use
;203	object already exists
;205	no such channel
;209	unknown DosPacket command
;212	directory instead of file or vice versa
;213	disk not validated
;214	disk read only
;216	directory not empty
;218	this disk not mounted
;219	invalid file seek position
;221	disk full
;222	file protected from deletion
;223	file write protected
;225	disk malformatted
;226	no disk
;232	no further directory entries

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
FIB_Private	 = 220			;internal use only
FIB_OwnerUID	 = 224
FIB_OwnerGID	 = 226
FIB_Sizeof	 = 260

;struct ExAllControl
EAC_Entries	= 0
EAC_LastKey	= 4
EAC_MatchString	= 8
EAC_MatchFunc	= 12
EAC_Sizeof	= 16

;struct ExAllData
ED_Next		= 0
ED_Name		= 4
ED_Type		= 8
ED_Size		= 12
ED_Prot		= 16
ED_Days		= 20
ED_Mins		= 24
ED_Ticks	= 28
ED_Comment	= 32
ED_OwnerUID	= 36
ED_OwnerGID	= 38
ED_Sizeof	= 40

;struct InfoData
ID_NumSoftErrors =  0
ID_UnitNumber	 =  4
ID_DiskState	 =  8
ID_NumBlocks	 = 12
ID_BlocksUsed	 = 16
ID_BytesPerBlock = 20
ID_DiskType	 = 24
ID_VolumeNode	 = 28
ID_InUse	 = 32
ID_Sizeof	 = 36

TRUE		= -1
FALSE		= 0

;--- from filesystem.resource ------------------------------

;struct FileSystemResource
FSR_IdString	= 14
FSR_List	= 18
FSR_Sizeof	= 30

;struct FileSystemEntry
FSE_DosType	= 14
FSE_Version	= 18
FSE_Revision	= 20
FSE_PatchFlags	= 22
FSE_Type	= 26
FSE_Task	= 30
FSE_Lock	= 34
FSE_Handler	= 38
FSE_StackSize	= 42
FSE_Priority	= 46
FSE_Startup	= 50
FSE_SegList	= 54
FSE_GlobVec	= 58
FSE_MySizeof	= 62

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

;commands
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

;commands
HD_SCSICMD	= 28

;SCSI commands
TESTUNITREADY	= $00
REQUESTSENSE	= $03
READCAPACITY	= $25
READ10		= $28
WRITE10		= $2a

;--- from timer.device -------------------------------------

;library functions
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

;--- from input.device -------------------------------------

;struct InputEvent
IE_NextEvent	= 0
IE_Class	= 4
IE_SubClass	= 5
IE_Code		= 6
IE_Qualifier	= 8
IE_Addr		= 10
IE_TimeStamp	= 14
IE_Sizeof	= 22

;IE_Class
IECLASS_DISKREMOVED	= 15
IECLASS_DISKINSERTED	= 16

;IE_Qualifier
IEQUAL_MULTIBROADCAST	= $800

;commands
IND_WRITEEVENT	= 11

;--- private data struktures & definitions -----------------

;determine FAT Type
MINCLUSTERS16	= $ff7-2		;$ff7 = "bad FAT12 cluster"
MINCLUSTERS32	= $fff7-2		;$fff7 = "bad FAT16 cluster"

;struct FAT32Buffer
F32B_Node	= 0
F32B_Start	= 8
F32B_Flags	= 12
F32B_Data	= 16
F32B_Sizeof	= $4010

;struct ExtDosList
XDOL_XLockList	= DOL_Sizeof
XDOL_Name	= DOL_Sizeof+12
XDOL_Sizeof	= DOL_Sizeof+28

;struct DiskKey
DKEY_BlockNum	= 0
DKEY_Offset	= 4
DKEY_Sizeof	= 6

;struct MSDirEntry		MS-DOS directory entry
MSDE_Name	= 0		;8 chars, space padded
MSDE_Ext	= 8		;dto., 3 chars name extension
MSDE_Flags	= 11
MSDE_unused1	= 12
MSDE_CheckSum	= 13		;only in extended entries
MSDE_CMilSecs	= 13		;only in standard entries, ms/10
MSDE_CTime	= 14		;creation time
MSDE_CDate	= 16
MSDE_ADate	= 18		;last access date
MSDE_1H		= 20		;FAT32: high word for MSDE_1L
MSDE_Time	= 22		;hour<<11 + minute<<5 + second/2
MSDE_Date	= 24		;(year-1980)<<9 + month<<5 + day
MSDE_1L		= 26		;# 1. cluster of file or directory table
MSDE_FSize	= 28		;file size in bytes (unsigned)
MSDE_Sizeof	= 32

MAXNAMELEN	= 104		;per file or directory

;struct ExtMSDirEntry
XMSDE_Key	= 32		;location of standard entry
XMSDE_Offset	= 36
XMSDE_ExtKey	= 38		;location of first extended entry or 0
XMSDE_ExtOffset = 42
XMSDE_unused	= 44
XMSDE_ExtNum	= 46		;count of extended entries
XMSDE_FNCheck	= 47		;checksum for extended entries
XMSDE_FNLength	= 48		;long name as both BStr and CStr
XMSDE_FullName	= 49		;room for 8 extensions (8*13+3 chars)
XMSDE_Sizeof	= 156		;longword aligned

;MSDE_Name[0] special values
MSDEB_UNUSED	= 0		;never used before (no need to scan further)
MSDEB_DELETED	= $e5		;deleted

;MSDE_Flags
;0 = protected from writing and deleting
;1 = hidden (1 & 2 maybe swapped)
;2 = system
;3 = volume name and date
;4 = subdirectory
;5 = not archived

;struct XLock
XL_Node		= 0		;struct MinNode
XL_OpenCnt	= 8		;<0 when opened exclusively
XL_Flags	= 10		;see below
XL_Parent	= 12		;struct XLock *parent
XL_Volume	= 16		;struct DosList *Volume
XL_FilePos	= 20		;highest seen byte offs..
XL_FileChain	= 24		;..and cluster
XL_MSDE		= 28		;struct ExtMSDirEntry
XL_Key		= XL_MSDE+XMSDE_Key
XL_Offset	= XL_MSDE+XMSDE_Offset
XL_Sizeof	= XL_MSDE+XMSDE_Sizeof

;XL_Flags
;bit #	15	= "there are open and changed files in this directory"

;special LocateObj() modes (yyy_MODE & xxx_LOCK)
CREATE_MODE	= $7fffffff	;create if nonexistant
FORCE_MODE	= $3fffffff	;create always
INTERNAL_MODE	= $dfffffff	;allow multiple opens of exclusive locks

;struct FileHandleExtension	;pointer to that in FH_Arg1
XFH_Node	= 0
XFH_XLock	= 8
XFH_CurrentPos	= 12
XFH_Cluster	= 16
XFH_Changed	= 20		;0 or 1
;22.w unused
XFH_Sizeof	= 24

;struct BlockBuffer
BB_Node		= 0		;struct MinNode for chaining in BlockList
BB_BlockNum	= 8		;0 = start of volume
BB_Blocks	= 12
;16.l unused
BB_OpenCnt	= 20		;access count; Bit 15 = "changed"
BB_Flags	= 22		;Bit 1 = "directory buffer"
				;Bit 2 = "root directory"
				;Bit 3 = "single block"
BB_DirtyFlags	= 24
BB_Data		= 40		;block contents here

;NewFlags - deferred operations:
;Bit	0 = turn off motor (floppy/ZIP drives only)
;	1 = do ETD_UPDATE
;	2 = write user data
;	3 = write FAT

;*** Global vars *******************************************

;Debug Info
DebugSize	=   0
DebugVersion	=   4
;6.w unused

;system linkage
DosBase		=   8
DeviceNode	=  12
VolumeNode	=  16
StartupMsg	=  20

DosPacket	=  24
pr_MsgPort	=  28
ReplyPort	=  32
SignalSet	=  36

ExecBase	=  40
IntBase		=  44
TimeRequest	=  48

;mfm.device
DevName		=  52
UnitNumber	=  56
DeviceFlags	=  60
DiskRequest	=  64
DiskReq2	=  68
ReadCmd		=  72		;also longword with WriteCmd
WriteCmd	=  74
UpdateCmd	=  76
CmdFlags	=  78
QueryResult	=  80		;embedded struct NSDeviceQueryResult

;CmdFlags
;$0001	ETD_ commands available
;$0002  TD64 commands available
;$0004	SCSI mode active
;$0008	do use CMD_UPDATE
;$0010	TJ commands available
;$0100  show extra date stamps as file comments
;$0200  store last read date
;$0400	convert short names to lowercase
;$0800	dito, including initial

;logical partition layout
BlockSize	=  96
BlockShift	=  98		;log2(Bytes/Block)
BlockMask	= 100		;Byte mask
FirstBlock	= 104		;partition offset from media start
TotalBlocks	= 108		;Partition size
HiddenBlocks	= 112		;offset from partition table instance or 0
PartitionNum	= 116		;0 for unpartitioned media
BlocksPerTrack	= 118
Surfaces	= 120
NumFATCopies	= 122
BlocksPerCluster = 123
RootDirEntries	= 124
FATStartBlock	= 126
BlocksPerFAT	= 128
RootStartBlock	= 132
RootDirEnd	= 136
LastCluster	= 140
ClusterShift	= 144		;log2(Blocks/Cluster)
ClusterSniff	= 146		;# blocks in last cluster if smaller
ClusterSize	= 148
ClusterMask	= 152		;Byte mask
ClusterBlockMask = 156		;block number mask
RootCluster	= 160
FSInfoBlock	= 164
BootSignature	= 168

;partition search
LastReadBlock	= 172
LastReadError	= 176
SearchCount	= 177
SearchMode	= 178
;179.b unused

;physikal media layout
PhysSize	= 180		;device access pattern
PhysShift	= 184		;log2(Blocks/Sector)
PhysFlags	= 186
TotalSectors	= 188
Cylinders	= 192
CylSectors	= 196

;File Allocation Table
FATBuffer	= 200
FATBufSize	= 204		;in bytes and in..
FATBNum		= 208		;..blocks (per segment for FAT32)
FATFlags	= 212
FATType		= 216		;0 = 12 bit, 1 = 16 bit, -1 = 32 bit, 2 = auto
;218.w unused
FAT32List	= 220		;embedded struct List

;Block buffer
BufList		= 232		;embedded struct List
NormBufsUsed	= 244		;dont reorder these 4!!!
NormBufsNum	= 246
DirBufsUsed	= 248
DirBufsMin	= 250
SingleBuf	= 252
SingleSize	= 256

;XLock`s
RootXLock	= 260
NewObject	= 264

;FileHandleExtensions
FileList	= 268		;embedded struct List

;volume properties
SerialNum	= 280
DiskType	= 284
DiskState	= 288
FreeClusters	= 292
NextFreeCluster	= 296		;scan for free clusters starting here
LastVolName	= 300		;14 chars

;status flags
ErrorNum	= 314		;0 (OK) or DOS error #
InhibitNest	= 316		;INHIBITED
DiskChanged	= 318
NewFlags	= 320
NoRequest	= 322		;suppress requester
PleaseUnmount	= 324
SoftLocked	= 326		;write protection..
PassKey		= 328		;..with key
NumLocks	= 332

;background activity
BackgroundJob	= 336
BackgroundData	= 340

;private DosEnvec duplicate
EnvecBuf	= 344
NumBuffers	= EnvecBuf+DE_NumBuffers+2
BufMemType	= EnvecBuf+DE_BufMemType
DosType		= EnvecBuf+DE_DosType

;Interrupt-Server
ChangeInt	= 424		;embedded struct Interrupt

;report disk change
InputRequest	= 448
InputEvent	= 452		;embedded struct InputEvent

;direct SCSI
SCSIStruct	= 476
SCSICmdLine	= 508
SCSIBuffer	= 524

;progress display
GrafBase	= 528

;user interface texts
UIText		= 532

;unicode maps
CodePage	= 596
InvCodeLen	= 600
InvCodePage	= 604

;OEM charset maps
OemPage		= 608
InvOemPage	= 612

;SCSI Sense data
SenseBuffer	= 616

;total size
VarsSizeof	= 874

;*** Here we go!! ******************************************

S_GLOBALS	= -4

Start:
	bra.s	s_start
s_resident:
	dc.w	RTC_MATCHWORD
	dc.l	s_resident
	dc.l	CodeEnd
	dc.b	0, FILE_VERSION, 0, 0
	dc.l	NodeName
	dc.l	IDStr
	dc.l	InitCode
	dc.l	UIModule-Start		;extra info for Install95
s_start:
	link.w	a5,#S_GLOBALS
	movem.l	d2/a2-a4,-(sp)

	moveq.l	#(VarsSizeof+15)>>4,d2
	lsl.l	#4,d2
	move.l	d2,d0
	move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
	move.l	(_AbsExecBase).w,a6
	jsr	AllocMem(a6)
	move.l	d0,a4			;do not change this anymore!!!
	move.l	d0,S_GLOBALS(a5)
	beq.w	s_end			;no space for global vars

	move.l	d2,(a4)			;DebugSize
	move.w	#FILE_VERSION<<8+FILE_REVISION,DebugVersion(a4)
	move.l	(_AbsExecBase).w,ExecBase(a4)
	lea	IDStr(pc),a1
	move.l	a1,ChangeInt+LN_Name(a4)
	move.l	a4,ChangeInt+IS_Data(a4)
	lea	IntCode(pc),a0
	move.l	a0,ChangeInt+IS_Code(a4) ;InterruptServer init
	lea	FileList(a4),a0
	bsr.w	InitList

	lea	UIModule(pc),a2		;&configuration list
s_uiscan:
	move.l	(a2)+,d0		;data type
	beq.s	s_uidone

	move.l	(a2)+,d1		;data size
	move.l	a2,a0			;&data
	add.l	d1,a2
	cmp.l	#"unic",d0
	beq.s	s_uiunicode

	cmp.l	#"oem ",d0
	beq.s	s_uioem

	cmp.l	#"loca",d0
	bne.s	s_uiscan		;skip unknown chunk
s_uilocale:
	lea	UIText(a4),a1
s_uit1:
	moveq.l	#0,d0
	move.b	(a0)+,d0
	beq.s	s_uiscan

	cmp.w	#NUMUITEXTS+1,d0
	bcc.s	s_uit2

	subq.l	#1,d0
	lsl.l	#2,d0
	move.l	a0,(a1,d0.l)		;connect user texts
s_uit2:
	tst.b	(a0)+
	bne.s	s_uit2
	bra.s	s_uit1
s_uiunicode:
	move.l	a0,CodePage(a4)		;activate char map
	bra.s	s_uiscan
s_uioem:
	move.l	a0,OemPage(a4)
	bra.s	s_uiscan
s_uidone:
	bsr.w	InvertCodePage

	lea	DefaultEnvec(pc),a0	;load defaults
	lea	EnvecBuf(a4),a1
	moveq.l	#19,d1
	move.l	d1,(a1)+		;DE_TableSize
s_envfill:
	move.b	(a0)+,d0
	ext.w	d0
	ext.l	d0
	move.l	d0,(a1)+
	subq.w	#1,d1
	bgt.s	s_envfill

	move.w	#128,EnvecBuf+DE_SizeBlock+2(a4)
	move.l	#"FAT"<<8,EnvecBuf+DE_DosType(a4)
	lea	MfmDevName(pc),a0
	move.l	a0,DevName(a4)

	moveq.l	#0,d0
	lea	DosName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,DosBase(a4)
	sub.l	a1,a1
	CALLEXEC FindTask
	moveq.l	#$5c,d2
	add.l	d0,d2
	move.l	d2,pr_MsgPort(a4)

	move.l	d2,a0
	CALLEXEC WaitPort
	move.l	d2,a0
	CALLEXEC GetMsg
	move.l	d0,a0			;&StartupMsg
	move.l	LN_Name(a0),a2		;&DosPacket
	move.l	DP_Arg3(a2),d0
	lsl.l	#2,d0
	move.l	d0,DeviceNode(a4)

	move.l	d0,a0
	move.l	DOL_Startup(a0),d0
	beq.s	s_2

	lsl.l	#2,d0
	move.l	d0,StartupMsg(a4)
	move.l	d0,a0			;&FileSysStartupMsg
	move.l	(a0),UnitNumber(a4)
	move.l	FSSM_Flags(a0),DeviceFlags(a4)
	move.l	FSSM_Device(a0),d0
	beq.s	s_1

	lsl.l	#2,d0
	addq.l	#1,d0
	move.l	d0,DevName(a4)
s_1:
	move.l	FSSM_Environ(a0),d0
	beq.s	s_2

	lsl.l	#2,d0
	move.l	d0,a0			;&DosEnvec, contains MountList info
	lea	EnvecBuf(a4),a1
	bsr.w	CopyDosEnvec
s_2:
	tst.l	EnvecBuf+DE_LowCyl(a4)	;partition not at media start..
	sne	d0
	move.b	d0,SearchMode(a4)	;..= "auto mode OFF"
	bsr.w	OpenAll
	move.l	d0,DP_Res2(a2)		;error code
	beq.s	s_openok

	clr.l	DP_Res1(a2)
	move.l	a2,a0
	bsr.w	ReplyDosPacket
	bra.w	s_exit

s_openok:
	move.l	DosType(a4),d0
	move.l	ExecBase(a4),a6
	bsr.w	RegisterFS		;allow sharing of code
	move.l	DeviceNode(a4),a0
	move.l	pr_MsgPort(a4),DOL_Task(a0)
	moveq.l	#-1,d0
	move.l	d0,DP_Res1(a2)
	move.l	a2,a0
	bsr.w	ReplyDosPacket		;return StartupMsg
	pea	ChangeInt(a4)
	bsr.w	DiskAddChInt		;enable disk change reports
	addq.l	#4,sp
	bsr.w	OpenDisk		;recognize disk
s_wait:
	move.l	SignalSet(a4),d0
	CALLEXEC Wait			;wait for order, disk change..
	tst.w	DiskChanged(a4)		;..or Timeout
	beq.s	s_getmsg

	bsr.w	IdentifyDisk
s_getmsg:
	move.l	S_GLOBALS(a5),a4	;safety
	move.l	pr_MsgPort(a4),a0
	CALLEXEC GetMsg			;receive order
	tst.l	d0
	beq.w	s_nomsg			;no order

	move.l	d0,a0
	move.l	LN_Name(a0),a2		;&DosPacket
	move.l	a2,DosPacket(a4)	;for DoRequest()
	tst.w	DiskChanged(a4)
	beq.s	s_domsg

	bsr.w	IdentifyDisk
s_domsg:
	clr.l	DP_Res2(a2)		;default status
	clr.w	ErrorNum(a4)
	move.l	DP_Type(a2),d0		;command #

	subq.l	#5,d0
	bcs.s	s_unknown

	moveq.l	#35-5,d1
	cmp.l	d1,d0
	bcs.s	s_jump

	moveq.l	#82-5,d1
	cmp.l	d1,d0
	beq.w	Action82

	moveq.l	#87-5,d1
	cmp.l	d1,d0
	beq.w	Action87

	sub.l	#1004-35,d0
	bcs.s	s_unknown

	moveq.l	#35-5,d1
	cmp.l	d1,d0
	bcs.s	s_unknown

	moveq.l	#1036+35-1004-5,d1
	cmp.l	d1,d0
	bcs.s	s_jump

	sub.l	#4200-1036,d0
	bcs.s	s_unknown

	cmp.l	d1,d0
	bcs.s	s_unknown

	moveq.l	#4203+1036+35-4200-1004-5,d1
	cmp.l	d1,d0
	bcc.s	s_unknown
s_jump:
	lea	s_tab(pc),a0
	lsl.l	#1,d0
	add.w	(a0,d0.l),a0
	jmp	(a0)
s_unknown:
	move.w	#209,ErrorNum(a4)	;"unsupported"
	moveq.l	#FALSE,d0
s_return:
	move.l	d0,DP_Res1(a2)		;...continue here
	move.w	ErrorNum(a4),d0
	beq.s	s_timer

	ext.l	d0
	move.l	d0,DP_Res2(a2)
s_timer:
	tst.w	NewFlags(a4)
	beq.s	s_reply

	bsr.w	DoTimer
s_reply:
	move.l	a2,a0
	bsr.w	ReplyDosPacket
	clr.l	DosPacket(a4)
	bra.w	s_getmsg

s_nomsg:
	move.l	BackgroundJob(a4),d1	;if no orders..
	beq.s	s_3

	move.l	d1,a1
	jsr	(a1)			;..do background jobs
	bra.w	s_getmsg
s_3:
	move.l	TimeRequest(a4),a1
	CALLEXEC CheckIO
	tst.l	d0
	beq.s	s_4			;no idle timeout yet

	tst.w	NewFlags(a4)
	beq.s	s_4			;no deferred work

	clr.l	-(sp)
	bsr.w	UpdateDisk
	addq.w	#4,sp
	bra.w	s_getmsg
s_4:
	tst.w	PleaseUnmount(a4)
	beq.w	s_wait			;no unmount requested

	tst.l	NumLocks(a4)
	bne.w	s_wait			;we are still referenced

	tst.w	PhysFlags(a4)
	beq.s	s_5

	bsr.w	CloseDisk		;unmount
	bsr.w	DoTimer
	bra.w	s_wait
s_5:
	move.l	TimeRequest(a4),a1
	CALLEXEC CheckIO
	tst.l	d0
	beq.w	s_wait			;no idle timeout

	bsr.w	_Forbid			;stop incoming orders
	moveq.l	#MP_MsgList,d0
	add.l	pr_MsgPort(a4),d0
	move.l	d0,a0
	addq.l	#4,d0
	cmp.l	(a0),d0
	beq.s	s_6

	bsr.w	_Permit			;we are not done...
	bra.w	s_getmsg
s_6:
	move.l	DeviceNode(a4),a0
	clr.l	DOL_Task(a0)		;unregister MsgPort
	bsr.w	_Permit
	bsr.w	DiskRemChInt
	bsr.w	CloseAll
s_exit:
	move.l	DosBase(a4),a1
	CALLEXEC CloseLibrary
	bsr.w	FreeInvTables		;free charset

	moveq.l	#(VarsSizeof+15)>>4,d0
	lsl.l	#4,d0
	move.l	a4,a1
	CALLEXEC FreeMem		;free global vars
s_end:
	moveq.l	#0,d0
	movem.l	(sp)+,d2/a2-a4
	unlk	a5
	rts

DefaultEnvec:
	dc.b	0, 0, 2, 2, 9, 0, 0, 0
	dc.b	0, 79, 5, MEMF_PUBLIC, -1, -2, 0, 0
	dc.b	0, 0, 1
DosName:
	dc.b	'dos.library',0
MfmDevName:
	dc.b	'mfm.device',0
	even

s_tab:
	dc.w	Action5-s_tab		;Action5 to Action34
	dc.w	s_unknown-s_tab
	dc.w	Action7-s_tab
	dc.w	Action8-s_tab
	dc.w	Action9-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action15-s_tab
	dc.w	Action16-s_tab
	dc.w	Action17-s_tab
	dc.w	Action18-s_tab
	dc.w	Action19-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action21-s_tab
	dc.w	Action22-s_tab
	dc.w	Action23-s_tab
	dc.w	Action24-s_tab
	dc.w	Action25-s_tab
	dc.w	Action26-s_tab
	dc.w	Action27-s_tab
	dc.w	Action28-s_tab
	dc.w	Action29-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action31-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action33-s_tab
	dc.w	Action34-s_tab

	dc.w	Action1004-s_tab	;Action1004 to Action1035
	dc.w	Action1005-s_tab
	dc.w	Action1006-s_tab
	dc.w	Action1007-s_tab
	dc.w	Action1008-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action1020-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action1022-s_tab
	dc.w	Action1023-s_tab
	dc.w	s_unknown-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action1026-s_tab
	dc.w	Action1027-s_tab
	dc.w	Action1028-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action1030-s_tab
	dc.w	Action1031-s_tab
	dc.w	s_unknown-s_tab
	dc.w	Action1033-s_tab
	dc.w	Action1034-s_tab
	dc.w	Action1035-s_tab

	dc.w	Action4200-s_tab	;Action4200 to Action4202
	dc.w	Action4201-s_tab
	dc.w	Action4202-s_tab

;= = top level order service routines  = = = = = = = = = = =
;--- ACTION_DIE --------------------------------------------

Action5:
	move.w	#1,PleaseUnmount(a4)
	moveq.l	#FALSE,d0
	bra.w	s_return

;--- ACTION_CURRENT_VOLUME ---------------------------------

Action7:
	move.l	DP_Arg1(a2),d0
	bsr.w	CheckXFH		;if valid..
	tst.l	d0
	beq.s	a7_current

	move.l	d0,a0
	move.l	XFH_XLock(a0),a0
	move.l	XL_Volume(a0),d0	;..the disk containing this file
	bra.s	a7_ok
a7_current:
	move.l	VolumeNode(a4),d0	;otherwise, the current disk
a7_ok:
	lsr.l	#2,d0
	move.l	UnitNumber(a4),DP_Res2(a2)
	bra.w	s_return

;--- ACTION_LOCATE_OBJECT ----------------------------------

Action8:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Read
	move.l	d0,d2
	beq.s	a8_end

	move.l	DP_Arg3(a2),d0
	moveq.l	#EXCLUSIVE_LOCK,d1
	cmp.l	d0,d1
	beq.s	a8_1

	moveq.l	#SHARED_LOCK,d0
a8_1:
	move.l	d0,-(sp)
	move.l	DP_Arg2(a2),-(sp)
	move.l	d2,-(sp)
	move.l	d0,d2
	bsr.w	LocateObj
	add.w	#12,sp
	tst.l	d0
	beq.s	a8_end

	move.l	d2,-(sp)
	move.l	d0,-(sp)
	bsr.w	NewLock
	addq.w	#8,sp
a8_end:
	bra.w	s_return

;--- ACTION_RENAME_DISK ------------------------------------

Action9:
	moveq.l	#0,d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg1(a2),-(sp)
	bsr.w	RenameDisk
	addq.w	#4,sp
	bra.w	s_return

;--- ACTION_FREE_LOCK --------------------------------------

Action15:
	move.l	DP_Arg1(a2),d0
	lsl.l	#2,d0			;dont free..
	beq.s	a15_end			;..implicit root lock

	move.l	d0,a0
	move.l	FL_Key(a0),d2
	move.l	a0,-(sp)
	bsr.w	FreeLock
	addq.l	#4,sp
	move.l	d2,a1
	bsr.w	CloseXLock
a15_end:
	moveq.l	#TRUE,d0
	bra.w	s_return

;--- ACTION_DELETE_OBJECT ----------------------------------

Action16:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg2(a2),-(sp)
	move.l	d0,-(sp)
	bsr.w	DeleteObj
	addq.l	#8,sp
	bra.w	s_return

;--- ACTION_RENAME_OBJECT ----------------------------------

Action17:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Write
	move.l	d0,d2
	beq.w	s_return

	move.l	DP_Arg3(a2),d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg4(a2),-(sp)
	move.l	d0,-(sp)
	move.l	DP_Arg2(a2),-(sp)
	move.l	d2,-(sp)
	bsr.w	RenameObj
	add.w	#16,sp
	bra.w	s_return

;--- ACTION_MORE_CACHE -------------------------------------

Action18:
	move.l	DP_Arg1(a2),d0
	add.w	d0,NumBuffers(a4)
	bsr.w	CacheResize
	move.l	d0,d2
	bsr.w	ReportGeometry
	move.l	d2,d0
	bra.w	s_return

;--- ACTION_SET_PROTECT ------------------------------------

Action21:
	move.l	DP_Arg2(a2),d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg4(a2),-(sp)
	move.l	DP_Arg3(a2),-(sp)
	move.l	d0,-(sp)
	bsr.w	SetProtect
	add.w	#12,sp
	bra.w	s_return

;--- ACTION_CREATE_DIR -------------------------------------

Action22:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.s	a22_end

	move.l	DP_Arg2(a2),-(sp)
	move.l	d0,-(sp)
	bsr.w	MakeDir
	addq.w	#8,sp
	tst.l	d0
	beq.s	a22_end

	pea	(SHARED_LOCK).w
	move.l	d0,-(sp)
	bsr.w	NewLock
	addq.w	#8,sp
a22_end:
	bra.w	s_return

;--- ACTION_EXAMINE_OBJECT ---------------------------------

Action23:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Read
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg2(a2),d1
	lsl.l	#2,d1
	move.l	d1,-(sp)		;&FileInfoBlock
	move.l	d0,-(sp)		;&XLock
	bsr.w	ExamineKey
	addq.w	#8,sp
	bra.w	s_return

;--- ACTION_EXAMINE_NEXT -----------------------------------

Action24:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Read
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg2(a2),d1
	lsl.l	#2,d1
	move.l	d1,-(sp)		;&FileInfoBlock
	move.l	d0,-(sp)		;&XLock
	bsr.w	ExamineNext
	addq.w	#8,sp
	bra.w	s_return

;--- ACTION_DISK_INFO --------------------------------------

Action25:
	move.l	DP_Arg1(a2),d0
	lsl.l	#2,d0
	move.l	d0,-(sp)
	bsr.w	GiveDiskInfo
	addq.l	#4,sp
	bra.w	s_return

;--- ACTION_INFO -------------------------------------------

Action26:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Read
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg2(a2),d0
	lsl.l	#2,d0
	move.l	d0,-(sp)
	bsr.w	GiveDiskInfo
	addq.w	#4,sp
	bra.w	s_return

;--- ACTION_FLUSH ------------------------------------------

Action27:
	pea	(TRUE).w		;"write immediately"
	bsr.w	UpdateDisk
	addq.w	#4,sp
	bra.w	s_return

;--- ACTION_SET_COMMENT ------------------------------------

Action28:
	move.l	DP_Arg2(a2),d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.s	a28_end

	move.l	DP_Arg4(a2),-(sp)
	move.l	DP_Arg3(a2),-(sp)
	move.l	d0,-(sp)
	bsr.w	SetComment
	add.w	#12,sp
a28_end:
	bra.w	s_return

;--- ACTION_PARENT -----------------------------------------

Action29:
	move.l	DP_Arg1(a2),d0
	lsl.l	#2,d0			;&FileLock
	beq.s	a29_1

	move.l	d0,a0
	move.l	FL_Key(a0),d0
a29_1:
	move.l	d0,a0
	bsr.w	xParent
	tst.l	d0
	beq.s	a29_end

	pea	(SHARED_LOCK).w
	move.l	d0,-(sp)
	bsr.w	NewLock
	addq.w	#8,sp
a29_end:
	bra.w	s_return

;--- ACTION_INHIBIT ----------------------------------------

Action31:
	tst.l	DP_Arg1(a2)
	beq.s	a31_unlock

	addq.w	#1,InhibitNest(a4)
	bsr.w	CloseDisk
	move.l	#ID_BUSY,DiskType(a4)
	bra.s	a33_end

a31_unlock:				;DOS V36+ uses this..
	subq.w	#1,InhibitNest(a4)
	bgt.s	a33_end			;..instead of ACTION_DISK_CHANGE
	bmi.s	a33_reset

;--- ACTION_DISK_CHANGE ------------------------------------

Action33:
	bsr.w	IdentifyDisk
a33_reset:
	clr.w	InhibitNest(a4)
a33_end:
	moveq.l	#TRUE,d0
	bra.w	s_return

;--- ACTION_SET_DATE ---------------------------------------

Action34:
	move.l	DP_Arg2(a2),d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.w	s_return

	move.l	DP_Arg4(a2),-(sp)
	move.l	DP_Arg3(a2),-(sp)
	move.l	d0,-(sp)
	bsr.w	SetFileDate
	add.w	#12,sp
	bra.w	s_return

;--- ACTION_READ -------------------------------------------

Action82:
	move.l	DP_Arg3(a2),-(sp)	;length
	move.l	DP_Arg2(a2),-(sp)	;&data
	move.l	DP_Arg1(a2),-(sp)	;FH_Arg1 = &FileHandleExtension
	bsr.w	ReadFromFile
	add.w	#12,sp
	bra.w	s_return

;--- ACTION_WRITE ------------------------------------------

Action87:
	move.l	DP_Arg3(a2),-(sp)	;length
	move.l	DP_Arg2(a2),-(sp)	;&data
	move.l	DP_Arg1(a2),-(sp)	;FH_Arg1 = &FileHandleExtension
	bsr.w	WriteToFile
	add.w	#12,sp
	bra.w	s_return

;--- ACTION_FINDOUTPUT -------------------------------------

Action1006:
	move.l	DP_Arg2(a2),d0
	bsr.w	Ok2Write
	tst.l	d0
	beq.w	s_return

;--- ACTION_FINDUPDATE and ACTION_FINDINPUT ----------------

Action1005:
Action1004:
	move.l	DP_Arg2(a2),d0
	bsr.w	Ok2Read
	tst.l	d0
	beq.s	a1004_end

	move.l	DP_Type(a2),-(sp)
	move.l	DP_Arg3(a2),-(sp)
	move.l	d0,-(sp)
	bsr.w	OpenFile
	add.w	#12,sp
	tst.l	d0			;&FileHandleExtension
	beq.s	a1004_end

	move.l	DP_Arg1(a2),d1
	lsl.l	#2,d1
	move.l	d1,a0			;&FileHandle supplied by dos.library
	move.l	d0,FH_Arg1(a0)
	addq.l	#1,NumLocks(a4)		;1 more lock
	moveq.l	#TRUE,d0
a1004_end:
	bra.w	s_return

;--- ACTION_END --------------------------------------------

Action1007:
	move.l	DP_Arg1(a2),-(sp)	;copy of FH_Arg1
	bsr.w	CloseFile
	addq.l	#4,sp
	bra.w	s_return

;--- ACTION_SEEK -------------------------------------------

Action1008:
	move.l	DP_Arg3(a2),-(sp)	;mode
	move.l	DP_Arg2(a2),-(sp)	;position
	move.l	DP_Arg1(a2),-(sp)	;FH_Arg1 = &FileHandleExtension
	bsr.w	SeekFilePos
	add.w	#12,sp
	bra.w	s_return

;--- ACTION_FORMAT -----------------------------------------

Action1020:
	move.l	DP_Arg2(a2),-(sp)
	move.l	DP_Arg1(a2),-(sp)
	bsr.w	FormatDisk
	addq.w	#8,sp
	bra.w	s_return

;--- ACTION_SET_FILE_SIZE ----------------------------------

Action1022:
	move.l	DP_Arg3(a2),-(sp)
	move.l	DP_Arg2(a2),-(sp)
	move.l	DP_Arg1(a2),-(sp)
	bsr.w	SetFileSize
	add.w	#12,sp
	bra.w	s_return

;--- ACTION_WRITE_PROTECT ----------------------------------

Action1023:
	move.l	DP_Arg2(a2),d1		;key
	tst.l	DP_Arg1(a2)
	beq.s	a1023_unlock

	tst.w	SoftLocked(a4)
	bne.s	a1023_end		;already locked

	move.w	#-1,SoftLocked(a4)	;"lock active"
	move.l	d1,PassKey(a4)
	moveq.l	#ID_VALIDATED,d0
	moveq.l	#ID_WRITE_PROT,d1
	bra.s	a1023_switch

a1023_unlock:
	tst.w	SoftLocked(a4)
	beq.s	a1023_end		;already unlocked

	move.l	PassKey(a4),d0
	beq.s	a1023_free		;any key..

	cmp.l	d0,d1			;..or only the same we were locked with
	bne.s	a1023_wrongkey
a1023_free:
	clr.w	SoftLocked(a4)		;"lock released"
	btst	#1,PhysFlags+1(a4)
	beq.s	a1023_end

	moveq.l	#ID_WRITE_PROT,d0
	moveq.l	#ID_VALIDATED,d1
a1023_switch:
	cmp.l	DiskState(a4),d0
	bne.s	a1023_end

	move.l	d1,DiskState(a4)
a1023_end:
	moveq.l	#TRUE,d0
	bra.w	s_return

a1023_wrongkey:
	move.w	#115,ErrorNum(a4)
	moveq.l	#FALSE,d0
	bra.w	s_return

;--- ACTION_FH_FROM_LOCK -----------------------------------

Action1026:
	move.l	DP_Arg2(a2),d0
	lsl.l	#2,d0
	move.l	d0,d2
	beq.s	a1026_end

	move.l	d0,a0
	move.l	FL_Key(a0),d0		;&XLock..
	move.l	DP_Type(a2),-(sp)	;.."use original"
	clr.l	-(sp)
	move.l	d0,-(sp)
	bsr.w	OpenFile
	add.w	#12,sp
	tst.l	d0			;&FileHandleExtension
	beq.s	a1026_end		;on success..

	move.l	DP_Arg1(a2),d1
	lsl.l	#2,d1
	move.l	d1,a0			;&FileHandle
	move.l	d0,FH_Arg1(a0)
	move.l	d2,-(sp)
	bsr.w	FreeLock		;..free FileLock
	addq.w	#4,sp
	moveq.l	#TRUE,d0
a1026_end:
	bra.w	s_return

;--- ACTION_IS_FILESYSTEM ----------------------------------

Action1027:
	moveq.l	#TRUE,d0
	bra.w	s_return

;--- ACTION_CHANGE_MODE ------------------------------------

Action1028:
	move.l	DP_Arg3(a2),-(sp)	;new mode
	move.l	DP_Arg2(a2),-(sp)	;(BPTR) object
	move.l	DP_Arg1(a2),-(sp)	;type
	bsr.w	ChangeMode
	add.w	#12,sp
	bra.w	s_return

;--- ACTION_COPY_DIR ---------------------------------------

Action19:
	move.l	DP_Arg1(a2),d0
	lsl.l	#2,d0
	beq.s	a1031_open

	move.l	d0,a0
	move.l	FL_Key(a0),d0
	bra.s	a1031_open

;--- ACTION_COPY_DIR_FH ------------------------------------

Action1030:
	move.l	DP_Arg1(a2),a0		;&FileHandleExtension
	move.l	XFH_XLock(a0),d0
	bra.s	a1031_open

;--- ACTION_PARENT_FH --------------------------------------

Action1031:
	move.l	DP_Arg1(a2),a0		;&FileHandleExtension
	move.l	XFH_XLock(a0),a0
	move.l	XL_Parent(a0),d0
a1031_open:
	move.l	d0,a0
	bsr.w	OpenXLock
	tst.l	d0
	beq.s	a1031_end		;locked exclusively

	pea	(SHARED_LOCK).w
	move.l	d0,-(sp)
	bsr.w	NewLock
	addq.w	#8,sp
a1031_end:
	bra.w	s_return

;--- ACTION_EXAMINE_ALL ------------------------------------

Action1033:
	move.l	DP_Arg1(a2),d0
	bsr.w	Ok2Read
	tst.l	d0
	beq.w	s_return

	lea	DP_Arg5+4(a2),a0
	move.l	-(a0),-(sp)
	move.l	-(a0),-(sp)
	move.l	-(a0),-(sp)
	move.l	-(a0),-(sp)
	move.l	d0,-(sp)
	bsr.w	ExamineAll
	add.w	#20,sp
	bra.w	s_return

;--- ACTION_EXAMINE_FH -------------------------------------

Action1034:
	move.l	DP_Arg1(a2),d0
	beq.s	a1034_end

	move.l	d0,a0			;&FileHandleExtension
	move.l	DP_Arg2(a2),d0
	lsl.l	#2,d0
	move.l	d0,-(sp)		;&FileInfoBlock
	move.l	XFH_XLock(a0),-(sp)
	bsr.w	ExamineKey
	addq.l	#8,sp
a1034_end:
	bra.w	s_return

;--- ACTION_EXAMINE_ALL_END --------------------------------

Action1035:
	moveq.l	#TRUE,d0
	bra.w	s_return

;--- ACTION_SERIALIZE_DISK ---------------------------------

Action4200:
	bsr.w	SerializeDisk
	bra.w	s_return

;--- ACTION_GET_DISK_FSSM ----------------------------------

Action4201:
	move.l	StartupMsg(a4),d0
	bra.w	s_return

;--- ACTION_FREE_DISK_FSSM ---------------------------------

Action4202:
	moveq.l	#TRUE,d0
	bra.w	s_return

;--- Diskwechel-Interrupt ----------------------------------
; a1 <- &GlobaleVariablen

IntCode:
	move.l	a6,-(sp)
	move.l	ExecBase(a1),a6
	move.w	#1,DiskChanged(a1)
	move.l	pr_MsgPort(a1),a0
	moveq.l	#0,d0
	moveq.l	#0,d1
	move.b	MP_SigBit(a0),d1
	bset	d1,d0
	move.l	MP_SigTask(a0),a1
	jsr	Signal(a6)		;Signal() the filesystem task
	move.l	(sp)+,a6
	moveq.l	#0,d0
	rts

;*** externally visible FileLocks **************************
;--- new FileLock ------------------------------------------
; <- struct XLock *object, LONG mode;
; -> BPTR NewLock or 0;

NewLock:
	move.l	a2,-(sp)
	moveq.l	#FL_Sizeof,d0
	bsr.w	AllocSegment
	move.l	d0,a2			;&FileLock..
	tst.l	d0
	beq.s	nl_error		;no memory

	move.l	pr_MsgPort(a4),FL_Task(a2)
	move.l	12(sp),FL_Access(a2)
	move.l	8(sp),a0		;&XLock
	move.l	a0,FL_Key(a2)
	move.l	XL_Volume(a0),d0
	move.l	d0,12(sp)
	lsr.l	#2,d0
	move.l	d0,FL_Volume(a2)	;..init and..
	bsr.w	_Forbid
	move.l	12(sp),a0
	move.l	DOL_LockList(a0),FL_Link(a2)
	move.l	a2,d0
	lsr.l	#2,d0
	move.l	d0,DOL_LockList(a0)	;..put into Locklist of VolumeNode
	bsr.w	_Permit
	addq.l	#1,NumLocks(a4)		;1 more lock
nl_end:
	move.l	a2,d0
	lsr.l	#2,d0			;APTR -> BPTR
	move.l	(sp)+,a2
	rts

nl_error:
	move.l	8(sp),a1
	bsr.w	CloseXLock		;free object on error
	move.w	#103,ErrorNum(a4)
	bra.s	nl_end

;--- remove FileLock from list and free --------------------
; <- struct FileLock *fl;
; -> BOOL ok;

FreeLock:
	link.w	a5,#0
	movem.l	a2/a3,-(sp)
	move.l	8(a5),a0		;&FileLock
	move.l	FL_Volume(a0),d0
	lsl.l	#2,d0
	move.l	d0,a2			;&VolumeNode
	add.w	#DOL_LockList,a2
	bsr.w	_Forbid
frl_loop:
	move.l	a2,a3
	move.l	(a2),d0
	lsl.l	#2,d0
	move.l	d0,a2			;&NextFileLock
	tst.l	d0
	beq.s	frl_last		;lock not in list??

	cmp.l	8(a5),a2
	bne.s	frl_loop		;search on

	move.l	(a2),(a3)		;remove FileLock from LockList
frl_last:
	bsr.w	_Permit
	move.l	a2,d0
	beq.s	frl_end

	move.l	a2,a1
	bsr.w	FreeSegment		;free lock
	subq.l	#1,NumLocks(a4)		;1 less lock
	moveq.l	#-1,d0
frl_end:
	movem.l	(sp)+,a2/a3
	unlk	a5
	rts

;--- change access mode of existing lock -------------------
; <- LONG type, BPTR object, LONG new mode;
; -> BOOL ok;

ChangeMode:
	move.l	8(sp),d0
	beq.s	chm_wrongtype		;no object??

	lsl.l	#2,d0
	move.l	d0,a0			;&FileLock or &FileHandle
	move.l	4(sp),d0		;type..
	beq.s	chm_lock

	subq.l	#1,d0
	bne.s	chm_wrongtype		;..invalid

	move.l	FH_Arg1(a0),a1		;&FileHandleExtension
	move.l	XFH_XLock(a1),a1	;&XLock
	bra.s	chm_check
chm_lock:
	move.l	FL_Key(a0),a1		;&XLock
chm_check:
	move.w	XL_OpenCnt(a1),d0
	moveq.l	#EXCLUSIVE_LOCK,d1
	cmp.l	12(sp),d1
	bne.s	chm_shared

	subq.w	#1,d0
	bmi.s	chm_ok			;already exclusive
	bgt.s	chm_inuse		;if only 1 user..

	moveq.l	#$18,d0
	and.b	XL_MSDE+MSDE_Flags(a1),d0
	bne.s	chm_inuse		;..of this file..
	bra.s	chm_flip		;.."exclusive access" from now on
chm_shared:
	moveq.l	#SHARED_LOCK,d1
	tst.w	d0
	bpl.s	chm_ok			;already "shared"
chm_flip:
	neg.w	XL_OpenCnt(a1)
chm_ok:
	moveq.l	#TRUE,d0
	tst.l	4(sp)			;for FileLocks..
	bne.s	chm_end

	move.l	d1,FL_Access(a0)	;..remember new mode here too
chm_end:
	rts

chm_inuse:
	move.w	#202,d0
	bra.s	chm_error
chm_wrongtype:
	move.w	#212,d0
chm_error:
	move.w	d0,ErrorNum(a4)
	moveq.l	#FALSE,d0
	bra.s	chm_end

;*** VolumeNode ********************************************
;--- generate standard disk name ---------------------------
; <- struct ExtMSDirEntry *target;

GetDefVolName:
	move.l	d2,-(sp)
	moveq.l	#8,d2
	move.l	SerialNum(a4),d1	;Serial #..
	move.l	8(sp),a1
gdvn_snloop:
	rol.l	#4,d1
	moveq.l	#$f,d0
	and.w	d1,d0
	cmp.w	#10,d0
	bcs.s	gdvn_n1

	addq.w	#7,d0
gdvn_n1:
	add.w	#'0',d0
	move.b	d0,(a1)+		;..as Name
	cmp.w	#5,d2
	bne.s	gdvn_n2

	move.b	#'-',(a1)+		;eg. "12EE-0E39"
gdvn_n2:
	subq.w	#1,d2
	bgt.s	gdvn_snloop

	move.b	#' ',(a1)+		;MSDE_Ext[1]
	move.w	#$2028,(a1)+		;MSDE_Ext[2], MSDE_Flags
	moveq.l	#XMSDE_FullName+1-12,d0
gdvn_sloop:
	clr.l	(a1)+
	subq.w	#4,d0
	bgt.s	gdvn_sloop

	move.l	8(sp),a1
	move.w	#$21,MSDE_Date(a1)	;1.1.1980
	move.l	(sp)+,d2
	rts

;--- register current disk with DOS ------------------------
; <- char *BStrName, struct DateStamp *date;
; -> &VolumeNode or 0

MountNewVolume:
	link.w	a5,#-4
	move.l	a2,-(sp)
	move.l	DosBase(a4),a0
	move.l	$22(a0),a1		;&RootNode
	move.l	$18(a1),d0
	lsl.l	#2,d0
	move.l	d0,-4(a5)		;&DosInfo

	moveq.l	#XDOL_Sizeof,d0
	bsr.w	AllocSegment
	move.l	d0,a2			;&VolumeNode
	tst.l	d0
	beq.s	mnv_error		;no memory

	lea	XDOL_XLockList(a2),a0	;&XLock List
	bsr.w	InitList

	lea	XDOL_Name(a2),a1	;&Name
	move.l	a1,d0
	lsr.l	#2,d0
	move.l	d0,DOL_Name(a2)		;(BPTR) Name
	move.l	8(a5),a0		;&source (BSTR)
	moveq.l	#0,d0
	move.b	(a0),d0
mnv_loop:
	move.b	(a0)+,(a1)+		;copy length + Name
	subq.w	#1,d0
	bpl.s	mnv_loop

	clr.b	(a1)			;just in case somebody expects a C-String
	moveq.l	#DLT_VOLUME,d0
	move.l	d0,DOL_Type(a2)			;Type "Volume"
	move.l	pr_MsgPort(a4),DOL_Task(a2)	;this FileSystem
	move.l	DiskType(a4),DOL_DiskType(a2)	;hopefully "FAT"
	clr.l	DOL_Unused(a2)

	lea	DOL_VolumeDate(a2),a0
	move.l	12(a5),a1
	move.l	(a1)+,(a0)+		;copy DateStamp
	move.l	(a1)+,(a0)+
	move.l	(a1)+,(a0)+

	bsr.w	_Forbid
	move.l	-4(a5),a0
	move.l	4(a0),(a2)		;append old list
	move.l	a2,d0
	lsr.l	#2,d0
	move.l	d0,4(a0)		;add to list head
	bsr.w	_Permit
mnv_end:
	move.l	a2,d0
	move.l	(sp)+,a2
	unlk	a5
	rts

mnv_error:
	move.w	#103,ErrorNum(a4)
	bra.s	mnv_end

;--- update VolumeNode -------------------------------------

TouchVolumeNode:
	movem.l	a2-a3,-(sp)
	move.l	VolumeNode(a4),d0
	beq.s	tvn_end

	move.l	d0,a3			;&DosList
	move.l	RootXLock(a4),d0
	beq.s	tvn_end

	move.l	d0,a2
	add.w	#XL_MSDE,a2		;&MSDirEntry of root dir
	move.l	a2,a0
	lea	XDOL_Name(a3),a1	;&Name
	bsr.w	GetBName		;Name,..
	move.l	MSDE_CTime(a2),d0
	lea	DOL_VolumeDate(a3),a1
	bsr.w	Date2Dos		;..date and time
tvn_end:
	movem.l	(sp)+,a2-a3
	rts

;--- unmount disk ------------------------------------------
; <- struct VolumeNode *old;
; -> BOOL ok;

UnMountVolume:
	move.l	a2,-(sp)
	move.l	8(sp),d0
	beq.s	umv_ok			;no VolumeNode, OK

	move.l	d0,a2
	tst.l	DOL_LockList(a2)
	bne.s	umv_error		;error: there still are active FileLocks

	move.l	DosBase(a4),a0
	move.l	$22(a0),a0		;&RootNode
	move.l	$18(a0),d0
	lsl.l	#2,d0
	move.l	d0,a1			;&DosInfo
	addq.l	#4,a1
	bsr.w	_Forbid
umv_loop:
	move.l	a1,a0
	move.l	(a1),d0
	lsl.l	#2,d0
	move.l	d0,a1			;&nextDosList
	tst.l	d0
	beq.s	umv_last		;not in List??

	cmp.l	a1,a2
	bne.s	umv_loop		;wrong Node, go on

	move.l	(a1),(a0)		;unlink Node
umv_last:
	bsr.w	_Permit
	move.l	a2,a1
	bsr.w	FreeSegment		;free Node
	cmp.l	VolumeNode(a4),a2
	bne.s	umv_ok

	clr.l	VolumeNode(a4)		;no zombies please
umv_ok:
	moveq.l	#-1,d0			;"OK"
umv_end:
	move.l	(sp)+,a2
	rts

umv_error:
	moveq.l	#0,d0
	bra.s	umv_end

;--- terminate disk access ---------------------------------
; -> BOOL ok;

CloseDisk:
	tst.w	PhysFlags(a4)
	beq.s	cd_ok			;nothing inserted

	move.l	VolumeNode(a4),d0
	beq.s	cd_report		;disk was invalid

	move.l	d0,a0
	clr.l	DOL_Task(a0)			;detach from File system
	move.l	pr_MsgPort(a4),DOL_Unused(a0)	;safe re-recognition
	tst.w	NewFlags(a4)
	beq.s	cd_free			;perform deferred actions..

	pea	(TRUE).w
	bsr.w	UpdateDisk		;..now
	addq.w	#4,sp
cd_free:
	clr.l	BackgroundJob(a4)	;abort background activity
	bsr.w	TouchVolumeNode
	bsr.w	FreeFATBuf		;free all block buffers
	bsr.w	CacheFree
	move.l	RootXLock(a4),a1
	bsr.w	CloseXLock		;free root dir..
	clr.l	RootXLock(a4)
	tst.l	VolumeNode(a4)
	bne.s	cd_sleep
cd_report:
	clr.w	PhysFlags(a4)
	bsr.w	ChangeReport
cd_ok:
	moveq.l	#-1,d0			;..and all other dirs, or..
cd_end:
	moveq.l	#ID_NONE,d1
	move.l	d1,DiskType(a4)
	rts

cd_sleep:
	clr.l	VolumeNode(a4)		;..if still open XLock`s..
	clr.w	PhysFlags(a4)
	bsr.w	ChangeReport
	moveq.l	#0,d0			;..stay in DOS List
	bra.s	cd_end

;--- read disk info ----------------------------------------

IdentifyDisk:
	clr.w	DiskChanged(a4)
	moveq.l	#-2,d0			;maybe except "motor off"..
	and.w	NewFlags(a4),d0
	beq.s	idd_doit		;..everything was already done

	pea	(TDERR_DISKCHANGED).w
	bsr.w	DoRequest		;otherwise show warning..
	addq.l	#4,sp
	tst.w	d0
	bne.s	idd_end			;..and go on with old disk
idd_doit:
	bsr.w	CloseDisk
	bsr.s	OpenDisk
idd_end:
	rts

;--- recognize and mount disk ------------------------------
; -> &VolumeNode or 0

OD_KEY		= -8
OD_NAMEBUF	= -20
OD_ROOTDATE	= -24
OD_DOSDATE	= -36
OD_MSDEBUF	= -36-XMSDE_Sizeof

OpenDisk:
	link.w	a5,#OD_MSDEBUF
	move.l	a2,-(sp)

	move.b	#1,NoRequest(a4)	;no read error requesters
	sub.l	a2,a2			;default: error
	tst.w	InhibitNest(a4)
	bne.w	od_end			;we are sleeping

;- - get disk name - - - - - - - - - - - - - - - - - - - - -

	bsr.w	GetDiskParams
	move.w	d0,PhysFlags(a4)
	beq.w	od_end			;no disk

	btst	#3,d0
	beq.w	od_report		;invalid disk

	bsr.w	ReadFAT			;get FAT
	tst.l	d0
	bne.s	od_label

	and.w	#$fff7,PhysFlags(a4)	;whistle back for..
	move.l	#ID_NDOS,DiskType(a4)	;..Amiga reformatted ZIP disk
	bra.w	od_report
od_label:
	move.l	RootCluster(a4),d0
	bsr.w	Cluster2Block
	move.l	d0,OD_KEY(a5)
	clr.w	OD_KEY+4(a5)
	lea	OD_MSDEBUF(a5),a2	;optimize
od_eloop:
	move.l	a2,-(sp)
	pea	OD_KEY(a5)
	bsr.w	ReadXMSDE
	addq.w	#8,sp
	tst.w	d0
	beq.s	od_standard		;root dir ends here,..

	move.b	(a2),d0
	beq.s	od_standard		;..no disk name found,..

	cmp.b	#MSDEB_DELETED,d0
	beq.s	od_eloop

	btst	#3,MSDE_Flags(a2)
	beq.s	od_eloop
	bra.s	od_found

od_standard:
	tst.l	SerialNum(a4)
	bne.s	od_stdok		;invalid Serial #..

	btst	#1,PhysFlags+1(a4)
	beq.s	od_stdok		;..when writable..

	bsr.w	TouchBootBlock		;..fix it now
od_stdok:
	move.l	a2,-(sp)
	bsr.w	GetDefVolName		;..generic standard name
	addq.l	#4,sp

od_found:
	move.l	a2,a0
	lea	OD_NAMEBUF(a5),a1
	bsr.w	GetBName		;Name,..
	move.l	MSDE_Time(a2),d0
	move.l	d0,MSDE_CTime(a2)
	lea	OD_DOSDATE(a5),a1
	bsr.w	Date2Dos		;..date and time

;- - register disk with DOS  - - - - - - - - - - - - - - - -

	move.l	DosBase(a4),a0
	move.l	$22(a0),a1		;&Rootnode
	move.l	$18(a1),d0
	lsl.l	#2,d0
	move.l	d0,a2			;&DosInfo
	addq.l	#4,a2
	bsr.w	_Forbid
od_loop:
	move.l	(a2),d0
	lsl.l	#2,d0
	move.l	d0,a2			;&nextDosList
	tst.l	d0
	beq.s	od_last			;not in List

	moveq.l	#DLT_VOLUME,d0
	cmp.l	DOL_Type(a2),d0
	bne.s	od_loop			;scan for volumes only

	move.l	DOL_Name(a2),d0
	lsl.l	#2,d0
	move.l	d0,a0			;&found Name
	lea	OD_NAMEBUF(a5),a1	;&searched Name (both BCPL strings)
	moveq.l	#0,d0
	move.b	(a0),d0
od_nloop:
	cmpm.b	(a1)+,(a0)+
	dbne	d0,od_nloop
	bne.s	od_loop			;wrong Name

	lea	DOL_VolumeDate(a2),a0
	lea	OD_DOSDATE(a5),a1
	moveq.l	#2,d0
od_dloop:
	cmpm.l	(a1)+,(a0)+
	dbne	d0,od_dloop
	bne.s	od_loop			;wrong date

	tst.l	DOL_Task(a2)
	bne.s	od_loop			;already in use??

	move.l	DOL_Unused(a2),d0
	cmp.l	pr_MsgPort(a4),d0	;a foreign handler..
	bne.s	od_loop			;..is looting us!!!

	clr.l	DOL_Unused(a2)
od_last:
	bsr.w	_Permit
	move.l	a2,d0
	bne.s	od_ready

	pea	OD_DOSDATE(a5)		;&date
	pea	OD_NAMEBUF(a5)		;&Name
	bsr.w	MountNewVolume		;new VolumeNode
	addq.l	#8,sp
	move.l	d0,a2
od_ready:
	move.l	a2,VolumeNode(a4)
	beq.s	od_end			;error

	move.l	pr_MsgPort(a4),DOL_Task(a2)	;connect File system
	lea	XDOL_Name+1(a2),a0
	lea	LastVolName(a4),a1
	bsr.w	StrCopy			;for DoRequest()

;- - start XLock`s - - - - - - - - - - - - - - - - - - - - -

	pea	(SHARED_LOCK).w
	pea	OD_MSDEBUF(a5)
	clr.l	-(sp)
	bsr.w	xLock
	add.w	#12,sp
	move.l	d0,RootXLock(a4)
od_report:
	bsr.w	ChangeReport		;report success
od_end:
	clr.b	NoRequest(a4)		;reenable read/write error reqs
	move.l	a2,d0

	move.l	(sp)+,a2
	unlk	a5
	rts

;--- check object read permission --------------------------
; d0 <- (BPTR)FileLock;
; d0 -> struct XLock *xl or 0;

Ok2Read:
	lsl.l	#2,d0			;&FileLock..
	bne.s	o2r_lock		;..valid

	move.l	RootXLock(a4),d0
	bne.s	o2r_end			;no Lock -> current disk

	move.l	DiskType(a4),d1
	addq.l	#-ID_NONE,d1
	beq.s	o2r_nodisk
	bra.s	o2r_nodos
o2r_lock:
	move.l	d0,a0
	move.l	FL_Volume(a0),d0
	lsl.l	#2,d0
	cmp.l	VolumeNode(a4),d0
	bne.s	o2r_notmounted

	move.l	FL_Key(a0),d0
o2r_end:
	rts

;- - error codes shared with Ok2Write()  - - - - - - - - - -

o2r_readonly:
	move.w	#214,d0
	bra.s	o2r_error
o2r_notmounted:
	move.w	#218,d0
	bra.s	o2r_error
o2r_nodisk:
	move.w	#226,d0
	bra.s	o2r_error
o2r_nodos:
	move.w	#225,d0
o2r_error:
	move.w	d0,ErrorNum(a4)
	moveq.l	#0,d0
	bra.s	o2r_end

;--- check object write permission -------------------------
; d0 <- (BPTR)FileLock;
; d0 -> struct XLock *xl or 0;

Ok2Write:
	lsl.l	#2,d0			;&FileLock..
	bne.s	o2w_lock		;..valid

	move.l	RootXLock(a4),d0
	bne.s	o2w_end			;no Lock -> current disk

	move.l	DiskType(a4),d1
	addq.l	#-ID_NONE,d1
	beq.s	o2r_nodisk
	bra.s	o2r_nodos
o2w_lock:
	move.l	d0,a0
	move.l	FL_Volume(a0),d0
	lsl.l	#2,d0
	cmp.l	VolumeNode(a4),d0
	bne.s	o2r_notmounted

	move.l	FL_Key(a0),d0
o2w_end:
	moveq.l	#ID_VALIDATED,d1
	cmp.l	DiskState(a4),d1
	bne.s	o2r_readonly

	rts

;*** DOS communication *************************************
;--- reply order -------------------------------------------
; a0 <- struct DosPacket *pkt;

ReplyDosPacket:
	move.l	DP_Message(a0),a1
	move.l	DP_MsgPort(a0),d0	  ;&ReplyPort (DOS)
	move.l	pr_MsgPort(a4),DP_MsgPort(a0) ;return Packet here later
	move.l	a0,LN_Name(a1)		  ;link Msg -> Packet
	move.l	d0,a0
	move.l	ExecBase(a4),a6
	jmp	PutMsg(a6)

;--- BStr -> disk name -------------------------------------
; a0 <- BPTR_BSTR Name
; a1 <- char &msde[12]
; d0 -> BOOL ok

BStr2DiskName:
	movem.l	d2/a2,-(sp)
	move.l	a1,a2			;&target
	move.l	a0,d0
	beq.s	b2d_end			;no Name

	lsl.l	#2,d0
	move.l	d0,a1			;&BSTR
	moveq.l	#0,d0
	move.b	(a1)+,d0
	beq.s	b2d_end			;empty Name

	move.w	d0,d1
	moveq.l	#11,d2
b2d_loop:
	moveq.l	#' ',d0			;space pad
	subq.w	#1,d1
	bmi.s	b2d_char

	move.b	(a1)+,d0		;char..
	bsr.s	Char2MS			;..convert and..
b2d_char:
	move.b	d0,(a2)+		;..write
	subq.w	#1,d2
	bgt.s	b2d_loop

	move.b	#$28,(a2)		;MSDE_Flags
	sub.w	#11,a2
	cmp.b	#$e5,(a2)		;special case Name[0] = MSDE_DELETED
	bne.s	b2d_ok

	move.b	#$05,(a2)
b2d_ok:
	moveq.l	#TRUE,d0
b2d_end:
	movem.l	(sp)+,d2/a2
	rts

;--- convert 1 charAmiga -> uppercase PC437 ---------------
;preserve d1, a1
; d0 <-> int char;

Char2MS:
	cmp.b	#'a',d0
	bcs.s	c2ms_check

	cmp.b	#'z'+1,d0
	bcs.s	c2ms_upcase

	tst.b	d0
	bmi.s	c2ms_special
c2ms_end:
	rts

c2ms_upcase:
	bclr	#5,d0			;toUpper
	bra.s	c2ms_end

c2ms_check:
	cmp.b	#'.',d0
	bne.s	c2ms_end
c2ms_block:
	moveq.l	#'_',d0
	bra.s	c2ms_end

c2ms_special:
	sub.b	#$a0,d0
	bcs.s	c2ms_block

	cmp.b	#$40,d0
	bcs.s	c2ms_change

	sub.b	#$20,d0			;toUpper special chars
c2ms_change:
	tst.l	OemPage(a4)
	beq.s	c2ms_end

	ext.w	d0
	move.l	OemPage(a4),a0
	add.w	d0,a0
	move.b	(a0),d0
	bra.s	c2ms_end

;--- convert C-String PC437 -> Amiga -----------------------
; a0 <- &String

StrPc2Amiga:
	move.l	InvOemPage(a4),d1
	beq.s	sp2a_end

	move.l	d1,a1
	sub.w	#128,a1
	moveq.l	#0,d0
sp2a_loop:
	move.b	(a0)+,d0
	bgt.s	sp2a_loop		;no special char
	beq.s	sp2a_end		;string end

	move.b	(a1,d0.l),-1(a0)	;replace char
	bra.s	sp2a_loop
sp2a_end:
	rts

;--- extract 1 path component and convert Amiga -> MS ------
; a0 <-> &source
; a1 <-  &dest
; d0  -> 0 (OK), -1 ("parent dir")

MakeShortName:
	movem.l	d2-d5/a2-a3,-(sp)
	cmp.b	#'/',(a0)
	beq.w	msn_parent		;relative path: to parent

	move.l	a1,a3			;&target
	move.l	a1,d2			;&Name extension
	moveq.l	#11,d3			;up to 11 chars
	moveq.l	#0,d4			;count dots
	bra.s	msn_start
msn_mark:
	moveq.l	#3,d4			;"does not fit in 8.3"
msn_loop:
	move.b	(a0),d0
	beq.w	msn_pass2		;until the end..

	addq.l	#1,a0
	cmp.b	#'/',d0
	beq.w	msn_pass2		;..or next component

	cmp.b	#'.',d0
	bne.s	msn_char		;printable char
msn_period:
	addq.w	#3,d4			;count dots
msn_start:
	move.b	(a0),d0
	beq.w	msn_pass2

	addq.l	#1,a0
	cmp.b	#'/',d0
	beq.s	msn_pass2

	cmp.b	#'.',d0
	beq.s	msn_period		;several dots in a row

	cmp.w	#3,d3
	bcc.s	msn_p1

	lea	8(a3),a1		;Name up to 8 chars
	moveq.l	#3,d3
	moveq.l	#3,d4
msn_p1:
	move.l	a1,d2			;&next Name ext
	subq.w	#2,d4
msn_char:
	cmp.b	#' ',d0
	beq.s	msn_mark		;remove spaces

	tst.w	d3
	beq.s	msn_mark		;up to 11 total chars

	tst.b	d0
	bmi.s	msn_table		;special chars

	cmp.b	#'a',d0
	bcs.s	msn_c1

	cmp.b	#'z'+1,d0
	bcc.s	msn_c1

	and.b	#$df,d0			;toUpper
msn_c1:
	lea	msn_chars(pc),a2
	moveq.l	#0,d1
	move.b	d0,d1
	lsr.w	#3,d1
	add.w	d1,a2
	moveq.l	#7,d1
	and.b	d0,d1
	btst	d1,(a2)
	beq.s	msn_write
msn_underscore:
	moveq.l	#'_',d0			;invalid char
	moveq.l	#3,d4
msn_write:
	move.b	d0,(a1)+		;write char
	subq.w	#1,d3
	bra.s	msn_loop
msn_table:
	btst	#6,d0
	beq.s	msn_t1

	and.b	#$df,d0			;toUpper special chars
msn_t1:
	sub.b	#$a0,d0
	bcs.s	msn_underscore

	move.l	OemPage(a4),d1
	beq.s	msn_t2

	move.l	d1,a2
	ext.w	d0
	add.w	d0,a2
	move.b	(a2),d0			;..and ANSI -> OEM
	bmi.s	msn_write

	moveq.l	#3,d4
	bra.s	msn_write
msn_t2:
	add.b	#$a0,d0
	bra.s	msn_write

msn_pass2:
	move.l	a0,d5			;save &source
	cmp.l	d2,a3
	bne.s	msn_ext			;no extension,..

	move.l	a1,d2			;..everything as Name
msn_ext:
	move.l	d2,a0			;&Name extension,..
	move.l	#"    ",d0
	move.l	a1,d1
	sub.l	d2,d1			;..and its length..
	beq.s	msn_ewrite

	moveq.l	#3,d3
	cmp.w	d1,d3
	bcc.s	msn_e1

	move.w	d3,d1			;..limit to 3 chars
	moveq.l	#3,d4
msn_e1:
	add.w	d1,a0
msn_eloop:
	move.b	-(a0),d0
	ror.l	#8,d0
	subq.w	#1,d1
	bgt.s	msn_eloop
msn_ewrite:
	move.l	d0,8(a3)		;copy ext to end
	move.l	d2,a0
	moveq.l	#8,d1
	add.l	a3,d1
	sub.l	d2,d1
	move.w	d1,d3
	bmi.s	msn_num
	beq.s	msn_3			;pad Name with..
msn_2:
	move.b	d0,(a0)+		;..spaces
	subq.w	#1,d1
	bgt.s	msn_2
msn_3:
	tst.w	d4
	bmi.s	msn_ready		;fits to 8.3..
msn_num:
	move.l	d2,a0
	subq.w	#2,d3
	bpl.s	msn_4

	add.w	d3,a0
msn_4:
	move.b	#'~',(a0)+
	move.b	#'1',(a0)		;..or append a version #
msn_ready:
	cmp.b	#$e5,(a3)		;special case 1. char = MSDEB_DELETED
	bne.s	msn_5

	move.b	#$05,(a3)
msn_5:
	move.l	d5,a0
	moveq.l	#0,d0
msn_end:
	movem.l	(sp)+,d2-d5/a2-a3
	rts

msn_parent:
	addq.l	#1,a0
	moveq.l	#-1,d0
	bra.s	msn_end

msn_chars:
	dc.l	-1,$04dc00fc,$00000038,$00000010

;--- find a unique standard name ---------------------------
; <- ULONG DirStartBlock, char &StdName[11];

UniqueStdName:
	link.w	a5,#-4
	movem.l	d2-d3/a2,-(sp)

;- - check already used standard names - - - - - - - - - - -

	move.l	12(a5),a0
	bsr.s	usn_bump
usn_rescan:
	clr.l	-4(a5)
	move.l	8(a5),d2
	moveq.l	#0,d3
usn_block:
	move.l	d2,d0
	beq.s	usn_done		;thats it!!

	bsr.w	ReadDirBlock
	tst.l	d0
	beq.s	usn_end			;read error

	move.l	d0,a2			;&Block contents
usn_entry:
	move.b	(a2),d0
	beq.s	usn_done		;dir end

	cmp.b	#MSDEB_DELETED,d0	;dir already densified,..
	beq.s	usn_done		;..stop scanning here

	btst	#3,MSDE_Flags(a2)	;long names and disk name..
	bne.s	usn_next		;..dont matter

	move.l	a2,a0
	move.l	12(a5),a1
	move.l	(a0)+,d0
	cmp.l	(a1)+,d0
	bne.s	usn_next		;if name already used..

	move.l	(a0)+,d0
	cmp.l	(a1)+,d0
	bne.s	usn_next

	move.w	(a0)+,d0
	cmp.w	(a1)+,d0
	bne.s	usn_next

	move.b	(a0),d0
	cmp.b	(a1),d0
	bne.s	usn_next

	move.w	#-1,-4(a5)
	move.l	12(a5),a0
	bsr.s	usn_bump		;..bump version
usn_next:
	add.w	#MSDE_Sizeof,a2
	bsr.w	NextMSDE
	tst.w	d3
	bne.s	usn_entry
	bra.s	usn_block
usn_done:
	tst.w	-4(a5)
	bne.s	usn_rescan
usn_end:
	movem.l	(sp)+,d2-d3/a2
	unlk	a5
	rts

;- - bump version  - - - - - - - - - - - - - - - - - - - - -
; a0 <- &StdName[11]

usn_bump:
	move.l	d2,-(sp)
	addq.l	#8,a0			;&Name[7]+1
	moveq.l	#7,d0
usn_beloop:
	cmp.b	#' ',-(a0)		;end search
	dbne	d0,usn_beloop

	move.w	d0,d2			;Offset and..
	move.l	a0,a1			;..&last char
usn_bdigit:
	move.b	(a0),d1
	cmp.b	#'0',d1
	bcs.s	usn_badd		;if no version..

	cmp.b	#'9',d1
	beq.s	usn_bcarry
	bcc.s	usn_badd		;..append a "1"

	addq.b	#1,d1			;1 up ("INDEX~1" -> "INDEX~2")..
	move.b	d1,(a0)
	bra.s	usn_bend		;..OK, thats already it.
usn_bcarry:
	move.b	#'0',(a0)		;carry otherwise
	subq.l	#1,a0
	subq.w	#1,d0
	bpl.s	usn_bdigit		;"HALLO~29" -> "HALLO~30"
usn_badd:
	cmp.w	#7,d2			;if enough room,..
	blt.s	usn_bashift		;..enlarge Name for new digit

	subq.w	#1,d0
	bmi.s	usn_bend		;not enough room for..

	move.b	#'~',-1(a0)		;..1 more digit
	bra.s	usn_ba2			;"HASEN~99" -> "HASE~100"
usn_bashift:
	addq.l	#1,a1
	move.b	#'0',(a1)		;append a 0
	addq.l	#1,a0			;"TOR~99" -> "TOR~100"
usn_ba2:
	move.b	#'1',(a0)		;the new digit
usn_bend:
	move.l	(sp)+,d2
	rts

;--- Fill Disk-Info-Block --------------------------------
; <- struct InfoData *target;
; -> BOOL ok;

GiveDiskInfo:
	move.l	4(sp),a0		;&target

	clr.l	ID_NumSoftErrors(a0)
	move.l	UnitNumber(a4),ID_UnitNumber(a0)
	move.l	DiskState(a4),ID_DiskState(a0)
	move.l	DiskType(a4),ID_DiskType(a0)

	move.l	VolumeNode(a4),d0
	lsr.l	#2,d0
	move.l	d0,ID_VolumeNode(a0)	;BPTR

	move.l	NumLocks(a4),d0
	beq.s	gdi_1

	moveq.l	#1,d0
gdi_1:
	move.l	d0,ID_InUse(a0)		;"still referenced"

	move.l	DosType(a4),d1
	cmp.l	DiskType(a4),d1
	bne.s	gdi_ndos		;Disk invalid

	move.l	#ID_DOS,ID_DiskType(a0)	;intentionally incorrect for Workbench..
					;..and info shell tool
	move.l	FreeClusters(a4),d0
	move.w	ClusterShift(a4),d1
	lsl.l	d1,d0			;..# of free blocks
	move.l	TotalBlocks(a4),d1
	move.l	d1,ID_NumBlocks(a0)
	sub.l	d0,d1
	move.l	d1,ID_BlocksUsed(a0)
	moveq.l	#0,d0
	move.w	BlockSize(a4),d0
	move.l	d0,ID_BytesPerBlock(a0)
gdi_end:
	moveq.l	#TRUE,d0
	rts

gdi_ndos:
	clr.l	ID_NumBlocks(a0)
	clr.l	ID_BlocksUsed(a0)
	clr.l	ID_BytesPerBlock(a0)
	bra.s	gdi_end

;--- copy DOS environment vector ---------------------------
; a0 <- &source
; a1 <- &target

CopyDosEnvec:
	move.l	(a0)+,d0		;# longwords in source..
	move.l	(a1)+,d1		;..and target
	cmp.l	d0,d1
	bcc.s	cde_loop

	move.l	d1,d0			;min(slength, tlength)
cde_loop:
	move.l	(a0)+,(a1)+
	subq.l	#1,d0
	bgt.s	cde_loop

	rts

;*** system resources **************************************
;--- get memory segment ------------------------------------
; d0 <- LONG lengthInBytes;
; d0 -> struct Segment *New or 0

AllocSegment:
	move.l	d2,-(sp)
	addq.l	#4,d0
	move.l	d0,d2
	move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
	CALLEXEC AllocMem
	tst.l	d0
	beq.s	as_end

	move.l	d0,a0
	move.l	d2,(a0)+		;remember length at offset -4
	move.l	a0,d0
as_end:
	move.l	(sp)+,d2
	rts

;--- free again --------------------------------------------
; a1 <- struct Segment *old

FreeSegment:
	move.l	-(a1),d0
	CALLEXEC FreeMem
	rts

;--- terminate disk device access --------------------------
; a1 <- struct IORequest **old;

ShutdownDevice:
	move.l	a2,-(sp)
	move.l	a1,a2			;&&IORequest
	move.l	(a2),d0
	beq.s	sdd_end			;no Request

	move.l	d0,a1
	tst.l	IO_Device(a1)
	beq.s	sdd_free

; commented out for corrupting memory
;	CALLEXEC WaitIO			;finish last access
;	move.l	(a2),a1

	CALLEXEC CloseDevice
sdd_free:
	move.l	(a2),a1
	bsr.w	FreeMsg
	clr.l	(a2)
sdd_end:
	move.l	(sp)+,a2
	rts

;--- general shutdown --------------------------------------

CloseAll:
	lea	InputRequest(a4),a1
	bsr.s	ShutdownDevice
	lea	TimeRequest(a4),a1
	bsr.s	ShutdownDevice
	lea	DiskRequest(a4),a1
	bsr.s	ShutdownDevice

	move.l	ReplyPort(a4),a1
	bsr.w	FreeMsgPort
	clr.l	ReplyPort(a4)

	move.l	IntBase(a4),d0
	beq.s	ca_1

	move.l	d0,a1
	CALLEXEC CloseLibrary
	clr.l	IntBase(a4)
ca_1:
	move.l	GrafBase(a4),d0
	beq.s	ca_end

	move.l	d0,a1
	CALLEXEC CloseLibrary
	clr.l	GrafBase(a4)
ca_end:
	rts

;--- general opening ---------------------------------------
; d0 -> error code or 0

OpenAll:
	movem.l	d4/a2,-(sp)
	moveq.l	#103,d4			;"no mem"
	tst.l	DosBase(a4)
	beq.w	oa_err

	bsr.w	CacheInit
	bsr.w	AllocMsgPort
	move.l	d0,ReplyPort(a4)	;for *.device replies
	beq.w	oa_err

	move.l	d0,a0			;&ReplyPort
	move.l	pr_MsgPort(a4),a1
	moveq.l	#0,d0
	moveq.l	#0,d1
	move.b	MP_SigBit(a0),d0
	bset	d0,d1
	move.b	MP_SigBit(a1),d0
	bset	d0,d1
	move.l	d1,SignalSet(a4)

;- - disk device - - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#IO_Sizeof,d0
	bsr.w	AllocMsg
	move.l	d0,DiskRequest(a4)
	beq.w	oa_err

	moveq.l	#115,d4			;"invalid parameters"
	movem.l	d2-d7/a2-a5,-(sp)	;workaround for..
	move.l	DevName(a4),a0
	move.l	UnitNumber(a4),d0
	move.l	DiskRequest(a4),a1
	move.l	DeviceFlags(a4),d1
	CALLEXEC OpenDevice
	movem.l	(sp)+,d2-d7/a2-a5	;..buggy devices
	tst.w	d0
	bne.w	oa_err

	tst.b	DosType+3(a4)
	seq	d0
	and.w	#1,d0			;DosType "FAT\0" = "use ETD"
	or.w	#$0308,d0		;enable date features and TD_UPDATE
	move.w	d0,CmdFlags(a4)
	move.l	EnvecBuf+DE_Control(a4),d0
	lsl.l	#2,d0
	beq.s	oa_1

	addq.l	#1,d0
	move.l	d0,a0
	bsr.w	SetOptions
oa_1:
	move.l	DiskRequest(a4),a1
	move.w	#NSCMD_DEVICEQUERY,IO_Command(a1)
	lea	QueryResult(a4),a0
	move.l	a0,IO_Data(a1)
	moveq.l	#QR_Sizeof,d0
	move.l	d0,IO_Length(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	oa_cend			;no NSD

	move.l	DiskRequest(a4),a1
	moveq.l	#QR_Sizeof,d0
	cmp.l	IO_Actual(a1),d0
	bne.s	oa_cend			;invalid..

	cmp.l	QueryResult+QR_SizeAvailable(a4),d0
	bne.s	oa_cend			;..reply

	cmp.w	#NSDEVTYPE_TRACKDISK,QueryResult+QR_DeviceType(a4)
	bne.w	oa_err			;no xxdisk.device

	move.l	QueryResult+QR_SupportedCmds(a4),d0
	beq.s	oa_cend

	move.l	d0,a0			;&list of supported commands
	moveq.l	#-4,d1
	and.w	CmdFlags(a4),d1
oa_cscan:
	move.w	(a0)+,d0
	beq.s	oa_cok

	cmp.w	#ETD_READ,d0
	bne.s	oa_2

	or.w	#1,d1			;"ETD available"
oa_2:
	cmp.w	#NSCMD_TD_READ64,d0
	bne.s	oa_3

	or.w	#2,d1			;"TD64 available"
oa_3:
	cmp.w	#"TJ",d0
	bne.s	oa_4

	or.w	#16,d1			;TJ. extensions available"
oa_4:
	bra.s	oa_cscan
oa_cok:
	move.w	d1,CmdFlags(a4)
oa_cend:

;- - timer.device - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#103,d4			;"no mem"
	moveq.l	#TR_Sizeof,d0
	move.l	ReplyPort(a4),a0
	bsr.w	AllocMsg
	move.l	d0,TimeRequest(a4)
	beq.w	oa_err

	move.l	d0,a1
	lea	TimerName(pc),a0
	moveq.l	#UNIT_VBLANK,d0
	moveq.l	#0,d1
	CALLEXEC OpenDevice
	tst.w	d0
	bne.w	oa_err

	move.l	TimeRequest(a4),a1
	move.w	#TR_ADDREQUEST,IO_Command(a1)
	clr.l	TR_Seconds(a1)
	move.l	#200000,TR_Micros(a1)	;wait 0.2 seconds..
	CALLEXEC DoIO			;..for some disk.devices readying

	move.l	TimeRequest(a4),a0
	move.b	#IOF_QUICK,IO_Flags(a0)	;WaitIO() sees Request finished

;- - input.device and intuition.library - - - - - - - - - -

	moveq.l	#IO_SimpleSizeof,d0
	move.l	ReplyPort(a4),a0
	bsr.w	AllocMsg
	move.l	d0,InputRequest(a4)
	beq.s	oa_err

	move.l	d0,a1
	lea	InputName(pc),a0
	moveq.l	#0,d0
	moveq.l	#0,d1
	CALLEXEC OpenDevice
	tst.w	d0
	bne.s	oa_err

	move.l	InputRequest(a4),a0
	move.b	#IOF_QUICK,IO_Flags(a0)	;WaitIO() sees Request finished

	moveq.l	#0,d0
	lea	IntName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,IntBase(a4)
	moveq.l	#0,d0
	lea	GrafName(pc),a1
	CALLEXEC OpenLibrary
	move.l	d0,GrafBase(a4)
	moveq.l	#0,d4			;"OK"
oa_end:
	move.l	d4,d0
	movem.l	(sp)+,d4/a2
	rts

oa_err:
	bsr.w	CloseAll		;partial failure
	bra.s	oa_end

TimerName:
	dc.b	"timer.device",0
InputName:
	dc.b	"input.device",0
IntName:
	dc.b	"intuition.library",0
GrafName:
	dc.b	"graphics.library",0
FSRName:
	dc.b	"FileSystem.resource",0
	even

NodeName:
	dc.b	"fat95",0
IDStr:
	VERSION_STRING
	dc.b	" (c) Torsten Jager, modified 2026 by Jaroslav Pulchart", LF, 0
	even

;--- ROM-Code init -----------------------------------------
; d0 <- 0
; a0 <- SegList
; a6 <- &ExecBase

InitCode:
	move.l	#"FAT"<<8+1,d0		;continued below

;--- register with filesystem.resource ---------------------
; d0 <- DosType
; a6 <- ExecBase
; d0 -> SegList or 0

RegisterFS:
	movem.l	d2-d3/a2-a3,-(sp)
	move.l	d0,d3			;DosType
	lea	FSRName(pc),a1
	jsr	OpenResource(a6)
	tst.l	d0
	beq.s	rfs_end

	move.l	d0,a2			;&FileSystemResource
	jsr	Forbid(a6)
	move.l	FSR_List(a2),d2
rfs_search:
	move.l	d2,a3			;&FileSystemEntry
	move.l	(a3),d2
	beq.s	rfs_new

	cmp.l	FSE_DosType(a3),d3
	bne.s	rfs_search

	jsr	Permit(a6)
	tst.l	LN_Name(a3)
	bne.s	rfs_ok
rfs_name:
	lea	IDStr(pc),a1
	move.l	a1,LN_Name(a3)
rfs_ok:
	move.l	FSE_SegList(a3),d0
rfs_end:
	movem.l	(sp)+,d2-d3/a2-a3
	rts

rfs_new:
	jsr	Permit(a6)
	moveq.l	#FSE_MySizeof,d0
	move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
	jsr	AllocMem(a6)
	tst.l	d0
	beq.s	rfs_end

	move.l	d0,a3			;new &FileSystemEntry
	move.l	d3,FSE_DosType(a3)
	move.l	#FILE_VERSION<<16+FILE_REVISION,FSE_Version(a3)
	move.w	#$0190,FSE_PatchFlags+2(a3)
	move.w	#4096,FSE_StackSize+2(a3)
	lea	Start(pc),a0
	move.l	a0,d0
	subq.l	#4,d0
	lsr.l	#2,d0
	move.l	d0,FSE_SegList(a3)
	moveq.l	#-1,d0
	move.l	d0,FSE_GlobVec(a3)
	jsr	Forbid(a6)
	lea	FSR_List(a2),a0
	move.l	a3,a1
	bsr.w	MyAddHead
	jsr	Permit(a6)
	bra.s	rfs_name

;--- invert unicode tables ---------------------------------

InvertCodePage:
	move.l	CodePage(a4),d0
	beq.w	icp_oem

	moveq.l	#256/4,d1
icp_1:
	clr.l	-(sp)			;head
	subq.w	#1,d1
	bgt.s	icp_1

	move.l	d0,a0
	moveq.l	#0,d0
	move.w	#256,d1
icp_2:
	move.b	(a0),d0
	addq.l	#2,a0
	move.b	#1,(sp,d0.l)		;mark used pages
	subq.w	#1,d1
	bgt.s	icp_2

	move.l	sp,a0
	moveq.l	#1,d0
	move.w	#256,d1
icp_3:
	tst.b	(a0)
	beq.s	icp_4

	move.b	d0,(a0)			;assign page bufs
	addq.w	#1,d0
icp_4:
	addq.l	#1,a0
	subq.w	#1,d1
	bgt.s	icp_3

	lsl.w	#8,d0
	move.l	d0,InvCodeLen(a4)
	moveq.l	#MEMF_NORM,d1
	CALLEXEC AllocMem		;main table
	move.l	d0,InvCodePage(a4)
	beq.s	icp_break

	move.l	sp,a0
	move.l	d0,a1
	moveq.l	#256/4,d1
icp_5:
	move.l	(a0)+,(a1)+		;copy head
	subq.w	#1,d1
	bgt.s	icp_5

	move.l	InvCodeLen(a4),d1
	lsr.l	#2,d1
	moveq.l	#256/4,d0
	sub.l	d0,d1
	move.l	#"____",d0
icp_6:
	move.l	d0,(a1)+		;line defaults
	subq.w	#1,d1
	bgt.s	icp_6

	move.l	CodePage(a4),a0
	move.l	InvCodePage(a4),a1
	moveq.l	#0,d1
icp_7:
	moveq.l	#0,d0
	move.b	(a0)+,d0
	move.b	(a1,d0.l),d0
	lsl.w	#8,d0
	move.b	(a0)+,d0
	move.b	d1,(a1,d0.l)		;write chars
	addq.w	#1,d1
	cmp.w	#256,d1
	bcs.s	icp_7
icp_break:
	add.w	#256,sp
icp_oem:
	tst.l	OemPage(a4)
	beq.s	icp_end			;if requested..

	moveq.l	#64,d0
	lsl.l	#1,d0
	moveq.l	#MEMF_NORM,d1
	CALLEXEC AllocMem
	move.l	d0,InvOemPage(a4)	;..same thing again..
	beq.s	icp_end

	move.l	d0,a1
	moveq.l	#32,d0
	move.l	#$80818283,d1		;..for chars 128 ~ 255..
icp_ofill:
	move.l	d1,(a1)+		;..of standard names
	add.l	#$04040404,d1
	subq.w	#1,d0
	bgt.s	icp_ofill

	move.l	OemPage(a4),a0
	add.w	#64,a0
	move.l	InvOemPage(a4),a1
	move.w	#$df,d0
icp_oscan:
	moveq.l	#0,d1
	move.b	-(a0),d1
	bpl.s	icp_osnext

	and.b	#$7f,d1
	move.b	d0,(a1,d1.l)		;invert OEM char matrix
icp_osnext:
	subq.w	#1,d0
	cmp.w	#$a0,d0
	bcc.s	icp_oscan
icp_end:
	rts

;--- free inverse tabs -------------------------------------

FreeInvTables:
	move.l	InvCodePage(a4),d1
	beq.s	fit_1

	move.l	InvCodeLen(a4),d0
	move.l	d1,a1
	CALLEXEC FreeMem
fit_1:
	move.l	InvOemPage(a4),d1
	beq.s	fit_end

	moveq.l	#64,d0
	lsl.l	#1,d0
	move.l	d1,a1
	CALLEXEC FreeMem
fit_end:
	rts

;--- rename volume -----------------------------------------
; <- BPTR_BSTR Name;
; -> BOOL ok;

RD_MSDEBUF	= -XMSDE_Sizeof
RD_FROM		= RD_MSDEBUF-6
RD_TO		= RD_MSDEBUF-12
RD_NAME		= RD_MSDEBUF-24

RenameDisk:
	link.w	a5,#RD_NAME
	movem.l	d2-d3/a2,-(sp)

	move.l	RootXLock(a4),a0
	tst.l	XL_Key(a0)
	beq.s	rd_check		;if present..

	clr.b	XL_MSDE+MSDE_Flags(a0)
	bsr.w	DeleteXLock		;..delete old disk name
	move.l	RootXLock(a4),a0
	clr.l	XL_Key(a0)
rd_check:
	move.l	8(a5),a0
	lea	RD_NAME(a5),a1
	bsr.w	BStr2DiskName
	tst.l	d0
	bne.s	rd_set			;new name valid
rd_ok:
	bsr.w	TouchBootBlock
	move.l	RootXLock(a4),a0
	move.l	SerialNum(a4),d0
	swap	d0
	move.l	d0,XL_MSDE+MSDE_CTime(a0)
	tst.l	XL_Key(a0)
	bne.s	rd_1

	pea	XL_MSDE(a0)
	bsr.w	GetDefVolName
	addq.l	#4,sp
	bra.s	rd_2
rd_1:
	add.w	#XL_MSDE,a0		;&MSDirEntry
	move.l	MSDE_Time(a0),d2	;save root date..
	move.l	MSDE_CTime(a0),d0
	move.l	d0,MSDE_Time(a0)	;put disk date here temporarily
	clr.l	MSDE_CTime(a0)
	clr.l	-(sp)
	move.l	a0,-(sp)
	bsr.w	WriteXMSDE
	addq.l	#8,sp
	move.l	RootXLock(a4),a0
	add.w	#XL_MSDE,a0		;&MSDirEntry
	move.l	MSDE_Time(a0),d0
	move.l	d0,MSDE_CTime(a0)
	move.l	d2,MSDE_Time(a0)	;..and restore
rd_2:
	bsr.w	TouchVolumeNode
	moveq.l	#TRUE,d0
rd_end:
	movem.l	(sp)+,d2-d3/a2
	unlk	a5
	rts

rd_error:
	moveq.l	#FALSE,d0
	bra.s	rd_end

rd_set:
	lea	RD_MSDEBUF(a5),a2	;optimize
	pea	RD_TO(a5)
	bsr.s	PackRootDir		;densify root dir
	move.l	RootCluster(a4),d0
	bsr.w	Cluster2Block
	move.l	d0,RD_FROM(a5)
	clr.w	RD_FROM+4(a5)
	move.l	a2,-(sp)
	pea	RD_FROM(a5)
	bsr.w	ReadXMSDE		;read first entry and..
	move.l	a2,-(sp)
	pea	RD_TO(a5)
	move.l	RootXLock(a4),-(sp)
	bsr.w	CheckDirSpace		;..if there is room,..
	add.w	#24,sp
	tst.l	RD_TO(a5)
	beq.s	rd_error

	pea	RD_TO(a5)
	move.l	a2,-(sp)
	bsr.w	MoveXMSDE		;..move it to end
	addq.l	#8,sp

	move.l	RootXLock(a4),a2
	move.l	RootCluster(a4),d0
	bsr.w	Cluster2Block
	move.l	d0,XL_Key(a2)
	clr.w	XL_Offset(a2)		;new first entry = disk name
	lea	RD_NAME(a5),a0
	lea	XL_MSDE(a2),a1		;&MSDirEntry of root
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+		;MSDE_Name...MSDE_Flags
	bra.w	rd_ok

;--- densify root dir --------------------------------------
; <- struct DiskKey *first free position;

PRD_MSDEBUF	= -XMSDE_Sizeof
PRD_FROM	= PRD_MSDEBUF-8

PackRootDir:
	link.w	a5,#PRD_FROM
	move.l	a2,-(sp)
	move.l	RootCluster(a4),d0
	bsr.s	Cluster2Block
	move.l	d0,PRD_FROM(a5)
	clr.w	PRD_FROM+4(a5)		;source..
	move.l	8(a5),a0
	move.l	d0,(a0)+
	clr.w	(a0)			;..= target = start of root dir
	lea	PRD_MSDEBUF(a5),a2	;optimize
prd_loop:
	tst.l	PRD_FROM(a5)
	beq.s	prd_end			;end of dir

	move.l	a2,-(sp)
	pea	PRD_FROM(a5)
	bsr.w	ReadXMSDE
	addq.w	#8,sp
	tst.w	d0
	beq.s	prd_error		;read error

	move.b	(a2),d0
	beq.s	prd_end			;unused entry, stop

	cmp.b	#MSDEB_DELETED,d0
	beq.s	prd_loop		;skip deleted entry

	move.l	8(a5),-(sp)
	move.l	a2,-(sp)
	bsr.w	MoveXMSDE
	addq.l	#8,sp
	bra.s	prd_loop
prd_end:
	move.l	(sp)+,a2
	unlk	a5
	rts

prd_error:
	moveq.l	#-1,d0
	bra.s	prd_end

;--- endian conversion Motorola <-> Intel ------------------

ReverseW	macro			;reverse word
		rol.w	#8,\1
		endm

ReverseL	macro			;reverse longword
		rol.w	#8,\1
		swap	\1
		rol.w	#8,\1
		endm


; a0 <- struct MSDirEntry *source;
; a1 <- struct MSDirEntry *target;

RCopyMSDE:
	move.l	(a0)+,(a1)+		;MSDE_Name through..
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
R2CopyMSDE:
	move.w	(a0)+,(a1)+		;..MSDE_CMilSecs
	moveq.l	#(MSDE_FSize-MSDE_CTime)/2,d1
rcm_loop:
	move.w	(a0)+,d0
	ReverseW d0
	move.w	d0,(a1)+		;reverse CTime through 1L words,..
	subq.w	#1,d1
	bgt.s	rcm_loop

	move.l	(a0),d0
	ReverseL d0
	move.l	d0,(a1)			;..FSize longword
	rts

;--- Cluster # -> Block # ----------------------------------
; !attention! preserve a1
; d0 <- Cluster #;
; d0 -> Block #;

Cluster2Block:
	subq.l	#2,d0			;data clusters start with # 2
	bcs.s	c2b_root
c2b_ok:
	move.w	ClusterShift(a4),d1
	lsl.l	d1,d0
	add.l	RootDirEnd(a4),d0
c2b_end:
	rts

c2b_root:
	move.l	RootCluster(a4),d0
	subq.l	#2,d0
	bcc.s	c2b_ok

	move.l	RootStartBlock(a4),d0	;Cluster 0 = root dir
	bra.s	c2b_end

;--- Block # -> Cluster # ----------------------------------
; d0 <- Block #;
; d1 -> Cluster #;

Block2Cluster:
	sub.l	RootDirEnd(a4),d0
	bcs.s	b2c_error		;outside data area

	move.w	ClusterShift(a4),d1
	lsr.l	d1,d0
	addq.l	#2,d0
b2c_end:
	rts

b2c_error:
	moveq.l	#0,d0
	bra.s	b2c_end

;--- follow block chain ------------------------------------
; d0 <- Block #;
; d0 -> next block # or 0

NextBlock:
	move.l	d2,-(sp)
	addq.l	#1,d0			;1 block further..
	move.l	RootDirEnd(a4),d2
	move.l	d0,d1
	sub.l	d2,d1
	bcs.s	nbl_end			;..is still inside root dir
	beq.s	nbl_stop		;..is end of root dir

	move.b	BlocksPerCluster(a4),d2
	subq.b	#1,d2
	and.b	d1,d2
	beq.s	nbl_fat			;..is in next cluster

	cmp.l	TotalBlocks(a4),d0	;last Cluster is sometimes smaller (?)
	bcs.s	nbl_end			;..is in same cluster
nbl_fat:
	subq.l	#1,d1
	move.w	ClusterShift(a4),d2
	lsr.l	d2,d1
	addq.l	#2,d1			;old cluster #
	move.l	d1,d0
	bsr.w	NextCluster
	tst.l	d0
	bmi.s	nbl_stop		;end of chain

	bsr.s	Cluster2Block
nbl_end:
	move.l	(sp)+,d2
	rts

nbl_stop:
	moveq.l	#0,d0
	bra.s	nbl_end

;*** format disk *******************************************
;--- set boot block serial ---------------------------------

TouchBootBlock:
	link.w	a5,#-DS_Sizeof
	move.l	a2,-(sp)
	moveq.l	#0,d0
	bsr.w	ReadSingle
	tst.l	d0
	beq.s	tbb_end

	move.l	d0,a2			;&block contents
	bsr.w	BlockChanged
	pea	-DS_Sizeof(a5)
	bsr.w	_DateStamp
	pea	-DS_Sizeof(a5)
	bsr.w	Date2MS
	addq.l	#8,sp
	move.l	d0,SerialNum(a4)	;MS_date << 16 + MS_time..
	lea	38(a2),a1
	tst.w	FATType(a4)
	bpl.s	tbb_1

	lea	66(a2),a1		;different position in FAT32
tbb_1:
	cmp.b	#$29,(a1)+		;older boot blocks..
	bne.s	tbb_end			;..are without this information

	move.b	d0,(a1)+
	move.b	SerialNum+2(a4),(a1)+
	move.b	SerialNum+1(a4),(a1)+
	move.b	SerialNum(a4),(a1)+	;..goes here
	move.l	RootXLock(a4),d0
	beq.s	tbb_end			;if known..

	move.l	d0,a0
	add.w	#XL_MSDE,a0
	tst.l	XMSDE_Key(a0)
	bne.s	tbb_2

	lea	tbb_default(pc),a0
tbb_2:
	moveq.l	#11,d0
tbb_nloop:
	move.b	(a0)+,(a1)+		;..update name as well
	subq.w	#1,d0
	bgt.s	tbb_nloop
tbb_end:
	move.l	(sp)+,a2
	unlk	a5
	rts

tbb_default:
	dc.b	"NO NAME     "

;--- check formatting prerequisites ------------------------
; -> BOOL ok;

CheckInhibited:
	move.w	#202,d1			;"in use"
	tst.w	InhibitNest(a4)
	beq.s	chi_error		;too dangerous!!

	bsr.w	GetDiskParams		;set params
	move.w	#226,d1
	roxr.w	#1,d0
	bcc.s	chi_error		;no disk

	move.w	#214,d1
	roxr.w	#1,d0
	bcc.s	chi_error		;hard or..

	tst.w	SoftLocked(a4)
	bne.s	chi_error		;..soft write protection

	move.w	#225,d1
	roxr.w	#1,d0
	bcc.s	chi_error		;no Low-Level-Format

	moveq.l	#TRUE,d0		;"OK"
chi_end:
	rts

chi_error:
	move.w	d1,ErrorNum(a4)
	moveq.l	#FALSE,d0
	bra.s	chi_end

;--- logical formatting ------------------------------------
; <- BPTR_BSTR Name, LONG DosType;
; -> BOOL ok;

FormatDisk:
	link.w	a5,#-12
	movem.l	d2-d4/a2,-(sp)

;- - prerequisites - - - - - - - - - - - - - - - - - - - - -

	bsr.s	CheckInhibited
	move.l	d0,d2
	beq.w	fmd_end

;- - name & date - - - - - - - - - - - - - - - - - - - - - -

	pea	-12(a5)
	bsr.w	_DateStamp
	pea	-12(a5)
	bsr.w	Date2MS
	addq.l	#8,sp
	move.l	d0,SerialNum(a4)	;MS_date << 16 + MS_time

	move.l	8(a5),a0
	lea	-12(a5),a1
	bsr.w	BStr2DiskName		;MSDE_Name[11] + MSDE_Flags

;- - Bootblock  - - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#63,d2			;usually 63 or..
	move.w	BlocksPerTrack(a4),d0
	cmp.w	d0,d2
	bcc.s	fd_t4
fd_t1:
	move.l	FirstBlock(a4),d0
	move.l	d2,d1
	UDIVMOD32
	tst.l	d1
	bne.s	fd_t2

	move.l	FirstBlock(a4),d0
	add.l	TotalBlocks(a4),d0
	move.l	d2,d1
	UDIVMOD32
	tst.l	d1
	beq.s	fd_t3
fd_t2:
	move.l	d2,d0
	moveq.l	#32,d2			;..32 blocks/track
	cmp.l	d2,d0
	bgt.s	fd_t1

	moveq.l	#1,d2
fd_t3:
	move.w	d2,BlocksPerTrack(a4)
fd_t4:
	moveq.l	#MSDE_Sizeof,d0
	add.w	BlockSize(a4),d0
	move.l	BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,a2
	tst.l	d0
	beq.w	fmd_nomem

	lea	BootSample12(pc),a0
	move.w	FATType(a4),d4
	bpl.s	fmd_b1

	add.w	#BootSample32-BootSample12,a0
fmd_b1:
	move.l	a2,a1
	moveq.l	#512/8,d0
fmd_bcopy:
	move.l	(a0)+,(a1)+		;copy standard boot block
	move.l	(a0)+,(a1)+
	subq.w	#1,d0
	bgt.s	fmd_bcopy

	lea	24(a2),a1		;update parameters
	move.b	BlocksPerTrack+1(a4),(a1)+
	move.b	BlocksPerTrack(a4),(a1)+
	move.b	Surfaces+1(a4),(a1)+
	move.b	Surfaces(a4),(a1)+
	move.b	HiddenBlocks+3(a4),(a1)+
	move.b	HiddenBlocks+2(a4),(a1)+
	move.b	HiddenBlocks+1(a4),(a1)+
	move.b	HiddenBlocks(a4),(a1)+
	lea	11(a2),a1
	move.b	BlockSize+1(a4),(a1)+
	move.b	BlockSize(a4),(a1)+
	move.b	BlocksPerCluster(a4),(a1)+
	move.b	FATStartBlock+1(a4),(a1)+
	move.b	FATStartBlock(a4),(a1)+
	move.b	NumFATCopies(a4),(a1)+
	tst.w	d4
	bmi.s	fmd_u1

	move.l	RootDirEnd(a4),d0
	sub.l	RootStartBlock(a4),d0
	move.w	BlockShift(a4),d1
	lsl.l	d1,d0
	lsr.l	#5,d0			;/= MSDE_Sizeof
	move.b	d0,(a1)+
	ror.w	#8,d0
	move.b	d0,(a1)+
	tst.w	TotalBlocks(a4)		;H-word only!!
	bne.s	fmd_u1

	move.b	TotalBlocks+3(a4),(a1)+
	move.b	TotalBlocks+2(a4),(a1)+	;is < 64K
	bra.s	fmd_u2
fmd_u1:
	lea	32(a2),a1
	move.b	TotalBlocks+3(a4),(a1)+
	move.b	TotalBlocks+2(a4),(a1)+
	move.b	TotalBlocks+1(a4),(a1)+
	move.b	TotalBlocks(a4),(a1)+	;is >= 64K
	tst.w	d4
	bpl.s	fmd_u2

	move.b	BlocksPerFAT+3(a4),(a1)+
	move.b	BlocksPerFAT+2(a4),(a1)+
	move.b	BlocksPerFAT+1(a4),(a1)+
	move.b	BlocksPerFAT(a4),(a1)+
	lea	67(a2),a1
	bra.s	fmd_u3
fmd_u2:
	lea	22(a2),a1
	move.b	BlocksPerFAT+3(a4),(a1)+
	move.b	BlocksPerFAT+2(a4),(a1)+
	lea	39(a2),a1
fmd_u3:
	move.b	SerialNum+3(a4),(a1)+	;Serial # and..
	move.b	SerialNum+2(a4),(a1)+
	move.b	SerialNum+1(a4),(a1)+
	move.b	SerialNum(a4),(a1)+
	lea	-12(a5),a0
	moveq.l	#11,d0
fmd_u4:
	move.b	(a0)+,(a1)+		;..Name
	subq.w	#1,d0
	bgt.s	fmd_u4

	tst.w	d4
	ble.s	fmd_u5			;FAT12 sample boot block or..

	move.b	#$f8,21(a2)		;.. adapt media description..
	move.b	#'6',58(a2)		;..for "FAT16"
fmd_u5:
	moveq.l	#0,d0
	move.l	a2,a0
	bsr.w	_WBlock
	tst.w	d4
	bpl.w	fmd_fstart		;FAT32 only

	moveq.l	#6,d0
	move.l	a2,a0
	bsr.w	_WBlock			;FAT32: Boot block duplicate

;- - Boot routine continuation - - - - - - - - - - - - - - -

	lea	ExtBoot32(pc),a0
	move.l	a2,a1
	moveq.l	#(ExtBootEnd-ExtBoot32)/8,d0
fmd_xbcopy:
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	subq.w	#1,d0
	bgt.s	fmd_xbcopy

	moveq.l	#(ExtBoot32+508-ExtBootEnd)/4,d0
	moveq.l	#0,d1
fmd_xbfill:
	move.l	d1,(a1)+
	subq.w	#1,d0
	bgt.s	fmd_xbfill

	moveq.l	#2,d0
	move.l	a2,a0
	bsr.w	_WBlock			;ExtBootBlock and..
	moveq.l	#8,d0
	move.l	a2,a0
	bsr.w	_WBlock			;..dupl

;- - FileSysInfoBlock - - - - - - - - - - - - - - - - - - -

	bsr.w	fmd_clrbuf
	move.l	#"RRaA",(a2)
	lea	484(a2),a0
	move.l	#"rrAa",(a0)+
	moveq.l	#-1,d0
	move.l	d0,(a0)+
	move.b	#2,(a0)
	move.w	#$55aa,510(a2)
	moveq.l	#7,d0
	move.l	a2,a0
	bsr.w	_WBlock			;dupl
	moveq.l	#0,d0
	move.b	BlocksPerCluster(a4),d0
	LOG2
	move.l	TotalBlocks(a4),d1
	sub.l	RootDirEnd(a4),d1	;# free data blocks
	lsr.l	d0,d1
	subq.l	#1,d1			;use 1 root cluster
	ReverseL d1
	move.l	d1,488(a2)
	moveq.l	#1,d0
	move.l	a2,a0
	bsr.w	_WBlock			;the Info-Block itself

;- - unused head blocks  - - - - - - - - - - - - - - - - - -

	bsr.w	fmd_clrbuf
	moveq.l	#3,d2
	moveq.l	#3,d3
fmd_clr1:
	move.l	d2,d0
	move.l	a2,a0
	bsr.w	_WBlock			;blocks #3..5
	addq.l	#1,d2
	subq.w	#1,d3
	bgt.s	fmd_clr1

	moveq.l	#9,d2
	move.w	FATStartBlock(a4),d3
	sub.w	d2,d3
fmd_clr2:
	move.l	d2,d0
	move.l	a2,a0
	bsr.w	_WBlock			;blocks #9..(usually) 31
	addq.l	#1,d2
	subq.w	#1,d3
	bgt.s	fmd_clr2

;- - FAT  - - - - - - - - - - - - - - - - - - - - - - - - -

fmd_fstart:
	bsr.w	fmd_clrbuf
	tst.w	FATType(a4)
	beq.s	fmd_f12
	bgt.s	fmd_f16

	move.l	#$f8ffff0f,(a2)
	move.l	#$ffffff0f,d0
	move.l	d0,4(a2)
	move.l	d0,8(a2)		;1 FAT32 root cluster
	bra.s	fmd_fdo
fmd_f16:
	move.l	#$f8ffffff,(a2)
	bra.s	fmd_fdo
fmd_f12:
	move.l	#$f9ffff00,(a2)
fmd_fdo:
	moveq.l	#0,d2
	move.w	FATStartBlock(a4),d2
	move.b	NumFATCopies(a4),d4
fmd_fat:
	move.l	BlocksPerFAT(a4),d3
	move.l	a2,a0
	add.w	#MSDE_Sizeof,a2
	bra.s	fmd_fwrite
fmd_fblock:
	move.l	a2,a0
fmd_fwrite:
	move.l	d2,d0
	bsr.w	_WBlock
	addq.l	#1,d2
	subq.l	#1,d3
	bgt.s	fmd_fblock

	sub.w	#MSDE_Sizeof,a2
	subq.b	#1,d4
	bgt.s	fmd_fat

;- - root dir  - - - - - - - - - - - - - - - - - - - - - - -

	lea	-12(a5),a0
	move.l	a2,a1
	move.l	(a0)+,(a1)+		;make Name entry..
	move.l	(a0)+,(a1)+
	move.l	(a0),(a1)
	move.l	SerialNum(a4),d0
	ReverseL d0
	move.l	d0,MSDE_Time(a2)	;..and date it
	move.l	RootDirEnd(a4),d3
	sub.l	d2,d3
	bne.s	fmd_rstart

	move.b	BlocksPerCluster(a4),d3
fmd_rstart:
	move.l	a2,a0
	add.w	#MSDE_Sizeof,a2
	bra.s	fmd_rwrite
fmd_rblock:
	move.l	a2,a0
fmd_rwrite:
	move.l	d2,d0
	bsr.w	_WBlock
	addq.l	#1,d2
	subq.l	#1,d3
	bgt.s	fmd_rblock

	sub.w	#MSDE_Sizeof,a2
	moveq.l	#MSDE_Sizeof,d0
	add.w	BlockSize(a4),d0
	move.l	a2,a1
	CALLEXEC FreeMem

fmd_ok:
	moveq.l	#TRUE,d2
fmd_close:
	bsr.w	CacheFlush		;write buffers
	bsr.w	DiskUpdate
	and.w	#$fff1,NewFlags(a4)	;just motor still running
fmd_end:
	bsr.w	CacheFree
	move.l	d2,d0
	movem.l	(sp)+,d2-d4/a2
	unlk	a5
	rts

fmd_nomem:
	move.w	#103,ErrorNum(a4)
	moveq.l	#FALSE,d2
	bra.s	fmd_close

fmd_clrbuf:
	moveq.l	#MSDE_Sizeof,d0
	add.w	BlockSize(a4),d0
	moveq.l	#0,d1
	move.l	a2,a0
fmd_cloop:
	move.l	d1,(a0)+
	move.l	d1,(a0)+
	subq.l	#8,d0
	bgt.s	fmd_cloop

	rts

;--- update disk date --------------------------------------
; -> BOOL ok;

SDI_KEY		= -8
SDI_MSDEBUF	= -8-XMSDE_Sizeof

SerializeDisk:
	link.w	a5,#SDI_MSDEBUF
	movem.l	d2/a2,-(sp)
	bsr.w	CheckInhibited
	move.l	d0,d2
	beq.s	sdi_end

	moveq.l	#FALSE,d2
	move.l	DosType(a4),d0
	cmp.l	DiskType(a4),d0
	bne.s	sdi_ndos

	bsr.w	TouchBootBlock		;set serial
	move.l	RootCluster(a4),d0
	bsr.w	Cluster2Block
	move.l	d0,SDI_KEY(a5)
	clr.w	SDI_KEY+4(a5)		;start of root dir
	lea	SDI_MSDEBUF(a5),a2	;&MSDEBuffer
sdi_loop:
	move.l	a2,-(sp)
	pea	SDI_KEY(a5)
	bsr.w	ReadXMSDE
	addq.l	#8,sp
	tst.w	d0
	beq.s	sdi_update		;end of root dir,..

	move.b	(a2),d0
	beq.s	sdi_update		;..no Disk name

	cmp.b	#MSDEB_DELETED,d0
	beq.s	sdi_loop		;skip deleted and..

	btst	#3,MSDE_Flags(a2)
	beq.s	sdi_loop		;..normal entries

	move.l	SerialNum(a4),d0	;put new date/time..
	swap	d0
	move.l	d0,MSDE_Time(a2)	;..to Disk name..
	clr.l	-(sp)
	move.l	a2,-(sp)
	bsr.w	WriteXMSDE		;..and write back
	addq.l	#8,sp
sdi_update:
	pea	(TRUE).w		;"immediately"
	bsr.w	UpdateDisk
	addq.l	#4,sp
	moveq.l	#TRUE,d2		;"OK"
sdi_end:
	bsr.s	CacheFree
	move.l	d2,d0
	movem.l	(sp)+,d2/a2
	unlk	a5
	rts

sdi_ndos:
	move.w	#225,ErrorNum(a4)
	bra.s	sdi_end

sdi_nomem:
	move.w	#103,ErrorNum(a4)
	bra.s	sdi_end

;*** Block cache *******************************************
;--- set parameters ----------------------------------------
; d0 -> # bufs

CacheSet:
CacheResize:
	moveq.l	#0,d0
	move.w	NumBuffers(a4),d0	;# buffers..
	bgt.s	crs_1

	moveq.l	#1,d0			;at least 1
	move.w	d0,NumBuffers(a4)
crs_1:
	moveq.l	#0,d1
	move.b	BlocksPerCluster(a4),d1
	beq.s	crs_end			;Geometry not yet known

	add.l	d1,d0
	subq.l	#1,d0			;..round up to..
	divu.w	d1,d0
	moveq.l	#3,d1
	cmp.w	d1,d0
	bcc.s	crs_2

	move.w	d1,d0			;..at least 3 (see MoveXMSDE())..
crs_2:
	move.w	d0,NormBufsNum(a4)	;..whole access windows
	ext.l	d0
	lsr.l	#1,d0			;reserve 1/2 of buffers for..
	move.w	d0,DirBufsMin(a4)	;..dirs
	moveq.l	#0,d0
	move.w	NumBuffers(a4),d0	;# bufs
crs_end:
	rts

;--- free all buffers --------------------------------------

CacheFree:
	move.l	BufList(a4),a0		;LH_Head
	tst.l	(a0)
	beq.s	cafr_single		;thats all

	bsr.s	FreeBlockBuf
	bra.s	CacheFree
cafr_single:
	move.l	SingleBuf(a4),d0
	beq.s	CacheInit

	move.l	d0,a1
	move.l	SingleSize(a4),d0
	CALLEXEC FreeMem

;--- start buffers -----------------------------------------

CacheInit:
	clr.l	SingleBuf(a4)
	lea	BufList(a4),a0
	bsr.w	InitList
	clr.w	NormBufsUsed(a4)
	clr.w	DirBufsUsed(a4)
	lea	FAT32List(a4),a0
	bsr.w	InitList		;caution!
	rts

;--- free 1 buffer -----------------------------------------
; a0 <- struct BlockBuffer *bb;

FreeBlockBuf:
	move.l	a2,-(sp)
	move.l	a0,a2
	move.l	a2,a1
	bsr.w	MyRemove
	tst.w	BB_OpenCnt(a2)
	bpl.s	fbb_1			;block unchanged

	move.l	a2,a0
	bsr.w	WriteBBuf		;write back
fbb_1:
	moveq.l	#BB_Data,d0
	add.l	ClusterSize(a4),d0
	move.l	a2,a1
	CALLEXEC FreeMem
	move.l	(sp)+,a2
	rts

;--- write all buffers -------------------------------------

CacheFlush:
	move.l	d2,-(sp)
	move.l	SingleBuf(a4),d0
	beq.s	cafl_again

	move.l	d0,a0
	tst.w	BB_OpenCnt(a0)
	bpl.s	cafl_again

	bsr.w	WriteBBuf
cafl_again:
	moveq.l	#-1,d1
	move.l	BufList(a4),d0
cafl_next:
	move.l	d0,a0
	move.l	(a0),d0
	beq.s	cafl_check		;end of list

	tst.w	BB_OpenCnt(a0)		;the changed block..
	bpl.s	cafl_next

	move.l	BB_BlockNum(a0),d2
	cmp.l	d1,d2			;..of lowest #..
	bcc.s	cafl_next

	move.l	d2,d1
	move.l	a0,a1
	bra.s	cafl_next
cafl_check:
	moveq.l	#-1,d0
	cmp.l	d0,d1
	beq.s	cafl_end		;thats all

	move.l	a1,a0
	bsr.w	WriteBBuf		;..to write back
	bra.s	cafl_again
cafl_end:
	move.l	(sp)+,d2
	rts

;--- write back Disk ---------------------------------------
; <- BOOL immediate;
; -> BOOL success;

UpdateDisk:
	move.l	d2,-(sp)
	btst	#3,NewFlags+1(a4)
	beq.s	ud_blocks

	bsr.s	UpdateFSInfo
	bsr.w	WriteFAT
ud_blocks:
	btst	#2,NewFlags+1(a4)
	beq.s	ud_check		;no changed blocks

	bsr.s	CacheFlush
ud_check:
	tst.l	8(sp)
	bne.s	ud_now

	moveq.l	#12,d0
	and.w	NewFlags(a4),d0
	beq.s	ud_now

	and.w	#~12,NewFlags(a4)
	bsr.s	DoTimer
	bra.s	ud_end

ud_now:
	btst	#1,NewFlags+1(a4)
	beq.s	ud_stop
ud_update:
	bsr.w	DiskUpdate
	tst.w	d0
	beq.s	ud_stop			;writing successful

	move.l	UIText+6*4(a4),-(sp)
	move.l	d0,-(sp)
	bsr.w	DoRequest		;report error
	addq.l	#8,sp
	tst.w	d0
	bne.s	ud_update		;"repeat"

ud_stop:
	btst	#0,NewFlags+1(a4)
	beq.s	ud_done

	bsr.w	DiskMotorOff
ud_done:
	clr.w	NewFlags(a4)

ud_end:
	moveq.l	#TRUE,d0
	move.l	(sp)+,d2
	rts

;--- update FileSysInfoBlock -------------------------------

UpdateFSInfo:
	move.l	FSInfoBlock(a4),d0
	beq.s	ufsi_end		;no Info-Block..

	bsr.w	ReadSingle
	tst.l	d0
	beq.s	ufsi_end		;..or unreadable

	move.l	d0,a1
	add.w	#488,a1
	move.l	FreeClusters(a4),d1
	ReverseL d1
	cmp.l	(a1),d1
	beq.s	ufsi_end		;no change

	move.l	d1,(a1)
	bsr.w	BlockChanged
	bsr.w	WriteBBuf
ufsi_end:
	rts

;*** Timing control ****************************************
;--- start timeout -----------------------------------------

DoTimer:
	move.l	TimeRequest(a4),a1
	CALLEXEC CheckIO
	tst.l	d0
	beq.s	doti_end		;timeout still running

	move.l	TimeRequest(a4),a1
	CALLEXEC WaitIO			;get back TimeRequest
	move.l	TimeRequest(a4),a1
	move.w	#TR_ADDREQUEST,IO_Command(a1)
	moveq.l	#1,d0
	move.l	d0,TR_Seconds(a1)	;1 second
	clr.l	TR_Micros(a1)		;0 microseconds
	CALLEXEC SendIO			;restart timer
doti_end:
	rts

;--- report diskchange -------------------------------------

ChangeReport:
	move.l	InputRequest(a4),a1
	CALLEXEC WaitIO
	lea	InputEvent+IE_TimeStamp(a4),a0
	move.l	TimeRequest(a4),a1
	move.l	IO_Device(a1),a6
	cmp.w	#36,LIB_Version(a6)
	bcs.s	cr_1			;next function needs V36

	jsr	GetSysTime(a6)		;current time
cr_1:
	lea	InputEvent(a4),a0
	clr.l	(a0)+			;IE_NextEvent
	moveq.l	#IECLASS_DISKREMOVED,d0
	tst.w	PhysFlags(a4)
	beq.s	cr_2

	moveq.l	#IECLASS_DISKINSERTED,d0
cr_2:
	ror.l	#8,d0
	move.l	d0,(a0)+		;IE_Class ff.
	move.w	#IEQUAL_MULTIBROADCAST,(a0)+
	clr.l	(a0)			;IE_Addr

	move.l	InputRequest(a4),a1
	move.w	#IND_WRITEEVENT,IO_Command(a1)
	moveq.l	#IE_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	InputEvent(a4),a0
	move.l	a0,IO_Data(a1)
	CALLEXEC SendIO			;post report
	rts

;*** disk block access *************************************
;--- read blocks -------------------------------------------
; d0 <- Block #
; d1 <- block count
; a1 <- &target
; d0 -> blocks read

_Read:
	movem.l	d2-d6/a2-a3,-(sp)
	move.l	d0,d2
	move.l	d0,LastReadBlock(a4)	;for debugging
	move.l	d1,d4
	moveq.l	#0,d5
	move.l	a1,a3
	move.l	DiskRequest(a4),a2
_r_group:
	move.l	EnvecBuf+DE_MaxTransfer(a4),d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0
	move.l	d4,d3
	cmp.l	d4,d0
	bcc.s	_r_1

	move.l	d0,d3			;do it in portions
_r_1:
	move.l	d3,d6
	lsl.l	d1,d6			;length in Bytes
	btst	#2,CmdFlags+1(a4)
	bne.s	_r_scsi

	move.w	ReadCmd(a4),IO_Command(a2)
	move.l	d6,IO_Length(a2)
	move.l	a3,IO_Data(a2)
	move.l	d2,d0
	rol.l	d1,d0
	move.l	BlockMask(a4),d1
	and.l	d0,d1
	move.l	d1,IO_Actual(a2)	;TD64: HighOffset
	eor.l	d1,d0
	move.l	d0,IO_Offset(a2)	;Byte-Offset
	clr.l	IO_SecLabel(a2)		;no sector label
	move.l	a2,a1
	bsr.w	SafeDoIO
	bra.s	_r_check
_r_scsi:
	move.w	#HD_SCSICMD,IO_Command(a2)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a2)
	lea	SCSIStruct(a4),a0
	move.l	a0,IO_Data(a2)
	move.l	a3,(a0)+		;SCSI_Data = &target
	move.l	d6,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	lea	SCSICmdLine(a4),a1
	move.l	a1,(a0)+		;SCSI_Command
	move.b	#READ10,(a1)+		;build command line
	clr.b	(a1)+
	move.l	d2,(a1)+
	clr.b	(a1)+
	rol.w	#8,d3
	move.b	d3,(a1)+
	rol.w	#8,d3
	move.b	d3,(a1)+
	clr.b	(a1)
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.l	(a0)			;SCSI_SenseLength and SCSI_SenseActual
	move.l	a2,a1
	bsr.w	SafeDoIO
	move.l	SCSIStruct+SCSI_Actual(a4),IO_Actual(a2)
_r_check:
	bsr.w	DiskSense
	move.b	d0,LastReadError(a4)
	bne.s	_r_error
_r_gnext:
	add.l	d6,a3			;bump &target
	add.l	d3,d2			;bump Block #
	add.l	d3,d5
	sub.l	d3,d4
	bgt.w	_r_group
_r_end:
	or.w	#1,NewFlags(a4)		;Motor running
	move.l	d5,d0
	movem.l	(sp)+,d2-d6/a2-a3
	rts

_r_error:
	move.l	d2,-(sp)		;Block #..
	move.l	UIText+4*4(a4),-(sp)
	move.l	d0,-(sp)		;IO_Error
	move.l	IO_Actual(a2),d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0
	add.l	d0,8(sp)		;..of error
	bsr.w	DoRequest
	add.w	#12,sp
	tst.w	d0
	bne.w	_r_group		;"repeat"

	move.w	#225,ErrorNum(a4)
	bra.s	_r_end

;--- write 1 block -----------------------------------------
; d0 <- relative Block #
; a0 <- &data
; d0 -> 1 (success) or 0

_WBlock:
	add.l	FirstBlock(a4),d0
	moveq.l	#1,d1			;continued below

;--- write blocks ------------------------------------------
; d0 <- Block #
; d1 <- block count
; a0 <- &source
; d0 -> blocks read

_Write:
	movem.l	d2-d6/a2-a3,-(sp)
	move.l	d0,d2
	move.l	d1,d4
	moveq.l	#0,d5
	move.l	a0,a3
	move.l	DiskRequest(a4),a2
_w_group:
	move.l	EnvecBuf+DE_MaxTransfer(a4),d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0
	move.l	d4,d3
	cmp.l	d4,d0
	bcc.s	_w_1

	move.l	d0,d3			;do it in portions
_w_1:
	move.l	d3,d6
	lsl.l	d1,d6			;length in Bytes
	btst	#2,CmdFlags+1(a4)
	bne.s	_w_scsi

	move.w	WriteCmd(a4),IO_Command(a2)
	move.l	d6,IO_Length(a2)
	move.l	a3,IO_Data(a2)
	move.l	d2,d0
	rol.l	d1,d0
	move.l	BlockMask(a4),d1
	and.l	d0,d1
	move.l	d1,IO_Actual(a2)	;TD64: HighOffset
	eor.l	d1,d0
	move.l	d0,IO_Offset(a2)	;Byte-Offset
	clr.l	IO_SecLabel(a2)		;no sector label
	move.l	a2,a1
	bsr.w	SafeDoIO
	bra.s	_w_check
_w_scsi:
	move.w	#HD_SCSICMD,IO_Command(a2)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a2)
	lea	SCSIStruct(a4),a0
	move.l	a0,IO_Data(a2)
	move.l	a3,(a0)+		;SCSI_Data = &target
	move.l	d6,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	lea	SCSICmdLine(a4),a1
	move.l	a1,(a0)+		;SCSI_Command
	move.b	#WRITE10,(a1)+		;build command line
	clr.b	(a1)+
	move.l	d2,(a1)+
	clr.b	(a1)+
	rol.w	#8,d3
	move.b	d3,(a1)+
	rol.w	#8,d3
	move.b	d3,(a1)+
	clr.b	(a1)
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_WRITE,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.l	(a0)			;SCSI_SenseLength and SCSI_SenseActual
	move.l	a2,a1
	bsr.w	SafeDoIO
	move.l	SCSIStruct+SCSI_Actual(a4),IO_Actual(a2)
_w_check:
	bsr.w	DiskSense
	tst.b	d0
	bne.s	_w_error
_w_gnext:
	add.l	d6,a3			;bump &target
	add.l	d3,d2			;bump Block #
	add.l	d3,d5
	sub.l	d3,d4
	bgt.w	_w_group
_w_end:
	or.w	#3,NewFlags(a4)		;Motor running & Update needed
	move.l	d5,d0
	movem.l	(sp)+,d2-d6/a2-a3
	rts

_w_error:
	move.l	d2,-(sp)		;Block #..
	move.l	UIText+5*4(a4),-(sp)
	move.l	d0,-(sp)		;IO_Error
	move.l	IO_Actual(a2),d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0
	add.l	d0,8(sp)		;..of error
	bsr.w	DoRequest
	add.w	#12,sp
	tst.w	d0
	bne.w	_w_group		;"repeat"

	move.w	#225,ErrorNum(a4)
	bra.s	_w_end

;--- read 1 Block ------------------------------------------
; d0 <- ULONG Block #;
; d0 -> BYTE *source;
; a0 -> struct BlockBuffer *bb;

ReadSingle:
	movem.l	d3/a2,-(sp)
	add.l	FirstBlock(a4),d0
	move.l	d0,d3			;absolute Block #
	move.l	SingleBuf(a4),a2
	move.l	a2,d0
	beq.s	rs_new

	cmp.l	BB_BlockNum(a2),d3
	beq.s	rs_ok

	tst.w	BB_OpenCnt(a2)
	bpl.s	rs_read

	move.l	a2,a0
	bsr.w	WriteBBuf
	bra.s	rs_read
rs_new:
	move.w	#4096,d1
	move.w	BlockSize(a4),d0
	cmp.w	d1,d0
	bcs.s	rs_alloc

	move.w	d0,d1
rs_alloc:
	moveq.l	#BB_Data,d0
	add.w	d1,d0
	move.l	d0,SingleSize(a4)
	move.l	BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,a2
	move.l	d0,SingleBuf(a4)
	beq.s	rs_end
rs_read:
	clr.w	BB_OpenCnt(a2)
	clr.l	BB_DirtyFlags(a2)
	move.l	d3,d0
	moveq.l	#1,d1
	move.l	d1,BB_Blocks(a2)
	lea	BB_Data(a2),a1
	bsr.w	_Read
	tst.l	d0
	beq.s	rs_end

	move.l	d3,BB_BlockNum(a2)
rs_ok:
	move.l	a2,a0
	moveq.l	#BB_Data,d0
	add.l	a2,d0
rs_end:
	movem.l	(sp)+,d3/a2
	rts

;--- read blocks cached ------------------------------------
; d0 <- ULONG Block #;
; d1 <- LONG mode;
; a0 <- ULONG BytesFromClusterStart if mode = RB_FILExxx
; d0 -> BYTE *data;
; d1 -> ULONG available length;
; a0 -> struct BlockBuffer *bb;

;Modus
RB_DIRNEW	= %010			;previous block contents irrelevant
RB_DIRREAD	= %011			;do read actually
RB_FILENEW	= %000			;same for file clusters
RB_FILEREAD	= %001

ReadDirBlock:
	moveq.l	#RB_DIRREAD,d1

ReadBlocks:
	movem.l	d2-d5/a2-a3,-(sp)
	cmp.l	RootDirEnd(a4),d0
	bcc.s	rbn_1

	or.w	#6,d1			;FAT12/16 root dir in separate buffer
rbn_1:
	add.l	FirstBlock(a4),d0
	move.l	d0,d3			;absolute Block #
	move.l	d1,d4			;mode
	btst	#1,d4
	bne.s	rbn_2			;in file mode..

	move.l	a0,d5			;..convert byte offset..
	add.l	BlockMask(a4),d5
	move.w	BlockShift(a4),d0
	lsr.l	d0,d5			;..into blocks..
	moveq.l	#0,d0
	move.b	BlocksPerCluster(a4),d0
	cmp.l	d5,d0
	bcc.s	rbn_2

	move.l	d0,d5			;..and limit to Cluster size
rbn_2:

;- - scan buffers  - - - - - - - - - - - - - - - - - - - - -

	move.l	BufList(a4),d2
rbn_search:
	move.l	d2,a2
	move.l	(a2),d2
	beq.s	rbn_disk		;not found, read

	move.l	BB_BlockNum(a2),d0
	cmp.l	d0,d3
	bcs.s	rbn_search

	add.l	BB_Blocks(a2),d0
	cmp.l	d0,d3
	bcc.s	rbn_search

	cmp.l	BufList(a4),a2
	beq.s	rbn_found		;hit in first buffer

	move.l	a2,a1
	bsr.w	MyRemove
	lea	BufList(a4),a0
	move.l	a2,a1
	bsr.w	MyAddHead		;buffer to top of list
rbn_found:
	move.w	BB_Flags(a2),d0
	eor.w	d4,d0
	roxr.w	#2,d0
	bcc.s	rbn_4			;keep protection

	moveq.l	#-1,d0
	btst	#1,d4
	beq.s	rbn_3			;dir -> file

	moveq.l	#0,d5
	move.b	BlocksPerCluster(a4),d5
	moveq.l	#1,d0			;file -> dir
rbn_3:
	add.w	d0,DirBufsUsed(a4)
	move.l	d5,BB_Blocks(a2)
	eor.w	#%010,BB_Flags(a2)
	bra.s	rbn_5
rbn_4:
	btst	#1,d4
	bne.s	rbn_5

	move.l	d5,BB_Blocks(a2)	;skip unused file blocks
rbn_5:
rbn_success:
	move.l	a2,a0
	move.w	BlockShift(a4),d2
	sub.l	BB_BlockNum(a2),d3
	move.l	BB_Blocks(a2),d1
	sub.l	d3,d1
	lsl.l	d2,d3
	lsl.l	d2,d1
	moveq.l	#BB_Data,d0
	add.l	d3,d0
	add.l	a2,d0
rbn_end:
	movem.l	(sp)+,d2-d5/a2-a3
	rts

;- - get a free buffer - - - - - - - - - - - - - - - - - - -

rbn_disk:
	lea	NormBufsUsed(a4),a3
	move.w	(a3),d0
	cmp.w	2(a3),d0
	bcc.s	rbn_reuse		;buffer count limit reached

	moveq.l	#BB_Data,d0
	add.l	ClusterSize(a4),d0
	move.l	BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,a2
	tst.l	d0
	bne.w	rbn_init		;allocate new buffer
rbn_reuse:
	move.l	BufList+8(a4),d2	;LH_TailPred
rbn_rsearch:
	move.l	d2,a2
	move.l	4(a2),d2
	beq.s	rbn_rnotfound

	move.w	BB_OpenCnt(a2),d0
	and.w	#$7fff,d0
	bne.s	rbn_rsearch		;this one still in use

	move.w	BB_Flags(a2),d0
	eor.w	d4,d0
	roxr.w	#2,d0
	bcc.s	rbn_rok			;keep protection

	moveq.l	#1,d1
	btst	#1,d4
	bne.s	rbn_fdswitch		;file -> dir

	move.w	DirBufsMin(a4),d0
	cmp.w	DirBufsUsed(a4),d0
	bcc.s	rbn_rsearch		;keep a minimum count of dir buffers

	moveq.l	#-1,d1			;dir -> file
rbn_fdswitch:
	eor.w	#%010,BB_Flags(a2)
	add.w	d1,DirBufsUsed(a4)
rbn_rok:
	move.l	a2,a1
	bsr.w	MyRemove
	tst.w	BB_OpenCnt(a2)
	bpl.s	rbn_nowfree		;reuse buffer

	move.l	a2,a0
	bsr.w	WriteBBuf
rbn_nowfree:
	move.w	2(a3),d0
	cmp.w	(a3),d0
	bcc.s	rbn_setup		;too many buffers,..

	btst	#1,d4
	beq.s	rbn_free

	subq.w	#1,DirBufsUsed(a4)
rbn_free:
	move.l	a2,a0
	bsr.w	FreeBlockBuf		;..free one and search on
	subq.w	#1,(a3)			;one less
	bra.s	rbn_reuse

rbn_rnotfound:				;worst case..
	moveq.l	#BB_Data,d0
	add.l	ClusterSize(a4),d0
	move.l	BufMemType(a4),d1
	CALLEXEC AllocMem		;..try again new buffer
	move.l	d0,a2
	tst.l	d0
	beq.w	rbn_nomem
rbn_init:
	move.w	d4,BB_Flags(a2)
	addq.w	#1,(a3)			;one more
	btst	#1,d4
	beq.s	rbn_setup

	addq.w	#1,DirBufsUsed(a4)
rbn_setup:
	moveq.l	#0,d1
	lea	BB_DirtyFlags(a2),a1
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	move.l	d1,(a1)+
	move.l	d1,(a1)			;clear "dirty" flags
	moveq.l	#0,d2
	move.b	BlocksPerCluster(a4),d2	;normal Cluster, mostly
	move.l	d3,d0			;absolute Block #
	sub.l	FirstBlock(a4),d0	;relative Block #
	beq.s	rbn_sfix		;special case: direct transfer emulation

	move.l	d0,d1
	sub.l	RootDirEnd(a4),d1
	bcc.s	rbn_scluster		;a data cluster

	sub.l	RootStartBlock(a4),d0	;FAT12/16 root dir
	and.l	ClusterBlockMask(a4),d0
	sub.l	d0,d1
	add.l	d2,d1
	ble.s	rbn_sfix

	sub.l	d1,d2			;limit to root length
	bra.s	rbn_sfix
rbn_scluster:
	move.l	ClusterBlockMask(a4),d0
	and.l	d1,d0
	btst	#1,d4
	bne.s	rbn_sfix

	move.l	d5,d2			;skip unused file blocks
rbn_sfix:
	move.l	d3,d1
	sub.l	d0,d1
	move.l	d1,BB_BlockNum(a2)
	move.l	d2,BB_Blocks(a2)
	clr.w	BB_OpenCnt(a2)
	lea	BufList(a4),a0
	move.l	a2,a1
	bsr.w	MyAddHead		;buffer back in List
	btst	#0,d4
	beq.w	rbn_success		;previous block contents not needed

;- - now actually do read  - - - - - - - - - - - - - - - - -

	move.l	BB_BlockNum(a2),d0
	move.l	BB_Blocks(a2),d1
	move.l	a2,a1
	add.w	#BB_Data,a1
	bsr.w	_Read
	tst.l	d0
	bne.w	rbn_success		;OK

	moveq.l	#-1,d0
	move.l	d0,BB_BlockNum(a2)
	move.w	#225,ErrorNum(a4)
	moveq.l	#0,d0			;read error, return NULL
	bra.w	rbn_end

rbn_nomem:
	move.w	#103,ErrorNum(a4)	;better luck next time
	moveq.l	#0,d0
	bra.w	rbn_end

;--- write back 1 buffer -----------------------------------
; a0 <- struct BlockBuffer *bb;

WriteBBuf:
	movem.l	d2-d5/a2-a3,-(sp)
	move.l	a0,a2			;&BlockBuffer
	move.l	BB_Blocks(a2),d3
	ble.s	wbb_end			;nothing to do

	moveq.l	#-1,d2
	moveq.l	#0,d4			;Block Offset
	lea	BB_DirtyFlags(a2),a3
wbb_block:
	moveq.l	#31,d0
	and.l	d4,d0
	bne.s	wbb_test

	move.l	(a3),d5
	clr.l	(a3)+
wbb_test:
	lsl.l	#1,d5
	bcc.s	wbb_no

	tst.l	d2
	bpl.s	wbb_next

	move.l	d4,d2			;first changed Block
	bra.s	wbb_next
wbb_no:
	tst.l	d2
	bmi.s	wbb_next

	move.l	d2,d0
	move.w	BlockShift(a4),d1
	lsl.l	d1,d0
	lea	BB_Data(a2,d0.l),a0
	move.l	d2,d0
	add.l	BB_BlockNum(a2),d0
	move.l	d4,d1
	sub.l	d2,d1
	bsr.w	_Write
	moveq.l	#-1,d2
wbb_next:
	addq.l	#1,d4
	subq.l	#1,d3
	bgt.s	wbb_block
	beq.s	wbb_no
wbb_ok:
	and.w	#$7fff,BB_OpenCnt(a2)
wbb_end:
	movem.l	(sp)+,d2-d5/a2-a3
	rts

;--- set dirty flags ---------------------------------------
; preserve all registers

; d0 <- &data inside buffer or 0
; a0 <- &BlockBuffer

BlockChanged:
	movem.l	d0-d1/a0,-(sp)
	or.w	#$8000,BB_OpenCnt(a0)
	or.w	#4,NewFlags(a4)		;"data blocks changed"
	sub.l	a0,d0
	moveq.l	#BB_Data,d1
	sub.l	d1,d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0
	moveq.l	#7,d1
	and.l	d0,d1
	eor.w	#7,d1
	lsr.l	#3,d0
	add.w	#BB_DirtyFlags,a0
	add.l	d0,a0
	bset	d1,(a0)
	movem.l	(sp)+,d0-d1/a0
	rts


; a0 <- &BlockBuffer
; a1 <- &data inside buffer
; d0 <- data length

SetDirty:
	movem.l	d0-d3/a1,-(sp)
	tst.l	d0
	ble.s	sdr_ok			;nothing to do

	move.l	a1,d2
	sub.l	a0,d2
	moveq.l	#BB_Data,d1
	sub.l	d1,d2
	bmi.s	sdr_end			;invalid data start

	moveq.l	#-1,d3
	add.l	d2,d3
	add.l	d0,d3
	cmp.l	ClusterSize(a4),d3
	bcc.s	sdr_end			;length invalid

	move.w	BlockShift(a4),d1
	lsr.l	d1,d2			;first Block
	lsr.l	d1,d3
	addq.l	#1,d3
	sub.l	d2,d3			;# blocks
sdr_loop:
	move.l	d2,d1
	lsr.l	#3,d1
	lea	BB_DirtyFlags(a0),a1
	add.l	d1,a1
	moveq.l	#7,d1
	and.l	d2,d1
	eor.w	#7,d1
	bset	d1,(a1)
	addq.l	#1,d2
	subq.l	#1,d3
	bgt.s	sdr_loop
sdr_ok:
	or.w	#$8000,BB_OpenCnt(a0)
	or.w	#4,NewFlags(a4)		;" data blocks changed"
sdr_end:
	movem.l	(sp)+,d0-d3/a1
	rts

;*** find and check volume *********************************
;--- set initial parameters --------------------------------
;preserve all registers

SetIntParams:
	movem.l	d0-d1,-(sp)
	moveq.l	#0,d0
	move.w	BlockSize(a4),d0
	subq.l	#1,d0
	move.l	d0,BlockMask(a4)
	addq.l	#1,d0
	LOG2
	move.w	d0,BlockShift(a4)
	move.w	d0,d1
	move.l	PhysSize(a4),d0
	LOG2
	sub.w	d1,d0
	move.w	d0,PhysShift(a4)	;normal 0
	movem.l	(sp)+,d0-d1
	rts

;--- evaluate partition table ------------------------------
; d0 <- Partition # 1..4 or 0 for "extended Partition"
; a0 <- &struct MasterBootRecord
; a2 <-> struct PartFrame (ULONG length, ULONG AbsBlock#)
; a5 <- &StackFrame (PartFrame Table)
; d0 -> absolute Block # or 0
; d1 -> length

GPA_TABSIZE	= 256			;32 frame entries

GetPartition:
	movem.l	d2-d3/a0,-(sp)
	move.w	d0,d2
	bne.s	gpa_1

	moveq.l	#1,d2
gpa_1:
	move.w	d2,d1
	lsl.w	#4,d1
	add.w	#430,d1
	add.w	d1,a0			;&entry in Partition table
gpa_check:
	move.b	4(a0),d1		;Partition type
	moveq.l	#0,d3
	subq.b	#1,d1
	beq.s	gpa_fat			;$01 = FAT12

	moveq.l	#1,d3
	subq.b	#3,d1
	beq.s	gpa_fat			;$04 = FAT16, < 32 M

	subq.b	#1,d1
	beq.s	gpa_ext			;$05 = extended Partition

	subq.b	#1,d1
	beq.s	gpa_fat			;$06 = FAT16, >= 32 M

	moveq.l	#-1,d3
	subq.b	#5,d1
	beq.s	gpa_fat			;$0b = FAT32, <= 2 G

	subq.b	#1,d1
	beq.s	gpa_fat			;$0c = FAT32, LBA

	moveq.l	#1,d3
	subq.b	#2,d1
	beq.s	gpa_fat			;$0e = FAT16, >= 32 M, LBA

	subq.b	#1,d1
	bne.s	gpa_next		;$0f = extended Partition, LBA
gpa_ext:
	tst.w	d0
	beq.s	gpa_found
	bra.s	gpa_next
gpa_fat:
	tst.w	d0
	bne.s	gpa_found
gpa_next:
	add.w	#16,a0
	addq.w	#1,d2
	cmp.w	#5,d2
	bcs.s	gpa_check
gpa_error:
	moveq.l	#0,d0			;"not found"
	bra.s	gpa_end
gpa_found:
	move.w	d3,FATType(a4)		;Info for AutoLayout()
	move.l	12(a0),d1
	ReverseL d1			;length in Sectors
	move.l	8(a0),d0
	ReverseL d0			;relative Block #
	move.l	d0,HiddenBlocks(a4)	;distance off MBR
gpa_fcheck:
	cmp.l	(a2),d0
	bcs.s	gpa_fok			;start still within current frame..

	addq.l	#8,a2			;..or maybe within parent,..
	cmp.l	a5,a2
	bcs.s	gpa_fcheck

	subq.l	#8,a2			;..but at least within start frame
gpa_fok:
	add.l	4(a2),d0		;absolute Block #
	move.l	a5,d2
	sub.l	a2,d2			;frame table..
	cmp.w	#GPA_TABSIZE+1-8,d2
	bcc.s	gpa_end			;..full

	move.l	d0,-(a2)
	move.l	d1,-(a2)		;this Partition as new frame
gpa_end:
	movem.l	(sp)+,d2-d3/a0
	rts

;--- validate boot block -----------------------------------
; a0 <-> &block contents
; d0  -> BOOL OK;

IsBootBlock:
	move.l	(a0),d1
	move.l	d1,BootSignature(a4)	;debugging
	cmp.b	#$e9,(a0)		;i80x86 word branch
	beq.s	ibb_bscheck

	and.l	#$ff80ff00,d1
	cmp.l	#$eb009000,d1		;i80x86 byte branch.. + NOP
	bne.s	ibb_error

	move.b	1(a0),d1		;for PalmOS memory cards..
	beq.s	ibb_bscheck		;..without boot code

	cmp.b	#36,d1			;..at least behind parameter block
	blt.s	ibb_error
ibb_bscheck:
	;Reject NTFS (OEM ID "NTFS    " at offset 3).  3(a0) is an odd
	;address, so a `cmp.l #"NTFS",3(a0)` would Address-Error on 68000.
	;Check byte at offset 3 first, then the remaining aligned long.
	cmp.b	#'N',3(a0)		;NTFS OEM ID byte 0..
	bne.s	ibb_not_ntfs
	cmp.l	#"TFS ",4(a0)		;..bytes 1..4 (aligned long)
	beq.w	ibb_error		;NTFS volume - not a FAT filesystem
ibb_not_ntfs:

	moveq.l	#0,d1
	move.b	13(a0),d1		;Blocks/Cluster..
	beq.s	ibb_error		;..is null..

	move.l	d1,d0
	LOG2
	bclr	d0,d1
	tst.l	d1
	bne.s	ibb_error		;..or no power of 2

	move.b	12(a0),d1
	lsl.w	#8,d1
	move.b	11(a0),d1		;logical Block size..
	move.l	d1,d0
	LOG2
	cmp.w	#9,d0
	bcs.s	ibb_error		;..is < 512,..

	cmp.w	#13,d0
	bcc.s	ibb_error		;..> 4096..

	bclr	d0,d1
	tst.l	d1
	bne.s	ibb_error		;..or no power of 2

	moveq.l	#-1,d0			;"OK"
ibb_end:
	rts

ibb_error:
	moveq.l	#0,d0
	bra.s	ibb_end

;--- read disk layout --------------------------------------
; -> flags: Bit..
;	0 = disk inserted
;	1 = disk writable
;	2 = disk readable
;	3 = boot block OK

GetDiskParams:
	link.w	a5,#-GPA_TABSIZE
	movem.l	d2-d7/a2,-(sp)		;GPT path uses d5/d6/d7 too

;- - general check - - - - - - - - - - - - - - - - - - - - -

	clr.b	SearchCount(a4)
	bsr.w	FreeFATBuf
	;Clear partition-state before probing, so a failed or partial
	;detection cannot leak stale FirstBlock/TotalBlocks/PartitionNum
	;/FATType values from a previous successful mount into gdp_ndos
	;(which reads them) or into the next probe cycle.
	clr.l	FirstBlock(a4)
	clr.l	TotalBlocks(a4)
	clr.l	HiddenBlocks(a4)
	clr.w	PartitionNum(a4)
	clr.w	FATType(a4)
	bsr.w	DiskStatus
	move.w	d0,d3
	beq.w	gdp_none		;no disk

	bsr.w	DiskGeometry
	bsr.w	ReportGeometry		;for FDA: temporarily mount whole disk
	bsr.w	CacheSet
	bsr.w	DiskChangeNum
	bsr.w	DiskClear
	addq.b	#1,SearchCount(a4)
	addq.b	#1,NoRequest(a4)	;dont report even "no disk"
	move.l	FirstBlock(a4),d0
	bsr.w	Test64			;for manually defined partition
	moveq.l	#0,d0
	bsr.w	ReadSingle
	subq.b	#1,NoRequest(a4)
	tst.l	d0
	bne.s	gdp_mbr

	cmp.b	#TDERR_DISKCHANGED,LastReadError(a4)
	bne.w	gdp_bad

	moveq.l	#0,d3
	bra.w	gdp_none
gdp_mbr:
	move.l	d0,a0			;&Block #0
	or.w	#4,d3			;"low level format OK"
	move.w	#2,FATType(a4)		;for AutoLayout()
	move.l	(a0),d0
	cmp.l	#"FAKE",d0		;manually defined partition..
	beq.w	gdp_fake		;..for testing

	cmp.w	#$55AA,510(a0)
	bne.s	gdp_foreign		;no magic #??

	cmp.l	#"RDSK",d0		;Amiga partition info inside..
	beq.s	gdp_foreign		;..first 256 bytes

	and.l	#$ffffff00,d0		;mask out low byte (filesystem type DOS\<type>)
	cmp.l	#"DOS"<<8,d0		;check if first 3 bytes are "DOS"
	beq.s	gdp_foreign		;an FFS media or something

	cmp.l	#"PFS"<<8,d0
	beq.s	gdp_foreign		;PFS media

	cmp.l	#"SFS"<<8,d0
	bne.s	gdp_notforeign		;not a known foreign format

gdp_foreign:
	;Foreign disk format detected (RDB, PFS, SFS, FFS, or no MBR signature)
	;For partition 1: show NDOS (disk present but wrong format)
	;For partition 2+: show ID_NONE (partition doesn't exist)
	cmp.b	#2,DosType+3(a4)
	bcc.w	gdp_none		;partition 2+ -> "No Disk"
	bra.w	gdp_ndos		;partition 0/1 -> "Uninitialized"

gdp_notforeign:

	clr.w	PartitionNum(a4)
	bsr.w	IsBootBlock
	tst.w	d0
	bne.w	gdp_bootfound		;unpartitioned volume

	tst.b	SearchMode(a4)
	bne.w	gdp_ndos		;set manually, dont search

;- - check for GPT partition table - - - - - - - - - - - - -
	;
	; GPT Detection Flow:
	; ~~~~~~~~~~~~~~~~~~~
	; MBR block 0 loaded (a0)
	;       |
	; Check partition type 0xEE (protective MBR)?
	;       |-- No --> gdp_mbr_search (normal MBR parsing)
	;       |
	;      Yes
	;       |
	; Read LBA 1 (GPT header)
	;       |
	; Check "EFI PART" signature
	;       |
	; Scan partition entries for FAT GUID (EBD0A0A2-...)
	;       |
	; Mount partition --> gdp_bootfound
	;
	;a0 still points to block 0 (MBR)
	;Check if first partition entry is type 0xEE (protective MBR for GPT)
	cmp.b	#$EE,446+4(a0)		;partition type at offset 446+4
	bne.w	gdp_mbr_search		;not GPT, try MBR

	;Protective MBR found - save d3 (disk status) and read GPT header
	move.w	d3,-(sp)		;save disk status (contains write-protect flag)
	addq.b	#1,SearchCount(a4)
	moveq.l	#1,d0			;LBA 1 = GPT header
	bsr.w	ReadSingle		;FirstBlock is 0 here
	tst.l	d0
	beq.w	gdp_gpt_cleanup		;read failed

	move.l	d0,a1			;&GPT header
	cmp.l	#"EFI ",(a1)		;check "EFI PART" signature
	bne.w	gdp_gpt_cleanup
	cmp.l	#"PART",4(a1)
	bne.w	gdp_gpt_cleanup

	;GPT header valid - get partition entry info
	move.l	72(a1),d4		;Partition entries LBA low (little-endian)
	ReverseL d4
	move.l	76(a1),d0		;Partition entries LBA high
	tst.l	d0
	bne.w	gdp_gpt_cleanup		;beyond 32-bit addressing
	move.l	80(a1),d5		;Number of partition entries (little-endian)
	ReverseL d5
	move.l	84(a1),d6		;Size of partition entry (little-endian)
	ReverseL d6
	tst.w	d6
	beq.w	gdp_gpt_cleanup		;invalid entry size

	;Get requested partition number
	moveq.l	#0,d2
	move.b	DosType+3(a4),d2
	bgt.s	gdp_gpt_p1
	moveq.l	#1,d2			;autoselect first FAT partition
gdp_gpt_p1:
	move.w	d2,PartitionNum(a4)
	subq.w	#1,d2			;convert to 0-based index
	bmi.w	gdp_gpt_cleanup		;invalid partition number

	;Scan GPT entries for FAT partition
	moveq.l	#0,d7			;FAT partition counter
	moveq.l	#0,d0			;current entry index (32-bit)
gdp_gpt_loop:
	cmp.l	d5,d0			;scanned all entries? (32-bit index vs count)
	bcc.w	gdp_gpt_cleanup		;not found

	;Calculate LBA and byte-offset for this entry
	move.l	d0,-(sp)		;save entry index
	move.l	d6,d1			;d1 = entry size
	UMUL32				;d0 = entry_idx * entry_size (byte offset)
	moveq.l	#0,d1
	move.w	BlockSize(a4),d1	;BlockSize fits in 16 bits (512..4096)
	UDIVMOD32			;d0 = block offset (quot), d1 = byte offset in block (rem)
	move.l	d1,d3			;d3 = byte offset within block
	add.l	d4,d0			;d0 = absolute LBA

	;Read block containing this entry (SingleBuf cache absorbs repeats)
	bsr.w	ReadSingle
	move.l	(sp)+,d1		;restore entry index to d1 temporarily
	tst.l	d0			;check if read succeeded
	beq.w	gdp_gpt_cleanup		;read failed
	move.l	d0,a1			;block data
	move.l	d1,d0			;restore entry index to d0

	add.w	d3,a1			;a1 = &partition entry (d3 < BlockSize, fits pos. word)

	;Check if entry is used (GUID not all zeros)
	tst.l	(a1)
	beq.s	gdp_gpt_next		;unused entry

	;Check partition type GUID (full 16 bytes) against FAT-carrying GUIDs:
	;  EBD0A0A2-B9E5-4433-87C0-68B6B72699C7  Microsoft Basic Data
	;  C12A7328-F81F-11D2-BA4B-00A0C93EC93B  EFI System Partition
	cmp.l	#$A2A0D0EB,(a1)		;MS Basic Data
	bne.s	gdp_gpt_try_esp
	cmp.l	#$E5B93344,4(a1)
	bne.s	gdp_gpt_try_esp
	cmp.l	#$87C068B6,8(a1)
	bne.s	gdp_gpt_try_esp
	cmp.l	#$B72699C7,12(a1)
	beq.s	gdp_gpt_match

gdp_gpt_try_esp:
	cmp.l	#$28732AC1,(a1)		;EFI System Partition
	bne.s	gdp_gpt_next
	cmp.l	#$1FF8D211,4(a1)
	bne.s	gdp_gpt_next
	cmp.l	#$BA4B00A0,8(a1)
	bne.s	gdp_gpt_next
	cmp.l	#$C93EC93B,12(a1)
	bne.s	gdp_gpt_next

gdp_gpt_match:
	;Found FAT partition - is it the one we want?
	cmp.w	d2,d7			;d7 = FAT partition counter, d2 = requested index
	beq.s	gdp_gpt_found
	addq.w	#1,d7			;next FAT partition
gdp_gpt_next:
	addq.l	#1,d0			;next entry (32-bit)
	bra.w	gdp_gpt_loop

gdp_gpt_found:
	;Get partition start and end LBA (little-endian, 64-bit)
	move.l	32(a1),d0		;First LBA low
	ReverseL d0
	move.l	36(a1),d1		;First LBA high
	tst.l	d1
	bne.s	gdp_gpt_cleanup		;beyond 32-bit addressing

	move.l	40(a1),d1		;Last LBA low
	ReverseL d1
	move.l	44(a1),d3		;Last LBA high
	tst.l	d3
	bne.s	gdp_gpt_cleanup		;beyond 32-bit addressing

	;Verify partition end is within 32-bit range BEFORE touching
	;any global state - a failed Test64 must not leave half-written
	;FirstBlock/TotalBlocks/HiddenBlocks visible to the caller.
	sub.l	d0,d1
	addq.l	#1,d1			;size = last - first + 1
	move.l	d0,d2			;save first LBA across Test64
	add.l	d1,d0
	subq.l	#1,d0
	bsr.w	Test64
	tst.l	d0
	beq.s	gdp_gpt_cleanup		;partition exceeds 4 Gbyte

	;Range OK - commit partition info to globals
	move.w	#2,FATType(a4)		;auto-detect FAT type
	move.l	d2,FirstBlock(a4)
	move.l	d1,TotalBlocks(a4)
	clr.l	HiddenBlocks(a4)

	;Restore d3 and use shared boot block validation
	move.w	(sp)+,d3		;restore disk status
	bra.s	gdp_readboot		;share boot block code with MBR path

gdp_gpt_cleanup:
	addq.l	#2,sp			;discard saved d3
	bra.w	gdp_none		;partition not found = no disk

;- - search MBR partition  - - - - - - - - - - - - - - - - -
gdp_mbr_search:
	move.l	a5,a2			;&frame table
	clr.l	-(a2)			;start frame: from beginning..
	moveq.l	#-1,d0
	move.l	d0,-(a2)		;..to end
	moveq.l	#0,d2
	move.b	DosType+3(a4),d2
	bgt.s	gdp_p1			;invalid MountList entry..

	moveq.l	#1,d2			;..autoselect first FAT-partition
gdp_p1:
	move.w	d2,PartitionNum(a4)
	subq.w	#5,d2
	bcc.s	gdp_plog		;logical partition requested

	addq.w	#5,d2
	move.w	d2,d0
	bsr.w	GetPartition
	move.l	d0,d4
	bne.s	gdp_pfound		;found primary partition

	moveq.l	#0,d2
gdp_plog:
	moveq.l	#0,d0
	bsr.w	GetPartition
	move.l	d0,d4
	beq.w	gdp_none		;partition not found = no disk

	bsr.w	Test64
	tst.l	d0
	beq.w	gdp_none		;..or beyond 4 Gbyte

	addq.b	#1,SearchCount(a4)
	move.l	d4,d0
	bsr.w	ReadSingle		;read next partition table
	tst.l	d0
	beq.w	gdp_ndos

	move.l	d0,a0
	subq.w	#1,d2
	bpl.s	gdp_plog		;skip this logical partition

	moveq.l	#1,d0
	bsr.w	GetPartition
	tst.l	d0			;partition not in expected place,..
	beq.s	gdp_plog		;..search on below
gdp_pfound:
	move.l	d0,FirstBlock(a4)
	move.l	d1,TotalBlocks(a4)
	add.l	d1,d0
	subq.l	#1,d0
	bsr.w	Test64
	tst.l	d0
	beq.w	gdp_none		;partition exceeds 4 Gbyte

gdp_readboot:				;shared entry point for GPT
	addq.b	#1,SearchCount(a4)
	moveq.l	#0,d0
	bsr.w	ReadSingle		;read Boot block
	tst.l	d0
	beq.w	gdp_ndos

	move.l	d0,a0			;&Block #0 of partition
	cmp.w	#$55AA,510(a0)
	bne.w	gdp_ndos		;Boot block invalid

	bsr.w	IsBootBlock
	tst.w	d0
	beq.w	gdp_ndos		;unknown disk type

;- - evaluate Boot block - - - - - - - - - - - - - - - - - -

gdp_bootfound:
	or.w	#8,d3			;"Boot block OK"
	lea	11(a0),a1

	move.b	(a1)+,d2
	rol.w	#8,d2
	move.b	(a1)+,d2
	rol.w	#8,d2			;logische Block size

	move.b	(a1)+,BlocksPerCluster(a4)

	move.b	(a1)+,FATStartBlock+1(a4)
	move.b	(a1)+,FATStartBlock(a4)

	move.b	(a1)+,NumFATCopies(a4)

	move.b	(a1)+,RootDirEntries+1(a4)
	move.b	(a1)+,RootDirEntries(a4)

	move.b	(a1)+,TotalBlocks+3(a4)
	move.b	(a1)+,TotalBlocks+2(a4)
	clr.w	TotalBlocks(a4)		;if < 64K
	clr.l	HiddenBlocks(a4)

	lea	22(a0),a1

	move.b	(a1)+,BlocksPerFAT+3(a4)
	move.b	(a1)+,BlocksPerFAT+2(a4)
	clr.w	BlocksPerFAT(a4)	;FAT12 and FAT16

	move.b	(a1)+,BlocksPerTrack+1(a4)
	move.b	(a1)+,BlocksPerTrack(a4)

	move.b	(a1)+,Surfaces+1(a4)
	move.b	(a1)+,Surfaces(a4)

	tst.l	TotalBlocks(a4)
	bne.s	gdp_2

	move.b	(a1)+,HiddenBlocks+3(a4)
	move.b	(a1)+,HiddenBlocks+2(a4)
	move.b	(a1)+,HiddenBlocks+1(a4)
	move.b	(a1)+,HiddenBlocks(a4)

	move.b	(a1)+,TotalBlocks+3(a4)
	move.b	(a1)+,TotalBlocks+2(a4)
	move.b	(a1)+,TotalBlocks+1(a4)
	move.b	(a1)+,TotalBlocks(a4)	;if >= 64K
gdp_2:
	tst.w	RootDirEntries(a4)
	bne.s	gdp_3

	move.b	(a1)+,BlocksPerFAT+3(a4)
	move.b	(a1)+,BlocksPerFAT+2(a4)
	move.b	(a1)+,BlocksPerFAT+1(a4)
	move.b	(a1)+,BlocksPerFAT(a4)	;FAT32

	lea	44(a0),a1

	move.b	(a1)+,RootCluster+3(a4)
	move.b	(a1)+,RootCluster+2(a4)
	move.b	(a1)+,RootCluster+1(a4)
	move.b	(a1)+,RootCluster(a4)

	move.b	(a1)+,FSInfoBlock+3(a4)
	move.b	(a1)+,FSInfoBlock+2(a4)
	clr.w	FSInfoBlock(a4)

	lea	67(a0),a1
	bra.s	gdp_4
gdp_3:
	clr.l	RootCluster(a4)		;FAT12 and FAT16
	clr.l	FSInfoBlock(a4)
	lea	39(a0),a1
gdp_4:
	move.b	(a1)+,SerialNum+3(a4)
	move.b	(a1)+,SerialNum+2(a4)
	move.b	(a1)+,SerialNum+1(a4)
	move.b	(a1)+,SerialNum(a4)

	cmp.w	BlockSize(a4),d2
	beq.s	gdp_5			;keep Block size or..

	bsr.w	CacheFree
	move.w	d2,BlockSize(a4)
	bsr.w	SetIntParams
	bsr.w	CacheSet		;..switch to new
gdp_5:
	bsr.w	CacheResize		;obey NumFATCopies
	moveq.l	#0,d0
	move.b	BlocksPerCluster(a4),d0
	subq.l	#1,d0
	move.l	d0,ClusterBlockMask(a4)
	addq.l	#1,d0
	LOG2
	move.w	d0,ClusterShift(a4)
	moveq.l	#0,d1
	move.w	BlockSize(a4),d1
	lsl.l	d0,d1
	move.l	d1,ClusterSize(a4)
	subq.l	#1,d1
	move.l	d1,ClusterMask(a4)	;optimize

	moveq.l	#0,d0
	move.b	NumFATCopies(a4),d0
	move.l	BlocksPerFAT(a4),d1
	UMUL32
	moveq.l	#0,d1
	move.w	FATStartBlock(a4),d1
	add.l	d0,d1			;first Block # after FATs
	move.l	d1,RootStartBlock(a4)

	moveq.l	#0,d0
	move.w	RootDirEntries(a4),d0
	lsl.l	#5,d0			;*= MSDE_Sizeof
	add.l	BlockMask(a4),d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0			;/= BlockSize
	add.l	RootStartBlock(a4),d0
	move.l	d0,RootDirEnd(a4)	;start of data area
	neg.l	d0
	add.l	TotalBlocks(a4),d0	;# blocks in data area
	moveq.l	#0,d1
	move.b	BlocksPerCluster(a4),d1
	subq.b	#1,d1
	and.w	d0,d1
	move.w	d1,ClusterSniff(a4)	;unused (?) rest of partition
	move.w	ClusterShift(a4),d1
	lsr.l	d1,d0			;# Cluster
	addq.l	#2-1,d0			;1. Cluster has # 2
	move.l	d0,LastCluster(a4)

	move.w	#-1,FATType(a4)
	tst.w	RootDirEntries(a4)
	beq.s	gdp_ok			;FAT32

	cmp.w	#MINCLUSTERS16+1,d0
	scc	d0
	and.w	#1,d0
	move.w	d0,FATType(a4)

	moveq.l	#9,d0
	mulu.w	Surfaces(a4),d0
	move.l	TotalBlocks(a4),d1
	divu.w	d0,d1
	move.l	DiskRequest(a4),a0
	cmp.w	#40,d1
	bhi.s	gdp_6

	bset	#7,IO_Flags(a0)		;double step mode @ 40 tracks
	bra.s	gdp_ok
gdp_6:
	and.b	#$7f,IO_Flags(a0)
gdp_ok:
	move.l	FirstBlock(a4),d0
	add.l	TotalBlocks(a4),d0
	subq.l	#1,d0
	bsr.w	Test64			;safety for manually defined partition
	btst	#2,CmdFlags(a4)
	beq.s	gdp_7				;in direct SCSI mode..

	moveq.l	#0,d0
	not.w	d0
	move.w	BlockShift(a4),d1
	lsl.l	d1,d0
	cmp.l	EnvecBuf+DE_MaxTransfer(a4),d0
	bcc.s	gdp_7

	move.l	d0,EnvecBuf+DE_MaxTransfer(a4)	;..observe Read10 limit
gdp_7:
	move.l	DosType(a4),DiskType(a4) ;eg. `FAT\0`
	bsr.w	ReportGeometry
gdp_end:
	bsr.w	DoTimer
	move.w	d3,d0
	ext.l	d0
	movem.l	(sp)+,d2-d7/a2
	unlk	a5
	rts

gdp_none:
	moveq.l	#ID_NONE,d0
	bra.s	gdp_error

gdp_ndos:				;readable but incomprehensible
	bsr.w	ReportGeometry
	bsr.s	AutoLayout
	move.l	FirstBlock(a4),d0
	add.l	TotalBlocks(a4),d0
	subq.l	#1,d0
	bsr.w	Test64			;safety for manually defined partition
	move.l	#ID_NDOS,d0
	bra.s	gdp_error

gdp_bad:				;unreadable
	bsr.w	ReportGeometry
	move.l	#ID_BAD,d0
gdp_error:
	move.l	d0,DiskType(a4)
	bsr.w	CacheFree
	bra.s	gdp_end

gdp_fake:
	addq.l	#6,a0
	move.w	(a0)+,FATType(a4)
	move.l	(a0)+,d0
	lsr.l	#2,d0
	move.l	d0,EnvecBuf+DE_SizeBlock(a4)
	move.l	(a0)+,EnvecBuf+DE_BlocksPerTrack(a4)
	move.l	(a0)+,EnvecBuf+DE_Surfaces(a4)
	move.l	(a0)+,EnvecBuf+DE_LowCyl(a4)
	move.l	(a0),EnvecBuf+DE_HighCyl(a4)
	bset	#7,SearchMode(a4)
	bsr.w	DiskGeometry
	bclr	#7,SearchMode(a4)
	bra.s	gdp_ndos

;--- lay out an emty disk ----------------------------------

AutoLayout:
	movem.l	d2-d3,-(sp)
	move.l	TotalBlocks(a4),d2	;# blocks
	move.w	FATType(a4),d0
	bmi.s	alo_fat32		;preset by partition table
	beq.s	alo_fat12

	subq.w	#1,d0
	beq.s	alo_fat16

;- - autoselect FAT type - - - - - - - - - - - - - - - - - -

	cmp.l	#MINCLUSTERS32*32,d2
	bcc.s	alo_fat32		;>= 1 Gbyte

	cmp.l	#MINCLUSTERS16*8,d2
	bcc.s	alo_fat16		;>= 16 Mbyte

;- - FAT12  - - - - - - - - - - - - - - - - - - - - - - - -

alo_fat12:
	cmp.l	#MINCLUSTERS16*64,d2
	bcc.s	alo_fat16		;too big for standard FAT12

	clr.w	FATType(a4)		;"FAT12"
	cmp.l	#2880,d2
	beq.s	alo_hdfloppy
	bcs.s	alo_ddfloppy

	moveq.l	#1,d1			;"large" FAT12 for CompactFlash
alo_12loop:
	lsl.l	#1,d1
	lsr.l	#1,d2
	cmp.l	#MINCLUSTERS16,d2
	bcc.s	alo_12loop		;find a suitable Cluster size

	moveq.l	#32,d3			;32 root dir blocks
	bra.s	alo_12done

alo_hdfloppy:
	moveq.l	#1,d1			;HD Floppy: 1 Block/Cluster..
	moveq.l	#14,d3			;..and 14 root dir blocks
	bra.s	alo_12done
alo_ddfloppy:
	moveq.l	#2,d1			;DD Floppy: 2 blocks/Cluster
	lsr.l	#1,d2			;# Cluster
	moveq.l	#7,d3			;7 root dir blocks
alo_12done:
	move.l	d2,d0
	lsl.l	#1,d2
	add.l	d0,d2			;Nibbles per 12bit FAT
	bra.s	alo_fatsize

;- - FAT16  - - - - - - - - - - - - - - - - - - - - - - - -

alo_fat16:
	move.w	#1,FATType(a4)		;"FAT16"
	moveq.l	#1,d1
alo_cloop:
	lsl.w	#1,d1			;Cluster size and..
	lsr.l	#1,d2			;..# Clusters
	cmp.l	#MINCLUSTERS32,d2
	bcc.s	alo_cloop

	lsl.l	#2,d2			;Nibbles per 16bit FAT
	moveq.l	#32,d3			;32 root dir blocks
	bra.s	alo_fatsize

;- - FAT32  - - - - - - - - - - - - - - - - - - - - - - - -

alo_fat32:
	move.w	#-1,FATType(a4)		;"FAT32"
	moveq.l	#12,d0			;log2(4096)
	sub.w	BlockShift(a4),d0
	moveq.l	#1,d1
	lsl.l	d0,d1			;# blocks for 4k standard clusters
	lsr.l	d0,d2			;# Clusters
	cmp.l	#8*1024*256+1,d2
	bcs.s	alo_32			;> 8 Gbyte: 8k Clusters

	cmp.l	#60*1024*256+1,d2
	bcs.s	alo_31			;> 60 Gbyte: 16k Clusters

	lsl.l	#1,d1
	lsr.l	#1,d2
alo_31:
	lsl.l	#1,d1
	lsr.l	#1,d2
alo_32:
	lsl.l	#3,d2			;Nibbles per 32bit FAT
	moveq.l	#0,d3			;no fixed size root dir

alo_fatsize:
	move.b	d1,BlocksPerCluster(a4)
	move.b	#2,NumFATCopies(a4)
	move.l	d2,d0			;Nibbles per FAT
	moveq.l	#0,d1
	move.w	BlockSize(a4),d1
	lsl.l	#1,d1			;Nibbles per block
	add.l	d1,d0
	subq.l	#1,d0			;round up
	UDIVMOD32
	move.l	d0,BlocksPerFAT(a4)
	moveq.l	#1,d1			;1 (FAT12, FAT16) or..
	tst.w	FATType(a4)
	bpl.s	alo_1

	moveq.l	#32,d1			;..32 head blocks (FAT32)
alo_1:
	move.w	d1,FATStartBlock(a4)
	lsl.l	#1,d0			;blocks for 2 FAT copies
	add.l	d0,d1
	move.l	d1,RootStartBlock(a4)
	add.l	d3,d1
	move.l	d1,RootDirEnd(a4)
	movem.l	(sp)+,d2-d3
	rts

;--- externally report disk geometry -----------------------

ReportGeometry:
	movem.l	d2-d3,-(sp)
	move.w	PhysShift(a4),d3
	move.l	PhysSize(a4),d0
	lsr.l	#2,d0
	move.l	d0,EnvecBuf+DE_SizeBlock(a4)
	moveq.l	#0,d0
	move.w	Surfaces(a4),d0
	move.l	d0,EnvecBuf+DE_Surfaces(a4)
	moveq.l	#0,d2
	move.w	BlocksPerTrack(a4),d2
	lsr.l	d3,d2
	move.l	d2,EnvecBuf+DE_BlocksPerTrack(a4)
	mulu.w	d0,d2			;Sektors/Cylinder
	beq.s	rge_report		;no Guru #5
rge_again:
	move.l	FirstBlock(a4),d0
	lsr.l	d3,d0
	move.l	d2,d1
	UDIVMOD32
	tst.l	d1
	bne.s	rge_pseudo		;no whole cylinder

	move.l	d0,EnvecBuf+DE_LowCyl(a4)
	move.l	FirstBlock(a4),d0
	add.l	TotalBlocks(a4),d0
	lsr.l	d3,d0
	move.l	d2,d1
	UDIVMOD32
	tst.l	d1
	bne.s	rge_pseudo		;dito

	subq.l	#1,d0
	move.l	d0,EnvecBuf+DE_HighCyl(a4)
	bra.s	rge_report
rge_pseudo:
	moveq.l	#1,d0
	cmp.l	EnvecBuf+DE_Surfaces(a4),d0
	beq.s	rge_linear

	move.l	d0,EnvecBuf+DE_Surfaces(a4)
	move.l	EnvecBuf+DE_BlocksPerTrack(a4),d2
	bra.s	rge_again
rge_linear:
	moveq.l	#1,d2
	move.l	d2,EnvecBuf+DE_BlocksPerTrack(a4)
	bra.s	rge_again
rge_report:
	move.l	StartupMsg(a4),d0
	beq.s	rge_end

	move.l	d0,a0			;&FileSysStartupMsg
	move.l	FSSM_Environ(a0),d0
	beq.s	rge_end

	lsl.l	#2,d0
	move.l	d0,a1			;&DosEnvec
	lea	EnvecBuf(a4),a0		;updated information..
	bsr.w	CopyDosEnvec		;..for Format and DiskCopy
	move.l	DiskRequest(a4),a1
	move.w	#TD_PROTSTATUS,IO_Command(a1)
	bsr.w	SafeDoIO		;tell FDA
rge_end:
	movem.l	(sp)+,d2-d3
	rts

;*** device communication **********************************
;--- remove disk change interrupt --------------------------
; TD_REMCHANGEINT does not work!!

DiskRemChInt:
	move.l	a2,-(sp)
	lea	DiskReq2(a4),a2
	tst.l	(a2)
	beq.s	drci_end

	tst.b	DosType+3(a4)
	bne.s	drci_cmd

	bsr.w	_Forbid			;mfm/trackdisk v34 bug workaround
	move.l	(a2),a1
	bsr.w	MyRemove		;remove node from list..
	bsr.w	_Permit
	bra.s	drci_free
drci_cmd:
	move.l	(a2),a1
	move.w	#TD_REMCHANGEINT,IO_Command(a1)
	bsr.w	SafeDoIO
drci_free:
	move.l	(a2),a1
	bsr.w	FreeMsg			;..and free it
	clr.l	(a2)
drci_end:
	move.l	(sp)+,a2
	rts

;--- install disk change interrupt -------------------------
; <- struct Interrupt *ChInt;
; -> BOOL error;

DiskAddChInt:
	move.l	a2,-(sp)
	move.l	DiskRequest(a4),a2
	tst.l	DiskReq2(a4)
	beq.s	daci_new

	bsr.s	DiskRemChInt		;remove old interrupt first
daci_new:
	moveq.l	#IO_SimpleSizeof,d0
	move.l	ReplyPort(a4),a0
	bsr.w	AllocMsg		;make second disk IORequest..
	move.l	d0,DiskReq2(a4)
	beq.s	daci_error

	move.l	d0,a1
	move.l	IO_Device(a2),a6
	move.l	a6,IO_Device(a1)	;..and copy the important..
	move.l	IO_Unit(a2),IO_Unit(a1)	;..fields
	move.w	#TD_ADDCHANGEINT,IO_Command(a1)
	moveq.l	#IS_Sizeof,d0
	move.l	d0,IO_Length(a1)
	move.l	8(sp),IO_Data(a1)	;&Interrupt
	movem.l	d2-d7/a2-a5,-(sp)	;safety
	jsr	BeginIO(a6)
	movem.l	(sp)+,d2-d7/a2-a5
	moveq.l	#0,d0
daci_end:
	move.l	(sp)+,a2
	rts

daci_error:
	moveq.l	#1,d0
	bra.s	daci_end

;--- synchronous xxdisk.device access ----------------------

; -> 0 (no Disk), 1 (read only), 3 (rw)

DiskStatus:
	move.l	a2,-(sp)
	move.l	DiskRequest(a4),a2
	move.w	#TD_CHANGESTATE,IO_Command(a2)
	move.l	a2,a1
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	dst_scsi		;no trackdisk emulation

	tst.l	IO_Actual(a2)
	bne.s	dst_none		;no Disk

	move.w	#TD_PROTSTATUS,IO_Command(a2)
	move.l	a2,a1
	bsr.s	SafeDoIO
	tst.l	IO_Actual(a2)
	bne.s	dst_prot		;Disk read only
	bra.s	dst_ok
dst_scsi:
	lea	SCSIStruct(a4),a0
	clr.l	(a0)+			;SCSI_Data
	clr.l	(a0)+			;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	lea	SCSICmdLine(a4),a1
	move.l	a1,(a0)+		;SCSI_Command
	move.w	#6,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.l	(a0)+			;SCSI_SenseLength, _SenseActual
	move.b	#TESTUNITREADY,(a1)+	;the command line
	clr.b	(a1)+
	clr.w	(a1)+
	clr.w	(a1)+
	move.l	DiskRequest(a4),a1
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	SCSIStruct(a4),a0
	move.l	a0,IO_Data(a1)
	bsr.s	SafeDoIO
	tst.b	d0
	beq.s	dst_ok

	bsr.w	DiskSense
	cmp.b	#TDERR_WRITEPROT,d0
	beq.s	dst_prot
dst_none:
	moveq.l	#0,d0
	bra.s	dst_end			;no Disk
dst_ok:
	moveq.l	#3,d0
	moveq.l	#ID_VALIDATED,d1
	tst.w	SoftLocked(a4)
	bne.s	dst_p2			;soft write protection
	bra.s	dst_state
dst_prot:
	moveq.l	#1,d0
dst_p2:
	moveq.l	#ID_WRITE_PROT,d1
dst_state:
	move.l	d1,DiskState(a4)
dst_end:
	move.l	(sp)+,a2
	rts

; a1 <- &IORequest

SafeDoIO:
	movem.l	d2-d7/a2-a5,-(sp)	;safety
	CALLEXEC DoIO
	movem.l	(sp)+,d2-d7/a2-a5
	rts

DiskChangeNum:
	btst	#0,CmdFlags+1(a4)
	beq.s	dcn_end			;ETD commands unavailable

	move.l	a2,-(sp)
	move.l	DiskRequest(a4),a2
	move.w	#TD_CHANGENUM,IO_Command(a2)
	move.l	a2,a1
	bsr.s	SafeDoIO
	move.l	IO_Actual(a2),d0
	move.l	d0,IO_ChangeNum(a2)
	move.l	(sp)+,a2
dcn_end:
	rts

DiskMotorOff:
	move.l	DiskRequest(a4),a1
	move.w	#TD_MOTOR,IO_Command(a1)
	clr.l	IO_Length(a1)
	bra.s	SafeDoIO

DiskClear:
	move.l	DiskRequest(a4),a1
	move.w	#CMD_CLEAR,IO_Command(a1)
	bra.s	SafeDoIO

DiskUpdate:
	btst	#3,CmdFlags+1(a4)
	beq.s	du_ok			;unsupported, omit

	move.l	DiskRequest(a4),a1
	move.w	UpdateCmd(a4),IO_Command(a1)
	bsr.s	SafeDoIO
	bsr.s	DiskSense
	cmp.b	#45,d0
	beq.s	du_off

	cmp.b	#IOERR_NOCMD,d0
	bne.s	du_end
du_off:
	and.w	#~8,CmdFlags(a4)
du_ok:
	moveq.l	#0,d0
du_end:
	rts

DiskSense:
	move.l	d2,-(sp)
	moveq.l	#0,d2
	move.b	d0,d2
	cmp.b	#45,d2
	bne.s	ds_end			;pass on other errors

	lea	SCSIStruct(a4),a0
	lea	SenseBuffer(a4),a1
	move.l	a1,(a0)+		;SCSI_Data
	moveq.l	#0,d0
	not.b	d0
	move.l	d0,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	lea	SCSICmdLine(a4),a1
	move.l	a1,(a0)+		;SCSI_Command
	move.w	#6,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.b	#SCSIF_READ,(a0)+	;SCSI_Flags
	clr.b	(a0)+			;SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.l	(a0)+			;SCSI_SenseLength, _SenseActual
	move.b	#REQUESTSENSE,(a1)+	;the command line
	clr.b	(a1)+
	clr.w	(a1)+
	move.b	d0,(a1)+
	clr.b	(a1)+
	move.l	DiskRequest(a4),a1
	move.w	#HD_SCSICMD,IO_Command(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	SCSIStruct(a4),a0
	move.l	a0,IO_Data(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	ds_end			;no sense data

	moveq.l	#$0f,d0
	and.b	SenseBuffer+2(a4),d0	;Sense-Key
	beq.s	ds_end			;everything OK??

	cmp.b	#$01,d0
	beq.s	ds_ok			;recovered error

	move.b	SenseBuffer+12(a4),d0	;Sense-Code
	lea	ds_tab(pc),a0
ds_loop:
	move.w	(a0)+,d1
	beq.s	ds_end			;Code unknown

	cmp.b	d0,d1
	bne.s	ds_loop

	lsr.w	#8,d1
	move.b	d1,d2			;the corresponding Amiga error code
ds_end:
	move.l	d2,d0
	move.l	(sp)+,d2
	rts

ds_ok:
	moveq.l	#0,d2
	bra.s	ds_end

ds_tab:
	dc.b	TDERR_DRIVEINUSE, $04 	;not ready
	dc.b	TDERR_NOSECHDR,	  $11 	;read error
	dc.b	IOERR_NOCMD,	  $20 	;unsupported
	dc.b	IOERR_BADLENGTH,  $21 	;invalid block adress
	dc.b	IOERR_NOCMD,	  $22 	;unknown function
	dc.b	IOERR_BADLENGTH,  $24 	;wrong parameter(s)
	dc.b	TDERR_WRITEPROT,  $27 	;read only
	dc.b	TDERR_DISKCHANGED,$28 	;disk changed
	dc.b	TDERR_DISKCHANGED,$3a 	;no Disk
	dc.b	0, 0

DiskGeometry:
	movem.l	d2-d4/a2,-(sp)
	sub.l	a2,a2			;no unmotivated FreeMem() below

;- - query .device - - - - - - - - - - - - - - - - - - - - -

	tst.b	SearchMode(a4)
	bne.w	dge_mountlist		;use manual settings..

	clr.l	EnvecBuf+DE_LowCyl(a4)	;..or scan automatically

	moveq.l	#DG_Sizeof,d0
	move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
	CALLEXEC AllocMem
	move.l	d0,a2			;&DriveGeometry
	tst.l	d0
	beq.s	dge_fallback

	move.l	DiskRequest(a4),a1
	move.w	#TD_GETGEOMETRY,IO_Command(a1)
	move.l	a2,IO_Data(a1)
	moveq.l	#DG_Sizeof,d0
	move.l	d0,IO_Length(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	dge_fallback		;device stays silent..

	move.l	DG_BufMemType(a2),BufMemType(a4) ;..or knows all better
	move.l	DG_SectorSize(a2),d3
	move.l	DG_Cylinders(a2),d2
	beq.s	dge_linear

	move.l	DG_Heads(a2),d1
	beq.s	dge_planar

	move.l	DG_TrackSectors(a2),d0
	bne.w	dge_dok
dge_planar:
	move.l	DG_CylSectors(a2),d0
	bne.s	dge_pok
dge_linear:
	move.l	DG_TotalSectors(a2),d2
	beq.s	dge_fallback		;whats all this then??

	moveq.l	#1,d0
dge_pok:
	moveq.l	#1,d1
	bra.w	dge_dok

;- - special case messydisk.device - - - - - - - - - - - - -

dge_fallback:
	tst.b	DosType+3(a4)
	bne.s	dge_readcapacity	;for floppies..

	move.l	DiskRequest(a4),a1
	move.w	#TD_GETDRIVETYPE,IO_Command(a1)
	bsr.w	SafeDoIO
	tst.b	d0
	bne.w	dge_mountlist		;..if no doubt..

	move.l	DiskRequest(a4),a1
	moveq.l	#9,d0
	moveq.l	#2,d1
	moveq.l	#40,d2
	move.l	IO_Actual(a1),d3
	subq.l	#2,d3
	beq.s	dge_floppy		;5 1/4", 40 tracks

	moveq.l	#80,d2
	subq.l	#1,d3
	bne.s	dge_floppy		;3 1/2", DD or unknown type

	moveq.l	#18,d0			;3 1/2", HD
dge_floppy:
	move.l	#512,d3			;..use default values
	bra.s	dge_dok

;- - information per SCSI  - - - - - - - - - - - - - - - - -

dge_readcapacity:
	move.l	DiskRequest(a4),a1
	move.w	#HD_SCSICMD,IO_Command(a1)
	lea	SCSIStruct(a4),a0
	move.l	a0,IO_Data(a1)
	moveq.l	#SCSI_Sizeof,d0
	move.l	d0,IO_Length(a1)
	lea	SenseBuffer(a4),a1
	move.l	a1,(a0)+		;SCSI_Data
	moveq.l	#8,d0
	move.l	d0,(a0)+		;SCSI_Length
	clr.l	(a0)+			;SCSI_Actual
	lea	SCSICmdLine(a4),a1
	move.l	a1,(a0)+		;SCSI_Command
	move.w	#10,(a0)+		;SCSI_CmdLength
	clr.w	(a0)+			;SCSI_CmdActual
	move.w	#SCSIF_READ<<8,(a0)+	;SCSI_Flags, SCSI_Status
	clr.l	(a0)+			;SCSI_SenseData
	clr.l	(a0)			;SCSI_SenseLength, SCSI_SenseActual
	move.w	#READCAPACITY<<8,(a1)+	;the command line
	clr.l	(a1)+
	clr.l	(a1)
	move.l	DiskRequest(a4),a1
	bsr.w	SafeDoIO
	tst.b	d0
	bne.s	dge_mountlist

	move.l	SenseBuffer+4(a4),d3
	move.l	SenseBuffer(a4),d0
	addq.l	#1,d0
	move.l	d0,d2
	moveq.l	#1,d1
	moveq.l	#1,d0
	bra.s	dge_dok

;- - last resort: MountList  - - - - - - - - - - - - - - - -

dge_mountlist:
	move.l	EnvecBuf+DE_SizeBlock(a4),d3
	lsl.l	#2,d3
	move.l	EnvecBuf+DE_HighCyl(a4),d2
	addq.l	#1,d2
	move.l	EnvecBuf+DE_Surfaces(a4),d1
	bne.s	dge_m1

	moveq.l	#2,d1
dge_m1:
	move.l	EnvecBuf+DE_BlocksPerTrack(a4),d0
	bne.s	dge_dok

	moveq.l	#9,d0

;- - fill in geometry table  - - - - - - - - - - - - - - - -

dge_dok:
	move.l	#512,d4			;default logical block size
	move.w	d4,BlockSize(a4)
	cmp.l	d4,d3
	bcc.s	dge_1

	move.l	d4,d3
dge_1:
	move.l	d3,PhysSize(a4)
	bsr.w	SetIntParams
	move.w	PhysShift(a4),d4
	move.l	d2,Cylinders(a4)
	move.w	d1,Surfaces(a4)
	lsl.l	d4,d0
	move.w	d0,BlocksPerTrack(a4)
	lsr.l	d4,d0
	UMUL32
	move.l	d0,CylSectors(a4)
	move.l	d0,d3
	move.l	EnvecBuf+DE_LowCyl(a4),d1
	UMUL32
	lsl.l	d4,d0
	move.l	d0,FirstBlock(a4)
	move.l	d3,d0
	move.l	d2,d1
	UMUL32
	move.l	d0,TotalSectors(a4)
	lsl.l	d4,d0			;LastBlock + 1, see below
	move.l	d0,d1
	sub.l	FirstBlock(a4),d1
	move.l	d1,TotalBlocks(a4)
	clr.l	HiddenBlocks(a4)
	move.b	#1,NumFATCopies(a4)	;1 buffer for GetDiskParams()

;- - choose command set  - - - - - - - - - - - - - - - - - -

	move.l	#CMD_READ<<16+CMD_WRITE,d2
	move.w	#CMD_UPDATE,d3
	btst	#0,CmdFlags+1(a4)	;if supported,..
	beq.s	dge_cmd1

	move.l	#ETD_READ<<16+ETD_WRITE,d2
	move.w	#ETD_UPDATE,d3		;..ETD commands,..
dge_cmd1:
	subq.l	#1,d0
	bcs.s	dge_cmd2		;size unknown

	move.w	BlockShift(a4),d1
	rol.l	d1,d0
	and.l	BlockMask(a4),d0
	beq.s	dge_cmd2		;..and if > 4 Gbyte..

	btst	#1,CmdFlags+1(a4)
	beq.s	dge_cmd2		;..prefer TD64 commands..

	move.l	#NSCMD_TD_READ64<<16+NSCMD_TD_WRITE64,d2
dge_cmd2:
	move.l	d2,ReadCmd(a4)
	move.w	d3,UpdateCmd(a4)	;..when possible

	move.l	a2,d0
	beq.s	dge_end

	moveq.l	#DG_Sizeof,d0
	move.l	a2,a1
	CALLEXEC FreeMem
dge_end:
	movem.l	(sp)+,d2-d4/a2
	rts

;*** search or create an Object ****************************
;--- search or create an XLock for Object ------------------
; <- struct XLock *base dir, struct ExtMSDirEntry *msde, LONG access mode;
; -> struct XLock *xn;

xLock:
	link.w	a5,#-4
	move.l	a2,-(sp)
	move.l	VolumeNode(a4),a2
	add.w	#XDOL_XLockList,a2
	move.l	12(a5),a0		;&ExtMSDirEntry
	moveq.l	#EXCLUSIVE_LOCK,d0
	cmp.l	16(a5),d0
	bne.s	xlo_shared

	moveq.l	#$18,d0
	and.b	MSDE_Flags(a0),d0	;for dirs..
	beq.s	xlo_loop
xlo_shared:
	moveq.l	#SHARED_LOCK,d0
	move.l	d0,16(a5)		;..no exclusive access
xlo_loop:
	move.l	(a2),a2			;&next XLock
	tst.l	(a2)
	beq.s	xlo_new			;list end, create

	move.l	XL_Key(a2),d0
	cmp.l	XMSDE_Key(a0),d0
	bne.s	xlo_1

	move.w	XL_Offset(a2),d0
	cmp.w	XMSDE_Offset(a0),d0
	beq.s	xlo_found		;XLock already present
xlo_1:
	tst.w	FATType(a4)
	bpl.s	xlo_2

	move.w	XL_MSDE+MSDE_1H(a2),d0
	cmp.w	MSDE_1H(a0),d0
	bne.s	xlo_loop
xlo_2:
	move.w	XL_MSDE+MSDE_1L(a2),d0
	cmp.w	MSDE_1L(a0),d0		;multiple links..
	bne.s	xlo_loop

	moveq.l	#$18,d0
	and.b	MSDE_Flags(a0),d0	;..to same..
	beq.s	xlo_loop

	moveq.l	#$18,d0
	and.b	XL_MSDE+MSDE_Flags(a2),d0 ;..dir
	beq.s	xlo_loop
xlo_found:
	tst.w	XL_OpenCnt(a2)
	blt.s	xlo_inuse		;exclusive access on

	moveq.l	#EXCLUSIVE_LOCK,d0
	cmp.l	16(a5),d0
	beq.s	xlo_inuse		;this will only work with new XLock

	addq.w	#1,XL_OpenCnt(a2)
	move.l	a2,d0
xlo_end:
	move.l	(sp)+,a2
	unlk	a5
	rts

xlo_inuse:
	move.w	#202,ErrorNum(a4)	;"object still in use"
	moveq.l	#0,d0
	bra.s	xlo_end

xlo_nomem:
	move.w	#103,ErrorNum(a4)	;no mem
	bra.s	xlo_end

xlo_new:
	moveq.l	#XL_Sizeof/4,d0
	lsl.l	#2,d0
	moveq.l	#MEMF_PUBLIC,d1
	CALLEXEC AllocMem		;make new XLock
	tst.l	d0
	beq.s	xlo_nomem

	move.l	d0,a2
	move.l	8(a5),d0		;if present..
	beq.s	xlo_n1

	move.l	d0,a0
	bsr.w	ForceOpenXLock		;..open base dir as well
xlo_n1:
	move.l	d0,XL_Parent(a2)	;for base dir,..
	moveq.l	#-1,d0			;..mark exclusive or..
	cmp.l	#EXCLUSIVE_LOCK,16(a5)
	beq.s	xlo_n2

	moveq.l	#1,d0			;..1 read access
xlo_n2:
	move.w	d0,XL_OpenCnt(a2)
	clr.l	XL_FilePos(a2)		;reset append pointer
	clr.l	XL_FileChain(a2)
	move.l	12(a5),a0
	lea	XL_MSDE(a2),a1
	moveq.l	#XMSDE_FNLength+5,d0
	add.b	XMSDE_FNLength(a0),d0
	lsr.l	#2,d0			;through end of long name..
	subq.w	#1,d0
xlo_ncopy:
	move.l	(a0)+,(a1)+		;..make ExtMSDirEntry
	dbf	d0,xlo_ncopy

	move.l	VolumeNode(a4),a0
	move.l	a0,XL_Volume(a2)
	add.w	#XDOL_XLockList,a0
	move.l	a2,a1
	bsr.w	MyAddHead
	move.l	a2,d0
	bra.w	xlo_end

;--- search Object on Disk and set XLock -------------------
; <- struct XLock *base dir, BPTR_BSTR *name,
;	ULONG access mode, struct XLock *ignore this object
;	(FORCE_MODE only);
; -> struct XLock *location;

LOB_CSTR	= -32-XMSDE_Sizeof-256
LOB_MSDEBUF	= -32-XMSDE_Sizeof
LOB_NAMEBUF	= -32
LOB_NAMENEXT	= -20		;&next name component
LOB_TO		= -16		;2 times struct DiskKey
LOB_FROM	= -10
LOB_DIRBLOCK	= -4

LOB_DIRXL	= 8		;parameters
LOB_NAME	= 12
LOB_MODE	= 16		;SHARED_LOCK or EXCLUSIVE_LOCK,..
				;..Bit 31 = 0 for "create new",..
				;..Bit 30 = 0 for "ignore hit"
				;..Bit 29 = 0 for "open exclusive locks too"
				;..Bit 28 = 0 (internal) "short name already used"
LOB_IGNOREXL	= 20

LocateObj:
	link.w	a5,#LOB_CSTR
	movem.l	d2-d4/a2-a3,-(sp)
	clr.l	NewObject(a4)		;second reply value
	move.l	LOB_NAME(a5),d0		;(BPTR)BSTR source
	lea	LOB_CSTR(a5),a1
	move.l	a1,LOB_NAME(a5)
	lsl.l	#2,d0
	beq.s	lob_nend		;no String = empty String

	move.l	d0,a0
	moveq.l	#0,d2
	move.b	(a0)+,d2		;length in bytes
lob_npart:
	moveq.l	#MAXNAMELEN,d1
lob_nchar:
	subq.w	#1,d2
	bmi.s	lob_nend		;BString ends

	move.b	(a0)+,d0
	cmp.b	#':',d0			;if present..
	beq.s	lob_ndev		;..skip device or volume name,..

	cmp.b	#'/',d0
	beq.s	lob_ndir

	subq.w	#1,d1			;limit each name component..
	bmi.s	lob_nchar		;..to length

	move.b	d0,(a1)+
	bra.s	lob_nchar
lob_ndir:
	tst.w	d2			;any chars remaining after '/'?
	beq.s	lob_nend		;no - trailing slash, skip it
	cmp.b	#'/',(a0)		;is next char also '/'?
	beq.s	lob_npart		;yes - skip consecutive slashes
	move.b	d0,(a1)+		;no - copy this '/' as path separator
	bra.s	lob_npart
lob_ndev:
	move.l	LOB_NAME(a5),a1		;..eg. Workbench-Device " ^WB^:"
	bra.s	lob_npart
lob_nend:
	clr.b	(a1)
	move.l	LOB_DIRXL(a5),a0
	bsr.w	ForceOpenXLock		;open base dir..
	move.l	d0,LOB_DIRXL(a5)	;..even if it is a file
	lea	LOB_MSDEBUF(a5),a2	;optimize

;- - scan dir  - - - - - - - - - - - - - - - - - - - - - - -

lob_scandir:
	move.l	LOB_NAME(a5),a0
	tst.b	(a0)
	beq.w	lob_found		;hit

	lea	LOB_NAMEBUF(a5),a1
	bsr.w	MakeShortName
	move.l	a0,LOB_NAMENEXT(a5)
	moveq.l	#SHARED_LOCK,d4
	tst.b	(a0)
	bne.s	lob_sd1			;only within target dir..

	move.l	LOB_MODE(a5),d4		;..follow mode
lob_sd1:
	tst.w	d0			;allow relative paths..
	bmi.w	lob_parent		;..off files

	move.l	LOB_DIRXL(a5),a0
	moveq.l	#$18,d0
	and.b	XL_MSDE+MSDE_Flags(a0),d0
	beq.w	lob_wrongtype		;file instead of dir??

	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	lob_sd2

	move.w	XL_MSDE+MSDE_1H(a0),d0
	swap	d0
lob_sd2:
	move.w	XL_MSDE+MSDE_1L(a0),d0
	bsr.w	Cluster2Block
	move.l	d0,LOB_DIRBLOCK(a5)	;start of dir
	move.l	d0,LOB_FROM(a5)
	clr.w	LOB_FROM+4(a5)
	move.l	d0,LOB_TO(a5)
	clr.w	LOB_TO+4(a5)

lob_readentry:
	move.l	LOB_FROM(a5),d2
	move.w	LOB_FROM+4(a5),d3
	move.l	a2,-(sp)
	pea	LOB_FROM(a5)
	bsr.w	ReadXMSDE
	addq.w	#8,sp
	tst.w	d0
	beq.w	lob_ready		;read error

	move.b	(a2),d0
	beq.w	lob_done		;end of dir

	cmp.b	#MSDEB_DELETED,d0
	beq.w	lob_nomatch

	tst.l	d4			;in write mode do densify..
	bmi.s	lob_check

	cmp.l	LOB_TO(a5),d2
	bne.s	lob_move

	cmp.w	LOB_TO+4(a5),d3
	beq.s	lob_isopt
lob_move:
	pea	LOB_TO(a5)
	move.l	a2,-(sp)
	bsr.w	MoveXMSDE		;..target dir
	addq.l	#8,sp
	bra.s	lob_check
lob_isopt:
	move.l	LOB_FROM(a5),LOB_TO(a5)
	move.w	LOB_FROM+4(a5),LOB_TO+4(a5)

;- - evaluate entry  - - - - - - - - - - - - - - - - - - - -

lob_check:
	btst	#3,MSDE_Flags(a2)
	bne.w	lob_nomatch		;ignore disk name

	lea	XMSDE_FullName(a2),a0	;&long name..
	move.b	(a0),d2
	beq.s	lob_oldstyle		;..not available

	move.l	LOB_NAME(a5),a1		;&desired name..
	move.b	#$df,d2
lob_cfull:
	move.b	(a1)+,d1
	beq.s	lob_cf1

	cmp.b	#'/',d1			;..may contain further components
	beq.s	lob_cf1

	move.b	(a0)+,d0
	beq.s	lob_oldstyle

	and.b	d2,d0			;toUpper
	and.b	d2,d1
	cmp.b	d0,d1
	beq.s	lob_cfull
	bra.s	lob_oldstyle
lob_cf1:
	tst.b	(a0)
	beq.s	lob_chit		;long name fits

lob_oldstyle:
	move.l	a2,a0			;MSDE_Name
	lea	LOB_NAMEBUF(a5),a1
	moveq.l	#10,d0			;8 + 3 chars
lob_cstd:
	cmpm.b	(a1)+,(a0)+
	dbne	d0,lob_cstd
	bne.s	lob_nomatch		;wrong short name

	tst.b	d2
	bne.s	lob_double
lob_chit:
	moveq.l	#$ffffff80,d0
	or.l	d4,d0			;no special modes here
	move.l	d0,-(sp)
	move.l	a2,-(sp)
	move.l	LOB_DIRXL(a5),-(sp)
	bsr.w	xLock
	add.w	#12,sp
	move.l	d0,d3
	beq.w	lob_ready		;eg. in use

	btst	#30,d4			;in FORCE_MODE..
	bne.s	lob_chdir

	cmp.l	LOB_IGNOREXL(a5),d3	;..ignore..
	bne.s	lob_chdir

	move.l	d3,a1
	bsr.w	CloseXLock
	bra.s	lob_nomatch		;..this one

lob_parent:
	move.l	LOB_DIRXL(a5),a0
	bsr.w	xParent
	move.l	d0,d3
	beq.w	lob_notfound		;above root is impossible
lob_chdir:
	move.l	LOB_DIRXL(a5),a1
	bsr.w	CloseXLock
	move.l	d3,LOB_DIRXL(a5)	;continue in this Object
	move.l	LOB_NAMENEXT(a5),LOB_NAME(a5)
	bra.w	lob_scandir

lob_double:
	bclr	#28,d4			;"short name in use"
lob_nomatch:
	tst.l	LOB_FROM(a5)
	bne.w	lob_readentry		;check next entry

lob_done:
	tst.l	d4			;existing Object or..
	bmi.w	lob_notfound		;..even dir not found

;- - create new Object - - - - - - - - - - - - - - - - - -

	moveq.l	#ID_VALIDATED,d0
	cmp.l	DiskState(a4),d0
	bne.w	lob_readonly		;Disk read only

	clr.w	ErrorNum(a4)		;OK for create
	btst	#28,d4
	bne.s	lob_copy		;if in use..

	pea	LOB_NAMEBUF(a5)
	move.l	LOB_DIRBLOCK(a5),-(sp)
	bsr.w	UniqueStdName		;..get a unique short name
	addq.l	#8,sp
lob_copy:
	lea	LOB_NAMEBUF(a5),a0
	move.l	a2,a1
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+		;copy short name
	clr.w	(a1)			;MSDE_unused1 and MSDE_CMilSecs
	clr.w	MSDE_1H(a2)
	clr.w	MSDE_1L(a2)
	clr.l	MSDE_FSize(a2)

	moveq.l	#-1,d0
	move.l	d0,XMSDE_ExtKey(a2) ;"extended entry" for CheckDirSpace()

	move.l	LOB_NAME(a5),a0
	lea	XMSDE_FullName(a2),a1
	moveq.l	#11,d0
	sub.l	a1,d0
lob_fncopy:
	move.b	(a0)+,(a1)+		;copy long name
	bne.s	lob_fncopy

	add.l	a1,d0			;name length + 12
	moveq.l	#-12,d1
	add.l	d0,d1
	move.b	d1,XMSDE_FNLength(a2)	;BStr length
	divu.w	#13,d0
	move.b	d0,XMSDE_ExtNum(a2)	;extension count

	move.l	a2,-(sp)
	pea	LOB_TO(a5)
	move.l	LOB_DIRXL(a5),-(sp)
	bsr.w	CheckDirSpace
	add.w	#12,sp
	move.w	LOB_TO+4(a5),XMSDE_ExtOffset(a2)
	move.l	LOB_TO(a5),XMSDE_ExtKey(a2)
	beq.w	lob_ready		;dir full

	moveq.l	#$ffffff80,d0
	or.l	d4,d0			;no special modes
	move.l	d0,-(sp)
	move.l	a2,-(sp)
	move.l	LOB_DIRXL(a5),-(sp)
	bsr.w	xLock
	add.w	#12,sp
	move.l	d0,NewObject(a4)
	beq.w	lob_ready		;no mem

	pea	2.w			;set all 3 time stamps..
	move.l	d0,-(sp)
	bsr.w	TouchXLock		;..and save new entry
	addq.w	#8,sp
	pea	1.w
	move.l	LOB_DIRXL(a5),-(sp)
	bsr.w	TouchXLock		;touch dir
	addq.w	#8,sp

;- - optimize: mark rest of dir as unused  - - - - - - - - -

lob_killtail:
	move.l	NewObject(a4),a0
	move.l	XL_Key(a0),d2
	move.w	XL_Offset(a0),d3
	move.l	d2,d0
	bsr.w	Block2Cluster
	move.l	d0,d4
	beq.s	lob_ktstart		;unless in fixed size root..

	bsr.w	NextCluster
	tst.l	d0
	ble.s	lob_ktstart		;..free following..

	bsr.w	FreeChain		;..clusters
	move.l	d4,d0
	moveq.l	#-1,d1
	bsr.w	PutFATEntry		;cut cluster chain here
lob_ktstart:
	bsr.w	NextMSDE		;start below new entry
lob_ktblock:
	move.l	d2,d0
	beq.s	lob_ready		;end of dir

	bsr.w	ReadDirBlock
	move.l	a0,a3			;&Block buffer
	move.l	d0,a2			;&Block contents
	moveq.l	#0,d4			;"no changes yet"
	tst.l	d0
	beq.s	lob_ready		;read error
lob_ktentry:
	move.l	a2,a0
	add.w	d3,a0			;&entry
	tst.b	(a0)
	bne.s	lob_ktclear

	moveq.l	#0,d2			;already marked from here, stop
	bra.s	lob_ktnext
lob_ktclear:
	moveq.l	#1,d4			;"Block changed"..
	moveq.l	#MSDE_Sizeof/8,d0
lob_ktloop:
	clr.l	(a0)+
	clr.l	(a0)+			;..because entry now deleted
	subq.w	#1,d0
	bgt.s	lob_ktloop

	bsr.w	NextMSDE
	tst.w	d3
	bne.s	lob_ktentry		;on with same block
lob_ktnext:
	tst.w	d4
	beq.s	lob_ktblock

	move.l	a3,a0
	move.l	a2,d0
	bsr.w	BlockChanged
	bra.s	lob_ktblock

;- - Done!!! - - - - - - - - - - - - - - - - - - - - - - - -

lob_notfound:
	move.w	#205,ErrorNum(a4)	;"not found"
lob_ready:
	move.l	LOB_DIRXL(a5),a1
	bsr.w	CloseXLock		;free base dir
	moveq.l	#0,d0
lob_end:
	movem.l	(sp)+,d2-d4/a2-a3
	unlk	a5
	rts

lob_found:
	move.l	LOB_DIRXL(a5),d0	;Object found,..
	move.l	d0,a0
	cmp.w	#-2,XL_OpenCnt(a0)
	bgt.s	lob_end			;..keep XLock

	btst	#5,LOB_MODE(a5)		;do open exclusive..
	beq.s	lob_end			;..XLock multiple times

	move.w	#202,ErrorNum(a4)	;"in use"
	bra.s	lob_ready

lob_wrongtype:
	move.w	#212,ErrorNum(a4)	;file instead of dir??
	bra.s	lob_ready

lob_readonly:
	move.w	#214,ErrorNum(a4)
	bra.s	lob_ready

;--- open XLock --------------------------------------------
; a0 <- struct XLock *xl or 0 for "root dir";
; d0 -> *xl or 0

ForceOpenXLock:
	moveq.l	#-1,d1			;special LocateObj() mode
	bra.s	oxl_start

OpenXLock:
	moveq.l	#0,d1
oxl_start:
	move.l	a0,d0
	bne.s	oxl_1

	move.l	RootXLock(a4),d0
	move.l	d0,a0
oxl_1:
	tst.w	XL_OpenCnt(a0)
	bgt.s	oxl_open

	tst.w	d1
	bne.s	oxl_force

	move.w	#202,ErrorNum(a4)	;exclusive access
	moveq.l	#0,d0
oxl_end:
	rts

oxl_open:
	addq.w	#1,XL_OpenCnt(a0)
	bra.s	oxl_end

oxl_force:				;open exclusive XLock..
	subq.w	#1,XL_OpenCnt(a0)	;..multiple times internally
	bra.s	oxl_end

;--- get parent dir XLock ----------------------------------
; a0 <- struct XLock *this;
; d0 -> struct XLock *parent;

xParent:
	move.l	a0,d0
	beq.s	xpa_error

	move.l	XL_Parent(a0),d0
	beq.s	xpa_end

	move.l	d0,a0
	bsr.s	OpenXLock
xpa_end:
	rts

xpa_error:
	move.w	#205,ErrorNum(a4)
	bra.s	xpa_end

;--- close XLock -------------------------------------------
; a1 <- struct XLock *xl;
; d0 -> BOOL ok;

CloseXLock:
	movem.l	d2-d3,-(sp)
	move.l	a1,d2
	beq.s	cxl_end
cxl_loop:
	move.l	d2,a1			;&XLock
	moveq.l	#-1,d1			;shared or..
	move.w	XL_OpenCnt(a1),d0
	bgt.s	cxl_1

	moveq.l	#1,d1			;..exklusive XLock
cxl_1:
	add.w	d1,d0			;1 less user
	move.w	d0,XL_OpenCnt(a1)
	bne.s	cxl_end			;still used

	move.l	4(a1),d3		;&previous XLock or &XLock list
	bsr.w	MyRemove		;remove XLock
	move.l	d2,a1
	btst	#3,XL_MSDE+MSDE_Flags(a1)
	beq.s	cxl_free		;when removed root XLock..

	move.l	d3,a0
	addq.l	#4,d3
	cmp.l	(a0),d3
	bne.s	cxl_free		;..and XLockList now empty..

	pea	-XDOL_XLockList(a0)
	bsr.w	UnMountVolume		;..free VolumeNode
	addq.w	#4,sp
cxl_free:
	move.l	d2,a1
	move.l	XL_Parent(a1),d2
	moveq.l	#XL_Sizeof/4,d0
	lsl.l	#2,d0
	CALLEXEC FreeMem		;free XLock mem
	tst.l	d2			;if present..
	bne.s	cxl_loop		;..close parent dir
cxl_end:
	moveq.l	#TRUE,d0
	movem.l	(sp)+,d2-d3
	rts

;--- Object name ExtMSDirEntry -> BSTR ----------------------
; a0 <- struct ExtMSDirEntry *source
; a1 <- char *target

GetBName:
	movem.l	a2-a3,-(sp)
	move.l	a0,a3			;&source
	move.l	a1,a2			;&target
	moveq.l	#0,d0
	move.b	XMSDE_FNLength(a0),d0
	beq.s	gbn_standard		;if present..

	addq.w	#2,d0
	add.w	#XMSDE_FNLength,a0
gbn_full:
	move.l	(a0)+,(a1)+		;..use long name
	subq.w	#4,d0
	bgt.s	gbn_full
	bra.w	gbn_end

gbn_standard:
	addq.l	#1,a1			;room for length byte
	btst	#3,MSDE_Flags(a0)
	beq.s	gbn_filename

	moveq.l	#11,d0
	bsr.s	SpcStrCopy		;Disk name (<= 11 chars)
	bra.s	gbn_namelen

gbn_filename:
	moveq.l	#8,d0
	bsr.s	SpcStrCopy		;file-/dir name (<= 8)
	move.b	#'.',(a1)+		;dot
	move.l	a1,-(sp)
	moveq.l	#3,d0
	bsr.s	SpcStrCopy		;Name extension (<= 3)
	cmp.l	(sp)+,a1
	bne.s	gbn_namelen

	subq.l	#1,a1			;no ext, no dot
gbn_namelen:
	clr.b	(a1)			;C String termination AND..
	move.l	a2,a0
	move.l	a1,d0
	sub.l	a0,d0
	subq.l	#1,d0
	move.b	d0,(a0)+		;..Name length
	cmp.b	#$05,(a0)
	bne.s	gbn_convert

	move.b	#$e5,(a0)		;secial case 1. char = MSDE_DELETED
gbn_convert:
	bsr.w	StrPc2Amiga		;Name PC437 -> Amiga
	move.w	#$0c00,d0
	and.w	CmdFlags(a4),d0
	beq.s	gbn_end			;keep uppercase

	btst	#3,MSDE_Flags(a3)
	bne.s	gbn_end			;no Disk name

	move.l	a2,a0
	addq.l	#1,a0
	btst	#10,d0
	beq.s	gbn_lnext

	tst.b	(a0)+			;mode "L": keep 1. char
	beq.s	gbn_end
	bra.s	gbn_lnext
gbn_lloop:
	cmp.b	#'A',d0
	bcs.s	gbn_lnext

	cmp.b	#'Z'+1,d0
	bcs.s	gbn_ldown

	cmp.b	#$c0,d0
	bcs.s	gbn_lnext

	cmp.b	#$df,d0
	bcc.s	gbn_lnext
gbn_ldown:
	or.b	#32,d0			;to lower
	move.b	d0,-1(a0)
gbn_lnext:
	move.b	(a0)+,d0
	bne.s	gbn_lloop
gbn_end:
	movem.l	(sp)+,a2-a3
	rts

;--- space trim string -------------------------------------
; a0 <-> &source
; a1 <-> &target
; d0 <-> length

SpcStrCopy:
	move.l	a1,d1
ssc_loop:
	move.b	(a0),(a1)+
	cmp.b	#' ',(a0)+
	beq.s	ssc_next

	move.l	a1,d1
ssc_next:
	subq.w	#1,d0
	bgt.s	ssc_loop

	move.l	d1,a1
	rts

;--- extra timestamps MSDE -> BStr -------------------------
; <- struct MSDirEntry *source, char *target;

TimeMSDE2BStr:
	move.l	8(sp),a1		;&target
	addq.l	#1,a1			;room for length byte
	move.l	4(sp),a0		;&MSDirEntry
	move.w	MSDE_CDate(a0),d0
	beq.s	tm2b_adate		;no creation date

	move.l	UIText+7*4(a4),a0
tm2b_t1:
	move.b	(a0)+,(a1)+
	bne.s	tm2b_t1

	move.b	#' ',-1(a1)
	bsr.w	MSDate2Str
	move.b	#' ',(a1)+
	move.l	4(sp),a0
	move.w	MSDE_CTime(a0),d1
	rol.w	#5,d1
	moveq.l	#$1f,d0
	and.w	d1,d0
	bsr.s	Num2Str2		;h
	move.b	#':',(a1)+
	rol.w	#6,d1
	moveq.l	#$3f,d0
	and.w	d1,d0
	bsr.s	Num2Str2		;m
	move.b	#':',(a1)+
	rol.w	#6,d1
	moveq.l	#$3e,d0
	and.w	d1,d0
	cmp.b	#100,MSDE_CMilSecs(a0)
	bcs.s	tm2b_1

	addq.w	#1,d0
tm2b_1:
	bsr.s	Num2Str2		;s
	move.w	MSDE_ADate(a0),d1
	beq.s	tm2b_end		;no..

	move.b	#',',(a1)+
	move.b	#' ',(a1)+
	bra.s	tm2b_t2
tm2b_adate:
	move.w	MSDE_ADate(a0),d1
	beq.s	tm2b_end		;..read date
tm2b_t2:
	move.l	UIText+8*4(a4),a0
tm2b_t3:
	move.b	(a0)+,(a1)+
	bne.s	tm2b_t3

	move.b	#' ',-1(a1)
	move.w	d1,d0
	bsr.s	MSDate2Str
tm2b_end:
	clr.b	(a1)
	move.l	8(sp),a0
	move.l	a1,d0
	sub.l	a0,d0
	subq.l	#1,d0
	move.b	d0,(a0)			;BStr length
	rts

;--- # -> 2 char string ------------------------------------
; d0 <-  #
; a1 <-> &string

Num2Str2:
	divu.w	#10,d0
	or.l	#'0'<<16+'0',d0
	move.b	d0,(a1)+
	swap	d0
	move.b	d0,(a1)+
	rts

;--- MS date -> string -------------------------------------
; d0 <-  MS date
; a1 <-> &string

MSDate2Str:
	move.w	d0,d1
	moveq.l	#$1f,d0
	and.w	d1,d0
	bsr.s	Num2Str2		;day
	move.b	#'.',(a1)+
	ror.w	#5,d1
	moveq.l	#$f,d0
	and.w	d1,d0
	bsr.s	Num2Str2		;month
	move.b	#'.',(a1)+
	ror.w	#4,d1
	moveq.l	#$7f,d0
	and.w	d1,d0
	add.w	#1980,d0
	move.l	d0,d1
	divu.w	#100,d1
	move.w	d1,d0
	bsr.s	Num2Str2		;year
	moveq.l	#0,d0
	swap	d1
	move.w	d1,d0
	bsr.s	Num2Str2		;year part 2
	rts

;--- write standard dir entry ------------------------------
; a0 <- &XMSDE

WriteMSDE:
	move.l	a2,-(sp)
	move.l	a0,a2			;&XMSDE
	move.l	XMSDE_Key(a2),d0
	beq.s	wms_end

	bsr.w	ReadDirBlock
	tst.l	d0
	beq.s	wms_end

	bsr.w	BlockChanged
	move.l	a2,a0
	move.l	d0,a1
	add.w	XMSDE_Offset(a2),a1
	bsr.w	RCopyMSDE
wms_end:
	move.l	(sp)+,a2
	rts

;--- relocate XMSDE on Disk --------------------------------
; <- struct ExtMSDirEntry *Eintrag, struct DiskKey *target;

MoveXMSDE:
	link.w	a5,#0
	movem.l	d2-d5/a2-a3,-(sp)
	move.l	8(a5),a2		;&ExtMSDirEntry
	move.w	XMSDE_ExtOffset(a2),d3	;source Offset
	move.l	XMSDE_ExtKey(a2),d2	;source Block #
	bne.s	mxms_1

	move.w	XMSDE_Offset(a2),d3
	move.l	XMSDE_Key(a2),d2	;just the standard entry
mxms_1:
	move.l	12(a5),a0
	move.l	(a0)+,d4		;target Block #
	move.w	(a0),d5			;target Offset
	cmp.w	d3,d5
	bne.s	mxms_2

	cmp.l	d2,d4
	beq.w	mxms_skip		;already there
mxms_2:
	move.l	d2,d0
	beq.w	mxms_end

	bsr.w	ReadDirBlock
	move.l	d0,a2
	tst.l	d0
	beq.w	mxms_end

	bsr.w	BlockChanged
	add.w	d3,a2			;&source
mxms_block:
	move.l	d4,d0
	beq.w	mxms_end

	bsr.w	ReadDirBlock
	move.l	d0,a3
	tst.l	d0
	beq.w	mxms_end

	bsr.w	BlockChanged
	add.w	d5,a3			;&target
mxms_entry:
	moveq.l	#MSDE_Sizeof/8,d0
mxms_eloop:
	move.l	(a2)+,(a3)+		;move 1 entry
	move.l	(a2)+,(a3)+
	subq.w	#1,d0
	bgt.s	mxms_eloop

	move.b	#MSDEB_DELETED,-MSDE_Sizeof(a2)	;free old entry
	move.l	8(a5),a0
	cmp.w	XMSDE_Offset(a0),d3
	bne.s	mxms_3

	cmp.l	XMSDE_Key(a0),d2
	beq.s	mxms_ready		;all done
mxms_3:
	add.w	#MSDE_Sizeof,d3
	cmp.w	BlockSize(a4),d3
	bcs.s	mxms_4			;source: go on in same..

	moveq.l	#0,d3
	move.l	d2,d0
	bsr.w	NextBlock
	move.l	d0,d2
	beq.w	mxms_end

	bsr.w	ReadDirBlock
	move.l	d0,a2			;..or next block
	tst.l	d0
	beq.w	mxms_end

	bsr.w	BlockChanged
mxms_4:
	add.w	#MSDE_Sizeof,d5
	cmp.w	BlockSize(a4),d5
	bcs.s	mxms_entry		;target: go on in same..

	moveq.l	#0,d5
	move.l	d4,d0
	bsr.w	NextBlock
	move.l	d0,d4
	bra.s	mxms_block		;..or next block

mxms_skip:
	move.l	XMSDE_Key(a2),d4
	move.w	XMSDE_Offset(a2),d5
	bra.s	mxms_cont

mxms_ready:
	move.l	8(a5),a2		;&XMSDE
	move.l	XMSDE_Key(a2),d2
	move.w	XMSDE_Offset(a2),d3	;old position
	move.l	d4,XMSDE_Key(a2)
	move.w	d5,XMSDE_Offset(a2)	;new position
	tst.l	XMSDE_ExtKey(a2)
	beq.s	mxms_5

	move.l	12(a5),a0
	move.l	(a0)+,XMSDE_ExtKey(a2)
	move.w	(a0),XMSDE_ExtOffset(a2) ;extension new position
mxms_5:
	move.l	VolumeNode(a4),a0
	add.w	#XDOL_XLockList,a0
mxms_lockloop:
	move.l	(a0),a0
	tst.l	(a0)
	beq.s	mxms_cont		;if present,..

	cmp.l	XL_Key(a0),d2		;..do correct open XLock..
	bne.s	mxms_lockloop

	cmp.w	XL_Offset(a0),d3	;..on this..
	bne.s	mxms_lockloop

	add.w	#XMSDE_Key,a2
	add.w	#XL_Key,a0
	move.l	(a2)+,(a0)+
	move.l	(a2)+,(a0)+
	move.l	(a2),(a0)		;..entry
mxms_cont:
	add.w	#MSDE_Sizeof,d5
	cmp.w	BlockSize(a4),d5
	bcs.s	mxms_6			;export new pos in same..

	moveq.l	#0,d5
	move.l	d4,d0
	bsr.w	NextBlock
	move.l	d0,d4			;..or next Block
mxms_6:
	move.l	12(a5),a0
	move.l	d4,(a0)+
	move.w	d5,(a0)
mxms_end:
	movem.l	(sp)+,d2-d5/a2-a3
	unlk	a5
	rts

;--- write (extended) dir entry ----------------------------
; a0 <- &Xlock

DeleteXLock:
	add.w	#XL_MSDE,a0		;&XMSDE
	move.b	#MSDEB_DELETED,(a0)
	clr.l	-(sp)
	move.l	a0,-(sp)
	bsr.s	WriteXMSDE
	addq.l	#8,sp
	rts

; <- struct ExtMSDirEntry *entry, struct DiskKey *next entry or 0;

WriteXMSDE:
	movem.l	d2-d5/a2-a3,-(sp)
	move.l	28(sp),a3		;&source
	move.l	XMSDE_ExtKey(a3),d2
	beq.s	wxms_standard

	move.l	a3,a0			;&MSDE_Name
	move.b	(a0)+,d0
	moveq.l	#5,d1
wxms_checksum:
	ror.b	#1,d0
	add.b	(a0)+,d0
	ror.b	#1,d0
	add.b	(a0)+,d0		;checksum for extended entries
	subq.w	#1,d1
	bgt.s	wxms_checksum

	move.b	d0,XMSDE_FNCheck(a3)
	moveq.l	#$40,d4
	or.b	XMSDE_ExtNum(a3),d4	;# extensions + start flag
	move.w	XMSDE_ExtOffset(a3),d3
	bra.s	wxms_block

wxms_standard:
	moveq.l	#0,d4
	move.l	XMSDE_Key(a3),d2
	move.w	XMSDE_Offset(a3),d3

wxms_block:
	move.l	d2,d0
	beq.w	wxms_end

	bsr.w	ReadDirBlock
	tst.l	d0
	beq.w	wxms_end

	move.l	d0,a2			;&DiskBlock
	add.w	d3,a2			;&MSDirEntry
	bsr.w	BlockChanged
wxms_next:
	tst.w	d4
	beq.w	wxms_norm		;standard entry last

	cmp.b	#MSDEB_DELETED,(a3)
	beq.w	wxms_deleted

	move.b	d4,(a2)			;ext #
	and.w	#$1f,d4			;reset start flag $40
	move.b	#$0f,MSDE_Flags(a2)	;ID
	clr.b	MSDE_unused1(a2)
	move.b	XMSDE_FNCheck(a3),MSDE_CheckSum(a2)
	clr.w	MSDE_1L(a2)		;no Cluster chain
	lea	XMSDE_FullName(a3),a0
	move.w	d4,d0
	subq.w	#1,d0
	mulu.w	#13,d0
	add.w	d0,a0			;&source Name portion
	move.l	#$f1f98000,d5
	moveq.l	#-1,d1
	lea	1(a2),a1
	move.l	CodePage(a4),d0
	bne.s	wxms_uwrite
wxms_cwrite1:
	clr.b	1(a1)
	move.b	(a0)+,(a1)+		;write UTF16 char
	beq.s	wxms_cskip2
wxms_cskip1:
	addq.l	#1,a1
	lsl.l	#1,d5
	bcs.s	wxms_cwrite1
	bne.s	wxms_cskip1
	bra.s	wxms_bready
wxms_cwrite2:
	move.b	d1,(a1)+
	move.b	d1,(a1)			;$ffff pad
wxms_cskip2:
	addq.l	#1,a1
	lsl.l	#1,d5
	bcs.s	wxms_cwrite2
	bne.s	wxms_cskip2
	bra.s	wxms_bready

wxms_uwrite:
	move.l	d0,a6			;&forward table
wxms_uchar:
	moveq.l	#0,d0
	moveq.l	#0,d1
	move.b	(a0)+,d1
	beq.s	wxms_uput

	lsl.w	#1,d1
	move.b	(a6,d1.l),d0
	move.b	1(a6,d1.l),d1
wxms_uput:
	move.b	d1,(a1)+
	move.b	d0,(a1)			;write Unicode char
	or.b	d1,d0
	moveq.l	#-1,d1
	tst.b	d0
	beq.s	wxms_cskip2
wxms_uskip:
	addq.l	#1,a1
	lsl.l	#1,d5
	bcs.s	wxms_uchar
	bne.s	wxms_uskip
	bra.s	wxms_bready

wxms_deleted:
	and.w	#$1f,d4			;reset Start Flag $40
	move.b	#MSDEB_DELETED,(a2)	;delete exts together with..
	bra.s	wxms_bready		;..standard entry

wxms_norm:
	move.l	d2,XMSDE_Key(a3)
	move.w	d3,XMSDE_Offset(a3)	;remember standard entry pos
	move.l	a3,a0			;copy..
	move.l	a2,a1
	bsr.w	RCopyMSDE		;..Standard entry last

wxms_bready:
	add.w	#MSDE_Sizeof,a2
	bsr.w	NextMSDE
	subq.w	#1,d4
	bmi.s	wxms_update

	tst.w	d3
	bne.w	wxms_next		;on in same Disk Block
wxms_update:
	tst.w	d4
	bpl.w	wxms_block
wxms_end:
	move.l	32(sp),d0
	beq.s	wxms_exit		;nobody wanted to know...

	move.l	d0,a0
	move.l	d2,(a0)+
	move.w	d3,(a0)
wxms_exit:
	movem.l	(sp)+,d2-d5/a2-a3
	rts

;--- read (extended) dir entry -----------------------------
; <- struct DiskKey *location, struct ExtMSDirEntry *target;
; -> BOOL ok;

ReadXMSDE:
	movem.l	d2-d5/a2-a3,-(sp)
	move.l	32(sp),a3		;&target
	move.l	28(sp),a0		;&DiskKey
	move.l	(a0)+,d2
	move.w	(a0),d3			;old position
	clr.l	XMSDE_ExtKey(a3)
	clr.w	XMSDE_FNLength(a3)	;including XMSDE_FullName[0]
	moveq.l	#-1,d4			;"nothing found yet"
rxms_loop:
	move.l	d2,d0
	beq.w	rxms_error		;end of dir

	bsr.w	ReadDirBlock
	tst.l	d0
	beq.w	rxms_error

	move.l	d0,a2			;&Block
	add.w	d3,a2			;&MSDirEntry
rxms_next:
	move.b	(a2),d0
	beq.w	rxms_normal		;an unused,..

	cmp.b	#MSDEB_DELETED,d0
	beq.w	rxms_normal		;..deleted or..

	moveq.l	#$3f,d1
	and.b	MSDE_Flags(a2),d1
	cmp.b	#$0f,d1
	bne.w	rxms_normal		;..standard entry

;- - an extended entry - - - - - - - - - - - - - - - - - - -

;rxms_extended:
	btst	#6,d0
	beq.s	rxms_xcont		;continued extension

	tst.w	d4
	bpl.w	rxms_normal		;2 start entries??

	moveq.l	#$1f,d4
	and.b	d0,d4
	move.b	d4,XMSDE_ExtNum(a3)	;start index,..
	move.l	d2,XMSDE_ExtKey(a3)
	move.w	d3,XMSDE_ExtOffset(a3)	;..start ext and..
	move.b	MSDE_CheckSum(a2),XMSDE_FNCheck(a3) ;..checksum
	bra.s	rxms_xread
rxms_xcont:
	subq.w	#1,d4
	cmp.b	d0,d4
	bne.w	rxms_normal		;wrong continuation index

	move.b	MSDE_CheckSum(a2),d0
	cmp.b	XMSDE_FNCheck(a3),d0
	bne.w	rxms_normal		;wrong continuation checksum
rxms_xread:
	move.w	d4,d0
	subq.w	#1,d0
	bmi.w	rxms_normal		;invalid index

	cmp.b	#(XMSDE_Sizeof-XMSDE_FullName)/13,d0
	bcc.s	rxms_xnext		;Name too long for struct ExtMSDirEntry

	mulu.w	#13,d0
	lea	XMSDE_FullName(a3),a1
	add.l	d0,a1			;&target Name portion
	move.l	#$f1f98000,d5
	lea	1(a2),a0
	move.l	InvCodePage(a4),d0
	bne.s	rxms_uread
rxms_xcread:
	move.b	(a0)+,(a1)+		;read long Name
	beq.s	rxms_xcstop
rxms_xcskip:
	addq.l	#1,a0
	lsl.l	#1,d5
	bcs.s	rxms_xcread
	bne.s	rxms_xcskip
rxms_xcdone:
	tst.l	d4			;if Name length is a multiple of 13..
	bmi.s	rxms_xnext

	clr.b	(a1)+			;..add string termination
rxms_xcstop:
	moveq.l	#-XMSDE_FullName-1,d0
	add.l	a1,d0
	sub.l	a3,d0
	move.b	d0,XMSDE_FNLength(a3)	;BStr length
	bset	#31,d4			;"Name end marked"
rxms_xnext:
	add.w	#MSDE_Sizeof,a2
	bsr.w	NextMSDE
	tst.w	d3
	bne.w	rxms_next		;on in same..
	bra.w	rxms_loop		;..or next Block

;- - an extended entry with UTF decoding - - - - - - - - - -

rxms_uread:
	move.l	d0,a6			;&reverse table
rxms_uchar:
	move.b	(a0)+,d1
	move.b	(a0),d0
	or.b	d1,d0
	beq.s	rxms_uwrite

	moveq.l	#0,d0
	move.b	(a0),d0
	move.b	(a6,d0.l),d0
	beq.s	rxms_udummy

	lsl.w	#8,d0
	move.b	d1,d0
	move.b	(a6,d0.l),d0
	bra.s	rxms_uwrite
rxms_udummy:
	moveq.l	#'_',d0
rxms_uwrite:
	move.b	d0,(a1)+
	beq.s	rxms_xcstop
rxms_uskip:
	addq.l	#1,a0
	lsl.l	#1,d5
	bcs.s	rxms_uchar
	bne.s	rxms_uskip
	bra.s	rxms_xcdone

;- - a standard entry  - - - - - - - - - - - - - - - - - - -

rxms_normal:
	move.l	d2,XMSDE_Key(a3)
	move.w	d3,XMSDE_Offset(a3)
	move.l	a2,a0			;copy..
	move.l	a3,a1
	bsr.w	RCopyMSDE		;..standard entry

	addq.w	#1,d4
	beq.s	rxms_ok			;thats already it

	subq.w	#2,d4
	bne.s	rxms_delete		;faulty extended sequence

	move.l	a3,a0			;&MSDE_Name
	move.b	(a0)+,d0
	moveq.l	#5,d1
rxms_checksum:
	ror.b	#1,d0
	add.b	(a0)+,d0
	ror.b	#1,d0
	add.b	(a0)+,d0		;checksum..
	subq.w	#1,d1
	bgt.s	rxms_checksum

	cmp.b	XMSDE_FNCheck(a3),d0
	beq.s	rxms_ok			;..fits standard Name
rxms_delete:
	move.l	28(sp),a0		;&DiskKey
	move.l	(a0)+,d2		;error: return to old position..
	move.w	(a0),d3
	clr.l	XMSDE_ExtKey(a3)	;..and treat like..
	move.b	#MSDEB_DELETED,(a3)	;..deleted
rxms_ok:
	bsr.s	NextMSDE
	moveq.l	#1,d0			;"OK"

rxms_end:
	move.l	28(sp),a0		;&DiskKey
	move.l	d2,(a0)+
	move.w	d3,(a0)			;new position
	movem.l	(sp)+,d2-d5/a2-a3
	rts

rxms_error:
	moveq.l	#0,d0
	bra.s	rxms_end

;--- go to next dir entry ----------------------------------
; !ATTENTION!
; d2 <-> ULONG Block #
; d3 <-> UWORD Offset

NextMSDE:
	add.w	#MSDE_Sizeof,d3
	cmp.w	BlockSize(a4),d3
	bcs.s	nms_end			;same Block

	moveq.l	#0,d3			;go to beginning..
	move.l	d2,d0
	bsr.w	NextBlock		;..of next Block
	move.l	d0,d2
nms_end:
	rts

;--- enarge dir --------------------------------------------
; <- struct XLock *dir;
; -> ULONG new Block # or 0;

EXD_NEWCLU	= -4
EXD_CLUSTER	= -8
EXD_NEWBLOCK	= -12
EXD_BLOCK	= -16
EXD_BCOUNT	= -17

ExtendDir:
	link.w	a5,#-20
	move.l	a2,-(sp)
	move.l	8(a5),a0		;&XLock
	move.l	RootCluster(a4),d0
	tst.l	XL_Parent(a0)
	beq.s	xtd_2			;special case: FAT32 root dir

	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	xtd_1

	move.w	XL_MSDE+MSDE_1H(a0),d0
	swap	d0
xtd_1:
	move.w	XL_MSDE+MSDE_1L(a0),d0
xtd_2:
	move.l	d0,EXD_CLUSTER(a5)	;Start cluster #
	bsr.w	ExtendChain
	move.l	d0,EXD_NEWCLU(a5)	;new Cluster #
	bmi.s	xtd_error		;no free Clusters

	bsr.w	Cluster2Block		;of new Cluster..
	move.l	d0,EXD_NEWBLOCK(a5)	;first new Block #
	move.l	d0,EXD_BLOCK(a5)
	move.b	BlocksPerCluster(a4),EXD_BCOUNT(a5) ;..all blocks..
xtd_loop:
	move.l	EXD_BLOCK(a5),d0
	moveq.l	#RB_DIRNEW,d1
	bsr.w	ReadBlocks
	tst.l	d0
	beq.s	xtd_nomem

	move.l	d0,a2			;&Block contents
	bsr.w	BlockChanged
	move.l	a2,a0
	move.w	BlockSize(a4),d1
xtd_clear:
	clr.l	(a0)+
	clr.l	(a0)+			;..zero filled
	subq.w	#8,d1
	bgt.s	xtd_clear

	tst.l	EXD_CLUSTER(a5)
	beq.s	xtd_init		;1. Block of new dir
xtd_write:
	addq.l	#1,EXD_BLOCK(a5)
	subq.b	#1,EXD_BCOUNT(a5)
	bgt.s	xtd_loop

	move.l	EXD_NEWBLOCK(a5),d0	;success!!
xtd_end:
	move.l	(sp)+,a2
	unlk	a5
	rts

xtd_nomem:
	move.w	#103,ErrorNum(a4)
xtd_error:
	moveq.l	#0,d0
	bra.s	xtd_end

xtd_init:
	move.l	8(a5),a0		;&XLock
	tst.w	FATType(a4)
	bpl.s	xtd_i1

	move.w	EXD_NEWCLU(a5),XL_MSDE+MSDE_1H(a0)
xtd_i1:
	move.w	EXD_NEWCLU+2(a5),XL_MSDE+MSDE_1L(a0) ;new Cluster = Start
	move.l	a2,a1
	bsr.s	MakeIntRef		;copy of dir descriptor..
	move.b	#'.',(a2)		;..as self link
	move.l	8(a5),a0
	move.l	XL_Parent(a0),d0
	beq.s	xtd_i2			;no higher than root

	move.l	d0,a0			;of &XLock of parent dir..
xtd_i2:
	lea	MSDE_Sizeof(a2),a1
	bsr.s	MakeIntRef		;..copy dir descriptor..
	move.w	#"..",MSDE_Sizeof(a2)	;..as parent link
	moveq.l	#-1,d0
	move.l	d0,EXD_CLUSTER(a5)	;"initialized"
	bra.s	xtd_write

;--- ExtendDir() private: make internal reference ----------
; a0 <- struct XLock *source;
; a1 <- struct MSDirEntry *target;

MakeIntRef:
	add.w	#XL_MSDE+MSDE_unused1,a0
	move.l	#"    ",d0
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.l	d0,(a1)+
	move.b	#$10,-1(a1)		;MSDE_Flags = "dir"
	bra.w	R2CopyMSDE		;copy rest and reverse #s

;--- check free dir space ----------------------------------
; <- struct XLock *dir, struct DiskKey *StartPosition,
;    struct ExtMSDirEntry *needed;
; return value in StartPosition

CheckDirSpace:
	move.l	d2,-(sp)
	move.l	16(sp),a0		;&ExtMSDirEntry
	moveq.l	#1,d2
	tst.l	XMSDE_ExtKey(a0)
	beq.s	cds_demand		;standard entry only

	add.b	XMSDE_ExtNum(a0),d2	;+ ext entries
cds_demand:
	lsl.l	#5,d2			;demand in bytes
	tst.w	FATType(a4)
	bmi.s	cds_subdir		;FAT32: all dirs are extendable

	move.l	8(sp),a0		;&XLock of dir
	tst.l	XL_Parent(a0)
	bne.s	cds_subdir

	move.l	12(sp),a0
	move.l	(a0),d0			;# Start block
	beq.s	cds_rootfull

	move.l	RootDirEnd(a4),d1
	sub.l	d0,d1
	mulu.w	BlockSize(a4),d1
	moveq.l	#0,d0
	move.w	4(a0),d0		;Offset
	sub.l	d0,d1			;free space in root..
	cmp.l	d2,d1
	bcc.s	cds_end			;..suffices
cds_rootfull:
	move.w	#232,ErrorNum(a4)	;fixed length root full
	clr.l	(a0)
	bra.s	cds_end

cds_subdir:
	move.l	12(sp),a0
	move.l	(a0),d0			;# Start block
	beq.s	cds_extend		;subdir full

	moveq.l	#0,d1
	move.w	4(a0),d1
	add.l	d1,d2			;honor Offset
cds_sloop:
	moveq.l	#0,d1
	move.w	BlockSize(a4),d1
	sub.l	d1,d2
	bcs.s	cds_end
	beq.s	cds_end			;as needed..

	bsr.w	NextBlock		;..get follow up blocks
	tst.l	d0
	bne.s	cds_sloop
cds_extend:
	move.l	8(sp),a0
	move.l	a0,-(sp)
	bsr.w	ExtendDir		;enlarge sub dir
	addq.l	#4,sp
	move.l	12(sp),a0
	tst.l	d0
	beq.s	cds_subfull		;no space

	tst.l	(a0)
	bne.s	cds_end

	move.l	d0,(a0)+
	clr.w	(a0)
	bra.s	cds_end
cds_subfull:
	move.w	#221,ErrorNum(a4)	;"Disk full"
	clr.l	(a0)
cds_end:
	move.l	(sp)+,d2
	rts

;--- examine next Object -----------------------------------
; <- struct XLock *dir, struct FileInfoBlock *fib;
; -> BOOL ok;

EXN_DISKKEY	= -8
EXN_MSDEBUF	= -8-XMSDE_Sizeof

ExamineNext:
	link.w	a5,#EXN_MSDEBUF
	movem.l	a2/a3,-(sp)
	lea	EXN_MSDEBUF(a5),a3	;&ExtMSDirEntry
	move.l	12(a5),a2		;&FileInfoBlock
	tst.l	8(a5)
	bne.s	exn_1

	move.l	RootXLock(a4),8(a5)
exn_1:
	move.l	FIB_DiskKey(a2),EXN_DISKKEY(a5)
	move.w	FIB_Private+2(a2),EXN_DISKKEY+4(a5)
	tst.w	FIB_Private(a2)
	bne.s	exn_read		;get next entry

	move.l	8(a5),a0
	moveq.l	#$18,d0
	and.b	XL_MSDE+MSDE_Flags(a0),d0
	beq.s	exn_nodir		;not a dir

	move.w	#1,FIB_Private(a2)	;clear Start flag
	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	exn_2

	move.w	XL_MSDE+MSDE_1H(a0),d0
	swap	d0
exn_2:
	move.w	XL_MSDE+MSDE_1L(a0),d0
	bsr.w	Cluster2Block
	move.l	d0,EXN_DISKKEY(a5)	;Disk Block # of dir
	clr.w	EXN_DISKKEY+4(a5)	;begin at 1. entry
exn_read:
	move.l	a3,-(sp)
	pea	EXN_DISKKEY(a5)
	bsr.w	ReadXMSDE
	addq.w	#8,sp
	tst.w	d0
	beq.s	exn_dirend		;end of chain or read error

	move.b	MSDE_Name(a3),d0
	beq.s	exn_dirend		;unused from here

	cmp.b	#MSDEB_DELETED,d0
	beq.s	exn_read		;skip deleted,..

	cmp.b	#'.',d0
	beq.s	exn_read		;..internal and..

	btst	#3,MSDE_Flags(a3)
	bne.s	exn_read		;..Disk name entries

	move.l	a2,-(sp)
	move.l	a3,-(sp)
	bsr.s	GiveFileInfo
	addq.w	#8,sp
	moveq.l	#TRUE,d0		;"ok"
exn_end:
	move.l	EXN_DISKKEY(a5),FIB_DiskKey(a2)
	move.w	EXN_DISKKEY+4(a5),FIB_Private+2(a2)
	movem.l	(sp)+,a2/a3
	unlk	a5
	rts

exn_nodir:
	move.w	#212,ErrorNum(a4)
	bra.s	exn_error
exn_dirend:
	move.w	#232,ErrorNum(a4)
exn_error:
	clr.l	EXN_DISKKEY(a5)
	moveq.l	#FALSE,d0
	bra.s	exn_end

;--- examine Object ----------------------------------------
; <- struct XLock *Object, struct FileInfoBlock *fib;
; -> BOOL ok;

ExamineKey:
	move.l	4(sp),d0
	bne.s	ekey_1

	move.l	RootXLock(a4),d0
ekey_1:
	move.l	d0,a0			;&XLock
	tst.w	XL_Flags(a0)
	bpl.s	ekey_2

	move.l	a0,-(sp)
	bsr.w	UpdateDir
	move.l	(sp)+,a0
ekey_2:
	move.l	8(sp),a1		;&FileInfoBlock
	move.l	XL_Key(a0),FIB_DiskKey(a1)
	move.w	XL_Offset(a0),FIB_Private+2(a1)
	clr.w	FIB_Private(a1)		;ExamineNext() start flag
	move.l	a1,-(sp)
	pea	XL_MSDE(a0)
	bsr.s	GiveFileInfo
	addq.w	#8,sp
	moveq.l	#TRUE,d0
	rts

;--- fill in File Info Block -------------------------------
; <- struct ExtMSDirEntry *xmsde, struct FileInfoBlock *target

GiveFileInfo:
	movem.l	a2-a3,-(sp)
	movem.l	12(sp),a2-a3		;&ExtMSDirEntry, &FileInfoBlock

;- - name  - - - - - - - - - - - - - - - - - - - - - - - - -

	move.l	a2,a0
	lea	FIB_Name(a3),a1
	bsr.w	GetBName

;- - type  - - - - - - - - - - - - - - - - - - - - - - - - -

	move.b	MSDE_Flags(a2),d0
	moveq.l	#1,d1
	btst	#3,d0
	bne.s	gfi_1			;root dir = 1

	moveq.l	#2,d1
	btst	#4,d0
	bne.s	gfi_1			;sub dir = 2

	moveq.l	#-3,d1			;file = -3
gfi_1:
	move.l	d1,FIB_DirEntryType(a3)
	move.l	d1,FIB_EntryType(a3)	;for buggy applications

;- - protection bits - - - - - - - - - - - - - - - - - - - -

	moveq.l	#0,d1
	lsr.b	#1,d0			;"read only"..
	bcc.s	gfi_2

	moveq.l	#5,d1			;..-> no writing or deleting
gfi_2:
	lsr.b	#1,d0			;"hidden"
	bcc.s	gfi_3

	or.b	#$80,d1
gfi_3:
	lsr.b	#1,d0			;"system"..
	bcc.s	gfi_4

	or.b	#$20,d1			;..-> "pure"
gfi_4:
	lsr.b	#3,d0			;not "changed"..
	bcs.s	gfi_5

	or.b	#$10,d1			;..-> "Archive"
gfi_5:
	move.l	d1,FIB_Protection(a3)

;- - size  - - - - - - - - - - - - - - - - - - - - - - - - -

	move.l	MSDE_FSize(a2),d0
	move.l	d0,FIB_Size(a3)		;length in Bytes

	add.l	BlockMask(a4),d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0			;# blocks..
	moveq.l	#0,d1
	move.b	BlocksPerCluster(a4),d1	;..rounded up to whole Clusters..
	subq.l	#1,d1
	add.l	d1,d0
	not.l	d1
	and.l	d1,d0
	move.l	d0,FIB_NumBlocks(a3)	;..= used blocks

;- - date, time  - - - - - - - - - - - - - - - - - - - - - -

	move.l	MSDE_Time(a2),d0
	lea	FIB_Date(a3),a1
	bsr.w	Date2Dos		;last changed

	btst	#0,CmdFlags(a4)
	beq.s	gfi_nocomment

	pea	FIB_Comment(a3)
	move.l	a2,-(sp)		;extra timestamps..
	bsr.w	TimeMSDE2BStr		;..as comment..
	addq.l	#8,sp
	bra.s	gfi_end
gfi_nocomment:
	clr.w	FIB_Comment(a3)		;..or not
gfi_end:
	movem.l	(sp)+,a2-a3
	rts

;--- examine whole dir -------------------------------------
; <- struct XLock *dir, struct ExAllData *target buffer, ULONG buffer size,
;    ULONG type, struct ExAllControl *parameters;
; -> BOOL continue;

EXA_STRUCTSIZE	= -2
EXA_DISKKEY	= -8
EXA_LASTKEY	= -16
EXA_LASTENTRY	= -20
EXA_MSDEBUF	= -20-XMSDE_Sizeof

ExamineAll:
	link.w	a5,#EXA_MSDEBUF
	movem.l	d2-d4/a2-a3,-(sp)

;- - preparation - - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#0,d3			;# entries
	move.l	20(a5),d4		;type
	subq.l	#1,d4
	moveq.l	#7,d1
	cmp.l	d1,d4
	bcc.w	exa_badtype

	lea	exa_sizes(pc),a0
	add.w	d4,a0
	moveq.l	#0,d0
	move.b	(a0),d0
	move.w	d0,EXA_STRUCTSIZE(a5)	;size per ExAllData
	move.l	8(a5),a0		;&XLock
	moveq.l	#$18,d0
	and.b	XL_MSDE+MSDE_Flags(a0),d0
	beq.w	exa_nodir		;not a dir

	move.l	24(a5),a1		;&ExAllControl
	move.l	EAC_LastKey(a1),d0
	beq.s	exa_new			;restart..

	move.l	d0,d1
	lsl.l	#5,d1			;*= MSDE_Sizeof
	and.l	BlockMask(a4),d1
	move.w	BlockShift(a4),d2
	subq.w	#5,d2
	lsr.l	d2,d0			;..or resume previous invocation
	clr.l	EAC_LastKey(a1)
	bra.s	exa_start
exa_new:
	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	exa_1

	move.w	XL_MSDE+MSDE_1H(a0),d0
	swap	d0
exa_1:
	move.w	XL_MSDE+MSDE_1L(a0),d0
	bsr.w	Cluster2Block
	moveq.l	#0,d1			;begin at 1. entry
exa_start:
	move.l	d0,EXA_DISKKEY(a5)
	move.w	d1,EXA_DISKKEY+4(a5)
	move.l	12(a5),a2		;&target
	move.l	16(a5),d2		;space remaining
	clr.l	EXA_LASTENTRY(a5)

;- - read entry  - - - - - - - - - - - - - - - - - - - - - -

exa_entry:
	move.l	EXA_DISKKEY(a5),EXA_LASTKEY(a5)
	move.w	EXA_DISKKEY+4(a5),EXA_LASTKEY+4(a5)
	pea	EXA_MSDEBUF(a5)
	pea	EXA_DISKKEY(a5)
	bsr.w	ReadXMSDE
	addq.w	#8,sp
	tst.w	d0
	beq.w	exa_dirend		;read error

	lea	EXA_MSDEBUF(a5),a0
	move.b	(a0),d0
	beq.w	exa_dirend		;all done!!

	cmp.b	#MSDEB_DELETED,d0
	beq.s	exa_entry		;skip deleted,..

	cmp.b	#'.',d0
	beq.s	exa_entry		;..internal and..

	btst	#3,MSDE_Flags(a0)
	bne.s	exa_entry		;..Disk name entries

	moveq.l	#0,d0
	move.w	EXA_STRUCTSIZE(a5),d0
	sub.l	d0,d2
	bcs.w	exa_overrun		;no space for ExAllData

	clr.l	(a2)			;ED_Next
	move.l	a2,a3
	add.w	d0,a3			;&target for Strings

;- - Name - - - - - - - - - - - - - - - - - - - - - - - - -

	moveq.l	#0,d0
	move.b	XMSDE_FNLength(a0),d0
	bne.s	exa_2

	moveq.l	#12,d0			;max short name size
exa_2:
	addq.l	#2+3,d0
	and.w	#-4,d0			;longword aligned
	sub.l	d0,d2
	bcs.w	exa_overrun		;no room for Name

	move.l	a3,d1
	addq.l	#1,d1
	move.l	d1,ED_Name(a2)
	move.l	a3,a1
	add.l	d0,a3
	bsr.w	GetBName
	tst.w	d4
	beq.w	exa_match

;- - Type  - - - - - - - - - - - - - - - - - - - - - - - - -

	move.b	EXA_MSDEBUF+MSDE_Flags(a5),d0
	moveq.l	#2,d1
	btst	#4,d0
	bne.s	exa_3			;sub dir = 2

	moveq.l	#-3,d1			;file = -3
exa_3:
	move.l	d1,ED_Type(a2)
	cmp.w	#2,d4
	bcs.s	exa_match

;- - file length - - - - - - - - - - - - - - - - - - - - - -

	move.l	EXA_MSDEBUF+MSDE_FSize(a5),ED_Size(a2)
	cmp.w	#3,d4
	bcs.s	exa_match

;- - protection bits - - - - - - - - - - - - - - - - - - - -

	moveq.l	#0,d1
	lsr.b	#1,d0			;"read only"..
	bcc.s	exa_4

	moveq.l	#5,d1			;..-> no writing and deleting
exa_4:
	lsr.b	#1,d0			;"hidden"
	bcc.s	exa_5

	or.b	#$80,d1
exa_5:
	lsr.b	#1,d0			;"system"..
	bcc.s	exa_6

	or.b	#$20,d1			;..-> "pure"
exa_6:
	lsr.b	#3,d0			;not "changed"..
	bcs.s	exa_7

	or.b	#$10,d1			;..-> "Archive"
exa_7:
	move.l	d1,ED_Prot(a2)
	cmp.w	#4,d4
	bcs.s	exa_match

;- - date and time - - - - - - - - - - - - - - - - - - - - -

	move.l	EXA_MSDEBUF+MSDE_Time(a5),d0
	lea	ED_Days(a2),a1
	bsr.w	Date2Dos		;"last changed"
	cmp.w	#5,d4
	bcs.s	exa_match

;- - extra time stamps as comment  - - - - - - - - - - - - -

	btst	#0,CmdFlags(a4)
	beq.s	exa_nocomment

	moveq.l	#60,d0
	sub.l	d0,d2
	bcs.w	exa_overrun		;no room

	move.l	a3,d1
	addq.l	#1,d1
	move.l	d1,ED_Comment(a2)
	move.l	a3,-(sp)
	add.l	d0,a3
	pea	EXA_MSDEBUF(a5)
	bsr.w	TimeMSDE2BStr
	addq.l	#8,sp
	bra.s	exa_8
exa_nocomment:
	clr.l	ED_Comment(a2)
exa_8:
	cmp.w	#6,d4
	bcs.s	exa_match

;- - owner Info  - - - - - - - - - - - - - - - - - - - - - -

	clr.l	ED_OwnerUID(a2)

;- - entry complete  - - - - - - - - - - - - - - - - - - - -

exa_match:
	move.l	24(a5),a1		;&ExAllControl
	move.l	EAC_MatchString(a1),d1
	beq.s	exa_hook		;no slection pattern

	move.l	d2,-(sp)
	move.l	ED_Name(a2),d2
	CALLDOS	MatchPatternNoCase
	move.l	(sp)+,d2
	tst.l	d0
	beq.w	exa_entry		;Name mismatch, skip

	move.l	24(a5),a1		;&ExAllControl
exa_hook:
	move.l	EAC_MatchFunc(a1),d1
	beq.s	exa_next		;no hook

	move.l	d1,a0			;&Hook
	move.l	H_Entry(a0),d1
	beq.s	exa_next		;hook invalid

	move.l	a2,-(sp)
	move.l	a2,a1			;&ExAllData
	lea	20(a5),a2		;&Type
	move.l	d1,a6
	jsr	(a6)			;hook has..
	move.l	(sp)+,a2
	tst.l	d0
	beq.w	exa_entry		;..disqualified this entry
exa_next:
	addq.l	#1,d3			;1 more
	move.l	EXA_LASTENTRY(a5),d0	;append to..
	beq.s	exa_n1

	move.l	d0,a0
	move.l	a2,(a0)			;..previous item
exa_n1:
	move.l	a2,EXA_LASTENTRY(a5)
	move.l	a3,a2
	bra.w	exa_entry

;- - Return - - - - - - - - - - - - - - - - - - - - - - - -

exa_overrun:				;if buffer full..
	move.l	EXA_LASTKEY(a5),d0
	move.w	BlockShift(a4),d2
	subq.w	#5,d2
	lsl.l	d2,d0
	move.w	EXA_LASTKEY+4(a5),d1
	lsr.w	#5,d1			;/= MSDE_Sizeof
	or.w	d1,d0
	move.l	24(a5),a1		;&ExAllControl
	move.l	d3,(a1)			;EAC_Entries
	move.l	d0,EAC_LastKey(a1)	;..do go on here..
	moveq.l	#TRUE,d0		;..later
	bra.s	exa_end

exa_badtype:
	moveq.l	#115,d1			;invalider ExAllData Type
	bra.s	exa_done
exa_nodir:
	move.w	#212,d1			;"not a dir"
	bra.s	exa_done
exa_dirend:
	move.w	#232,d1			;"all done"
exa_done:
	move.w	d1,ErrorNum(a4)
	move.l	24(a5),a1		;&ExAllControl
	move.l	d3,(a1)			;EAC_Entries
	moveq.l	#FALSE,d0
exa_end:
	movem.l	(sp)+,d2-d4/a2-a3
	unlk	a5
	rts

exa_sizes:
	dc.b	ED_Type, ED_Size, ED_Prot, ED_Days
	dc.b	ED_Comment, ED_OwnerUID, ED_Sizeof
	even

;--- set protection bits -----------------------------------
; <- struct XLock *base dir, BPTR_BSTR Name, ULONG bits;
; -> BOOL ok;

SetProtect:
	link.w	a5,#0
	move.l	a3,-(sp)
	pea	INTERNAL_MODE&EXCLUSIVE_LOCK
	move.l	12(a5),-(sp)
	move.l	8(a5),-(sp)
	bsr.w	LocateObj
	add.w	#12,sp
	tst.l	d0
	beq.s	spr_error		;Object not found

	move.l	d0,a3			;&XLock
	moveq.l	#$ffffffd8,d1
	and.b	XL_MSDE+MSDE_Flags(a3),d1
	move.l	16(a5),d0
	btst	#7,d0			;(undocumented)..
	beq.s	spr_1

	bset	#1,d1			;..= "hidden"
spr_1:
	btst	#5,d0			;"pure"..
	beq.s	spr_2

	bset	#2,d1			;..= "System"
spr_2:
	btst	#4,d0			;"archived"..
	bne.s	spr_3

	bset	#5,d1			;..= "not changed"
spr_3:
	and.w	#5,d0			;"no writing" or "no deleting"..
	beq.s	spr_4

	bset	#0,d1			;..= "read only"
spr_4:
	move.b	d1,XL_MSDE+MSDE_Flags(a3)
	lea	XL_MSDE(a3),a0
	bsr.w	WriteMSDE
	move.l	a3,a1
	bsr.w	CloseXLock
	moveq.l	#TRUE,d0		;"OK"
spr_end:
	move.l	(sp)+,a3
	unlk	a5
	rts

spr_error:
	moveq.l	#FALSE,d0
	bra.s	spr_end

;--- set datestamps ----------------------------------------
; <- struct XLock *xl, LONG mode;
; mode: 0 = read, 1 = write, 2 = Init

TouchXLock:
	link.w	a5,#-DS_Sizeof
	move.l	d2,-(sp)
	pea	-DS_Sizeof(a5)
	bsr.w	_DateStamp
	pea	-DS_Sizeof(a5)
	bsr.w	Date2MS
	addq.l	#8,sp
	swap	d0			;time << 16 + date
	move.l	8(a5),a0		;&XLock
	add.w	#XL_MSDE,a0		;&ExtMSDirEntry
	tst.l	XL_Parent-XL_MSDE(a0)
	beq.s	txl_root		;special case root dir

	move.l	12(a5),d2		;mode
	subq.l	#1,d2
	bmi.s	txl_read
	beq.s	txl_write

	move.l	DS_Ticks-DS_Sizeof(a5),d1
	lsl.l	#1,d1
	divu.w	#200,d1
	swap	d1
	move.b	d1,MSDE_CMilSecs(a0)	;0.00 ~ 1.99 seconds
	move.l	d0,MSDE_CTime(a0)
txl_write:
	or.b	#$20,MSDE_Flags(a0)	;mark changed
	move.l	d0,MSDE_Time(a0)
txl_update:
	move.w	d0,MSDE_ADate(a0)
	tst.l	d2
	bgt.s	txl_all

	bsr.w	WriteMSDE		;write standard entry only
txl_end:
	move.l	(sp)+,d2
	unlk	a5
	rts

txl_read:
	cmp.w	MSDE_ADate(a0),d0
	beq.s	txl_end			;already set

	btst	#1,CmdFlags(a4)
	beq.s	txl_end			;user does not want that

	moveq.l	#ID_VALIDATED,d1
	cmp.l	DiskState(a4),d1
	beq.s	txl_update
	bra.s	txl_end			;read only Disk, no error

txl_all:
	clr.l	-(sp)
	move.l	a0,-(sp)
	bsr.w	WriteXMSDE		;keep long Name
	addq.l	#8,sp
	bra.s	txl_end

txl_root:
	move.l	12(a5),d1		;mode
	subq.l	#1,d1
	bne.s	txl_end

	move.l	d0,MSDE_Time(a0)	;set root date internally only
	bra.s	txl_end

;*** File Allocation Table *********************************
;--- free FAT flags ----------------------------------------

FreeFATFlags:
	move.l	FATFlags(a4),d1
	beq.s	fff_end

	move.l	FATBNum(a4),d0
	addq.l	#7,d0
	lsr.l	#3,d0
	move.l	d1,a1
	CALLEXEC FreeMem
	clr.l	FATFlags(a4)
fff_end:
	rts

;--- new "FAT changed" flags -------------------------------

NewFATFlags:
	bsr.s	FreeFATFlags
	tst.w	FATType(a4)		;this much work..
	ble.s	nff_end			;..only for FAT16

	move.l	FATBNum(a4),d0
	addq.l	#7,d0
	lsr.l	#3,d0
	move.l	#MEMF_CLEAR,d1
	CALLEXEC AllocMem
	move.l	d0,FATFlags(a4)
nff_end:
	rts

;--- read --------------------------------------------------
; -> &FAT or 0;

ReadFAT:
	movem.l	d2-d4/a2,-(sp)
	tst.w	FATType(a4)		;buffer huge 32bit FATs..
	bmi.w	rf_32bit		;..windowed

	move.l	FATBuffer(a4),d0
	bne.s	rf_start

	move.l	BlocksPerFAT(a4),d0
	move.l	d0,FATBNum(a4)
	bsr.s	NewFATFlags
	move.l	FATBNum(a4),d0
	move.w	BlockShift(a4),d1
	lsl.l	d1,d0
	move.l	d0,FATBufSize(a4)
	move.l	BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,FATBuffer(a4)
	bne.s	rf_start
rf_end:
	move.l	FATBuffer(a4),d0
	movem.l	(sp)+,d2-d4/a2
	rts

;- - read - - - - - - - - - - - - - - - - - - - - - - - - -

rf_start:
	move.l	d0,a2			;&target
	bclr	#3,NewFlags+1(a4)
	moveq.l	#0,d0
	move.w	FATStartBlock(a4),d0
	add.l	FirstBlock(a4),d0
	move.l	BlocksPerFAT(a4),d2
	move.l	d2,d1
	move.l	a2,a1
	bsr.w	_Read			;try all at once,..
	cmp.l	d0,d2
	beq.s	rf_ok			;..OK

	move.w	BlockShift(a4),d4
	moveq.l	#0,d2			;Block #
rf_block:
	moveq.l	#0,d3			;FAT # * BlocksPerFAT
rf_fat:
	moveq.l	#0,d0
	move.w	FATStartBlock(a4),d0
	add.l	d2,d0
	add.l	d3,d0
	add.l	FirstBlock(a4),d0
	moveq.l	#1,d1
	move.l	a2,a1
	bsr.w	_Read
	tst.l	d0			;when unreadable..
	bne.s	rf_copy

	move.l	BlocksPerFAT(a4),d0
	add.l	d0,d3			;..try next FAT copy..
	moveq.l	#0,d1
	move.b	NumFATCopies(a4),d1
	UMUL32
	cmp.l	d0,d3
	bcs.s	rf_fat

	moveq.l	#-1,d0			;..or in the worst case..
	move.w	BlockSize(a4),d1
	subq.w	#4,d1
rf_fill:
	move.l	d0,(a2)+		;..assume "everything fulll"
	subq.w	#4,d1
	bcc.s	rf_fill
	bra.s	rf_bnext
rf_copy:
	add.w	BlockSize(a4),a2
rf_bnext:
	addq.l	#1,d2
	cmp.l	BlocksPerFAT(a4),d2
	bcs.s	rf_block

;- - check for Amiga partition  - - - - - - - - - - - - - -

rf_ok:
	tst.w	FATType(a4)
	ble.s	rf_scan			;do this for FAT16 only

	cmp.b	#2,NumFATCopies(a4)	;2. FAT copy for..
	bcs.s	rf_scan			;..consisency check

	moveq.l	#0,d2
	move.w	FATStartBlock(a4),d2
	add.l	BlocksPerFAT(a4),d2	;Block # 2. FAT copy
	move.l	LastCluster(a4),d3
	addq.l	#2-1,d3
	move.w	BlockShift(a4),d1
	subq.w	#1,d1
	lsr.l	d1,d3			;# whole FAT blocks
	move.l	FATBuffer(a4),a2
rf_aloop:
	move.l	(a2),d0
	clr.b	d0
	cmp.l	#"DOS"<<8,d0
	beq.s	rf_acheck

	cmp.l	#"PFS"<<8,d0
	beq.s	rf_acheck		;these IDs..
rf_anext:
	add.w	BlockSize(a4),a2
	addq.l	#1,d2
	subq.l	#1,d3
	bgt.s	rf_aloop
	bra.s	rf_scan

rf_acheck:
	move.l	d2,d0
	bsr.w	ReadSingle
	tst.l	d0
	beq.s	rf_anext

	move.l	d0,a1
	move.l	a2,a0
	move.w	BlockSize(a4),d1
	lsr.w	#2,d1
rf_acloop:
	move.l	(a0)+,d0		;..could be..
	cmp.l	(a1)+,d0		;..valid FAT entries
	bne.s	rf_abreak

	subq.w	#1,d1
	bgt.s	rf_acloop
	bra.s	rf_anext

rf_abreak:
	bsr.w	FreeFATBuf
	bra.w	rf_end

;- - count free clusters  - - - - - - - - - - - - - - - - -

rf_scan:
	move.l	LastCluster(a4),d2
	moveq.l	#0,d3
	moveq.l	#0,d4
rf_count:
	move.l	d2,d0
	bsr.w	GetFATEntry		;scan FAT..
	tst.l	d0
	bne.s	rf_cnext

	addq.l	#1,d3			;..and count free Clusters
	move.l	d2,d4			;the first free Cluster
rf_cnext:
	subq.l	#1,d2
	moveq.l	#2,d0
	cmp.l	d0,d2
	bcc.s	rf_count

	move.l	d3,FreeClusters(a4)
	move.l	d4,NextFreeCluster(a4)
	bra.w	rf_end

;- - prepare FAT32 background reading - - - - - - - - - -

rf_32bit:
	move.l	FATBuffer(a4),d0
	bne.s	rf_32init

	move.l	#8*F32B_Sizeof,d0	;8 Segments of 16 kbyte each
	move.l	d0,FATBufSize(a4)
	move.l	BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,FATBuffer(a4)
	beq.w	rf_end
rf_32init:
	move.l	d0,a2
	lea	FAT32List(a4),a0
	bsr.w	InitList
	move.l	#F32B_Sizeof-F32B_Data,d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0
	move.l	d0,FATBNum(a4)
	moveq.l	#8,d2
rf_32iloop:
	lea	FAT32List(a4),a0
	move.l	a2,a1
	bsr.w	MyAddHead		;add Segments to list
	moveq.l	#-1,d0
	move.l	d0,F32B_Start(a2)	;"empty"
	clr.l	F32B_Flags(a2)
	add.w	#F32B_Sizeof,a2
	subq.w	#1,d2
	bgt.s	rf_32iloop

	moveq.l	#ID_VALIDATING,d0
	move.l	d0,DiskState(a4)	;do scan huge 32bit FAT..
	clr.l	FreeClusters(a4)
	clr.l	NextFreeCluster(a4)
	clr.l	BackgroundData(a4)
	lea	ScanFAT32(pc),a0
	move.l	a0,BackgroundJob(a4)	;..when idle
	bra.w	rf_end

;--- 32bit FAT background reading --------------------------

ScanFAT32:
	movem.l	d2-d6,-(sp)
	move.l	BackgroundData(a4),d2	;Index of entry
	move.l	FreeClusters(a4),d3	;determine..
	move.l	NextFreeCluster(a4),d4	;..free space
	move.l	LastCluster(a4),d5
	addq.l	#1,d5
	sub.l	d2,d5			;# entries to go
sf32_block:
	move.l	d2,d0
	moveq.l	#0,d1
	bsr.w	MoveFATWindow
	tst.l	d0
	beq.s	sf32_finished		;read error, stop

	move.l	d0,a0			;&FAT window
	move.l	#$ffffff0f,d1
	move.l	#(F32B_Sizeof-F32B_Data)/4,d6
	sub.l	d6,d5
	bcc.s	sf32_entry		;scan to end of window..

	add.l	d5,d6			;..or FAT
	moveq.l	#0,d5
sf32_entry:
	move.l	(a0)+,d0
	and.l	d1,d0			;mask out Flags
	bne.s	sf32_next

	addq.l	#1,d3			;1 more free Cluster..
	tst.l	d4
	bne.s	sf32_next

	move.l	d2,d4			;..and also the first free one
sf32_next:
	addq.l	#1,d2
	subq.l	#1,d6
	bgt.s	sf32_entry

	tst.l	d5
	ble.s	sf32_finished		;all done!!!

	tst.w	DiskChanged(a4)
	bne.s	sf32_end		;on disk change or..

	move.l	pr_MsgPort(a4),a0
	add.w	#MP_MsgList,a0
	move.l	(a0)+,d0
	cmp.l	d0,a0
	beq.s	sf32_block		;..incoming order interrupt here
sf32_end:
	move.l	d2,BackgroundData(a4)
	move.l	d3,FreeClusters(a4)
	move.l	d4,NextFreeCluster(a4)
	movem.l	(sp)+,d2-d6
	rts

sf32_finished:
	clr.l	BackgroundJob(a4)	;work done.
	moveq.l	#ID_WRITE_PROT,d0
	btst	#1,PhysFlags+1(a4)	;if allowed..
	beq.s	sf32_2

	tst.w	SoftLocked(a4)
	bne.s	sf32_2

	moveq.l	#ID_VALIDATED,d0
sf32_2:
	move.l	d0,DiskState(a4)	;..give write permission
	tst.l	d4
	bne.s	sf32_end

	moveq.l	#2,d4			;for the rare case "everything full"
	bra.s	sf32_end

;--- write -------------------------------------------------

WF32_TABLE	= -9*4

WriteFAT:
	movem.l	d2-d7/a2-a3,-(sp)
	tst.l	FATBuffer(a4)
	beq.s	wf_end			;??

	tst.w	FATType(a4)
	bmi.w	wf_32bit

	moveq.l	#0,d2
	move.w	FATStartBlock(a4),d2
	add.l	FirstBlock(a4),d2
	move.l	d2,a2			;Start Block #
	move.b	NumFATCopies(a4),d3
	beq.s	wf_end			;???!!

	move.l	FATBNum(a4),d4
	beq.s	wf_end			;!!!!!

	tst.l	FATFlags(a4)
	bne.s	wf_select

wf_all:
	move.l	d2,d0
	move.l	d4,d1
	move.l	FATBuffer(a4),a0
	bsr.w	_Write			;write whole window at once
	add.l	BlocksPerFAT(a4),d2
	subq.b	#1,d3
	bgt.s	wf_all
	bra.s	wf_end

wf_select:
	move.l	a2,d2			;Start block # of this FAT copy
	move.l	FATFlags(a4),a3		;the "changed" Flags
	move.l	d4,d5			;blocks/FAT
	moveq.l	#0,d7			;Bits/Byte
	moveq.l	#0,d1			;# changed blocks
	bra.s	wf_sskip3
wf_sskip1:
	subq.w	#1,d7
	bgt.s	wf_sskip2

	move.b	(a3)+,d6
	moveq.l	#8,d7
wf_sskip2:
	lsr.b	#1,d6
	bcs.s	wf_scount3		;skip unchanged..

	addq.l	#1,d2
wf_sskip3:
	subq.l	#1,d5
	bpl.s	wf_sskip1		;..blocks

	add.l	FATBNum(a4),a2
	subq.b	#1,d3
	bgt.s	wf_select		;next FAT copy

	move.l	FATFlags(a4),a0
	move.l	FATBNum(a4),d0
	addq.l	#7,d0
	lsr.l	#3,d0
wf_clearflags:
	clr.b	(a0)+			;"done!!!"
	subq.l	#1,d0
	bgt.s	wf_clearflags
wf_end:
	and.w	#~8,NewFlags(a4)	;"FAT now unchanged"
	movem.l	(sp)+,d2-d7/a2-a3
	rts

wf_scount1:
	subq.w	#1,d7
	bgt.s	wf_scount2

	move.b	(a3)+,d6
	moveq.l	#8,d7
wf_scount2:
	lsr.b	#1,d6
	bcc.s	wf_sflush		;changed blocks..
wf_scount3:
	addq.l	#1,d1			;..counted and..
	subq.l	#1,d5
	bpl.s	wf_scount1
wf_sflush:
	move.l	d1,-(sp)
	move.l	d2,d0
	sub.l	a2,d0			;FATBuffer Block Offset
	move.w	BlockShift(a4),d1
	lsl.l	d1,d0			;FATBuffer Byte Offset
	add.l	FATBuffer(a4),d0
	move.l	d0,a0			;&source
	move.l	(sp)+,d1
	move.l	d2,d0
	add.l	d1,d2
	bsr.w	_Write			;..written at once
	moveq.l	#0,d1
	addq.l	#1,d2
	bra.s	wf_sskip3

wf_32bit:
	link.w	a5,#WF32_TABLE
	move.l	FAT32List(a4),a0
	lea	WF32_TABLE(a5),a1
wf32_list:
	tst.l	F32B_Flags(a0)		;the changed Cache Segments..
	beq.s	wf32_lnext

	move.l	a0,(a1)+		;..counted and..
wf32_lnext:
	move.l	(a0),a0
	tst.l	(a0)
	bne.s	wf32_list

	clr.l	(a1)
wf32_bubble:
	moveq.l	#0,d2
	lea	WF32_TABLE(a5),a2
	move.l	(a2)+,a1
wf32_bloop:
	move.l	a1,a0
	move.l	(a2)+,d1
	beq.s	wf32_bcheck

	move.l	d1,a1
	move.l	F32B_Start(a1),d1
	cmp.l	F32B_Start(a0),d1
	bcc.s	wf32_bloop		;..sorted by Block..

	move.l	a1,-8(a2)
	move.l	a0,-4(a2)
	move.l	a0,a1			;..numbers
	moveq.l	#1,d2
	bra.s	wf32_bloop
wf32_bcheck:
	tst.w	d2
	bne.s	wf32_bubble

	moveq.l	#0,d4
	move.w	FATStartBlock(a4),d4
	add.l	FirstBlock(a4),d4
	move.b	NumFATCopies(a4),d5
	beq.s	wf32_done		;??
wf32_fat:
	lea	WF32_TABLE(a5),a3
wf32_chunk:
	move.l	(a3)+,d0
	beq.s	wf32_fnext		;all Segments done

	move.l	d0,a2			;&FAT32Buffer
	move.l	F32B_Start(a2),d2
	move.w	BlockShift(a4),d1
	subq.w	#2,d1
	lsr.l	d1,d2			;FAT Block Offset
	move.l	F32B_Flags(a2),d6
	moveq.l	#0,d7			;Segment Block Offset
wf32_skip:
	moveq.l	#0,d3
	lsr.l	#1,d6
	bcs.s	wf32_count		;unchanged..
	beq.s	wf32_chunk

	addq.l	#1,d7			;..blocks
	bra.s	wf32_skip
wf32_count:
	addq.l	#1,d3			;count changed blocks..
	lsr.l	#1,d6
	bcs.s	wf32_count

	move.l	d7,d0
	move.w	BlockShift(a4),d1
	lsl.l	d1,d0			;Segment Byte Offset
	lea	F32B_Data(a2),a0
	add.l	d0,a0			;&source
	move.l	d2,d0
	add.l	d4,d0
	add.l	d7,d0
	move.l	d3,d1
	bsr.w	_Write			;..and write at once
	add.l	d3,d7
	addq.l	#1,d7
	bra.s	wf32_skip
wf32_fnext:
	add.l	BlocksPerFAT(a4),d4
	subq.b	#1,d5
	bgt.s	wf32_fat
wf32_done:
	lea	WF32_TABLE(a5),a0
wf32_clear:
	move.l	(a0)+,d0
	beq.s	wf32_end

	move.l	d0,a1
	clr.l	F32B_Flags(a1)		;"unchanged"
	bra.s	wf32_clear
wf32_end:
	unlk	a5
	bra.w	wf_end

;--- free --------------------------------------------------

FreeFATBuf:
	bsr.w	FreeFATFlags
	move.l	FATBuffer(a4),d1
	beq.s	ffb_end

	move.l	d1,a1
	move.l	FATBufSize(a4),d0
	CALLEXEC FreeMem
	clr.l	FATBuffer(a4)
	lea	FAT32List(a4),a0
	bsr.w	InitList
	bclr	#3,NewFlags+1(a4)
ffb_end:
	rts

;--- move FAT 32 access window -----------------------------
; d0 <- Index
; d1 <- 0 (read only), -1 (mark as changed)
; d0 -> &entry or 0

MFW_MASK	= (F32B_Sizeof-F32B_Data)/4-1

MoveFATWindow:
	movem.l	d2-d5/a2,-(sp)
	move.l	d0,d2			;Index
	move.l	d1,d3			;mode
	and.w	#~MFW_MASK,d0
	move.l	d0,d5
	eor.l	d0,d2
	move.l	FAT32List(a4),a2
	cmp.l	F32B_Start(a2),d0
	beq.w	mfw_first

	move.l	(a2),d1
	bra.s	mfw_snext
mfw_search:
	cmp.l	F32B_Start(a2),d0
	beq.s	mfw_found
mfw_snext:
	move.l	d1,a2
	move.l	(a2),d1
	bne.s	mfw_search

	move.l	FAT32List+8(a4),a2
	tst.l	F32B_Flags(a2)
	beq.s	mfw_read

	bsr.w	WriteFAT
mfw_read:
	move.l	d5,F32B_Start(a2)
	move.w	BlockShift(a4),d1
	subq.w	#2,d1
	lsr.l	d1,d5			;FAT Block Offset
	moveq.l	#0,d4
	move.w	FATStartBlock(a4),d4
	add.l	FirstBlock(a4),d4
	add.l	d5,d4			;absolute Block #
	neg.l	d5
	add.l	BlocksPerFAT(a4),d5	;to the end of FAT..
	move.l	FATBNum(a4),d0
	cmp.l	d5,d0
	bcc.s	mfw_r1

	move.l	d0,d5			;..or buffer segment
mfw_r1:
	move.b	NumFATCopies(a4),d3
	beq.s	mfw_rfill		;???
mfw_rtry:
	move.l	d4,d0
	move.l	d5,d1
	lea	F32B_Data(a2),a1
	bsr.w	_Read
	cmp.l	d0,d5
	beq.s	mfw_found

	add.l	BlocksPerFAT(a4),d4
	subq.b	#1,d3
	bgt.s	mfw_rtry		;in the worst case..
mfw_rfill:
	lea	F32B_Data(a2),a1
	move.w	#(F32B_Sizeof-F32B_Data)/4,d0
	move.l	#$ffffff0f,d1
mfw_rf1:
	move.l	d1,(a1)+		;..assume "everything full"
	subq.w	#1,d0
	bgt.s	mfw_rf1
mfw_found:
	move.l	a2,a1
	bsr.w	MyRemove
	lea	FAT32List(a4),a0
	move.l	a2,a1
	bsr.w	MyAddHead
mfw_first:
	lsl.l	#2,d2			;Segment Byte Offset
	tst.w	d3
	bpl.s	mfw_ok

	move.l	d2,d0
	move.w	BlockShift(a4),d1
	lsr.l	d1,d0			;Segment Block Offset
	move.l	F32B_Flags(a2),d1
	bset	d0,d1			;"Block changed"
	move.l	d1,F32B_Flags(a2)
mfw_ok:
	moveq.l	#F32B_Data,d0
	add.l	d2,d0
	add.l	a2,d0
	movem.l	(sp)+,d2-d5/a2
	rts

;--- read entry --------------------------------------------
; d0 <- ULONG Cluster #;
; d0 -> ULONG next cluster #;

NextCluster:
GetFATEntry:
	move.l	d0,d1			;FAT Index
	move.l	FATBuffer(a4),d0
	beq.s	gfe_error

	move.l	d0,a0			;&FAT
	tst.w	FATType(a4)
	beq.s	gfe_12bit
	bpl.s	gfe_16bit

	move.l	d1,d0
	moveq.l	#0,d1
	bsr.w	MoveFATWindow		;32bit entries
	move.l	d0,a0
	move.l	(a0),d0
	and.b	#$0f,d0			;only 28bit are actually used
	ReverseL d0
	cmp.l	#$0ffffff7,d0
	bcs.s	gfe_end
	bra.s	gfe_special

gfe_16bit:
	lsl.l	#1,d1			;16bit entries
	add.l	d1,a0
	moveq.l	#0,d0
	move.w	(a0),d0
	ReverseW d0
	cmp.w	#$fff7,d0
	bcs.s	gfe_end
	bra.s	gfe_special

gfe_12bit:
	move.w	d1,d0			;12bit entries
	add.w	d0,a0
	lsr.w	#1,d0
	add.w	d0,a0
	moveq.l	#0,d0
	move.b	1(a0),d0
	rol.w	#8,d0
	move.b	(a0),d0
	lsr.w	#1,d1
	bcc.s	gfe_12l

	lsr.w	#4,d0
	bra.s	gfe_12c
gfe_12l:
	and.w	#$fff,d0
gfe_12c:
	cmp.w	#$ff7,d0
	bcs.s	gfe_end

gfe_special:
	moveq.l	#$fffffff0,d1
	or.l	d1,d0			;Cluster # with special meaning
gfe_end:
	rts

gfe_error:
	moveq.l	#-1,d0
	bra.s	gfe_end

;--- write entry -------------------------------------------
; d0 <- ULONG Cluster #
; d1 <- ULONG new next Cluster #

PutFATEntry:
	move.l	d2,-(sp)
	move.l	d1,d2			;new contents
	move.l	d0,d1			;FAT Index
	move.l	FATBuffer(a4),d0
	beq.s	pfe_end

	move.l	d0,a0			;&FAT
	tst.w	FATType(a4)
	beq.s	pfe_12bit
	bpl.s	pfe_16bit

	move.l	d1,d0
	moveq.l	#-1,d1
	bsr.w	MoveFATWindow		;32bit entries
	move.l	d0,a0
	ReverseL d2
	and.b	#$0f,d2			;only 28bit are actually used
	move.l	(a0),d0
	and.l	#$f0,d0			;keep 4 Flag bits
	or.l	d2,d0
	move.l	d0,(a0)
	bra.s	pfe_ok

pfe_16bit:
	lsl.l	#1,d1			;16bit entries
	add.l	d1,a0
	ReverseW d2
	move.w	d2,(a0)
	move.l	FATFlags(a4),d0
	beq.s	pfe_ok			;safety

	move.l	d0,a0
	move.w	BlockShift(a4),d0
	lsr.l	d0,d1			;Block # in FAT
	moveq.l	#7,d0
	and.l	d1,d0
	lsr.l	#3,d1
	add.l	d1,a0
	bset	d0,(a0)			;"this FAT-Block changed"
	bra.s	pfe_ok

pfe_12bit:
	move.w	d1,d0			;12bit entries
	add.w	d0,a0
	lsr.w	#1,d0
	add.w	d0,a0
	and.w	#$fff,d2
	lsr.w	#1,d1
	bcc.s	pfe_12l

	ror.w	#4,d2
	move.b	d2,1(a0)
	moveq.l	#$f,d1
	bra.s	pfe_12end
pfe_12l:
	move.b	d2,(a0)+
	moveq.l	#-16,d1			;= $f0.b
pfe_12end:
	and.b	(a0),d1
	ror.w	#8,d2
	or.b	d1,d2
	move.b	d2,(a0)

pfe_ok:
	or.w	#8,NewFlags(a4)		;"FAT changed"
pfe_end:
	move.l	(sp)+,d2
	rts

;--- append 1 cluster to chain -----------------------------
; d0 <- ULONG Start Cluster # or 0;
; d0 -> ULONG new Cluster # or -1;

ExtendChain:
	movem.l	d2-d4,-(sp)
	move.l	d0,d2
	beq.s	xch_add			;start new chain
xch_search:
	move.l	d2,d0
	bsr.w	NextCluster
	tst.l	d0			;find last Cluster
	bmi.s	xch_add

	move.l	d0,d2
	bra.s	xch_search
xch_add:
	subq.l	#1,FreeClusters(a4)
	bcs.s	xch_error		;Disk full

	move.l	LastCluster(a4),d3
	addq.l	#1,d3
	move.l	d2,d4			;# predictor
	bgt.s	xch_loop

	move.l	NextFreeCluster(a4),d2
	subq.l	#1,d2
xch_loop:
	addq.l	#1,d2			;scan pred+1 ~ n-1..
	cmp.l	d3,d2
	bcs.s	xch_2

	moveq.l	#2,d2			;..then 2 ~ pred-1..
xch_2:
	move.l	d2,d0
	bsr.w	GetFATEntry
	tst.l	d0			;..for free Clusters
	bne.s	xch_loop

	move.l	d2,NextFreeCluster(a4)
	move.l	d2,d0
	moveq.l	#-1,d1
	bsr.w	PutFATEntry		;found Cluster = "end of chain"

	move.l	d4,d0
	ble.s	xch_end			;if predictor valid,..

	move.l	d2,d1
	bsr.w	PutFATEntry		;..append there
xch_end:
	move.l	d2,d0
	movem.l	(sp)+,d2-d4
	rts

xch_error:
	addq.l	#1,FreeClusters(a4)	;revoke subtraction
	move.w	#221,ErrorNum(a4)
	moveq.l	#-1,d2			;"error"
	bra.s	xch_end

;--- free cluster chain ------------------------------------
; d0 <- ULONG StartClustersummer;

FreeChain:
	movem.l	d2-d4/a2,-(sp)
	move.l	d0,d2
	ble.s	fch_end

	move.l	FreeClusters(a4),d3
	move.l	NextFreeCluster(a4),d4
	bne.s	fch_loop

	moveq.l	#-1,d4
fch_loop:
	cmp.l	d4,d2			;update first free..
	bcc.s	fch_free

	move.l	d2,d4			;..cluster #
fch_free:
	move.l	d2,d0
	bsr.w	NextCluster		;read and..
	exg.l	d0,d2
	moveq.l	#0,d1
	bsr.w	PutFATEntry		;..delete entry
	addq.l	#1,d3
	tst.l	d2
	bgt.s	fch_loop

	move.l	d3,FreeClusters(a4)
	move.l	d4,NextFreeCluster(a4)
fch_end:
	movem.l	(sp)+,d2-d4/a2
	rts

;*** High Level file access ********************************
;--- open file ---------------------------------------------
; <- struct XLock *base dir, BPTR_BSTR name, LONG mode;
; -> struct FileHandleExtension *xfh or 0;

OpenFile:
	link.w	a5,#0
	movem.l	d2-d3,-(sp)
	moveq.l	#0,d3
	move.l	8(a5),d2		;&XLock
	move.l	16(a5),d1		;mode
	cmp.w	#1026,d1
	beq.s	of_check		;special case ACTION_FH_FROM_LOCK

	moveq.l	#SHARED_LOCK,d0
	sub.w	#1004,d1		;MODE_READWRITE
	beq.s	of_create

	subq.w	#2,d1			;MODE_NEWFILE
	bne.s	of_open			;MODE_OLDFILE or unknown mode

	moveq.l	#EXCLUSIVE_LOCK,d0
of_create:
	and.l	#CREATE_MODE,d0		;create when nonexistant
of_open:
	move.l	d0,-(sp)
	move.l	12(a5),-(sp)
	move.l	d2,-(sp)
	bsr.w	LocateObj
	add.w	#12,sp
	move.l	d0,d2
	bne.s	of_check

	move.l	NewObject(a4),d2
	bne.s	of_isfile
	bra.s	of_end			;no XLock
of_check:
	cmp.l	#1006,16(a5)
	beq.s	of_freeold

	move.l	d2,a0
	moveq.l	#$18,d1
	and.b	XL_MSDE+MSDE_Flags(a0),d1
	beq.s	of_isfile

	move.w	#212,ErrorNum(a4)	;dont "open" dirs
	bra.s	of_close
of_freeold:
	move.l	d2,a0
	bsr.w	FreeObj			;overwrite old object
	tst.w	d0
	beq.s	of_close

	move.l	d2,a0
	move.b	#$20,XL_MSDE+MSDE_Flags(a0)
	pea	2.w			;set 3 times
	move.l	a0,-(sp)
	bsr.w	TouchXLock
	addq.l	#8,sp
of_isfile:
	moveq.l	#XFH_Sizeof,d0
	move.l	#MEMF_PUBLIC+MEMF_CLEAR,d1
	CALLEXEC AllocMem
	move.l	d0,d3			;&FileHandleExtension
	beq.s	of_nomem

	move.l	d2,a0
	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	of_1

	move.w	XL_MSDE+MSDE_1H(a0),d0
	swap	d0
of_1:
	move.w	XL_MSDE+MSDE_1L(a0),d0
	move.l	d3,a1
	move.l	d2,XFH_XLock(a1)
	move.l	d0,XFH_Cluster(a1)
	tst.l	XL_FilePos(a0)
	bne.s	of_2			;if not already done..

	move.l	d0,XL_FileChain(a0)	;..init append pointer
of_2:
	lea	FileList(a4),a0
	bsr.w	MyAddHead
of_end:
	move.l	d3,d0
	movem.l	(sp)+,d2-d3
	unlk	a5
	rts

of_nomem:
	move.w	#103,ErrorNum(a4)
of_close:
	cmp.w	#1026,16+2(a5)		;dont free at FH_FROM_LOCK
	beq.s	of_end

	move.l	d2,a1
	bsr.w	CloseXLock
	bra.s	of_end

;--- close file --------------------------------------------
; <- struct FileHandleExtension *xfh or 0;
; -> BOOL ok or &Global_Vars;

CloseFile:
	move.l	a2,-(sp)
	move.l	8(sp),a2		;&FileHandleExtension
	move.l	a2,d0
	beq.s	cf_debug		;secret feature!!!

	moveq.l	#0,d0
	move.w	XFH_Changed(a2),d0	;set access or change date..
	move.l	d0,-(sp)
	move.l	XFH_XLock(a2),-(sp)
	bsr.w	TouchXLock		;..and write dir entry
	addq.l	#8,sp
	move.l	XFH_XLock(a2),a1
	bsr.w	CloseXLock
	move.l	a2,a1
	bsr.w	MyRemove
	moveq.l	#XFH_Sizeof,d0
	move.l	a2,a1
	CALLEXEC FreeMem
	subq.l	#1,NumLocks(a4)		;1 less Lock
	moveq.l	#TRUE,d0
cf_end:
	move.l	(sp)+,a2
	rts

cf_debug:
	move.l	a4,d0
	bra.s	cf_end

;--- FH_Arg1 valid? ----------------------------------------
; d0 <- &FileHandleExtension
; d0 -> &FileHandleExtension or 0

CheckXFH:
	tst.l	d0
	beq.s	cxfh_end

	move.l	FileList(a4),d1
cxfh_loop:
	move.l	d1,a0
	move.l	(a0),d1
	beq.s	cxfh_error		;not in List, invalid

	cmp.l	a0,d0
	bne.s	cxfh_loop		;search on
cxfh_end:
	rts

cxfh_error:
	moveq.l	#0,d0
	bra.s	cxfh_end

;--- seek into file ----------------------------------------
; <- struct FileHandleExtension *xfh, LONG new Position, LONG mode;
; -> LONG old Position or -1;

SeekFilePos:
	movem.l	d2-d5,-(sp)
	move.l	20(sp),a0		  ;&FileHandleExtension
	move.l	XFH_CurrentPos(a0),d2	  ;old Position
	move.l	XFH_XLock(a0),a1	  ;&XLock
	move.l	XL_MSDE+MSDE_FSize(a1),d4 ;file length
	move.l	24(sp),d0
	move.l	28(sp),d1		;mode..
	beq.s	sfp_fromcurrent

	addq.l	#1,d1
	beq.s	sfp_test		;off file beginning

	subq.l	#2,d1
	bne.s	sfp_error		;..invalid

	add.l	d4,d0			;off end of file
	bra.s	sfp_test
sfp_fromcurrent:
	add.l	d2,d0			;off old position
sfp_test:
	cmp.l	d0,d4			;new Position:..
	bcc.s	sfp_seek		;..0 ~ file length permitted
sfp_error:
	move.w	#219,ErrorNum(a4)
sfp_fail:
	moveq.l	#-1,d0
sfp_end:
	movem.l	(sp)+,d2-d5
	rts

sfp_seek:
	moveq.l	#-1,d5			;for UpdateFileChain()
	move.l	d0,d4			;new Position in Bytes..
	move.w	BlockShift(a4),d1
	add.w	ClusterShift(a4),d1
	lsr.l	d1,d0
	move.l	d0,d3			;..and in Clusters
	move.l	d2,d0
	lsr.l	d1,d0
	sub.l	d0,d3			;target distance in Clusters
	beq.s	sfp_found		;already there
	bcs.s	sfp_back		;off file beginning or..

	move.l	XFH_Cluster(a0),d0	;..current Cluster
	bra.s	sfp_mount
sfp_back:
	add.l	d0,d3
	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	sfp_1

	move.w	XL_MSDE+MSDE_1H(a1),d0
	swap	d0
sfp_1:
	move.w	XL_MSDE+MSDE_1L(a1),d0
sfp_mount:
	move.l	VolumeNode(a4),d1
	cmp.l	XL_Volume(a1),d1
	beq.s	sfp_next		;OK, Disk inserted

	move.w	#218,ErrorNum(a4)	;no,..
	bra.s	sfp_fail		;..FAT unavailable

sfp_loop:
	tst.l	d0
	ble.s	sfp_error		;Cluster chain too short  for target position

	move.l	d0,d5
	bsr.w	NextCluster
sfp_next:
	subq.l	#1,d3
	bcc.s	sfp_loop

	move.l	20(sp),a0
	move.l	d0,XFH_Cluster(a0)
sfp_found:
	move.l	d4,XFH_CurrentPos(a0)
	move.l	d5,d0
	bsr.s	UpdateFileChain
	move.l	d2,d0			;return old Position
	bra.s	sfp_end

;--- update append pointer ---------------------------------
; d0 <- previous Cluster #
; a0 <- &FileHandleExtension

UpdateFileChain:
	move.l	XFH_XLock(a0),a1	;&XLock
	move.l	XL_FilePos(a1),d1
	cmp.l	XFH_CurrentPos(a0),d1
	bcc.s	ufc_end			;would be no improvement

	move.l	XFH_Cluster(a0),d1	;if valid, remember current..
	bpl.s	ufc_ok

	move.l	d0,d1			;..or previous cluster otherwise
	bmi.s	ufc_end
ufc_ok:
	move.l	d1,XL_FileChain(a1)
	move.l	XFH_CurrentPos(a0),d1
	move.l	d1,XL_FilePos(a1)
ufc_end:
	rts

;--- read file ---------------------------------------------
; <- struct FileHandleExtension *xfh, BYTE *target, LONG length;
; -> LONG read length;

RFF_RESULT	= -4
;-6.w unused
RFF_MODE	= -8
RFF_FSIZE	= -12

ReadFromFile:
	link.w	a5,#RFF_FSIZE
	movem.l	d2-d6/a2-a3,-(sp)
	move.l	8(a5),a2		;&FileHandleExtension
	move.l	12(a5),a3		;&target
	move.l	16(a5),d4		;length
	move.l	VolumeNode(a4),d1
	move.l	XFH_XLock(a2),a0
	move.l	XL_MSDE+MSDE_FSize(a0),RFF_FSIZE(a5)
	cmp.l	XL_Volume(a0),d1
	beq.s	rff_start		;OK, Disk inserted

	move.w	#218,ErrorNum(a4)	;or not
	moveq.l	#-1,d0
rff_end:
	movem.l	(sp)+,d2-d6/a2-a3
	unlk	a5
	rts

rff_ready:
	move.l	d6,d0
	move.l	a2,a0
	bsr.s	UpdateFileChain
	move.l	RFF_RESULT(a5),d0
	bra.s	rff_end

rff_seekerr:
	move.w	#219,ErrorNum(a4)
rff_error:
	move.l	RFF_RESULT(a5),d0
	sub.l	d4,d0
	bne.s	rff_end			;partial success

	moveq.l	#-1,d0			;total failure
	bra.s	rff_end

rff_start:
	moveq.l	#-1,d6			;for UpdateFileChain()
	move.l	XFH_XLock(a2),a0
	move.l	XL_MSDE+MSDE_FSize(a0),d0
	move.l	XFH_CurrentPos(a2),d5
	sub.l	d5,d0			;rest length from current Position
	and.l	ClusterMask(a4),d5	;Offset from Cluster begin
	cmp.l	d4,d0
	bcc.s	rff_1

	move.l	d0,d4			;limit length to end of file
rff_1:
	move.l	d4,RFF_RESULT(a5)
	beq.s	rff_ready		;nothing to do

	move.l	a3,d0
	move.l	d5,d1
	bsr.w	CheckDirect
	move.w	d0,RFF_MODE(a5)

;- - find a swath of consecutive clusters  - - - - - - - - -

rff_swath:
	move.l	XFH_Cluster(a2),d2
	ble.s	rff_seekerr		;Cluster chain too short for file length

	move.l	d2,-(sp)		;save d2
	move.l	ClusterSize(a4),d3
	sub.l	d5,d3			;length to Cluster end
	bra.s	rff_snext
rff_scluster:
	move.l	d2,d6
	move.l	d2,d0
	bsr.w	NextCluster
	exg.l	d0,d2
	addq.l	#1,d0
	cmp.l	d0,d2
	bne.s	rff_sblock		;Cluster chain discontinuity

	add.l	ClusterSize(a4),d3	;1 more Cluster in swath
rff_snext:
	cmp.l	d3,d4
	bcc.s	rff_scluster

	move.l	d4,d3			;limit to target length
rff_sblock:
	move.l	d2,XFH_Cluster(a2)	;next swath from here
	move.l	(sp)+,d2		;restore d2 ;-)

;- - read swath  - - - - - - - - - - - - - - - - - - - - - -

	tst.l	d5			;if incomplete,..
	bne.s	rff_buffered		;..buffer 1. Cluster
rff_spart:
	move.l	d2,d0
	move.l	d3,d1
	bsr.w	BufScan
	move.l	d1,d5			;# direct transfer blocks
	bne.s	rff_direct

rff_buffered:
	move.l	d2,d0
	bsr.w	Cluster2Block
	moveq.l	#RB_FILEREAD,d1
	move.l	RFF_FSIZE(a5),a0
	add.l	d5,a0
	sub.l	XFH_CurrentPos(a2),a0	;Bytes from Cluster begin to end of file
	bsr.w	ReadBlocks
	tst.l	d0
	beq.w	rff_error		;read error

	move.l	d0,a0
	add.l	d5,a0			;&source
	move.l	a3,a1			;&target
	sub.l	d5,d1
	move.l	d3,d0			;limit part to..
	cmp.l	d0,d1
	bcc.s	rff_bcopy

	move.l	d1,d0			;..buffer size
rff_bcopy:
	sub.l	d0,d3			;mark progress
	sub.l	d0,d4
	add.l	d0,XFH_CurrentPos(a2)
	add.l	d0,a3
	CALLEXEC CopyMem		;get partial cluster
	addq.l	#1,d2			;next Cluster
	moveq.l	#0,d5			;no more offset
	tst.l	d3
	bne.s	rff_spart		;resume same swath,..

	tst.l	d4
	bne.w	rff_swath		;..or find next one
	bra.w	rff_ready		;all done!!

rff_direct:
	tst.w	RFF_MODE(a5)
	bpl.s	rff_emulate

	move.l	a3,a1			;target
	bsr.w	_Read
rff_ereturn:
	cmp.l	d0,d5
	bne.w	rff_error		;read error

	move.w	BlockShift(a4),d1
	move.l	d5,d0
	lsl.l	d1,d0			;progress in bytes..
	sub.l	d0,d3
	sub.l	d0,d4
	add.l	d0,XFH_CurrentPos(a2)
	add.l	d0,a3
	move.w	ClusterShift(a4),d1
	move.l	d5,d0
	lsr.l	d1,d0			;..and in Clusters
	add.l	d0,d2
	moveq.l	#0,d5			;no more offset
	tst.l	d3
	bne.w	rff_spart		;resume same swath,..

	tst.l	d4
	bne.w	rff_swath		;..or find next one
	bra.w	rff_ready		;all done!!

rff_emulate:
	movem.l	d2-d4/a2-a3,-(sp)
	move.l	d0,d2			;absolute Block #
	move.l	d1,d3			;# blocks
	moveq.l	#0,d4
	move.b	BlocksPerCluster(a4),d4
	moveq.l	#0,d0			;use 1 buffer..
	moveq.l	#RB_FILENEW,d1
	bsr.w	ReadBlocks
	tst.l	d0
	beq.s	rff_eend

	move.l	a0,a2
	add.w	#BB_Data,a2		;..for temporary storage
rff_eloop:
	move.l	d2,d0
	move.l	d4,d1
	move.l	a2,a1
	bsr.w	_Read
	cmp.l	d0,d4
	bne.s	rff_eend		;read error

	move.l	a2,a0
	move.l	a3,a1
	move.l	ClusterSize(a4),d0
	add.l	d0,a3
	CALLEXEC CopyMem
	add.l	d4,d2
	sub.l	d4,d3
	bgt.s	rff_eloop
rff_eend:
	move.l	d5,d0
	sub.l	d3,d0
	movem.l	(sp)+,d2-d4/a2-a3
	bra.w	rff_ereturn

;--- test direct transfer support --------------------------
; d0 <- &RAM
; d1 <- Byte offset off Cluster begin
; d0 -> BOOL ok

CheckDirect:
	tst.l	d1
	beq.s	chd_1

	add.l	ClusterSize(a4),d0
	sub.l	d1,d0
chd_1:
	move.l	EnvecBuf+DE_Mask(a4),d1
	not.l	d1
	and.l	d0,d1			;alignment and..
	bne.s	chd_no

	move.l	d0,a1
	CALLEXEC TypeOfMem
	move.l	BufMemType(a4),d1
	and.l	d1,d0
	cmp.l	d0,d1			;..memory type suitable
	bne.s	chd_no

	moveq.l	#-1,d0
chd_end:
	rts

chd_no:
	moveq.l	#0,d0
	bra.s	chd_end

;--- find suitable range for direct transfer ---------------
; d0 <- Start Cluster #
; d1 <- length in bytes
; d0 -> absolute Start Block #
; d1 -> permitted length in blocks or 0

BufScan:
	movem.l	d2-d3,-(sp)
	move.l	d1,d3
	bsr.w	Cluster2Block
	add.l	FirstBlock(a4),d0	;abs. Block #
	move.l	d3,d1
	move.w	ClusterShift(a4),d3
	add.w	BlockShift(a4),d3
	lsr.l	d3,d1
	beq.s	bs_end			;no whole Cluster

	move.w	ClusterShift(a4),d3
	lsl.l	d3,d1			;length in blocks
	move.l	BufList(a4),d2
	bra.s	bs_next
bs_loop:
	move.l	BB_BlockNum(a0),d3
	sub.l	d0,d3
	bcs.s	bs_next			;is before or..

	cmp.l	d1,d3
	bcc.s	bs_next			;..after desired area

	move.l	d3,d1			;limit length
	beq.s	bs_move			;exact hit
bs_next:
	move.l	d2,a0
	move.l	(a0),d2
	bne.s	bs_loop
bs_end:
	movem.l	(sp)+,d2-d3
	rts

bs_move:
	move.l	d0,d3
	move.l	a0,d2
	cmp.l	BufList(a4),d2
	beq.s	bs_end			;optimize:..

	move.l	d2,a1
	bsr.w	MyRemove
	lea	BufList(a4),a0
	move.l	d2,a1
	bsr.w	MyAddHead		;..Puffer to start of list
	move.l	d3,d0
	moveq.l	#0,d1
	bra.s	bs_end

;--- write file --------------------------------------------
; <- struct FileHandleExtension *xfh, BYTE *data, LONG length;
; -> LONG written length;

WTF_CLUSTER	= -4
WTF_POS		= -8
;-10.w unused
WTF_MODE	= -12
WTF_FSIZE	= -16

WriteToFile:
	link.w	a5,#WTF_FSIZE
	movem.l	d2-d7/a2-a3,-(sp)
	move.l	8(a5),a2		;&FileHandleExtension
	move.l	12(a5),a3		;&source
	move.l	16(a5),d4		;length
	beq.s	wtf_end			;nothing to do

	move.l	XFH_XLock(a2),a0
	move.l	XL_MSDE+MSDE_FSize(a0),WTF_FSIZE(a5)
	move.l	VolumeNode(a4),d1
	cmp.l	XL_Volume(a0),d1
	beq.s	wtf_1			;Disk inserted

	move.w	#218,ErrorNum(a4)	;or not
	bra.s	wtf_end
wtf_1:
	moveq.l	#ID_VALIDATED,d0
	cmp.l	DiskState(a4),d0
	beq.s	wtf_2

	move.w	#214,ErrorNum(a4)	;Disk or..
	bra.s	wtf_end
wtf_2:
	btst	#0,XL_MSDE+MSDE_Flags(a0)
	beq.s	wtf_start

	move.w	#223,ErrorNum(a4)	;..file is read only
wtf_end:
	move.l	16(a5),d0
	sub.l	d4,d0
	movem.l	(sp)+,d2-d7/a2-a3
	unlk	a5
	rts

wtf_start:
	move.l	XL_FileChain(a0),d7
	move.l	XFH_CurrentPos(a2),d5
	move.l	d5,WTF_POS(a5)
	move.l	d5,d0
	add.l	d4,d0			;new Position
	cmp.l	WTF_FSIZE(a5),d0
	bcs.s	wtf_3

	move.l	d0,WTF_FSIZE(a5)	;new file length for ReadBlocks()
wtf_3:
	and.l	ClusterMask(a4),d5	;Offset from Cluster begin
	move.l	XFH_Cluster(a2),d2
	bgt.s	wtf_firstc		;resume last Cluster..

	move.l	d7,d0
	bsr.w	ExtendChain
	tst.l	d0
	bmi.w	wtf_ready		;Disk full

	move.l	d7,d1
	move.l	d0,d7
	move.l	d0,d2			;..or start a new one
	tst.l	d1
	bne.s	wtf_firstc

	move.l	XFH_XLock(a2),a0
	move.w	d0,XL_MSDE+MSDE_1L(a0)	;this is the first..
	tst.w	FATType(a4)
	bpl.s	wtf_firstc

	swap	d0
	move.w	d0,XL_MSDE+MSDE_1H(a0)	;..Cluster of this file
wtf_firstc:
	move.l	d2,WTF_CLUSTER(a5)
	move.l	a3,d0
	move.l	d5,d1
	bsr.w	CheckDirect
	move.w	d0,WTF_MODE(a5)

;- - find a swath of consecutive clusters  - - - - - - - - -

wtf_swath:
	move.l	WTF_CLUSTER(a5),d2
	bmi.w	wtf_ready		;Disk full

	move.l	d2,d6			;save d2
	move.l	ClusterSize(a4),d3
	sub.l	d5,d3			;length to end of Cluster
	bra.s	wtf_snext
wtf_scluster:
	move.l	d2,d7
	move.l	d2,d0
	bsr.w	NextCluster		;next cluster is..
	tst.l	d0
	bgt.s	wtf_s1			;..already present,..

	cmp.l	d3,d4
	beq.s	wtf_s1			;..not needed..

	move.l	d2,d0			;fill up disk, then stop
	bsr.w	ExtendChain		;..or new
wtf_s1:
	exg.l	d0,d2
	addq.l	#1,d0
	cmp.l	d0,d2
	bne.s	wtf_sblock		;chain discontinuity

	add.l	ClusterSize(a4),d3	;one more Cluster in this swath
wtf_snext:
	cmp.l	d3,d4
	bcc.s	wtf_scluster

	move.l	d4,d3			;limit to target length
wtf_sblock:
	move.l	d2,WTF_CLUSTER(a5)	;next swath from here
	move.l	d6,d2			;restore d2 ;-)

;- - write swath  - - - - - - - - - - - - - - - - - - - - -

	tst.l	d5			;when incomplete,..
	bne.s	wtf_bufread		;..buffer first Cluster
wtf_spart:
	move.l	d2,d0
	move.l	d3,d1
	bsr.w	BufScan
	move.l	d1,d5			;# blocks for direct transfer
	bne.s	wtf_direct

wtf_bufauto:
	moveq.l	#RB_FILENEW,d6
	move.l	WTF_POS(a5),d0
	add.l	d4,d0			;when enlarging a file,..
	move.l	XFH_XLock(a2),a0
	cmp.l	XL_MSDE+MSDE_FSize(a0),d0
	bcc.s	wtf_buffered		;..dont preread last Cluster
wtf_bufread:
	moveq.l	#RB_FILEREAD,d6
wtf_buffered:
	move.l	d2,d0
	bsr.w	Cluster2Block
	move.l	d6,d1
	move.l	WTF_FSIZE(a5),a0
	add.l	d5,a0
	sub.l	WTF_POS(a5),a0		;Bytes from Cluster begin to end of file
	bsr.w	ReadBlocks
	tst.l	d0
	beq.w	wtf_ready		;read error

	move.l	d0,a1
	add.l	d5,a1			;&target
	sub.l	d5,d1
	move.l	d3,d0			;limit part length..
	cmp.l	d0,d1
	bcc.s	wtf_bcopy

	move.l	d1,d0			;..to end of buffer
wtf_bcopy:
	bsr.w	SetDirty		;changed blocks
	move.l	a3,a0			;&source
	sub.l	d0,d3			;mark progress
	sub.l	d0,d4
	add.l	d0,WTF_POS(a5)
	add.l	d0,a3
	CALLEXEC CopyMem		;put part
	addq.l	#1,d2			;next Cluster
	moveq.l	#0,d5			;no more offset
	tst.l	d3
	bne.s	wtf_spart		;resume same swath,..

	tst.l	d4
	bne.w	wtf_swath		;..or find next one
	bra.w	wtf_ready		;all done!!

wtf_direct:
	tst.w	WTF_MODE(a5)
	bpl.s	wtf_emulate

	move.l	a3,a0			;source
	bsr.w	_Write
wtf_ereturn:
	cmp.l	d0,d5
	bne.s	wtf_ready		;write error

	move.w	BlockShift(a4),d1
	move.l	d5,d0
	lsl.l	d1,d0			;progress in bytes..
	sub.l	d0,d3
	sub.l	d0,d4
	add.l	d0,WTF_POS(a5)
	add.l	d0,a3
	move.w	ClusterShift(a4),d1
	move.l	d5,d0
	lsr.l	d1,d0			;..and in Clusters
	add.l	d0,d2
	moveq.l	#0,d5			;no more offset
	tst.l	d3
	bne.w	wtf_spart		;resume same swath,..

	tst.l	d4
	bne.w	wtf_swath		;..or find next one
	bra.s	wtf_ready		;all done!!!

wtf_emulate:
	movem.l	d2-d4/a2-a3,-(sp)
	move.l	d0,d2			;absolute Block #
	move.l	d1,d3			;# blocks
	moveq.l	#0,d4
	move.b	BlocksPerCluster(a4),d4
	moveq.l	#0,d0			;temporarily use one block buffer..
	moveq.l	#RB_FILENEW,d1
	bsr.w	ReadBlocks
	tst.l	d0
	beq.s	wtf_eend

	move.l	a0,a2
	add.w	#BB_Data,a2		;..for intermediate storage
wtf_eloop:
	move.l	a3,a0
	move.l	a2,a1
	move.l	ClusterSize(a4),d0
	add.l	d0,a3
	CALLEXEC CopyMem
	move.l	d2,d0
	move.l	d4,d1
	move.l	a2,a0
	bsr.w	_Write
	cmp.l	d0,d4
	bne.s	wtf_eend		;write error

	add.l	d4,d2
	sub.l	d4,d3
	bgt.s	wtf_eloop
wtf_eend:
	move.l	d5,d0
	sub.l	d3,d0
	movem.l	(sp)+,d2-d4/a2-a3
	bra.s	wtf_ereturn

;- - summary - - - - - - - - - - - - - - - - - - - - - - - -

wtf_ready:				;all done!!!
	move.w	#1,XFH_Changed(a2)	;"file changed"
	move.l	XFH_XLock(a2),a0
	move.l	WTF_POS(a5),d1
	cmp.l	XL_MSDE+MSDE_FSize(a0),d1
	bcs.s	wtf_r1

	move.l	d1,XL_MSDE+MSDE_FSize(a0) ;file has been enlarged
	move.l	XL_Parent(a0),a1
	or.w	#$8000,XL_Flags(a1)
wtf_r1:
	tst.l	d4			;on success..
	bne.s	wtf_r2

	move.l	d1,XFH_CurrentPos(a2)	;..set new Position
	move.l	WTF_CLUSTER(a5),XFH_Cluster(a2)
wtf_r2:
	move.l	d7,d0
	move.l	a2,a0
	bsr.w	UpdateFileChain
	bra.w	wtf_end

;--- alter file length -------------------------------------
; <- struct FileHandleExtension *xfh, LONG new length, LONG mode;
; -> LONG new length or -1;

SetFileSize:
	movem.l	d2-d5/a2-a3,-(sp)
	move.l	28(sp),a2		;&FileHandleExtension
	move.l	XFH_XLock(a2),a3	;&XLock

;- - prerequisites  - - - - - - - - - - - - - - - - - - - -

	move.l	XL_Volume(a3),d0
	cmp.l	VolumeNode(a4),d0
	bne.w	sfs_notmounted		;FAT unavailable

	moveq.l	#ID_VALIDATED,d0
	cmp.l	DiskState(a4),d0
	bne.w	sfs_diskprot		;Disk or..

	btst	#0,XL_MSDE+MSDE_Flags(a3)
	bne.w	sfs_fileprot		;..file read only

	move.l	FileList(a4),d2
	moveq.l	#0,d1
	bra.s	sfs_snext
sfs_scan:
	cmp.l	XFH_XLock(a0),a3	;of all..
	bne.s	sfs_snext

	cmp.l	a0,a2			;..open FileHandles..
	beq.s	sfs_snext		;..to this file..

	move.l	XFH_CurrentPos(a0),d0
	cmp.l	d0,d1
	bcc.s	sfs_snext

	move.l	d0,d1			;..get highest Position
sfs_snext:
	move.l	d2,a0
	move.l	(a0),d2
	bne.s	sfs_scan

	move.l	32(sp),d0		;Offset
	move.l	36(sp),d2		;mode..
	beq.s	sfs_fromcurrent

	addq.l	#1,d2
	beq.s	sfs_check		;off file beginning

	subq.l	#2,d2
	bne.w	sfs_seekerr		;..invalid

	add.l	XL_MSDE+MSDE_FSize(a3),d0 ;off end of file
	bra.s	sfs_check
sfs_fromcurrent:
	add.l	XFH_CurrentPos(a2),d0
sfs_check:
	tst.l	d0
	bmi.w	sfs_seekerr		;less than 0 bytes??

	cmp.l	d1,d0
	bcc.s	sfs_c1

	move.l	d1,d0			;dont pull the rug from under other accessors
sfs_c1:
	move.l	d0,d5			;the new length
	move.l	ClusterMask(a4),d4
	move.w	BlockShift(a4),d1
	add.w	ClusterShift(a4),d1
	add.l	d4,d0
	lsr.l	d1,d0
	move.l	d0,d3			;# Clusters after..
	add.l	XL_MSDE+MSDE_FSize(a3),d4
	lsr.l	d1,d4			;..and before
	sub.l	d4,d3
	bcs.s	sfs_cut
	bne.w	sfs_append

;- - Cluster chain unchanged - - - - - - - - - - - - - - - -

	cmp.l	XFH_CurrentPos(a2),d5
	bcc.w	sfs_ok			;limit new Position..

	move.l	d5,XFH_CurrentPos(a2)	;..to new end of file
	tst.l	XFH_Cluster(a2)		;if needed..
	bpl.w	sfs_ok

	move.l	XL_FileChain(a3),d0
	move.l	d0,XFH_Cluster(a2)	;..go back to last valid Cluster
	bra.w	sfs_ok

;- - cut off clusters - - - - - - - - - - - - - - - - - - -

sfs_cut:
	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	sfs_u1

	move.w	XL_MSDE+MSDE_1H(a3),d0
	swap	d0
sfs_u1:
	move.w	XL_MSDE+MSDE_1L(a3),d0
	move.l	d4,d2
	add.l	d3,d2			;# remaining Clusters
	bne.s	sfs_unext

	clr.l	XL_FilePos(a3)
	clr.l	XL_FileChain(a3)
	moveq.l	#0,d3
	move.l	d0,d4			;free entire chain
	clr.w	XL_MSDE+MSDE_1L(a3)
	tst.w	FATType(a4)
	bpl.s	sfs_ufree

	clr.w	XL_MSDE+MSDE_1H(a3)
	bra.s	sfs_ufree
sfs_uwalk:
	bsr.w	NextCluster		;skip Clusters 0...n-1
sfs_unext:
	tst.l	d0
	ble.w	sfs_seekerr

	subq.l	#1,d2
	bgt.s	sfs_uwalk

	move.l	d5,XL_FilePos(a3)
	move.l	d0,XL_FileChain(a3)
	move.l	d0,d2
	bsr.w	NextCluster		;Cluster n..
	move.l	d0,d4
	move.l	d2,d0
	moveq.l	#-1,d1
	bsr.w	PutFATEntry		;..= new end of chain
	moveq.l	#-1,d3
sfs_ufree:
	move.l	d4,d0
	bsr.w	FreeChain		;free Clusters n+1...?
	exg.l	d3,d4			;for sfs_sdjust
	cmp.l	XFH_CurrentPos(a2),d5	;limit new Position..
	bcc.s	sfs_adjust

	move.l	d5,XFH_CurrentPos(a2)	;..to new end of file
	moveq.l	#-1,d1
	move.l	ClusterMask(a4),d0
	and.l	d5,d0
	beq.s	sfs_u2

	move.l	d2,d1
sfs_u2:
	move.l	d1,XFH_Cluster(a2)
	bra.s	sfs_adjust

;- - append cluster  - - - - - - - - - - - - - - - - - - - -

sfs_append:
	move.l	d3,d2			;# Cluster to be appended
	add.l	d4,d3
	move.l	XL_FileChain(a3),d0
	bsr.w	ExtendChain
	move.l	d0,d4			;first new Cluster..
	bmi.s	sfs_abreak

	tst.l	XL_MSDE+MSDE_FSize(a3)
	bne.s	sfs_anext

	move.w	d0,XL_MSDE+MSDE_1L(a3)	;..and maybe first in file
	tst.w	FATType(a4)
	bpl.s	sfs_anext

	swap	d0
	move.w	d0,XL_MSDE+MSDE_1H(a3)
	swap	d0
	bra.s	sfs_anext
sfs_aloop:
	bsr.w	ExtendChain		;extend chain
	tst.l	d0
	bmi.s	sfs_abreak
sfs_anext:
	move.l	d0,XL_FileChain(a3)
	subq.l	#1,d2
	bgt.s	sfs_aloop
	bra.s	sfs_aok
sfs_abreak:
	move.w	BlockShift(a4),d1
	add.w	ClusterShift(a4),d1	;disk full, stop here..
	move.l	d3,d0
	sub.l	d2,d0
	lsl.l	d1,d0
	move.l	d0,d5			;..and limit new length
sfs_aok:
	move.l	d5,XL_FilePos(a3)
	move.l	XL_MSDE+MSDE_FSize(a3),d3
	beq.s	sfs_adjust

	moveq.l	#-1,d3

;- - adjust any affected open file handles - - - - - - - -

sfs_adjust:
	move.l	FileList(a4),d2
	bra.s	sfs_dnext
sfs_dloop:
	cmp.l	XFH_XLock(a0),a3
	bne.s	sfs_dnext

	cmp.l	XFH_Cluster(a0),d3
	bne.s	sfs_dnext

	move.l	d4,XFH_Cluster(a0)
sfs_dnext:
	move.l	d2,a0
	move.l	(a0),d2
	bne.s	sfs_dloop
sfs_ok:
	move.w	#1,XFH_Changed(a2)
	move.l	d5,XL_MSDE+MSDE_FSize(a3)
	move.l	d5,d0
sfs_end:
	movem.l	(sp)+,d2-d5/a2-a3
	rts

sfs_notmounted:
	move.w	#218,d0
	bra.s	sfs_error
sfs_diskprot:
	move.w	#214,d0
	bra.s	sfs_error
sfs_fileprot:
	move.w	#223,d0
	bra.s	sfs_error
sfs_seekerr:
	move.w	#219,d0
sfs_error:
	move.w	d0,ErrorNum(a4)
	moveq.l	#-1,d0
	bra.s	sfs_end

;--- intermediate dir refresh (user dir scan) --------------
; a0 <- &XLock
; d0 -> 0 (nothing to do), 1 (OK)

UpdateDir:
	tst.w	XL_Flags(a0)
	bmi.s	upd_start

	moveq.l	#0,d0
upd_end:
	rts

upd_start:
	movem.l	d2/a2-a3,-(sp)
	move.l	a0,a2			;&XLock
	and.w	#$7fff,XL_Flags(a2)	;avoid recursion
	moveq.l	#0,d2			;nothing done yet
	move.l	FileList(a4),a3
upd_scan:
	tst.l	(a3)
	beq.s	upd_done		;these were all open files

	tst.w	XFH_Changed(a3)
	beq.s	upd_next		;unchanged

	move.l	XFH_XLock(a3),a0
	move.l	XL_Parent(a0),d0
	cmp.l	d0,a2
	bne.s	upd_next		;not in this dir

	add.w	#XL_MSDE,a0
	bsr.w	WriteMSDE		;update dir entry
	moveq.l	#1,d2			;something done :)
upd_next:
	move.l	(a3),a3
	bra.s	upd_scan
upd_done:
	tst.l	d2
	beq.s	upd_ok			;if something done..

	pea	1.w
	move.l	a2,-(sp)
	bsr.w	TouchXLock		;..report this outside
	addq.l	#8,sp
upd_ok:
	move.l	d2,d0
	movem.l	(sp)+,d2/a2-a3
	bra.s	upd_end

;--- free object ------------------------------------------
; a0 <- &XLock
; d0 -> BOOL ok

FreeObj:
	movem.l	d2-d4/a2-a3,-(sp)
	move.l	a0,a2			;&XLock
	cmp.w	#1,XL_OpenCnt(a2)
	bgt.w	fo_inuse		;in use

	move.b	XL_MSDE+MSDE_Flags(a2),d1
	btst	#3,d1
	bne.w	fo_inuse		;keep root dir!!!

	btst	#0,d1
	bne.w	fo_readonly		;read only

	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	fo_1

	move.w	XL_MSDE+MSDE_1H(a2),d0
	swap	d0
fo_1:
	move.w	XL_MSDE+MSDE_1L(a2),d0
	move.l	d0,d4
	ble.s	fo_reset		;no Cluster chain

	btst	#4,d1
	beq.s	fo_freechain		;a file

	bsr.w	Cluster2Block
	move.l	d0,d2
fo_block:
	move.l	d2,d0
	beq.s	fo_freechain		;end of chain

	bsr.w	ReadDirBlock
	tst.l	d0
	beq.s	fo_inuse		;read error

	move.l	d0,a3			;&Block contents
	moveq.l	#0,d3			;Offset
fo_entry:
	move.b	(a3),d0			;MSDE_Name[0]
	beq.s	fo_freechain		;end of dir

	cmp.b	#MSDEB_DELETED,d0
	beq.s	fo_enext

	cmp.b	#'.',d0
	beq.s	fo_enext

	moveq.l	#$3f,d0
	and.b	MSDE_Flags(a3),d0
	cmp.b	#$0f,d0
	bne.s	fo_notempty		;dir not empty
fo_enext:
	moveq.l	#MSDE_Sizeof,d0
	add.l	d0,a3
	add.w	d0,d3
	cmp.w	BlockSize(a4),d3
	bcs.s	fo_entry

	move.l	d2,d0
	bsr.w	NextBlock
	move.l	d0,d2
	bra.s	fo_block
fo_freechain:
	move.l	d4,d0
	bsr.w	FreeChain		;free Cluster chain..
fo_reset:
	clr.l	XL_MSDE+MSDE_FSize(a2)
	clr.w	XL_MSDE+MSDE_1L(a2)	;..and delete link..
	tst.w	FATType(a4)
	bpl.s	fo_2

	clr.w	XL_MSDE+MSDE_1H(a2)	;..to it
fo_2:
	clr.l	XL_FilePos(a2)		;reset append pointer
	clr.l	XL_FileChain(a2)
	pea	1.w
	move.l	XL_Parent(a2),-(sp)	;set date of parent..
	bsr.w	TouchXLock		;..dir
	addq.l	#8,sp
fo_ok:
	moveq.l	#TRUE,d0
fo_end:
	movem.l	(sp)+,d2-d4/a2-a3
	rts

fo_inuse:
	move.w	#202,d1
	bra.s	fo_error
fo_readonly:
	move.w	#222,d1
	bra.s	fo_error
fo_notempty:
	move.w	#216,d1
fo_error:
	move.w	d1,ErrorNum(a4)
	moveq.l	#FALSE,d0
	bra.s	fo_end

;--- delete dir or file ------------------------------------
; <- struct XLock *base dir, BPTR_BSTR Name;
; -> BOOL ok;

DeleteObj:
	link.w	a5,#0
	move.l	a2,-(sp)

	pea	(EXCLUSIVE_LOCK).w
	move.l	12(a5),-(sp)
	move.l	8(a5),-(sp)
	bsr.w	LocateObj
	add.w	#12,sp
	move.l	d0,a2
	tst.l	d0
	beq.s	do_error		;not found

	move.l	a2,a0
	bsr.w	FreeObj
	tst.w	d0
	beq.s	do_close		;no permission

	move.l	a2,a0
	bsr.w	DeleteXLock
	move.l	a2,a1
	bsr.w	CloseXLock
	moveq.l	#TRUE,d0		;"OK"
	bra.s	do_end
do_close:
	move.l	a2,a1
	bsr.w	CloseXLock
do_error:
	moveq.l	#FALSE,d0
do_end:
	move.l	(sp)+,a2
	unlk	a5
	rts

;--- set file or dir date ----------------------------------
; <- struct XLock *base dir, BPTR_BSTR Name, struct DateStamp *date;
; -> BOOL ok;

SetFileDate:
	link.w	a5,#-12
	move.l	a2,-(sp)
	pea	INTERNAL_MODE&EXCLUSIVE_LOCK
	move.l	12(a5),-(sp)
	move.l	8(a5),-(sp)
	bsr.w	LocateObj
	add.w	#12,sp
	move.l	d0,a2
	tst.l	d0
	beq.s	sfd_error

	move.l	16(a5),a0
	addq.l	#8,a0
	move.l	a5,a1
	move.l	(a0),d0			;DS_Ticks
	move.l	#60*50,d1
	UDIVMOD32
	move.l	d1,-(a1)
	add.l	-(a0),d0		;DS_Mins
	moveq.l	#(24*60)>>5,d1
	lsl.l	#5,d1
	UDIVMOD32
	move.l	d1,-(a1)
	add.l	-(a0),d0		;DS_Days
	move.l	d0,-(a1)
	pea	-12(a5)
	bsr.w	Date2MS
	addq.l	#4,sp
	swap	d0
	move.l	d0,XL_MSDE+MSDE_Time(a2)
	lea	XL_MSDE(a2),a0
	bsr.w	WriteMSDE
	move.l	a2,a1
	bsr.w	CloseXLock
	moveq.l	#TRUE,d0		;"OK"
sfd_end:
	move.l	(sp)+,a2
	unlk	a5
	rts

sfd_error:
	moveq.l	#FALSE,d0
	bra.s	sfd_end

;--- Hacker commands ---------------------------------------
; <- struct XLock *dir, BPTR_BSTR Name, BPTR_BSTR comment;
; -> BOOL ok;

SetComment:
	link.w	a5,#0
	movem.l	d2/a2,-(sp)
	move.l	16(a5),d0
	beq.w	sc_error		;"no comment"

	lsl.l	#2,d0
	move.l	d0,a0
	moveq.l	#0,d2
	move.b	(a0)+,d2		;a0 = &comment
	cmp.b	#'!',(a0)+
	bne.w	sc_error		;not a command

	lea	sc_words(pc),a1
	bsr.w	sc_scan
	move.w	d0,d2
	beq.w	sc_error		;no valid command

	subq.w	#1,d2
	beq.s	sc_scandisk

	subq.w	#1,d2
	beq.s	sc_erase

	subq.w	#1,d2
	bne.s	sc_transform

	bsr.w	SetOptions
	bra.w	sc_end
sc_scandisk:
	bsr.w	ScanDisk
	bra.w	sc_end
sc_erase:
	bsr.w	SecurityErase
	bra.s	sc_end
sc_transform:
	pea	INTERNAL_MODE&EXCLUSIVE_LOCK
	move.l	12(a5),-(sp)
	move.l	8(a5),-(sp)
	bsr.w	LocateObj
	add.w	#12,sp
	move.l	d0,a2
	tst.l	d0
	beq.s	sc_end			;Object in use or not found

	btst	#3,XL_MSDE+MSDE_Flags(a2)
	bne.s	sc_closexlock		;better dont touch root dir

	subq.w	#1,d2
	bne.s	sc_2dir

;- - dir -> file - - - - - - - - - - - - - - - - - - - - - -

	bclr	#4,XL_MSDE+MSDE_Flags(a2)
	beq.s	sc_closexlock		;already is a file

	moveq.l	#0,d2
	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	sc_2f1

	move.w	XL_MSDE+MSDE_1H(a2),d0
	swap	d0
sc_2f1:
	move.w	XL_MSDE+MSDE_1L(a2),d0
	tst.l	d0
	ble.s	sc_2f2

	bsr.w	Cluster2Block
sc_2floop:
	addq.l	#1,d2			;# dir blocks..
	bsr.w	NextBlock
	tst.l	d0
	bne.s	sc_2floop
sc_2f2:
	move.w	BlockShift(a4),d0
	lsl.l	d0,d2			  ;..* Block length..
	move.l	d2,XL_MSDE+MSDE_FSize(a2) ;..= file length
	bra.s	sc_writeback

;- - file -> dir - - - - - - - - - - - - - - - - - - - - - -

sc_2dir:
	bset	#4,XL_MSDE+MSDE_Flags(a2)
	bne.s	sc_closexlock		;already is dir

	clr.l	XL_MSDE+MSDE_FSize(a2)

sc_writeback:
	lea	XL_MSDE(a2),a0
	bsr.w	WriteMSDE
sc_closexlock:
	move.l	a2,a1
	bsr.w	CloseXLock
	moveq.l	#TRUE,d0
sc_end:
	movem.l	(sp)+,d2/a2
	unlk	a5
	rts

sc_error:
	move.w	#209,ErrorNum(a4)	;for uninformed people..
	moveq.l	#0,d0			;..we play dumb.
	bra.s	sc_end

; a0 <-> &comment string
; a1 <-  &recognized words
; d0  -> # found word or 0

sc_scan:
	movem.l	d1/a1-a2,-(sp)
	move.l	a0,a2
	moveq.l	#1,d0
sc_sloop:
	move.b	(a1)+,d1
	beq.s	sc_send			;word found

	cmp.b	(a0)+,d1
	beq.s	sc_sloop		;on mismatch..
sc_skip:
	tst.b	(a1)+
	bne.s	sc_skip			;..try next word

	tst.b	(a1)
	beq.s	sc_serror		;end of list, thats it!

	move.l	a2,a0
	addq.l	#1,d0
	bra.s	sc_sloop
sc_send:
	movem.l	(sp)+,d1/a1-a2
	rts

sc_serror:
	moveq.l	#0,d0
	bra.s	sc_send

sc_words:
	dc.b	"scandisk",0
	dc.b	"erase",0
	dc.b	"control ",0
	dc.b	"file",0
	dc.b	"dir",0,0
	even

;--- change settings ---------------------------------------
; a0 <- &string
; d0 -> -1 (OK)

SetOptions:
	move.l	d2,-(sp)
so_on:
	moveq.l	#-1,d2
so_char:
	move.b	(a0)+,d0
	cmp.b	#' ',d0
	bcs.s	so_end			;thats all

	cmp.b	#'+',d0
	beq.s	so_on			;turn the following ON..

	cmp.b	#'-',d0
	beq.s	so_off			;..or OFF

	lea	so_tab(pc),a1
so_test:
	move.w	(a1)+,d1
	beq.s	so_char			;unknown option

	cmp.b	d0,d1
	bne.s	so_test

	lsr.w	#8,d1
	move.w	CmdFlags(a4),d0
	tst.w	d2
	beq.s	so_clear

	bset	d1,d0
	bra.s	so_write
so_clear:
	bclr	d1,d0
so_write:
	move.w	d0,CmdFlags(a4)
	bra.s	so_char
so_off:
	moveq.l	#0,d2
	bra.s	so_char
so_end:
	moveq.l	#-1,d0
	move.l	(sp)+,d2
	rts

so_tab:
	dc.b	2,"s"
	dc.b	3,"u"
	dc.b	8,"d"
	dc.b	9,"D"
	dc.b	10,"L"
	dc.b	11,"l"
	dc.w	0

;--- local vars for ScanDisk() and SecurityErase() ---------

SD_CLUSTERS	= -4
SD_DONE		= -8
SD_BLOCKBUF	= -12
SD_WINDOW	= -16
SD_RASTPORT	= -20
SD_TEXTHEIGHT	= -22
SD_TEXTWIDTH	= -24
SD_TEXTY	= -26
SD_TEXTX	= -28
SD_BARHEIGHT	= -30
SD_BARWIDTH	= -32
SD_BARY		= -34
SD_BARX		= -36
SD_BARPOS	= -38
SD_C1		= -39
SD_C4		= -40
SD_C0		= -41
SD_C5		= -42
SD_C2		= -43
SD_C3		= -44
SD_LASTKEY	= -46
SD_LASTQUAL	= -48
SD_STEPMASK	= -52
SD_ERRORS	= -56
SD_OPENCHAINS	= -60
SD_VOIDLINKS	= -64
SD_FILESIZES	= -68
SD_LOSTCHAINS	= -72
SD_LOSTCLUSTERS	= -76
SD_TITLE	= -76-120
SD_STRINGBUF	= -76-320

;--- zero out unused Cluster -------------------------------

SecurityErase:
	link.w	a5,#SD_STRINGBUF
	movem.l	d2-d6/a2-a3,-(sp)
	move.l	FreeClusters(a4),d3
	beq.w	se_end			;nothing to do

	move.l	d3,SD_CLUSTERS(a5)
	clr.l	SD_DONE(a5)

;- - open progresss window - - - - - - - - - - - - - - - - -

	move.l	d3,d0
	LOG2
	subq.w	#6,d0			;update progress display in 64..
	bpl.s	se_1

	moveq.l	#0,d0
se_1:
	moveq.l	#0,d1
	bset	d0,d1
	move.l	d1,SD_STEPMASK(a5)	;..steps
	bsr.w	OpenProgWindow
	move.l	d0,SD_WINDOW(a5)
	bsr.w	sd_initwingfx

;- - zero blocks - - - - - - - - - - - - - - - - - - - - - -

	sub.l	a3,a3			;still no zero buffer
	move.l	UIText+14*4(a4),a0
	bsr.w	sd_text
	moveq.l	#2,d2			;Cluster #
	clr.l	SD_OPENCHAINS(a5)	;here: # zeroed Clusters
	moveq.l	#-1,d6			;try CFA_ERASE_SECTORS..
	btst	#4,CmdFlags+1(a4)
	bne.s	se_swath

	moveq.l	#0,d6			;..or not
	moveq.l	#2,d0
	swap	d0
	moveq.l	#MEMF_CLEAR>>16,d1
	swap	d1
	or.l	BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,a3			;&zero buffer
	tst.l	d0
	beq.w	se_stop
se_swath:
	move.l	SD_OPENCHAINS(a5),d0
	add.l	d0,SD_DONE(a5)
	bsr.w	sd_bar			;update progresss bar
	cmp.w	#KEY_ESC,SD_LASTKEY(a5)
	beq.w	se_stop			;user stop

	move.l	LastCluster(a4),d3
	addq.l	#1,d3
	sub.l	d2,d3
	ble.w	se_done

	moveq.l	#0,d4			;part start
se_count:
	move.l	d2,d0
	bsr.w	GetFATEntry
	tst.l	d0
	beq.s	se_free

	tst.l	d4
	beq.s	se_cnext		;find next free Cluster
	bra.s	se_flush		;part ends here
se_free:
	tst.l	d4
	bne.s	se_1more

	move.l	d2,d4			;part begins here
	moveq.l	#0,d5
se_1more:
	cmp.l	SD_STEPMASK(a5),d5
	bcc.s	se_flush

	addq.l	#1,d5			;continue part
se_cnext:
	addq.l	#1,d2
	subq.l	#1,d3
	bgt.s	se_count
se_flush:
	clr.l	SD_OPENCHAINS(a5)
	move.l	d4,d0
	beq.s	se_swath

	move.l	d5,SD_OPENCHAINS(a5)
	bsr.w	Cluster2Block
	add.l	FirstBlock(a4),d0
	move.l	d0,d4			;absolute Block #
	move.w	ClusterShift(a4),d0
	lsl.l	d0,d5			;# blocks
	tst.l	d6
	beq.s	se_write

	move.l	d4,d0
	move.l	d5,d1
	move.l	d6,a0
	bsr.w	_Write			;use CFA_ERASE_SECTORS
	cmp.l	d0,d5
	beq.s	se_swath

	moveq.l	#2,d0
	swap	d0
	moveq.l	#MEMF_CLEAR>>16,d1
	swap	d1
	or.l	BufMemType(a4),d1
	CALLEXEC AllocMem
	move.l	d0,a3
	tst.l	d0
	beq.s	se_stop			;no zero buffer
se_write:
	moveq.l	#0,d6
	moveq.l	#17,d0
	sub.w	BlockShift(a4),d0
	moveq.l	#0,d1
	bset	d0,d1			;blocks/buffer
	cmp.l	d1,d5
	bcc.s	se_w1

	move.l	d5,d1
se_w1:
	move.l	d1,-(sp)
	move.l	d4,d0
	move.l	a3,a0
	bsr.w	_Write			;zero fill
	move.l	(sp)+,d1
	cmp.l	d0,d1
	bne.s	se_stop

	add.l	d1,d4
	sub.l	d1,d5
	bgt.s	se_write
	bra.w	se_swath
se_done:

;- - all done! - - - - - - - - - - - - - - - - - - - - - - -

se_stop:
	move.l	a3,d0
	beq.s	se_update

	moveq.l	#2,d0
	swap	d0
	move.l	a3,a1
	CALLEXEC FreeMem
se_update:
	pea	(-1).w
	bsr.w	UpdateDisk
	addq.l	#4,sp
	move.l	SD_WINDOW(a5),d0
	beq.s	se_end

	move.l	d0,a0
	CALLINT	CloseWindow
se_end:
	movem.l	(sp)+,d2-d6/a2-a3
	unlk	a5
	rts

;--- check and repair file system --------------------------
; d0 -> # errors or -1

;temporary UBYTE[numOfClusters]: bit...
;	0 = "last,.."
;	1 = "..used,.."
;	2 = "..first Cluster of a chain"
;	3 = "Cluster claimed by a file or dir"

ScanDisk:
	link.w	a5,#SD_STRINGBUF
	movem.l	d2-d7/a2-a3,-(sp)
	lea	SD_ERRORS(a5),a1
	clr.l	(a1)
	clr.l	-(a1)
	clr.l	-(a1)
	clr.l	-(a1)
	clr.l	-(a1)
	clr.l	-(a1)
	move.l	LastCluster(a4),d3
	addq.l	#1,d3
	move.l	d3,SD_CLUSTERS(a5)
	clr.l	SD_DONE(a5)
	move.l	d3,d0
	move.l	#MEMF_CLEAR,d1
	CALLEXEC AllocMem
	move.l	d0,a3
	tst.l	d0
	beq.w	sd_nomem

;- - open progresss window - - - - - - - - - - - - - - - - -

	move.l	d3,d0
	LOG2
	subq.w	#6,d0			;update progress bar in 64..
	moveq.l	#0,d1
	bset	d0,d1
	subq.l	#1,d1
	move.l	d1,SD_STEPMASK(a5)	;..steps
	bsr.w	OpenProgWindow
	move.l	d0,SD_WINDOW(a5)
	bsr.w	sd_initwingfx

;- - a forest hike - - - - - - - - - - - - - - - - - - - - -

	move.l	UIText+9*4(a4),a0
	bsr.w	sd_text
	moveq.l	#0,d7			;root level
	moveq.l	#0,d6			;parent link to root always 0
	move.l	RootCluster(a4),d0
	bra.s	sd_tstart
sd_tcluster:
	move.l	d0,d6			;dir Cluster #
sd_tstart:
	cmp.w	#KEY_ESC,SD_LASTKEY(a5)
	beq.w	sd_tabort		;user stop

	bsr.w	sd_getchain
	move.l	d6,d0
	bsr.w	Cluster2Block
	move.l	d0,d5			;dir Block #
	moveq.l	#0,d4			;Offset
sd_tblock:
	move.l	d5,d0
	beq.w	sd_tup			;end of chain

	bsr.w	ReadDirBlock
	tst.l	d0
	beq.w	sd_tup			;read error

	move.l	d0,a2
	add.l	d4,a2			;&dir entry
	move.l	a0,SD_BLOCKBUF(a5)
sd_tentry:
	move.b	(a2),d0
	beq.w	sd_tup			;end of dir

	cmp.b	#MSDEB_DELETED,d0
	beq.w	sd_tenext		;deleted

	moveq.l	#$3f,d1
	and.b	MSDE_Flags(a2),d1
	cmp.b	#$0f,d1
	beq.w	sd_tenext		;a long name entry

	btst	#3,d1
	bne.w	sd_tenext		;Disk name entry

	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	sd_t1

	move.w	MSDE_1H(a2),d0
	ReverseW d0
	swap	d0
sd_t1:
	move.w	MSDE_1L(a2),d0
	ReverseW d0			;link cluster #
	btst	#4,d1
	beq.s	sd_tfile

	cmp.b	#'.',(a2)
	bne.s	sd_tuserdir

	cmp.b	#'.',1(a2)
	beq.s	sd_tbacklink

	cmp.l	d6,d0
	beq.w	sd_tenext		;self link OK

	move.l	d6,d1
	bra.s	sd_tsetchain
sd_tuserdir:				;turn subdirs..
	cmp.l	RootCluster(a4),d0
	beq.s	sd_tudfix

	moveq.l	#2,d1
	cmp.l	d1,d0
	bcs.s	sd_tudfix		;..with too small or..

	cmp.l	d3,d0			;..too large cluster #..
	bcs.w	sd_tdown
sd_tudfix:
	clr.l	MSDE_FSize(a2)		;..into empty..
	and.b	#$ef,MSDE_Flags(a2)	;..files
	moveq.l	#0,d1
	bra.s	sd_tsetchain
sd_tbacklink:
	tst.l	d7
	beq.s	sd_tenext		;irrelevant in root dir

	move.l	8(sp),d1
	cmp.l	d1,d0
	beq.s	sd_tenext		;parent link OK
sd_tsetchain:
	addq.l	#1,SD_VOIDLINKS(a5)
	ReverseW d1
	move.w	d1,MSDE_1L(a2)
	tst.w	FATType(a4)
	bpl.s	sd_tupdate

	swap	d1
	ReverseW d1
	move.w	d1,MSDE_1H(a2)
	bra.s	sd_tupdate
sd_tfile:
	move.l	MSDE_FSize(a2),d2
	move.l	d2,d1
	or.l	d0,d1
	beq.s	sd_tf1			;leere file without cluster chain OK

	cmp.l	RootCluster(a4),d0
	beq.s	sd_tudfix

	moveq.l	#2,d1
	cmp.l	d1,d0
	bcs.s	sd_tudfix		;cluster # too small..

	cmp.l	d3,d0			;..or too large
	bcc.s	sd_tudfix
sd_tf1:
	bsr.w	sd_getchain
	move.w	BlockShift(a4),d1
	add.w	ClusterShift(a4),d1
	ReverseL d2
	add.l	ClusterMask(a4),d2
	lsr.l	d1,d2
	cmp.l	d2,d0
	beq.s	sd_tenext		;file length fits

	lsl.l	d1,d0
	ReverseL d0
	move.l	d0,MSDE_FSize(a2)
	addq.l	#1,SD_FILESIZES(a5)
sd_tupdate:
	move.l	SD_BLOCKBUF(a5),a0
	move.l	a2,d0
	bsr.w	BlockChanged
sd_tenext:
	moveq.l	#MSDE_Sizeof,d0
	add.l	d0,a2
	add.w	d0,d4
	cmp.w	BlockSize(a4),d4
	bcs.w	sd_tentry
sd_tbnext:
	moveq.l	#0,d4
	move.l	d5,d0
	bsr.w	NextBlock
	move.l	d0,d5
	bra.w	sd_tblock

sd_tdown:
	tst.l	MSDE_FSize(a2)		;dirs should have..
	beq.s	sd_td1

	clr.l	MSDE_FSize(a2)		;..no file length
	move.l	SD_BLOCKBUF(a5),a0
	move.l	a2,d0
	bsr.w	BlockChanged
	addq.l	#1,SD_FILESIZES(a5)
sd_td1:
	moveq.l	#50,d1
	cmp.l	d1,d7
	bcc.s	sd_tenext		;stack overflow

	addq.l	#1,d7
	movem.l	d4-d6,-(sp)
	bra.w	sd_tcluster		;enter sub dir

sd_tup:
	subq.l	#1,d7
	bmi.s	sd_fatscan		;all done!

	movem.l	(sp)+,d4-d6		;resume parent dir
	add.w	#MSDE_Sizeof,d4
	cmp.w	BlockSize(a4),d4
	bcs.w	sd_tblock
	bra.s	sd_tbnext

sd_tabort:
	subq.l	#1,d7
	bmi.w	sd_abort

	movem.l	(sp)+,d4-d6		;clean up stack
	bra.s	sd_tabort

;- - analyze FAT - - - - - - - - - - - - - - - - - - - - - -

sd_fatscan:
	move.l	UIText+10*4(a4),a0
	bsr.w	sd_text
	move.l	a3,a2
	addq.l	#2,a2
	moveq.l	#2,d2
sd_fcluster:
	cmp.w	#KEY_ESC,SD_LASTKEY(a5)
	beq.w	sd_abort		;user stop

	move.b	(a2),d4
	btst	#3,d4
	bne.s	sd_fnext		;already registered

	addq.l	#1,SD_DONE(a5)
	move.l	d2,d0
	bsr.w	GetFATEntry
	move.l	d0,d5			;link..
	beq.s	sd_ffree
	bmi.s	sd_flast

	moveq.l	#2,d1
	cmp.l	d1,d0
	bcs.s	sd_fcut			;..outside..

	cmp.l	d3,d0
	bcc.s	sd_fcut			;..data area..

	cmp.l	d2,d0
	beq.s	sd_fcut			;..or to self

	move.l	a3,a0
	add.l	d0,a0
	move.b	(a0),d0
	beq.s	sd_f1			;get chain at end..

	moveq.l	#%1100,d1
	and.b	d0,d1
	cmp.b	#%0100,d1		;..or at start..
	bne.s	sd_fcut			;already in use
sd_f1:
	and.b	#%1011,d0		;..enlarged
	or.b	#%0010,d0
	move.b	d0,(a0)
	moveq.l	#%0110,d0
	bra.s	sd_fused
sd_ffree:
	tst.b	d4
	beq.s	sd_fnext		;a free cluster

	subq.l	#1,FreeClusters(a4)
sd_fcut:
	move.l	d2,d0
	moveq.l	#-1,d1
	bsr.w	PutFATEntry		;terminate chain here
sd_flast:
	moveq.l	#%0111,d0
sd_fused:
	addq.l	#1,SD_LOSTCLUSTERS(a5)
	tst.b	d4
	beq.s	sd_f2			;if its referenced,..

	and.b	#%0011,d0		;..its no start cluster
sd_f2:
	move.b	d0,(a2)
sd_fnext:
	addq.l	#1,a2
	addq.l	#1,d2
	move.l	SD_STEPMASK(a5),d0
	and.l	d2,d0
	bne.s	sd_fn2			;from time to time..

	bsr.w	sd_bar			;..update progress bar
sd_fn2:
	cmp.l	d3,d2
	bcs.w	sd_fcluster

;- - salvage lost cluster chains - - - - - - - - - - - - - -

	move.l	UIText+11*4(a4),a0
	bsr.w	sd_text
	sub.w	#20,sp
	move.l	sp,d2
	addq.l	#3,d2
	lsr.l	#2,d2			;BPTR_BSTR file name
	move.l	d2,d0
	lsl.l	#2,d0
	move.l	d0,a1
	move.l	#12<<24+"fil",(a1)+
	move.l	#"e000",(a1)+
	move.l	#"/.ch",(a1)+		;'/'='0'-1
	move.w	#"k"<<8,(a1)		;preset filename
	moveq.l	#2,d4
	move.l	a3,a2
	addq.l	#2,a2
sd_lostsearch:
	moveq.l	#%1100,d0
	and.b	(a2)+,d0
	cmp.b	#%0100,d0
	bne.w	sd_lsnext

	move.l	d4,d5
	moveq.l	#0,d6
sd_lscluster:
	addq.l	#1,d6
	move.l	d5,d0
	bsr.w	GetFATEntry		;get chain length
	move.l	d0,d5
	bgt.s	sd_lscluster
sd_lsname:
	move.l	d2,d0
	lsl.l	#2,d0
	addq.l	#8,d0
	move.l	d0,a1			;&last digit in file name
sd_lsbump:
	move.b	(a1),d0
	addq.b	#1,d0			;Name: bump #..
	move.b	d0,(a1)
	cmp.b	#'9'+1,d0
	bcs.s	sd_lsfile		;..and retry

	move.b	#'0',(a1)
	subq.l	#1,a1
	bra.s	sd_lsbump		;carry to next digit
sd_lsfile:
	pea	CREATE_MODE&EXCLUSIVE_LOCK
	move.l	d2,-(sp)
	clr.l	-(sp)			;into root dir
	bsr.w	LocateObj
	add.w	#12,sp
	tst.l	d0
	beq.s	sd_lswrite

	move.l	d0,a1
	bsr.w	CloseXLock		;if file name already used..
	bra.s	sd_lsname		;..try next #
sd_lswrite:
	move.l	NewObject(a4),d5
	beq.s	sd_lsnext

	addq.l	#1,SD_LOSTCHAINS(a5)
	add.l	d6,SD_LOSTCLUSTERS(a5)	;chain length in Clusters..
	move.l	d5,a1			;&XLock
	move.w	BlockShift(a4),d1
	add.w	ClusterShift(a4),d1
	lsl.l	d1,d6			;..and in Bytes
	move.l	d6,XL_MSDE+MSDE_FSize(a1)
	move.w	d4,XL_MSDE+MSDE_1L(a1)	;write..
	tst.w	FATType(a4)
	bpl.s	sd_lsclose

	swap	d4
	move.w	d4,XL_MSDE+MSDE_1H(a1)	;..chain start
	swap	d4
sd_lsclose:
	move.l	d5,a0
	add.w	#XL_MSDE,a0
	bsr.w	WriteMSDE
	move.l	d5,a1
	bsr.w	CloseXLock
sd_lsnext:
	addq.l	#1,d4
	cmp.l	d3,d4
	bcs.w	sd_lostsearch
sd_lsbreak:
	add.w	#20,sp

;- - all done! - - - - - - - - - - - - - - - - - - - - - - -

sd_abort:
	pea	(-1).w
	bsr.w	UpdateDisk
	addq.l	#4,sp
	lea	SD_ERRORS(a5),a1
	move.l	-(a1),d1
	add.l	-(a1),d1
	add.l	-(a1),d1
	add.l	-(a1),d1
	move.l	UIText+13*4(a4),a0
	move.l	d1,SD_ERRORS(a5)
	beq.s	sd_ready

	move.l	UIText+12*4(a4),a0
sd_ready:
	move.l	d1,-(sp)
	pea	SD_STRINGBUF(a5)
	move.l	a0,-(sp)
	bsr.w	SPrintF
	add.w	#12,sp
	lea	SD_STRINGBUF(a5),a0
	bsr.w	sd_text
	move.l	TimeRequest(a4),a1
	CALLEXEC WaitIO			;get back TimeRequest
	move.l	TimeRequest(a4),a1
	move.w	#TR_ADDREQUEST,IO_Command(a1)
	moveq.l	#3,d0
	move.l	d0,TR_Seconds(a1)	;wait 3 seconds
	clr.l	TR_Micros(a1)
	CALLEXEC DoIO
	move.l	TimeRequest(a4),a1
	move.b	#IOF_QUICK,IO_Flags(a1)	;protect against double WaitIO()
	move.l	SD_WINDOW(a5),d0
	beq.s	sd_freebuf

	move.l	d0,a0
	CALLINT	CloseWindow
sd_freebuf:
	move.l	d3,d0
	move.l	a3,a1
	CALLEXEC FreeMem
sd_nomem:
	move.l	SD_ERRORS(a5),d0
	bgt.s	sd_end

	moveq.l	#TRUE,d0
sd_end:
	movem.l	(sp)+,d2-d7/a2-a3
	unlk	a5
	rts

;- - follow and analyze cluster chain  - - - - - - - - - - -
; d0 <- start cluster #
; d3 <- # clusters
; a3 <- &analyze buffer
; a5 <- &ScanDisk vars
; d0 -> chain length

sd_getchain:
	movem.l	d2/d4,-(sp)
	moveq.l	#0,d4			;chain length
	move.l	d0,d2			;Cluster #
	beq.s	sd_gcend		;no chain
sd_gcloop:
	tst.l	d0
	bmi.s	sd_gclast		;normal end
	beq.s	sd_gcadd		;open end

	moveq.l	#2,d1
	cmp.l	d1,d0
	bcs.s	sd_gccut		;outside..

	cmp.l	d3,d0
	bcc.s	sd_gccut		;..data area

	move.l	a3,a0
	add.l	d0,a0
	tst.b	(a0)
	bne.s	sd_gccut		;used twice

	moveq.l	#%1010,d1
	tst.l	d4
	bne.s	sd_gc1

	moveq.l	#%1110,d1
sd_gc1:	
	move.b	d1,(a0)
	addq.l	#1,d4
	move.l	d0,d2
	bsr.w	GetFATEntry
	bra.s	sd_gcloop
sd_gclast:
	tst.l	d4
	beq.s	sd_gcend
sd_gcstop:
	move.l	a3,a0
	add.l	d2,a0
	or.b	#%1011,(a0)
sd_gcend:
	add.l	d4,SD_DONE(a5)
	bsr.w	sd_bar			;update progress bar
	move.l	d4,d0
	movem.l	(sp)+,d2/d4
	rts

sd_gcadd:
	addq.l	#1,SD_OPENCHAINS(a5)
	subq.l	#1,FreeClusters(a4)
	addq.l	#1,d4
	bra.s	sd_gctail
sd_gccut:
	addq.l	#1,SD_VOIDLINKS(a5)
	tst.l	d4
	beq.s	sd_gcend
sd_gctail:
	move.l	d2,d0
	moveq.l	#-1,d1
	bsr.w	PutFATEntry
	bra.s	sd_gcstop

;- - open progress window  - - - - - - - - - - - - - - - - -
; a5 <- &ScanDisk vars
; d0 -> &Window or 0

OPW_FLAG1 = WFLG_DRAGBAR+WFLG_DEPTHGADGET+WFLG_CLOSEGADGET+WFLG_SMART_REFRESH
OPW_FLAGS = OPW_FLAG1+WFLG_ACTIVATE

OpenProgWindow:
	movem.l	d2-d6,-(sp)
	move.l	IntBase(a4),a6
	cmp.w	#36,LIB_Version(a6)
	bcs.w	opw_error		;needed for OpenWindowTagList() etc.

	moveq.l	#0,d6			;flags
	move.l	DosPacket(a4),d0
	beq.s	opw_default		;no order

	move.l	d0,a0
	move.l	DP_MsgPort(a0),a0
	moveq.l	#3,d0
	and.b	MP_Flags(a0),d0
	bne.s	opw_default		;unknown client

	move.l	MP_SigTask(a0),a0
	cmp.b	#NT_PROCESS,LN_Type(a0)
	bne.s	opw_default		;plain Task, no Process struct

	move.l	184(a0),d0		;&parent window
	beq.s	opw_default

	moveq.l	#-1,d1
	cmp.l	d0,d1
	beq.s	opw_default		;Process wants no DOS requesters

	move.l	d0,a0
	move.l	WIN_Screen(a0),d0
	bra.s	opw_screen
opw_default:
	moveq.l	#1,d6
	sub.l	a0,a0
	CALLINT	LockPubScreen
opw_screen:
	move.l	d0,d4
	beq.w	opw_error

	move.l	d0,a0			;&Screen
	lea	SCR_RastPort(a0),a1
	move.l	sp,d5
	clr.l	-(sp)			;TAG_DONE
	move.l	#OPW_FLAGS,-(sp)
	move.l	#WA_Flags,-(sp)
	move.l	#IDCMP_CLOSEWINDOW+IDCMP_VANILLAKEY,-(sp)
	move.l	#WA_IDCMP,-(sp)
	moveq.l	#1,d3
	add.b	SCR_WBorTop(a0),d3
	add.b	SCR_WBorBottom(a0),d3
	add.w	RP_TxHeight(a1),d3
	moveq.l	#5,d0
	mulu.w	RP_TxHeight(a1),d0
	add.l	d0,d3
	move.l	d3,-(sp)
	move.l	#WA_Height,-(sp)
	moveq.l	#80,d2
	lsl.l	#2,d2
	move.l	d2,-(sp)
	move.l	#WA_Width,-(sp)
	moveq.l	#0,d0
	move.w	SCR_Height(a0),d0
	sub.w	d3,d0
	lsr.w	#1,d0
	move.l	d0,-(sp)
	move.l	#WA_Top,-(sp)
	move.w	SCR_Width(a0),d0
	sub.w	d2,d0
	lsr.w	#1,d0
	move.l	d0,-(sp)
	move.l	#WA_Left,-(sp)
	move.l	a0,-(sp)
	move.l	#WA_CustomScreen,-(sp)
	lea	SD_TITLE(a5),a1
	move.l	a1,-(sp)
	move.l	DeviceNode(a4),a0
	move.l	DOL_Name(a0),d0
	lsl.l	#2,d0
	addq.l	#1,d0
	move.l	d0,a0
	bsr.w	StrCopy
	lea	opw_minus(pc),a0
	bsr.w	StrCopy
	move.l	UIText+4*15(a4),a0
	bsr.w	StrCopy
	move.l	#WA_Title,-(sp)
	sub.l	a0,a0
	move.l	sp,a1
	CALLINT	OpenWindowTagList
	move.l	d0,d2			;&Window
	move.l	d5,sp
	tst.w	d6
	beq.s	opw_1

	sub.l	a0,a0
	move.l	d4,a1
	CALLINT	UnlockPubScreen
opw_1:
	move.l	d2,d0
opw_end:
	movem.l	(sp)+,d2-d6
	rts

opw_error:
	moveq.l	#0,d0
	bra.s	opw_end

opw_minus:
	dc.b	": - ",0
	even

;- - init progress gfx - - - - - - - - - - - - - - - - - - -

sd_initwingfx:
	movem.l	d2-d4,-(sp)
	clr.l	SD_LASTQUAL(a5)
	move.l	SD_WINDOW(a5),d0
	beq.w	sdiwg_end		;no window

	move.l	d0,a0
	move.l	WIN_RastPort(a0),a1
	move.l	WIN_Screen(a0),a0
	move.l	SCR_RastPort+RP_Font(a0),d0
	beq.s	sdiwg_1

	move.l	d0,a0
	CALLGRAF SetFont
sdiwg_1:
	move.l	SD_WINDOW(a5),a0
	move.l	WIN_RastPort(a0),a1
	move.l	a1,SD_RASTPORT(a5)
	moveq.l	#10,d0
	add.b	WIN_BorderLeft(a0),d0
	move.w	d0,SD_TEXTX(a5)
	move.w	d0,SD_BARX(a5)
	moveq.l	#-10,d1
	sub.b	WIN_BorderRight(a0),d1
	sub.w	d0,d1
	add.w	WIN_Width(a0),d1
	move.w	d1,SD_TEXTWIDTH(a5)
	move.w	d1,SD_BARWIDTH(a5)
	move.w	RP_TxHeight(a1),d1
	move.w	d1,SD_TEXTHEIGHT(a5)
	move.w	d1,SD_BARHEIGHT(a5)
	moveq.l	#0,d0
	move.b	WIN_BorderTop(a0),d0
	add.w	d1,d0
	move.w	d0,SD_TEXTY(a5)
	lsl.w	#1,d1
	add.w	d1,d0
	move.w	d0,SD_BARY(a5)
	clr.w	SD_BARPOS(a5)
	moveq.l	#0,d2
	move.w	#$0101,d4
	move.l	WIN_Screen(a0),a0
	CALLINT	GetScreenDrawInfo
	tst.l	d0
	beq.s	sdiwg_2

	move.l	d0,a0			;&DrawInfo
	move.l	DRI_Pens(a0),a1
	move.b	SHINEPEN(a1),d2
	lsl.w	#8,d2
	move.b	SHADOWPEN(a1),d2
	swap	d2
	move.b	FILLTEXTPEN+1(a1),d2
	lsl.w	#8,d2
	move.b	BACKGROUNDPEN+1(a1),d2
	move.b	FILLPEN+1(a1),d4
	lsl.w	#8,d4
	move.b	TEXTPEN+1(a1),d4
	move.l	SD_WINDOW(a5),a0
	move.l	WIN_Screen(a0),a0
	CALLSAME FreeScreenDrawInfo
sdiwg_2:
	move.l	d2,SD_C3(a5)
	move.w	d4,SD_C4(a5)
sdiwg_end:
	movem.l	(sp)+,d2-d4
	rts

;- - print UI Text - - - - - - - - - - - - - - - - - - - - -
; a0 <- &Text
; a5 <- &ScanDisk vars

sd_text:
	tst.l	SD_WINDOW(a5)
	beq.s	sdt_end

	movem.l	d2-d4/a2,-(sp)
	move.l	a0,d4			;&Text
	move.l	SD_RASTPORT(a5),a2
	move.l	a2,a1
	moveq.l	#0,d0
	move.b	SD_C0(a5),d0
	CALLGRAF SetAPen
	lea	SD_TEXTX(a5),a0
	move.w	(a0)+,d0
	move.w	(a0)+,d1
	move.w	d0,d2
	add.w	(a0)+,d2
	subq.w	#1,d2
	move.w	d1,d3
	add.w	(a0),d3
	subq.w	#1,d3
	move.l	a2,a1
	CALLSAME RectFill
	move.l	a2,a1
	moveq.l	#0,d0
	move.b	SD_C1(a5),d0
	CALLSAME SetAPen
	move.l	a2,a1
	move.w	SD_TEXTX(a5),d0
	move.w	SD_TEXTY(a5),d1
	add.w	RP_TxBaseline(a1),d1
	CALLSAME Move
	move.l	a2,a1
	move.l	d4,a0
	bsr.w	StrLen
	CALLSAME Text
	movem.l	(sp)+,d2-d4/a2
sdt_end:
	rts

;- - progress bar  - - - - - - - - - - - - - - - - - - - - -
; a5 <- &ScanDisk vars

sd_bar:
	movem.l	d2-d3,-(sp)
	tst.l	SD_WINDOW(a5)
	beq.w	sdb_end

	moveq.l	#0,d0
	move.w	SD_BARWIDTH(a5),d0
	move.l	SD_DONE(a5),d1
	UMUL32
	move.l	SD_CLUSTERS(a5),d1
	UDIVMOD32
	move.w	d0,d2
	move.w	SD_BARPOS(a5),d0
	cmp.w	d0,d2
	beq.w	sdb_end			;nothing to do

	move.l	SD_RASTPORT(a5),a1
	moveq.l	#0,d0
	move.b	SD_C4(a5),d0
	CALLGRAF SetAPen
	move.w	SD_BARPOS(a5),d0
	move.w	d2,SD_BARPOS(a5)
	move.w	SD_BARX(a5),d1
	add.w	d1,d0
	add.w	d1,d2
	subq.w	#1,d2
	move.w	SD_BARY(a5),d1
	move.w	d1,d3
	add.w	SD_BARHEIGHT(a5),d3
	subq.w	#1,d3
	move.l	SD_RASTPORT(a5),a1
	CALLSAME RectFill
	move.l	SD_WINDOW(a5),a0
	move.l	WIN_UserPort(a0),d2
	beq.s	sdb_end			;no message port
sdb_msg:
	move.l	d2,a0
	CALLEXEC GetMsg
	tst.l	d0
	beq.s	sdb_end			;no messages

	move.l	d0,a1			;&IntuiMessage
	move.w	IM_Qualifier(a1),d0
	move.w	d0,SD_LASTQUAL(a5)
	moveq.l	#KEY_ESC,d0
	move.l	IM_Class(a1),d1
	cmp.l	#IDCMP_CLOSEWINDOW,d1
	beq.s	sdb_key

	cmp.l	#IDCMP_VANILLAKEY,IM_Class(a1)
	bne.s	sdb_reply

	move.w	IM_Code(a1),d0
sdb_key:
	move.w	d0,SD_LASTKEY(a5)	;remember user keypresses
sdb_reply:
	CALLEXEC ReplyMsg
	bra.s	sdb_msg
sdb_end:
	movem.l	(sp)+,d2-d3
	rts

;--- make new dir ------------------------------------------
; <- struct XLock *BaseDir, BPTR_BSTR Name;
; -> struct XLock *NewDir or 0;

MakeDir:
	link.w	a5,#0
	move.l	a2,-(sp)
	pea	CREATE_MODE&SHARED_LOCK
	move.l	12(a5),-(sp)
	move.l	8(a5),-(sp)
	bsr.w	LocateObj
	add.w	#12,sp
	move.l	d0,a2
	tst.l	d0
	bne.s	md_close

	move.l	NewObject(a4),a2
	move.l	a2,d0
	bne.s	md_init

	cmp.w	#202,ErrorNum(a4)	;"in use"..
	beq.s	md_exists
	bra.s	md_end
md_init:
	move.l	a2,-(sp)
	bsr.w	ExtendDir		;init new dir
	addq.w	#4,sp
	tst.l	d0
	beq.s	md_delete

	move.b	#$30,XL_MSDE+MSDE_Flags(a2)
	lea	XL_MSDE(a2),a0
	bsr.w	WriteMSDE
md_end:
	move.l	a2,d0
	move.l	(sp)+,a2
	unlk	a5
	rts

md_close:
	move.l	a2,a1
	bsr.w	CloseXLock
	sub.l	a2,a2
md_exists:
	move.w	#203,ErrorNum(a4)	;..also means "exists already"
	bra.s	md_end

md_delete:
	move.l	a2,a1
	bsr.w	CloseXLock
	sub.l	a2,a2
	move.l	12(a5),-(sp)
	move.l	8(a5),-(sp)
	bsr.w	DeleteObj
	addq.l	#8,sp
	bra.s	md_end

;--- move and/or rename object -----------------------------
; <- struct XLock *OldBaseDir, BPTR_BSTR OldName,
;    struct XLock *NewBaseDir, BPTR_BSTR NewName;
; -> BOOL ok;

ROB_RESULT	= -4

RenameObj:
	link.w	a5,#ROB_RESULT
	movem.l	d2/a2-a3,-(sp)
	clr.l	ROB_RESULT(a5)		;"FALSE"

	pea	(SHARED_LOCK).w
	move.l	12(a5),-(sp)
	move.l	8(a5),-(sp)
	bsr.w	LocateObj
	add.w	#12,sp
	move.l	d0,a2
	tst.l	d0
	beq.w	rob_end			;source not found

	tst.l	XL_Parent(a2)
	beq.w	rob_freesrc		;the root stays here!!

	move.l	a2,-(sp)		;if target = source,..
	pea	FORCE_MODE&SHARED_LOCK	;..enforce creating..
	move.l	20(a5),-(sp)
	move.l	16(a5),-(sp)
	bsr.w	LocateObj		;..a new entry
	add.w	#16,sp
	move.l	d0,a3
	tst.l	d0
	beq.s	rob_create

	move.w	#203,ErrorNum(a4)	;"target already exists"
	bra.w	rob_freedest

rob_create:
	move.l	NewObject(a4),d0
	beq.w	rob_freesrc		;target not allocated

	move.l	d0,a3			;&new target
rob_ploop:
	move.l	d0,a0
	move.l	XL_Parent(a0),d0	;dont move target into any of the..
	beq.s	rob_copyback

	cmp.l	a2,d0			;..sources parents!!!
	bne.s	rob_ploop

	move.l	a3,a0
	bsr.w	DeleteXLock
	move.w	#202,ErrorNum(a4)	;move dir into self?!
	bra.w	rob_freedest

rob_copyback:
	move.l	a2,a0
	bsr.w	DeleteXLock		;delete old object

	lea	XL_MSDE(a3),a0
	lea	XL_MSDE(a2),a1
	move.l	(a0)+,(a1)+
	move.l	(a0)+,(a1)+
	move.w	(a0)+,(a1)+
	move.b	(a0)+,(a1)+		;copy new values: standard name,..

	lea	XL_Key(a3),a0
	lea	XL_Key(a2),a1
	moveq.l	#XL_Sizeof-XL_Key,d0
rob_cbloop:
	move.l	(a0)+,(a1)+		;..position pointer, full name
	subq.w	#4,d0
	bgt.s	rob_cbloop

	move.l	XL_Parent(a2),d0
	cmp.l	XL_Parent(a3),d0
	beq.s	rob_write		;rename only. no move

	move.l	d0,a1
	bsr.w	CloseXLock
	move.l	XL_Parent(a3),XL_Parent(a2) ;change parent dir
	clr.l	XL_Parent(a3)
	btst	#4,XL_MSDE+MSDE_Flags(a2)
	beq.s	rob_write		;move file

	moveq.l	#0,d0
	tst.w	FATType(a4)
	bpl.s	rob_1

	move.w	XL_MSDE+MSDE_1H(a2),d0
	swap	d0
rob_1:
	move.w	XL_MSDE+MSDE_1L(a2),d0
	bsr.w	Cluster2Block
	bsr.w	ReadDirBlock		;in 1st block of..
	move.l	d0,d2			;..dir to be moved..
	beq.s	rob_write

	move.l	d2,a1
	cmp.w	#"..",MSDE_Sizeof(a1)	;..adjust the internal back link..
	bne.s	rob_closeblock

	bsr.w	BlockChanged
	move.l	XL_Parent(a2),a0	;..to parent..
	add.w	#XL_MSDE+MSDE_unused1,a0
	move.l	d2,a1
	add.w	#MSDE_Sizeof+MSDE_unused1,a1
	bsr.w	R2CopyMSDE		;..dir
rob_closeblock:

rob_write:
	bset	#5,XL_MSDE+MSDE_Flags(a2) ;clear archive bit
	lea	XL_MSDE(a2),a0
	bsr.w	WriteMSDE
	moveq.l	#TRUE,d0
	move.l	d0,ROB_RESULT(a5)

rob_freedest:
	move.l	a3,a1
	bsr.w	CloseXLock
rob_freesrc:
	move.l	a2,a1
	bsr.w	CloseXLock
rob_end:
	move.l	ROB_RESULT(a5),d0
	movem.l	(sp)+,d2/a2-a3
	unlk	a5
	rts

;*** user communication ************************************
;--- report error ------------------------------------------
; <- LONG cmd<<16+error_code, char *format, ULONG block_number;
; -> 0 (abort), 1 (repeat);

DREQ_BUF	= -80
DREQ_POSTEXT	= DREQ_BUF-IT_Sizeof
DREQ_NEGTEXT	= DREQ_POSTEXT-IT_Sizeof
DREQ_TEXT1	= DREQ_NEGTEXT-IT_Sizeof
DREQ_TEXT2	= DREQ_TEXT1-IT_Sizeof

DoRequest:
	link.w	a5,#DREQ_TEXT2
	move.l	a2,-(sp)
	sub.l	a2,a2			;default: no parent window
	move.l	DosPacket(a4),d0
	beq.s	dreq_case		;no order

	move.l	d0,a0
	move.l	DP_MsgPort(a0),a0
	moveq.l	#3,d0
	and.b	MP_Flags(a0),d0
	bne.s	dreq_case		;unknown client

	move.l	MP_SigTask(a0),a0
	cmp.b	#NT_PROCESS,LN_Type(a0)
	bne.s	dreq_case		;plain Task, no Process struct

	move.l	184(a0),a2		;&parent window
	moveq.l	#-1,d0
	cmp.l	d0,a2
	beq.w	dreq_abort		;Process wants no DOS requesters
dreq_case:
	move.l	8(a5),d0
	cmp.b	#TDERR_DISKCHANGED,d0
	bne.s	dreq_readerr

	cmp.b	#2,NoRequest(a4)	;disk recognition: drive still empty
	bcc.w	dreq_abort		;(scsi.device 43.35 bug)

	pea	LastVolName(a4)
	pea	DREQ_BUF(a5)
	move.l	UIText+3*4(a4),-(sp)
	bsr.w	SPrintF			;"please reinsert disk"
	add.w	#12,sp
	bra.s	dreq_req

dreq_readerr:
	tst.b	NoRequest(a4)		;during disk recognition..
	bne.w	dreq_abort		;..dont report read errors

	move.l	16(a5),-(sp)
	ext.w	d0
	ext.l	d0
	move.l	d0,-(sp)
	move.l	DeviceNode(a4),a0
	move.l	DOL_Name(a0),d1
	lsl.l	#2,d1
	addq.l	#1,d1
	move.l	d1,-(sp)
	pea	DREQ_BUF(a5)
	move.l	12(a5),-(sp)
	bsr.w	SPrintF			;"read error"
	add.w	#20,sp

dreq_req:
	lea	DREQ_BUF(a5),a0
	move.l	a0,DREQ_TEXT1+IT_String(a5)
	moveq.l	#0,d1
dreq_rl:
	moveq.l	#-LF-1,d0		;at first newline..
	add.b	(a0)+,d0
	bcs.s	dreq_rl

	addq.b	#1,d0
	bne.s	dreq_r1

	move.l	a0,d1
	clr.b	-(a0)			;..split
dreq_r1:
	move.l	d1,DREQ_TEXT2+IT_String(a5)
	move.l	UIText(a4),DREQ_NEGTEXT+IT_String(a5)
	move.l	UIText+2*4(a4),DREQ_POSTEXT+IT_String(a5)
	lea	DREQ_TEXT2(a5),a1
	moveq.l	#4,d1
dreq_r2:
	move.l	#$00010100,(a1)+
	addq.l	#4,a1
	clr.l	(a1)+
	addq.l	#4,a1
	clr.l	(a1)+
	subq.w	#1,d1
	bgt.s	dreq_r2

	lea	DREQ_TEXT2(a5),a0
	move.l	a0,DREQ_TEXT1+IT_Next(a5)
	move.l	#6<<16+3,d0
	move.l	d0,DREQ_POSTEXT+IT_X(a5)
	move.l	d0,DREQ_NEGTEXT+IT_X(a5)
	move.l	#16<<16+5,DREQ_TEXT1+IT_X(a5)
	move.l	#16<<16+15,DREQ_TEXT2+IT_X(a5)

dreq_repeat:
	pea	64.w			;height
	pea	320.w			;width
	clr.l	-(sp)
	clr.l	-(sp)
	pea	DREQ_NEGTEXT(a5)
	pea	DREQ_POSTEXT(a5)
	pea	DREQ_TEXT1(a5)		;&request text
	move.l	a2,-(sp)		;&parent window
	bsr.w	_AutoRequest
	add.w	#32,sp
	cmp.b	#TDERR_DISKCHANGED,8+3(a5)
	bne.s	dreq_end		;"normal" read error

	tst.l	d0
	beq.s	dreq_end		;user took "abort"

	bsr.w	DiskStatus
	tst.w	d0
	beq.s	dreq_repeat		;disk still not inserted

	move.l	d0,-(sp)
	bsr.w	DiskClear
	bsr.w	DiskChangeNum
	clr.w	DiskChanged(a4)
	move.l	(sp)+,d0
dreq_end:
	move.l	(sp)+,a2
	unlk	a5
	rts

dreq_abort:
	moveq.l	#0,d0			;if requester cannot be displayed..
	bra.s	dreq_end		;..assume "abort"

;--- check whether TD64 is needed and available ------------
; d0 <- Block #
; d0 -> BOOL ok

Test64:
	cmp.l	#1<<(32-9),d0
	bcs.s	t64_ok			;within 4Gbyte

	btst	#1,CmdFlags+1(a4)
	bne.s	t64_set			;TD64 commands available or..

	or.w	#4,CmdFlags(a4)		;..fall back to direct SCSI
t64_ok:
	moveq.l	#-1,d0			;"OK"
	rts

t64_set:
	move.l	#NSCMD_TD_READ64<<16+NSCMD_TD_WRITE64,ReadCmd(a4)
	bra.s	t64_ok

;*** date conversion ***************************************
;--- MS-DOS date -> AmigaDOS date --------------------------
; d0 <- MS_time<<16+MS_date
; a1 <- &DateStamp

Date2Dos:
	movem.l	d2-d3,-(sp)
	move.l	d0,d3

	swap	d0			;MS time hours<<11+minutes<<5+seconds/2
	moveq.l	#$1f,d1
	and.w	d0,d1			;seconds/2
	mulu.w	#2*50,d1
	move.l	d1,DS_Ticks(a1)
	rol.w	#5,d0
	moveq.l	#$1f,d1
	and.w	d0,d1			;hours
	mulu.w	#60,d1
	rol.w	#6,d0
	and.w	#$3f,d0			;minutes
	add.w	d0,d1
	move.l	d1,DS_Mins(a1)

	moveq.l	#0,d1
	move.w	d3,d1			;MS date (year-1980)<<9+month<<5+day
	lsr.w	#5,d1
	moveq.l	#$f,d0
	and.w	d1,d0			;month 1..12
	add.w	#9,d0
	divu.w	#12,d0
	lsr.w	#4,d1
	add.w	#1980-1,d1
	add.w	d0,d1			;the march year
	swap	d0			;the month (0 = march .. 11 = february)
	mulu.w	#306,d0
	addq.w	#5,d0
	divu.w	#10,d0			;total days of previous months
	moveq.l	#$1f,d2
	and.w	d3,d2
	add.w	d2,d0			;days since march 1st + 1 ..
	ext.l	d0
	move.w	d1,d2
	mulu.w	#365,d2
	add.l	d2,d0			;..+ 365 days per year..
	lsr.l	#2,d1
	add.l	d1,d0			;..+ 1 leap day every 4 years..
	divu.w	#25,d1
	ext.l	d1
	sub.l	d1,d0			;..- 1 leap day every 100 years..
	lsr.l	#2,d1
	add.l	d1,d0			;..+ 1 leap day every 400 years..
	sub.l	#722391,d0		;..- (jan 1st, 1978 - march 1st, 0000) - 1
	move.l	d0,DS_Days(a1)

	movem.l	(sp)+,d2-d3
	rts

;--- AmigaDOS date -> MS date ------------------------------
; <- struct DateStamp *source;
; -> MS_date << 16 + MS_time

Date2MS:
	movem.l	d2-d3,-(sp)
	move.l	12(sp),a0		;&source

	move.l	(a0),d2			;DS_Days: days since jan 1st, 1978
	add.l	#722390,d2		;days since march 1st, 0000

	move.l	d2,d0
	addq.l	#1,d0
	move.l	#400*365+100-4+1,d1	;remove leap days:
	UDIVMOD32
	move.l	d2,d1
	sub.l	d0,d1			;-1 every 400 years
	move.l	d1,d0
	divu.w	#100*365+25-1,d0
	ext.l	d0
	add.l	d0,d1			;+1 every 100 years
	move.l	d1,d0
	addq.l	#1,d0
	divu.w	#4*365+1,d0
	ext.l	d0
	sub.l	d0,d1			;-1 every 4 years
	divu.w	#365,d1
	move.w	d1,d3			;the march year

	move.w	d1,d0
	mulu.w	#365,d0
	sub.l	d0,d2
	lsr.w	#2,d1
	ext.l	d1
	sub.l	d1,d2
	divu.w	#25,d1
	ext.l	d1
	add.l	d1,d2
	lsr.w	#2,d1
	sub.l	d1,d2			;days since march 1st

	divu.w	#153,d2			;cycle: every 5 months have 153 days
	move.w	d2,d0
	lsl.w	#2,d0
	add.w	d2,d0
	clr.w	d2
	swap	d2
	lsl.w	#1,d2
	divu.w	#61,d2			;average month length 30.5 days
	add.w	d0,d2			;the month (0 = march .. 11 = february)
	addq.w	#3,d2			;march = 3
	cmp.w	#13,d2
	bcs.s	upd_1

	sub.w	#12,d2			;january + february..
	addq.w	#1,d3			;..belong to next calendar year
upd_1:
	sub.w	#1980,d3
	moveq.l	#$7f,d0
	and.w	d3,d0
	ror.w	#7,d0			;(year-1980)<<9..
	rol.w	#5,d2
	or.w	d2,d0			;..+ month<<5..
	swap	d2
	lsr.w	#1,d2
	addq.w	#1,d2			;day of month 1..31
	or.w	d2,d0			;..+ day = MS_date

	move.l	DS_Mins(a0),d2
	divu.w	#60,d2
	move.w	d2,d1
	ror.w	#5,d1			;hour<<11..
	swap	d2
	rol.w	#5,d2
	or.w	d2,d1			;..+ minute<<5..
	move.l	DS_Ticks(a0),d2
	divu.w	#2*50,d2
	or.w	d2,d1			;..+ second/2 = MS_time

	swap	d0
	move.w	d1,d0
	movem.l	(sp)+,d2-d3
	rts

;*** string ops ********************************************
;--- copy string -------------------------------------------
; a0 <-  &source
; a1 <-> &dest

StrCopy:
	move.b	(a0)+,(a1)+
	bne.s	StrCopy

	subq.l	#1,a1
	rts

;--- get string lenth --------------------------------------
; a0 <- &String
; d0 -> length

StrLen:
	move.l	a0,d0
sl_loop:
	tst.b	(a0)+
	bne.s	sl_loop

	exg.l	d0,a0
	sub.l	a0,d0
	subq.l	#1,d0			;dont count termination
	rts

;--- string print formatted --------------------------------
; <- char *Format, char *target, ...

SPrintF:
	movem.l	d2/a2,-(sp)
	lea	12(sp),a2
	move.l	(a2)+,a0		;&format string
	move.l	(a2)+,a1		;&target
spf_start:
	moveq.l	#0,d2
spf_loop:
	move.b	(a0)+,d0
	beq.s	spf_end

	moveq.l	#-'%',d1
	add.b	d0,d1
	beq.s	spf_percent

	sub.b	#$5c-$25,d1		;"\"-"%
	beq.s	spf_backslash

	subq.b	#"d"-$5c,d1
	beq.s	spf_d

	subq.b	#"l"-"d",d1
	beq.s	spf_l

	subq.b	#"n"-"l",d1
	beq.s	spf_n

	subq.b	#"s"-"n",d1
	beq.s	spf_s

	subq.b	#"u"-"s",d1
	beq.s	spf_u
spf_write:
	move.b	d0,(a1)+
	bra.s	spf_start
spf_end:
	clr.b	(a1)
	movem.l	(sp)+,d2/a2
	rts

;- - format identifier - - - - - - - - - - - - - - - - - - -

spf_percent:
	tst.b	d2
	bmi.s	spf_write

	moveq.l	#-128,d2
	bra.s	spf_loop

;- - special char  - - - - - - - - - - - - - - - - - - - - -

spf_backslash:
	btst	#5,d2
	bne.s	spf_write

	moveq.l	#$20,d2
	bra.s	spf_loop

;- - signed decimal  - - - - - - - - - - - - - - - - - - - -

spf_d:
	tst.b	d2
	bpl.s	spf_write

	lsl.b	#1,d2
	bpl.s	spf_d1

	move.l	(a2)+,d0
	bra.s	spf_d2
spf_d1:
	move.w	(a2)+,d0
	ext.l	d0
spf_d2:
	tst.l	d0
	bpl.s	spf_n2s

	move.b	#'-',(a1)+
	neg.l	d0
spf_n2s:
	bsr.s	Num2Str
	bra.s	spf_start

;- - longword  - - - - - - - - - - - - - - - - - - - - - - -

spf_l:
	tst.b	d2
	bpl.s	spf_write

	moveq.l	#-64,d2
	bra.s	spf_loop

;- - newline - - - - - - - - - - - - - - - - - - - - - - - -

spf_n:
	btst	#5,d2
	beq.s	spf_write

	moveq.l	#LF,d0
	bra.s	spf_write

;- - string  - - - - - - - - - - - - - - - - - - - - - - - -

spf_s:
	tst.b	d2
	bpl.s	spf_write

	move.l	(a2)+,d1
	beq.s	spf_start

	move.l	a0,-(sp)
	move.l	d1,a0
	bsr.w	StrCopy
	move.l	(sp)+,a0
	bra.w	spf_start

;- - unsigned decimal  - - - - - - - - - - - - - - - - - - -

spf_u:
	tst.b	d2
	bpl.s	spf_write

	lsl.b	#1,d2
	bpl.s	spf_u1

	move.l	(a2)+,d0
	bra.s	spf_n2s
spf_u1:
	moveq.l	#0,d0
	move.w	(a2)+,d0
	bra.s	spf_n2s

;--- integer -> String -------------------------------------
; d0 <-  longword
; a1 <-> &string buffer

Num2Str:
	movem.l	d0-d2/a0,-(sp)
	move.l	a1,a0		;remember buffer start
n2s_loop1:
	moveq.l	#10,d1
	UDIVMOD32
	or.b	#'0',d1
	move.b	d1,(a1)+	;append digit
	tst.l	d0
	bne.s	n2s_loop1

	move.l	a1,d2		;remember buffer end
	move.l	a1,d1
	sub.l	a0,d1		;digit count
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
	clr.b	(a1)		;string termination
	movem.l	(sp)+,d0-d2/a0
	rts

;*** longword math (68000 fallbacks; 020+ inlines via macros) ***
	ifnd	__68020__
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

	endif	;__68020__

;*** from dos.library **************************************

_DateStamp
	move.l	4(sp),d1
	move.l	DosBase(a4),a6
	jmp	-$00c0(a6)

;*** Exec supplements **************************************
;--- get self administrating mem ---------------------------
; d0 <- size in bytes
; d1 <- mem type
; d0 -> &mem or 0

AllocVec:
	addq.l	#4,d0
	move.l	d0,-(sp)
	CALLEXEC AllocMem
	move.l	(sp)+,d1
	tst.l	d0
	beq.s	av_end

	move.l	d0,a0
	move.l	d1,(a0)+
	move.l	a0,d0
av_end:
	rts

;--- empty list --------------------------------------------
; a0 <- &Liste

InitList:
	move.l	a0,(a0)
	addq.l	#4,(a0)
	clr.l	4(a0)
	move.l	a0,8(a0)
	rts

;--- add Node at list top ----------------------------------
; a0 <- &Liste
; a1 <- &node

MyAddHead:
	move.l	(a0),(a1)		;link..
	move.l	a1,(a0)			;..fore
	move.l	a0,4(a1)		;link..
	move.l	(a1),a0			;&successor
	move.l	a1,4(a0)		;..back
	rts

;--- remove Node from list ---------------------------------
; a1 <- &node

MyRemove:
	move.l	(a1)+,a0		;&successor
	move.l	(a1),a1			;&predictor
	move.l	a0,(a1)			;link fore..
	move.l	a1,4(a0)		;..and back
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

;*** from exec.library *************************************

_Forbid:
	move.l	ExecBase(a4),a6
	jmp	-$084(a6)

_Permit:
	move.l	ExecBase(a4),a6
	jmp	-$08a(a6)

;*** from intuition.library ********************************

_AutoRequest:
	movem.l	d2-d3/a2-a3,-(sp)
	movem.l	20(sp),a0-a3
	movem.l	36(sp),d0-d3
	move.l	IntBase(a4),a6
	jsr	-$15c(a6)
	movem.l	(sp)+,d2-d3/a2-a3
	rts

	cnop	0,4

;*** constants and initialzed vars *************************

BootSample12:				;FAT12 and FAT16
	dc.b	$EB,$3E,$90		;branch to boot routine (i80x86-Code)
	dc.b	")GZ.,IHC"		;System ID (Win95)
	dc.b	$00,$02			;bytes/sector (little endian)
	dc.b	$02			;sectors/cluster
	dc.b	$01,$00			;# reserved sectors
	dc.b	$02			;# FAT copies
	dc.b	$70,$00			;# root dir entries
	dc.b	$00,$00			;# sectors (if < 65535)
	dc.b	$F9			;media ID
	dc.b	$03,$00			;sectors/FAT
	dc.b	$09,$00			;sectors/track
	dc.b	$02,$00			;# surfaces
	dc.b	$00,$00,$00,$00		;# hidden sectors
	dc.b	$00,$00,$00,$00		;# sectors (if >= 65535)
	dc.b	$00,$00			;drive #
	dc.b	$29			;"the next 3 fields are valid"
	dc.b	$6D,$29,$F4,$0F		;serial #
	dc.b	"           "		;volume name duplicate
	dc.b	"FAT12   "		;file system ID
	dc.b	$F1,$7D			;boot routine
	dc.b	$FA,$33,$C9,$8E,$D1,$BC,$FC,$7B
	dc.b	$16,$07,$BD,$78,$00,$C5,$76,$00
	dc.b	$1E,$56,$16,$55,$BF,$22,$05,$89
	dc.b	$7E,$00,$89,$4E,$02,$B1,$0B,$FC
	dc.b	$F3,$A4,$06,$1F,$BD,$00,$7C,$C6
	dc.b	$45,$FE,$0F,$8B,$46,$18,$88,$45
	dc.b	$F9,$FB,$38,$66,$24,$7C,$04,$CD
	dc.b	$13,$72,$3C,$8A,$46,$10,$98,$F7
	dc.b	$66,$16,$03,$46,$1C,$13,$56,$1E
	dc.b	$03,$46,$0E,$13,$D1,$50,$52,$89
	dc.b	$46,$FC,$89,$56,$FE,$B8,$20,$00
	dc.b	$8B,$76,$11,$F7,$E6,$8B,$5E,$0B
	dc.b	$03,$C3,$48,$F7,$F3,$01,$46,$FC
	dc.b	$11,$4E,$FE,$5A,$58,$BB,$00,$07
	dc.b	$8B,$FB,$B1,$01,$E8,$94,$00,$72
	dc.b	$47,$38,$2D,$74,$19,$B1,$0B,$56
	dc.b	$8B,$76,$3E,$F3,$A6,$5E,$74,$4A
	dc.b	$4E,$74,$0B,$03,$F9,$83,$C7,$15
	dc.b	$3B,$FB,$72,$E5,$EB,$D7,$2B,$C9
	dc.b	$B8,$D8,$7D,$87,$46,$3E,$3C,$D8
	dc.b	$75,$99,$BE,$80,$7D,$AC,$98,$03
	dc.b	$F0,$AC,$84,$C0,$74,$17,$3C,$FF
	dc.b	$74,$09,$B4,$0E,$BB,$07,$00,$CD
	dc.b	$10,$EB,$EE,$BE,$83,$7D,$EB,$E5
	dc.b	$BE,$81,$7D,$EB,$E0,$33,$C0,$CD
	dc.b	$16,$5E,$1F,$8F,$04,$8F,$44,$02
	dc.b	$CD,$19,$BE,$82,$7D,$8B,$7D,$0F
	dc.b	$83,$FF,$02,$72,$C8,$8B,$C7,$48
	dc.b	$48,$8A,$4E,$0D,$F7,$E1,$03,$46
	dc.b	$FC,$13,$56,$FE,$BB,$00,$07,$53
	dc.b	$B1,$04,$E8,$16,$00,$5B,$72,$C8
	dc.b	$81,$3F,$4D,$5A,$75,$A7,$81,$BF
	dc.b	$00,$02,$42,$4A,$75,$9F,$EA,$00
	dc.b	$02,$70,$00,$50,$52,$51,$91,$92
	dc.b	$33,$D2,$F7,$76,$18,$91,$F7,$76
	dc.b	$18,$42,$87,$CA,$F7,$76,$1A,$8A
	dc.b	$F2,$8A,$56,$24,$8A,$E8,$D0,$CC
	dc.b	$D0,$CC,$0A,$CC,$B8,$01,$02,$CD
	dc.b	$13,$59,$5A,$58,$72,$09,$40,$75
	dc.b	$01,$42,$03,$5E,$0B,$E2,$CC,$C3
	dc.b	$03,$18,$01,$27,$0D,$0A,$55,$6E
	dc.b	$67,$75,$65,$6C,$74,$69,$67,$65
	dc.b	$73,$20,$53,$79,$73,$74,$65,$6D
	dc.b	$20,$FF,$0D,$0A,$45,$2F,$41,$2D
	dc.b	$46,$65,$68,$6C,$65,$72,$20,$20
	dc.b	$20,$20,$FF,$0D,$0A,$44,$61,$74
	dc.b	$65,$6E,$74,$72,$61,$65,$67,$65
	dc.b	$72,$20,$77,$65,$63,$68,$73,$65
	dc.b	$6C,$6E,$20,$75,$6E,$64,$20,$54
	dc.b	$61,$73,$74,$65,$20,$64,$72,$75
	dc.b	$65,$63,$6B,$65,$6E,$0D,$0A,$00
	dc.b	$49,$4F,$20,$20,$20,$20,$20,$20
	dc.b	$53,$59,$53,$4D,$53,$44,$4F,$53
	dc.b	$20,$20,$20,$53,$59,$53,$80,$01
	dc.b	$00,$57,$49,$4E,$42,$4F,$4F,$54
	dc.b	$20,$53,$59,$53
	dc.b	$00,$00,$55,$AA		;"magic number"

BootSample32:				;FAT32
	dc.b	$EB,$58,$90		;branch to boot routine (i80x86-Code)
	dc.b	"MSWIN4.1"		;System ID (Win98)
	dc.b	$00,$02			;bytes/sector (little endian)
	dc.b	$08			;sectors/cluster
	dc.b	$20,$00			;# reserved sectors (32)
	dc.b	$02			;# FAT copies
	dc.b	$00,$00			;# root dir entries (0)
	dc.b	$00,$00			;# sectors if < 65535 (0)
	dc.b	$F8			;media ID
	dc.b	$00,$00			;sectors/FAT (0)
	dc.b	$3F,$00			;sectors/track
	dc.b	$FF,$00			;# surfaces
	dc.b	$BD,$04,$7D,$00		;# hidden sectors
	dc.b	$86,$BB,$7E,$00		;# sectors
	dc.b	$A7,$1F,$00,$00		;sectors/FAT
	dc.b	$00,$00			;FAT flags
	dc.b	$00,$00			;Version #
	dc.b	$02,$00,$00,$00		;root cluster # (2)
	dc.b	$01,$00			;Block # FSInfo (1)
	dc.b	$06,$00			;Block # of boot block duplicate (6)
	dc.b	$00,$00,$00,$00
	dc.b	$00,$00,$00,$00
	dc.b	$00,$00,$00,$00		;12 reserved bytes
	dc.b	$80,$00			;drive #
	dc.b	$29			;"the next 3 fields are valid"
	dc.b	$F2,$18,$35,$14		;serial #
	dc.b	"           "		;volume name duplicate
	dc.b	"FAT32   "		;file system ID
	dc.b	$FA,$33,$C9,$8E,$D1,$BC
	dc.b	$F8,$7B,$8E,$C1,$BD,$78,$00,$C5
	dc.b	$76,$00,$1E,$56,$16,$55,$BF,$22
	dc.b	$05,$89,$7E,$00,$89,$4E,$02,$B1
	dc.b	$0B,$FC,$F3,$A4,$8E,$D9,$BD,$00
	dc.b	$7C,$C6,$45,$FE,$0F,$8B,$46,$18
	dc.b	$88,$45,$F9,$38,$4E,$40,$7D,$25
	dc.b	$8B,$C1,$99,$BB,$00,$07,$E8,$97
	dc.b	$00,$72,$1A,$83,$EB,$3A,$66,$A1
	dc.b	$1C,$7C,$66,$3B,$07,$8A,$57,$FC
	dc.b	$75,$06,$80,$CA,$02,$88,$56,$02
	dc.b	$80,$C3,$10,$73,$ED,$BF,$02,$00
	dc.b	$83,$7E,$16,$00,$75,$45,$8B,$46
	dc.b	$1C,$8B,$56,$1E,$B9,$03,$00,$49
	dc.b	$40,$75,$01,$42,$BB,$00,$7E,$E8
	dc.b	$5F,$00,$73,$26,$B0,$F8,$4F,$74
	dc.b	$1D,$8B,$46,$32,$33,$D2,$B9,$03
	dc.b	$00,$3B,$C8,$77,$1E,$8B,$76,$0E
	dc.b	$3B,$CE,$73,$17,$2B,$F1,$03,$46
	dc.b	$1C,$13,$56,$1E,$EB,$D1,$73,$0B
	dc.b	$EB,$27,$83,$7E,$2A,$00,$77,$03
	dc.b	$E9,$FD,$02,$BE,$7E,$7D,$AC,$98
	dc.b	$03,$F0,$AC,$84,$C0,$74,$17,$3C
	dc.b	$FF,$74,$09,$B4,$0E,$BB,$07,$00
	dc.b	$CD,$10,$EB,$EE,$BE,$81,$7D,$EB
	dc.b	$E5,$BE,$7F,$7D,$EB,$E0,$98,$CD
	dc.b	$16,$5E,$1F,$66,$8F,$04,$CD,$19
	dc.b	$41,$56,$66,$6A,$00,$52,$50,$06
	dc.b	$53,$6A,$01,$6A,$10,$8B,$F4,$60
	dc.b	$80,$7E,$02,$0E,$75,$04,$B4,$42
	dc.b	$EB,$1D,$91,$92,$33,$D2,$F7,$76
	dc.b	$18,$91,$F7,$76,$18,$42,$87,$CA
	dc.b	$F7,$76,$1A,$8A,$F2,$8A,$E8,$C0
	dc.b	$CC,$02,$0A,$CC,$B8,$01,$02,$8A
	dc.b	$56,$40,$CD,$13,$61,$8D,$64,$10
	dc.b	$5E,$72,$0A,$40,$75,$01,$42,$03
	dc.b	$5E,$0B,$49,$75,$B4,$C3,$03,$18
	dc.b	$01,$27,$0D,$0A,$55,$6E,$67,$75
	dc.b	$65,$6C,$74,$69,$67,$65,$73,$20
	dc.b	$53,$79,$73,$74,$65,$6D,$20,$FF
	dc.b	$0D,$0A,$45,$2F,$41,$2D,$46,$65
	dc.b	$68,$6C,$65,$72,$20,$20,$20,$20
	dc.b	$FF,$0D,$0A,$44,$61,$74,$65,$6E
	dc.b	$74,$72,$61,$65,$67,$65,$72,$20
	dc.b	$77,$65,$63,$68,$73,$65,$6C,$6E
	dc.b	$20,$75,$6E,$64,$20,$54,$61,$73
	dc.b	$74,$65,$20,$64,$72,$75,$65,$63
	dc.b	$6B,$65,$6E,$0D,$0A,$00,$00,$00
	dc.b	$49,$4F,$20,$20,$20,$20,$20,$20
	dc.b	$53,$59,$53,$4D,$53,$44,$4F,$53
	dc.b	$20,$20,$20,$53,$59,$53,$7E,$01
	dc.b	$00,$57,$49,$4E,$42,$4F,$4F,$54
	dc.b	$20,$53,$59,$53,$00,$00,$55,$AA

ExtBoot32:				;FAT32 boot routine continued
	dc.b	$FA,$66,$0F,$B6,$46,$10,$66,$8B
	dc.b	$4E,$24,$66,$F7,$E1,$66,$03,$46
	dc.b	$1C,$66,$0F,$B7,$56,$0E,$66,$03
	dc.b	$C2,$33,$C9,$66,$89,$46,$FC,$66
	dc.b	$C7,$46,$F8,$FF,$FF,$FF,$FF,$FA
	dc.b	$66,$8B,$46,$2C,$66,$83,$F8,$02
	dc.b	$0F,$82,$CF,$FC,$66,$3D,$F8,$FF
	dc.b	$FF,$0F,$0F,$83,$C5,$FC,$66,$0F
	dc.b	$A4,$C2,$10,$FB,$52,$50,$FA,$66
	dc.b	$C1,$E0,$10,$66,$0F,$AC,$D0,$10
	dc.b	$66,$83,$E8,$02,$66,$0F,$B6,$5E
	dc.b	$0D,$8B,$F3,$66,$F7,$E3,$66,$03
	dc.b	$46,$FC,$66,$0F,$A4,$C2,$10,$FB
	dc.b	$BB,$00,$07,$8B,$FB,$B9,$01,$00
	dc.b	$E8,$BE,$FC,$0F,$82,$AA,$FC,$38
	dc.b	$2D,$74,$1E,$B1,$0B,$56,$BE,$D8
	dc.b	$7D,$F3,$A6,$5E,$74,$19,$03,$F9
	dc.b	$83,$C7,$15,$3B,$FB,$72,$E8,$4E
	dc.b	$75,$D6,$58,$5A,$E8,$66,$00,$72
	dc.b	$AB,$83,$C4,$04,$E9,$64,$FC,$83
	dc.b	$C4,$04,$8B,$75,$09,$8B,$7D,$0F
	dc.b	$8B,$C6,$FA,$66,$C1,$E0,$10,$8B
	dc.b	$C7,$66,$83,$F8,$02,$72,$3B,$66
	dc.b	$3D,$F8,$FF,$FF,$0F,$73,$33,$66
	dc.b	$48,$66,$48,$66,$0F,$B6,$4E,$0D
	dc.b	$66,$F7,$E1,$66,$03,$46,$FC,$66
	dc.b	$0F,$A4,$C2,$10,$FB,$BB,$00,$07
	dc.b	$53,$B9,$04,$00,$E8,$52,$FC,$5B
	dc.b	$0F,$82,$3D,$FC,$81,$3F,$4D,$5A
	dc.b	$75,$08,$81,$BF,$00,$02,$42,$4A
	dc.b	$74,$06,$BE,$80,$7D,$E9,$0E,$FC
	dc.b	$EA,$00,$02,$70,$00,$03,$C0,$13
	dc.b	$D2,$03,$C0,$13,$D2,$E8,$18,$00
	dc.b	$FA,$26,$66,$8B,$01,$66,$25,$FF
	dc.b	$FF,$FF,$0F,$66,$0F,$A4,$C2,$10
	dc.b	$66,$3D,$F8,$FF,$FF,$0F,$FB,$C3
	dc.b	$BF,$00,$7E,$FA,$66,$C1,$E0,$10
	dc.b	$66,$0F,$AC,$D0,$10,$66,$0F,$B7
	dc.b	$4E,$0B,$66,$33,$D2,$66,$F7,$F1
	dc.b	$66,$3B,$46,$F8,$74,$44,$66,$89
	dc.b	$46,$F8,$66,$03,$46,$1C,$66,$0F
	dc.b	$B7,$4E,$0E,$66,$03,$C1,$66,$0F
	dc.b	$B7,$5E,$28,$83,$E3,$0F,$74,$16
	dc.b	$3A,$5E,$10,$0F,$83,$A4,$FB,$52
	dc.b	$66,$8B,$C8,$66,$8B,$46,$24,$66
	dc.b	$F7,$E3,$66,$03,$C1,$5A,$52,$66
	dc.b	$0F,$A4,$C2,$10,$FB,$8B,$DF,$B9
	dc.b	$01,$00,$E8,$B4,$FB,$5A,$0F,$82
	dc.b	$9F,$FB,$FB,$8B,$DA,$C3,$00,$00
ExtBootEnd:
	cnop	0,4

;--- Text for den Nutzer -----------------------------------

UIModule:
	dc.b	"loca"
	dc.l	uit_e1-uit_s1
uit_s1:
	dc.b	 1,"Abort",0
	dc.b	 2,"Skip",0
	dc.b	 3,"Retry",0
	dc.b	 4,"Please reinsert the disk \n",$22,"%s",$22,"!",0
	dc.b	 5,"%s:\nRead error %ld at block %lu.",0
	dc.b	 6,"%s:\nWrite error %ld at block %lu.",0
	dc.b	 7,"%s:\nUpdate error %ld.",0
	dc.b	 8,"created",0
	dc.b	 9,"last accessed",0
	dc.b	10,"Checking directories...",0
	dc.b	11,"Checking file allocation table...",0
	dc.b	12,"Searching for lost files...",0
	dc.b	13,"%lu error(s) fixed!",0
	dc.b	14,"Everything is fine :)",0
	dc.b	15,"Erasing free disk space...",0
	dc.b	16,"Press <ESC> to abort.",0
	dc.b	 0
	even
NUMUITEXTS	= 16

uit_e1:
	dc.b	"oem "
	dc.l	uit_e2-uit_s2
uit_s2:
	dc.l	$5fad9b9c, $5f9d7c15, $5f5fa6ae, $aac45f7e
	dc.l	$f8f1fd33, $60e6e3f9, $5f31a7af, $acab5fa8
	dc.l	$41414141, $8e8f9280, $45904545, $49494949
	dc.l	$44a54f4f, $4f4f99fe, $ed555555, $9a595fe1
uit_e2:
	dc.l	0
	cnop	0,4
CodeEnd:

;*** That's all folks!! ************************************
		end
