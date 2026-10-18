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

unit Settings;

{ Settings manager

  This unit is responsible for loading and saving most settings, using
  the main INI file.  Most settings are also declared here.

  Each set of properties has associated load and save procedures.  The
  load procedure is called during startup, and the save procedure is
  called by the individual property dialogs, after the user presses OK.

  LoadSettings() will initialize some general settings, and those which
  are not available for editing in dialogs.  Then it loads all the
  settings which do belong in property dialogs.

  AnnounceSettingsChanged() should be called by a property dialog
  after it has saved its properties, passing a parameter that indicates
  which part of the setup has changed.  This causes WM_SETTINGSCHANGED
  to be broadcast to all forms, which respond appropriately. }

interface

uses Classes, SysUtils, IniFiles, Profile, WinTypes, Graphics, Controls, Forms;

type
  { sorting in icon windows }
  TSortOrder = (soName, soType, soSize, soDate);

  { new window placement }
  TWindowOpen = (woCascaded, woRandom, woSaved);

  TDisplayMode = (dmLargeIcons, dmSmallIcons, dmList);

  { trash management }
  TBinAction  = (baLeave, baDelete, baEmpty, baCollect);

  { application colour palette
    3.0 added Checklist
    3.1 added Startmenu }
  TCalColor = (ccWinFrame, ccIconBack, ccIconSel, ccShortArrow,
    ccAliasArrow, ccPercent, ccPercentBack, ccTaskbar, ccStartmenu,
    ccStartHighlight, ccChecklist);

  TSettingChanges = set of (scSystem, scFileSystem, scDesktop,
    scStartMenu, scBin, scTaskbar, scDisplay, scINIFile, sc4DOS, scDevices);

  TLayout = record
    Lower: Integer;
    Upper: Integer;
    Size : TPoint;
  end;

  TFileDetail = (fdSize, fdDate, fdTime, fdAttr, fdDesc);
  TFileDetails = set of TFileDetail;

const
  { 3.0 added Checklist
    3.1 added Startmenu }
  ColorNames: array[TCalColor] of string[15] =
    ('Window frames', 'Icon background', 'Icon selection', 'Shortcut arrows',
     'Alias arrows', 'Percent bar', 'Percent back', 'Taskbar', 'Startmenu',
     'Start highlight', 'Checklist');

  DefaultColors : array[TCalColor] of TColor =
    (clBtnFace, clWindow, clHighlight, clBlack,
     clBlack, clNavy, clSilver, clSilver, clSilver,
     clHighlight, clSilver);

  Programs: string[79] = ' com exe bat pif ';

  AllDetails: TFileDetails = [fdSize, fdDate, fdTime, fdAttr, fdDesc];

