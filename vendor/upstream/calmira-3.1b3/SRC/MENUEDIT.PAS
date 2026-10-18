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

unit MenuEdit;

{ Start menu item editor

  This dialog accepts input through the EditItem procedure.  After
  the modal state is finished, the edited data can be retrieved
  through the DataString function }

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, ExtCtrls, Dialogs,
  StylSped, Icondlg, SysUtils, TabNotBk, TabPanel, Picbtn;

type
  TMenuEditDlg = class(TForm)
    IconDialog: TIconDialog;
    OpenDialog: TOpenDialog;
    TabPanel1: TTabPanel;
    Notebook: TNotebook;
    Label1: TLabel;
    CaptionEdit: TEdit;
    Label2: TLabel;
    CommandEdit: TComboBox;
    Label3: TLabel;
    FolderEdit: TEdit;
    Label5: TLabel;
    BrowseIcon: TStyleSpeed;
    IconEdit: TEdit;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    BrowseFolder: TStyleSpeed;
    BrowseCommand: TStyleSpeed;
    ShowCombo: TComboBox;
    Label4: TLabel;
    Bevel1: TBevel;
    Bevel2: TBevel;
    TargetIcon: TImage;
    CaptionLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BrowseCommandClick(Sender: TObject);
    procedure BrowseFolderClick(Sender: TObject);
    procedure BrowseIconClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure CaptionEditExit(Sender: TObject);
    procedure IconEditExit(Sender: TObject);
  private
    { Private declarations }
    SaveHistory: Boolean;
    Procedure SetIcon(const filename: TFilename; index: Integer);
  public
    { Public declarations }
    function DataString: string;
    function EditItem(const prompt, captext, data: string): TModalResult;
  end;

var
  MenuEditDlg: TMenuEditDlg;

implementation

{$R *.DFM}

uses Graphics, FileCtrl, ShellAPI, Strings, Settings, Start, MiscUtil,
  WinProcs, WinTypes, Tree, RefEdit, Locale, Resource;

procedure TMenuEditDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;
  ini.ReadStrings('IconSources', IconDialog.HistoryList);
  { 3.1 }
  BrowseCommand.Glyph.Handle := LoadBitmap(HInstance, 'BROWSEBMP');
  BrowseIcon.Glyph.Handle := LoadBitmap(HInstance, 'BROWSEBMP');
  BrowseFolder.Glyph.Handle := LoadBitmap(HInstance, 'BROWSEBMP');
end;

procedure TMenuEditDlg.FormDestroy(Sender: TObject);
begin
  if SaveHistory then
    ini.RewriteSectionStrings('IconSources', IconDialog.HistoryList);
  MenuEditDlg := nil;
end;

procedure TMenuEditDlg.BrowseCommandClick(Sender: TObject);
var
  lctext: string;
begin
  with CommandEdit do
  begin
    lctext := Lowercase(Text);
    if Pos('$folder', lctext) = 1 then
      Text := '$Folder ' + SelectFolder(Copy(Text, 9, 255))
    else if Pos('$largeiconfolder', lctext) = 1 then
      Text := '$LargeIconFolder ' + SelectFolder(Copy(Text, 18, 255))
    else if Pos('$smalliconfolder', lctext) = 1 then
      Text := '$SmallIconFolder ' + SelectFolder(Copy(Text, 18, 255))
    else if Pos('$listfolder', lctext) = 1 then
      Text := '$ListFolder ' + SelectFolder(Copy(Text, 13, 255))
    else
      if OpenDialog.Execute then
      begin
        Text := Lowercase(OpenDialog.Filename);
        IconEditExit(Self); { 3.1 }
      end;
  end;
end;

procedure TMenuEditDlg.BrowseFolderClick(Sender: TObject);
begin
  FolderEdit.Text := SelectFolder(FolderEdit.Text);
end;

procedure TMenuEditDlg.BrowseIconClick(Sender: TObject);
begin
  with IconDialog do
  begin
    { Calmira 1.1 bug fix to search default file }
    if IconEdit.Text > '' then Filename := ExtractIconFile(IconEdit.Text)
    else Filename := FirstWord(CommandEdit.Text);
    IconIndex := ExtractIconIndex(IconEdit.Text);
    if Execute then
    begin
      IconEdit.Text := Format('%s(%d)', [Filename, IconIndex]);
      IconEditExit(Self); { 3.1 }
      SaveHistory := True;
    end;
  end;
end;

procedure TMenuEditDlg.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if (ModalResult = mrOK) and Blank(CaptionEdit.Text) then
  begin
    ErrorMsgRes(SCaptionNeedsText);
    CanClose := False;
  end;
end;

procedure TMenuEditDlg.CaptionEditExit(Sender: TObject);
begin
  CaptionLabel.Caption := CaptionEdit.Text;
end;

procedure TMenuEditDlg.IconEditExit(Sender: TObject); { 3.1 }
begin
  if IconEdit.Text > '' then with IconEdit do
    SetIcon(ExtractIconFile(Text), ExtractIconIndex(Text))
  else
  begin
    SetIcon(FirstWord(CommandEdit.Text), 0);
  end;
end;

function TMenuEditDlg.DataString: string;
begin
  Result := PackStartInfo(CommandEdit.Text, FolderEdit.Text,
    ExtractIconFile(IconEdit.Text),
    ShowCombo.ItemIndex, { 3.1 }
    ExtractIconIndex(IconEdit.Text));
end;

function TMenuEditDlg.EditItem(const prompt, captext, data: string): TModalResult;
var
  buf: TFilename;
begin
  Caption := prompt;
  with ExtractStartInfo(data) do
  begin
    CaptionLabel.Caption := captext;
    CaptionEdit.Text := captext;
    CommandEdit.Text := Command;
    FolderEdit.Text := Directory;
    if IconFile > '' then
    begin
      IconEdit.Text := Format('%s(%d)', [IconFile, IconIndex]);
      { 3.1 }
      buf := IconFile;
      SetIcon(buf, IconIndex);
    end
    else
    begin
      IconEdit.Text := '';
      { 3.1 }
      buf := FirstWord(Command);
      SetIcon(buf, 0);
    end;
    ShowCombo.ItemIndex := ShowMode; { 3.1 }
  end;
  ActiveControl := CaptionEdit;
  Result := ShowModal;
end;

Procedure TMenuEditDlg.SetIcon(const filename: TFilename; index: Integer); { 3.1 }
var
  buf: TFilename;
  icon: HIcon;
begin
  buf := filename;
  icon := ExtractIcon(Handle, StrPChar(buf), index);
  if icon > 1 then
    TargetIcon.Picture.Icon.Handle := icon
  else
    TargetIcon.Picture.Icon := Icons.Get(Copy(ExtractFileExt(buf), 2, 3));
end;

function IsSpecialItem(const s: string): Boolean;
begin
  Result := (s > '') and ((s[1] = '*') or (s[1] = '-'));
end;

end.

