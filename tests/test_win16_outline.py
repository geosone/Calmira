"""Outline unit scope and Calmira TScrollTree compatibility guards."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16OutlineTests(unittest.TestCase):
    def test_outline_follows_delphi_interface(self):
        source = (ROOT / 'src/win16/outline.pas').read_text()
        for text in ('TCustomOutline = class(TCustomGrid)', 'TOutline = class(TCustomOutline)',
                     'TOutlineNode = class(TPersistent)', 'InvalidIndex = -1;',
                     'property SelectedItem: LongInt read GetSelectedItem write SetSelectedItem;',
                     "raise EOutlineError.CreateFmt('Invalid outline index %d', [Index]);",
                     '{ As in Delphi, Index is the grid row, not the item index. }',
                     'procedure Expand(Index: LongInt); virtual;'):
            self.assertIn(text, source)
        canvas = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        self.assertIn('property PenPos: TPoint read GetPenPos write SetPenPos;', canvas)

    def test_native_probe_covers_outline_and_scroll_tree(self):
        probe = (ROOT / 'tests/pascal/test_win16_outline.pas').read_text()
        for text in ('items are indexed in pre-order over all nodes', 'child iteration ends with -1',
                     'OnExpand can add the children it shows', 'collapsing moves the selection to the visible parent',
                     'adding lines builds the tree from tabs', 'owner draw gets the grid row as Index',
                     'TScrollTree.GetItemAt only finds cells with an item', 'DottedLineTo ends at the target'):
            self.assertIn(text, probe)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-outline-runtime-test',
                      makefile.split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0])

    def test_form_units_leave_dfm_resources_to_the_loader(self):
        # FPC cannot link resources for Win16; loaders replace {$R *.DFM}.
        for path in sorted(list((ROOT / 'src').glob('*.pas')) + list((ROOT / 'vcl').glob('*.pas'))):
            data = path.read_bytes()
            for line in data.split(b'\n'):
                if re.search(rb'\{\$R \*\.dfm\}', line, re.I):
                    self.assertIn(b'{$IFNDEF FPC}{$R *.dfm}{$ENDIF}', line, path.name)
            if b'{$IFNDEF FPC}{$R *.dfm}{$ENDIF}' in data:
                self.assertEqual(data.count(b'\n'), data.count(b'\r\n'), path.name + ' keeps CRLF line endings')

    def test_delphi_type_aliases_used_by_shell_units(self):
        self.assertIn('TCaption = string[255];', (ROOT / 'src/win16/controls.pas').read_text())
        self.assertIn('TModalResult = Controls.TModalResult;', (ROOT / 'src/win16/forms.pas').read_text())


if __name__ == '__main__':
    unittest.main()
