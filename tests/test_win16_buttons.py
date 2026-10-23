"""Native button/PicBtn scope guards; input and drawing acceptance are Win16."""
from pathlib import Path
import unittest

from test_win16_handles import active_source

ROOT = Path(__file__).resolve().parents[1]


class Win16ButtonTests(unittest.TestCase):
    def test_superclass_keeps_user_bytes_and_appends_far_object_association(self):
        source = (ROOT / 'src/win16/native_window.pas').read_text()
        for text in ('GetClassInfo(0, SourceName, Info)',
                     'Inc(Info.cbWndExtra, SizeOf(Pointer))',
                     'Info.style := Info.style and not CS_GLOBALCLASS',
                     'GetClassWord(Window, GCW_CBWNDEXTRA) - SizeOf(Pointer)',
                     'GetWindowLong(Window, ObjectOffset)',
                     'SetWindowLong(Window, ObjectOffset, 0)',
                     'function TNativeWindow.NativeClassName'):
            self.assertIn(text, source)
        self.assertNotIn('GWL_WNDPROC', source)

    def test_parent_routes_only_managed_direct_child_commands_and_draw_items(self):
        source = (ROOT / 'src/win16/controls.pas').read_text()
        for text in ('function TCustomControl.FindWindowedChild',
                     'WinProcs.GetParent(Window) <> Handle',
                     'TCustomControl(FWindows[I]).Handle = Window',
                     'M.ItemID = Word(GetDlgCtrlID(M.Ctl))', 'Child.ControlCommand(M.NotifyCode)',
                     'M.DrawItemStruct^.hwndItem', 'Child.ControlDrawItem(M.DrawItemStruct^)',
                     'finally FCompositing := Previous'):
            self.assertIn(text, source)

    def test_button_uses_real_user_procedure_input_and_font(self):
        source = (ROOT / 'src/win16/native_button.pas').read_text()
        for text in ("RegisterNativeSuperclass('BUTTON'", 'CallWindowProc(ButtonProcedure',
                     '(M.Msg = WM_PAINT) or (M.Msg = WM_ERASEBKGND)',
                     'Result := Code = BN_CLICKED', 'Result and Enabled and Visible',
                     'Perform(WM_SETFONT, NativeFont, 0)', 'Canvas.Font.OnChange := FontChanged',
                     'try FontChanged(Self); except DestroyHandle; raise',
                     'Perform(WM_SETFONT, GetStockObject(SYSTEM_FONT), 0)',
                     'if FDrawing then raise', 'finally Canvas.Handle := Previous; FDrawing := False'):
            self.assertIn(text, source)
        std = (ROOT / 'src/win16/stdctrls.pas').read_text()
        self.assertIn('TButton = native_button.TButton', std)
        self.assertNotIn('BS_PUSHBUTTON', (ROOT / 'src/win16/native_input.pas').read_text())

    def test_bitmap_button_has_owned_glyph_and_native_state_driven_layout(self):
        source = (ROOT / 'src/win16/buttons.pas').read_text()
        for text in ('TBitBtn = class(TButton)', 'Result := BS_OWNERDRAW',
                     'FGlyph := Graphics.TBitmap.Create', 'FGlyph.Assign(Value)',
                     'FGlyph.OnChange := nil; FGlyph.Free',
                     'ODS_SELECTED', 'ODS_DISABLED or ODS_GRAYED', 'Frame := 1', 'Frame := 2',
                     'Canvas.CopyTransparent(Target, FGlyph.Canvas, Source, Key)',
                     'DT_CALCRECT or DT_SINGLELINE', 'FreeSpace := FreeSpace div 3',
                     'LongInt(R.Right) - FMargin - GroupW', 'LongInt(R.Bottom) - FMargin - GroupH'):
            self.assertIn(text, source)

    def test_original_picbtn_keeps_loading_policy_without_fake_dialog_globals(self):
        fpc = active_source('vcl/picbtn.pas')
        old = active_source('vcl/picbtn.pas', False)
        for text in ('TPicBtn = class(TBitBtn)', 'procedure TPicBtn.Loaded',
                     'Glyph := nil', 'Height := Height - PicBtnHeightDelta',
                     'Margin := 4', 'Spacing := -1'):
            self.assertIn(text, fpc)
            self.assertIn(text, old)
        self.assertNotIn('MsgDlgGlyphs', fpc)
        self.assertNotIn('procedure PicBtnGlyphsChanged', fpc)
        self.assertIn('MsgDlgGlyphs := PicBtnGlyphs', old)

    def test_native_button_probe_covers_clicks_keyboard_routing_and_lifetime(self):
        source = (ROOT / 'tests/pascal/test_win16_button.pas').read_text()
        for text in ('native focused Space key activates button',
                     'native release outside button cancels click',
                     'disabled button ignores direct and routed activation',
                     'unmanaged child notification never interprets foreign window bytes',
                     'click exception is contained by receiving parent callback boundary',
                     'managed recreation restores button association and native click behavior'):
            self.assertIn(text, source)

    def test_native_bitmap_probe_covers_original_loading_states_and_cleanup(self):
        source = (ROOT / 'tests/pascal/test_win16_bitbtn.pas').read_text()
        for text in ('original PicBtn Loaded removes disabled glyphs',
                     'native pressed state selects pressed strip frame',
                     'disabled native state selects supplied disabled glyph frame',
                     'explicit right margin is measured inward',
                     'explicit bottom margin is measured inward',
                     'owner-draw failure is contained by parent and releases DC',
                     'bitmap button redraw and activation cycles retain USER and GDI resources'):
            self.assertIn(text, source)

    def test_progress_profiles_share_flow_but_keep_separate_units_and_memory_budgets(self):
        picture = (ROOT / 'tests/pascal/test_win16_progress_ui.pas').read_text()
        button = (ROOT / 'tests/pascal/test_win16_progress_button.pas').read_text()
        for source in (picture, button):
            self.assertIn('{$M 4096,1024}', source)
            self.assertIn('{$I progress_ui_probe.inc}', source)
        self.assertIn('{$DEFINE PROGRESS_BUTTON}', button)
        self.assertNotIn('{$DEFINE PROGRESS_BUTTON}', picture)
        common = (ROOT / 'tests/pascal/progress_ui_probe.inc').read_text()
        self.assertIn('PostMessage(CancelButton.Handle, WM_LBUTTONDOWN', common)
        self.assertIn('PostMessage(CancelButton.Handle, WM_LBUTTONUP', common)
        self.assertIn('procedure TProgressProbe.CancelClicked', common)
        self.assertIn('native Cancel stops progress at step 5', common)
