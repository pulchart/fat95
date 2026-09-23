#!/usr/bin/env python3
"""Regression check: the '..' entry of a new directory names its parent, so the parent cluster survives MakeIntRef.

Status: gated, run by make test. Exit 0 means correct.
Run: python3 tests/audit_extenddir_check.py"""
import json
import struct
import tempfile
from pathlib import Path
from harness import Handler, C, CPU, load

with tempfile.TemporaryDirectory() as tmp:
    image_path = Path(tmp) / 'handler.hunk'
    image = load(image_path)
    rows = []
    cases = [(0, 'FAT12'), (1, 'FAT16'), (0xffff, 'FAT32')]
    for parent_is_root in (False, True):
      for fat_type, label in cases:
          h = Handler(image)
          try:
              child, parent, root, data, shim = 0x52000, 0x53000, 0x54000, 0x56000, 0x58000
              for ptr in (child, parent, root):
                  h.mem.w_block(ptr, bytes(C['XL_Sizeof']))
              h.mem.w32(child + C['XL_Parent'], parent)
              h.mem.w32(parent + C['XL_Parent'], 0 if parent_is_root else root)
              h.mem.w16(parent + C['XL_MSDE'] + C['MSDE_1L'], 42)
              h.mem.w8(parent + C['XL_MSDE'] + C['MSDE_Flags'], 0x10)
              h.set('FATType', fat_type, 2)
              h.set('BlocksPerCluster', 1, 1)
              h.mem.w32(C['XL_Parent'], 0)  # deterministic low-memory read at a0=0
              h.stub('ExtendChain', lambda: h.result(100))
              h.stub('Cluster2Block', lambda: h.result(900))
              h.stub('ReadBlocks', lambda: h.result(data))
              h.stub('BlockChanged', lambda: None)
              code = b'\x2f\x3c' + struct.pack('>I', child)
              code += b'\x4e\xb9' + struct.pack('>I', h.syms['ExtendDir'])
              code += b'\x58\x8f\x4e\x75'
              h.mem.w_block(shim, code)
              h.syms['audit_call'] = shim
              result = h.run('audit_call')
              entry = bytes(h.mem.r_block(data + C['MSDE_Sizeof'], C['MSDE_Sizeof']))
              actual = int.from_bytes(entry[C['MSDE_1L']:C['MSDE_1L'] + 2], 'little')
              assert result == 900 and entry[:2] == b'..'
              want = 0 if parent_is_root else 42
              assert actual == want, (label, parent_is_root, 'parent cluster', actual, want)
              assert h.cpu.r_reg(8) == parent, (label, hex(h.cpu.r_reg(8)))
              rows.append({'cpu': CPU, 'fat': label,
                           'actual_parent_cluster': actual, 'parent_pointer': hex(parent),
                           'a0_after_makeintref': hex(h.cpu.r_reg(8)), 'return': result,
                           'parent_is_root': parent_is_root, 'expected': want})
          finally:
              h.close()
    print(json.dumps(rows, indent=2))