var
  { System properties }
  ComputerCaption: TCaption;
  ShowSplash     : Boolean;
  RestoreSys     : Boolean; { restore Computer window after loading }
  SysWinQuit     : Boolean; { close Computer window to quit program }
  QueryQuit      : Boolean;
  TrackThumb     : Boolean; { scroll window contents when dragging scrollbar }
  GlobalHotkeys  : Boolean;
  ShowDailyTips  : Boolean;
  CompIconStart  : Boolean;

  { these are available in the dialog }
  EnableWinScripts: Boolean;
  EnableDosScripts: Boolean;

  { these must be manually edited }
  DosTimerInterval  : Integer;
  DosScriptFilename : TFilename;
  WinScriptExtension: string[4];

  Win95Keyboard   : Boolean; { set in Start menu properties }
  ShowShutDownBMP : Boolean; { 3.0 }

  { File system properties }
  DefaultSort   : TSortOrder;
  DefaultDisplay: TDisplayMode;
  DefaultFilter : string[79];
  IconStrings   : TFilename; { extensions to search for icons in }
  ListKBDecimals: Integer;
  AliasExtension: string[4];
  AliasExtensionUpper: string[4];

  FileHints    : Boolean;
  HintDelay    : Integer;

  UseDescriptions : Boolean;
  DescriptionFile : String[15];
  DescCaptions    : Boolean; { show descriptions as captions }
  Simul4DOS       : Boolean; { load description file before changing }
  { 3.1 }
  EnableLFN       : Boolean;

  ConfirmCopyStart : Boolean;
  ConfirmMoveStart : Boolean;
  ConfirmDelStart  : Boolean;
  ConfirmCopyFile  : Boolean;
  ConfirmMoveFile  : Boolean;
  ConfirmDelFile   : Boolean;
  ConfirmReplace   : Boolean;
  ConfirmProtect   : Boolean;
  ConfirmCopyFolder: Boolean;
  ConfirmMoveFolder: Boolean;
  ConfirmDelFolder : Boolean;
  ConfirmNewAlias  : Boolean;

  ShowBrowserToolbar: Boolean; { 3.0 }
  ShortWinCaptions  : Boolean;
  ShowHidSys        : Boolean; { show hidden/system files }
  ProgDrop          : Boolean; { allow drop into programs }
  FindDlgIcons      : Boolean; { icons in find dialog list }
  AliasArrows       : Boolean;
  DefDragCopy       : Boolean;
  MiniIcons         : Boolean;
  UpcaseFirstChar   : Boolean;
  NoRegExtensions   : Boolean;

  HintDesc  : Boolean;
  HintDate  : Boolean;
  HintTime  : Boolean;
  HintAttrib: Boolean;
  HintBytes : Boolean;

  DefaultColumns: TFileDetails;

  InspectProg : TFilename;
  DefaultProg : TFilename;
  UndeleteProg: TFilename;
  DiskProg    : TFilename;

  { Desktop properties }
  WindowOpen    : TWindowOpen; { new window placement }
  SingleStatus  : Boolean;
  SaveWindows   : Boolean; { save windows between sessions }
  ShortArrows   : Boolean;
  AnimCursor    : Boolean;
  ShowDeskMenu  : Boolean;
  ExploreLastFolder : Boolean;
  ConfirmDelShort: Boolean;
  StickyShorts   : Boolean; { move only when caption is dragged }
  OneClickShorts : Boolean; { activate after single click }
  BrowseSame     : Boolean; { browse folders in same window }
  RightClose     : Boolean; { right click on min/max box to close }
  RButtonUpClose : Boolean;
  RunAutoClose   : Boolean; { closes run dialog after execution }
  DesktopParent  : Boolean;
  FilePaneCols   : Integer;

  { Taskbar properties }
  DisableTaskbar: Boolean;
  StayVisible   : Boolean;
  ShrinkMax     : Boolean; { constrain maximised windows above the bar }
  Clock24       : Boolean;
  PopupRes      : Boolean;
  PopupDate     : Boolean;
  Animate       : Boolean;
  FullAnimate   : Boolean; { 3.0 }
  ButtonHints   : Boolean;
  ArrangeMin    : Boolean; { move minimised windows upwards }
  HideMinApps   : Boolean;
  IconWindowTask : Boolean;
  ExplorerTask   : Boolean;
  FullFolderPath : Boolean;
  DocNameFirst   : Boolean;
  DocNameLower   : Boolean;
  ShowRealSysMenu: Boolean; { 2.2 }

  TopTaskbar  : Boolean; { 2.2 }
  RowCount    : Integer; { 2.2 }
  UpSpeed     : Integer; { 3.0 }
  DownSpeed   : Integer; { 3.0 }

  { Bin properties }
  BinCaption  : TCaption;
  BinAction   : TBinAction;
  BinCapacity : Integer;
  BinIcons    : Boolean;
  DeleteToBin : Boolean;

  { Start menu properties }
  StartMenu3D  : Boolean;
  ShellStartup : Boolean;
  ShellDDE     : Boolean;
  BoldSelect   : Boolean;
  StartMouseUp : Boolean;
  LargeRootmenu: Boolean;
  ColouredBar  : Boolean;
  StartFile    : TFilename; { normally "START.INI" }
  LargeItemHeight: Integer; { 3.0 }

  { Internal }
  IsShell : Boolean;
  Restart : Boolean;
  MultipleProfiles: Boolean;
  DoubleClickSpeed: Integer;     { read from WIN.INI }
  Sounds          : TStringList; { sound effects WAV file list }
  KeyMaps         : TStringList; { keyboard shortcuts }
  WindowPos       : TStringList; { window positions }
  GlobalCaptions  : TStringList;
  ini             : TProfile;    { main ini file }
  FirstRun        : Boolean;     { first time Calmira is run }
  LoadFromWinDir  : Boolean;
  NormalHintPause : Integer;
  Colors        : array[TCalColor] of TColor;
  DeskGrid      : TPoint;  { desktop grid for lining up icons }
  BrowseGrid    : TPoint;  { icon window grid size }
  LineHeight    : Integer; { height of lists and outlines }
  MinAppHeight  : Integer; { height of icons above the taskbar }
  DescWidth     : Integer; { width of descriptions in icon windows }
  ColumnPadding : Integer;

  CanEditSettings  : Boolean; { 2.2 }
  GlobalFont : TFont;
  Layouts : array[0..15] of TLayout;
  NumLayouts : Integer;
  FileWritePath : TFilename; { 2.2a }
  BasePath      : TFilename; { 2.2a }

