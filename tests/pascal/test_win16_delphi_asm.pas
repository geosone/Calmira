program TestWin16DelphiAsm;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, MiscUtil, Strings, delphi_asm_probe;
var Failed: Boolean; I, Sum: Integer;
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
{ A forward declaration, then an assembler body: still the stack. }
function Twice(A: Integer): Integer; forward;
function Twice(A: Integer): Integer; assembler;
asm
  MOV AX,A
  ADD AX,AX
end;
begin
  LogLine('STEP Delphi 1 assembler routines');
  try
    Check((ProbeSub(10, 3) = 7) and (ProbeSub(3, 10) = -7), 'an interface-declared assembler routine reads its stack parameters');
    Check(Twice(21) = 42, 'a forward-declared assembler routine reads its stack parameters');
    Check((Min(3, -4) = -4) and (Max(3, -4) = 3) and (Range(15, 0, 10) = 10) and (Range(-5, 0, 10) = 0) and
      (Sign(-9) = -1) and (Sign(0) = 0), 'MiscUtil Min, Max, Range and Sign');
    Check((LowCase('Q') = 'q') and InString('b', 'abc') and not InString('z', 'abc') and
      (CharCount('a', 'banana') = 3) and IsBlank('   ') and not IsBlank(' x '), 'Strings character routines');
    Check(FillString('*', 4) = '****', 'Strings.FillString returns through @Result');
    Sum := 0;
    for I := 1 to 2000 do Inc(Sum, Min(I, 1) + ProbeSub(I, I));
    Check(Sum = 2000, 'repeated calls leave the stack balanced');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
