"""Source contract for the initial Dialogs subset; native tests run under Win3.11."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'src/win16/dialogs.pas'


class DialogsSubsetTests(unittest.TestCase):
    def test_delphi_1_types_keep_their_order(self):
        source = SOURCE.read_text()
        self.assertIn('TMsgDlgType = (mtWarning, mtError, mtInformation, mtConfirmation, mtCustom);', source)
        self.assertIn('TMsgDlgBtn = (mbYes, mbNo, mbOK, mbCancel, mbAbort, mbRetry, mbIgnore, mbAll, mbHelp);', source)
        self.assertIn('(mrYes, mrNo, mrOk, mrCancel, mrAbort, mrRetry, mrIgnore, mrAll, mrNone)', source)

    def test_dialogs_use_native_controls_not_messagebox(self):
        source = SOURCE.read_text()
        self.assertNotIn('MessageBox(', source)
        for text in ('native_label', 'native_button', 'native_edit', 'Form.ShowModal',
                     'finally Form.Free; end;', "LoadIcon(0, Icons[AType])"):
            self.assertIn(text, source)
        # StdCtrls would also link the checkbox into the shared DGROUP.
        self.assertNotIn('StdCtrls', source.split('implementation', 1)[1])

    def test_no_form_subclass_or_extra_exception_class(self):
        source = SOURCE.read_text()
        self.assertNotIn('= class(TForm)', source)
        self.assertNotIn('class(Exception)', source)
        self.assertIn('Form.CreateHandle(0, Form.Caption, DialogStyle', source)

    def test_default_and_cancel_buttons_follow_delphi(self):
        source = SOURCE.read_text()
        for text in ('if mbOK in AButtons then DefaultButton := mbOK',
                     'else if mbYes in AButtons then DefaultButton := mbYes',
                     'if mbCancel in AButtons then CancelButton := mbCancel',
                     'else if mbNo in AButtons then CancelButton := mbNo'):
            self.assertIn(text, source)

    def test_captions_are_localized_in_all_catalogues(self):
        source = SOURCE.read_text()
        self.assertIn("FormText('TMessageForm', Key, 'Caption', Default)", source)
        self.assertIn("FormText('TStandardButtons', 'Cancel', 'Caption', Default)", source)
        extras = json.loads((ROOT / 'locales/extra.json').read_text())
        for code in ('en', 'de', 'fr'):
            forms = extras[code]['Forms']
            for key in ('Warning', 'Error', 'Information', 'Confirm', 'Yes', 'No', 'OK',
                        'Help', 'Abort', 'Retry', 'Ignore', 'All'):
                self.assertIn(f'TMessageForm.{key}.Caption', forms, code)

    def test_common_dialogs_are_not_silently_aliased(self):
        interface = SOURCE.read_text().split('unit Dialogs;', 1)[1].split('implementation', 1)[0]
        for name in ('TOpenDialog', 'TSaveDialog', 'TFontDialog', 'TColorDialog'):
            self.assertNotIn(name, interface)

    def test_native_suites_are_part_of_fixed_regression(self):
        makefile = (ROOT / 'makefile').read_text()
        regression = makefile.split('win16-fixed-regression: fpc-win16-fixed-compiler', 1)[1].split('\n\n', 1)[0]
        for target in ('win16-dialogs-runtime-test', 'win16-input-query-runtime-test'):
            self.assertIn(target, regression)


if __name__ == '__main__':
    unittest.main()
