program TestColorNames;
{$mode delphi}{$H+}
uses SysUtils, color_names;
type TCollector = class
  Count: Integer;
  procedure Visit(const Name: string);
end;
var Collector: TCollector; Value: LongInt; Name: string; Rejected: Boolean;
procedure Check(Okay: Boolean; const Description: string);
begin if not Okay then begin WriteLn('FAIL ', Description); Halt(1); end; end;
procedure TCollector.Visit(const Name: string);
var Color: LongInt; Back: string;
begin
  Check(IdentToColor(Name, Color), 'enumerated name parses');
  Check(ColorToIdent(Color, Back) and (Back = Name), 'enumerated name is canonical');
  Check(StringToColor(ColorToString(Color)) = Color, 'named round trip');
  Inc(Count);
end;
begin
  Collector := TCollector.Create;
  try GetColorValues(Collector.Visit); Check(Collector.Count = 39, 'complete Win3.1 color set');
  finally Collector.Free; end;
  Check(StringToColor('cLbTnHiGhLiGhT') = clBtnHighlight, 'case insensitive names');
  Check(StringToColor('$80000005') = clWindow, 'unsigned system-color hex');
  Check(StringToColor('$FFFFFFFF') = -1, 'all-bits hex');
  Check(StringToColor('-123') = -123, 'signed decimal');
  Check(StringToColor('16711680') = clBlue, 'decimal RGB');
  Check(ColorToString($123456) = '$00123456', 'unknown color numeric fallback');
  Check(StringToColor(ColorToString(-123)) = -123, 'unknown negative round trip');
  Value := 123; Name := 'untouched';
  Check(not IdentToColor('clTypo', Value) and (Value = 123), 'unknown name preserves output');
  Check(not ColorToIdent(123, Name) and (Name = 'untouched'), 'unknown value preserves output');
  Rejected := False;
  try StringToColor('clTypo'); except on EConvertError do Rejected := True; end;
  Check(Rejected, 'invalid color raises conversion error');
  Rejected := False;
  try StringToColor('$100000000'); except on EConvertError do Rejected := True; end;
  Check(Rejected, 'numeric overflow rejected');
  Rejected := False;
  try StringToColor('-2147483649'); except on EConvertError do Rejected := True; end;
  Check(Rejected, 'negative overflow rejected');
  Rejected := False;
  try StringToColor('$FFFFFFFFFFFFFFFF'); except on EConvertError do Rejected := True; end;
  Check(Rejected, 'unsigned 64-bit hex cannot wrap into a signed color');
  Check(StringToColor('$80000000') = clScrollBar, 'lowest signed color bit pattern');
  WriteLn('PASS color names and conversions');
end.
