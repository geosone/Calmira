{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-1999 Calmira Online!                               }
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

unit Strtprop;

{ Start Menu Properties Dialog

  The main control is a TOutline that contains a copy of the start
  menu.  Each outline node contains a pointer to a dynamic 255 char
  string that stores additional data.  The string size is fixed
  because TOutlineNode's Data property cannot be used easily with
  AssignStr, which requires a var parameter. }

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, Menus, Grids, Outline, TabNotBk, SysUtils, Chklist, StylSped,
  Scrtree, Messages, CalForm, Settings, ExtCtrls, TabPanel, Picbtn, Spin;

type
  TStartPropDlg = class(TCalForm)
    OutlineMenu: TPopupMenu;
    AddItem: TMenuItem;
    InsertItem: TMenuItem;
    EditItem: TMenuItem;
    DeleteItem: TMenuItem;
    ExpandItem: TMenuItem;
    CollapseItem: TMenuItem;
    N1: TMenuItem;
    Convert: TMenuItem;
    Modified: TCheckBox;
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    AddBtn: TStyleSpeed;
    InsertBtn: TStyleSpeed;
    EditBtn: TStyleSpeed;
    DeleteBtn: TStyleSpeed;
    ExpandBtn: TStyleSpeed;
    CollapseBtn: TStyleSpeed;
    ConvertBtn: TStyleSpeed;
    Outline: TScrollTree;
    Bevel1: TBevel;
    Label1: TLabel;
    Win31Menu: TRadioButton;
    Win95Menu: TRadioButton;
    NewStyles: TCheckList;
    PrefList: TCheckList;
    Label2: TLabel;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    Label3: TLabel;
    LrgItmHeight: TSpinEdit;
    Label4: TLabel; { 3.0 }
    procedure OutlineDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure OutlineDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure OutlineEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure OutlineMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure AddItemClick(Sender: TObject);
    procedure InsertItemClick(Sender: TObject);
    procedure EditItemClick(Sender: TObject);
    procedure DeleteItemClick(Sender: TObject);
    procedure ExpandItemClick(Sender: TObject);
    procedure CollapseItemClick(Sender: TObject);
    procedure ConvertClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure OutlineDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure CancelBtnClick(Sender: TObject);
    procedure OutlineDblClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure Win31MenuClick(Sender: TObject);
    procedure NewStylesClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure OutlineMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    {procedure ModifiedMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);} { 2.2 }
  private
    { Private declarations }
    DragItem: Longint;
    ProgramsMenu: Longint;
    CurrentGroup: Longint;
    {IconsChanged: Boolean;} { 2.2 }
    procedure ConvertProgItem(Sender: TObject; const group,
      caption: TFilename; const data: string);
    function AddOutlineNode(index : Longint; const cap, data: string;
      Op: TAttachMode): Longint;
    procedure DisposeNode(node: TOutlineNode);
    function MenuNodeAt(X, Y: Integer): Longint;
    procedure ProcessDDECommands;
    procedure DDECreateGroup(const s: string);
    procedure DDEShowGroup(const s: string);
    procedure DDEDeleteGroup(const s: string);
    procedure DDEAddItem(const Command, Caption, IconFile: TFilename;
      IconIndex, X, Y: Integer; Directory: TFilename);
    procedure DDEDeleteItem(const s: string);
    function FindChildNode(ParentNode: Longint; const caption: string): Longint;
  public
    { Public declarations }
    procedure Configure;
    procedure SettingsChanged(Changes: TSettingChanges); override;
  end;

var
  StartPropDlg: TStartPropDlg;
  NewStartItems: TStringList;
  ShellDDEBuf: TStringList;

implementation

{$R *.DFM}

uses Start, ProgConv, MenuEdit, MultiGrd, IconWin, Directry, Files,
  CompSys, MiscUtil, Dialogs, Strings, Desk, Resource, Locale, Task;

procedure TStartPropDlg.OutlineDragDrop(Sender, Source: TObject; X,
  Y: Integer);
