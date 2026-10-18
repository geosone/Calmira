{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-2000 Calmira Online!                               }
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

unit Tree;

{ This form serves two purposes: the global variable Explorer points
  to the "Explorer" window that is used to navigate disks.  One
  function called SelectFolder() creates a modal tree dialog
  for the user to pick a directory.

  3.1 -- OpenExplorer() creates the Explorer.  It first creates an icon
  window with Explorer as it's owner, then sets the Outline's parent
  to the TreePanel in the icon window.  The Explorer form itself is
  not shown.

  Since Delphi's form inheritence is rather limited, both versions
  of the tree are handled by one class, and the IsDialog field
  determines how the object should behave.

  Directory outlines

  Delphi's sample TDirectoryOutline is pretty hopeless, as most Delphi
  programmers have discovered.  The tree view needs to indicate folders
  which contain sub-folders, but TOutline can't cope with drawing
  plus/minus symbols together with node pictures, and TDirectoryOutline
  doesn't bother to tackle this.

  So some custom code is required, which builds each level of the
  tree as the user reaches it, but also checks for sub-folders.

  Outline drawing

  The main feature of the tree view is the that way it owner-draws the
  TOutline control.  The default TOutline painting method uses BrushCopy(),
  which provides bitmap transparency but is extremely slow.  The tree
  view just uses Draw(), which makes it very fast, but this means that
  selected items can only be focused and not highlighted.

  Another problem is that level 1 nodes (i.e. disk drives) need to have
  descriptive captions, but this makes it harder to obtain the
  selected folder using the FullPath property.  The solution is to store
  the descriptive captions in a separate TStringList which is accessed
  during drawing. }

interface

uses SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, Grids, Outline, StdCtrls, IconWin, FileCtrl, Menus,
  ExtCtrls, CalForm, Settings, Scrtree, CalMsgs, Sysmenu, Buttons, Picbtn,
  NetDlgs;

type
  TExplorer = class(TCalForm)
    PopupMenu: TPopupMenu;
    OpenFolder: TMenuItem;
    OpenNew: TMenuItem;
    Find: TMenuItem;
    N1: TMenuItem;
    ExpandLevel: TMenuItem;
    ExpandBranch: TMenuItem;
    ExpandAll: TMenuItem;
    CollapseBranch: TMenuItem;
    N2: TMenuItem;
    RefreshTree: TMenuItem;
    Outline: TScrollTree;
    SystemMenu: TSystemMenu;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    MapNetwork: TMenuItem;
    DisconnectNetwork: TMenuItem;
    N3: TMenuItem;
    ShareAs: TMenuItem;
    StopSharing: TMenuItem;
    N4: TMenuItem;
    NetConnectDialog: TNetConnectDialog;
    NetDisconnectDialog: TNetDisconnectDialog;
    NetShareAsDialog: TNetShareAsDialog;
    NetStopShareDialog: TNetStopShareDialog;
    Properties: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure OutlineDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure FormResize(Sender: TObject);
    procedure OpenFolderClick(Sender: TObject);
    procedure OpenNewClick(Sender: TObject);
    procedure ExpandLevelClick(Sender: TObject);
    procedure ExpandBranchClick(Sender: TObject);
    procedure ExpandAllClick(Sender: TObject);
    procedure CollapseBranchClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure OutlineMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure OutlineMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure OutlineMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure OutlineClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure RefreshTreeClick(Sender: TObject);
    procedure OutlineExpand(Sender: TObject; Index: Longint);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure OutlineKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure OutlineDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure OutlineDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure PopupMenuPopup(Sender: TObject);
    {procedure DelClick(Sender: TObject);}
    { 3.1 }
    procedure FindClick(Sender: TObject);
    procedure MapNetworkClick(Sender: TObject);
    procedure DisconnectNetworkClick(Sender: TObject);
    procedure ShareAsClick(Sender: TObject);
    procedure StopSharingClick(Sender: TObject);
    procedure PropertiesClick(Sender: TObject);
  private
    { Private declarations }
    FilePane: TIconWindow;
    PreventClick: Boolean;
    OldSelectedItem: Longint; { 3.1 }
    Walking: Boolean;
    DriveCaptions: TStringList;
    BmpList: TBitmap;
    IsDialog: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure ExpandFolder(Index: Longint);
    procedure Walktree(Index: Longint);
    function FindDirectory(const Dir: string; ExpandPath: Boolean): Longint;
  public
    { Public declarations }
    function SelectedFolder: TFilename;
    procedure BuildTree;
    procedure Configure;
    procedure Travel(const folder: TFilename);
    procedure SettingsChanged(Changes: TSettingChanges); override;
    constructor CreateDialog(AOwner: TComponent);
  end;

