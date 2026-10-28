program TestWin16FarImports;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, far_import_probe;
var Failed: Boolean; Before, Ticks: LongInt;
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
begin
  LogLine('STEP far imports');
  try
    Before := WinProcs.GetTickCount;
    Ticks := ProbeTickCount;
    Check((Ticks >= Before) and (Ticks - Before < 1000), 'a wrapped USER import is reached with a far jump');
    Check(ProbeWindowsVersion = LongInt(GetVersion), 'a wrapped KERNEL import returns its result');
    Check(CompareText(ExtractFileName(ProbeParamStr(0)), 'GDITEST.EXE') = 0,
      'ParamStr links in Delphi mode');
    Check(ProbeParamStr(99) = '', 'ParamStr beyond ParamCount is empty');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
