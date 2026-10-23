{ Runtime language catalogues: one executable, external Windows ANSI data. }
unit language_catalog;
{$IFDEF FPC}{$mode delphi}{$H-}{$ENDIF}
interface
function ConfigureLanguage(const Directory, Code: string): Boolean;
function LanguageText(const Section, Key, Default: string): string;
function SelectedLanguage: string;
procedure InitializeLanguage(const Directory, ConfigFile: string);
function ReadConfiguration(const FileName, Section, Key, Default: string): string;
implementation
uses SysUtils;
var
  LanguageDirectory: string;
  LanguageCode: string;

function SafeCode(const Code: string): Boolean;
var I: Integer;
begin
  SafeCode := False;
  if (Length(Code) < 2) or (Length(Code) > 8) then Exit;
  for I := 1 to Length(Code) do
    if not (Code[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-']) then Exit;
  SafeCode := True;
end;

function DecodeValue(const Value: string): string;
var I: Integer; ResultText: string;
begin
  ResultText := '';
  I := 1;
  while I <= Length(Value) do
  begin
    if (Value[I] = '\') and (I < Length(Value)) then
    begin
      Inc(I);
      case Value[I] of
        'n': ResultText := ResultText + #13#10;
        't': ResultText := ResultText + #9;
        '\': ResultText := ResultText + '\';
      else ResultText := ResultText + '\' + Value[I];
      end;
    end
    else ResultText := ResultText + Value[I];
    Inc(I);
  end;
  DecodeValue := ResultText;
end;

function ReadIniValue(const FileName, Section, Key: string;
  var Value: string): Boolean;
var
  Source: Text;
  Line, ActiveSection: string;
  P, ErrorCode: Integer;
begin
  ReadIniValue := False;
  ActiveSection := '';
  AssignFile(Source, FileName);
  {$I-} Reset(Source); ErrorCode := IOResult; {$I+}
  if ErrorCode <> 0 then Exit;
  try
    while not Eof(Source) do
    begin
      ReadLn(Source, Line);
      if (Line <> '') and (Line[1] = '[') and
        (Line[Length(Line)] = ']') then
        ActiveSection := Copy(Line, 2, Length(Line) - 2)
      else if CompareText(ActiveSection, Section) = 0 then
      begin
        P := Pos('=', Line);
        if (P > 0) and
          (CompareText(Copy(Line, 1, P - 1), Key) = 0) then
        begin
          Value := Copy(Line, P + 1, 255);
          ReadIniValue := True;
          Exit;
        end;
      end;
    end;
  finally
    CloseFile(Source);
  end;
end;

function ReadValue(const Code, Section, Key: string;
  var Value: string): Boolean;
begin
  Value := '';
  ReadValue := ReadIniValue(LanguageDirectory + Code + '.LNG',
    Section, Key, Value);
  Value := DecodeValue(Value);
end;

function ReadConfiguration(const FileName, Section, Key, Default: string): string;
var Value: string;
begin
  Value := Default;
  ReadIniValue(FileName, Section, Key, Value);
  ReadConfiguration := Value;
end;

function ConfigureLanguage(const Directory, Code: string): Boolean;
var Probe: string;
begin
  LanguageDirectory := Directory;
  if (LanguageDirectory <> '') and
    not (LanguageDirectory[Length(LanguageDirectory)] in ['\', '/']) then
    LanguageDirectory := LanguageDirectory + PathDelim;
  LanguageCode := 'en';
  ConfigureLanguage := False;
  if not SafeCode(Code) then Exit;
  if ReadValue(LowerCase(Code), 'Language', 'Code', Probe) and
    (CompareText(Probe, Code) = 0) then
  begin
    LanguageCode := LowerCase(Code);
    ConfigureLanguage := True;
  end;
end;

function LanguageText(const Section, Key, Default: string): string;
var Value: string;
begin
  if ReadValue(LanguageCode, Section, Key, Value) or
    ((LanguageCode <> 'en') and ReadValue('en', Section, Key, Value)) then
    LanguageText := Value
  else LanguageText := Default;
end;

function SelectedLanguage: string;
begin SelectedLanguage := LanguageCode; end;
procedure InitializeLanguage(const Directory, ConfigFile: string);
var Code: string;
begin
  Code := 'en';
  ReadIniValue(ConfigFile, 'Language', 'Selected', Code);
  ConfigureLanguage(Directory, Code);
end;
initialization
  LanguageCode := 'en';
end.
