"""Validate the independent CPU probe, not the installed emulator's behavior."""
import errno
import os
from pathlib import Path
import platform
import shutil
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class EnterProbeTests(unittest.TestCase):
    @unittest.skipUnless(platform.machine() in ('x86_64', 'i386', 'i686')
                         and shutil.which('nasm') and shutil.which('ld'),
                         'requires an x86 Linux host with NASM and ld')
    def test_native_enter_allocations_match_unsigned_immediates(self):
        with tempfile.TemporaryDirectory() as directory:
            obj = str(Path(directory) / 'probe.o')
            exe = str(Path(directory) / 'probe')
            subprocess.run(['nasm', '-f', 'elf32',
                            str(ROOT / 'tests/asm/enter_frame_probe.asm'),
                            '-o', obj], check=True, capture_output=True)
            subprocess.run(['ld', '-m', 'elf_i386', obj, '-o', exe],
                           check=True, capture_output=True)
            try:
                result = subprocess.run([exe], capture_output=True, timeout=5)
            except OSError as error:
                if error.errno == errno.ENOEXEC:
                    self.skipTest('native Linux i386 execution unavailable')
                raise
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, struct.pack('<4I', 0x7fff, 0x8000,
                                                        0x846c, 0xffff))

    def test_instrumentation_requires_explicit_build_directory(self):
        environment = os.environ.copy()
        environment['ARCHIVE_DIAGNOSTIC'] = '1'
        environment.pop('ARCHIVE_BUILD_DIR', None)
        result = subprocess.run(['sh', str(ROOT / 'tools/build_archive_reader.sh'), 'dos'],
                                env=environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ARCHIVE_BUILD_DIR', result.stderr)

    def test_instrumentation_rejects_host_mode(self):
        environment = dict(os.environ, ARCHIVE_DIAGNOSTIC='1',
                           ARCHIVE_BUILD_DIR='/unused-diagnostic-output')
        result = subprocess.run(['sh', str(ROOT / 'tools/build_archive_reader.sh'), 'host'],
                                env=environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('DOS mode', result.stderr)
