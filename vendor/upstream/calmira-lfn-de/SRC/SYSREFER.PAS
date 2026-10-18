{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.3                                                  }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    This program is free software; you can redistribute it and/or modify  }
{    it under the terms of the GNU General Public License as published by  }
{    the Free Software Foundation; either version 2 of the License, or     }
{    (at your option) any later version.                                   }
{                                                                          }
{    This program is distributed in the hope that it will be useful,       }
{    but WITHOUT ANY WARRANTY; without even the implied warranty of        }
{    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         }
{    GNU General Public License for more details.                          }
{                                                                          }
{    You should have received a copy of the GNU General Public License     }
{    along with this program; if not, write to the Free Software           }
{    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.             }
{                                                                          }
{**************************************************************************}

unit SysRefer;

{ TSystemReference is a class used to unify shortcuts and aliases.
  Each shortcut and alias contains a reference object, which points
  to a file, folder or disk drive, and handles most of the action.

  There are 5 string properties, which require a lot of memory,
  so instead of using 5 string fields, each property maps to
  a function which assigns and maintains a dynamic string.
  Empty strings don't take up any memory.

  BeginUpdate, EndUpdate - ensures that the OnChange event is
    not triggered while the fields are being modified.

  Edit - creates a property dialog to edit the reference, executes
    it and returns the result of the edit, either mrOK or mrCancel.

  LoadFromStream, SaveToStream - this uses a TStreamer object to
    read and write the reference.

  Reference objects do not maintain icons themselves, but have
  an AssignIcon function that sets a TIcon to a suitable image that
  reflects the object. }

interface

uses Classes, LfnUtils, Graphics, SysUtils, IniFiles, Forms, Streamer;

type
  TReferenceKind = (rkDrive, rkFolder, rkFile, rkInternet);

  TSystemReference = class
  private
    { Private declarations }
    FKind: TReferenceKind;
    FShowMode: Integer;
    FUseDocFolder: Boolean;
    {FIconIndex: Integer;}
    FOnChange: TNotifyEvent;
    FUpdates: Integer;
    FStringBuf: array[0..4] of PString;
    FLeft, FTop: Integer;
    FSystemString: string;
    procedure SetKind(value: TReferenceKind);
    procedure SetStringProp(i: Integer; const s: string);
    function GetStringProp(i: Integer): string;
  protected
    { Protected declarations }
    procedure Change; virtual;
    procedure SetAsLast;
  public
    { Public declarations }
    constructor Create;
    destructor Destroy; override;
    procedure Open;
    procedure DragDrop(Source: TObject);
    procedure AcceptFiles(files: TStrings);
    function Edit: TModalResult;
    procedure AssignIcon(Icon: TIcon);
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure LoadFromStream(s: TStreamer);
    procedure SaveToStream(s: TStreamer);
    procedure LoadFromIni(ini: TIniFile; const section: string);
    procedure SaveToIni(ini: TIniFile; const section: string);
    function AssignFromExternal: Boolean;
    property SystemString: string Read FSystemString write FSystemString;
    property Left: Integer read FLeft write FLeft;
    property Top: Integer read FTop write FTop;
    property Kind: TReferenceKind read FKind {write FKind};
    property Target: string index 0 read GetStringProp write SetStringProp;
    property Params: string index 1 read GetStringProp write SetStringProp;
    property WorkingFolder: string index 2 read GetStringProp write SetStringProp;
    property ShowMode: Integer read FShowMode write FShowMode;
    property UseDocFolder: Boolean read FUseDocFolder write FUseDocFolder;
    property Caption: string index 3 read GetStringProp write SetStringProp;
    {property IconFile: string index 4 read GetStringProp write SetStringProp;
    property IconIndex: Integer read FIconIndex write FIconIndex;}
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  { The two subclasses are only used to distinguish between shortcuts
    and aliases at run-time. }

{var
  { Preset references pointing to a drive, folder or file.  These can be
    used freely, but remember that there is no locking mechanism for
    mutual exclusion. }

const
  { The Lastxxxx variables hold information about the most recent program
    executed.  This is used to provide a suitable icon for the taskbar. }
  LastInstance: Word = 0;
  LastIconFile: TLfnFileName = '';
  LastIconIndex: Integer = 0;

implementation

uses Controls, IconWin, Desk, Files, SysRefEd, Strings, FileFind, MiscUtil,
  WinTypes, ShellAPI, Resource, Drives, WasteBin, FileMan, MultiGrd, Settings,
  FourDOS, TabNotBk, Environs, Clipbrd, Dialogs, CompSys, Internet,
  WinProcs, Locale;

constructor TSystemReference.Create;
var
  i: Integer;
begin
  inherited Create;
  for i := 0 to High(FStringBuf) do FStringBuf[i] := NullStr;
  SetKind(rkFolder);
end;

destructor TSystemReference.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FStringBuf) do DisposeStr(FStringBuf[i]);
  inherited Destroy;
end;

