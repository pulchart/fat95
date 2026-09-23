#!/usr/bin/env python3
"""Repository paths, assembler discovery and the one assemble() every suite uses.

Standard library only: deps.py imports this module on a host where nothing else
is installed yet, to report what is missing.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

if sys.flags.optimize:
    raise SystemExit('Tests require assertions: unset PYTHONOPTIMIZE and omit -O.')

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / 'tests'
RUNS = TESTS / '.amifuse-runs'          # gitignored; images and logs land here

CPU = os.environ.get('FAT95_TEST_CPU', '68000')
if CPU not in ('68000', '68020'):
    raise SystemExit('FAT95_TEST_CPU must be 68000 or 68020, not ' + CPU)

EXPECTED_VASM_VERSION = '2.0f'          # keep in step with the Makefile


def find_vasm():
    """FAT95_VASM (what make exports) > VASM_HOME/bin > PATH > the Makefile default."""
    if os.environ.get('FAT95_VASM'):
        return Path(os.environ['FAT95_VASM'])
    if os.environ.get('VASM_HOME'):
        return Path(os.environ['VASM_HOME']) / 'bin' / 'vasmm68k_mot'
    found = shutil.which('vasmm68k_mot')
    return Path(found) if found else Path('/opt/vasm/bin/vasmm68k_mot')


VASM = find_vasm()


def assemble(output, source='src/fat95.s', cpu=None, listing=None, extra=()):
    """Assemble source into a hunk executable, symbol table kept.

    The harness reads the symbol table to find routine entry points, so the
    Makefile's -nosym must never appear here.
    """
    cpu = cpu or CPU
    command = [str(VASM), '-quiet', '-I' + str(ROOT / 'src'), '-Fhunkexe', '-m' + cpu]
    if cpu == '68020':
        command.append('-D__68020__=1')
    if listing is not None:
        command += ['-L', str(listing)]
    command += [*extra, '-o', str(output), str(source)]
    subprocess.run(command, cwd=ROOT, check=True)
    return Path(output)


def load(output, source='src/fat95.s', **kwargs):
    """assemble() then load the hunk; amitools is imported lazily for deps.py."""
    from amitools.binfmt.BinFmt import BinFmt
    assemble(output, source, **kwargs)
    return BinFmt().load_image(str(output))
