program TestExceptionText;
{$mode delphi}{$H+}
uses SysUtils, exception_text;
var Text, Original: AnsiString;
procedure Check(Okay: Boolean; const Description: string);
begin if not Okay then raise Exception.Create(Description); end;
begin
  Check(ExceptionDisplayText('ordinary failure', 'EProbe') = 'ordinary failure', 'message retained');
  Check(ExceptionDisplayText('', 'EProbe') = 'EProbe', 'empty message uses class');
  Check(ExceptionDisplayText('', '') = 'Exception', 'empty fallback');
  Check(ExceptionDisplayText('a'#0'b'#228, 'E') = 'a b'#228, 'NUL normalized and ANSI retained');
  Original := StringOfChar('x', ExceptionTextLimit);
  Check(ExceptionDisplayText(Original, 'E') = Original, 'full capacity not marked truncated');
  Text := ExceptionDisplayText(Original + 'y', 'E');
  Check((Length(Text) = ExceptionTextLimit) and (Copy(Text, 1, ExceptionTextLimit - 3) =
    StringOfChar('x', ExceptionTextLimit - 3)) and (Copy(Text, ExceptionTextLimit - 2, 3) = '...'),
    'over-capacity payload has exact bound and ellipsis');
  Check(Length(Original) = ExceptionTextLimit, 'source not modified');
  Text := ExceptionDisplayText('', Original + 'y');
  Check((Length(Text) = ExceptionTextLimit) and (Copy(Text, ExceptionTextLimit - 2, 3) = '...'),
    'class fallback is also bounded');
  Text := ExceptionDisplayText(#0 + StringOfChar('x', 2000), 'E');
  Check((Length(Text) = ExceptionTextLimit) and (Text[1] = ' ') and (Pos(#0, Text) = 0),
    'long embedded NUL payload normalized');
  WriteLn('exception-text tests: OK');
end.
