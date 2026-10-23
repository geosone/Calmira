program MenusTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, native_input, Menus;
type
  TSink = class
    Clicked: TMenuItem;
    Clicks, Popups: Integer;
    procedure Click(Sender: TObject);
    procedure Popup(Sender: TObject);
  end;
var Failed: Boolean; Sink: TSink;
{$I win16_stack_guard.inc}
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
begin Clicked := TMenuItem(Sender); Inc(Clicks); end;
procedure TSink.Popup(Sender: TObject);
begin Inc(Popups); end;
procedure Pump;
var Msg: TMsg;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
  begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
function MenuText(Menu: HMENU; Position: Integer): string;
var Buffer: array[0..127] of Char;
begin
  GetMenuString(Menu, Position, Buffer, SizeOf(Buffer), MF_BYPOSITION);
  Result := StrPas(Buffer);
end;
function Texts(Menu: HMENU): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to GetMenuItemCount(Menu) - 1 do
  begin
    if I > 0 then Result := Result + '|';
    if GetMenuState(Menu, I, MF_BYPOSITION) and MF_SEPARATOR <> 0 then Result := Result + '-'
    else Result := Result + MenuText(Menu, I);
  end;
end;
procedure Shortcuts;
var Key: Word; Shift: TShiftState;
begin
  Check(ShortCut(Ord('S'), [ssCtrl]) = scCtrl + Ord('S'), 'ShortCut value');
  Check(ShortCutToText(ShortCut(VK_DELETE, [ssShift, ssCtrl])) = 'Shift+Ctrl+Del', 'shortcut text');
  Check(ShortCutToText(ShortCut(VK_F4, [ssAlt])) = 'Alt+F4', 'function key text');
  Check(TextToShortCut('ctrl+alt+pgdn') = scCtrl + scAlt + VK_NEXT, 'text to shortcut');
  Check(TextToShortCut('Ctrl+Nonsense') = 0, 'unknown key');
  ShortCutToKey(scShift + Ord('A'), Key, Shift);
  Check((Key = Ord('A')) and (Shift = [ssShift]), 'shortcut to key');
