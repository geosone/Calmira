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

unit Directry;

{ This unit provides the main file management objects: TDirectory,
  TDirItem, TFileItem, TFile and TFolder. }

interface

uses Classes, Graphics, SysUtils, Grids, Iconic, Shorts, Dialogs, Referenc,
  Settings, ObjList, WinTypes, FourDOS, LfnUtils;

type
  TDirectory = class;
  TDirItem   = class;
  TFileItem  = class;
  TFile      = class;
  TFolder    = class;

  { the 8.3 character name }
  TFileBody    = string;

  { indicates if an item should be left alone, deleted from the
    list or destroyed }
  TFileRelease = (frNone, frRemove, frFree);

  ERenameError = class(Exception);
  EAttribError = class(Exception);
  EScanError = class(Exception);

  { TDirectory is a list of file and folder objects, that encapsulates
    a DOS directory listing.

    Properties
      Path - the full pathname with trailing backslash
      Fullname - the full name without trailing backslash
      Size - the number of bytes of disk space used by its contents
      SortOrder - the way in which the contents are sorted
      Filter - the file specification passed to FindFirst()
      Mask - the Attr field passed to FindFirst()
      Changed - True if the contents have changed since last update
      Desc - string list containing file descriptions

    Events
      OnUpdate - occurs when a file operation has been completed, to
        notify the owning window to modify its controls and display

    Methods
      Create - allocates and initializes a new object, and calls
        Scan() to read in the contents of the directory it represents
      Destroy - frees the contents as well as the directory object
      Add - adds a TDirItem to the list
      Remove - deletes a TDirItem from the list
      Sort - sorts the contents depending on the SortOrder property
      Update - writes file descriptions to disk, triggers the OnUpdate
        event and sets the Changed property to False
      Find - searches for the index of a given filename, and returns
        true if found
      AddItem - given a TLfnSearchrec, constructs a suitable object to
        represent the file or folder and adds it to the list
      Flush - removes or frees file items with a flag that is frRemove
        or frFree, and calls Update if required
      CreateFolder - creates a subdirectory and adds a new TFolder
        object to itself }

  TDirectory = class(TObjectList)
  private
    FPath: TLfnFileName;
    FSortOrder: TSortOrder;
    FFilter: PString;
    FMask: Integer;
    FOnUpdate: TNotifyEvent;
    FChanged: Boolean;
    FDesc: TDescriptions;
    FColumns: TFileDetails;
    function GetSize: Longint;
    function GetFullName: TLfnFileName;
    function GetFilter: string;
    procedure SetFilter(const Value: string);
  protected
    function ItemIndex(Item: TDirItem): Integer;
  public
    constructor Create(const APath: TLfnFileName);
    destructor Destroy; override;
    function Add(Item: TDirItem): Integer;
    function Remove(Item: TDirItem): Integer;
    function Find(const s:string; var Index: Integer): Boolean;
    procedure AddItem(const rec: TLfnSearchrec);
    procedure CreateFolder(const foldername: TLfnFileName);
    procedure Scan;
    procedure Sort;
    procedure Update;
    procedure Flush;
    property Path: TLfnFileName read FPath write FPath;
    property Fullname: TLfnFileName read GetFullname;
    property Size: Longint read GetSize;
    property SortOrder: TSortOrder read FSortOrder write FSortOrder;
    property Filter: string read GetFilter write SetFilter;
    property Mask: Integer read FMask write FMask;
    property OnUpdate: TNotifyEvent read FOnUpdate write FOnUpdate;
    property Changed: Boolean read FChanged write FChanged;
    property Desc: TDescriptions read FDesc;
    property Columns: TFileDetails read FColumns write FColumns;
  end;

  { TDirItem is a versatile abstract object that gives a lot of functionality
    to its descendants.  It encapsulates a single item in a directory listing,
    such as a file or folder, and handles many functions common to both.

    Properties
      Dir - a pointer to the owning directory object
      Filename - the 8.3 character MS-DOS filename
      Extension - optional 3 character extension
      Attr - MS-DOS file attributes consisting of faXXX constants
      TimeStamp - the DOS date/time stamp converted to a TDateTime format
      Size - size in bytes
      Fullname - full pathname (e.g. c:\abc\def\123.txt)
      Release - determines whether this item should be removed from the
        directory or destroyed when the directory is next updated
      Hint - the popup hint string, which depends on the current
        user preferences
      HasDesc - True if the item has a file description

    Methods
      Create - initializes a new item with details obtained from DOS
      SetFileName (protected) - dangerous, this one!  Turns Filename into
        a 'virtual' property.
      GetSearchRec - returns a TSearchRec containing the item's DOS details.
      Draw - paints the item's icon and caption onto a canvas
      DrawAsList - draws a row of a directory listing
      GetTitle - returns the DOS filenme or file description, depending
        on the current user settings and presence of description
      GetStartInfo - returns a string structure suitable for adding into
        the start menu
      AssignRef - modifies the fields of a TReference object so that it
        points to the TDirItem.  Used for making shortcuts and aliases.
      EditDescription - prompts the user for a new file description and
        returns true if the operation is successful
      AcceptsDrops - returns True if the user can drag and drop other
        objects into this one
      DragDrop - called when something has been dropped into the object
      LessThan - returns True if this item should be listed before the
        item passed as parameter.  User in sorting/searching.

      File management methods - at present, these make sure that file
      descriptions are kept updated, but could be extended to provide other
      housekeeping code.

      TDirItem's methods are usually overriden and the inherited method
      called immediately after a successful disk operation -- the parent
      and target TDirectory objects must not be changed before calling
      these methods.

      Delete - deletes an object
      CopyToDirectory - copies an object to another TDirectory
      CopyToPath - copies the object to a disk directory with no
        corresponding TDirectory object
      MoveToDirectory - moves an object to another TDirectory
      MoveToPath - moves the object to a disk directory with no
        corresponding TDirectory object
      MoveAndRename - similar to MoveToPath, but also changes the filename.
        Used to put things in the bin }

  TDirItem = class(TIconic)
  private
    FName: TFileBody;
    FAttr: Integer;
    FTimeStamp: TDateTime;
    FSize: Longint;
    FDir: TDirectory;
    FRelease: TFileRelease;
    FHasDesc: Boolean;
    function GetHint: string; virtual;
    function GetFullName: TLfnFileName;
    function GetExtension: TLfnFileExt;
    procedure SetFileAttr(attrib: Integer);
    function GetDescription: string;
    procedure PutDescription(const value: string);
  protected
    procedure SetFileName(const AName: TFileBody); virtual;
  public
    constructor Create(const details: TLfnSearchrec; ADir: TDirectory);
    function GetFmtFileName: TFileBody;
    procedure Draw(Canvas: TCanvas; const Rect: TRect;
      const State: TGridDrawState); override;
    procedure DrawAsList(Canvas: TCanvas; const Rect: TRect;
      const State: TGridDrawState); virtual;
    procedure DrawSmall(Canvas: TCanvas; const Rect: TRect;
      const State: TGridDrawState); virtual;
    procedure DrawSmallIcon(Canvas: TCanvas; const Rect: TRect); virtual; abstract;
    procedure Delete; virtual;
    procedure CopyToDirectory(d: TDirectory); virtual;
    procedure CopyToPath(const p: TLfnFileName); virtual;
    procedure MoveToDirectory(d: TDirectory); virtual;
    procedure MoveToPath(const p: TLfnFileName); virtual;
    procedure MoveAndRename(const NewName: TLfnFileName); virtual;
    function EditDescription: Boolean;
    function LessThan(f: TDirItem): Boolean; virtual;
    function AcceptsDrops: Boolean; virtual; abstract;
    procedure AssignRef(ref: TReference); override;
    procedure DragDrop(Source: TObject); virtual; abstract;
    function GetTitle: string; virtual;
    function GetStartInfo: string; virtual; abstract;
    function GetSearchRec: TLfnSearchrec;
    property Filename: TFileBody read FName write SetFileName;
    property Attr: Integer read FAttr write SetFileAttr;
    property TimeStamp: TDateTime read FTimeStamp;
    property Size: Longint read FSize;
    property FullName: TLfnFileName read GetFullName;
    property Extension: TLfnFileExt read GetExtension;
    property Dir: TDirectory read FDir;
    property Release: TFileRelease read FRelease write FRelease;
    property Hint: string read GetHint;
    property Description: string read GetDescription write PutDescription;
  end;

  { TFileItem is an abstract base class that encapsulates a single file.
    As well as overriding many of TDirItem's methods so that they manage
    files, new methods are introduced that work only on files.
    This abstract class is provided so that descendants such as TAlias
    can represent different kinds of file, but still have basic file
    operations carried out on them. }

  TFileItem = class(TDirItem)
  protected
    FIsProgram: Boolean;
  public
    procedure DrawSmallIcon(Canvas: TCanvas; const Rect: TRect); override;
    procedure Open; override;
    procedure Delete; override;
    procedure CopyToDirectory(d: TDirectory); override;
    procedure CopyToPath(const p: TLfnFileName); override;
    procedure MoveToDirectory(d: TDirectory); override;
    procedure MoveToPath(const p: TLfnFileName); override;
    procedure MoveAndRename(const NewName: TLfnFileName); override;
    procedure Duplicate(const AName: TLfnFileName); virtual;
    function LessThan(f: TDirItem): Boolean; override;
  end;

  { TFile is the usual class that is instantiated to represent a
    disk file.  It keeps track of whether it extracted an icon
    to display itself, and if so, the icon is freed along with the
    object }

  TFile = class(TFileItem)
  private
    FOwnIcon: Boolean;
  protected
    procedure AssignIcon; virtual;
    procedure FreeIcon; virtual;
    procedure SetFileName(const AName: TFileBody); override;
    property OwnIcon: Boolean read FOwnIcon write FOwnIcon;
  public
    constructor Create(const details: TLfnSearchrec; ADir: TDirectory);
    destructor Destroy; override;
    function AcceptsDrops: Boolean; override;
    procedure DragDrop(Source: TObject); override;
    procedure AssignRef(ref: TReference); override;
    function GetStartInfo: string; override;
  end;

  { TFolder encapsulates a subdirectory.  It overrides numerous methods
    of TDirItem to handle directories, and introduces CheckPath to
    verify that the folder can be put into a destination folder }

  TFolder = class(TDirItem)
  private
    FOwnIcon: Boolean;
    procedure CheckPath(const p: TLfnFileName);
  protected
    procedure AssignIcon;
    procedure FreeIcon; virtual;
    procedure SetFileName(const AName: TFileBody); override;
    function GetHint: string;override;
  public
    constructor Create(const details: TLfnSearchRec; ADir: TDirectory);
    destructor Destroy; override;
    procedure DrawSmallIcon(Canvas: TCanvas; const Rect: TRect); override;
    procedure Open; override;
    procedure Delete; override;
    procedure CopyToDirectory(d: TDirectory); override;
    procedure CopyToPath(const p: TLfnFileName); override;
    procedure MoveToDirectory(d: TDirectory); override;
    procedure MoveToPath(const p: TLfnFileName); override;
    procedure MoveAndRename(const NewName: TLfnFileName); override;
    function LessThan(f: TDirItem): Boolean; override;
    procedure AssignRef(ref: TReference); override;
    function AcceptsDrops: Boolean; override;
    procedure DragDrop(Source: TObject); override;
    function GetStartInfo: string; override;
  end;

  { TFileList is a simple container for TDirItem objects.  It is
    used to hold items during processing, and accumulates information
    about the items as they are added.  This information is available
    trought the integer properties.  The DeepScan flag determines
    whether sub-folders are searched when a folder is added to the list }

  TFileList = class(TList)
  private
    FFileSize: Longint;
    FFileCount: Integer;
    FFolderCount: Integer;
    FItemCount: Integer;
    FDeepScan: Boolean;
  public
    constructor Create;
    procedure Clear;
    function Add(Item: Pointer): Integer;
    property FileSize: Longint read FFileSize;
    property FileCount: Integer read FFileCount;
    property FolderCount: Integer read FFolderCount;
    property ItemCount: Integer read FItemCount write FItemCount;
    property DeepScan: Boolean read FDeepScan write FDeepScan;
  end;

