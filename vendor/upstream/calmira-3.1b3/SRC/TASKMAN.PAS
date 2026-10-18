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

unit Taskman;

interface

uses SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, Buttons, StylSped, StdCtrls, Grids, Multigrd, Sysmenu,
  Menus;

type
  TTaskManager = class(TForm)
    SwitchToBtn: TStyleSpeed;
    EndTaskBtn: TStyleSpeed;
    TerminateBtn: TStyleSpeed;
    MinimizeBtn: TStyleSpeed;
    TileHorzBtn: TStyleSpeed;
    ArrangeBtn: TStyleSpeed;
    TileVertBtn: TStyleSpeed;
    CancelBtn: TStyleSpeed;
    CascadeBtn: TStyleSpeed;
    Grid: TMultiGrid;
    SystemMenu: TSystemMenu;
    HideBtn: TStyleSpeed;
    procedure FormDeactivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure TerminateBtnClick(Sender: TObject);
    procedure EndTaskBtnClick(Sender: TObject);
    procedure SwitchToBtnClick(Sender: TObject);
    procedure MinimizeBtnClick(Sender: TObject);
    procedure ArrangeBtnClick(Sender: TObject);
    procedure TileHorzBtnClick(Sender: TObject);
    procedure TileVertBtnClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure CancelBtnClick(Sender: TObject);
    procedure CascadeBtnClick(Sender: TObject);
    procedure GridDrawCell(Sender: TObject; Index: Integer; Rect: TRect;
      State: TGridDrawState);
    procedure GridDblClick(Sender: TObject);
    procedure GridKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure GridMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormPaint(Sender: TObject);
    procedure HideBtnClick(Sender: TObject);
  private
    { Private declarations }
    LastActiveWindow: HWnd;
    WindowList: TList;
    TaskList: TStringList;
    procedure AddTask(Wnd: HWnd);
    function SelectedWnd: HWnd;
    function SelectedTask: THandle;
    procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
    function GetWindowList: TList;
  public
    { Public declarations }
  end;

var
  TaskManager: TTaskManager;

procedure OpenTaskManager;

implementation

uses ToolHelp, Task, Desk, Settings, MiscUtil, Locale, Resource,
  ShellAPI, CalMsgs, Debug;

{$R *.DFM}

type
  TTaskItem = class
  public
    Wnd: HWnd;
    Icon: TIcon;
    constructor Create(handle: HWnd);
    destructor Destroy; override;
  end;

constructor TTaskItem.Create(handle: HWnd);
var
  module: array[0..127] of Char;
  h: HIcon;
