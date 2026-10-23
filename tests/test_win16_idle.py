"""Idle contract guards; native tests establish empty-queue and modal behavior."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IdleTests(unittest.TestCase):
    def test_idle_requires_empty_queue_and_cooperates_only_when_requested(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        body = source.split('function TNativeMessageLoop.PrepareWait(', 1)[1].split(
            'function TNativeMessageLoop.Deliver(', 1)[0]
        for text in ('if Provider = nil then Exit', 'if Provider.FIdling then Exit',
                     'PeekMessage(Pending, 0, 0, 0, PM_NOREMOVE)', 'Done := True',
                     'Provider.FIdling := True', 'try Provider.FOnIdle(Self, Done)',
                     'finally Provider.FIdling := False', 'if not Done then',
                     'WinProcs.Yield; Result := False'):
            self.assertIn(text, body)
        self.assertLess(body.index('PM_NOREMOVE'), body.index('Provider.FOnIdle(Self, Done)'))
        self.assertLess(body.index('if not Done then'), body.index('WinProcs.Yield'))
        self.assertNotIn('PM_REMOVE)', body)
        after_query = body.split('PM_NOREMOVE) then Exit;', 1)[1]
        self.assertLess(after_query.index('if FTerminated then Exit'), after_query.index('Provider.FOnIdle(Self, Done)'))
        self.assertLess(after_query.index('Provider := IdleProvider'), after_query.index('Provider.FOnIdle(Self, Done)'))

    def test_modal_inherits_nearest_idle_provider_without_recursing_into_busy_parent(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        for text in ('while (Result <> nil) and not Assigned(Result.FOnIdle)',
                     'Result := Result.FPreviousActive', 'if Provider.FIdling then Exit',
                     'if FIdling then raise', 'property Idling: Boolean read FIdling'):
            self.assertIn(text, source)
        modal = source.split('function TNativeMessageLoop.RunModal(', 1)[1].split(
            'function TNativeMessageLoop.Run:', 1)[0]
        idle_check = modal.index('if IdleCalled then')
        condition_check = modal.index('if not ContinueWhile then Break', idle_check)
        self.assertLess(condition_check, modal.index('GetMessage('))
        self.assertIn('if not PrepareWait(IdleCalled) then Continue', modal)

    def test_bounded_pump_does_not_invoke_idle_and_quit_delivery_stays_central(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        bounded = source.split('function TNativeMessageLoop.ProcessMessages(', 1)[1]
        self.assertNotIn('PrepareWait', bounded)
        self.assertNotIn('FOnIdle', bounded)
        self.assertIn('Result < Limit', bounded)
        self.assertIn('if not Deliver(Message) then Break', bounded)
        self.assertEqual(source.count('FExitCode := SmallInt(Message.wParam)'), 1)
        run = source.split('function TNativeMessageLoop.Run:', 1)[1].split(
            'function TNativeMessageLoop.ProcessMessages(', 1)[0]
        self.assertLess(run.index('PrepareWait'), run.index('GetMessage('))
        self.assertIn('finally ActiveLoop := nil', run)

    def test_application_registration_is_handle_free_atomic_and_uses_application_sender(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        setter = source.split('procedure TNativeApplication.SetOnIdle(', 1)[1].split(
            'procedure TNativeApplication.Idle(', 1)[0]
        for text in ('CheckEventMutable', 'if FLoop.Idling then raise',
                     'if Assigned(Value) then FLoop.OnIdle := Idle else FLoop.OnIdle := nil',
                     'FOnIdle := Value'):
            self.assertIn(text, setter)
        self.assertLess(setter.index('FLoop.OnIdle :='), setter.index('FOnIdle := Value'))
        self.assertNotIn('GetHandle', setter)
        body = source.split('procedure TNativeApplication.Idle(', 1)[1].split('end;', 1)[0]
        self.assertIn('not FShuttingDown', body)
        self.assertIn('FOnIdle(Self, Done)', body)
        self.assertIn('FLoop.OnIdle := nil', source)

    def test_loop_native_fixture_covers_wait_slices_quit_conditions_and_provider_lifetime(self):
        source = (ROOT / 'tests/pascal/test_win16_idle.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'bounded empty pump never invokes idle', 'Done true does not busy poll empty queue',
                     'queued message interrupts repeated idle slices',
                     'idle exception propagates and releases provider guard',
                     'idle can end modal condition without posting a wakeup',
                     'modal inherits parent idle with current-pump sender and provider mutation guard',
                     'modal opened from idle does not recursively call busy provider',
                     'nearest explicit modal provider overrides busy parent'):
            self.assertIn(text, source)

    def test_application_native_fixture_covers_sender_modal_exceptions_signed_quit_and_cleanup(self):
        source = (ROOT / 'tests/pascal/test_win16_application_idle.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'idle registration creates no native transport or form HWND',
                     'application bounded pump does not call idle',
                     'application idle sender guards and run flags',
                     'startup modal inherits application idle service',
                     'idle-opened modal skips busy inherited provider',
                     'modal idle signed quit reaches suspended root',
                     'modal inherited idle exception restores owner and root pump',
                     'root recovers after inherited modal idle error'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        for profile in ('idle', 'application-idle'):
            self.assertIn(f'win16-{profile}-runtime-test: win16-{profile}', make)
            self.assertIn(f'tests/win16-{profile}/units', make)
            self.assertIn(f'check_win16_budget.py $(BUILD_DIR)/tests/win16-{profile}/GDITEST.EXE', make)


if __name__ == '__main__':
    unittest.main()
