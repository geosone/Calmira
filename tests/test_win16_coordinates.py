from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CoordinateTests(unittest.TestCase):
    def test_both_control_types_expose_typed_nonvirtual_conversions(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for method in ('ClientToScreen', 'ScreenToClient'):
            self.assertEqual(source.count(
                f'function {method}(const Position: TPoint): TPoint;'), 2)
            for kind in ('TCustomControl', 'TGraphicControl'):
                body = source.split(f'function {kind}.{method}(', 1)[1].split('\nend;', 1)[0]
                self.assertNotIn('CreateControl', body)
                self.assertNotIn('CreateHandle', body)
                self.assertNotIn('SetFocus', body)
                self.assertIn('TranslatePosition', body)

    def test_window_origin_comes_from_user_not_cached_bounds(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for method in ('ClientToScreen', 'ScreenToClient'):
            body = source.split(f'function TCustomControl.{method}(', 1)[1].split('\nend;', 1)[0]
            self.assertIn('(Handle = 0) or not IsWindow(Handle)', body)
            self.assertIn('WinProcs.ClientToScreen(Handle, Origin)', body)
            self.assertNotIn('FLeft', body)
            self.assertNotIn('FTop', body)
        self.assertIn('WinProcs.ScreenToClient(NativeParent, Origin)', source)

    def test_translation_checks_signed_range_before_narrowing(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('function TranslatePosition(', 1)[1].split('\nend;', 1)[0]
        for text in ('X, Y: LongInt', 'LongInt(Position.X)', 'LongInt(Position.Y)',
                     'X < -32768', 'X > 32767', 'Y < -32768', 'Y > 32767'):
            self.assertIn(text, body)
        self.assertLess(body.index('raise ENativeWindowError'), body.index('Result.X := X'))

    def test_graphic_bounds_use_wide_validation_and_existing_virtual_mutator(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('procedure TGraphicControl.SetBoundsRect(', 1)[1].split('\nend;', 1)[0]
        for text in ('W, H: LongInt', 'LongInt(Value.Right) - Value.Left',
                     'LongInt(Value.Bottom) - Value.Top', 'W > 32767', 'H > 32767',
                     'SetBounds(Value.Left, Value.Top, W, H)'):
            self.assertIn(text, body)

    def test_native_fixture_and_acceptance_wiring(self):
        source = (ROOT / 'tests/pascal/test_win16_coordinates.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'actual USER client origin', 'external native move',
                     'native reparent conversion', 'windowless conversion',
                     'positive coordinate overflow', 'negative inverse coordinate overflow',
                     'BoundsRect retains graphic paint mutation guard',
                     'destroyed parent has no stale coordinate mapping',
                     'parent HWND recreation'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        aggregate = make.split('win16-fixed-regression: fpc-win16-fixed-compiler', 1)[1].split(
            '\nwin16-class-pointer:', 1)[0]
        self.assertIn('win16-coordinates-runtime-test', aggregate)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-coordinates/GDITEST.EXE', make)


if __name__ == '__main__':
    unittest.main()
