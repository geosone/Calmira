program TestWin16Dll;
{$mode delphi}{$H-}{$APPTYPE GUI}
uses WinTypes, WinProcs, SysUtils;
function ProbeTwice(X: Integer): Integer; far; external 'DLLPROBE';
function ProbeState: Integer; far; external 'DLLPROBE';
function ProbeHeap(const S: string): Integer; far; external 'DLLPROBE';
type TProbeTwice = function(X: Integer): Integer; far;
var Failed: Boolean;
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
function LogContains(Text: PChar): Boolean;
var F: HFILE; Buffer: array[0..4095] of Char; Count: Integer;
begin
  Result := False;
  F := _lopen('C:\GDITEST.LOG', OF_READ);
  if F = HFILE_ERROR then Exit;
  Count := _lread(F, @Buffer, SizeOf(Buffer) - 1); _lclose(F);
  if Count < 0 then Exit;
  Buffer[Count] := #0;
  Result := StrPos(Buffer, Text) <> nil;
end;
procedure CheckDynamic;
{ DLLDYN.DLL is the same library under another module name, loaded only here,
  so FreeLibrary unloads it and Windows calls its WEP. }
var Lib: THandle; Twice: TProbeTwice;
begin
  Lib := LoadLibrary('DLLDYN.DLL');
  Check(Lib >= 32, 'LoadLibrary loads a library');
  if Lib < 32 then Exit;
  @Twice := GetProcAddress(Lib, 'ProbeTwice');
  Check(Assigned(Twice) and (Twice(-4) = -8), 'GetProcAddress by name');
  Check(not LogContains('NOTE library finalization ran'), 'the library is not finalized while loaded');
  FreeLibrary(Lib);
  Check(LogContains('NOTE library finalization ran'), 'FreeLibrary finalizes the library through WEP');
end;
var State: Integer;
begin
  LogLine('STEP Free Pascal library');
  try
    State := ProbeState;
    Check(State and 8 <> 0, 'the library''s units were initialized');
    Check(State and 1 <> 0, 'the library''s main block ran');
    Check(State and 2 <> 0, 'IsLibrary is set in the library');
    Check(State and 4 <> 0, 'HInstance is the library''s module');
    Check(not IsLibrary, 'IsLibrary is clear in the program');
    Check(ProbeTwice(21) = 42, 'a static import returns its result');
    Check(ProbeHeap('abc') = 6, 'heap, strings and exceptions inside the library');
    CheckDynamic;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
