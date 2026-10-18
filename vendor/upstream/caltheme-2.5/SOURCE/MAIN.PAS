unit Main;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Controls,
  Forms, Dialogs, ExtCtrls, TabPanel, StdCtrls, Picbtn, INIFiles,
  Search, ShellAPI, FileCtrl, Graphics, Buttons, Grids, Tranimag;

type
  TCalThemeForm = class(TForm)
    Panel1: TPanel;
    Notebook1: TNotebook;
    TabPanel1: TTabPanel;
    Memo1: TMemo;
    Label1: TLabel;
    Label2: TLabel;
    CloseBtn: TPicBtn;
    Label3: TLabel;
    Label5: TLabel;
    SaveINIBtn: TPicBtn;
    LibraryEdit: TEdit;
    Bevel1: TBevel;
    Label13: TLabel;
    ThemeApplyBtn: TPicBtn;
    RestoreDefaultsBtn: TPicBtn;
    IDL_Filenames: TFileListBox;
    Label7: TLabel;
    IDS_Wallpaper: TLabel;
    Label17: TLabel;
    IDL_Directory: TDirectoryListBox;
    IDC_Drive: TDriveComboBox;
    IDC_Tiled: TCheckBox;
    IDC_Stretch: TCheckBox;
    ClearPaperBtn: TPicBtn;
    ApplyPaperBtn: TPicBtn;
    ScrollBox: TScrollBox;
    IDI_Preview: TImage;
    FindBtn: TPicBtn;
    FindDialog: TFindDialog;
    ReplaceDialog1: TReplaceDialog;
    ReplaceBtn: TPicBtn;
    Label16: TLabel;
    Drives1: TDriveComboBox;
    Directories1: TDirectoryListBox;
    Files1: TFileListBox;
    Label4: TLabel;
    Label6: TLabel;
    Label8: TLabel;
    StringGrid1: TStringGrid;
    Bevel2: TBevel;
    Bevel4: TBevel;
    ThemeCheck: TCheckBox;
    PaperCheck: TCheckBox;
    TabCheck: TCheckBox;
    Label9: TLabel;
    Image2: TTranImage;
    Image1: TTranImage;
    Bevel3: TBevel;
    Label10: TLabel;
    procedure CloseBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SaveINIBtnClick(Sender: TObject);
    procedure IDL_FilenamesClick(Sender: TObject);
    procedure IDC_StretchClick(Sender: TObject);
    procedure ClearPaperBtnClick(Sender: TObject);
    procedure ApplyPaperBtnClick(Sender: TObject);
    procedure ThemeApplyBtnClick(Sender: TObject);
    procedure RestoreDefaultsBtnClick(Sender: TObject);
    procedure FindBtnClick(Sender: TObject);
    procedure FindDialogFind(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Image1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Image1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure Image1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ReplaceBtnClick(Sender: TObject);
    procedure Replace(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ShowFolderFinder;
    procedure Drives1Change(Sender: TObject);
    procedure Directories1Change(Sender: TObject);
    procedure ReadIcons;
    procedure Files1Click(Sender: TObject);
    procedure StringGrid1DrawCell(Sender: TObject; Col, Row: Longint;
      Rect: TRect; State: TGridDrawState);
    procedure ClearIcons;

  private
    { Private declarations }
    OldX,
    OldY,
    OldLeft,
    OldTop   : Integer;
    ScreenDC : HDC;
    MoveRect : TRect;
    Moving   : Boolean;
  public
    { Public declarations }
  end;

var
  CalThemeForm: TCalThemeForm;
  Location, CalmiraINILocation, CalThemeINILocation,
  ThemeFolder, PaperFolder : string;
  oldWallpaper: array [0..128] of char;
  oldTiled, CloseVar, ActiveTab : integer;
  FirstRun, RememberTheme, RememberPaper, RememberTabs : boolean;

implementation

uses Strings, Finder;

{$R *.DFM}

procedure TCalThemeForm.CloseBtnClick(Sender: TObject);
begin
 Close;
end;

procedure TCalThemeForm.FormCreate(Sender: TObject);
var TheDLL : string;
begin
 FirstRun := true;
 GetProfileString('Desktop', 'Wallpaper', '', oldWallpaper, 128);
 IDS_Wallpaper.Caption := oldWallpaper;
 oldTiled := GetProfileInt('Desktop', 'TileWallpaper', 0);
 IDC_Tiled.Checked := boolean(oldTiled);
 CalThemeINILocation :=  ExtractFilePath(Application.ExeName)+'calthem2.ini';

 with TINIFile.Create(CalThemeINILocation) do begin
  try
   FirstRun := ReadBool('Settings', 'First Run', FirstRun);
   RememberTheme := ReadBool('Settings', 'Remember Theme Folder', RememberTheme);
   RememberPaper := ReadBool('Settings', 'Remember Wallpaper Folder', RememberPaper);
   RememberTabs := ReadBool('Settings', 'Remember Tab Setting', RememberTabs);
   CalmiraINILocation := ReadString('Settings', 'Calmira INI Location', CalmiraINILocation);
   TheDLL := ReadString('Settings', 'Icon Theme', TheDLL);
   ThemeFolder := ReadString('Settings', 'Theme Folder', ThemeFolder);
   PaperFolder := ReadString('Settings', 'Wallpaper Folder', PaperFolder);
   ActiveTab := ReadInteger('Settings', 'Active Tab', ActiveTab);
  finally free;
  end;
 end;

 ThemeCheck.Checked := RememberTheme;
 if ThemeCheck.Checked then
 if DirectoryExists(ThemeFolder) then Directories1.Directory := ThemeFolder;

 PaperCheck.Checked := RememberPaper;
 if PaperCheck.Checked then
 if DirectoryExists(PaperFolder) then IDL_Directory.Directory := PaperFolder;

 if TheDLL = '' then begin
  LibraryEdit.Text := 'No theme selected';
 end else begin
  LibraryEdit.Text := TheDLL;
  ReadIcons;
 end;

{ Testing the active tab needs to be done after testing the theme library, or
  else the TabPanel defaults to the Icon Theme tab if it's read a library into
  the StringGrid. }

 TabCheck.Checked := RememberTabs;
 if TabCheck.Checked then
 with TabPanel1 do begin
 if ActiveTab > 3 then TabIndex := 0
 else TabIndex := ActiveTab;
 end;

end;

procedure TCalThemeForm.FormShow(Sender: TObject);
{ This is all to do with locating CALMIRA.INI. This version of CalTheme no
  longer needs to be in the same folder as Calmira, and the OnShow procedure
  covers both a new CalTheme installation and an overwrite of an existing
  installation. }

begin
 if FileExists(CalmiraINILocation) then begin
 memo1.lines.loadfromfile(CalmiraINILocation);
 Label16.Caption := 'Editing ' + CalmiraINILocation;
 exit;
 end;
 if FirstRun then begin
  MessageDlg('This appears to be the first time you have run CalTheme (at least with version 2.5) on this system.'
  +' You need to specify the location of the CALMIRA.INI file: a dialogue will now open for you to do this.',
  mtInformation, [mbOK], 0);
  ShowFolderFinder;
  CalmiraINILocation := Location + '\calmira.ini';
 end;
 if not FileExists (CalmiraINILocation) then begin
  if MessageDlg('Unable to find CALMIRA.INI. The location of the file may be incorrectly specified, '
  + ' or CalTheme may have been moved.' + #13 +  #13+
  'Do you want to locate the file again? (NB: choosing "No" will close CalTheme)' + #13,
   mtWarning, [mbYes, mbNo], 0) = id_No then CalThemeForm.Close else begin
   ShowFolderFinder;
   CalmiraINILocation := Location + '\calmira.ini';
   end;
  end;
 Label16.Caption := 'Editing ' + CalmiraINILocation;
 memo1.lines.loadfromfile(CalmiraINILocation);
end;

procedure TCalThemeForm.SaveINIBtnClick(Sender: TObject);
begin
 memo1.lines.savetofile(CalmiraINILocation);
end;

procedure TCalThemeForm.IDL_FilenamesClick(Sender: TObject);
{ Loads and previews a selected bitmap }
begin
 IDI_Preview.Picture.LoadFromFile(IDL_Filenames.FileName);
 IDC_StretchClick(Sender);
end;

procedure TCalThemeForm.IDC_StretchClick(Sender: TObject);
{ Displays bitmap stretched/shrunk or actual size. This took a little work
  to get right in this version; earlier versions didn't stretch or scroll
  the bitmap properly. }
begin
with ScrollBox do
 begin
  IDI_Preview.Stretch := IDC_Stretch.Checked;
  if (IDI_Preview.Stretch) then
  begin
   IDI_Preview.Width := 164;
   IDI_Preview.Height := 123;
   HorzScrollBar.Visible := False;
   VertScrollBar.Visible := False;
  end
  else
   begin
    IDI_Preview.AutoSize := True;
    if (IDI_Preview.Width < 164) then
    IDI_Preview.Width := 164 else
    HorzScrollBar.Visible := True;
    if (IDI_Preview.Height < 123) then
    IDI_Preview.Height := 123
    else
    VertScrollBar.Visible := True;
    HorzScrollBar.Position := (IDI_Preview.Width - Width) div 2;
    VertScrollBar.Position := (IDI_Preview.Height - Height) div 2;
    end;
  end;
end;

procedure TCalThemeForm.ClearPaperBtnClick(Sender: TObject);
{ self-explanatory }
var
  fn: array [0..10] of char;
begin
 lStrCpy(fn, '(none)');
 SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, @fn, SPIF_UPDATEINIFILE);
end;

procedure TCalThemeForm.ApplyPaperBtnClick(Sender: TObject);
{ self-explanatory }
var
 fn: array [0..128] of char;
 tiled: array [0..1] of char;
begin
 if IDL_Filenames.FileName<>'' then begin
  if IDC_Tiled.Checked then
   lStrCpy(tiled, '1')
  else
   lStrCpy(tiled, '0');
  WriteProfileString('Desktop', 'TileWallPaper', tiled);
  StrPCopy(fn, IDL_Filenames.FileName);
  SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, @fn, SPIF_UPDATEINIFILE)
 end;
