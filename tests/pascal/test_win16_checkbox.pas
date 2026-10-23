program TestWin16CheckBox;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls,
  native_checkbox, native_window;
type
  TObserver = class
    Calls: Integer;
    Fail, Reenter: Boolean;
    procedure Clicked(Sender: TObject);
  end;
var Root, Peer: TCustomControl; Box: TCheckBox; Observer: TObserver;
  Failed, Rejected: Boolean; I, Before, PoolUser, PoolGDI: Integer; Raw: HWND;
  Buffer: array[0..255] of Char; Font: TFont;
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
procedure TObserver.Clicked(Sender: TObject);
begin
  if Sender <> Box then raise Exception.Create('Wrong sender');
  Inc(Calls);
  if Reenter then Box.State := cbUnchecked;
  if Fail then raise Exception.Create('checkbox click failure');
end;
procedure MouseClick;
begin
  Box.Perform(WM_LBUTTONDOWN, MK_LBUTTON, $00080008);
  Box.Perform(WM_LBUTTONUP, 0, $00080008);
end;
begin
  LogLine('STEP native three-state checkbox');
  try
    Root := TCustomControl.Create(nil); Peer := TCustomControl.Create(nil);
    Observer := TObserver.Create; Box := TCheckBox.Create(nil);
    Box.OnClick := Observer.Clicked; Box.Caption := 'Remember';
    Box.Checked := True; Box.Checked := True;
    Check(Box.Checked and (Observer.Calls = 1) and (Box.Handle = 0), 'detached state notifies once');
    Root.CreateHandle(0, 'Check parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 10, 10, 230, 90);
    Peer.CreateHandle(0, 'Peer', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 250, 10, 200, 90);
    Box.SetBounds(5, 5, 140, 23); Before := Observer.Calls; Box.Parent := Root;
    GetWindowText(Box.Handle, Buffer, SizeOf(Buffer));
    Check((StrPas(Buffer) = 'Remember') and (Box.Perform(BM_GETCHECK, 0, 0) = 1) and
      (Observer.Calls = Before) and Box.TabStop, 'native creation restores state quietly');
    MouseClick;
    Check(not Box.Checked and (Observer.Calls = Before + 1), 'mouse toggles exactly once');
    Box.SetFocus; Before := Observer.Calls;
    Box.Perform(WM_KEYDOWN, VK_SPACE, 1); Box.Perform(WM_KEYUP, VK_SPACE, LongInt($C0000001));
    Check(Box.Checked and (Observer.Calls = Before + 1), 'native Space toggles exactly once');
    Box.AllowGrayed := True; Box.Checked := False; Box.Click;
    Check((Box.State = cbGrayed) and not Box.Checked and (Box.Perform(BM_GETCHECK, 0, 0) = 2),
      'unchecked to grayed');
    Box.Click; Check(Box.Checked, 'grayed to checked');
    Box.Click; Check(Box.State = cbUnchecked, 'checked to unchecked');
    Box.AllowGrayed := False; Box.Click; Check(Box.Checked, 'two-state click skips gray');
    Box.Perform(BM_SETCHECK, 2, 0); Check(Box.State = cbGrayed, 'native state queried rather than cached');
    Before := Observer.Calls; Box.Enabled := False; Box.Click; MouseClick;
    Check((Box.State = cbGrayed) and (Observer.Calls = Before), 'disabled activation ignored');
    Box.Checked := True;
    Check(Box.Checked and (Observer.Calls = Before + 1), 'disabled programmatic state still notifies');
    Box.Enabled := True; Box.Visible := False; Before := Observer.Calls;
    Root.Perform(WM_COMMAND, GetDlgCtrlID(Box.Handle), LongInt(Box.Handle) or (LongInt(BN_CLICKED) shl 16));
    Check(Observer.Calls = Before, 'hidden notification ignored');
    Box.Visible := True; Before := Observer.Calls;
    Check(not Root.DispatchDialogKey(VK_RETURN) and (Observer.Calls = Before), 'Enter is not checkbox toggle');
    Observer.Reenter := True; Box.Checked := False; Before := Observer.Calls; Box.Checked := True;
    Observer.Reenter := False;
    Check(not Box.Checked and (Observer.Calls = Before + 1), 'nested state mutation has bounded event');
    Observer.Fail := True; Before := Root.CallbackErrors; MouseClick; Observer.Fail := False;
    Check(Box.Checked and (Root.CallbackErrors = Before + 1) and
      (Root.LastCallbackError = 'checkbox click failure'), 'click exception contained in parent');
    Before := Observer.Calls; MouseClick;
    Check(not Box.Checked and (Observer.Calls = Before + 1), 'click guard recovers'); Root.ClearCallbackError;
    Rejected := False;
    try Box.Caption := 'bad'#0'value'; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Box.Caption = 'Remember'), 'caption NUL preserves state');
    Font := TFont.Create; Font.Name := 'Courier'; Font.Size := 12; Box.Font := Font;
    Font.Name := 'Helv'; Font.Free; Font := nil;
    Check((Box.Font.Name = 'Courier') and (Box.Perform(WM_GETFONT, 0, 0) = Box.Font.Handle), 'native font copy');
    Box.State := cbGrayed; Before := Observer.Calls; Raw := Box.Handle; Box.Parent := Peer;
    Check((Box.Handle = Raw) and (Box.State = cbGrayed) and (Observer.Calls = Before), 'reparent preserves state');
    Box.DestroyHandle; Box.CreateControl(Peer.Handle);
    Check((Box.State = cbGrayed) and (Observer.Calls = Before), 'recreation is quiet');
    PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES); PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for I := 1 to 60 do begin Box.Click; Box.DestroyHandle; Box.CreateControl(Peer.Handle); end;
    Check((GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2), 'checkbox recreation resource stability');
    Check((Box.CallbackErrors = 0) and (Peer.CallbackErrors = 0), 'no unexpected native errors');
    Box.Parent := nil; Observer.Fail := True; Rejected := False;
    try Box.Checked := not Box.Checked; except on Exception do Rejected := True; end;
    Observer.Fail := False; Before := Observer.Calls; Box.Click;
    Check(Rejected and (Observer.Calls = Before + 1), 'direct failure releases event guard');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Box.Free; Root.Free; Peer.Free; Observer.Free; Font.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
