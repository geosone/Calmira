{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.3                                                  }
{    Copyright (C) 1998-2002 Calmira Online!                               }
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

unit DeskProp;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons, Settings,
  StdCtrls, ExtCtrls, ChkList, TabNotBk, TabPanel, Picbtn, StylSped, Spin,
  Dialogs, CalColor, LfnUtils, IconDlg, Mydocs;

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
    Label9: TLabel;
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
    Preview: TPaintBox;
    Label14: TLabel;
    lstWallpapers: TListBox;
    Label15: TLabel;
    cmbTile: TComboBox;
    Label16: TLabel;
    bmpico: TImage;
    btnSearch: TPicBtn;
    lstPatterns: TComboBox;
    Label17: TLabel;
    lstSysItems: TListBox;
    Label18: TLabel;
    imgIcon: TImage;
    btnChangeIcon: TPicBtn;
    btnDefaultIcon: TPicBtn;
    lstINI: TListBox;
    lstRES: TListBox;
    lstRet: TListBox;
    dlgIcon: TIconDialog;
    Label19: TLabel;
    Label20: TLabel;
    SpecIcons: TCheckList;
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
    procedure PreviewPaint(Sender: TObject);
    procedure lstWallpapersDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure lstWallpapersClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure lstSysItemsClick(Sender: TObject);
    procedure btnDefaultIconClick(Sender: TObject);
    procedure btnChangeIconClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure NotebookPageChanged(Sender: TObject);
    procedure lstPatternsChange(Sender: TObject);
    procedure cmbTileChange(Sender: TObject);
  private
    { Private declarations }
    Changes: TSettingChanges;
    SaveCustomColors: Boolean;
    SaveHistory: Boolean;
    PatIdx, TileIdx: Integer;
    procedure SetFontLabels;
    procedure EnumColorProc(const s: string);
    procedure EnumCalColorProc(const s: string);
    procedure LoadIcons;
    procedure SaveIcons;
  public
    { Public declarations }
  end;

{
var
  DeskPropDlg: TDeskPropDlg;
}

implementation
{$R *.DFM}

uses SysUtils, Desk, Environs, Start, MiscUtil, IniFiles,Files,
  AskDrop, Progress, OpenDlg,
  Strings, Drives, CompSys, Replace, Internet,
  FourDOS, Registry, CalMsgs,RefEdit, ShellApi;

