program SystemDllsTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, ToolHelp, Ver;
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
procedure Timer;
var A, B: TTimerInfo; Start: LongInt;
begin
  A.dwSize := SizeOf(A); B.dwSize := SizeOf(B);
  Check(TimerCount(@A), 'TimerCount');
  Start := WinProcs.GetTickCount;
  repeat until WinProcs.GetTickCount - Start >= 120;
  TimerCount(@B);
  Check((B.dwmsSinceStart - A.dwmsSinceStart >= 100) and (B.dwmsThisVM >= A.dwmsThisVM), 'timer advances');
end;
procedure Version;
var Path: array[0..144] of Char; Handle, Size: LongInt; Buffer, Value: Pointer;
  Len: Word; Fixed: PVS_FIXEDFILEINFO; Translation: PLongInt; Key: string;
begin
  GetSystemDirectory(Path, SizeOf(Path)); StrCat(Path, '\USER.EXE');
  Size := GetFileVersionInfoSize(Path, Handle);
  Check(Size > SizeOf(TVS_FIXEDFILEINFO), 'version info size');
  if Size <= 0 then Exit;
  GetMem(Buffer, Size);
  try
    Check(GetFileVersionInfo(Path, Handle, Size, Buffer), 'version info');
    Check(VerQueryValue(Buffer, '\', Pointer(Fixed), Len) and (Len = SizeOf(TVS_FIXEDFILEINFO)) and
      (Fixed^.dwSignature = LongInt(VS_FFI_SIGNATURE)) and (Fixed^.dwFileType = VFT_DLL) and
      (Fixed^.dwFileOS and $FFFF = VOS__WINDOWS16) and (HiWord(Fixed^.dwFileVersionMS) = 3),
      'fixed info of USER.EXE');
    Check(VerQueryValue(Buffer, '\VarFileInfo\Translation', Pointer(Translation), Len) and (Len >= 4),
      'translation table');
    Key := Format('\StringFileInfo\%.4x%.4x\CompanyName'#0, [LoWord(Translation^), HiWord(Translation^)]);
    Check(VerQueryValue(Buffer, @Key[1], Value, Len) and (StrPos(PChar(Value), 'Microsoft') <> nil),
      'company name');
    Check(not VerQueryValue(Buffer, '\StringFileInfo\NOPE\Nothing', Value, Len), 'missing block');
  finally FreeMem(Buffer, Size); end;
  StrCopy(Path, 'C:\MISSING.DLL');
  Check(GetFileVersionInfoSize(Path, Handle) = 0, 'missing file');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP system DLLs');
  try Timer; Version;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'stack');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
