"""WNDHOOKS.DLL builds from the original src/wndhooks.dpr and its hooks run
under Windows 3.11."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(name, encoding='utf-8'):
    return (ROOT / name).read_text(encoding=encoding)


class Win16WndHooksTests(unittest.TestCase):
    def test_original_source_only_adds_win31(self):
        source = (ROOT / 'src/wndhooks.dpr').read_bytes().decode('latin-1')
        self.assertIn('uses {$IFDEF FPC}Win31, {$ENDIF}WinProcs, WinTypes, Messages, CalMsgs;\r\n', source)
        # And, for the CTL3D dialog hook, KERNEL's GetProcAddress by ordinal.
        self.assertEqual(source.count('{$IFDEF FPC}'), 2)
        self.assertIn('{$IFDEF FPC}WinGetProcAddress{$ELSE}GetProcAddress{$ENDIF}', source)

    def test_ctl3d_dialogs_for_every_program_are_optional(self):
        # [Preferences] Ctl3DDialogs=1: a WH_CALLWNDPROC hook subclasses the
        # standard dialogs of other programs with CTL3DV2.DLL on WM_INITDIALOG.
        source = (ROOT / 'src/wndhooks.dpr').read_bytes().decode('latin-1')
        for text in ("(lstrcmp(ClassName, '#32770') = 0)", 'Ctl3DSubclassDlgEx(hWnd, $FFFF);',
                     "LoadLibrary('CTL3DV2.DLL')", 'SetCtl3DDialogs index 22;',
                     '(GetWindowTask(hWnd) <> Ctl3DOwnTask)'):
            self.assertIn(text, source)
        hooks = (ROOT / 'src/hooks.pas').read_bytes().decode('latin-1')
        self.assertIn("@SetCtl3DDialogs     := GetProcAddress(WndHookDLL, 'SETCTL3DDIALOGS');", hooks)
        self.assertIn('if Assigned(SetCtl3DDialogs) then SetCtl3DDialogs(False);', hooks)
        self.assertIn('if Assigned(SetCtl3DDialogs) then SetCtl3DDialogs(Ctl3DDialogs);',
                      (ROOT / 'src/compsys.pas').read_bytes().decode('latin-1'))
        settings = (ROOT / 'src/settings.pas').read_bytes().decode('latin-1')
        self.assertIn("Ctl3DDialogs := ReadBool('Preferences', 'Ctl3DDialogs', False);", settings)
        ini = (ROOT / 'src/calmira.ini').read_bytes().decode('latin-1').replace('\r\n', '\n')
        self.assertIn('\nCtl3DDialogs=0\n', ini)
        make = read('makefile')
        for target in ('win16-plain-dialogs-runtime-test', 'win16-ctl3d-dialogs-runtime-test'):
            self.assertIn(' ' + target + ' ', make)
        native = read('tests/pascal/test_win16_ctl3d_dialogs.pas')
        self.assertIn("'CTL3D gives the dialog of another program its grey face'", native)
        self.assertIn("'the dialog of another program keeps its Windows 3.1 face'", native)

    def test_native_suite_is_in_the_regression(self):
        make = read('makefile')
        self.assertIn('-FE$(BUILD_DIR)/wndhooks -oWNDHOOKS.DLL src/wndhooks.dpr', make)
        self.assertIn('win16-lfnfuncs-doslfn-runtime-test win16-wndhooks-runtime-test \\', make)
        native = read('tests/pascal/test_win16_wndhooks.pas')
        for check in ('all 22 exports are found by the names src/hooks.pas uses',
                      'IsHotKey: Ctrl+Shift+A is a hot key', 'the shell hook reports a new top-level window',
                      'the window procedure hook reports an activation', 'a maximized window ends at YLimit',
                      'the desktop hook reports mouse buttons on the desktop',
                      'ReleaseDesktopHook restores the desktop',
                      'the file monitor reports creating and deleting a file'):
            self.assertIn(check, native)


if __name__ == '__main__':
    unittest.main()
