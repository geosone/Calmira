import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    'normalize_tray_aliases', ROOT / 'tools/normalize_tray_aliases.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class TrayAliasTests(unittest.TestCase):
    def test_obsolete_source_is_replaced_without_losing_trailing_data(self):
        source = b'%calmira%\\w95icons.dll'
        prefix = b'\x04CMSR' + bytes(6) + b'\x03app\x04Name'
        data = prefix + bytes([len(source)]) + source + b'\x13\0' + b'CACHE'
        self.assertEqual(MODULE.normalize(data), prefix + b'\0\0\0CACHE')

    def test_truncated_alias_is_rejected(self):
        with self.assertRaises(ValueError):
            MODULE.normalize(b'\x04CMSR' + bytes(6) + b'\xff')

    def test_bundled_aliases_have_no_removed_icon_dependency(self):
        for path in (ROOT / 'src/TRAY').glob('*.ALS'):
            data = path.read_bytes()
            self.assertEqual(MODULE.normalize(data), data, path.name)


if __name__ == '__main__':
    unittest.main()
