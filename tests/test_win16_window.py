"""Scope/ABI guards; native behavior is verified by test_win16_window.pas."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16WindowTests(unittest.TestCase):
    def test_association_uses_full_far_pointer_in_private_window_bytes(self):
        source = (ROOT / 'src/win16/native_window.pas').read_text()
        for text in ('Info.cbWndExtra := SizeOf(Pointer)',
                     'PCREATESTRUCT(Pointer(LP))^.lpCreateParams',
                     'SetWindowLong(Window, ObjectOffset, LongInt(Pointer(Instance)))',
                     'TNativeWindow(Pointer(GetWindowLong(Window, ObjectOffset)))',
                     'GetClassWord(Window, GCW_CBWNDEXTRA) - SizeOf(Pointer)',
                     'Parent, HMENU(Id), HInstance, Pointer(Self)'):
            self.assertIn(text, source)
        self.assertNotIn('SetWindowWord', source)

    def test_callback_boundary_records_errors_and_always_detaches(self):
        source = (ROOT / 'src/win16/native_window.pas').read_text()
        for text in ('finally\n    if Id = WM_NCDESTROY then',
                     'SetWindowLong(Window, ObjectOffset, 0)', 'Instance.FHandle := 0',
                     'Instance.RecordCallbackException(E)', 'RecordCallbackError(E.Message)',
                     "RecordCallbackError('Non-Exception callback failure')",
                     'if Id = WM_CREATE then Message.Result := -1',
                     'if FCallbackErrors < High(Word)', 'FHandle := 0;'):
            self.assertIn(text, source)
        self.assertIn('Result := DefWindowProc(FHandle, Msg, WParam, LParam)', source)
        self.assertIn('begin Dispatch(Message); end', source)

    def test_native_probe_covers_lifecycle_reentrancy_and_failure(self):
        source = (ROOT / 'tests/pascal/test_win16_window.pas').read_text()
        for text in ('separate windows bind objects before WM_CREATE',
                     'nested SendMessage dispatch targets peer instance',
                     'reentrant creation binds child without replacing parent receiver',
                     'unhandled messages reach DefWindowProc',
                     'callback exceptions are recorded without unwinding USER',
                     'parent destruction detaches parent and child objects',
                     'NC destroy exception still clears handle association',
                     'WM_CREATE exception aborts creation without stale handle',
                     'WM_NCCREATE exception aborts creation without stale handle',
                     'component owner frees its native windows', 'GFSR_USERRESOURCES'):
            self.assertIn(text, source)

    def test_foundation_does_not_fake_controls_or_forms(self):
        foundation = (ROOT / 'src/win16/native_window.pas').read_text()
        self.assertIn('unit native_window;', foundation)
        self.assertIn('TNativeWindow = class(TControl)', foundation)
        self.assertNotIn('TForm = class', foundation)
        source = (ROOT / 'makefile').read_text()
        self.assertIn('win16-window: fpc-win16-gui-rtl', source)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-window/GDITEST.EXE', source)
