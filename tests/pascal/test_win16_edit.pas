program TestWin16Edit;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls,
  native_edit, native_window;
type
  TObserver = class
    Calls: Integer;
    Fail, Reenter: Boolean;
    procedure Changed(Sender: TObject);
    procedure Character(Sender: TObject; var Key: Char);
  end;
var Root, Peer: TCustomControl; Edit: TEdit; Observer: TObserver;
  Failed, Rejected: Boolean; I, Before, PoolUser, PoolGDI: Integer;
  Raw: HWND; Buffer: array[0..300] of Char; Font: TFont;
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
procedure TObserver.Changed(Sender: TObject);
begin
  if Sender <> Edit then raise Exception.Create('Wrong sender');
  Inc(Calls);
  if Reenter then Edit.Text := 'nested';
  if Fail then raise Exception.Create('edit change failure');
end;
procedure TObserver.Character(Sender: TObject; var Key: Char);
begin if Key = 'x' then Key := 'Z' else if Key = '!' then Key := #0; end;
begin
  FillChar(StackBottom^, 64, $A5);
  LogLine('STEP native single-line edit');
  try
    Root := TCustomControl.Create(nil); Peer := TCustomControl.Create(nil);
    Observer := TObserver.Create; Edit := TEdit.Create(nil); Edit.OnChange := Observer.Changed;
    Edit.Text := 'before'; Edit.Text := 'before';
    Check((Edit.Handle = 0) and (Observer.Calls = 1), 'detached text changes once');
    Edit.SelStart := 1; Edit.SelLength := 3;
    Check(Edit.SelText = 'efo', 'detached selection');
    Edit.SelText := 'X'; Check((Edit.Text = 'bXre') and Edit.Modified, 'detached replacement');
    Before := Observer.Calls; Edit.SelText := '';
    Check(Observer.Calls = Before, 'empty replacement is quiet');
    Edit.PasswordChar := '*'; Edit.MaxLength := 10;
    Root.CreateHandle(0, 'Edit parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 10, 10, 230, 90);
    Peer.CreateHandle(0, 'Peer', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 250, 10, 200, 90);
    Edit.SetBounds(5, 5, 150, 23); Before := Observer.Calls; Edit.Parent := Root;
    Check((Observer.Calls = Before) and (Edit.Text = 'bXre') and (Edit.SelStart = 2) and
      (Edit.SelLength = 0) and Edit.Modified, 'creation preserves text selection and modified quietly');
    Check((Edit.Perform(EM_GETPASSWORDCHAR, 0, 0) = Ord('*')) and Edit.TabStop,
      'native password and tab style');
    Edit.PasswordChar := #0;
    Check(Edit.Perform(EM_GETPASSWORDCHAR, 0, 0) = 0, 'password can be revealed');
    Edit.Text := 'hello'; Edit.SelStart := 1; Edit.SelLength := 3;
    Check((Edit.SelStart = 1) and (Edit.SelLength = 3) and (Edit.SelText = 'ell'),
      'Win16 packed selection ABI');
    Edit.SelText := 'i'; Check(Edit.Text = 'hio', 'live replacement');
    Edit.SelectAll; Check((Edit.SelStart = 0) and (Edit.SelLength = 3), 'select all');
    Edit.SelStart := 99; Edit.SelLength := 99;
    Check((Edit.SelStart = 3) and (Edit.SelLength = 0), 'selection clamps to text');
    Edit.MaxLength := 255; Edit.Text := 'copy me'; Edit.SelStart := 0; Edit.SelLength := 4;
    Edit.CopyToClipboard; Edit.SelStart := 7; Edit.PasteFromClipboard;
    Check(Edit.Text = 'copy mecopy', 'native clipboard copy and paste');
    Edit.Text := 'cut me'; Edit.SelStart := 0; Edit.SelLength := 3; Edit.CutToClipboard;
    Check((Edit.Text = ' me') and Edit.CanUndo, 'native cut has undo');
    Edit.Undo; Check(Edit.Text = 'cut me', 'native undo restores cut');
    Edit.SelectAll; Edit.ClearSelection; Check(Edit.Text = '', 'clear selection');
    Edit.Text := StringOfChar('a', 255); Edit.SelStart := 255; Rejected := False;
    try Edit.SelText := 'x'; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Length(Edit.Text) = 255), 'selection overflow preserves text');
    Edit.Text := ''; Edit.SetFocus; Before := Observer.Calls;
    Edit.Perform(WM_CHAR, Ord('a'), 1); Edit.Perform(WM_CHAR, Ord('b'), 1);
    Check((Edit.Text = 'ab') and (Observer.Calls = Before + 2) and Edit.Modified,
      'USER typing notifies once per change');
    Edit.Modified := False; Check(not Edit.Modified, 'modified flag clears');
    Edit.OnKeyPress := Observer.Character;
    Edit.Perform(WM_CHAR, Ord('x'), 1); Edit.Perform(WM_CHAR, Ord('!'), 1);
    Check(Edit.Text = 'abZ', 'mutable and consumed character events');
    Edit.OnKeyPress := nil; Edit.ReadOnly := True;
    Edit.Perform(WM_CHAR, Ord('q'), 1);
    Check((Edit.Text = 'abZ') and (DWORD(GetWindowLong(Edit.Handle, GWL_STYLE)) and ES_READONLY <> 0),
      'native read-only blocks typing');
    Edit.Text := 'program'; Check(Edit.Text = 'program', 'read-only permits programmatic text');
    Edit.ReadOnly := False; Edit.Clear; Edit.MaxLength := 3;
    for I := 1 to 5 do Edit.Perform(WM_CHAR, Ord('0') + I, 1);
    Check(Edit.Text = '123', 'native interactive limit');
    Edit.CharCase := ecUpperCase; Edit.Clear; Edit.Perform(WM_CHAR, Ord('a'), 1);
    Check(Edit.Text = 'A', 'live native uppercase');
    Edit.CharCase := ecLowerCase; Edit.Clear; Edit.Perform(WM_CHAR, Ord('B'), 1);
    Check(Edit.Text = 'b', 'live native lowercase');
    Edit.CharCase := ecNormal; Edit.Text := '123';
    Rejected := False;
    try Edit.MaxLength := 0; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Edit.MaxLength = 3), 'invalid limit preserves state');
    Rejected := False;
    try Edit.Text := 'bad'#0'value'; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Edit.Text = '123'), 'NUL rejected before mutation');
    FillChar(Buffer, SizeOf(Buffer), 'a'); Buffer[300] := #0;
    Before := Edit.CallbackErrors;
    Check(Edit.Perform(WM_SETTEXT, 0, LongInt(Pointer(@Buffer))) = 0, 'oversized native text rejected');
    Check((Edit.Text = '123') and (Edit.CallbackErrors = Before + 1), 'rejected native text preserves buffer');
    Edit.ClearCallbackError; Edit.MaxLength := 255;
    Observer.Reenter := True; Before := Observer.Calls; Edit.Text := 'outer'; Observer.Reenter := False;
    Check((Edit.Text = 'nested') and (Observer.Calls = Before + 1), 'nested mutation without recursive event');
    Observer.Fail := True; Before := Root.CallbackErrors; Edit.Text := 'failed'; Observer.Fail := False;
    Check((Edit.Text = 'failed') and (Root.CallbackErrors = Before + 1) and
      (Root.LastCallbackError = 'edit change failure'), 'change error contained at parent callback');
    Before := Observer.Calls; Edit.Text := 'recovered';
    Check(Observer.Calls = Before + 1, 'change guard recovers'); Root.ClearCallbackError;
    Font := TFont.Create; Font.Name := 'Courier'; Font.Size := 12; Edit.Font := Font;
    Font.Name := 'Helv'; Font.Free; Font := nil;
    Check((Edit.Font.Name = 'Courier') and (Edit.Perform(WM_GETFONT, 0, 0) = Edit.Font.Handle),
      'font deep copy reaches native edit');
    Edit.Text := 'retain'; Edit.SelStart := 1; Edit.SelLength := 3; Edit.Modified := True;
    Raw := Edit.Handle; Edit.Parent := Peer;
    Check((Edit.Handle = Raw) and (Edit.Text = 'retain') and (Edit.SelText = 'eta'),
      'live reparent preserves buffer selection');
    Edit.PasswordChar := '*'; Edit.ReadOnly := True; Before := Observer.Calls;
    Edit.DestroyHandle; Edit.CreateControl(Peer.Handle);
    Check((Edit.Text = 'retain') and (Edit.SelStart = 1) and (Edit.SelLength = 3) and Edit.Modified and
      (Observer.Calls = Before) and (Edit.Perform(EM_GETPASSWORDCHAR, 0, 0) = Ord('*')),
      'recreation restores native edit state quietly');
    PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES); PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for I := 1 to 40 do begin Edit.DestroyHandle; Edit.CreateControl(Peer.Handle); end;
    Check((GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2), 'edit recreation resource stability');
    Check((Edit.CallbackErrors = 0) and (Peer.CallbackErrors = 0), 'no unexpected native errors');
    Edit.Parent := nil; Observer.Fail := True; Rejected := False;
    try Edit.Text := 'detached failure'; except on Exception do Rejected := True; end;
    Observer.Fail := False; Before := Observer.Calls; Edit.Text := 'again';
    Check(Rejected and (Observer.Calls = Before + 1), 'detached event exception releases guard');
    Before := Observer.Calls; Edit.CreateControl(Root.Handle); Edit.Text := 'legacy';
    Edit.SelectAll; Edit.Perform(WM_CHAR, Ord('L'), 1);
    Check((Edit.Text = 'L') and (Observer.Calls = Before + 2), 'legacy native parent change fallback');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Edit.Free; Root.Free; Peer.Free; Observer.Free; Font.Free;
  Check(StackGuardIntact, 'stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
