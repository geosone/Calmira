{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.0                                                    }
{    Copyright (C) 1997  Li-Hsin Huang                                     }
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

unit FileFind;

{ Find dialog

  Performs a recursive background search for the specified files,
  and adds the file details to a multi-column list box.  The fields
  are encoded and unformatted in the DrawItem handler.  This limits
  the number of entries, so for a greater capacity, consider moving
  the data into a TStringList and just adding null fields in the
  listbox (the string list probably uses more memory because it
  allocates lots of small blocks).

  The listbox is a drag-drop source, and has a separate global
  variable pointing to it.  This is so that drag-drop targets can
  check the source without dereferencing the FindForm variable,
  whieh may be nil when the dialog is not open.
}

interface

uses WinTypes, WinProcs, Classes, Forms, Controls, Buttons, CalForm,
  StdCtrls, ExtCtrls, SysUtils, Menus, DragDrop, DropServ, Graphics,
  TabNotBk, Settings;

type
  TFindForm = class(TCalForm)
    CloseBtn: TBitBtn;
    SearchBtn: TBitBtn;
    ClearBtn: TBitBtn;
    Header: THeader;
    Menu: TPopupMenu;
    OpenParent: TMenuItem;
    Delete: TMenuItem;
    DropServer: TDropServer;
    Open: TMenuItem;
    N1: TMenuItem;
    Listbox: TListBox;
    FoundLabel: TLabel;
    SelLabel: TLabel;
    Notebook: TTabbedNotebook;
    Label1: TLabel;
    FileEdit: TComboBox;
    Label2: TLabel;
    StartEdit: TComboBox;
    N2: TMenuItem;
    CopyFilenames: TMenuItem;
    CopyFileInfo: TMenuItem;
    Bevel3: TBevel;
    Image: TImage;
    SubFolders: TCheckBox;
    OpenWith: TMenuItem;
    procedure SearchBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure ClearBtnClick(Sender: TObject);
    procedure ListboxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure HeaderSized(Sender: TObject; ASection, AWidth: Integer);
    procedure FormDestroy(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
    procedure OpenParentClick(Sender: TObject);
    procedure MenuPopup(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure DropServerFileDrop(Sender: TObject; X, Y: Integer;
      Target: Word);
    procedure ListboxMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure ListboxEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure OpenClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure StartEditKeyPress(Sender: TObject; var Key: Char);
    procedure ListboxClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure StartEditDblClick(Sender: TObject);
    procedure CopyFilenamesClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormResize(Sender: TObject);
    procedure OpenWithClick(Sender: TObject);
  private
    { Private declarations }
    Searching: Boolean;
    FSelection: TStringList;
    LocStart, SizeStart, DateStart: Integer;
    Changed : Boolean;
    FileSpecs : TStringList;
    SearchCount : Integer;
    procedure SearchFiles(const StartPath: TFilename);
    procedure ExtractSearchMasks;
    procedure UpdateStatusBar;
  public
    { Public declarations }
    function CompileSelection: TStringList;
    procedure SettingsChanged(Changes : TSettingChanges); override;
    function FilenameAt(i: Integer) : TFilename;
    function IsFile(i: Integer): Boolean;
    property Selection : TStringList read FSelection;
  end;

  EFindError = class(Exception);

var
  FindForm: TFindForm;
  FindList: TListBox;

procedure FileFindExecute(const StartPath : string);

implementation

{$R *.DFM}

uses Dialogs, Resource, Strings, MiscUtil, Tree, IconWin, OpenFile,
  Fileman, Drives, Desk, FileCtrl, Files, Directry, Locale, Embed;


procedure TFindForm.ExtractSearchMasks;
var specs : TFilename;
begin
  specs := RemoveSpaces(FileEdit.Text);
  FileSpecs.Clear;
  if specs > '' then
    repeat FileSpecs.Add(GetWord(specs, ';')) until specs = '';
end;


procedure TFindForm.UpdateStatusBar;
begin
  FoundLabel.Caption := Format(SSItemsFound, [Listbox.Items.Count]);
  SelLabel.Caption := Format(SSFoundSelected, [Listbox.SelCount]);
end;


procedure TFindForm.SearchBtnClick(Sender: TObject);
begin
  if Searching then begin
    Searching := False;
    Exit;
  end;

  with StartEdit do begin
    case Length(Text) of
      0   : Text := 'c:\';
      1..2: Text := Text[1] + ':\';
      else Text := MakePath(Lowercase(Text));
    end;
  end;
  ExtractSearchMasks;
  if FileSpecs.Count = 0 then raise EFindError.CreateRes(SSpecifyFiles);

  Changed := AddHistory(FileEdit) or Changed;
  Changed := AddHistory(StartEdit) or Changed;

  Searching := True;
  Inc(SearchCount);

  SearchBtn.Caption := LoadStr(SStopSearch);
  CloseBtn.Enabled := False;
  ClearBtn.Enabled := False;
  Listbox.Enabled := True;
  Desktop.SetCursor(crBusyPointer);

  try
    SearchFiles(StartEdit.Text);
  finally
    Searching := False;
    SearchBtn.Caption := LoadStr(SStartSearch);
    CloseBtn.Enabled := True;
    ClearBtn.Enabled := True;
    Listbox.Items.EndUpdate;
    Desktop.ReleaseCursor;

    PlaySound(Sounds.Values['NotifyCompletion']);
    if Listbox.Items.Count = 0 then begin
      if Application.Active then
        MsgDialogRes(SNoMatchingFiles, mtInformation, [mbOK], 0);
      Listbox.Enabled := False;
    end
    else Listbox.Enabled := True;
    UpdateStatusBar;
  end;
end;



{ buffers which are kept off the stack }

var
  ListEntry : string;
  SizeStr : string[15];

procedure TFindForm.SearchFiles(const StartPath: TFilename);
var
  rec: TSearchRec;
  code, i : Integer;
  icon : TIcon;
begin
  Application.ProcessMessages;
  if not Searching or Application.Terminated then Abort;

  for i := 0 to FileSpecs.Count-1 do begin

  { loop through wildcards }
  code := FindFirst(StartPath + FileSpecs[i], faAnyFile and not faVolumeID, rec);

  while code = 0 do begin
    if rec.name[1] <> '.' then begin

      rec.name := Lowercase(rec.name);

      if rec.attr and faDirectory > 0 then
        icon := TinyFolder
      else if ExtensionIn(Copy(ExtractFileExt(rec.name), 2, 3), programs) then
        icon := TinyProg
      else
        icon := TinyFile;


      if rec.attr and faDirectory > 0 then SizeStr := '<DIR>'
      else SizeStr := FormatByte(rec.size, ListKBDecimals);

      ListEntry := Format('%s;%s;%s;%s', [rec.name, MakeDirname(StartPath),
        sizestr, DateToStr(TimestampToDate(rec.time))]);

      try
        with Listbox.Items do
          if ((FileSpecs.Count = 1) and (SearchCount = 1)) or
            (IndexOf(ListEntry) = -1) then begin
              AddObject(ListEntry, icon);
            if Count mod 20 = 0 then UpdateStatusbar;
          end;
      except
        on EOutOfResources do begin
          MsgDialogRes(SFindListboxFull, mtInformation, [mbOK], 0);
          Abort;
        end;
      end;
    end;
    Application.ProcessMessages;
    code := FindNext(rec);
  end;

  end;

  if SubFolders.Checked then begin
    { search subdirs }
    code := FindFirst(StartPath + '*.*', faDirectory, rec);
    while code = 0 do begin
      if (rec.Attr and faDirectory <> 0) and (rec.name[1] <> '.') then
        SearchFiles(StartPath + Lowercase(rec.name) + '\');
      Application.ProcessMessages;
      code := FindNext(rec);
    end;
  end;
end;



procedure TFindForm.FormCreate(Sender: TObject);
begin
  Icon.Assign(Icons.Get('FindDialog'));
  Image.Picture.Icon.Assign(Icon);
  CloseBtn.Cancel := True;
  Searching := False;
  Listbox.DragCursor := crDropFile;
  FSelection := TStringList.Create;
  FileSpecs := TStringList.Create;
  FileSpecs.Duplicates := dupIgnore;
  FindList := Listbox;
  Listbox.ItemHeight := LineHeight;
  LoadPosition(ini, 'Find Dialog');
  ini.ReadStrings('Search for', FileEdit.Items);
  ini.ReadStrings('Start from', StartEdit.Items);
  ini.ReadHeader('Find Dialog', Header);
  HeaderSized(Header, 0, Header.SectionWidth[0]);
end;


procedure TFindForm.CloseBtnClick(Sender: TObject);
begin
  Close;
end;


procedure TFindForm.ClearBtnClick(Sender: TObject);
begin
  with Listbox do begin
    Items.Clear;
    UpdateStatusBar;
    Enabled := False;
    SearchCount := 0;
  end;
end;

procedure TFindForm.ListboxDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  filename: string[15];
  location: TFilename;
  size    : string[15];
  date    : string[15];
begin
  with Listbox, Listbox.Canvas do begin
    FillRect(Rect);

    if FindDlgIcons then begin
      Draw(Rect.Left, Rect.Top, TIcon(Items.Objects[Index]));
      Inc(Rect.Left, 20);
    end;

    Inc(Rect.Top);
    Unformat(Items[Index], '%s;%s;%s;%s',
      [@filename, 15, @location, 79, @size, 15, @date, 15]);

    TextOut(Rect.Left + 2, Rect.Top, filename);
    TextOut(LocStart, Rect.Top, MinimizeName(location, Canvas, SizeStart - LocStart));
    TextOut(DateStart-10-TextWidth(size), Rect.Top, size);
    TextOut(DateStart, Rect.Top, date);
  end;
end;


procedure TFindForm.HeaderSized(Sender: TObject; ASection,
  AWidth: Integer);
begin
  with Header do begin
    LocStart := SectionWidth[0];
    SizeStart := LocStart + SectionWidth[1];
    DateStart := SizeStart + SectionWidth[2];
  end;
  Listbox.Invalidate;
end;


function TFindForm.FilenameAt(i: Integer): TFilename;
var
  name: string[15];
  location : TFilename;
begin
  { The listbox stores the name and location the wrong way around...}
  Unformat(Listbox.Items[i], '%s;%s;', [@name, 15, @location, 79]);
  Result := MakePath(location) + name;
end;

function TFindForm.IsFile(i: Integer): Boolean;
begin
  Result := Listbox.Items.Objects[i] <> TinyFolder;
end;


function TFindForm.CompileSelection: TStringList;
var
  i: Integer;
begin
  FSelection.Clear;
  for i := 0 to Listbox.Items.Count-1 do
    if Listbox.Selected[i] then FSelection.Add(FilenameAt(i));
  Result := FSelection;
end;


procedure TFindForm.FormDestroy(Sender: TObject);
begin
  ini.WriteHeader('Find Dialog', Header);

  if Changed then begin
    ini.RewriteSectionStrings('Search for', FileEdit.Items);
    ini.RewriteSectionStrings('Start from', StartEdit.Items);
  end;

  FSelection.Free;
  FileSpecs.Free;
  FindList := nil;
  FindForm := nil;
end;



procedure TFindForm.DeleteClick(Sender: TObject);
var
  i: Integer;
  s: TFilename;
begin
  if not Searching then with Listbox do begin
    NoToAll;
    i := 0;
    Items.BeginUpdate;
    Desktop.SetCursor(crHourGlass);
    try
      for i := Items.Count-1 downto 0 do
        if Selected[i] then begin
          if GetAsyncKeyState(VK_ESCAPE) < 0 then Break;
          s := FilenameAt(i);
          if IsFile(i) and EraseFile(s, -1) then begin
            Items.Delete(i);
            Desktop.RefreshList.Add(ExtractFileDir(s));
          end
        end;
    finally
      Desktop.RefreshNow;
      Desktop.ReleaseCursor;
      Items.EndUpdate;
      Enabled := Items.Count > 0;
      UpdateStatusBar;
    end;
  end;
end;


procedure TFindForm.OpenParentClick(Sender: TObject);
var
  folder, filename: TFilename;
  w: TIconWindow;
begin
  with Listbox do
  if ItemIndex <> -1 then begin
    filename := FilenameAt(ItemIndex);
    folder := ExtractFileDir(filename);
    Desktop.OpenFolder(folder);
    w := Desktop.WindowOf(folder);
    if w <> nil then w.GotoItem(ExtractFilename(filename));
  end;
end;


procedure TFindForm.MenuPopup(Sender: TObject);
begin
  Open.Enabled := Listbox.ItemIndex <> -1;
  OpenWith.Enabled := Open.Enabled and IsFile(Listbox.ItemIndex);
  OpenParent.Enabled := Open.Enabled;
  Delete.Enabled := Open.Enabled;
end;


procedure TFindForm.FormShow(Sender: TObject);
begin
  if StartEdit.Text = '' then
    StartEdit.Text := Copy(CurrentDirectory, 1, 3);
  ActiveControl := FileEdit;
end;


procedure TFindForm.DropServerFileDrop(Sender: TObject; X, Y: Integer;
  Target: Word);
begin
  with DropServer.Files do begin
    Assign(CompileSelection);
    if IsPrintManager(Target) and (Count > 0) then begin
      PrintFile(Strings[0]);
      Clear;
    end;
  end;
end;


procedure TFindForm.ListboxMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if Listbox.Dragging and DropServer.CanDrop and AnimCursor then
    SetCursor(Screen.Cursors[crFlutter])
end;


procedure TFindForm.ListboxEndDrag(Sender, Target: TObject; X,
  Y: Integer);
begin
  DropServer.DragFinished;
end;


procedure TFindForm.OpenClick(Sender: TObject);
var
  s: TFilename;
begin
  with Listbox do
  if ItemIndex <> -1 then begin
    s := FilenameAt(ItemIndex);
    if Items.Objects[ItemIndex] = TinyFolder then Desktop.OpenFolder(s)
    else DefaultExec(s, '', ExtractFileDir(s), SW_SHOW);
  end;
end;


procedure TFindForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  SavePosition(ini, 'Find Dialog');
end;


procedure FileFindExecute(const StartPath : string);
begin
  ShowHourglass;
  if FindForm = nil then FindForm := TFindForm.Create(Application);

  with FindForm do begin
    AssignHistoryText(FileEdit, '');
    AssignHistoryText(StartEdit, Lowercase(StartPath));
    WindowState := wsNormal;
    Show;
  end;
end;


procedure TFindForm.StartEditKeyPress(Sender: TObject; var Key: Char);
begin
  Key := LowCase(Key);
end;


procedure TFindForm.ListboxClick(Sender: TObject);
begin
  UpdateStatusBar;
end;


procedure TFindForm.FormPaint(Sender: TObject);
var
  R: TRect;
begin
  Border3D(Canvas, ClientWidth-1, ClientHeight-1);
  R := Rect(4, Listbox.Top + Listbox.Height + 3,
    SelLabel.Left - 10, ClientHeight - 3);
  RecessBevel(Canvas, R);
  R.Left := R.Right + 3;
  R.Right := ClientWidth - 3;
  RecessBevel(Canvas, R);
  Canvas.Draw(ClientWidth-17, ClientHeight-17, Sizebox);
end;


procedure TFindForm.StartEditDblClick(Sender: TObject);
begin
  SubFolders.Checked := True;
  StartEdit.Text := SelectFolder(StartEdit.Text);
end;


procedure TFindForm.SettingsChanged(Changes : TSettingChanges);
begin
  if scFileSystem in Changes then Listbox.Invalidate;

  if scSystem in Changes then begin
    ini.ReadNewStrings('Search for', FileEdit.Items);
    ini.ReadNewStrings('Start from', StartEdit.Items);
  end;
end;

procedure TFindForm.CopyFilenamesClick(Sender: TObject);
var
  strings  : TStringList;
  filename : string[15];
  location : TFilename;
  size     : string[15];
  date     : string[15];
  i        : Integer;
  locwidth : Integer;
begin
  strings := TStringList.Create;
  try
    locwidth := Header.SectionWidth[1] div Canvas.TextWidth('n');

    with Listbox do
      for i := 0 to Items.Count-1 do
        if Selected[i] then
          if LongBool(TComponent(Sender).Tag) then begin
            Unformat(Items[i], '%s;%s;%s;%s',
             [@filename, 15, @location, 79, @size, 15, @date, 15]);
            strings.Add(Format('%-12s %-*s %10s %s',
              [filename, locwidth, location, size, date]));
          end
          else
            strings.Add(FilenameAt(i));

    CopyStringsToClipboard(strings);
  finally
    strings.Free;
  end;
end;

procedure TFindForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not Searching;
end;

procedure TFindForm.FormResize(Sender: TObject);
begin
  Invalidate;
  StretchShift([Notebook, Header, FileEdit, StartEdit], [stWidth]);
  StretchShift([SearchBtn, ClearBtn, CloseBtn], [stLeft]);
  StretchShift([Bevel3, Listbox], [stWidth, stHeight]);
  StretchShift([FoundLabel, SelLabel], [stTop]);
end;

procedure TFindForm.OpenWithClick(Sender: TObject);
var s: TFilename;
begin
  with Listbox do
    if (ItemIndex > -1) and IsFile(ItemIndex) then begin
    ShowHourGlass;
    s := TOpenFileDlg.Execute;
    if s > '' then OpenFileWith(FilenameAt(ItemIndex), s);
  end;
end;

end.