procedure TSystemReference.SetStringProp(i: Integer; const s: string);
begin
  if FStringBuf[i]^ <> s then
  begin
    AssignStr(FStringBuf[i], s);
    if i = 3 then Change; { caption field }
  end;
end;

function TSystemReference.GetStringProp(i: Integer): string;
begin
  Result := FStringBuf[i]^;
end;

procedure TSystemReference.Open;
begin
  case Kind of
    rkDrive, rkFolder:
      Desktop.OpenFolderRefresh(ExpandFoldername(EnvironSubst(Target), WinPath[1]));
    rkFile :
      begin
        SetAsLast;
        LastInstance := DefaultExec(Target, Params, WorkingFolder,
          ShowCmdsEx(ShowMode));
      end;
    rkInternet: DefaultExec(Target, '', '', SW_SHOWNORMAL);
  end;
end;

procedure TSystemReference.DragDrop(Source: TObject);
var
  f, win: TIconWindow;
  files: TStringList;
begin
  if Source is TMultiGrid then
  begin
    win := TMultiGrid(Source).Owner as TIconWindow;
    if Kind in [rkDrive, rkFolder] then
    begin
      { 3.11 -- changed VK_SHIFT to VK_MENU }
      if GetAsyncKeyState(VK_MENU) < 0 then
      begin
        win.DropAsAliases(Target);
        Exit;
      end;
      f := Desktop.WindowOf(Target);
      if f = nil then
      begin
        { Since there is no TDirectory to transfer file descriptions
          to, a separate object must be used to load them }
        if UseDescriptions then
          SharedDesc.LoadFromPath(MakePath(Target));
        try
          win.DropInFolder(Target);
        finally
          if UseDescriptions then SharedDesc.SaveToPath(MakePath(Target));
        end;
      end
      else win.DropInWindow(f.Dir);
    end
    else
    begin
      files := win.CompileFilenames;
      try
        AcceptFiles(files);
      finally
        files.Free;
      end;
    end;
  end
  else if (Source = Bin.Listbox) and (Kind <> rkFile) then
    Bin.RestoreTo(MakeDirname(Target))
  else if Source = FindList then
    AcceptFiles(FindForm.CompileSelection)
  else if Source is TStrings then
    AcceptFiles(TStrings(Source));
end;

procedure TSystemReference.AcceptFiles(files: TStrings);
var
  i: Integer;
  d: TLfnFileName;
  p: string;
begin
  { This should only be used to handle file drops from other programs,
    since file descriptions are not updated.  TIconWindow has
    DropInWindow and DropInFolder methods to handle normal file transfer. }
  if Kind in [rkFolder, rkDrive] then ProcessFiles(files, Target)
  else
  begin
    { Drop files into a program }
    p := Params;
    if UseDocFolder and (Files.Count > 0) then
    begin
      { Get rid of the pathnames }
      d := ExtractFileDir(files[0]);
      for i := 0 to files.Count-1 do
        files[i] := ExtractFileName(files[i]);
    end
    else d := WorkingFolder;
    { If no drop position is specified, add them to the end of the params }
    if Pos('%DROPPEDFILES%', Uppercase(params)) = 0 then
      AppendStr(p, ' %DROPPEDFILES%');
    Environment.Values['DROPPEDFILES'] := FileParams(files);
    LastInstance := DefaultExec(Target, p, d, ShowCmdsEx(ShowMode));
    if LastInstance <= 32 then
      ErrorMsgResFmt(SCannotOpenTarget, [Target])
    else SetAsLast;
    Environment.Values['DROPPEDFILES'] := '';
  end;
end;

procedure TSystemReference.AssignIcon(Icon: TIcon);
var
  h: HIcon;
  s: TLfnFileName;
begin
  Icon.Assign(icons.Get(SystemString));
end;

procedure TSystemReference.BeginUpdate;
begin
  Inc(FUpdates);
end;

procedure TSystemReference.EndUpdate;
begin
  if FUpdates > 0 then
  begin
    Dec(FUpdates);
    if FUpdates = 0 then Change;
  end;
end;

procedure TSystemReference.SetKind(value: TReferenceKind);
begin
  FKind := value;
  Change;
end;

procedure TSystemReference.Change;
begin
  if (FUpdates = 0) and Assigned(FOnChange) then FOnChange(self);
end;

function TSystemReference.Edit: TModalResult;
const
  Captions: array[Boolean] of Word = (SShortcutProperties, SAliasProperties);
var
  buf: TLfnFileName;
  s : string;
begin
  ShowHourglass;
  Result := mrCancel;
  SysRefEditDlg := TSysRefEditDlg.Create(Application);
  with SysRefEditDlg do
  begin
    AssignIcon(TargetIcon.Picture.Icon); { 3.1 }
    SysRefEditDlg.SystemString := Self.SystemString;
    Caption := Self.Caption+' Properties';
    CaptionLabel.Caption := Self.Caption;
    CapEdit.Text := Self.Caption;
    if Pos(' ',Target)=0 then
     TargetEdit.Text := Target
    else
      TargetEdit.Text := '"'+Target+'"';
    try
      if ShowModal = mrOK then
      begin
        Result := mrOK;
        {Kind := RefKind;}
        s := TargetEdit.Text;
        Target := NextITem(s,Word('"'),Delim_Whitespace);
        self.Caption := CapEdit.Text;
        Change;
      end;
    finally
      FreeAndNil(SysRefEditDlg);
    end;
  end;
