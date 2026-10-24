"""TTimer and form CreateParams guards."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16TimerTests(unittest.TestCase):
    def test_timer_follows_delphi_interface(self):
        source = (ROOT / 'src/win16/extctrls.pas').read_text()
        for text in ('TTimer = class(TComponent)',
                     'property Enabled: Boolean read FEnabled write SetEnabled default True;',
                     'property Interval: Word read FInterval write SetInterval default 1000;',
                     'if (FInterval <> 0) and FEnabled and Assigned(FOnTimer) then',
                     "raise EOutOfResources.Create('Not enough timers available');",
                     'try Timer; except Application.HandleException(Self); end;'):
            self.assertIn(text, source)

    def test_create_params_only_changes_what_the_port_honours(self):
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('TCreateParams = record', controls)
        forms = (ROOT / 'src/win16/forms.pas').read_text()
        for text in ('procedure CreateParams(var Params: TCreateParams); virtual;',
                     'if Params.WndParent = GetDesktopWindow then Params.WndParent := 0;',
                     "raise ENativeWindowError.Create('Owned forms are not provided');",
                     "raise ENativeWindowError.Create('Only Caption, Style, bounds and WndParent can change in CreateParams');"):
            self.assertIn(text, forms)

    def test_native_probe_covers_timer_and_create_params(self):
        probe = (ROOT / 'tests/pascal/test_win16_timer.pas').read_text()
        for text in ('an enabled timer with OnTimer ticks', 'Interval 0 stops the timer',
                     'without OnTimer nothing runs', 'a failing OnTimer is reported and the timer goes on',
                     'the desktop as WndParent leaves the form unowned', 'an owner window raises'):
            self.assertIn(text, probe)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-timer-runtime-test',
                      makefile.split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0])


if __name__ == '__main__':
    unittest.main()
