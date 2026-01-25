# fat95

Win95/98 compatible FAT filesystem handler for AmigaOS. Fork of disk/misc/fat95.lha.

# What's New in 3.19-dev (25.01.2026)

* Added Makefile-based build system.
* Set English as default localization for fat95 handler.
* Rebuild by vasm 2.0d

# Purpose

"fat95" is a DOS handler to mount and use Win95/98 volumes just as if they were
AMIGA volumes.

# System Requirements

* every AMIGA, OS 1.3+ (OS 2.0+ for full functionality)
* a suitable device file for low level disk access, like the
  mfm.device for floppies.

# Features

**PLEASE READ** english/readme.too REALLY!

* workbench and applications support
* diskchange autosense
* format type autosense: FAT12, FAT16 and FAT32
* simple LINUX style partition selection or manual definition
* up to 4 GBytes of partition size for FAT16
* large harddisk support via TD64 or direct SCSI
* long filenames (up to 104 chars for now)
* inquiry, read, write, and maintenance access
* built-in error check utility
* disk formatting using the OS 2.0+ format command
* MS-DOS 8.3 downward compatibility
* user definable language and code page
* date range Jan 1st, 1980 through Dec 31st, 2107
* extended datestamp support: creation date and time, last accessed date
  (written automatically, readable as file comment text)
* volume serial number as name for unnamed volumes
* automatic directory optimization
* written entirely in assembly language
