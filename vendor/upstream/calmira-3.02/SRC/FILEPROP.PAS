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

unit FileProp;

{ File Properties dialog

  Displays details of files (and version information), folders or
  a combination.  The main call is SetItem(), which accepts either
  a TDirItem or a TFileList, and sets up the dialog appropriately.

  Translation note: the tabbed notebook page names must match
  the resource file.
}

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls,
  Buttons, StdCtrls, ExtCtrls, Directry, TabNotBk, Dialogs,
  LabelSel, Picbtn, TabPanel;

type
  TFilePropDlg = class(TForm)
    LabelSel: TLabelSelect;
    OpenDialog: TOpenDialog;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    Label5: TLabel;
    Bevel2: TBevel;
    ReadOnly: TCheckBox;
    Archive: TCheckBox;
    SystemFile: TCheckBox;
    Hidden: TCheckBox;
    Notes: TNotebook;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    FilenameLab: TLabel;
    LocationLab: TLabel;
    SizeLab: TLabel;
    DateLab: TLabel;
    Label10: TLabel;
    TypeLab: TLabel;
    Label6: TLabel;
    Foldername: TLabel;
    Label8: TLabel;
    FolderLoc: TLabel;
    Label16: TLabel;
    Foldersize: TLabel;
    Label21: TLabel;
    FolderDate: TLabel;
    Label23: TLabel;
    TotalLab: TLabel;
    Label7: TLabel;
    Label9: TLabel;
    Selfiles: TLabel;
    Selsize: TLabel;
    Bevel1: TBevel;
    Panel1: TPanel;
    ItemImage: TImage;
    Bevel3: TBevel;
    Header1: THeader;
    VerinfoList: TListBox;
    Bevel4: TBevel;
    AssocLabel: TLabel;
    rbRegistry: TRadioButton;
    AssocList: TComboBox;
    rbCommand: TRadioButton;
    UserCommand: TEdit;
    rbNothing: TRadioButton;
    procedure OKBtnClick(Sender: TObject);
    procedure ReadOnlyClick(Sender: TObject);
    procedure TotalLabClick(Sender: TObject);
    procedure VerinfoListDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure FormCreate(Sender: TObject);
    procedure Header1Sized(Sender: TObject; ASection, AWidth: Integer);
    procedure FoldernameMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure rbRegistryClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure AssocListChange(Sender: TObject);
    procedure UserCommandDblClick(Sender: TObject);
    procedure TabPanelChange(Sender: TObject; NewTab: Integer;
      var AllowChange: Boolean);
  private
    { Private declarations }
    Item: TObject;
    AttrChanged: Boolean;
    FileExt: TFileExt;
    AssocChanged: Boolean;
    FileTypes: TStringList;
    LongDateTime: string[63];
    ComboSaveIndex: Integer;
    procedure SetSingle;
    procedure SetFile;
    procedure SetFolder;
    procedure SetList;
    procedure ExtractVerInfo;
    procedure SetCheckBoxes(attr, gray: Integer);
    procedure SaveAttributes;
    procedure SaveAssociation;
    procedure BuildAssociations;
  public
    { Public declarations }
    procedure SetItem(AItem: TObject);
  end;

var
  FilePropDlg: TFilePropDlg;

implementation

{$R *.DFM}

uses SysUtils, Files, Strings, Resource, Settings, MiscUtil,
  FileCtrl, FileMan, Alias, FourDOS, ShellAPI, Locale, VerInfo;


procedure TFilePropDlg.SetCheckboxes(attr, gray: Integer);

procedure SetCheckBox(Checkbox: TCheckbox; mask: Integer);
begin
  with Checkbox do
  begin
    Checked := attr and mask <> 0;
    if gray and mask <> 0 then State := cbGrayed
    else AllowGrayed := False;
  end;
end;

begin
  SetCheckbox(ReadOnly, faReadOnly);
  SetCheckbox(Archive, faArchive);
  SetCheckbox(Hidden, faHidden);
  SetCheckbox(SystemFile, faSysFile);
end;

procedure TFilePropDlg.SetSingle;
begin
  with Item as TDirItem do
  begin
    ItemImage.Picture.Icon := Icon;
    SetCheckBoxes(Attr, 0);
  end;
end;

