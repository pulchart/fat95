# fat95 tests

## Start here

Requires Linux, Python 3.11+ and [vasm 2.0f](../CONTRIBUTING.md#build).
From the repository root:

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r tests/requirements.txt
make test
```

An existing compatible Python environment also works. The requirements pin
tested **amitools-amifuse** and **machine68k-amifuse** versions. Do not mix them
with upstream packages: their import paths overlap. Use `make check-test-deps`
to diagnose missing dependencies, untested versions or conflicting providers.

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
python -m pip install -r tests/requirements-amifuse.txt
# Install dosfstools and mtools with your distribution's package manager.
make test-amifuse AMIFUSE_CYCLES=1  # short run; default is 100 restart cycles
```

This builds the 68020 handler and tests FAT images through DOS packets.
It checks results with `fsck.fat` and mtools. Missing dependencies fail the
requested run. Requirements include the tested base packages; amifuse uses
private APIs, so upgrades need verification.

The matrix covers nested directories, long names, seek/resize, live handles,
disk-full recovery and remounts. It also runs 18 bounded media-removal,
replacement and write/flush-failure cases; restart cycles do not repeat these.

Other image scripts run separately; see [INVENTORY.md](INVENTORY.md).
Only `amifuse_fuse.py` needs fuse3 and access to `/dev/fuse`.
Set `FAT95_BASELINE_DRIVER` to a second handler binary for A/B comparisons.

## Add or debug a test

Copy [test_example.py](test_example.py). It assembles once per class, creates
one `Handler` per test and closes it through `addCleanup`. Only one emulated
machine may be live at a time.

[harness.py](harness.py) documents routine calls, globals, disk contents,
I/O events and failure injection. Injection flags persist until cleared.
Equates come from `src/fat95.s`; renaming one can require test changes.
The fixed memory map reserves `$24000..$44080` for FAT windows and
`$48000` for the block buffer. Keep assembler symbols: routine lookup needs them.

Give each test class and method a short docstring stating what it guards,
then run `make test-list-update`. Commit the updated
[INVENTORY.md](INVENTORY.md) with the test; `make test` checks it.

For Make, set `VASM_HOME` to override the assembler installation.
Direct Python runs resolve `FAT95_VASM`, then `VASM_HOME/bin`, then
`vasmm68k_mot` on PATH, then `/opt/vasm/bin/vasmm68k_mot`.
Make exports its selected assembler as `FAT95_VASM`.

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
