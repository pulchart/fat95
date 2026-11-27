# fat95 integration tests

fat95 under AmigaOS 3.1, AmigaOS 3.2.3 and AROS in FS-UAE (A1200): PC floppies through mfm.device and disks with FAT partitions. No PCMCIA, no compactflash.device.

## Running

```
make test-integration                                # every scenario on every OS profile
make test-integration IT="--os 3.1 --scenario sf_fat32"
tests/integration/run.py --list                      # scenarios, the OSes they run on, description
tests/integration/run.py --config FILE               # another configuration (default: config.yaml here, or $FAT95_IT_CONFIG)
tests/integration/run.py --work DIR                  # a new directory for this run
```

`make test-integration` builds `smoke` first; run.py alone needs `make smoke`. The run first prints its plan: per OS profile the scenarios it runs, or why the profile is skipped. Exit code 0 when every scenario that ran passes. Each run gets a new directory under `work`; nothing is written into the source tree outside it.

## Configuration

`config.yaml` holds the inputs that are not part of the repository. A relative path starts at the repository root, so `../amigaos-ptable` is a checkout beside this one.

`os` names the OS profiles. A profile whose files are missing is skipped. An AmigaOS profile:

| Key | Content |
|---|---|
| `kickstart` | Kickstart ROM; a `.F8` half takes the `.E0` half beside it |
| `commands_adf` | disks the boot disk takes its C: commands from, searched in order |
| `workbench_adf` | disk with `Devs/mfm.device` |

An AROS profile:

| Key | Content |
|---|---|
| `kickstart`, `kickstart_ext` | AROS ROM halves |
| `system_dir` | AROS system directory; a copy of it is the boot volume |

Optional per profile:

| Key | Default | Meaning |
|---|---|---|
| `ide_device` | `scsi.device` | device the disk mountlists use |
| `ide_controller` | `ide0` | FS-UAE controller the disk is attached to |
| `ide_unit` | `0` | unit of the disk on `ide_device` |
| `ptable` | `true` | `false` leaves ptable.library off the boot volume |
| `stack` | `8192` | handler stack, in the mountlists and the RDB |
| `max_transfer` | `0x20000` in mountlists, RDB default | MaxTransfer |
| `copy` | `Copy` | command that moves files between `OUT:` and the fat95 volume |
| `cpu` | `68020` | FS-UAE CPU |
| `fast_memory` | `8192` | Fast RAM in KB |
| `fsuae` | none | extra FS-UAE lines |

Builds:

| Key | Default |
|---|---|
| `fat95`, `dd`, `lsfsres` | this repository's `dist/` |
| `debug95` | this repository's `dist/`; optional, dumps the handler state into `OUT:` |
| `ptable` | none: ptable.library build, fat95 reads partition tables through it |

Optional parameters: `work` (`build/integration`), `fsuae` (`fs-uae`), `vasm` (`vasmm68k_mot`), `wait` (`5` seconds after a mount), `limit` (`240` seconds before a scenario counts as hung; a scenario can set its own).

## Scenarios

`scenarios.yaml` lists them: the medium, its layout, the OS profiles, the AmigaDOS steps as named fragments and the check set. The check sets are in `scenarios.py`.

`smoke` (`tools/smoke.c`) runs on the mounted volume: a 128 KiB + 1 file written and read back, reads across 512, 4096 and 65536, seeks from the start, the current position and the end, `SetFileSize` down and up, a long name in a subdirectory, rename into another directory, delete.

| Scenario | OS | Checks |
|---|---|---|
| `floppy_fat12` | 3.1, 3.2.3 | PC 720K floppy through mfm.device: payload reads back, `smoke` passes, a written file reads back and lands on the image |
| `disk_fat16` | all | MBR FAT16 partition: the same |
| `disk_fat32` | all | MBR FAT32 partition: the same |
| `sf_fat32` | all | FAT32 from block 0, no partition table: the same |
| `rdb_fat32` | all | RDB that carries fat95 and a FAT32 partition, mounted by the OS at boot: the same |

## Host tools

FS-UAE, xvfb-run, amitools (`xdftool`, `rdbtool`), sfdisk, mkfs.fat, mtools, gzip, vasm, vbcc with `NDK/` for `smoke`, Python 3 with PyYAML.

## Phases

1. Plan: the OS profiles and scenarios that run, the profiles that are skipped.
2. Preparation per OS: an AmigaOS boot disk with the C: commands from `commands_adf`, mfm.device, fat95, dd, lsfsres, ptable.library, `noreq` and `smoke`; or a copy of the AROS system directory with the same files.
3. Per scenario: the medium image, a mountlist and the steps, in the host directory the guest sees as `OUT:`.
4. Boot: the Startup-Sequence runs the steps; the guest writes its findings to `OUT:`.
5. Checks: on `OUT:` and the medium image (mtools).

FS-UAE is started a second time when it exits or the guest has not begun its steps within 60 seconds.

## Emulation

- Floppies run at 8x (`floppy_drive_speed = 800`).
- Disks are attached as whole disks (`hard_drive_N_type = rdb`); type `hdf` wraps a disk without an RDB in an RDB that FS-UAE makes up.
- An unpartitioned medium is as large as its mountlist says, so those mountlists cover the whole disk.
- The RDB filesystem entry carries the stack size; without it the Kickstart starts the handler on its small default stack and writes hang.
- `noreq` turns requesters off for the shell, so a missing volume fails a step instead of blocking the run.

## AROS

- Info prints `read/write`; the check ignores case.
- AROS `Copy` to and from the FS-UAE host directory (`OUT:`) fails with "object already exists" and "object is in use"; the profiles set `copy: dd`.
- The nightly ata.device sends the second data block of a WRITE MULTIPLE above 128 sectors before the drive asks for it, and the write fails; the profile sets `max_transfer: 0x10000`.
- The ApolloOS ata.device fails with "Failed to Allocate CacheData" in FS-UAE, so that profile puts the disk on the UAE controller (`uaehf.device`).

## Not covered

- AROS and PC floppies: no mfm.device.