procedure TFilePropDlg.SetFile;
var
  s: string;
begin
  SetSingle;
  with Item as TFileItem do
  begin
    Notes.PageIndex := 0;
    FilenameLab.Caption := Filename;
    LocationLab.Caption := Dir.Fullname;
    DateLab.Caption := FormatDateTime(LongDateTime, TimeStamp);
    SizeLab.Caption := FormatByte(Size, 2);
    if Size > 1024 then with SizeLab do
    begin
      Hint := FormatByteLong(Size);
      Caption := Caption + Format('  (%s)', [Hint]);
    end;
    FileExt := Extension;
    if Item is TAlias then s:= 'Alias'
    else
    begin
      ini.ReadSectionValues('File Types', FileTypes);
      s := FileTypes.Values[FileExt];
    end;
    if s = '' then
    begin
      { query the registry }
      s := GetRegValue(GetRegValue('.' + FileExt));
      if s = '' then s := LoadStr(SUnknown);
    end;
    TypeLab.Caption := s;
    ExtractVerInfo;
  end;
end;

procedure TFilePropDlg.SetFolder;
begin
  SetSingle;
  with Item as TFolder do begin
    Notes.PageIndex := 1;
    Foldername.Caption := Filename;
    FolderLoc.Caption := Dir.Fullname;
    FolderDate.Caption := FormatDateTime(LongDateTime, TimeStamp);
    with DirInfo(Fullname, False) do
    begin
      FolderSize.Caption := FmtLoadStr(SFolderContents,
        [FormatByte(size, 2), files, OneItem[files = 1]]);
      if Size > 1024 then
        FolderSize.Hint := FormatByteLong(Size);
    end;
  end;
end;

procedure TFilePropDlg.SetList;
var
  i, gray, attr: Integer;
  f: TDirItem;
begin
  with Item as TFileList do
  begin
    Notes.PageIndex := 2;
    ItemImage.Picture.Icon := Icons.Get('MultiFile');
    Selfiles.Caption := FmtLoadStr(SSelectionContents, [FileCount,
      OneItem[FileCount = 1], FolderCount, OneItem[FolderCount = 1]]);
    Selsize.Caption := FormatByte(FileSize, 2);
    if FileSize > 1024 then
      Selsize.Hint := FormatByteLong(FileSize);
    { Determine which checkboxes should be grayed out }
    attr := TDirItem(Items[0]).Attr;
    gray := 0;
    for i := 1 to Count-1 do
    begin
       f := TDirItem(Items[i]);
       gray := gray or (f.Attr xor attr);
       attr := attr or f.Attr;
    end;
    SetCheckBoxes(attr, gray);
  end;
end;

procedure TFilePropDlg.SetItem(AItem: TObject);
begin
  Item := AItem;
  if Item is TFileItem then SetFile
  else if Item is TFolder then SetFolder
  else SetList;
  Caption := Notes.ActivePage;
  with NoteBook.Pages do
  begin
    if VerInfoList.Items.Count = 0 then Delete(IndexOf(LoadStr(SVersion)));
    if not (Item is TFileItem) or
      (FileExt = '') or ExtensionIn(FileExt, Programs) then
        Delete(IndexOf(LoadStr(SAssociation)));
  end;
  TabPanel.Tabs.Assign(Notebook.Pages); { 2.12 }
end;

procedure TFilePropDlg.SaveAttributes;
var
  i, attrib, gray: Integer;
begin
  attrib := Integer(ReadOnly.Checked) * faReadOnly or
            Integer(Archive.Checked) * faArchive or
            Integer(Hidden.Checked) * faHidden or
            Integer(SystemFile.Checked) * faSysFile;
  if Item is TDirItem then
    (Item as TDirItem).Attr := attrib
  else with Item as TFileList do
  begin
    gray := Integer(ReadOnly.State = cbGrayed) * faReadOnly or
            Integer(Archive.State = cbGrayed) * faArchive or
            Integer(Hidden.State = cbGrayed) * faHidden or
            Integer(SystemFile.State = cbGrayed) * faSysFile;
    for i := 0 to Count-1 do
      with TDirItem(Items[i]) do Attr := attrib or (gray and Attr);
  end;
end;

function SubstExtension(const source, ext: string): string;
var
  p: Integer;
