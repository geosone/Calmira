"""View action contracts; real USER order/pixels are checked in native probes."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ControlViewTests(unittest.TestCase):
    def test_control_methods_share_one_virtual_policy_hook(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('procedure ChangeView(Action: TControlViewAction); virtual;', source)
        for name, action in (('Show', 'cvaShow'), ('Hide', 'cvaHide'),
                             ('BringToFront', 'cvaFront'), ('SendToBack', 'cvaBack')):
            self.assertIn(f'procedure TCustomControl.{name};\nbegin ChangeView({action}); end;', source)
        form = (ROOT / 'src/win16/native_form.pas').read_text()
        self.assertIn('procedure ChangeView(Action: TControlViewAction); override;', form)
        body = form.split('procedure TNativeForm.ChangeView(', 1)[1].split(
            'procedure TNativeForm.HideWindow;', 1)[0]
        self.assertIn('cvaShow: Show', body)
        self.assertIn('cvaHide: Hide', body)

    def test_native_order_avoids_geometry_tab_order_and_focus_mutation(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('procedure TCustomControl.ChangeView(', 1)[1].split(
            'function TCustomControl.GetWidth:', 1)[0]
        for text in ('HWND_TOP', 'HWND_BOTTOM', 'SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE',
                     'FParent.FChanging', 'FParent.FCompositing', 'FParent.Canvas.Handle',
                     'FChanging := True', 'finally FChanging := False'):
            self.assertIn(text, body)
        order = body.split('cvaFront, cvaBack:', 1)[1]
        for text in ('CreateHandle', 'SetActiveWindow', 'SetFocus', 'FWindows.', 'SetBounds'):
            self.assertNotIn(text, order)

    def test_hide_releases_entire_descendant_input_scope_before_visibility_change(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('procedure TCustomControl.ChangeView(', 1)[1].split(
            'function TCustomControl.GetWidth:', 1)[0]
        for text in ('Current := GetCapture', 'IsChild(Handle, Current) then ReleaseCapture',
                     'Current := GetFocus', 'IsChild(Handle, Current) then WinProcs.SetFocus(0)'):
            self.assertIn(text, body)
        self.assertLess(body.index('ReleaseCapture'), body.index('SetVisible(False)'))
        self.assertLess(body.index('SetFocus(0)'), body.index('SetVisible(False)'))

    def test_form_activation_is_explicit_guarded_and_never_shows_hidden_windows(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        body = source.split('procedure TNativeForm.ChangeView(', 1)[1].split(
            'procedure TNativeForm.HideWindow;', 1)[0]
        for text in ('CheckChanging', '(Handle = 0) or not Visible then Exit',
                     'FChangingForm := True', 'inherited ChangeView(Action)',
                     '(Action = cvaFront) and Enabled then SetActiveWindow(Handle)',
                     'finally FChangingForm := False'):
            self.assertIn(text, body)
        for text in ('WindowState :=', 'CreateHandle(', 'SetFocus('):
            self.assertNotIn(text, body)

    def test_graphic_order_moves_only_the_composition_list_with_paint_guards(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('procedure TGraphicControl.ChangeOrder(', 1)[1].split(
            'procedure TGraphicControl.Update;', 1)[0]
        for text in ('if FParent = nil then Exit', 'FCanvas.Handle <> 0',
                     'FParent.Painting', 'FParent.FCompositing',
                     'FParent.FGraphics.Move(Index, Target); DirtyBounds'):
            self.assertIn(text, body)
        for text in ('CreateHandle', 'SetWindowPos', 'SetFocus', 'FWindows.'):
            self.assertNotIn(text, body)

    def test_native_profiles_cover_lifecycle_screen_order_real_pixels_and_resources(self):
        core = (ROOT / 'tests/pascal/test_win16_control_view.pas').read_text()
        view = (ROOT / 'tests/pascal/test_win16_view_order.pas').read_text()
        for text in ('base control Show Hide preserve form construction and lifecycle events',
                     'parent Hide releases descendant input and rejects exit callback reentry',
                     'z order leaves geometry and logical tab order unchanged',
                     'form raise retains completed activation after callback error',
                     'base control Hide completes modal form'):
            self.assertIn(text, core)
        for text in ('original NextForm policy advances through actual BringToFront method',
                     'graphic BringToFront changes actual overlap pixels',
                     'graphic model order survives parent HWND recreation',
                     'repeated reordering and composition retain GDI USER pools and DC cleanup'):
            self.assertIn(text, view)
        make = (ROOT / 'makefile').read_text()
        for profile, source in (('control-view', core), ('view-order', view)):
            self.assertIn('{$M 4096,2048}', source)
            self.assertIn('Check(StackGuardIntact', source)
            self.assertIn(f'win16-{profile}-runtime-test: win16-{profile}', make)
            self.assertIn(f'check_win16_budget.py $(BUILD_DIR)/tests/win16-{profile}/GDITEST.EXE', make)


if __name__ == '__main__':
    unittest.main()
