# Building fat95

## Requirements

Podman and an amigaos-ptable checkout: the `extern/ptable` submodule or `PTABLE=`. Every target runs in the [amiga-toolchain](https://github.com/pulchart/container-amiga-toolchain) image, which holds vasm, vbcc, the NDK, the test and lint tools, md2guide and lha. Outside the image `make` runs the requested targets there, in one container, with the checkout and `PTABLE` mounted; inside it, as in CI, make runs them directly. make pulls a newer `latest` when the registry has one; `TOOLCHAIN_IMAGE=` selects another image, such as a dated tag or the Docker Hub copy.

`make` and `make guides` write the handler, the tools, the bundled ptable.library and lsptres and the guides to `dist/`, which git ignores except for `dist/DOSDrivers` and `dist/locale`.

CI runs on every pull request, master push and manual run in the image's current digest. It lints, builds and tests in parallel and uploads the build as `fat95-dist`; the FS-UAE integration suite runs on the build in the amiga-fsuae images of AROS and ApolloOS. Then it packs that build into the release archive, checks that the archive holds the build's handlers, tools and ptable.library copies and uploads the archive with its readme as `fat95-release`. Each run's summary lists the image, the built files, the tests, the integration scenarios and the archive with a download link.

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
| `make lint` | ruff and yamllint |
| `make test-integration` | FS-UAE integration suite, see [tests/integration](../tests/integration/README.md) |
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