end;

procedure TCalThemeForm.ThemeApplyBtnClick(Sender: TObject);
{ self-explanatory }
var ChosenDLL : string;
begin
if LibraryEdit.text > '' then
 if not (LibraryEdit.text = 'No theme selected') then
 if not (LibraryEdit.text = 'No icons in this file') then begin
 if FileExists(Files1.Filename) then ChosenDLL := Files1.filename else
 ChosenDLL := LibraryEdit.text;
  with TINIFile.Create(CalmiraINILocation) do begin
   try
    WriteString('Icons', '_folder', chosendll+'(0)');
    WriteString('Icons', '_file', chosendll+'(1)');
    WriteString('Icons', '_doc', chosendll+'(2)');
    WriteString('Icons', '_tfile', chosendll+'(3)');
    WriteString('Icons', '_tfolder', chosendll+'(4)');
    WriteString('Icons', '_tprog', chosendll+'(5)');
    WriteString('Icons', '_compute', chosendll+'(6)');
    WriteString('Icons', '_explore', chosendll+'(7)');
    WriteString('Icons', '_windows', chosendll+'(8)');
    WriteString('Icons', '_msdos', chosendll+'(9)');
    WriteString('Icons', '_multi', chosendll+'(10)');
    WriteString('Icons', '_finddlg', chosendll+'(11)');
    WriteString('Icons', '_rundlg', chosendll+'(12)');
    WriteString('Icons', '_hard', chosendll+'(13)');
    WriteString('Icons', '_floppy', chosendll+'(14)');
    WriteString('Icons', '_cdrom', chosendll+'(15)');
    WriteString('Icons', '_ramdisk', chosendll+'(16)');
    WriteString('Icons', '_network', chosendll+'(17)');
    WriteString('Icons', '_emptbin', chosendll+'(18)');
    WriteString('Icons', '_fullbin', chosendll+'(19)');
    WriteString('Icons', '_internt', chosendll+'(20)');
    WriteString('Icons', '_shutdn', chosendll+'(21)');
   finally free;
   Memo1.lines.LoadFromFile(CalmiraINILocation);
   with TINIFile.Create(CalThemeINILocation) do begin
    try
     WriteString('Settings', 'Icon Theme', chosendll);
    finally free;
    end;
    end;
   end;
  end;
 end;
