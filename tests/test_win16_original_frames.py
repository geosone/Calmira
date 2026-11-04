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


if __name__ == '__main__':
    unittest.main()
