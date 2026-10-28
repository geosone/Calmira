"""Original password-dialog provenance and portable/native build boundaries."""
import hashlib
from pathlib import Path
import tempfile
import unittest

from test_win16_handles import active_source
from tools.build_languages import build
from tools.compile_dfm import compile_bundle

ROOT = Path(__file__).resolve().parents[1]


class PasswordPortTests(unittest.TestCase):
    def test_original_binary_resources_remain_unchanged(self):
        expected = {
            'src/password.dfm': '64c6e7c15c13e9d5930ca341cba61bae5fc763aa0ee2852c6082fc5712f6cd55',
            'src/locale.res': '8d1d55c0ec816be5349a02615a5a214e06d6cb511583328fc7f8f71a3a8b2e9c',
        }
        for name, digest in expected.items():
            self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), digest)

    def test_original_layout_generates_native_fields_masks_and_event(self):
        source, resources = compile_bundle((ROOT / 'src/password.dfm').read_bytes())
        self.assertTrue(resources)
        for value in ("Edit1.MaxLength := 8", "Edit2.PasswordChar := '*'",
                      "Edit3.PasswordChar := '*'", 'OKBtn.OnClick := OKBtnClick',
                      'CancelBtn.ModalResult := mrCancel', 'if AComponent = Edit1 then Edit1 := nil',
                      'Glyph.LoadFromResourceName(HInstance'):
            self.assertIn(value, source)

    def test_fpc_mode_is_state_not_caption_and_initialization_is_transactional(self):
        source = active_source('src/password.pas')
        self.assertIn('class(TForm)', source)
        self.assertNotIn('{$I password_form.inc}', source)
        self.assertIn('FNewUser and not IsValidLogin', source)
        self.assertIn('not FNewUser and (Edit1.Text <> previous)', source)
        self.assertNotIn('Caption = LocalLoadStr', source)
        self.assertIn('FInitialized := False', source)
        self.assertEqual(source.count('FInitialized := True'), 2)
        self.assertIn('if not FInitialized then raise', source)
        self.assertIn('if Visible or ModalRunning then raise', source)
        self.assertIn('MessageBox(Handle, Text, Title, MB_OK or MB_ICONHAND)', source)
        self.assertNotIn('MiscUtil', source)

    def test_delphi_implementation_is_retained(self):
        source = active_source('src/password.pas', False)
        self.assertIn('class(TForm)', source)
        self.assertIn('{$R *.dfm}', source)
        self.assertIn('AppendStr(Result, IntToHex(Ord(t[i]), 2))', source)
        self.assertIn("(Caption = LocalLoadStr(SCreateNewUser))", source)
        self.assertNotIn('native_modal', source)
        self.assertNotIn('FInitialized', source)

    def test_numeric_resource_provider_stays_lightweight_and_scoped(self):
        source = (ROOT / 'src/win16/resource_text.pas').read_text()
        self.assertIn('Result := Provider; Provider := Value', source)
        self.assertIn('LoadString(HInstance, Ident', source)
        self.assertIn('Provider(Ident, Value)', source)
        self.assertIn('if Assigned(Provider) then ApplyProvider(Ident, Result)', source)
        self.assertIn('Pos(#0, Result)', source)
        self.assertNotIn('language_catalog', source)
        self.assertNotIn('LangUI', source)
        self.assertNotIn('{$R locale.res}', active_source('src/locale.pas'))
        self.assertIn('{$R locale.res}', active_source('src/locale.pas', False))

    def test_bound_resource_path_does_not_reserve_provider_return_temporary(self):
        source = (ROOT / 'src/win16/resource_text.pas').read_text()
        load = source.split('function LocalLoadStr(Ident: Word): string;', 2)[2]
        self.assertIn('LoadString(HInstance, Ident', load)
        self.assertNotIn(':= Provider(', load)
        provider = source.split('procedure ApplyProvider', 1)[1].split('function LocalLoadStr', 1)[0]
        self.assertIn('Value := Provider(Ident, Value)', provider)
        self.assertNotIn('LoadString(', provider)

    def test_german_numeric_overrides_do_not_remove_forms_or_english(self):
        with tempfile.TemporaryDirectory() as directory:
            build(Path(directory))
            german = (Path(directory) / 'de.LNG').read_text(encoding='cp1252')
            english = (Path(directory) / 'en.LNG').read_text(encoding='cp1252')
            self.assertIn('1201=Neuen Benutzer anlegen', german)
            self.assertIn('1205=Kennwort ändern', german)
            self.assertIn('1212=Das eingegebene alte Kennwort ist falsch.', german)
            self.assertIn('TIncSearchDlg.Label1.Caption=', german)
            self.assertIn('1201=Create new user', english)
            self.assertEqual(german.count('[Strings]'), 1)

    def test_separate_profiles_bind_original_strings_and_generated_glyphs(self):
        source = (ROOT / 'makefile').read_text()
        for name in ('password', 'password-language', 'resource-text'):
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', source)
            self.assertIn(f'$(BUILD_DIR)/tests/win16-{name}/units', source)
        self.assertIn('tools/merge_res16.py src/locale.res $(BUILD_DIR)/generated/forms/password_dfm.res', source)
        portable = (ROOT / 'src/portable/legacy_password.pas').read_text()
        self.assertIn('NOT secure encryption', portable)
        self.assertIn('MaxLegacyPasswordLength = 127', portable)
        self.assertIn('Odd(Length(S))', portable)

    def test_edit_callbacks_do_not_reserve_unused_short_string_on_every_message(self):
        source = (ROOT / 'src/win16/native_edit.pas').read_text()
        dispatch = source.split('procedure TEdit.WndProc', 1)[1].split('procedure TEdit.ReadSelection', 1)[0]
        self.assertNotIn('Previous: string', dispatch)
        self.assertIn('ReadChangedText', dispatch)
        window = (ROOT / 'src/win16/native_window.pas').read_text()
        callback = window.split('function NativeWindowProc', 1)[1].split('procedure RegisterNativeSuperclass', 1)[0]
        self.assertIn('Instance.RecordCallbackException(E)', callback)
        self.assertNotIn('RecordCallbackError(E.Message)', callback)
        for name in ('password', 'password_language'):
            fixture = (ROOT / f'tests/pascal/test_win16_{name}.pas').read_text()
            self.assertIn('{$M 4096,2048}', fixture)
            self.assertIn('Check(StackGuardIntact', fixture)


if __name__ == '__main__':
    unittest.main()
