{**************************************************************************}
{                                                                          }
{    Calmira Reborn shell for Microsoft(R) Windows(TM) 3.1                 }
{    Version 5.0                                                           }
{    Copyright (C) 2022-2023 Hunter Turcin                                      }
{    Copyright (C) 2004-2007 Alexandre Rodrigues de Sousa                  }
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

unit FileMan;

{ FileMan contains the main file management engine used for processing
  files and directories.  It provides high-level operations which can
  be used easily from other units, while allowing full user interaction
  and error handling.

  Application.ProcessMessages is called frequently so that the progress
  bar can be updated and the user can press the Cancel button.

  Almost all of Calmira's filename strings are stored and processed
  as lower case to be consistent, especially useful because there is no
  case insensitive Pos() function.  Also, all filenames should be fully
  qualified to avoid ambiguities. }

interface

uses Classes, SysUtils, Forms, Dialogs, WinTypes, lfnutils;

type
  EFileOpError = class(Exception);

const
  faProtected = faReadOnly or faHidden or faSysFile;
  faFileDir = faAnyFile and not faVolumeID;

procedure YesToAll;
procedure NoToAll;
function CopyFile(const Filename, Destname: TLfnFilename): Boolean;
function MoveFile(const Filename, Destname: TLFnFilename; attr: Integer): Boolean;
function CopyDirectory(const Dirname, Destname: TLfnFilename): Boolean;
function MoveDirectory(const Dirname, Destname: TLfnFilename): Boolean;
function DeleteDirectory(const Dirname: TLfnFilename): Boolean;
function EraseFile(const Filename: string; attr: Integer): Boolean;
procedure CreateDirectory(const Dirname: TLfnFilename);
procedure RemoveDirectory(const Dirname: TLfnFilename);
procedure ProcessFiles(files: TStrings; const dest: TLfnFilename);
procedure ExitDirectory(const Dirname: TLfnFilename);
procedure OpenURL(const url: string);
function DefaultExec(FileName, Params, DefaultDir: string;
  ShowCmd: Word): Integer;
{ Encapsulates ShellExecute.  If a filename with no associated
  program is encountered, the default viewer is used to open the file.
  Also, DOS environment strings are inserted into each string before
  they are passed to Windows }
function DefaultExecCommand(Command, DefaultDir: string; ShowCmd: Word): Integer;
procedure OpenFileWith(const filename: TLfnFilename; command : string);
function ExtensionIn(const ext: string; const list: string): Boolean;
{ Searches a string containing file extensions separated by
  spaces.  It is case sensitive. }
function ConfirmFolder(const s: string): TModalResult;
function IsPrintManager(Wnd: HWND): Boolean;
procedure PrintFile(const filename : TLfnFilename);
procedure BackgroundProcess;

var
  BytesTransferred: Longint;

implementation

uses Controls, WinProcs, Settings, Desk, AskDrop, Progress, Files,
  Strings, MiscUtil, Drives, Environs, CompSys, Replace, Internet,
  FourDOS, Locale, IniFiles, Registry;

var
  CopyAllFiles  : Boolean;
  MoveAllFiles  : Boolean;
  DelAllFiles   : Boolean;
  RepAllFiles   : Boolean;
  MoveAllProt   : Boolean;
  DelAllProt    : Boolean;
  CopyAllFolders: Boolean;
  MoveAllFolders: Boolean;
  DelAllFolders : Boolean;

procedure NoToAll;
begin
  CopyAllFiles  := False;
  MoveAllFiles  := False;
  DelAllFiles   := False;
  RepAllFiles   := False;
  MoveAllProt   := False;
  DelAllProt    := False;
  CopyAllFolders:= False;
  MoveAllFolders:= False;
  DelAllFolders := False;
end;

procedure YesToAll;
begin
  CopyAllFiles  := True;
  MoveAllFiles  := True;
  DelAllFiles   := True;
  RepAllFiles   := True;
  MoveAllProt   := True;
  DelAllProt    := True;
  CopyAllFolders:= True;
  MoveAllFolders:= True;
  DelAllFolders := True;
