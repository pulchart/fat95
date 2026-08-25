## 20260825-dev

<!-- COMPONENTS:BEGIN -->
_Components in this release_:

- `fat95 4.0-dev (25.08.2026)` _(new)_
- `install95 3.19 (25.01.2026)`
- `dd 2.3 (16.08.2026)` _(new)_
- `debug95 3.19 (25.01.2026)`
- `SetFileSize 1.1 (25.01.2026)`
- `boot95 3.19 (25.01.2026)`
- `lsfsres 1.0 (16.05.2026)`
- `ptable.library 2.0-dev (18.08.2026)` _(new)_
- `lsptres 1.0-dev (30.07.2026)` _(new)_
<!-- COMPONENTS:END -->


#### fat95 handler

- **New `q` (quiet) option.** Control `"+q"` silences all fat95 error windows for a mount (errors go to the calling program instead). Unmounting a removed card now cancels any open window automatically.
- **Shared partition scanning.** fat95 auto-detects its FAT partition (MBR, GPT, and flat whole-disk FAT) from the shared `partition.resource` published by `ptable.library`, the same scan used by `compactflash.device`, instead of scanning the partition table itself. The resolved mount Flags/CONTROL and the DosType the mount carries are reported and shown by `lsptres`. Auto-detect now requires `ptable.library` (bundled, install to `LIBS:`); explicit-geometry mountlist entries still mount without it. See [ptable.md](https://github.com/pulchart/amigaos-ptable/blob/HEAD/docs/ptable.md) and [lsptres.md](https://github.com/pulchart/amigaos-ptable/blob/HEAD/docs/lsptres.md). The `ptable.library` and `lsptres` are now bundled in the archive, shared with the CompactFlash driver. `lsptres` lists `partition.resource`.
- Pulling a card while a Workbench window or an open file still holds the volume no longer stalls the driver: fat95 declines to quit at once and stays in service, so the partition is kept and the card mounts again when reinserted.
- Fixed: duplicating the ZERO lock with no card inserted could crash.

#### Tools

#### dd 2.3
- A 64-bit transfer command (`NSCMD_TD64`, or classic `TD64`) is now used whenever the driver advertises one, not only past 4 GiB.
- New `CMDSRC` (`CS=`) and `CMDDST` (`CD=`) force the transfer command for one side only. `CMD` still sets both sides. Only a real `.device` side is affected.
- A forced command the driver does not advertise is now reported before the transfer, together with the methods the device does offer. An I/O error `-3` points at `dd INSPECT`.
- New `MAXTRANSFER` (`MT=`) sets the bytes per device request (default 130560).
- New `MEM` sets the buffer memory type (`ANY|PUBLIC|CHIP|FAST|24BIT`), instead of the type the driver reports.
- Every transfer prints an `xfer:` line with the bytes per request in use.
- `INSPECT` also reports the buffer memory type and the device type.
- A driver reporting fewer bytes moved than requested is reported once per transfer.
- Fixed: a source file that is not a whole number of blocks lost its last partial block.
- Fixed: a bad buffer when a device does not report its geometry.
- Fixed: a hang when the block size exceeds one request.

## 20260614

_Components in this release_:

- `fat95 3.24 (07.06.2026)`
- `install95 3.19 (25.01.2026)`
- `dd 2.2 (13.06.2026)` _(new)_
- `debug95 3.19 (25.01.2026)`
- `SetFileSize 1.1 (25.01.2026)`
- `boot95 3.19 (25.01.2026)`
- `lsfsres 1.0 (16.05.2026)`

#### Tools

This release is mainly a `dd` maintenance update. `dd 2.2` adds TD64 support for large-disk transfers, fixes unreliable NSD detection from the previous `dd` release, and improves INSPECT output.

#### dd 2.2

IO (transfer) command usage changes:
- Added TD64 support through `TD_READ64` and `TD_WRITE64`
- Runtime fallback from `NSCMD_TD64` to `TD64` to `HD_SCSICMD`.
- Hardened the `NSD` probe, fixing issue #20.
- `INSPECT` now reports all detected >4 GiB I/O transfer methods.
- `INSPECT VERBOSE` now lists all supported commands.
- Added a new `CMD=AUTO|CMD|TD64|NSCMD|SCSI` argument to force the transfer command.

#### dd 2.1

- On Kickstart older than 2.0 (V36), `dd` now prints a short message saying it needs Kickstart 2.0+ and exits, instead of failing silently.
- Console output now uses `VFPrintf`.

## 20260609

_Components in this release_:

- `fat95 3.24 (07.06.2026)` _(new)_
- `install95 3.19 (25.01.2026)`
- `dd 2.0 (01.06.2026)` _(new)_
- `debug95 3.19 (25.01.2026)`
- `SetFileSize 1.1 (25.01.2026)`
- `boot95 3.19 (25.01.2026)`
- `lsfsres 1.0 (16.05.2026)`

#### fat95 handler

- **fat95 3.24** Adds a second way to choose which FAT partition a mountlist mounts via _Device name suffix._ Set `DosType` to `0x464154FF` for every FAT mount, and the number at the end of the device name picks the partition. The number is 0-based, like `DF0:` and `HD0:`: `CF0:` is the first FAT partition, `CF1:` the second, and so on. The old way _DosType byte (`FAT\<n>`)_ is unchanged, and you can mix them on one system. See [Partition Selection](../README.md#partition-selection) for full details.

#### Tools

##### dd 2.0

Major update with **breaking change** in argument positioning and parsing.

- _CLI parsing (breaking change)._ `dd` now uses the standard AmigaOS argument parser, so bad arguments are caught up front instead of silently mis-parsed. Type `dd ?` for the new usage banner. The unit number moved from between SRC and DST to a single positional slot after DST; for device-to-device copies use the keyword form `US <n>` / `UD <n>`. `FILL:`, `RSPEED:`, `RWSPEED:` are unchanged. See [dd Usage](dd.md) for more details.
- _NSD 64-bit I/O support._ `dd` now probes NSD at device open and uses `NSCMD_TD_READ64`/`NSCMD_TD_WRITE64` when the driver advertises them. This is an additional dispatch path next to the existing `HD_SCSICMD` (SCSI READ10/WRITE10) fallback that already handles >4 GiB I/O on drivers without NSD.
- _INSPECT mode._ `dd INSPECT <device.name> [UNIT n]` prints device geometry, NSD support (if any), and which command set dd would use for I/O on the device.

#### Packaging

- **Archive version is now a date (YYYYMMDD).** The release bundle ships several independently-versioned pieces (`fat95`, `install95`, `dd`, `debug95`, `SetFileSize`, `boot95`, `lsfsres`), each on its own cadence, so a single `v3.x` number for the whole archive never matched what was actually inside.

## 3.23 (19.05.2026)

This release brings several reliability fixes, contributed by Stefan Reinauer (@reinauer). Thanks!

- **Bug fixes**
  - File position is now correctly advanced after a short (partial) write, preventing data corruption on subsequent writes to the same file handle.
  - SCSI READ10/WRITE10 commands now correctly clamp the block count to 16 bits; previously, large I/O requests could silently transfer fewer blocks than requested.
  - I/O retries are now aborted if the disk was swapped during a retried read or write, preventing silent data corruption when media changes mid-operation.
  - The `..` (parent) directory entry for subdirectories created under the FAT32 root now correctly stores cluster 0, fixing `fsck.vfat` complaints on FAT32 volumes.
  - The free-cluster scan in `ExtendChain` is now bounded to avoid an infinite loop on a corrupted or full FAT.

- **Performance**
  - FAT16 free-cluster counting during mount is now ~50% faster on 68000, by scanning the raw FAT buffer directly instead of calling the generic `GetFATEntry` path per entry.

## 3.22 (16.05.2026)

This release improves ROM resident handling:

- ROM resident installation now registers `FAT\0` through `FAT\8` in `FileSystem.resource` at boot, so any partition with one of those DosTypes, whether RDB auto-mounted or mounted later via a mountlist / mount command, uses the ROM handler directly and skips loading `L:fat95` from disk. Previously the ROM resident registration did not actually run at boot, so even with fat95 baked into a Kickstart ROM every FAT mount fell back to loading `L:fat95` from disk.
- New `c/lsfsres` tool lists every entry in `FileSystem.resource` with DosType, version, SegList address, handler name, and a `[ROM]`/`[RAM]` tag. Useful for confirming which filesystem handlers are active and whether they come from ROM or disk.

This release also contains internal micro-optimisations and minor size reductions:

- Several inner loops are optimised for both CPU tiers.
- Directory block clearing and file delete are faster on 68000.
- FAT entry reads on 68020+ use fewer instructions.
- SCSI READ10/WRITE10 command setup now uses a shared helper.
- GPT partition GUID matching is now table-driven.

## 3.21 (18.04.2026)

This release focuses on stability and compatibility improvements across both CPU tiers (`68000`/`68010` and `68020+`).

- **Improvements**
  - Fixed an unaligned long-word compare in the NTFS boot-sector check that could raise an Address Error on 68000/010.
  - GPT partition detection (3.19+) now follows the AmigaOS register-preservation rules; a violation could have corrupted caller state after a mount.
  - Partition state is reset before every mount attempt, so a failed or rejected probe can no longer influence the next one.
  - GPT FAT allowed partition type GUIDs are now both Microsoft Basic Data (`EBD0A0A2-B9E5-4433-87C0-68B6B72699C7`) and EFI System Partition (`C12A7328-F81F-11D2-BA4B-00A0C93EC93B`).

- **CPU-tier builds**
  - fat95 now ships in two CPU tiers. Copy the one matching your CPU to `L:fat95`:
    - `l/68020/fat95` -- A1200 stock + 68020+ accelerators (030/040/060)
    - `l/68000/fat95` -- stock A500 / A600 / A1000 / A2000 / CDTV
  - 68020+ build is slightly smaller thanks to native 32-bit math. See [CPU tiers](../README.md#cpu-tiers).
  - The `$VER:` string is tagged `[68020]` or `[68000]`, so `version l:fat95 full` shows which tier is loaded.

## 3.20 (16.03.2026)

- **NTFS volume rejection**
  - NTFS volumes are now explicitly rejected and reported as unrecognised instead of being incorrectly mounted as an unnamed FAT volume with its serial number as the volume name (e.g. "0000-0100").
  - Affects GPT disks (both FAT and NTFS share the same "Microsoft Basic Data" partition GUID), MBR disks where an NTFS partition was placed in a FAT partition slot (e.g. type 0x0B/0x0C), and unpartitioned direct volume access paths.
  - Relates to github issues: [pulchart/cfd#37](https://github.com/pulchart/cfd/issues/37), [salass00/ntfs-3g#3](https://github.com/salass00/ntfs-3g/issues/3)

## 3.19 (01.02.2026)

- **Fork of 3.18**
  - Set English as default localization for fat95 handler.
  - Rebuild by vasm 2.0d.
  - Consolidated documentation into fat95.guide.

- Detect SFS/PFS/FFS/RDB as foreign disk formats.

- **GPT partition table support**
  - Automatic detection of GPT disks via protective MBR (type 0xEE).
  - Scans GPT partition entries whose type GUID is Microsoft Basic Data or EFI System Partition (FAT candidates).
  - Supports partition selection via DosType (same as MBR: FAT\1, FAT\2, etc.).

- **Improved disk change handling**
  - Non-existent partitions now show "No Disk" instead of "Uninitialized".
  - Fixes stale partition data when switching to cards with fewer partitions. See [Disk Status Meanings](../README.md#disk-status-meanings).
  - Foreign disk formats (RDB, PFS, SFS) show appropriate status per partition.

- **Bug fixes**
  - Fixed trailing slashes in path names (e.g., `makedir cf0:temp/` now correctly creates `temp`).
  - WARNING: Using trailing slashes with 3.18 corrupted the filesystem.

## Original fat95 History Through v3.18

| Version | Date | Changes |
| ------- | ---- | ------- |
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
