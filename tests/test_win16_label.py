"""Label/font API scope guards; actual text rendering is native-only."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Win16LabelTests(unittest.TestCase):
    def test_disabled_label_uses_system_color_without_mutating_font(self):
        source = (ROOT / 'src/win16/native_label.pas').read_text()
        self.assertIn('property Enabled;', source)
        self.assertNotIn('\n  published\n', source.split('implementation', 1)[0])
        paint = source.split('procedure TLabel.Paint;', 1)[1]
        self.assertIn('if Enabled then SetTextColor', paint)
        self.assertIn('GetSysColor(COLOR_GRAYTEXT)', paint)
        self.assertNotIn('Font.Color :=', paint)
        probe = (ROOT / 'tests/pascal/test_win16_label.pas').read_text()
        for text in ('disabled label paints system gray', 'reenabling label restores latest stored font color',
                     'showing disabled label preserves disabled appearance', 'Check(StackGuardIntact'):
            self.assertIn(text, probe)
        mnemonic = (ROOT / 'tests/pascal/test_win16_mnemonic.pas').read_text()
        self.assertIn('disabled labels do not consume mnemonic', mnemonic)
        self.assertIn('disabled label yields to duplicate mnemonic', mnemonic)

    def test_label_is_a_real_windowless_subset(self):
        source = (ROOT / 'src/win16/native_label.pas').read_text()
        facade = (ROOT / 'src/win16/stdctrls.pas').read_text()
        for text in ('IFNDEF WIN16', 'TLabel = class(TGraphicControl)',
                     'DrawText(Canvas.Handle', 'DT_WORDBREAK', 'DT_NOPREFIX',
                     'DT_RIGHT', 'DT_CENTER', 'DT_EXPANDTABS'):
            self.assertIn(text, source)
        self.assertIn('TLabel = native_label.TLabel', facade)
        self.assertIn('TButton = native_button.TButton', facade)
        self.assertIn('TEdit = native_edit.TEdit', facade)
        self.assertIn('TCheckBox = native_checkbox.TCheckBox', facade)
        self.assertNotIn('native_edit', source)
        for text in ('AutoSize:', 'ParentFont:'):
            self.assertNotIn(text, source)
        self.assertIn('property FocusControl: TCustomControl', source)

    def test_font_is_owned_and_native_dc_state_is_restored(self):
        source = (ROOT / 'src/win16/native_label.pas').read_text()
        base = (ROOT / 'src/win16/control_base.pas').read_text()
        for text in ('FFont := TGDIFont.Create; FFont.OnChange := FontObjectChanged',
                     'FFont.OnChange := nil', 'if Value = nil then raise'):
            self.assertIn(text, base)
        for text in ('procedure FontChanged; override;', 'SelectObject(Canvas.Handle, Font.Handle)',
                     'State := SaveDC(Canvas.Handle)',
                     'finally RestoreDC(Canvas.Handle, State)',
                     'Pos(#0, Value)', 'SetBkMode(Canvas.Handle, TRANSPARENT)'):
            self.assertIn(text, source)
        changed = source.split('procedure TLabel.FontChanged', 1)[1].split('procedure ', 1)[0]
        self.assertIn('Invalidate', changed)

    def test_font_notifications_suppress_recursion_not_state_changes(self):
        source = (ROOT / 'src/win16/gdi_canvas.pas').read_text()
        for text in ('procedure TGDIResource.Changed',
                     'if FNotifying or not Assigned(FOnChange) then Exit',
                     'try FOnChange(Self); finally FNotifying := False',
                     'property Color: TColor read FColor write SetColor',
                     'FColor := Value; Changed',
                     'FPixelsPerInch := TGDIFont(Source).FPixelsPerInch; Changed'):
            self.assertIn(text, source)

    def test_native_probe_covers_rendering_copy_and_callback_recovery(self):
        source = (ROOT / 'tests/pascal/test_win16_label.pas').read_text()
        for text in ('windowless label paints real left-aligned ANSI glyphs',
                     'right alignment repositions glyphs',
                     'word wrap produces actual additional native text lines',
                     'direct font color change invalidates label',
                     'font assignment deep-copies state and survives source destruction',
                     'font notification suppresses recursion',
                     'font event exception propagates after releasing notification guard',
                     'font replacement and label rendering retain GDI and USER resources'):
            self.assertIn(text, source)
        makefile = (ROOT / 'makefile').read_text()
        self.assertIn('win16-label: fpc-win16-gui-rtl', makefile)
        self.assertIn('win16-label-runtime-test: win16-label', makefile)
