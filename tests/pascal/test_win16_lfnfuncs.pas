program TestWin16LfnFuncs;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, Lfnutils;
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
procedure CheckItems;
var S, A, B, C: string; Buffer: array[0..63] of Char; P, Rest: PChar;
begin
  S := 'one, two ,three';
  A := NextItem(S, 0, Ord(',')); B := NextItem(S, 0, Ord(',')); C := NextItem(S, 0, Ord(','));
  Check((A = 'one') and (B = 'two') and (C = 'three') and (S = ''), 'NextItem splits and trims');
  S := '"a,b",c';
  A := NextItem(S, Ord('"'), Ord(','));
  Check((A = 'a,b') and (S = 'c'), 'NextItem keeps quoted separators');
  StrPCopy(Buffer, 'x;y'); P := Buffer;
  Rest := NextItemStr(P, 0, Ord(';'));
  Check((StrPas(Rest) = 'x') and (StrPas(P) = 'y'), 'NextItemStr returns the item and advances');
end;
procedure CheckFiles;
var Rec: TLfnSearchRec; Found: Integer; H: Integer;
begin
  SetLFN(False);
  Check(not GetLFN, 'SetLFN and GetLFN');
  Check(IsProgExt('exe') and IsProgExt('COM') and not IsProgExt('txt'), 'IsProgExt');
  Found := LFindFirst('C:\GDITEST.EXE', faAnyFile, Rec);
  Check((Found = 0) and (CompareText(Rec.Name, 'GDITEST.EXE') = 0) and (Rec.Size > 0),
    'LFindFirst without long names finds a file');
  Check(LFindNext(Rec) <> 0, 'LFindNext ends the search');
  LFindClose(Rec);
  H := LFileOpen('C:\GDITEST.EXE', fmOpenRead);
  Check(H > 0, 'LFileOpen without long names');
  if H > 0 then FileClose(H);
end;
begin
  LogLine('STEP LFNFUNCS.DLL');
  try
    CheckItems;
    CheckFiles;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
