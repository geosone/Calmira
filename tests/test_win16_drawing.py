"""Native drawing feature scope and original-consumer compatibility guards."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16DrawingTests(unittest.TestCase):
    def test_stretch_dispatch_uses_snapshot_and_explicit_scaling_limits(self):
        canvas = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        bitmap = (ROOT / 'src/win16/gdi_bitmap.pas').read_text()
        probe = (ROOT / 'tests/pascal/test_win16_drawing.pas').read_text()
        for text in ('procedure StretchDraw(const Area: TRect; Graphic: TGDIGraphic)',
                     'Graphic.StretchTo(FHandle, Area)', 'Scaling is not supported for this graphic',
                     'LongInt(Area.Right) - Area.Left', 'Graphic.Empty then Exit'):
            self.assertIn(text, canvas)
        for text in ('if Destination = FDC then', 'Snapshot.Assign(Self)',
                     'finally Snapshot.Free', 'SetStretchBltMode(Destination, COLORONCOLOR)',
                     'finally RestoreDC(Destination, State)'):
            self.assertIn(text, bitmap)
        for text in ('wallpaper self-shrink snapshots pixels',
                     'overlapping self-stretch reads an immutable source snapshot',
                     'transparent self-stretch snapshots source and destination background',
                     'StretchDraw retains caller clipping', 'mirrored stretch is rejected',
                     'empty stretch targets and graphics emit no event'):
            self.assertIn(text, probe)

    def test_public_brush_factory_and_bitmap_snapshot_setter(self):
        source = (ROOT / 'src/win16/graphics.pas').read_text()
        for text in ('TBrush = class(TGDIBrush)', 'property Bitmap: TBitmap write SetBitmap',
                     'function TCanvas.CreateBrush: TGDIBrush', 'Result := TBrush.Create',
                     'property Brush: TBrush read GetBrush write SetBrush'):
            self.assertIn(text, source)
        self.assertIn('Brush.Bitmap := Pattern', (ROOT / 'vcl/slider.pas').read_text())

    def test_native_probe_checks_pattern_lifetimes_and_drawing_pixels(self):
        source = (ROOT / 'tests/pascal/test_win16_drawing.pas').read_text()
        for text in ('Pattern.Free; Pattern := nil', '8 by 8 checkerboard tiles',
                     'same-color assignment exits pattern mode', 'Brush.Assign(Canvas.Brush)',
                     'Canvas.RefreshSystemColors', 'invalid pattern size preserves cached brush',
                     'TextRect clips glyphs', 'drawing focus rectangle twice restores original pixels',
                     'border flood fill respects red boundary', 'surface flood fill replaces only connected',
                     'full-circle Pie supports disk-usage chart drawing', 'GFSR_GDIRESOURCES'):
            self.assertIn(text, source)

    def test_native_focus_api_is_void_and_canvas_dc_is_borrowed(self):
        source = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        self.assertIn('WinProcs.DrawFocusRect(FHandle, @Area);', source)
        self.assertNotIn('if not WinProcs.DrawFocusRect', source)
        self.assertNotIn('DeleteDC(FHandle)', source)
        self.assertIn('CreatePatternBrush(FPattern)', source)
        self.assertIn('SelectObject(Temp, Previous); DeleteDC(Temp)', source)

    def test_fill_enum_exports_and_native_order(self):
        core = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        facade = (ROOT / 'src/win16/graphics.pas').read_text()
        self.assertIn('TFillStyle = (fsBorder, fsSurface)', core)
        self.assertIn('ExtFloodFill(FHandle, X, Y, ColorToRGB(Color), Ord(FillStyle))', core)
        self.assertIn('fsBorder = gdi_canvas.fsBorder; fsSurface = gdi_canvas.fsSurface', facade)
