program TestWin16ComputerWindow;
{ Starts the real CALMIRA.EXE in German and opens My Computer: the names of
  the desktop windows and, in the screenshot, the number of objects. }
{$mode delphi}{$H-}{$APPTYPE GUI}
uses WinTypes, WinProcs, SysUtils;
var
  Failed: Boolean;
  Started: LongInt;

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

{ USER's tick count; SysUtils.GetTickCount is not usable on Win16. LongInt
  differences stay right across bit 31. }
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

function Find(const Title: string): HWND;
var Z: array[0..79] of Char;
begin
  Result := FindWindow(nil, StrPCopy(Z, Title));
end;

{ Waits for a top-level window; 0 if it does not appear in time. }
function WaitFor(const Title: string; Seconds: Integer): HWND;
var Start: LongInt;
begin
  Start := Ticks;
  repeat
    Result := Find(Title);
    if Result <> 0 then Exit;
    Pump(250);
  until Ticks - Start >= LongInt(Seconds) * 1000;
end;

function Elapsed: string;
begin
  Result := IntToStr((Ticks - Started) div 1000) + ' s';
end;

function StartEntry(const Section, Key: string): string;
var S, K, D, F: array[0..79] of Char; Buffer: array[0..255] of Char;
begin
  GetPrivateProfileString(StrPCopy(S, Section), StrPCopy(K, Key), StrPCopy(D, ''),
    Buffer, SizeOf(Buffer), StrPCopy(F, 'C:\START.INI'));
  Result := StrPas(Buffer);
end;

function CalmiraEntry(const Section, Key: string): string;
var S, K, D, F: array[0..79] of Char; Buffer: array[0..255] of Char;
begin
  GetPrivateProfileString(StrPCopy(S, Section), StrPCopy(K, Key), StrPCopy(D, ''),
    Buffer, SizeOf(Buffer), StrPCopy(F, 'C:\CALMIRA.INI'));
  Result := StrPas(Buffer);
end;

{ The submenus of Programs come first, in alphabetical order, then the
  programs: no group may follow a program. }
function FoldersFirst: Boolean;
var S, D, F: array[0..79] of Char; Buffer: array[0..4095] of Char;
  P: PChar; Key, Last: string; SeenItem: Boolean;
begin
  Result := True; SeenItem := False; Last := '';
  GetPrivateProfileString(StrPCopy(S, 'Start\&Programs'), nil, StrPCopy(D, ''), Buffer,
    SizeOf(Buffer), StrPCopy(F, 'C:\START.INI'));
  P := Buffer;
  while P^ <> #0 do
  begin
    Key := StrPas(P);
    if Key[Length(Key)] = '*' then
    begin
      if SeenItem or (CompareText(Key, Last) < 0) then Result := False;
      Last := Key;
    end
    else SeenItem := True;
    Inc(P, StrLen(P) + 1);
  end;
end;

{ A stale Start menu image cache: a valid 1x1 bitmap of 58 bytes. }
procedure WriteStaleCache;
const Bytes: array[0..57] of Byte = (
  $42,$4D, 58,0,0,0, 0,0,0,0, 54,0,0,0,
  40,0,0,0, 1,0,0,0, 1,0,0,0, 1,0, 24,0, 0,0,0,0, 4,0,0,0,
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, $C0,$C0,$C0,0);
var F: HFILE;
begin
  F := _lcreat('C:\BMPCACHE.BMP', 0);
  if F <> HFILE_ERROR then begin _lwrite(F, @Bytes, SizeOf(Bytes)); _lclose(F); end;
end;

function CacheSize: LongInt;
var F: HFILE;
begin
  Result := -1;
  F := _lopen('C:\BMPCACHE.BMP', OF_READ);
  if F = HFILE_ERROR then Exit;
  Result := _llseek(F, 0, 2); _lclose(F);
end;

{ Calmira in German, as setup leaves it: C:\LANG\DE.LNG and
  [Language] Selected=de. }
procedure UseGerman;
var Source, Target: HFILE; Buffer: array[0..1023] of Byte; Count: Integer;
  S, K, V, F: array[0..79] of Char;
begin
  CreateDir('C:\LANG');
  Source := _lopen('C:\DE.LNG', OF_READ);
  Target := _lcreat('C:\LANG\DE.LNG', 0);
  Check((Source <> HFILE_ERROR) and (Target <> HFILE_ERROR), 'the German catalogue is in C:\LANG');
  repeat
    Count := _lread(Source, @Buffer, SizeOf(Buffer));
    if Count > 0 then _lwrite(Target, @Buffer, Count);
  until Count <= 0;
  _lclose(Source); _lclose(Target);
  WritePrivateProfileString(StrPCopy(S, 'Language'), StrPCopy(K, 'Selected'),
    StrPCopy(V, 'de'), StrPCopy(F, 'C:\CALMIRA.INI'));
  { A name of the user, which the catalogue must not replace. }
  WritePrivateProfileString(StrPCopy(S, 'Bin'), StrPCopy(K, 'Caption'),
    StrPCopy(V, 'Abfall'), StrPCopy(F, 'C:\CALMIRA.INI'));
  { A program without an icon of its own, as EXPLORER.EXE was once UPX
    had dropped its resources: GDITEST.EXE itself has none. }
  WritePrivateProfileString(StrPCopy(S, 'Programs'), StrPCopy(K, 'C:\GDITEST.EXE'),
    StrPCopy(V, 'Ohne Symbol'), StrPCopy(F, 'C:\CALMIRA.INI'));
end;

var
  Instance: THandle;
  Welcome, Tip, Computer: HWND;
begin
  LogLine('Computer window');
  UseGerman;
  Started := Ticks;
  Instance := WinExec('C:\CALMIRA.EXE', SW_SHOWNORMAL);
  Check(Instance >= 32, 'CALMIRA.EXE starts');
  Welcome := WaitFor('Willkommen', 40);
  if Welcome <> 0 then PostMessage(Welcome, WM_CLOSE, 0, 0);
  Tip := WaitFor('Tipp des Tages', 15);
  if Tip <> 0 then PostMessage(Tip, WM_CLOSE, 0, 0);
  Pump(2000);
  Computer := Find('Arbeitsplatz');
  Check((Computer <> 0) and (Find('My Computer') = 0) and (Find('Computer') = 0),
    'the default name My Computer is shown in German as Arbeitsplatz');
  Check((Find('Abfall') <> 0) and (Find('Papierkorb') = 0) and (Find('Recycle Bin') = 0),
    'the Recycle Bin keeps the name of the user; the catalogue does not translate the form again');
  if Computer = 0 then Computer := Find('Computer');
  if Computer <> 0 then
  begin
    ShowWindow(Computer, SW_RESTORE);
    Pump(5000);
    Check(not IsIconic(Computer), 'My Computer opens');
    Check((Find('Fehler') = 0) and (Find('Error') = 0),
      'a program without an icon shows no error box in My Computer');
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
  Pump(60000);
end.