procedure ReplaceBitmapColors(bitmap: TBitmap; source, dest: TColor);
function ReadColor(col: TCalColor): TColor;
procedure LoadSettings;
procedure AnnounceSettingsChanged(changes : TSettingChanges);
procedure LoadSystemProp;
procedure SaveSystemProp;
procedure LoadFileSysProp;
procedure SaveFileSysProp;
procedure LoadBinProp;
procedure SaveBinProp;
procedure LoadDeskProp;
procedure SaveDeskProp;
procedure LoadStartProp;
procedure SaveStartProp;
procedure LoadTaskProp;
procedure SaveTaskProp;
procedure WritePathDetermined;

implementation

uses Directry, Strings, MiscUtil, WinProcs, Resource, CalMsgs, Menus, Task,
  Start, FourDOS, Environs, Files, FileMan, IconSel, IconWin, Internet,
  PicBtn, Dialogs;

procedure ReplaceBitmapColors(bitmap: TBitmap; source, dest: TColor);
var
  i, j: Integer;
begin
  { changes pixels from one colour to another }
  if source <> dest then
    with bitmap do
      for i := 0 to Width - 1 do
        for j := 0 to Height - 1 do
          if Canvas.Pixels[i, j] = source then Canvas.Pixels[i, j] := dest;
end;

function ReadColor(col: TCalColor): TColor;
var
  s: string[31];
begin
  s := ini.ReadString('Colors', ColorNames[col], '');
  if s = '' then Result := DefaultColors[col]
  else Result := StringToColor(s);
end;

procedure LoadSettings;
var
  i: Integer;
begin
  with ini do
  begin
    FirstRun := ReadBool('Calmira', 'FirstRun31', True);
    WriteBool('Calmira', 'FirstRun31', False);
    DeskGrid.X   := ReadInteger('Desktop', 'DeskGridX', 25);
    DeskGrid.Y   := ReadInteger('Desktop', 'DeskGridY', 25);
    ReadFont('Display', GlobalFont);
    NormalHintPause := ReadInteger('Calmira', 'NormalHintPause', 800);
    ReadSectionValues('Environment', Environment);
    Environment.Values['CALMIRA'] := Lowercase(ExtractFileDir(ApplicationPath));
    Sounds.Clear;
    ReadSectionValues('Sounds', Sounds);
    GlobalCaptions.Clear;
    ReadSectionValues('Drives', GlobalCaptions);
    ReadSectionValues('Window captions', GlobalCaptions);
    WindowPos.Clear;
    ReadSectionValues('Window positions', WindowPos);
    Keymaps.Clear;
    ReadSection('Keyboard', KeyMaps);
    for i := 0 to KeyMaps.Count - 1 do
      KeyMaps.Objects[i] :=
        TObject(TextToShortcut(ReadString('Keyboard', KeyMaps[i], '')));
    FilePaneCols    := ReadInteger('File system', 'FilePaneCols', 5);
    DescWidth       := ReadInteger('File system', 'DescriptionWidth', -1);
    ColumnPadding   := ReadInteger('File system', 'ColumnPadding', 8);
    MaxHistorySize  := ReadInteger('Calmira', 'MaxHistorySize', 24);
    AliasExtension  := Lowercase(ReadString('File system', 'AliasExtension', '.als'));
    AliasExtensionUpper := Uppercase(AliasExtension);
    RepaintBeforeHourglass := ReadInteger('Display', 'RepaintBeforeHourglass', 2);
    URLPrefixes := ReadString('Internet', 'URLPrefixes', URLPrefixes);
    CanEditSettings := ReadBool('Calmira', 'CanEditSettings', True);
  end;
  LoadSystemProp;
  LoadDeskProp;
  LoadFileSysProp;
  LoadTaskProp;
  LoadBinProp;
  LoadStartProp;
  { install Win95 colour scheme }
  if FirstRun then with TIniFile.Create('control.ini') do
  begin
    WriteString('Color schemes', 'Windows 95 standard',
     '808000,808080,FFFFFF,0,C0C0C0,0,800000,808080,' +
     'FFFFFF,C0C0C0,C0C0C0,0,10E0E0E0,C0C0C0,808080,0,' +
     '808080,800000,FFFFFF,C0C0C0,FFFFFF');
    Free;
  end;
end;

{ Bin properties }

procedure LoadBinProp;
begin
  with ini do
  begin
    BinCaption  := ReadString('Bin', 'Caption', 'Bin');
    BinAction   := TBinAction(ReadInteger('Bin', 'Action', 0));
    BinCapacity := ReadInteger('Bin', 'Capacity', 8);
    BinIcons    := ReadBool('Bin', 'Icons', False);
    DeleteToBin := ReadBool('Bin', 'DeleteToBin', False);
  end;
end;

