# dd - Raw block transfer tool

`dd` reads and writes raw disk blocks. Since dd 2.0 it uses the AmigaOS argument parser. Type `dd ?` (or `dd HELP`) to see the quick reference.

## Template

```
SRC,DST,UNIT/N,START/N,COUNT/N,BS/N,US=UNITSRC/N/K,UD=UNITDST/N/K,HELP=H/S,INSPECT=I/K
```

## Positional form

```
dd <src> <dst> [<unit>] [<start>] [<count>] [<blocksize>]
```

`SRC` and `DST` are required. The single `UNIT` slot applies to whichever of `SRC`/`DST` is a `.device`. If **both** are devices, use the keyword form `US <n>` / `UD <n>` to disambiguate.

## Special names

| Name | Where | Meaning |
|---|---|---|
| `FILL:` | SRC | Infinite stream of zero bytes. `FILL:255`, `FILL:170`, ... for other byte values. |
| `RSPEED:` | DST | Read-only throughput benchmark (no actual write). |
| `RWSPEED:` | DST | Read+write throughput benchmark. |

## INSPECT mode

`dd INSPECT <device.name> [UNIT n]` (short: `dd I <device.name>`) probes the device and prints what dd sees, without doing any I/O:

```
dd INSPECT compactflash.device UNIT 0
```

Example output:

```
scsi.device unit 0:
  sector size:    512
  total sectors:  7831152
  cylinders:      7769
  heads:          16
  sec/track:      63
  NSD:            not supported
  for <=4 GiB:    CMD_READ / CMD_WRITE
  for  >4 GiB:    HD_SCSICMD / HD_SCSICMD
```

The output covers:

- Sector size, total sectors, CHS geometry (cylinders/heads/sec-per-track).
- NSD probe result: `not supported`, or `supported, commands:` followed by the driver's full `SupportedCommands` list (each command name printed on its own line, e.g. `CMD_READ`, `NSCMD_TD_READ64`, `HD_SCSICMD`, ...).
- Which command set dd would use for a transfer on this device, both for ranges that fit in 4 GiB byte-addressing (`CMD_READ` / `CMD_WRITE`) and for ranges past 4 GiB (either `NSCMD_TD_READ64` / `NSCMD_TD_WRITE64` if NSD advertises them, or `HD_SCSICMD` as fallback).

Useful for diagnosing >4 GiB transfer issues: if the device's `NSD: not supported`, dd falls back to `HD_SCSICMD` (SCSI READ10/WRITE10) and any LBA bug in the driver's SCSI emulation will surface there. Compare the INSPECT output between a working setup and a failing one to spot driver version or capability differences.

Every real transfer also prints a one-line "read: ... via <cmd>" and "write: ... via <cmd>" before the data loop starts, so you can confirm the dispatched command without re-running INSPECT.

## Examples

```
; copy 128 blocks from scsi.device unit 1 into a file
dd scsi.device ram:dump 1 0 128

; write a file back to scsi.device unit 1
dd ram:dump scsi.device 1 0 128

; zero-fill compactflash.device unit 0 (entire disk)
dd FILL: compactflash.device 0

; read 2000 blocks at LBA 8388000 from CF unit 0 into a file
dd compactflash.device ram:chunk 0 8388000 2000

; device-to-device clone, use keyword form for separate units
dd cf.device scsi.device US 0 UD 1 START 0 COUNT 1000

; fully keyword form (always works)
dd SRC compactflash.device DST ram:dump UNIT 0 START 100 COUNT 200

; probe a device, print its capabilities, do no I/O
dd INSPECT compactflash.device UNIT 0
dd I scsi.device
```

## Migration from dd 1.x

dd 2.0 introduced a CLI breaking change. In dd 1.x the unit number followed each `*.device` argument inline. In dd 2.x the positional order is always `SRC DST [UNIT] [START] [COUNT] [BS]`; the unit moves from between-SRC-and-DST to after-DST. `FILL:` / `RSPEED:` / `RWSPEED:` are unchanged.

| Use case | dd 1.x CLI | dd 2.x CLI |
|---|---|---|
| Fill device | `dd FILL: scsi.device 0` | `dd FILL: scsi.device 0` *(unchanged)* |
| Fill device with count + block size | `dd FILL: scsi.device 0 0 1048576 512` | `dd FILL: scsi.device 0 0 1048576 512` *(unchanged)* |
| Write file to device | `dd ram:dump scsi.device 1 0 128` | `dd ram:dump scsi.device 1 0 128` *(unchanged)* |
| Read region from device into file | `dd scsi.device 1 ram:dump 0 128` | `dd scsi.device ram:dump 1 0 128` |
| Device-to-device copy | `dd cf.device 0 scsi.device 1 0 1000` | `dd cf.device scsi.device US 0 UD 1 START 0 COUNT 1000` |
| Help | bespoke help text | `dd ?` |

