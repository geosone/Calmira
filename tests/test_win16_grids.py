"""Native Grids unit scope and Calmira TMultiGrid compatibility guards."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16GridsTests(unittest.TestCase):
    def test_grid_classes_follow_delphi_interface(self):
        source = (ROOT / 'src/win16/grids.pas').read_text()
        for text in ('TCustomGrid = class(TCustomControl)', 'TDrawGrid = class(TCustomGrid)',
                     'TStringGrid = class(TDrawGrid)', 'TGridLineStrings = class(TStrings)',
                     'EInvalidGridOperation'):
            self.assertIn(text, source)
        self.assertIn('TScrollStyle = (ssNone, ssHorizontal, ssVertical, ssBoth);',
                      (ROOT / 'src/win16/native_memo.pas').read_text())
        self.assertIn('TScrollStyle = native_memo.TScrollStyle;', (ROOT / 'src/win16/stdctrls.pas').read_text())

    def test_unsupported_features_raise_instead_of_silently_failing(self):
        source = (ROOT / 'src/win16/grids.pas').read_text()
        self.assertIn('Grid editing, tabbing, sizing and moving are not supported', source)
        self.assertIn('Grid rows and columns have a fixed size', source)

    def test_native_probe_covers_drawing_input_and_multigrid(self):
        probe = (ROOT / 'tests/pascal/test_win16_grids.pas').read_text()
        for text in ('MouseToCell finds the cell under a point', 'fixed grid lines are black',
                     'OnSelectCell can refuse a cell', 'SB_THUMBPOSITION moves to the thumb',
                     'unsupported options raise', 'goRowSelect selects whole rows',
                     'rows have a fixed length', "Calmira''s TMultiGrid sizes itself",
                     'SetSize keeps the selection', 'DropFocus draws outside paint'):
            self.assertIn(text, probe)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-grids-runtime-test',
                      makefile.split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0])


if __name__ == '__main__':
    unittest.main()
