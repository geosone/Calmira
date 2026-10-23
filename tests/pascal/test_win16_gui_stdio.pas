program GUIIOTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils;
var Failed: Boolean;
procedure LogLine(const Text: string);
var F: HFILE; Line: string; Data: array[0..255] of Char;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Data, Line);
  _lwrite(F, @Data, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure Exercise;
var T: Text; S: string; C: Char; I: Integer; Okay: Boolean;
begin
  Check((@Output = @StdOut) and (@Output = @ErrOutput) and (@Output = @StdErr), 'GUI aliases');
  Check(TextRec(Output).Handle = System.UnusedHandle, 'GUI device has no DOS handle');
  Check((SizeOf(TextRec(T).Name) = 256) and (SizeOf(TextRec(T).Name[0]) = 1) and
    (SizeOf(TextRec(T).Buffer) = 256), 'ANSI path ABI; full buffers');
  AssignFile(StdOut, 'C:\CHANNEL.TXT'); Rewrite(StdOut);
  try
    WriteLn(Output, 'one'); WriteLn('two'); WriteLn(ErrOutput, 'three'); WriteLn(StdErr, 'four');
    Flush(Output);
  finally CloseFile(StdOut); SysInitStdIO; end;
  AssignFile(T, 'C:\CHANNEL.TXT'); Reset(T);
  try
    ReadLn(T, S); Okay := S = 'one'; ReadLn(T, S); Okay := Okay and (S = 'two');
    ReadLn(T, S); Okay := Okay and (S = 'three'); ReadLn(T, S); Okay := Okay and (S = 'four');
    Check(Okay and EOF(T), 'shared redirected channel');
  finally CloseFile(T); end;
  Check(TextRec(Output).Mode = fmOutput, 'GUI diagnostics restored');
  AssignFile(T, 'C:\TEXTIO.TXT'); Rewrite(T);
  try
    S := ''; for I := 1 to 255 do S := S + 'a';
    WriteLn(T, S); WriteLn(T);
    for I := 1 to 600 do Write(T, 'x');
    WriteLn(T); WriteLn(T, 'tail');
  finally CloseFile(T); end;
  Reset(T);
  try
    ReadLn(T, S); Okay := Length(S) = 255;
    for I := 1 to Length(S) do Okay := Okay and (S[I] = 'a');
    ReadLn(T, S); Okay := Okay and (S = '');
    for I := 1 to 600 do begin Read(T, C); Okay := Okay and (C = 'x'); end;
    ReadLn(T, S); Okay := Okay and (S = ''); ReadLn(T, S);
    Check(Okay and (S = 'tail') and EOF(T), 'explicit Text I/O across buffer boundaries');
  finally CloseFile(T); end;
end;
begin
  LogLine('STEP private GUI stdio ABI');
  try Exercise;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
