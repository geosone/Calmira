program ClipbrdTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, Forms, Clipbrd;
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
procedure RunChecks;
var Buffer: array[0..15] of Char; Big: array[0..399] of Char; Data: THandle; I: Integer;
  Custom: Word;
begin
  Clipboard.AsText := 'C:\WINDOWS\*.INI';
  Check(Clipboard.HasFormat(CF_TEXT) and (Clipboard.AsText = 'C:\WINDOWS\*.INI'), 'text round trip');
  Check(GetClipboardOwner = Application.Handle, 'owned by application window');
  Check((Clipboard.GetTextBuf(Buffer, 6) = 5) and (StrComp(Buffer, 'C:\WI') = 0), 'truncating buffer');
  FillChar(Big, SizeOf(Big) - 1, 'x'); Big[SizeOf(Big) - 1] := #0;
  Clipboard.SetTextBuf(Big);
  Check(Length(Clipboard.AsText) = 255, 'AsText limited to short string');
  Custom := RegisterClipboardFormat('Calmira Probe');
  Data := GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE, 4);
  Clipboard.Open;
  try
    Clipboard.AsText := 'both';
    Clipboard.SetAsHandle(Custom, Data);
  finally Clipboard.Close; end;
  Check(Clipboard.HasFormat(Custom) and (Clipboard.AsText = 'both'), 'several formats in one Open');
  Check(Clipboard.FormatCount >= 2, 'format count');
  I := 0;
  while (I < Clipboard.FormatCount) and (Clipboard.Formats[I] <> Custom) do Inc(I);
  Check(I < Clipboard.FormatCount, 'enumerate formats');
  Clipboard.Clear;
  Check(not Clipboard.HasFormat(CF_TEXT) and (Clipboard.AsText = '') and
    (Clipboard.FormatCount = 0), 'clear');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP Clipbrd');
  try RunChecks;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'stack');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
