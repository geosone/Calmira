"""Application activation scope guards; native tests use a second visible task."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ApplicationActivationTests(unittest.TestCase):
    def test_active_is_native_task_state_not_main_form_or_notification_cache(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        body = source.split('function TNativeApplication.GetActive:', 1)[1].split(
            'procedure TNativeApplication.WindowActivation(', 1)[0]
        for text in ('CheckReady', 'Window := GetActiveWindow', 'IsWindow(Window)',
                     'GetWindowTask(Window) = FTask'):
            self.assertIn(text, body)
        for text in ('FMainForm', 'FWindow.Handle', 'EnsureHandle', 'GetHandle;', 'FActive'):
            self.assertNotIn(text, body)
        self.assertNotIn('FActive:', source)

    def test_registration_is_opt_in_and_guarded_across_all_window_dispatch(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        for name in ('Activate', 'Deactivate'):
            setter = source.split(f'procedure TNativeApplication.SetOn{name}(', 1)[1].split('end;', 1)[0]
            self.assertIn('CheckEventMutable', setter)
            self.assertIn('if Assigned(Value) then GetHandle', setter)
            self.assertLess(setter.index('CheckEventMutable'), setter.index('GetHandle'))
        guard = source.split('procedure TNativeApplication.CheckEventMutable;', 1)[1].split('end;', 1)[0]
        self.assertIn('CheckReady', guard)
        self.assertIn('if FWindow.Dispatching then raise', guard)
        self.assertIn('FWindow.OnActivation := WindowActivation', source)

    def test_default_and_hooks_precede_event_inside_native_dispatch_guard(self):
        source = (ROOT / 'src/win16/native_application_window.pas').read_text()
        body = source.split('procedure TNativeApplicationWindow.WndProc(', 1)[1].split(
            'destructor TNativeApplicationWindow.Destroy;', 1)[0]
        self.assertLess(body.index('if PWindowHook(FHooks[Index])^(Message) then Exit'),
                        body.index('FOnActivation(Self, Message.WParam <> 0)'))
        default = body.rindex('inherited WndProc(Message)')
        self.assertLess(default, body.index('(Message.Msg = WM_ACTIVATEAPP)'))
        self.assertIn('finally Dec(FDispatchDepth)', body)
        self.assertNotIn('except', body)
        self.assertIn('begin CheckMutable; FOnActivation := Value; end', source)

    def test_application_is_event_sender_and_teardown_suppresses_notifications(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        body = source.split('procedure TNativeApplication.WindowActivation(', 1)[1].split(
            'procedure TNativeApplication.Initialize;', 1)[0]
        for text in ('if FShuttingDown then Exit', 'FOnActivate(Self)', 'FOnDeactivate(Self)'):
            self.assertIn(text, body)
        self.assertNotIn('FOnActivate(Sender)', body)
        self.assertIn('FOnActivate := nil; FOnDeactivate := nil', source)
        window = (ROOT / 'src/win16/native_application_window.pas').read_text()
        self.assertIn('FOnClose := nil; FOnActivation := nil', window)

    def test_native_fixture_distinguishes_protocol_checks_from_real_task_activation(self):
        source = (ROOT / 'tests/pascal/test_win16_application_activation.pas').read_text()
        helper = (ROOT / 'tests/pascal/activation_sender.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'same-task form switches do not synthesize app activation',
                     'visible helper runs in independent Win16 task',
                     'real task switch deactivates application not just form',
                     'return to main task activates application',
                     'activation event guards registration hooks title and pumps',
                     'notifications do not overwrite native Active and sender is application',
                     'application deactivation exception stays inside USER boundary',
                     'notification HWND recreation retains activation callbacks and hooks',
                     'activation handshake preserves signed cross-task reply',
                     'activation run leaves no quit residue'):
            self.assertIn(text, source)
        for text in ('{$M 4096,2048}', 'ShowWindow(Window, SW_SHOWNORMAL)',
                     'SetActiveWindow(Window)', 'LongInt(GetCurrentTask)',
                     'SendMessage(Target, ReadyMessage', 'FinishedMessage'):
            self.assertIn(text, helper)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-application-activation-runtime-test: win16-application-activation', make)
        self.assertIn("GDI_HELPER_EXE='$(abspath $(BUILD_DIR)/tests/win16-activation-sender/APPSEND.EXE)'", make)
        for path in ('win16-application-activation/GDITEST.EXE', 'win16-activation-sender/APPSEND.EXE'):
            self.assertIn(f'check_win16_budget.py $(BUILD_DIR)/tests/{path}', make)


if __name__ == '__main__':
    unittest.main()
