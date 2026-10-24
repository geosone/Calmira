"""Track the actual Win16 ABI port and non-mutating RTL preparation."""
import importlib.util
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('prepare_win16_rtl', ROOT / 'tools/prepare_win16_rtl.py')
PREPARE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREPARE)


class Win16MessageTests(unittest.TestCase):
    def test_all_message_records_used_by_owned_sources_have_declarations(self):
        required = set()
        for directory in ('src', 'vcl'):
            for path in (ROOT / directory).rglob('*.pas'):
                if path.name != 'messages.pas':
                    required.update(name.lower() for name in re.findall(
                        r'\b(?:TWM\w+|TMessage)\b', path.read_bytes().decode('latin-1')))
        source = (ROOT / 'src/win16/messages.pas').read_text()
        declared = {name.lower() for name in re.findall(r'\b(T\w+)\s*=', source)}
        self.assertFalse(required - declared, sorted(required - declared))
        self.assertIn('{$IFNDEF WIN16}{$FATAL', source)

    def test_source_provenance_and_license_text_are_retained(self):
        origin = json.loads((ROOT / 'src/win16/messages.origin.json').read_text())
        self.assertEqual(origin['revision'], '25d18a56b13a2ae1a2760ade7c5960847811f622')
        original_source = ROOT / 'vendor/reference/freepascal' / origin['source']
        self.assertEqual(hashlib.sha256(original_source.read_bytes()).hexdigest(), origin['upstream_sha256'])
        for supplied, original in (('fpc-rtl-copying.txt', 'COPYING.txt'),
                                   ('fpc-rtl-exception.txt', 'COPYING.FPC')):
            self.assertEqual((ROOT / 'docs/licenses' / supplied).read_text().rstrip(),
                             (ROOT / 'vendor/reference/freepascal/rtl' / original).read_text().rstrip())

    def test_preparation_patches_only_a_fingerprinted_copy_and_reuses_it(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'checkout'
            source.mkdir()
            subprocess.run(['git', 'init', '-q', str(source)], check=True)
            original = ('           msghandler : tmessagehandler;\n\n'
                        '        begin\n           index:=dword(message);\n'
                        '           ovmt := PVmt(ClassType);\n'
                        '           while assigned(ovmt) do\n             begin\n')
            path = source / 'rtl/inc/objpas.inc'
            path.parent.mkdir(parents=True)
            path.write_text(original)
            jump = source / 'rtl/i8086/setjump.inc'
            jump.parent.mkdir(parents=True)
            jump.write_bytes((ROOT / 'vendor/reference/freepascal/rtl/i8086/setjump.inc').read_bytes())
            system = source / 'rtl/win16/system.pp'
            system.parent.mkdir(parents=True)
            original_system = (ROOT / 'vendor/reference/freepascal/rtl/win16/system.pp').read_bytes()
            system.write_bytes(original_system)
            heap = source / 'rtl/win16/glbheap.inc'
            original_heap = (ROOT / 'vendor/reference/freepascal/rtl/win16/glbheap.inc').read_bytes()
            heap.write_bytes(original_heap)
            extra = {}
            for name in ('rtl/win16/dos.pp', 'rtl/win16/prt0comn.asm',
                         'rtl/objpas/sysutils/sysstrh.inc', 'rtl/objpas/sysutils/sysstr.inc',
                         'rtl/objpas/sysutils/sysutilh.inc', 'rtl/objpas/sysutils/sysutils.inc',
                         'rtl/objpas/sysutils/datih.inc',
                         'rtl/objpas/sysutils/dati.inc', 'rtl/win16/winprocsh.inc', 'rtl/win16/win31.pp',
                         'rtl/win16/wintypes.inc'):
                target = source / name
                target.parent.mkdir(parents=True, exist_ok=True)
                extra[name] = (ROOT / 'vendor/reference/freepascal' / name).read_bytes()
                target.write_bytes(extra[name])
            subprocess.run(['git', '-C', str(source), 'add', 'rtl'], check=True)
            subprocess.run(['git', '-C', str(source), '-c', 'user.name=Fixture',
                            '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'Fixture'], check=True)
            output = Path(directory) / 'prepared'
            first = PREPARE.prepare(source, output)
            self.assertEqual(path.read_text(), original)
            self.assertEqual(system.read_bytes(), original_system)
            self.assertEqual(heap.read_bytes(), original_heap)
            for name, content in extra.items():
                self.assertEqual((source / name).read_bytes(), content, name)
            self.assertIn('CALMIRA_WIN16_DOS_NO_STRINGS', (first / 'rtl/win16/dos.pp').read_text(encoding='latin1'))
            self.assertIn('set_unit_var __fpc_HInstance, 0, di', (first / 'rtl/win16/prt0comn.asm').read_text())
            self.assertIn('PAutoDataSegHeader(Ptr(SSeg,0))', (first / 'rtl/win16/system.pp').read_text(encoding='latin1'))
            self.assertIn('procedure AppendStr(var Dest: OpenString; const S: ShortString);',
                          (first / 'rtl/objpas/sysutils/sysstr.inc').read_text(encoding='latin1'))
            self.assertIn('Procedure FmtStr(Var Res: OpenString; Const Fmt : String; Const args: Array of const);',
                          (first / 'rtl/objpas/sysutils/sysstrh.inc').read_text(encoding='latin1'))
            self.assertIn('TFileName = ShortString;',
                          (first / 'rtl/objpas/sysutils/sysutilh.inc').read_text(encoding='latin1'))
            self.assertIn('procedure DateTimeToString(var Result: OpenString;',
                          (first / 'rtl/objpas/sysutils/dati.inc').read_text(encoding='latin1'))
            wintypes = (first / 'rtl/win16/wintypes.inc').read_text(encoding='latin1')
            self.assertIn('{$ifdef CALMIRA_WIN16_DELPHI1_TYPES}', wintypes)
            self.assertIn('LPPOINT = ^TPoint; far;', wintypes)
            winprocs = (first / 'rtl/win16/winprocsh.inc').read_text(encoding='latin1')
            self.assertIn('function FillRect(hdc: HDC; constref rc: TRect; hbr: HBRUSH)', winprocs)
            self.assertIn('function IntersectRect(var rcDest: TRect; constref rcSrc1, rcSrc2: TRect)', winprocs)
            self.assertIn('constref rcSource1, rcSource2: TRect',
                          (first / 'rtl/win16/win31.pp').read_text(encoding='latin1'))
            patched_heap = (first / 'rtl/win16/glbheap.inc').read_text()
            self.assertIn('CALMIRA_WIN16_REALLOC_BOUNDS', patched_heap)
            self.assertIn('if CopySize>size then', patched_heap)
            self.assertIn('Move(p^,result^,CopySize);', patched_heap)
            self.assertIn('Move(p^,result^,SysGlobalMemSize(p));', patched_heap)
            prepared_system = (first / 'rtl/win16/system.pp').read_text()
            self.assertIn('defined(WIN16) and defined(CALMIRA_WIN16_GUI_STDIO)', prepared_system)
            self.assertIn('{$define FPC_ANSI_TEXTFILEREC}', prepared_system)
            self.assertIn('{$define FPC_STDOUT_TRUE_ALIAS}', prepared_system)
            self.assertIn('{$I calmira_guierr.inc}', prepared_system)
            self.assertIn('ReleaseGuiErrorBuffer;', prepared_system)
            self.assertIn('TextRec(F).Handle:=UnusedHandle;', prepared_system)
            overlay = Path('rtl/win16/calmira_guierr.inc')
            overlay_source = ROOT / 'src/win16/rtl_gui_error.inc'
            self.assertEqual((first / overlay).read_bytes(), overlay_source.read_bytes())
            manifest = json.loads((first / 'calmira-rtl.json').read_text())
            self.assertEqual(manifest['schema'], 2)
            self.assertEqual(manifest['overlays'][str(overlay)],
                             hashlib.sha256(overlay_source.read_bytes()).hexdigest())
            alternate = Path(directory) / 'alternate.inc'
            alternate.write_bytes(overlay_source.read_bytes() + b'\n{ changed overlay }\n')
            with patch.object(PREPARE, 'OVERLAYS', {overlay: alternate}):
                changed_overlay = PREPARE.prepare(source, output)
            self.assertNotEqual(first, changed_overlay)
            self.assertEqual((changed_overlay / overlay).read_bytes(), alternate.read_bytes())
            self.assertEqual((first / overlay).read_bytes(), overlay_source.read_bytes())
            patched = (first / 'rtl/inc/objpas.inc').read_text()
            jump_patch = (first / 'rtl/i8086/setjump.inc').read_text()
            self.assertIn('CALMIRA_WIN16_SJLJ_TAILCALL', jump_patch)
            self.assertIn('requires far code and far data', jump_patch)
            self.assertIn('dw offset Catch', jump_patch)
            self.assertIn('dw offset Throw', jump_patch)
            self.assertIn('fpc_SetJmp:=Catch', jump_patch)
            self.assertIn('index:=word(message);', patched)
            self.assertIn('index:=dword(message);', patched)
            self.assertIn('defined(WIN16) and defined(CALMIRA_WIN16_MESSAGE_ABI)', patched)
            self.assertEqual(PREPARE.prepare(source, output), first)
            path.write_text(original + '\n{ changed source }\n')
            second = PREPARE.prepare(source, output)
            self.assertNotEqual(first, second)
            self.assertIn('{ changed source }', (second / 'rtl/inc/objpas.inc').read_text())
            self.assertTrue(first.exists())
            with self.assertRaisesRegex(ValueError, 'outside'):
                PREPARE.prepare(source, source / 'build')


if __name__ == '__main__':
    unittest.main()