end;

function CanReplace(Filename, Destname: TLfnFilename): Boolean;
begin
  { Returns True if the user specifies that the destination file
    (which must exist) can be replaced. }
  if ReplaceBox = nil then ReplaceBox := TReplaceBox.Create(Application);
  case ReplaceBox.Query(Filename, Destname) of
    mrYes   : Result := True;
    mrAll   : begin
                RepAllFiles := True;
                Result := True;
              end;
    mrNo    : begin
                ProgressBox.UpdateGauge;
                Result := False;
              end;
    mrCancel: Abort;
  end;
end;

function ProtectBox(const name, op: string): Word;
begin
  { Asks the user for confirmation before deleting or moving
    a protected file }
  Desktop.SetCursor(crDefault);
  try
    Result := MsgDialogResFmt(SQueryAffectProtected, [name, op],
      mtConfirmation, [mbYes, mbNo, mbCancel, mbAll], 0);
  finally
    Desktop.ReleaseCursor;
  end;
end;

function ConfirmSingleOperation(Ask: Boolean; var All: Boolean;
  const prompt, filename: string): Boolean;
begin
  Result := True;
  if Ask and not All then
  begin
    Desktop.SetCursor(crDefault);
    try
      case MsgDialog(Format('%s %s ?', [prompt, filename]), mtConfirmation,
        [mbYes, mbNo, mbCancel, mbAll], 0) of
          mrNo    : Result := False;
          mrCancel: Abort;
          mrAll   : All := True;
      end;
    finally
      Desktop.ReleaseCursor;
    end;
  end;
end;

function CopyFile(const Filename, Destname: TLfnFilename): Boolean;
begin
  Result := False;
  ProgressBox.CheckForAbort;
  ProgressBox.UpdateLabel(Filename, Destname);
  if not ConfirmSingleOperation(ConfirmCopyFile, CopyAllFiles,
    LoadStr(SCopyFile), Filename) then Exit;
  if Filename = Destname then
    raise EFileOpError.CreateResFmt(SCannotCopyFileToSelf, [Filename]);
  if ConfirmReplace and not RepAllFiles and FFileExists(Destname)
    and not CanReplace(Filename, Destname) then Exit;
  Application.ProcessMessages;
  try
    { low-level copy in Files.pas }
    FileCopy(Filename, Destname);
    ProgressBox.UpdateGauge;
  except
    on EWriteAccessDenied do
    { try removing protection bits }
    if FileSetAttr(Destname, 0) < 0 then raise
    else
    begin
      { attempt the copy again }
      FileCopy(Filename, Destname);
      ProgressBox.UpdateGauge;
    end;
  end;
  Result := True;
end;

function MoveFile(const Filename, Destname: TLfnFilename; attr: Integer): Boolean;
begin
  Result := False;
  ProgressBox.CheckForAbort;
  ProgressBox.UpdateLabel(Filename, Destname);
  if not ConfirmSingleOperation(ConfirmMoveFile, MoveAllFiles,
    LoadStr(SMoveFile), Filename) then Exit;
  if Filename = Destname then
    raise EFileOpError.CreateResFmt(SCannotMoveFileToSelf, [Filename]);
  if attr < 0 then attr := LFileGetAttr(Filename);
  { Check for read-only, hidden or system file }
  if (attr and faProtected > 0) and ConfirmProtect and not MoveAllProt then
    case ProtectBox(Filename, LoadStr(SMove)) of
      mrNo    : begin
                  ProgressBox.UpdateGauge;
                  exit;
                end;
      mrCancel: Abort;
      mrAll   : MoveAllProt := True;
    end;
  { If destination already exists, ask before replacing it.  If the
    user says "yes", try deleting it so that the move can be performed
    by a rename operation.  If the first delete fails, reset the attributes
    and try again }
  if FFileExists(Destname) then
    if not ConfirmReplace or RepAllFiles or CanReplace(Filename, Destname) then
    begin
      if not LDeleteFile(Destname) then
        if (LFileSetAttr(Destname, 0) < 0) or not LDeleteFile(Destname) then
          raise EFileOpError.CreateResFmt(SCannotReplaceFile, [Destname])
    end
    else Exit;
  Application.ProcessMessages;
  { Files on the same drive are moved using a rename.  Those on
    different drives are copied, and the original is deleted afterwards. }
  if (UpCase(Filename[1]) <> UpCase(Destname[1])) or
    not LRenameFile(Filename, Destname) then
    begin
    FileCopy(Filename, Destname);
    { first make sure the file can have read-write access }
    if (attr and faReadOnly > 0) and (FileSetAttr(Filename, 0) < 0) then
      raise EFileOpError.CreateResFmt(SCannotMoveFile, [Filename]);
    if not LDeleteFile(Filename) then
      raise EFileOpError.CreateResFmt(SCannotMoveFile, [Filename]);
  end;
  ProgressBox.UpdateGauge;
  Result := True;