const
  faHidSys = faHidden or faSysFile;
  DirectoryMasks: array[Boolean] of Word =
    (faDirectory, faDirectory or faHidden or faSysFile);

implementation

uses ShellAPI, Forms, Controls, Progress, Resource, FileMan, WinProcs,
  Streamer, Desk, Files, IniFiles, Strings, MiscUtil, Alias, IconWin, Start,
  Locale, Embed, CompSys;

var
  ResizeBitmap: Graphics.TBitmap;

{ TDirectory }

constructor TDirectory.Create(const APath: TLfnFileName);
begin
  { initialize fields and scan directory }
  inherited Create;
  FDesc := TDescriptions.Create;
  FMask := DirectoryMasks[ShowHidSys];
  Path := APath;
  FSortOrder := DefaultSort;
  FOnUpdate := nil;
  FChanged := False;
  FFilter := NullStr;
  FColumns := DefaultColumns;
  Filter := DefaultFilter;
end;

destructor TDirectory.Destroy;
begin
  FDesc.Free;
  DisposeStr(FFilter);
  inherited Destroy;
end;

function TDirectory.GetFilter: string;
begin
  Result := FFilter^;
end;

procedure TDirectory.SetFilter(const Value: string);
begin
  AssignStr(FFilter, Value);
end;

