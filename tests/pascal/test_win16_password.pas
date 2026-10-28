program PasswordTest;
{$mode delphi}{$H-}{$K+}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Password, password_dfm, Controls,
  PicBtn, native_form, resource_text, Locale;
type TD = object
  Mode, Errors: Integer;
  LastError: Word;
  RaiseError, OwnerDisabled, InitRejected: Boolean;
  procedure Error(Sender: TObject; Ident: Word);
  procedure Shown(Sender: TObject);
end;
  PD = ^TD;
var Dialog: TPasswordDlg; Owner: TNativeForm; Driver: PD; Failed, Rejected: Boolean;
  Timer: UINT; Boxes, I, BeforeUSER, BeforeGDI: Integer; LongValue: string;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure Enter;
begin PostMessage(Dialog.Edit1.Handle, WM_KEYDOWN, VK_RETURN, 1); end;
procedure TD.Error(Sender: TObject; Ident: Word);
begin
  Inc(Errors); LastError := Ident;
  if Sender <> Dialog then raise Exception.Create('sender');
  if RaiseError then raise Exception.Create('validation callback');
  if Mode = 2 then
  begin Dialog.Edit1.Text := 'User1'; Dialog.Edit3.Text := Dialog.Edit2.Text; Enter; end;
end;
procedure TD.Shown(Sender: TObject);
begin
  OwnerDisabled := not IsWindowEnabled(Owner.Handle);
  try Dialog.InitNewUser; except on Exception do InitRejected := True; end;
  Dialog.Edit1.Text := 'User1'; Dialog.Edit2.Text := 'sample'; Dialog.Edit3.Text := 'sample';
  case Mode of
    1: Enter;
    2, 5: begin Dialog.Edit1.Text := 'invalid_'; Enter; end;
    3: PostMessage(Dialog.Edit1.Handle, WM_KEYDOWN, VK_ESCAPE, 1);
    4: PostMessage(Dialog.Handle, WM_CLOSE, 0, 0);
  end;
end;
procedure Tick(Window: HWND; Message, Event: UINT; Time: DWORD); export;
var Box, Child: HWND; Name: array[0..31] of Char;
begin
  try
    Box := GetActiveWindow;
    if (Box = 0) or (GetWindowTask(Box) <> GetCurrentTask) or
      (GetParent(Box) <> Dialog.Handle) then Exit;
    GetClassName(Box, Name, SizeOf(Name)); if StrComp(Name, '#32770') <> 0 then Exit;
    Child := GetWindow(Box, GW_CHILD);
    while Child <> 0 do
    begin
      GetClassName(Child, Name, SizeOf(Name));
      if StrIComp(Name, 'Button') = 0 then
      begin
        Inc(Boxes); Dialog.Edit1.Text := 'User1';
        SendMessage(Box, WM_COMMAND, GetDlgCtrlID(Child), LongInt(Child)); Enter; Exit;
      end;
      Child := GetWindow(Child, GW_HWNDNEXT);
    end;
  except Failed := True; end;
end;
procedure Modal(Mode, Expected: Integer);
begin
  Dialog.InitNewUser; Driver^.Mode := Mode; Driver^.Errors := 0; Driver^.InitRejected := False;
  Check(Dialog.ShowModal(Owner.Handle) = Expected, 'modal result');
  Check(Driver^.OwnerDisabled and Driver^.InitRejected and IsWindowEnabled(Owner.Handle) and
    not Dialog.Visible and not Dialog.ModalRunning, 'owner/lifecycle');
