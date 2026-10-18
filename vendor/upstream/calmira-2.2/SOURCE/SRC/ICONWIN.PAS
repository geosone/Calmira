{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.2                                                    }
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

unit IconWin;

{ Icon Windows unit.

  Fields

    FDir - the form's TDirectory object that holds a list of files and folders.

    SelSize - the size (in bytes) of all items selected

    FDragCopy - True if the current drag-and-drop should copy files if
      successful, False if the operation is a move.

    FSelected - the focused TDirItem

    FSelection - contains a list of selected TDirItems, but is only valid
      immediately after CompileSelection is called.

    FLocked - boolean that indicates if the form should not change its
      size automatically, probably due to the tree view being attached.

    DragJustEnded - flag that is set after OnDragEnd to stop deselections

    Stretching - true if the user is using the lasso to make a selection
}

interface

uses
  SysUtils, WinTypes, Classes, Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  Directry, Menus, MultiGrd, Dropclnt, DropServ, DragDrop, Settings,
  Grids, Messages, Progress, Resource, CalForm;

type
  TIconWindow = class(TCalForm)
    TotalLabel: TLabel;
    SelLabel: TLabel;
    ObjectMenu: TPopupMenu;
    Open: TMenuItem;
    OpenWith: TMenuItem;
    Delete: TMenuItem;
    Properties: TMenuItem;
    Rename: TMenuItem;
    Duplicate: TMenuItem;
    Grid: TMultiGrid;
    DropServer: TDropServer;
    DropClient: TDropClient;
    WinMenu: TPopupMenu;
    CreateFolder: TMenuItem;
    Run: TMenuItem;
    N1: TMenuItem;
    SetFilter: TMenuItem;
    SortbyType: TMenuItem;
    SortbyName: TMenuItem;
    SortbySize: TMenuItem;
    SortbyDate: TMenuItem;
    N2: TMenuItem;
    Inspect: TMenuItem;
    ViewList: TMenuItem;
    AliasProp: TMenuItem;
    Describe: TMenuItem;
    FileSystem: TMenuItem;
    NewAlias: TMenuItem;
    LargeIcons: TMenuItem;
    SmallIcons: TMenuItem;
    N3: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure GridDragOver(Sender, Source: TObject; X, Y: Integer;
     State: TDragState; var Accept: Boolean);
    procedure GridDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ObjectMenuPopup(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure CreateFolderClick(Sender: TObject);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton;
     Shift: TShiftState; X, Y: Integer);
    procedure FormDragOver(Sender, Source: TObject; X, Y: Integer;
     State: TDragState; var Accept: Boolean);
    procedure OpenWithClick(Sender: TObject);
    procedure PropertiesClick(Sender: TObject);
    procedure GridCellSelected(Sender: TObject; Index : Integer; IsSelected: Boolean);
    procedure RenameClick(Sender: TObject);
    procedure GridKeyPress(Sender: TObject; var Key: Char);
    procedure FormDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure RunClick(Sender: TObject);
    procedure SetFilterClick(Sender: TObject);
    procedure SortByTypeClick(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure DuplicateClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; Index: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure GridSelectCell(Sender: TObject; Index: Integer;
      var CanSelect: Boolean);
    procedure DropServerFileDrop(Sender: TObject; X, Y: Integer;
      Target: Word);
    procedure TotalLabelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GridMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GridEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure SelLabelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GridMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DropClientDropFiles(Sender: TObject);
    procedure DropServerDeskDrop(Sender: TObject; X, Y: Integer;
      Target: Word);
    procedure FormDblClick(Sender: TObject);
    procedure GridSelect(Sender: TObject; Index: Integer);
    procedure InspectClick(Sender: TObject);
    procedure ViewListClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure AliasPropClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure DescribeClick(Sender: TObject);
    procedure FileSystemClick(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure NewAliasClick(Sender: TObject);
    procedure TotalLabelClick(Sender: TObject);
    procedure WinMenuPopup(Sender: TObject);
  private
    { Private declarations }
    FDir : TDirectory;
    Selsize : Longint;
    FDragCopy : Boolean;
    FSelected : TDirItem;
    FSelection: TFileList;
    FLocked : Boolean;
    DragJustEnded: Boolean;
    Stretching: Boolean;
    Corner, Anchor: TPoint;
    Narrow : Boolean;
    ShowingSelection : Boolean;
    procedure Arrange(Sender : TObject);
    procedure InitFileOp(Op : TFileOperation);
    procedure DoneFileOp;
    function InitCopy(const dest: string) : Boolean;
    function InitMove(const dest: string) : Boolean;
    function InitDelete(const dest: string) : Boolean;

    { 2.2 }
    procedure InitBlindFileOp(Op : TFileOperation; list: TFileList);
    procedure DoneBlindFileOp;
    function InitBlindCopy(const source : TFilename; list: TFileList): Boolean;
    function InitBlindMove(const source : TFilename; list: TFileList): Boolean;

    procedure AutoResize;
    procedure ConstructPathMenu;
    procedure SetDragCopy(copy: Boolean);
    procedure GridDrawList(Sender: TObject; Index: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure GridDrawSmall(Sender: TObject; Index: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMNCRButtonDown(var Msg: TWMNCRButtonDown); message WM_NCRBUTTONDOWN;
    procedure WMActivate(var Msg : TWMActivate); message WM_ACTIVATE;
    procedure DrawLasso(r: TRect);
    procedure SelectFileHandler(Sender : TObject;
      const FileSpec : string; select : Boolean);
    procedure SearchFileHandler(Sender : TObject; const s: string);
    procedure InitTopLeft;
    procedure AssignCaption;
    procedure MarkItems(IsCopy : Boolean);
    procedure PasteItems;
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Init(AOwner: TComponent;
      const foldername, filter: TFilename);
    procedure DropInFolder(const foldername: TFilename);
    procedure DropInWindow(d : TDirectory);
    procedure DropAsAliases(const foldername : TFilename);
    procedure FolderRenamed(const previous, current: TFilename);
    function FileAt(x, y : Integer; wholecell: Boolean) : TDirItem;
    function CompileSelection(recurse: Boolean): TFileList;
    function CompileFilenames: TStringList;
    procedure ChangeDir(const foldername : string);
    function LoadDimensions: Boolean;
    procedure SaveDimensions;
    procedure Configure;
    procedure SettingsChanged(Changes : TSettingChanges); override;
    procedure RefreshWin;
    procedure UpdateStatusbar(TotalChanged, SelChanged: Boolean);
    procedure CopyToClipboard;
    procedure GotoItem(const filename: string);
    class function CalcSize(cols, rows : Integer): TPoint;
    class procedure CalcColWidths;
    procedure SelectFromClipboard;
    property Dir : TDirectory read FDir;
    property Selected : TDirItem read FSelected write FSelected;
    property Selection: TFileList read FSelection;
    property DragCopy: Boolean read FDragCopy write SetDragCopy;
    property Locked : Boolean read FLocked write FLocked;
  end;

const
   MacroDisplayMode : Integer = 0;

var
   Xspare, YSpare: Integer;
   NameColWidth, SizeColWidth, DateColWidth,
   TimeColWidth, AttrColWidth : Integer;
   SampleDate, SampleTime : string[31];

implementation

{$R *.DFM}

uses ShellAPI, FileProp, DiskProp, Drives, Graphics, Tree, Environs,
  Fileman, WasteBin, FileCtrl, OpenFile, RunProg, Desk, FileFind,
  Filter, CompSys, Strings, MiscUtil, Files, WinProcs, Alias, FSysProp, Select,
  Clipbrd, Referenc, Locale, Embed, Iconic, Task, IncSrch, FourDOS;


var
  PathMenu : TPopupMenu;
  LastPath : TFilename;
  FileClipboard : TStringList;
  FileClipboardCopy : Boolean;

const
  LabelTop : Integer = 4;
  LabelDiv : Integer = 153;


procedure TIconWindow.FormCreate(Sender: TObject);
begin
  Icon.Assign(FolderIcon);
  DeleteMenu(GetSystemMenu(Handle, False), SC_SIZE, MF_BYCOMMAND);
  FSelection := TFileList.Create;
  SelLabel.Left := LabelDiv;
end;


procedure TIconWindow.FormDestroy(Sender: TObject);
begin
  Desktop.RemoveWindow(self);
  Dir.Free;
  FSelection.Free;
  if WindowOpen = woSaved then SaveDimensions;
end;


function TIconWindow.LoadDimensions: Boolean;
var
  l, t, w, h: Integer;
  s: string[31];
begin
  { Loads positions and size from INI file }
  s := WindowPos.Values[Dir.Fullname];
  if s = '' then Result := False
  else try
    Result := Unformat(s, '%d,%d,%d,%d', [@l, @t, @w, @h]) = 4;
    if Result then begin
      SetBounds(l, t, w, h);
      Locked := True;
    end;
  except
    on EConvertError do;
  end;
end;


procedure TIconWindow.SaveDimensions;
begin
  WindowPos.Values[Dir.Fullname] :=
    Format('%d,%d,%d,%d', [Left, Top, Width, Height]);
end;




procedure TIconWindow.Configure;
begin
  Color := Colors[ccWinFrame];

  with Grid do begin
    Visible := False;
    Color := Colors[ccIconBack];
    SelColor := Colors[ccIconSel];
    ThumbTrack := TrackThumb;

    if ViewList.Checked then begin
      DefaultColWidth := Width;
      DefaultRowHeight := LineHeight;
      OnDrawCell := GridDrawList;
    end
    else if SmallIcons.Checked then begin
      DefaultColWidth := NameColWidth + 24;
      DefaultRowHeight := LineHeight;
      OnDrawCell := GridDrawSmall;
    end
    else begin
      DefaultColWidth := BrowseGrid.X;
      DefaultRowHeight := BrowseGrid.Y;
    end;

    Font.Assign(GlobalFont);
    Canvas.Font.Assign(Font);
    Visible := True;
  end;

  with CalcSize(2, 1) do begin
    MinimumWidth := X;
    MinimumHeight := Y;
  end;
end;


class procedure TIconWindow.CalcColWidths;
begin
  with Computer.Canvas do begin
    NameColWidth := TextWidth('nnnnnnnn.nnn') + ColumnPadding;
    SizeColWidth := TextWidth('9999.99MB') + ColumnPadding;
    DateColWidth := TextWidth(SampleDate) + ColumnPadding;
    TimeColWidth := TextWidth(SampleTime) + ColumnPadding;
    AttrColWidth := TextWidth('arh') + ColumnPadding;
  end;
end;

constructor TIconWindow.Init(AOwner: TComponent;
  const foldername, filter: TFilename);
begin
  inherited Create(AOwner);

  { Icon windows always show a directory when opened, so a special
    constructor is needed to ensure that a directory name is used. }

  FDir := TDirectory.Create(Makepath(foldername));
  FDir.Filter := filter;
  FDir.Scan;
  FDir.OnUpdate := Arrange;

  AssignCaption;
  Desktop.AddWindow(self);

  if MacroDisplayMode <> 0 then begin
    SetMenuCheck([LargeIcons, SmallIcons, ViewList], MacroDisplayMode-1);
    MacroDisplayMode := 0;
  end
  else
    SetMenuCheck([LargeIcons, SmallIcons, ViewList], Integer(DefaultDisplay));

  Configure;

  SetMenuCheck([SortByType, SortByName, SortBySize, SortByDate],
    Integer(Dir.SortOrder));

  if not Locked then AutoResize;
  Arrange(self);

  InitTopLeft;
end;


procedure TIconWindow.InitTopLeft;
begin
  if WindowOpen = woRandom then
    SetBounds(Random(Screen.Width - Width - 2),
      Random(Screen.Height - Height - 62),
      Width, Height)

  else if not ((WindowOpen = woSaved) and LoadDimensions) then begin
    if Screen.ActiveForm is TIconWindow then begin
      Top := Screen.ActiveForm.Top + 32;
      Left := Screen.ActiveForm.Left + 32;
    end
    else begin
       Top := (Screen.Height - Height) div 2;
       Left := (Screen.Width - Width) div 2;
    end;
  end;
end;


procedure TIconWindow.ConstructPathMenu;
var
  s: TFilename;
  m: TMenuItem;
  i: Integer;
begin
  { Fills a popup menu with the list of ancestor directories. }

  s := ExtractFileDir(Dir.Fullname);
  if LastPath = s then Exit;

  with PathMenu.Items do
    while Count > 0 do Items[0].Free;

  while Length(s) >= 3 do begin
    m := TMenuItem.Create(PathMenu);
    m.Caption := s;
    m.OnClick := Desktop.WindowSelect;
    PathMenu.Items.Add(m);
    if Length(s) = 3 then s := ''
    else s := ExtractFileDir(s);
  end;
end;


class function TIconWindow.CalcSize(cols, rows : Integer): TPoint;
begin
  Result.x := cols * BrowseGrid.X + XSpare;
  Result.y := rows * BrowseGrid.Y + YSpare;
end;


function GridDimensions(N: Integer) : TPoint;
var i: Integer;
begin
  Result.X := 5;
  Result.Y := 4;

  if N >= Layouts[NumLayouts-1].Upper then
    Result := Layouts[NumLayouts-1].Size;

  for i := 0 to NumLayouts-1 do
    with Layouts[i] do
    if (N >= Lower) and (N <= Upper) then begin
      Result := Size;
      Exit;
    end;
end;



procedure TIconWindow.AutoResize;
var
  size, cells: TPoint;
  details : TFileDetails;
begin
  { Changes the size of the window depending on the number of icons
    in the list }

  if WindowState <> wsNormal then Exit;

  cells := GridDimensions(Dir.Count);
  size := CalcSize(cells.X, cells.Y);

  if ViewList.Checked then begin
    details := Dir.Columns;
    size.x := 22 + NameColWidth + XSpare;
    if fdSize in details then Inc(size.x, SizeColWidth);
    if fdDate in details then Inc(size.x, DateColWidth);
    if fdTime in details then Inc(size.x, TimeColWidth);
    if fdAttr in details then Inc(size.x, AttrColWidth);
    if UseDescriptions and (fdDesc in details) then
      if DescWidth > -1 then Inc(size.x, DescWidth)
      else Inc(size.x, (15 * BrowseGrid.X) div 10);
  end
  else if SmallIcons.Checked then
    size.x := (24 + NameColWidth) * Max(2, cells.x - 2) + XSpare;


  { The OnResize event is only triggered when the bounds change, but
    as a convention, AutoResize needs to call Resize exactly once
    to reset some of the controls }

  if EqualRect(BoundsRect, Bounds(Left, Top, size.X, size.Y)) then Resize
  else SetBounds(Left, Top, size.X, size.Y);
end;


procedure TIconWindow.Arrange(Sender : TObject);
begin
  { Called after a directory's contents have changed }

  if not (csDestroying in ComponentState) then begin
    UpdateStatusbar(True, False);
    Selsize := 0;

    with Grid, Dir do begin
      Reset;                 { clear the grid }
      Limit := Count;        { set the selection extent }
      SizeGrid;              { adjust the rows and columns to fit }

      { The focus might be out of bounds after files have been deleted }
      if (Focus >= Count) and (Count > 0) then Focus := Count-1;
      GridSelect(self, Focus);
    end;
  end;
end;


procedure TIconWindow.FormResize(Sender: TObject);
var
  GridBottom : Integer;
  NowNarrow : Boolean;
  NewWidth : Integer;
begin
  if WindowState <> wsMinimized then begin
    Grid.SetBounds(4, 4, ClientWidth - 8, ClientHeight - 26);
    TotalLabel.Top := Grid.Top + Grid.Height + LabelTop;
    SelLabel.Top := TotalLabel.Top;

    NowNarrow := (LabelDiv * 2 > ClientWidth) or SingleStatus;
    if Narrow <> NowNarrow then begin
      Narrow := NowNarrow;
      if Narrow then UpdateStatusbar(True, False)
      else UpdateStatusbar(True, True);
    end;
    SelLabel.Visible := not Narrow;

    if ViewList.Checked then NewWidth := Width - 2
    else if SmallIcons.Checked then NewWidth := NameColWidth + 24
    else NewWidth := BrowseGrid.X;

    { TCustomGrid doesn't compare the current column width with a new
      setting, so DefaultColWidth should be assigned only when required }

    with Grid do
      if DefaultColWidth <> NewWidth then DefaultColWidth := NewWidth;

    Grid.SizeGrid;
    Invalidate;
  end;
end;



procedure TIconWindow.FormPaint(Sender: TObject);
var
  r: TRect;
  x, y: Integer;
begin
  Border3D(Canvas, ClientWidth-1, ClientHeight-1);
  if Narrow then
    r := Rect(4, ClientHeight - 19, ClientWidth - 3, ClientHeight - 3)
  else begin
    r := Bounds(4, ClientHeight - 19, LabelDiv - 13, 16);
    RecessBevel(Canvas, R);
    r.Left := r.Right + 3;
    r.Right := ClientWidth - 3;
  end;
  RecessBevel(Canvas, R);

  { Draw the resize "grip" }
  Canvas.Draw(ClientWidth-17, ClientHeight-17, Sizebox);
end;


function TIconWindow.FileAt(x, y : Integer; WholeCell: Boolean) : TDirItem;
var
  rect : TRect;
  i : Integer;
begin
  { Returns the item at the given mouse coordinates (grid coordinate system).
    If WholeCell is true, the entire grid box tested for containment,
    otherwise only the icon area (approximately) is tested }

  i := Grid.MouseToCell(x, y);
  rect := Grid.CellBounds(i);

  if not (ViewList.Checked or SmallIcons.Checked or WholeCell) then begin
    InflateRect(rect, -16, -8);
    OffsetRect(rect, 0, -8);
  end;

  if PtInRect(rect, Point(x, y)) and (i < Dir.Count) then
    Result := TDirItem(Dir[i])
  else Result := nil;
end;



procedure TIconWindow.GridDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  f: TDirItem;
  DropInIcon : Boolean;
  NewDrop : Integer;
begin
  { Scroll the grid if the cursor is floating over the vertical
    scroll bar's buttons }

  with Grid do
    if (X > Width - 24) and (VisibleRowCount < RowCount) then begin
      if (Y < 32) and (TopRow > 0) then
        TopRow := TopRow-1
      else if (Y > Height-32) and (TopRow < RowCount-VisibleRowCount) then
        TopRow := TopRow+1;
    end;

  if Source = Computer.Grid then Accept := False
  else begin
    { This bit is tricky...when the cursor is over a suitable icon,
      the focus box is turned on.  However, when it is not over a suitable
      icon, Accept can still be True because the drop target becomes
      the window.  That is, Accept and DropInIcon are independent }

    f := FileAt(X, Y, False);
    DropInIcon := (f <> nil) and f.AcceptsDrops;
    NewDrop := Grid.MouseToCell(X, Y);
    Accept := (Source <> Sender) or ((NewDrop <> Grid.Focus) and DropInIcon);

    with Grid do
      if not (Accept and DropInIcon) or (State = dsDragLeave) then
        DropFocus := -1
      else
        DropFocus := NewDrop;
  end;
end;


procedure TIconWindow.GridDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  target : TDirItem;
  w : TIconWindow;
begin
  Grid.DropFocus := -1;
  target := FileAt(X, Y, False);

  if (target <> nil) and target.AcceptsDrops then
    target.DragDrop(Source)

  else if Source is TMultiGrid then begin
    w := (TMultiGrid(Source).Owner as TIconWindow);
    if GetAsyncKeyState(VK_SHIFT) < 0 then w.DropAsAliases(Dir.Fullname)
    else w.DropInWindow(Dir)
  end

  else if Source = Bin.Listbox then
    Bin.RestoreTo(Dir.Fullname)

  else if Source = FindList then
    ProcessFiles(FindForm.CompileSelection, Dir.Fullname);
end;


procedure TIconWindow.InitFileOp(Op : TFileOperation);
begin
  { Begings a file operation by initialising the progress display,
    cursor and file manager }

  Desktop.SetCursor(crBusyPointer);
  CompileSelection(True);
  NoToAll;

  ProgressBox.Init(Op, Selection.FileCount);

  if UseDescriptions and Simul4DOS then
    Dir.Desc.LoadFromPath(Dir.Path);
end;


procedure TIconWindow.DoneFileOp;
begin
  ProgressBox.Hide;
  Desktop.ReleaseCursor;
  Desktop.RefreshNow;
  PlaySound(Sounds.Values['NotifyCompletion']);
  if Application.Active then SetFocus;
  NoToAll;
end;



function TIconWindow.InitCopy(const dest : string): Boolean;
begin
  Result := not (ConfirmCopyStart and
    (MsgDialogResFmt(SQueryCopyItems,
       [Grid.SelCount, OneItem[Grid.SelCount = 1], Dir.Fullname, dest],
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes));

  if Result then InitFileOp(foCopy);
end;


function TIconWindow.InitMove(const dest: string) : Boolean;
begin
  Result := not (ConfirmMoveStart and
    (MsgDialogResFmt(SQueryMoveItems,
       [Grid.SelCount, OneItem[Grid.SelCount = 1], Dir.Fullname, dest],
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes));

  if Result then InitFileOp(foMove);
end;



procedure TIconWindow.InitBlindFileOp(Op : TFileOperation; list : TFileList);
begin
  Desktop.SetCursor(crBusyPointer);
  NoToAll;
  ProgressBox.Init(Op, list.FileCount);
end;


procedure TIconWindow.DoneBlindFileOp;
begin
  ProgressBox.Hide;
  Desktop.ReleaseCursor;
  Desktop.RefreshNow;
  PlaySound(Sounds.Values['NotifyCompletion']);
  if Application.Active then SetFocus;
  NoToAll;
end;


function TIconWindow.InitBlindCopy(const source : TFilename; list : TFileList): Boolean;
begin
  Result := not (ConfirmCopyStart and
    (MsgDialogResFmt(SQueryCopyItems,
       [list.Count, OneItem[list.Count = 1], source, Dir.Fullname],
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes));

  if Result then InitBlindFileOp(foCopy, list);
end;


function TIconWindow.InitBlindMove(const source: TFilename; list : TFileList) : Boolean;
begin
  Result := not (ConfirmMoveStart and
    (MsgDialogResFmt(SQueryMoveItems,
       [list.Count, OneItem[list.Count = 1], source, Dir.Fullname],
       mtConfirmation, [mbYes, mbNo], 0) <> mrYes));

  if Result then InitBlindFileOp(foMove, list);
end;


function TIconWindow.InitDelete(const dest: string) : Boolean;
begin
  Result := not (ConfirmDelStart and
    (MsgDialogResFmt(SQueryDeleteItems,
      [Grid.Selcount, OneItem[Grid.SelCount = 1], dest],
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes));

  if Result then InitFileOp(foDelete);
end;


procedure TIconWindow.DropInFolder(const foldername : TFilename);
var
  i : Integer;
  path : TFilename;
begin
  { Copies or moves selected items from this window into a
    specified folder.  If the folder is being shown in an icon window,
    DropInWindow should be used instead. }

  path := MakePath(foldername);
  if path = Dir.Path then begin
    ErrorMsgRes(SCannotPutToSelf);
    Exit;
  end;

  case DragCopy of
    True : if not InitCopy(foldername) then exit;
    False: if not InitMove(foldername) then exit;
  end;
  try
    if DragCopy then
      for i := 0 to Selection.count-1 do TDirItem(Selection[i]).CopyToPath(path)
    else
      for i := 0 to Selection.Count-1 do TDirItem(Selection[i]).MoveToPath(path);
  finally
    if not DragCopy then Dir.Flush;
    DoneFileOp;
  end;
end;


procedure TIconWindow.DropInWindow(d : TDirectory);
var i: Integer;
begin
  { Copies or moves selected items from this window into another window,
    represented by its directory object }

  if d = Dir then begin
    ErrorMsgRes(SCannotPutToSelf);
    exit;
  end;

  if UseDescriptions and Simul4DOS then
    d.Desc.LoadFromPath(d.Path);

  case DragCopy of
    True : if not InitCopy(d.Fullname) then exit;
    False: if not InitMove(d.Fullname) then exit;
  end;

  try
    if DragCopy then
       for i := 0 to Selection.count-1 do TDirItem(Selection[i]).CopyToDirectory(d)
    else
       for i := 0 to Selection.count-1 do TDirItem(Selection[i]).MoveToDirectory(d);
  finally
    if not DragCopy then Dir.Flush;
    d.Flush;
    DoneFileOp;
  end;
end;



procedure TIconWindow.ObjectMenuPopup(Sender: TObject);
var
  valid : Boolean;
  IsFile : Boolean;
begin
  { Hide inappropriate menu items, depending on the currently
    "focused" object.  }

  valid := Selected <> nil;
  IsFile := Selected is TFileItem;

  Describe.Visible := UseDescriptions;
  Open.Visible := valid;
  OpenWith.Visible := IsFile;
  Inspect.Visible := IsFile and (InspectProg > '');
  Duplicate.Visible := Selected is TFile;
  AliasProp.Visible := Selected is TAlias;
  Properties.Visible := valid;
  Rename.Visible := valid;
  Delete.Visible := valid;
end;


procedure TIconWindow.OpenClick(Sender: TObject);
begin
  if Selected <> nil then Selected.Open;
end;


procedure TIconWindow.DeleteClick(Sender: TObject);
var i : Integer;
begin
  if DeleteToBin and not ((BinAction = baDelete) or (GetAsyncKeyState(VK_SHIFT) < 0)
     or (dfRemoveable in GetDriveFlags(Dir.Path[1]))) then begin
    Bin.FormDragDrop(Bin, Grid, 1, 1);
    Exit;
  end;

  if (Grid.SelCount > 0) and InitDelete(Dir.Fullname) then
  try
    for i := 0 to Selection.Count-1 do TDirItem(Selection[i]).Delete;
  finally
    Dir.Flush;
    DoneFileOp;
  end;
end;


procedure TIconWindow.CreateFolderClick(Sender: TObject);
var s: TFilename;
begin
  s := '';
  if InputQuery(LoadStr(SCreateFolder), LoadStr(SNewFolderName), s) then
    Dir.CreateFolder(Lowercase(s));
end;


procedure TIconWindow.DrawLasso(r: TRect);
begin
  { Draw the "column of marching ants" selection box, like the
    one used in Delphi's form editor.  PolyLine must be used for
    this effect -- MoveTo and LineTo don't work }

  with Grid.Canvas do begin
    Pen.Style := psDot;
    Pen.Mode := pmXor;
    PolyLine([Point(r.Left, r.Top), Point(r.Right, r.Top),
      Point(r.Right, r.Bottom), Point(r.Left, r.Bottom),
      Point(r.Left, r.Top)]);
  end;
end;


procedure TIconWindow.GridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  p : TPoint;
  r : TRect;
begin
  if not (ssDouble in Shift) then begin

    if Button = mbLeft then begin
      if (FileAt(X, Y, False) <> nil) and (Grid.SelCount > 0) then with Grid do begin
        { Start dragging when clicking over an icon }
        DragCopy := DefDragCopy xor (ssAlt in Shift);
        BeginDrag(False);
      end
      else with Grid do begin
        { Start lasso selection when clicking over empty space }
        Stretching := True;
        Update;
        Anchor := Point(X, Y);
        Corner := Anchor;
        with ClientRect do begin
          r.TopLeft := ClientToScreen(TopLeft);
          r.BottomRight := ClientToScreen(Bottomright);
          ClipCursor(@r);
        end;
      end;
    end

    else if Grid.Dragging then
      { Toggle move/copy when right clicking during file drag }
      DragCopy := not DragCopy

    else if not Stretching then with Grid do begin
      { Display appropriate context menu }
      GetCursorPos(p);
      if FileAt(X, Y, False) = nil then
        WinMenu.Popup(p.x, p.y)
      else begin
        AllowMulti := False;
        Select(MouseToCell(X, Y));
        AllowMulti := True;
        if SelCount > 0 then begin
          if ssAlt in Shift then Properties.Click
          else if ssCtrl in Shift then OpenWith.Click
          else if ssShift in Shift then Inspect.Click
          else ObjectMenu.Popup(p.x, p.y);
        end;
      end;
    end;
  end;
end;


procedure TIconWindow.FormDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Source <> Grid) and (Source <> Computer.Grid);
end;


procedure TIconWindow.OpenWithClick(Sender: TObject);
var s: TFilename;
begin
  if not (Selected is TFileItem) then exit;
  ShowHourGlass;
  s := TOpenFileDlg.Execute;
  if s > '' then OpenFileWith(Selected.Fullname, s);
end;


procedure TIconWindow.PropertiesClick(Sender: TObject);
begin
  if Grid.SelCount > 0 then begin
    ShowHourglass;
    with TFilePropDlg.Create(Application) do
    try
      if Grid.Selcount = 1 then SetItem(Selected)
      else SetItem(CompileSelection(True));
      ShowModal;
    finally
      Free;
    end;
  end;
end;


procedure TIconWindow.GridCellSelected(Sender: TObject; Index : Integer;
  IsSelected: Boolean);
var s: Longint;
begin
  { Called once for each selection or deselection in the grid.  If the
    user selects 100 files in one go, this is called 100 times, so keep
    the code short }

  if Index < Dir.Count then begin
    s := TDirItem(Dir[Index]).Size;
    if IsSelected then Inc(Selsize, s) else Dec(Selsize, s);
  end;
end;


procedure TIconWindow.RenameClick(Sender: TObject);
var s: TFilename;
begin
  if Selected <> nil then with Selected do begin
    s := Filename;
    if InputQuery(FmtLoadStr(SRename, [Filename]), LoadStr(SNewFilename), s) then begin
      if UseDescriptions and Simul4DOS then
        Dir.Desc.LoadFromPath(Dir.Path);
      Filename := Lowercase(s);
      Dir.Update;
    end;
  end;
end;


procedure TIconWindow.GridKeyPress(Sender: TObject; var Key: Char);
var
  c: Char;
  i, foc: Integer;
  found : Boolean;
  sel : Boolean;
begin
  case Key of
   { optimized Case statement in ascending order of ASCII value }

   ' ': if Grid.Focus < Dir.Count then begin
          { 2.11 fix }
          foc := Grid.Focus;
          sel := not Grid.Selected[foc];
          Grid.Selected[foc] := sel;
          UpdateStatusbar(False, True);
          if sel then
            Selected := TDirItem(Dir[foc])
          else
            Selected := nil;
        end;
   '*': Desktop.CloseOtherWindows(self);
   '+': Desktop.CloseLowerWindows(Dir.Fullname);
   ',': with Grid do { 2.12 }
          if SelCount = Dir.Count then DeselectAll else SelectAll;
   '-': Desktop.ClosePathWindows(Dir.Fullname);
   '.': with TIncSearchDlg.Create(Application) do
        try
          OnSearch := SearchFileHandler;
          ShowModal;
        finally
          Free;
        end;
   '/': Desktop.CloseWindows;
   '?': SetFilter.Click;
   'D': SortByDate.Click;
   'I': LargeIcons.Click;
   'L': ViewList.Click;
   'M': SmallIcons.Click;
   'N': SortByName.Click;
   'S': SortBySize.Click;
   'T': SortByType.Click;
   '\': Desktop.OpenFolder(Dir.Path[1] + ':\');

  else if not (Key in Uppers) then
    { Jump to the next object which begins with this character }

    with Dir do if Count > 1 then begin
      c := LowCase(Key);
      foc := Grid.Focus;
      i := (foc + 1) mod Count;

      while (i <> foc) and (LowCase(TDirItem(List^[i]).GetTitle[1]) <> c) do
        i := (i + 1) mod Count;

      if i <> foc then Grid.Select(i);
    end;
  end;
end;


procedure TIconWindow.FormDragDrop(Sender, Source: TObject; X, Y: Integer);
begin
  if Source is TMultiGrid then
    TIconWindow(TMultiGrid(Source).Owner).DropInWindow(Dir)

  else if Source = Bin.Listbox then
    Bin.RestoreTo(Dir.Fullname)

  else if Source = FindList then
    ProcessFiles(FindForm.CompileSelection, Dir.Fullname);
end;


procedure TIconWindow.RefreshWin;
begin
  try
    Dir.Scan;
    if not Locked then AutoResize;
    Arrange(self);
  except
    on EScanError do Close;
  end;
end;


procedure TIconWindow.RunClick(Sender: TObject);
begin
  if Selected <> nil then RunExecute(Selected.Filename, Dir.Fullname)
  else RunExecute('', Dir.Fullname);
end;


procedure TIconWindow.DropAsAliases(const foldername : TFilename);
var
  i: Integer;
begin
  ShowHourGlass;
  for i := 0 to Dir.Count-1 do
    if Grid.Selected[i] then
      with TDirItem(Dir[i]) do
        WriteAlias(MakePath(foldername) +
          ChangeFileExt(Filename, AliasExtension));
end;


procedure TIconWindow.SetFilterClick(Sender: TObject);
begin
  ShowHourglass;
  with TFilterDialog.Create(Application) do
  try
    if Execute(Dir) = mrOK then RefreshWin;
  finally
    Free;
  end;
end;


procedure TIconWindow.SortByTypeClick(Sender: TObject);
var item: TDirItem;
begin
  { Handles all "sorting" menu item events }
  with Sender as TMenuItem do
    if not Checked then begin
      { save focused item }
      item := nil;
      if Grid.Focus < Dir.Count then item := TDirItem(Dir.Items[Grid.Focus]);

      SetMenuCheck([SortByType, SortByName, SortBySize, SortByDate], Tag);
      Dir.SortOrder := TSortOrder(Tag);
      Dir.Sort;
      if item <> nil then Grid.Focus := Dir.IndexOf(item);
      Dir.Update;
      RefreshCursor;
    end;
end;


function TIconWindow.CompileSelection(recurse: Boolean): TFileList;
var i: Integer;
begin
  { Fills a TFileList with the current selection.  Recurse controls
    whether subdirectories have their content sizes counted.  Use
    this instead of the TDirectory object when items may be moved
    or deleted }

  Desktop.SetCursor(crHourGlass);
  with Selection do begin
    Clear;
    Capacity := max(Capacity, Grid.SelCount);
    Selection.DeepScan := recurse;
    for i := 0 to Dir.Count-1 do
      if Grid.Selected[i] then Selection.Add(Dir[i]);
  end;
  Desktop.ReleaseCursor;
  Result := Selection;
end;


procedure TIconWindow.MarkItems(IsCopy : Boolean);
var
  i: Integer;
begin
  FileClipboard.Clear;
  if Grid.SelCount > 0 then begin
    FileClipboardCopy := IsCopy;
    FileClipboard.Add(Dir.Path);
    for i := 0 to Dir.Count-1 do
      if Grid.Selected[i] then FileClipboard.Add(TDirItem(Dir.Items[i]).Filename);
  end;
end;

procedure TIconWindow.SelectFromClipboard;
var
  filename: string[12];
  i, index: Integer;
begin
  if FileClipboard.Count > 1 then begin
    Grid.DeselectAll;
    for i := 1 to FileClipboard.Count-1 do
      if Dir.Find(FileClipboard[i], index) then
        Grid.Selected[index] := True;
  end;
end;

procedure TIconWindow.PasteItems;
var
  path : TFilename;
  w : TIconWindow;
  SourceDir : TDirectory;
  SourceSelection : TFileList;
  i, index : Integer;
begin
  if FileClipboard.Count <= 1 then Exit;

  path := FileClipboard[0];
  if path = Dir.Path then begin
    ErrorMsgRes(SCannotPutToSelf);
    Exit;
  end;

  w := Desktop.WindowOf(ExtractFileDir(path));
  if w <> nil then begin
    w.SelectFromClipboard;
    w.DragCopy := FileClipboardCopy;
    w.DropInWindow(Dir);
    SetFocus;
    if not FileClipboardCopy then FileClipboard.Clear;
    Exit;
  end;

  { More complicated case - no existing window... }

  SourceDir := TDirectory.Create(path);
  SourceDir.Scan;

  SourceSelection := TFileList.Create;
  SourceSelection.DeepScan := True;

  for i := 1 to FileClipboard.Count-1 do
    if SourceDir.Find(FileClipboard[i], index) then
      SourceSelection.Add(SourceDir.Items[index]);

  case FileClipboardCopy of
    True : if not InitBlindCopy(SourceDir.Fullname, SourceSelection) then Exit;
    False: if not InitBlindMove(SourceDir.Fullname, SourceSelection) then Exit;
  end;

  try
    if FileClipboardCopy then
       for i := 0 to SourceSelection.count-1 do TDirItem(SourceSelection[i]).CopyToDirectory(Dir)
    else
       for i := 0 to SourceSelection.count-1 do TDirItem(SourceSelection[i]).MoveToDirectory(Dir);
  finally
    DoneBlindFileOp;
    SourceDir.Flush;
    Dir.Flush;
    SourceDir.Free;
    SourceSelection.Free;
  end;
end;


procedure TIconWindow.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  item : TMenuItem;
  s: TFilename;
  p: PChar;
begin
  { The grid can only have one PopupMenu property, so the window menu
    is searched manually for a shortcut match }
  s := '';
  item := WinMenu.FindItem(Shortcut(Key, Shift), fkShortcut);

  if item <> nil then item.Click
  else begin
    { Handle keyboard commands not in menus }

    if (Key = VK_BACK) and (Shift + [ssAlt] = [ssAlt]) then begin
      if Length(Dir.Path) > 3 then
        Desktop.OpenFolder(ExtractFileDir(Dir.Fullname))
      else
        Computer.ShowNormal;
    end

    else if (Shift = [ssCtrl, ssShift]) and (Chr(Key) in ValidDrives) then
      { Ctrl+Alt+Letter opens the root directory }
      Desktop.OpenFolder(LowCase(Chr(Key)) + ':\')

    else if Shift = [ssCtrl] then
      case key of
        Ord('A'): with Grid do
                    if SelCount = Dir.Count then DeselectAll else SelectAll;
        Ord('C'): MarkItems(True); { 2.2 }
        Ord('E'): OpenExplorer(Dir.Fullname);
        Ord('F'): FileFindExecute(Dir.Fullname);
        Ord('P'): begin
                    if Selected <> nil then s := Selected.Fullname;
                    if InputQuery(LoadStr(SPrintFile), LoadStr(SFilename), s) then
                      PrintFile(s);
                  end;
        Ord('O'): Computer.ExecuteMacro(self, '$Folder', '');
        Ord('S'): with TSelectFileDlg.Create(Application) do
                  try
                    OnSelectFiles := SelectFileHandler;
                    ShowModal;
                  finally
                    Free;
                  end;
        Ord('U'): DefaultExecCommand(UndeleteProg, Dir.Fullname, SW_SHOW);
        Ord('V'): PasteItems; { 2.2 }
        Ord('X'): MarkItems(False); { 2.2 }
        Ord('Z'): CopyToClipboard; { 2.2 moved to Ctrl+Z }
        VK_F5   : Desktop.Cascade;
      end

    else if (Shift = [ssShift]) then
      case key of
        VK_DELETE : Delete.Click;
        VK_F5     : Desktop.ArrangeIcons
      end

    else if (Shift = [ssAlt]) and (Key = Ord('W')) and Locked and (Explorer <> nil) then
      Explorer.SetFocus { 2.2 }

    else if Shift = [] then
      case Key of
        VK_F3   : FileFindExecute(Dir.Fullname);
        VK_F5   : RefreshWin;
        VK_F12  : Application.Minimize;
      end;
  end;
end;


procedure TIconWindow.WMSysCommand(var Msg: TWMSysCommand);
begin
  inherited;
  with Sounds do case Msg.CmdType and $FFF0 of
    SC_MINIMIZE: PlaySound(Values['WindowMinimize']);
    SC_MAXIMIZE: PlaySound(Values['WindowMaximize']);
    SC_CLOSE   : PlaySound(Values['WindowClose']);
    SC_RESTORE : PlaySound(Values['WindowRestore']);
  end;
end;


procedure TIconWindow.FormShow(Sender: TObject);
begin
  PlaySound(Sounds.Values['WindowOpen']);
  if IconWindowTask then Taskbar.AddButton(Handle);
end;


procedure TIconWindow.DuplicateClick(Sender: TObject);
var s: string;
begin
   if not (Selected is TFileItem) then exit;

   s := '';
   if InputQuery(FmtLoadStr(SDuplicateFile, [Selected.Filename]),
      LoadStr(SNewFilename), s) then begin
     (Selected as TFileItem).Duplicate(Lowercase(s));
     Dir.Update;
   end;
end;


procedure TIconWindow.GridDrawCell(Sender: TObject; Index: Integer;
  Rect: TRect; State: TGridDrawState);
begin
  TDirItem(Dir[Index]).Draw(Grid.Canvas, Rect);
end;

procedure TIconWindow.GridDrawSmall(Sender: TObject; Index: Integer;
  Rect: TRect; State: TGridDrawState);
begin
  TDirItem(Dir[Index]).DrawSmall(Grid.Canvas, Rect);
end;


procedure TIconWindow.GridDrawList(Sender: TObject; Index: Integer;
  Rect: TRect; State: TGridDrawState);
begin
  TDirItem(Dir[Index]).DrawAsList(Grid.Canvas, Rect)
end;


procedure TIconWindow.GridSelectCell(Sender: TObject; Index: Integer;
  var CanSelect: Boolean);
begin
  CanSelect := not Stretching;
end;


procedure TIconWindow.DropServerFileDrop(Sender: TObject; X, Y: Integer;
  Target: Word);
var i: Integer;
begin
  with DropServer.Files do begin
    if Grid.SelCount > 0 then
      for i := 0 to Dir.Count-1 do
        if Grid.Selected[i] then Add(TDirItem(Dir[i]).Fullname);

    if IsPrintManager(Target) and (Count > 0) then begin
      PrintFile(Strings[0]);
      Clear;
    end;
  end;
end;


procedure TIconWindow.TotalLabelMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if ssShift in Shift then SelLabelMouseDown(self, Button, Shift, X, Y)
  else if Button = mbRight then DiskPropExecute(Upcase(Dir.Path[1]));
end;


procedure TIconWindow.GridMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  r, s: TRect;
  i, count, topitem: Integer;
begin
  if Button <> mbLeft then exit;
  ClipCursor(nil);

  with Grid do begin
    count := Grid.SelCount;

    if Stretching then begin
      { Select files inside lasso }
      Stretching := False;
      R := NormalizeRect(Anchor, Corner);
      DrawLasso(R);
      topitem := Toprow * ColCount;
      for i := topitem to Min(Dir.Count,
       topitem + (VisibleColCount * (VisibleRowCount+1)))-1 do begin

        s := CellBounds(i);
        InflateRect(s, -16, -8);
        if Intersects(R, S) then Selected[i] := True;
      end;
    end;

    { Deselect when the user clicks in an empty area, provided that
      no new files were selected and a drag hasn't just finished }

    if (count = SelCount) and not DragJustEnded and
      (FileAt(X, Y, True) = nil) and (Dir.Count > 0) then
      DeselectAll;

    GridSelect(self, Focus);
  end;
  DragJustEnded := False;
end;


procedure TIconWindow.GridEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  DragJustEnded := True;
  DropServer.DragFinished;
end;


procedure TIconWindow.SelLabelMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  k: Word;
begin
  if Button = mbLeft then with Grid do
    if ssCtrl in Shift then begin
      for i := 0 to Dir.Count-1 do Selected[i] := not Selected[i];
      UpdateStatusbar(False, True);
    end
    else
      if SelCount = 0 then SelectAll
      else DeselectAll

  else if Button = mbRight then begin
    { fake a Ctrl+S shortcut }
    k := Ord('S');
    GridKeyDown(Grid, k, [ssCtrl]);
  end;
end;


procedure TIconWindow.GridMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
 if Grid.Dragging then begin
    if DropServer.CanDrop and AnimCursor then
      SetCursor(Screen.Cursors[crFlutter]);
 end
 else if Stretching then begin
    { erase previous lasso and redraw }
    DrawLasso(NormalizeRect(Anchor, Corner));
    Corner := Point(X, Y);
    DrawLasso(NormalizeRect(Anchor, Corner));
  end;
end;


procedure TIconWindow.DropClientDropFiles(Sender: TObject);
var target : TDirItem;
begin
  with DropClient do
  if (WindowState <> wsMinimized) and PtInRect(Grid.BoundsRect, DropPos) then begin

    target := FileAt(DropPos.x, DropPos.y, False);

    if (target <> nil) and target.AcceptsDrops then
      target.DragDrop(Files)
    else
      ProcessFiles(Files, Dir.Fullname)
  end
  else ProcessFiles(Files, Dir.Fullname)
end;


procedure TIconWindow.FolderRenamed(const previous, current: TFilename);
var s: TFilename;
begin
  { Search for the ancestor which has been renamed and change that
    part of the string to the new name }

  s := Dir.Fullname;
  if (previous = s) or IsAncestorDir(previous, s) then begin
    System.Delete(s, 1, Length(previous));
    Desktop.RemoveWindow(self);
    Dir.Path := current + s + '\';
    AssignCaption;
    Desktop.AddWindow(self);
  end;
end;


procedure TIconWindow.DropServerDeskDrop(Sender: TObject; X, Y: Integer;
  Target: Word);
begin
  if (Selected <> nil) and CanEditSettings { 2.2 } then
    Selected.CreateShortcut.MinPosition := Point(X - 16, Y - 16);
end;


procedure TIconWindow.WMNCRButtonDown(var Msg: TWMNCRButtonDown);
begin
  inherited;
  with Msg do
    if HitTest = HTSYSMENU then begin
      ConstructPathMenu;
      PathMenu.Popup(XCursor, YCursor);
    end;
end;


function TIconWindow.CompileFilenames: TStringList;
var i: Integer;
begin
  { Just returns a new list of filenames.  Compare CompileSelection method }
  Result := TStringList.Create;
  for i := 0 to Dir.Count-1 do
    if Grid.Selected[i] then Result.Add(TDirItem(Dir[i]).Fullname);
end;


procedure TIconWindow.SetDragCopy(copy: Boolean);
const
  DragCursors : array[Boolean, Boolean] of TCursor =
    ( (crDropFile, crDropMulti), (crDropCopy, crDropMultiCopy ));
begin
  { Sets the cursor shape depending on whether copy mode is on, and
    how many items are selected }

  FDragCopy := copy;
  with Grid do DragCursor := DragCursors[FDragCopy, SelCount > 1];
  RefreshCursor;
end;


procedure TIconWindow.FormDblClick(Sender: TObject);
const
  NewStates : array[TWindowState] of TWindowState =
    (wsMaximized, wsMinimized, wsNormal);
begin
  WindowState := NewStates[WindowState];
end;


procedure TIconWindow.GridSelect(Sender: TObject; Index: Integer);
begin
  { Called whenever the selection has changed }

  if (index < Dir.Count) and (Grid.SelCount > 0) then
    Selected := TDirItem(Dir[index])
  else begin
    Selected := nil;
    if Dir.Count = 0 then Grid.Focus := 0;
  end;

  UpdateStatusBar(False, True);
end;


procedure TIconWindow.InspectClick(Sender: TObject);
begin
  if (Selected is TFileItem) and (InspectProg > '') then
    OpenFileWith(Selected.Fullname, InspectProg);
end;


procedure TIconWindow.ChangeDir(const foldername : string);
begin
  if foldername = Dir.Fullname then exit;
  Desktop.RemoveWindow(self);
  Dir.Path := MakePath(foldername);
  AssignCaption;
  Desktop.AddWindow(self);
  RefreshWin;
  with Grid do begin
    if TopRow > 0 then begin
      Update;
      TopRow := 0;
    end;
    Focus := 0;
  end;
end;


procedure TIconWindow.ViewListClick(Sender: TObject);
begin
  with Sender as TMenuItem do
    if not Checked then
      SetMenuCheck([LargeIcons, SmallIcons, ViewList], Tag);

  with Grid do begin
    Visible := False;
    if ViewList.Checked then begin
      DefaultRowHeight := LineHeight;
      OnDrawCell := GridDrawList;
    end
    else if SmallIcons.Checked then begin
      DefaultRowHeight := LineHeight;
      OnDrawCell := GridDrawSmall;
    end
    else begin
      DefaultRowHeight := BrowseGrid.Y;
      OnDrawCell := GridDrawCell;
    end;

    if not Locked and (WindowState = wsNormal) then AutoResize
    else Resize;
    Visible := True;
    SetFocus;
  end;
end;


procedure TIconWindow.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var p: TPoint;
begin
  if Button = mbRight then begin
    GetCursorPos(p);
    WinMenu.Popup(p.X, p.Y);
  end;
end;


procedure TIconWindow.AliasPropClick(Sender: TObject);
begin
  if Selected is TAlias then TAlias(Selected).Edit;
end;


procedure TIconWindow.WMActivate(var Msg : TWMActivate);
begin
  inherited;
  if Msg.Active = WA_INACTIVE then Application.HintPause := NormalHintPause
  else Application.HintPause := HintDelay;
end;


procedure TIconWindow.FormHide(Sender: TObject);
begin
  if IconWindowTask then Taskbar.DeleteButton(Handle);
end;


procedure TIconWindow.DescribeClick(Sender: TObject);
var i: Integer;
begin
  if Grid.Selcount = 0 then Exit;

  if UseDescriptions and Simul4DOS then
    Dir.Desc.LoadFromPath(Dir.Path);

  ShowHourglass;
  CompileSelection(False);
  for i := 0 to Selection.count-1 do
    if not TDirItem(Selection[i]).EditDescription then Break;

  Dir.Desc.SaveToPath(Dir.Path);
  Grid.Invalidate;
end;


procedure TIconWindow.FileSystemClick(Sender: TObject);
begin
  ShowModalDialog(TFileSysPropDlg);
end;

procedure TIconWindow.SettingsChanged(Changes: TSettingChanges);
begin
  if [scSystem, scFileSystem, scDesktop, scDisplay] * Changes <> [] then
    Configure;
  if sc4DOS in Changes then RefreshWin;
end;


procedure TIconWindow.SelectFileHandler(Sender : TObject;
  const FileSpec : string; select : Boolean);
var i: Integer;
begin
  for i := 0 to Dir.Count-1 do
    if WildCardMatch(TDirItem(Dir[i]).Filename, FileSpec) then
      Grid.Selected[i] := select;
  GridSelect(self, Grid.Focus);
end;



procedure TIconWindow.GridDblClick(Sender: TObject);
begin
  if (GetAsyncKeyState(VK_SHIFT) < 0) and (Selected is TFolder) then
    OpenExplorer(Selected.Fullname)
  else
    Open.Click;
end;

procedure TIconWindow.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;


function MakeValidFilename(const s: TFilename): TFilename;
var i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    if not (s[i] in InvalidFilenameChars) then
      AppendStr(Result, s[i]);
end;


procedure TIconWindow.NewAliasClick(Sender: TObject);
const
  NewAliasKind : array[Boolean] of TReferenceKind =
    (rkFile, rkInternet);
var
  s: TFilename;
  Icon : TIcon;
  R : TReference;
begin
  ShowHourglass;
  R := TAliasReference.Create;
  with R do
  try
    Kind := NewAliasKind[Computer.BrowserLink.IsBrowserLoaded];

    if AssignFromExternal then begin
      s := MangleFilename(Dir.Path,
        MakeValidFilename(Copy(Caption, 1, 8)) + AliasExtension);
      if (ConfirmNewAlias or not (dfWriteable in GetDriveFlags(s[1]))) and
        not InputQuery(LoadStr(SCreateAlias), LoadStr(SAliasFilename), s) then Exit;

      Icon := TIcon.Create;
      try
        AssignIcon(Icon);
        TAlias.Store(s, R, Icon);
        Desktop.UpdateFileWindow(s);
      finally
        Icon.Free;
      end;
    end
  finally
    Free;
  end;
end;


procedure TIconWindow.UpdateStatusbar(TotalChanged, SelChanged: Boolean);
begin
  ShowingSelection := False;

  if (SelChanged and Narrow and (Grid.SelCount = 0)) or TotalChanged then
    TotalLabel.Caption :=
      Format(SSNumObjects,
        [Dir.Count, OneItem[Dir.Count = 1], FormatByte(Dir.Size, 2)]);

  if SelChanged then
    if Narrow and (Grid.SelCount > 0) then begin
      TotalLabel.Caption := Format(SelectionLabels[Grid.SelCount = 1],
        [Grid.SelCount, FormatByte(Selsize, 2)]);
      ShowingSelection := True;
    end
    else
      SelLabel.Caption := Format(SelectionLabels[Grid.SelCount = 1],
      [Grid.SelCount, FormatByte(Selsize, 2)]);
end;


procedure TIconWindow.TotalLabelClick(Sender: TObject);
begin
  if GetAsyncKeyState(VK_SHIFT) >= 0 then RefreshWin;
end;

procedure TIconWindow.WinMenuPopup(Sender: TObject);
begin
  SetFilter.Checked := Dir.Filter <> DefaultFilter;
end;

procedure TIconWindow.CopyToClipboard;
var
  strings: TStrings;
  i : Integer;
  s : string;
  details : TFileDetails;
  item : TDirItem;
begin
  if Grid.SelCount = 0 then
    Clipboard.AsText := Dir.Path + Dir.Filter

  else begin
    strings := TStringList.Create;
    try
      strings.Add(LoadStr(SDirectoryOf) + Dir.Fullname);

      if not ViewList.Checked then begin
        for i := 0 to Dir.Count-1 do
          if Grid.Selected[i] then
            strings.Add(TDirItem(Dir[i]).GetTitle)
      end

      else begin
        details := Dir.Columns;

        for i := 0 to Dir.Count-1 do
          if Grid.Selected[i] then begin
            item := TDirItem(Dir[i]);

            s := Format('%-12s', [item.Filename]);

            if fdSize in details then begin
              if item is TFolder then
                AppendStr(s, ' <DIR>     ')
              else
                AppendStr(s, Format(' %10s',
                  [FormatByte(item.Size, ListKBDecimals)]));
            end;

            if fdDate in details then
              AppendStr(s, Format(' %*s',
                [Length(SampleDate), DateToStr(item.TimeStamp)]));

            if fdTime in details then
              AppendStr(s,Format(' %*s',
                [Length(SampleTime), ShortTimeToStr(item.TimeStamp)]));

            if fdAttr in details then
              AppendStr(s, Format(' %-4s', [AttrToStr(item.Attr and not faDirectory)]));

            if UseDescriptions and (fdDesc in details) then
              AppendStr(s, ' ' + item.Description);

            strings.Add(s);
          end;
      end;

      CopyStringsToClipboard(strings);
    finally
      strings.Free;
    end;
  end;
end;

procedure TIconWindow.GotoItem(const filename: string);
var i: Integer;
begin
  if Dir.Find(filename, i) then with Grid do begin
    Select(i);
    Selected[i] := True;
  end;
end;

procedure TIconWindow.AssignCaption;
var
  folder, buf : string[79];
  des : TDescriptions;
begin
  folder := Dir.Fullname;
  TotalLabel.Hint := folder;

  buf := GlobalCaptions.Values[folder];

  if (buf = '') and DescCaptions and (Length(folder) > 3) then begin
    des := TDescriptions.Create;
    des.LoadFromPath(ExtractFilePath(folder));    { 2.11 fix }
    buf := des.Get(Extractfilename(folder), nil);
    des.Free;
  end;

  if ShortWinCaptions or (buf > '') then begin
    if buf = '' then begin
      if Length(folder) = 3 then
        buf := MakeDriveName(GuessDriveType(Dir.Path[1]), Dir.Path[1])
      else begin
        buf := ExtractFilename(folder);
        if UpcaseFirstChar then buf[1] := Upcase(buf[1]);
      end;
    end;
    Caption := buf;
  end
  else
    Caption := folder;
end;

procedure TIconWindow.SearchFileHandler(Sender : TObject; const s: string);
var
  i: Integer;
  cap : string[31];
  found : Boolean;
begin
  if s = '' then Exit;

  for i := 0 to Dir.Count-1 do begin
    if LargeIcons.Checked then cap := TDirItem(Dir[i]).GetTitle
    else cap := TDirItem(Dir[i]).Filename;

    if s[Length(s)] = ' ' then
      found := CompareText(Copy(s, 1, Length(s)-1), cap) = 0
    else
      found := Pos(s, Lowercase(cap)) = 1;

    if found then begin
      GotoItem(TDirItem(Dir[i]).Filename);
      Exit;
    end;
  end;
end;



procedure DoneIconWin; far;
begin
  FileClipboard.Free;
end;

initialization
  PathMenu := TPopupMenu.Create(Application);
  Xspare := GetSystemMetrics(SM_CYVSCROLL) + 13;
  Yspare := GetSystemMetrics(SM_CYCAPTION) + 29;
  SampleDate := DateToStr(EncodeDate(1997, 12, 12));
  SampleTime := ShortTimeToStr(EncodeTime(12, 0, 0, 0));
  FileClipboard := TStringList.Create;

  if Screen.PixelsPerInch > 96 then begin
    LabelTop := 2;
    LabelDiv := 170;
  end;
  AddExitProc(DoneIconWin);
end.