begin
  Wnd := handle;
  Icon := TIcon.Create;
  { 3.1 Get window's class icon }
  h := GetClassWord(Wnd, GCW_HICON);
  if h = 0 then
  begin
    { Extract icon form file }
    GetModuleFilename(GetWindowWord(Wnd, GWW_HINSTANCE), module, High(module) - 2);
    h := ExtractIcon(HInstance, module, 0);
  end;
  if h <= 1 then
    { Use the Windows icon }
    h := CopyIcon(Hinstance, WindowsIcon.Handle);
  Icon.Handle := CopyIcon(Hinstance, h);
end;

destructor TTaskItem.Destroy;
begin
  Icon.Free;
  inherited Destroy;
end;

procedure OpenTaskManager;
begin
  if TaskManager = nil then
    TaskManager := TTaskManager.Create(Application);
  TaskManager.Show;
end;

procedure TTaskManager.FormDeactivate(Sender: TObject);
begin
  TaskManager := nil;
  Release;
end;

procedure TTaskManager.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  with TaskList do
    for i := 0 to Count - 1 do Objects[i].Free;
  WindowList.Free;
  TaskList.Free;
  TaskManager := nil;
end;

procedure TTaskManager.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Action := caFree;
end;

function EnumWinProc(Wnd: HWnd; tm: TTaskManager): Bool; export;
begin
  { Adds all task windows to the manager }
  if IsProperTaskWindow(Wnd) then tm.AddTask(Wnd);
  Result := True;
end;

procedure TTaskManager.AddTask(Wnd: HWnd);
var
  s: string[127];
begin
  s[0] := Chr(GetWindowText(Wnd, @s[1], SizeOf(s) - 3));
  if not IsWindowVisible(Wnd) then AppendStr(s, ' (Hidden)');
  TaskList.AddObject(s, TTaskItem.Create(Wnd));
end;

procedure TTaskManager.FormCreate(Sender: TObject);
var
  i, count: Integer;
  s: string;
  o: TObject;
begin
  WindowList := TList.Create;
  TaskList := TStringList.Create;
  TaskList.Sorted := True;
  TaskList.Duplicates := dupAccept;
  EnumWindows(@EnumWinProc, Longint(self));
  TaskList.Sorted := False;
  count := TaskList.Count;
  i := 0;
  while i < count do
  begin
    if not IsWindowVisible(TTaskItem(TaskList.Objects[i]).Wnd) then
    begin
      s := TaskList[i];
      o := TaskList.Objects[i];
      TaskList.Delete(i);
      TaskList.AddObject(s, o);
      Dec(count);
    end;
    Inc(i);
  end;
  for i := 0 to TaskList.Count - 1 do
    WindowList.Add(TObject(Longint(TTaskItem(TaskList.Objects[i]).Wnd)));
  LastActiveWindow := GetActiveWindow;
  with Grid do
  begin
    DefaultColWidth := Width - 2;
    Limit := TaskList.Count;
    RowCount := Limit;
  end;
  with SystemMenu do
  begin { 3.0 }
    DeleteCommand(SC_RESTORE);
    DeleteCommand(SC_SIZE);
    DeleteCommand(SC_MINIMIZE);
    DeleteCommand(SC_MAXIMIZE);
    DeleteCommand(SC_TASKLIST);
    Delete(1);
    Delete(2);
  end;
end;

function TTaskManager.SelectedWnd: HWnd;
begin
  Result := HWnd(TTaskItem(TaskList.Objects[Grid.Focus]).Wnd);
end;

function TTaskManager.SelectedTask : THandle;
begin
  Result := GetWindowTask(SelectedWnd);
end;

function TTaskManager.GetWindowList: TList;
var
  i: Integer;
begin
  WindowList.Clear;
  with Grid do
    for i := 0 to TaskList.Count - 1 do
      if Selected[i] or (SelCount < 2) and not
        (HWnd(TTaskItem(TaskList.Objects[i]).Wnd) = Application.Handle) { 3.0 }
          then WindowList.Add(TObject(Longint(TTaskItem(TaskList.Objects[i]).Wnd)));
  Result := WindowList;
end;

procedure TTaskManager.TerminateBtnClick(Sender: TObject);
begin
  if SelectedTask <> 0 then
  begin
    if MsgDialog(Format(LoadStr(SQueryTerminate), [TaskList[Grid.Focus]]),
      mtWarning, [mbYes, mbNo], 0) = mrYes then
      begin
        TerminateApp(SelectedTask, NO_UAE_BOX);
        Close;
      end;
  end;
end;

procedure TTaskManager.EndTaskBtnClick(Sender: TObject);
begin
  if SelectedWnd <> 0 then
  begin
    if SelectedWnd = Application.Handle then
    begin
      Close;
      Application.Terminate;
    end
    else
    begin
      PostMessage(SelectedWnd, WM_CLOSE, 0, 0);
      Close;
    end;
  end;
end;

procedure TTaskManager.SwitchToBtnClick(Sender: TObject);
var
  Wnd: HWnd;
begin
  Wnd := SelectedWnd;
  if Wnd = 0 then Exit;
  if not IsWindowEnabled(Wnd) then begin
    MessageBeep(MB_ICONHAND);
    Exit;
  end;
  SendMessage(Wnd, WM_ACTIVATE, WA_ACTIVE, MakeLong(Wnd, Word(True)));
  if IsIconic(Wnd) then ShowWindow(Wnd, SW_RESTORE)
  else BringWindowToTop(Wnd);
  Close;
end;

procedure TTaskManager.MinimizeBtnClick(Sender: TObject);
begin
  Taskbar.MinimizeList(GetWindowList);
  Close;
end;

procedure TTaskManager.ArrangeBtnClick(Sender: TObject);
begin
  Desktop.ArrangeIcons;
  Close;
end;

function CanArrangeWindow(Wnd: HWnd): Boolean;
var
  R: TRect;
begin
  GetWindowRect(Wnd, R);
  Result := IsWindowVisible(Wnd) and not (IsRectEmpty(R) or IsIconic(Wnd) or
    IsZoomed(Wnd));
end;

procedure TTaskManager.TileHorzBtnClick(Sender: TObject);
begin
  Desktop.TileHorizList(GetWindowList);
  Close;
end;

procedure TTaskManager.TileVertBtnClick(Sender: TObject);
begin
  Desktop.TileVertList(GetWindowList);
  Close;
end;

procedure TTaskManager.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and not (ssCtrl in Shift) then
    Close;
end;

procedure TTaskManager.CancelBtnClick(Sender: TObject);
begin
  if IsWindow(LastActiveWindow) then SetActiveWindow(LastActiveWindow);
  Close;
end;

procedure TTaskManager.CascadeBtnClick(Sender: TObject);
begin
  Desktop.CascadeList(GetWindowList);
  Close;
end;

procedure TTaskManager.WMSysCommand(var Msg: TWMSysCommand);
begin
  if (Msg.Msg = SC_CLOSE) and IsWindow(LastActiveWindow) then
    SetActiveWindow(LastActiveWindow);
  inherited;
end;

procedure TTaskManager.GridDrawCell(Sender: TObject; Index: Integer;
  Rect: TRect; State: TGridDrawState);
var
  Glyph: TBitmap;
begin
  with Grid, Canvas do
  begin
    Glyph := TBitmap.Create;
    ShrinkIcon((TaskList.Objects[Index] as TTaskItem).Icon.Handle, Glyph,
      Brush.Color);
    FillRect(Rect);
    Draw(Rect.Left + 2, Rect.Top + 1, Glyph);
    if gdSelected in State then
      Font.Color := clHighlightText
    else
      Font.Color := clWindowText;
    Canvas.TextOut(Rect.Left + 22, Rect.Top+2, TaskList[Index]);
    Glyph.Free;
  end;
end;

procedure TTaskManager.GridDblClick(Sender: TObject);
begin
  SwitchToBtn.Click;
end;

procedure TTaskManager.GridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_ESCAPE: if not (ssCtrl in Shift) then Close;
    VK_RETURN: SwitchToBtn.Click;
    Ord('A') : if ssCtrl in Shift then with Grid do
                 if SelCount > 0 then DeselectAll else SelectAll;
  end;
end;

procedure TTaskManager.GridMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
begin
  with Grid do
  begin
    i := MouseToCell(X, Y);
    if (SelCount = Limit) and not PtInRect(CellBounds(i), Point(X, Y)) then
      DeselectAll;
  end;
end;

procedure TTaskManager.FormPaint(Sender: TObject);
begin
  Border3D(Canvas, ClientWidth - 1, ClientHeight - 1);
end;

procedure TTaskManager.HideBtnClick(Sender: TObject);
var
  Wnd: HWnd;
begin
  Wnd := SelectedWnd;
  if Wnd = 0 then Exit;
  if IsWindowVisible(Wnd) then
  begin
    ShowWindow(Wnd, SW_HIDE);
    Taskbar.DeleteButton(Wnd);
  end
  else
  begin
    ShowWindow(Wnd, SW_SHOWNA);
    Taskbar.AddButton(Wnd);
    if IsIconic(Wnd) then Taskbar.Perform(WM_HIDEQUERY, Wnd, 0);
  end;
  if IsWindow(LastActiveWindow) then SetActiveWindow(LastActiveWindow);
  Close;
end;

end.

