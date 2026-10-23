program TestWin16Radio;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Controls, native_radio, native_checkbox;
type
  TObserver = class
    Last: TObject;
    Calls: Integer;
    procedure Clicked(Sender: TObject);
  end;
var Root, Group: TCustomControl; A, B, C, Other: TRadioButton; Box: TCheckBox;
  Observer: TObserver; Failed, Rejected: Boolean; I, PoolUser: Integer;
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
procedure TObserver.Clicked(Sender: TObject);
begin Last := Sender; Inc(Calls); end;
function Make(Parent: TCustomControl; const Caption: string; Y: Integer): TRadioButton;
begin
  Result := TRadioButton.Create(nil);
  Result.Caption := Caption; Result.OnClick := Observer.Clicked;
  Result.SetBounds(5, Y, 120, 20); Result.Parent := Parent;
end;
procedure MouseClick(Button: TRadioButton);
begin
  Button.Perform(WM_LBUTTONDOWN, MK_LBUTTON, $00080008);
  Button.Perform(WM_LBUTTONUP, 0, $00080008);
end;
function Native(Button: TRadioButton): Boolean;
begin Result := Button.Perform(BM_GETCHECK, 0, 0) = 1; end;
begin
  LogLine('STEP native radio buttons');
  Observer := TObserver.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Radio parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 10, 10, 300, 160);
    Group := TCustomControl.Create(nil); Group.SetBounds(150, 5, 140, 80); Group.Parent := Root;
    A := Make(Root, '&Alpha', 5); B := Make(Root, '&Beta', 30); C := Make(Root, '&Gamma', 55);
    Other := Make(Group, '&Other', 5);
    Box := TCheckBox.Create(nil); Box.SetBounds(5, 80, 120, 20); Box.Parent := Root; Box.Checked := True;
    Check((GetWindowLong(A.Handle, GWL_STYLE) and $F = BS_RADIOBUTTON) and not A.TabStop and
      (A.Alignment = taRightJustify), 'manual radio style, no tab stop while unchecked');
    A.Checked := True;
    Check(A.Checked and Native(A) and A.TabStop and (Observer.Calls = 1) and (Observer.Last = A),
      'check notifies once');
    MouseClick(B);
    Check(B.Checked and Native(B) and not A.Checked and not Native(A) and B.TabStop and not A.TabStop and
      (Observer.Calls = 2) and (Observer.Last = B), 'mouse click moves the check within siblings');
    Other.Checked := True;
    Check(Other.Checked and B.Checked and Box.Checked, 'other parent and checkboxes are independent');
    MouseClick(B);
    Check(Observer.Calls = 3, 'clicking the checked button does not renotify');
    B.Checked := False;
    Check(not B.Checked and not A.Checked and not C.Checked and (Observer.Calls = 3),
      'unchecking is quiet and leaves none checked');
    Root.DispatchMnemonic('g');
    Check(C.Checked and (Observer.Last = C) and C.Focused, 'mnemonic focuses and checks');
    C.Enabled := False; MouseClick(A);
    Check(A.Checked and not C.Checked, 'disabled sibling is still unchecked');
    C.Enabled := True; Observer.Calls := 0; C.Enabled := False; C.Click;
    Check(not C.Checked and (Observer.Calls = 0), 'disabled click ignored');
    C.Enabled := True;
    A.Alignment := taLeftJustify;
    Check(GetWindowLong(A.Handle, GWL_STYLE) and BS_LEFTTEXT <> 0, 'left text alignment');
    Rejected := False;
    try A.Alignment := taCenter; except on Exception do Rejected := True; end;
    Check(Rejected and (A.Alignment = taLeftJustify), 'center alignment rejected');
    A.DestroyHandle; A.CreateControl(Root.Handle);
    Check(Native(A) and (GetWindowLong(A.Handle, GWL_STYLE) and BS_LEFTTEXT <> 0) and
      (GetWindowLong(A.Handle, GWL_STYLE) and WS_TABSTOP <> 0), 'recreation keeps state');
    PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 40 do begin A.DestroyHandle; A.CreateControl(Root.Handle); end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2, 'recreation resource stability');
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  A.Free; B.Free; C.Free; Other.Free; Box.Free; Group.Free; Root.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
