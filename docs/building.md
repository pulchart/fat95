# Building fat95

## Requirements

* vasm 2.0f (`vasmm68k_mot`), default path `/opt/vasm` (`VASM_HOME=`)
* an amigaos-ptable checkout: `extern/ptable` submodule or `PTABLE=`
* `../cfd/tools/md2guide.py` and python3 for the guides, `lha` for releases

## ptable.library

`make` builds ptable.library (small and full) and `lsptres` in the ptable checkout and copies them into `dist/`. During ptable development:

```sh
export PTABLE=/path/to/amigaos-ptable
```

`make ptable-sync` moves `extern/ptable` to its `origin/master` tip and rebuilds.

## Release

```sh
make clean; make; make guide; make release
```

## Targets

| Target | Does |
|--------|------|
| `make` | fat95 in all CPU tiers and the tools |
| `make guide` | AmigaGuide files from Markdown |
| `make stage` | archive tree in `build/stage` |
| `make release` | Aminet LHA archive and readme |
| `make test` | emulated checks on all CPU tiers |
| `make clean`, `distclean`, `help` | cleanup, target list |

## Install script

`make stage` joins fragments into `Install` and `Language` and replaces `@VERSION@`. `Install.info` and `Language.info` start them with `Installer`.

| File | Does |
|------|------|
| `install/fat95.head` | version, final report names `SYS:`, welcome, variables for `ptable.inc` |
| `$(PTABLE)/install/common.inc` | `P_COPY`: copies a file, asks before replacing a newer one; `P_LOADMODULE`: one LoadModule line in `S:User-Startup` shared by cfd and fat95 |
| `install/language.inc` | default language from the system locale, `P_LANGUAGE` writes it into `L:fat95` with `install95` |
| `install/fat95.pre` | CPU tier 68000/68020/68080, `L:fat95` |
| `$(PTABLE)/install/ptable.inc` | small/full choice, `ptable.library` from `libs/` to `LIBS:` |
| `install/fat95.post` | language, tools list, optional MS0/MS1 mountlists |
| `install/fat95.tail` | `(exit)` |
| `install/language.head`, `language.tail` | `Language`: change the language of an installed `L:fat95` |

- `Install` = `fat95.head` + `common.inc` + `language.inc` + `fat95.pre` + `ptable.inc` + `fat95.post` + `fat95.tail`.
- `Language` = `language.head` + `language.inc` + `language.tail`.

`ptable.inc` takes the CPU from the fat95 tier (`ptable-ask-cpu` 0) and does not ask for `lsptres` (`ptable-ask-lsptres` 0). Build with `PTABLE=` pointing at an amigaos-ptable checkout.
