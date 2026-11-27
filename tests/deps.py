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

MIN_PYTHON = (3, 14)

# The amiga-toolchain image lists the Python packages it installs, at the
# versions the suites run with; make runs the suites in that image.
IMAGE_REQUIREMENTS = Path("/usr/share/amiga-toolchain/requirements.txt")
HINT = "run make, which uses the amiga-toolchain image, or uv pip install -r its requirements.txt"
TESTED = ("amitools", "machine68k")
TESTED_AMIFUSE = ("amifuse", "fusepy")
# The amifuse forks claim the same import paths as the packages above.
FORKS = (("amitools-amifuse", "amitools"), ("machine68k-amifuse", "machine68k"))

BINARIES = (
    ("mkfs.fat", "dnf install dosfstools"),
    ("fsck.fat", "dnf install dosfstools"),
    ("mcopy", "dnf install mtools"),
    ("fusermount3", "dnf install fuse3, only amifuse_fuse.py needs it"),
)


def image_versions():
    """The image's pinned versions by distribution name, {} outside the image."""
    pins = {}
    if IMAGE_REQUIREMENTS.is_file():
        for line in IMAGE_REQUIREMENTS.read_text().splitlines():
            name, _, pinned = line.split("#")[0].partition("==")
            if pinned:
                pins[name.split("[")[0].strip().lower()] = pinned.strip()
    return pins


def version(dist):
    """Installed version of a distribution, or None."""
    try:
        return md.version(dist)
    except md.PackageNotFoundError:
        return None


def report(rows, required):
    """Print one tier. Returns True when something required is missing."""
    missing = False
    pins = image_versions()
    for dist in rows:
        have, tested = version(dist), pins.get(dist)
        if have is None:
            print("  MISSING  %-20s %s" % (dist, HINT))
            missing = missing or required
        elif tested is None or have == tested:
            print("  ok       %-20s %s" % (dist, have))
        else:
            print("  UNTESTED %-20s %s, the image has %s" % (dist, have, tested))
    return missing


def vasm_banner():
    try:
        out = subprocess.run([str(VASM), "-v"], capture_output=True, text=True, timeout=10)
        return (out.stdout + out.stderr).strip().splitlines()[0]
    except OSError, subprocess.SubprocessError, IndexError:
        return "<not runnable>"


def main():
    bad = False
    print("python      %d.%d.%d  (%d.%d or newer required)" % (*sys.version_info[:3], *MIN_PYTHON))
    bad = bad or sys.version_info < MIN_PYTHON

    print("vasm        %s" % VASM)
    print("            %s" % vasm_banner())
    runnable = Path(str(VASM)).is_file() and os.access(str(VASM), os.X_OK)
    if not runnable:
        print(
            "  MISSING  vasm %s, build it from http://sun.hasenbraten.de/vasm/"
            % EXPECTED_VASM_VERSION
        )
        print("           and set VASM_HOME, or put vasmm68k_mot on PATH")
        bad = True
    elif EXPECTED_VASM_VERSION not in vasm_banner():
        print("  UNTESTED vasm, expected %s" % EXPECTED_VASM_VERSION)

    print("\nrequired, for make test")
    bad = report(TESTED, True) or bad

    # Two providers of one import path overwrite each other and the suite then
    # fails in every test. This is the single most likely broken install.
    for fork, wanted in FORKS:
        if version(fork) and version(wanted):
            print(
                "  CONFLICT %-20s %s and %s are both installed and claim the same"
                % ("", fork, wanted)
            )
            print(
                "           import paths. Uninstalling %s alone removes files %s" % (fork, wanted)
            )
            print("           owns too, so use a fresh venv, or uninstall both and")
            print("           reinstall the image's requirements.txt")
            bad = True
        elif version(fork):
            print("  WRONG    %-20s %s is installed instead of %s" % ("", fork, wanted))
            bad = True

    print("\noptional, for make test-amifuse")
    report(TESTED_AMIFUSE, False)
    for name, hint in BINARIES:
        print(
            "  ok       %-20s %s" % (name, shutil.which(name))
            if shutil.which(name)
            else "  MISSING  %-20s %s" % (name, hint)
        )
    print(
        "  ok       %-20s present" % "/dev/fuse"
        if Path("/dev/fuse").exists()
        else "  MISSING  %-20s load the fuse module; the caller must be allowed to mount"
        % "/dev/fuse"
    )

    if bad:
        print("\nSomething required is missing or inconsistent, see above.")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
