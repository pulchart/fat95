#!/usr/bin/env python3
"""The suite describes itself: every test carries a description and the inventory in INVENTORY.md matches them.

Neither case assembles anything, so both run without vasm and amitools.

Status: library, collected by unittest like any other test file.
Run: make test
"""
import ast
import unittest
from pathlib import Path

import list_tests

TESTS = Path(__file__).resolve().parent


class Documented(unittest.TestCase):
    """Keeps the per-test descriptions present and the generated inventory current."""

    def test_every_test_method_has_a_description(self):
        """Each test method and each test class carries a docstring, so the inventory can state what it guards."""
        undocumented = []
        for path in sorted(TESTS.glob('test_*.py')):
            tree = ast.parse(path.read_text())
            for node in ast.walk(tree):
                named = (isinstance(node, ast.ClassDef)
                         or (isinstance(node, ast.FunctionDef) and node.name.startswith('test')))
                if named and not ast.get_docstring(node):
                    undocumented.append('%s:%s' % (path.name, node.name))
        self.assertEqual(undocumented, [],
                         'add a one-line docstring saying what each of these guards')

    def test_inventory_is_current(self):
        """The generated block in INVENTORY.md is what list_tests.py produces right now."""
        inventory = list_tests.INVENTORY.read_text()
        self.assertIn(list_tests.BEGIN, inventory, 'INVENTORY.md lost its generated block')
        current = inventory.partition(list_tests.BEGIN)[2].partition(list_tests.END)[0].splitlines()
        expected = list_tests.render().partition(list_tests.BEGIN)[2].partition(list_tests.END)[0].splitlines()
        for line, (have, want) in enumerate(zip(current, expected), 1):
            self.assertEqual(have, want,
                             'stale inventory at line %d: run make test-list-update' % line)
        self.assertEqual(len(current), len(expected),
                         'stale inventory, %d lines instead of %d: run make test-list-update'
                         % (len(current), len(expected)))


if __name__ == '__main__':
    unittest.main()