begin
  Result := source;
  p := Pos('%1', Result);
  if p > 0 then
  begin
    Delete(Result, p, 2);
    Insert('^.' + ext, Result, p);
  end;
end;

procedure TFilePropDlg.SaveAssociation;
var
  filename   : array[0..79] of Char;
  ext        : array[0..7] of Char;
  subkey     : array[0..7] of Char;
  buf1, buf2 : array[0..79] of Char;
  fileclass  : string[63];
begin
  StrPCopy(filename, WinPath + 'win.ini');
  StrPCopy(ext, FileExt);
  subkey[0] := '.';
  StrCopy(@subkey[1], ext);
  case GetRadioIndex([rbRegistry, rbCommand, rbNothing]) of
    0: begin
         with AssocList do
         begin
           if ItemIndex = -1 then Exit;
           fileclass := PString(Items.Objects[ItemIndex])^;
         end;
         WritePrivateProfileString('Extensions', ext, StrPCopy(buf1,
           SubstExtension(GetRegValue(fileclass + '\shell\open\command'),
           FileExt)), filename);
         RegSetValue(HKEY_CLASSES_ROOT, subkey,
           REG_SZ, StrPCopy(buf2, fileclass), 0);
       end;
    1: begin
         if UserCommand.Text = '' then Exit;
         WritePrivateProfileString('Extensions', ext, StrPCopy(buf1,
           SubstExtension(UserCommand.Text, FileExt)), filename);
         RegSetValue(HKEY_CLASSES_ROOT, subkey, REG_SZ, '', 0);
         RegSetValue(HKEY_CLASSES_ROOT,
           StrPCopy(buf1, Format('.%s\shell\open\command', [FileExt])),
           REG_SZ, StrPCopy(buf2, UserCommand.Text), 0);
       end;
    2: begin
         WritePrivateProfileString('Extensions', ext, nil, filename);
         RegDeleteKey(HKEY_CLASSES_ROOT, subkey);
       end;
  end;
end;

procedure TFilePropDlg.OKBtnClick(Sender: TObject);
begin
  if AttrChanged then SaveAttributes;
  if AssocChanged then SaveAssociation;
end;

procedure TFilePropDlg.ReadOnlyClick(Sender: TObject);
begin
  AttrChanged := True;
end;

procedure TFilePropDlg.TotalLabClick(Sender: TObject);
begin
  ShowHourglass;
  with DirInfo((Item as TFolder).Fullname, True) do
  begin
    TotalLab.Caption := FmtLoadStr(STotalContents, [files, OneItem[files = 1],
      dirs, OneItem[dirs = 1], FormatByte(size, 2)]);
    TotalLab.Hint := FormatByteLong(Size);
  end;
  with TotalLab do
  begin
    OnClick := nil;
    OnMouseDown := FolderNameMouseDown;
    Cursor := crIBeam;
  end;
end;

procedure TFilePropDlg.ExtractVerInfo;
var
  Res: TVersion;

procedure AddField(FieldIdent: Word; const info: string);
begin
  if info > '' then
    VerInfoList.Items.Add(Format('%s¬%s', [LoadStr(FieldIdent), info]));
end;

begin
  try
    Res := TVersion.Create((Item as TFileItem).Fullname);
    if not Res.HasData then Exit;
    VerInfoList.Items.BeginUpdate;
    with Res do
    begin
      AddField(SProductName, ProductName);
      AddField(SLegalCopyright, LegalCopyright);
      AddField(SDescription, FileDescription);
      AddField(SType, FileType);
      AddField(SSubType, FileSubType);
      AddField(SFileOS, FileOS);
      AddField(SComments, Comments);
      AddField(SProductVersion, ProductVersion);
      AddField(SFileVersion, FileVersion);
      AddField(SCompany, CompanyName);
      AddField(SLegalTrademarks, LegalTrademarks);
      AddField(SInternalName, InternalName);
      AddField(SPrivateBuild, PrivateBuild);
      AddField(SSpecialBuild, SpecialBuild);
      AddField(SOriginalFilename, OriginalFilename);
    end;
    with VerInfoList do
    begin
      Canvas.Font := Font;
      Header1.SectionWidth[0] :=
        Canvas.TextWidth(LoadStr(SOriginalFilename)) + 8;
      Items.EndUpdate;
    end;
  finally
    Res.Free;
  end;
