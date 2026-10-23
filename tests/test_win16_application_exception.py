"""Explicit exception routing; native fixture verifies ownership and USER boundaries."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ApplicationExceptionTests(unittest.TestCase):
    def test_route_uses_active_exception_and_preserves_sender(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        body = source.split('procedure TNativeApplication.HandleException(', 1)[1].split(
            'procedure TNativeApplication.WindowActivation(', 1)[0]
        for text in ('Current := ExceptObject', 'if not (Current is Exception)',
                     'if Current is EAbort then Exit',
                     'FOnException(Sender, Exception(Current))',
                     'else PresentException(Exception(Current))',
                     'finally FHandlingException := False'):
            self.assertIn(text, body)
        self.assertNotIn('Exception(Sender)', body)
        self.assertNotIn('.Free', body)
        self.assertLess(body.index('Current is EAbort'), body.index('FOnException(Sender'))

    def test_registration_is_handle_free_and_reentrant_calls_are_guarded(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        setter = source.split('procedure TNativeApplication.SetOnException(', 1)[1].split(
            'procedure TNativeApplication.PresentException(', 1)[0]
        self.assertIn('CheckEventMutable', setter)
        self.assertIn('if FHandlingException then raise', setter)
        self.assertNotIn('GetHandle', setter)
        self.assertEqual(source.count(
            'if FPumping or FCreatingForm or FWindow.Dispatching or FHandlingException or FHelping then raise'), 2)
        explicit = source.split('procedure TNativeApplication.ShowException(', 1)[1].split(
            'procedure TNativeApplication.HandleException(', 1)[0]
        self.assertIn('(E = nil) or FHandlingException', explicit)
        self.assertIn('try PresentException(E); finally FHandlingException := False', explicit)
        self.assertNotIn('FOnException(', explicit)
        self.assertIn('FOnException := nil', source)

    def test_default_presentation_snapshots_bounded_ansi_text(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        body = source.split('procedure TNativeApplication.PresentException(', 1)[1].split(
            'procedure TNativeApplication.ShowException(', 1)[0]
        for text in ('Text, Caption: AnsiString',
                     'ExceptionDisplayText(E.Message, E.ClassName)',
                     "if Caption = '' then Caption := 'Calmira'",
                     'MessageBox(Handle, PChar(Text), PChar(Caption), MB_OK or MB_ICONEXCLAMATION)'):
            self.assertIn(text, body)
        formatter = (ROOT / 'src/portable/exception_text.pas').read_text()
        for text in ('ExceptionTextLimit = 1024', 'Copy(Source, 1, ExceptionTextLimit)',
                     "if Result[I] = #0 then Result[I] := ' '",
                     'if Length(Source) > ExceptionTextLimit then'):
            self.assertIn(text, formatter)
        self.assertNotIn('array[', body)

    def test_exception_routing_does_not_replace_existing_native_or_idle_boundaries(self):
        window = (ROOT / 'src/win16/native_window.pas').read_text()
        loop = (ROOT / 'src/win16/native_loop.pas').read_text()
        self.assertIn('Instance.RecordCallbackException(E)', window)
        self.assertNotIn('HandleException', window)
        self.assertNotIn('HandleException', loop)
        self.assertNotIn('OnException', loop)
        idle = (ROOT / 'tests/pascal/test_win16_application_idle.pas').read_text()
        self.assertIn('application idle error propagates outside USER with guards released', idle)

    def test_native_fixture_exercises_real_dialog_ownership_and_recovery(self):
        fixture = (ROOT / 'tests/pascal/test_win16_application_exception.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'RTL releases active exception exactly once',
                     'borrowed identity sender help context and recursion guards',
                     'direct handler failure propagates with original released',
                     'native boundary contains handler failure without global rerouting',
                     'unrouted callback keeps existing diagnostics',
                     'native routing recovers after handler error',
                     'explicit ShowException bypasses event and retains caller ownership',
                     'GetWindowTask(Box) <> GetCurrentTask', 'GetParent(Box) = App.Handle',
                     'GetDlgCtrlID(Child)', 'except Failed := True; end;'):
            self.assertIn(text, fixture)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-application-exception-runtime-test: win16-application-exception', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-application-exception/GDITEST.EXE', make)
        self.assertIn('tests/pascal/test_exception_text.pas', make)


if __name__ == '__main__':
    unittest.main()
