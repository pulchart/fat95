# fat95 tests

## Start here

`make test` runs the suites in the amiga-toolchain image, which holds vasm 2.0f, Python 3.14+, `amitools`, `machine68k` and `amifuse` at the versions in its `requirements.txt`, see [CONTRIBUTING.md](../CONTRIBUTING.md#build). For Python runs outside the image, `uv pip install -r` that file into a venv. Do not mix `amitools` and `machine68k` with the amifuse forks: their import paths overlap. `make check-test-deps` reports missing packages, versions other than the image's and conflicting providers.

`make lint` runs ruff and yamllint; `pre-commit install` runs them before each commit.

`make test` runs unit tests and standalone checks on 68000 and 68020.
Any failure fails the run.

```sh
make test TEST_CPUS=68020         # one CPU
make test V=1                    # verbose
python -m unittest discover -s tests -k test_short_write_is_failure -v
```

For direct Python runs, set `FAT95_TEST_CPU=68020` to select that CPU;
the default is 68000. Use `-k DirtyBitTests` to select a class.

## Optional image tests

```sh
make test-amifuse AMIFUSE_CYCLES=1  # short run; default is 100 restart cycles
```

This builds the 68020 handler and tests FAT images through DOS packets, with
amifuse, dosfstools and mtools from the image. It checks results with
`fsck.fat` and mtools. amifuse uses private APIs, so upgrades need
verification.

The matrix covers nested directories, long names, seek/resize, live handles,
disk-full recovery and remounts. It also runs 18 bounded media-removal,
replacement and write/flush-failure cases; restart cycles do not repeat these.
`amifuse_format.py` formats FAT12, FAT16 and FAT32 images, then checks them with `fsck.fat` and compares the boot code with the stub (byte comparison needs nasm).

`amifuse_fat_names.py` mounts FAT12, FAT16 and FAT32 images with long names outside the code page; it needs dosfstools and mtools.

`amifuse_full_dir.py` creates and renames objects in a directory whose last slot holds a locked entry, on FAT12, FAT16 and FAT32; it needs dosfstools and mtools.

Other image scripts run separately; see [INVENTORY.md](INVENTORY.md).
Only `amifuse_fuse.py` needs fuse3 and access to `/dev/fuse`.
Set `FAT95_BASELINE_DRIVER` to a second handler binary for A/B comparisons.

## Add or debug a test

Copy [test_example.py](test_example.py). It assembles once per class, creates
one `Handler` per test and closes it through `addCleanup`. Only one emulated
machine may be live at a time.

[harness.py](harness.py) documents routine calls, globals, disk contents,
I/O events and failure injection. Injection flags persist until cleared.
Equates come from `src/fat95.s` and the files it includes, such as `src/fat95_vars.i`; renaming one can require test changes.
The fixed memory map reserves `$24000..$44080` for FAT windows and
`$48000` for the block buffer. Keep assembler symbols: routine lookup needs them.

Give each test class and method a short docstring stating what it guards,
then run `make test-list-update`. Commit the updated
[INVENTORY.md](INVENTORY.md) with the test; `make test` checks it.

The suites take vasm from `FAT95_VASM`, `VASM_HOME/bin` or PATH, in that
order; in the amiga-toolchain image PATH has it.

## Failures and coverage

Report the commit, dirty-tree status, command/environment, failing case and
`make check-test-deps` output. For image tests, include the case log,
`result.json` and seed. Results and images (720 KB–128 MB) remain in
`tests/.amifuse-runs/<run>/`, including `summary.json`; `make clean` preserves
them. Send images only when needed. Other tests use temporary directories.

Fast tests execute assembled routines with mocked device/Exec calls; image
tests exercise DOS packets. Neither validates hardware timing, interrupts,
reentrancy or multitasking. Mocks cover only injected behavior, not arbitrary
device faults. Coordinate hardware validation with the maintainer.
