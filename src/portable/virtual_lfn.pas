{ Portable virtual long-filename mapping for FAT12/16/32 hosts.

  Files stay addressable by an actual DOS 8.3 alias.  DESCRIPT.ION stores the
  display name used by Calmira and, later, by the Win16 common-dialog hook. }
unit virtual_lfn;

{$IFDEF FPC}
  {$mode delphi}
  {$H-}
{$ENDIF}

interface

type
  TVirtualLFNEntry = record
    AliasName: string[12];
    LongName: string[255];
    Metadata: string[255];
  end;

function IsDos83Name(const FileName: string): Boolean;
function MakeDosAlias(const LongName: string; Serial: Word): string;
function ParseDescriptionLine(const Line: string;
  var Entry: TVirtualLFNEntry): Boolean;
function ComposeDescriptionLine(const Entry: TVirtualLFNEntry): string;

implementation

uses SysUtils;

function IsDosChar(C: Char): Boolean;
begin
  C := UpCase(C);
  IsDosChar := ((C >= 'A') and (C <= 'Z')) or
    ((C >= '0') and (C <= '9')) or
    (Pos(C, '$%''-_@~`!(){}^#&') > 0);
end;

function IsReservedBase(const BaseName: string): Boolean;
var
  S: string;
begin
  S := UpperCase(BaseName);
  IsReservedBase := (S = 'CON') or (S = 'PRN') or (S = 'AUX') or
    (S = 'NUL') or
    ((Length(S) = 4) and ((Copy(S, 1, 3) = 'COM') or
      (Copy(S, 1, 3) = 'LPT')) and (S[4] >= '1') and (S[4] <= '9'));
end;

function IsDos83Name(const FileName: string): Boolean;
var
  DotAt, I, BaseLength, ExtensionLength: Integer;
  BaseName: string;
begin
  IsDos83Name := False;
  if (FileName = '') or (FileName = '.') or (FileName = '..') or
    (Pos('\', FileName) > 0) or (Pos('/', FileName) > 0) or
    (Pos(':', FileName) > 0) or (Pos(' ', FileName) > 0) then
    Exit;
  DotAt := Pos('.', FileName);
  if (DotAt > 0) and (Pos('.', Copy(FileName, DotAt + 1, 255)) > 0) then
    Exit;
  if DotAt = 0 then
  begin
    BaseLength := Length(FileName);
    ExtensionLength := 0;
    BaseName := FileName;
  end
  else
  begin
    BaseLength := DotAt - 1;
    ExtensionLength := Length(FileName) - DotAt;
    BaseName := Copy(FileName, 1, BaseLength);
  end;
  if (BaseLength < 1) or (BaseLength > 8) or
    (ExtensionLength > 3) or IsReservedBase(BaseName) then
    Exit;
  for I := 1 to Length(FileName) do
    if (FileName[I] <> '.') and not IsDosChar(FileName[I]) then
      Exit;
  IsDos83Name := True;
end;

function CleanPart(const Value: string): string;
var
  I: Integer;
  C: Char;
  ResultText: string;
begin
  ResultText := '';
  for I := 1 to Length(Value) do
  begin
    C := UpCase(Value[I]);
    if IsDosChar(C) then
      ResultText := ResultText + C
    else if (C <> ' ') and (C <> '.') then
      ResultText := ResultText + '_';
  end;
  CleanPart := ResultText;
end;

function MakeDosAlias(const LongName: string; Serial: Word): string;
var
  NameOnly, BaseName, ExtensionName, NumberText: string;
  I, DotAt, PrefixLength: Integer;
begin
  NameOnly := LongName;
  for I := Length(NameOnly) downto 1 do
    if (NameOnly[I] = '\') or (NameOnly[I] = '/') or
      (NameOnly[I] = ':') then
    begin
      NameOnly := Copy(NameOnly, I + 1, 255);
      Break;
    end;
  if IsDos83Name(NameOnly) then
  begin
    MakeDosAlias := UpperCase(NameOnly);
    Exit;
  end;
  DotAt := 0;
  for I := Length(NameOnly) downto 2 do
    if NameOnly[I] = '.' then
    begin
      DotAt := I;
      Break;
    end;
  if DotAt = 0 then
  begin
    BaseName := NameOnly;
    ExtensionName := '';
  end
  else
  begin
    BaseName := Copy(NameOnly, 1, DotAt - 1);
    ExtensionName := CleanPart(Copy(NameOnly, DotAt + 1, 255));
  end;
  BaseName := CleanPart(BaseName);
  if BaseName = '' then
    BaseName := 'FILE';
  if Serial = 0 then
    Serial := 1;
  NumberText := IntToStr(Serial);
  PrefixLength := 7 - Length(NumberText);
  if PrefixLength < 1 then
    PrefixLength := 1;
  BaseName := Copy(BaseName, 1, PrefixLength) + '~' + NumberText;
  if ExtensionName <> '' then
    BaseName := BaseName + '.' + Copy(ExtensionName, 1, 3);
  MakeDosAlias := BaseName;
end;

function TrimRightSpace(const Value: string): string;
var
  ResultText: string;
begin
  ResultText := Value;
  while (Length(ResultText) > 0) and
    ((ResultText[Length(ResultText)] = ' ') or
      (ResultText[Length(ResultText)] = #9)) do
    Delete(ResultText, Length(ResultText), 1);
  TrimRightSpace := ResultText;
end;

function ParseDescriptionLine(const Line: string;
  var Entry: TVirtualLFNEntry): Boolean;
var
  I, StartAt, MetadataAt: Integer;
  Work: string;
begin
  Entry.AliasName := '';
  Entry.LongName := '';
  Entry.Metadata := '';
  ParseDescriptionLine := False;
  I := 1;
  while (I <= Length(Line)) and (Line[I] <> ' ') and (Line[I] <> #9) do
    Inc(I);
  if (I = 1) or (I > Length(Line)) then
    Exit;
  Entry.AliasName := UpperCase(Copy(Line, 1, I - 1));
  if not IsDos83Name(Entry.AliasName) then
    Exit;
  StartAt := I;
  while (StartAt <= Length(Line)) and
    ((Line[StartAt] = ' ') or (Line[StartAt] = #9)) do
    Inc(StartAt);
  Work := Copy(Line, StartAt, 255);
  MetadataAt := Pos(#4, Work);
  if MetadataAt > 0 then
  begin
    Entry.Metadata := Copy(Work, MetadataAt + 1, 255);
    Work := Copy(Work, 1, MetadataAt - 1);
  end;
  Entry.LongName := TrimRightSpace(Work);
  ParseDescriptionLine := Entry.LongName <> '';
end;

function ComposeDescriptionLine(const Entry: TVirtualLFNEntry): string;
var
  ResultText: string;
begin
  ResultText := UpperCase(Entry.AliasName) + ' ' + Entry.LongName;
  if Entry.Metadata <> '' then
    ResultText := ResultText + #4 + Entry.Metadata;
  ComposeDescriptionLine := ResultText;
end;

end.
