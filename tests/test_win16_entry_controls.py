"""Native entry-control scope guards; real behavior is tested under Win3.11."""
from pathlib import Path
import unittest

from test_win16_handles import active_source
from tools.build_languages import DfmReader
from tools.dfm_loader import compile_loader

ROOT = Path(__file__).resolve().parents[1]


class Win16EntryControlTests(unittest.TestCase):
    def test_edit_uses_real_private_user_edit_not_painted_text(self):
        source = (ROOT / 'src/win16/native_edit.pas').read_text()
        for text in ("RegisterNativeSuperclass('EDIT'", 'CallWindowProc(EditProcedure',
                     '(M.Msg = WM_PAINT) or (M.Msg = WM_ERASEBKGND)',
                     'ES_AUTOHSCROLL', 'ES_READONLY', 'EM_SETREADONLY',
                     'EM_SETPASSWORDCHAR', 'EM_LIMITTEXT', 'Code = EN_CHANGE'):
            self.assertIn(text, source)
        for text in ('ES_UPPERCASE', 'ES_LOWERCASE', 'SetCharCase',
                     'live native uppercase', 'live native lowercase'):
            self.assertIn(text, source + (ROOT / 'tests/pascal/test_win16_edit.pas').read_text())

    def test_edit_preserves_far_win16_selection_abi_and_short_string_bounds(self):
        source = (ROOT / 'src/win16/native_edit.pas').read_text()
        for text in ('LongInt(FSelStart + FSelLength) shl 16',
                     'Perform(EM_SETSEL, 0,', 'Perform(EM_GETSEL, 0, 0)',
                     'while (I < 255) and (Source[I] <> #0)',
                     'GetWindowTextLength(Handle) > 255',
                     'Length(FText) - FSelLength + LongInt(Length(Value)) > 255',
                     '(Value < 0) or (Value > 255)', 'if FMaxLength = 0 then Result := 255',
                     'default 0;', 'Pos(#0, Value)'):
            self.assertIn(text, source)
        self.assertNotIn('StrLen(', source)

    def test_edit_snapshots_native_state_and_releases_event_guard(self):
        source = (ROOT / 'src/win16/native_edit.pas').read_text()
        for text in ('if M.Msg = WM_DESTROY then',
                     'ReadText; ReadSelection; FModified := GetModified',
                     'FInitializing := True', 'finally FInitializing := False',
                     'WriteSelection; SetModified(FModified)',
                     'if FInitializing or FNotifying then Exit',
                     'finally FNotifying := False', 'if Previous <> FText then Change'):
            self.assertIn(text, source)

    def test_clipboard_and_undo_are_real_user_operations(self):
        source = (ROOT / 'src/win16/native_edit.pas').read_text()
        for message in ('WM_CLEAR', 'WM_COPY', 'WM_CUT', 'WM_PASTE', 'EM_UNDO', 'EM_CANUNDO'):
            self.assertIn(f'Perform({message}, 0, 0)', source)
        native = (ROOT / 'tests/pascal/test_win16_edit.pas').read_text()
        for text in ('native clipboard copy and paste', 'native undo restores cut',
                     'selection overflow preserves text', 'empty replacement is quiet',
                     'change error contained at parent callback',
                     'recreation restores native edit state quietly'):
            self.assertIn(text, native)

    def test_checkbox_uses_manual_native_three_state_without_push_button_keys(self):
        source = (ROOT / 'src/win16/native_checkbox.pas').read_text()
        for text in ("RegisterNativeSuperclass('BUTTON'", 'CallWindowProc(CheckProcedure',
                     'or BS_3STATE', 'Perform(BM_GETCHECK, 0, 0)',
                     'Perform(BM_SETCHECK, Ord(Value), 0)',
                     'cbUnchecked: if FAllowGrayed then State := cbGrayed',
                     'cbGrayed: State := cbChecked', 'cbChecked: State := cbUnchecked',
                     'if M.Msg = WM_DESTROY then FState := GetState',
                     'if FNotifying then Exit', 'finally FNotifying := False'):
            self.assertIn(text, source)
        self.assertNotIn('BS_AUTO', source)
        self.assertNotIn('class(TButton)', source)

    def test_native_checkbox_probe_covers_notifications_and_lifetime(self):
        source = (ROOT / 'tests/pascal/test_win16_checkbox.pas').read_text()
        for text in ('mouse toggles exactly once', 'native Space toggles exactly once',
                     'disabled programmatic state still notifies',
                     'Enter is not checkbox toggle', 'nested state mutation has bounded event',
                     'click exception contained in parent', 'recreation is quiet',
                     'checkbox recreation resource stability'):
            self.assertIn(text, source)

    def test_native_integration_validates_then_accepts_or_cancels(self):
        source = (ROOT / 'tests/pascal/test_win16_input_dialog.pas').read_text()
        for text in ('Loop.OnMessage := Form.ProcessDialogMessage',
                     'typing validates', 'Space toggles option',
                     'invalid Enter rejected', 'accept values; no quit',
                     'quiet state recreation',
                     'Loop.OnMessage := nil'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        for name in ('edit', 'checkbox', 'input-dialog'):
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', makefile)
            fixture = (ROOT / f'tests/pascal/test_win16_{name.replace("-", "_")}.pas').read_text()
            self.assertIn('{$M 4096,2048}', fixture)

    def test_original_incremental_search_keeps_original_logic_and_delphi_branch(self):
        fpc = active_source('src/incsrch.pas')
        old = active_source('src/incsrch.pas', False)
        self.assertIn('class(TForm)', fpc)
        self.assertIn('class(TForm)', old)
        self.assertIn('{$R *.dfm}', old)
        self.assertNotIn('{$R *.dfm}', fpc)
        self.assertNotIn('constructor TIncSearchDlg.Create', old)
        for source in (fpc, old):
            for text in ('FOnSearch(self, Edit.Text)', 'Text := Lowercase(InitialChar)',
                         '(Key = VK_RETURN) or (Key = VK_ESCAPE) then Close'):
                self.assertIn(text, source)
        generated, _ = compile_loader((ROOT / 'src/incsrch.dfm').read_bytes(),
                                      (ROOT / 'src/incsrch.pas').read_text(encoding='cp1252'))
        self.assertNotIn('{$I incsrch_form.inc}', fpc)
        for text in ('F.Edit.OnChange := F.EditChange', 'F.Edit.OnKeyDown := F.EditKeyDown',
                     'F.OnShow := F.FormShow', 'F.Edit.CharCase := ecLowerCase',
                     "if InitialChar = #0 then Text := '' else"):
            self.assertIn(text, fpc + generated)

    def test_generated_search_layout_matches_existing_binary_dfm(self):
        properties = ('ClientWidth', 'ClientHeight', 'Left', 'Top', 'Width', 'Height',
                      'CharCase', 'ActiveControl', 'Font.Name', 'Font.Height')
        values = {}
        DfmReader((ROOT / 'src/incsrch.dfm').read_bytes(), properties).component(values)
        source, _ = compile_loader((ROOT / 'src/incsrch.dfm').read_bytes(),
                                   (ROOT / 'src/incsrch.pas').read_text(encoding='cp1252'))
        prefix = 'TIncSearchDlg.'
        width = values[prefix + 'IncSearchDlg.ClientWidth']
        height = values[prefix + 'IncSearchDlg.ClientHeight']
        self.assertIn(f'F.ClientHeight := {height};', source)
        self.assertIn(f'F.ClientWidth := {width};', source)
        for name in ('Edit', 'Label1'):
            bounds = ', '.join(str(values[prefix + name + '.' + p])
                               for p in ('Left', 'Top', 'Width', 'Height'))
            self.assertIn(f'F.{name}.SetBounds({bounds})', source)
            caption = values.get(prefix + name + '.Caption')
            if caption is not None:
                self.assertIn(f"F.{name}.Caption := FormText('TIncSearchDlg', '{name}', 'Caption', '{caption}')", source)
        self.assertEqual(values[prefix + 'Edit.CharCase'], 'ecLowerCase')
        self.assertEqual(values[prefix + 'IncSearchDlg.ActiveControl'], 'Edit')

    def test_original_search_native_probe_covers_reuse_recreation_and_queue(self):
        source = (ROOT / 'tests/pascal/test_win16_incsrch.pas').read_text()
        for text in ('initial', 'empty', 'bounds', 'search', 'Enter', 'Escape', 'case'):
            self.assertIn("'" + text + "'", source)
        self.assertIn('win16-incsrch-runtime-test: win16-incsrch', (ROOT / 'makefile').read_text())
