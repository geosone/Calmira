program TestWin16WndHooks;
{ Calmira's WNDHOOKS.DLL, built from src/wndhooks.dpr, loaded by name as
  src/hooks.pas does, with each hook triggered through Windows. }
{$mode delphi}{$H-}{$APPTYPE GUI}
uses WinTypes, WinProcs, Win31, SysUtils, CalMsgs;
type
  TProc = procedure; far;
  THwndProc = procedure(Wnd: HWND); far;
  TBoolProc = procedure(Value: Boolean); far;
  TYLimit = procedure(yt: Integer; y: Integer); far;
  THotKey = function(wParam: Word; lParam: Longint): Boolean; far;
  TFileStart = function(CallBack: HWND): Boolean; far;
var
  Failed: Boolean;
  Lib: THandle;
  CallBack: HWND;
  Got: array[WM_SHELLWNDCREATE..WM_DESKPAINT] of Word;
  GotFileChange: Integer;
  LastWParam: array[WM_SHELLWNDCREATE..WM_DESKPAINT] of Word;

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

function CallBackProc(Wnd: HWND; Msg: Word; wParam: Word; lParam: Longint): Longint; export;
begin
  if (Msg >= WM_SHELLWNDCREATE) and (Msg <= WM_DESKPAINT) then
  begin
    Inc(Got[Msg]);
    LastWParam[Msg] := wParam;
    Result := 0;
  end
  else if Msg = WM_FILESYSCHANGE then
  begin
    Inc(GotFileChange);
    Result := 0;
  end
  else
    Result := DefWindowProc(Wnd, Msg, wParam, lParam);
end;

procedure Pump;
var Msg: TMsg; Start: Longint;
begin
  Start := GetTickCount;
  repeat
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
    begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
  until GetTickCount - Start > 300;
end;

function Bind(const Name: string): Pointer;
var Z: array[0..63] of Char;
begin
  Result := GetProcAddress(Lib, StrPCopy(Z, Name));
  if Result = nil then LogLine('NOTE missing export ' + Name);
end;

function MakeWindow(Style: Longint): HWND;
begin
  Result := CreateWindow('HookProbe', 'Hook probe', Style, 40, 40, 200, 120,
    0, 0, HInstance, nil);
end;

procedure CheckExports;
const
  Names: array[1..21] of string[20] = ('STARTTASKMONITOR', 'STOPTASKMONITOR',
    'SETWNDHOOK', 'UNHOOKWNDHOOK', 'SETYLIMIT', 'STARTMOUSEMONITOR',
    'STOPMOUSEMONITOR', 'ENABLEMOUSEMONITOR', 'DISABLEMOUSEMONITOR',
    'SETCALLBACKWND', 'SETMAXENABLED', 'SETRCLOSEENABLED', 'SETDESKTOPHOOK',
    'RELEASEDESKTOPHOOK', 'STARTKEYBOARDHOOK', 'STOPKEYBOARDHOOK',
    'SETRBUTTONUPCLOSE', 'ISHOTKEY', 'SETWIN95KEYENABLED', 'STARTFILEMONITOR',
    'STOPFILEMONITOR');
var I, Found: Integer;
begin
  Found := 0;
  for I := Low(Names) to High(Names) do
    if Bind(Names[I]) <> nil then Inc(Found);
  Check(Found = 21, 'all 21 exports are found by the names src/hooks.pas uses');
end;

procedure CheckHotKey;
var IsHotKey: THotKey; Keys: TKeyboardState;
begin
  @IsHotKey := Bind('ISHOTKEY');
  GetKeyboardState(Keys);
  Keys[VK_CONTROL] := #0; Keys[VK_SHIFT] := #0;
  SetKeyboardState(Keys);
  Check(not IsHotKey(Ord('A'), 1), 'IsHotKey: a plain key is no hot key');
  Keys[VK_CONTROL] := #$80; Keys[VK_SHIFT] := #$80;
  SetKeyboardState(Keys);
  Check(IsHotKey(Ord('A'), 1), 'IsHotKey: Ctrl+Shift+A is a hot key');
  Check(not IsHotKey(VK_SHIFT, 1), 'IsHotKey: a modifier alone is no hot key');
  Keys[VK_CONTROL] := #0; Keys[VK_SHIFT] := #0;
  SetKeyboardState(Keys);
end;

