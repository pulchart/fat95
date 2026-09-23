"""SerializeDisk must propagate the result of flushing its changes."""
import tempfile
import unittest
from pathlib import Path

from harness import Handler, load


class SerializeTests(unittest.TestCase):
    """Serialization reports success only after a successful flush."""

    @classmethod
    def setUpClass(cls):
        tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(tmp.cleanup)
        cls.image = load(Path(tmp.name) / 'handler.hunk')

    def setUp(self):
        self.h = Handler(self.image)
        self.addCleanup(self.h.close)
        self.h.set('DosType', 0x46415400)
        self.h.set('DiskType', 0x46415400)
        for name, value in [('CheckInhibited', 0xffffffff), ('TouchBootBlock', 1),
                            ('Cluster2Block', 32), ('ReadXMSDE', 0), ('CacheFree', 0)]:
            self.h.stub(name, lambda value=value: self.h.result(value))

    def serialize(self, succeeds):
        calls = []

        def update():
            calls.append('flush')
            if not succeeds:
                self.h.set('ErrorNum', 225, 2)
            self.h.result(0xffffffff if succeeds else 0)

        self.h.stub('UpdateDisk', update)
        result = self.h.run('SerializeDisk')
        self.assertEqual(calls, ['flush'])
        return result

    def test_failed_flush_reports_failure(self):
        """A failed flush returns failure and preserves the device error."""
        self.assertEqual(self.serialize(False), 0)
        self.assertEqual(self.h.get('ErrorNum', 2), 225)

    def test_successful_flush_reports_success(self):
        """A successful flush still returns success."""
        self.assertNotEqual(self.serialize(True), 0)


if __name__ == '__main__':
    unittest.main()
