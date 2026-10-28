"""Compiler correction provenance, isolated staging and native acceptance wiring."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import prepare_fpc_compiler as stage

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / 'vendor/reference/freepascal'


def checkout(directory):
    source = Path(directory) / 'checkout'
    source.mkdir()
    subprocess.run(['git', 'init', '-q', str(source)], check=True)
    files = {'compiler/i8086/n8086add.pas': (UPSTREAM / 'compiler/i8086/n8086add.pas').read_bytes(),
             'compiler/i8086/n8086ld.pas': (UPSTREAM / 'compiler/i8086/n8086ld.pas').read_bytes(),
             'compiler/i8086/hlcgcpu.pas': (UPSTREAM / 'compiler/i8086/hlcgcpu.pas').read_bytes(),
             'compiler/Makefile': b'# fixture\n', 'rtl/Makefile': b'# fixture\n',
             'Makefile': b'# fixture\n', 'Makefile.fpc': b'# fixture\n',
             'LICENSE': b'fixture license\n'}
    for name, data in files.items():
        path = source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    subprocess.run(['git', '-C', str(source), 'add', '.'], check=True)
    subprocess.run(['git', '-C', str(source), '-c', 'user.name=Fixture',
                    '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Fixture'], check=True)
    return source, files


class CompilerPointerTests(unittest.TestCase):
    def test_stage_is_fingerprinted_nonmutating_and_excludes_untracked_build_files(self):
        with tempfile.TemporaryDirectory() as directory:
            source, files = checkout(directory)
            (source / 'compiler/local.ppu').write_bytes(b'not tracked')
            output = Path(directory) / 'staged'
            target = stage.prepare(source, output, 'test-bootstrap')
            self.assertEqual(stage.prepare(source, output, 'test-bootstrap'), target)
            self.assertFalse((target / 'compiler/local.ppu').exists())
            for name, data in files.items():
                self.assertEqual((source / name).read_bytes(), data)
            code = (target / 'compiler/i8086/n8086add.pas').read_text()
            self.assertIn('is_implicit_pointer_object_type(left.resultdef)', code)
            self.assertIn('(left.resultdef.typ=classrefdef)) and (left.resultdef.size=4)', code)
            self.assertIn('if is_farpointer(left.resultdef) then\n          second_cmpfarpointer', code)
            load = (target / 'compiler/i8086/n8086ld.pas').read_text()
            self.assertIn('(tconstsym(symtableentry).consttyp in [constresourcestring,constwresourcestring]) and\n'
                          '                 (current_settings.x86memorymodel=mm_huge)', load)
            self.assertIn('segref.refaddr:=addr_seg;\n                  cg.a_load_ref_reg', load)
            wrapper = (target / 'compiler/i8086/hlcgcpu.pas').read_text()
            self.assertIn('procedure thlcgcpu.g_external_wrapper(', wrapper)
            self.assertIn('if not is_proc_far(procdef) then', wrapper)
            self.assertIn('list.concat(taicpu.op_sym(A_JMP,S_FAR,current_asmdata.RefAsmSymbol(externalname,AT_FUNCTION)));',
                          wrapper)
            manifest = json.loads((target / 'calmira-compiler.json').read_text())
            self.assertEqual(manifest['schema'], 2)
            self.assertEqual(manifest['build_id'], 'test-bootstrap')
            self.assertEqual(manifest['patches'], {patch.name: hashlib.sha256(patch.read_bytes()).hexdigest()
                                                   for patch in stage.PATCHES})
            self.assertEqual((target / 'LICENSE').read_bytes(), files['LICENSE'])

    def test_build_identity_builder_and_tracked_source_invalidate_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            source, _ = checkout(directory)
            output = Path(directory) / 'staged'
            first = stage.prepare(source, output, 'one')
            self.assertNotEqual(first, stage.prepare(source, output, 'two'))
            builder = Path(directory) / 'builder.sh'
            builder.write_bytes(stage.BUILDER.read_bytes() + b'\n# changed build options\n')
            with patch.object(stage, 'BUILDER', builder):
                self.assertNotEqual(first, stage.prepare(source, output, 'one'))
            path = source / 'compiler/i8086/n8086add.pas'
            path.write_bytes(path.read_bytes() + b'\n{ tracked change }\n')
            changed = stage.prepare(source, output, 'one')
            self.assertNotEqual(first, changed)
            self.assertTrue(first.exists())

    def test_rejects_source_overlap_incomplete_sources_and_bad_cache_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            source, _ = checkout(directory)
            with self.assertRaisesRegex(ValueError, 'outside'):
                stage.prepare(source, source / 'build', 'test')
            output = Path(directory) / 'staged'
            target = stage.prepare(source, output, 'test')
            (target / 'calmira-compiler.json').write_text('{"fingerprint":"wrong"}')
            with self.assertRaisesRegex(ValueError, 'fingerprint'):
                stage.prepare(source, output, 'test')
            subprocess.run(['git', '-C', str(source), 'rm', '-q', 'LICENSE'], check=True)
            with self.assertRaisesRegex(ValueError, 'incomplete tracked'):
                stage.prepare(source, output, 'test')

    def test_patch_failure_leaves_no_partial_stage(self):
        with tempfile.TemporaryDirectory() as directory:
            source, files = checkout(directory)
            bad = Path(directory) / 'bad.patch'
            bad.write_text('--- a/compiler/i8086/n8086add.pas\n+++ b/compiler/i8086/n8086add.pas\n'
                           '@@ -1 +1 @@\n-not present in source\n+changed\n')
            output = Path(directory) / 'staged'
            with patch.object(stage, 'PATCHES', (bad,)), self.assertRaises(subprocess.CalledProcessError):
                stage.prepare(source, output, 'test')
            self.assertEqual(list(output.iterdir()), [])
            self.assertEqual((source / 'compiler/i8086/n8086add.pas').read_bytes(),
                             files['compiler/i8086/n8086add.pas'])

    def test_native_regression_has_a_separate_compiler_rtl_and_unit_tree(self):
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-fixed-regression: fpc-win16-fixed-compiler', make)
        self.assertIn("BUILD_DIR='$(BUILD_DIR)/class-pointer/'\"$$compiler_profile\"", make)
        self.assertIn('["fingerprint"][:20]', make)
        self.assertIn("FPC_WIN16='$(abspath $(FPC_WIN16_FIXED))'", make)
        self.assertIn('win16-class-pointer-runtime-test: win16-class-pointer', make)
        native = (ROOT / 'tests/pascal/test_win16_class_pointer.pas').read_text()
        for case in ('class segment participates', 'class offset participates',
                     'same offset different segments', 'classref segment participates',
                     'direct allocation has zero offset', 'failed constructor cleanup',
                     'repeated lifetime balance', 'Check(StackGuardIntact'):
            self.assertIn(case, native)
        self.assertIn("RTL_TEST_EXE='$(abspath $(BUILD_DIR)/tests/win16-classes/RTLTEST.EXE)'", make)
        self.assertIn("RTL_CATALOG_DIR='$(abspath $(BUILD_DIR)/lang)'", make)
        runner = (ROOT / 'tests/dos/test_win16_classes_win311.sh').read_text()
        self.assertIn('${RTL_TEST_EXE:-', runner)
        self.assertIn('${RTL_CATALOG_DIR:-', runner)

    def test_language_target_generates_into_selected_build_tree(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'isolated'
            subprocess.run(['make', 'BUILD_DIR=' + str(output), 'languages'], cwd=ROOT,
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertTrue((output / 'lang/en.LNG').is_file())
            self.assertTrue((output / 'lang/de.LNG').is_file())
            self.assertTrue((output / 'lang/fr.LNG').is_file())


if __name__ == '__main__':
    unittest.main()
