import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('pack_executables', ROOT / 'tools/pack_executables.py')
PACK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACK)


class PackEnvironmentTests(unittest.TestCase):
    def test_tool_path_environment_is_removed_from_every_upx_child_only(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'app.exe'
            original = b'original executable contents'
            source.write_bytes(original)
            output = root / 'packed'
            calls = []

            def run(command, *, check, env):
                self.assertTrue(check)
                self.assertNotIn('UPX', env)
                self.assertEqual(env['KEEP'], 'unchanged')
                calls.append(command)
                if command[1] == '--best':
                    Path(command[2]).write_bytes(b'packed')
                elif command[1] == '-d':
                    Path(command[3]).write_bytes(original)

            with patch.dict(os.environ, {'UPX': '/tool/path/upx', 'KEEP': 'unchanged'}, clear=True):
                with patch.object(PACK.subprocess, 'run', side_effect=run):
                    report = PACK.pack(root / 'upx', [source], output)
                self.assertEqual(os.environ['UPX'], '/tool/path/upx')
            self.assertEqual([call[1] for call in calls], ['--best', '-t', '-d'])
            self.assertEqual(source.read_bytes(), original)
            self.assertEqual((output / 'APP.EXE').read_bytes(), b'packed')
            self.assertEqual(report['APP.EXE']['packed_bytes'], 6)

    def test_failed_validation_preserves_prior_packed_output_and_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'app.exe'
            source.write_bytes(b'original executable')
            output = root / 'packed'
            output.mkdir()
            (output / 'APP.EXE').write_bytes(b'older valid packed executable')
            (output / 'compression.json').write_text('older report')

            def run(command, *, check, env):
                self.assertNotIn('UPX', env)
                if command[1] == '--best':
                    Path(command[2]).write_bytes(b'packed')
                else:
                    raise subprocess.CalledProcessError(1, command)

            with patch.object(PACK.subprocess, 'run', side_effect=run):
                with self.assertRaises(subprocess.CalledProcessError):
                    PACK.pack(root / 'upx', [source], output)
            self.assertEqual((output / 'APP.EXE').read_bytes(), b'older valid packed executable')
            self.assertEqual((output / 'compression.json').read_text(), 'older report')

    def test_round_trip_mismatch_is_not_published(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'app.exe'
            source.write_bytes(b'original executable')
            output = root / 'packed'

            def run(command, *, check, env):
                self.assertNotIn('UPX', env)
                if command[1] == '--best':
                    Path(command[2]).write_bytes(b'packed')
                elif command[1] == '-d':
                    Path(command[3]).write_bytes(b'corrupt extraction')

            with patch.object(PACK.subprocess, 'run', side_effect=run):
                with self.assertRaisesRegex(ValueError, 'round-trip changed'):
                    PACK.pack(root / 'upx', [source], output)
            self.assertFalse((output / 'APP.EXE').exists())
            self.assertFalse((output / 'compression.json').exists())


if __name__ == '__main__':
    unittest.main()
