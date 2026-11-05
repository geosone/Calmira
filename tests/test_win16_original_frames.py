"""Guards for details measured against the original Calmira Reborn windows."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIN16 = ROOT / 'src/win16'


def source(name):
    return (WIN16 / name).read_text(encoding='cp1252').replace('\r\n', '\n')


class OriginalFrameTests(unittest.TestCase):
    def test_monochrome_glyphs_take_font_and_brush_colours(self):
        # Calmira's caption buttons are monochrome bitmaps drawn with Draw.
        canvas = source('gdi_canvas.pas')
        self.assertIn('SetBkColor(DC, ColorToRGB(FBrush.Color));', canvas)
        self.assertEqual(canvas.count('    DrawColors;\n'), 2)

    def test_header_has_delphis_single_border(self):
        header = source('native_header.pas')
        self.assertIn('property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;',
                      header)
        self.assertIn('if FBorderStyle = bsSingle then Style := Style or WS_BORDER;', header)
        self.assertIn('InflateRect(R, -3, 0);', header)

    def test_grids_get_the_ctl3d_frame(self):
        self.assertIn('function TCustomGrid.Ctl3DFramed: Boolean;\nbegin Result := True; end;', source('grids.pas'))

    def test_latched_speed_buttons_match_the_original_toolbar(self):
        button = source('native_speedbutton.pas')
        self.assertIn('DitherFace(DC, Graphics.Rect(R.Left, R.Top, R.Right + 1, R.Bottom + 1));', button)
        self.assertIn('Shift := Ord(FState = bsDown);', button)

    def test_forms_are_overlapped_and_owned(self):
        # Measured: forms $16CF0000 owned by TApplication $940A0000.
        modal = source('native_modal.pas')
        self.assertNotIn('WS_POPUP', modal)
        self.assertIn('GetWindow(Handle, GW_OWNER)', modal)
        app = source('native_application_window.pas')
        self.assertIn('WS_POPUP or WS_CLIPSIBLINGS or WS_SYSMENU or WS_MINIMIZEBOX', app)

    def test_pop_up_hints_are_on_by_default_below_their_control(self):
        forms = source('forms.pas')
        self.assertIn('  { As Delphi 1\'s TApplication.Create. Calmira never turns pop-up hints on,\n'
                      '    yet the original shows its file and toolbar hints. }\n  ShowHint := True;', forms)
        self.assertIn('Info.HintPos := ControlToScreen(Control, Point(0, ControlHeight(Control) + 6));', forms)

    def test_input_query_matches_the_original_change_description(self):
        dialogs = source('dialogs.pas')
        self.assertIn('QueryWidth = 270; QueryHeight = 95; QueryLeft = MsgMargin; PromptTop = MsgMargin;', dialogs)
        self.assertIn('EditTop = 28; EditWidth = 250; EditHeight = 20; QueryButtonTop = 58; QueryGap = 10;',
                      dialogs)
        self.assertIn('QueryButtonWidth = 77; QueryButtonHeight = 27;', dialogs)
        buttons = source('buttons.pas')
        self.assertIn('if Active then TextFont.Style := TextFont.Style + [fsBold]\n'
                      '  else TextFont.Style := TextFont.Style - [fsBold];', buttons)

    def test_focus_rectangles_take_the_canvas_colours(self):
        canvas = source('gdi_canvas.pas')
        self.assertIn('SetTextColor(DC, ColorToRGB(FFont.Color));', canvas)
        self.assertNotIn('SetTextColor(DC, 0); SetBkColor(DC, $FFFFFF);', canvas)
        self.assertIn('if FBrush.Style = bsClear then SetBkColor(DC, $FFFFFF)\n'
                      '    else SetBkColor(DC, ColorToRGB(FBrush.Color));', canvas)

    def test_grid_keeps_its_focused_cell_while_its_form_is_inactive(self):
        grids = source('grids.pas')
        self.assertIn('Current := GridIsActive(Self);', grids)
        self.assertIn('if Current and (CurRow = Row) and (CurCol = Col) then Include(State, gdFocused);', grids)
        self.assertIn('else Result := (FLastFocus <> 0) and (FLastFocus = Control.Handle);',
                      source('native_form.pas'))

    def test_message_buttons_sit_eight_pixels_apart(self):
        self.assertIn('Margin = 12; IconSize = 32; ButtonGap = 8;', source('dialogs.pas'))

    def test_a_drag_start_cancels_the_grids_selection_mode(self):
        controls = source('controls.pas')
        self.assertIn('if (Previous <> 0) and (Previous <> FCapture.Handle) then\n'
                      '    SendMessage(Previous, WM_CANCELMODE, 0, 0);\n  SetCapture(FCapture.Handle);', controls)
        grids = source('grids.pas')
        self.assertIn('procedure WMCancelMode(var Msg: TMessage); message WM_CANCELMODE;', grids)
        self.assertIn('KillTimer(Handle, SelectTimer);\n    FGridState := gsNormal;', grids)

    def test_common_dialogs_get_delphis_centring_ctl3d_hook(self):
        dialogs = source('dialogs.pas')
        self.assertIn('if HookCtl3D then Subclass3DDlgEx(Wnd, $FFFF);\n    CenterWindow(Wnd);', dialogs)
        self.assertIn('(GetSystemMetrics(SM_CYSCREEN) - Area.Bottom + Area.Top) div 3', dialogs)
        for flag in ('OFN_ENABLEHOOK', 'CC_ENABLEHOOK', 'CF_ENABLEHOOK'):
            self.assertIn(flag, dialogs)
        self.assertIn('OrdSubclassDlgEx = 21;', source('native_ctl3d.pas'))

    def test_drag_source_counts_as_the_capture_control(self):
        self.assertIn('Result := DragSource;\n  if Result <> nil then Exit;', source('controls.pas'))

    def test_combo_lists_open_as_tall_as_their_items(self):
        combo = source('native_combobox.pas')
        self.assertIn('DropDown;\n        AdjustDropDown;', combo)
        self.assertIn('if Count < 1 then Count := 1;', combo)

    def test_caption_is_new_before_wm_settext(self):
        self.assertIn('  FCaption := Value;\n  if Handle <> 0 then\n'
                      '  begin StrPCopy(Buffer, Value); SetWindowText(Handle, Buffer); end;',
                      source('native_form.pas'))

    def test_outline_draws_its_own_focus_and_notifies_before_selecting(self):
        outline = source('outline.pas')
        self.assertIn('DefaultDrawing := False;', outline)
        self.assertIn('FNotifyBeforeSelect := True;', outline)
        grids = source('grids.pas')
        self.assertIn('if FNotifyBeforeSelect then inherited MouseDown(Button, Shift, X, Y);', grids)
        self.assertIn('if not FNotifyBeforeSelect then inherited MouseDown(Button, Shift, X, Y);', grids)

    def test_screen_centred_forms_centre_when_first_shown(self):
        forms = source('forms.pas')
        self.assertIn('procedure TForm.PlaceOnShow;', forms)
        self.assertIn('SetBounds(X, Y, Width, Height);\n  FPosition := poDesigned;', forms)
        self.assertIn('FPendingState := False;\n    PlaceOnShow;', source('native_form.pas'))

    def test_later_siblings_lie_above_earlier_ones(self):
        controls = source('controls.pas')
        self.assertIn('procedure TCustomControl.PlaceInZOrder;', controls)
        self.assertIn('After := HWND_TOP;', controls)
        self.assertIn('inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);\n    try\n      PlaceInZOrder;', controls)
        place = controls[controls.index('procedure TCustomControl.PlaceInZOrder;'):]
        place = place[:place.index('\nend;')]
        self.assertIn('I := FParent.FControls.IndexOf(Self);', place)
        self.assertNotIn('FWindows', place)

    def test_list_boxes_erase_in_their_colour(self):
        self.assertIn('procedure TCustomListBox.CNCtlColor(var M: TMessage);\nbegin\n  M.Result := CtlColorBrush(HDC(M.WParam));',
                      source('native_listbox.pas'))

    def test_spin_arrows_are_delphi_sized(self):
        self.assertIn('Size := 4;\n    if Size > Bottom - Top - 4 then', source('native_spin.pas'))

    def test_disabled_speed_button_captions_are_embossed(self):
        speed = source('native_speedbutton.pas')
        self.assertIn('OffsetRect(TextArea, 1, 1);\n      SetTextColor(DC, ColorToRGB(clBtnHighlight));', speed)
        self.assertNotIn('ColorToRGB(clGrayText)', speed)

    def test_sliders_load_minimum_before_maximum(self):
        slider = (WIN16.parent.parent / 'vcl' / 'slider.pas').read_text(encoding='cp1252')
        self.assertIn("if csLoading in ComponentState then begin fMin := avalue; Exit; end;", slider)
        self.assertIn("if csLoading in ComponentState then begin fMax := avalue; Exit; end;", slider)

    def test_labels_always_break_words_when_painting(self):
        label = source('native_label.pas')
        paint = label[label.index('procedure TLabel.Paint;'):]
        self.assertIn('  Flags := Flags or DT_WORDBREAK;', paint)
        self.assertNotIn('if FWordWrap then Flags := Flags or DT_WORDBREAK;', paint)

    def test_disabled_bitbtn_captions_are_embossed(self):
        buttons = source('buttons.pas')
        self.assertIn('OffsetRect(TextArea, 1, 1);\n      SetTextColor(Item.hDC, ColorToRGB(clBtnHighlight));', buttons)
        self.assertNotIn('ColorToRGB(clGrayText)', buttons)

    def test_forms_repaint_over_what_on_show_drew(self):
        self.assertIn('if Assigned(FOnShow) and IsWindowVisible(Handle) then\n      RedrawWindow(Handle, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or RDW_ALLCHILDREN);',
                      source('native_form.pas'))

    def test_drop_down_combo_strip_takes_parent_colour(self):
        combo = source('native_combobox.pas')
        self.assertIn("procedure CNCtlColor(var M: TMessage); message CN_CTLCOLOR;", combo)
        self.assertIn("if (FStyle in [csDropDown, csSimple]) and (Parent <> nil) then\n    M.Result := TParentAccess(Parent).CtlColorBrush(HDC(M.WParam))", combo)
        self.assertIn("procedure WMCtlColor(var M: TMessage); message WM_CTLCOLOR;", combo)

    def test_modal_form_created_before_choosing_its_owner(self):
        modal = source('native_modal.pas')
        create = modal.index("  if Handle = 0 then\n    CreateHandle(0, Caption,")
        keep = modal.index("  KeepOwner := (OwnerWindow = 0) and (Handle <> 0)")
        self.assertLess(create, keep)

    def test_focused_control_is_entered_after_on_show(self):
        form = source('native_form.pas')
        self.assertIn("Focus := GetFocus;\n    DoShow;", form)
        self.assertIn("if Control <> nil then Control.SelectOnEnter;", form)
        self.assertIn("procedure TEdit.SelectOnEnter;\nbegin\n  if FAutoSelect then SelectAll;", source('native_edit.pas'))
        self.assertIn("Perform(CB_SETEDITSEL, 0, MakeLong(0, $FFFF));", source('native_combobox.pas'))

    def test_message_handler_exceptions_reach_the_application(self):
        window = source('native_window.pas')
        self.assertIn("if not PresentCallbackException(Instance) then Instance.RecordCallbackException(E);", window)
        self.assertIn("CallbackExceptionHandler := HandleException;", source('forms.pas'))
        bitmap = source('gdi_bitmap.pas')
        self.assertIn("{ As Delphi's TBitmap.Draw, an empty bitmap draws nothing. }\n  if FHandle = 0 then Exit;", bitmap)

    def test_automatic_drag_list_selects_as_in_delphi(self):
        listbox = source('native_listbox.pas')
        self.assertIn("(DragMode = dmAutomatic) and Enabled and not Dragging and (Handle <> 0) then\n"
                      "        AutoDragPress(M)", listbox)
        self.assertIn('(Item >= 0) and Selected[Item] then\n  begin BeginDrag(False); Exit; end;', listbox)
        self.assertIn('DefaultHandler(M);\n  if FMultiSelect and Modifier then Exit;\n  BeginDrag(False);', listbox)

    def test_screen_lists_every_live_form(self):
        form = source('native_form.pas')
        self.assertIn('LiveForms.Add(Self);', form)
        self.assertIn('if LiveForms <> nil then LiveForms.Remove(Self);', form)
        screen = source('native_screen.pas')
        self.assertNotIn('FApplication.Forms', screen)
        self.assertNotIn('FApplication.FormCount', screen)

    def test_form_visible_shows_and_hides_with_events(self):
        form = source('native_form.pas')
        self.assertIn('property Visible: Boolean read GetFormVisible write SetFormVisible;', form)
        self.assertIn("if not FChangingForm and (Value <> inherited Visible) and (Value or (Handle <> 0)) then\n"
                      "    if Value then Show else Hide\n  else inherited Visible := Value;", form)

    def test_advanced_tab_click_resolves_as_in_delphi(self):
        # TCustomOutline.Click is protected in Delphi 1's Outline unit, so the
        # bare Click inside `with Outline do` is the form's. FPC would find the
        # outline's and grey out Remove and Modify when the tab first opens.
        sysprop = (WIN16.parent / 'sysprop.pas').read_text(encoding='cp1252').replace('\r\n', '\n')
        self.assertIn('        EndUpdate;\n', sysprop)
        self.assertIn('        Self.Click;\n', sysprop)
        self.assertNotIn('        EndUpdate;\n        Click;\n', sysprop)

    def test_modal_dialogs_pass_messages_to_the_application(self):
        modal = source('native_modal.pas')
        self.assertIn('FModalLoop.PreFilter := ModalMessageFilter;\n    FModalLoop.OnMessage := ProcessDialogMessage;', modal)
        loop = source('native_loop.pas')
        self.assertIn('if Assigned(FPreFilter) then\n    if FPreFilter(Message) then Exit;', loop)
        self.assertIn('ModalMessageFilter := MessageFilter;', source('forms.pas'))


if __name__ == '__main__':
    unittest.main()
