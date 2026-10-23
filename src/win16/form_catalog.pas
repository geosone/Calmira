{ SPDX-License-Identifier: GPL-2.0-or-later
  Optional low-DGROUP caption resolver for generated Win16 forms. Existing LNG
  [Forms] catalogues are shared; this does not replace the portable language API. }
unit form_catalog;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This caption adapter requires Win16}{$ENDIF}
interface
type
  TFormTextCatalog = class(TObject)
  private
    FDirectory: string;
    FCode: string[8];
    function ReadValue(const Code, Key: string; var Value: string): Boolean;
  public
    constructor Create(const Directory: string);
    function SelectLanguage(const Code: string): Boolean;
    function Translate(const RootClass, ComponentName, PropertyName,
      DefaultText: string): string;
    function TranslateResource(Ident: Word; const DefaultText: string): string;
  end;
implementation
uses SysUtils, WinTypes, WinProcs;
constructor TFormTextCatalog.Create(const Directory: string);
begin
  inherited Create; FCode := 'en';
  if (Pos(#0, Directory) <> 0) or (Length(Directory) > 240) or
    (Length(Directory) < 3) then
    raise Exception.Create('Invalid form catalogue');
  if not (Directory[1] in ['a'..'z', 'A'..'Z']) or (Directory[2] <> ':') or (Directory[3] <> '\') then
    raise Exception.Create('Invalid form catalogue');
  FDirectory := Directory;
  if (FDirectory <> '') and (FDirectory[Length(FDirectory)] <> '\') then FDirectory := FDirectory + '\';
end;
function Decode(const Value: string): string;
var I: Integer;
begin
  Result := ''; I := 1;
  while I <= Length(Value) do
  begin
    if Length(Result) = 255 then raise Exception.Create('Invalid form catalogue');
    if (Value[I] = '\') and (I < Length(Value)) then
    begin
      Inc(I);
      case Value[I] of
        'n': begin if Length(Result) > 253 then raise Exception.Create('Invalid form catalogue');
          Result := Result + #13#10; end;
        't': Result := Result + #9;
        '\': Result := Result + '\';
      else
        if Length(Result) > 253 then raise Exception.Create('Invalid form catalogue');
        Result := Result + '\' + Value[I];
      end;
    end
    else Result := Result + Value[I];
    Inc(I);
  end;
end;
function ProfileValue(const FileName: string; Section: PChar; const Key: string; var Value: string): Boolean;
var Path, Name, Buffer: array[0..255] of Char; Count: Word;
begin
  StrPCopy(Path, FileName); StrPCopy(Name, Key);
  Count := GetPrivateProfileString(Section, Name, '!missing1!', Buffer, SizeOf(Buffer), Path);
  if Count >= 255 then raise Exception.Create('Invalid form catalogue');
  SetString(Value, PChar(@Buffer), Count);
  if Value = '!missing1!' then
  begin
    { Printable defaults: Win3.11 strips control-character defaults. Two
      distinct markers distinguish missing keys from empty/marker-valued keys. }
    Count := GetPrivateProfileString(Section, Name, '!missing2!', Buffer, SizeOf(Buffer), Path);
    if Count >= 255 then raise Exception.Create('Invalid form catalogue');
    SetString(Value, PChar(@Buffer), Count); Result := Value <> '!missing2!';
  end
  else Result := True;
end;
function TFormTextCatalog.ReadValue(const Code, Key: string; var Value: string): Boolean;
begin
  Result := ProfileValue(FDirectory + Code + '.LNG', 'Forms', Key, Value);
  if Result then Value := Decode(Value);
end;
function TFormTextCatalog.SelectLanguage(const Code: string): Boolean;
var I: Integer; Actual, Candidate: string;
begin
  Result := False; FCode := 'en';
  if (Length(Code) < 2) or (Length(Code) > 8) then Exit;
  Candidate := Code;
  for I := 1 to Length(Candidate) do
  begin
    if not (Candidate[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-']) then Exit;
    if Candidate[I] in ['A'..'Z'] then Candidate[I] := Chr(Ord(Candidate[I]) + 32);
  end;
  if ProfileValue(FDirectory + Candidate + '.LNG', 'Language', 'Code', Actual) and
    (Actual = Candidate) then
  begin FCode := Candidate; Result := True; end;
end;
function TFormTextCatalog.Translate(const RootClass, ComponentName, PropertyName,
  DefaultText: string): string;
var Key: string;
begin
  if LongInt(Length(RootClass)) + Length(ComponentName) + Length(PropertyName) + 2 > 255 then
    raise Exception.Create('Invalid form catalogue');
  Key := RootClass + '.' + ComponentName + '.' + PropertyName;
  if ReadValue(FCode, Key, Result) then Exit;
  if (FCode <> 'en') and ReadValue('en', Key, Result) then Exit;
  Result := DefaultText;
end;
function TFormTextCatalog.TranslateResource(Ident: Word; const DefaultText: string): string;
var Key: string[5];
begin
  Key := IntToStr(Ident);
  if ProfileValue(FDirectory + FCode + '.LNG', 'Strings', Key, Result) then Result := Decode(Result)
  else if (FCode <> 'en') and ProfileValue(FDirectory + 'en.LNG', 'Strings', Key, Result) then Result := Decode(Result)
  else Result := DefaultText;
end;
end.
