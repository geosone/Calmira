"""Scope guards supplement (not replace) the real USER keyboard tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeMnemonicTests(unittest.TestCase):
    def read(self, name):
        return (ROOT / name).read_text()

    def test_alt_dispatch_is_scoped_to_managed_enabled_origin(self):
        source = self.read('src/win16/native_form.pas')
        for text in ('if not CanFocus then Exit', 'Message.message = WM_SYSCHAR',
                     '$20000000', 'Message.wParam > 255', 'GetKeyState(VK_CONTROL)',
                     'FindControl(Message.hwnd)', 'Current.CanFocus', 'DispatchMnemonic'):
            self.assertIn(text, source)

    def test_label_target_is_weak_and_revalidated_before_focus(self):
        source = self.read('src/win16/native_label.pas')
        for text in ('RemoveFreeNotification(Self)', 'Value.FreeNotification(Self)',
                     'Operation = opRemove', 'FFocusControl := nil',
                     'Root.FindControl(Target.Handle) <> Target', 'not Target.CanFocus'):
            self.assertIn(text, source)
        body = source.split('function TLabel.DialogChar', 1)[1].split('constructor ', 1)[0]
        self.assertLess(body.index('Result := True'), body.index('Target.SetFocus'))
        self.assertNotIn('Target.', body.split('Target.SetFocus;', 1)[1])

    def test_native_probe_covers_callback_and_lifetime_edges(self):
        source = self.read('tests/pascal/test_win16_mnemonic.pas')
        for text in ('ANSI case', 'ampersands', 'first label', 'hidden label',
                     'disabled target', 'escaped prefix', 'weak reference', 'foreign target',
                     'nested target', 'disabled container', 'button once', 'checkbox once',
                     'requires Alt context', 'foreign origin', 'focus callback veto',
                     'filter recovery', 'recreate', '{$M 4096,2048}'):
            self.assertIn(text, source)

    def test_original_select_callback_body_and_tokenizer_are_preserved(self):
        select = self.read('src/select.pas')
        self.assertIn('s := Edit.Text;', select)
        self.assertIn("FSelectFiles(Self, GetWord(s, ';'), Sender = SelectBtn);", select)
        self.assertIn("until s = '';", select)
        self.assertIn("Icons.Get('MultiFile')", select)
        self.assertIn("LoadFromResource(HInstance, 'MULTIFILEICON')", select)
        original = self.read('vcl/strings.pas').split('implementation', 1)[1]
        original = original.split('function GetWord(var s: OpenString; delim: Char): string;', 1)[1]
        original = original.split('\nfunction ', 1)[0].strip()
        extracted = self.read('src/portable/word_tokens.pas').split('implementation', 1)[1]
        extracted = extracted.split('function GetWord(var s: OpenString; delim: Char): string;', 1)[1]
        extracted = extracted.rsplit('end.', 1)[0].strip()
        self.assertEqual(original, extracted)
