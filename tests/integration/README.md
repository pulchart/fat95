# fat95 integration tests

fat95 under AmigaOS 3.1, AmigaOS 3.2.3, AROS and ApolloOS in FS-UAE (A1200, and AmigaOS as an A600 with the 68000 builds): PC floppies through mfm.device and disks with FAT partitions. No PCMCIA, no compactflash.device.

## Running

Each OS runs in an [amiga-fsuae](https://github.com/pulchart/container-amiga-fsuae) image with podman, one after another:

| OS | image |
|---|---|
| `3.2.3-a1200`, `3.1-a1200`, `3.2.3-a600`, `3.1-a600` | `localhost/amiga-fsuae-amigaos:<version>`, built locally from own install media |
| `aros` | `ghcr.io/pulchart/amiga-fsuae-aros:latest` |
| `apolloos` | `ghcr.io/pulchart/amiga-fsuae-apolloos:latest` |

```
make test-integration PTABLE=...                     # every scenario on every OS, except stress_
make test-integration IT_OS=aros IT="--scenario sf_fat32"
make test-stress                                     # stress_fat16 and stress_fat32 on every OS
make test-integration IT_OS=3.2.3-a1200 IT="--scenario stress_fat12"   # a stress_ scenario runs only when named
tests/integration/run.py --list                      # scenarios, the OSes they run on, description
```

`make test-integration` builds `smoke` and `noreq` first and mounts the repository and the run directory at the same paths. A `stress_` scenario fetches FileSystemStressTest 1.2 from Aminet (disk/misc) once into `build/fsst`, checked against its SHA-256. `make` with `PTABLE` puts ptable.library into `dist/libs`. Exit code 0 when every scenario passes. Each run gets a new directory under `build/integration`, or `IT_WORK`. CI runs `aros` and `apolloos` only, the scenarios and `stress_fat16` with `stress_fat32` in parallel jobs, with FileSystemStressTest kept in the Actions cache.

In an image, as in CI:

```
tests/integration/run.py --os aros [--scenario NAME ...] [--work DIR] [--config FILE]
```

run.py takes the OS from the image: `AMIGA_SYSTEM` is the system directory, `AMIGA_KICKSTART` the ROM, `AMIGA_KICKSTART_EXT` its second half and `AMIGA_HD_CONTROLLER` the FS-UAE controller for disks (default `ide0`), if any.

## Configuration

`config.yaml` (or `--config`, `$FAT95_IT_CONFIG`) names the OS profiles in `os` with their settings, and the builds. A relative path starts at the repository root.

Optional per profile:

| Key | Default | Meaning |
|---|---|---|
| `ide_device` | `scsi.device` | device the disk mountlists use |
| `ide_unit` | `0` | unit of the disk on `ide_device` |
| `ptable` | `true` | `false` leaves ptable.library off the boot volume |
| `setpatch` | `true` | `false` leaves `SetPatch` out of the Startup-Sequence |
| `stack` | `8192` | handler stack, in the mountlists and the RDB |
| `max_transfer` | `0x20000` in mountlists, RDB default | MaxTransfer |
| `copy` | `Copy` | command that moves files between `OUT:` and the fat95 volume |
| `cpu` | `68020` | FS-UAE CPU |
| `model` | `A1200` | FS-UAE Amiga model, and the image's `<model>.rom` beside `AMIGA_KICKSTART` |
| `tier` | none | `68000`: the 68000 builds of fat95 and ptable.library |
| `fast_memory` | `8192` | Fast RAM in KB |
| `fsuae` | none | extra FS-UAE lines |

Builds:

| Key | Default |
|---|---|
| `fat95`, `dd`, `install95`, `lsfsres` | this repository's `dist/` |
| `ptable` | `dist/libs/full/68020/ptable.library`; fat95 reads partition tables through it |
| `debug95` | this repository's `dist/`; optional, dumps the handler state into `OUT:` |

Optional parameters: `work` (`build/integration`, for run.py alone), `fsuae` (`fs-uae`), `wait` (`5` seconds after a mount), `limit` (`240` seconds before a scenario counts as hung; a scenario can set its own).

## Scenarios

`scenarios.yaml` lists them: the medium, its layout, the OS profiles, the AmigaDOS steps as named fragments and the check set. The check sets are in `scenarios.py`.

`smoke` (`tools/smoke.c`) runs on the mounted volume: a 128 KiB + 1 file written and read back, reads across 512, 4096 and 65536, seeks from the start, the current position and the end, `SetFileSize` down and up, a long name in a subdirectory, rename into another directory, delete.

| Scenario | OS | Checks |
|---|---|---|
| `floppy_fat12` | AmigaOS | PC 720K floppy through mfm.device: payload reads back, `smoke` passes, a written file reads back and lands on the image |
| `disk_fat16` | all | MBR FAT16 partition: the same |
| `disk_fat32` | all | MBR FAT32 partition: the same |
| `sf_fat32` | all | FAT32 from block 0, no partition table: the same |
| `rdb_fat32` | all | RDB that carries fat95 and a FAT32 partition, mounted by the OS at boot: the same |
| `stress_fat12` | AmigaOS | PC 720K floppy: FileSystemStressTest as below |
| `stress_fat16` | all | MBR FAT16 partition, 128 MiB, 68040 with JIT: two FileSystemStressTest writers with small files in one directory at once, then large files, then the volume filled; every file validated and removed, the directory empty, fsck clean, the handler's free clusters equal to the image's |
| `stress_fat32` | all | the same on FAT32 with 512-byte clusters |
| `names` | all | FAT16 with long names outside the code page (`fatnames.py`), among them an emoji, a `^` and a czech name: each listed with its `^` escapes, typed back (an escape in lower case too), copied, renamed and created; `Delete a^880.txt` leaves `a880.txt`; the image checked by name and contents, fsck clean |
| `names_pct` | all | the same names with `Control +n%`: listed with `%` escapes, `^` plain; where `Type` reads `%` as a pattern (AmigaOS) `a%880.txt` finds `a880.txt` and `a'%880.txt` the file |
| `names_off` | all | the same names with `Control -n`: `_` for every character outside the code page, an emoji as one |
| `install95` | all | `install95` writes every language of `dist/locale` into a copy of the handler and reads it back the same; no arguments, no mode, a missing language, a missing or write-protected handler and the handler as language file give their message and rc 10; the handler set to czech mounts the names volume, lists the names in its code page and creates one typed in it |
| `installer` | 3.2.3 | the Installer scripts of the release tree in NOVICE, driven by clicks: Language on fat95 4.2 of the last release asks, takes No and leaves it as it was; Install puts fat95 5.0 for the CPU in place with the execute bit, ptable.library 3.0, lsptres and the language english |

## Host tools

podman; the images bring the rest. `make test-integration` builds `smoke`, `noreq` and the release tree (`make stage`) in the amiga-toolchain image first. The `installer` scenario fetches fat95 4.2 from its release once into `build/deps`, checked against its SHA-256.

## Phases

1. Plan: the scenarios of the OS.
2. Preparation: a copy of the system directory with fat95, dd, install95, lsfsres, ptable.library, `noreq` and `smoke`, plus FileSystemStressTest as `C:fsst` for a `stress_` scenario.
3. Per scenario: the medium image, a mountlist and the steps, in the host directory the guest sees as `OUT:`.
4. Boot: the Startup-Sequence runs the steps; the guest writes its findings to `OUT:`.
5. Checks: on `OUT:` and the medium image (mtools).

FS-UAE is started a second time when it exits or the guest has not begun its steps within 60 seconds.

## Emulation

- Floppies run at 8x (`floppy_drive_speed = 800`).
- Disks are attached as whole disks (`hard_drive_N_type = rdb`); type `hdf` wraps a disk without an RDB in an RDB that FS-UAE makes up.
- An unpartitioned medium is as large as its mountlist says, so those mountlists cover the whole disk.
- An MBR disk has 1 MiB free after its partition. The AmigaOS 3.1 scsi.device addresses the disk through its CHS geometry and cannot reach the last blocks, so a partition up to the end fails when it fills.
- The RDB filesystem entry carries the stack size; without it the Kickstart starts the handler on its small default stack and writes hang.
- `noreq` turns requesters off for the shell, so a missing volume fails a step instead of blocking the run.
- A scenario with `gui` steps runs Xvfb on display 99 at 1024x768. When the guest writes `OUT:gui`, the host moves the Amiga pointer with Amiga+cursor keys (FS-UAE has no absolute X mouse), clicks with xdotool and saves a screenshot after each step.
- The RAM: of AmigaOS 3.1 and AROS ignores a cleared `w` bit, so `install95` meets its write-protected handler on the FAT volume.

## AROS

- Info prints `read/write`; the check ignores case.
- AROS `Copy` to and from the FS-UAE host directory (`OUT:`) fails with "object already exists" and "object is in use"; the profiles set `copy: dd`.
- ApolloOS finds IDE only on Apollo boards, so its image puts disks on the UAE controller and the profile mounts them through `uaehf.device`.

## Not covered

- The Installer on AmigaOS 3.1: the 3.1 image holds the Workbench disk only, without Installer.
- AROS and PC floppies: no mfm.device.
