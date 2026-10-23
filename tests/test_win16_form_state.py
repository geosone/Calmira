"""Win16 state/placement contract guards; native probes establish USER behavior."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FormStateTests(unittest.TestCase):
    def test_live_state_uses_task_local_user_flags_and_hidden_state_is_deferred(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        for text in ('TWindowState = (wsNormal, wsMinimized, wsMaximized)',
                     'GetWindowTask(Handle) <> GetCurrentTask', 'IsIconic(Handle)', 'IsZoomed(Handle)',
                     '(Handle <> 0) and not FPendingState',
                     'if (Handle = 0) or not Visible then',
                     'FWindowState := Value; FPendingState := True; Exit'):
            self.assertIn(text, source)
        show = source.split('procedure TNativeForm.Show;', 1)[1].split(
            'procedure TNativeForm.HideWindow;', 1)[0]
        self.assertLess(show.index('Requested := GetWindowState'), show.index('CreateHandle('))
        self.assertLess(show.index('FPendingState := False'), show.index('Visible := True'))
        self.assertLess(show.index('ApplyWindowState(Requested)'), show.index('DoShow;'))

    def test_state_commands_preserve_normal_semantics_and_callback_guards(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        for text in ('wsNormal: Command := SW_SHOWNORMAL', 'wsMinimized: Command := SW_MINIMIZE',
                     'wsMaximized: Command := SW_SHOWMAXIMIZED',
                     'ShowWindow(Handle, Command); FWindowState := ReadWindowState',
                     'if FWindowState <> Value then raise', 'Ord(Value) > Ord(wsMaximized)',
                     'try ApplyWindowState(Value); finally FChangingState := False',
                     'if ReadWindowState <> wsNormal then raise'):
            self.assertIn(text, source)
        self.assertNotIn('Command := SW_RESTORE', source)

    def test_teardown_preserves_native_normal_placement_in_model_only(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        body = source.split('procedure TNativeForm.WMNCDestroy(', 1)[1].split(
            'function TNativeForm.ReadWindowState:', 1)[0]
        for text in ('FWindowState := GetWindowState; FPendingState := True',
                     'FillChar(Placement, SizeOf(Placement), 0)', 'Placement.length := SizeOf(Placement)',
                     'GetWindowPlacement(Handle, @Placement)', 'inherited WMNCDestroy(M)',
                     'finally', 'StoreBounds(Placement.rcNormalPosition)', 'if not Valid then raise'):
            self.assertIn(text, body)
        self.assertLess(body.index('GetWindowPlacement'), body.index('inherited WMNCDestroy'))
        self.assertLess(body.index('inherited WMNCDestroy'), body.index('StoreBounds'))
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        store = controls.split('procedure TCustomControl.StoreBounds(', 1)[1].split('end;', 1)[0]
        for text in ('FLeft := Area.Left', 'FTop := Area.Top',
                     'FWidth := Area.Right - Area.Left', 'FHeight := Area.Bottom - Area.Top'):
            self.assertIn(text, store)
        for text in ('SetWindowPos', 'SetBounds(', 'CreateHandle', 'ShowWindow'):
            self.assertNotIn(text, store)

    def test_minimized_forms_do_not_focus_children_or_route_dialog_keys(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        routing = source.split('function TNativeForm.ProcessDialogMessage(', 1)[1].split(
            'constructor TNativeForm.Create(', 1)[0]
        self.assertIn('if WindowState = wsMinimized then Exit', routing)
        self.assertIn('if not Active or (WindowState = wsMinimized) then Exit', source)
        self.assertIn('FChangingActiveControl or not Active or (WindowState = wsMinimized)', source)
        show = source.split('procedure TNativeForm.DoShow;', 1)[1].split('procedure ', 1)[0]
        self.assertLess(show.index('WindowState <> wsMinimized'), show.index('FInitialControl.SetFocus'))
        modal = (ROOT / 'src/win16/native_modal.pas').read_text()
        self.assertIn('if not IsIconic(Handle) and (FindControl(GetFocus) = nil)', modal)

    def test_native_profile_checks_state_placement_modal_and_recreation(self):
        source = (ROOT / 'tests/pascal/test_win16_form_state.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'deferred minimized state allocates no HWND',
                     'getter observes external native maximize',
                     'native restore-to-maximized policy remains USER-owned',
                     'nonnormal bounds assignment cannot corrupt restore placement',
                     'hidden state assignment is deferred without showing HWND',
                     'minimized teardown retains state and normal bounds rather than icon geometry',
                     'normal placement survives close destroy recreate',
                     'minimized modal does not focus descendant',
                     'state modal restores owner focus and enable state',
                     'state cycles retain USER and GDI resources'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-form-state-runtime-test: win16-form-state', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-form-state/GDITEST.EXE', make)


if __name__ == '__main__':
    unittest.main()
