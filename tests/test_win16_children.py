"""Mixed visual membership guards; actual dispatch and rollback run on Win3.11."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MixedChildrenTests(unittest.TestCase):
    def test_common_identity_is_real_without_windowless_handle_storage(self):
        base = (ROOT / 'src/win16/control_base.pas').read_text()
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        native = (ROOT / 'src/win16/native_window.pas').read_text()
        self.assertIn('TControl = class(TComponent)', base)
        self.assertIn('TControl = control_base.TControl;', controls)
        self.assertIn('TGraphicControl = class(TControl)', controls)
        self.assertIn('TNativeWindow = class(TControl)', native)
        self.assertNotIn('HWND', base)
        virtuals = set(re.findall(r'(?:procedure|function) (\w+)(?:\([^)]*\))?[^;]*; virtual;', base))
        # One view policy slot plus the bounds pair and the Delphi drag hooks.
        self.assertEqual(virtuals, {'ControlOperation', 'GetControlBounds', 'SetControlBounds',
                                    'DoEndDrag', 'DragOver', 'DragDrop',
                                    'Start', 'Finish', 'Forget'})
        self.assertIn('ControlOperation(Operation: TControlOperation; var Value: Boolean); virtual; abstract;', base)
        for name in ('Show', 'Hide', 'BringToFront', 'SendToBack', 'GetEnabled', 'SetEnabled',
                     'GetVisible', 'SetVisible'):
            self.assertIn(f'TControl.{name}', base)

    def test_membership_is_filtered_by_model_parent_not_component_owner(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('function TCustomControl.IsVisualChild', 1)[1].split(
            'procedure TCustomControl.ControlOperation', 1)[0]
        for text in ('TCustomControl(Child).FParent = Self', 'TGraphicControl(Child).FParent = Self',
                     'IsVisualChild(TControl(FControls[I]))', 'if not IsVisualChild(Child) then Continue',
                     'Invalid control index'):
            self.assertIn(text, body)
        for text in ('Components[', 'ComponentCount', 'FWindows[', 'FGraphics['):
            self.assertNotIn(text, body)
        self.assertIn('property Controls[Index: Integer]: TControl', source)
        self.assertIn('property ControlCount: Integer', source)

    def test_staging_allocates_before_native_changes_and_removes_both_records_on_failure(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        body = source.split('procedure TCustomControl.SetParent', 1)[1].split('function ', 1)[0]
        self.assertLess(body.index('Value.FControls.Add(Self)'), body.index('WinProcs.SetParent('))
        self.assertIn('except FParent := Previous; raise', body)
        self.assertIn('Previous.FWindows.Remove(Self); Previous.FControls.Remove(Self)', body)
        self.assertIn('Value.FWindows.Remove(Self); Value.FControls.Remove(Self)', body)
        self.assertIn('except Value.FControls.Remove(Self); raise', body)
        graphic = source.split('procedure TGraphicControl.SetParent', 1)[1].split('procedure ', 1)[0]
        self.assertLess(graphic.index('Value.FControls.Add(Self)'), graphic.index('FParent := Value'))
        self.assertIn('FParent.Canvas.Handle <> 0', graphic)
        self.assertIn('Value.Canvas.Handle <> 0', graphic)

    def test_common_operations_reuse_existing_type_specific_policies(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for cls in ('TCustomControl', 'TGraphicControl'):
            body = source.split(f'procedure {cls}.ControlOperation', 1)[1].split('end;', 1)[0]
            self.assertIn('coWriteEnabled: SetEnabled(Value)', body)
            self.assertIn('coWriteVisible: SetVisible(Value)', body)
        self.assertIn('coShow: ChangeView(cvaShow)', source)
        self.assertIn('coHide: ChangeView(cvaHide)', source)

    def test_native_fixture_and_budget_are_in_corrected_regression(self):
        probe = (ROOT / 'tests/pascal/test_win16_children.pas').read_text()
        for text in ('{$M 4096,2048}', 'Check(StackGuardIntact',
                     'focus callback cannot see provisional membership',
                     'failed creation restores old mixed position',
                     'original Controls zero Free loop', 'while Host.ControlCount > 0',
                     'common control Show preserves lazy form lifecycle',
                     'common control BringToFront reaches real graphic composition'):
            self.assertIn(text, probe)
        make = (ROOT / 'makefile').read_text()
        self.assertIn('win16-children-runtime-test \\', make)
        self.assertIn('win16-children-runtime-test: win16-children', make)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-children/GDITEST.EXE', make)