end;


procedure TCalThemeForm.RestoreDefaultsBtnClick(Sender: TObject);
{ self-explanatory }
begin
 if MessageDlg('Restore default Calmira icons?', mtConfirmation, [mbYes, mbNo], 0)
 = idYes then
 begin
  CalmiraINILocation := ExtractFilePath(Application.ExeName)+'calmira.ini';
   with TINIFile.Create(CalmiraINILocation) do
    try
    WriteString('Icons', '_folder', '');
    WriteString('Icons', '_file', '');
    WriteString('Icons', '_doc', '');
    WriteString('Icons', '_tfile', '');
    WriteString('Icons', '_tfolder', '');
    WriteString('Icons', '_tprog', '');
    WriteString('Icons', '_compute', '');
    WriteString('Icons', '_explore', '');
    WriteString('Icons', '_windows', '');
    WriteString('Icons', '_msdos', '');
    WriteString('Icons', '_multi', '');
    WriteString('Icons', '_finddlg', '');
    WriteString('Icons', '_rundlg', '');
    WriteString('Icons', '_hard', '');
    WriteString('Icons', '_floppy', '');
    WriteString('Icons', '_cdrom', '');
    WriteString('Icons', '_ramdisk', '');
    WriteString('Icons', '_network', '');
    WriteString('Icons', '_emptbin', '');
    WriteString('Icons', '_fullbin', '');
    WriteString('Icons', '_internt', '');
    WriteString('Icons', '_shutdn', '');
    finally free;
   Memo1.lines.LoadFromFile(CalmiraINILocation);
   LibraryEdit.Text := 'No theme selected';
   with TINIFile.Create(CalThemeINILocation) do begin
    try
     WriteString('Settings', 'Icon Theme', '');
    finally free;
    end;
    end;
  end;
 end;