procedure SaveBinProp;
begin
  with ini do
  begin
    WriteString('Bin', 'Caption', BinCaption);
    WriteInteger('Bin', 'Action', Integer(BinAction));
    WriteInteger('Bin', 'Capacity', BinCapacity);
    WriteBool('Bin', 'Icons', BinIcons);
    WriteBool('Bin', 'DeleteToBin', DeleteToBin);
  end;
end;

{ Desktop properties }

procedure LoadDeskProp;
var
  strings: TStringList;
  i: Integer;
begin
  with ini do
  begin
    SingleStatus      := ReadBool('Preferences', 'SingleStatus', False);
    SaveWindows       := ReadBool('Preferences', 'SaveWindows', False);
    ShortArrows       := ReadBool('Preferences', 'ShortArrows', True);
    AnimCursor        := ReadBool('Preferences', 'AnimCursor', True);
    ShowDeskMenu      := ReadBool('Preferences', 'ShowDeskMenu', True);
    ExploreLastFolder := ReadBool('Preferences', 'ExploreLastFolder', False);
    StickyShorts      := ReadBool('Preferences', 'StickyShorts', False);
    OneClickShorts    := ReadBool('Preferences', 'OneClickShorts', False);
    BrowseSame        := ReadBool('Preferences', 'BrowseSame', False);
    RightClose        := ReadBool('Preferences', 'RightClose', True);
    RButtonUpClose    := ReadBool('Preferences', 'RButtonUpClose', False);
    ConfirmDelShort   := ReadBool('Confirmation', 'DelShort', True);
    RunAutoClose      := ReadBool('Preferences', 'RunAutoClose', True);
    DesktopParent     := ReadBool('Preferences', 'DesktopParent', False);
    WindowOpen        := TWindowOpen(ReadInteger('Preferences', 'WindowOpen', 0));
  end;
  strings := TStringList.Create;
  try
    ini.ReadSectionValues('Layouts', strings);
    NumLayouts := Min(strings.Count, High(Layouts)+1);
    for i := 0 to NumLayouts-1 do
      with Layouts[i] do
        Unformat(strings[i], '%d..%d=%d*%d', [@Lower, @Upper, @Size.X, @Size.Y]);
  finally
    strings.Free;
  end;
end;

procedure SaveDeskProp;
begin
  with ini do begin
    WriteBool('Preferences', 'SingleStatus', SingleStatus);
    WriteBool('Preferences', 'SaveWindows', SaveWindows);
    WriteBool('Preferences', 'ShortArrows', ShortArrows);
    WriteBool('Preferences', 'AnimCursor', AnimCursor);
    WriteBool('Preferences', 'ShowDeskMenu', ShowDeskMenu);
    WriteBool('Preferences', 'ExploreLastFolder', ExploreLastFolder);
    WriteBool('Confirmation', 'DelShort', ConfirmDelShort);
    WriteBool('Preferences', 'StickyShorts', StickyShorts);
    WriteBool('Preferences', 'OneClickShorts', OneClickShorts);
    WriteBool('Preferences', 'BrowseSame', BrowseSame);
    WriteBool('Preferences', 'RightClose', RightClose);
    WriteBool('Preferences', 'RunAutoClose', RunAutoClose);
    WriteBool('Preferences', 'DesktopParent', DesktopParent);
    WriteBool('Preferences', 'RButtonUpClose', RButtonUpClose);
    WriteInteger('Preferences', 'WindowOpen', Integer(WindowOpen));
  end;
end;

{ File system properties }

procedure LoadFileSysProp;
var
  b: Byte;
