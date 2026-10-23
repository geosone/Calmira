program TestWin16ListBox;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, control_base, native_window, StdCtrls;
type
  TObserver = class
    Clicks, DblClicks, Draws, SelectedDraws: Integer;
    LastIndex: Integer;
    procedure Click(Sender: TObject);
    procedure DblClick(Sender: TObject);
    procedure Draw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  end;
var Root: TCustomControl; List, Multi, Drawn: TListBox; Observer: TObserver; Failed: Boolean;
  Msg: TMsg; R: TRect; Rejected: Boolean; Pos: TPoint;
procedure TObserver.Click(Sender: TObject); begin Inc(Clicks); end;
procedure TObserver.DblClick(Sender: TObject); begin Inc(DblClicks); end;
procedure TObserver.Draw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  Inc(Draws); LastIndex := Index;
  if odSelected in State then Inc(SelectedDraws);
  TListBox(Control).Canvas.FillRect(Rect);
  TListBox(Control).Canvas.TextOut(Rect.Left + 4, Rect.Top, '*' + TListBox(Control).Items[Index]);
end;
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
procedure Pump;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
begin
  LogLine('STEP list box');
  Observer := TObserver.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'List parent', WS_POPUP or WS_VISIBLE, 10, 10, 420, 220);
    List := TListBox.Create(nil);
    Check((List.Width = 121) and (List.Height = 97) and List.TabStop and (List.ItemIndex = -1) and
      (List.BorderStyle = bsSingle) and List.ExtendedSelect and (List.Color = clWindow), 'Delphi defaults');
    List.Items.Add('beta'); List.Items.Add('alpha'); List.Items.AddObject('gamma', Observer);
    List.ItemIndex := 1;
    List.SetBounds(10, 10, 120, 120); List.Parent := Root;
    List.OnClick := Observer.Click; List.OnDblClick := Observer.DblClick;
    Check((List.Perform(LB_GETCOUNT, 0, 0) = 3) and (List.ItemIndex = 1) and
      (List.Items.Objects[2] = Observer), 'items and selection reach the native list');
    List.Items.Insert(0, 'first'); List.Items.Delete(3);
    Check((List.Items.Count = 3) and (List.Items[0] = 'first') and (List.Perform(LB_GETCOUNT, 0, 0) = 3),
      'insert and delete stay mirrored');
    List.Sorted := True;
    Check((List.Items[0] = 'alpha') and (List.Items[2] = 'first'), 'Sorted reorders');
    List.Items.Add('aaa');
    Check(List.Items.IndexOf('aaa') = 0, 'sorted add');
    Rejected := False;
    try List.Items.Insert(0, 'x'); except on ENativeWindowError do Rejected := True; end;
    Check(Rejected, 'sorted insert rejected');
    List.ItemIndex := 2;
    R := List.ItemRect(2);
    List.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(R.Left + 4, R.Top + 2));
    List.Perform(WM_LBUTTONUP, 0, MakeLong(R.Left + 4, R.Top + 2));
    Pump;
    Pos.X := R.Left + 4; Pos.Y := R.Top + 2;
    Check(List.ItemAtPos(Pos, True) = 2, 'ItemAtPos');
    Observer.Clicks := 0;
    List.Perform(WM_KEYDOWN, VK_DOWN, 0); Pump;
    Check((List.ItemIndex = 3) and (Observer.Clicks = 1), 'keyboard selection fires OnClick');
    { Handle recreation keeps items and selection. }
    List.Parent := nil;
    Check((List.Handle = 0) and (List.ItemIndex = 3) and (List.Items.Count = 4), 'state survives handle loss');
    List.Parent := Root;
    Check((List.Perform(LB_GETCOUNT, 0, 0) = 4) and (List.ItemIndex = 3), 'state restored on recreation');
    List.Clear;
    Check((List.Items.Count = 0) and (List.ItemIndex = -1), 'Clear');

    Multi := TListBox.Create(nil);
    Multi.MultiSelect := True;
    Multi.Items.Add('one'); Multi.Items.Add('two'); Multi.Items.Add('three');
    Multi.Selected[0] := True; Multi.Selected[2] := True;
    Check(Multi.SelCount = 2, 'multi-selection before the handle');
    Multi.SetBounds(140, 10, 120, 100); Multi.Parent := Root;
    Check((Multi.SelCount = 2) and Multi.Selected[2] and not Multi.Selected[1], 'multi-selection reaches USER');
    Multi.Selected[2] := False;
    Multi.Parent := nil; Multi.Parent := Root;
    Check((Multi.SelCount = 1) and Multi.Selected[0], 'multi-selection survives recreation');
    Rejected := False;
    try Multi.MultiSelect := False; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected, 'creation styles are fixed on a live list');

    Drawn := TListBox.Create(nil);
    Drawn.Style := lbOwnerDrawFixed; Drawn.ItemHeight := 20;
    Drawn.Items.Add('red'); Drawn.Items.Add('green');
    Drawn.OnDrawItem := Observer.Draw;
    Drawn.SetBounds(270, 10, 120, 100); Drawn.Parent := Root;
    Drawn.ItemIndex := 1;
    Drawn.Repaint; Pump;
    R := Drawn.ItemRect(0);
    Check((Observer.Draws >= 2) and (Observer.SelectedDraws >= 1) and (Drawn.ItemHeight = 20) and
      (R.Bottom - R.Top = 20), 'owner-draw fixed paints through OnDrawItem');
    Check(Drawn.Font.Color <> clHighlightText, 'selection colour does not leak into Font');
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Drawn.Free; Multi.Free; List.Free; Root.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