procedure CheckTaskMonitor;
var W: HWND;
begin
  THwndProc(Bind('SETCALLBACKWND'))(CallBack);
  TProc(Bind('STARTTASKMONITOR'))();
  W := MakeWindow(WS_OVERLAPPEDWINDOW or WS_VISIBLE);
  Pump;
  Check((Got[WM_SHELLWNDCREATE] > 0) and (LastWParam[WM_SHELLWNDCREATE] = W),
    'the shell hook reports a new top-level window');
  DestroyWindow(W);
  Pump;
  Check((Got[WM_SHELLWNDDESTROY] > 0) and (LastWParam[WM_SHELLWNDDESTROY] = W),
    'the shell hook reports a destroyed top-level window');
  TProc(Bind('STOPTASKMONITOR'))();
end;

procedure CheckWndHook;
var A, B: HWND; R: TRect; Frame: Integer;
begin
  TProc(Bind('SETWNDHOOK'))();
  A := MakeWindow(WS_OVERLAPPEDWINDOW or WS_VISIBLE);
  B := MakeWindow(WS_OVERLAPPEDWINDOW or WS_VISIBLE);
  Pump;
  Got[WM_WINACTIVE] := 0;
  SetActiveWindow(A);
  Pump;
  Check((Got[WM_WINACTIVE] > 0) and (LastWParam[WM_WINACTIVE] = A),
    'the window procedure hook reports an activation');
  { Maximized windows stop at the taskbar's YLimit. }
  TYLimit(Bind('SETYLIMIT'))(0, 300);
  TBoolProc(Bind('SETMAXENABLED'))(True);
  ShowWindow(B, SW_SHOWMAXIMIZED);
  Pump;
  GetWindowRect(B, R);
  Frame := GetSystemMetrics(SM_CYFRAME);
  Check(R.Bottom = 300 + Frame, 'a maximized window ends at YLimit: bottom '
    + IntToStr(R.Bottom));
  TBoolProc(Bind('SETMAXENABLED'))(False);
  TProc(Bind('UNHOOKWNDHOOK'))();
  DestroyWindow(B);
  DestroyWindow(A);
  Pump;
end;

procedure CheckDesktopHook;
var Desktop: HWND; Original: Longint;
begin
  Desktop := GetDesktopWindow;
  Original := GetWindowLong(Desktop, GWL_WNDPROC);
  THwndProc(Bind('SETDESKTOPHOOK'))(CallBack);
  Check(GetWindowLong(Desktop, GWL_WNDPROC) <> Original, 'the desktop hook subclasses the desktop');
  SendMessage(Desktop, WM_LBUTTONDOWN, 0, MakeLong(5, 5));
  SendMessage(Desktop, WM_LBUTTONUP, 0, MakeLong(5, 5));
  Pump;
  Check((Got[WM_DESKMOUSEDOWN] > 0) and (Got[WM_DESKMOUSEUP] > 0),
    'the desktop hook reports mouse buttons on the desktop');
  TProc(Bind('RELEASEDESKTOPHOOK'))();
  Check(GetWindowLong(Desktop, GWL_WNDPROC) = Original, 'ReleaseDesktopHook restores the desktop');
end;

procedure CheckFileMonitor;
var F: HFILE; Started: Boolean; Buff: TOFStruct;
begin
  Started := TFileStart(Bind('STARTFILEMONITOR'))(CallBack);
  Check(Started, 'StartFileMonitor registers with KERNEL');
  F := _lcreat('C:\HOOKFILE.TMP', 0);
  _lclose(F);
  OpenFile('C:\HOOKFILE.TMP', Buff, OF_DELETE);
  Pump;
  Check(GotFileChange >= 2, 'the file monitor reports creating and deleting a file: '
    + IntToStr(GotFileChange));
  TProc(Bind('STOPFILEMONITOR'))();
end;

var
  WC: TWndClass;
  Path: array[0..79] of Char;
begin
  LogLine('STEP WNDHOOKS.DLL');
  try
    FillChar(WC, SizeOf(WC), 0);
    WC.lpfnWndProc := @CallBackProc;
    WC.hInstance := HInstance;
    WC.hCursor := LoadCursor(0, IDC_ARROW);
    WC.hbrBackground := COLOR_WINDOW + 1;
    WC.lpszClassName := 'HookProbe';
    RegisterClass(WC);
    CallBack := CreateWindow('HookProbe', 'Hook callback', WS_OVERLAPPED, 0, 0, 10, 10,
      0, 0, HInstance, nil);
    Lib := LoadLibrary(StrPCopy(Path, 'C:\WNDHOOKS.DLL'));
    Check(Lib >= 32, 'LoadLibrary loads WNDHOOKS.DLL');
    if Lib >= 32 then
    begin
      CheckExports;
      CheckHotKey;
      CheckTaskMonitor;
      CheckWndHook;
      CheckDesktopHook;
      CheckFileMonitor;
      FreeLibrary(Lib);
    end;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
