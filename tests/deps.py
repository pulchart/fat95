#!/usr/bin/env python3
"""Report what each test tier needs, what is installed, and what is wrong.

Standard library only, so it runs before anything else is installed. Prints the
versions rather than a yes or no, because a failure report is only useful when
it says which versions produced it.
Run: make check-test-deps   or   python3 tests/deps.py
"""
import importlib.metadata as md
import os
import shutil
import subprocess
import sys
from pathlib import Path

from toolchain import VASM, EXPECTED_VASM_VERSION

MIN_PYTHON = (3, 11)

# Distribution name, the version the suite was last green against, and the hint.
# The package names are not the import names: amitools-amifuse provides amitools.
TESTED = (
    ('amitools-amifuse', '0.8.0.post8', 'pip install -r tests/requirements.txt'),
    ('machine68k-amifuse', '0.4.1.post1', 'pip install -r tests/requirements.txt'),
)
TESTED_AMIFUSE = (
    ('amifuse', '0.6.0', 'pip install -r tests/requirements-amifuse.txt'),
    ('fusepy', '3.0.1', 'pip install -r tests/requirements-amifuse.txt'),
)
# Upstream distributions that claim the same import paths as the forks above.
CONFLICTS = (('amitools', 'amitools-amifuse'), ('machine68k', 'machine68k-amifuse'))

BINARIES = (
    ('mkfs.fat', 'dnf install dosfstools'),
    ('fsck.fat', 'dnf install dosfstools'),
    ('mcopy', 'dnf install mtools'),
    ('fusermount3', 'dnf install fuse3, only amifuse_fuse.py needs it'),
)


def version(dist):
    """Installed version of a distribution, or None."""
    try:
        return md.version(dist)
    except md.PackageNotFoundError:
        return None


def report(rows, required):
    """Print one tier. Returns True when something required is missing."""
    missing = False
    for dist, tested, hint in rows:
        have = version(dist)
        if have is None:
            print('  MISSING  %-20s %s' % (dist, hint))
            missing = missing or required
        elif have == tested:
            print('  ok       %-20s %s' % (dist, have))
        else:
            print('  UNTESTED %-20s %s, the suite was last green against %s'
                  % (dist, have, tested))
    return missing


def vasm_banner():
    try:
        out = subprocess.run([str(VASM), '-v'], capture_output=True, text=True, timeout=10)
        return (out.stdout + out.stderr).strip().splitlines()[0]
    except (OSError, subprocess.SubprocessError, IndexError):
        return '<not runnable>'


def main():
    bad = False
    print('python      %d.%d.%d  (%d.%d or newer required)'
          % (*sys.version_info[:3], *MIN_PYTHON))
    bad = bad or sys.version_info < MIN_PYTHON

    print('vasm        %s' % VASM)
    print('            %s' % vasm_banner())
    runnable = Path(str(VASM)).is_file() and os.access(str(VASM), os.X_OK)
    if not runnable:
        print('  MISSING  vasm %s, build it from http://sun.hasenbraten.de/vasm/'
              % EXPECTED_VASM_VERSION)
        print('           and set VASM_HOME, or put vasmm68k_mot on PATH')
        bad = True
    elif EXPECTED_VASM_VERSION not in vasm_banner():
        print('  UNTESTED vasm, expected %s' % EXPECTED_VASM_VERSION)

    print('\nrequired, for make test')
    bad = report(TESTED, True) or bad

    # Two providers of one import path overwrite each other and the suite then
    # fails in every test. This is the single most likely broken install.
    for upstream, fork in CONFLICTS:
        if version(upstream) and version(fork):
            print('  CONFLICT %-20s %s and %s are both installed and claim the same'
                  % ('', upstream, fork))
            print('           import paths. Uninstalling %s alone removes files the'
                  % upstream)
            print('           fork owns too, so use a fresh venv, or uninstall both and')
            print('           reinstall from tests/requirements.txt')
            bad = True
        elif version(upstream) and not version(fork):
            print('  WRONG    %-20s %s is installed instead of %s; the harness needs'
                  % ('', upstream, fork))
            print('           Machine.from_name, which upstream does not provide')
            bad = True

    print('\noptional, for make test-amifuse')
    report(TESTED_AMIFUSE, False)
    for name, hint in BINARIES:
        print('  ok       %-20s %s' % (name, shutil.which(name)) if shutil.which(name)
              else '  MISSING  %-20s %s' % (name, hint))
    print('  ok       %-20s present' % '/dev/fuse' if Path('/dev/fuse').exists()
          else '  MISSING  %-20s load the fuse module; the caller must be allowed to mount'
               % '/dev/fuse')

    if bad:
        print('\nSomething required is missing or inconsistent, see above.')
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main())
