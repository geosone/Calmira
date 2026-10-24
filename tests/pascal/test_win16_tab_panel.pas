program TestWin16TabPanel;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, Forms, ExtCtrls,
  Tabs, TabPanel;
type
  TEvents = class
    Clicks, DblClicks, Resizes, Changes, LastNewTab: Integer;
    Veto: Boolean;
    procedure Click(Sender: TObject);
    procedure DblClick(Sender: TObject);
    procedure Resize(Sender: TObject);
    procedure Change(Sender: TObject; NewTab: Integer; var AllowChange: Boolean);
  end;
  { Counts the CM_FOCUSCHANGED broadcast a form sends its controls. }
  TFocusPanel = class(TPanel)
  public
    Notices: Integer;
    LastSender: TWinControl;
    procedure CMFocusChanged(var Message: TCMFocusChanged); message CM_FOCUSCHANGED;
  end;
var Main: TForm; Outer, Inner: TPanel; Watch: TFocusPanel; Tabs: TTabPanel; Book: TNotebook;
  Events: TEvents; Failed, Raised: Boolean; DC: HDC; Edge: Integer; Area: TRect; Code: LongInt;
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
procedure TEvents.DblClick(Sender: TObject); begin Inc(DblClicks); end;
procedure TEvents.Resize(Sender: TObject); begin Inc(Resizes); end;
procedure TEvents.Change(Sender: TObject; NewTab: Integer; var AllowChange: Boolean);
begin
  Inc(Changes); LastNewTab := NewTab;
  AllowChange := not Veto;
end;
procedure TFocusPanel.CMFocusChanged(var Message: TCMFocusChanged);
begin
  Inc(Notices); LastSender := Message.Sender;
end;
function PixelAt(Control: TWinControl; X, Y: Integer): TColorRef;
begin
  DC := GetDC(Control.Handle);
  Result := GetPixel(DC, X, Y);
  ReleaseDC(Control.Handle, DC);
end;
function HasTextPixel(Control: TWinControl; const R: TRect): Boolean;
var X, Y: Integer; Face: TColorRef;
begin
  Result := False;
  DC := GetDC(Control.Handle);
  Face := GetPixel(DC, R.Left, R.Top);
  for Y := R.Top to R.Bottom - 1 do
    for X := R.Left to R.Right - 1 do
      if GetPixel(DC, X, Y) <> Face then begin Result := True; Break; end;
  ReleaseDC(Control.Handle, DC);
end;
procedure ClickAt(Control: TWinControl; X, Y: Integer);
begin
  SendMessage(Control.Handle, WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(X, Y));
  SendMessage(Control.Handle, WM_LBUTTONUP, 0, MakeLong(X, Y));
