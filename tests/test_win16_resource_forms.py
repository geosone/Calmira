"""Original-dialog routing, lightweight units and reproducible build wiring."""
import json
from pathlib import Path
import tempfile
import unittest

from test_win16_handles import active_source
from tools.build_languages import build
from tools.compile_dfm import compile_bundle, inventory

ROOT = Path(__file__).resolve().parents[1]


class Win16ResourceFormTests(unittest.TestCase):
    def test_original_drag_drop_handlers_and_delphi_branch_are_retained(self):
        fpc = active_source('src/askdrop.pas')
        old = active_source('src/askdrop.pas', False)
        self.assertIn('class(TNativeModalForm)', fpc)
        self.assertIn('{$I askdrop_form.inc}', fpc)
        self.assertIn('Icon.Picture.Icon.LoadFromResource(0, IDI_QUESTION)', fpc)
        self.assertIn('InitialControl := BitBtn1', fpc)
        self.assertIn('if SoundEnabled then MessageBeep(MB_ICONQUESTION)', fpc)
        self.assertNotIn('MiscUtil', fpc.split('implementation', 1)[1])
        self.assertIn('class(TForm)', old)
        self.assertIn('{$R *.dfm}', old)
        self.assertIn('Icon.Picture.Icon.Handle := LoadIcon(0, IDI_QUESTION)', old)
        self.assertIn('if MsgDialogSounds then MessageBeep(MB_ICONQUESTION)', old)

    def test_picbtn_loaded_is_guarded_and_does_not_import_entry_controls(self):
        fpc = active_source('vcl/picbtn.pas')
        old = active_source('vcl/picbtn.pas', False)
        self.assertIn('if FResourceLoaded then Exit', fpc)
        self.assertIn('FResourceLoaded := True', fpc)
        self.assertIn('procedure TPicBtn.FinishLoading', fpc)
        self.assertNotIn('StdCtrls', fpc)
        self.assertNotIn('FResourceLoaded', old)
        self.assertNotIn('procedure TPicBtn.FinishLoading', old)

    def test_language_extras_merge_forms_instead_of_erasing_upstream_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            build(Path(directory))
            for code, caption in [('en', 'Cancel'), ('de', 'Abbrechen'), ('fr', 'Annuler')]:
                data = (Path(directory) / (code + '.LNG')).read_text(encoding='cp1252')
                self.assertIn('TStandardButtons.Cancel.Caption=' + caption, data)
                self.assertIn('TIncSearchDlg.Label1.Caption=', data)
                self.assertIn('TAskDropBox.BitBtn1.Caption=', data)
                self.assertEqual(data.count('[Forms]'), 1)
                coverage = json.loads((Path(directory) / 'coverage.json').read_text())
                self.assertGreater(coverage[code]['entries'], 900)

    def test_resource_inventory_distinguishes_layout_support_from_source_porting(self):
        report = inventory(ROOT / 'src')
        for name in ('askdrop.dfm', 'incsrch.dfm', 'password.dfm'):
            self.assertIn(name, report['supported'])
        self.assertIn('Kind', report['blocked']['replace.dfm'])
        self.assertIn('class(TNativeModalForm)', active_source('src/password.pas'))
        self.assertIn('Forms, Dialogs', active_source('src/password.pas', False))

    def test_native_resource_binding_and_separate_probe_outputs_are_required(self):
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('--resources $(BUILD_DIR)/generated/forms/askdrop.res', makefile)
        for name in ('askdrop', 'askdrop-modal', 'askdrop-language'):
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', makefile)
            self.assertIn(f'$(BUILD_DIR)/tests/win16-{name}/units', makefile)
            self.assertIn(f'$(BUILD_DIR)/generated/forms/askdrop.res $(BUILD_DIR)/tests/win16-{name}/GDITEST.EXE', makefile)
        self.assertIn('win16-gui-stdio-runtime-test: win16-gui-stdio', makefile)
        source, resources = compile_bundle((ROOT / 'src/askdrop.dfm').read_bytes())
        self.assertTrue(resources)
        self.assertIn('DfmCreateEvent := FormCreate', source)

    def test_caption_provider_does_not_eagerly_import_the_concrete_catalogue(self):
        provider = (ROOT / 'src/win16/form_text.pas').read_text()
        catalog = (ROOT / 'src/win16/form_catalog.pas').read_text()
        self.assertIn('uses SysUtils;', provider)
        self.assertNotIn('TFormTextCatalog = class', provider)
        self.assertIn('TFormTextCatalog = class(TObject)', catalog)
        self.assertIn('GetPrivateProfileString', catalog)

    def test_gui_runtime_has_explicit_output_alias_and_ansi_record_acceptance(self):
        fixture = (ROOT / 'tests/pascal/test_win16_gui_stdio.pas').read_text()
        for text in ('@Output = @StdOut', '@Output = @ErrOutput', '@Output = @StdErr',
                     'SizeOf(TextRec(T).Name) = 256', 'SizeOf(TextRec(T).Buffer) = 256',
                     'SysInitStdIO', 'explicit Text I/O across buffer boundaries'):
            self.assertIn(text, fixture)
        self.assertIn('-dCALMIRA_WIN16_GUI_STDIO', (ROOT / 'tools/build_win16_rtl.sh').read_text())


if __name__ == '__main__':
    unittest.main()