const
 prv_wallx = 16;
 prv_wally = 17;
 prv_wallw = 152;
 prv_wallh = 112;

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
  wini : TIniFile;
  windir, walldir, tmp: string[255];
  winini: TIniFile;
  idx,i:Integer;
  b : Boolean;

  procedure ListDir(dir,ext:string);
  var
   R: Integer;
   F: TLfnSearchRec;
   s: String;
  begin
    R := LFindFirst(dir+'\*.'+ext,faReadOnly or
                    faSysFile or faArchive,F);
   while R=0 do
    begin
    s := F.Name;
    if (UpcaseFirstChar) and (s=AnsiUpperCase(s)) then
     begin
     s := AnsiLowerCase(s);
     s[1] := UpCase(s[1]);
     end;
    lstWallpapers.Items.Add(GetLongName(LExpandFileName(dir+'\'+ s)));
    R := LFindNExt(F);
    end;
   LFindClose(F);
  end;

  procedure ListSpecIcons;
  var
   MyDocs:Boolean;
  begin
  MyDocs := Desktop.MyDocuments.Visible;
  SpecIcons.SetData([MyDocs]);
  end;

begin
  CheckList.Color := Colors[ccChecklist];
  SpecIcons.Color := Colors[ccChecklist];
  Changes := [];
  Notebook.PageIndex := 0;
  Placement.ItemIndex := Integer(WindowOpen);
  ListSpecIcons;
  SpecIcons.Hints.Assign(SpecIcons.Items);
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
  wini := TIniFile.Create('control.ini');
  wini.ReadSection('Patterns',lstPatterns.Items);
  wini.Destroy;
  { 3.11 }
  lstWallpapers.Items.Add('(None)');
  windir[0] := Char(GetWindowsDirectory(PChar(@windir[1]),254));
  ListDir(windir,'bmp');
  ListDir(windir,'rle');
  WinIni := TIniFile.Create('win.ini');
  walldir := WinIni.ReadString('Desktop','WallpapersDir','');
  if(walldir<>'')and
    (AnsiUpperCase(GetLongName(LExpandFileName(windir)))<>
     AnsiUpperCase(GetLongName(LExpandFileName(walldir)))) then
    begin
    ListDir(walldir,'bmp');
    ListDir(walldir,'rle');
    end;
  tmp := WinIni.ReadString('Desktop','Wallpaper','(None)');
  if LowerCase(tmp)<>'(none)' then
   tmp := GetLongName(LExpandFileName(SearchProgPath(tmp,windir+';'+walldir)));
  if not FFileExists(tmp) then
    tmp := '(none)';
  idx := -1;
  for i:=0 to lstWallpapers.Items.Count-1 do
   begin
   if AnsiUpperCase(GetLongName(LExpandFileName(lstWallpapers.Items.Strings[i])))=
      AnsiUpperCase(GetLongName(LExpandFileName(tmp)))
     then idx := i;
   end;
  if(idx<>-1) then lstWallpapers.ItemIndex := idx
  else
   begin
   idx := lstWallpapers.Items.Add(GetLongName(LExpandFileName(tmp)));
   lstWallpapers.ItemIndex := idx
   end;
  b := WinIni.ReadInteger('Desktop','TileWallpaper',0)<>0;
  if b then
   cmbTile.ItemIndex := 1
  else
   cmbTile.ItemIndex := 0;
  walldir := WinIni.ReadString('Desktop','Pattern','(None)');
  WinIni.Destroy;
  WinIni := TIniFile.Create('Control.Ini');
  for i:=0 to lstPatterns.Items.Count-1 do
   begin
   if UpperCase(
      WinIni.ReadString('Patterns',
       UpperCase(lstPatterns.Items.Strings[i]),
       '(None)'))=
      UpperCase(walldir)
     then idx := i;
   end;
  WinIni.Destroy;
  ini.ReadStrings('IconSources', dlgIcon.HistoryList);
  SaveHistory := false;
  if(idx<>-1) then lstPatterns.ItemIndex := idx;
  PatIdx := lstPatterns.ItemIndex;
  TileIdx := cmbTile.ItemIndex;
  LoadIcons;
  SetFontLabels;
end;

procedure TDeskPropDlg.OKBtnClick(Sender: TObject);
var
  c: TCalColor;
  str: array [0..MAX_PATH] of Char;
  WinIni: TIniFile;

  procedure SaveSpecIcons;
  var
   MyDocs:Boolean;
  begin
  SpecIcons.GetData([@MyDocs]);
  Desktop.MyDocuments.Visible := MyDocs;
  end;

begin
  WindowOpen := TWindowOpen(Placement.ItemIndex);
  SaveSpecIcons;
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
  Desktop.Save;
  WinIni := TIniFile.Create('Win.Ini');
  WinIni.WriteInteger('Desktop','TileWallpaper',{cmbTile.ItemIndex}TileIdx);
  if lstWallpapers.ItemIndex <> -1 then
    StrPCopy(@str[0],
    GetShortName(lstWallpapers.Items.Strings[lstWallpapers.ItemIndex]))
  else
    StrCopy(@str[0],'(None)');
  SystemParametersInfo(SPI_SETDESKWALLPAPER,
   0,@str[0],SPIF_UPDATEINIFILE or SPIF_SENDWININICHANGE);
  WinIni.Destroy;
  WinIni := TIniFile.Create('Control.Ini');
  if lstPatterns.ItemIndex <> -1 then
    StrPCopy(@str[0],
    WinIni.ReadString('Patterns',
    lstPatterns.Items.Strings[{lstPatterns.ItemIndex}PatIdx],
    '(None)'))
  else
    StrCopy(@str[0],'(None)');
  WinIni.Destroy;
  SystemParametersInfo(SPI_SETDESKPATTERN,
   0,@str[0],SPIF_UPDATEINIFILE or SPIF_SENDWININICHANGE);
  SaveIcons;
  AnnounceSettingsChanged(Changes);
end;

{ 3.1 }
procedure TDeskPropDlg.WinDesktopClick(Sender: TObject);
var
  buf: array[0..255] of Char;
begin
  WinExec(StrPCopy(buf, EnvironSubst(ini.ReadString('Desktop', 'WinDesktop',
    'control.exe main.cpl Desktop'))), SW_SHOWNORMAL);
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

procedure TDeskPropDlg.PreviewPaint(Sender: TObject);
var
 Screen, Wallpaper, Monitor,p : TBitmap;
 temp: TRect;
 tw, th, ax, ay: Integer;

procedure GetPattern(var Pattern:TBitmap;const Name:string);
var
  wini: TIniFile;
  p: string;
  idx1,idx2,cl: integer;
begin
  wini := TIniFile.Create('control.ini');
  p := wini.ReadString('Patterns',Name,'(None)');
  wini.Destroy;
  Pattern.Width := 8;
  Pattern.Height := 8;
  while (p[0]<>#0) and (p[1]=' ') do
    Delete(p,1,1);
  while (p[0]<>#0) and (p[Length(p)]=' ') do
    Delete(p,Length(p),1);
  if (UpperCase(p)='(NONE)')or(p[0]=#0) then
    begin
    Pattern.Canvas.Brush.Color := clBackground;
    Pattern.Canvas.FillRect(Rect(0,0,8,8));
    end
  else
    begin
    for idx1:=0 to 7 do
      begin
       try
       cl := StrToInt(GetWord(p,' '));
       for idx2:=0 to 7 do
        begin
        if (cl and 1)<>0 then
          Pattern.Canvas.Pixels[idx2,idx1] := clBlack
        else
          Pattern.Canvas.Pixels[idx2,idx1] := clBackground;
        cl := cl shr 1;
        end;
       except
       MessageDlg('An error ocurred while trying to get the pattern bitmap from "CONTROLS.INI"',
        mtError,[mbOK],0);
       Exit;
       end;
      end;
    end;
end;

begin
Monitor := TBitmap.Create;
Monitor.Handle := LoadBitmap(HInstance,'WALL_MONITOR');
temp := Rect(0,0,Preview.Width,Preview.Height);
Preview.Canvas.BrushCopy(temp,monitor,temp,monitor.canvas.pixels[0,0]);
Monitor.Destroy;
Screen := TBitmap.Create;
Screen.Width := prv_wallw;
Screen.Height := prv_wallh;
p := TBitmap.Create;                   
Screen.Canvas.Brush.Color := clBackground;
GetPattern(p, lstPatterns.Text);
Screen.Canvas.Brush.Bitmap:=(p);
temp := Rect(0,0,prv_wallw,prv_wallh);
Screen.Canvas.FillRect(temp);
p.Destroy;
if (lstWallpapers.ItemIndex > -1)  and (lstWallpapers.ItemIndex < lstWallpapers.Items.Count)
   and (AnsiLowerCase(lstWallpapers.Items.Strings[lstWallpapers.ItemIndex])<>'(none)')
   and (FFileExists(lstWallpapers.Items.Strings[lstWallpapers.ItemIndex])) then
 begin
 Wallpaper := TBitmap.Create;
 Wallpaper.LoadFromFile(GetShortName(lstWallpapers.Items.Strings[lstWallpapers.ItemIndex]));
 {ShowMessage('Wallpaper = '+IntToStr(Wallpaper.Width)+'x'+IntToStr(Wallpaper.Height));}
 tw := Round((LongInt(Wallpaper.Width)*prv_wallw) / 640.0);
 th := Round((LongInt(Wallpaper.Height)*prv_wallh) / 480.0);
 if tw<1 then tw := 1;
 if th<1 then th := 1;
 {ShowMessage('Scaled = '+IntToStr(tw)+'x'+IntToStr(th));}
 Wallpaper.Canvas.StretchDraw(Rect(0,0,tw,th),Wallpaper);
 Wallpaper.Width := tw;
 Wallpaper.Height := th;
 if(cmbTile.ItemIndex=1) then
  begin
  ax := 0;
  while ax<Screen.Width do
   begin
   ay := 0;
   while ay<Screen.Height do
    begin
    Screen.Canvas.Draw(ax,ay,Wallpaper);
    Inc(ay,th);
    end;
   Inc(ax,tw);
   end;
  end
 else
  begin
  Screen.Canvas.Draw((Screen.Width-tw) div 2,(Screen.Height-th) div 2,Wallpaper);
  end;
 Wallpaper.Destroy;
 end;
Preview.Canvas.Draw(prv_wallx, prv_wally, Screen);
Screen.Destroy;
end;

procedure TDeskPropDlg.lstWallpapersDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
 r: Trect;
begin
r := Classes.Rect(rect.Left, Rect.Top, Rect.Left+16, Rect.Top+16);
lstWallpapers.Canvas.FillRect(rect);
if UpperCase(lstWallpapers.Items.Strings[Index])='(NONE)' then
  begin
  lstWallpapers.Canvas.Font.Style :=
     lstWallpapers.Canvas.Font.Style + [fsBold];
  lstWallpapers.Canvas.Font.Color := clGrayText;
  end
else
  lstWallpapers.Canvas.BrushCopy(r,bmpico.Picture.Bitmap,Classes.Rect(0,0,16,16),bmpico.Picture.Bitmap.Canvas.Pixels[0,0]);
lstWallpapers.Canvas.TextOut(r.Left + 18, r.Top+2, ExtractFileName(lstWallpapers.Items.Strings[Index]));
end;

procedure TDeskPropDlg.lstWallpapersClick(Sender: TObject);
begin
Preview.Repaint;
end;

procedure TDeskPropDlg.btnSearchClick(Sender: TObject);
var
 i: integer;
begin
with TOpenDialogExFrm.Init(Application,'C:','*.*',dkOpenDialog) do
 begin
 cmbFilter.Filter := 'Wallpaper files (*.bmp,*.rle)|*.bmp;*.rle|All files (*.*)|*.*';
 if Execute then
  begin
  i := lstWallpapers.Items.Add(FileName);
  lstWallpapers.ItemIndex := i;
  Preview.Invalidate;
  end;
 Destroy;
 end;
end;

procedure TDeskPropDlg.LoadIcons;
var
 i: integer;
begin
lstRet.Clear;
for i:=0 to lstSysItems.Items.Count -1 do
  lstRet.Items.Add(ini.ReadString('Icons',
      lstIni.Items.Strings[i],EmptyStr));
end;

procedure TDeskPropDlg.SaveIcons;
var
 i: integer;
 s: string;
begin
for i:=0 to lstSysItems.Items.Count -1 do
  begin
  s := ini.ReadString('Icons',
      lstIni.Items.Strings[i],EmptyStr);
  if ((lstRet.Items.Strings[i]=EmptyStr) and (s>EmptyStr))
     or (lstRet.Items.Strings[i]>EmptyStr) then
   ini.WriteString('Icons',lstIni.Items.Strings[i],
       lstRet.Items.Strings[i]);
  end;
end;

procedure TDeskPropDlg.lstSysItemsClick(Sender: TObject);
var
 ic: TIcon;
 h: HIcon;
 i, idx : integer;
 fname: PChar;
begin
i := lstSysItems.ItemIndex;
if (i=-1) then
  begin
  imgIcon.Hide;
  btnChangeIcon.Enabled := False;
  btnDefaultIcon.Enabled := false;
  Exit;
  end;
if lstRet.Items.Strings[i]=EmptyStr then
 begin
 fname := stralloc(MAX_PATH+1);
 StrPCopy(fname,lstRES.Items.Strings[i]);
 h := LoadIcon(HInstance,fname);
 strdispose(fname);
 ic := TIcon.Create;
 ic.Handle := h;
 imgIcon.Picture.Icon.Assign(ic);
 ic.Destroy;
 end
else
 begin
 fname := stralloc(MAX_PATH+1);
 StrPCopy(fname,GetShortName(ExtractIconFile(lstRet.Items.Strings[i])));
 idx := ExtractIconIndex(lstRet.Items.Strings[i]);
 h := ExtractIcon(HInstance,fname,idx);
 StrDispose(fname);
 ic := TIcon.Create;
 ic.Handle := h;
 imgIcon.Picture.Icon.Assign(ic);
 ic.Destroy;
 end;
imgIcon.Show;
  btnChangeIcon.Enabled := True;
  btnDefaultIcon.Enabled := True;
end;

procedure TDeskPropDlg.btnDefaultIconClick(Sender: TObject);
var
 i: integer;
begin
i := lstSysItems.ItemIndex;
if (i=-1) then
 Exit;
lstRet.Items.Strings[i] := EmptyStr;
lstSysitemsclick(Sender);
end;

procedure TDeskPropDlg.btnChangeIconClick(Sender: TObject);
var
 i: integer;
begin
i := lstSysItems.ItemIndex;
if (i=-1) then
 Exit;
if(lstRet.Items.Strings[i]<>'') then
 begin
 dlgIcon.Filename := ExtractIconFile
                     (lstRet.Items.Strings[i]);
 dlgIcon.Index    := ExtractIconIndex
                     (lstRet.Items.Strings[i]);
 end;
if dlgIcon.Execute then
 begin
 lstRet.Items.Strings[i] := Format('%s(%d)',
          [dlgIcon.Filename,dlgIcon.Index]);
 SaveHistory := True;
 lstSysitemsclick(Sender);
 end;
end;

procedure TDeskPropDlg.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
if SaveHistory then
 ini.WriteNewStrings('IconSources', dlgIcon.HistoryList);
end;

procedure TDeskPropDlg.NotebookPageChanged(Sender: TObject);
begin
lstPatterns.ItemIndex := PatIdx;
cmbTile.ItemIndex := TileIdx;
end;

procedure TDeskPropDlg.lstPatternsChange(Sender: TObject);
begin
PatIdx := lstPatterns.ItemIndex;
lstWallpapersClick(Sender);
end;

procedure TDeskPropDlg.cmbTileChange(Sender: TObject);
begin
TileIdx := cmbTile.ItemIndex;
lstWallpapersClick(Sender);
end;

end.