function TDirectory.Add(Item: TDirItem): Integer;
begin
  { inserts the item in sorted order }
  Result := ItemIndex(Item);
  Insert(Result, Item);
  FChanged := True;
end;

function TDirectory.Remove(Item: TDirItem): Integer;
begin
  Result := inherited Remove(Item);
  FChanged := True;
end;

function TDirectory.ItemIndex(Item: TDirItem): Integer;
var
  left, right, mid : Integer;
begin
  { Ordinary binary chop algorithm using the LessThan method
    as comparator.  Returns the index where the item should be placed. }
  left := 0;
  right := Count;
  while left < right do
  begin
    mid := (left + right) shr 1;
    if TDirItem(List^[mid]).LessThan(Item)
    then left := mid + 1
    else right := mid;
  end;
  Result := left;
end;

function TDirectory.Find(const s: string; var Index: Integer): Boolean;
var
  i: Integer;
begin
  { This must use a linear search because only the filename
    is provided as parameter and the directory list can be sorted in
    many ways }
  for i := 0 to Count - 1 do
    if TDirItem(List^[i]).Filename = s then
    begin
      Index := i;
      Result := True;
      Exit;
    end;
  Result := False;
end;

{ AddItem creates a new TDirItem descendant and adds it to the directory
  list.  '.' and '..' entries are discarded, and files with an extension
  of ALS are assumed to be an alias, and the file is opened to check
  the signature.  If no signature is found, a normal TFile is created
  which is guaranteed to load. }

procedure TDirectory.AddItem(const rec: TLfnSearchrec);
var
  f: TDirItem;
  s: TStreamer;
  sig: string[7];
begin
  if rec.name[1] = '.' then Exit;
  if rec.attr and faDirectory <> 0 then
    f := TFolder.Create(rec, self)
  else if ExtractFileExt(rec.name) = AliasExtensionUpper then
    try
      s := TStreamer.Create(GetShortName(Path + rec.name), fmOpenRead);
      sig := s.ReadString;
      if (Length(sig) >= 4) and (PLongint(@sig[1])^ = AliasSigValue) then
        f := TAlias.Create(rec, self, s)
      else f := TFile.Create(rec, self);
    finally
      s.Free;
    end
  else f := TFile.Create(rec, self);
  Add(f);
end;

{ The 4DOS descript.ion file is loaded before searching the directory
  so that TDirItems can check for a description while they are initializing.
  A slight problem occurs when there is no disk in the drive -- FindFirst
  returns -3 fairly quickly when searching for *.*, but searching for
  'descript.ion' seems to make some machines hang until a disk is inserted. }

procedure TDirectory.Scan;
var
  rec: TLfnSearchRec;
  code, dummy: Integer;
  m: Word;
  specs,filter: TLfnFileName;
begin
  UpdateScreen;
  Desktop.SetCursor(crHourGlass);
  try
    ClearObjects;
    FDesc.Clear;
    if UseDescriptions then FDesc.LoadFromPath(Path);
    specs := FFilter^;
    m := Mask;
    if(m and faDirectory)<>0 then
      begin
      code := LFindFirst(Path+'*.*', m, rec);
      if code = -3 then
        raise EScanError.CreateResFmt(SCannotOpenFolder, [Fullname]);
      while code = 0 do
      begin
        if ((rec.Attr and faDirectory)<>0) and (rec.Name<>'.') and (rec.Name<>'..') then
          AddItem(rec);
        if GetAsyncKeyState(VK_ESCAPE) < 0 then Break;
        code := LFindNext(rec);
      end;
      LFindClose(rec); { 3.11 }
      m := m and (not faDirectory);
      end;
    repeat
      filter := Path + GetWord(specs, ';');
      code := LFindFirst(filter, m, rec);
      if code = -3 then
        raise EScanError.CreateResFmt(SCannotOpenFolder, [Fullname]);
      while code = 0 do
      begin
        if (specs = '') or not Find(Lowercase(rec.Name), dummy) then
          AddItem(rec);
        if GetAsyncKeyState(VK_ESCAPE) < 0 then Break;
        code := LFindNext(rec);
      end;
      LFindClose(rec); { 3.11 }
    until specs = '';
  finally
    Desktop.ReleaseCursor;
  end;
