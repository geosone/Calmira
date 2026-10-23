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
        interface = source.split('unit Forms;', 1)[1].split('implementation', 1)[0]
        for name in ('property Icon', 'property Menu', 'HintColor', 'FormStyle'):
            self.assertNotIn(name, interface)
        self.assertIn("raise ENativeScreenError.Create('Invalid screen form')", source)

    def test_native_suite_is_part_of_fixed_regression(self):
        makefile = (ROOT / 'makefile').read_text()
        regression = makefile.split('win16-fixed-regression: fpc-win16-fixed-compiler', 1)[1].split('\n\n', 1)[0]
        self.assertIn('win16-forms-runtime-test', regression)
        self.assertIn('tests/pascal/test_win16_forms.pas', makefile)


if __name__ == '__main__':
    unittest.main()
