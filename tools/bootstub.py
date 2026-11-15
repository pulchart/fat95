#!/usr/bin/env python3
"""Assemble tools/bootstub.asm and print it as annotated dc.b lines.

The output is pasted into src/fat95.s after the BPB of the boot sector
samples.  Needs nasm and ndisasm.

    tools/bootstub.py            print the dc.b block and the size
    tools/bootstub.py --bin F    also write the raw bytes to F
"""
import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ASM = Path(__file__).with_name('bootstub.asm')
COMMENT_COL = 32


def assemble(out, *defines):
    cmd = ['nasm', '-f', 'bin', *defines, str(ASM), '-o', str(out)]
    subprocess.run(cmd, check=True)
    return Path(out).read_bytes()


def dc_line(data, comment):
    body = ','.join(f'${b:02X}' for b in data)
    width = 16 + len(body)
    tabs = max(1, -(-(COMMENT_COL - width) // 8))
    return f'\tdc.b\t{body}' + '\t' * tabs + f';{comment}'


def listing(code):
    """Yield (bytes, text) per instruction of the code part."""
    with tempfile.NamedTemporaryFile(suffix='.bin') as f:
        f.write(code)
        f.flush()
        text = subprocess.run(['ndisasm', '-b16', f.name], check=True,
                              capture_output=True, text=True).stdout
    for line in text.splitlines():
        m = re.match(r'[0-9A-F]{8}\s+([0-9A-F]+)\s+(.*)', line)
        if m:
            yield bytes.fromhex(m.group(1)), re.sub(r'\bbyte ', '', m.group(2))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--bin', help='also write the raw stub bytes here')
    args = ap.parse_args()
    with tempfile.TemporaryDirectory() as d:
        full = assemble(Path(d) / 'full.bin')
        code = assemble(Path(d) / 'code.bin', '-dNOMSG')
    if args.bin:
        Path(args.bin).write_bytes(full)
    for data, text in listing(code):
        print(dc_line(data, text))
    msg = full[len(code):].decode('ascii')
    lines = msg.rstrip('\0').split('\r\n')
    for i, text in enumerate(lines[:-1]):
        print(f'\tdc.b\t"{text}",$0D,$0A')
    print('\tdc.b\t0')
    print(f'; {len(full)} bytes', file=sys.stderr)


if __name__ == '__main__':
    sys.exit(main())