end;

function TDirectory.GetSize: Longint;
var
  i: Integer;
begin
  { counts the bytes in the files }
  Result := 0;
  for i := 0 to Count - 1 do Inc(Result, TDirItem(List^[i]).Size);
end;

function TDirectory.GetFullname: TLfnFileName;
begin
  Result := Path;
  if Length(Result) > 3 then Dec(Result[0]);
end;

procedure TDirectory.CreateFolder(const foldername: TLfnFileName);
var
  dest: TLfnFileName;
  rec: TLfnSearchrec;
begin
  dest := Path + foldername;
  if FFileExists(dest) then
    raise EFileOpError.CreateResFmt(SFileAlreadyExists, [dest])
  else if FDirectoryExists(dest) then
    raise EFileOpError.CreateResFmt(SFolderAlreadyExists, [dest])
  else begin
    CreateDirectory(dest);
    LFindFirst(dest, faDirectory, rec);
    AddItem(rec);
    LFindClose(rec); { 3.11 }
    Update;
  end;
end;

{ The sorting is a simple insertion sort (utilising the binary comparison).
  rather than quicksort, since directories don't usually have more than a
  few hundred items.  A temporary TList is used to hold the contents while
  they are being inserted back into the TDirectory }

procedure TDirectory.Sort;
var
  temp: TList;
  i, n: Integer;
