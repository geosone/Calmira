program ShellApiTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, ShellAPI;
const WS_EX_ACCEPTFILES = $00000010;
var Failed: Boolean;
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
procedure Registry;
var Key, Sub: HKEY; Buffer: array[0..79] of Char; Size: LongInt; Index: LongInt;
  Found: Boolean;
begin
  Check(RegCreateKey(HKEY_CLASSES_ROOT, 'CalmiraProbe\shell', Key) = ERROR_SUCCESS, 'create key');
  Check(RegSetValue(Key, 'open', REG_SZ, 'probe.exe %1', 12) = ERROR_SUCCESS, 'set value');
  Size := SizeOf(Buffer);
  Check((RegQueryValue(Key, 'open', Buffer, Size) = ERROR_SUCCESS) and
    (StrComp(Buffer, 'probe.exe %1') = 0) and (Size = 13), 'query value and size');
  Found := False; Index := 0;
  while RegEnumKey(Key, Index, Buffer, SizeOf(Buffer)) = ERROR_SUCCESS do
  begin
    if StrIComp(Buffer, 'open') = 0 then Found := True;
    Inc(Index);
  end;
  Check(Found and (Index = 1), 'enumerate subkey');
  Check(RegCloseKey(Key) = ERROR_SUCCESS, 'close key');
  Check(RegOpenKey(HKEY_CLASSES_ROOT, 'CalmiraProbe', Sub) = ERROR_SUCCESS, 'reopen key');
  Check(RegDeleteKey(Sub, 'shell') = ERROR_SUCCESS, 'delete subtree');
  RegCloseKey(Sub);
  Check(RegDeleteKey(HKEY_CLASSES_ROOT, 'CalmiraProbe') = ERROR_SUCCESS, 'delete key');
  Check(RegOpenKey(HKEY_CLASSES_ROOT, 'CalmiraProbe', Sub) <> ERROR_SUCCESS, 'deleted key is gone');
end;
procedure ShellFunctions;
var Windows, Path: array[0..144] of Char; Icon: HICON; Count: Word; Code: THandle;
  Wnd: HWND;
begin
  GetWindowsDirectory(Windows, SizeOf(Windows));
  StrCopy(Path, Windows); StrCat(Path, '\PROGMAN.EXE');
  Count := Word(ExtractIcon(HInstance, Path, $FFFF));
  Check(Count > 1, 'icon count of PROGMAN.EXE');
  Icon := ExtractIcon(HInstance, Path, 0);
  Check(Icon > 1, 'extract first icon');
  if Icon > 1 then DestroyIcon(Icon);
  Check(ExtractIcon(HInstance, Path, Count + 5) = 0, 'index beyond count');
  StrCopy(Path, Windows); StrCat(Path, '\WIN.INI');
  Code := FindExecutable(Path, nil, Windows);
  Check((Code > 32) and (StrPos(StrUpper(Windows), 'NOTEPAD') <> nil), 'INI association');
  Check(ShellExecute(0, nil, 'C:\MISSING\NOPROBE.EXE', nil, nil, SW_SHOWNORMAL) <= 32,
    'missing program reports an error code');
  Wnd := CreateWindow('STATIC', 'probe', WS_POPUP, 0, 0, 10, 10, 0, 0, HInstance, nil);
  DragAcceptFiles(Wnd, True);
  Check(GetWindowLong(Wnd, GWL_EXSTYLE) and WS_EX_ACCEPTFILES <> 0, 'accept files');
  DragAcceptFiles(Wnd, False);
  Check(GetWindowLong(Wnd, GWL_EXSTYLE) and WS_EX_ACCEPTFILES = 0, 'reject files');
  DestroyWindow(Wnd);
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP ShellAPI');
  try Registry; ShellFunctions;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'stack');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
