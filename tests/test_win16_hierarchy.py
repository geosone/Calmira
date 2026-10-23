"""Scope/transaction guards; actual HWND parenting is checked under Win3.1x."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16HierarchyTests(unittest.TestCase):
    def test_windowed_parenting_is_explicit_and_uses_native_setparent(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        windowed = source.split('TGraphicControl = class(TControl)', 1)[0]
        self.assertIn('property Parent: TCustomControl', windowed)
        for text in ('WinProcs.SetParent(Handle, Value.Handle)',
                     'WinProcs.GetParent(Handle) <> Value.Handle',
                     'IsChild(Handle, Value.Handle)', 'Control parent cycle',
                     'if Current = Self then', 'Previous.FWindows.Remove(Self)',
                     'Value.FWindows.Remove(Self)',
                     'Native reparent rollback failed; HWND detached'):
            self.assertIn(text, source)

    def test_creation_and_teardown_keep_model_separate_from_hwnd_lifetime(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('TCustomControl(FWindows[I]).CreateControl(Handle)',
                     'except DestroyHandle; raise', 'except FParent := Previous; raise',
                     'FWindows[FWindows.Count - 1]).Parent := nil',
                     'procedure TCustomControl.WMNCDestroy',
                     'FChanging := False'):
            self.assertIn(text, source)
        native = (ROOT / 'src/win16/native_window.pas').read_text()
        self.assertIn('X, Y, Width, Height: SmallInt); virtual;', native)

    def test_bounds_are_checked_and_native_updates_refresh_cache(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('LongInt(Value.Right) - Value.Left', 'LongInt(X) + AWidth > 32767',
                     'ScreenToClient(NativeParent, Origin)', 'GetWindowRect(Handle, Area)',
                     'procedure TCustomControl.WMMove', 'procedure TCustomControl.WMSize',
                     'property BoundsRect: TRect', 'property ClientRect: TRect',
                     'if FChanging or Painting or FCompositing or (Canvas.Handle <> 0)'):
            self.assertIn(text, source)

    def test_native_probe_covers_reparent_bounds_and_partial_failure(self):
        source = (ROOT / 'tests/pascal/test_win16_hierarchy.pas').read_text()
        for text in ('recursively creates managed descendant HWNDs',
                     'external USER move and resize update cached model bounds',
                     'live reparent preserves child and descendant handles',
                     'decorated window distinguishes outer dimensions',
                     'detaching destroys HWND subtree but retains descendant objects',
                     'failed auto-creation rolls back object parent membership',
                     'failed deferred descendant creation destroys partial HWND tree',
                     'freeing parent detaches independently owned child objects'):
            self.assertIn(text, source)
