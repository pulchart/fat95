# dd - Raw block transfer tool

`dd` reads and writes raw disk blocks. Since dd 2.0 it uses the AmigaOS argument parser. Type `dd ?` (or `dd HELP`) to see the quick reference.

## Template

```
SRC,DST,UNIT/N,START/N,COUNT/N,BS/N,US=UNITSRC/N/K,UD=UNITDST/N/K,HELP=H/S,INSPECT=I/K,VERBOSE=V/S,CMD/K
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

`dd INSPECT <device.name> [UNIT n] [VERBOSE]` (short: `dd I <device.name>`) probes the device and prints what dd sees, without doing any I/O. Add `VERBOSE` to also list the driver's full `SupportedCommands` set:

```
dd INSPECT compactflash.device UNIT 0
dd INSPECT scsi.device VERBOSE
```

Example output (`VERBOSE`, so the command list is included):

```
scsi.device unit 0:
  sector size:    512
  total sectors:  7831152
  cylinders:      31076
  heads:          4
  sec/track:      63
  >4GiB methods:  NSCMD_TD64, TD64, HD_SCSI
  commands:
                  $0002 (CMD_READ)
                  $0003 (CMD_WRITE)
                  $0016 (TD_GETGEOMETRY)
                  $0018 (TD_READ64)
                  $0019 (TD_WRITE64)
                  $001C (HD_SCSICMD)
                  $4000 (NSCMD_DEVICEQUERY)
                  $544A (unknown)
                  $C000 (NSCMD_TD_READ64)
                  $C001 (NSCMD_TD_WRITE64)
  for <=4 GiB:    CMD_READ / CMD_WRITE
  for  >4 GiB:    NSCMD_TD_READ64 / NSCMD_TD_WRITE64
```
(The command list above is abridged)

The output covers:

- Sector size, total sectors, CHS geometry (cylinders/heads/sec-per-track).
- Transfer capabilities: a `>4GiB methods:` line summarises the large-transfer commands the device offers (`NSCMD_TD64`, `TD64`, `HD_SCSI`, or `(none)`), and with `VERBOSE` a `commands:` block lists its full command set. Each command is shown as its hex value and name, with `(unknown)` for any value dd doesn't recognise.
- Which command set dd would use for a transfer on this device, both for ranges that fit in 4 GiB byte-addressing (`CMD_READ` / `CMD_WRITE`) and for ranges past 4 GiB. See [IO command selection](#io-command-selection).

Every real transfer also prints a one-line "read: ... via <cmd>" and "write: ... via <cmd>" before the data loop starts, so you can confirm the dispatched command without re-running INSPECT. If a command is rejected mid-transfer, a "<cmd> not supported, falling back to <cmd>" line is printed and the swath is retried with the next command down the ladder.

## IO command selection

For each side of a transfer (`SRC` is the read path, `DST` the write path) dd picks one device command. Files, `FILL:` and the speed benchmarks use plain DOS `Read`/`Write` instead.

### Automatic selection

The choice depends on whether the byte range exceeds 32-bit addressing (4 GiB) and on what the driver advertises through NSD:

```
  real .device ? --- no ---> DOS Read/Write (file, FILL:, RSPEED:)
        |
       yes
        |
  forced SCSI (bit 7) ? --- yes ---> HD_SCSICMD
        |                            (set when block size is not 2^n)
        no
        |
  range > 4 GiB ? --- no ---> CMD_READ / CMD_WRITE
        |
       yes
        |
  NSD advertises NSCMD_TD_READ64 ?
        |
        +-- yes --> NSCMD_TD_READ64 / NSCMD_TD_WRITE64
        |
        +-- no  --> TD_READ64 / TD_WRITE64
```

If a chosen command is rejected at I/O time with `IOERR_NOCMD` (-3), dd steps one rung down the ladder and retries the *same* block range, printing a `<cmd> not supported, falling back to <cmd>` notice:

```
  NSCMD_TD_READ64   -->  TD_READ64   -->  HD_SCSICMD  -->  report -3
  NSCMD_TD_WRITE64  -->  TD_WRITE64  -->  HD_SCSICMD  -->  report -3
```

`HD_SCSICMD` (SCSI `READ10`/`WRITE10`) is the last resort — it needs the driver to implement raw SCSI passthrough, which not every device provides. `CMD_READ`/`CMD_WRITE` and `HD_SCSICMD` have no successor, so if they fail the error is reported. This is why a >4 GiB transfer on a device with no usable NSD still works: dd starts at `TD_READ64` and only drops to `HD_SCSICMD` if the driver rejects TD64 as well.

### Forcing the command

`CMD=<name>` pins the transfer command and skips the selection above entirely:

| `CMD=` | Uses |
|---|---|
| `AUTO` | Auto-detect (default; the diagram + runtime fallback above). |
| `CMD` | `CMD_READ` / `CMD_WRITE`. |
| `TD64` | `TD_READ64` / `TD_WRITE64`. |
| `NSCMD` | `NSCMD_TD_READ64` / `NSCMD_TD_WRITE64`. |
| `SCSI` | `HD_SCSICMD`. |

A forced command is honored strictly: it is **not** auto-downgraded, so if the device rejects it the error is reported (e.g. `read error (-3)`). `CMD=CMD` uses a 32-bit byte offset and is refused for transfers that cross 4 GiB (use `TD64`/`NSCMD`/`SCSI` for those). The byte-offset commands (`CMD`/`TD64`/`NSCMD`) assume a power-of-2 block size; for an odd block size use `CMD=SCSI`. `CMD=` does not affect INSPECT output (which reports device capability, not the forced choice).

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

; probe and also list the full SupportedCommands set
dd INSPECT scsi.device VERBOSE

; force a specific transfer command (no auto-fallback)
dd uaehf.device NIL: 0 CMD=TD64
dd scsi.device RAM:dump 0 0 1000 CMD=SCSI
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