end;

procedure CreateDirectory(const Dirname: TLfnFilename);
begin
  if not CreateDir(Dirname) then
    ErrorMsgResFmt(SCannotCreateFolder, [Dirname]);
end;

procedure CreateDirectoryMerge(const Dirname: TLfnFilename);
begin
  { Similar to CreateDirectory, but used when copying or moving
    whole directory structures.  If the destination already exists,
    then the contents will be merged, in which case any window showing
    the destination must be refreshed afterwards }
  if not FDirectoryExists(Dirname) then CreateDirectory(Dirname)
  else Desktop.RefreshList.Add(Dirname);
end;

procedure ExitDirectory(const Dirname: TLfnFilename);
const
  NewDir: string[3] = 'c:\';
var
  current: TFilename;
begin
  { If the current directory is somewhere inside Dirname,
    the directory is changed to the root directory.  This is required
    because directories cannot be deleted or renamed while they are active. }
  LGetDir(DriveNumber(Dirname[1]), current);
  current := Lowercase(current);
  if (current = Dirname) or IsAncestorDir(Dirname, current) then
  begin
    NewDir[1] := Dirname[1];
    ChDir(NewDir);
  end;
end;

procedure RemoveDirectory(const Dirname: TLfnFilename);
begin
  { Errors are ignored here because the user may choose not to
    delete a specific file during a directory-delete, in which case
    the parent dir can't be removed.  We want to prevent the entire
    operation from being aborted due to this. }
  ExitDirectory(Dirname);
  RemoveDir(Dirname);
end;

function CopyDirectory(const Dirname, Destname: TLfnFilename): Boolean;
var
  source, target: TLfnFileName;
  code: Integer;
  rec: TLfnSearchRec;
begin
  { CopyDirectory recursively scans a directory structure and recreates
    the contents elsewhere.  Both CreateDirectoryMerge and CopyFile will
    raise exceptions on error, which terminates this procedure.

    We must check that Destname is not the same as, or a subdirectory of
    Dirname, otherwise you will cause an infinite recursion, which XCOPY
    calls a cyclic copy. }
  Result := False;
  ProgressBox.CheckForAbort;
  if (Dirname = Destname) or IsAncestorDir(Dirname, Destname) then
    raise EFileOpError.CreateRes(SCannotCyclicCopy);
  if not ConfirmSingleOperation(ConfirmCopyFolder, CopyAllFolders,
    LoadStr(SCopyFolder), Dirname) then Exit;
  CreateDirectoryMerge(Destname);
  code := LFindFirst(Dirname + '\*.*', faFileDir, rec);
  while code = 0 do
  begin
    if rec.name[1] <> '.' then
    begin
      rec.name := Lowercase(rec.name);
      source := Dirname + '\' + rec.name;
      target := Destname + '\' + rec.name;
      if UseDescriptions and (rec.name = DescriptionFile) and
        FFileExists(target) then
          MergeDescriptionFiles(Destname, Dirname)
      else
      begin
        if rec.attr and faDirectory <> 0 then
          Result := CopyDirectory(source, target)
        else
        begin
          CopyFile(source, target);
          Inc(BytesTransferred, rec.size);
        end;
      end;
    end;
    code := LFindNext(rec);
  end;
  LFindClose(rec); { 3.11 }
  Result := True;
