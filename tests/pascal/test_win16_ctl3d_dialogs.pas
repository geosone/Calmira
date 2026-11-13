program TestWin16Ctl3DDialogs;
{ Starts the real CALMIRA.EXE, then opens a standard dialog of this program,
  another task. By default it keeps the white face of Windows 3.1; with
  [Preferences] Ctl3DDialogs=1 (built with -dCTL3DDIALOGS) Calmira's hook in
  WNDHOOKS.DLL gives it the grey 3D face of CTL3DV2.DLL. }
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
{$IFDEF CTL3DDIALOGS}
  StrPCopy(F, 'C:\CALMIRA.INI');
  WritePrivateProfileString(StrPCopy(S, 'Preferences'), StrPCopy(K, 'Ctl3DDialogs'),
    StrPCopy(V, '1'), F);
{$ENDIF}
end;

function DialogProc(Wnd: HWND; Msg: Word; wParam: Word; lParam: LongInt): Bool; far; export;
begin
  Result := Msg = WM_INITDIALOG;
end;

{ A dialog template in memory: a caption, a check box and a text. }
var
  Template: array[0..255] of Byte;
  Size: Integer;

procedure PutByte(Value: Byte);
begin
  Template[Size] := Value; Inc(Size);
end;

procedure PutWord(Value: Word);
begin
  PutByte(Lo(Value)); PutByte(Hi(Value));
end;

procedure PutText(const Text: string);
var I: Integer;
begin
  for I := 1 to Length(Text) do PutByte(Ord(Text[I]));
  PutByte(0);
end;

procedure PutItem(X, Y, CX, CY, Id: Integer; Style: LongInt; ClassId: Byte; const Text: string);
begin
  PutWord(X); PutWord(Y); PutWord(CX); PutWord(CY); PutWord(Id);
  PutWord(LoWord(Style)); PutWord(HiWord(Style));
  PutByte(ClassId); PutText(Text); PutByte(0);
end;

procedure BuildTemplate;
var Style: LongInt;
begin
  Size := 0;
  Style := WS_POPUP or WS_VISIBLE or WS_CAPTION or WS_SYSMENU or DS_MODALFRAME;
  PutWord(LoWord(Style)); PutWord(HiWord(Style));
  PutByte(2); PutWord(40); PutWord(30); PutWord(160); PutWord(90);
  PutByte(0); PutByte(0); PutText('Standard Dialog');
  PutItem(8, 8, 100, 12, 101, WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX, $80, 'Check box');
  PutItem(8, 26, 100, 10, 102, WS_CHILD or WS_VISIBLE or SS_LEFT, $82, 'Text');
end;

var
  Instance: THandle;
  Welcome, Tip, Dialog: HWND;
  Area: TRect; DC: HDC; Face, Window, Pixel: TColorRef;
begin
{$IFDEF CTL3DDIALOGS}
  LogLine('Dialogs of another program with Ctl3DDialogs=1');
{$ELSE}
  LogLine('Dialogs of another program by default');
{$ENDIF}
  Configure;
  Instance := WinExec('C:\CALMIRA.EXE', SW_SHOWNORMAL);
  Check(Instance >= 32, 'CALMIRA.EXE starts');
  Welcome := WaitForTitle('Welcome', 40);
  if Welcome <> 0 then PostMessage(Welcome, WM_CLOSE, 0, 0);
  Tip := WaitForTitle('Tip of the Day', 15);
  if Tip <> 0 then PostMessage(Tip, WM_CLOSE, 0, 0);
  Pump(3000);
  BuildTemplate;
  Dialog := CreateDialogIndirect(HInstance, @Template, 0,
    TFarProc(MakeProcInstance(TFarProc(@DialogProc), HInstance)));
  Check(Dialog <> 0, 'a standard dialog opens');
  if Dialog <> 0 then
  begin
    Pump(2000);
    { A spot of the dialog's face, below its controls. }
    GetWindowRect(Dialog, Area);
    DC := GetDC(0);
    Face := GetNearestColor(DC, GetSysColor(COLOR_BTNFACE));
    Window := GetNearestColor(DC, GetSysColor(COLOR_WINDOW));
    Pixel := GetPixel(DC, Area.Right - 20, Area.Bottom - 20);
    ReleaseDC(0, DC);
    LogLine('dialog face ' + IntToHex(Pixel, 8));
{$IFDEF CTL3DDIALOGS}
    Check(Pixel = Face, 'CTL3D gives the dialog of another program its grey face');
{$ELSE}
    Check(Pixel = Window, 'the dialog of another program keeps its Windows 3.1 face');
{$ENDIF}
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
  Pump(60000);
end.
