#!/usr/bin/env python3
"""Regression check: the ptable wrappers act on d0, not on the condition codes exec.library's OpenLibrary happens to leave on the ROM-bootstrap retry. Each routine is driven with both flag polarities for both outcomes; the result must depend only on the returned base.

Status: gated, run by make test. Exit 0 means correct.
Run from the repository root: python3 tests/audit_ptable_check.py
Reuses IntegrationTests.image and drives its class fixture by hand."""
import json, sys
from test_integration import IntegrationTests
from harness import Handler, C, CPU

IntegrationTests.setUpClass()
rows, bad = [], []
try:
    for name, lvo in (('PublishViaPtable', -36), ('MarkAbsentViaPtable', -60)):
        for base in (0x60000, 0):
            for z in (0, 1):
                h = Handler(IntegrationTests.image); h.set('ExecBase', 0x70000); events = []
                def openlib():
                    events.append('OpenLibrary')
                    second = events.count('OpenLibrary') == 2
                    h.result(base if second else 0)
                    h.cpu.w_sr((h.cpu.r_sr() & ~4) | (4 if z else 0))
                h.trap(0x70000 + C['OpenLibrary'], openlib)
                h.trap(0x70000 + C['FindResident'], lambda: (events.append('FindResident'), h.result(0x65000)))
                h.trap(0x70000 + C['InitResident'], lambda: events.append('InitResident'))
                h.trap(0x70000 + C['CloseLibrary'], lambda: events.append('CloseLibrary'))
                h.trap(0x60000 + lvo, lambda: events.append('work'))
                outcome = 'returned'
                try: h.run(name)
                except Exception as exc: outcome = type(exc).__name__
                did_work = 'work' in events
                closed = 'CloseLibrary' in events
                want_work = base != 0
                ok = (outcome == 'returned' and did_work == want_work and closed == want_work)
                rows.append(dict(cpu=CPU, routine=name, retry_base=hex(base), retry_z=z,
                                 outcome=outcome, work=did_work, closed=closed,
                                 expected_work=want_work, pass_=ok))
                if not ok: bad.append(rows[-1])
                h.close()
finally:
    IntegrationTests.tearDownClass()
print(json.dumps(rows, indent=2))
print(f'{len(rows)-len(bad)}/{len(rows)} cases behave on d0 alone', file=sys.stderr)
sys.exit(1 if bad else 0)