end;

function MoveDirectory(const Dirname, Destname: TLfnFilename): Boolean;
var
  source, target: TLfnFilename;
  code: Integer;
  rec: TLfnSearchRec;
begin
  { The structure of this is very similar to CopyDirectory, and the
    same rules about cyclic copying applies }
  Result := False;
  ProgressBox.CheckForAbort;
  if (Dirname = Destname) or IsAncestorDir(Dirname, Destname) then
    raise EFileOpError.CreateRes(SCannotCyclicMove);
  if not ConfirmSingleOperation(ConfirmMoveFolder, MoveAllFolders,
    LoadStr(SMoveFolder), Dirname) then Exit;
  CreateDirectoryMerge(Destname);
  code := LFindFirst(Dirname + '\*.*', faFileDir, rec);
  while code = 0 do
  begin
    if rec.name[1] <> '.' then
    begin
      rec.name := Lowercase(rec.name);
      source := Dirname + '\' + rec.name;
      target := Destname + '\' + rec.name;
      if UseDescriptions and (rec.name = DescriptionFile) then
      begin
        MergeDescriptionFiles(Destname, Dirname);
        LFileSetAttr(source, 0);
        LDeleteFile(source);
      end
      else
      begin
        if rec.attr and faDirectory <> 0 then
          Result := MoveDirectory(source, target)
        else
        begin
          Result := MoveFile(source, target, rec.attr);
          Inc(BytesTransferred, rec.size);
        end;
      end;
    end;
    code := LFindNext(rec);
  end;
  LFindClose(rec); { 3.11 }
  RemoveDirectory(Dirname);
  Result := True;
end;

function DeleteDirectory(const Dirname: TLfnFilename): Boolean;
var
  target: TLfnFilename;
  code: Integer;
  rec: TLfnSearchRec;
begin
  Result := False;
  ProgressBox.CheckForAbort;
  if not ConfirmSingleOperation(ConfirmDelFolder, DelAllFolders,
    LoadStr(SDeleteFolder), Dirname) then Exit;
  code := LFindFirst(Dirname + '\*.*', faFileDir, rec);
  while code = 0 do
  begin
    if rec.name[1] <> '.' then
    begin
      target := Dirname + '\' + Lowercase(rec.name);
      if rec.attr and faDirectory <> 0 then Result := DeleteDirectory(target)
      else EraseFile(target, rec.attr);
    end;
    code := LFindNext(rec);
  end;
  LFindClose(rec); { 3.11 }
  RemoveDirectory(Dirname);
  Result := True;
end;

function EraseFile(const Filename: string; attr: Integer): Boolean;
begin
  Result := False;
  ProgressBox.CheckForAbort;
  if not ConfirmSingleOperation(ConfirmDelFile, DelAllFiles,
    LoadStr(SDeleteFile), Filename) then Exit;
  if attr = -1 then attr := LFileGetAttr(Filename);
  if attr and faProtected <> 0 then
    if ConfirmProtect and not DelAllProt then
      case ProtectBox(Filename, LoadStr(SDelete)) of
        mrYes    : LFileSetAttr(Filename, 0);
        mrNo     : begin
                     ProgressBox.UpdateGauge;
                     Exit;
                   end;
        mrCancel : Abort;
        mrAll    : begin
                     DelAllProt := True;
                     LFileSetAttr(Filename, 0);
                   end;
      end
    else LFileSetAttr(Filename, 0);
  if not LDeleteFile(Filename) then
    raise EFileOpError.CreateResFmt(SCannotDeleteFile, [Filename]);
  ProgressBox.UpdateGauge;
  Result := True;
end;

