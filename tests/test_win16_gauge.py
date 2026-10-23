"""Original gauge port scope guards; drawing acceptance runs under Win3.11."""
from pathlib import Path
import unittest

from test_win16_handles import active_source

ROOT = Path(__file__).resolve().parents[1]


class Win16GaugeTests(unittest.TestCase):
    def test_original_classes_build_without_empty_framework_shims(self):
        fpc = active_source('vcl/bargauge.pas')
        old = active_source('vcl/bargauge.pas', False)
        for text in ('TAbstractBar = class(TGraphicControl)',
                     'TBarGauge = class(TAbstractBar)', 'TWin95Gauge = class(TAbstractBar)',
                     'MulDiv(', 'TextRect(r, x, y, S)'):
            self.assertIn(text, fpc)
        for unit in ('Forms', 'Dialogs', 'StdCtrls', 'ExtCtrls'):
            self.assertNotIn(unit, fpc)
            self.assertIn(unit, old)
        for property_name in ('Align', 'ParentShowHint', 'ShowHint', 'Enabled', 'Font', 'ParentFont'):
            self.assertNotIn('property ' + property_name + ';', fpc)
            self.assertIn('property ' + property_name + ';', old)
        self.assertIn('Font.Assign(Self.Font)', old)

    def test_range_arithmetic_and_backgrounds_are_safe(self):
        fpc = active_source('vcl/bargauge.pas')
        for text in ('Double(FCurValue) - Double(FMinValue)',
                     'Double(FMaxValue) - Double(FMinValue)',
                     'Next := Int64(FCurValue) + Value',
                     'if Next > FMaxValue then Next := FMaxValue',
                     'if Next < FMinValue then Next := FMinValue',
                     'if Value > FMaxValue then raise ERangeError',
                     'if Value < FMinValue then raise ERangeError',
                     'else Slots := (Height - 3) div 10',
                     'LongInt(GetPercentDone) * Slots',
                     'if X < 3 then Exit', 'Canvas.Brush.Style := bsSolid'):
            self.assertIn(text, fpc)
        self.assertNotIn('for i := 0 to GetSegments', fpc)
        self.assertIn('for i := 0 to GetSegments', active_source('vcl/bargauge.pas', False))
        self.assertIn('procedure SetBounds(X, Y, AWidth, AHeight: Integer); virtual;',
                      (ROOT / 'src/win16/controls.pas').read_text())

    def test_native_probe_checks_pixels_text_ranges_and_resource_lifetime(self):
        source = (ROOT / 'tests/pascal/test_win16_gauge.pas').read_text()
        for text in ('zero vertical progress draws no spurious first segment',
                     'vertical segment count follows height rather than width',
                     'decreasing progress erases old segments',
                     'original percent text renders through actual native font drawing',
                     'paint restores solid brush after previous transparent text drawing',
                     'full signed 32-bit range computes percent',
                     'positive progress addition saturates',
                     'base width property dispatches original gauge sizing override',
                     'thin full-progress gauge skips inverted segment interior',
                     'zero-size gauge invalidates old bounds without drawing a surface',
                     'gauge redraw cycles retain GDI and USER resources'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-gauge: fpc-win16-gui-rtl', makefile)
        self.assertIn('win16-gauge-runtime-test: win16-gauge', makefile)
