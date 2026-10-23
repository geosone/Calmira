"""Scope guards for true graphic children and the original pie-chart port."""
from pathlib import Path
import unittest

from test_win16_handles import active_source

ROOT = Path(__file__).resolve().parents[1]


class Win16GraphicTests(unittest.TestCase):
    def test_enabled_state_is_local_guarded_and_mnemonic_dispatch_checks_it(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('property Enabled: Boolean read FEnabled write SetEnabled', source)
        self.assertIn('Graphic.Visible and Graphic.Enabled', source)
        setter = source.split('procedure TGraphicControl.SetEnabled', 1)[1].split('procedure ', 1)[0]
        self.assertLess(setter.index('if Value = FEnabled then Exit'), setter.index('FCanvas.Handle <> 0'))
        self.assertLess(setter.index('raise ENativeWindowError'), setter.index('FEnabled := Value'))
        self.assertIn('FParent.FCompositing', setter)
        self.assertIn('FEnabled := Value; Invalidate', setter)
        self.assertNotIn('EnableWindow(', setter)
        probe = (ROOT / 'tests/pascal/test_win16_graphic.pas').read_text()
        for text in ('enabled mutation during graphic paint is rejected',
                     'disabled graphic still paints', 'graphic enabled state survives reparenting',
                     'Check(StackGuardIntact'):
            self.assertIn(text, probe)

    def test_graphic_control_is_not_a_windowed_alias(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        graphic = source.split('TGraphicControl = class(TControl)', 1)[1].split('const\n', 1)[0]
        self.assertIn('property Parent: TCustomControl', graphic)
        self.assertIn('property Canvas: TCanvas', graphic)
        self.assertNotIn('property Handle:', graphic)
        self.assertNotIn('TGraphicControl = class(TCustomControl)', source)

    def test_compositor_preserves_dc_and_intersects_native_clip(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        paint = source.split('procedure TGraphicControl.PaintOn', 1)[1]
        for text in ('State := SaveDC(DC)', 'OffsetViewportOrg(DC, FLeft, FTop)',
                     'IntersectClipRect(DC, 0, 0, FWidth, FHeight)',
                     'if Clip = NULLREGION then Exit', 'FCanvas.Handle := Surface.Canvas.Handle',
                     'finally FCanvas.Handle := 0', 'finally RestoreDC(DC, State)',
                     'Surface.SetSize(FWidth, FHeight)', 'finally Surface.Free',
                     'Surface.Canvas.Handle, 0, 0, SRCCOPY'):
            self.assertIn(text, paint)
        self.assertNotIn('GetDC(', paint)
        self.assertNotIn('DeleteDC(', paint)
        native = (ROOT / 'src/win16/native_paint.pas').read_text()
        self.assertIn('Paint;\n        PaintOverlay;', native)
        self.assertIn('if Acquired and not FPainting then PaintOverlay', native)

    def test_lifetime_and_bounds_have_real_checks(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('Value.FGraphics.Add(Self)', 'Previous.FGraphics.Remove(Self)',
                     "ENativeWindowError.Create('Cannot reparent during paint')",
                     'LongInt(X) + AWidth > 32767', 'DirtyBounds; FLeft := X',
                     'FGraphics[FGraphics.Count - 1]).Parent := nil',
                     'FParent.FCompositing', 'finally FCompositing := False',
                     "ENativeWindowError.Create('Cannot resize during graphic paint')"):
            self.assertIn(text, source)

    def test_original_pie_keeps_delphi_path_and_uses_scoped_fpc_paint(self):
        fpc = active_source('vcl/win95pie.pas')
        old = active_source('vcl/win95pie.pas', False)
        self.assertIn('TWin95PieChart = class(TGraphicControl)', fpc)
        self.assertIn('Canvas.Handle = 0 then begin Invalidate; Exit', fpc)
        self.assertIn('if FValue > FMaximum then FValue := FMaximum', fpc)
        self.assertNotIn('property Align;', fpc)
        self.assertIn('property Align;', old)
        self.assertNotIn('Canvas.Handle = 0', old)
        self.assertIn('Sin((Angle * Pi) / 180)', fpc)
        probe = (ROOT / 'tests/pascal/test_win16_graphic.pas').read_text()
        for text in ('allocate no native child HWNDs', 'original zero-used pie',
                     'partial parent update clip', 'reparenting removes old graphic',
                     'parent destruction detaches independently owned graphics',
                     'graphic paint exception detaches child and parent canvases'):
            self.assertIn(text, probe)
        self.assertIn('partial pie shadow repaint matches full-render flood-fill pixels', probe)
