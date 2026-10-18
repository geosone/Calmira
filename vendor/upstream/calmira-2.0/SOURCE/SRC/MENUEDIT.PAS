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

unit MenuEdit;

{ Start menu item editor

  This dialog accepts input through the EditItem procedure.  After
  the modal state is finished, the edited data can be retrieved
  through the DataString function
}

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, ExtCtrls, Dialogs,
  StylSped, Icondlg, SysUtils, TabNotBk;

type
  TMenuEditDlg = class(TForm)
    OKBtn: TBitBtn;
    CancelBtn: TBitBtn;
    IconDialog: TIconDialog;
    OpenDialog: TOpenDialog;
    Notebook: TTabbedNotebook;
    Label1: TLabel;
    Label2: TLabel;
    TargetLabel: TLabel;
    Label3: TLabel;
    BrowseIcon: TStyleSpeed;
    FolderEdit: TEdit;
    CaptionEdit: TEdit;
    IconEdit: TEdit;
    rbNormal: TRadioButton;
    rbMinimize: TRadioButton;
    rbMaximize: TRadioButton;
    HelpBtn: TBitBtn;
    CommandEdit: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CommandEditDblClick(Sender: TObject);
    procedure BrowseIconClick(Sender: TObject);
    procedure FolderEditDblClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure IconEditDblClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure CommandEditChange(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure rbNormalDblClick(Sender: TObject);
  private
    { Private declarations }
    SaveHistory : Boolean;
  public
    { Public declarations }
    IconChanged : Boolean;
    function DataString: string;
    function EditItem(const prompt, captext, data: string): TModalResult;
  end;


var
  MenuEditDlg: TMenuEditDlg;

implementation

{$R *.DFM}

uses Graphics, FileCtrl, ShellAPI, Strings, Settings, Start, MiscUtil,
  WinProcs, Tree, RefEdit, Locale;


procedure TMenuEditDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;
  ini.ReadStrings('IconSources', IconDialog.HistoryList);
  if not ShowBrowseBtns then begin
    IconEdit.Width := FolderEdit.Width;
    IconEdit.ShowHint := True;
  end;
end;


procedure TMenuEditDlg.FormDestroy(Sender: TObject);
begin
  if SaveHistory then
    ini.RewriteSectionStrings('IconSources', IconDialog.HistoryList);
  MenuEditDlg := nil;
end;


procedure TMenuEditDlg.CommandEditDblClick(Sender: TObject);
begin
  with CommandEdit do
    if Pos('$folder', Lowercase(Text)) > 0 then
      Text := '$Folder ' + SelectFolder(Copy(Text, 9, 255))
    else
      if OpenDialog.Execute then Text := Lowercase(OpenDialog.Filename);
end;


function TMenuEditDlg.DataString: string;
begin
  Result := PackStartInfo(CommandEdit.Text, FolderEdit.Text,
    ExtractIconFile(IconEdit.Text),
    GetRadioIndex([rbNormal, rbMinimize, rbMaximize]),
    ExtractIconIndex(IconEdit.Text));
end;


function TMenuEditDlg.EditItem(const prompt, captext, data: string): TModalResult;
begin
  Caption := prompt;
  with ExtractStartInfo(data) do begin
    CaptionEdit.Text := captext;
    CommandEdit.Text := Command;
    FolderEdit.Text := Directory;
    if IconFile > '' then
      IconEdit.Text := Format('%s(%d)', [IconFile, IconIndex])
    else
      IconEdit.Text := '';
    SetRadioIndex([rbNormal, rbMinimize, rbMaximize], ShowMode);
  end;
  ActiveControl := CaptionEdit;
  Result := ShowModal;
end;


procedure TMenuEditDlg.BrowseIconClick(Sender: TObject);
begin
  with IconDialog do begin
    { Calmira 1.1 bug fix to search default file }
    if IconEdit.Text > '' then Filename := ExtractIconFile(IconEdit.Text)
    else Filename := FirstWord(CommandEdit.Text);
    IconIndex := ExtractIconIndex(IconEdit.Text);

    if Execute then begin
      IconEdit.Text := Format('%s(%d)', [Filename, IconIndex]);
      SaveHistory := True;
    end;
  end;
end;


procedure TMenuEditDlg.FolderEditDblClick(Sender: TObject);
begin
  FolderEdit.Text := SelectFolder(FolderEdit.Text);
end;

procedure TMenuEditDlg.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if (ModalResult = mrOK) and (CaptionEdit.Text = '') then begin
    ErrorMsgRes(SCaptionNeedsText);
    CanClose := False;
  end;
end;


procedure TMenuEditDlg.IconEditDblClick(Sender: TObject);
begin
  if not ShowBrowseBtns then BrowseIcon.Click;
end;

function IsSpecialItem(const s: string): Boolean;
begin
  Result := (s > '') and ((s[1] = '*') or (s[1] = '-'));
end;


procedure TMenuEditDlg.FormShow(Sender: TObject);
begin
  ActiveControl := CaptionEdit;
  IconChanged := IsSpecialItem(CaptionEdit.Text);
end;

procedure TMenuEditDlg.CommandEditChange(Sender: TObject);
begin
  IconChanged := True;
end;

procedure TMenuEditDlg.OKBtnClick(Sender: TObject);
begin
  IconChanged := IconChanged or IsSpecialItem(CaptionEdit.Text);
end;

procedure TMenuEditDlg.rbNormalDblClick(Sender: TObject);
begin
  OKBtn.Click;
end;

end.