end;

procedure TSystemReference.SetAsLast;
begin
{  LastIconFile := IconFile;
  LastIconIndex := IconIndex;}
end;

procedure TSystemReference.LoadFromStream(s: TStreamer);
begin
  BeginUpdate;
  with s do
  begin
    FLeft := ReadInteger;
    FTop := ReadInteger;
    {Kind := TReferenceKind(ReadInteger);}
    Target := ReadString;
    Caption := ReadString;
    {IconFile := ReadString;
    IconIndex := ReadInteger;}
    Params := ReadString;
{    WorkingFolder := ReadString;
    ShowMode := ReadInteger;}
    UseDocFolder := ReadBoolean;
  end;
  EndUpdate;
end;

procedure TSystemReference.SaveToStream(s: TStreamer);
begin
  with s do
  begin
    WriteInteger(FLeft);
    WriteInteger(FTop);
{    WriteInteger(Integer(Kind));}
    WriteString(Target);
    WriteString(Caption);
{    WriteString(IconFile);
    WriteInteger(IconIndex);}
    WriteString(Params);
{    WriteString(WorkingFolder);
    WriteInteger(ShowMode);}
    WriteBoolean(UseDocFolder);
  end;
end;

procedure TSystemReference.LoadFromIni(ini: TIniFile; const section: string);
var
 s: string;
begin
  BeginUpdate;
  with ini do
  begin
    {Kind := TReferenceKind(ReadInteger(section, 'Kind', 0));}
    s := ReadString(section, 'Target', 'c:\');
    if (FFileExists(s)) or (FDirectoryExists(s)) then
     Target := GetLongName(s)
    else
     Target := s;
    Caption := ReadString(section, 'Caption', 'Drive C:');
    {IconFile := ReadString(section, 'IconFile', '');
    IconIndex := ReadInteger(section, 'IconIndex', 0);}
    Params := ReadString(section, 'Params', '');
{    s := ReadString(section, 'WorkingFolder', '');
    if (FDirectoryExists(s)) then
     WorkingFolder := GetLongName(s)
    else
     WorkingFolder := s;
    ShowMode := ReadInteger(section, 'ShowMode', 0);}
    UseDocFolder := ReadBool(section, 'UseDocFolder', True);
 end;
 EndUpdate;
end;

procedure TSystemReference.SaveToIni(ini: TIniFile; const section: string);
begin
  with ini do begin
    {WriteInteger(section, 'Kind', Integer(Kind));}
    if FFileExists(Target) or FDirectoryExists(target) then
     WriteString(section, 'Target', GetShortName(Target))
    else
     WriteString(section, 'Target', Target);
    WriteString(section, 'Caption', Caption);
{    WriteString(section, 'IconFile', IconFile);
    WriteInteger(section, 'IconIndex', IconIndex);}
    WriteString(section, 'Params', Params);
{    if FDirectoryExists(WorkingFolder) then
     WriteString(section, 'WorkingFolder', GetShortName(WorkingFolder))
    else
     WriteString(section, 'WorkingFolder', WorkingFolder);
    WriteInteger(section, 'ShowMode', ShowMode);}
    WriteBool(section, 'UseDocFolder', UseDocFolder);
  end;
end;

function TSystemReference.AssignFromExternal: Boolean;
var
  location, url: string;
begin
  if (Kind = rkInternet) and
    Computer.BrowserLink.CaptureLocation(location, url) then
    begin
      Caption := location;
      Target := url;
    end
  else if ClipBoard.HasFormat(CF_TEXT) then
    Target := LowerCase(Clipboard.AsText)
  else Target := '';
  case Kind of
    rkDrive   : Result := IsDriveString(Target);
    rkFolder  : Result := HDirectoryExists(Target);
    rkFile    : Result := FileExists(Target);
    rkInternet: Result := IsURL(Target);
  end;
  if not Result then Target := '';
  Result := (Edit = mrOK) and ((Kind <> rkFolder) or
    (HDirectoryExists(Target) or (ConfirmFolder(Target) <> mrCancel)));
end;

{procedure DoneReference; far;
begin
  DriveRef.Free;
  FolderRef.Free;
  FileRef.Free;
end;          }

{initialization
  DriveRef := TSystemReference.Create;
  DriveRef.Kind := rkDrive;
  FolderRef := TSystemReference.Create;
  FolderRef.Kind := rkFolder;
  FileRef := TSystemReference.Create;
  FileRef.Kind := rkFile;
  AddExitProc(DoneReference);}
end.

