"""The optional emulator builder must reject unverified source archives."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / 'tools/analysis/build_qemu_enter.sh'


class QemuEnterBuildTests(unittest.TestCase):
    def test_missing_archive_is_rejected_before_build(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(['sh', str(BUILDER)], capture_output=True,
                                    text=True, env=dict(os.environ,
                                    QEMU_SOURCE_ARCHIVE=str(Path(directory) / 'missing')))
            self.assertEqual(result.returncode, 2)
            self.assertIn('QEMU_SOURCE_ARCHIVE', result.stderr)

    def test_unverified_archive_is_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'invalid.tar.xz'
            archive.write_bytes(b'not the verified release')
            result = subprocess.run(['sh', str(BUILDER)], capture_output=True,
                                    text=True, env=dict(os.environ,
                                    QEMU_SOURCE_ARCHIVE=str(archive)))
            self.assertEqual(result.returncode, 2)
            self.assertIn('SHA-512 mismatch', result.stderr)

    @unittest.skipUnless(shutil.which('patch'), 'requires patch')
    def test_patch_only_zero_extends_the_enter_allocation(self):
        before = ('static void gen_ENTER(DisasContext *s, X86DecodedInsn *decode)\n'
                  '{\n'
                  '   gen_enter(s, decode->op[1].imm, decode->op[2].imm);\n'
                  '}\n\n')
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'target/i386/tcg/emit.c.inc'
            target.parent.mkdir(parents=True)
            target.write_text(before)
            result = subprocess.run(['patch', '--batch', '--fuzz=0', '-p1',
                                     '-i', str(ROOT / 'tools/patches/qemu-10.2.3-enter-unsigned.patch')],
                                    cwd=directory, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(target.read_text(), before.replace(
                's, decode->op[1].imm', 's, (uint16_t)decode->op[1].imm'))
