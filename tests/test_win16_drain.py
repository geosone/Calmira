"""Scoped drain contracts; real queue/modal behavior is tested in Win3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DrainTests(unittest.TestCase):
    def test_parameterless_overload_preserves_bounded_api_and_run_state(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn('function ProcessMessages(Limit: Word): Word; overload;', source)
        self.assertIn('procedure ProcessMessages; overload;', source)
        body = source.split('procedure TNativeApplication.ProcessMessages;', 1)[1].split(
            'function TNativeApplication.ProcessMessages(', 1)[0]
        for text in ('CheckReady', 'FDraining or FCreatingForm or FWindow.Dispatching',
                     'FHandlingException', 'FHelping or FLoop.Idling',
                     '(FPumping and not FRunning)', 'WasPumping := FPumping',
                     'FDraining := True', 'FLoop.DrainMessages',
                     'finally FDraining := False; FPumping := WasPumping'):
            self.assertIn(text, body)
        for text in ('FRunning :=', 'FMainForm.Show', '65535', 'ProcessMessages(0)'):
            self.assertNotIn(text, body)

    def test_drain_uses_scoped_frame_and_live_current_filter(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        body = source.split('procedure TNativeMessageLoop.DrainMessages;', 1)[1].split(
            'function TNativeMessageLoop.ProcessMessages(', 1)[0]
        for text in ('Child := TNativeMessageLoop.Create', 'ActiveLoop.ForwardFilter',
                     'else Child.FOnMessage := ForwardFilter',
                     'Child.FPreviousActive := ActiveLoop', 'Child.FDraining := True',
                     'ActiveLoop := Child', 'PeekMessage(Message, 0, 0, 0, PM_REMOVE)',
                     'if not Child.Deliver(Message) then Break',
                     'ActiveLoop := Child.FPreviousActive', 'Child.Free'):
            self.assertIn(text, body)
        for text in ('GetMessage(', 'PrepareWait(', 'FOnIdle(', '65535', 'Result < Limit'):
            self.assertNotIn(text, body)
        forward = source.split('function TNativeMessageLoop.ForwardFilter(', 1)[1].split(
            'function TNativeMessageLoop.Deliver(', 1)[0]
        self.assertIn('if Assigned(FOnMessage) then Result := FOnMessage(Message)', forward)

    def test_recursion_idle_and_termination_are_checked_across_ancestor_chain(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        body = source.split('procedure TNativeMessageLoop.DrainMessages;', 1)[1].split(
            'function TNativeMessageLoop.ProcessMessages(', 1)[0]
        for text in ('Current := ActiveLoop', 'while Current <> nil',
                     'Current.FDraining or Current.FIdling',
                     'Current := Current.FPreviousActive',
                     'FTerminated := True; FExitCode := Current.FExitCode',
                     'if FTerminated then Exit', 'finally',
                     'FTerminated := True; FExitCode := Child.FExitCode'):
            self.assertIn(text, body)
        self.assertLess(body.index('if FTerminated then Exit'), body.index('Child := TNativeMessageLoop.Create'))

    def test_filter_modal_quit_is_checked_before_native_dispatch(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        body = source.split('function TNativeMessageLoop.Deliver(', 1)[1].split(
            'function TNativeMessageLoop.RunModal(', 1)[0]
        self.assertLess(body.index('if FTerminated then'), body.index('if Assigned(FOnMessage)'))
        after = body.split('if FOnMessage(Message) then Exit;', 1)[1]
        self.assertLess(after.index('if FTerminated then'), after.index('TranslateMessage(Message)'))
        self.assertIn('Result := False; Exit', after)
        self.assertNotIn('PostQuitMessage(', source)

    def test_sticky_exit_code_is_not_overwritten_by_an_unrelated_active_loop(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        body = source.split('procedure TNativeMessageLoop.DrainMessages;', 1)[1].split(
            'function TNativeMessageLoop.ProcessMessages(', 1)[0]
        self.assertIn('if Current.FTerminated and not FTerminated then', body)
        fixture = (ROOT / 'tests/pascal/test_win16_drain.pas').read_text()
        self.assertIn('Retired := Root; Root := nil', fixture)
        self.assertIn('Retired.DrainMessages', fixture)
        self.assertIn('already terminated caller retains first exit code', fixture)

    def test_native_profiles_cover_queue_filter_quit_and_real_cancel(self):
        loop = (ROOT / 'tests/pascal/test_win16_drain.pas').read_text()
        app = (ROOT / 'tests/pascal/test_win16_application_pump.pas').read_text()
        for text in ('finite repost chain', 'source filter reassignment',
                     'filter exception restores suspended root', 'active modal filter',
                     'signed quit reaches modal root and unrelated caller',
                     'modal quit inside drain filter prevents later native dispatch'):
            self.assertIn(text, loop)
        for text in ('real Cancel click while long operation callback is active',
                     'actual modal default-button routing without root filter',
                     'sent transport help and exception callbacks reject',
                     'filter failure releases application drain guards',
                     'rejects active idle and factory construction callbacks',
                     'successor sees sentinel without leaked quit'):
            self.assertIn(text, app)
        make = (ROOT / 'makefile').read_text()
        for name, fixture in (('drain', loop), ('application-pump', app)):
            self.assertIn('{$M 4096,2048}', fixture)
            self.assertIn('Check(StackGuardIntact', fixture)
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', make)
            self.assertIn(f'check_win16_budget.py $(BUILD_DIR)/tests/win16-{name}/GDITEST.EXE', make)
            aggregate = make.split('win16-fixed-regression: fpc-win16-fixed-compiler', 1)[1].split(
                '\nwin16-class-pointer:', 1)[0]
            self.assertIn(f'win16-{name}-runtime-test', aggregate)


if __name__ == '__main__':
    unittest.main()
