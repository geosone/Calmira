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

unit Refedit;

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, ExtCtrls, Dialogs,
  StylSped, Icondlg, SysUtils, TabNotBk, Referenc, TabPanel, Picbtn;

type
  TRefEditDlg = class(TForm)
    IconDialog: TIconDialog;
    OpenDialog: TOpenDialog;
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    CapEdit: TEdit;
    Label1: TLabel;
    TargetLabel: TLabel;
    TargetEdit: TEdit;
    Label2: TLabel;
    IconEdit: TEdit;
    BrowseIcon: TStyleSpeed;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    BrowseTarget: TStyleSpeed;
    FilePanel: TGroupBox;
    ParamLabel: TLabel;
    Label3: TLabel;
    BrowseFolder: TStyleSpeed;
    FolderEdit: TEdit;
    DocFolder: TCheckBox;
    ParamEdit: TEdit;
    ShowGroup: TRadioGroup;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BrowseTargetClick(Sender: TObject);
    procedure BrowseIconClick(Sender: TObject);
    procedure BrowseFolderClick(Sender: TObject);
    procedure TargetLabelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    SaveHistory: Boolean;
    FRefKind: TReferenceKind;
    procedure SetRefKind(Value: TReferenceKind);
  public
    { Public declarations }
    property RefKind : TReferenceKind read FRefKind write SetRefKind;
  end;

var
  RefEditDlg: TRefEditDlg;

function ExtractIconFile(const s: string): TFilename;
function ExtractIconIndex(const s: string): Integer;

implementation

{$R *.DFM}

uses Graphics, FileCtrl, ShellAPI, Strings, Settings, WinProcs,
  Tree, MiscUtil, Locale;

function ExtractIconFile(const s: string): TFilename;
begin
  Result := '';
  Unformat(s, '%s(', [@Result, 79]);
end;

function ExtractIconIndex(const s: string): Integer;
begin
  Result := 0;
  Unformat(s, '%S(%d)', [@Result]);
end;

procedure TRefEditDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;
  ini.ReadStrings('IconSources', IconDialog.HistoryList);
  { 3.1 }
  BrowseTarget.Glyph.Handle := LoadBitmap(HInstance, 'BROWSEBMP');
  BrowseIcon.Glyph.Handle := LoadBitmap(HInstance, 'BROWSEBMP');
  BrowseFolder.Glyph.Handle := LoadBitmap(HInstance, 'BROWSEBMP');
end;

procedure TRefEditDlg.FormDestroy(Sender: TObject);
begin
  if SaveHistory then
    ini.RewriteSectionStrings('IconSources', IconDialog.HistoryList);
end;

procedure TRefEditDlg.BrowseTargetClick(Sender: TObject);
begin
  case RefKind of
    rkDrive,
    rkFolder: TargetEdit.Text := SelectFolder(TargetEdit.Text);
    rkFile  : with OpenDialog do if Execute then TargetEdit.Text := Filename;
  end;
end;

procedure TRefEditDlg.BrowseIconClick(Sender: TObject);
begin
  with IconDialog do
  begin
    if IconEdit.Text > '' then Filename := ExtractIconFile(IconEdit.Text)
    else Filename := TargetEdit.Text;
    IconIndex := ExtractIconIndex(IconEdit.Text);
    if Execute then
    begin
      IconEdit.Text := Format('%s(%d)', [Filename, IconIndex]);
      SaveHistory := True;
    end;
  end;
end;

procedure TRefEditDlg.BrowseFolderClick(Sender: TObject);
begin
  FolderEdit.Text := SelectFolder(FolderEdit.Text);
end;

procedure TRefEditDlg.SetRefKind(Value: TReferenceKind);
const
  Captions: array[TReferenceKind] of Word =
    (SDriveRefPrompt, SFolderRefPrompt, SFileRefPrompt, SInternetRefPrompt);
  TextColours: array[Boolean] of TColor = (clGray, clBlack);
begin
  FRefKind := Value;
  TargetLabel.Caption := LoadStr(Captions[FRefKind]);
  FilePanel.Enabled := FRefKind = rkFile;
  FilePanel.Font.Color := TextColours[FRefKind = rkFile];
end;

procedure TRefEditDlg.TargetLabelMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  RefKind := TReferenceKind((Ord(RefKind) + 1) mod
    (Ord(High(TReferenceKind)) + 1));
end;

procedure TRefEditDlg.FormShow(Sender: TObject);
begin
  ActiveControl := CapEdit;
end;

end.

