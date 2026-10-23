"""Source scope guards; window pixels and USER/GDI lifetimes need Win3.1x."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16PaintTests(unittest.TestCase):
    def test_native_paint_balances_borrowed_dc_even_on_error(self):
        source = (ROOT / 'src/win16/native_paint.pas').read_text()
        for text in ('DC := BeginPaint(Window, PS)', 'finally EndPaint(Window, PS)',
                     'FCanvas.Handle := DC', 'FCanvas.Handle := PreviousDC',
                     'RestoreDC(DC, State)', 'FPainting := False',
                     'FillChar(FPaintRect, SizeOf(FPaintRect), 0)'):
            self.assertIn(text, source)
        paint = source.split('procedure TNativePaintWindow.WMPaint', 1)[1].split(
            'procedure TNativePaintWindow.Invalidate;', 1)[0]
        self.assertNotIn('GetDC(', paint)
        self.assertNotIn('DeleteDC(', source)
        self.assertLess(source.index('if FPainting then Exit'), source.index('BeginPaint(Window, PS)'))

    def test_background_fill_preserves_user_brush_and_native_clip(self):
        source = (ROOT / 'src/win16/native_paint.pas').read_text()
        for text in ('FPaintRect := PS.rcPaint', 'CreateSolidBrush(ColorToRGB(FColor))',
                     'WinProcs.FillRect(DC, FPaintRect, Background)',
                     'finally DeleteObject(Background)', 'message WM_ERASEBKGND'):
            self.assertIn(text, source)
        self.assertNotIn('FCanvas.Brush.Color :=', source)
        self.assertNotIn('SelectClipRgn', source)

    def test_native_probe_covers_pixels_clipping_exception_and_reentry(self):
        source = (ROOT / 'tests/pascal/test_win16_paint.pas').read_text()
        for text in ('native paint fills configured background',
                     'partial update clips drawing without replacing outside pixels',
                     'disjoint update regions preserve pixels inside their bounding gap',
                     'nested WM_PAINT does not replace active canvas or recurse',
                     'paint exception still detaches canvas and ends native paint',
                     'drawing outside paint is rejected', 'window remains drawable after paint exception',
                     'GFSR_GDIRESOURCES', 'GFSR_USERRESOURCES'):
            self.assertIn(text, source)

    def test_invalidation_is_bounded_and_framework_scope_is_explicit(self):
        source = (ROOT / 'src/win16/native_paint.pas').read_text()
        for text in ('unit native_paint;', 'TNativePaintWindow = class(TNativeWindow)',
                     'LongInt(Area.Right) - Area.Left', 'if (W = 0) or (H = 0) then Exit',
                     "ENativeWindowError.Create('Missing native window')"):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-paint: fpc-win16-gui-rtl', makefile)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-paint/GDITEST.EXE', makefile)
