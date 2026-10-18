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

unit Fsysprop;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, Chklist, TabNotBk, Dialogs, Settings, TabPanel,
  Picbtn, Slider, Spin;

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
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
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
    slDelay: TSlider;
    Bevel1: TBevel;
    Label6: TLabel;
    DescPanel: TPanel;
    cbDescCaptions: TCheckBox;
    cbSimul4DOS: TCheckBox;
    Label10: TLabel;
    Label1: TLabel;
    DescFileEdit: TEdit;
    Label18: TLabel;
    Label19: TLabel;
    KBDecimalsEdit: TSpinEdit;
    Bevel5: TBevel;
    Label12: TLabel;
    Bevel6: TBevel;
    Label20: TLabel;
    cb4DOSDesc: TCheckBox;
    cbEnableLFN: TCheckBox;
    Label21: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure cb4DOSDescClick(Sender: TObject);
    procedure InspectEditDblClick(Sender: TObject);
  private
    { Private declarations }
    Changes: TSettingChanges;
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
const
  FontColors: array[Boolean] of TColor = (clGray, clBlack);
begin
  ConfirmList.Color := Colors[ccChecklist];
  MiscList.Color := Colors[ccChecklist];
  Changes := [scFileSystem];
  Notebook.PageIndex := 0;
  { General }
  Contents.ItemIndex := Integer(DefaultDisplay);
  Sorting.ItemIndex := Integer(DefaultSort);
  IconEdit.Text := Trim(IconStrings);
  FilterEdit.Text := DefaultFilter;
  { Details }
  cbFileHints.Checked := FileHints;
  slDelay.Value := HintDelay;
  KBDecimalsEdit.Value := ListKBDecimals;
  { Options }
  ConfirmList.SetData(
    [ConfirmCopyStart, ConfirmMoveStart, ConfirmDelStart,
     ConfirmCopyFile, ConfirmMoveFile, ConfirmDelFile,
     ConfirmReplace, ConfirmProtect, ConfirmCopyFolder,
     ConfirmMoveFolder, ConfirmDelFolder, ConfirmNewAlias]);
  MiscList.SetData(
    [ShowBrowserToolbar { 3.0 }, ShortWinCaptions, ShowHidSys, MiniIcons,
     UpcaseFirstChar, NoRegExtensions, ProgDrop, FindDlgIcons, AliasArrows,
     DefDragCopy, HintDesc, HintBytes, HintDate, HintTime, HintAttrib,
     fdSize in DefaultColumns, fdDate in DefaultColumns,
     fdTime in DefaultColumns, fdAttr in DefaultColumns,
     fdDesc in DefaultColumns]);
  { Utilities }
  InspectEdit.Text := InspectProg;
  DefaultEdit.Text := DefaultProg;
  UndelEdit.Text := UndeleteProg;
  DiskEdit.Text := DiskProg;
  { 4DOS }
  cb4DOSDesc.Checked := UseDescriptions;
  DescPanel.Enabled := UseDescriptions;
  DescPanel.Font.Color := FontColors[UseDescriptions];
  DescFileEdit.Text := DescriptionFile; { 3.0 }
  cbSimul4DOS.Checked := Simul4DOS;
  cbDescCaptions.Checked := DescCaptions;
  cbEnableLFN.Checked := EnableLFN;
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
  HintDelay := slDelay.Value;
  ListKBDecimals := KBDecimalsEdit.Value;
  { Options }
  ConfirmList.GetData(
    [@ConfirmCopyStart, @ConfirmMoveStart, @ConfirmDelStart,
     @ConfirmCopyFile, @ConfirmMoveFile, @ConfirmDelFile,
     @ConfirmReplace, @ConfirmProtect, @ConfirmCopyFolder,
     @ConfirmMoveFolder, @ConfirmDelFolder, @ConfirmNewAlias]);
  MiscList.GetData(
    [@ShowBrowserToolbar { 3.0 }, @ShortWinCaptions, @ShowHidSys, @MiniIcons,
     @UpcaseFirstChar, @NoRegExtensions, @ProgDrop, @FindDlgIcons, @AliasArrows,
     @DefDragCopy, @HintDesc, @HintBytes, @HintDate, @HintTime, @HintAttrib,
     @b[0], @b[1], @b[2], @b[3], @b[4]]);
  DefaultColumns := [];
  for i := 0 to 4 do
    if b[i] then Include(DefaultColumns, TFileDetail(i));
  { Utilities }
  InspectProg := InspectEdit.Text;
  DefaultProg := DefaultEdit.Text;
  UndeleteProg := UndelEdit.Text;
  DiskProg := DiskEdit.Text;
  { 4DOS }
  UseDescriptions := cb4DOSDesc.Checked;
  Simul4DOS := cbSimul4DOS.Checked;
  DescCaptions := cbDescCaptions.Checked;
  DescriptionFile := LowerCase(DescFileEdit.Text); { 3.0 }
  EnableLFN := cbEnableLFN.Checked;
  SaveFileSysProp;
  AnnounceSettingsChanged(Changes);
end;

procedure TFileSysPropDlg.cb4DOSDescClick(Sender: TObject);
const
  FontColors: array[Boolean] of TColor = (clGray, clBlack);
begin
  if Sender = cb4DOSDesc then
  begin
    DescPanel.Enabled := cb4DOSDesc.Checked;
    DescPanel.Font.Color := FontColors[cb4DOSDesc.Checked];
  end;
  if Showing then Include(Changes, sc4DOS);
end;

procedure TFileSysPropDlg.InspectEditDblClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    (Sender as TEdit).Text := Lowercase(OpenDialog.Filename);
end;

end.

