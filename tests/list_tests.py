#!/usr/bin/env python3
"""Update tests/INVENTORY.md from the docstrings in tests/.

Reads the sources with ast, so it needs neither vasm nor amitools.
Run: make test-list-update
"""
import ast
import re
from pathlib import Path

TESTS = Path(__file__).resolve().parent
INVENTORY = TESTS / 'INVENTORY.md'
BEGIN, END = '<!-- TESTS:BEGIN -->', '<!-- TESTS:END -->'
TOOLING = ('toolchain.py', 'deps.py', 'list_tests.py')


def cell(text):
    """One markdown table cell: single line, pipes escaped."""
    return ' '.join((text or '').split()).replace('|', r'\|')


def summary(doc):
    """The first paragraph of a docstring, as one line."""
    return cell((doc or '').split('\n\n')[0])


def status(doc):
    """The word after 'Status:' in a module docstring, or '' when it has none."""
    for line in (doc or '').splitlines():
        if line.startswith('Status:'):
            rest = line[len('Status:'):].strip()
            return re.split(r'[,.]', rest)[0].strip()
    return ''


def modules():
    for path in sorted(TESTS.glob('*.py')):
        if path.name in TOOLING:
            continue
        yield path, ast.parse(path.read_text())


def render():
    out = [BEGIN, '']
    out += ['### Unit tests', '',
            'Collected by `unittest discover`, run by `make test` on both CPU tiers.', '']
    scripts = []
    for path, tree in modules():
        classes = [n for n in tree.body if isinstance(n, ast.ClassDef)]
        cases = [(c, [f for f in c.body
                      if isinstance(f, ast.FunctionDef) and f.name.startswith('test')])
                 for c in classes]
        cases = [(c, f) for c, f in cases if f]
        if not cases:
            scripts.append((path, tree))
            continue
        out += ['#### `%s`' % path.name, '', summary(ast.get_docstring(tree)), '']
        for klass, funcs in cases:
            out += ['| test | what it guards |', '|---|---|']
            out += ['| `%s` | %s |' % (f.name, summary(ast.get_docstring(f))) for f in funcs]
            out += ['']
    out += ['### Scripts', '',
            'Not collected by `unittest`; each one is run on its own.\n\n'
            '`gated` runs under `make test` and must exit 0. '
            '`handler-in-the-loop tier` is the tier `make test-amifuse` drives: '
            '`amifuse_suite.py` and `amifuse_media.py --suite` run there; other '
            'image scripts run by hand. '
            '`library` entries are imported by the others, never run.', '',
            '| file | status | what it checks |', '|---|---|---|']
    for path, tree in scripts:
        doc = ast.get_docstring(tree)
        out += ['| `%s` | %s | %s |' % (path.name, status(doc) or '-', summary(doc))]
    out += ['', END]
    return '\n'.join(out) + '\n'


def update():
    text = INVENTORY.read_text()
    head, _, rest = text.partition(BEGIN)
    _, _, tail = rest.partition(END)
    INVENTORY.write_text(head + render().strip() + tail)


if __name__ == '__main__':
    update()
