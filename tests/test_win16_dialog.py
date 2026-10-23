"""Dialog-navigation scope guards; behavior runs under actual Win3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16DialogTests(unittest.TestCase):
    def test_filter_precedes_translation_but_never_intercepts_quit(self):
        source = (ROOT / 'src/win16/native_loop.pas').read_text()
        self.assertLess(source.index('FExitCode := SmallInt(Message.wParam)'),
                        source.index('if FOnMessage(Message) then Exit'))
        self.assertLess(source.index('if FOnMessage(Message) then Exit'),
                        source.index('TranslateMessage(Message)'))
        self.assertIn('Inc(Result)', source)
        self.assertIn('receiver must outlive', source)

    def test_form_limits_preprocessing_to_managed_targets_and_unmodified_keys(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        for text in ('Message.message <> WM_KEYDOWN', 'FindControl(Message.hwnd)',
                     'GetKeyState(VK_CONTROL)', 'GetKeyState(VK_MENU)',
                     'GetKeyState(VK_SHIFT)', 'DLGC_WANTTAB', 'DLGC_WANTALLKEYS',
                     'LongInt(Pointer(@Message))', 'FocusNext(', 'DispatchDialogKey('):
            self.assertIn(text, source)

    def test_traversal_uses_managed_order_and_live_eligibility(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('List.Move(List.IndexOf(Self), Value)',
                     'FindWindowedChild(Child.Handle) <> Child', 'Child.CanFocus',
                     'Child.CollectFocusControls(List)', 'if not Candidate.TabStop then Continue',
                     'Current.ControlDialogKey(Key)', 'finally List.Free; end;',
                     'Current.Canvas.Handle <> 0'):
            self.assertIn(text, source)

    def test_button_defaults_do_not_change_owner_draw_class(self):
        source = (ROOT / 'src/win16/native_button.pas').read_text()
        self.assertIn('Perform(BM_SETSTYLE, ButtonStyle, 1)', source)
        self.assertIn('(FDefault or Focused)', source)
        self.assertIn('(Key = VK_ESCAPE) and FCancel', source)
        self.assertIn('if TabStop then Style := Style or WS_TABSTOP', source)
        progress = (ROOT / 'tests/pascal/progress_ui_probe.inc').read_text()
        self.assertIn('CancelButton.Cancel := True', progress)
        self.assertEqual(progress.count('Loop.OnMessage := Form.ProcessDialogMessage'), 3)
        self.assertIn('Loop.OnMessage := nil', progress)

    def test_native_acceptance_covers_queue_and_dialog_edges(self):
        source = (ROOT / 'tests/pascal/test_win16_dialog.pas').read_text()
        for text in ('Shift Tab reverses', 'Tab leaves group',
                     'nonstop focus keeps position', 'drawing rejects tab reorder',
                     'control retains all dialog keys', 'focused button wins over default',
                     'queued Enter consumed before translation',
                     'consumed chain obeys budget and nesting guard',
                     'filter exception releases pump guard', 'quit bypasses message filter',
                     'recreation retains dialog settings'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-dialog-runtime-test: win16-dialog', makefile)
