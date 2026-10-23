program GUIDiagnosticsTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils;
var Failed: Boolean; Boxes: Integer; Timer: UINT; I: Integer; Suffix: string;
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10;
  _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure Tick(Window: HWND; Message, Event: UINT; Time: DWORD); export;
var Box, Child: HWND; Name: array[0..31] of Char;
begin
  try
  { No exceptions may cross the native timer callback. Only inspect our task. }
  Box := GetActiveWindow;
  if (Box = 0) or (GetWindowTask(Box) <> GetCurrentTask) then Exit;
  GetClassName(Box, Name, SizeOf(Name));
  if StrComp(Name, '#32770') <> 0 then Exit;
  { Payload identity is tested by the shared-buffer harness on host and Win16;
    do not assume USER exposes the text through a STATIC child. }
  Child := GetWindow(Box, GW_CHILD);
  while Child <> 0 do
  begin
    GetClassName(Child, Name, SizeOf(Name));
    if StrIComp(Name, 'Button') = 0 then
    begin
      Inc(Boxes);
      { Win3.11 uses ID 2 for this box. Use its actual button, not IDOK or
        synthetic Enter, which can leave a character queued for the next box. }
      SendMessage(Box, WM_COMMAND, GetDlgCtrlID(Child), LongInt(Child)); Exit;
    end;
    Child := GetWindow(Child, GW_HWNDNEXT);
  end;
  Failed := True;
  except Failed := True; end;
end;
begin
  LogLine('STEP native GUI diagnostic capacity');
  try
    Timer := SetTimer(0, 0, 55, TFarProc(@Tick));
    if Timer = 0 then raise Exception.Create('timer');
    try
      for I := 1 to 1000 do Write(Output, 'a'); Flush(Output);
      Check(Boxes = 0, 'partial output remains buffered');
      Suffix := ''; for I := 1 to 100 do Suffix := Suffix + Char(33 + I mod 90);
      Write(Output, Suffix); Flush(Output);
      Check(Boxes = 1, 'full buffer emits one native message');
      Close(Output); Check(Boxes = 2, 'close emits retained suffix');
      SysInitStdIO; Boxes := 0; NoErrMsg := True;
      try
        for I := 1 to 1100 do Write(Output, 'x'); Flush(Output); Close(Output);
      finally NoErrMsg := False; SysInitStdIO; end;
      Check(Boxes = 0, 'NoErrMsg suppresses full and partial output');
    finally KillTimer(0, Timer); Timer := 0; end;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  if Timer <> 0 then KillTimer(0, Timer);
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
