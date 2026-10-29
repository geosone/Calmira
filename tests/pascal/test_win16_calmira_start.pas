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

var
  Instance: THandle;
  Welcome, Computer, Bin, Tip: HWND;
  CalmiraTask: THandle;
begin
  LogLine('Calmira start');
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
    Check(StartEntry('Start\&Programs', 'Program Manager*') <> '',
      'Program Manager groups are synchronised into the Start menu');
    Check(Find('Error') = 0, 'no error box while starting');
    PostMessage(Welcome, WM_CLOSE, 0, 0);
    Tip := WaitFor('Tip of the Day', 15);
    Check((Tip <> 0) and (GetWindowTask(Tip) = CalmiraTask) and (Find('Welcome') = 0),
      'closing Welcome shows the Tip of the Day (' + Elapsed + ')');
    Check(Find('Error') = 0, 'no error box after the first-run dialogs');
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