const
  Attach: array[Boolean] of TAttachMode = (oaInsert, oaAddChild);
var
  dest: Longint;
  i: Integer;
begin
  Outline.DropFocus := -1;
  dest := Outline.GetItemAt(X, Y);
  { Handle drops from icon windows or from outline itself }
  if Source is TMultiGrid then
    with (TMultiGrid(Source).Owner as TIconWindow).CompileSelection(False) do
      for i := 0 to Count-1 do
        with TDirItem(Items[i]) do
          AddOutlineNode(dest, GetTitle, GetStartInfo, oaAddChild)
  else with Outline, Items[DragItem] do
  begin
    { Strange things seem to happen without BeginUpdate/EndUpdate! }
    BeginUpdate;
    if GetAsyncKeyState(VK_CONTROL) < 0 then
      AddOutlineNode(dest, Text, PString(Data)^,
        Attach[GetAsyncKeyState(VK_MENU) < 0])
    else
    begin
      Collapse;
      MoveTo(dest, Attach[GetAsyncKeyState(VK_MENU) < 0]);
    end;
    EndUpdate;
  end;
  Modified.State := cbGrayed; { 3.0 }
end;

procedure TStartPropDlg.OutlineDragOver(Sender, Source: TObject;
  X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := ((Sender = Source) or (Source is TMultiGrid) and
    (Source <> Computer.Grid)) and (Outline.GetItemAt(X, Y) > 0);
  with Outline do
    if not Accept or (State = dsDragLeave) then DropFocus := -1
    else DropFocus := GetCellAt(X, Y);
end;

procedure TStartPropDlg.OutlineEndDrag(Sender, Target: TObject;
  X, Y: Integer);
begin
  ClipCursor(nil);
end;

function TStartPropDlg.MenuNodeAt(X, Y : Integer): Longint;
var
  P: Integer;
begin
  Result := Outline.GetItem(X, Y);
  if Result > 0 then with Outline.Items[Result] do
  begin
    P := (Level - 1) { 3.0 } * 18 + 2;
    if HasItems and (X >= P) and (X <= P + 12) then Exit;
  end;
  Result := 0;
end;

procedure TStartPropDlg.OutlineMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  r: TRect;
  i: Longint;
  p: TPoint;
begin
  if ssDouble in Shift then Exit
  else if Button = mbRight then with Outline do
  begin
    { Select the item under the cursor and popup menu }
    if GetCaptureControl <> nil then Exit;
    i := GetItem(X, Y);
    if i > 0 then SelectedItem := i;
    GetCursorPos(p);
    OutlineMenu.Popup(p.X, p.Y);
  end
  else with Outline do
  begin
    DragItem := GetItem(X, Y);
    if (DragItem > 0) and (MenuNodeAt(X, Y) = 0) then
    begin
      with ClientRect do
      begin
        r.TopLeft := ClientToScreen(TopLeft);
        r.BottomRight := ClientToScreen(Bottomright);
        ClipCursor(@r);
      end;
      BeginDrag(False);
    end;
  end
end;

procedure TStartPropDlg.AddItemClick(Sender: TObject);
begin
  with MenuEditDlg do
    if EditItem(LoadStr(SAddMenuItem), '', ';;;;') = mrOK then
      AddOutlineNode(Outline.SelectedItem, CaptionEdit.Text, DataString, oaInsert);
end;

procedure TStartPropDlg.InsertItemClick(Sender: TObject);
begin
  with Outline, MenuEditDlg do
    if SelectedItem = 0 then AddItem.Click
    else if EditItem(LoadStr(SInsertMenuItem), '', ';;;;') = mrOK then
      AddOutlineNode(SelectedItem, CaptionEdit.Text, DataString, oaAddChild);
end;

procedure TStartPropDlg.EditItemClick(Sender: TObject);
var
  node: TOutlineNode;
begin
  ShowHourglass;
  with Outline, MenuEditDlg do
    if (SelectedItem > 0) then
    begin
      node := Items[SelectedItem];
      if EditItem(LoadStr(SMenuItemProperties), node.Text,
        PString(node.Data)^) = mrOK then
      begin
        PString(node.Data)^ := DataString;
        node.Text := CaptionEdit.Text;
        Modified.State := cbGrayed; { 3.0 }
      end;
    end;
end;

procedure TStartPropDlg.DisposeNode(node: TOutlineNode);
var
  i: Longint;
begin
  { Recursive procedure to free dynamic strings }
  Dispose(PString(node.Data));
  i := node.GetFirstChild;
  while i <> -1 do
  begin
    DisposeNode(Outline.Items[i]);
    i := node.GetNextChild(i);
  end;
end;

procedure TStartPropDlg.DeleteItemClick(Sender: TObject);
var
  node: TOutlineNode;
  i: Longint;
begin
  with Outline do
    if SelectedItem > 0 then
    begin
      node := Items[SelectedItem];
      if node.HasItems and (MsgDialogRes(SQueryDeleteMenu,
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes) then Exit;
      DisposeNode(node);
      DeleteSelectedNode;
      Modified.State := cbGrayed; { 3.0 }
    end;
end;

procedure TStartPropDlg.ExpandItemClick(Sender: TObject);
begin
  Outline.FullExpand;
end;

procedure TStartPropDlg.CollapseItemClick(Sender: TObject);
begin
  Outline.FullCollapse;
end;

procedure TStartPropDlg.ConvertClick(Sender: TObject);
begin
  ShowHourGlass;
  with TConvertDlg.Create(Application) do
  try
    OnConvertProg := ConvertProgItem;
    ShowModal;
  finally
    Free;
  end;
end;

procedure TStartPropDlg.ConvertProgItem(Sender: TObject;
  const group, caption: TFilename; const data: string);
var
  i, parentnode: Longint;
begin
  with Outline do
  begin
    { Find existing submenu containing the group }
    parentnode := GetTextItem(group);
    if parentnode = 0 then
    begin
      { Create a new group node and add the item to it }
      parentnode := AddOutlineNode(SelectedItem, group, ';;;;', oaAdd);
      AddOutlineNode(parentnode, caption, data, oaAddChild);
    end
    else
    begin
      { An existing group has been found.  Now look for a matching
        menu item, and update it if found.  Otherwise, just add
        another item }
      i := Items[parentnode].GetFirstChild;
      while i <> -1 do
        if CompareText(Items[i].Text, caption) = 0 then
        begin
          PString(Items[i].Data)^ := data;
          Exit;
        end
        else i := Items[parentnode].GetNextChild(i);
      AddOutlineNode(parentnode, caption, data, oaAddChild);
    end;
  end;
end;

procedure TStartPropDlg.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  { A menu editor dialog is created here to speed up editing }
  PrefList.Color := Colors[ccChecklist];
  Notebook.PageIndex := 0;
  MenuEditDlg := TMenuEditDlg.Create(Application);
  StartMenu.AssignToOutline(Outline);
  with NewStartItems do
  begin
    for i := 0 to Count-1 do AddOutlineNode(0, GetStrKey(Strings[i]),
      GetStrValue(Strings[i]), oaAdd);
    Clear;
  end;
  with Outline do
  begin
    SetUpdateState(False);
    Canvas.Font.Assign(Font);
    Canvas.Pen.Color := clGray;
  end;
  if StartMenu3D then Win95Menu.Checked := True
  else Win31Menu.Checked := True;
  LrgItmHeight.Value := LargeItemHeight; { 3.0 }
  NewStyles.SetData([LargeRootMenu, ColouredBar, BoldSelect]);
  PrefList.SetData([ShellStartup, StartMouseUp, ShellDDE, { 2.2 } Win95Keyboard]);
  PrefList.Hints.Assign(PrefList.Items); { 3.1 }
  LoadPosition(ini, 'Start Menu Properties');
  Configure;
  Modified.Checked := False;
  ProcessDDECommands;
  EnableControlList([OKBtn, Notebook], CanEditSettings); { 2.2 }
end;

function TStartPropDlg.AddOutlineNode(index: Longint;
  const cap, data : string; Op: TAttachMode): Longint;
var
  p: PString;
begin
  { Add a new outline node with a dynamic string as the Data }
  Modified.State := cbGrayed; { 3.0 }
  New(p);
  p^ := data;
  case Op of
    oaAdd      : Result := Outline.AddObject(index, cap, p);
    oaAddChild : Result := Outline.AddChildObject(index, cap, p);
    oaInsert   : Result := Outline.InsertObject(index, cap, p);
  end;
end;

procedure TStartPropDlg.OKBtnClick(Sender: TObject);
begin
  StartMenu3D := Win95Menu.Checked;
  LargeItemHeight := LrgItmHeight.Value; { 3.0 }
  NewStyles.GetData([@LargeRootMenu, @ColouredBar, @BoldSelect]);
  PrefList.GetData([@ShellStartup, @StartMouseUp, @ShellDDE, { 2.2 } @Win95Keyboard]);
  SaveStartProp;
  Taskbar.Configure;
  if not (Modified.State = (cbUnchecked)) { 3.0 } then
  begin
    YieldDuringLoad := True;
    Cursor := crHourglass;
    try
      EnableControls(False);
      DeleteFile(FileWritePath + 'bmpcache.bmp');
      if Modified.Checked then
        DeleteFile(FileWritePath + 'imgindex.dat'); { 3.0 }
      StartMenu.RebuildFromOutline(Outline);
    finally
      EnableControls(True);
      YieldDuringLoad := False;
      Cursor := crDefault;
      PlaySound(Sounds.Values['NotifyCompletion']);
    end;
  end;
  Close;
  AnnounceSettingsChanged([scStartMenu]);
end;

procedure TStartPropDlg.FormDestroy(Sender: TObject);
var
  i: Longint;
begin
  with Outline do
    for i := 1 to ItemCount do Dispose(PString(Items[i].Data));
  MenuEditDlg.Free;
  MenuEditDlg := nil;
  StartPropDlg := nil;
end;

procedure TStartPropDlg.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Action := caFree;
  SavePosition(ini, 'Start Menu Properties');
end;

procedure TStartPropDlg.OutlineDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  item: TOutlineNode;
  x, y: Integer;
  Focus: TRect;
begin
  { Fast outline drawing with no BrushCopy.  Unlike the tree view,
    (see TREE.PAS) there are no disadvantages here because all the
    pictures are square or rectangular, so no transparency is
    needed }
  with Outline do
  begin
    index := GetItem(0, Rect.Top);
    item := Items[index];
    x := Rect.Left + item.Level * 18 + 2;
    y := (Rect.Top + Rect.Bottom) div 2;
    with Canvas do begin
      Brush.Color := Color;
      FillRect(Rect);
      if odSelected in State then
      begin { 3.0 }
        Brush.Color := clHighlight;
        Font.Color := clHighlightText;
        Focus := Rect;
        Focus.Left := x + 18;
        Focus.Right := Focus.Left + TextWidth(item.Text) + 4;
        FillRect(Focus);
      end
      else Font.Color := clWindowText;
      if item.HasItems then
        if item.Expanded then Draw(x, Rect.Top + 1, PictureOpen)
        else Draw(x, Rect.Top + 1, PictureClosed)
      else Draw(x, Rect.Top + 1, PictureLeaf);
      if odSelected in State then DrawFocusRect(Focus);
      TextOut(x + 20, Rect.Top + 1, item.Text);
      { Draw horizontal line connecting node to branch }
      MoveTo(x - 2, y);
      Dec(x, 12);
      DottedLineTo(x, y);
      { Draw vertical line, it's length depending on whether
        this node has additional siblings }
      if Item.Parent.GetLastChild = Item.Index then
        DottedLineTo(x, Rect.Top-1)
      else if index = 1 then
        DottedLineTo(x, Rect.Bottom) { 3.0 }
      else
      begin
        MoveTo(x, Rect.Top);
        DottedLineTo(x, Rect.Bottom);
      end;
      { Draw a suitable plus/minus picture depending on if
        there are subitems }
      if Item.HasItems then
        if item.Expanded then
          {CopyRect(Bounds(x - 4, y - 4, 9, 9), BmpList.Canvas, PictureMinusRect)}
          Draw(x - 4, y - 4, PictureMinus)
        else
          {CopyRect(bounds(x - 4, y - 4, 9, 9), BmpList.Canvas, PicturePlusRect);}
          Draw(x - 4, y - 4, PicturePlus);
      { Loop back to the root through all parent nodes, drawing a
        vertical line if the parent has child nodes to be drawn
        below this node }
      item := item.Parent;
      while (Item <> nil) and (Item.Parent <> nil) do
      begin
        Dec(x, 18);
        if Item.Parent.GetLastChild > Item.Index then
        begin
          MoveTo(x, Rect.Top);
          DottedLineTo(x, Rect.Bottom);
        end;
        item := item.Parent;
      end;
    end;
  end;
end;

procedure TStartPropDlg.CancelBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TStartPropDlg.SettingsChanged(Changes: TSettingChanges);
begin
  if [scDesktop, scDisplay, scSystem] * Changes <> [] then Configure;
end;

procedure TStartPropDlg.Configure;
begin
  Outline.ThumbTracking := TrackThumb;
  Outline.ItemHeight := LineHeight;
end;

procedure TStartPropDlg.OutlineDblClick(Sender: TObject);
begin
  with Outline do
    if (SelectedItem > 0) and not Items[SelectedItem].HasItems then
      EditBtn.Click;
end;

procedure TStartPropDlg.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  CanClose := Controls[0].Enabled;
end;

procedure TStartPropDlg.Win31MenuClick(Sender: TObject);
begin
  NewStyles.Enabled := Win95Menu.Checked;
  LrgItmHeight.Enabled := Win95Menu.Checked;
  Modified.State := cbGrayed; { 3.0 }
end;

procedure TStartPropDlg.NewStylesClick(Sender: TObject);
begin
  if NewStyles.ItemIndex = 0 then begin
    Modified.State := cbGrayed; { 3.0 }
  end;
end;

procedure TStartPropDlg.FormResize(Sender: TObject);
begin
  StretchShift([HelpBtn, CancelBtn, OKBtn, Modified], [stLeft, stTop]);
  StretchShift([TabPanel { 2.12 }, Outline], [stWidth, stHeight]);
  StretchShift([Bevel1, PrefList], [stWidth]);
end;

procedure TStartPropDlg.OutlineMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  item: Longint;
begin
  if (Button = mbLeft) and not (ssDouble in Shift) then
  begin
    item := MenuNodeAt(X, Y);
    if item > 0 then with Outline.Items[item] do
      Expanded := not Expanded;
  end;
end;

function TStartPropDlg.FindChildNode(ParentNode: Longint; const caption: string): Longint;
var
  node: TOutlineNode;
begin
  with Outline do
  begin
    node := Items[ParentNode];
    Result := node.GetFirstChild;
    while Result <> -1 do
    begin
      if Items[Result].Text = caption then Exit
      else Result := node.GetNextChild(Result);
    end;
    Result := 0;
  end;
end;

procedure TStartPropDlg.DDECreateGroup(const s: string);
var
  item: Longint;
begin
  item := FindChildNode(ProgramsMenu, s);
  if item = 0 then item := AddOutlineNode(ProgramsMenu, s, '', oaAddChild);
  CurrentGroup := item;
end;

procedure TStartPropDlg.DDEShowGroup(const s: string);
var
  item: Longint;
begin
  item := FindChildNode(ProgramsMenu, s);
  if item > 0 then CurrentGroup := item;
end;

procedure TStartPropDlg.DDEDeleteGroup(const s: string);
var
  item: Longint;
begin
  item := FindChildNode(ProgramsMenu, s);
  if item > 0 then Outline.Delete(item);
end;

procedure TStartPropDlg.DDEAddItem(const Command, Caption, IconFile: TFilename;
  IconIndex, X, Y: Integer; Directory: TFilename);
begin
  if Directory = '' then Directory := ExtractFileDir(Command);
  AddOutlineNode(CurrentGroup, Caption, PackStartInfo(Command, Directory,
    IconFile, 0, IconIndex), oaAddChild);
end;

procedure TStartPropDlg.DDEDeleteItem(const s: string);
var
  item: Longint;
begin
  item := FindChildNode(CurrentGroup, s);
  if item > 0 then Outline.Delete(item);
end;

function GetStrParam(var s: string): TFilename;
var
  i: Integer;
begin
  if (s = '') or (s[1] = ')') or (s[1] = ']') then Result := ''
  else
  begin
    if s[1] = '"' then begin
      i := 2;
      while (i < Length(s)) and (s[i] <> '"') do Inc(i);
      Result := Copy(s, 2, i - 2);
      if (i < Length(s)) and (s[i + 1] = ',') then Inc(i);
    end
    else
    begin
      i := 1;
      while (i < Length(s)) and (s[i] <> ',') and (s[i] <> ')') do Inc(i);
      Result := Copy(s, 1, i - 1);
    end;
    Delete(s, 1, i);
  end;
end;

function GetIntParam(var s: string): Integer;
var
  i: Integer;
  field: string[15];
begin
  if (s = '') or (s[1] = ')') or (s[1] = ']') then Result := 0
  else
  begin
    i := 1;
    while (i < Length(s)) and ((s[i] in Digits) or (s[i] = '-')) do Inc(i);
    Result := StrToIntDef(Copy(s, 1, i - 1), 0);
    Delete(s, 1, i);
  end;
end;

const
  CommandPrefixes : array[0..5] of string[15] =
    ('[CreateGroup(', '[ShowGroup(', '[DeleteGroup(',
     '[AddItem(', '[ReplaceItem(', '[DeleteItem(');

function ParseCommand(var s: string): Integer;
var
  t: string[15];
begin
  for Result := 0 to High(CommandPrefixes) do
  begin
    t := Copy(s, 1, Length(CommandPrefixes[Result]));
    if CompareText(CommandPrefixes[Result], t) = 0 then
    begin
      Delete(s, 1, Length(CommandPrefixes[Result]));
      Exit;
    end;
  end;
  Result := -1;
end;

procedure TStartPropDlg.ProcessDDECommands;
var
  i,p : Integer;
  s: string;
begin
  ProgramsMenu := Outline.GetTextItem(ini.ReadString('Start menu',
    'ProgramsGroup', '&Programs'));
  if (ProgramsMenu <= 0) or (ShellDDEBuf.Count = 0) then
  begin
    { 2.12 }
    ShellDDEBuf.Clear;
    Exit;
  end;
  CurrentGroup := ProgramsMenu;
  i := 0;
  while i < ShellDDEBuf.Count do
  begin
    s := ShellDDEBuf[i];
    case ParseCommand(s) of
      0: DDECreateGroup(GetStrParam(s));
      1: DDEShowGroup(GetStrParam(s));
      2: DDEDeleteGroup(GetStrParam(s));
      3: DDEAddItem(GetStrParam(s), GetStrParam(s), GetStrParam(s),
           GetIntParam(s), GetIntParam(s), GetIntParam(s), GetStrParam(s));
      4: DDEDeleteItem(GetStrParam(s));
      5: DDEDeleteItem(GetStrParam(s));
    end;
    p := Pos('][', s);
    if p > 0 then
    begin
      Delete(s, 1, p);
      if s > '' then ShellDDEBuf.Insert(i + 1, s);
    end;
    Inc(i);
  end;
  ShellDDEBuf.Clear;
  Modified.State := cbGrayed;
end;

procedure DoneStartProp; far;
begin
  NewStartItems.Free;
  ShellDDEBuf.Free;
end;

initialization
  NewStartItems := TStringList.Create;
  ShellDDEBuf := TStringList.Create;
  AddExitProc(DoneStartProp);
end.

