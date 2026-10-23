program TestWin16Grids;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, StdCtrls, Forms, Grids,
  MultiGrd, native_window;
type
  TEvents = class
    Draws, FixedDraws, FocusedDraws, SelectedDraws, Clicks, DblClicks, TopLefts, Selects: Integer;
    Veto: Longint;
    LastSelect: Integer;
    procedure DrawCell(Sender: TObject; Col, Row: Longint; Rect: TRect; State: TGridDrawState);
    procedure SelectCell(Sender: TObject; Col, Row: Longint; var CanSelect: Boolean);
    procedure Click(Sender: TObject);
    procedure DblClick(Sender: TObject);
    procedure TopLeft(Sender: TObject);
    procedure MultiSelect(Sender: TObject; Index: Integer);
  end;
var Root: TCustomControl; Grid: TDrawGrid; Strings: TStringGrid; Multi: TMultiGrid; Events: TEvents;
  Failed, Raised: Boolean; R: TRect; ACol, ARow: Longint; Min, Max: SmallInt; Sel: TGridRect;
  Line: TStringList; Owned: TObject; DC: HDC;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
function Same(const A: TRect; L, T, Rt, B: Integer): Boolean;
begin
  Result := (A.Left = L) and (A.Top = T) and (A.Right = Rt) and (A.Bottom = B);
  if not Result then LogLine(Format('INFO rect %d,%d,%d,%d want %d,%d,%d,%d',
    [A.Left, A.Top, A.Right, A.Bottom, L, T, Rt, B]));
end;
procedure Pump;
var Msg: TMsg; Start: LongInt;
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < 150 do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure Key(Window: HWND; Code: Word);
begin SendMessage(Window, WM_KEYDOWN, Code, 1); end;
procedure Click(Window: HWND; X, Y: Integer; Double: Boolean);
begin
  if Double then SendMessage(Window, WM_LBUTTONDBLCLK, MK_LBUTTON, MakeLong(X, Y))
  else SendMessage(Window, WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(X, Y));
  SendMessage(Window, WM_LBUTTONUP, 0, MakeLong(X, Y));
end;
function Pixel(Window: HWND; X, Y: Integer): TColorRef;
begin
  DC := GetDC(Window); Result := GetPixel(DC, X, Y); ReleaseDC(Window, DC);
end;
function AnyInk(Window: HWND; const Area: TRect): Boolean;
var X, Y: Integer;
begin
  Result := False;
  DC := GetDC(Window);
  for Y := Area.Top + 1 to Area.Bottom - 2 do
    for X := Area.Left + 1 to Area.Right - 2 do
      if GetPixel(DC, X, Y) <> ColorToRGB(clWindow) then Result := True;
  ReleaseDC(Window, DC);
end;
procedure TEvents.DrawCell(Sender: TObject; Col, Row: Longint; Rect: TRect; State: TGridDrawState);
begin
  Inc(Draws);
  if gdFixed in State then Inc(FixedDraws);
  if gdFocused in State then Inc(FocusedDraws);
  if gdSelected in State then Inc(SelectedDraws);
