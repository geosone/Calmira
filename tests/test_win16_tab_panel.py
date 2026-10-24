"""Panel, Tabs and Calmira TTabPanel compatibility guards."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16TabPanelTests(unittest.TestCase):
    def test_panel_follows_delphi_interface(self):
        source = (ROOT / 'src/win16/extctrls.pas').read_text()
        for text in ('TPanelBevel = (bvNone, bvLowered, bvRaised);',
                     'TCustomPanel = class(TCustomControl)', 'TPanel = class(TCustomPanel)',
                     'property BevelOuter: TPanelBevel read FBevelOuter write SetBevelOuter default bvRaised;',
                     'property Alignment: TAlignment read FAlignment write SetAlignment default taCenter;',
                     'procedure AlignControls(AControl: TControl; var Rect: TRect); override;',
                     '{ Not WinProcs.PtInRect: its POINT-by-value call fails on Win16. }'):
            self.assertIn(text, source)

    def test_tabs_unit_declares_types_without_tab_set(self):
        source = (ROOT / 'src/win16/tabs.pas').read_text()
        self.assertIn('TTabChangeEvent = procedure(Sender: TObject; NewTab: Integer;', source)
        self.assertNotIn('TTabSet', source.split('implementation', 1)[0].split('}', 1)[1])

    def test_focus_change_is_broadcast_to_the_form(self):
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        self.assertIn('CM_FOCUSCHANGED = CM_BASE + 7;', controls)
        self.assertIn('TCMFocusChanged = record', controls)
        forms = (ROOT / 'src/win16/forms.pas').read_text()
        self.assertIn('procedure BroadcastFocusChanged(Control, Focused: TCustomControl);', forms)

    def test_tab_panel_source_keeps_crlf_and_guards_control_style(self):
        data = (ROOT / 'vcl/tabpanel.pas').read_bytes()
        self.assertEqual(data.count(b'\n'), data.count(b'\r\n'))
        self.assertIn(b'  {$IFNDEF FPC}\r\n  ControlStyle := ControlStyle + [csDesignInteractive, csOpaque];\r\n'
                      b'  {$ENDIF}\r\n', data)

    def test_native_probe_covers_panel_and_tab_panel(self):
        probe = (ROOT / 'tests/pascal/test_win16_tab_panel.pas').read_text()
        for text in ('aligned children stay inside both bevels and the border',
                     'a press released inside fires OnClick', 'OnChange can refuse a tab',
                     'turning the notebook moves the tab silently', 'clicking a tab selects it',
                     "focusing a control tells the form''s controls", 'arrow keys cycle through the tabs',
                     'freeing the notebook unlinks it'):
            self.assertIn(text, probe)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-tab-panel-runtime-test',
                      makefile.split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0])


if __name__ == '__main__':
    unittest.main()
