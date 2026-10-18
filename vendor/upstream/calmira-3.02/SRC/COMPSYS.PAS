{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-1999 Calmira Online!                               }
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

unit Compsys;

{ Computer unit

  This form is the "acting" main form, even though Application.MainForm
  actually points to the splash screen.  TComputer handles system
  messages and other operations which are global to Calmira.  Desktop
  interaction is handled here too but most tasks are delegated to
  TDesktop to perform. }

interface

uses SysUtils, WinTypes, Messages, Classes, Controls, Forms, Dialogs,
  Iconic, Menus, DragDrop, Dropclnt, Multigrd, DropServ, CalMsgs, Hooks,
  Grids, Start, Apholder, ObjList, CalForm, DdeMan, Settings,
  Sysmenu, Internet, ExtCtrls;

type
  TComputer = class(TCalForm)
    WindowMenu: TPopupMenu;
    About: TMenuItem;
    HelpContents: TMenuItem;
    Find: TMenuItem;
    Grid: TMultiGrid;
    App: TAppHolder;
    DropServer: TDropServer;
    RefreshSys: TMenuItem;
    DesktopMenu: TPopupMenu;
    DeskProperties: TMenuItem;
    DeskArrangeIcons: TMenuItem;
    DeskClearDesktop: TMenuItem;
    DeskCloseBrowsers: TMenuItem;
    ConfigFileSystem: TMenuItem;
    ConfigDesktop: TMenuItem;
    ConfigStartMenu: TMenuItem;
    ConfigBin: TMenuItem;
    ConfigTaskbar: TMenuItem;
    ObjectMenu: TPopupMenu;
    Properties: TMenuItem;
    CreateAlias: TMenuItem;
    SysProperties: TMenuItem;
    CascadeBrowsers: TMenuItem;
    DeskLineUpIcons: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    N4: TMenuItem;
    TopicSearch: TMenuItem;
    N5: TMenuItem;
    DeskFind: TMenuItem;
    DeskRun: TMenuItem;
    Run: TMenuItem;
    DeskOpen: TMenuItem;
    SystemMenu: TSystemMenu;
    DeskExplore: TMenuItem;
    MinimizePrograms: TMenuItem;
    DeskArrange: TMenuItem;
    New1: TMenuItem;
    NewFileShort: TMenuItem;
    NewFolderShort: TMenuItem;
    NewNetShort: TMenuItem;
    Open: TMenuItem;
    BrowserLink: TBrowserLink;
    Timer: TTimer;
    NewDriveShort: TMenuItem;
    DeskRepaint: TMenuItem;
    Tipoftheday1: TMenuItem;
    Help1: TMenuItem;
    Progman: TDdeServerConv;
    RestoreShortcuts: TMenuItem;
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure GridDblClick(Sender: TObject);
    procedure CreateAliasClick(Sender: TObject);
    procedure PropertiesClick(Sender: TObject);
    procedure AboutClick(Sender: TObject);
    procedure HelpContentsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FindClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure GridDrawCell(Sender: TObject; Index: Integer; Rect: TRect;
      State: TGridDrawState);
    procedure GridSelectCell(Sender: TObject; Index: Integer;
      var CanSelect: Boolean);
    procedure DropServerFileDrag(Sender: TObject; X, Y: Integer;
      Target: Word; var Accept: Boolean);
    procedure GridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DropServerDeskDrop(Sender: TObject; X, Y: Integer;
      Target: Word);
    procedure AppException(Sender: TObject; E: Exception);
    procedure AppShowHint(var HintStr: OpenString; var CanShow: Boolean;
      var HintInfo: THintInfo);
    procedure GridMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure AppMessage(var Msg: TMsg; var Handled: Boolean);
    procedure GridEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure AppActivate(Sender: TObject);
    procedure AppDeactivate(Sender: TObject);
    procedure RefreshSysClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure DeskPropertiesClick(Sender: TObject);
    procedure DeskArrangeIconsClick(Sender: TObject);
    procedure DeskClearDesktopClick(Sender: TObject);
    procedure DeskCloseBrowsersClick(Sender: TObject);
    procedure ConfigDesktopClick(Sender: TObject);
    procedure ConfigStartMenuClick(Sender: TObject);
    procedure ConfigBinClick(Sender: TObject);
    procedure ConfigTaskbarClick(Sender: TObject);
    procedure ConfigFileSystemClick(Sender: TObject);
    procedure ObjectMenuPopup(Sender: TObject);
    procedure SysPropertiesClick(Sender: TObject);
    procedure CascadeBrowsersClick(Sender: TObject);
    procedure DeskLineUpIconsClick(Sender: TObject);
    procedure TopicSearchClick(Sender: TObject);
    function AppWndProc(var Message: TMessage): Boolean;
    procedure DeskOpenClick(Sender: TObject);
    procedure AppActiveFormChange(Sender: TObject);
    procedure RunClick(Sender: TObject);
    procedure DeskExploreClick(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure FormDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure MinimizeProgramsClick(Sender: TObject);
    procedure NewNetShortClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure DeskRepaintClick(Sender: TObject);
    procedure Tipoftheday1Click(Sender: TObject);
    procedure ProgmanExecuteMacro(Sender: TObject; Msg: TStrings);
    procedure RestoreShortcutsClick(Sender: TObject);
  private
    { Private declarations }
    Selected: TComputerIcon;
    FItems: TObjectList;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMCommand(var Msg: TWMCommand); message WM_COMMAND;
    procedure WMNCRButtonDown(var Msg: TWMNCRButtonDown); message WM_NCRBUTTONDOWN;
    procedure WMDeskMenu(var Msg: TMessage); message WM_DESKMENU;
    procedure WMDeskActivate(var Msg: TMessage); message WM_DESKACTIVATE;
    procedure WMKeyboardHook(var Msg: TMessage); message WM_KEYBOARDHOOK;
    procedure WMKeyboardAction(var Msg: TMessage); message WM_KEYBOARDACTION;
    procedure WMWindowsKey(var Msg : TMessage); message WM_WINDOWSKEY; { 2.2 }
    procedure WMWindowsKeyAct(var Msg: TMessage); message WM_WINDOWSKEYACT; { 2.2 }
  public
    procedure Configure;
    procedure SettingsChanged(Changes: TSettingChanges); override;
    procedure ExecuteMacro(Sender: TObject; const macro: string; params: string);
    procedure ExecuteScript(const filename: TFilename; EraseFile: Boolean);
    property Items: TObjectList read FItems;
  end;

const
  { Custom system menu commands }
  SC_ARRANGEICONS    = SC_VSCROLL + 1024;
  SC_CLEARDESKTOP    = SC_VSCROLL + 1056;
  SC_CLOSEBROWSERS   = SC_VSCROLL + 1088;
  SC_ABOUT           = SC_VSCROLL + 1120;
  SC_CASCADEBROWSERS = SC_VSCROLL + 1152;
  SC_LINEUPICONS     = SC_VSCROLL + 1184;
  SC_PROPERTIES      = SC_VSCROLL + 1216;

var
  Computer: TComputer;
  LastErrorMode: Integer;
  LastDeskClick: TPoint;

procedure KeyCommand(const title: string);
function ProvideLastIcon(Instance: Word): HIcon;

implementation

{$R *.DFM}

uses Desk, Shorts, DiskProp, Directry, About, IconWin, WinProcs, Drives,
  FileFind, IniFiles, Resource, Strings, MiscUtil, Files, FileMan, Environs,
  WasteBin, FileCtrl, Graphics, Tree, ShutDown, RunProg, Referenc, ChkList,
  ShellAPI, StrtProp, DeskProp, TaskProp, SysProp, FSysProp, Clipbrd,
  Tips, Locale, Task, TaskMan { 2.2 };

{ This unit is responsible for opening various non-modal windows.
  Inconsistencies will arise if non-modal icon windows are opened while
  a modal dialog is showing, so the IsDialogModal function is used. }

function IsDialogModal: Boolean;
begin
  Result := not IsWindowEnabled(Application.MainForm.Handle);
end;

function CheckDialogModal: Boolean;
var Msg: string[79];
begin
  Result := IsDialogModal;
  if Result then
  begin
    if Screen.ActiveForm = nil then
      Msg := LoadStr(SCloseUnnamedDialog)
    else
      Msg := FmtLoadStr(SCloseSpecificDialog, [Screen.ActiveForm.Caption]);
    MsgDialog(Msg, mtInformation, [mbOK], 0);
  end;
end;

procedure TComputer.FormDestroy(Sender: TObject);
begin
  ReleaseDesktopHook;
  FItems.Free;
end;

procedure TComputer.FormResize(Sender: TObject);
begin
  Grid.Width := ClientWidth - 8;
  Grid.Height := ClientHeight - 8;
  Grid.SizeGrid;
  Selected := nil;
  Invalidate;
end;

procedure TComputer.GridDblClick(Sender: TObject);
begin
  if Selected <> nil then Selected.Open;
end;

procedure TComputer.CreateAliasClick(Sender: TObject);
var
  filename : TFilename;
begin
  if Selected is TDrive then
    filename := 'c:\drive' + LowCase(TDrive(Selected).Letter) + AliasExtension
  else
    filename := ChangeFileExt(TProgram(Selected).Filename, AliasExtension);
  Selected.WriteAlias(Lowercase(filename));
end;

procedure TComputer.PropertiesClick(Sender: TObject);
begin
  if Selected is TDrive then DiskPropExecute(TDrive(Selected).Letter);
end;

procedure TComputer.AboutClick(Sender: TObject);
begin
  ShowModalDialog(TAboutBox);
end;

procedure TComputer.AppException(Sender: TObject; E: Exception);
begin
  { Use MessageDialog to display exception messages because
    the forms look nicer in a small font }
  MsgDialog(E.Message, mtError, [mbOK], E.HelpContext);
end;

procedure TComputer.WMSysCommand(var Msg: TWMSysCommand);
begin
  case Msg.CmdType and $FFF0 of
    SC_RESTORE         : if SystemDrivesChanged then
                         begin
                           DetectDrives;
                           RefreshSys.Click;
                         end;
    SC_ARRANGEICONS    : DeskArrange.Click;
    SC_CLEARDESKTOP    : DeskClearDesktop.Click;
    SC_CLOSEBROWSERS   : DeskCloseBrowsers.Click;
    SC_ABOUT           : About.Click;
    SC_CASCADEBROWSERS : CascadeBrowsers.Click;
    SC_LINEUPICONS     : DeskLineUpIcons.Click;
    SC_PROPERTIES      : SysProperties.Click;
  end;
  inherited;
end;

procedure TComputer.WMCommand(var Msg: TWMCommand);
var
  item: TMenuItem;
begin
  item := StartMenu.FindItem(Msg.ItemID, fkCommand);
  if item <> nil then item.Click;
  inherited;
end;

procedure TComputer.HelpContentsClick(Sender: TObject);
begin
   Application.HelpJump('Contents');
end;

procedure TComputer.FormCreate(Sender: TObject);
var
  i: Integer;
begin
  if IsShell and ShellDDE then DdeMgr.AppName := 'PROGMAN'
  else DdeMgr.AppName := 'CALMIRA';
  Icon.Assign(Icons.Get('Computer'));
  FItems := TObjectList.Create;
  AppActivate(self);
  with SystemMenu do begin
    AddSeparator;
    AddLoadStr(SMenuCascadeBrowsers, SC_CASCADEBROWSERS);
    AddLoadStr(SMenuArrangeIcons, SC_ARRANGEICONS);
    AddLoadStr(SMenuLineUpIcons, SC_LINEUPICONS);
    AddLoadStr(SMenuCloseBrowsers, SC_CLOSEBROWSERS);
    AddLoadStr(SMenuClearDesktop, SC_CLEARDESKTOP);
    AddSeparator;
    AddLoadStr(SMenuProperties, SC_PROPERTIES);
    AddLoadStr(SMenuAbout, SC_ABOUT);
    DeleteCommand(SC_SIZE);
  end;
  StartMenu.OnStartMacro := ExecuteMacro;
  RefreshSys.Click;
  Configure;
  if Caption = '' then Exit; { 2.2 }
  LoadMinPosition(ini, 'Computer');
  LoadPosition(ini, 'Computer');
  Resize;
  Update;
end;

procedure TComputer.Configure;
begin
  Caption := ComputerCaption;
  Color := Colors[ccWinFrame];
  Font.Assign(GlobalFont);
  with Grid do
  begin
    Visible := False;
    Color := Colors[ccIconBack];
    SelColor := Colors[ccIconSel];
    DefaultColWidth := BrowseGrid.X;
    DefaultRowHeight := BrowseGrid.Y;
    Font.Assign(GlobalFont);
    Canvas.Font.Assign(Font);
    Visible := True;
  end;
  MinimumWidth := 128;
  MinimumHeight := 64;
  if ShowDeskMenu then SetDesktopHook(Handle)
  else ReleaseDesktopHook;
  if GlobalHotkeys then SetKeyboardHook(Handle)
  else ReleaseKeyboardHook;
  SetRCloseEnabled(RightClose);
  SetRButtonUpClose(RButtonUpClose);
  BrowserLink.ServiceApplication :=
    ini.ReadString('Internet', 'ServiceApplication', '');
  Timer.Interval := DosTimerInterval;
  Timer.Enabled := EnableDosScripts;
end;

procedure TComputer.FindClick(Sender: TObject);
begin
  if CheckDialogModal then Exit;
  FileFindExecute('');
end;

procedure TComputer.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if SysWinQuit then begin
    { save the desktop before it's too late! }
    Desktop.Save;
    if IsShell then
    begin
      { Always ask before a shell is closed down.  The InSendMessage is
        there for a reason: a slight problem arises when Windows Setup tries
        to restart Windows -- the call to ExitWindows returns false, so
        Calmira doesn't quit and Setup backs off.  The trick is to detect
        when Setup is the "caller" using InSendMessage }
      if not InSendMessage then
      begin
        ShowModalDialog(TQuitDlg);
        CanClose := False;
      end
      else CanClose := not QueryQuit or
        (MsgDialogRes(SNotifyEndWindows, mtInformation, [mbOK, mbCancel], 0) = mrOK);
    end
    else CanClose := not QueryQuit or
      (MsgDialogRes(SQueryQuit, mtConfirmation, [mbYes, mbNo], 0) = mrYes);
  end;
end;

procedure TComputer.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if SysWinQuit then Application.Terminate
  else Action := caMinimize;
end;

procedure TComputer.WMNCRButtonDown(var Msg: TWMNCRButtonDown);
begin
  with Msg do
    if (WindowState = wsMinimized) then
      if (HitTest = HTSYSMENU) or CompIconStart then
        StartMenu.Popup(XCursor, YCursor, False)
      else
        WindowMenu.Popup(XCursor, YCursor)
    else inherited;
end;

procedure TComputer.GridDrawCell(Sender: TObject; Index: Integer;
  Rect: TRect; State: TGridDrawState);
begin
  if Index < FItems.Count then
    TComputerIcon(FItems[Index]).Draw(Grid.Canvas, Rect);
end;

procedure TComputer.GridSelectCell(Sender: TObject; Index: Integer;
  var CanSelect: Boolean);
begin
   CanSelect := Index < FItems.Count;
   if CanSelect then Selected := TComputerIcon(FItems[Index])
   else Selected := nil;
end;

procedure TComputer.DropServerFileDrag(Sender: TObject; X, Y: Integer;
  Target: Word; var Accept: Boolean);
begin
  Accept := Target = GetDesktopWindow;
end;

procedure TComputer.GridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
  p: TPoint;
  rect : TRect;
begin
  if Button = mbLeft then
  begin
    if Selected <> nil then Grid.BeginDrag(False)
  end
  else if not Grid.Dragging then
  begin
    { popup one of the menus depending on whether the cursor
      is directly over an icon }
    i := Grid.MouseToCell(X, Y);
    rect := Grid.CellBounds(i);
    InflateRect(rect, -16, -8);
    OffsetRect(rect, 0, -8);
    GetCursorPos(p);
    if PtInRect(rect, Point(x, y)) and (i < Items.Count) then
    begin
      Grid.Select(i);
      ObjectMenu.Popup(p.x, p.y)
    end
    else WindowMenu.Popup(p.X, p.Y);
  end;
end;

procedure TComputer.DropServerDeskDrop(Sender: TObject; X, Y: Integer;
  Target: Word);
begin
  if CanEditSettings { 2.2 } then
    Selected.CreateShortcut.MinPosition := Point(X - 16, Y - 16);
end;

procedure TComputer.AppShowHint(var HintStr: OpenString;
  var CanShow: Boolean; var HintInfo: THintInfo);
var
  f: TDirItem;
  w: TIconWindow;
  i: Integer;
begin
  { Handles popup file hints.  A hint is shown only when there
    is no dragging taking place, otherwise the hint window will
    interfere with the focus rect.  The hint is shown slightly
    below the cursor and is forced to hide or change once the
    cursor leaves the current cell. }
  with HintInfo do
    if (HintControl is TMultiGrid) and FileHints then
      with TMultiGrid(HintControl) do
      begin
        if not (Owner is TIconWindow) then Exit;
        w := TIconWindow(Owner);
        if (GetCaptureControl <> nil) or (w.DisplayMode = dmList)
          then Exit; { 2.2b }
        f := w.FileAt(CursorPos.X, CursorPos.Y, True);
        CanShow := f <> nil;
        if not CanShow then Exit;
        CursorRect := CellBounds(MouseToCell(CursorPos.X, CursorPos.Y));
        with ClientToScreen(CursorPos) do HintPos := Point(X, Y + 16);
        HintStr := f.Hint;
      end
    else if HintControl is TCheckList then
      with TCheckList(HintControl) do
      begin
        i := ItemAtPos(CursorPos, False);
        if (i < 0) or (i >= Hints.Count) then Exit;
        HintStr := Hints[i];
        CursorRect := ItemRect(i);
      end;
end;

procedure TComputer.GridMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if Grid.Dragging and DropServer.CanDrop and AnimCursor then
    SetCursor(Screen.Cursors[crFlutter])
end;

function EnumTitleProc(Wnd: HWND; caption: PString): Bool; export;
var
  buf: TCaption;
begin
  Result := True;
  buf[0] := Chr(GetWindowText(Wnd, @buf[1], 78));
  if CompareText(buf, caption^) = 0 then
  begin
    SendMessage(Wnd, WM_ACTIVATE, WA_ACTIVE, MakeLong(Wnd, Word(True)));
    if IsIconic(Wnd) then ShowWindow(Wnd, SW_RESTORE)
    else BringWindowToTop(Wnd);
    Result := False;
  end
end;

procedure KeyCommand(const title: string);
var
  i: Integer;
  f: TForm;
  p: TPoint;
  item: TMenuItem;
begin
  { First look for a matching form caption }
  with Screen do
    for i := 0 to FormCount - 1 do
    begin
      f := Forms[i];
      if CompareText(f.Caption, title) = 0 then
      begin
        if f is TShort then f.Perform(WM_OPENSHORT, 0, 0)
        else if f.Visible and f.Enabled then
        begin
          f.WindowState := wsNormal;
          f.BringToFront;
        end;
        Exit;
      end;
    end;
  item := StartMenu.Find(title, miAll);
  if item <> nil then
  begin
    if item.Count = 0 then item.Click
    else
    begin
      GetCursorPos(p);
      StartMenu.PopupMenuItem(item.Handle, p.x, p.y, True);
    end
  end
  else if CouldBeFolder(title) and HDirectoryExists(title) then
    Desktop.OpenFolder(title)
  else if CompareText(title, 'Start') = 0 then
    Taskbar.StartKeyPopup
  else
    EnumWindows(@EnumTitleProc, Longint(@title));
end;

procedure TComputer.WMKeyboardHook(var Msg: TMessage);
var
  i: Integer;
begin
  i := KeyMaps.IndexOfObject(TObject(Shortcut(Msg.wParam,
    KeyDataToShiftState(Msg.lParam))));
  Msg.Result := Integer(i > -1);
  if Msg.Result > 0 then PostMessage(Handle, WM_KEYBOARDACTION, i, 0);
end;

procedure TComputer.WMKeyboardAction(var Msg: TMessage);
begin
  if not IsDialogModal then
  try
    KeyCommand(KeyMaps[Msg.wParam]);
  except
    on E: Exception do Application.HandleException(E);
  end;
end;

procedure TComputer.AppMessage(var Msg: TMsg; var Handled: Boolean);
var
  Atom: TAtom;
  buf: array[0..79] of Char;
begin
  with Msg do
    case Message of
      WM_CLOSE:
        if Msg.HWnd = Application.Handle then
        begin
          Handled := True;
          Desktop.Save;
          if IsShell and (MsgDialogRes(SNotifyEndWindows,
            mtInformation, [mbOK, mbCancel], 0) = mrOK) then ExitWindows(0, 0);
        end;
      WM_DROPFILES :
        TDropClient.CheckMessage(Msg, Handled);
      WM_KEYDOWN :
        { Check for keyboard shortcuts.  Exceptions must be handled explicitly,
          otherwise the program will be terminated by the Delphi RTL }
        if not IsDialogModal then
          if (Msg.wParam = VK_TAB) and (GetKeyState(VK_CONTROL) < 0) then
            try
              Desktop.NextForm
            except
              on E: Exception do Application.HandleException(E);
            end
          else if not GlobalHotKeys and IsHotKey(Msg.wParam, Msg.lParam) then
            Perform(WM_KEYBOARDHOOK, Msg.wParam, Msg.lParam);
      $C000..$FFFF : { registered messages }
        if Message = WM_CALMIRA then
        begin
          Handled := True;
          case wParam of
            CM_PREVINSTANCE:
              begin
                BringToFront;
                WindowState := wsNormal;
              end;
            CM_EXPLORER: { 3.1 }
              begin
                if Msg.lParam > 0 then
                begin
                  Atom := msg.lParam;
                  GlobalGetAtomName(Atom, buf, 79);
                  GlobalDeleteAtom(Atom);
                  OpenExplorer(StrPas(buf));
                end
                else OpenExplorer('');
              end;
            CM_TASKMAN: { 2.2 }
              OpenTaskManager;
            CM_RELOADOPTIONS:
              AnnounceSettingsChanged([scSystem, scFileSystem,
                scDesktop, scStartMenu, scBin, scTaskbar,
                scDisplay, scINIFile, sc4DOS, scDevices]);
          end;
        end;
    end;
end;

procedure TComputer.GridEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  DropServer.DragFinished;
end;

procedure ExecuteFolderMacro(mode: Integer; params: string);
var
  foldername: TFilename;
  filespec: string[12];
  IconWindow: TIconWindow;
begin
  MacroDisplayMode := mode;
  if params = '' then
  begin
    if not InputQuery(LoadStr(SOpenFolder), LoadStr(SFolderName), params)
      then Exit;
    params := Lowercase(ExpandFoldername(EnvironSubst(params), Winpath[1]));
  end;
  if (Pos('*', params) > 0) or (Pos('?', params) > 0) then
  begin
    filespec := ExtractFilename(params);
    foldername := ExtractFileDir(params);
  end
  else
  begin
    filespec := DefaultFilter;
    foldername := params;
  end;
  if ConfirmFolder(foldername) <> mrYes then Exit;
  IconWindow := Desktop.WindowOf(foldername);
  if IconWindow = nil then
    TIconWindow.Init(Application, Lowercase(foldername),
      Lowercase(filespec)).Show
  else with IconWindow do
  begin
    Dir.Filter := filespec;
    RefreshWin;
    ShowNormal;
  end;
end;

const
  MacroList : array[0..20] of PChar =
    ({0}'$Folder',
     {1}'$System',
     {2}'$Run',
     {3}'$Explore',
     {4}'$Find',
     {5}'$Shutdown',
     {6}'$SystemProp',
     {7}'$DesktopProp',
     {8}'$FileSystemProp',
     {9}'$TaskbarProp',
     {10}'$BinProp',
     {11}'$StartMenuProp',
     {12}'$CascadeBrowsers',
     {13}'$ArrangeIcons',
     {14}'$LineUpIcons',
     {15}'$CloseBrowsers',
     {16}'$ClearDesktop',
     {17}'$MinimizePrograms',
     {18}'$LargeIconFolder',
     {19}'$SmallIconFolder',
     {20}'$ListFolder');

function FindCommand(const Cmds: array of PChar; const s: string): Integer;
var
  buf: array[0..255] of Char;
begin
  for Result := 0 to High(Cmds) do
    if StrIComp(Cmds[Result], StrPCopy(buf, s)) = 0 then Exit;
  Result := -1;
end;

procedure TComputer.ExecuteMacro(Sender : TObject; const macro: string; params : string);
var
  CommandID : Integer;
begin
  if CheckDialogModal then Exit;
  CommandID := FindCommand(MacroList, macro);
  case CommandID of
    0: ExecuteFolderMacro(0, params);
    1: ShowNormal;
    2: RunExecute({ 2.2 } params, '');
    3: OpenExplorer(params);
    4: if not CheckDialogModal { 2.2 } then FileFindExecute({ 2.2 } params);
    5: ShowModalDialog(TQuitDlg);
    6: SysProperties.Click;
    7: ConfigDesktop.Click;
    8: ConfigFileSystem.Click;
    9: ConfigTaskbar.Click;
    10: ConfigBin.Click;
    11: ConfigStartMenu.Click;
    12..17: DeskArrange.Items[CommandID-12].Click;
    18..20: ExecuteFolderMacro(CommandID - 17, params);
  else
    MsgDialogResFmt(SUnknownCommand, [macro], mtError, [mbOK], 0);
  end;
end;

function ProvideLastIcon(Instance: Word): HIcon;
begin
  { If the last program the user executed matches the given instance
    handle, then an icon is extracted if the user specified a
    particular one }
  Result := 0;
  if Instance = LastInstance then
  begin
    if LastIconFile > '' then Result := ExtractIcon(HInstance,
      StringAsPChar(LastIconFile), LastIconIndex);
    LastInstance := 0;
    LastIconFile := '';
    LastIconIndex := 0;
  end;
end;

procedure TComputer.AppActivate(Sender: TObject);
begin
  LastErrorMode := SetErrorMode(SEM_FAILCRITICALERRORS);
end;

procedure TComputer.AppDeactivate(Sender: TObject);
begin
  SetErrorMode(LastErrorMode);
  if TaskManager <> nil then TaskManager.Release; { 2.2 }
end;

procedure TComputer.RefreshSysClick(Sender: TObject);
var
  drive: Char;
  progs: TStringList;
  progname: TFilename;
  p: TProgram;
  i: Integer;
begin
  Selected := nil;
  FItems.ClearObjects;
  DetectDrives;
  { Add the disk drives }
  for drive := 'A' to 'Z' do
    if drive in ValidDrives then FItems.Add(TDrive.Create(drive));
  { Add the program "shortcuts" }
  progs := TStringList.Create;
  try
    ini.ReadSection('Programs', progs);
    for i := 0 to progs.Count-1 do
    begin
      progname := EnvironSubst(progs[i]);
      if FileExists(progname) then
      begin
        p := TProgram.Create(progname);
        p.Caption := ini.ReadString('Programs', progs[i], ExtractFilename(progs[i]));
        FItems.Add(p);
      end;
    end;
  finally
    progs.Free;
  end;
  with Grid do
  begin
    Reset;
    Limit := FItems.Count;
    SizeGrid;
    Focus := 0;
  end;
  Invalidate;
end;

procedure TComputer.FormPaint(Sender: TObject);
begin
  Border3D(Canvas, ClientWidth-1, ClientHeight-1);
end;

procedure TComputer.WMDeskMenu(var Msg: TMessage);
begin
  LastDeskClick := TPoint(Msg.lParam);
  with TPoint(Msg.lParam) do DesktopMenu.Popup(X, Y);
end;

procedure TComputer.DeskPropertiesClick(Sender: TObject);
begin
  ConfigDesktop.Click;
end;

procedure TComputer.DeskArrangeIconsClick(Sender: TObject);
begin
  Desktop.ArrangeIcons;
end;

procedure TComputer.DeskClearDesktopClick(Sender: TObject);
begin
  if not (CheckDialogModal or DesktopParent) then Application.Minimize;
end;

procedure TComputer.DeskCloseBrowsersClick(Sender: TObject);
begin
  if not CheckDialogModal then Desktop.CloseWindows;
end;

procedure TComputer.ConfigDesktopClick(Sender: TObject);
begin
  if not CheckDialogModal then ShowModalDialog(TDeskPropDlg);
end;

procedure TComputer.ConfigStartMenuClick(Sender: TObject);
begin
  if CheckDialogModal then Exit;
  ShowHourglass;
  if StartPropDlg = nil then
    StartPropDlg := TStartPropDlg.Create(Application);
  StartPropDlg.Show;
end;

procedure TComputer.ConfigBinClick(Sender: TObject);
begin
  Bin.Properties.Click;
end;

procedure TComputer.ConfigTaskbarClick(Sender: TObject);
begin
  ShowModalDialog(TTaskPropDlg);
end;

procedure TComputer.ConfigFileSystemClick(Sender: TObject);
begin
  ShowModalDialog(TFileSysPropDlg);
end;

procedure TComputer.ObjectMenuPopup(Sender: TObject);
begin
  CreateAlias.Enabled := Selected <> nil;
  Properties.Enabled := Selected is TDrive;
end;

procedure TComputer.SysPropertiesClick(Sender: TObject);
begin
  ShowModalDialog(TSysPropDlg);
end;

procedure TComputer.CascadeBrowsersClick(Sender: TObject);
begin
  if not CheckDialogModal then Desktop.Cascade;
end;

procedure TComputer.DeskLineUpIconsClick(Sender: TObject);
begin
  Desktop.SnapToGrid;
end;

procedure TComputer.TopicSearchClick(Sender: TObject);
const
  EmptyString : PChar = '';
begin
  Application.HelpCommand(HELP_PARTIALKEY, Longint(EmptyString));
end;

function TComputer.AppWndProc(var Message: TMessage): Boolean;
begin
  Result := False;
  with Message do
    if (Msg = WM_ENDSESSION) and Bool(wParam) then Desktop.Save;
end;

procedure TComputer.SettingsChanged(Changes: TSettingChanges);
begin
  if [scSystem, scFileSystem, scDesktop, scDisplay] * Changes <> [] then
    Configure;
  if [scDevices, scINIFile] * Changes <> [] then RefreshSys.Click;
  if scStartMenu in Changes { 3.1 } then
    if IsShell and ShellDDE then DdeMgr.AppName := 'PROGMAN'
    else DdeMgr.AppName := 'CALMIRA';
end;

procedure TComputer.DeskOpenClick(Sender: TObject);
begin
  if CheckDialogModal then Exit;
  ExecuteMacro(self, '$Folder', '');
end;

procedure TComputer.AppActiveFormChange(Sender: TObject);
var
  s: TCaption;
begin
  if ComponentState <> [] then Exit;
  if Screen.ActiveForm is TIconWindow then
  begin
    s := TIconWindow(Screen.ActiveForm).Dir.Fullname;
    Environment.Values['CURRENTFOLDER'] := s;
    Environment.Values['CURRENTDRIVE'] := s[1];
  end
  else
  begin
    Environment.Values['CURRENTFOLDER'] := '';
    Environment.Values['CURRENTDRIVE'] := '';
  end;
end;

procedure TComputer.RunClick(Sender: TObject);
begin
  if not CheckDialogModal then RunExecute('', '');
end;

procedure TComputer.DeskExploreClick(Sender: TObject);
begin
  if not CheckDialogModal then OpenExplorer('');
end;

procedure TComputer.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  item: TMenuItem;
begin
  item := WindowMenu.FindItem(Shortcut(Key, Shift), fkShortcut);
  if item <> nil then item.Click;
end;

procedure TComputer.FormDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Source is TMultiGrid) and (TMultiGrid(Source).Owner is TIconWindow);
end;

procedure TComputer.FormDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  i: Integer;
begin
  with ((Source as TMultiGrid).Owner as TIconWindow).CompileSelection(False) do
    for i := 0 to Count-1 do
      with TDirItem(Items[i]) do
        NewStartItems.Values[GetTitle] := GetStartInfo;
end;

procedure TComputer.MinimizeProgramsClick(Sender: TObject);
begin
  Taskbar.MinimizeAll;
end;

procedure BringIconicFormToFront(F: TForm);
begin
  if Assigned(F) then with F do
    if Visible and Enabled and (WindowState = wsMinimized) then BringToFront;
end;

procedure TComputer.WMDeskActivate(var Msg: TMessage);
var
  i: Integer;
begin
  { 2.2 }
  with Application do
    if IsIconic(Handle) then ShowWindow(Handle, SW_RESTORE);
  if CheckDialogModal then Exit;
  if not DesktopParent then BringWindowToTop(Application.Handle)
  else
  begin
    with Screen do
      for i := 0 to FormCount - 1 do
        if Forms[i] is TShort then BringIconicFormToFront(Forms[i]);
    BringIconicFormToFront(self);
    BringIconicFormToFront(Bin);
    BringIconicFormToFront(FindForm);
    BringIconicFormToFront(RunDlg);
    BringIconicFormToFront(Explorer);
  end;
end;

procedure TComputer.NewNetShortClick(Sender: TObject);
begin
  if CanEditSettings { 2.2 } then with TShort.Create(Application) do
  begin
    Ref.Kind := TReferenceKind((Sender as TComponent).Tag);
    if Ref.AssignFromExternal then
    begin
      Caption := Ref.Caption;
      Ref.AssignIcon(Icon);
      MinPosition := LastDeskClick;
    end
    else Free;
  end;
end;

const
  RunningScript : Boolean = False;

procedure TComputer.ExecuteScript(const filename: TFilename; EraseFile: Boolean);
var
  lines: TStringList;
  next: Integer;

procedure ProcessStart;
var
  command: string;
  dir: TFilename;
  i: Integer;
begin
  dir := lines[next];
  i := next + 1;
  while (i < lines.Count) and (lines[i] <> '') do
  begin
    command := lines[i];
    DefaultExec(Lowercase(GetWord(command, ' ')), command, dir, SW_SHOW);
    Inc(i);
  end;
  next := i;
end;

const
  ScriptCmds : array[0..4] of PChar = ('Explore', 'Folder', 'Start',
    'Activate', 'Macro');
var
  currentdir: TFilename;
  s: string;
  i: Integer;
begin
  if RunningScript then Exit;
  RunningScript := True;
  lines := TStringList.Create;
  try
    lines.LoadFromFile(filename);
    if EraseFile then DeleteFile(filename);
    for i := 0 to lines.Count-1 do lines[i] := Trim(lines[i]);
    next := 0;
    while next < lines.Count do
    begin
      s := lines[next];
      if s > '' then Inc(next);
      case FindCommand(ScriptCmds, s) of
        0: OpenExplorer(Lowercase(lines[next]));
        1: begin
             currentdir := Lowercase(lines[next]);
             Inc(next);
             s := Lowercase(lines[next]);
             if CouldBeFolder(s) then Desktop.OpenFolder(s)
             else if (s > '') and (s[1] in Alphas) then
               Desktop.OpenFolder(MakePath(currentdir) + s)
             else
               Desktop.OpenFolder(ExpandFoldername(s, currentdir[1]));
           end;
        2: ProcessStart;
        3: KeyCommand(lines[next]);
        4: begin
             s := lines[next];
             ExecuteMacro(self, GetWord(s, ' '), s);
           end;
      end;
      Inc(next);
    end;
  finally
    lines.Free;
    RunningScript := False;
  end;
end;

procedure TComputer.TimerTimer(Sender: TObject);
var
  h : Integer;
begin
  if not RunningScript and FileExists(DOSScriptFilename) then
    if not IsDialogModal then
    begin
      h := FileOpen(DosScriptFilename, fmShareDenyWrite);
      if h > 0 then
      begin
        FileClose(h);
        ExecuteScript(DOSScriptFilename, True);
      end;
    end
    else MessageBeep(0);
end;

procedure TComputer.DeskRepaintClick(Sender: TObject);
begin
  Desktop.Repaint;
end;

procedure TComputer.Tipoftheday1Click(Sender: TObject);
begin
   ShowModalDialog(TTipDialog);
end;

procedure TComputer.ProgmanExecuteMacro(Sender: TObject; Msg: TStrings);
begin
  ShellDDEBuf.AddStrings(Msg)
end;

procedure TComputer.WMWindowsKey(var Msg: TMessage); { 2.2 }
begin
  PostMessage(Handle, WM_WINDOWSKEYACT, 0, 0);
end;

procedure TComputer.WMWindowsKeyAct(var Msg: TMessage); { 2.2 }
begin
  Taskbar.StartKeyPopup;
end;

procedure TComputer.RestoreShortcutsClick(Sender: TObject);
begin
  Desktop.Revert; { 2.2 }
end;

end.

