"""Compile real Microsoft modules; never substitute a host filesystem mock."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'vendor/reference/microsoft-winfile'
WATCOM = Path(os.environ.get('WATCOM', '/opt/watcom'))


@unittest.skipUnless((WATCOM / 'binl64/wcc').is_file(), 'OpenWatcom is not installed')
class WinFilePortTests(unittest.TestCase):
    def test_original_modules_compile_as_win16_omf(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            result = subprocess.run(
                ['make', '-f', 'win16/Makefile', f'WATCOM={WATCOM}',
                 f'OUT={output}', 'core'], cwd=SOURCE,
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for module in ('lfnmisc', 'wfmem', 'numfmt', 'memory'):
                self.assertEqual((output / f'{module}.obj').read_bytes()[0], 0x80,
                                 f'{module} must be a native OMF object')
            self.assertEqual((output / 'WINFILE.LIB').read_bytes()[0], 0xF0)

    def test_small_memory_model_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [str(WATCOM / 'binl64/wcc'), '-q', '-bt=windows', '-ms',
                 f'-i={WATCOM}/h', f'-i={WATCOM}/h/win',
                 f'-fr={directory}/wrong-model.err',
                 f'-fo={directory}/wrong-model.obj', 'win16/memory.c'],
                cwd=SOURCE, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0,
                                'near-only model must not silently compile this port')
            self.assertIn('Dimension cannot be 0 or negative', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
