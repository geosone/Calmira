"""Resize scope guards; native probes verify USER/client geometry and callbacks."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FormResizeTests(unittest.TestCase):
    def test_client_metrics_use_existing_rect_query_without_handle_creation(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for name, expression in (('Width', 'Area.Right - Area.Left'),
                                 ('Height', 'Area.Bottom - Area.Top')):
            self.assertIn(f'property Client{name}: Integer read GetClient{name}', source)
            body = source.split(f'function TCustomControl.GetClient{name}:', 1)[1].split('end;', 1)[0]
            self.assertIn('Area := GetClientRect', body)
            self.assertIn(expression, body)
            self.assertNotIn('CreateHandle', body)

    def test_native_resize_uses_actual_client_rect_and_commits_before_notification(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        body = source.split('procedure TNativeForm.WMSize(', 1)[1].split(
            'procedure TNativeForm.WMNCDestroy(', 1)[0]
        for text in ('inherited WMSize(M)', 'WinProcs.GetClientRect(Handle, Area)',
                     '(W = FResizeWidth) and (H = FResizeHeight)',
                     'FResizeWidth := W; FResizeHeight := H',
                     'if FResizing then Exit', 'FResizing := True',
                     'try Resize; finally FResizing := False'):
            self.assertIn(text, body)
        self.assertLess(body.index('inherited WMSize(M)'), body.index('GetClientRect'))
        self.assertLess(body.index('FResizeWidth := W'), body.index('try Resize'))
        self.assertNotIn('M.LParam', body)
        self.assertNotIn('M.WParam', body)

    def test_virtual_bounds_dispatch_and_teardown_keep_resize_guard_effective(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('procedure SetBounds(X, Y, AWidth, AHeight: Integer); virtual;', controls)
        self.assertIn('procedure SetBounds(X, Y, AWidth, AHeight: Integer); override;', source)
        bounds = source.split('procedure TNativeForm.SetBounds(', 1)[1].split(
            'procedure TNativeForm.Resize;', 1)[0]
        self.assertLess(bounds.index('if FResizing or FChangingState then raise'), bounds.index('inherited SetBounds'))
        self.assertIn('or FResizing or FChangingState then', source)
        teardown = source.split('procedure TNativeForm.WMNCDestroy(', 1)[1].split(
            'function TNativeForm.ReadWindowState:', 1)[0]
        self.assertIn('finally', teardown)
        self.assertIn('FResizeWidth := -1; FResizeHeight := -1', teardown)
        self.assertIn('procedure Resize; virtual;', source)
        self.assertIn('FOnResize(Self)', source)

    def test_native_fixture_preserves_checks_for_layout_failure_modal_and_recreation(self):
        source = (ROOT / 'tests/pascal/test_win16_form_resize.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'virtual Resize before OnShow', 'arranges nested controls',
                     'forged size produce no resize event',
                     'resize rejects own bounds and lifecycle reentry before mutation',
                     'explicit virtual Resize remains available',
                     'native resize exception preserves completed geometry',
                     'hidden native resize does not show form',
                     'recreated HWND resets resize baseline',
                     'modal native resize updates child layout',
                     'resize cycles retain USER and GDI resources'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-form-resize-runtime-test: win16-form-resize', make)
        self.assertIn('tests/win16-form-resize/units', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-form-resize/GDITEST.EXE', make)


if __name__ == '__main__':
    unittest.main()