begin
  with ini do
  begin
    DefaultDisplay  := TDisplayMode(ReadInteger('File system', 'DefaultDisplay', 0));
    DefaultSort     := TSortOrder(ReadInteger('File system', 'DefaultSort', 0));
    IconStrings     := ' ' + ReadString('File system', 'IconStrings', 'exe') + ' ';
    DefaultFilter   := ReadString('File system ', 'DefaultFilter', '*.*');
    FileHints       := ReadBool('File system ', 'FileHints', True);
    HintDelay       := ReadInteger('File system ', 'HintDelay', 800);
    ListKBDecimals  := ReadInteger('File system', 'ListKBDecimals', 0);
    UseDescriptions := ReadBool('File system', 'UseDescriptions', False);
    DescriptionFile := ReadString('File system', 'DescriptionFile', 'descript.ion'); { 3.0 }
    DescCaptions    := ReadBool('File system', 'DescCaptions', False);
    Simul4DOS       := ReadBool('File system', 'Simul4DOS', False);
    EnableLFN       := ReadBool('File system', 'EnableLFN', False);
    ConfirmCopyStart  := ReadBool('Confirmation', 'CopyStart', False);
    ConfirmMoveStart  := ReadBool('Confirmation', 'MoveStart', False);
    ConfirmDelStart   := ReadBool('Confirmation', 'DelStart', True);
    ConfirmCopyFile   := ReadBool('Confirmation', 'CopyFile', False);
    ConfirmMoveFile   := ReadBool('Confirmation', 'MoveFile', False);
    ConfirmDelFile    := ReadBool('Confirmation', 'DelFile', True);
    ConfirmReplace    := ReadBool('Confirmation', 'Replace', True);
    ConfirmProtect    := ReadBool('Confirmation', 'Protect', True);
    ConfirmCopyFolder := ReadBool('Confirmation', 'CopyFolder', False);
    ConfirmMoveFolder := ReadBool('Confirmation', 'MoveFolder', False);
    ConfirmDelFolder  := ReadBool('Confirmation', 'DelFolder', True);
    ConfirmNewAlias   := ReadBool('Confirmation', 'NewAlias', False);
    ShowBrowserToolbar := ReadBool('Preferences', 'ShowBrowserToolbar', True); { 3.0 }
    ShortWinCaptions := ReadBool('Preferences', 'ShortWinCaptions', True);
    ShowHidSys       := ReadBool('Preferences', 'ShowHidSys', False);
    ProgDrop         := ReadBool('Preferences', 'ProgDrop', False);
    FindDlgIcons     := ReadBool('Preferences', 'FindDlgIcons', True);
    AliasArrows      := ReadBool('Preferences', 'AliasArrows', True);
    DefDragCopy      := ReadBool('Preferences', 'DefDragCopy', True);
    MiniIcons        := ReadBool('Preferences', 'MiniIcons', True);
    UpcaseFirstChar  := ReadBool('Preferences', 'UpcaseFirstChar', True);
    NoRegExtensions  := ReadBool('Preferences', 'NoRegExtensions', True);
    HintDesc     := ReadBool('Preferences', 'HintDesc',   HintDesc);
    HintDate     := ReadBool('Preferences', 'HintDate',   HintDate);
    HintTime     := ReadBool('Preferences', 'HintTime',   HintTime);
    HintAttrib   := ReadBool('Preferences', 'HintAttrib', HintAttrib);
    HintBytes     := ReadBool('Preferences', 'HintBytes', HintBytes);
    b := ReadInteger('Preferences', 'DefaultColumns', Byte(AllDetails));
    DefaultColumns := TFileDetails(b);
    InspectProg  := ReadString('Utilities', 'Inspect', '%windir%\notepad.exe');
    DefaultProg  := ReadString('Utilities', 'Default', '%windir%\notepad.exe');
    UndeleteProg := ReadString('Utilities', 'Undelete', '');
    DiskProg     := ReadString('Utilities', 'Disk', '');
  end;
  @BackgroundProc := @FileMan.BackgroundProcess;
end;

procedure SaveFileSysProp;
begin
  with ini do
  begin
    WriteInteger('File system', 'DefaultDisplay', Integer(DefaultDisplay));
    WriteInteger('File system', 'DefaultSort', Integer(DefaultSort));
    WriteString('File system', 'IconStrings', IconStrings);
    WriteString('File system ', 'DefaultFilter', DefaultFilter);
    WriteBool('File system', 'FileHints', FileHints);
    WriteInteger('File system', 'HintDelay', HintDelay);
    WriteInteger('File system', 'ListKBDecimals', ListKBDecimals);
    WriteBool('File system', 'UseDescriptions', UseDescriptions);
    WriteString('File system', 'DescriptionFile', DescriptionFile);
    WriteBool('File system', 'DescCaptions', DescCaptions);
    WriteBool('File system', 'Simul4DOS', Simul4DOS);
    WriteBool('File system', 'EnableLFN', EnableLFN);
    WriteBool('Confirmation', 'CopyStart', ConfirmCopyStart);
    WriteBool('Confirmation', 'MoveStart', ConfirmMoveStart);
    WriteBool('Confirmation', 'DelStart', ConfirmDelStart);
    WriteBool('Confirmation', 'CopyFile', ConfirmCopyFile);
    WriteBool('Confirmation', 'MoveFile', ConfirmMoveFile);
    WriteBool('Confirmation', 'DelFile', ConfirmDelFile);
    WriteBool('Confirmation', 'Replace', ConfirmReplace);
    WriteBool('Confirmation', 'Protect', ConfirmProtect);
    WriteBool('Confirmation', 'CopyFolder', ConfirmCopyFolder);
    WriteBool('Confirmation', 'MoveFolder', ConfirmMoveFolder);
    WriteBool('Confirmation', 'DelFolder', ConfirmDelFolder);
    WriteBool('Confirmation', 'NewAlias', ConfirmNewAlias);
    WriteBool('Preferences', 'ShowBrowserToolbar', ShowBrowserToolbar); { 3.0 }
    WriteBool('Preferences', 'ShortWinCaptions', ShortWinCaptions);
    WriteBool('Preferences', 'ShowHidSys', ShowHidSys);
    WriteBool('Preferences', 'ProgDrop', ProgDrop);
    WriteBool('Preferences', 'FindDlgIcons', FindDlgIcons);
    WriteBool('Preferences', 'AliasArrows', AliasArrows);
    WriteBool('Preferences', 'DefDragCopy', DefDragCopy);
    WriteBool('Preferences', 'MiniIcons', MiniIcons);
    WriteBool('Preferences', 'UpcaseFirstChar', UpcaseFirstChar);
    WriteBool('Preferences', 'NoRegExtensions', NoRegExtensions);
    WriteBool('Preferences', 'HintDesc', HintDesc);
    WriteBool('Preferences', 'HintDate', HintDate);
    WriteBool('Preferences', 'HintTime', HintTime);
    WriteBool('Preferences', 'HintAttrib', HintAttrib);
    WriteBool('Preferences', 'HintBytes', HintBytes);
    WriteInteger('Preferences', 'DefaultColumns', Byte(DefaultColumns));
    WriteString('Utilities', 'Inspect', InspectProg);
    WriteString('Utilities', 'Default', DefaultProg);
    WriteString('Utilities', 'Undelete', UndeleteProg);
    WriteString('Utilities', 'Disk', DiskProg);
  end;
