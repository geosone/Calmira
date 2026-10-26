program TestWin16FormMenu;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, Forms, Menus, StdCtrls,
  ExtCtrls, Buttons;
type
  TEvents = class
    Clicks, Opens, Moves: Integer;
    procedure Click(Sender: TObject);
    procedure Open(Sender: TObject);
    procedure Move(Sender: TObject; Shift: TShiftState; X, Y: Integer);
  end;
  TProtectedWin = class(TWinControl);
  TProtectedControl = class(TControl);
var Events: TEvents; Main: TForm; Bar: TMainMenu; FileItem, SaveItem, KeyItem: TMenuItem;
  Memo: TMemo; Edit: TEdit; List: TListBox; Button: TBitBtn; Panel: TPanel; Shape: TShape;
  Failed: Boolean;
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
procedure TEvents.Click(Sender: TObject); begin Inc(Clicks); end;
procedure TEvents.Open(Sender: TObject); begin Inc(Opens); end;
procedure TEvents.Move(Sender: TObject; Shift: TShiftState; X, Y: Integer); begin Inc(Moves); end;
function KeyMessage(Window: HWND; Key: Word): Boolean;
var Msg: TMsg;
begin
  FillChar(Msg, SizeOf(Msg), 0);
  Msg.hwnd := Window; Msg.message := WM_KEYDOWN; Msg.wParam := Key; Msg.lParam := 1;
  Result := Main.ProcessDialogMessage(Msg);
end;
procedure CheckMenu;
begin
  KeyItem := NewItem('&Refresh', ShortCut(VK_F5, []), False, True, Events.Click, 0, 'KeyItem');
  SaveItem := NewItem('&Save', 0, False, True, Events.Click, 0, 'SaveItem');
  FileItem := NewSubMenu('&File', 0, 'FileItem', [SaveItem, KeyItem]);
  FileItem.OnClick := Events.Open;
  Bar := NewMenu(Main, 'Bar', [FileItem]);
  Main.Menu := Bar;
  Check(GetMenu(Main.Handle) = Bar.Handle, 'assigning Menu attaches the menu bar');
  SendMessage(Main.Handle, WM_COMMAND, SaveItem.Command, 0);
  Check(Events.Clicks = 1, 'a menu command clicks its item');
  SendMessage(Main.Handle, WM_INITMENUPOPUP, FileItem.Handle, 0);
  Check(Events.Opens = 1, 'opening a submenu fires its OnClick');
  Check(KeyMessage(Edit.Handle, VK_F5) and (Events.Clicks = 2), 'a menu shortcut clicks its item');
  KeyItem.Enabled := False;
  Check(not KeyMessage(Edit.Handle, VK_F5) and (Events.Clicks = 2), 'a disabled item ignores its shortcut');
  Check((KeyDataToShiftState($20000000) = [ssAlt]) and (KeyDataToShiftState(0) = []),
    'KeyDataToShiftState reads Alt from the key data');
  Main.Menu := nil;
  Check(GetMenu(Main.Handle) = 0, 'clearing Menu detaches the menu bar');
  Main.Menu := Bar; Bar.Free;
  Check(Main.Menu = nil, 'a freed menu leaves the form');
