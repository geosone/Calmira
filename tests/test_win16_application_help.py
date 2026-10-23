"""Application help scope guards; native tests exercise installed Win3.11 help."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ApplicationHelpTests(unittest.TestCase):
    def test_event_precedes_backend_and_can_supply_its_own_boolean_result(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        body = source.split('function TNativeApplication.HelpCommand(', 1)[1].split(
            'function TNativeApplication.HelpContext(', 1)[0]
        for text in ('CheckReady', 'if FHelping then raise', 'CallHelp := True',
                     'Result := FOnHelp(Command, Data, CallHelp)',
                     'if CallHelp then', 'LaunchHelp(Handle, HelpFile, Command, Data)',
                     'finally FHelping := False'):
            self.assertIn(text, body)
        self.assertLess(body.index('FOnHelp(Command'), body.index('LaunchHelp('))
        self.assertNotIn('except', body)

    def test_registration_and_file_assignment_do_not_create_a_transport(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        body = source.split('procedure TNativeApplication.SetHelpFile(', 1)[1].split(
            'function TNativeApplication.HelpCommand(', 1)[0]
        self.assertIn('CheckReady', body)
        self.assertIn('CheckEventMutable', body)
        self.assertIn('if FHelping then raise', body)
        self.assertIn('Pos(#0, Value)', body)
        self.assertIn('FHelpFile: AnsiString', source)
        for forbidden in ('GetHandle', 'EnsureHandle', 'LaunchHelp'):
            self.assertNotIn(forbidden, body)

    def test_context_and_macro_data_preserve_the_native_abi_and_pointer_lifetime(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn('HelpCommand(HELP_CONTEXT, Context)', source)
        jump = source.split('function TNativeApplication.HelpJump(', 1)[1].split(
            'procedure TNativeApplication.Initialize;', 1)[0]
        self.assertIn('Macro: AnsiString', jump)
        self.assertIn('HelpJumpMacro(FHelpFile, Context)', jump)
        self.assertIn('HelpCommand(HELP_COMMAND, LongInt(PChar(Macro)))', jump)
        self.assertNotIn('PostMessage', jump)
        helper = (ROOT / 'src/portable/help_jump.pas').read_text()
        self.assertIn('Length(Context) > 255', helper)
        self.assertIn('Length(FileName) > 255', helper)
        self.assertIn("'0'..'9', '_', '.'", helper)

    def test_destructor_closes_only_previously_opened_native_help_without_callbacks(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        destructor = source.split('destructor TNativeApplication.Destroy;', 1)[1]
        self.assertIn('if FHelpOpen and (FWindow <> nil) and (FWindow.Handle <> 0)', destructor)
        self.assertIn('WinHelp(FWindow.Handle, PChar(FHelpFile), HELP_QUIT, 0)', destructor)
        self.assertLess(destructor.index('HELP_QUIT'), destructor.index('FWindow.Free'))
        self.assertNotIn('HelpCommand(', destructor)
        self.assertNotIn('LaunchHelp(', destructor)
        self.assertNotIn('GetHandle', destructor)

    def test_native_fixture_and_disposable_runner_are_wired(self):
        source = (ROOT / 'tests/pascal/test_win16_application_help.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'jump macro pointer is live and interception creates no HWND',
                     'direct help exception propagates and releases guard',
                     'real WinHelp displays installed help from explicit path',
                     'localized dialogs preserve help and pump guards',
                     'application teardown silently quits its native help',
                     'GetDlgCtrlID(Child)', 'except Failed := True; end;'):
            self.assertIn(text, source)
        runner = (ROOT / 'tests/dos/test_win16_gdi.sh').read_text()
        self.assertIn('if [ -n "${GDI_HELP_FILE:-}" ]; then', runner)
        self.assertIn('::/HELPDOCS/CALMIRA.HLP', runner)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-application-help-runtime-test: win16-application-help', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-application-help/GDITEST.EXE', make)
        self.assertIn('tests/pascal/test_help_jump.pas', make)


if __name__ == '__main__':
    unittest.main()
