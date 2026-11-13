program TestWin16Captions;
{ Starts the real CALMIRA.EXE and opens My Computer through a DOS script.
  By default Windows draws the caption, as for any Windows 3.1 program, and
  centres the title; with [Preferences] Win95Captions=1 (built with
  -dWIN95CAPTIONS) Calmira draws its Windows 95 caption, the title on the
  left after the small icon. }
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

procedure Configure;
var S, K, V, F: array[0..79] of Char;
begin
  StrPCopy(F, 'C:\CALMIRA.INI');
  WritePrivateProfileString(StrPCopy(S, 'Scripts'), StrPCopy(K, 'EnableDosScripts'),
    StrPCopy(V, '1'), F);
  WritePrivateProfileString(StrPCopy(S, 'Scripts'), StrPCopy(K, 'DosScriptFilename'),
    StrPCopy(V, 'C:\CALMIRA.RUN'), F);
{$IFDEF WIN95CAPTIONS}
  WritePrivateProfileString(StrPCopy(S, 'Preferences'), StrPCopy(K, 'Win95Captions'),
    StrPCopy(V, '1'), F);
{$ENDIF}
end;

{ Columns of the caption bar, from its left end, with pixels in the colour
  of an active caption's text; the system menu box is left out. }
procedure TitleColumns(Window: HWND; var First, Last: Integer; var Width: Integer);
var DC: HDC; Area: TRect; X, Y, Top, Bottom, Left: Integer; Text: TColorRef;
begin
  First := -1; Last := -1;
  GetWindowRect(Window, Area);
  Width := Area.Right - Area.Left;
  Top := Area.Top + GetSystemMetrics(SM_CYFRAME);
  Bottom := Top + GetSystemMetrics(SM_CYCAPTION) - 2;
  Left := Area.Left + GetSystemMetrics(SM_CXFRAME) + GetSystemMetrics(SM_CXSIZE) + 2;
  DC := GetDC(0);
  Text := GetNearestColor(DC, GetSysColor(COLOR_CAPTIONTEXT));
  for X := Left to Area.Right - GetSystemMetrics(SM_CXFRAME) - 3 * GetSystemMetrics(SM_CXSIZE) do
    for Y := Top + 2 to Bottom - 2 do
      if GetPixel(DC, X, Y) = Text then
      begin
        if First < 0 then First := X - Area.Left;
        Last := X - Area.Left;
      end;
  ReleaseDC(0, DC);
end;

var
  Instance: THandle;
  Welcome, Tip, Window: HWND;
  First, Last, Width, Middle: Integer;
begin
{$IFDEF WIN95CAPTIONS}
  LogLine('Captions with Win95Captions=1');
{$ELSE}
  LogLine('Captions by default');
{$ENDIF}
  Configure;
  Instance := WinExec('C:\CALMIRA.EXE', SW_SHOWNORMAL);
  Check(Instance >= 32, 'CALMIRA.EXE starts');
  Welcome := WaitForTitle('Welcome', 40);
  if Welcome <> 0 then PostMessage(Welcome, WM_CLOSE, 0, 0);
  Tip := WaitForTitle('Tip of the Day', 15);
  if Tip <> 0 then PostMessage(Tip, WM_CLOSE, 0, 0);
  Pump(2000);
  WriteText('C:\CALMIRA.RUN', 'Macro'#13#10'$System'#13#10);
  Window := WaitForClass('TComputer', 30);
  Check(Window <> 0, 'a DOS script opens My Computer');
  if Window <> 0 then
  begin
    MoveWindow(Window, 100, 60, 440, 260, True);
    SetActiveWindow(Window);
    Pump(3000);
    TitleColumns(Window, First, Last, Width);
    Middle := (First + Last) div 2;
    LogLine('title columns ' + IntToStr(First) + '..' + IntToStr(Last) + ' of ' + IntToStr(Width));
    Check(First > 0, 'the active caption shows its title');
{$IFDEF WIN95CAPTIONS}
    Check((First < Width div 4) and (Middle < Width div 3),
      'Calmira draws its Windows 95 caption, the title on the left');
{$ELSE}
    Check(Abs(Middle - Width div 2) < Width div 10,
      'Windows draws the Windows 3.1 caption, the title in the middle');
{$ENDIF}
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
  Pump(60000);
end.