procedure OpenExplorer(const default: TFilename);
function SelectFolder(const default: TFilename): TFilename;

var
  Explorer: TExplorer;

implementation

{$R *.DFM}

uses Strings, Desk, MiscUtil, Files, Resource, CompSys, Iconic, Drives,
  MultiGrd, Referenc, Locale, FileMan, Task, FileFind, DiskProp, Directry,
  FileProp, SysProp;

{ TOutlineNode's Data property is used to store flags, which speeds
  up drawing by avoiding the call to GetLastChild by marking the last
  child node.  The HasChildren flag determines if subdirectories
  exist.  The BeingShared flag determines if a drive or folder is
  being shared.  The NameIsLFN is used in OutLineDrawItem. }
const
  IsLastChild = 1;
  HasChildren = 2;
  BeingShared = 4; { 3.1 }
 {NameIsLFN   = 8;}

function ExtractNodeDir(const s: TFilename): TFilename;
var
  p: Integer;
begin
  { Returns the name of a folder, given an outline node's FullPath,
    which looks something like "Computer\c:\\delphi\projects".
    The first Delete() call chops off 'Computer\' and the second
    removes the extra '\'.  This should leave a valid folder. }
  Result := s;
  p := Pos('\', Result);
  if p > 0 then System.Delete(Result, 1, p);
  p := Pos('\\', Result);
  if p > 0 then System.Delete(Result, p, 1);
end;

procedure TExplorer.BuildTree;
var
  root: string[3];
  i: Integer;
  Last: Longint;
  Letter: Char;
  DriveType: TDriveType;
  title: string[63];
  node: TOutlineNode;
begin
  { Constructs the 1st two levels of the outline.
    Fixed drives are searched for a volume label and removeable drives
    are just indicated as such.  Each title is added to the DriveCaptions
    list. }
  DriveCaptions.Clear;
  Outline.Clear;
  Outline.AddChild(0, Computer.Caption);
  Last := 0;
  for Letter := 'A' to 'Z' do
  begin
    DriveType := GuessDriveType(Letter);
    if DriveType <> dtNoDrive then
    begin
      Last := Outline.AddChild(1, LowCase(Letter) + ':\');
      node := Outline.Items[Last];
      case DriveType of
        dtFloppy,
        dtCDROM  : {if ShowRemovableVolume then
                     title := GetVolumeLabel(Letter)
                   else} title := '';
        dtFixed,
        dtNetwork: title := GetNetworkVolume(Letter);
        dtRAM    : title := GetVolumeLabel(Letter);
      end;
      if title = '' then
        title := MakeDriveName(DriveType, Letter)
      else
        title := Format('%s (%s:)', [title, Letter]);
      DriveCaptions.AddObject(title, node);
      { 3.1 }
      if not IsDialog then if IsShared(Letter + ':\') then
        Outline.Items[Last].Data := Pointer(BeingShared or
          Longint(Outline.Items[Last].Data));
    end;
  end;
  if Last > 0 then
    Outline.Items[Last].Data := Pointer(IsLastChild or
      Longint(Outline.Items[Last].Data));
  Outline.Items[1].Expand;
end;

procedure TExplorer.FormCreate(Sender: TObject);
begin
  with SystemMenu do begin
    DeleteCommand(SC_SIZE);
    DeleteCommand(SC_MAXIMIZE);
  end;
  MinimumWidth := 180;
  MinimumHeight := 140;
  DriveCaptions := TStringList.Create;
  Icon.Assign(Icons.Get('EXPLORER'));
  Configure;
  if not IsDialog then
  begin
    OKBtn.Free;
    CancelBtn.Free;
  end;
  BuildTree;
end;

procedure TExplorer.Configure;
begin
  Color := Colors[ccWinFrame];
  with Outline do
  begin
    Font.Assign(GlobalFont);
    Canvas.Font.Assign(Font);
    Canvas.Pen.Color := clGray;
    ItemHeight := LineHeight;
    ThumbTracking := TrackThumb;
  end;
  { 3.1 set tree icons' background color to match window }
  if BmpList <> nil then BmpList.Free;
  BmpList := TResBitmap.AlternateLoad('TREEBMPS', 'explrico.bmp');
  with BmpList do
    ReplaceBitmapColors(BmpList, Canvas.Pixels[0, Height - 1], clWindow);
end;

procedure TExplorer.OutlineDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
const
  PicturePlusRect: TRect = (Left: 160; Top: 0; Right: 169; Bottom: 9);
  PictureMinusRect: TRect = (Left: 176; Top: 0; Right: 185; Bottom: 9);
var
  item: TOutlineNode;
  x, y, L: Integer;
  folder: string[63];
  Focus: TRect;
  SharedY: Byte;
begin
  with Outline do begin
    { TOutline [mistakenly?] passes the graphical row as the Index
      rather than the index of the outline item, so we must convert
      it back. }
    Index := GetItem(0, Rect.Top);
    item := Items[index];
    L := item.Level;
    x := Rect.Left + (L - 1) * 18 + 2;
    y := (Rect.Top + Rect.Bottom) div 2;
    { 3.1 -- is this drive or folder being shared? }
    if Longint(item.Data) and BeingShared > 0 then
      SharedY := 16
    else
      SharedY := 0;
    { items on level 2 are disk drives, which have their captions
      stored in the string list }
    if L = 2 then
      folder := DriveCaptions[DriveCaptions.IndexOfObject(item)]
    else
    begin
      folder := item.Text;
      if UpcaseFirstChar then folder[1] := UpCase(folder[1]);
    end;
    with Canvas do
    begin
      Brush.Color := Color;
      FillRect(Rect);
      if odSelected in State then
      begin { 3.0 }
        Brush.Color := clHighlight;
        Font.Color := clHighlightText;
        Focus := Rect;
        Focus.Left := x + 18;
        Focus.Right := Focus.Left + TextWidth(folder) + 4;
        FillRect(Focus); { Highlight }
      end
      else Font.Color := clWindowText;
      { index = 1   the Computer 'icon' is drawn
        level = 2   the drive type is used to offset into the bitmap list
        else        an open or closed folder is drawn }
      if index = 1 then
        { draw computer icon }
        CopyRect(Bounds(x, Rect.Top, 16, 16), BmpList.Canvas,
          Bounds(0, 0, 16, 16))
      else if L = 2 then
        { draw drive icon }
        CopyRect(Bounds(x, Rect.Top, 16, 16), BmpList.Canvas,
          Bounds(Succ(Ord(GuessDriveType(item.Text[1]))) * 16, SharedY, 16, 16))
      else if (odSelected in State) then
        { draw open folder icon }
        CopyRect(Bounds(x, Rect.Top, 16, 16), BmpList.Canvas,
          Bounds(128, SharedY, 16, 16))
      else
        { draw closed folder icon }
        CopyRect(Bounds(x, Rect.Top, 16, 16), BmpList.Canvas,
          Bounds(144, SharedY, 16, 16));
      if odFocused in State then DrawFocusRect(Focus);
      TextOut(x + 20, Rect.Top + 1, folder);
      if index = 1 then exit;
      { Draw the horizontal line connecting the node }
      MoveTo(x - 2, y);
      Dec(x, 12);
      DottedLineTo(x, y);
      { If the node is the last child, don't extend the vertical
        line any further than the middle }
      if Longint(item.Data) and IsLastChild > 0 then
        DottedLineTo(x, Rect.Top - 1)
      else
      begin
        MoveTo(x, Rect.Top);
        DottedLineTo(x, Rect.Bottom);
      end;
      { Draw a suitable plus/minus picture depending on if
        there are subfolders }
      if (Longint(item.Data) and HasChildren > 0) or (L = 2) then
        if item.Expanded then
          CopyRect(Bounds(x - 4, y - 4, 9, 9), BmpList.Canvas, PictureMinusRect)
        else
          CopyRect(bounds(x - 4, y - 4, 9, 9), BmpList.Canvas, PicturePlusRect);
      { Draw the vertical lines to the left of the node's bitmap,
        by moving up through the parent nodes.  If a parent node
        is a "last child", then don't draw a line (because there
        are no siblings underneath it) }
      Dec(x, 18);
      while x > 0 do begin
        item := item.Parent;
        if not Longint(item.Data) and IsLastChild > 0 then
        begin
          MoveTo(x, Rect.Top);
          DottedLineTo(x, Rect.Bottom);
        end;
        Dec(x, 18);
      end;
    end;
  end;
end;

(*
procedure TExplorer.DriveBoxDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  Level: Word;
begin
  with DriveBox do
  begin
    Level := StrToInt(Items[Index][1]);
    with Canvas do
    begin
      Brush.Color := clWhite;
      Font.Color := clWindowText;
      FillRect(Rect);
      if Level = 1 then
        CopyRect(Bounds(4, Rect.Top, 16, 16), BmpList.Canvas,
          Bounds(0, 0, 16, 16))
      else if Level >= 2 then
        CopyRect(Bounds((Level * 8) - 4, Rect.Top, 16, 16), BmpList.Canvas,
          Bounds(Succ(Ord(GuessDriveType(Items[Index][Length(Items[Index]) - 2])))
          * 16, 0, 16, 16));
      TextOut((Level * 8) + 16, Rect.Top + 1,
        Copy(Items[Index], 3, Length(Items[Index])));
    end;
  end;
end;
*)

function TExplorer.SelectedFolder: TFilename;
var
  p: Integer;
begin
  with Outline do
    if SelectedItem = 1 then Result := ''
    else Result := ExtractNodeDir(Items[SelectedItem].FullPath);
end;

procedure TExplorer.Notification(AComponent: TComponent; Operation: TOperation);
begin
  { The tree view must be kept informed if it's slave icon window
    has been destroyed }
  inherited Notification(AComponent, Operation);
  if (AComponent = FilePane) and (Operation = opRemove) then FilePane := nil;
end;

procedure TExplorer.FormResize(Sender: TObject);
begin
  if IsDialog then
  begin
    StretchShift([Outline], [stWidth, stHeight]);
    StretchShift([OKBtn, CancelBtn], [stLeft, stTop]);
  end
  else
  begin
    Outline.Width := ClientWidth - 8;
    Outline.Height := ClientHeight - Outline.Top - 4;
  end;
  Invalidate;
end;

procedure TExplorer.OpenFolderClick(Sender: TObject);
var
  s: TFilename;
  w: TIconWindow;
begin
  { A modal tree dialog returns immediately after a folder is
    "opened" or Enter is pressed }
  if IsDialog then
  begin
    if Outline.SelectedItem > 1 then ModalResult := mrOK;
    Exit;
  end;
  if Outline.SelectedItem = 1 then Computer.ShowNormal
  else
  begin
    s := SelectedFolder;
    w := Desktop.WindowOf(s);
    if w <> nil then
    begin
      { there is an existing icon window of the selected directory }
      if w = FilePane then
      begin
        { the icon window already belongs to explorer }
        if w.Dir.Fullname <> s then w.RefreshWin;
        Exit;
      end;
      { don't use w.Free because this method may be called during
        a KeyPress event of w }
      w.Release;
    end;
    if FilePane <> nil then
    begin
      FilePane.ChangeDir(s);
    end
    else
    begin
      { 3.1 -- Create a new icon window and place the tree outline
        on the icon window's TreePanel }
      FilePane := TIconWindow.Init({Application}Explorer, s, DefaultFilter);
      FilePane.Locked := True;
      Outline.Parent := Filepane.TreePanel;
      Outline.Align := alClient;
      FilePane.Show;
    end;
  end;
end;

procedure TExplorer.OpenNewClick(Sender: TObject);
begin
  if IsDialog then Exit;
  if Outline.SelectedItem = 1 then Computer.ShowNormal
  else
    { 3.1 -- Instead of calling Desktop.Openfolder, the window
      is opened manually here, because we want to override the
      'Browse through folders in the same icon window' setting,
      which is evaluated in OpenFolder, in case it is switched
      off. }
    TIconWindow.Init(Application, SelectedFolder, DefaultFilter).Show;
end;

procedure TExplorer.ExpandLevelClick(Sender: TObject);
var
  item: TOutlineNode;
begin
  with Outline do
  begin
    item := Items[SelectedItem];
    if not item.HasItems and (Longint(item.Data) and HasChildren > 0) then
      ExpandFolder(SelectedItem);
    item.Expand;
  end;
end;

procedure TExplorer.ExpandBranchClick(Sender: TObject);
begin
  Desktop.SetCursor(crHourGlass);
  Update;
  Walking := True;
  try
    with Outline do
    begin
      WalkTree(SelectedItem);
      Items[SelectedItem].FullExpand;
    end;
  finally
    Desktop.ReleaseCursor;
    Walking := False;
  end;
end;

procedure TExplorer.ExpandAllClick(Sender: TObject);
begin
  UpdateScreen;
  Desktop.SetCursor(crHourGlass);
  LockWindowUpdate(Outline.Handle);
  Walking := True;
  try
    WalkTree(1);
    Outline.FullExpand;
  finally
    LockWindowUpdate(0);
    Desktop.ReleaseCursor;
    Walking := False;
  end;
end;

procedure TExplorer.CollapseBranchClick(Sender: TObject);
begin
  with Outline do Items[SelectedItem].Collapse;
end;

procedure TExplorer.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if IsDialog then Action := caHide
  else
  begin
    Action := caFree;
    if FilePane <> nil then
    begin
      FilePane.Locked := False;
      FilePane := nil;
    end;
  end;
end;

procedure TExplorer.OutlineMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  junction: Integer;
  item: Longint;
  node: TOutlineNode;
  i: Integer;
  p: TPoint;
begin
  if (Button = mbLeft) and not (ssDouble in Shift) then with Outline do
  begin
    { Test if the user clicked on + or - box }
    item := GetItemAt(X, Y);
    if item > 0 then
    begin
      node := Items[item];
      if (Longint(node.Data) and HasChildren > 0) or (node.Level = 2) then
      begin
        junction := (node.Level - 1) * 18 - 10;
        if (X > junction - 8) and (X < junction + 8) then
        begin
          PreventClick := True;
          with node do Expanded := not Expanded;
          OldSelectedItem := SelectedItem;
          { 3.1 }
          if not node.Expanded and (FilePane <> nil) then OpenFolder.Click;
        end;
      end;
    end;
  end
  else if Button = mbRight then with Outline do
  begin
    i := GetItem(X, Y);
    if i > 0 then
    begin
      PreventClick := True;
      SelectedItem := i;
      OldSelectedItem := i;
      GetCursorPos(p);
      PopupMenu.Popup(p.X, p.Y);
      PreventClick := False;
    end;
  end;
end;

procedure TExplorer.OutlineMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if PreventClick then Outline.SelectedItem := OldSelectedItem;
end;

procedure TExplorer.OutlineMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  PreventClick := False;
end;

procedure TExplorer.OutlineClick(Sender: TObject);
begin
  if not (PreventClick or Walking or IsDialog) then OpenFolder.Click
end;

procedure TExplorer.FormDestroy(Sender: TObject);
begin
  if not IsDialog then
  begin
    ini.WriteString('Explorer', 'LastFolder', SelectedFolder);
    Explorer := nil;
  end;
  DriveCaptions.Free;
  BmpList.Free;
end;

procedure TExplorer.RefreshTreeClick(Sender: TObject);
var
  last: TFilename;
  i: Longint;
begin
  last := SelectedFolder;
  DetectDrives;
  BuildTree;
  if last > '' then Travel(last);
  { 3.1 }
  if (Filepane <> nil) and (Sender = RefreshTree) then
    Filepane.RefreshWin; 
end;

procedure TExplorer.Travel(const folder: TFilename);
var
  i: Longint;
begin
  Walking := True;
  try
    i := 0;
    if (Length(folder) = 3) or HDirectoryExists(folder) then
      i := FindDirectory(folder, True);
  finally
    Walking := False;
  end;
  if i > 0 then Outline.SelectedItem := i;
end;

procedure TExplorer.OutlineExpand(Sender: TObject; Index: Longint);
var
  node: TOutlineNode;
begin
  node := Outline.Items[Index];
  if not node.HasItems and ((Longint(node.Data) and HasChildren > 0) or
    (node.Level = 2)) then
    begin
      ExpandFolder(Index);
      if not node.HasItems then node.Expanded := False;
    end;
end;

function TExplorer.FindDirectory(const Dir: string; ExpandPath: Boolean): Longint;
var
  start: Longint;
  node: TOutlineNode;
  this: string[12];
begin
  { FindDirectory locates an outline node by recursing until the top level
    folder is extracted.  Then it unrolls, searching for directory names
    as it returns, while expanding the nodes it passes through }
  if Length(Dir) = 3 then
  begin
    Result := Outline.GetTextItem(Dir);
    if (Result > 0) and ExpandPath then Outline.Items[Result].Expand;
  end
  else
  begin
    Result := 0;
    this := ExtractFilename(Dir);
    if (this = '') or (Length(this) = Length(Dir)) then Exit;
    start := FindDirectory(ExtractFileDir(Dir), ExpandPath);
    if start > 0 then
    begin
      node := Outline.Items[start];
      Result := node.GetFirstChild;
      while Result <> -1 do
        if Outline.Items[Result].Text = this then
        begin
          if ExpandPath then Outline.Items[Result].Expand;
          Exit;
        end
        else Result := node.GetNextChild(Result);
    end;
  end;
end;

procedure TExplorer.Walktree(Index: Longint);
var
  i: Longint;
  p: TOutlineNode;
begin
  { Expands a branch of the tree beginning at Index.  This is not the
    same as FullExpand because this expansion causes new nodes to be
    added when directories are found }
  p := Outline.Items[Index];
  p.Expand;
  i := p.GetFirstChild;
  while i <> -1 do
  begin
    if Longint(Outline.Items[i].Data) and HasChildren > 0 then WalkTree(i);
    i := p.GetNextChild(i);
    if GetAsyncKeyState(VK_ESCAPE) < 0 then Abort;
  end;
end;

const
  MaskFlags: array[Boolean] of Word = (0, faHidden or faSysFile);

function HasSubDirectories(const Dirname: string): Boolean;
var
  rec: TSearchRec;
  code: Integer;
begin
  code := FindFirst(Dirname + '\*.*', faDirectory or MaskFlags[ShowHidSys], rec);
  while code = 0 do
    if (rec.attr and faDirectory <> 0) and (rec.name[1] <> '.') then Break
    else code := FindNext(rec);
  Result := code = 0;
end;

procedure TExplorer.ExpandFolder(Index: Longint);
var
  rec: TSearchRec;
  path: TFilename;
  last: Longint;
  par, item: TOutlineNode;
  code, i: Integer;
  sortlist: TStringList;
begin
  last := -1;
  par := Outline.Items[Index];
  path := MakePath(ExtractNodeDir(par.FullPath));
  sortlist := TUniqueStrings.Create;
  try
    code := FindFirst(path + '*.*', faDirectory or MaskFlags[ShowHidSys], rec);
    while code = 0 do
    begin
      if (rec.Attr and faDirectory <> 0) and (rec.Name[1] <> '.') then
      begin
        rec.Name := LowerCase(rec.Name);
        if HasSubDirectories(path + rec.Name) then
          sortlist.AddObject(rec.Name, Pointer(HasChildren))
        else sortlist.Add(rec.Name);
      end;
      if GetAsyncKeyState(VK_ESCAPE) < 0 then Break;
      code := FindNext(rec);
    end;
    with sortlist do
      if Count > 0 then
      begin
        for i := 0 to Count - 1 do
        begin
          last := Outline.AddChildObject(Index, Strings[i], Objects[i]);
          { 3.1 }
          item := Outline.Items[last];
          if not IsDialog then
            if IsShared(ExtractNodeDir(item.FullPath)) then
              item.Data := Pointer(BeingShared or Longint(item.Data));
        end;
        item.Data := Pointer(IsLastChild or Longint(item.Data));
        par.Data := Pointer(HasChildren or Longint(par.Data));
      end;
  finally
    sortlist.Free;
  end;
end;

procedure TExplorer.FormHide(Sender: TObject);
begin
  if not IsDialog and ExplorerTask then Taskbar.DeleteButton(Handle);
end;

procedure TExplorer.FormShow(Sender: TObject);
begin
  if not IsDialog and ExplorerTask then Taskbar.AddButton(Handle);
  Outline.SetFocus; { 3.1 }
end;

procedure TExplorer.FormPaint(Sender: TObject);
begin
  if not IsDialog then Border3D(Canvas, ClientWidth - 1, ClientHeight - 1);
end;

constructor TExplorer.CreateDialog(AOwner: TComponent);
var
  OKBtn, CancelBtn: TBitBtn;
begin
  IsDialog := True;
  inherited Create(AOwner);
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  OpenNew.Enabled := False;
end;

procedure TExplorer.OutlineKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if IsDialog and (Key = VK_ESCAPE) then
    ModalResult := mrCancel
  else
    Filepane.GridKeyDown(Sender, Key, Shift); { 3.1 }
end;

procedure TExplorer.OutlineDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Source is TMultiGrid) and (Source <> Computer.Grid)
    and (Outline.GetItemAt(X, Y) > 1);
  with Outline do
    if not Accept or (State = dsDragLeave) then DropFocus := -1
    else DropFocus := GetCellAt(X, Y);
end;

procedure TExplorer.OutlineDragDrop(Sender, Source: TObject; X,
  Y: Integer);
begin
  with Outline do
  begin
    DropFocus := -1;
    FolderRef.Target := ExtractNodeDir(Items[GetItemAt(X, Y)].FullPath);
  end;
  FolderRef.DragDrop(Source);
end;

procedure TExplorer.SettingsChanged(Changes: TSettingChanges);
begin
  if [scSystem, scDisplay, scDesktop] * Changes <> [] then Configure;
  if scDevices in Changes then RefreshTree.Click;
end;

{ 3.1 }

procedure TExplorer.FindClick(Sender: TObject);
begin
  FileFindExecute(SelectedFolder);
end;

procedure TExplorer.MapNetworkClick(Sender: TObject);
begin
  if NetConnectDialog.Execute then RefreshTree.Click;
end;

procedure TExplorer.DisconnectNetworkClick(Sender: TObject);
begin
  if NetDisconnectDialog.Execute then RefreshTree.Click;
end;

procedure TExplorer.ShareAsClick(Sender: TObject);
begin
  with NetShareAsDialog do
  begin
    PathName := SelectedFolder;
    if Execute then RefreshTree.Click;
  end;
end;

procedure TExplorer.StopSharingClick(Sender: TObject);
begin
  with NetStopShareDialog do
  begin
    PathName := SelectedFolder;
    if Execute then RefreshTree.Click;
  end;
end;

procedure TExplorer.PropertiesClick(Sender: TObject);
begin
  if Outline.SelectedItem = 1 then
    ShowModalDialog(TSysPropDlg)
  else if Length(SelectedFolder) = 3 then
    DiskPropExecute(SelectedFolder[1])
  else
  begin
    { folder properties }
  end;
end;

procedure TExplorer.PopupMenuPopup(Sender: TObject);
begin
  {Del.Enabled := not IsDialog and (Length(SelectedFolder) > 3);}
  Properties.Enabled := (Length(SelectedFolder) <= 3);
end;

(* Delete Directory removed due to instability.

procedure TExplorer.DelClick(Sender: TObject);
var
  s: TFilename;
begin
  s := SelectedFolder;
  if (Length(s) > 3) and not (ConfirmDelStart and
    (MsgDialogResFmt(SQueryDeleteItems, [1, '', ExtractFileDir(s)],
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes)) then begin
    Desktop.CloseSubWindows(s);
    if DeleteDirectory(s) then Outline.DeleteSelectedNode;
  end;
end;
*)

type
  TProtectedWin = class(TWinControl);

procedure OpenExplorer(const default: TFilename);
var
  dest: TFilename;
begin
  ShowHourGlass;
  if Explorer = nil then Explorer := TExplorer.Create(Application);
  with Explorer do
  begin
    dest := default;
    if (dest = '') and ExploreLastFolder then
    begin
      dest := ini.ReadString('Explorer', 'LastFolder', '');
      if (dfRemoveable in GetDriveFlags(dest[1])) or
        not HDirectoryExists(dest) { 3.1 } then dest := '';
    end;
    if dest = '' then
      dest := ini.ReadString('Explorer', 'DefaultFolder', 'c:\'); { 3.1 }
    Travel(dest);
    if SelectedFolder > '' then TProtectedWin(Outline).Click;
  end;
end;

function SelectFolder(const default: TFilename): TFilename;
begin
  with TExplorer.CreateDialog(Application) do
  begin
    Caption := LoadStr(SSelectFolder);
    Travel(default);
    try
      Result := '';
      if ShowModal = mrOK then Result := SelectedFolder
      else Result := default;
    finally
      Free;
    end;
  end;
end;

end.

