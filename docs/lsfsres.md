# lsfsres - FileSystem.resource entry lister

`lsfsres` lists every entry in `FileSystem.resource`: DosType, version, SegList address, and handler name. A `[ROM]` / `[RAM]` tag shows whether the handler lives in Kickstart ROM or was loaded from disk.

**Use cases**:
- Confirm a ROM-resident filesystem (e.g. fat95 baked into a Kickstart  bundle) registered itself at boot.
- Spot whether a mounted volume is using the ROM copy or a disk copy of a handler.

## Usage

```
lsfsres

; or forward via serial line
lsfsres >SER:
```

## Examples

### fat95 loaded from `L:`

```
 #: DosType (ascii) Version  Patch SegList  Loc   Name
----------------------------------------------------------
 1: 46415401 (FAT.)    00030015 0190  4044D374 [RAM]   fat95 3.22 (13.05.2026) [68020]
 2: 50445303 (PDS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
 3: 50465303 (PFS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
 4: 50445301 (PDS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
 5: 50465301 (PFS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
 6: 444F5307 (DOS.)    002F0004 0000  D1F90000 [RAM]   filesysres 47.4 (16.1.2021)
 7: 444F5306 (DOS.)    002F0004 0000  D2610000 [RAM]   filesysres 47.4 (16.1.2021)
 8: 444F5305 (DOS.)    002F0004 0000  D2C90000 [RAM]   filesysres 47.4 (16.1.2021)
 9: 444F5304 (DOS.)    002F0004 0000  D3310000 [RAM]   filesysres 47.4 (16.1.2021)
10: 444F5303 (DOS.)    002F0004 0000  D3990000 [RAM]   filesysres 47.4 (16.1.2021)
11: 444F5302 (DOS.)    002F0004 0000  D0990000 [RAM]   filesysres 47.4 (16.1.2021)
12: 444F5301 (DOS.)    002F0004 0000  00000000 [RAM]   filesysres 47.4 (16.1.2021)
13: 554E4901 (UNI.)    00000000 0008  7C994110 [RAM]   filesysres 47.4 (16.1.2021)
----------------------------------------------------------
Total: 13 entries in FileSystem.resource.
```

### fat95 baked into Kickstart ROM

v3.22+: cold-boot registration of `FAT\0`..`FAT\8`). It was broken before fat95 3.22, so prior ROM builds still fall back to `L:fat95` (RAM).

```
 #: DosType (ascii) Version  Patch SegList  Loc   Name
----------------------------------------------------------
 1: 46415408 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 2: 46415407 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 3: 46415406 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 4: 46415405 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 5: 46415404 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 6: 46415403 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 7: 46415402 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 8: 46415401 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
 9: 46415400 (FAT.)    00030016 0190  00E4CB14 [ROM]   fat95 3.22 (13.05.2026) [68020]
10: 50445303 (PDS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
11: 50465303 (PFS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
12: 50445301 (PDS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
13: 50465301 (PFS.)    00140000 0180  00E3DDD4 [ROM]   pfs3aio
14: 444F5307 (DOS.)    002F0004 0000  D2590000 [RAM]   filesysres 47.4 (16.1.2021)
15: 444F5306 (DOS.)    002F0004 0000  D2C10000 [RAM]   filesysres 47.4 (16.1.2021)
16: 444F5305 (DOS.)    002F0004 0000  D3290000 [RAM]   filesysres 47.4 (16.1.2021)
17: 444F5304 (DOS.)    002F0004 0000  D3910000 [RAM]   filesysres 47.4 (16.1.2021)
18: 444F5303 (DOS.)    002F0004 0000  D3F90000 [RAM]   filesysres 47.4 (16.1.2021)
19: 444F5302 (DOS.)    002F0004 0000  D0F90000 [RAM]   filesysres 47.4 (16.1.2021)
20: 444F5301 (DOS.)    002F0004 0000  00000000 [RAM]   filesysres 47.4 (16.1.2021)
21: 554E4901 (UNI.)    00000000 0008  7C994110 [RAM]   filesysres 47.4 (16.1.2021)
----------------------------------------------------------
Total: 21 entries in FileSystem.resource.
```

