"""FileCtrl filter combo, bitmap saving, string-table exceptions and shapes."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
WIN31_UNITS = ('about', 'desk', 'deskprop', 'iconwin', 'mydocs', 'opendlg', 'runprog', 'shorts',
               'shutdown', 'task', 'taskman', 'tree')


class Win16FileFilterTests(unittest.TestCase):
    def test_filter_combo_box_parses_delphi_filters(self):
        source = (ROOT / 'src/win16/filectrl.pas').read_text()
        for text in ('TFilterComboBox = class(TCustomComboBox)', "SetFilter('All files (*.*)|*.*');",
                     'if Pattern = \'\' then Pattern := Description;', "Result := '*.*';",
                     'property Mask: string read GetMask;'):
            self.assertIn(text, source)

    def test_bitmap_saves_bottom_up_24_bit_rows(self):
        source = (ROOT / 'src/win16/gdi_bitmap.pas').read_text()
        for text in ('procedure SaveToFile(const FileName: string);', 'procedure FreeImage;',
                     'RowBytes := (LongInt(FWidth) * 3 + 3) and not 3;',
                     'if Deselected then SelectObject(FDC, FHandle);'):
            self.assertIn(text, source)

    def test_shape_and_paint_box_follow_delphi(self):
        source = (ROOT / 'src/win16/extctrls.pas').read_text()
        for text in ('TPaintBox = class(TGraphicControl)', 'TShape = class(TGraphicControl)',
                     'property OnPaint: TNotifyEvent read FOnPaint write FOnPaint;',
                     'property Shape: TShapeType read FShape write SetShape default stRectangle;',
                     'FBrush := TBrush.Create; FBrush.OnChange := StyleChanged;'):
            self.assertIn(text, source)
        canvas = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        self.assertIn('procedure TGDIResource.Changed;', canvas)
        self.assertNotIn('procedure TGDIFont.Changed;', canvas)

    def test_controls_expose_delphi_window_lookups(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('function FindControl(Handle: HWND): TWinControl;', 'function GetCaptureControl: TControl;',
                     'function Showing: Boolean;'):
            self.assertIn(text, source)
        listbox = (ROOT / 'src/win16/native_listbox.pas').read_text()
        self.assertIn('    property DragCursor;\n', listbox)

    def test_calmira_units_import_win31_first(self):
        for name in WIN31_UNITS:
            data = (ROOT / 'src' / (name + '.pas')).read_bytes()
            self.assertIn(b'uses {$IFDEF FPC}Win31, {$ENDIF}', data, name)
            self.assertEqual(data.count(b'\n'), data.count(b'\r\n'), name)
        for name in ('referenc', 'filefind'):
            data = (ROOT / 'src' / (name + '.pas')).read_bytes()
            self.assertIn(b'{$IFDEF FPC}, LangUI{$ENDIF};\r\n', data, name)
        start = (ROOT / 'src/start.pas').read_bytes()
        self.assertIn(b'ShutDown{$IFDEF FPC}, Win31{$ENDIF};', start)
        self.assertEqual(start.count(b'\n'), start.count(b'\r\n'))

    def test_delphi1_rect_overlays_corner_points(self):
        patch = (ROOT / 'tools/patches/fpc-win16-delphi1-types.patch').read_text()
        self.assertIn('+      1: (TopLeft, BottomRight: TPoint);', patch)

    def test_native_probes_cover_the_slice(self):
        probe = (ROOT / 'tests/pascal/test_win16_file_filter.pas').read_text()
        for text in ('Filter pairs descriptions with masks', 'a saved bitmap keeps its pixels and row order',
                     'IsAccel matches the mnemonic character', 'CreateResFmt takes a string-table identifier',
                     'LoadStr reads the module string table'):
            self.assertIn(text, probe)
        self.assertIn('1089, "Cannot copy %s to itself"',
                      (ROOT / 'tests/pascal/test_win16_file_filter.rc').read_text())
        shape = (ROOT / 'tests/pascal/test_win16_shape.pas').read_text()
        for text in ('changing the brush repaints the shape', 'TPaintBox paints through OnPaint',
                     'GetCaptureControl finds the capturing control', 'a hidden parent hides its children'):
            self.assertIn(text, shape)
        regression = (ROOT / 'makefile').read_text().split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0]
        for name in ('win16-file-filter-runtime-test', 'win16-shape-runtime-test'):
            self.assertIn(name, regression)


if __name__ == '__main__':
    unittest.main()
