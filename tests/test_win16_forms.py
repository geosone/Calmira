"""Source contract for the initial Forms layer; the native test runs under Win3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'src/win16/forms.pas'


class FormsLayerTests(unittest.TestCase):
    def test_globals_are_created_initialized_and_freed_by_the_unit(self):
        source = SOURCE.read_text()
        init = source.split('initialization', 1)[1]
        for text in ('Application := TApplication.Create(nil); Application.Initialize;',
                     'Screen.Application := Application',
                     'Application.Free; Application := nil;', 'Screen.Free; Screen := nil;'):
            self.assertIn(text, init)
        self.assertLess(init.index('Application.Free'), init.index('Screen.Free'))

    def test_builds_on_native_foundations_instead_of_duplicating_them(self):
        source = SOURCE.read_text()
        for text in ('TForm = class(TNativeModalForm)', 'TApplication = class(TNativeApplication)',
                     'TScreen = class(TNativeScreen)', 'TCloseAction = TNativeCloseAction'):
            self.assertIn(text, source)
        self.assertNotIn('GetMessage(', source)
        self.assertNotIn('CreateWindow', source)

    def test_cafree_is_deferred_through_the_application_window(self):
        source = SOURCE.read_text()
        close = source.split('procedure TForm.DoClose', 1)[1].split('procedure TForm.Release', 1)[0]
        self.assertIn('if Action = caFree then begin Action := caHide; Release; end;', close)
        self.assertNotIn('Free;', close.replace('caFree', ''))
        for text in ("RegisterWindowMessage('CalmiraFormRelease')", 'HookMainWindow(ReleaseHook)',
                     'PostMessage(Handle, ReleaseMessage, 0, 0)', 'Form.FreeNotification(Self)',
                     'FReleases.Remove(AComponent)', 'if FReleases.IndexOf(Form) >= 0 then Exit;'):
            self.assertIn(text, source)

    def test_unsupported_services_are_not_silently_aliased(self):
        source = SOURCE.read_text()
        self.assertIn("raise ENativeScreenError.Create('Invalid screen form')", source)

    def test_application_hints(self):
        source = SOURCE.read_text()
        interface = source.split('unit Forms;', 1)[1].split('implementation', 1)[0]
        for text in ('property HintColor: TColor', 'property HintPause: Integer',
                     'property OnShowHint: TShowHintEvent', 'property OnHint: TNotifyEvent',
                     'HintWindowClass: THintWindowClass = THintWindow;', 'THintInfo = record',
                     'TWindowHook = TNativeWindowHook;', 'procedure CancelHint;'):
            self.assertIn(text, interface)
        # WinProcs.PtInRect takes USER's packed POINT; Controls' version is correct.
        self.assertIn('not Controls.PtInRect(FHintCursorRect', source)
        self.assertIn('FHintWindow.Canvas.ContextHandle', source)
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('THintWindow = class(TCustomControl)', 'function IsHintMsg(var Msg: TMsg): Boolean; virtual;',
                     'function FindDragTarget(const Pos: TPoint; AllowDisabled: Boolean): TControl;',
                     'function GetShortHint(const Hint: string): string;', 'function HandleAllocated: Boolean;'):
            self.assertIn(text, controls)
        test = (ROOT / 'tests/pascal/test_win16_hints.pas').read_text()
        for text in ('the short hint pops up after HintPause', 'OnShowHint can refuse a hint',
                     'moves inside the control do not restart the hint', 'a key press cancels the hint'):
            self.assertIn(text, test)
        self.assertIn('win16-hints-runtime-test', (ROOT / 'makefile').read_text())
        task = (ROOT / 'src/task.pas').read_bytes()
        self.assertIn(b'{$IFDEF FPC}\r\n  DrawText(HintWindow.Canvas.ContextHandle', task)

    def test_minimize_restore_and_screen_events(self):
        source = SOURCE.read_text()
        interface = source.split('unit Forms;', 1)[1].split('implementation', 1)[0]
        # apholder assigns these inside "with Application do" / "with Screen do":
        # without them FPC silently binds to TAppHolder's own properties.
        for text in ('procedure Minimize;', 'procedure Restore;',
                     'property OnMinimize: TNotifyEvent', 'property OnRestore: TNotifyEvent',
                     'property OnActiveControlChange: TNotifyEvent', 'property OnActiveFormChange: TNotifyEvent'):
            self.assertIn(text, interface)
        self.assertIn('(FindNativeWindow(Window) is TNativeForm) then FHiddenForms.Add', source)
        self.assertIn('PostMessage(Handle, WM_SYSCOMMAND, SC_RESTORE, 0);', source)
        self.assertIn('(Application.MainForm = Self) then', source)
        self.assertIn('EnterNotify := Screen.ControlEntered;', source)
        native_input = (ROOT / 'src/win16/native_input.pas').read_text()
        self.assertIn('if Assigned(EnterNotify) then EnterNotify(Self);\n  if Assigned(FOnEnter)', native_input)
        test = (ROOT / 'tests/pascal/test_win16_minimize.pas').read_text()
        for text in ('minimizing the main form minimizes the application',
                     'TAppHolder hands its events to Application and Screen',
                     'OnActiveControlChange runs before OnEnter'):
            self.assertIn(text, test)
        self.assertIn('win16-minimize-runtime-test', (ROOT / 'makefile').read_text())

    def test_native_suite_is_part_of_fixed_regression(self):
        makefile = (ROOT / 'makefile').read_text()
        regression = makefile.split('win16-fixed-regression: fpc-win16-fixed-compiler', 1)[1].split('\n\n', 1)[0]
        self.assertIn('win16-forms-runtime-test', regression)
        self.assertIn('tests/pascal/test_win16_forms.pas', makefile)


if __name__ == '__main__':
    unittest.main()
