"""Scope/lifetime guards; native Windows tests verify USER ordering and focus."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeScreenTests(unittest.TestCase):
    def test_explicit_view_is_task_affine_and_weakly_bound(self):
        source = (ROOT / 'src/win16/native_screen.pas').read_text()
        for text in ('TNativeScreen = class(TComponent)', 'GetCurrentTask <> FTask',
                     'Value.TaskHandle <> FTask', 'not Value.Initialized',
                     'Value.FreeNotification(Self)', 'FApplication.RemoveFreeNotification(Self)',
                     '(AComponent = FApplication) then', 'FCursors.Reset; FApplication := nil'):
            self.assertIn(text, source)
        self.assertNotIn('var Screen:', source)
        self.assertNotIn('unit Forms;', source)
        self.assertNotIn('FApplication.Free', source)

    def test_application_teardown_returns_empty_before_registry_access(self):
        source = (ROOT / 'src/win16/native_screen.pas').read_text()
        self.assertIn('not FApplication.ShuttingDown', source)
        self.assertIn('if HasApplication then Result := FApplication.FormCount', source)
        app = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn('property TaskHandle: HTASK read FTask', app)
        self.assertIn('property ShuttingDown: Boolean read FShuttingDown', app)

    def test_indexed_order_uses_user_then_unique_registration_fallback(self):
        source = (ROOT / 'src/win16/native_screen.pas').read_text()
        collect = source.split('procedure TNativeScreen.CollectForms', 1)[1].split('function TNativeScreen.GetForm(', 1)[0]
        for text in ('GetTopWindow(0)', 'GetWindowTask(Window) = FTask',
                     'Form.Handle = Window', 'GetWindow(Window, GW_HWNDNEXT)',
                     'if List.IndexOf(Form) < 0 then List.Add(Form)'):
            self.assertIn(text, collect)
        self.assertLess(collect.index('GetTopWindow(0)'), collect.index('if List.IndexOf(Form) < 0'))
        for text in ('CreateHandle(', '.Show;', 'SetActiveWindow(', 'ProcessMessages(', 'OnActivate'):
            self.assertNotIn(text, collect)
        self.assertIn('(Index < 0) or (Index >= GetFormCount)', source)
        self.assertIn('finally Ordered.Free', source)

    def test_focus_is_live_scoped_and_excludes_frame_or_unusable_child(self):
        source = (ROOT / 'src/win16/native_screen.pas').read_text()
        for text in ('Window := GetActiveWindow', 'GetWindowTask(Window) <> FTask',
                     'not IsWindowVisible(Window)', 'not IsWindowEnabled(Window)',
                     'Form.Handle = Window', 'Form.FindControl(GetFocus)',
                     'if Result = Form then Result := nil', 'not Result.CanFocus'):
            self.assertIn(text, source)
        self.assertNotIn('FActiveForm', source)
        self.assertNotIn('FActiveControl', source)

    def test_metrics_read_real_apis_and_release_screen_dc(self):
        source = (ROOT / 'src/win16/native_screen.pas').read_text()
        for text in ('GetSystemMetrics(SM_CXSCREEN)', 'GetSystemMetrics(SM_CYSCREEN)',
                     'Display := GetDC(0)', 'GetDeviceCaps(Display, LOGPIXELSY)',
                     'finally ReleaseDC(0, Display)', "Create('Cannot acquire screen DC')"):
            self.assertIn(text, source)
        self.assertNotIn('Result := 96', source)
        self.assertNotIn('property Canvas:', source)
        self.assertNotIn('property OnActiveFormChange:', source)

    def test_native_profiles_cover_cycle_focus_modal_and_lifetime(self):
        core = (ROOT / 'tests/pascal/test_win16_screen.pas').read_text()
        modal = (ROOT / 'tests/pascal/test_win16_screen_modal.pas').read_text()
        for text in ('bottom-of-pack cycle visits third form', 'reparented focus uses new native form',
                     'failed rebind preserves previous application', 'screen reads are empty during application teardown',
                     'unregistered active frame is not misidentified', 'recreated HWND returns to native front',
                     'screen outlives application without dangling binding'):
            self.assertIn(text, core)
        for text in ('registered modal is active front with edit focus', 'unregistered modal does not impersonate owner',
                     'modal exit restores actual owner and focus view', 'startup error restores screen state',
                     'modal signed quit reaches root'):
            self.assertIn(text, modal)
        make = (ROOT / 'makefile').read_text()
        for name, source in (('screen', core), ('screen-modal', modal)):
            self.assertIn('{$M 4096,2048}', source)
            self.assertIn('Check(StackGuardIntact', source)
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', make)
            self.assertIn(f'$(BUILD_DIR)/tests/win16-{name}/units', make)


if __name__ == '__main__':
    unittest.main()