end;

{ Start menu properties }

procedure LoadStartProp;
begin
  with ini do
  begin
    StartMenu3D  := ReadBool('Start menu', 'StartMenu3D', True);
    BoldSelect   := ReadBool('Start menu', 'BoldSelect', True);
    ShellStartup := ReadBool('Start menu', 'ShellStartup', True);
    ShellDDE     := ReadBool('Start menu', 'ShellDDE', False);
    StartMouseUp := ReadBool('Start menu', 'StartMouseUp', True);
    LargeRootMenu := ReadBool('Start menu', 'LargeRootMenu', True);
    ColouredBar := ReadBool('Start menu', 'ColouredBar', True);
    LargeItemHeight := ReadInteger('Start menu', 'LargeItemHeight', 34); { 3.0 }
    Win95Keyboard := ReadBool('Preferences', 'Win95Keyboard', False); { 2.2 }
  end;
end;

procedure SaveStartProp;
begin
  with ini do
  begin
    WriteBool('Start menu', 'StartMenu3D', StartMenu3D);
    WriteBool('Start menu', 'BoldSelect', BoldSelect);
    WriteBool('Start menu', 'ShellStartup', ShellStartup);
    WriteBool('Start menu', 'ShellDDE', ShellDDE);
    WriteBool('Start menu', 'StartMouseUp', StartMouseUp);
    WriteBool('Start menu', 'LargeRootMenu', LargeRootMenu);
    WriteBool('Start menu', 'ColouredBar', ColouredBar);
    WriteInteger('Start menu', 'LargeItemHeight', LargeItemHeight); { 3.0 }
    WriteBool('Preferences', 'Win95Keyboard', Win95Keyboard); { 2.2 }
  end;
end;

{ System properties }

procedure LoadSystemProp;
var
  c: TCalColor;