end;
procedure CheckMemo;
var Style: LongInt;
begin
  Memo := TMemo.Create(Main);
  Check(Memo.WordWrap and Memo.WantReturns and not Memo.WantTabs and (Memo.ScrollBars = ssNone),
    'TMemo has Delphi''s defaults');
  Memo.ScrollBars := ssVertical;
  Memo.Parent := Main; Memo.SetBounds(10, 40, 150, 80);
  Style := GetWindowLong(Memo.Handle, GWL_STYLE);
  Check((Style and ES_MULTILINE <> 0) and (Style and WS_VSCROLL <> 0) and (Style and ES_AUTOHSCROLL = 0),
    'a word-wrapping memo is multi-line with a vertical scroll bar');
  Memo.Lines.Add('one'); Memo.Lines.Add('two'); Memo.Lines.Insert(1, 'mid');
  Check((Memo.Text = 'one'#13#10'mid'#13#10'two') and (Memo.Lines.Count = 3) and (Memo.Lines[2] = 'two'),
    'Lines are the text''s CR/LF-separated lines');
  Memo.Lines.Delete(0); Memo.Lines[0] := 'first';
  Check(Memo.Text = 'first'#13#10'two', 'changing Lines rewrites the text');
  Memo.Lines.Clear;
  Check((Memo.Text = '') and (Memo.Lines.Count = 0), 'clearing Lines empties the memo');
  Check(SendMessage(Memo.Handle, WM_GETDLGCODE, 0, 0) and DLGC_WANTTAB = 0, 'without WantTabs Tab is not wanted');
  Memo.SetFocus;
  Check(KeyMessage(Memo.Handle, VK_TAB) and (GetFocus <> Memo.Handle), 'Tab leaves the memo');
  Memo.WantTabs := True;
  Check(SendMessage(Memo.Handle, WM_GETDLGCODE, 0, 0) and DLGC_WANTTAB <> 0, 'WantTabs asks for Tab');
  Memo.WordWrap := True;
end;
procedure CheckControls;
var Area: TRect; Point1: TPoint;
begin
  Edit.OEMConvert := True;
  Check(GetWindowLong(Edit.Handle, GWL_STYLE) and ES_OEMCONVERT <> 0, 'OEMConvert sets the edit style');
  Button := TBitBtn.Create(Main);
  ComponentLoading(Button); Button.Caption := 'Stop'; Button.Kind := bkCancel;
  Check((Button.Caption = 'Stop') and Button.Cancel and (Button.ModalResult = mrCancel),
    'a streamed caption survives Kind');
  Button.Free;
  Button := TBitBtn.Create(Main);
  Button.Kind := bkOK;
  Check((Button.Caption = 'OK') and Button.Default and not Button.Cancel and (Button.ModalResult = mrOK),
    'Kind sets the caption, Default and ModalResult');
  Panel := TPanel.Create(Main); Panel.Parent := Main; Panel.SetBounds(200, 10, 100, 100);
  Shape := TShape.Create(Main); Panel.InsertControl(Shape); Shape.SetBounds(10, 10, 20, 20);
  List := TListBox.Create(Main); Panel.InsertControl(List); List.SetBounds(40, 40, 50, 50);
  Check((Shape.Parent = Panel) and (List.Parent = Panel), 'InsertControl adopts graphic and windowed children');
  Check((Panel.ControlAtPos(Point(15, 15), False) = Shape) and (Panel.ControlAtPos(Point(45, 45), False) = List) and
    (Panel.ControlAtPos(Point(35, 5), False) = nil), 'ControlAtPos finds the child under the point');
  Shape.Visible := False;
  Check(Panel.ControlAtPos(Point(15, 15), True) = nil, 'ControlAtPos skips hidden children');
  Point1 := TControl(Shape).ClientToScreen(Point(0, 0));
  Check((Point1.X = Panel.ClientToScreen(Point(10, 10)).X) and (TControl(Shape).ScreenToClient(Point1).Y = 0) and
    (TControl(List).ScreenToClient(TControl(List).ClientToScreen(Point(3, 4))).X = 3),
    'ClientToScreen works through a TControl reference');
  TProtectedControl(List).OnMouseMove := Events.Move;
  Check(Events.Moves = 0, 'OnMouseMove set through TControl reaches a windowed control');
  List.OnClick := Events.Click;
  TProtectedWin(List).Click;
  Check(Events.Clicks = 3, 'Click is virtual from TWinControl down');
  Area := Rect(0, 0, 10, 10);
  Check(PtInRect(Area, Point(9, 9)) and not PtInRect(Area, Point(10, 5)) and
    PtInRect(Panel.ClientRect, Point(99, 0)) and not PtInRect(Panel.ClientRect, Point(-1, 0)),
    'WinProcs.PtInRect takes a const rectangle and answers correctly');
end;
procedure CheckIcon;
var Source, Copy: TIcon; Stream: TMemoryStream; Marker: LongInt; Size: LongInt;
  First, Second: TBitmap; X, Y: Integer; Same: Boolean;
begin
  Source := TIcon.Create; Copy := TIcon.Create; Stream := TMemoryStream.Create;
  First := TBitmap.Create; Second := TBitmap.Create;
  try
    Source.CopyFromHandle(LoadIcon(0, IDI_EXCLAMATION));
    Source.SaveToStream(Stream);
    Size := Stream.Size;
    Marker := $12345678; Stream.WriteBuffer(Marker, SizeOf(Marker));
    Stream.Position := 0;
    Copy.LoadFromStream(Stream);
    Marker := 0; Stream.ReadBuffer(Marker, SizeOf(Marker));
    Check((Size = 766) and (Stream.Position = Size + 4) and (Marker = $12345678),
      'an icon stream ends where the next data begins');
    First.Width := 32; First.Height := 32; Second.Width := 32; Second.Height := 32;
    First.Canvas.Brush.Color := clFuchsia; First.Canvas.FillRect(Rect(0, 0, 32, 32));
    Second.Canvas.Brush.Color := clFuchsia; Second.Canvas.FillRect(Rect(0, 0, 32, 32));
    First.Canvas.Draw(0, 0, Source); Second.Canvas.Draw(0, 0, Copy);
    Same := True;
    for Y := 0 to 31 do
      for X := 0 to 31 do
        if First.Canvas.Pixels[X, Y] <> Second.Canvas.Pixels[X, Y] then Same := False;
    Check(Same and (First.Canvas.Pixels[0, 0] = clFuchsia), 'a reloaded icon draws the same pixels and mask');
  finally
    Second.Free; First.Free; Stream.Free; Copy.Free; Source.Free;
  end;
end;
begin
  LogLine('STEP form menu');
  Events := TEvents.Create;
  try
    Main := TForm.Create(nil); Main.SetBounds(10, 10, 360, 220); Main.Caption := 'Menus';
    Edit := TEdit.Create(Main); Edit.Parent := Main; Edit.SetBounds(10, 10, 100, 24);
    Main.Show; Pump;
    CheckMenu;
    CheckMemo;
    CheckControls;
    CheckIcon;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Main.Free;
  Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
