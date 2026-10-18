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

unit DeskProp;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons, Settings,
  StdCtrls, ExtCtrls, ChkList, TabNotBk, TabPanel, Picbtn, StylSped, Spin,
  Dialogs, CalColor;

type
  TDeskPropDlg = class(TForm)
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    Placement: TRadioGroup;
    Label1: TLabel;
    CheckList: TCheckList;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    WinDesktop: TStyleSpeed;
    Bevel2: TBevel;
    Label5: TLabel;
    Label3: TLabel;
    Element: TComboBox;
    Label4: TLabel;
    ColorPick: TComboBox;
    Sample: TShape;
    Bevel4: TBevel;
    CustomBtn: TStyleSpeed;
    Label6: TLabel;
    Bevel3: TBevel;
    Label8: TLabel;
    Label7: TLabel;
    GridHeight: TSpinEdit;
    RowHeight: TSpinEdit;
    GridWidth: TSpinEdit;
    ColorDialog: TColorDialog;
    Bevel1: TBevel;
    Bevel5: TBevel;
    FontDialog: TFontDialog;
    GlobalFontBtn: TStyleSpeed;
    MenuFontBtn: TStyleSpeed;
    Label2: TLabel;
    Label10: TLabel;
    GlobalFontLabel: TLabel;
    MenuFontLabel: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    DeskGridWidth: TSpinEdit;
    DeskGridHeight: TSpinEdit;
    Label13: TLabel;
    Label9: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure WinDesktopClick(Sender: TObject);
    procedure ElementChange(Sender: TObject);
    procedure ColorPickChange(Sender: TObject);
    procedure CustomBtnClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure GlobalFontBtnClick(Sender: TObject);
    procedure MenuFontBtnClick(Sender: TObject);
  private
    { Private declarations }
    Changes: TSettingChanges;
    SaveCustomColors: Boolean;
    procedure SetFontLabels;
    procedure EnumColorProc(const s: string);
    procedure EnumCalColorProc(const s: string);
  public
    { Public declarations }
  end;

{
var
  DeskPropDlg: TDeskPropDlg;
}

implementation

{$R *.DFM}

uses SysUtils, Desk, Environs, Start, MiscUtil;

procedure TDeskPropDlg.SetFontLabels;
begin
  with GlobalFontLabel do
  begin
    Font.Assign(GlobalFont);
    Caption := Font.Name + ', ' + IntToStr(Font.Size) + ' pt';
  end;
  with MenuFontLabel do
  begin
    ini.ReadFont('Start menu', MenuFontLabel.Font);
    Caption := Font.Name + ', ' + IntToStr(Font.Size) + ' pt';
  end;
end;

procedure TDeskPropDlg.EnumColorProc(const s: string);
begin
  ColorPick.Items.AddObject(Copy(s, 3, Length(s) - 2),
    TObject(StringToColor(s)));
end;

procedure TDeskPropDlg.EnumCalColorProc(const s: string);
begin
  ColorPick.Items.AddObject(Copy(s, 3, Length(s) - 2),
    TObject(StringToCalColor(s)));
end;

procedure TDeskPropDlg.FormCreate(Sender: TObject);
var
  c: TCalColor;
begin
  CheckList.Color := Colors[ccChecklist];
  Changes := [];
  Notebook.PageIndex := 0;
  Placement.ItemIndex := Integer(WindowOpen);
  CheckList.SetData([SingleStatus, SaveWindows, ShortArrows,
    ShowDeskMenu, ExploreLastFolder, ConfirmDelShort,
    StickyShorts, OneClickShorts, BrowseSame,
    RightClose, RunAutoClose, DesktopParent]);
  CheckList.Hints.Assign(CheckList.Items); { 3.1 }
  { 3.11 moved from System properties }
  for c := Low(TCalColor) to High(TCalColor) do
    Element.Items.AddObject(ini.ReadString('Colour descriptions',
      IntToStr(Ord(c)), ''), Pointer(Colors[c]));
  GetColorValues(EnumColorProc);
  GetCalColorValues(EnumCalColorProc);
  DeskGridWidth.Value := DeskGrid.X; { 3.2 }
  DeskGridHeight.Value := DeskGrid.Y; { 3.2 }
  GridWidth.Value := BrowseGrid.X;
  GridHeight.Value := BrowseGrid.Y;
  RowHeight.Value := LineHeight;
  ini.ReadSectionValues('Custom colors', ColorDialog.CustomColors);
  EnableControlList([OKBtn, Notebook], CanEditSettings); { 2.2 }
  { 3.11 }
  SetFontLabels;