begin
  ShowHourGlass;
  temp := TList.Create;
  try
    n := Count;
    temp.Capacity := n;
    System.Move(List^, temp.List^, n * Sizeof(Pointer));
    { just clear the list, don't use ClearObjects! }
    Clear;
    for i := 0 to n - 1 do Add(temp.List^[i]);
  finally
    temp.Free;
  end;
end;

procedure TDirectory.Update;
begin
  if UseDescriptions then FDesc.SaveToPath(Path);
  if Assigned(FOnUpdate) then FOnUpdate(self);
  FChanged := False;
end;

{ Flush is called when a delete or move operation is complete.  It loops
  through the list, removing items with an frRemove flag and freeing
  those with an frFree flag.  The loop is in reverse because delete
  operations are faster if you delete from the end of a list.

  Although it sounds neater, the items cannot be removed or freed during
  the operation because the user might drag the progress box around.  This
  would expose parts of the icon window which would call the TDirItems
  to redraw themselves.  }

procedure TDirectory.Flush;
var
  i: Integer;
  item: TDirItem;
begin
  for i := Count - 1 downto 0 do
  begin
    item := TDirItem(List^[i]);
    case item.Release of
      frNone  : Continue;
      frRemove: TDirItem(List^[i]).Release := frNone;
      frFree  : TDirItem(List^[i]).Free;
    end;
    Delete(i);
    FChanged := True;
  end;
  if FChanged then Update;
end;

{ TDirItem }

constructor TDirItem.Create(const details: TLfnSearchrec; ADir: TDirectory);
begin
  inherited Create;
  with details do
  begin
    FName := {Lowercase(}name{)};
    FAttr := attr;
    FSize := size;
    FTimeStamp := TimestampToDate(time);
  end;
  FDir := ADir;
  FRelease := frNone;
  FHasDesc := UseDescriptions and (Dir.Desc.Get(Filename, self) > '');
end;

function TDirItem.GetFullName: TLfnFileName;
begin
  Result := Dir.Path + Filename;
end;

function TDirItem.GetExtension: TLfnFileExt;
begin
  Result := Copy(ExtractFileExt(Filename), 2, 3);
end;

procedure TDirItem.SetFileAttr(attrib: Integer);
begin
  if FAttr = attrib then Exit;
  if LFileSetAttr(Fullname, attrib) = 0 then FAttr := attrib
  else raise EAttribError.CreateResFmt(SCannotChangeAttr, [Fullname]);
end;

{ GetDescription makes use of the HasDesc flag to avoid performing a
  search when it is known that there is no description.  Consequently,
  Put must maintain this flag, and the description should not be set
  in any other way.

  4DOS specifies that a ^D placed in the description string indicates that
  everything following the marker is extra data used by third party programs.
  Calmira doesn't need to store extra data, but the original data must be
  maintained for compatibility. }

function TDirItem.GetDescription: string;
var
  p: Integer;
begin
  if FHasDesc then
  begin
    Result := Dir.Desc.Get(GetShortName(Filename), self);
    p := Pos(^D, Result);
    if p > 0 then Result[0] := Chr(p-1);
  end
  else Result := '';
end;

procedure TDirItem.PutDescription(const value: string);
var
  s: string;
  p: Integer;
begin
  s := Dir.Desc.Get(Filename, self);
  p := Pos(^D, s);
  if p > 0 then Dir.Desc.Put(GetShortName(filename), self, value + Copy(s, p + 1, 255))
  else Dir.Desc.Put(GetShortName(filename), self, value);
  FHasDesc := value > '';
end;

function TDirItem.GetFmtFileName: TFileBody;
var
  p: Integer;
begin
  Result := FName;
  if UpcaseFirstChar and (Result = AnsiUpperCase(Result)) then
   begin
   Result := AnsiLowerCase(Result);
   Result[1] := Upcase(Result[1]);
   end;
  if NoRegExtensions and (Icon <> FileIcon) and (Icon <> FolderIcon) then
  begin
    p := Pos('.', Result);
    if p > 0 then Result[0] := Chr(p - 1);
  end;
end;

procedure TDirItem.Draw(Canvas: TCanvas; const Rect: TRect;
  const State: TGridDrawState);
begin
  if UseDescriptions and DescCaptions then
    InternalDraw(Canvas, Rect, State, GetTitle)
  else InternalDraw(Canvas, Rect, State, GetFmtFileName);
end;

procedure TDirItem.DrawSmall(Canvas: TCanvas; const Rect: TRect;
  const State: TGridDrawState);
var
  s: string;
  r: TRect;
begin
  with Canvas do
  begin
    Brush.Color := Colors[ccIconBack];
    FillRect(Rect);
    DrawSmallIcon(Canvas, Rect);
    s := MinimizeString(GetFmtFileName, Canvas, NameColWidth - 4);
    r := Rect;
    Inc(r.Left, 20);
    r.Right := r.Left + TextWidth(s) + 4;
    if gdSelected in State then
    begin
      Brush.Color := Colors[ccIconSel];
      Fillrect(r);
    end;
    TextOut(Rect.Left + 22, Rect.Top + 1, s);
    if gdFocused in State then DrawFocusRect(r);
  end;
end;

procedure TDirItem.DrawAsList(Canvas: TCanvas; const Rect: TRect;
  const State: TGridDrawState);
var
  SizeStr, DateStr, TimeStr, AttrStr: string[15];
  TypeStr: string[63];
  s: string;
  r: TRect;
  w: Integer;
  Top, Left: Integer;
  Details: TFileDetails;
begin
  Details := Dir.Columns;
  with Canvas do
  begin
    Brush.Color := Colors[ccIconBack];
    FillRect(Rect);
    DrawSmallIcon(Canvas, Rect);
    Top := Rect.Top + 1;
    Left := Rect.Left + 22;
    s := MinimizeString(GetFmtFileName, Canvas, NameColWidth - ColumnPadding div 2);
    r := Rect;
    Inc(r.Left, 20);
    r.Right := r.Left + TextWidth(s) + 4;
    if gdSelected in State then
    begin
      Brush.Color := Colors[ccIconSel];
      Fillrect(r);
    end;
    TextOut(Left, Top, s);
    if gdFocused in State then DrawFocusRect(r);
    Brush.Color := Colors[ccIconBack];
    Font.Color := clWindowText;
    Inc(Left, NameColWidth);
    if fdSize in Details then
    begin
      if Self is TFolder then SizeStr := ''
      else SizeStr := FormatByte(Size, ListKBDecimals, ListMBDecimals);
      TextOut(Left + SizeColWidth - ColumnPadding - TextWidth(SizeStr), Top, SizeStr);
      Inc(Left, SizeColWidth);
    end;
    if fdType in Details then
    begin
      if Self is TAlias then TypeStr := LoadStr(SCAlias)
      else if Self is TFolder then TypeStr := LoadStr(SCFolder)
      else TypeStr := Icons.GetType(Copy(ExtractFileExt(Filename), 2, 3));
      TypeStr := MinimizeString(TypeStr, Canvas, TypeColWidth - ColumnPadding div 2);
      TextOut(Left, Top, TypeStr);
      Inc(Left, TypeColWidth);
    end;
    if (fdDate in Details) or (fdTime in Details) then
    begin
      { 3.2 fused date and time columns }
      if fdDate in Details then
      begin
        w := (TextWidth(SampleTime) + ColumnPadding) * Integer(fdTime in Details);
        DateTimeToString(DateStr, ShortDateFormat, TimeStamp);
        TextOut(Left + DateColWidth - ColumnPadding - TextWidth(DateStr) - w, Top, DateStr);
      end;
      if fdTime in Details then
      begin
        DateTimeToString(TimeStr, ShortTimeFormat, TimeStamp);
        TextOut(Left + DateColWidth - ColumnPadding - TextWidth(TimeStr), Top, TimeStr);
      end;
      Inc(Left, DateColWidth);
    end;
    if fdAttr in Details then
    begin
      { 3.1 right justified }
      AttrStr := AttrToStr(Attr);
      TextOut(Left + AttrColWidth - ColumnPadding - TextWidth(AttrStr), Top, AttrStr);
      Inc(Left, AttrColWidth);
    end;
    if (fdDesc in Details) and UseDescriptions then
      TextOut(Left, Top, Description);
  end;
end;

function TDirItem.GetTitle: string;
begin
  Result := Description;
  if Result = '' then Result := GetFmtFileName;
end;

{ The LessThan method is the main comparison function for sorting, and
  needs to work with the four orderings and handle descriptions when they
  are used as captions.  The main sort key (Type, Data, Size) is compared
  first and if they are equal, the captions are compared using the
  auxiliary function.  CompareText must be used because descriptions can
  be in upper and lower case }

function TDirItem.LessThan(f: TDirItem): Boolean;

function CaptionLessThan: Boolean;
begin
  if DescCaptions then Result := CompareText(GetTitle, f.GetTitle) < 0
  else Result := CompareText(Filename,f.Filename) < 0;
end;

var
  c: Integer;
begin
  case Dir.SortOrder of
    soName: Result := CaptionLessThan;
    soType: begin
              c := CompareText(Extension, f.Extension);
              Result := (c < 0) or ((c = 0) and CaptionLessThan)
            end;
    soSize: Result := (Size > f.Size) or
              ((Size = f.Size) and CaptionLessThan);
    soDate: Result := (TimeStamp > f.TimeStamp) or
              ((TimeStamp = f.TimeStamp) and CaptionLessThan);
  end;
end;

{ SeTLfnFileName is the property write method for the Filename property.
  It is virtual so descandants can override it to constrain the renaming.
  However, it is vital that overridden property access methods call
  "inherited SeTLfnFileName" rather than using the "inherited Filename"
  property, which would cause an infinite recursion and stack overflow }

procedure TDirItem.SetFileName(const AName: TFileBody);
var
  buf: string;
begin
  if AName <> FName then
  begin
    if not IsValidFilename(AName) then
      raise ERenameError.CreateResFmt(SInvalidFilename, [AName])
    else
    begin
      if LRenameFile(GetLongName(Dir.Path + FName), Dir.Path +  AName) then
      begin
        if UseDescriptions then
        begin
          buf := Description;
          Description := '';
        end;
        Dir.Remove(self);
        FName := AName;
        Dir.Add(self);
        if UseDescriptions then Description := buf;
      end
      else raise ERenameError.CreateResFmt(SCannotRename, [Fullname, AName]);
    end;
  end;
end;

function TDirItem.GetSearchRec: TLfnSearchrec;
begin
  Result.name := {UpperCase(}Filename{)};
  Result.attr := Attr;
  Result.size := Size;
  Result.time := DateTimeToFileDate(TimeStamp);
end;

procedure TDirItem.AssignRef(ref: TReference);
begin
  with Ref do
  begin
    Target := Fullname;
    Caption := GetTitle;
  end;
end;

{ The popup hints must show either the file description or the DOS
  filename, depending on the context.  The idea is that the user can
  use the hint to see information not displayed under the icon --
  if a description is shown as the icon caption, the hint shows the
  filename.  If the filename is the caption, a description is put
  in the hint, if one exists. }

function TDirItem.GetHint: string;

procedure AddField(const s: string);
begin
  if Result > '' then AppendStr(Result, #13);
  AppendStr(Result, s);
end;

begin
  Result := '';
  if UseDescriptions and HintDesc then
  begin
    Result := Description;
    if Result = '' then Result := SSNoDescription
    else if DescCaptions then Result := Filename;
  end;
  if HintType then
  begin
    if Self is TAlias then AddField(LoadStr(SCAlias))
    else if Self is TFolder then AddField(LoadStr(SCFolder))
    else AddField(Icons.GetType(Copy(ExtractFileExt(Filename), 2, 3)));
  end;
  if HintBytes and not (Self is TFolder) then AddField(LoadStr(SCSize)+': '+FormatByteLong(Size));
  if HintDate then AddField(LoadStr(SCModDate)+': '+DateToStr(TimeStamp));
  if HintTime then AddField(LoadStr(SCModTime)+': '+ShortTimeToStr(TimeStamp));
  if HintAttrib then AddField(LoadStr(SCAttributes)+': '+AttrToStr(Attr));
end;

procedure TDirItem.Delete;
begin
  FRelease := frFree;
  Dir.Desc.Put(Filename, nil, '');
end;

{ The following five methods are responsible for maintaining the consistency
  of file descriptions.  When a description is transferred, the destination
  object is not known, so nil is passed.

  Note that Dir.Desc.Get is used rather than the Description property.  This
  is because the Description property filters out data following a ^D marker,
  which we must keep. }

procedure TDirItem.MoveToDirectory(d: TDirectory);
begin
  FRelease := frRemove;
  if UseDescriptions then
  begin
    d.Desc.Put(Filename, nil, Dir.Desc.Get(Filename, self));
    Dir.Desc.Put(Filename, self, '');
  end;
end;

procedure TDirItem.MoveToPath(const p: TLfnFileName);
begin
  FRelease := frFree;
  if UseDescriptions then
  begin
    SharedDesc.Put(Filename, nil, Dir.Desc.Get(Filename, self));
    Dir.Desc.Put(Filename, self, '');
  end;
end;

procedure TDirItem.CopyToDirectory(d: TDirectory);
begin
  if UseDescriptions then
    d.Desc.Put(Filename, nil, Dir.Desc.Get(Filename, self));
end;

procedure TDirItem.CopyToPath(const p: TLfnFileName);
begin
  if UseDescriptions then
    SharedDesc.Put(Filename, nil, Dir.Desc.Get(Filename, self));
end;

procedure TDirItem.MoveAndRename(const NewName: TLfnFileName);
begin
  FRelease := frFree;
  if UseDescriptions then
    Dir.Desc.Put(Filename, nil, '');
end;

function TDirItem.EditDescription: Boolean;
var
  buf: string;
begin
  buf := Description;
  Result := InputQuery(LoadStr(SChangeDescription),
    FmtLoadStr(SDescribe, [Filename]), buf);
  if Result then Description := buf;
end;

{ TFileItem }

procedure TFileItem.CopyToPath(const p: TLfnFileName);
begin
  if CopyFile(Fullname, p + Filename) then
    inherited CopyToPath(p);
end;

procedure TFileItem.CopyToDirectory(d: TDirectory);
var
  i: Integer;
begin
  if CopyFile(Fullname, d.Path + Filename) then
  begin
    { replace any existing object with the same name }
    inherited CopyToDirectory(d);
    if d.Find(Filename, i) then TFileItem(d[i]).Release := frFree;
    d.AddItem(GetSearchRec);
  end;
end;

procedure TFileItem.MoveToDirectory(d: TDirectory);
var
  i: Integer;
begin
  if MoveFile(FullName, d.Path + Filename, Attr) then
  begin
    inherited MoveToDirectory(d);
    FDir := d;
    if d.Find(Filename, i) then TDirItem(d[i]).Release := frFree;
    d.Add(self);
  end;
end;

procedure TFileItem.MoveToPath(const p: TLfnFileName);
begin
  if MoveFile(FullName, p + Filename, Attr) then
    inherited MoveToPath(p);
end;

procedure TFileItem.MoveAndRename(const NewName: TLfnFileName);
begin
  if MoveFile(FullName, NewName, Attr) then
    inherited MoveAndRename(NewName);
end;

procedure TFileItem.Duplicate(const AName: TLfnFileName);
var
  rec: TLfnSearchrec;
  i: Integer;
begin
  if not IsValidFilename(AName) then
    raise EFileOpError.CreateResFmt(SInvalidFilename, [AName]);
  if CopyFile(Fullname, Dir.Path + AName) then
  begin
    rec := GetSearchRec;
    rec.Name := AName;
    with Dir do
    begin
      Desc.Put(AName, nil, Description);
      if Find(AName, i) then FreeObject(i);
      AddItem(rec);
      Update;
    end;
  end;
end;

function TFileItem.LessThan(f: TDirItem): Boolean;
begin
  { files are always placed after folders }
  Result := not (f is TFolder) and inherited LessThan(f);
end;

procedure TFileItem.DrawSmallIcon(Canvas: TCanvas; const Rect: TRect);
var
  SaveHQ: Boolean;
begin
  if MiniIcons and not((Icon = FileIcon) or (Icon = ProgIcon)) { 3.1 } then
  begin
    { 3.11 }
    SaveHQ := HQIconStretch;
    HQIconStretch := HQMiniIcons;
    ShrinkIcon(Icon.Handle, ResizeBitmap, Canvas.Brush.Color);
    HQIconStretch := SaveHQ;
    Canvas.Draw(Rect.Left + 2, Rect.Top, ResizeBitmap);
  end
  else if FIsProgram then
    Canvas.Draw(Rect.Left + 2, Rect.Top, TinyProg)
  else
    Canvas.Draw(Rect.Left + 2, Rect.Top, TinyFile)
end;

procedure TFileItem.Delete;
begin
  if EraseFile(Fullname, Attr) then inherited Delete;
end;

{ TFile }

constructor TFile.Create(const details: TLfnSearchrec; ADir: TDirectory);
begin
  inherited Create(details, ADir);
  AssignIcon;
end;

destructor TFile.Destroy;
begin
  FreeIcon;
  inherited Destroy;
end;

procedure TFile.FreeIcon;
begin
  if FOwnIcon then
  begin
    FreeAndNil(FIcon);
    FOwnIcon := False;
  end;
end;

procedure TFile.AssignIcon;
var
  h: HIcon;
  ext: TFileExt;
  filestr: TLfnFileName;
  fname: String;
begin
  OwnIcon := False;
  ext := Extension;
  FIsProgram := ExtensionIn(LowerCase(ext), LowerCase(programs));
  { Try and extract an icon if the file extension is in the list
    of icon file types, otherwise get a pointer to an icon from
    the resource store }
  if ExtensionIn(LowerCase(ext), LowerCase(IconStrings)) then with Icons do
  begin
    fname := GetShortName(Fullname);
    h := ExtractIcon(HInstance, StrPCopy(@filestr, fname), 0);
    case h of
      0: FIcon := FileIcon;
      1: FIcon := ProgIcon;
    else
      begin
        FIcon := TIcon.Create;
        FIcon.Handle := h;
        OwnIcon := True;
      end;
    end;
  end
  else
    FIcon := Icons.Get(ext);
  if FIsProgram and (FIcon = FileIcon) then
    FIcon := ProgIcon; { 3.1 }
end;

procedure TFileItem.Open;
begin
  DefaultExec(Fullname, '', Dir.Fullname, SW_SHOWNORMAL);
end;

procedure TFile.SetFileName(const AName: TFileBody);
begin
  { If the file's extension changes, it might need a different icon }
  FreeIcon;
  try
    inherited SetFileName(AName);
  finally
    AssignIcon;
  end;
end;

procedure TFile.AssignRef(ref: TReference);
begin
  with Ref do begin
    BeginUpdate;
    inherited AssignRef(ref);
    Kind := rkFile;
    EndUpdate;
  end;
end;

function TFile.AcceptsDrops: Boolean;
begin
  { the user can choose whether programs accept drops }
  Result := FIsProgram and ProgDrop;
end;

procedure TFile.DragDrop(Source: TObject);
begin
  FileRef.Target := Fullname;
  FileRef.DragDrop(Source);
end;

function TFile.GetStartInfo: string;
begin
  Result := PackStartInfo(Fullname, Dir.Fullname, '', 0, 0);
end;

{ TFolder }

function TFolder.GetHint: string;
var
 s: string;
 fini: TIniFile;
begin
Result := inherited GetHint;
if((LFileGetAttr(FullName) and(faReadOnly or faSysFile))<>0) then
 begin
 s:= FullName;
 if(s[Length(s)]<>'\') and (s[Length(s)]<>'/') then
  s := s +'\';
 s := s+'desktop.ini';
 if FFileExists(s) then
  begin
  fini := TIniFile.Create(GetShortName(s));
  s := fini.ReadString('.ShellClassInfo','InfoTip','');
  if TrimLeft(s)<>'' then
    Result := s;
  fini.Destroy;
  end;
 end;
end;

procedure TFolder.AssignIcon;
var
 h: HIcon;
 s: string;
 _s: array [0..MAX_PATH] of Char;
 i: integer;
 fini: TIniFile;

procedure AssignDefaultIcon;
begin
FIcon := TIcon.Create;
FIcon.Assign(foldericon);
end;

begin
if((LFileGetAttr(FullName) and(faReadOnly or faSysFile))<>0) then
 begin
 s:= FullName;
 if(s[Length(s)]<>'\') and (s[Length(s)]<>'/') then
  s := s +'\';
 s := s+'desktop.ini';
 if FFileExists(s) then
  begin
  fini := TIniFile.Create(GetShortName(s));
  s := fini.ReadString('.ShellClassInfo','IconFile','');
  i := fini.ReadInteger('.ShellClassInfo','IconIndex',0);
  if FFileExists(s) then
   begin
   StrPCopy(@_s[0],GetShortName(s));
   h := ExtractIcon(HInstance,@_s[0],i);
   if h <> 0 then
    begin
    FIcon := TIcon.Create;
    FIcon.Handle := h;
    end
   else
    AssignDefaultIcon;
   end
  else
   AssignDefaultIcon;
  fini.Destroy;
  end
 else
  AssignDefaultIcon;
 end
else
 AssignDefaultIcon;
end;

constructor TFolder.Create(const details: TLfnSearchrec; ADir: TDirectory);
begin
  inherited Create(details, ADir);
  AssignIcon;
end;

procedure TFolder.DrawSmallIcon(Canvas: TCanvas; const Rect: TRect);
begin
  Canvas.Draw(Rect.Left + 2, Rect.Top, TinyFolder);
end;

procedure TFolder.Open;
begin
  Desktop.OpenFolderRefresh(Fullname);
end;

procedure TFolder.Delete;
begin
  Desktop.CloseSubWindows(Fullname);
  DeleteDirectory(Fullname);
  if not HDirectoryExists(Fullname) then inherited Delete;
end;

destructor TFolder.Destroy;
begin
  FreeIcon;
  inherited Destroy;
end;

procedure TFolder.FreeIcon;
begin
   if Assigned(FIcon) then
    FreeAndNil(FIcon);
end;

procedure TFolder.CheckPath(const p: TLfnFileName);
var
  dest: TLfnFileName;
begin
  dest := p + Filename;
  if Fullname = MakeDirname(p) then
    raise EFileOpError.CreateRes(SCannotPutFolderOnSelf)
  else if IsAncestorDir(Fullname, Makedirname(p)) then
    raise EFileOpError.CreateRes(SCannotPutFolderInSelf)
  else if FFileExists(dest) then
    raise EFileOpError.CreateResFmt(SCannotPutFolderOverFile, [dest])
end;

procedure TFolder.CopyToDirectory(d: TDirectory);
var
  rec: TLfnSearchrec;
  i: Integer;
begin
  CheckPath(d.Path);
  if CopyDirectory(Fullname, d.Path + Filename) then
  begin
    inherited CopyToDirectory(d);
    if not d.Find(Filename, i) and (LFindfirst(d.Path + Filename,
      faDirectory, rec) = 0) then d.AddItem(rec);
    LFindClose(rec); { 3.11 }
  end;
end;

procedure TFolder.CopyToPath(const p: TLfnFileName);
begin
  CheckPath(p);
  if CopyDirectory(Fullname, p + Filename) then inherited CopyToPath(p);
end;

procedure TFolder.MoveToDirectory(d: TDirectory);
var
  rec: TLfnSearchrec;
  i: Integer;
begin
  { Windows showing this folder or any descendants are closed
    first to prevent any inconsistencies }
  CheckPath(d.Path);
  Desktop.CloseSubWindows(Fullname);
  if MoveDirectory(Fullname, d.Path + Filename) then
  begin
    inherited MoveToDirectory(d);
    if not d.Find(Filename, i) and (LFindfirst(d.Path + Filename,
      faDirectory, rec) = 0) then d.AddItem(rec);
    LFindClose(rec); { 3.11 }
    FRelease := frFree;
  end;
end;

procedure TFolder.MoveToPath(const p: TLfnFileName);
begin
  CheckPath(p);
  Desktop.CloseSubWindows(Fullname);
  if MoveDirectory(Fullname, p + Filename) then
    inherited MoveToPath(p);
end;

procedure TFolder.MoveAndRename(const NewName: TLfnFileName);
begin
  Desktop.CloseSubWindows(Fullname);
  if MoveDirectory(FullName, NewName) then
    inherited MoveAndRename(NewName);
end;

procedure TFolder.SetFileName(const AName: TFileBody);
var
  oldname: TLfnFileName;
begin
  {FreeIcon;}
  oldname := Fullname;
  ExitDirectory(oldname);
  inherited SetFileName(AName);
  Desktop.RenameWindows(oldname, Fullname);
  {AssignIcon;}
end;

procedure TFolder.DragDrop(Source: TObject);
begin
  FolderRef.Target := Fullname;
  FolderRef.DragDrop(Source);
end;

function TFolder.LessThan(f: TDirItem): Boolean;
begin
  Result := (f is TFileItem) or inherited LessThan(f);
end;

procedure TFolder.AssignRef(ref: TReference);
begin
  with Ref do
  begin
    BeginUpdate;
    inherited AssignRef(ref);
    Kind := rkFolder;
    EndUpdate;
  end;
end;

function TFolder.AcceptsDrops: Boolean;
begin
  Result := True;
end;

function TFolder.GetStartInfo: string;
begin
  Result := PackStartInfo('$Folder ' + Fullname, '', '', 0, 0);
end;

{ TFileList }

constructor TFileList.Create;
begin
  inherited Create;
  FFileSize := 0;
  FFileCount := 0;
  FFolderCount := 0;
end;

procedure TFileList.Clear;
begin
  inherited Clear;
  FFileSize := 0;
  FFileCount := 0;
  FFolderCount := 0;
  FItemCount := 0;
end;

function TFileList.Add(Item: Pointer): Integer;
begin
  Result := inherited Add(Item);
  if TObject(Item) is TFileItem then
  begin
    Inc(FFileCount);
    Inc(FItemCount);
    Inc(FFileSize, TFileItem(Item).Size);
  end
  else
  begin
    Inc(FFolderCount);
    Inc(FItemCount);
    if DeepScan then
    begin
      ShowHourGlass;
      with DirInfo(TFolder(Item).Fullname, True) do
      begin
        Inc(FFileCount, files);
        Inc(FFolderCount, dirs);
        Inc(FItemCount, files + dirs);
        Inc(FFileSize, size);
      end;
    end;
  end;
end;

procedure DoneDirectry; far;
begin
  ResizeBitmap.Free;
end;

initialization
  ResizeBitmap := Graphics.TBitmap.Create;
  ResizeBitmap.Width := 32;
  ResizeBitmap.Height := 32;
  AddExitProc(DoneDirectry);
end.

