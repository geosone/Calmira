{ Calmira System library 3.3, Li-Hsin Huang & Erwin Dokter.
  Released into the public domain, May 2002.
  GetWord extracted from vcl/strings.pas without the unrelated assembler/UI
  routines. Preserve its empty-token and repeated-delimiter behavior. }
unit word_tokens;
{$mode delphi}{$H-}{$B-}
interface
function GetWord(var s: OpenString; delim: Char): string;
implementation
function GetWord(var s: OpenString; delim: Char): string;
var
  i: Integer;
begin
  i := Pos(delim, s);
  if i = 0 then begin
    if Length(s) > 0 then
    begin
      Result := s;
      s := '';
    end
    else Result := '';
  end
  else
  begin
    Result := Copy(s, 1, i - 1);
    while (i <= Length(s)) and (s[i] = delim) do Inc(i);
    Delete(s, 1, i - 1);
  end;
end;
end.