procedure ProcessFiles(files: TStrings; const dest: TLfnFilename);
var
  CopyDroppedFiles: Boolean;
  destpath: TLfnFilename;
  i: Integer;
begin
  { Mainly used to handle file drops from other programs.  A list of
    filenames will be copied or moved after asking the user, and all
    affected windows are refreshed.

    Note that file descriptions are NOT preserved. }
  i := 0;
  while i < files.Count do
    if not FFileExists(files[i]) then files.Delete(i)
    else inc(i);
  if files.Count = 0 then
    raise EFileOpError.CreateRes(SNoFilesFound);
  destpath := MakePath(dest);
  try
    AskDropBox := TAskDropBox.Create(Application);
    case AskDropBox.ShowModal of
      mrOK : CopyDroppedFiles := True;
      mrYes: CopyDroppedFiles := False;
      mrCancel: Abort;
    end
  finally
    FreeAndNil(AskDropBox);
  end;
  if CopyDroppedFiles then ProgressBox.Init(foCopy, files.Count)
  else ProgressBox.Init(foMove, files.Count);
  try
    NoToAll;
    for i := 0 to files.Count-1 do
    begin
      if CopyDroppedFiles then
        CopyFile(GetLongName(files[i]), destpath + ExtractFilename(files[i]))
      else
      begin
        MoveFile(GetLongName(files[i]), destpath + ExtractFilename(files[i]), -1);
        Desktop.RefreshList.Add(ExtractFileDir(GetLongName(files[i])));
      end;
    end;
    Desktop.RefreshList.Add(dest);
  finally
    ProgressBox.Hide;
    if not FileSysChangeOn { 3.2 } then Desktop.RefreshNow;
    PlaySound(Sounds.Values['NotifyCompletion']);
  end;
end;

procedure OpenURL(const url: string);
var
  command,s: string;
begin
  { 3.11 -- Execute the default browser, using DDE if loaded. }
  if Browser = '' then with Computer.BrowserLink do
  begin
    { reload ServiceApplication, just in case it has been changed }
    ReadServiceApplication;
    if IsBrowserLoaded then
    begin
      OpenURL(url);
      Exit;
    end
    else with TRegistry.Create do
    begin
      s := ReadString(ReadString('.htm') +
        '\shell\open\command');
      command := NextItem(s,Word('"'), DELIM_Whitespace);
      Free;
    end;
  end
  else command := Browser;
  if command > '' then
  begin                       
    command := GetShortName(command);
    AppendStr(command, ' ' + url);
    WinExec(StrPChar(command), SW_SHOWNORMAL);
  end;
end;

function DefaultExec(Filename, Params, DefaultDir: string;
  ShowCmd: Word): Integer;
var
  s: string;
