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
        self.assertEqual(source.count('{$IFDEF FPC}'), 1)

    def test_native_suite_is_in_the_regression(self):
        make = read('makefile')
        self.assertIn('-FE$(BUILD_DIR)/wndhooks -oWNDHOOKS.DLL src/wndhooks.dpr', make)
        self.assertIn('win16-lfnfuncs-runtime-test win16-wndhooks-runtime-test \\', make)
        native = read('tests/pascal/test_win16_wndhooks.pas')
        for check in ('all 21 exports are found by the names src/hooks.pas uses',
                      'IsHotKey: Ctrl+Shift+A is a hot key', 'the shell hook reports a new top-level window',
                      'the window procedure hook reports an activation', 'a maximized window ends at YLimit',
                      'the desktop hook reports mouse buttons on the desktop',
                      'ReleaseDesktopHook restores the desktop',
                      'the file monitor reports creating and deleting a file'):
            self.assertIn(check, native)


if __name__ == '__main__':
    unittest.main()
