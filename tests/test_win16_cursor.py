"""Cursor ABI, ownership and guard checks; behavior is exercised on Windows 3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeCursorTests(unittest.TestCase):
    def test_common_cursor_dispatch_stays_small_and_retains_native_stock_choices(self):
        source = (ROOT / 'src/win16/native_cursors.pas').read_text()
        for text in ('TCursor = SmallInt', 'crDefault = 0; crNone = -1;',
                     'crHourGlass = -11', 'LoadCursor(0, Resource)',
                     'crIBeam: Resource := IDC_IBEAM', 'crSizeWE: Resource := IDC_SIZEWE',
                     'if Index = crNone then Exit'):
            self.assertIn(text, source)
        self.assertNotIn('class(', source)
        self.assertNotIn('Classes', source)
        self.assertNotIn('ShowCursor(', source)

    def test_pointer_target_uses_scalar_point_abi_and_client_hit_testing(self):
        source = (ROOT / 'src/win16/native_cursors.pas').read_text()
        for text in ("PackedWindowFromPoint(Value: LongInt): HWND; external 'USER' name 'WINDOWFROMPOINT'",
                     'GetCursorPos(@Position)', 'LongInt(Word(Position.X))',
                     'Result := GetCapture', 'GetWindowTask(Result) <> GetCurrentTask',
                     'WM_NCHITTEST', 'if HitTest = HTCLIENT then'):
            self.assertIn(text, source)
        self.assertNotIn('WindowFromPoint(Position)', source)

    def test_provider_is_task_scoped_single_owner_and_removed_only_by_owner(self):
        source = (ROOT / 'src/win16/native_cursors.pas').read_text()
        for text in ('(ProviderOwner = nil) or (ProviderOwner = Owner)',
                     '(ProviderOwner = Owner) and (ProviderTask = GetCurrentTask)',
                     'Resolver := nil; ProviderOwner := nil; ProviderTask := 0',
                     'ProviderTask <> GetCurrentTask'):
            self.assertIn(text, source)

    def test_native_cursor_dispatch_is_inside_the_existing_user_exception_boundary(self):
        source = (ROOT / 'src/win16/native_window.pas').read_text()
        callback = source.split('function NativeWindowProc(', 1)[1].split('procedure RegisterNativeSuperclass', 1)[0]
        self.assertLess(callback.index('try'), callback.index('ApplyNativeCursor('))
        self.assertLess(callback.index('Instance.FDestroying'), callback.index('ApplyNativeCursor('))
        self.assertLess(callback.index('ApplyNativeCursor('), callback.index('Instance.WndProc(Message)'))
        self.assertIn('Instance.RecordCallbackException(E)', callback)
        self.assertIn('Info.hCursor := LoadCursor(0, IDC_ARROW)', source)

    def test_per_control_cursor_validates_before_commit_and_preserves_system_nonclient(self):
        source = (ROOT / 'src/win16/native_input.pas').read_text()
        setter = source.split('procedure TNativeInputWindow.SetCursor(', 1)[1].split('procedure TNativeInputWindow.WMSetCursor', 1)[0]
        self.assertLess(setter.index('FChangingCursor := True'), setter.index('LookupNativeCursor('))
        self.assertLess(setter.index('LookupNativeCursor('), setter.index('FCursor := Value'))
        self.assertIn('finally FChangingCursor := False', setter)
        for text in ('SmallInt(Word(M.LParam)) = HTCLIENT', 'FCursor <> crDefault',
                     'IsChild(Handle, Target)', 'DefaultHandler(M)'):
            self.assertIn(text, source)

    def test_policy_borrows_handles_and_guards_full_stack_mutation(self):
        source = (ROOT / 'src/win16/native_cursor_policy.pas').read_text()
        self.assertNotIn('DestroyCursor(', source)
        for text in ('(FCursor = Index)', 'PSavedCursor(FStack[I])^ = Index',
                     "Create('Empty cursor stack')", 'FLastWindow := Target',
                     'if FTask <> GetCurrentTask then Exit', 'HitTest <> HTCLIENT'):
            self.assertIn(text, source)
        for name in ('SetCursor(Value:', 'PushCursor(Value:', 'PopCursor;'):
            body = source.split('procedure TNativeCursorPolicy.' + name, 1)[1].split('\nend;', 1)[0]
            self.assertLess(body.index('FChanging := True'), body.index('RequiredCursor('))
            self.assertIn('finally FChanging := False', body)
        self.assertIn('RemoveCursorProvider(Pointer(Self)); FEnabled := False', source)

    def test_screen_binding_teardown_resets_cursor_without_automatic_constructor_install(self):
        source = (ROOT / 'src/win16/native_screen.pas').read_text()
        constructor = source.split('constructor TNativeScreen.Create', 1)[1].split('function TNativeScreen.CursorWindowAllowed', 1)[0]
        self.assertNotIn('.Enable', constructor)
        self.assertIn('FCursors := TNativeCursorPolicy.Create(CursorWindowAllowed)', constructor)
        self.assertIn('begin FCursors.Reset; FApplication := nil', source)
        self.assertIn('FCursors.Free; FCursors := nil', source)
        scope = source.split('function TNativeScreen.CursorWindowAllowed', 1)[1].split('function TNativeScreen.GetCursor', 1)[0]
        for text in ('HasApplication', 'IsWindowVisible(Window)', 'GetWindowTask(Window) <> FTask',
                     'IsChild(Form.Handle, Window)'):
            self.assertIn(text, scope)

    def test_native_profiles_cover_real_handles_nesting_ownership_capture_and_modal_quit(self):
        core = (ROOT / 'tests/pascal/test_win16_cursor.pas').read_text()
        modal = (ROOT / 'tests/pascal/test_win16_cursor_modal.pas').read_text()
        for text in ('packed POINT hit testing finds real EDIT', 'nested none cursor hides image',
                     'caller retains borrowed cursor destruction', 'saved custom cursor cannot be removed',
                     'cursor mutation from hit-test callback is rejected', 'cursor display count is unchanged',
                     'second screen cannot steal cursor controller', 'application destruction cancels cursor policy'):
            self.assertIn(text, core)
        for text in ('registered modal inherits screen busy override', 'unregistered modal retains native cursor',
                     'popup does not inherit owner control cursor', 'modal startup failure preserves outer cursor',
                     'cursor modal signed quit reaches root'):
            self.assertIn(text, modal)
        make = (ROOT / 'makefile').read_text()
        for name, source in (('cursor', core), ('cursor-modal', modal)):
            self.assertIn('{$M 4096,2048}', source)
            self.assertIn('Check(StackGuardIntact', source)
            self.assertIn(f'win16-{name}-runtime-test: win16-{name}', make)
            self.assertIn(f'$(BUILD_DIR)/tests/win16-{name}/units', make)


if __name__ == '__main__':
    unittest.main()