end;
procedure Structure;
var Menu: TPopupMenu; Open, Save, Sub, Inner, Hidden: TMenuItem; H, SubHandle: HMENU;
begin
  Menu := NewPopupMenu(nil, 'Menu', paLeft, True, [
    NewItem('&Open', ShortCut(Ord('O'), [ssCtrl]), False, True, Sink.Click, 0, 'Open'),
    NewLine,
    NewSubMenu('&More', 0, 'More', [NewItem('&Inner', 0, True, False, Sink.Click, 0, 'Inner')]),
    NewItem('&Save', 0, False, True, Sink.Click, 0, 'Save')]);
  try
    Open := Menu.Items[0]; Sub := Menu.Items[2]; Inner := Sub[0]; Save := Menu.Items[3];
    H := Menu.Handle;
    Check(Texts(H) = '&Open'#9'Ctrl+O|-|&More|&Save', 'popup texts');
    SubHandle := GetSubMenu(H, 2);
    Check((SubHandle <> 0) and (SubHandle = Sub.Handle) and (Texts(SubHandle) = '&Inner'), 'submenu');
    Check(GetMenuState(SubHandle, Inner.Command, MF_BYCOMMAND) and (MF_CHECKED or MF_GRAYED) =
      MF_CHECKED or MF_GRAYED, 'initial checked and grayed');
    Check(GetMenuItemID(H, 0) = Open.Command, 'command id');
    Open.Checked := True; Save.Enabled := False;
    Check((GetMenuState(H, Open.Command, MF_BYCOMMAND) and MF_CHECKED <> 0) and
      (GetMenuState(H, Save.Command, MF_BYCOMMAND) and MF_GRAYED <> 0) and (Menu.Handle = H),
      'checked and enabled in place');
    { Calmira customizes live handles; in-place updates must keep them. }
    ModifyMenu(H, 3, MF_BYPOSITION or MF_STRING or MF_GRAYED, Save.Command, 'Custom');
    Save.Checked := True;
    Check(MenuText(H, 3) = 'Custom', 'customization survives Checked');
    Open.Caption := 'O&pen';
    Check(MenuText(H, 3) = '&Save', 'caption change rebuilds');
    Hidden := NewItem('Hidden', 0, False, True, nil, 0, '');
    Menu.Items.Insert(1, Hidden);
    Hidden.Visible := False;
    Check(Texts(H) = 'O&pen'#9'Ctrl+O|-|&More|&Save', 'invisible item skipped');
    Hidden.Visible := True;
    Check(Texts(H) = 'O&pen'#9'Ctrl+O|Hidden|-|&More|&Save', 'visible again');
    Hidden.Free;
    Check((Menu.Items.Count = 4) and (Texts(H) = 'O&pen'#9'Ctrl+O|-|&More|&Save'), 'freed item removed');
    Inner.Caption := 'Renamed';
    Check((GetSubMenu(H, 2) = SubHandle) and (Texts(SubHandle) = 'Renamed'), 'submenu rebuilt in place');
    Save.MenuIndex := 0;
    Check(MenuText(H, 0) = '&Save', 'menu index');
    Check((Menu.FindItem(Inner.Command, fkCommand) = Inner) and
      (Menu.FindItem(SubHandle, fkHandle) = Sub) and
      (Menu.FindItem(ShortCut(Ord('O'), [ssCtrl]), fkShortCut) = Open) and
      (Menu.FindItem($EFFF, fkCommand) = nil), 'FindItem');
    Sink.Clicks := 0; Save.Enabled := True;
    Check(Menu.DispatchCommand(Save.Command) and (Sink.Clicked = Save) and
      not Menu.DispatchCommand($EFFF), 'DispatchCommand');
    Inner.Enabled := False; Sink.Clicks := 0;
    Menu.DispatchCommand(Inner.Command);
    Check(Sink.Clicks = 0, 'disabled item does not click');
    Sub.Free;
    Check(Texts(H) = '&Save|O&pen'#9'Ctrl+O|-', 'freed submenu removed');
  finally Menu.Free; end;
end;
procedure TrackPopup;
var Menu: TPopupMenu; First, Second: TMenuItem;
begin
  Menu := NewPopupMenu(nil, 'Track', paLeft, True, [
    NewItem('&First', 0, False, True, Sink.Click, 0, ''),
    NewItem('&Second', 0, False, True, Sink.Click, 0, '')]);
  try
    First := Menu.Items[0]; Second := Menu.Items[1];
    Menu.OnPopup := Sink.Popup; Sink.Clicked := nil; Sink.Popups := 0;
    { Queue the keys first; TrackPopupMenu's own loop consumes them. }
    Menu.Items.Handle;
    PostMessage(PopupListWindow, WM_CHAR, Ord('s'), 0);
    Check(PopupListWindow <> 0, 'popup list window');
    Menu.Popup(20, 20);
    Pump;
    Check((Sink.Popups = 1) and (Sink.Clicked = Second) and (First <> nil), 'TrackPopupMenu selects by mnemonic');
  finally Menu.Free; end;
end;
procedure MainMenu;
var Menu: TMainMenu; Wnd: HWND; Edit: TMenuItem;
begin
  Wnd := CreateWindow('STATIC', 'menu host', WS_OVERLAPPEDWINDOW, 0, 0, 200, 120, 0, 0, HInstance, nil);
  Menu := NewMenu(nil, 'Main', [NewSubMenu('&File', 0, '', [NewItem('E&xit', 0, False, True, nil, 0, '')]),
    NewSubMenu('&Edit', 0, '', [NewItem('&Copy', 0, False, True, nil, 0, '')])]);
  try
    Menu.WindowHandle := Wnd;
    Check((GetMenu(Wnd) = Menu.Handle) and (Texts(Menu.Handle) = '&File|&Edit'), 'menu bar attached');
    Edit := Menu.Items[1];
    Edit.Caption := '&Bearbeiten';
    Check((GetMenu(Wnd) = Menu.Handle) and (Texts(GetMenu(Wnd)) = '&File|&Bearbeiten'), 'menu bar rebuilt');
    Menu.WindowHandle := 0;
    Check(GetMenu(Wnd) = 0, 'menu bar detached');
  finally Menu.Free; DestroyWindow(Wnd); end;
end;
procedure Resources;
var Before: Word; I: Integer; Menu: TPopupMenu;
begin
  Before := GetFreeSystemResources(GFSR_USERRESOURCES);
  for I := 1 to 40 do
  begin
    Menu := NewPopupMenu(nil, '', paLeft, True, [NewItem('a', 0, False, True, nil, 0, ''),
      NewSubMenu('b', 0, '', [NewItem('c', 0, False, True, nil, 0, '')])]);
    Menu.Handle;
    Menu.Free;
  end;
  Check(GetFreeSystemResources(GFSR_USERRESOURCES) + 1 >= Before, 'menu handles released');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP Menus');
  Sink := TSink.Create;
  try Shortcuts; Structure; TrackPopup; MainMenu; Resources;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Sink.Free;
  Check(StackGuardIntact, 'stack');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
