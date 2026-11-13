program TestWin16DesktopWallpaper;
{ Starts the real CALMIRA.EXE with a red 1024x768 wallpaper and opens
  Desktop Properties through a DOS script: the monitor in the dialog must
  show the wallpaper, also after the dialog has been painted again. }
{$mode delphi}{$H-}{$APPTYPE GUI}
uses WinTypes, WinProcs, SysUtils;
var
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

function Ticks: LongInt;
begin
  Result := LongInt(WinProcs.GetTickCount);
end;

procedure Pump(Milliseconds: LongInt);
var Msg: TMsg; Start: LongInt;
begin
  Start := Ticks;
  repeat
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
    begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
    Yield;
  until Ticks - Start >= Milliseconds;
end;

function WaitForClass(const ClassName: string; Seconds: Integer): HWND;
var Z: array[0..79] of Char; Start: LongInt;
begin
  Start := Ticks;
  repeat
    Result := FindWindow(StrPCopy(Z, ClassName), nil);
    if Result <> 0 then Exit;
    Pump(250);
  until Ticks - Start >= LongInt(Seconds) * 1000;
end;

function WaitForTitle(const Title: string; Seconds: Integer): HWND;
var Z: array[0..79] of Char; Start: LongInt;
begin
  Start := Ticks;
  repeat
    Result := FindWindow(nil, StrPCopy(Z, Title));
    if Result <> 0 then Exit;
    Pump(250);
  until Ticks - Start >= LongInt(Seconds) * 1000;
end;

procedure WriteText(const FileName, Text: string);
var F: HFILE; Z: array[0..79] of Char;
begin
  F := _lcreat(StrPCopy(Z, FileName), 0);
  if F <> HFILE_ERROR then begin _lwrite(F, @Text[1], Length(Text)); _lclose(F); end;
end;

{ A 1024x768 BMP in one colour, as large as the Calmira wallpaper: 4 bits
  as a VGA wallpaper, or 8 bits with a palette of Used colours (a
  256-colour image reduced to 236 lists only those). }
procedure WriteBitmap(const FileName: string; Bits, Used: Integer; Color: TColorRef);
const
  Width = 1024; Height = 768;
var F: HFILE; Header: array[0..54 + 1024 - 1] of Byte; Row: array[0..Width - 1] of Byte;
  Size, RowBytes, HeaderSize: LongInt; Y: Integer; Z: array[0..79] of Char;
  procedure Put(Offset: Integer; Value: LongInt; Count: Integer);
  var I: Integer;
  begin
    for I := 0 to Count - 1 do Header[Offset + I] := (Value shr (8 * I)) and $FF;
  end;
begin
  FillChar(Header, SizeOf(Header), 0);
  HeaderSize := 54 + 4 * LongInt(Used);
  RowBytes := (LongInt(Width) * Bits) div 8;
  Size := HeaderSize + RowBytes * Height;
  Header[0] := Ord('B'); Header[1] := Ord('M'); Put(2, Size, 4); Put(10, HeaderSize, 4);
  Put(14, 40, 4); Put(18, Width, 4); Put(22, Height, 4); Put(26, 1, 2); Put(28, Bits, 2);
  Put(34, RowBytes * Height, 4); Put(46, Used, 4); Put(50, Used, 4);
  { Palette entry 1 (blue, green, red, 0) is the colour; entry 0 stays black. }
  Header[54 + 4] := GetBValue(Color); Header[54 + 5] := GetGValue(Color);
  Header[54 + 6] := GetRValue(Color);
  if Bits = 4 then FillChar(Row, RowBytes, $11) else FillChar(Row, RowBytes, 1);
  F := _lcreat(StrPCopy(Z, FileName), 0);
  if F = HFILE_ERROR then begin Check(False, FileName + ' can be written'); Exit; end;
  _lwrite(F, @Header, HeaderSize);
  for Y := 1 to Height do _lwrite(F, @Row, RowBytes);
  _lclose(F);
end;

procedure Configure;
var S, K, V, F: array[0..79] of Char;
begin
  WriteBitmap('C:\WINDOWS\RED.BMP', 4, 16, RGB(255, 0, 0));
  WriteBitmap('C:\WINDOWS\BLUE256.BMP', 8, 236, RGB(0, 0, 255));
  WriteProfileString('Desktop', 'Wallpaper', 'C:\WINDOWS\RED.BMP');
  WriteProfileString('Desktop', 'TileWallpaper', '0');
  StrPCopy(F, 'C:\CALMIRA.INI');
  WritePrivateProfileString(StrPCopy(S, 'Scripts'), StrPCopy(K, 'EnableDosScripts'),
    StrPCopy(V, '1'), F);
  WritePrivateProfileString(StrPCopy(S, 'Scripts'), StrPCopy(K, 'DosScriptFilename'),
    StrPCopy(V, 'C:\CALMIRA.RUN'), F);
