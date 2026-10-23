program MnemonicTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Controls, StdCtrls,
  native_form, native_loop, native_mnemonic, native_window;
type
  TD = object
    Calls: Integer;
    DisableOnEnter, FailClick: Boolean;
    procedure Clicked(Sender: TObject);
    procedure Entered(Sender: TObject);
  end;
var Form, Other: TNativeForm; Panel, Temporary: TCustomControl;
  Edit, Second: TEdit; FirstLabel, Duplicate: TLabel; Button: TButton; Box: TCheckBox;
  Loop: TNativeMessageLoop; Driver: TD; Failed, Rejected: Boolean; M: TMsg; Before: Integer;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string; Data: array[0..255] of Char;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Data, Line);
  _lwrite(F, @Data, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TD.Clicked(Sender: TObject);
begin Inc(Calls); if FailClick then raise Exception.Create('click'); end;
procedure TD.Entered(Sender: TObject);
begin if DisableOnEnter then TCustomControl(Sender).Enabled := False; end;
procedure Alt(Key: Char);
begin
  PostMessage(GetFocus, WM_SYSCHAR, Ord(Key), $20000001); Loop.ProcessMessages(100);
end;
begin
  FillChar(StackBottom^, 64, $A5);
  LogLine('STEP native mnemonics');
  FillChar(Driver, SizeOf(Driver), 0);
  try
    Check(CaptionMatches('&&&File:', 'f') and not CaptionMatches('&&File:', 'f') and
      not CaptionMatches('Last&', 't') and not CaptionMatches('&x', #0), 'ampersands');
    Check(CaptionMatches('&'#228, #196), 'ANSI case');
    Form := TNativeForm.Create(nil); Form.SetBounds(10, 10, 250, 160);
    Edit := TEdit.Create(Form); Edit.Parent := Form; Edit.SetBounds(60, 8, 120, 20);
    Second := TEdit.Create(Form); Second.Parent := Form; Second.SetBounds(60, 36, 120, 20);
    FirstLabel := TLabel.Create(Form); FirstLabel.Parent := Form; FirstLabel.Caption := '&File:';
    FirstLabel.FocusControl := Edit;
    Duplicate := TLabel.Create(Form); Duplicate.Parent := Form; Duplicate.Caption := '&File:';
    Duplicate.FocusControl := Second;
    Button := TButton.Create(Form); Button.Parent := Form; Button.Caption := '&Go';
    Button.SetBounds(8, 70, 70, 24); Button.OnClick := Driver.Clicked; Button.OnEnter := Driver.Entered;
    Box := TCheckBox.Create(Form); Box.Parent := Form; Box.Caption := '&Keep'; Box.SetBounds(90, 70, 100, 20);
    Check(not Form.DispatchMnemonic('f'), 'detached');
    Form.InitialControl := Second; Form.Show; SetActiveWindow(Form.Handle);
    Loop := TNativeMessageLoop.Create; Loop.OnMessage := Form.ProcessDialogMessage;
    Alt('f'); Check(Edit.Focused, 'first label');
    FirstLabel.Enabled := False; Alt('f');
    Check(Second.Focused and FirstLabel.Visible, 'disabled label yields to duplicate mnemonic');
    Duplicate.Enabled := False; Edit.SetFocus; Alt('f');
    Check(Edit.Focused and not Form.DispatchMnemonic('f'), 'disabled labels do not consume mnemonic');
    FirstLabel.Enabled := True; Alt('f'); Check(Edit.Focused, 'reenabled label mnemonic');
    Duplicate.Enabled := True;
    FirstLabel.Visible := False; Alt('f'); Check(Second.Focused, 'hidden label');
    FirstLabel.Visible := True; Edit.Enabled := False; Alt('F'); Check(Second.Focused, 'disabled target');
    Edit.Enabled := True; Duplicate.Visible := False;
    FirstLabel.Caption := 'Save && &As:';
    Check(not Form.DispatchMnemonic('&') and not Form.DispatchMnemonic('s') and
      Form.DispatchMnemonic('a') and Edit.Focused, 'escaped prefix');
    FirstLabel.ShowAccelChar := False; Second.SetFocus;
    Check(not Form.DispatchMnemonic('a') and Second.Focused, 'prefix disabled');
    FirstLabel.ShowAccelChar := True; FirstLabel.Caption := '&File:';
    Temporary := TCustomControl.Create(nil); Temporary.Parent := Form;
    FirstLabel.FocusControl := Temporary; Temporary.Free; Temporary := nil;
    Check(FirstLabel.FocusControl = nil, 'weak reference');
    FirstLabel.FocusControl := Edit;
    Other := TNativeForm.Create(nil); Other.SetBounds(270, 10, 160, 120); Other.Show;
    Edit.Parent := Other;
    Check(not Form.DispatchMnemonic('f'), 'foreign target');
    Panel := TCustomControl.Create(Form); Panel.Parent := Form; Panel.SetBounds(8, 100, 220, 40);
    Edit.Parent := Panel; Edit.SetBounds(60, 4, 120, 20); FirstLabel.Parent := Panel;
    SetActiveWindow(Form.Handle); Alt('f'); Check(Edit.Focused, 'nested target');
    Panel.Enabled := False;
    Check(not Form.DispatchMnemonic('f') and FirstLabel.Enabled, 'disabled container'); Panel.Enabled := True;
    Alt('g'); Check((Driver.Calls = 1) and Button.Focused, 'button once');
    Alt('k'); Check(Box.Checked and Box.Focused, 'checkbox once');
    Alt('K'); Check(not Box.Checked, 'checkbox toggle');
    FillChar(M, SizeOf(M), 0); M.hwnd := Second.Handle; M.message := WM_SYSCHAR;
    M.wParam := Ord('g'); M.lParam := 1;
    Check(not Form.ProcessDialogMessage(M), 'requires Alt context');
    M.lParam := $20000001; M.wParam := 256;
    Check(not Form.ProcessDialogMessage(M), 'bounded character');
    M.wParam := Ord('g'); M.hwnd := Other.Handle;
    Check(not Form.ProcessDialogMessage(M), 'foreign origin');
    Driver.DisableOnEnter := True; Second.SetFocus; Before := Driver.Calls; Rejected := False;
    try Alt('g'); except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and not Button.Enabled and (Driver.Calls = Before), 'focus callback veto');
    Driver.DisableOnEnter := False; Button.Enabled := True; Second.SetFocus;
    Driver.FailClick := True; Rejected := False;
    try Alt('g'); except on Exception do Rejected := True; end;
    Driver.FailClick := False; Alt('g');
    Check(Rejected and (Driver.Calls = Before + 2), 'filter recovery');
    FirstLabel.Enabled := False;
    Form.Hide; Form.DestroyHandle; Form.Show; SetActiveWindow(Form.Handle);
    Check(not FirstLabel.Enabled and not Form.DispatchMnemonic('f'),
      'disabled label mnemonic policy survives native recreation');
    FirstLabel.Enabled := True; Alt('f');
    Check(Edit.Focused and (FirstLabel.FocusControl = Edit), 'recreate');
    Check((Form.CallbackErrors = 0) and (Button.CallbackErrors = 0), 'callbacks');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  if Loop <> nil then Loop.OnMessage := nil;
  Check(StackGuardIntact, 'mnemonic stack boundary');
  Form.Free; Other.Free; Temporary.Free; Loop.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
