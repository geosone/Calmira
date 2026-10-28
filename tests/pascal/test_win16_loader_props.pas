program TestWin16LoaderProps;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses Win31, WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, Forms, Menus, StdCtrls,
  ExtCtrls;
type
  TEvents = class
    Clicks, FormDbl, ImageDbl, EditDbl, RadioDbl, Keys, Chars: Integer;
    procedure Click(Sender: TObject);
    procedure FormDblClick(Sender: TObject);
    procedure ImageDblClick(Sender: TObject);
    procedure EditDblClick(Sender: TObject);
    procedure RadioDblClick(Sender: TObject);
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure KeyPress(Sender: TObject; var Key: Char);
  end;
  TProtectedLabel = class(TLabel);
var Events: TEvents; Main: TForm; Edit: TEdit; Failed: Boolean;
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
procedure TEvents.FormDblClick(Sender: TObject); begin Inc(FormDbl); end;
procedure TEvents.ImageDblClick(Sender: TObject); begin Inc(ImageDbl); end;
procedure TEvents.EditDblClick(Sender: TObject); begin Inc(EditDbl); end;
procedure TEvents.RadioDblClick(Sender: TObject); begin Inc(RadioDbl); end;
procedure TEvents.KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  Inc(Keys);
  if Key = VK_F6 then Key := 0;
end;
procedure TEvents.KeyPress(Sender: TObject; var Key: Char);
begin
  Inc(Chars);
  if Key = 'a' then Key := 'b';
end;
function SendKey(Window: HWND; Message, Key: Word; var Msg: TMsg): Boolean;
begin
  FillChar(Msg, SizeOf(Msg), 0);
  Msg.hwnd := Window; Msg.message := Message; Msg.wParam := Key; Msg.lParam := 1;
  Result := Main.ProcessDialogMessage(Msg);
end;
procedure Mouse(Window: HWND; Message: Word; X, Y: Integer);
begin
  SendMessage(Window, Message, MK_LBUTTON, MakeLong(X, Y));
  SendMessage(Window, WM_LBUTTONUP, 0, MakeLong(X, Y));
end;
procedure CheckLabels;
var Wide, Fixed, Right, Loading, Empty: TLabel;
begin
  Wide := TLabel.Create(Main);
  Check(Wide.AutoSize and (Wide.Width = 65) and (Wide.Height = 17), 'TLabel has Delphi''s defaults');
  Wide.Parent := Main; Wide.SetBounds(10, 100, 10, 10);
  Wide.Caption := 'A much longer label caption';
  Check((Wide.Width > 80) and (Wide.Height > 8) and (Wide.Height < 30) and (Wide.Left = 10),
    'an AutoSize label fits its caption');
  Fixed := TLabel.Create(Main); Fixed.Parent := Main;
  Fixed.AutoSize := False; Fixed.SetBounds(10, 120, 30, 16);
  Fixed.Caption := 'A much longer label caption';
  Check((Fixed.Width = 30) and (Fixed.Height = 16), 'AutoSize False keeps the bounds');
  Right := TLabel.Create(Main); Right.Parent := Main;
  Right.Alignment := taRightJustify; Right.SetBounds(300, 140, 40, 16);
  Right.Caption := 'A wider right label';
  Check((Right.Left + Right.Width = 340) and (Right.Width > 40), 'a right-aligned label keeps its right edge');
  Loading := TLabel.Create(Main);
  ComponentLoading(Loading); Loading.Parent := Main;
  Loading.SetBounds(10, 160, 5, 5); Loading.Caption := 'Loaded caption';
  Check(Loading.Width = 5, 'a loading label keeps its streamed size');
  TProtectedLabel(Loading).Loaded;
  Check((Loading.Width > 5) and not (csLoading in Loading.ComponentState), 'Loaded fits the label once');
  Empty := TLabel.Create(Main); Empty.Parent := Main; Empty.SetBounds(10, 180, 50, 50);
  Empty.Caption := 'x'; Empty.Caption := '';
  Check((Empty.Width > 0) and (Empty.Width < 10) and (Empty.Height > 8) and (Empty.Height < 30),
    'an empty caption measures one blank');

  Wide.Cursor := crIBeam;
  SetCursor(LoadCursor(0, IDC_ARROW));
  SetCursorPos(Main.ClientToScreen(Point(Wide.Left + 2, Wide.Top + 2)).X,
    Main.ClientToScreen(Point(Wide.Left + 2, Wide.Top + 2)).Y);
  SendMessage(Main.Handle, WM_SETCURSOR, Main.Handle, MakeLong(HTCLIENT, WM_MOUSEMOVE));
  Check(GetCursor = LoadCursor(0, IDC_IBEAM), 'the parent shows a graphic control''s Cursor');
  SetCursorPos(Main.ClientToScreen(Point(350, 10)).X, Main.ClientToScreen(Point(350, 10)).Y);
  SendMessage(Main.Handle, WM_SETCURSOR, Main.Handle, MakeLong(HTCLIENT, WM_MOUSEMOVE));
  Check(GetCursor <> LoadCursor(0, IDC_IBEAM), 'away from the control the cursor is not used');
  try
    Wide.Cursor := 12345;
    Check(False, 'an unknown graphic cursor is rejected');
  except on E: Exception do Check(Wide.Cursor = crIBeam, 'an unknown graphic cursor is rejected'); end;
