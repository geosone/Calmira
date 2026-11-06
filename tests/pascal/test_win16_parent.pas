program TestWin16Parent;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, StdCtrls, Menus, native_window;
type
  TSink = class
    Clicked: TObject; MouseUps, MouseDowns: Integer;
    procedure Click(Sender: TObject);
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  end;
var Root, Panel: TCustomControl; Sink: TSink; Text: TLabel; Button: TButton; Edit: TEdit;
  Failed: Boolean;
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
procedure TSink.Click(Sender: TObject);
begin Clicked := Sender; end;
procedure TSink.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin Inc(MouseDowns); end;
procedure TSink.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin Inc(MouseUps); end;
procedure Pump;
var Msg: TMsg;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
  begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure RightClick(Window: HWND; Menu: TPopupMenu);
begin
  { Queue the key first; TrackPopupMenu's own loop consumes it. }
  Menu.Items.Handle;
  PostMessage(PopupListWindow, WM_CHAR, Ord('s'), 0);
  SendMessage(Window, WM_RBUTTONDOWN, MK_RBUTTON, MakeLong(5, 5));
  Pump;
end;
procedure PopupMenus;
var Menu: TPopupMenu;
begin
  Menu := NewPopupMenu(nil, 'Context', paLeft, True, [
    NewItem('&First', 0, False, True, Sink.Click, 0, ''),
    NewItem('&Second', 0, False, True, Sink.Click, 0, '')]);
  Panel.PopupMenu := Menu; Panel.OnMouseUp := Sink.MouseUp; Panel.OnMouseDown := Sink.MouseDown;
  { Delphi 1 opens the menu on the right press, so USER tracks it with the
    button down and highlights nothing until the mouse moves. }
  RightClick(Panel.Handle, Menu);
  Check((Sink.Clicked = Menu.Items[1]) and (Menu.PopupComponent = Panel) and (Sink.MouseDowns = 0),
    'a right-button press opens PopupMenu instead of MouseDown');
  Sink.Clicked := nil;
  SendMessage(Panel.Handle, WM_RBUTTONUP, 0, MakeLong(5, 5)); Pump;
  Check((Sink.Clicked = nil) and (Sink.MouseUps = 1), 'a right-button release opens no menu');
  Menu.AutoPopup := False; Sink.MouseUps := 0;
  SendMessage(Panel.Handle, WM_RBUTTONDOWN, MK_RBUTTON, MakeLong(5, 5)); Pump;
  Check((Sink.Clicked = nil) and (Sink.MouseDowns = 1), 'without AutoPopup MouseDown is reported');
  Menu.AutoPopup := True; Sink.Clicked := nil;
  Text.SetBounds(0, 0, 60, 20); Text.PopupMenu := Menu;
  RightClick(Root.Handle, Menu);
  Check((Sink.Clicked = Menu.Items[1]) and (Menu.PopupComponent = Text), 'graphic controls open PopupMenu too');
  Menu.Free;
  Check((Panel.PopupMenu = nil) and (Text.PopupMenu = nil), 'a freed menu is cleared from its controls');
end;
{ A folder window's header comes before its grid in the form, but the grid
  is first in tab order. The grid still lies over the header, as in Delphi,
  where the stacking follows insertion and not the tab order. }
procedure TabbedOrder;
var Holder, Header, Grid: TCustomControl;
begin
  Holder := TCustomControl.Create(nil); Holder.SetBounds(0, 0, 200, 100);
  Header := TCustomControl.Create(nil); Header.SetBounds(0, 0, 200, 18); Header.Parent := Holder;
  Grid := TCustomControl.Create(nil); Grid.SetBounds(0, 14, 200, 80); Grid.Parent := Holder;
  Grid.TabOrder := 0;
  Holder.Parent := Root;
  Check((Grid.TabOrder = 0) and (GetWindow(Holder.Handle, GW_CHILD) = Grid.Handle) and
    (GetWindow(Grid.Handle, GW_HWNDNEXT) = Header.Handle),
    'stacking follows insertion, not tab order');
  Grid.Free; Header.Free; Holder.Free;
end;
begin
  LogLine('STEP parent properties');
  Sink := TSink.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Parent properties', WS_POPUP or WS_VISIBLE, 10, 10, 300, 200);
    Root.Font.Height := -16; Root.Color := clWhite;
    Panel := TCustomControl.Create(nil); Panel.SetBounds(0, 0, 200, 100); Panel.Parent := Root;
    Text := TLabel.Create(nil); Text.Parent := Panel; Text.Caption := 'Inherited';
    Button := TButton.Create(nil); Button.SetBounds(0, 40, 75, 23); Button.Parent := Panel;
    Edit := TEdit.Create(nil); Edit.SetBounds(0, 70, 100, 23); Edit.Parent := Panel;
    Check((GetWindow(Panel.Handle, GW_CHILD) = Edit.Handle) and
      (GetWindow(Edit.Handle, GW_HWNDNEXT) = Button.Handle),
      'a later sibling lies above an earlier one, as in Delphi');
    Button.Parent := nil; Button.Parent := Panel;
    Check(GetWindow(Panel.Handle, GW_CHILD) = Button.Handle, 'a re-added sibling goes on top');
    TabbedOrder;
    Check(Panel.ParentFont and (Panel.Font.Height = -16) and (Panel.Canvas.Font.Height = -16),
      'a new child takes the parent font and keeps ParentFont');
    Check((Text.Font.Height = -16) and (Button.Font.Height = -16), 'grandchildren inherit too');
    Check((Panel.Color = clWhite) and Panel.ParentColor and (Text.Color = clWhite),
      'ParentColor copies the parent colour');
    Check(not Edit.ParentColor and (Edit.Color = clWindow), 'TEdit starts with clWindow, ParentColor False');
    Root.Font.Height := -20;
    Check((Text.Font.Height = -20) and
      (HFONT(SendMessage(Button.Handle, WM_GETFONT, 0, 0)) = Button.Font.Handle),
      'a parent font change reaches native grandchildren');
    Panel.Font.Height := -9;
    Check(not Panel.ParentFont and (Text.Font.Height = -9), 'assigning Font clears ParentFont');
    Root.Font.Height := -22;
    Check((Panel.Font.Height = -9) and (Text.Font.Height = -9), 'an own font is kept');
    Panel.ParentFont := True;
    Check((Panel.Font.Height = -22) and (Text.Font.Height = -22), 'ParentFont := True re-inherits');
    Panel.Color := clRed;
    Check(not Panel.ParentColor and (Text.Color = clRed), 'assigning Color clears ParentColor');
    Panel.ParentColor := True;
    Check((Panel.Color = clWhite) and (Text.Color = clWhite), 'ParentColor := True re-inherits');
    Root.Ctl3D := False;
    Check(not Panel.Ctl3D and Panel.ParentCtl3D and not Button.Ctl3D, 'Ctl3D follows ParentCtl3D');
    Panel.Ctl3D := True;
    Check(not Panel.ParentCtl3D and Button.Ctl3D, 'assigning Ctl3D clears ParentCtl3D');
    Root.ShowHint := True; Text.Hint := 'Tip';
    Check(Text.ShowHint and Text.ParentShowHint and (Text.Hint = 'Tip'), 'ShowHint follows ParentShowHint');
    Text.Parent := nil; Root.Font.Height := -11; Text.Parent := Root;
    Check(Text.Font.Height = -11, 'reparenting re-reads the new parent');
    PopupMenus;
    Check((Root.CallbackErrors = 0) and (Panel.CallbackErrors = 0), 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Edit.Free; Button.Free; Text.Free; Panel.Free; Root.Free; Sink.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