begin
  with ini do
  begin
    ComputerCaption := ReadString('Computer', 'Caption', 'Computer');
    ShowSplash := ReadBool('Preferences', 'ShowSplash', True);
    RestoreSys := ReadBool('Preferences', 'RestoreSys', False);
    SysWinQuit := ReadBool('Preferences', 'SysWinQuit', False);
    QueryQuit := ReadBool('Preferences', 'QueryQuit', True);
    MsgDialogSounds := ReadBool('Preferences', 'MsgDialogSounds', True);
    TrackThumb := ReadBool('Preferences', 'TrackThumb', True);
    GlobalHotkeys := ReadBool('Preferences', 'GlobalHotKeys', True);
    NotifyNoIcons := ReadBool('Preferences', 'NotifyNoIcons', True);
    ShowDailyTips := ReadBool('Preferences', 'ShowDailyTips', True);
    CompIconStart := ReadBool('Preferences', 'CompIconStart', False);
    DarkIconStretch := ReadBool('Preferences', 'DarkIconStretch', True);
    HQIconStretch := ReadBool('Preferences', 'HQIconStretch', False);
    EnableDosScripts := ReadBool('Scripts', 'EnableDosScripts', True);
    EnableWinScripts := ReadBool('Scripts', 'EnableWinScripts', True);
    { 2.12 }
    PicBtnGlyphs := ReadBool('Preferences', 'PicBtnGlyphs', False);
    PicBtnGlyphsChanged;
    { 3.0 }
    ShowShutDownBMP := ReadBool('Preferences', 'ShowShutDownBMP', True);
    { loaded only }
    DosTimerInterval := ReadInteger('Scripts', 'DosTimerInterval', 1000);
    DosScriptFilename := ReadString('Scripts', 'DosScriptFilename', 'c:\calmira.run');
    WinScriptExtension := ReadString('Scripts', 'WinScriptExtension', '.run');
    for c := Low(TCalColor) to High(TCalColor) do
      Colors[c] := ReadColor(c);
    ReplaceBitmapColors(ShortArrow, clBlack, Colors[ccShortArrow]);
    ReplaceBitmapColors(AliasArrow, clBlack, Colors[ccAliasArrow]);
    ReplaceBitmapColors(SizeBox, clSilver, Colors[ccWinFrame]);
    BrowseGrid.X := ReadInteger('Display', 'BrowseGridX', 70);
    BrowseGrid.Y := ReadInteger('Display', 'BrowseGridY', 60);
    LineHeight   := ReadInteger('Display', 'LineHeight', 16);
  end;
end;

procedure SaveSystemProp;
var
  c: TCalColor;
begin
  with ini do
  begin
    WriteString('Computer', 'Caption', ComputerCaption);
    WriteBool('Preferences', 'ShowSplash', ShowSplash);
    WriteBool('Preferences', 'RestoreSys', RestoreSys);
    WriteBool('Preferences', 'SysWinQuit', SysWinQuit);
    WriteBool('Preferences', 'QueryQuit', QueryQuit);
    WriteBool('Preferences', 'MsgDialogSounds', MsgDialogSounds);
    WriteBool('Preferences', 'TrackThumb', TrackThumb);
    WriteBool('Preferences', 'GlobalHotKeys', GlobalHotKeys);
    WriteBool('Preferences', 'NotifyNoIcons', NotifyNoIcons);
    WriteBool('Preferences', 'ShowDailyTips', ShowDailyTips);
    WriteBool('Preferences', 'CompIconStart', CompIconStart);
    WriteBool('Preferences', 'DarkIconStretch', DarkIconStretch);
    WriteBool('Preferences', 'HQIconStretch', HQIconStretch);
    WriteBool('Preferences', 'PicBtnGlyphs', PicBtnGlyphs); { 2.12 }
    WriteBool('Preferences', 'ShowShutDownBMP', ShowShutDownBMP); { 3.0 }
    WriteBool('Scripts', 'EnableDosScripts', EnableDosScripts);
    WriteBool('Scripts', 'EnableWinScripts', EnableWinScripts);
    for c := Low(TCalColor) to High(TCalColor) do
      WriteString('Colors', ColorNames[c], ColorToString(Colors[c]));;
    WriteInteger('Display', 'BrowseGridX', BrowseGrid.X);
    WriteInteger('Display', 'BrowseGridY', BrowseGrid.Y );
    WriteInteger('Display', 'LineHeight', LineHeight);
  end;
end;

{ Taskbar properties }

procedure LoadTaskProp;
begin
  with ini do
  begin
    DisableTaskbar := ReadBool('Taskbar', 'Disable', False);
    StayVisible := ReadBool('Taskbar', 'StayVisible', False);
    ShrinkMax   := ReadBool('Taskbar', 'ShrinkMax', True);
    Clock24     := ReadBool('Taskbar', 'Clock24', False);
    PopupRes    := ReadBool('Taskbar', 'PopupRes', True);
    PopupDate   := ReadBool('Taskbar', 'PopupDate', True);
    Animate     := ReadBool('Taskbar', 'Animate', True);
    FullAnimate := ReadBool('Taskbar', 'FullAnimate', True);
    ButtonHints := ReadBool('Taskbar', 'ButtonHints', True);
    ArrangeMin  := ReadBool('Taskbar', 'ArrangeMin', True);
    HideMinApps := ReadBool('Taskbar', 'HideMinApps', True);
    IconWindowTask := ReadBool('Taskbar', 'IconWindowTask', True);
    ExplorerTask := ReadBool('Taskbar', 'ExplorerTask', True);
    FullFolderPath := ReadBool('Taskbar', 'FullFolderPath', False);
    DocNameFirst := ReadBool('Taskbar', 'DocNameFirst', False);
    DocNameLower := ReadBool('Taskbar', 'DocNameLower', False);
    MinAppHeight := ReadInteger('Taskbar', 'MinAppHeight', 60);
    { 2.2 }
    TopTaskbar   := ReadBool('Taskbar', 'TopTaskbar', False);
    RowCount  := Max(ReadInteger('Taskbar', 'RowCount', 1), 1);
    ShowRealSysMenu := ReadBool('Taskbar', 'ShowRealSysMenu', True);
    { 3.0 }
    UpSpeed := ReadInteger('Taskbar', 'UpSpeed', 4);
    DownSpeed := ReadInteger('Taskbar', 'DownSpeed', 2);
  end;