end;
procedure CheckClicks;
var Image: TImage; Radio: TRadioButton; Box: TCheckBox; Hidden: TEdit; Msg: TMsg;
begin
  Image := TImage.Create(Main); Image.Parent := Main; Image.SetBounds(200, 10, 32, 32);
  Image.OnClick := Events.Click; Image.OnDblClick := Events.ImageDblClick;
  Main.OnDblClick := Events.FormDblClick;
  Mouse(Main.Handle, WM_LBUTTONDOWN, 210, 20);
  Check(Events.Clicks = 1, 'TImage.OnClick fires');
  Mouse(Main.Handle, WM_LBUTTONDBLCLK, 210, 20);
  Check((Events.ImageDbl = 1) and (Events.FormDbl = 0), 'a double click on an image reaches only the image');
  Mouse(Main.Handle, WM_LBUTTONDBLCLK, 300, 60);
  Check((Events.FormDbl = 1) and (Events.ImageDbl = 1), 'a double click on the form fires its OnDblClick');

  Edit.OnDblClick := Events.EditDblClick;
  Mouse(Edit.Handle, WM_LBUTTONDBLCLK, 5, 5);
  Check(Events.EditDbl = 1, 'TEdit.OnDblClick fires');
  Hidden := TEdit.Create(Main);
  Check(Hidden.HideSelection, 'HideSelection defaults to True');
  Hidden.HideSelection := False; Hidden.Parent := Main; Hidden.SetBounds(10, 40, 100, 24);
  Check(GetWindowLong(Hidden.Handle, GWL_STYLE) and ES_NOHIDESEL <> 0, 'HideSelection False sets ES_NOHIDESEL');
  try
    Hidden.HideSelection := True;
    Check(False, 'HideSelection is fixed once the window exists');
  except on E: Exception do Check(not Hidden.HideSelection, 'HideSelection is fixed once the window exists'); end;

  Radio := TRadioButton.Create(Main); Radio.Parent := Main; Radio.SetBounds(10, 200, 100, 17);
  Radio.OnDblClick := Events.RadioDblClick;
  SendMessage(Main.Handle, WM_COMMAND, GetDlgCtrlID(Radio.Handle), MakeLong(Radio.Handle, BN_DOUBLECLICKED));
  Check((Events.RadioDbl = 1) and not Radio.Checked, 'BN_DOUBLECLICKED fires TRadioButton.OnDblClick');

  Box := TCheckBox.Create(Main);
  Check(Box.Alignment = taRightJustify, 'TCheckBox.Alignment defaults to taRightJustify');
  Box.Alignment := taLeftJustify; Box.Parent := Main; Box.SetBounds(120, 200, 100, 17);
  Check(GetWindowLong(Box.Handle, GWL_STYLE) and BS_LEFTTEXT <> 0, 'taLeftJustify puts the caption left');
  Box.Alignment := taRightJustify;
  Check(GetWindowLong(Box.Handle, GWL_STYLE) and BS_LEFTTEXT = 0, 'Alignment changes a live checkbox');

  Main.OnKeyDown := Events.KeyDown; Main.OnKeyPress := Events.KeyPress;
  Check(not Main.KeyPreview and Main.AutoScroll, 'KeyPreview and AutoScroll have Delphi''s defaults');
  Check(not SendKey(Edit.Handle, WM_KEYDOWN, VK_F6, Msg) and (Events.Keys = 0), 'without KeyPreview the form sees no child keys');
  Main.KeyPreview := True;
  Check(SendKey(Edit.Handle, WM_KEYDOWN, VK_F6, Msg) and (Events.Keys = 1), 'KeyPreview: clearing Key consumes it');
  Check(not SendKey(Edit.Handle, WM_KEYDOWN, VK_F7, Msg) and (Events.Keys = 2) and (Msg.wParam = VK_F7),
    'KeyPreview: other keys go on to the control');
  Check(not SendKey(Edit.Handle, WM_CHAR, Ord('a'), Msg) and (Events.Chars = 1) and (Msg.wParam = Ord('b')),
    'KeyPreview: KeyPress can change the character');
  Check(not SendKey(Main.Handle, WM_KEYDOWN, VK_F6, Msg) and (Events.Keys = 2), 'keys sent to the form itself are not previewed');
  Main.KeyPreview := False;
