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

unit Fsysprop;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, Chklist, TabNotBk, Dialogs, Settings, TabPanel,
  Picbtn;

type
  TFileSysPropDlg = class(TForm)
    OpenDialog: TOpenDialog;
    TabPanel1: TTabPanel;
    Notebook: TNotebook;
    Contents: TRadioGroup;
    Sorting: TRadioGroup;
    Label8: TLabel;
    Bevel3: TBevel;
    IconEdit: TEdit;
    Label11: TLabel;
    FilterEdit: TEdit;
    Bevel2: TBevel;
    cbFileHints: TCheckBox;
    Label2: TLabel;
    sbDelay: TScrollBar;
    Label3: TLabel;
    Label4: TLabel;
    Label6: TLabel;
    Bevel1: TBevel;
    rbDOSFilenames: TRadioButton;
    rb4DOSDesc: TRadioButton;
    Label5: TLabel;
    DescPanel: TPanel;
    Label10: TLabel;
    cbDescCaptions: TCheckBox;
    cbSimul4DOS: TCheckBox;
    Label7: TLabel;
    ConfirmList: TCheckList;
    Label9: TLabel;
    MiscList: TCheckList;
    Label17: TLabel;
    Bevel4: TBevel;
    Label13: TLabel;
    InspectEdit: TEdit;
    Label14: TLabel;
    DefaultEdit: TEdit;
    Label15: TLabel;
    UndelEdit: TEdit;
    Label16: TLabel;
    DiskEdit: TEdit;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure rb4DOSDescClick(Sender: TObject);
    procedure InspectEditDblClick(Sender: TObject);
  private
    { Private declarations }
    Changes : TSettingChanges;
  public
    { Public declarations }
  end;

{
var
  FileSysPropDlg: TFileSysPropDlg;
}

implementation

uses Strings, SysUtils, Tree, MiscUtil;

{$R *.DFM}

procedure TFileSysPropDlg.FormCreate(Sender: TObject);
begin
  Changes := [scFileSystem];
  Notebook.PageIndex := 0;

  { General }
  Contents.ItemIndex := Integer(DefaultDisplay);
  Sorting.ItemIndex := Integer(DefaultSort);
  IconEdit.Text := Trim(IconStrings);
  FilterEdit.Text := DefaultFilter;

  { Details }
  cbFileHints.Checked := FileHints;
  sbDelay.Position := HintDelay;
  rbDOSFilenames.Checked := not UseDescriptions;
  rb4DOSDesc.Checked := UseDescriptions;
  cbSimul4DOS.Checked := Simul4DOS;
  cbDescCaptions.Checked := DescCaptions;

  { Options }
  ConfirmList.SetData(
    [ConfirmCopyStart, ConfirmMoveStart, ConfirmDelStart,
     ConfirmCopyFile, ConfirmMoveFile, ConfirmDelFile,
     ConfirmReplace, ConfirmProtect, ConfirmCopyFolder,
     ConfirmMoveFolder, ConfirmDelFolder, ConfirmNewAlias]);

  MiscList.SetData(
    [ShortWinCaptions, ShowHidSys, MiniIcons,
     UpcaseFirstChar, NoRegExtensions, ProgDrop,
     FindDlgIcons, AliasArrows,
     DefDragCopy, HintDesc, HintBytes, HintDate, HintTime, HintAttrib,
     fdSize in DefaultColumns, fdDate in DefaultColumns,
     fdTime in DefaultColumns, fdAttr in DefaultColumns,
     fdDesc in DefaultColumns]);

  { Utilities }
  InspectEdit.Text := InspectProg;
  DefaultEdit.Text := DefaultProg;
  UndelEdit.Text := UndeleteProg;
  DiskEdit.Text := DiskProg;

  EnableControlList([OKBtn, Notebook], CanEditSettings); { 2.2 }
end;



procedure TFileSysPropDlg.OKBtnClick(Sender: TObject);
var
  i: Integer;
  b: array[0..4] of Boolean;
begin
  { General }
  DefaultDisplay := TDisplayMode(Contents.ItemIndex);
  DefaultSort := TSortOrder(Sorting.ItemIndex);
  IconStrings := ' ' + Trim(Lowercase(IconEdit.Text)) + ' ';
  DefaultFilter := RemoveSpaces(FilterEdit.Text);

  { Details }

  FileHints := cbFileHints.Checked;
  HintDelay := sbDelay.Position;
  UseDescriptions := rb4DOSDesc.Checked;
  DescCaptions := cbDescCaptions.Checked;
  Simul4DOS := cbSimul4DOS.Checked;

  { Options }
  ConfirmList.GetData(
    [@ConfirmCopyStart, @ConfirmMoveStart, @ConfirmDelStart,
     @ConfirmCopyFile, @ConfirmMoveFile, @ConfirmDelFile,
     @ConfirmReplace, @ConfirmProtect, @ConfirmCopyFolder,
     @ConfirmMoveFolder, @ConfirmDelFolder, @ConfirmNewAlias]);

  MiscList.GetData(
    [@ShortWinCaptions, @ShowHidSys, @MiniIcons,
     @UpcaseFirstChar, @NoRegExtensions, @ProgDrop,
     @FindDlgIcons, @AliasArrows,
     @DefDragCopy, @HintDesc, @HintBytes, @HintDate, @HintTime, @HintAttrib,
     @b[0], @b[1], @b[2], @b[3], @b[4]]);

  DefaultColumns := [];
  for i := 0 to 4 do
    if b[i] then Include(DefaultColumns, TFileDetail(i));

  InspectProg := InspectEdit.Text;
  DefaultProg := DefaultEdit.Text;
  UndeleteProg := UndelEdit.Text;
  DiskProg := DiskEdit.Text;

  SaveFileSysProp;
  AnnounceSettingsChanged(Changes);
end;



procedure TFileSysPropDlg.rb4DOSDescClick(Sender: TObject);
const
  FontColors : array[Boolean] of TColor = (clGray, clBlack);
begin
  DescPanel.Enabled := rb4DOSDesc.Checked;
  DescPanel.Font.Color := FontColors[rb4DOSDesc.Checked];
  if Showing then Include(Changes, sc4DOS);
end;


procedure TFileSysPropDlg.InspectEditDblClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    (Sender as TEdit).Text := Lowercase(OpenDialog.Filename);
end;


end.
