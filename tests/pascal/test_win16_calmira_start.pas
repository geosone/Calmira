program TestWin16CalmiraStart;
{ Starts the real CALMIRA.EXE (with its INI files, TIPS.TXT and DLLs in C:\)
  as a user would, and follows its first run: the desktop icons and the
  Welcome box, then the Tip of the Day once Welcome is closed. }
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

var
  Instance: THandle;
  Welcome, Computer, Bin, Tip, Bar, Manager: HWND;
  R: TRect;
  CalmiraTask: THandle;
begin
  LogLine('Calmira start');
  WriteStaleCache;
  Check(CacheSize = 58, 'a stale Start menu image cache is in place');
  Started := Ticks;
  Instance := WinExec('C:\CALMIRA.EXE', SW_SHOWNORMAL);
  Check(Instance >= 32, 'CALMIRA.EXE starts');
  Welcome := WaitFor('Welcome', 40);
  Check(Welcome <> 0, 'first run shows the Welcome box (' + Elapsed + ')');
  if Welcome <> 0 then
  begin
    CalmiraTask := GetWindowTask(Welcome);
    Computer := Find('My Computer');
    Bin := Find('Recycle Bin');
    Check((Computer <> 0) and IsIconic(Computer) and IsWindowVisible(Computer) and
      (GetWindowTask(Computer) = CalmiraTask), 'My Computer is a desktop icon of Calmira');
    Check((Bin <> 0) and IsIconic(Bin) and (GetWindowTask(Bin) = CalmiraTask),
      'Recycle Bin is a desktop icon of Calmira');
    Check((Find('Calmira Explorer') <> 0) and (Find('MS-DOS Prompt') <> 0) and
      (GetWindowTask(Find('MS-DOS Prompt')) = CalmiraTask), 'the desktop shortcuts carry their captions');
    Manager := FindWindow('Progman', nil); GetWindowRect(Manager, R);
    Check((Manager <> 0) and IsIconic(Manager) and (R.Top >= GetSystemMetrics(SM_CYSCREEN)),
      'Program Manager has a taskbar button, so its icon moves off the desktop');
    Check((StartEntry('Start\&Programs', 'Hauptgruppe*') <> '') and
      (StartEntry('Start\&Programs\Hauptgruppe', 'Systemsteuerung') <> ''),
      'Program Manager groups become menus of their own under Programs');
    Check((StartEntry('Start\&Programs', 'Program Manager*') = '') and
      (StartEntry('Start\&Programs', 'Accessories*') = '') and
      (StartEntry('Start\&Programs', 'Startup*') = ''),
      'the English stand-ins of START.INI give way to the real groups');
    Check(StartEntry('Start\&Programs', 'Hauptgruppe (99)*') = '',
      'group names keep their captions, without a (99) suffix');
    Check(FoldersFirst, 'the groups stand above the programs, in alphabetical order');
    Check(CalmiraEntry('Start Menu', 'StartupGroup') = 'Autostart',
      'the German startup group Autostart is the one Calmira runs');
    { The synchronisation rewrote START.INI, so the image cache built for
      the old menu must not be used: its icons would sit one item off. }
    Check((CacheSize > 58), 'the Start menu image cache is rebuilt after the groups are synchronised');
    Check(Find('Error') = 0, 'no error box while starting');
    Bar := Find('Taskbar');
    if Bar <> 0 then GetWindowRect(Bar, R);
    Check((Bar <> 0) and IsWindowVisible(Bar) and (GetWindowTask(Bar) = CalmiraTask) and
      (R.Left = 0) and (R.Right = GetSystemMetrics(SM_CXSCREEN)) and
      (R.Bottom >= GetSystemMetrics(SM_CYSCREEN)) and (R.Top < GetSystemMetrics(SM_CYSCREEN) - 20),
      'the taskbar is shown along the bottom of the screen');
    PostMessage(Welcome, WM_CLOSE, 0, 0);
    Tip := WaitFor('Tip of the Day', 15);
    Check((Tip <> 0) and (GetWindowTask(Tip) = CalmiraTask) and (Find('Welcome') = 0),
      'closing Welcome shows the Tip of the Day (' + Elapsed + ')');
    Check(Find('Error') = 0, 'no error box after the first-run dialogs');
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
