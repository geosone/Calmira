program TestHelpJump;
{$mode delphi}{$H+}
uses SysUtils, help_jump;
var I: Integer; Bad: array[0..5] of AnsiString; Rejected: Boolean; Macro: AnsiString;
procedure Check(Okay: Boolean; const Text: string);
begin if not Okay then raise Exception.Create(Text); end;
begin
  Check(HelpJumpMacro('C:\HELPDOCS\CALMIRA.HLP', 'Contents') =
    'JumpID("C:\\HELPDOCS\\CALMIRA.HLP","Contents")', 'DOS separators escaped');
  Check(HelpJumpMacro('calmira.hlp', 'topic_1.a') =
    'JumpID("calmira.hlp","topic_1.a")', 'context retained');
  Bad[0] := ''; Bad[1] := 'x");ExecFile("bad")'; Bad[2] := 'a'#0'b';
  Bad[3] := 'a\b'; Bad[4] := 'a'#13'b'; Bad[5] := StringOfChar('x', 256);
  for I := 0 to High(Bad) do
  begin
    Rejected := False;
    try HelpJumpMacro('calmira.hlp', Bad[I]); except on EConvertError do Rejected := True; end;
    Check(Rejected, 'invalid context rejected');
  end;
  Rejected := False;
  try HelpJumpMacro('a"b.hlp', 'Contents'); except on EConvertError do Rejected := True; end;
  Check(Rejected, 'quoted path rejected');
  Rejected := False;
  try HelpJumpMacro('a'#0'b.hlp', 'Contents'); except on EConvertError do Rejected := True; end;
  Check(Rejected, 'NUL path rejected');
  Macro := HelpJumpMacro(StringOfChar('\', 255), StringOfChar('x', 255));
  Check(Length(Macro) = 778, 'maximum request not silently truncated');
  WriteLn('help-jump tests: OK');
end.