end;
procedure TEvents.SelectCell(Sender: TObject; Col, Row: Longint; var CanSelect: Boolean);
begin Inc(Selects); CanSelect := Row <> Veto; end;
procedure TEvents.Click(Sender: TObject); begin Inc(Clicks); end;
procedure TEvents.DblClick(Sender: TObject); begin Inc(DblClicks); end;
procedure TEvents.TopLeft(Sender: TObject); begin Inc(TopLefts); end;
procedure TEvents.MultiSelect(Sender: TObject; Index: Integer); begin LastSelect := Index; end;
begin
  LogLine('STEP grids');
  Events := TEvents.Create; Events.Veto := -1;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Grids', WS_POPUP or WS_VISIBLE, 0, 0, 600, 420);
    Grid := TDrawGrid.Create(nil);
    Check((Grid.ColCount = 5) and (Grid.RowCount = 5) and (Grid.FixedCols = 1) and (Grid.FixedRows = 1) and
      (Grid.DefaultColWidth = 64) and (Grid.DefaultRowHeight = 24) and (Grid.Col = 1) and (Grid.Row = 1) and
      (Grid.Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect]) and
      (Grid.Color = clWindow) and Grid.TabStop, 'TDrawGrid has Delphi 1 defaults');
    Grid.OnDrawCell := Events.DrawCell; Grid.OnSelectCell := Events.SelectCell;
    Grid.OnClick := Events.Click; Grid.OnDblClick := Events.DblClick;
    Grid.OnTopLeftChanged := Events.TopLeft;
    Grid.SetBounds(10, 10, 300, 120); Grid.RowCount := 20;
    Grid.Parent := Root;
    Check(GetWindowLong(Grid.Handle, GWL_STYLE) and WS_BORDER <> 0, 'bsSingle gives the grid a border');
    Check(Same(Grid.CellRect(0, 0), 0, 0, 64, 24) and Same(Grid.CellRect(1, 1), 65, 25, 129, 49),
      'CellRect follows column widths, row heights and grid lines');
    Grid.MouseToCell(70, 30, ACol, ARow);
    Check((ACol = 1) and (ARow = 1), 'MouseToCell finds the cell under a point');
    Grid.MouseToCell(70, 1000, ACol, ARow);
    Check((ACol = -1) and (ARow = -1), 'MouseToCell outside the cells gives -1');
    Check(Grid.VisibleRowCount = (Grid.ClientHeight - 25) div 25, 'VisibleRowCount counts fully visible rows');
    GetScrollRange(Grid.Handle, SB_VERT, Min, Max);
    Check(Max > Min, 'a vertical scroll bar appears when rows do not fit');
    GetScrollRange(Grid.Handle, SB_HORZ, Min, Max);
    Check(Max > Min, 'a horizontal scroll bar appears when columns do not fit');

    Grid.SetFocus; Events.Draws := 0; Events.FixedDraws := 0; Events.FocusedDraws := 0;
    Grid.Invalidate; UpdateWindow(Grid.Handle);
    Check((Events.Draws > 0) and (Events.FixedDraws > 0) and (Events.FocusedDraws = 1),
      'Paint calls OnDrawCell with gdFixed and one gdFocused cell');
    Check(Pixel(Grid.Handle, 30, 10) = ColorToRGB(clBtnFace), 'fixed cells use FixedColor');
    Check(Pixel(Grid.Handle, 64, 10) = RGB(0, 0, 0), 'fixed grid lines are black');
    Check(Pixel(Grid.Handle, 129, 60) = ColorToRGB(clSilver), 'cell grid lines are silver');

    Events.Clicks := 0;
    Key(Grid.Handle, VK_DOWN);
    Check((Grid.Row = 2) and (Grid.Col = 1) and (Events.Clicks = 1), 'Down moves the focus and clicks');
    Key(Grid.Handle, VK_RIGHT); Key(Grid.Handle, VK_END);
    Check(Grid.Col = 4, 'End moves to the last column');
    Key(Grid.Handle, VK_HOME);
    Check(Grid.Col = 1, 'Home moves to the first non-fixed column');
    Events.Veto := 3;
    Key(Grid.Handle, VK_DOWN);
    Check(Grid.Row = 2, 'OnSelectCell can refuse a cell');
    Events.Veto := -1;
    Grid.Row := 2; Grid.Col := 1;
    Sel.Left := 1; Sel.Top := 2; Sel.Right := 3; Sel.Bottom := 4;
    Grid.Selection := Sel;
    Check((Grid.Selection.Left = 1) and (Grid.Selection.Bottom = 4) and (Grid.Col = 3) and (Grid.Row = 4),
      'Selection sets anchor and current cell');
    Grid.Row := 2;
    Check((Grid.Selection.Left = Grid.Selection.Right) and (Grid.Selection.Top = 2), 'moving the focus collapses the selection');

    Events.TopLefts := 0;
    Grid.Row := 15;
    Check((Grid.TopRow > 1) and (Grid.TopRow + Grid.VisibleRowCount - 1 = 15) and (Events.TopLefts = 1),
      'focusing a hidden row scrolls it into view');
    SendMessage(Grid.Handle, WM_VSCROLL, SB_TOP, 0);
    Check(Grid.TopRow = 1, 'SB_TOP scrolls to the first row');
    SendMessage(Grid.Handle, WM_VSCROLL, SB_LINEDOWN, 0);
    Check(Grid.TopRow = 2, 'SB_LINEDOWN scrolls one row');
    SendMessage(Grid.Handle, WM_VSCROLL, SB_BOTTOM, 0);
    Check(Grid.TopRow + Grid.VisibleRowCount = 20, 'SB_BOTTOM shows the last row');
    SendMessage(Grid.Handle, WM_VSCROLL, SB_THUMBTRACK, 0);
    Check(Grid.TopRow <> 1, 'thumb tracking is off by default');
    SendMessage(Grid.Handle, WM_VSCROLL, SB_THUMBPOSITION, 0);
    Check(Grid.TopRow = 1, 'SB_THUMBPOSITION moves to the thumb');
    Check(GetScrollPos(Grid.Handle, SB_VERT) = 0, 'the scroll position follows TopRow');

    Events.Clicks := 0;
    R := Grid.CellRect(3, 2);
    Click(Grid.Handle, R.Left + 5, R.Top + 5, False);
    Check((Grid.Col = 3) and (Grid.Row = 2) and (Events.Clicks = 1), 'clicking a cell focuses it and clicks');
    Click(Grid.Handle, 5, 5, False);
    Check((Grid.Col = 3) and (Grid.Row = 2), 'clicking a fixed cell does not move the focus');
    Click(Grid.Handle, R.Left + 5, R.Top + 5, True);
    Check(Events.DblClicks = 1, 'double click calls OnDblClick');

    Grid.ColWidths[1] := 30;
    Check(Same(Grid.CellRect(2, 2), 96, 50, 160, 74), 'ColWidths changes one column');
    Grid.DefaultColWidth := 50;
    Check(Grid.ColWidths[1] = 50, 'DefaultColWidth drops custom widths');
    Grid.ColCount := 3;
    Check(Grid.Col = 2, 'shrinking ColCount moves the focus inside the grid');
    GetScrollRange(Grid.Handle, SB_HORZ, Min, Max);
    Check(Max = Min, 'the horizontal scroll bar goes once the columns fit');
    Raised := False;
    try Grid.Options := Grid.Options + [goEditing]; except on EInvalidGridOperation do Raised := True; end;
    Check(Raised and not (goEditing in Grid.Options), 'unsupported options raise');
    Raised := False;
    try Grid.BorderStyle := bsNone; except on EInvalidGridOperation do Raised := True; end;
    Check(Raised, 'BorderStyle cannot change once the window exists');
    Grid.Options := Grid.Options + [goRowSelect];
    Check((Grid.Selection.Left = 1) and (Grid.Selection.Right = 2), 'goRowSelect selects whole rows');
    Grid.Options := [goThumbTracking];
    SendMessage(Grid.Handle, WM_VSCROLL, SB_THUMBTRACK, MakeLong(127, 0));
    Check(Grid.TopRow + Grid.VisibleRowCount = 20, 'goThumbTracking follows the thumb');

    Strings := TStringGrid.Create(nil);
    Strings.SetBounds(320, 10, 260, 150); Strings.Parent := Root;
    Strings.Cells[1, 1] := 'Calmira';
    Owned := TObject.Create;
    Strings.Objects[2, 1] := Owned;
    Check((Strings.Cells[1, 1] = 'Calmira') and (Strings.Rows[1][1] = 'Calmira') and
      (Strings.Cols[1][1] = 'Calmira') and (Strings.Objects[2, 1] = Owned) and (Strings.Cells[0, 0] = ''),
      'TStringGrid stores Cells and Objects, seen through Rows and Cols');
    Line := TStringList.Create; Line.Add('a'); Line.Add('b');
    Strings.Rows[3] := Line;
    Check((Strings.Cells[0, 3] = 'a') and (Strings.Cells[1, 3] = 'b') and (Strings.Cells[2, 3] = ''),
      'assigning Rows copies and pads');
    Raised := False;
    try Strings.Rows[3].Add('x'); except on EInvalidGridOperation do Raised := True; end;
    Check(Raised, 'rows have a fixed length');
    Strings.ColCount := 2;
    Check((Strings.Rows[1].Count = 2) and (Strings.Cells[1, 1] = 'Calmira'), 'shrinking keeps the remaining cells');
    UpdateWindow(Strings.Handle);
    R := Strings.CellRect(1, 1);
    Check(AnyInk(Strings.Handle, R), 'cell text is drawn');
    Line.Free; Owned.Free;

    Multi := TMultiGrid.Create(nil);
    Multi.SetBounds(320, 170, 260, 200); Multi.Parent := Root;
    Multi.DefaultColWidth := 64; Multi.DefaultRowHeight := 32;
    Multi.Limit := 10; Multi.OnSelect := Events.MultiSelect;
    Multi.SizeGrid;
    Check((Multi.ColCount = 4) and (Multi.RowCount = 3), 'Calmira''s TMultiGrid sizes itself');
    Multi.Select(5);
    Check(Multi.Selected[5] and (Multi.SelCount = 1) and (Multi.Focus = 5) and (Events.LastSelect = 5),
      'TMultiGrid.Select focuses and selects a cell');
    Check(Multi.MouseToCell(70, 40) = 5, 'TMultiGrid.MouseToCell gives the cell index');
    Check(Same(Multi.CellBounds(5), 64, 32, 128, 64), 'TMultiGrid.CellBounds uses CellRect');
    Multi.SelectAll;
    Check(Multi.SelCount = 10, 'SelectAll stops at Limit');
    Multi.SetSize(2, 6);
    Check((Multi.ColCount = 2) and (Multi.RowCount = 6) and Multi.Selected[5], 'SetSize keeps the selection');
    Multi.DropFocus := 3;
    Check(Multi.DropFocus = 3, 'DropFocus draws outside paint');
    Multi.DropFocus := -1;
    Pump;
    Check(Root.CallbackErrors = 0, 'no native callback errors');
    if Grid.CallbackErrors <> 0 then LogLine('INFO grid ' + Grid.LastCallbackError);
    Check((Grid.CallbackErrors = 0) and (Strings.CallbackErrors = 0) and (Multi.CallbackErrors = 0),
      'no grid callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Multi.Free; Strings.Free; Grid.Free; Root.Free; Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