end;

procedure SaveTaskProp;
begin
  with ini do
  begin
    WriteBool('Taskbar', 'Disable', DisableTaskbar);
    WriteBool('Taskbar', 'StayVisible', StayVisible);
    WriteBool('Taskbar', 'ShrinkMax', ShrinkMax);
    WriteBool('Taskbar', 'Clock24', Clock24);
    WriteBool('Taskbar', 'PopupRes', PopupRes);
    WriteBool('Taskbar', 'PopupDate', PopupDate);
    WriteBool('Taskbar', 'Animate', Animate);
    WriteBool('Taskbar', 'FullAnimate', FullAnimate);
    WriteBool('Taskbar', 'ButtonHints', ButtonHints);
    WriteBool('Taskbar', 'ArrangeMin', ArrangeMin);
    WriteBool('Taskbar', 'HideMinApps', HideMinApps);
    WriteBool('Taskbar', 'IconWindowTask', IconWindowTask);
    WriteBool('Taskbar', 'ExplorerTask', ExplorerTask);
    WriteBool('Taskbar', 'FullFolderPath', FullFolderPath);
    WriteBool('Taskbar', 'DocNameFirst', DocNameFirst);
    WriteBool('Taskbar', 'DocNameLower', DocNameLower);
    { 2.2 }
    WriteBool('Taskbar', 'TopTaskbar', TopTaskbar);
    WriteInteger('Taskbar', 'RowCount', RowCount);
    WriteBool('Taskbar', 'ShowRealSysMenu', ShowRealSysMenu);
    { 3.0 }
    WriteInteger('Taskbar', 'UpSpeed', UpSpeed);
    WriteInteger('Taskbar', 'DownSpeed', DownSpeed);
  end;
end;

procedure AnnounceSettingsChanged(changes: TSettingChanges);
var
  i: Integer;
begin
  if scINIFile in changes then LoadSettings;
  PicBtnGlyphsChanged;
  { Notify taskbar of updates }
  if [scDisplay, scINIFile, scTaskbar] * changes <> [] then
    Taskbar.Configure;
  if scDisplay in changes then begin
    ShortArrow.Reload;
    AliasArrow.Reload;
    SizeBox.Reload;
    ReplaceBitmapColors(ShortArrow, clBlack, Colors[ccShortArrow]);
    ReplaceBitmapColors(AliasArrow, clBlack, Colors[ccAliasArrow]);
    ReplaceBitmapColors(SizeBox, clSilver, Colors[ccWinFrame]);
  end;
  if scStartMenu in Changes then StartMenu.Configure;
  with Screen do
    for i := 0 to FormCount - 1 do
      PostMessage(Forms[i].Handle, WM_SETTINGSCHANGED, Word(Changes), 0);
end;

procedure WritePathDetermined; { 2.2a }
begin
  ini := TProfile.Create(FileWritePath + 'calmira.ini');
  StartFile := FileWritePath + 'start.ini';
end;

procedure InitSettings;
begin
  Sounds := TStringList.Create;
  KeyMaps := TStringList.Create;
  WindowPos := TStringList.Create;
  GlobalCaptions := TStringList.Create;
  GlobalFont := TFont.Create;
  with TIniFile.Create('system.ini') do begin
    IsShell := CompareText(ExtractFilename(ReadString('boot', 'shell',
      'progman.exe')), 'calmira.exe') = 0;
    Free;
  end;
  with TIniFile.Create('win.ini') do begin
    programs := Format(' %s ', [LowerCase(ReadString('Windows', 'Programs',
      programs))]);
    DoubleClickSpeed := ReadInteger('Windows', 'DoubleClickSpeed', 452);
    LoadFromWinDir := ReadBool('Calmira', 'LoadFromWinDir', False);
    Free;
  end;
  if LoadFromWinDir then FileWritePath := WinPath
  else FileWritePath := ApplicationPath;
  BasePath := FileWritePath; { 2.2a }
end;

procedure DoneSettings; far;
begin
  Sounds.Free;
  KeyMaps.Free;
  WindowPos.Free;
  GlobalCaptions.Free;
  ini.Free;
  GlobalFont.Free;
end;

initialization
  InitSettings;
  AddExitProc(DoneSettings);
end.