end;
procedure Validation;
begin
    Rejected := False; try Dialog.OKBtn.Click; except on Exception do Rejected := True; end;
    Check(Rejected and (Dialog.ModalResult = mrNone), 'initialization required');
    Dialog.InitNewUser;
    Check((Dialog.Edit1.PasswordChar = #0) and (Dialog.Edit1.MaxLength = 8) and
      (Dialog.Edit2.PasswordChar = '*') and (Dialog.Edit2.MaxLength = 127) and
      (Dialog.Edit3.MaxLength = 127) and not Dialog.OKBtn.Glyph.Empty, 'fields/glyphs');
    Check((Dialog.Caption = 'Create new user') and (LocalLoadStr(SInvalidUserName) <> ''), 'bound strings');
    Dialog.Caption := 'other'; Dialog.Edit1.Text := 'invalid_'; Dialog.OKBtn.Click;
    Check((Driver^.LastError = SInvalidUserName) and (Dialog.ModalResult = mrNone), 'caption independent');
    Dialog.Edit1.Text := 'User1'; Dialog.Edit2.Text := 'a'; Dialog.Edit3.Text := 'b'; Dialog.OKBtn.Click;
    Check((Driver^.LastError = SPasswordMismatch) and (Dialog.ModalResult = mrNone), 'mismatch');
    Driver^.RaiseError := True; Rejected := False;
    try Dialog.OKBtn.Click; except on Exception do Rejected := True; end;
    Driver^.RaiseError := False; Dialog.Edit3.Text := 'a'; Dialog.OKBtn.Click;
    Check(Rejected and (Dialog.ModalResult = mrOK), 'callback recovery');
end;
procedure Change;
begin
    Dialog.InitChangePassword('previous-long');
    Check((Dialog.Edit1.MaxLength = 127) and (Dialog.Edit1.PasswordChar = '*') and
      (Dialog.Edit2.Text = '') and (Dialog.ModalResult = mrNone), 'change reset');
    Dialog.Edit1.Text := 'wrong'; Dialog.OKBtn.Click;
    Check((Driver^.LastError = SInvalidOldPassword) and (Dialog.ModalResult = mrNone), 'old password');
    Dialog.Edit1.Text := 'previous-long'; Dialog.OKBtn.Click;
    Check(Dialog.ModalResult = mrOK, 'old value over eight bytes');
    Dialog.InitChangePassword(''); Dialog.Edit1.Text := 'wrong'; Dialog.OKBtn.Click;
    Check((Driver^.LastError = SInvalidOldPassword) and (Dialog.ModalResult = mrNone), 'empty old exact match');
    Dialog.Edit1.Text := ''; Dialog.OKBtn.Click; Check(Dialog.ModalResult = mrOK, 'empty passwords');
end;
procedure Maximum;
begin
    Dialog.InitNewUser; Dialog.Edit1.Text := 'User1';
    LongValue := ''; for I := 1 to 128 do LongValue := LongValue + 'x';
    Dialog.Edit2.Text := LongValue; Dialog.Edit3.Text := LongValue; Rejected := False;
    try Dialog.OKBtn.Click; except on EConvertError do Rejected := True; end;
    Check(Rejected and (Dialog.ModalResult = mrNone), 'storage bound');
    Delete(LongValue, 128, 1); Dialog.Edit2.Text := LongValue; Dialog.Edit3.Text := LongValue;
    Dialog.OKBtn.Click;
    Check((Dialog.ModalResult = mrOK) and (Length(EncryptPassword(LongValue)) = 254) and
      (DecryptPassword(EncryptPassword(LongValue)) = LongValue), 'maximum value');
end;
procedure ModalChecks;
begin
    Owner := TNativeForm.Create(nil); Owner.SetBounds(10, 10, 180, 100); Owner.Show;
    Dialog.OnShow := Driver^.Shown;
    Modal(1, mrOK); Modal(2, mrOK); Check(Driver^.Errors = 1, 'modal validation retry');
    Modal(3, mrCancel); Modal(4, mrCancel); Dialog.DestroyHandle; Modal(1, mrOK);
    Timer := SetTimer(0, 0, 55, TFarProc(@Tick)); if Timer = 0 then raise Exception.Create('timer');
    Dialog.OnValidationError := nil;
    try Modal(5, mrOK); Check(Boxes = 1, 'native validation message');
    finally KillTimer(0, Timer); Timer := 0; end;
    Check((Dialog.CallbackErrors = 0) and (Dialog.OKBtn.CallbackErrors = 0), 'callbacks');
end;
procedure Resources;
begin
    Dialog.Free; Dialog := nil;
    BeforeUSER := GetFreeSystemResources(GFSR_USERRESOURCES); BeforeGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for I := 1 to 20 do
    begin
      PicBtnGlyphs := Odd(I); Dialog := TPasswordDlg.Create(nil); Dialog.InitNewUser;
      Dialog.Show; Dialog.Hide; Dialog.Free; Dialog := nil;
    end;
    Check((GetFreeSystemResources(GFSR_USERRESOURCES) >= BeforeUSER - 2) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= BeforeGDI - 2), 'resources');
end;
begin
  FillChar(StackBottom^, 64, $A5);
  LogLine('STEP original password');
  try
    New(Driver); FillChar(Driver^, SizeOf(Driver^), 0);
    PicBtnGlyphs := True; Dialog := TPasswordDlg.Create(nil); Dialog.OnValidationError := Driver^.Error;
    Validation; Change; Maximum; ModalChecks;
    Owner.Free; Owner := nil;
    Resources;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  if Timer <> 0 then KillTimer(0, Timer);
  Dialog.Free; Owner.Free; if Driver <> nil then Dispose(Driver);
  Check(StackGuardIntact, 'stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
