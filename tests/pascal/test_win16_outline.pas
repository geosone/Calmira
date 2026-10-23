program TestWin16Outline;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, StdCtrls, Forms, Grids,
  Outline, ScrTree, native_window;
type
  TEvents = class
    Expands, Collapses, LastExpand, Clicks, DblClicks, Draws, LastDrawRow, FocusDraws: Longint;
    Lazy: Boolean;
    procedure Expand(Sender: TObject; Index: Longint);
    procedure Collapse(Sender: TObject; Index: Longint);
    procedure Click(Sender: TObject);
    procedure DblClick(Sender: TObject);
    procedure DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  end;
var Root: TCustomControl; Tree: TScrollTree; Events: TEvents; Failed, Raised: Boolean;
  A, A1, A2, Between, B, Index: Longint; Data: Pointer; Lines: TStringList; P: TPoint;
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
procedure Pump;
var Msg: TMsg; Start: LongInt;
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < 150 do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure TEvents.Expand(Sender: TObject; Index: Longint);
begin
  Inc(Expands); LastExpand := Index;
  { Like Calmira's explorer: children are added when a node first opens. }
  if Lazy and not Tree.Items[Index].HasItems then Tree.AddChild(Index, 'Lazy');
end;
procedure TEvents.Collapse(Sender: TObject; Index: Longint); begin Inc(Collapses); end;
procedure TEvents.Click(Sender: TObject); begin Inc(Clicks); end;
procedure TEvents.DblClick(Sender: TObject); begin Inc(DblClicks); end;
procedure TEvents.DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  Inc(Draws); LastDrawRow := Index;
  if odFocused in State then Inc(FocusDraws);
end;
function Texts: string;
var I: Longint;
begin
  Result := '';
  for I := 1 to Tree.ItemCount do Result := Result + Tree.Items[I].Text + ' ';
end;
begin
  LogLine('STEP outline');
  Events := TEvents.Create;
  Lines := TStringList.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Outline', WS_POPUP or WS_VISIBLE, 0, 0, 400, 300);
    Tree := TScrollTree.Create(nil);
    Tree.SetBounds(10, 10, 200, 160); Tree.Parent := Root;
    Tree.OnExpand := Events.Expand; Tree.OnCollapse := Events.Collapse;
    Tree.OnClick := Events.Click; Tree.OnDblClick := Events.DblClick;
    Check((Tree.ItemCount = 0) and (Tree.SelectedItem = 0) and (Tree.ItemSeparator = '\') and
      (Tree.OutlineStyle = osTreePictureText) and (Tree.Options = [ooDrawTreeRoot, ooDrawFocusRect]),
      'a new outline is empty with Delphi''s defaults');

    Data := Pointer(Tree);
    A := Tree.Add(0, 'A');
    A1 := Tree.AddChild(A, 'A1');
    A2 := Tree.AddChildObject(A, 'A2', Data);
    B := Tree.Add(0, 'B');
    Between := Tree.Insert(B, 'Between');
    Check(Texts = 'A A1 A2 Between B ', 'items are indexed in pre-order over all nodes');
    Check((A = 1) and (A1 = 2) and (A2 = 3) and (Between = 4) and (Tree.ItemCount = 5),
      'Add, AddChild and Insert return the new index');
    Check((Tree.Items[3].Level = 2) and (Tree.Items[3].Parent = Tree.Items[1]) and (Tree.Items[3].Data = Data) and
      (Tree.Items[3].FullPath = 'A\A2') and (Tree.Items[3].TopItem = 1) and Tree.Items[1].HasItems,
      'node level, parent, data, full path and top item');
    Check((Tree.Items[1].GetFirstChild = 2) and (Tree.Items[1].GetNextChild(2) = 3) and
      (Tree.Items[1].GetNextChild(3) = -1) and (Tree.Items[1].GetPrevChild(3) = 2) and
      (Tree.Items[1].GetLastChild = 3) and (Tree.Items[2].GetFirstChild = -1),
      'child iteration ends with -1');
    Check((Tree.RowCount = 3) and not Tree.Items[2].IsVisible and Tree.Items[5].IsVisible,
      'only the expanded part is shown');
    Check((Tree.GetTextItem('Between') = 4) and (Tree.GetDataItem(Data) = 3) and (Tree.GetTextItem('none') = 0),
      'GetTextItem and GetDataItem');

    Tree.Items[1].Expand;
    Check(Tree.Items[1].Expanded and (Tree.RowCount = 5) and (Events.Expands = 1) and (Events.LastExpand = 1),
      'expanding shows the children and calls OnExpand');
    Events.Clicks := 0;
    Tree.SelectedItem := 3;
    Check((Tree.Row = 2) and (Tree.SelectedItem = 3) and (Events.Clicks = 1), 'SelectedItem selects the row and clicks');
    Tree.Items[1].Collapse;
    Check((Tree.SelectedItem = 1) and (Tree.RowCount = 3) and (Events.Collapses = 1),
      'collapsing moves the selection to the visible parent');
    Tree.SelectedItem := 3;
    Check(Tree.SelectedItem = 1, 'selecting a hidden item selects its visible parent');

    Events.Lazy := True;
    Tree.Items[5].Expanded := True;
    Check((Tree.ItemCount = 6) and (Tree.Items[6].Text = 'Lazy') and (Tree.Items[6].Level = 2) and (Tree.RowCount = 4),
      'OnExpand can add the children it shows');
    Events.Lazy := False;

    Tree.FullExpand;
    Check(Tree.RowCount = 6, 'FullExpand shows every item');
    Tree.TopRow := 0;
    Check((Tree.GetItem(0, Tree.ItemHeight * 2 + 1) = 3) and (Tree.GetItem(0, 1000) = 6),
      'GetItem finds the row under Y, clamped to the last one');
    Check((Tree.GetItemAt(5, Tree.ItemHeight + 2) = 2) and (Tree.GetItemAt(5, 1000) = 0) and
      (Tree.GetCellAt(5, Tree.ItemHeight + 2) = 1), 'TScrollTree.GetItemAt only finds cells with an item');
    Tree.FullCollapse;
    Check(Tree.RowCount = 3, 'FullCollapse leaves the top level');

    Tree.Items[1].Expand;
    Lines.Assign(Tree.Lines);
    Check((Lines.Count = 6) and (Lines[1] = #9'A1') and (Lines[5] = #9'Lazy'), 'Lines indent children with tabs');
    Tree.Lines.Clear;
    Tree.Lines.Add('X'); Tree.Lines.Add(#9'Y'); Tree.Lines.Add(#9#9'Z'); Tree.Lines.Add('W');
    Check((Texts = 'X Y Z W ') and (Tree.Items[3].Level = 3) and (Tree.Items[4].Level = 1),
      'adding lines builds the tree from tabs');
    Raised := False;
    try Tree.Lines.Add(#9#9#9'deep'); except on EOutlineError do Raised := True; end;
    Check(Raised, 'a line cannot skip a level');

    Tree.Items[4].MoveTo(1, oaAddChild);
    Check((Texts = 'X Y Z W ') and (Tree.Items[4].Level = 2) and (Tree.Items[1].GetLastChild = 4),
      'MoveTo attaches an item as a child');
    Tree.Items[4].ChangeLevelBy(-1);
    Check(Tree.Items[4].Level = 1, 'ChangeLevelBy -1 moves an item up a level');
    Tree.Items[4].ChangeLevelBy(1);
    Check((Tree.Items[4].Level = 2) and (Tree.Items[4].Parent = Tree.Items[1]),
      'ChangeLevelBy 1 makes an item the last child of its previous sibling');

    Tree.Items[1].Expand; Tree.SelectedItem := 2;
    Check(Tree.ChildNodeSelected, 'ChildNodeSelected for a nested item');
    Tree.DeleteSelectedNode;
    Check((Texts = 'X W ') and (Tree.SelectedItem <> 0), 'DeleteSelectedNode removes the item and its children');
    Raised := False;
    try Index := Tree.Items[9].Index; except on EOutlineError do Raised := True; end;
    Check(Raised, 'an invalid index raises EOutlineError');

    Tree.Clear;
    A := Tree.Add(0, 'Folder'); Tree.AddChild(A, 'Inner'); Tree.Add(0, 'Leaf');
    Tree.SelectedItem := 1; Events.DblClicks := 0;
    SendMessage(Tree.Handle, WM_LBUTTONDBLCLK, MK_LBUTTON, MakeLong(5, 2));
    SendMessage(Tree.Handle, WM_LBUTTONUP, 0, MakeLong(5, 2));
    Check(Tree.Items[1].Expanded and (Events.DblClicks = 1), 'double click opens the item and calls OnDblClick');
    WinProcs.SetFocus(Tree.Handle);
    SendMessage(Tree.Handle, WM_CHAR, Ord('-'), 0);
    Check(not Tree.Items[1].Expanded, '- closes the selected item');
    SendMessage(Tree.Handle, WM_CHAR, Ord('+'), 0);
    Check(Tree.Items[1].Expanded, '+ opens the selected item');

    Tree.Style := otOwnerDraw; Tree.OnDrawItem := Events.DrawItem;
    InvalidateRect(Tree.Handle, nil, True); UpdateWindow(Tree.Handle);
    Check((Events.Draws = 3) and (Events.LastDrawRow = 2) and (Events.FocusDraws = 1),
      'owner draw gets the grid row as Index');
    Tree.DropFocus := 1; Tree.DropFocus := -1;
    Check(Tree.DropFocus = -1, 'DropFocus draws and erases outside paint');
    Tree.Canvas.MoveTo(3, 4); P := Tree.Canvas.PenPos;
    Check((P.X = 3) and (P.Y = 4), 'Canvas.PenPos reads the current position');
    Tree.Canvas.MoveTo(2, 2); Tree.DottedLineTo(2, 10); P := Tree.Canvas.PenPos;
    Check((P.X = 2) and (P.Y = 10), 'DottedLineTo ends at the target');
    Check(Tree.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Tree.Free; Root.Free; Events.Free; Lines.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
