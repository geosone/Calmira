"""Integration boundaries for the shared, dual-target diagnostic implementation."""
from pathlib import Path
import hashlib
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GUIErrorBufferTests(unittest.TestCase):
    def test_upstream_provenance_and_linking_exception_are_retained(self):
        origin = json.loads((ROOT / 'src/win16/rtl_gui_error.origin.json').read_text())
        original = ROOT / 'vendor/reference/freepascal' / origin['source']
        self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(), origin['upstream_sha256'])
        self.assertEqual(origin['revision'], '25d18a56b13a2ae1a2760ade7c5960847811f622')
        for license_file in ('fpc-rtl-copying.txt', 'fpc-rtl-exception.txt'):
            self.assertTrue((ROOT / 'docs/licenses' / license_file).is_file())

    def test_private_runtime_retains_default_branch_and_full_capacity(self):
        patch = (ROOT / 'tools/patches/fpc-win16-gui-error-buffer.patch').read_text()
        for text in ('{$IFDEF CALMIRA_WIN16_GUI_STDIO}', '{$ELSE}',
                     'ErrorBuf : array[0..ErrorBufferLength]', '{$I calmira_guierr.inc}',
                     'ReleaseGuiErrorBuffer;', 'EnsureGuiErrorBuffer;',
                     'TextRec(F).Handle:=UnusedHandle;'):
            self.assertIn(text, patch)
        original = (ROOT / 'vendor/reference/freepascal/rtl/win16/system.pp').read_text()
        self.assertIn('ErrorBufferLength = 1024;', original)
        self.assertNotIn('calmira_guierr.inc', original)

    def test_host_and_win16_execute_the_same_implementation_with_bounds_checks(self):
        harness = (ROOT / 'tests/pascal/test_gui_error_buffer.pas').read_text()
        self.assertIn('{$I ../../src/win16/rtl_gui_error.inc}', harness)
        for behavior in ('buffer canaries', 'no repeated prefix/lost suffix',
                         'multiple complete buffers', 'allocation failure retains complete text',
                         'lock failure releases allocation', 'balanced cycles'):
            self.assertIn(behavior, harness)
        makefile = (ROOT / 'makefile').read_text()
        rule = makefile.split('win16-gui-buffer: ', 1)[1].split('win16-gui-buffer-runtime-test:', 1)[0]
        self.assertIn('-Cr -Co', rule)
        self.assertIn('tests/pascal/test_gui_error_buffer.pas', rule)

    def test_emergency_output_uses_only_windows_allocations_and_bounded_stack(self):
        source = (ROOT / 'src/win16/rtl_gui_error.inc').read_text()
        self.assertIn('GlobalAlloc(GMEM_FIXED or GMEM_ZEROINIT, ErrorBufferLength + 1)', source)
        self.assertIn('Emergency: array[0..256]', source)
        self.assertIn('PFarChar(F.BufPtr)[Consumed]', source)
        self.assertIn('Inc(Consumed, Count)', source)
        self.assertNotIn('GetMem(', source)
        self.assertNotIn('AllocMem(', source)

    def test_selection_acceptance_includes_runtime_languages_and_public_field_lifetime(self):
        makefile = (ROOT / 'makefile').read_text()
        batch = makefile.split('win16-ui-runtime-test:', 1)[1].split('calmira:', 1)[0]
        self.assertIn('win16-select-runtime-test', batch)
        self.assertIn('win16-select-language-runtime-test', batch)
        language = (ROOT / 'tests/pascal/test_win16_select_language.pas').read_text()
        for text in ('Catalog.SelectLanguage(Code)', 'SetFormTextProvider(Previous)',
                     'localized action', 'Dialog.Edit.Free', 'Dialog.Edit = nil',
                     'Dialog.InitialControl = nil', 'Dialog.Label1.FocusControl = nil'):
            self.assertIn(text, language)
