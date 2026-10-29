"""Properties the generated Calmira form loaders set: label sizing, cursors,
double clicks, key preview, checkbox alignment and menu shortcut texts."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def read(name):
    return (ROOT / name).read_text()


class Win16LoaderPropertyTests(unittest.TestCase):
    def test_label_sizes_itself_like_delphi(self):
        source = read('src/win16/native_label.pas')
        for text in ('property AutoSize: Boolean read FAutoSize write SetAutoSize default True;',
                     'if not FAutoSize or (csLoading in ComponentState) then Exit;',
                     'if FAlignment = taRightJustify then Inc(X, Width - Area.Right);',
                     'procedure Loaded; override;', 'property OnDragDrop;', 'property OnDragOver;'):
            self.assertIn(text, source)

    def test_graphic_controls_have_a_cursor_their_parent_shows(self):
        source = read('src/win16/controls.pas')
        for text in ('property Cursor: TCursor read FCursor write SetCursor default crDefault;',
                     'function GraphicCursor(var M: TMessage): Boolean;',
                     'if GraphicCursor(Message) then Exit;',
                     "if not LookupNativeCursor(Value, Handle) then raise ENativeWindowError.Create('Invalid cursor');"):
            self.assertIn(text, source)
        image = read('src/win16/extctrls.pas')
        start = image.index('TImage = class(TGraphicControl)')
        published = image[start:image.index('end;', start)]
        for name in ('OnClick', 'OnDblClick', 'OnMouseDown', 'OnDragDrop', 'OnDragOver'):
            self.assertIn(f'property {name};', published)

    def test_double_clicks_and_edit_styles(self):
        edit = read('src/win16/native_edit.pas')
        for text in ('property HideSelection: Boolean read FHideSelection write SetHideSelection default True;',
                     'if not FHideSelection then Style := Style or ES_NOHIDESEL;',
                     'if M.Msg = WM_LBUTTONDBLCLK then DblClick;',
                     'property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;'):
            self.assertIn(text, edit)
        radio = read('src/win16/native_radio.pas')
        self.assertIn('if Code = BN_CLICKED then Click else DblClick;', radio)
        check = read('src/win16/native_checkbox.pas')
        self.assertIn('property Alignment: TLeftRight read FAlignment write SetAlignment default taRightJustify;', check)

    def test_form_key_preview_and_double_click(self):
        source = read('src/win16/forms.pas')
        for text in ('property KeyPreview: Boolean read FKeyPreview write FKeyPreview default False;',
                     'property AutoScroll: Boolean read FAutoScroll write FAutoScroll default True;',
                     'if not Result and FKeyPreview then Result := PreviewKey(Message);',
                     'if not HandleAllocated or (Message.hwnd = Handle) or not IsChild(Handle, Message.hwnd) then Exit;',
                     'procedure WMLButtonDblClk(var Message: TWMMouse); message WM_LBUTTONDBLCLK;'):
            self.assertIn(text, source)

    def test_menu_shortcut_text_and_help_contexts(self):
        source = read('src/win16/menus.pas')
        for text in ('property ShortCutText: string read FShortCutText write SetShortCutText;',
                     "if Item.FShortCutText <> '' then Caption := Caption + #9 + Item.FShortCutText",
                     'function GetHelpContext(Value: Word; ByCommand: Boolean): LongInt;',
                     'property HelpContext: LongInt read GetPopupHelpContext write SetPopupHelpContext default 0;'):
            self.assertIn(text, source)

    def test_loaders_always_see_graphics_and_controls(self):
        self.assertIn("IMPLICIT_UNITS = ('Graphics', 'Controls')", read('tools/dfm_loader.py'))

    def test_native_suite_is_in_the_regression(self):
        make = read('makefile')
        self.assertIn('win16-loader-props-runtime-test: win16-loader-props', make)
        self.assertIn('win16-form-menu-runtime-test win16-loader-props-runtime-test', make)
        native = read('tests/pascal/test_win16_loader_props.pas')
        for check in ('an AutoSize label fits its caption', 'a loading label keeps its streamed size',
                      "the parent shows a graphic control''s Cursor", 'TEdit.OnDblClick fires',
                      'BN_DOUBLECLICKED fires TRadioButton.OnDblClick', 'KeyPreview: clearing Key consumes it',
                      'ShortCutText takes precedence over ShortCut',
                      'GetHelpContext falls back to the parents and the popup menu'):
            self.assertIn(check, native)


if __name__ == '__main__':
    unittest.main()
