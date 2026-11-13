{ Import Windows 3.x Program Manager groups as Start menus of their own. }
unit GrpSync;

interface

function SyncProgramGroups(Force: Boolean;
  var Imported, Rejected: Integer): Boolean;
procedure AutoSyncProgramGroups;

implementation

uses Classes, SysUtils, WinProcs, IniFiles, Profile, Settings, Files, Start,
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

{ PROGMAN.INI holds ANSI paths; DOS file access needs the OEM name, as
  PROGMAN's OpenFile converts it (German Windows has an O-umlaut in ZUBEHOR.GRP). }
function OemPath(const Value: string): string;
var
  Buffer: array[0..255] of Char;
begin
  StrPCopy(Buffer, Value);
  AnsiToOem({$IFDEF FPC}PFarChar{$ELSE}PChar{$ENDIF}(@Buffer),
    {$IFDEF FPC}PFarChar{$ELSE}PChar{$ENDIF}(@Buffer));
  OemPath := StrPas(Buffer);
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

const
  { GetPrivateProfileString trims control characters and blanks from the
    default, so a missing key is told apart by a printable value. }
  NoKey = '<no key>';

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
      Existing := Profile.ReadString(Section, Candidate + '*', NoKey)
    else
      Existing := Profile.ReadString(Section, Candidate, NoKey);
    if Existing = NoKey then
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

const
  { CALMIRA.INI lists the Start menus that the groups made, so the next
    synchronisation replaces them and leaves menus of the user alone. }
  OwnedSection = 'Program Groups';
  { The menus of a fresh START.INI: English stand-ins for the groups. }
  DefaultGroups: array[0..4] of string[11] = ('Accessories', 'Games',
    'Main', 'Network', 'Startup');
  { Program Manager's startup group in the languages of Windows 3.1, for
    a PROGMAN.INI without a Startup= setting. }
  StartupNames: array[0..5] of string[21] = ('Startup', 'Autostart',
    'D'#233'marrage', 'Opstarten', 'Esecuzione automatica', 'Inicio');

function MenuText(const Key: string): string;
var
  S: string;
  I: Integer;
begin
  S := Key;
  if (S <> '') and (S[Length(S)] = '*') then
    Delete(S, Length(S), 1);
  I := Pos('&', S);
  if I <> 0 then
    Delete(S, I, 1);
  MenuText := S;
end;

{ Submenus first, alphabetically, then programs and separators in their
  order: imported groups were appended below the programs before. }
procedure PutFoldersFirst(Profile: TProfile; const Section: string);
var
  Keys, FolderKeys, FolderValues, OtherKeys, OtherValues: TStringList;
  Key: string;
  I, J: Integer;
begin
  Keys := TStringList.Create;
  FolderKeys := TStringList.Create;
  FolderValues := TStringList.Create;
  OtherKeys := TStringList.Create;
  OtherValues := TStringList.Create;
  try
    Profile.ReadSection(Section, Keys);
    for I := 0 to Keys.Count - 1 do
    begin
      Key := Keys[I];
      if (Key <> '') and (Key[Length(Key)] = '*') then
      begin
        J := 0;
        while (J < FolderKeys.Count) and
          (CompareText(MenuText(FolderKeys[J]), MenuText(Key)) <= 0) do
          Inc(J);
        FolderKeys.Insert(J, Key);
        FolderValues.Insert(J, Profile.ReadString(Section, Key, ''));
      end
      else
      begin
        OtherKeys.Add(Key);
        OtherValues.Add(Profile.ReadString(Section, Key, ''));
      end;
    end;
    Profile.EraseSection(Section);
    for I := 0 to FolderKeys.Count - 1 do
      Profile.WriteString(Section, FolderKeys[I], FolderValues[I]);
    for I := 0 to OtherKeys.Count - 1 do
      Profile.WriteString(Section, OtherKeys[I], OtherValues[I]);
  finally
    OtherValues.Free;
    OtherKeys.Free;
    FolderValues.Free;
    FolderKeys.Free;
    Keys.Free;
  end;
end;

procedure ReadOwnedMenus(Owned: TStringList);
var
  Keys: TStringList;
  I: Integer;
begin
  Keys := TStringList.Create;
  try
    ini.ReadSection(OwnedSection, Keys);
    for I := 0 to Keys.Count - 1 do
      Owned.Add(ini.ReadString(OwnedSection, Keys[I], ''));
  finally
    Keys.Free;
  end;
end;

function SyncProgramGroups(Force: Boolean;
  var Imported, Rejected: Integer): Boolean;
var
  Progman, StartProfile: TProfile;
  Names, Paths, Owned, Captions, GroupNames: TStringList;
  Group: ^TProgramGroup;
  ErrorText, Path, Signature, OldSignature, StartupName: string;
  ProgramsCaption, RootCaption, ParentSection, RootSection,
    GroupCaption, GroupSection, ItemCaption: string;
  Hash: Longint;
  I, J: Integer;
  Present, OldTree: Boolean;
begin
  SyncProgramGroups := False;
  Imported := 0;
  Rejected := 0;
  if not FileExists(WinPath + 'PROGMAN.INI') then
    Exit;
  Names := TStringList.Create;
  Paths := TStringList.Create;
  Owned := TStringList.Create;
  Captions := TStringList.Create;
  GroupNames := TStringList.Create;
  New(Group);
  try
    Progman := TProfile.Create(WinPath + 'PROGMAN.INI');
    try
      Progman.ReadSection('Groups', Names);
      for I := 0 to Names.Count - 1 do
      begin
        Path := GroupPath(Progman.ReadString('Groups', Names[I], ''));
        if Path <> '' then
          Paths.Add(OemPath(Path));
      end;
      StartupName := Progman.ReadString('Settings', 'Startup', '');
    finally
      Progman.Free;
    end;

    Hash := 5381;
    { The groups became menus of their own in 5.0.92; an older signature
      must not keep the former Program Manager submenu. }
    HashString(Hash, 'menus');
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
    { The caption of the submenu that earlier versions filled. }
    RootCaption := CleanName(ini.ReadString('Start Menu',
      'ProgramGroupsCaption', 'Program Manager'), 'Program Manager');
    ParentSection := 'Start\' + ProgramsCaption;
    RootSection := ParentSection + '\' + RootCaption;
    ReadOwnedMenus(Owned);
    StartProfile := TProfile.Create(StartFile);
    try
      OldTree := StartProfile.ReadString(ParentSection,
        RootCaption + '*', NoKey) <> NoKey;
      Present := Owned.Count = Imported;
      for I := 0 to Owned.Count - 1 do
        if StartProfile.ReadString(ParentSection, Owned[I] + '*',
          NoKey) = NoKey then
          Present := False;
      if not Force and (Signature = OldSignature) and Present and
        not OldTree then
        Exit;
      if OldTree then
        RemoveImportedTree(StartProfile, ParentSection, RootCaption,
          RootSection);
      { The first groups replace the stand-ins of a fresh START.INI. }
      if (Owned.Count = 0) and (Imported <> 0) then
        for I := Low(DefaultGroups) to High(DefaultGroups) do
          Owned.Add(DefaultGroups[I]);
      for I := 0 to Owned.Count - 1 do
        RemoveImportedTree(StartProfile, ParentSection, Owned[I],
          ParentSection + '\' + Owned[I]);
      for I := 0 to Paths.Count - 1 do
        if LoadProgramGroup(Paths[I], Group^, ErrorText) then
        begin
          GroupCaption := UniqueKey(StartProfile, ParentSection,
            CleanName(Group^.Name, 'Group'), True);
          StartProfile.WriteString(ParentSection, GroupCaption + '*',
            ';;0;<programs>;0');
          Captions.Add(GroupCaption);
          GroupNames.Add(Group^.Name);
          GroupSection := ParentSection + '\' + GroupCaption;
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
      PutFoldersFirst(StartProfile, ParentSection);
    finally
      StartProfile.Free;
    end;
    ini.EraseSection(OwnedSection);
    for I := 0 to Captions.Count - 1 do
      ini.WriteString(OwnedSection, 'Menu' + IntToStr(I + 1), Captions[I]);
    { Calmira runs the startup group as the shell; German Windows calls it
      Autostart. A StartupGroup= of the user stays. }
    if ini.ReadString('Start Menu', 'StartupGroup', NoKey) = NoKey then
      for I := 0 to GroupNames.Count - 1 do
      begin
        if StartupName <> '' then
          Present := CompareText(GroupNames[I], StartupName) = 0
        else
        begin
          Present := False;
          for J := Low(StartupNames) to High(StartupNames) do
            if CompareText(GroupNames[I], StartupNames[J]) = 0 then
              Present := True;
        end;
        if Present then
        begin
          ini.WriteString('Start Menu', 'StartupGroup', Captions[I]);
          Break;
        end;
      end;
    ini.WriteString('Start Menu', 'ProgramGroupsSignature', Signature);
    { As the Start menu editor does: the image cache follows START.INI item
      by item, so a changed menu must rebuild it, or the icons slip. }
    DeleteFile(FileWritePath + 'BMPCACHE.BMP');
    SyncProgramGroups := True;
  finally
    Dispose(Group);
    GroupNames.Free;
    Captions.Free;
    Owned.Free;
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