end;

procedure TCalThemeForm.FindBtnClick(Sender: TObject);
{ Activates the 'Find' dialogue and the SEARCH.PAS routines }
begin
 with FindDialog do begin
 FindText := '';
 if Memo1.SelText <> '' then FindText := Memo1.SelText;
 Execute;
 end;
end;

procedure TCalThemeForm.FindDialogFind(Sender: TObject);
{ 'Find' dialogue's actions when search gives a result or is completed }
var
 Buff, P, FT : PChar;
 BuffLen : Word;
begin
  with Sender as TFindDialog do
   if not SearchMemo(Memo1, FindText, Options) then
   MessageDlg('Search operation complete on "' + FindText + '"', mtInformation, [mbOk], 0);
end;

procedure TCalThemeForm.Image1MouseDown(Sender: TObject;
{ The 'CalTheme 2' image acts as a titlebar }
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then begin
    SetCapture(Panel1.Handle);
    ScreenDC := GetDC(0);
    OldX := X;
    OldY := Y;
    OldLeft := X;
    OldTop := Y;
    MoveRect := BoundsRect;
    DrawFocusRect(ScreenDC,MoveRect);
    Moving := True;
  end;
end;

procedure TCalThemeForm.Image1MouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
{ The 'CalTheme 2' image acts as a titlebar }
begin
  if Moving then begin
    DrawFocusRect(ScreenDC,MoveRect);
    OldX := X;
    OldY := Y;
    MoveRect := Rect(Left+OldX-OldLeft,Top+OldY-OldTop,
                     Left+Width+OldX-OldLeft,Top+Height+OldY-OldTop);
    DrawFocusRect(ScreenDC,MoveRect);
  end;
end;

procedure TCalThemeForm.Image1MouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
{ The 'CalTheme 2' image acts as a titlebar }
begin
  if Button = mbLeft then begin
    ReleaseCapture;
    DrawFocusRect(ScreenDC,MoveRect);
    Left := Left+X-OldLeft;
    Top := Top+Y-OldTop;
    ReleaseDC(0,ScreenDC);
    Moving := False;
  end;
end;

procedure TCalThemeForm.ReplaceBtnClick(Sender: TObject);
{ Activates the 'Replace' dialogue and the SEARCH.PAS routines }
begin
 with ReplaceDialog1 do begin
  FindText := '';
  ReplaceText := '';
  if Memo1.SelText <> '' then FindText := Memo1.SelText;
  Execute;
 end;
end;

procedure TCalThemeForm.Replace(Sender: TObject);
{ The 'Replace' dialogue's actions on replacement or completion }
var
   Found: Boolean;
begin
  with ReplaceDialog1 do
   begin
    if AnsiCompareText(Memo1.SelText, FindText) = 0 then
    Memo1.SelText := ReplaceText;
    Found := SearchMemo(Memo1, FindText, Options);
    while Found and (frReplaceAll in Options) do
    begin
     Memo1.SelText := ReplaceText;
     Found := SearchMemo(Memo1, FindText, Options);
    end;
    if (not Found) and (frReplace in Options) then
    MessageDlg('Cannot Find "' + FindText + '"', mtInformation, [mbOk], 0);
 end;
end;

procedure TCalThemeForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
{ Close and save }
begin
 FirstRun := false;
 RememberTheme := ThemeCheck.Checked;
 RememberPaper := PaperCheck.Checked;
 RememberTabs := TabCheck.Checked;
 ThemeFolder := Directories1.Directory;
 PaperFolder := IDL_Directory.Directory;
 ActiveTab := TabPanel1.TabIndex;
 with TINIFile.Create(CalThemeINILocation) do
  try
   writeBool('Settings', 'First Run', FirstRun);
   writeBool('Settings', 'Remember Theme Folder', RememberTheme);
   writeBool('Settings', 'Remember Wallpaper Folder', RememberPaper);
   writeBool('Settings', 'Remember Tab Setting', RememberTabs);
   WriteString('Settings', 'Calmira INI Location', CalmiraINILocation);
   WriteString('Settings', 'Theme Folder', ThemeFolder);
   WriteString('Settings', 'Wallpaper Folder', PaperFolder);
   WriteInteger('Settings', 'Active Tab', ActiveTab);
  finally free
 end;
end;

procedure TCalThemeForm.ShowFolderFinder;
{ self-explanatory }
begin
with FolderFinder do begin
 showmodal;
 if ModalResult = mrOK then Location := FolderFinder.Folder1.Directory;
end;
end;

procedure TCalThemeForm.Drives1Change(Sender: TObject);
{ self-explanatory }
begin
 Directories1.Drive := Drives1.Drive;
end;

procedure TCalThemeForm.Directories1Change(Sender: TObject);
{ self-explanatory }
begin
 Files1.Directory := Directories1.Directory;
end;

procedure TCalThemeForm.ClearIcons;
{ self-explanatory }
var i : integer;
begin
 with StringGrid1 do begin
  Hide;
  for i := 0 to (RowCount-1) do
  Rows[i].Clear;
  Show;
 end;
end;

procedure TCalThemeForm.ReadIcons;
{ self-explanatory, but detailed. Based on code from Neil Rubenking's
  "Delphi for Dummies". I'd like to find a way of displaying the icons
  so that the StringGrid doesn't scroll, and the top line of the icons
  is always visible. }
var
 PName   : array[0..255] of char;
 FName   : string[13];
 N       : word;
 IcoH    : HIcon;
 CurItem : LongInt;
begin
 with LibraryEdit do begin
  FName := Text;
  StrPCopy(PName, Text);
 end;
 N := 0;
 CurItem := 0;
 with StringGrid1 do begin
  ClearIcons;
  repeat
  IcoH := ExtractIcon(hInstance, PName, N);
  if IcoH <= 1 then begin
   if N <= 1 then LibraryEdit.Text := 'No icons in this file';
   break;
  end;
  Col := CurItem mod ColCount;
  if (CurItem div ColCount) >= RowCount then
   RowCount := RowCount + 1;
  Row := CurItem div ColCount;
  Cells[Col, Row] := {FName + ' #' + IntToStr(N);} ' ';
  Objects[Col, Row] := TIcon.Create;
  with Objects [Col, Row] as TIcon do
   Handle := IcoH;
  CurItem := CurItem + 1;
  N := N+1;
 until false;
 end;
end;

procedure TCalThemeForm.Files1Click(Sender: TObject);
{ self-explanatory }
begin
 LibraryEdit.Text := Files1.Filename;
 ReadIcons;
end;

procedure TCalThemeForm.StringGrid1DrawCell(Sender: TObject; Col,
  Row: Longint; Rect: TRect; State: TGridDrawState);
{ Activated when the StringGrid draws an item. }
begin
 if StringGrid1.Objects[Col, Row] is TIcon then
 StringGrid1.Canvas.Draw
 (Rect.Left+4, Rect.Top+4, TIcon(StringGrid1.Objects[Col,Row]));
end;

end.
