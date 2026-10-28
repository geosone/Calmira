"""Modal scope guards; queue ownership and UI cleanup require native acceptance."""
from pathlib import Path
import unittest

from test_win16_handles import active_source

ROOT = Path(__file__).resolve().parents[1]


class Win16ModalTests(unittest.TestCase):
    def test_explicit_modal_pump_restores_ancestor_without_relaxing_ordinary_guard(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        for text in ('if ActiveLoop <> nil then', 'if Previous = Self then',
                     'if not Assigned(ContinueWhile)',
                     'FPreviousActive := ActiveLoop; ActiveLoop := Self',
                     'finally ActiveLoop := FPreviousActive; FPreviousActive := nil',
                     'if not ContinueWhile then Break', 'if FTerminated then Break'):
            self.assertIn(text, source)
        self.assertEqual(source.count('finally ActiveLoop := nil; end;'), 2)

    def test_quit_is_forwarded_as_state_not_a_reposted_quit(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        for text in ('Previous.FTerminated := True; Previous.FExitCode := FExitCode',
                     'Previous := Previous.FPreviousActive',
                     'PostAppMessage(GetCurrentTask, WM_NULL, 0, 0)',
                     'if Previous.FTerminated then'):
            self.assertIn(text, source)
        self.assertNotIn('PostQuitMessage(', source)

    def test_modal_form_validates_owner_and_preserves_enable_focus_and_native_owner(self):
        source = (ROOT / 'src/win16/native_modal.pas').read_text()
        for text in ('class(TNativeForm)', 'GetWindowTask(OwnerWindow) <> GetCurrentTask',
                     'GWL_STYLE)) and WS_CHILD <> 0', 'Style or WS_POPUP',
                     'SetWindowWord(Handle, GWW_HWNDPARENT, OwnerWindow)',
                     'if IsWindowEnabled(OwnerWindow) then',
                     'DisabledOwner := True; EnableWindow(OwnerWindow, False)',
                     'if DisabledOwner and IsWindow(OwnerWindow)',
                     'SetWindowWord(Handle, GWW_HWNDPARENT, OldOwner)',
                     'if UsableWindow(OldFocus) then WinProcs.SetFocus(OldFocus)',
                     'ActiveModal := PreviousModal; FModalRunning := False'):
            self.assertIn(text, source)
        self.assertNotIn('SetSysModalWindow', source)
        self.assertNotIn('unit Forms;', source)

    def test_result_closure_reuses_guarded_close_and_clears_vetoed_results(self):
        source = (ROOT / 'src/win16/native_modal.pas').read_text()
        body = source.split('function TNativeModalForm.ContinueModal:', 1)[1].split('function ', 1)[0]
        self.assertIn('Close;', body)
        self.assertIn('if (Handle <> 0) and Visible then FModalResult := mrNone', body)
        self.assertNotIn('CloseQuery;', body)
        for text in ('FModalLoop.OnMessage := nil', 'FModalLoop.Free; FModalLoop := nil',
                     'if FModalLoop.Terminated or (FModalResult = mrNone)',
                     'FTaskQuit := FModalLoop.Terminated; FTaskExitCode := FModalLoop.ExitCode',
                     'if ActiveModal.FPreparing then', 'PostAppMessage(GetCurrentTask, WM_NULL'):
            self.assertIn(text, source)

    def test_button_result_is_applied_before_event_without_modal_unit_dependency(self):
        source = (ROOT / 'src/win16/native_button.pas').read_text()
        body = source.split('procedure TButton.Click;', 1)[1].split('function ', 1)[0]
        self.assertLess(body.index('Parent.ApplyModalResult(FModalResult)'), body.index('FOnClick(Self)'))
        self.assertIn('property ModalResult: TModalResult', source)
        self.assertNotIn('native_modal', source)
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('if FParent <> nil then FParent.ApplyModalResult(Value)', controls)

    def test_native_probe_covers_modal_lifetime_veto_nested_quit_and_successor(self):
        source = (ROOT / 'tests/pascal/test_win16_modal.pas').read_text()
        for text in ('owner and focus restored', 'direct close queried once',
                     'hide cancels directly', 'native destroy cancels',
                     'click can clear result', 'close query can veto result',
                     'disabled owner stays disabled', 'show failure restores owner',
                     'hide failure releases modal pump', 'nested modal owner stack',
                     'active owner inferred', 'queued Escape cancels',
                     'lifecycle nesting rejected', 'show event result accepted',
                     'child owner rejected safely',
                     'standalone quit reported',
                     'focus cleanup rejects reentry',
                     'only explicit modal nesting allowed', 'quit unwinds every pump once',
                     'quit not reposted to successor', 'modal resource stability'):
            self.assertIn(text, source)
        modal = (ROOT / 'src/win16/native_modal.pas').read_text()
        self.assertLess(modal.index('WinProcs.SetFocus(OldFocus)'),
                        modal.index('ActiveModal := PreviousModal; FModalRunning := False'))

    def test_low_level_modal_condition_preserves_queue_quit_and_pump_cleanup(self):
        source = (ROOT / 'tests/pascal/test_win16_modal_loop.pas').read_text()
        for text in ('nil condition rejected', 'false condition does not dequeue',
                     'condition exception releases pump',
                     'condition quit stops before GetMessage',
                     'terminated modal pump stays sticky', 'successor sees no reposted quit'):
            self.assertIn(text, source)
        self.assertIn('win16-modal-loop-runtime-test: win16-modal-loop',
                      (ROOT / 'makefile').read_text())

    def test_original_search_keeps_modeless_and_modal_acceptance_and_delphi_branch(self):
        self.assertIn('class(TForm)', active_source('src/incsrch.pas'))
        self.assertIn('class(TForm)', active_source('src/incsrch.pas', False))
        source = (ROOT / 'tests/pascal/test_win16_incsrch_modal.pas').read_text()
        for text in ('Dialog.FormShow(Sender)', 'Dialog.ShowModal',
                     'original search and Enter', 'empty modal Escape', 'modal recreation'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        for name in ('modal', 'incsrch-modal'):
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', makefile)