end;
begin
  LogLine('STEP tab panel');
  Events := TEvents.Create;
  try
    Main := TForm.Create(nil); Main.SetBounds(10, 10, 360, 300); Main.Caption := 'Panels';
    Outer := TPanel.Create(Main);
    Check((Outer.Width = 185) and (Outer.Height = 41) and (Outer.Alignment = taCenter) and
      (Outer.BevelOuter = bvRaised) and (Outer.BevelInner = bvNone) and (Outer.BevelWidth = 1) and
      (Outer.BorderWidth = 0) and (Outer.Color = clBtnFace), 'TPanel has Delphi''s defaults');
    Outer.Parent := Main; Outer.SetBounds(10, 10, 160, 100);
    Outer.BevelInner := bvLowered; Outer.BevelWidth := 2; Outer.BorderWidth := 3;
    Outer.OnClick := Events.Click; Outer.OnDblClick := Events.DblClick; Outer.OnResize := Events.Resize;
    Inner := TPanel.Create(Main); Inner.Parent := Outer; Inner.Align := alClient;
    Inner.BevelOuter := bvNone; Inner.Caption := 'Inner'; Inner.Color := clWhite;
    Watch := TFocusPanel.Create(Main); Watch.Parent := Main; Watch.SetBounds(180, 10, 160, 30);
    Main.Show; Pump;
    Area := Inner.BoundsRect;
    Check((Area.Left = 7) and (Area.Top = 7) and (Area.Right = 153) and (Area.Bottom = 93),
      'aligned children stay inside both bevels and the border');
    Check((PixelAt(Outer, 0, 0) = ColorToRGB(clBtnHighlight)) and
      (PixelAt(Outer, 159, 99) = ColorToRGB(clBtnShadow)), 'the raised outer bevel is light at the top left');
    Check((PixelAt(Outer, 5, 5) = ColorToRGB(clBtnShadow)) and
      (PixelAt(Outer, 3, 3) = ColorToRGB(clBtnFace)), 'the lowered inner bevel follows the border gap');
    Check(HasTextPixel(Inner, Rect(40, 30, 106, 56)) and not HasTextPixel(Inner, Rect(2, 2, 30, 20)),
      'the caption is drawn centred');
    Inner.Alignment := taLeftJustify; Pump;
    Check(HasTextPixel(Inner, Rect(0, 30, 30, 56)), 'Alignment moves the caption to the left');

    ClickAt(Outer, 2, 50);
    Check(Events.Clicks = 1, 'a press released inside fires OnClick');
    SendMessage(Outer.Handle, WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(2, 50));
    SendMessage(Outer.Handle, WM_LBUTTONUP, 0, MakeLong(400, 50));
    Check(Events.Clicks = 1, 'releasing outside does not click');
    Check(GetCapture = 0, 'the mouse is released after the press');
    Events.Resizes := 0;
    Outer.SetBounds(10, 10, 170, 110); Pump;
    Check((Events.Resizes >= 1) and (Inner.Width = 156), 'resizing fires OnResize and realigns');
    Raised := False;
    try Outer.BorderStyle := bsSingle; except on Exception do Raised := True; end;
    Check(Raised and (Outer.BorderStyle = bsNone), 'BorderStyle cannot change on a live panel');
    Outer.Free; Outer := nil; Inner := nil;

    Tabs := TTabPanel.Create(Main); Tabs.Parent := Main; Tabs.SetBounds(10, 60, 300, 200);
    Tabs.TabStop := True;
    Book := TNotebook.Create(Main); Book.Parent := Tabs; Book.Align := alClient;
    Book.Pages.Clear; Book.Pages.Add('General'); Book.Pages.Add('Desktop'); Book.Pages.Add('Taskbar');
    Book.PageIndex := 1;
    Tabs.Notebook := Book; Tabs.OnChange := Events.Change;
    Pump;
    Check((Tabs.Tabs.Count = 3) and (Tabs.Tabs[2] = 'Taskbar') and (Tabs.TabIndex = 1),
      'linking a notebook copies its pages and page');
    Check((Book.Top = Tabs.TabHeight + 1) and (Book.Left = 1), 'the notebook fills the bevelled area below the tabs');
    Tabs.TabIndex := 2;
    Check((Book.PageIndex = 2) and (Events.Changes = 1) and (Events.LastNewTab = 2),
      'TabIndex turns the notebook page and asks OnChange');
    Events.Veto := True;
    Tabs.TabIndex := 0;
    Check((Tabs.TabIndex = 2) and (Book.PageIndex = 2), 'OnChange can refuse a tab');
    Events.Veto := False; Events.Changes := 0;
    Book.PageIndex := 0;
    Check((Tabs.TabIndex = 0) and (Events.Changes = 0), 'turning the notebook moves the tab silently');

    Tabs.Repaint; Pump;
    Edge := LongInt(Tabs.Tabs.Objects[1]);
    Check((Edge > LongInt(Tabs.Tabs.Objects[0])) and (LongInt(Tabs.Tabs.Objects[0]) > 2),
      'painting records the right edge of each tab');
    ClickAt(Tabs, Edge - 4, 8);
    Check((Tabs.TabIndex = 1) and (Book.PageIndex = 1), 'clicking a tab selects it');
    ClickAt(Tabs, Edge - 4, Tabs.TabHeight + 20);
    Check(Tabs.TabIndex = 1, 'clicks below the tabs do not change the page');

    Code := SendMessage(Tabs.Handle, WM_GETDLGCODE, 0, 0);
    Check(Code and DLGC_WANTARROWS <> 0, 'the tab panel wants the arrow keys');
    Watch.Notices := 0;
    Tabs.SetFocus; Pump;
    Check(Tabs.Focused and (Watch.Notices >= 1) and (Watch.LastSender = Tabs),
      'focusing a control tells the form''s controls');
    SendMessage(Tabs.Handle, WM_KEYDOWN, VK_RIGHT, 0);
    SendMessage(Tabs.Handle, WM_KEYDOWN, VK_RIGHT, 0);
    Check((Tabs.TabIndex = 0) and (Book.PageIndex = 0), 'arrow keys cycle through the tabs');
    SendMessage(Tabs.Handle, WM_KEYDOWN, VK_LEFT, 0);
    Check(Tabs.TabIndex = 2, 'the left arrow wraps to the last tab');
    Tabs.SelectNext(True);
    Check(Tabs.TabIndex = 0, 'SelectNext moves on like Ctrl+Tab');
    Check(Book.Handle <> 0, 'the notebook survives page changes');

    Book.Free; Book := nil;
    Check(Tabs.Notebook = nil, 'freeing the notebook unlinks it');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Main.Free;
  Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
