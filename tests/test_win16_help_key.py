"""Queued F1 routing scope; native tests establish focus, modal and callback behavior."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HelpKeyTests(unittest.TestCase):
    def test_context_metadata_is_handle_free_and_resolved_from_current_parent_chain(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('procedure TCustomControl.SetHelpContext(', 1)[1].split(
            'function TCustomControl.GetTabOrder:', 1)[0]
        for text in ('if Value < 0 then raise', 'FHelpContext := Value',
                     'Current := Self', 'while Current <> nil',
                     'Current.FHelpContext <> 0', 'Current := Current.FParent'):
            self.assertIn(text, body)
        for text in ('CreateHandle', 'GetFocus', 'SendMessage', 'EnsureHandle'):
            self.assertNotIn(text, body)

    def test_plain_first_press_f1_obeys_live_focus_and_control_ownership(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        body = source.split('function TNativeForm.ProcessDialogMessage(', 1)[1].split(
            'constructor TNativeForm.Create(', 1)[0]
        for text in ('WindowState = wsMinimized', 'if not CanFocus then Exit',
                     'Message.message <> WM_KEYDOWN', 'GetKeyState(VK_CONTROL)',
                     'GetKeyState(VK_MENU)', 'GetKeyState(VK_SHIFT)',
                     'GetFocus <> Message.hwnd', 'DWORD(Message.lParam) and $60000000',
                     'FHost.FormHelp(Self, Current.ResolveHelpContext); Exit'):
            self.assertIn(text, body)
        self.assertLess(body.index('DLGC_WANTALLKEYS'), body.index('FHost.FormHelp'))

    def test_form_host_is_optional_and_base_form_never_imports_application_or_winhelp(self):
        form = (ROOT / 'src/win16/native_form.pas').read_text()
        self.assertIn('function TNativeFormHost.FormHelp(', form)
        body = form.split('function TNativeFormHost.FormHelp(', 1)[1].split('end;', 1)[0]
        self.assertIn('Result := False', body)
        self.assertIn('(FHost = nil)', form)
        self.assertNotIn('uses native_application', form)
        self.assertNotIn('LaunchHelp(', form)

    def test_application_validates_registration_then_consumes_exactly_one_help_attempt(self):
        source = (ROOT / 'src/win16/native_application.pas').read_text()
        body = source.split('function TNativeApplication.FormHelp(', 1)[1].split(
            'procedure TNativeApplication.Start(', 1)[0]
        for text in ('CheckReady', 'if FForms.IndexOf(Value) < 0 then Exit',
                     'HelpCommand(HELP_CONTENTS, 0) else HelpContext(Context)', 'Result := True'):
            self.assertIn(text, body)
        self.assertLess(body.index('FForms.IndexOf'), body.index('HelpCommand('))
        self.assertNotIn('except', body)
        self.assertNotIn('Value.', body)

    def test_native_fixture_covers_dfm_queue_focus_modal_and_mutation_cases(self):
        source = (ROOT / 'tests/pascal/test_win16_help_key.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     '{$I help_context_form.inc}', 'F1 is consumed even when OnHelp returns false',
                     'reparented context lookup preserves full LongInt',
                     'application queue filter precedes F1',
                     'DLGC_WANTALLKEYS keeps F1 in the native control',
                     'ineligible keys never invoke help',
                     'unregistered form retains normal F1 dispatch',
                     'queued F1 error propagates and pump recovers',
                     'modal F1 error restores owner and loop',
                     'queued F1 really opens installed help in foreign WinHelp task',
                     'F1-opened help quits cleanly',
                     'queued help may free current secondary form without stale traversal'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-help-key-runtime-test: win16-help-key', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-help-key/GDITEST.EXE', make)
        self.assertIn('python3 tests/help_context_fixture.py $@', make)


if __name__ == '__main__':
    unittest.main()
