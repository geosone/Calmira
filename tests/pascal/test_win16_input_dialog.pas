program TestWin16InputDialog;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Controls, StdCtrls,
  native_form, native_loop;
type
  TObserver = class
    Accepts, Cancels, Changes: Integer;
    Saved: string;
    Remembered: Boolean;
    procedure Changed(Sender: TObject);
    procedure Accepted(Sender: TObject);
    procedure Cancelled(Sender: TObject);
  end;
var Form: TNativeForm; Edit: TEdit; Box: TCheckBox; Accept, Cancel: TButton;
  Loop: TNativeMessageLoop; Observer: TObserver; Failed: Boolean;
  I, PoolUser, Before: Integer;
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
procedure TObserver.Changed(Sender: TObject);
var Text: string; Position: Integer; Valid: Boolean;
begin
  Inc(Changes); Text := Edit.Text; Valid := False;
  for Position := 1 to Length(Text) do
    if Text[Position] > ' ' then Valid := True;
  Accept.Enabled := Valid;
end;
procedure TObserver.Accepted(Sender: TObject);
begin
  Inc(Accepts); Saved := Edit.Text; Remembered := Box.Checked; Form.Close;
end;
procedure TObserver.Cancelled(Sender: TObject);
begin Inc(Cancels); Form.Close; end;
procedure Key(Value: Word; Scan: LongInt);
var Target: HWND;
begin
  Target := GetFocus;
  if not PostMessage(Target, WM_KEYDOWN, Value, Scan) or
    not PostMessage(Target, WM_KEYUP, Value, Scan or LongInt($C0000000)) then
    raise Exception.Create('Cannot post key');
  Loop.ProcessMessages(100);
end;
procedure ShowInput;
begin Form.Show; SetActiveWindow(Form.Handle); Edit.SetFocus; Loop.ProcessMessages(100); end;
begin
  LogLine('STEP input dialog');
  try
    Form := TNativeForm.Create(nil); Form.Caption := 'Input';
    Form.SetBounds(20, 20, 240, 160);
    Edit := TEdit.Create(Form); Edit.SetBounds(10, 10, 180, 23); Edit.Parent := Form;
    Box := TCheckBox.Create(Form); Box.Caption := 'Remember';
    Box.SetBounds(10, 45, 180, 20); Box.Parent := Form;
    Accept := TButton.Create(Form); Accept.Caption := 'Accept'; Accept.Default := True;
    Accept.Enabled := False; Accept.SetBounds(10, 80, 75, 23); Accept.Parent := Form;
    Cancel := TButton.Create(Form); Cancel.Caption := 'Cancel'; Cancel.Cancel := True;
    Cancel.SetBounds(100, 80, 75, 23); Cancel.Parent := Form;
    Observer := TObserver.Create; Edit.OnChange := Observer.Changed;
    Accept.OnClick := Observer.Accepted; Cancel.OnClick := Observer.Cancelled;
    Loop := TNativeMessageLoop.Create; Loop.OnMessage := Form.ProcessDialogMessage;
    ShowInput; Key(VK_RETURN, $001C0001);
    Check(Form.Visible and (Observer.Accepts = 0), 'reject empty');
    Key(Ord('A'), $001E0001);
    Check(((Edit.Text = 'a') or (Edit.Text = 'A')) and Accept.Enabled and
      (Observer.Changes = 1), 'typing validates');
    Key(VK_TAB, $000F0001); Check(Box.Focused, 'Tab option');
    Key(VK_SPACE, $00390001); Check(Box.Checked, 'Space toggles option');
    Key(VK_TAB, $000F0001); Check(Accept.Focused, 'Tab accept');
    Key(VK_RETURN, $001C0001);
    Check(not Form.Visible and (Observer.Accepts = 1) and Observer.Remembered and
      ((Observer.Saved = 'a') or (Observer.Saved = 'A')) and not Loop.Terminated,
      'accept values; no quit');
    ShowInput; Edit.SelectAll; Key(VK_BACK, $000E0001);
    Check((Edit.Text = '') and not Accept.Enabled, 'deletion invalidates');
    Key(VK_RETURN, $001C0001);
    Check(Form.Visible and (Observer.Accepts = 1), 'invalid Enter rejected');
    Key(VK_ESCAPE, $00010001);
    Check(not Form.Visible and (Observer.Cancels = 1) and not Loop.Terminated,
      'Escape cancels');
    Before := Observer.Changes; Form.DestroyHandle; ShowInput;
    Check((Edit.Text = '') and Box.Checked and not Accept.Enabled and
      (Observer.Changes = Before), 'quiet state recreation');
    Edit.Text := 'recreated'; Key(VK_RETURN, $001C0001);
    Check((Observer.Accepts = 2) and (Observer.Saved = 'recreated'), 'accept after recreate');
    PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 20 do
    begin Form.DestroyHandle; ShowInput; Key(VK_ESCAPE, $00010001); end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2, 'recreation resources');
    Check((Form.CallbackErrors = 0) and (Edit.CallbackErrors = 0) and
      (Box.CallbackErrors = 0), 'no callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Loop <> nil then Loop.OnMessage := nil;
  Form.Free; Loop.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