end;

{ Pixels of a colour on the screen inside the dialog, every fourth pixel;
  the screen, as the preview lies on a child window of the notebook. }
function Pixels(Dialog: HWND; Color: TColorRef): LongInt;
var DC: HDC; Area: TRect; X, Y: Integer;
begin
  Result := 0;
  GetWindowRect(Dialog, Area);
  DC := GetDC(0);
  Y := Area.Top;
  while Y < Area.Bottom do
  begin
    X := Area.Left;
    while X < Area.Right do
    begin
      if GetPixel(DC, X, Y) = Color then Inc(Result);
      Inc(X, 4);
    end;
    Inc(Y, 4);
  end;
  ReleaseDC(0, DC);
end;

{ The visible list box below Parent with an item containing Text, and the
  index of that item. }
function FindItem(Parent: HWND; const Text: string; var Index: Integer): HWND;
var Child: HWND; Count, I: Integer; Buffer: array[0..255] of Char;
begin
  Result := 0;
  Child := GetWindow(Parent, GW_CHILD);
  while (Child <> 0) and (Result = 0) do
  begin
    if IsWindowVisible(Child) then
    begin
      Count := SendMessage(Child, LB_GETCOUNT, 0, 0);
      GetClassName(Child, Buffer, SizeOf(Buffer));
      if (Pos('LISTBOX', UpperCase(StrPas(Buffer))) > 0) and (Count > 0) then
        for I := 0 to Count - 1 do
          if (SendMessage(Child, LB_GETTEXTLEN, I, 0) < SizeOf(Buffer)) and
            (SendMessage(Child, LB_GETTEXT, I, LongInt(@Buffer)) > 0) and
            (Pos(Text, UpperCase(StrPas(Buffer))) > 0) then
          begin Result := Child; Index := I; Break; end;
      if Result = 0 then Result := FindItem(Child, Text, Index);
    end;
    Child := GetWindow(Child, GW_HWNDNEXT);
  end;
end;

var
  Instance: THandle;
  Welcome, Tip, Dialog, List: HWND;
  First, Again: LongInt; Index: Integer;
begin
  LogLine('Desktop wallpaper preview');
  Configure;
  Instance := WinExec('C:\CALMIRA.EXE', SW_SHOWNORMAL);
  Check(Instance >= 32, 'CALMIRA.EXE starts');
  Welcome := WaitForTitle('Welcome', 40);
  if Welcome <> 0 then PostMessage(Welcome, WM_CLOSE, 0, 0);
  Tip := WaitForTitle('Tip of the Day', 15);
  if Tip <> 0 then PostMessage(Tip, WM_CLOSE, 0, 0);
  Pump(2000);
  WriteText('C:\CALMIRA.RUN', 'Macro'#13#10'$DesktopProp'#13#10);
  Dialog := WaitForClass('TDeskPropDlg', 30);
  Check(Dialog <> 0, 'a DOS script opens Desktop Properties');
  if Dialog <> 0 then
  begin
    Pump(3000);
    First := Pixels(Dialog, RGB(255, 0, 0));
    LogLine('red pixels after opening: ' + IntToStr(First));
    Check(First > 200, 'the monitor shows the wallpaper of WIN.INI');
    { A click on another wallpaper in the list. }
    List := FindItem(Dialog, 'BLUE256.BMP', Index);
    Check(List <> 0, 'the list offers the wallpapers of the Windows directory');
    if List <> 0 then
    begin
      SendMessage(List, LB_SETCURSEL, Index, 0);
      SendMessage(GetParent(List), WM_COMMAND, GetDlgCtrlID(List), MakeLong(List, LBN_SELCHANGE));
      Pump(3000);
      Again := Pixels(Dialog, RGB(0, 0, 255));
      LogLine('blue pixels after choosing BLUE256.BMP: ' + IntToStr(Again));
      Check(Again > 200, 'the monitor shows a wallpaper with a 236-colour palette chosen in the list');
      Check((FindWindow(nil, 'Error') = 0) and (FindWindow(nil, 'Fehler') = 0),
        'a reduced palette raises no error box');
      InvalidateRect(Dialog, nil, True);
      UpdateWindow(Dialog);
      Pump(3000);
      Again := Pixels(Dialog, RGB(0, 0, 255));
      LogLine('blue pixels after painting again: ' + IntToStr(Again));
      Check(Again > 200, 'the monitor still shows it after painting again');
    end;
    { The dialog stays open for the screenshot. }
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
  Pump(60000);
end.
