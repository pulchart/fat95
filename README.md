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
* `ptable.library` v2 (in ROM or `LIBS:`) for whole-disk auto-detect
  mounts of MBR/GPT cards. Mountlist entries that give explicit
  geometry, and unpartitioned (superfloppy) volumes, do not need it.

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

## Release Notes

See [docs/changes.md](docs/changes.md) for release news and history.

## Documentation Included

- `docs/fat95.md` - main filesystem handler documentation.
- `docs/changes.md` - release notes and original fat95 history.
- `docs/dd.guide` - `dd` raw block transfer tool documentation.
- `docs/lsfsres.guide` - `lsfsres` FileSystem.resource lister documentation.

## Installation

**Introduction**

Installing disk drives under AmigaOS requires *two* components:

1. A **hardware driver** that provides block-level access to the drive. This can be part of the Kickstart ROM (e.g., `trackdisk.device`) or a separate file (e.g., `Devs:compactflash.device`).
2. A **filesystem handler** that manages partitions, directories, and files. The standard filesystem is in ROM. Others, like fat95, are files in the `L:` drawer.

These two components are connected via a **mountlist** - a configuration file that tells AmigaOS how to mount the drive.

**Installation**

1. Pick the CPU tier that matches your machine (see [CPU tiers](#cpu-tiers)) and copy the matching `l/<tier>/fat95` to `L:fat95`:
   ```
   # A1200 stock or any 68020+/030/040/060 accelerator
   Copy fat95/l/68020/fat95 L:fat95

   # Stock A500 / A600 / A1000 / A2000 / CDTV (68000)
   Copy fat95/l/68000/fat95 L:fat95
   ```
2. Edit the `install_fat95` text file for your language.
3. Double-click the `install_fat95` icon to activate the changes.
4. Optionally double-click example mountlist icons in `DOSDrivers/`:
   - `MS0`/`MS1` - FAT-formatted PC DD 720k floppy (mfm.device)
   - `CF0` - FAT partition on CompactFlash in PCMCIA slot (compactflash.device), supports MBR and GPT
   For custom configurations, see the [Mountlist Configuration](#mountlist-configuration) section.
5. Copy mountlists to:
   - `DEVS:DOSDrivers/` for automatic mounting at boot, or
   - `SYS:Storage/DOSDrives/` for manual mounting via shell command (Method A: Shell Command)

### CPU tiers

fat95 3.21+ ships as two CPU tiers. Copy the one that matches your CPU to `L:fat95`:

| Tier | File | Target |
|------|------|--------|
| 68020+ | `l/68020/fat95` | A1200 stock + any 68020 / 030 / 040 / 060 accelerator |
| 68000  | `l/68000/fat95` | stock A500 / A600 / A1000 / A2000 / CDTV |

The two tiers are functionally identical. The 68020+ tier is slightly smaller and uses native 32-bit `mulu.l` / `divul.l` / `bfffo`; the 68000 tier falls back to library routines and is the only version that is safe to run on a plain 68000.

You can confirm which tier you have loaded by reading the `$VER:` string:

```
version fat95 full
fat95 3.21 (17.04.2026)
[68020]
```

## Mountlist Configuration

### Device Driver Settings

First, the name of the driver:

```
Device = scsi.device
```

That's the one responsible for the Amiga's internal IDE or SCSI port. Usually, multiple drives can be connected to such a port. Therefore, we need to state which one we want:

```
Unit = 1
```

This is the "slave" IDE drive (e.g., a ZIP drive). The "master" harddisk has number 0. For drivers with a single drive only, it is also 0.

```
Flags = 0
```

Some drivers allow special settings to be made via this one. Most cases, that 0 is enough.

```
BufMemType = 1
MaxTransfer = 0x20000
Mask = 0xfffffffe
```

For the (unpatched) A1200 ROM scsi.device. Or if driver doesn't need them, simply discard.

### File System Settings

```
Filesystem = l:fat95
```

AmigaOS wants the full path here.

```
StackSize = 4096
```

Reserve that many bytes for temporary data. State too few, and "mysterious" crashes will happen.

```
GlobVec = -1
```

fat95 is assembly language written, so -1.

```
Buffers = 200
```

Hold that many blocks of 512 bytes each in memory. More = Faster = Less memory available.

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
| `q` | Quiet: never open error requesters (read/write/reinsert windows); errors are reported to the caller instead. Recommended for hot-plugged removable media | OFF |

Regardless of `q`, no requester is opened once the handler has been asked to quit (`ACTION_DIE`), so an unmount can never stall behind a window.

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

**Choosing which partition to mount**

There are two ways to tell fat95 which FAT partition a mount should use. Both work, and you can use them at the same time on one system. Each mountlist picks its way by its **DosType** value, so use whichever you like.

*Option A: DosType byte (`FAT\<n>`)*

The partition selector is the last byte of the DosType. The device name can be anything you like.

| DosType | Hex Value | Description |
|---------|-----------|-------------|
| FAT\0 | 0x46415400 | Floppies only |
| FAT\1 | 0x46415401 | First FAT partition |
| FAT\2 | 0x46415402 | Second FAT partition |
| FAT\3 | 0x46415403 | Third FAT partition |
| FAT\4 | 0x46415404 | Fourth FAT partition |
| FAT\5 | 0x46415405 | First logical drive (extended partition) |
| FAT\6 | 0x46415406 | Second logical drive, etc. |

*Option B: device name suffix*

Use DosType `0x464154FF` for **every** FAT mount, and the number at the end of the device name picks the partition. The number is 0-based, like `DF0:` and `HD0:`:

| Device name | DosType | Mounts |
|-------------|---------|--------|
| `CF0:` | 0x464154FF | First FAT partition |
| `CF1:` | 0x464154FF | Second FAT partition |
| `CF9:` | 0x464154FF | Tenth FAT partition |
| `CF:` (no number) | 0x464154FF | First FAT partition (default) |

The whole trailing digit run is read as one decimal number from 0 to 254 (`CF255:` and above fail the mount). To mount several partitions from one card, copy the mountlist to `CF0`, `CF1`, `CF2`. The DosType stays the same; only the leading device name differs.

Because every FAT mount uses the same DosType (`0x464154FF`), fat95 needs only one entry in `FileSystem.resource`, no matter how many partitions you mount. With the DosType-byte way each distinct `FAT\<n>` you use needs its own `FileSystem.resource` entry (and when fat95 is ROM-resident it registers `FAT\0`..`FAT\8` as nine separate entries at boot). One entry instead of many means a little less memory and a shorter resource list. You can see the entries with the [`lsfsres`](docs/lsfsres.md) tool.

*Floppies and other unpartitioned media* behave identically under both schemes: the whole disk is mounted as one FAT volume and the partition selector is ignored (the physical drive is chosen by `Unit=`). A floppy mountlist using either DosType mounts the same way.

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

For GPT disks, fat95 considers only partition entries whose **type GUID** is one of the following:

| Type GUID | Description |
|-----------|-------------|
| `EBD0A0A2-B9E5-4433-87C0-68B6B72699C7` | Microsoft Basic Data |
| `C12A7328-F81F-11D2-BA4B-00A0C93EC93B` | EFI System Partition |

Other GPT entries (Windows Recovery, Linux filesystems, unused slots, etc.) are skipped when assigning FAT\1, FAT\2, …

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

Two options based on DosType, both mount the first FAT partition (see [Partition Selection](#partition-selection)).

```
CF0:
    FileSystem     = L:fat95
    Device         = compactflash.device
    Unit           = 0
    Flags          = 0
    LowCyl         = 0 /* Auto partition search */
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

    /* Option A: DosType byte (`FAT\<n>`): FAT\1 = first FAT partition */
    DosType        = 0x46415401

    /* Option B: DosType byte (`FAT\255`): partition by device name e.g. cf0 = first FAT partition */
    DosType        = 0x464154FF

    Activate       = 1
```

For devices with more than one FAT partition:

- Option A: copy the mountlist and change `DosType` to `0x46415402` (FAT\2), `0x46415403` (FAT\3), and so on, matching the table in [Partition Selection](#partition-selection).
- Option B: copy the mountlist to `CF1`, `CF2`, ... and keep `DosType = 0x464154FF`. The number on the device name picks the partition.

The `FileSystem = l:fat95` line stays in every copy. AmigaOS `Mount` needs it even when fat95 is already in ROM, because the `FileSystem.resource` auto-lookup only fires on the auto-mount path, not on text-file DOSDrivers.

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
| `c/lsfsres` | FileSystem.resource entry lister |
| `c/lsptres` | partition.resource entry lister (from ptable.library) |
| `libs/<cpu>/ptable.library` | partition scan/automount library (small), bundled |

`ptable.library` and `lsptres` are built from the companion [amigaos-ptable](https://github.com/pulchart/amigaos-ptable) repo and bundled here so whole-disk auto-detect works without a separate install; `lsptres` lists `partition.resource` (the partition-side companion to `lsfsres`).

### dd

Raw block transfer tool. See [docs/dd.md](docs/dd.md) for more details.

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

This installs an Amiga automount sequence in the unused area between the MBR and first partition (~30KB). Requires fat95 in `L:` drawer.

**Caution:** Overwrites existing Amiga style partitioning info.

### lsfsres

Lists `FileSystem.resource` entries. See [docs/lsfsres.md](docs/lsfsres.md) for more details.

### lsptres

Lists `partition.resource` entries (bundled from ptable.library). The partition-side companion to `lsfsres`.

## License

GNU LGPL v2.1
