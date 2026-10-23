program IniFilesTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, IniFiles;
const IniName = 'C:\PROBE.INI';
var Failed: Boolean;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure WriteSource;
var F: TextFile;
begin
  AssignFile(F, IniName); Rewrite(F);
  Writeln(F, '[Main]'); Writeln(F, 'Name=Calmira'); Writeln(F, 'Hex=0x1F');
  Writeln(F, 'Big=100000'); Writeln(F, 'Bad=abc'); Writeln(F, 'On=1');
  Writeln(F, '[Other]'); Writeln(F, 'X=1');
  CloseFile(F);
end;
procedure RunChecks;
var Ini: TIniFile; List: TStringList;
begin
  WriteSource;
  Ini := TIniFile.Create(IniName); List := TStringList.Create;
  try
    Check(Ini.FileName = IniName, 'file name');
    Check(Ini.ReadString('Main', 'Name', '') = 'Calmira', 'read string');
    Check(Ini.ReadString('Main', 'Missing', 'dflt') = 'dflt', 'string default');
    Check(Ini.ReadInteger('Main', 'Hex', 0) = 31, 'C hex integer');
    Check(Ini.ReadInteger('Main', 'Big', 0) = 100000, 'long integer');
    Check(Ini.ReadInteger('Main', 'Bad', 7) = 7, 'invalid integer default');
    Check(Ini.ReadBool('Main', 'On', False) and Ini.ReadBool('Main', 'Off', True), 'read bool');
    Ini.ReadSection('Main', List);
    Check(List.CommaText = 'Name,Hex,Big,Bad,On', 'read section');
    Ini.ReadSectionValues('Other', List);
    Check((List.Count = 1) and (List[0] = 'X=1'), 'read section values');
    Ini.WriteString('New', 'Text', 'hello world'); Ini.WriteInteger('New', 'Num', -42);
    Ini.WriteBool('New', 'Flag', True);
    Check((Ini.ReadString('New', 'Text', '') = 'hello world') and
      (Ini.ReadInteger('New', 'Num', 0) = -42) and Ini.ReadBool('New', 'Flag', False), 'write and reread');
    Ini.EraseSection('Other');
    Ini.ReadSection('Other', List);
    Check(List.Count = 0, 'erase section');
    Ini.ReadSection('Empty', List);
    Check(List.Count = 0, 'missing section');
  finally List.Free; Ini.Free; end;
  WritePrivateProfileString(nil, nil, nil, IniName);
  Ini := TIniFile.Create(IniName);
  try Check(Ini.ReadString('New', 'Text', '') = 'hello world', 'flushed to disk');
  finally Ini.Free; end;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP IniFiles');
  try RunChecks;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'stack');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
