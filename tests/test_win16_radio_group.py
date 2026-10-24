"""Group box, radio group and PicBtn dialog-size guards."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16RadioGroupTests(unittest.TestCase):
    def test_group_box_follows_delphi_interface(self):
        source = (ROOT / 'src/win16/stdctrls.pas').read_text()
        for text in ('TCustomGroupBox = class(TCustomControl)', 'TGroupBox = class(TCustomGroupBox)',
                     'Inc(Rect.Top, CaptionHeight);', 'if Ctl3D then InflateRect(Rect, -1, -1);',
                     '{ Also needed outside Paint, where the control canvas has no DC. }'):
            self.assertIn(text, source)

    def test_radio_group_follows_delphi_interface(self):
        source = (ROOT / 'src/win16/extctrls.pas').read_text()
        for text in ('TCustomRadioGroup = class(TCustomGroupBox)', 'TRadioGroup = class(TCustomRadioGroup)',
                     'property Columns: Integer read FColumns write SetColumns default 1;',
                     'property ItemIndex: Integer read FItemIndex write SetItemIndex default -1;',
                     'TGroupButton = class(TRadioButton)', 'if FUpdating then Exit;',
                     'ButtonsPerCol := (FButtons.Count + FColumns - 1) div FColumns;'):
            self.assertIn(text, source)

    def test_resource_unit_imports_win31_for_copy_icon(self):
        data = (ROOT / 'src/resource.pas').read_bytes()
        self.assertIn(b'Registry{$IFDEF FPC}, Win31{$ENDIF};\r\n', data)
        self.assertEqual(data.count(b'\n'), data.count(b'\r\n'))

    def test_native_probe_covers_group_box_and_radio_group(self):
        probe = (ROOT / 'tests/pascal/test_win16_radio_group.pas').read_text()
        for text in ('aligned children stay inside the frame and below the caption',
                     'ItemIndex checks a button without OnClick', 'clicking a button selects it with OnClick',
                     'Columns fills each column top to bottom', 'a streamed ItemIndex applies after Items load',
                     'disabling the group disables its buttons'):
            self.assertIn(text, probe)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-radio-group-runtime-test',
                      makefile.split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0])


if __name__ == '__main__':
    unittest.main()
