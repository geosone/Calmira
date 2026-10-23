"""Activation/focus contract guards; native USER tests establish behavior."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FormActivationTests(unittest.TestCase):
    def test_activation_and_focus_are_live_not_cached_borrowed_references(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        for text in ('GetWindowTask(Handle) = GetCurrentTask', 'GetActiveWindow = Handle',
                     'Result := FindControl(GetFocus)', 'if Result = Self then Result := nil',
                     'if not Result.CanFocus then Result := nil',
                     'property Active: Boolean', 'property ActiveControl: TCustomControl'):
            self.assertIn(text, source)
        for text in ('FActiveControl:', 'FActive:', 'unit Forms;'):
            self.assertNotIn(text, source)
        getters = source.split('function TNativeForm.GetActive:', 1)[1].split(
            'procedure TNativeForm.SetActiveControl(', 1)[0]
        self.assertNotIn('SetActiveWindow(', getters)
        self.assertEqual(source.count('SetActiveWindow('), 1)
        view = source.split('procedure TNativeForm.ChangeView(', 1)[1].split(
            'procedure TNativeForm.HideWindow;', 1)[0]
        self.assertIn('(Action = cvaFront) and Enabled then SetActiveWindow(Handle)', view)

    def test_focus_assignment_validates_native_and_model_ancestry_before_callbacks(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        setter = source.split('procedure TNativeForm.SetActiveControl(', 1)[1].split(
            'procedure TNativeForm.DoActivate;', 1)[0]
        for text in ('FChangingActiveControl or not Active', 'not ContainsControl(Value)',
                     'FindControl(Value.Handle) <> Value', 'not Value.CanFocus',
                     'FChangingActiveControl := True',
                     'if Value = nil then SetFocus else Value.SetFocus',
                     'finally FChangingActiveControl := False'):
            self.assertIn(text, setter)
        self.assertLess(setter.index('FindControl(Value.Handle)'), setter.index('FChangingActiveControl := True'))
        self.assertNotIn('CreateHandle(', setter)
        self.assertNotIn('FInitialControl :=', setter)

    def test_activation_preserves_user_default_before_events_and_releases_guards(self):
        source = (ROOT / 'src/win16/native_form.pas').read_text()
        body = source.split('procedure TNativeForm.WMActivate(', 1)[1].split(
            'function TNativeForm.CloseQuery:', 1)[0]
        for text in ('FActivationDepth >= 32', 'Inc(FActivationDepth)',
                     'WA_INACTIVE: DoDeactivate', 'WA_ACTIVE, WA_CLICKACTIVE: DoActivate',
                     'finally Dec(FActivationDepth)', 'DefaultHandler(M)'):
            self.assertIn(text, body)
        self.assertLess(body.index('DefaultHandler(M)'), body.index('DoActivate'))
        self.assertIn('(FActivationDepth <> 0)', source)
        self.assertNotIn('except', body)

    def test_native_profile_exercises_nested_failures_modal_restore_and_lifetime(self):
        source = (ROOT / 'tests/pascal/test_win16_form_activation.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'already-active USER request emits no duplicate transition',
                     'activation handler focuses edit', 'foreign focus assignment preserves native focus',
                     'focus callback cannot recursively assign active control',
                     'activation exception stays inside USER boundary',
                     'deactivation exception preserves native transition',
                     'nested cross-form activation follows live USER state',
                     'modal exit restores owner activation and child focus',
                     'freed focused child leaves no cached pointer',
                     'repeated activation retains USER and GDI resources'):
            self.assertIn(text, source)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-form-activation-runtime-test: win16-form-activation', make)
        self.assertIn('tests/win16-form-activation/units', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-form-activation/GDITEST.EXE', make)


if __name__ == '__main__':
    unittest.main()
