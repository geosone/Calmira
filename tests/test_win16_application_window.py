"""Transport boundaries; the native fixture also starts an independent Win16 task."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ApplicationWindowTests(unittest.TestCase):
    def test_class_registration_checks_callback_extra_bytes_and_module(self):
        source = (ROOT / 'src/win16/native_window.pas').read_text()
        register = source.split('procedure EnsureNativeWindowClass(Name: PChar);', 2)[2]
        for text in ('GetClassInfo(HInstance, Name, Info)',
                     'Move(Info.lpfnWndProc, Actual, SizeOf(Actual))',
                     'Actual <> Pointer(@NativeWindowProc)',
                     'Info.cbWndExtra <> SizeOf(Pointer)', 'Info.hInstance <> HInstance',
                     'Native window class collision'):
            self.assertIn(text, register)

    def test_hidden_identity_is_separate_lazy_and_not_a_main_form_alias(self):
        source = (ROOT / 'src/win16/native_application_window.pas').read_text()
        app = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn("ApplicationClassName = 'TApplication'", source)
        self.assertIn("FTitle := 'Calmira'", source)
        self.assertIn('CreateHandle(0, Title, WS_POPUP, 0, 0, 0, 0)', source)
        self.assertIn('FWindow.EnsureHandle; Result := FWindow.Handle', app)
        self.assertNotIn('Result := FMainForm.Handle', app)
        self.assertIn('FWindow := TNativeApplicationWindow.Create(nil)', app)

    def test_hooks_compare_both_method_pointers_and_lock_mutation(self):
        source = (ROOT / 'src/win16/native_application_window.pas').read_text()
        for text in ('TMethod(A).Code = TMethod(B).Code', 'TMethod(A).Data = TMethod(B).Data',
                     'if Dispatching then raise', 'for Index := FHooks.Count - 1 downto 0',
                     'Inc(FDispatchDepth)', 'finally Dec(FDispatchDepth)',
                     'Dispose(Item)', 'except Dispose(Item); raise'):
            self.assertIn(text, source)
        for signature in ('SetTitle(', 'EnsureHandle;', 'HookMainWindow(', 'UnhookMainWindow('):
            body = source.split('TNativeApplicationWindow.' + signature, 1)[1]
            self.assertIn('CheckMutable;', body.split('\nend;', 1)[0])
        self.assertIn('if PWindowHook(FHooks[Index])^(Message) then Exit', source)

    def test_native_association_teardown_and_close_policy_are_not_swallowed(self):
        source = (ROOT / 'src/win16/native_application_window.pas').read_text()
        dispatch = source.split('procedure TNativeApplicationWindow.WndProc', 1)[1]
        for message in ('WM_NCCREATE', 'WM_CREATE', 'WM_DESTROY', 'WM_NCDESTROY'):
            self.assertIn(message, dispatch)
        self.assertLess(dispatch.index('inherited WndProc(Message); Exit'), dispatch.index('Inc(FDispatchDepth)'))
        self.assertIn('if Message.Msg = WM_CLOSE then', dispatch)
        app = (ROOT / 'src/win16/native_application.pas').read_text()
        self.assertIn('if FMainForm <> nil then CloseMainForm else Terminate', app)
        destroy = app.split('destructor TNativeApplication.Destroy;', 1)[1]
        self.assertLess(destroy.index('FShuttingDown := True'), destroy.index('FWindow.Free'))
        self.assertLess(destroy.index('FWindow.Free'), destroy.index('DetachForm(Form)'))

    def test_title_is_verified_against_user_without_win32_return_assumptions(self):
        source = (ROOT / 'src/win16/native_application_window.pas').read_text()
        self.assertIn('Pos(#0, Value)', source)
        self.assertIn('SetWindowText(Handle, Buffer);', source)  # Win16 API is a procedure
        self.assertIn('GetWindowText(Handle, Buffer, SizeOf(Buffer))', source)
        self.assertIn('if StrPas(Buffer) <> Value then raise', source)

    def test_native_fixture_uses_a_second_executable_and_original_message_contract(self):
        fixture = (ROOT / 'tests/pascal/test_win16_application_window.pas').read_text()
        helper = (ROOT / 'tests/pascal/application_sender.pas').read_text()
        for text in ('foreign class collision rejected', 'dispatch mutation and pump guards',
                     'queued filter can consume before window hook', 'same method distinct receiver',
                     'hook exception stays inside USER boundary', 'full 255-byte title',
                     'cross-task hook and filter separation', 'application close honors main veto',
                     'transport recreates without quitting', 'Check(StackGuardIntact'):
            self.assertIn(text, fixture)
        self.assertIn('{$M 4096,2048}', fixture)
        self.assertIn("FindWindow('TApplication', 'Calmira')", helper)
        self.assertIn('SendMessage(Target, WM_CALMIRA, CM_PREVINSTANCE', helper)
        self.assertIn('PostMessage(Target, WM_CALMIRA, CM_TOGGLEDESKTOP, Reply)', helper)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-application-window-runtime-test: win16-application-window', make)
        self.assertIn('GDI_HELPER_EXE=', make)
        runner = (ROOT / 'tests/dos/test_win16_gdi.sh').read_text()
        self.assertIn('"$GDI_HELPER_EXE" ::/APPSEND.EXE', runner)


if __name__ == '__main__':
    unittest.main()
