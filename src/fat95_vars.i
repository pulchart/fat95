; fat95 handler globals, offsets from the base in a4. debug95 dumps them,
; tools/parse_debug95.py reads them and make runs its --check first.
; .b, .w or .l at the start of a comment sets the field size, and a second
; width (.w .l) allows that access in fat95.s too.

;Debug Info
DebugSize	=   0
DebugVersion	=   4		;.w version << 8 + revision
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
ReadCmd		=  72		;.w .l, also longword with WriteCmd
WriteCmd	=  74
UpdateCmd	=  76
CmdFlags	=  78
QueryResult	=  80		;embedded struct NSDeviceQueryResult

;CmdFlags
;$0001	ETD_ commands available
;$0002  TD64 commands available
;$0004	SCSI mode active
;$0008	use CMD_UPDATE
;$0010	TJ commands available
;$0100  show extra date stamps as file comments
;$0200  store last read date
;$0400	convert short names to lowercase
;$0800	lowercase short names, first letter too
;$1000	quiet: suppress error requesters ("q" option)
;$2000	mount used: claim a partition another handler already serves
;	("m" option; the user's own risk, writes corrupt the volume)

;logical partition layout
BlockSize	=  96
BlockShift	=  98		;log2(Bytes/Block)
BlockMask	= 100		;Byte mask
FirstBlock	= 104		;partition offset from media start
TotalBlocks	= 108		;Partition size
HiddenBlocks	= 112		;offset from partition table instance or 0
PartitionNum	= 116		;0 = no partition table
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
LastReadBlock	= 172		;last block read, for debugging
LastReadError	= 176
SearchCount	= 177
SearchMode	= 178
PartitionSelector = 179		;resolved partition selector (0..255)

;physikal media layout
PhysSize	= 180		;device sector size in bytes, 512 at least
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
FATType		= 216		;0 = FAT12, 1 = FAT16, -1 = FAT32, 2 = auto
PartClaimed	= 218		;.w 1 = our partition is mounted by another
				;handler (access errors map to 202 "in use")
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
DiskType	= 284		;ID_ value, -1 = no disk
DiskState	= 288		;80 = write protected, 81 = validating,
				;82 = validated
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
NumBuffers	= EnvecBuf+DE_NumBuffers+2 ;.w
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

;OEM charset maps: one block, the inverse map then the forward one
OemPage		= 608		;Amiga $a0..$ff -> upper case OEM
InvOemPage	= 612		;OEM $80..$ff -> Amiga

;SCSI Sense data
SenseBuffer	= 616

;FSInfo publication and per-insertion I/O state
FSInfoUnknown   = 874		;trusted marker or recursion guard
FSInfoDirty     = 876
MediaGeneration = 878
MountGeneration = 882
WriteFault      = 886
DiscardBuffers  = 888
ReadFailures    = 890
CheckComplete   = 894
ScanActive      = 896

DirtyReady      = 898		;the dirty flag is in use on this mount
DirtyEligible   = 900		;every copy of the dirty flag was clean at mount
DirtyCycle      = 902
DirtyIO         = 904
RegStart	= 906		;start block given to RegisterPartition, in the
				;row's blocks; UnregisterPartition passes it back
WantedStart	= 910		;name component the units below belong to, or 0
WantedCount	= 914		;its UTF-16 units
WantedOff	= 916		;byte offset of each unit, -1 for a low surrogate
WantedUp	= 1020		;each unit in upper case

;total size
VarsSizeof      = 1228

;*** Summary of parse_debug95.py, formats described there ***

;@show dec	Device		unit = UnitNumber
;@show bytes	Device		block size = BlockSize
;@show bytes	Device		sector size = PhysSize
;@show hex	Device		open flags = DeviceFlags
;@show flags	Device		features = CmdFlags
;@show enum	Partition	type = FATType
;@show id	Partition	DosType = DosType
;@show enum	Partition	number = PartitionNum
;@show dec	Partition	first block = FirstBlock
;@show dec	Partition	blocks = TotalBlocks
;@show bytes	Partition	size = TotalBlocks*BlockSize
;@show bytes	Partition	cluster size = ClusterSize
;@show yesno	Partition	mounted by another handler = PartClaimed
;@show text	Volume		name = LastVolName
;@show hex	Volume		serial number = SerialNum
;@show id	Volume		disk type = DiskType
;@show enum	Volume		state = DiskState
;@show yesno	Volume		dirty flag in use = DirtyReady
;@show yesno	Volume		mounted clean = DirtyEligible
;@show bytes	Volume		free = FreeClusters*ClusterSize
;@show yesno	Volume		write locked = SoftLocked
;@show dec	Activity	open locks = NumLocks
;@show dec	Activity	inhibit count = InhibitNest
;@show dec	Activity	buffers = NumBuffers
;@show yesno	Names		[unicode] table = CodePage
;@show yesno	Names		[oem] table = OemPage
;@show doserr	Errors		last DOS error = ErrorNum
;@show ioerr	Errors		last read = LastReadError
;@show dec	Errors		last block read = LastReadBlock
;@show dec	Errors		failed reads = ReadFailures
;@show yesno	Errors		write fault = WriteFault
