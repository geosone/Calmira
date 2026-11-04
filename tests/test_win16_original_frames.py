"""Guards for details measured against the original Calmira Reborn windows."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIN16 = ROOT / 'src/win16'


def source(name):
    return (WIN16 / name).read_text(encoding='cp1252').replace('\r\n', '\n')


class OriginalFrameTests(unittest.TestCase):
    def test_monochrome_glyphs_take_font_and_brush_colours(self):
        # Calmira's caption buttons are monochrome bitmaps drawn with Draw.
        canvas = source('gdi_canvas.pas')
        self.assertIn('SetBkColor(DC, ColorToRGB(FBrush.Color));', canvas)
        self.assertEqual(canvas.count('    DrawColors;\n'), 2)

    def test_header_has_delphis_single_border(self):
        header = source('native_header.pas')
        self.assertIn('property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;',
                      header)
        self.assertIn('if FBorderStyle = bsSingle then Style := Style or WS_BORDER;', header)
        self.assertIn('InflateRect(R, -3, 0);', header)

    def test_grids_get_the_ctl3d_frame(self):
        self.assertIn('function TCustomGrid.Ctl3DFramed: Boolean;\nbegin Result := True; end;', source('grids.pas'))

    def test_latched_speed_buttons_match_the_original_toolbar(self):
        button = source('native_speedbutton.pas')
        self.assertIn('DitherFace(DC, Graphics.Rect(R.Left, R.Top, R.Right + 1, R.Bottom + 1));', button)
        self.assertIn('Shift := Ord(FState = bsDown);', button)

    def test_forms_are_overlapped_and_owned(self):
        # Measured: forms $16CF0000 owned by TApplication $940A0000.
        modal = source('native_modal.pas')
        self.assertNotIn('WS_POPUP', modal)
        self.assertIn('GetWindow(Handle, GW_OWNER)', modal)
        app = source('native_application_window.pas')
        self.assertIn('WS_POPUP or WS_CLIPSIBLINGS or WS_SYSMENU or WS_MINIMIZEBOX', app)

    def test_pop_up_hints_are_on_by_default_below_their_control(self):
        forms = source('forms.pas')
        self.assertIn('  { As Delphi 1\'s TApplication.Create. Calmira never turns pop-up hints on,\n'
                      '    yet the original shows its file and toolbar hints. }\n  ShowHint := True;', forms)
        self.assertIn('Info.HintPos := ControlToScreen(Control, Point(0, ControlHeight(Control) + 6));', forms)

    def test_input_query_matches_the_original_change_description(self):
        dialogs = source('dialogs.pas')
        self.assertIn('QueryWidth = 270; QueryHeight = 95; QueryLeft = MsgMargin; PromptTop = MsgMargin;', dialogs)
        self.assertIn('EditTop = 28; EditWidth = 250; EditHeight = 20; QueryButtonTop = 58; QueryGap = 10;',
                      dialogs)
        self.assertIn('QueryButtonWidth = 77; QueryButtonHeight = 27;', dialogs)
        buttons = source('buttons.pas')
        self.assertIn('if Active then TextFont.Style := TextFont.Style + [fsBold]\n'
                      '  else TextFont.Style := TextFont.Style - [fsBold];', buttons)

    def test_focus_rectangles_take_the_canvas_colours(self):
        canvas = source('gdi_canvas.pas')
        self.assertIn('SetTextColor(DC, ColorToRGB(FFont.Color));', canvas)
        self.assertNotIn('SetTextColor(DC, 0); SetBkColor(DC, $FFFFFF);', canvas)
        self.assertIn('if FBrush.Style = bsClear then SetBkColor(DC, $FFFFFF)\n'
                      '    else SetBkColor(DC, ColorToRGB(FBrush.Color));', canvas)

    def test_grid_keeps_its_focused_cell_while_its_form_is_inactive(self):
        grids = source('grids.pas')
        self.assertIn('Current := GridIsActive(Self);', grids)
        self.assertIn('if Current and (CurRow = Row) and (CurCol = Col) then Include(State, gdFocused);', grids)
        self.assertIn('else Result := (FLastFocus <> 0) and (FLastFocus = Control.Handle);',
                      source('native_form.pas'))

    def test_message_buttons_sit_eight_pixels_apart(self):
        self.assertIn('Margin = 12; IconSize = 32; ButtonGap = 8;', source('dialogs.pas'))


if __name__ == '__main__':
    unittest.main()
