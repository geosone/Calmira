"""Guard immediate-draw scope ownership; native pixels need Win3.1x."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16DrawTests(unittest.TestCase):
    def test_immediate_scope_only_releases_its_own_getdc(self):
        source = (ROOT / 'src/win16/native_paint.pas').read_text()
        draw = source.split('procedure TNativePaintWindow.DrawNow', 1)[1]
        for text in ('if not Assigned(Painter)', 'if Window = 0 then',
                     'PreviousDC := FCanvas.Handle', 'Acquired := DC = 0',
                     'if Acquired then DC := GetDC(Window)', 'State := SaveDC(DC)',
                     'Painter(Self)', 'FCanvas.Handle := PreviousDC',
                     'RestoreDC(DC, State)', 'if Acquired then ReleaseDC(Window, DC)'):
            self.assertIn(text, draw)
        self.assertNotIn('DeleteDC(', draw)
        self.assertNotIn('BeginPaint(', draw)
        self.assertNotIn('ValidateRect(', draw)

    def test_reentrant_paint_preserves_outer_binding(self):
        source = (ROOT / 'src/win16/native_paint.pas').read_text()
        paint = source.split('procedure TNativePaintWindow.WMPaint', 1)[1].split(
            'procedure TNativePaintWindow.Invalidate;', 1)[0]
        self.assertIn('PreviousDC := FCanvas.Handle', paint)
        self.assertIn('FCanvas.Handle := PreviousDC', paint)
        self.assertIn('finally EndPaint(Window, PS)', paint)

    def test_native_probe_covers_clipping_reentry_failure_and_mouse_draw(self):
        source = (ROOT / 'tests/pascal/test_win16_draw.pas').read_text()
        for text in ('DrawNow draws actual pixels outside paint',
                     'nested drawing reuses canvas and restores native DC state',
                     'reentrant WM_PAINT restores outer drawing DC',
                     'DrawNow inside Paint retains native update clipping',
                     'immediate drawing does not validate pending update regions',
                     'direct drawing exception propagates after DC cleanup',
                     'drawing from mouse callback uses native exception containment',
                     'GFSR_GDIRESOURCES', 'GFSR_USERRESOURCES'):
            self.assertIn(text, source)
