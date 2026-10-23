"""Input ABI/source guards; native behavior requires the Win3.1x probe."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16InputTests(unittest.TestCase):
    def test_mouse_uses_signed_record_and_message_button_state(self):
        source = (ROOT / 'src/win16/native_input.pas').read_text()
        for text in ('var M: TWMMouse', 'M.XPos, M.YPos', 'M.Keys and MK_SHIFT',
                     'M.Keys and MK_CONTROL', 'M.Keys and MK_LBUTTON',
                     'M.Keys and MK_RBUTTON', 'M.Keys and MK_MBUTTON',
                     'Include(Shift, ssDouble)', 'GetKeyState(VK_MENU) < 0'):
            self.assertIn(text, source)
        self.assertNotIn('GetAsyncKeyState', source)
        self.assertIn('Info.style := CS_DBLCLKS', (ROOT / 'src/win16/native_window.pas').read_text())

    def test_keyboard_preserves_default_processing_and_consumption(self):
        source = (ROOT / 'src/win16/native_input.pas').read_text()
        for text in ('GetKeyState(VK_SHIFT) < 0', 'GetKeyState(VK_CONTROL) < 0',
                     'M.LParam and $20000000', 'M.WParam := Key',
                     'if Key = 0 then M.Result := 0 else DefaultHandler(M)',
                     'if Key = #0 then M.Result := 0 else DefaultHandler(M)',
                     'if M.WParam > 255 then begin DefaultHandler(M); Exit; end'):
            self.assertIn(text, source)

    def test_focus_and_capture_are_native_not_cached(self):
        source = (ROOT / 'src/win16/native_input.pas').read_text()
        for text in ('GetFocus = Handle', 'GetCapture = Handle', 'IsWindowVisible(Current)',
                     'IsWindowEnabled(Current)', 'Current := GetParent(Current)',
                     'WinProcs.SetFocus(Handle)', 'if GetMouseCapture then ReleaseCapture',
                     'SetCapture(Handle)'):
            self.assertIn(text, source)
        self.assertNotIn('FFocused', source)
        self.assertNotIn('FCapture', source)

    def test_probe_distinguishes_message_delivery_from_real_focus_capture(self):
        source = (ROOT / 'tests/pascal/test_win16_input.pas').read_text()
        for text in ('mouse uses signed Win16 coordinates', 'var Key replacement reaches',
                     'zero Key consumes key down and key up', 'system-key context bit preserves Alt',
                     'packed DBCS character is forwarded without truncation',
                     'input callback exception is contained', 'real focus transfer invokes OnEnter',
                     'disabled ancestor prevents child focus', 'releasing nonowned capture',
                     'native destruction clears focus and capture', 'SetKeyboardState(@Saved)'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-input: fpc-win16-gui-rtl', makefile)
        self.assertIn('check_win16_budget.py $(BUILD_DIR)/tests/win16-input/GDITEST.EXE', makefile)
