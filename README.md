# Win95/98 compatible FAT filesystem handler for AmigaOS.

Based on Torsten Jager's fat95 v3.18 (Aminet: [disk/misc/fat95.lha](https://aminet.net/package/disk/misc/fat95)).

## fat95 handler

**Download** at GitHub [Releases](https://github.com/pulchart/fat95/releases)

**Purpose**

"fat95" is a DOS handler to mount and use Win95/98 volumes just as if they were AMIGA volumes.

**Personal Note**

Improvements to this handler are developed in my free time. If you'd like to support ongoing maintenance and experimentation, you can do so on [Ko-fi](https://ko-fi.com/jaroslavpulchart).

**Community Links**

- **English Amiga Forum Thread:** [Discussion Thread](https://eab.abime.net/showthread.php?t=121575) user questions and troubleshooting.
- **Aminet fat95 Advanced Search:** [FAT95 releases (m68k, AmigaOS)](https://aminet.net/search?type=advanced&name=fat95&q_path=AND&path%5B%5D=disk%2Fmisc&q_date=AND&o_date=equal&date=&q_desc=AND&desc=&q_readme=AND&readme=&q_content=AND&content=&q_arch=AND&arch%5B%5D=m68k-amigaos&search=search) shows all fat95 packages.

**System Requirements**

* Every AMIGA, OS 1.3+ (OS 2.0+ for full functionality)
* A suitable device file for low level disk access, like the
  mfm.device for floppies, compactflash.device for CF in PCMCIA.

**Features**

* Workbench and applications support
* Diskchange autosense
* Format type autosense: FAT12, FAT16 and FAT32
* MBR and GPT partition table support
* Simple LINUX style partition selection or manual definition
* Up to 4 GBytes of partition size for FAT16
* Large harddisk support via TD64 or direct SCSI
* Long filenames (up to 104 chars for now)
* Inquiry, read, write, and maintenance access
* Built-in error check utility
* Disk formatting using the OS 2.0+ format command
* MS-DOS 8.3 downward compatibility
* User definable language and code page
* Date range Jan 1st, 1980 through Dec 31st, 2107
* Extended datestamp support: creation date and time, last accessed date
  (written automatically, readable as file comment text)
* Volume serial number as name for unnamed volumes
* Automatic directory optimization
* Written entirely in assembly language

## What's New in

### 3.20 (16.03.2026)

* **NTFS volume rejection**
  - NTFS volumes are now explicitly rejected and reported as unrecognised instead of being incorrectly mounted as an unnamed FAT volume with its serial number as the volume name (e.g. "0000-0100").
  - Affects GPT disks (both FAT and NTFS share the same "Microsoft Basic Data" partition GUID), MBR disks where an NTFS partition was placed in a FAT partition slot (e.g. type 0x0B/0x0C), and unpartitioned direct volume access paths.
  - Relates to github issues: [pulchart/cfd#37](https://github.com/pulchart/cfd/issues/37), [salass00/ntfs-3g#3](https://github.com/salass00/ntfs-3g/issues/3)

### 3.19 (01.02.2026)

* **Fork of 3.18**
  - Set English as default localization for fat95 handler
  - Rebuild by vasm 2.0d
  - Consolidated documentation into fat95.guide

* Detect SFS/PFS/FFS/RDB as foreign disk formats

* **GPT partition table support**
  - Automatic detection of GPT disks via protective MBR (type 0xEE)
  - Scans GPT partition entries for Microsoft Basic Data partitions (FAT)
  - Supports partition selection via DosType (same as MBR: FAT\1, FAT\2, etc.)

* **Improved disk change handling**
  - Non-existent partitions now show "No Disk" instead of "Uninitialized"
  - Fixes stale partition data when switching to cards with fewer partitions (see [Disk Status Meanings](#disk-status-meanings))
  - Foreign disk formats (RDB, PFS, SFS) show appropriate status per partition

* **Bug fixes**
  - Fixed trailing slashes in path names (e.g., "makedir cf0:temp/" now correctly creates "temp")
    WARNING: Using trailing slashes with 3.18 corrupted the filesystem

## Installation

**Introduction**

Installing disk drives under AmigaOS requires *two* components:

1. A **hardware driver** that provides block-level access to the drive. This can be part of the Kickstart ROM (e.g., `trackdisk.device`) or a separate file (e.g., `Devs:compactflash.device`).
2. A **filesystem handler** that manages partitions, directories, and files. The standard filesystem is in ROM. Others, like fat95, are files in the `L:` drawer.

These two components are connected via a **mountlist** - a configuration file that tells AmigaOS how to mount the drive.

**Installation**

1. Edit the `install_fat95` text file for your language.
2. Double-click the `install_fat95` icon to activate the changes.
3. Optionally double-click example mountlist icons in `DOSDrivers/`:
   - `MS0`/`MS1` - FAT-formatted PC DD 720k floppy (mfm.device)
   - `CF0` - FAT partition on CompactFlash in PCMCIA slot (compactflash.device), supports MBR and GPT
   For custom configurations, see the [Mountlist Configuration](#mountlist-configuration) section.
4. Copy mountlists to:
   - `DEVS:DOSDrivers/` for automatic mounting at boot, or
   - `SYS:Storage/DOSDrives/` for manual mounting via shell command (Method A: Shell Command)

## Mountlist Configuration

### Device Driver Settings

First, the name of the driver:

```
Device = scsi.device
```

That's the one responsible for the Amiga's internal IDE or SCSI
port. Usually, multiple drives can be connected to such a port.
Therefore, we need to state which one we want:

```
Unit = 1
```

This is the "slave" IDE drive (e.g., a ZIP drive).
The "master" harddisk has number 0.
For drivers with a single drive only, it is also 0.

```
Flags = 0
```

Some drivers allow special settings to be made via this one.
Most cases, that 0 is enough.

```
BufMemType = 1
MaxTransfer = 0x20000
Mask = 0xfffffffe
```

For the (unpatched) A1200 ROM scsi.device. Or if driver
doesn't need them, simply discard.

### File System Settings

```
Filesystem = l:fat95
```

AmigaOS wants the full path here.

```
StackSize = 4096
```

Reserve that many bytes for temporary data. State too few,
and "mysterious" crashes will happen.

```
GlobVec = -1
```

fat95 is assembly language written, so -1.

```
Buffers = 200
```

Hold that many blocks of 512 bytes each in memory.
More = Faster = Less memory available.

### Control Options

```
Control = "+s"
```

Available options:

| Option | Description | Default |
|--------|-------------|---------|
| `+` | Turn ON the following options | - |
| `-` | Turn OFF the following options | - |
| `s` | Force direct SCSI reads/writes (for >4GB disks) | OFF |
| `d` | Display extra datestamp info as file comments | ON |
| `D` | Record "last accessed" date on file reads | ON |
| `l` | Show 8.3 filenames lowercase (e.g., "test.txt") | OFF |
| `L` | Show 8.3 filenames with uppercase initial (e.g., "Test.txt") | OFF |

### Startup Options

```
Activate = 1
```

Start immediately instead of on first access.

## Partition Selection

fat95 supports both **MBR** and **GPT** partition tables with automatic detection.

### Automatic Partition Search (Recommended)

```
LowCyl = 0              /* Enable auto search */

BlockSize = 512         /* Required by Mount command */
HighCyl = 1
BlocksPerTrack = 1
Surfaces = 1
```

**DosType Values**

The **DosType** controls which partition to mount:

| DosType | Hex Value | Description |
|---------|-----------|-------------|
| FAT\0 | 0x46415400 | Floppies only |
| FAT\1 | 0x46415401 | First FAT partition (recommended) |
| FAT\2 | 0x46415402 | Second FAT partition |
| FAT\3 | 0x46415403 | Third FAT partition |
| FAT\4 | 0x46415404 | Fourth FAT partition |
| FAT\5 | 0x46415405 | First logical drive (extended partition) |
| FAT\6 | 0x46415406 | Second logical drive, etc. |

**Recognized partition types:**

For MBR disks, fat95 recognizes these partition types:

| Type | Description |
|------|-------------|
| 0x01 | FAT12 |
| 0x04 | FAT16, < 32 MB |
| 0x06 | FAT16, >= 32 MB |
| 0x0B | FAT32 |
| 0x0C | FAT32, LBA |
| 0x0E | FAT16, LBA |
| 0x05, 0x0F | Extended partition (for logical partitions) |

For GPT disks, fat95 counts only FAT partitions (Microsoft Basic Data GUID: `EBD0A0A2-B9E5-4433-87C0-68B6B72699C7`).
Non-FAT partitions (EFI System, Windows Recovery, etc.) are automatically skipped.

**GPT vs MBR Detection**

fat95 automatically detects the partition table type:
1. Reads block 0 (MBR)
2. Checks for protective MBR (partition type 0xEE)
3. If found, reads GPT header at LBA 1 and scans GPT entries
4. Otherwise, parses standard MBR partition table

### Manual Partition Definition

For special cases like damaged partition tables:

```
BlockSize = 512
DosType = 0x46415401

BlocksPerTrack = 1
Surfaces = 1
LowCyl = <StartBlockNumber>
HighCyl = <LastBlock>
```

## Mounting the Drive

### Complete Mountlist Example

```
CF0:
    FileSystem     = L:fat95
    Device         = compactflash.device
    Unit           = 0
    Flags          = 0
    LowCyl         = 0          /* Auto partition search */
    HighCyl        = 1
    Surfaces       = 1
    BlocksPerTrack = 1
    BlockSize      = 512
    Buffers        = 200
    BufMemType     = 1
    MaxTransfer    = 0x1FE00
    Mask           = 0xFFFFFFFE
    StackSize      = 4096
    Priority       = 5
    GlobVec        = -1
    DosType        = 0x46415401 /* FAT\1 = first FAT partition */
    Activate       = 1
```

### Method A: Shell Command

```
mount CF0:
```

### Method B: Workbench Icon

1. Create project icon `CF0.info`
2. Enter `c:mount` as the default tool
3. Double click the icon

### Method C: Auto-mount at Boot

Copy both `CF0` and `CF0.info` to `DEVS:DOSDrivers`

### Method D: OS 1.3 (MountList file)

Edit `DEVS:MountList` and append:

```
CF0:
    Device = scsi.device
    /* ... other entries ... */
```

Then mount with:

```
mount CF0:
```

## Special Features

fat95 uses file comments for special commands:

**Scandisk**

```
filenote CF0:anyfile "!scandisk"
```

Recovers lost files and fixes disk errors.

**Control Options**

```
filenote CF0:anyfile "!control -dD"
```

Changes configuration options at runtime.

**Security Erase**

```
filenote CF0:anyfile "!erase"
```

Overwrites deleted files with zeroes (unrecoverable delete).
Works with CompactFlash built-in erase when available.

**Note:** scandisk and erase can be aborted with `<ESC>`.

## Troubleshooting

**Report issues at:** https://github.com/pulchart/fat95/issues

**Q: "object not found" when mounting?**

A: Check the `Device =`, `Unit =` and `Flags =` entries.

**Debug tool:**

```
debug95 CF0: ram:cf0.log
```

Creates a dump of internal fat95 variables for diagnosis.

### FAT32 Notes

* FAT32 FAT table can be huge (8MB for 8GB partition)
* fat95 does not cache entire FAT32 table to save memory
* Free space calculation happens after mount ("volume is validating")

### Disk Status Meanings

Fat95 reports different disk statuses depending on what it finds:

| Status | ID | Icon | Meaning |
|--------|----|------|---------|
| **Mounted** | `ID_DOS` | `Volume name` | FAT partition found and mounted successfully |
| **Uninitialized** | `ID_NDOS` | `CF0:NDOS` or `CF0:Uninitialized` | Disk present but not FAT format (e.g., RDB, PFS, SFS, FFS) or bad MBR partition table |
| **No Disk** | `ID_NONE` | (none) | No media inserted OR requested partition doesn't exist |
| **Unreadable** | `ID_BAD` | `CF0:BAD` | Disk read error or hardware failure |
| **Busy** | `ID_BUSY` | `CF0:BUSY` | Handler is inhibited (via `INHIBIT` command) |

**Partition specific behavior**

When you have multiple mount points (e.g., FAT\1, FAT\2, FAT\3) and insert a disk:

| Scenario | FAT\1 | FAT\2 | FAT\3 |
|----------|-------|-------|-------|
| 3-partition FAT disk | Mounted | Mounted | Mounted |
| 1-partition FAT disk | Mounted | No Disk | No Disk |
| RDB/PFS/SFS disk | Uninitialized | No Disk | No Disk |
| No disk inserted | No Disk | No Disk | No Disk |

This behavior ensures:
- **FAT\1** correctly shows "Uninitialized" for foreign formats (disk present, wrong type)
- **FAT\2, FAT\3, etc.** correctly show "No Disk" when the requested partition doesn't exist

The exact status shown may depend on the order of disk insertion and reinsertion.

## Tools Included

| Tool | Description |
|------|-------------|
| `l/fat95` | FAT95 filesystem handler |
| `l/install95` | Locale installer (read/write locale files) |
| `c/dd` | Raw block transfer tool |
| `c/debug95` | Debug information tool |
| `c/SetFileSize` | File size modification utility |
| `c/boot95` | Boot partition creation tool |

### dd Usage

Copy disk blocks to file:

```
dd scsi.device 1 ram:dump 0 128
```

Write file back to disk:

```
dd ram:dump scsi.device 1 0 128
```

### Debug95

Creates a dump of internal fat95 variables for diagnosis.
```
debug95 CF0: ram:cf0.log
```

### boot95

Booting from FAT Partition
```
boot95 CF0:
```

This installs an Amiga automount sequence in the unused area between
the MBR and first partition (~30KB). Requires fat95 in `L:` drawer.

**Caution:** Overwrites existing Amiga style partitioning info.

## License

GNU LGPL v2.1

## History

| Version | Date | Changes |
|---------|------|---------|
| v3.20 | 03/2026 | NTFS volume rejection |
| v3.19 | 02/2026 | GPT partition table support, improved disk change handling, Fixed trailing slashes in path names |
| v3.18 | 03/2013 | Open source release LGPL (Torsten Jager) |
| v3.17 | - | No info |
| v3.16 | - | No info |
| v3.15 | 05/2004 | Added "l" option (lowercase 8.3 names) |
| v3.14 | 05/2004 | Added "L" option (uppercase initial) |
| v3.13 | 02/2004 | PalmOS formatted memory card support |
| v3.12 | 11/2003 | Alternative disk recognition via SCSI, optional TD_UPDATE, faster small writes |
| v3.11 | 08/2003 | Optimized short name generator, directory updates during writes |
| v3.10 | 07/2003 | Fixed directory creation bugs, international character fixes |
| v3.09 | 04/2003 | Security erase feature, abortable scandisk |
| v3.08 | 10/2002 | Skipped version number |
| v3.07 | 09/2002 | File writing fix, SCSI auto-select, Hungarian localization |
| v3.06 | 08/2002 | Faster small file access |
| v3.05 | 07/2002 | New configuration options |
| v3.04 | 07/2002 | Removed startup messages, scandisk fixes, improved dd tool |
| v3.03 | 05/2002 | Removed DiskUpdate error message |
| v3.02 | 03/2002 | Directory creation fix, FAT12 CF card formatting, SCSI error checking |
| v3.01 | 02/2002 | Minor short name bug fix |
| v3.00 | 02/2002 | User character set for 8.3 names, official FAT32 cluster sizes |
| v2.19 | 01/2002 | Filenames up to 104 characters |
| v2.18 | 12/2001 | SetFileSize() support, user language support |
| v2.17 | 09/2001 | Faster FAT32, Amiga reformatted ZIPs recognized |
| v2.16 | 08/2001 | MaxTransfer fix, FileSystem.resource code sharing |
| v2.15 | 05/2001 | Crash fixes, pure attribute, error check, boot95 tool |
| v2.14 | 03/2001 | FAT32 mode bug fix |
| v2.13 | 02/2001 | New buffering system |
| v2.12 | 02/2001 | SCSI direct command support |
| v2.11 | 12/2000 | Better FDA compatibility |
| v2.10 | 10/2000 | Exotic partition tables, TD64 error requester |
| v2.9 | 09/2000 | AddBuffers fix, safer CURRENT_VOLUME, trackwise access |
| v2.8 | 08/2000 | Software write protection, fat95debug tool |
| v2.7 | 08/2000 | Logical drive recognition fix |
| v2.6 | 07/2000 | Disk full crash fix, inconsistent file access fix |
| v2.5 | 07/2000 | Track-wise buffering, FAT32 free space fix |
| v2.4 | 07/2000 | Exclusive locks fix, 8.3 name fixes |
| v2.3 | 07/2000 | Native ExAll(), ChangeMode(), various bugfixes |
| v2.2 | 06/2000 | Restart validator, 65-char filenames, FAT32 formatting |
| v2.1 | 04/2000 | NSD and TD64 support, FAT32 28-bit fix, timestamp fix |
| v2.0 | 04/2000 | First FAT32 support |
| v1.22 | 03/2000 | Large sectors fix (>512 bytes) |
| v1.21 | 03/2000 | Cluster-wise file access, diskchange messages |
| v1.20 | 03/2000 | Separate caches, workbench icon suppression |
| v1.19 | 03/2000 | Partition selection fix |
| v1.18 | 03/2000 | First partition support |
| v1.17 | 02/2000 | Second published version, improved FORMAT |
| v1.16 | - | No info |
| v1.15 | 02/2000 | Code optimizations |
| v1.14 | 02/2000 | FAT copy update fix |
| v1.13 | 02/2000 | SERIALIZE_DISK fix |
| v1.12 | 01/2000 | ETD commands, SERIALIZE_DISK, faster FAT16 writeback |
| v1.11 | 01/2000 | Device workarounds, faster drawer operations |
| v1.10 | - | No info |
| v1.9 | - | No info |
| v1.8 | 01/2000 | Workaround for register-trashing devices |
| v1.7 | 01/2000 | Formatting fix, double-mount crash fix, reentrant code |
| v1.6 | 12/1999 | Large partition fix, SID2 workaround, serial number, dir optimization |
| v1.5 | 11/1999 | First published version |
