program TestWordTokens;
{$mode delphi}{$H-}
uses word_tokens;
var S, Token: string; Short: string[8]; I: Integer;
procedure Check(Condition: Boolean);
begin if not Condition then Halt(1); end;
begin
  S := '*.txt;*.doc'; Check(GetWord(S, ';') = '*.txt');
  Check(S = '*.doc'); Check(GetWord(S, ';') = '*.doc'); Check(S = '');
  S := ';;*.pas;;;*.inc;;'; Check(GetWord(S, ';') = '');
  Check(GetWord(S, ';') = '*.pas'); Check(GetWord(S, ';') = '*.inc'); Check(S = '');
  S := ''; Check(GetWord(S, ';') = ''); S := ';;;'; Check(GetWord(S, ';') = ''); Check(S = '');
  Short := 'a;;b'; Check(GetWord(Short, ';') = 'a'); Check(Short = 'b');
  S := ' x ; y '; Check(GetWord(S, ';') = ' x '); Check(GetWord(S, ';') = ' y ');
  S := ''; for I := 1 to 255 do S := S + 'x';
  Token := GetWord(S, ';'); Check(Length(Token) = 255); Check(S = '');
  S := #228';'#233; Check(GetWord(S, ';') = #228); Check(GetWord(S, ';') = #233);
  WriteLn('word token tests: OK');
end.
