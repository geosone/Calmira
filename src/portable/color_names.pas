{ SPDX-License-Identifier: GPL-2.0-or-later }
unit color_names;
{$mode delphi}{$H+}
interface
uses Classes;
const
  clBlack = LongInt($000000); clMaroon = LongInt($000080);
  clGreen = LongInt($008000); clOlive = LongInt($008080);
  clNavy = LongInt($800000); clPurple = LongInt($800080);
  clTeal = LongInt($808000); clGray = LongInt($808080);
  clSilver = LongInt($C0C0C0); clRed = LongInt($0000FF);
  clLime = LongInt($00FF00); clYellow = LongInt($00FFFF);
  clBlue = LongInt($FF0000); clFuchsia = LongInt($FF00FF);
  clAqua = LongInt($FFFF00); clWhite = LongInt($FFFFFF);
  clScrollBar = LongInt($80000000); clBackground = LongInt($80000001);
  clActiveCaption = LongInt($80000002); clInactiveCaption = LongInt($80000003);
  clMenu = LongInt($80000004); clWindow = LongInt($80000005);
  clWindowFrame = LongInt($80000006); clMenuText = LongInt($80000007);
  clWindowText = LongInt($80000008); clCaptionText = LongInt($80000009);
  clActiveBorder = LongInt($8000000A); clInactiveBorder = LongInt($8000000B);
  clAppWorkSpace = LongInt($8000000C); clHighlight = LongInt($8000000D);
  clHighlightText = LongInt($8000000E); clBtnFace = LongInt($8000000F);
  clBtnShadow = LongInt($80000010); clGrayText = LongInt($80000011);
  clBtnText = LongInt($80000012); clInactiveCaptionText = LongInt($80000013);
  clBtnHighlight = LongInt($80000014);
  clNone = LongInt($1FFFFFFF); clDefault = LongInt($20000000);
function IdentToColor(const Ident: string; var Color: LongInt): Boolean;
function ColorToIdent(Color: LongInt; var Ident: string): Boolean;
function StringToColor(const Text: string): LongInt;
function ColorToString(Color: LongInt): string;
procedure GetColorValues(Proc: TGetStrProc);
implementation
uses SysUtils;
type TColorName = record Value: LongInt; Name: PChar; end;
const Names: array[0..38] of TColorName = (
  (Value: clBlack; Name: 'clBlack'), (Value: clMaroon; Name: 'clMaroon'),
  (Value: clGreen; Name: 'clGreen'), (Value: clOlive; Name: 'clOlive'),
  (Value: clNavy; Name: 'clNavy'), (Value: clPurple; Name: 'clPurple'),
  (Value: clTeal; Name: 'clTeal'), (Value: clGray; Name: 'clGray'),
  (Value: clSilver; Name: 'clSilver'), (Value: clRed; Name: 'clRed'),
  (Value: clLime; Name: 'clLime'), (Value: clYellow; Name: 'clYellow'),
  (Value: clBlue; Name: 'clBlue'), (Value: clFuchsia; Name: 'clFuchsia'),
  (Value: clAqua; Name: 'clAqua'), (Value: clWhite; Name: 'clWhite'),
  (Value: clScrollBar; Name: 'clScrollBar'), (Value: clBackground; Name: 'clBackground'),
  (Value: clActiveCaption; Name: 'clActiveCaption'), (Value: clInactiveCaption; Name: 'clInactiveCaption'),
  (Value: clMenu; Name: 'clMenu'), (Value: clWindow; Name: 'clWindow'),
  (Value: clWindowFrame; Name: 'clWindowFrame'), (Value: clMenuText; Name: 'clMenuText'),
  (Value: clWindowText; Name: 'clWindowText'), (Value: clCaptionText; Name: 'clCaptionText'),
  (Value: clActiveBorder; Name: 'clActiveBorder'), (Value: clInactiveBorder; Name: 'clInactiveBorder'),
  (Value: clAppWorkSpace; Name: 'clAppWorkSpace'), (Value: clHighlight; Name: 'clHighlight'),
  (Value: clHighlightText; Name: 'clHighlightText'), (Value: clBtnFace; Name: 'clBtnFace'),
  (Value: clBtnShadow; Name: 'clBtnShadow'), (Value: clGrayText; Name: 'clGrayText'),
  (Value: clBtnText; Name: 'clBtnText'), (Value: clInactiveCaptionText; Name: 'clInactiveCaptionText'),
  (Value: clBtnHighlight; Name: 'clBtnHighlight'), (Value: clNone; Name: 'clNone'),
  (Value: clDefault; Name: 'clDefault'));
function IdentToColor(const Ident: string; var Color: LongInt): Boolean;
var I: Integer;
begin
  for I := Low(Names) to High(Names) do
    if CompareText(Ident, string(Names[I].Name)) = 0 then
    begin Color := Names[I].Value; Result := True; Exit; end;
  Result := False;
end;
function ColorToIdent(Color: LongInt; var Ident: string): Boolean;
var I: Integer;
begin
  for I := Low(Names) to High(Names) do
    if Names[I].Value = Color then
    begin Ident := string(Names[I].Name); Result := True; Exit; end;
  Result := False;
end;
function StringToColor(const Text: string): LongInt;
var Parsed: QWord; Signed: Int64; Numeric: string;
begin
  Result := 0;
  if IdentToColor(Text, Result) then Exit;
  Numeric := Trim(Text);
  if (Numeric <> '') and (Numeric[1] = '-') then
  begin
    if not TryStrToInt64(Numeric, Signed) then raise EConvertError.Create('Invalid color: ' + Text);
    if (Signed < -2147483648) or (Signed > 0) then
      raise EConvertError.Create('Color exceeds 32 bits: ' + Text);
    Result := LongInt(Signed); Exit;
  end;
  if not TryStrToQWord(Numeric, Parsed) then raise EConvertError.Create('Invalid color: ' + Text);
  if Parsed > 4294967295 then
    raise EConvertError.Create('Color exceeds 32 bits: ' + Text);
  Result := LongInt(Parsed);
end;
function ColorToString(Color: LongInt): string;
begin
  Result := '';
  if not ColorToIdent(Color, Result) then Result := '$' + IntToHex(LongWord(Color), 8);
end;
procedure GetColorValues(Proc: TGetStrProc);
var I: Integer;
begin for I := Low(Names) to High(Names) do Proc(string(Names[I].Name)); end;
end.
