"""Guards for the Delphi 1 CTL3D look: dialog frames, child frames and message dialogs."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIN16 = ROOT / 'src/win16'


def source(name):
    return (WIN16 / name).read_text(encoding='cp1252').replace('\r\n', '\n')


class Ctl3DTest(unittest.TestCase):
    def test_ctl3d_loads_by_ordinal_through_kernel(self):
        unit = source('native_ctl3d.pas')
        # The RTL's GetProcAddress takes a string; KERNEL's is WinGetProcAddress.
        self.assertIn('WinGetProcAddress(Ctl3DHandle, MakeIntResource(Ordinal))', unit)
        self.assertNotRegex(unit, r'(?<!Win)GetProcAddress\(')
        for name, ordinal in (('OrdRegister', 12), ('OrdUnregister', 13), ('OrdBtnWndProc', 7),
                              ('OrdCtlColorEx', 18), ('OrdDlgFramePaint', 20)):
            self.assertRegex(unit, rf'\b{name} = {ordinal}\b')
        self.assertIn("LoadLibrary('CTL3DV2.DLL')", unit)
        self.assertIn('SetErrorMode(SEM_NOOPENFILEERRORBOX)', unit)

    def test_dialog_forms_get_the_modal_frame_ctl3d_paints(self):
        forms = source('forms.pas')
        self.assertIn('bsDialog: Result := WS_CAPTION or WS_DLGFRAME or DS_MODALFRAME;', forms)
        self.assertIn('if FBorderStyle = bsDialog then Result := WS_EX_DLGMODALFRAME else Result := 0;', forms)
        self.assertIn('Message.Result := Ctl3DDlgFramePaint(Handle, Message.Msg, Message.WParam, Message.LParam);', forms)
        # Before the form's own handlers, as Delphi 1: ExtForm's caption
        # must not paint over the CTL3D frame of Start Menu Properties.
        frame = forms.split('function TForm.PaintFrameFirst(var Message: TMessage): Boolean;', 1)[1].split('\nend;', 1)[0]
        self.assertIn('Ctl3DDlgFramePaint(Handle, Message.Msg, Message.WParam, Message.LParam)', frame)
        self.assertNotIn('procedure TForm.DefaultHandler', forms)
        # Within the existing WndProc case: no extra frame on the 4 KB test stacks.
        self.assertIn('    WM_NCPAINT, WM_NCACTIVATE, WM_SETTEXT:\n      if PaintFrameFirst(Message) then Exit;',
                      source('controls.pas'))
        self.assertIn('AdjustWindowRectEx(Result, Form.FrameStyle, Form.Menu <> nil, Form.NativeExStyle);', forms)
        self.assertIn("initialization\n  ReleaseMessage := RegisterWindowMessage('CalmiraFormRelease');\n"
                      "  { Loaded up front, on a shallow stack: CTL3D's start-up code runs on ours. }\n  InitCtl3D;", forms)
        self.assertIn('DoneCtl3D;', forms)
        window = source('native_window.pas')
        self.assertIn('CreateWindowEx(NativeExStyle, ClassName,', window)

    def test_framed_children_get_delphis_sunken_edge(self):
        controls = source('controls.pas')
        self.assertIn('if Child.FCtl3D and Child.Ctl3DFramed and Child.Visible then', controls)
        self.assertIn('Edge := Rect(Bounds.Left - 1, Bounds.Top - 1, Bounds.Right, Bounds.Bottom);', controls)
        for unit, cls in (('native_edit.pas', 'TEdit'), ('native_combobox.pas', 'TCustomComboBox'),
                          ('native_listbox.pas', 'TCustomListBox')):
            self.assertIn(f'function {cls}.Ctl3DFramed: Boolean;\nbegin Result := True; end;', source(unit))
        self.assertIn("inherited CreateHandle(Parent, '', Style, X + 1, Y + 1, Width - 2, Height - 2);",
                      source('native_listbox.pas'))

    def test_buttons_run_through_ctl3d_on_their_parents_color(self):
        controls = source('controls.pas')
        self.assertIn('procedure WMCtlColor(var M: TMessage); message WM_CTLCOLOR;', controls)
        self.assertIn('Brush := Reflect(Child, CN_CTLCOLOR, M.WParam, M.LParam);', controls)
        self.assertIn('WinProcs.FillRect(HDC(M.WParam), Area, CtlColorBrush(HDC(M.WParam)));', controls)
        self.assertIn('  CreateWnd;\n  WndCreated;\nend;', controls)
        for unit in ('native_checkbox.pas', 'native_radio.pas'):
            text = source(unit)
            self.assertIn('if Ctl3D and (Ctl3DBtnWndProc <> nil) then\n'
                          '      Result := CallWindowProc(WinTypes.WNDPROC(Ctl3DBtnWndProc),', text)
            self.assertIn('M.Result := CtlColorBrush(HDC(M.WParam));', text)
            self.assertIn('if M.Msg = WM_ERASEBKGND then EraseWithColor(M)', text)

    def test_marks_set_before_the_list_window_survive_createwnd(self):
        listbox = source('native_listbox.pas')
        self.assertIn('if (I < FCreatedSelection.Size) and FCreatedSelection[I] then SetSelected(I, True);',
                      listbox)
        self.assertIn('Marked := FListBox.FMultiSelect and FListBox.Selected[Index];', listbox)

    def test_message_dialogs_use_delphi_1_font_and_layout(self):
        dialogs = source('dialogs.pas')
        self.assertIn("Form.Font.Name := 'MS Sans Serif'; Form.Font.Size := 8; Form.Font.Style := [fsBold];",
                      dialogs)
        self.assertIn('MsgMargin = 10; MsgBottom = 8;', dialogs)
        self.assertIn('AdjustWindowRectEx(Area, DialogStyle or DS_MODALFRAME, False, WS_EX_DLGMODALFRAME);',
                      dialogs)
        self.assertIn('GetSystemMetrics(SM_CXSCREEN) div 2 - (Area.Right - Area.Left) div 2', dialogs)
        self.assertRegex(dialogs, re.escape('Inc(TextTop, (IconSize - (TextArea.Bottom - TextArea.Top)) div 2);'))


if __name__ == '__main__':
    unittest.main()