begin
  if Filename = '' then Exit;
  Filename := EnvironSubst(Filename);
  { Substitute environment variables }
  Params := EnvironSubst(Params);
  DefaultDir := EnvironSubst(DefaultDir);
  {and then gets the program full path if it's in a directory in
   the PATH environment variable }
  filename := SearchProgPath(filename,EnvironSubst('%windir%\system')+';'+DefaultDir+';'+EnvironSubst('%PATH%'));
  filename := GetShortName(filename);
  if IsURL(filename) then
  begin
    OpenURL(filename);
    Exit;
  end;
  if LowerCase(ExtractFileExt(Filename)) = '.url' then
  begin
    { 3.1 -- Read the .url file and open the url contained within. }
    with TIniFile.Create(Filename) do
    begin
      s := ReadString('InternetShortcut', 'URL', '');
      Free;
    end;
    if s > '' then OpenURL(s);
    Exit;
  end;
  if EnableWinScripts and (CompareText(ExtractFileExt(Filename),
    WinScriptExtension) = 0) then
    begin
      Computer.ExecuteScript(Filename, False);
      Exit;
    end;
  Result := FileExecute('open', Filename, Params, GetShortName(DefaultDir), ShowCmd);
  { ShellExecute sometimes return error code 2 (file not found), for a
    file with no extension.  Code 31 means that no associated program
    exists. }
  if (Result = 31) or ((Result = 2) and FFileExists(Filename)) then
  begin
    if DefaultProg > ''  then
    begin
      Result := FileExecute('open', GetShortName(EnvironSubst(DefaultProg)),
        { 2.12 } params + ' ' + QualifiedFilename(Filename),
        DefaultDir, SW_SHOWNORMAL);
      if Result <= 32 then ErrorMsgRes(SCannotRunDefViewer)
    end
    else ErrorMsgRes(SFileNotAssociated);
  end
  else
  case Result of
    { 3.1 improved error reporting }
    0         : ErrorMsgRes(SCorruptEXE);
    2, 3      : ErrorMsgResFmt(SFileNotFound, [Filename]);
    5         : ErrorMsgRes(SSharingError);
    6         : ErrorMsgRes(SDLLFailed);
    8         : ErrorMsgRes(SAppOutOfMemory);
    10        : ErrorMsgRes(SIncorrectWinVer);
    11        : ErrorMsgRes(SInvalidExe);
    12, 13, 14: ErrorMsgRes(SNonWindowsApp);
    15        : ErrorMsgRes(SRealModeApp);
    16        : ErrorMsgRes(SSecondInstance);
    19        : ErrorMsgRes(SCompressedEXE);
    20        : ErrorMsgRes(SCorruptDLL);
    21        : ErrorMsgRes(SRequiresWin32);
  end;
end;

function DefaultExecCommand(Command, DefaultDir: string; ShowCmd: Word): Integer;
var
  i: Integer;
  params: string;
begin
  {params := '';}
  params := Command;
  Command := NextItem(params,Word('"'),DELIM_Whitespace);
  Result := DefaultExec(Command, params, DefaultDir, ShowCmd);
end;

procedure OpenFileWith(const filename: TLfnFilename; command: string);
var
  prog: TLfnFilename;
  s: string;
begin
  s := Command;
  prog := NextItem(s, Word('"'),DELIM_Whitespace);
  Environment.Values['filename'] := GetShortName(LExpandFileName(EnvironSubst(QualifiedFilename(filename))));
  command := s;
  s := EnvironSubst('%windir%\system')+';'+EnvironSubst('%path%');
  prog := EnvironSubst(prog);
  prog := SearchProgPath(prog,s);
  Strings.Replace(command, '%1', '%filename%');
  if Pos('%filename%', command) = 0 then AppendStr(command, ' %filename%');
  ShowHourGlass;
  if FileExecute('open', GetShortName(EnvironSubst(prog)), (EnvironSubst(command)),
    ExtractFileDir(GetShortName(filename)), SW_SHOWNORMAL) <= 32 then
      ErrorMsgResFmt(SCannotOpenFileWith, [filename, prog]);
  Environment.Values['filename'] := '';
end;

function ExtensionIn(const ext: string; const list: string): Boolean;
begin
  Result := Pos(' ' + ext + ' ', list) > 0;
end;

function ConfirmFolder(const s: string): TModalResult;
begin
  Result := mrYes;
  if not HDirectoryExists(s) then
  begin
    Result := MsgDialogResFmt(SConfirmNewFolder, [s],
      mtConfirmation, [mbYes, mbNo, mbCancel], 0);
    if Result = mrYes then
    begin
      ForceDirectories(s);
      Desktop.Refresh(ExtractFileDir(s));
    end;
  end;
end;

function IsPrintManager(Wnd: HWND): Boolean;
var
  filename: TLfnFilename;
begin
  filename[0] := Chr(GetModuleFilename(GetWindowWord(Wnd, GWW_HINSTANCE),
    @filename[1], 78));
  Result := CompareText(ExtractFilename(filename), 'printman.exe') = 0;
end;

procedure PrintFile(const filename: TLfnFilename);
begin
  FileExecute('print', GetShortName(filename), '', '', SW_SHOWNORMAL);
end;

procedure BackgroundProcess;
begin
  Application.ProcessMessages;
  Progressbox.CheckForAbort;
end;

end.

