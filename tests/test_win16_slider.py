"""Original-slider port scope and conditional compatibility guards."""
from pathlib import Path
import unittest

from test_win16_handles import active_source

ROOT = Path(__file__).resolve().parents[1]


class Win16SliderTests(unittest.TestCase):
    def test_controls_subset_has_real_window_bounds_visibility_and_enable(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('TCustomControl = class(TNativeInputWindow)',
                     'procedure CreateControl(ParentWindow: HWND)', 'GetClientRect(Handle, Area)',
                     'SetWindowPos(Handle', 'EnableWindow(Handle, Value)',
                     'ShowWindow(Handle, SW_SHOWNOACTIVATE)',
                     'if Handle <> 0 then inherited Invalidate',
                     'function PtInRect(const Area: TRect; const Position: TPoint)',
                     'Position.X < Area.Right', 'Position.Y < Area.Bottom'):
            self.assertIn(text, source)
        self.assertNotIn('TGraphicControl = class(TCustomControl)', source)

    def test_fpc_port_uses_scopes_capture_and_geometry_guards(self):
        source = active_source('vcl/slider.pas')
        for text in ('DrawNow(DrawThumbNow)', 'MouseCapture := True',
                     'MouseCapture := False', 'Capture and not MouseCapture',
                     'finally SelectObject(MemDC, OldBmp)', 'FBackingDirty',
                     'if FBackingDirty then Repaint', 'GetClipBox(Canvas.Handle, Clip)',
                     'LongInt(fMax) - avalue > 32767', 'Height <= ThumbHeight',
                     'PatternBackground <> ThumbColor', 'SetWideValue',
                     'LongInt(CapturePoint.Y) - Y'):
            self.assertIn(text, source)
        self.assertNotIn('TCMFocusChanged', source)
        for unsupported in ('property OnDragDrop;', 'property TabOrder;', 'property OnClick;'):
            self.assertNotIn(unsupported, source)

    def test_classic_delphi_branch_keeps_original_properties_and_focus_protocol(self):
        source = active_source('vcl/slider.pas', False)
        self.assertIn('TCMFocusChanged', source)
        self.assertIn('property OnDragDrop;', source)
        self.assertIn('property TabOrder;', source)
        self.assertNotIn('DrawNow(', source)
        self.assertNotIn('MouseCapture :=', source)

    def test_native_probe_compiles_real_component_and_checks_behavior(self):
        source = (ROOT / 'tests/pascal/test_win16_slider.pas').read_text()
        for text in ('Controls, Slider;', 'S := TSlider.Create(nil)',
                     'original vertical slider paints actual thumb',
                     'Value setter moves thumb outside Paint', 'thumb drag acquires real focus',
                     'original drag arithmetic updates value', 'focus loss redraws solid thumb',
                     'capture stolen by peer cancels stale internal slider drag',
                     'orientation change recreates horizontal thumb backing',
                     'zero slider range is rejected before division', 'GFSR_GDIRESOURCES',
                     'partial paint invalidates thumb cache', 'extreme signed drag clamps'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-slider: fpc-win16-gui-rtl', makefile)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-slider/GDITEST.EXE', makefile)
