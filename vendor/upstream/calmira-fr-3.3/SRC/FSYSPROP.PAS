{**************************************************************************}
{                                                                          }
{    Calmira II shell pour Microsoft® Windows(TM) 3.1                      }
{    Version française 3.3                                                 }
{    Copyright (C) 2000-2002 Jean Blanchard                                }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ce programme est libre ; vous pouvez le redistribuer et/ou le         }
{    modifier selon les termes de la Licence Publique Générale GNU telle   }
{   que publiée par la Free Software Foundation ; version 2 de la licence  }
{    ou (au choix) n'importe quelle version plus récente.                  }
{                                                                          }
{    Ce programme est distibué dans l'espoir qu'il sera utile, mais SANS   }
{    AUCUNE GARANTIE ; sans même la garantie implicite de                  }
{    COMMERCIALISATION ou d'APTITUDE A UN USAGE PARTICULIER. Voir la       }
{    licence publique générale pour plus de détails.                                        }
{                                                                          }
{    Vous devriez avoir reçue une copie de la licence publique générale    }
{    avec ce programme; si ce n'est pas le cas, écrivez à la Free          }
{    Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.    }
{                                                                          }
{--------------------------------------------------------------------------}

unit Fsysprop;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, Chklist, TabNotBk, Dialogs, Settings, TabPanel,
  Picbtn, Slider, Spin;

type
  TFileSysPropDlg = class(TForm)
    OpenDialog: TOpenDialog;
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    ModeExpl: TRadioGroup;
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
    Label18: TLabel;
    Label19: TLabel;
    KBDecimalsEdit: TSpinEdit;
    MBDecimalsEdit: TSpinEdit;
    Label23: TLabel;
    Label24: TLabel;
    Bevel5: TBevel;
    Label12: TLabel;
    Bevel6: TBevel;
    Label20: TLabel;
    cb4DOSDesc: TCheckBox;
    cbEnableLFN: TCheckBox;
    Label21: TLabel;
    Label22: TLabel;
    Bevel7: TBevel;
    cbFileSysChange: TCheckBox;
    ModeFen: TRadioGroup;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure cb4DOSDescClick(Sender: TObject);
    procedure InspectEditDblClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure cbFileSysChangeClick(Sender: TObject);
    procedure KBDecimalsEditChange(Sender: TObject);
    procedure MBDecimalsEditChange(Sender: TObject);
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
  Changes := [scFileSystem];
  ConfirmList.Color := Colors[ccChecklist];
  MiscList.Color := Colors[ccChecklist];
  Notebook.PageIndex := 0;
  { General }
  ModeExpl.ItemIndex := Integer(ExplorerDisplay);
  ModeFen.ItemIndex := Integer(DefaultDisplay);
  Sorting.ItemIndex := Integer(DefaultSort);
  cbFileSysChange.Checked := FileSysChange; { 3.2 }
  IconEdit.Text := Trim(IconStrings);
  FilterEdit.Text := DefaultFilter;
  { Details }
  cbFileHints.Checked := FileHints;
  slDelay.Value := HintDelay;
  KBDecimalsEdit.Value := ListKBDecimals;
  MBDecimalsEdit.Value := ListMBDecimals;
  Label19.Caption := format(Label19.Caption, [OneItem[KBDecimalsEdit.Value = 1]]);
  Label24.Caption := format(Label24.Caption, [OneItem[MBDecimalsEdit.Value = 1]]);
  { Options }
  ConfirmList.SetData(
    [ConfirmCopyStart, ConfirmMoveStart, ConfirmDelStart,
     ConfirmCopyFile, ConfirmMoveFile, ConfirmDelFile,
     ConfirmReplace, ConfirmProtect, ConfirmCopyFolder,
     ConfirmMoveFolder, ConfirmDelFolder, ConfirmNewAlias]);
  MiscList.SetData(
    [ShowBrowserToolbar { 3.0 }, ShowBrowserStatusbar { 3.2 },
     FlatToolbarButtons { 3.1 }, ShortWinCaptions,
     ShowHidSys, DrawShadedIcons, MiniIcons, HQMiniIcons, UpcaseFirstChar,
     NoRegExtensions, ProgDrop, FindDlgIcons, AliasArrows, DefDragCopy,
     HintDesc, HintBytes, HintType, HintDate, HintTime, HintAttrib,
     fdSize in DefaultColumns, fdType in DefaultColumns,
     fdDate in DefaultColumns, fdTime in DefaultColumns,
     fdAttr in DefaultColumns, fdDesc in DefaultColumns]);
  { Utilities }
  InspectEdit.Text := InspectProg;
  DefaultEdit.Text := DefaultProg;
  UndelEdit.Text := UndeleteProg;
  DiskEdit.Text := DiskProg;
  { 4DOS }
  cb4DOSDesc.Checked := UseDescriptions;
  DescPanel.Enabled := UseDescriptions;
  DescPanel.Font.Color := FontColors[UseDescriptions];
  cbSimul4DOS.Checked := Simul4DOS;
  cbDescCaptions.Checked := DescCaptions;
  cbEnableLFN.Checked := EnableLFN;
  EnableControlList([OKBtn, Notebook], CanEditSettings); { 2.2 }
end;

procedure TFileSysPropDlg.OKBtnClick(Sender: TObject);
var
  i: Integer;
  b: array[0..5] of Boolean;
begin
  { General }
  ExplorerDisplay := TDisplayMode(ModeExpl.ItemIndex);
  DefaultDisplay := TDisplayMode(ModeFen.ItemIndex);
  DefaultSort := TSortOrder(Sorting.ItemIndex);
  FileSysChange := cbFileSysChange.Checked; { 3.2 }
  IconStrings := ' ' + Trim(Lowercase(IconEdit.Text)) + ' ';
  DefaultFilter := RemoveSpaces(FilterEdit.Text);
  { Details }
  FileHints := cbFileHints.Checked;
  HintDelay := slDelay.Value;
  ListKBDecimals := KBDecimalsEdit.Value;
  ListMBDecimals := MBDecimalsEdit.Value;
  { Options }
  ConfirmList.GetData(
    [@ConfirmCopyStart, @ConfirmMoveStart, @ConfirmDelStart,
     @ConfirmCopyFile, @ConfirmMoveFile, @ConfirmDelFile,
     @ConfirmReplace, @ConfirmProtect, @ConfirmCopyFolder,
     @ConfirmMoveFolder, @ConfirmDelFolder, @ConfirmNewAlias]);
  MiscList.GetData(
    [@ShowBrowserToolbar { 3.0 }, @ShowBrowserStatusbar { 3.2 },
     @FlatToolbarButtons { 3.1 }, @ShortWinCaptions,
     @ShowHidSys, @DrawShadedIcons, @MiniIcons, @HQMiniIcons, @UpcaseFirstChar,
     @NoRegExtensions, @ProgDrop, @FindDlgIcons, @AliasArrows, @DefDragCopy,
     @HintDesc, @HintBytes, @HintType, @HintDate, @HintTime, @HintAttrib,
     @b[0], @b[1], @b[2], @b[3], @b[4], @b[5]]);
  DefaultColumns := [];
  for i := 0 to 5 do
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

procedure TFileSysPropDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_TAB) and (ssCtrl in Shift) then
    TabPanel.SelectNext(not (ssShift in Shift));
end;

procedure TFileSysPropDlg.cbFileSysChangeClick(Sender: TObject);
begin
  if Showing then Include(Changes, scSystem);
end;

procedure TFileSysPropDlg.KBDecimalsEditChange(Sender: TObject);
begin
  Label19.Caption := format('décimale%s pour la taille en Ko des fichiers',
    [OneItem[KBDecimalsEdit.Value = 1]]);
end;

procedure TFileSysPropDlg.MBDecimalsEditChange(Sender: TObject);
begin
  Label24.Caption := format('décimale%s pour la taille en Mo des fichiers',
    [OneItem[MBDecimalsEdit.Value = 1]]);
end;

end.

