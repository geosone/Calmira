"""Form menu bars, TMemo, TBitBtn kinds, icon streams and TControl helpers."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16FormMenuTests(unittest.TestCase):
    def test_form_owns_its_menu_bar(self):
        source = (ROOT / 'src/win16/forms.pas').read_text()
        for text in ('property Menu: TMainMenu read FMenu write SetMenu;',
                     'function ProcessDialogMessage(var Message: TMsg): Boolean; override;',
                     'if FMenu.IsShortCut(Key) then begin Result := True; Exit; end;',
                     "if (Message.Ctl = 0) and (FMenu <> nil) and FMenu.DispatchCommand(Message.ItemID) then",
                     'function KeyDataToShiftState(KeyData: LongInt): TShiftState;',
                     'property OnPaint: TNotifyEvent read FOnPaint write FOnPaint;'):
            self.assertIn(text, source)
        menus = (ROOT / 'src/win16/menus.pas').read_text()
        self.assertIn('function IsShortCut(var Message: TWMKey): Boolean;', menus)
        self.assertIn('CM_APPSYSCOMMAND = CM_BASE + 23;', (ROOT / 'src/win16/controls.pas').read_text())

    def test_memo_keeps_the_short_string_limit(self):
        source = (ROOT / 'src/win16/native_memo.pas').read_text()
        for text in ('TMemo = class(TEdit)', "raise ENativeWindowError.Create('Memo text exceeds 255 bytes');",
                     'property WordWrap: Boolean read FWordWrap write SetWordWrap default True;',
                     'if not FWantReturns then M.Result := M.Result and not DLGC_WANTALLKEYS;'):
            self.assertIn(text, source)
        form = (ROOT / 'src/win16/native_form.pas').read_text()
        self.assertIn('if (Message.wParam <> VK_TAB) and (Code and DLGC_WANTALLKEYS <> 0) then Exit;', form)

    def test_bit_button_kinds_and_icon_streams(self):
        buttons = (ROOT / 'src/win16/buttons.pas').read_text()
        for text in ('TBitBtnKind = (bkCustom, bkOK, bkCancel, bkHelp, bkYes, bkNo, bkClose,',
                     "if not (csLoading in ComponentState) or (Caption = '') then Caption := KindCaptions[Value];"):
            self.assertIn(text, buttons)
        icon = (ROOT / 'src/win16/gdi_icon.pas').read_text()
        for text in ('procedure LoadFromStream(Stream: TStream);', 'procedure SaveToStream(Stream: TStream);',
                     "StrPCopy(Name, ChangeFileExt(StrPas(Name), '.ICO'));"):
            self.assertIn(text, icon)

    def test_control_helpers_live_on_tcontrol(self):
        base = (ROOT / 'src/win16/control_base.pas').read_text()
        for text in ('function ClientToScreen(const Position: TPoint): TPoint; virtual;',
                     'property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;'):
            self.assertIn(text, base)
        controls = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('procedure InsertControl(AControl: TControl);',
                     'function ControlAtPos(const Pos: TPoint; AllowDisabled: Boolean): TControl;',
                     '    procedure Click; virtual;\n'):
            self.assertIn(text, controls)
        patch = (ROOT / 'tools/patches/fpc-win16-delphi1-types.patch').read_text()
        self.assertIn('+function PtInRect(const rc: TRect; pt: TPoint): BOOL;', patch)
        self.assertIn('+{$if defined(CALMIRA_WIN16_DELPHI1_TYPES) and not defined(SYSTEMUNIT)}', patch)

    def test_calmira_sources_stay_minimal(self):
        for name in ('deskprop', 'taskman'):
            data = (ROOT / 'src' / (name + '.pas')).read_bytes()
            self.assertIn(b'{$IFDEF FPC}Graphics{$ELSE}Classes{$ENDIF}.Rect(', data)
            self.assertEqual(data.count(b'\n'), data.count(b'\r\n'), name)

    def test_native_probe_covers_the_slice(self):
        probe = (ROOT / 'tests/pascal/test_win16_form_menu.pas').read_text()
        for text in ('a menu shortcut clicks its item', 'a freed menu leaves the form',
                     "Lines are the text''s CR/LF-separated lines", 'Tab leaves the memo',
                     'a streamed caption survives Kind', 'ControlAtPos finds the child under the point',
                     'WinProcs.PtInRect takes a const rectangle and answers correctly',
                     'a reloaded icon draws the same pixels and mask'):
            self.assertIn(text, probe)
        regression = (ROOT / 'makefile').read_text().split('win16-fixed-regression:', 1)[1].split('\n\n', 1)[0]
        self.assertIn('win16-form-menu-runtime-test', regression)


if __name__ == '__main__':
    unittest.main()