end;

procedure TFilePropDlg.VerinfoListDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  field: string[31];
  value: string;
begin
  with VerInfoList do
  begin
    Unformat(Items[Index], '%s¬%s', [@field, 31, @value, 255]);
    with Canvas do
    begin
      FillRect(Rect);
      TextOut(Rect.Left + 2, Rect.Top + 1, field);
      TextOut(Rect.Left + Header1.SectionWidth[0], Rect.Top + 1, value);
    end;
  end;
end;

procedure TFilePropDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;
  VerInfoList.ItemHeight := LineHeight;
  FileTypes := TStringList.Create;
  LongDateTime := ini.ReadString('File System',
    'LongDateTime', 'dddd d mmmm yyyy,  hh:mm am/pm');
end;

procedure TFilePropDlg.Header1Sized(Sender: TObject; ASection,
  AWidth: Integer);
begin
  VerInfoList.Invalidate;
end;

procedure TFilePropDlg.BuildAssociations;
var
  cb: Longint;
  buf: array[0..79] of Char;
  i, position: Longint;
  FileClass: string[79];
  ThisClass: string[79];
  OpenCommand: string[79];
  Entry: string[159];
begin
  ShowHourglass;
  AssocLabel.Caption := FmtLoadStr(SAssociateTypeWith, [FileExt]);
  rbNothing.Checked := True;
  FileClass := GetRegValue('.' + FileExt);
  if FileClass = '' then
  begin
    OpenCommand := GetRegValue(Format('.%s\shell\open\command', [FileExt]));
    if OpenCommand > '' then
    begin
      rbCommand.Checked := True;
      UserCommand.Text := OpenCommand;
    end;
  end;
  i := 0;
  cb := Sizeof(buf)-1;
  with AssocList do
  begin
    Items.BeginUpdate;
    while RegEnumKey(HKEY_CLASSES_ROOT, i, buf, cb) = ERROR_SUCCESS do
    begin
      ThisClass := StrPas(buf);
      if (ThisClass > '') and (ThisClass[1] <> '.') then
      begin
        Entry := GetRegValue(ThisClass);
        OpenCommand := GetRegValue(ThisClass + '\shell\open\command');
        if Entry > '' then
        begin
          if OpenCommand > '' then
            Entry := Format('%s   (%s)', [Entry, OpenCommand]);
          position := Items.AddObject(Entry, TObject(NewStr(ThisClass)));
        end;
      end;
      Inc(i);
      cb := Sizeof(buf)-1;
    end;
    Items.EndUpdate;
    for i := 0 to Items.Count-1 do
      if FileClass = PString(Items.Objects[i])^ then
      begin
        ItemIndex := i;
        rbRegistry.Checked := True;
        Exit;
      end;
  end;
  AssocChanged := False;
end;

procedure TFilePropDlg.FoldernameMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then LabelSel.Overlay(Sender as TLabel);
end;

procedure TFilePropDlg.rbRegistryClick(Sender: TObject);
begin
  AssocList.Enabled := rbRegistry.Checked;
  UserCommand.Enabled := rbCommand.Checked;
  AssocChanged := True;
end;

procedure TFilePropDlg.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  FileTypes.Free;
  if NoteBook.Pages.IndexOf(LoadStr(SAssociation)) > -1 then
  with AssocList do
    for i := 0 to Items.Count-1 do
      DisposeStr(PString(Items.Objects[i]));
end;

procedure TFilePropDlg.AssocListChange(Sender: TObject);
begin
  AssocChanged := True;
end;

procedure TFilePropDlg.UserCommandDblClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    UserCommand.Text := Lowercase(OpenDialog.Filename) + ' %1';
end;

procedure TFilePropDlg.TabPanelChange(Sender: TObject; NewTab: Integer;
  var AllowChange: Boolean);
begin
  { 2.12 association scanning code put in separate method. }
  if (Notebook.Pages[NewTab] = LoadStr(SAssociation)) then
  begin
    if AssocList.Items.Count = 0 then BuildAssociations
    else AssocList.ItemIndex := ComboSaveIndex;
  end
  else if Notebook.ActivePage = LoadStr(SAssociation) then
    ComboSaveIndex := AssocList.ItemIndex;
end;

end.