end;
procedure CheckMenus;
var Popup: TPopupMenu; Open, Copy, Paste, Child, More: TMenuItem; Text: array[0..63] of Char;
  function ItemText(Index: Integer): string;
  begin
    GetMenuString(Popup.Handle, Index, Text, SizeOf(Text), MF_BYPOSITION);
    Result := StrPas(Text);
  end;
begin
  Popup := TPopupMenu.Create(Main);
  Open := NewItem('&Open', 0, False, True, nil, 0, 'Open');
  Open.ShortCutText := 'Enter';
  Copy := NewItem('&Copy', ShortCut(Ord('C'), [ssCtrl]), False, True, nil, 12, 'Copy');
  Paste := NewItem('&Paste', ShortCut(Ord('V'), [ssCtrl]), False, True, nil, 0, 'Paste');
  Paste.ShortCutText := 'Shift+Ins';
  Child := NewItem('&Child', 0, False, True, nil, 0, 'Child');
  More := NewSubMenu('&More', 40, 'More', [Child]);
  Popup.Items.Add(Open); Popup.Items.Add(Copy); Popup.Items.Add(Paste); Popup.Items.Add(More);
  Check(ItemText(0) = '&Open'#9'Enter', 'ShortCutText is shown after the caption');
  Check(ItemText(1) = '&Copy'#9'Ctrl+C', 'a ShortCut alone shows its key');
  Check(ItemText(2) = '&Paste'#9'Shift+Ins', 'ShortCutText takes precedence over ShortCut');
  Popup.HelpContext := 7;
  Check(Popup.HelpContext = 7, 'TPopupMenu.HelpContext');
  Check((Popup.GetHelpContext(Copy.Command, True) = 12) and (Popup.GetHelpContext(Child.Command, True) = 40) and
    (Popup.GetHelpContext(Open.Command, True) = 7) and (Popup.GetHelpContext(More.Handle, False) = 40),
    'GetHelpContext falls back to the parents and the popup menu');
end;
begin
  LogLine('STEP loader properties');
  Events := TEvents.Create;
  try
    Main := TForm.Create(nil); Main.SetBounds(10, 10, 400, 260); Main.Caption := 'Loader properties';
    Edit := TEdit.Create(Main); Edit.Parent := Main; Edit.SetBounds(10, 10, 100, 24);
    Main.Show; Pump;
    CheckLabels;
    CheckClicks;
    CheckMenus;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Main.Free;
  Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
