{ Import Windows 3.x Program Manager groups into an owned Start-menu tree. }
unit GrpSync;

interface

function SyncProgramGroups(Force: Boolean;
  var Imported, Rejected: Integer): Boolean;
procedure AutoSyncProgramGroups;

implementation

uses Classes, SysUtils, IniFiles, Profile, Settings, Files, Start,
  program_groups;

function CleanName(const Value, Fallback: string): string;
var
  I: Integer;
  S: string;
begin
  S := Value;
  for I := 1 to Length(S) do
    if S[I] in ['\', '=', '[', ']', #13, #10] then
      S[I] := '-';
  while (S <> '') and (S[Length(S)] = '*') do
    Delete(S, Length(S), 1);
  if S = '' then
    S := Fallback;
  CleanName := S;
end;

function GroupPath(const Value: string): string;
var
  S: string;
begin
  S := Value;
  if (Length(S) >= 2) and (S[1] = '"') and (S[Length(S)] = '"') then
    S := Copy(S, 2, Length(S) - 2);
  if (Length(S) >= 2) and (S[2] = ':') then
    GroupPath := S
  else if (S <> '') and (S[1] = '\') then
    GroupPath := Copy(WinPath, 1, 2) + S
  else
    GroupPath := WinPath + S;
end;

procedure HashByte(var Hash: Longint; Value: Byte);
begin
  Hash := (Hash shl 5) + Hash;
  Hash := Hash xor Value;
end;

procedure HashString(var Hash: Longint; const Value: string);
var
  I: Integer;
begin
  HashByte(Hash, Length(Value));
  for I := 1 to Length(Value) do
    HashByte(Hash, Ord(Value[I]));
end;

procedure HashGroup(var Hash: Longint; const Group: TProgramGroup);
var
  I: Integer;
begin
  HashString(Hash, Group.Name);
  HashByte(Hash, Group.ProgramCount);
  for I := 0 to Group.ProgramCount - 1 do
    with Group.Programs[I] do
    begin
      HashString(Hash, Caption);
      HashString(Hash, Command);
      HashString(Hash, IconFile);
      HashString(Hash, WorkDirectory);
      HashByte(Hash, IconIndex and $FF);
      HashByte(Hash, (IconIndex shr 8) and $FF);
      HashByte(Hash, HotKey and $FF);
      HashByte(Hash, (HotKey shr 8) and $FF);
      HashByte(Hash, ShowCommand and $FF);
    end;
end;

function CalmiraShowMode(Command: Word): Integer;
begin
  case Command of
    0: CalmiraShowMode := 3;
    2, 6, 7: CalmiraShowMode := 1;
    3: CalmiraShowMode := 2;
  else
    CalmiraShowMode := 0;
  end;
end;

function UniqueKey(Profile: TProfile; const Section, Wanted: string;
  SubMenu: Boolean): string;
var
  BaseName, Candidate, Existing: string;
  Number: Integer;
begin
  BaseName := Copy(Wanted, 1, 70);
  Candidate := BaseName;
  Number := 1;
  repeat
    if SubMenu then
      Existing := Profile.ReadString(Section, Candidate + '*', #1)
    else
      Existing := Profile.ReadString(Section, Candidate, #1);
    if Existing = #1 then
    begin
      UniqueKey := Candidate;
      Exit;
    end;
    Inc(Number);
    Candidate := Copy(BaseName, 1, 68) + ' (' + IntToStr(Number) + ')';
  until Number = 100;
  UniqueKey := Copy(BaseName, 1, 68) + ' (99)';
end;

procedure RemoveImportedTree(Profile: TProfile; const ParentSection,
  RootCaption, RootSection: string);
var
  Sections: TStringList;
  I: Integer;
begin
  Profile.DeleteKey(ParentSection, RootCaption + '*');
  Sections := TStringList.Create;
  try
    Profile.ReadSections(Sections);
    for I := Sections.Count - 1 downto 0 do
      if (CompareText(Sections[I], RootSection) = 0) or
        (CompareText(Copy(Sections[I], 1, Length(RootSection) + 1),
          RootSection + '\') = 0) then
        Profile.EraseSection(Sections[I]);
  finally
    Sections.Free;
  end;
end;

function SyncProgramGroups(Force: Boolean;
  var Imported, Rejected: Integer): Boolean;
var
  Progman, StartProfile: TProfile;
  Names, Paths: TStringList;
  Group: ^TProgramGroup;
  ErrorText, Path, Signature, OldSignature: string;
  ProgramsCaption, RootCaption, ParentSection, RootSection,
    GroupCaption, GroupSection, ItemCaption: string;
  Hash: Longint;
  I, J: Integer;
  RootPresent: Boolean;
begin
  SyncProgramGroups := False;
  Imported := 0;
  Rejected := 0;
  if not FileExists(WinPath + 'PROGMAN.INI') then
    Exit;
  Names := TStringList.Create;
  Paths := TStringList.Create;
  New(Group);
  try
    Progman := TProfile.Create(WinPath + 'PROGMAN.INI');
    try
      Progman.ReadSection('Groups', Names);
      for I := 0 to Names.Count - 1 do
      begin
        Path := GroupPath(Progman.ReadString('Groups', Names[I], ''));
        if Path <> '' then
          Paths.Add(Path);
      end;
    finally
      Progman.Free;
    end;

    Hash := 5381;
    for I := 0 to Paths.Count - 1 do
      if LoadProgramGroup(Paths[I], Group^, ErrorText) then
      begin
        HashString(Hash, Paths[I]);
        HashGroup(Hash, Group^);
        Inc(Imported);
      end
      else
        Inc(Rejected);
    if Rejected <> 0 then
      Exit;
    Signature := IntToHex(Hash, 8);
    OldSignature := ini.ReadString('Start Menu',
      'ProgramGroupsSignature', '');
    ProgramsCaption := CleanName(ini.ReadString('Start Menu',
      'ProgramsGroup', '&Programs'), '&Programs');
    RootCaption := CleanName(ini.ReadString('Start Menu',
      'ProgramGroupsCaption', 'Program Manager'), 'Program Manager');
    ParentSection := 'Start\' + ProgramsCaption;
    RootSection := ParentSection + '\' + RootCaption;
    StartProfile := TProfile.Create(StartFile);
    try
      RootPresent := StartProfile.ReadString(ParentSection,
        RootCaption + '*', #1) <> #1;
      if not Force and (Signature = OldSignature) and
        (((Imported <> 0) and RootPresent) or
         ((Imported = 0) and not RootPresent)) then
        Exit;
      RemoveImportedTree(StartProfile, ParentSection, RootCaption,
        RootSection);
      if Imported <> 0 then
      begin
        StartProfile.WriteString(ParentSection, RootCaption + '*',
          ';;0;<programs>;0');
        for I := 0 to Paths.Count - 1 do
          if LoadProgramGroup(Paths[I], Group^, ErrorText) then
          begin
            GroupCaption := UniqueKey(StartProfile, RootSection,
              CleanName(Group^.Name, 'Group'), True);
            StartProfile.WriteString(RootSection, GroupCaption + '*',
              ';;0;<programs>;0');
            GroupSection := RootSection + '\' + GroupCaption;
            for J := 0 to Group^.ProgramCount - 1 do
              with Group^.Programs[J] do
              begin
                ItemCaption := UniqueKey(StartProfile, GroupSection,
                  CleanName(Caption, 'Program'), False);
                StartProfile.WriteString(GroupSection, ItemCaption,
                  PackStartInfo(Command, WorkDirectory, IconFile,
                    CalmiraShowMode(ShowCommand), IconIndex));
              end;
          end;
      end;
    finally
      StartProfile.Free;
    end;
    ini.WriteString('Start Menu', 'ProgramGroupsSignature', Signature);
    SyncProgramGroups := True;
  finally
    Dispose(Group);
    Paths.Free;
    Names.Free;
  end;
end;

procedure AutoSyncProgramGroups;
var
  Imported, Rejected: Integer;
begin
  if ini.ReadBool('Start Menu', 'SyncProgramGroups', True) then
    SyncProgramGroups(False, Imported, Rejected);
end;

end.
