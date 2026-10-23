{ SPDX-License-Identifier: GPL-2.0-or-later
  Win16 ANSI caption accelerators, respecting literal && and trailing &. }
unit native_mnemonic;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This mnemonic helper requires Win16}{$ENDIF}
interface
function CaptionMatches(const Caption: string; Key: Char): Boolean;
implementation
uses WinProcs;
function CaptionMatches(const Caption: string; Key: Char): Boolean;
var I: Integer; Pair: array[0..1] of Char;
begin
  Result := False;
  if Key = #0 then Exit;
  I := 1;
  while I < Length(Caption) do
  begin
    if Caption[I] = '&' then
    begin
      Inc(I);
      if Caption[I] <> '&' then
      begin
        Pair[0] := Caption[I]; Pair[1] := Key;
        AnsiUpperBuff(Pair, 2);
        if Pair[0] = Pair[1] then begin Result := True; Exit; end;
      end;
    end;
    Inc(I);
  end;
end;
end.