end;

procedure TDeskPropDlg.OKBtnClick(Sender: TObject);
var
  c: TCalColor;
begin
  WindowOpen := TWindowOpen(Placement.ItemIndex);
  CheckList.GetData([@SingleStatus, @SaveWindows, @ShortArrows,
    @ShowDeskMenu, @ExploreLastFolder, @ConfirmDelShort,
    @StickyShorts, @OneClickShorts, @BrowseSame,
    @RightClose, @RunAutoClose, @DesktopParent]);
  { 3.11 moved from System properties }
  for c:= Low(TCalColor) to High(TCalColor) do
    Colors[c] := Longint(Element.Items.Objects[Integer(c)]);
  DeskGrid.X := DeskGridWidth.Value; { 3.2 }
  DeskGrid.Y := DeskGridHeight.Value; { 3.2 }
  BrowseGrid.X := GridWidth.Value;
  BrowseGrid.Y := GridHeight.Value;
  LineHeight := RowHeight.Value;
  Changes := [scDesktop];
  if CustomBtn.Enabled then
  begin
    Include(Changes, scDisplay);
    Include(Changes, scStartMenu); { 3.1 }
  end;
  SaveDeskProp;
  AnnounceSettingsChanged(Changes);
end;

{ 3.1 }
procedure TDeskPropDlg.WinDesktopClick(Sender: TObject);
var
  buf: array[0..255] of Char;
begin
  WinExec(StrPCopy(buf, EnvironSubst(ini.ReadString('Desktop', 'WinDesktop',
    'control.exe main.cpl Bureau'))), SW_SHOWNORMAL);
end;

procedure TDeskPropDlg.ElementChange(Sender: TObject);
var
  c: TColor;
begin
  with Element do c := TColor(Items.Objects[ItemIndex]);
  with ColorPick do
  begin
    Enabled := True;
    ItemIndex := Items.IndexOfObject(TObject(c));
  end;
  CustomBtn.Enabled := True;
  Sample.Brush.Color := c;
end;

procedure TDeskPropDlg.ColorPickChange(Sender: TObject);
var
  c: TColor;
begin
  with ColorPick do c := TColor(Items.Objects[ItemIndex]);
  with Element do Items.Objects[ItemIndex] := TObject(c);
  Sample.Brush.Color := c;
end;

procedure TDeskPropDlg.CustomBtnClick(Sender: TObject);
var
  c: TColor;
begin
  ColorDialog.Color := Sample.Brush.Color;
  if ColorDialog.Execute then
  begin
    c := ColorDialog.Color;
    with ColorPick do ItemIndex := Items.IndexOfObject(TObject(c));
    with Element do Items.Objects[ItemIndex] := TObject(c);
    Sample.Brush.Color := c;
    SaveCustomColors := True;
  end;
end;

procedure TDeskPropDlg.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_TAB) and (ssCtrl in Shift) then
    TabPanel.SelectNext(not (ssShift in Shift));
end;

procedure TDeskPropDlg.GlobalFontBtnClick(Sender: TObject);
begin
  with FontDialog do
  begin
    Font.Assign(GlobalFont);
    if Execute then
    begin
      GlobalFont.Assign(Font);
      ini.WriteFont('Display', GlobalFont);
      SetFontLabels;
    end;
  end;
end;

procedure TDeskPropDlg.MenuFontBtnClick(Sender: TObject);
begin
  with FontDialog do
  begin
    ini.ReadFont('Start Menu', Font);
    if Execute then
    begin
      ini.WriteFont('Start menu', Font);
      StartMenu.Configure;
      SetFontLabels;
    end;
  end;
end;

end.

