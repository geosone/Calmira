"""Offline layout controls must change only the intended directory bytes."""
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / 'tools/analysis/swap_probe_entries.py'


class ProbeEntrySwapTests(unittest.TestCase):
    def setUp(self):
        parent = ROOT / 'build/tests'
        parent.mkdir(parents=True, exist_ok=True)
        self.work = tempfile.TemporaryDirectory(prefix='entry-swap.', dir=parent)
        self.addCleanup(self.work.cleanup)
        self.image = Path(self.work.name) / 'prepared.img'
        self.data = bytearray(2048)
        struct.pack_into('<H', self.data, 11, 512)
        struct.pack_into('<H', self.data, 14, 1)
        self.data[16] = 1
        struct.pack_into('<H', self.data, 17, 16)
        struct.pack_into('<H', self.data, 22, 1)
        for number, name, cluster in ((0, b'REAL16  EXE', 100),
                                      (1, b'OLDREAL EXE', 200)):
            offset = 1024 + number * 32
            self.data[offset:offset + 11] = name
            self.data[offset + 11] = 0x20
            struct.pack_into('<HI', self.data, offset + 26, cluster, 8192)

    def run_tool(self, mode, path=None):
        self.image.write_bytes(self.data)
        return subprocess.run(['python3', str(TOOL), str(path or self.image),
                               '--offset', '0', '--mode', mode],
                              capture_output=True, text=True)

    def test_swaps_only_complete_directory_records(self):
        result = self.run_tool('entries')
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = self.data.copy()
        expected[1024:1056] = self.data[1056:1088]
        expected[1056:1088] = self.data[1024:1056]
        self.assertEqual(self.image.read_bytes(), expected)

    def test_swaps_only_cluster_words(self):
        result = self.run_tool('chains')
        self.assertEqual(result.returncode, 0, result.stderr)
        expected = self.data.copy()
        expected[1050:1052] = self.data[1082:1084]
        expected[1082:1084] = self.data[1050:1052]
        self.assertEqual(self.image.read_bytes(), expected)

    def test_rejects_different_sizes_without_writing(self):
        self.data[1084] = 1
        self.assertNotEqual(self.run_tool('chains').returncode, 0)
        self.assertEqual(self.image.read_bytes(), self.data)

    def test_rejects_non_disposable_name(self):
        other = self.image.with_name('original.img')
        other.write_bytes(self.data)
        self.assertNotEqual(self.run_tool('entries', other).returncode, 0)
        self.assertEqual(other.read_bytes(), self.data)

    def test_rejects_symbolic_link(self):
        link = self.image.with_name('link.img')
        link.symlink_to(self.image)
        self.assertNotEqual(self.run_tool('entries', link).returncode, 0)
        self.assertEqual(self.image.read_bytes(), self.data)
