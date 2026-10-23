{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 TIniFile over the Windows private profile API, so writes share the
  USER profile cache with other Windows programs. }
unit IniFiles;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This IniFiles unit requires Win16}{$ENDIF}
interface
uses Classes;
type
  TIniFile = class(TObject)
  private
    FFileName: string;
  public
    constructor Create(const FileName: string);
    function ReadString(const Section, Ident, Default: string): string;
    procedure WriteString(const Section, Ident, Value: string);
    function ReadInteger(const Section, Ident: string; Default: LongInt): LongInt;
    procedure WriteInteger(const Section, Ident: string; Value: LongInt);
    function ReadBool(const Section, Ident: string; Default: Boolean): Boolean;
    procedure WriteBool(const Section, Ident: string; Value: Boolean);
    procedure ReadSection(const Section: string; Strings: TStrings);
    procedure ReadSectionValues(const Section: string; Strings: TStrings);
    procedure EraseSection(const Section: string);
    property FileName: string read FFileName;
  end;
implementation
uses SysUtils, WinProcs;
const
  { Section key lists are returned as one buffer of #0-separated names. }
  SectionBufferSize = 8192;
type
  TName = array[0..255] of Char;
constructor TIniFile.Create(const FileName: string);
begin
  inherited Create;
  FFileName := FileName;
end;
function TIniFile.ReadString(const Section, Ident, Default: string): string;
var CSection, CIdent, CDefault, CFile, Buffer: TName;
begin
  GetPrivateProfileString(StrPCopy(CSection, Section), StrPCopy(CIdent, Ident),
    StrPCopy(CDefault, Default), Buffer, SizeOf(Buffer) - 1, StrPCopy(CFile, FFileName));
  Result := StrPas(Buffer);
end;
procedure TIniFile.WriteString(const Section, Ident, Value: string);
var CSection, CIdent, CValue, CFile: TName;
begin
  WritePrivateProfileString(StrPCopy(CSection, Section), StrPCopy(CIdent, Ident),
    StrPCopy(CValue, Value), StrPCopy(CFile, FFileName));
end;
function TIniFile.ReadInteger(const Section, Ident: string; Default: LongInt): LongInt;
var Text: string;
begin
  Text := ReadString(Section, Ident, '');
  if (Length(Text) > 2) and (Text[1] = '0') and (UpCase(Text[2]) = 'X') then
    Text := '$' + Copy(Text, 3, 255);
  Result := StrToIntDef(Text, Default);
end;
procedure TIniFile.WriteInteger(const Section, Ident: string; Value: LongInt);
begin
  WriteString(Section, Ident, IntToStr(Value));
end;
function TIniFile.ReadBool(const Section, Ident: string; Default: Boolean): Boolean;
begin
  Result := ReadInteger(Section, Ident, Ord(Default)) <> 0;
end;
procedure TIniFile.WriteBool(const Section, Ident: string; Value: Boolean);
const Values: array[Boolean] of string[1] = ('0', '1');
begin
  WriteString(Section, Ident, Values[Value]);
end;
procedure TIniFile.ReadSection(const Section: string; Strings: TStrings);
var CSection, CFile: TName; Buffer, P: PChar;
begin
  GetMem(Buffer, SectionBufferSize);
  Strings.BeginUpdate;
  try
    Strings.Clear;
    Buffer[0] := #0;
    GetPrivateProfileString(StrPCopy(CSection, Section), nil, '', Buffer,
      SectionBufferSize, StrPCopy(CFile, FFileName));
    P := Buffer;
    while P^ <> #0 do
    begin
      Strings.Add(StrPas(P));
      Inc(P, StrLen(P) + 1);
    end;
  finally
    Strings.EndUpdate;
    FreeMem(Buffer, SectionBufferSize);
  end;
end;
procedure TIniFile.ReadSectionValues(const Section: string; Strings: TStrings);
var Keys: TStringList; I: Integer;
begin
  Keys := TStringList.Create;
  Strings.BeginUpdate;
  try
    ReadSection(Section, Keys);
    Strings.Clear;
    for I := 0 to Keys.Count - 1 do
      Strings.Add(Keys[I] + '=' + ReadString(Section, Keys[I], ''));
  finally
    Strings.EndUpdate;
    Keys.Free;
  end;
end;
procedure TIniFile.EraseSection(const Section: string);
var CSection, CFile: TName;
begin
  WritePrivateProfileString(StrPCopy(CSection, Section), nil, nil, StrPCopy(CFile, FFileName));
end;
end.
