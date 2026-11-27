# debug95 - fat95 state dump

`debug95` writes the internal state of fat95 for one volume to a file. Attach the file to a bug report.

Reading the file is expert work. `parse_debug95.py` from the `tools` directory of the [source repository](https://github.com/pulchart/fat95/tree/master/tools) turns it into text on a PC with Python 3.

## Usage

```
debug95 <volume> <file>

debug95 CF0: RAM:cf0.dump
```

The only condition is that the handler can still answer a packet. debug95 gives up after 10 seconds without an answer, and Ctrl-C stops it earlier.

## Reading the dump

Take the parser from the same release as the handler that wrote the dump, because each release can lay out its variables differently. A dump of another release makes the parser print a warning.

```
python3 tools/parse_debug95.py cf0.dump                 summary
python3 tools/parse_debug95.py --all cf0.dump           every variable
python3 tools/parse_debug95.py --diff a.dump b.dump     variables that differ
```

`--diff` compares two dumps.

## The summary

```
fat95 4.3 handler state, cf0.dump (1232 bytes)

Device     unit                        0
           block size                  512 bytes
           sector size                 512 bytes
           open flags                  0x00000000
           features                    TD64 commands available
                                       use CMD_UPDATE

Partition  type                        FAT32
           DosType                     FAT\255
           number                      1
           first block                 2048
           blocks                      131072
           size                        64 MiB
           cluster size                512 bytes
           mounted by another handler  no

Volume     name                        "FAT32"
           serial number               0x57C0733A
           disk type                   FAT\255
           state                       validated
           dirty flag in use           yes
           mounted clean               yes
           free                        62.8 MiB
           write locked                no

Activity   open locks                  0
           inhibit count               0
           buffers                     50

Names      [unicode] table             no
           [oem] table                 yes

Errors     last DOS error              none
           last read                   none
           last block read             4098
           failed reads                0
           write fault                 no
```

**Device** shows how fat95 talks to the device. The features list the command sets it found (TD64, ETD or SCSI) and the options it runs with.

**Partition** shows which partition fat95 picked, where it starts and how large it is. Number 0 means fat95 found no partition table and uses the medium or the RDB partition as a whole.

**Volume** shows the volume as AmigaDOS sees it. Mounted clean is no for a volume that was dirty at mount, and such a volume stays dirty.

**Activity** counts the locks and files still open, which keep a volume from being unmounted.

**Names** shows whether the language file supplied the `[unicode]` and `[oem]` tables that convert file names.

**Errors** keeps the last DOS error, the last device error with the block it read, and how many reads failed. A write fault blocks every further write until the volume is mounted again.
