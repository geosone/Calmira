"""A diagnostic code probe must preserve the original MZ layout and fixups."""
import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('startup_probe', ROOT / 'tools/analysis/patch_dos_startup_probe.py')
PROBE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PROBE)


def fixture():
    data = bytearray(1024)
    data[:2] = b'MZ'
    struct.pack_into('<HH', data, 6, 1, 3)
    struct.pack_into('<HH', data, 20, 0x100, 0)
    struct.pack_into('<H', data, 24, 0x1e)
    struct.pack_into('<HH', data, 0x1e, 0x13b, 0)
    entry = 0x30 + 0x100
    data[entry:entry + 2] = b'\xeb\x37'
    data[entry + 0x3a] = 0xb9
    struct.pack_into('<H', data, entry + 0x3b, 0x180)
    return data, entry


class StartupProbeTests(unittest.TestCase):
    def test_preserves_length_header_fixups_and_live_startup(self):
        data, entry = fixture()
        result = PROBE.instrument(data)
        self.assertEqual(len(result), len(data))
        self.assertEqual(result[:entry], data[:entry])
        self.assertEqual(result[entry + 0x39:], data[entry + 0x39:])
        self.assertEqual(result[entry:entry + 2], b'\xeb\x02')
        self.assertIn(b'\x2e\xa1\x3b\x01', result[entry + 4:entry + 0x39])

    def test_rejects_short_or_non_mz_input(self):
        for data in (b'', b'MZ', bytes(1024)):
            with self.subTest(size=len(data)), self.assertRaises(ValueError):
                PROBE.instrument(data)

    def test_rejects_unknown_startup(self):
        data, entry = fixture()
        data[entry] = 0x90
        with self.assertRaises(ValueError):
            PROBE.instrument(data)

    def test_rejects_missing_fixup(self):
        data, unused = fixture()
        struct.pack_into('<H', data, 0x1e, 0x120)
        with self.assertRaises(ValueError):
            PROBE.instrument(data)

    def test_rejects_header_table_overrun(self):
        data, unused = fixture()
        struct.pack_into('<H', data, 6, 100)
        with self.assertRaises(ValueError):
            PROBE.instrument(data)

    def test_rejects_truncated_code(self):
        data, entry = fixture()
        with self.assertRaises(ValueError):
            PROBE.instrument(data[:entry + 16])


if __name__ == '__main__':
    unittest.main()
