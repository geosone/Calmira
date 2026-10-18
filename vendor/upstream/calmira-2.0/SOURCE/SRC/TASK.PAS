{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.0                                                    }
{    Copyright (C) 1997  Li-Hsin Huang                                     }
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

unit Task;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Buttons, ExtCtrls, Stylsped, Menus, CalMsgs, StdCtrls, Profile;

type
  TWindowType = (wtGeneral, wtIconWindow, wtExplorer);

  TTaskButton = class(TStyleSpeed)
  private
    FWindow : HWnd;
    FTask   : THandle;
    FWindowType : TWindowType;
    procedure SetWindow(value : HWND);
  public
    constructor Create(AOwner : TComponent); override;
    procedure RefreshCaption;
    procedure AssignGlyph;
    function MinimizeCaption(s : string): string;
    property Window : HWND read FWindow write SetWindow;
    property Task : THandle read FTask;
    property WindowType : TWindowType read FWindowType;
  end;


  TButtonList = class(TList)
  private
    function GetButtons(i: Integer): TTaskButton;
  public
    property Buttons[i: Integer]: TTaskButton read GetButtons;
  end;


  TTrayProgram = class(TGraphicControl)
  private
    FGlyph : TBitmap;
    FModuleFile : TFilename;
    FCommand : TFilename;
    procedure HideAppIcon;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;
    procedure SetProgram(const command: TFilename);
    procedure Click; override;
  end;


  TBar = class(TForm)
    TaskMenu: TPopupMenu;
    Restore: TMenuItem;
    Minimize: TMenuItem;
    Maximize: TMenuItem;
    CloseItem: TMenuItem;
    StartBtn: TStyleSpeed;
    SysMenu: TPopupMenu;
    Terminate: TMenuItem;
    Quit: TMenuItem;
    Timer: TTimer;
    Clock: TPanel;
    Stay: TMenuItem;
    HideBar: TMenuItem;
    HintTimer: TTimer;
    Spy: TMenuItem;
    N2: TMenuItem;
    Properties1: TMenuItem;
    Startproperties1: TMenuItem;
    N1: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormDeactivate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure RestoreClick(Sender: TObject);
    procedure MinimizeClick(Sender: TObject);
    procedure MaximizeClick(Sender: TObject);
    procedure CloseItemClick(Sender: TObject);
    procedure TaskMenuPopup(Sender: TObject);
    procedure TerminateClick(Sender: TObject);
    procedure StartBtnMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure QuitClick(Sender: TObject);
    procedure SysMenuPopup(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure ClockMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ClockMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ClockMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure StayClick(Sender: TObject);
    procedure HideBarClick(Sender: TObject);
    procedure HintTimerTimer(Sender: TObject);
    procedure SpyClick(Sender: TObject);
    procedure Startproperties1Click(Sender: TObject);
    procedure Properties1Click(Sender: TObject);
    procedure ClockDblClick(Sender: TObject);
  private
    { Private declarations }
    BarShowing    : Boolean;
    ButtonList    : TButtonList;
    Excludes      : TStringList;
    HintWindow    : THintWindow;
    HintControl   : TControl;
    Pressed       : Integer;
    InTaskClick   : Boolean;
    HiddenList    : TList;
    ini           : TProfile;
    procedure TaskClick(Sender : TObject);
    procedure TaskMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure WMMouseActivate(var Msg : TWMMouseActivate); message WM_MOUSEACTIVATE;
    procedure ShellWndCreate(var Msg : TMessage); message WM_SHELLWNDCREATE;
    procedure ShellWndDestroy(var Msg : TMessage); message WM_SHELLWNDDESTROY;
    procedure WMMouseHook(var Msg : TMessage); message WM_MOUSEHOOK;
    procedure WMHideQuery(var Msg : TMessage); message WM_HIDEQUERY;
    procedure WMWinActivate(var Msg : TMessage); message WM_WINACTIVE;
    procedure WMAddButton(var Msg : TMessage); message WM_ADDBUTTON;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
    procedure AppMessage(var Msg : TMsg; var Handled : Boolean);
    function TaskToButton(task: THandle): Integer;
    function WndToButton(Wnd : HWnd): Integer;
    function ShouldExclude(Wnd : HWND): Boolean;
    procedure ShowMinimized(Wnd : HWND);
    procedure AppException(Sender: TObject; E: Exception);
  public
    { Public declarations }
    procedure Activate;
    procedure Deactivate;
    procedure Press(Wnd: HWND);
    procedure RefreshCaptions;
    procedure RefreshWindows;
    procedure ArrangeButtons;
    procedure UpdateButtons;
    procedure AddButton(Wnd : HWND);
    procedure DeleteButton(Wnd : HWND);
    procedure Configure;
    procedure ActivateHint(p: TPoint);
    procedure CancelHint;
    procedure SetClock(const s : string);
  end;

var
  Bar: TBar;

implementation

uses ShellAPI, ToolHelp, Strings;

{$R *.DFM}
{$R TASKBMPS.RES}

{ These headers are used to interface with the included DLL }

procedure StartTaskMonitor; far; external 'WNDHOOKS' index 1;
procedure StopTaskMonitor; far; external 'WNDHOOKS' index 2;
procedure SetWndHook; far; external 'WNDHOOKS' index 3;
procedure UnhookWndHook; far; external 'WNDHOOKS' index 4;
procedure SetYLimit(y: Integer); far; external 'WNDHOOKS' index 5;
procedure StartMouseMonitor; far; external 'WNDHOOKS' index 6;
procedure StopMouseMonitor; far; external 'WNDHOOKS' index 7;
procedure EnableMouseMonitor; far; external 'WNDHOOKS' index 8;
procedure DisableMouseMonitor; far; external 'WNDHOOKS' index 9;
procedure SetCallBackWnd(Wnd: HWND); far; external 'WNDHOOKS' index 10;
procedure SetMaxEnabled(value: Boolean); far; external 'WNDHOOKS' index 11;

var
  MinAppHeight : Integer;
  YLimit : Integer;
  UseMouseHook  : Boolean;
  ShrinkMax     : Boolean;
  Clock24       : Boolean;
  PopupRes      : Boolean;
  PopupDate     : Boolean;
  Animate       : Boolean;
  ButtonHints   : Boolean;
  MoveIconsUp   : Boolean;
  ArrangeMin    : Boolean;
  HideMinApps   : Boolean;
  ShowCalWindows: Boolean;
  StartMouseUp  : Boolean;
  DocNameFirst  : Boolean;
  DocNameLower  : Boolean;
  IgnoreGPF     : Boolean;
  LoadFromWinDir: Boolean;
  ConciseDT     : string[127];
  FullDT        : string[127];
  FullFolderPath: Boolean;
  ShowNoActivate : Boolean;
  ApplicationPath : TFilename;
  WinPath : TFilename;
  AlternateIconStretch : Boolean;

  ExplorerBmp    : TBitmap;
  FolderBmp     : TBitmap;



function GetMinPosition(Wnd: HWND): TPoint;
var place: TWindowPlacement;
begin
  { Returns the position of the window's icon }
  place.Length := sizeof(place);
  GetWindowPlacement(Wnd, @place);
  Result := place.ptMinPosition;
end;


procedure MoveDesktopIcon(Wnd: HWND; pt: TPoint);
var
  place: TWindowPlacement;
begin
  { Repositions a window's icon.  If the window is minimized,
    it must be hidden before being moved to ensure that the
    desktop background is updated }

  place.Length := sizeof(place);
  GetWindowPlacement(Wnd, @place);

  with place.ptMinPosition do
    if (x = pt.x) and (y = pt.y) then Exit;

  place.ptMinPosition := pt;
  place.Flags := place.Flags or WPF_SETMINPOSITION;

  if IsIconic(Wnd) then begin
    ShowWindow(Wnd, SW_HIDE);
    place.ShowCmd := SW_SHOWMINNOACTIVE;
  end
  else
    place.ShowCmd := SW_SHOWNA;
  SetWindowPlacement(Wnd, @place);
end;


procedure RaiseWindow(Wnd: HWnd);
var p: TPoint;
begin
  { Shifts a minimized window up a little }
  p := GetMinPosition(Wnd);
  if (p.y > YLimit - MinAppHeight) and (p.y < Screen.Height) then begin
    p.y := YLimit - MinAppHeight;
    MoveDesktopIcon(Wnd, p);
  end;
end;





function TButtonList.GetButtons(i: Integer): TTaskButton;
begin
  Result := TTaskButton(Items[i]);
end;

function InitBitmap(ABitmap: TBitmap;
  AWidth, AHeight : Integer; Color : TColor) : TBitmap;
begin
  { initializes a bitmap with width, height and background colour }

  with ABitmap do begin
    Width := AWidth;
    Height := AHeight;
    Canvas.Brush.Color := Color;
    Canvas.FillRect(Rect(0, 0, Width, Height));
  end;
  Result := ABitmap;
end;


procedure ShrinkIcon(H : HIcon; Glyph : TBitmap);
var
  bmp : TBitmap;
  i, j : Integer;
  src, dest : HDC;
  OldStretch : Integer;
begin
  bmp := InitBitmap(TBitmap.Create, 32, 32, clSilver);
  DrawIcon(bmp.Canvas.Handle, 0, 0, H);

  try
    with Glyph do begin
      Width := 16;
      Height := 16;

      src := bmp.Canvas.Handle;
      dest := Canvas.Handle;

      { Canvas.StretchDraw seems to use a stretch mode which is
        not ANDSCANS, ORSCANS or DELETESCANS! Retreiving the mode
        produces STRETCH_ANDSCANS but the black is mostly missing } 

      if AlternateIconStretch then begin
        OldStretch := SetStretchBltMode(dest, STRETCH_ANDSCANS);
        StretchBlt(dest, 0, 0, 16, 16, src, 0, 0, 32, 32, SRCCOPY);
        SetStretchBltMode(dest, OldStretch);
      end
      else begin
        Canvas.StretchDraw(Rect(0, 0, 16, 16), bmp);

        for i := 0 to 15 do
          for j := 0 to 15 do
           if GetPixel(dest, i, j) = clSilver then
             SetPixel(dest, i, j, GetPixel(src, i shl 1, j shl 1));
      end;
      Canvas.Pixels[0, 15] := clBtnFace;
    end;
  finally
    bmp.Free;
  end;
end;


procedure GetModuleAndClass(Wnd: HWND; var f, c: OpenString);
begin
  { Fills two strings with the module and class names of a window }
  f[0] := Chr(GetModuleFilename(GetWindowWord(Wnd, GWW_HINSTANCE), @f[1], High(f)-1));
  c[0] := Chr(GetClassName(Wnd, @c[1], High(c)-1));
end;



function IsTaskWindow(Wnd: HWND): Boolean;
var
  Style: Longint;
begin
  { Returns true if the window qualifies as a "task" }

  Style  := GetWindowLong(Wnd, GWL_STYLE);
  Result := (GetWindowWord(Wnd, GWW_HWNDPARENT) = 0) and
             Bool(GetWindowTextLength(Wnd)) and
             ((Style and WS_MINIMIZEBOX <> 0) or
              (Style and WS_MAXIMIZEBOX <> 0) or
              (Style and WS_THICKFRAME <> 0) or
              (Style and WS_SYSMENU <> 0));
end;


{
function IsTaskWindow(Wnd: HWND): Boolean;
begin
  Result := (GetWindow(Wnd, GW_OWNER) = 0) and
             Bool(GetWindowTextLength(Wnd)) and
             (GetwindowLong(Wnd, GWL_STYLE) and WS_SYSMENU <> 0) and
             (GetWindowTask(Wnd) <> GetCurrentTask);
end;
}

function IsVisibleTaskWindow(Wnd: HWND): Boolean;
begin
  Result := IsTaskWindow(Wnd) and IsWindowVisible(Wnd);
end;


function IsHiddenTaskWindow(Wnd: HWND): Boolean;
begin
  Result := IsTaskWindow(Wnd) and not IsWindowVisible(Wnd);
end;


function EnumWinProc(Wnd: HWnd; Bar: TBar): Bool; export;
begin
  { Adds all visible task windows to the bar }
  if IsVisibleTaskWindow(Wnd) and (GetWindowTask(Wnd) <> GetCurrentTask) then begin
    Bar.Perform(WM_SHELLWNDCREATE, Wnd, 0);
    if IsIconic(Wnd) then Bar.Perform(WM_HIDEQUERY, Wnd, 0);
  end;
  Result := True;
end;




{ TTaskButton }

constructor TTaskButton.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  Style := sbWin95;
  Margin := 2;
  Spacing := 1;
  GroupIndex := 1;
  AllowAllUp := True;
end;


procedure TTaskButton.SetWindow(value : HWND);
var
  filename, classname : string[127];
begin
  FWindow := value;
  FTask := GetWindowTask(FWindow);

  GetModuleAndClass(Window, filename, classname);
  filename := ExtractFilename(filename);

  FWindowType := wtGeneral;

  if filename = 'CALMIRA.EXE' then begin
    if classname = 'TIconWindow' then FWindowType := wtIconWindow
    else if classname = 'TExplorer' then FWindowType := wtExplorer
  end;

  AssignGlyph;
  RefreshCaption;
end;

procedure ChooseBitmap(Dest, Source: TBitmap; Res: PChar);
begin
  if Source.Empty then Dest.Handle := LoadBitmap(HInstance, Res)
  else Dest.Assign(Source);
end;

(*
procedure TTaskButton.AssignGlyph;
var
  m, c : string[127];
  h : HIcon;
  ImageLoaded : Boolean;
begin
  ImageLoaded := False;

  if CalmiraWindow > 0 then begin

    if ShowCalWindows and (FWindowType <> wtGeneral) then begin
      case FWindowType of
        wtIconWindow : ChooseBitmap(Glyph, FolderBmp, 'FOLDERBMP');
        wtExplorer   : ChooseBitmap(Glyph, ExplorerBmp, 'EXPLORERBMP');
      end;
      ImageLoaded := True;
    end

    else begin
      { Ask Calmira to provide an icon }
      Application.ProcessMessages;
      h := SendMessage(CalmiraWnd, WM_CALMIRA, CM_GETTASKICON,
        GetWindowWord(Window, GWW_HINSTANCE));
      if h > 1 then begin
        ShrinkIcon(h, Glyph);
        DestroyIcon(h);
        ImageLoaded := True;
      end;
    end;
  end;

  if not ImageLoaded then begin
    GetModuleAndClass(Window, m, c);
    h := ExtractIcon(HInstance, StringAsPChar(m), 0);
    ShrinkIcon(h, Glyph);
    DestroyIcon(h);
  end;
end;
*)

procedure TTaskButton.AssignGlyph;
var
  m, c : string[127];
  h : HIcon;
begin
  if CalmiraWindow > 0 then begin

    if ShowCalWindows and (FWindowType <> wtGeneral) then
      case FWindowType of
        wtIconWindow : ChooseBitmap(Glyph, FolderBmp, 'FOLDERBMP');
        wtExplorer   : ChooseBitmap(Glyph, ExplorerBmp, 'EXPLORERBMP');
      end

    else begin
      { Ask Calmira to provide an icon }
      Application.ProcessMessages;
      h := SendMessage(CalmiraWnd, WM_CALMIRA, CM_GETTASKICON,
        GetWindowWord(Window, GWW_HINSTANCE));
      if h > 1 then begin
        ShrinkIcon(h, Glyph);
        DestroyIcon(h);
      end;
    end;
  end;

  if Glyph.Empty then begin
    GetModuleAndClass(Window, m, c);
    h := ExtractIcon(HInstance, StringAsPChar(m), 0);
    ShrinkIcon(h, Glyph);
    DestroyIcon(h);
  end;
end;


function TTaskButton.MinimizeCaption(s : string): string;

var i, j   : Integer;    { counters }
    target : Integer;    { maximum width of text that can fit }
    dw     : Integer;    { width of three dots }
    tw     : Integer;    { current text width }
    app, doc : string[79];
begin
  { Given a string and a button width, truncate it so that it fits
    comfortably on the button.  First check if it fits.  If it doesn't,
    keep chopping the end off until it does and append three dots to it.

    To avoid calling Canvas.TextWidth too many times, the string
    is cut in half if the width is over twice the desired width

    Bizzare bug: change Bar.Canvas to just Canvas and something very
    strange happens... }

  if DocNameFirst then begin
    i := Pos(' - ', s);
    if i > 0 then begin
      app := Copy(s, 1, i-1);
      doc := Copy(s, i+3, 255);
      if DocNameLower then doc := Lowercase(doc);
      s := Format('%s - %s', [doc, app]);
    end;
  end;

  tw := Bar.Canvas.TextWidth(s);

  if (tw > Width - 22) then begin
    dw := Bar.Canvas.TextWidth('...');
    target := Width - 22 - dw;

    if target < dw then begin
      Result := '';
      exit;
    end;

    repeat
      if (tw > target * 2) and (s[0] > #1)  then Dec(s[0], ord(s[0]) div 2)
      else Dec(s[0]);
      tw := Bar.Canvas.TextWidth(s);
    until ((tw <= Target) or (Length(s) = 1));
    if Length(s) <= 1 then s := ''
    else AppendStr(s, '...');
  end;

  Result := s;
end;


function GetDirectory(Wnd : Hwnd): string;
var
  h : THandle;
begin
  h := GlobalAlloc(GMEM_SHARE, 256);
  try
    SendMessage(Wnd, WM_QUERYPATH, h, 0);
    Result := StrPas(GlobalLock(h));
    GlobalUnlock(h);
  finally
    GlobalFree(h);
  end;
end;

procedure TTaskButton.RefreshCaption;
var
  s: string[127];
begin
  s[0] := Chr(GetWindowText(Window, @s[1], 126));

  if (FWindowType = wtIconWindow) then begin
    Hint := GetDirectory(Window);
    if not FullFolderPath and (Length(s) > 3) and (s[2] = ':') and (s[3] = '\') then
      s := ExtractFilename(s);
  end
  else Hint := s;

  Caption := MinimizeCaption(s);
end;


{ routine for finding a window belonging to a module -- the module handle,
  not instance handle, is given so GetWindowWord can't be used }

var FoundWindow : HWND;

function WinModuleProc(Wnd: HWnd; Filename: PChar): Bool; export;
var
  buf : array[0..127] of char;
begin
  if IsTaskWindow(Wnd) then begin
    GetModuleFilename(GetWindowWord(Wnd, GWW_HINSTANCE), buf, 127);
    if StrComp(Filename, buf) = 0 then begin
      FoundWindow := Wnd;
      Result := False;
      Exit;
    end;
  end;
  FoundWindow := 0;
  Result := True;
end;


{ TTrayProgram }

constructor TTrayProgram.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FGlyph := TBitmap.Create;
  SetBounds(0, 0, 20, 20);
  Align := alLeft;
end;

destructor TTrayProgram.Destroy;
begin
  FGlyph.Free;
  inherited Destroy;
end;

procedure TTrayProgram.Paint;
begin
  Canvas.Draw((Width - FGlyph.Width) div 2, (Height - FGlyph.Height) div 2, FGlyph);
end;

procedure TTrayProgram.SetProgram(const command: TFilename);
var
  h : HIcon;
  p : Integer;
begin
  FCommand := command;
  FModuleFile := Uppercase(command);
  p := Pos(' ', FModuleFile);
  if p > 1 then FModuleFile[0] := Chr(p-1);

  h := ExtractIcon(HInstance, StringAsPChar(FModuleFile), 0);
  try
    ShrinkIcon(h, FGlyph);
  finally
    DestroyIcon(h);
  end;

  HideAppIcon;
end;

procedure TTrayProgram.HideAppIcon;
begin
  EnumWindows(@WinModuleProc, Longint(@FModuleFile[1]));
  if FoundWindow > 0 then MoveDesktopIcon(FoundWindow, Point(0, Screen.Height));
end;

procedure TTrayProgram.Click;
begin
  if GetModuleHandle(@FModuleFile[1]) > 0 then begin
    { Re-activate the utility }
    EnumWindows(@WinModuleProc, Longint(@FModuleFile[1]));
    if FoundWindow > 0 then
      if IsIconic(FoundWindow) then ShowWindow(FoundWindow, SW_RESTORE)
      else BringWindowToTop(FoundWindow)
  end
  else begin
    { run a new instance }
    WinExec(StringAsPChar(FCommand), SW_SHOW);
    HideAppIcon;
  end;
end;


function LoadBitmapExtern(filename: TFilename): TBitmap;
begin
  Result := TBitmap.Create;
  if FileExists(filename) then Result.LoadFromFile(filename);
end;

{ Main taskbar }


procedure TBar.FormCreate(Sender: TObject);
var
  i: Integer;
  Wnd : HWND;
  buf : TFilename;
begin
  Pressed := -1;
  SetCallBackWnd(Handle);

  HintWindow := THintWindow.Create(Application);
  HintWindow.Visible := False;

  if Screen.PixelsPerInch > 96 then
    StartBtn.Width := StartBtn.Width + 6;

  Screen.Cursor := crHourGlass;
  try
    with TProFile.Create(WinPath + 'WIN.INI') do begin
      LoadFromWinDir := ReadBool('Calmira', 'LoadFromWinDir', False);
      Free;
    end;
    if LoadFromWinDir then
      ini := TProfile.Create(WinPath + 'CALMIRA.INI')
    else
      ini := TProfile.Create(ApplicationPath + 'CALMIRA.INI');

    with Application do begin
      SetWindowLong(Handle, GWL_STYLE,
        GetWindowLong(Handle, GWL_STYLE) and
          not (WS_MAXIMIZEBOX or WS_MINIMIZEBOX));

      OnDeactivate := FormDeactivate;
      OnMessage := AppMessage;
      OnException := AppException;
    end;

    ExplorerBmp := LoadBitmapExtern(ApplicationPath + 'TASKEXP.BMP');
    FolderBmp := LoadBitmapExtern(ApplicationPath + 'TASKFOLD.BMP');

    Setbounds(0, Screen.Height -1, Screen.Width, Height);
    ButtonList := TButtonList.Create;
    HiddenList := TList.Create;

    Configure;

    YLimit := Screen.Height - ClientHeight;
    SetYLimit(YLimit);

    StartTaskMonitor;
    if UseMouseHook then StartMouseMonitor;
    SetWndHook;

    if Stay.Checked then Activate else Deactivate;

    EnumWindows(@EnumWinProc, Longint(self));
  finally
    Screen.Cursor := crDefault;
    DragAcceptFiles(Handle, True);
  end;
end;


procedure TBar.WMMouseHook(var Msg : TMessage);
begin
  { Called by the DLL when the cursor leaves the taskbar }
  if not Stay.Checked and (GetCapture = 0) and BarShowing then Deactivate
  else if ButtonHints and HintWindow.Visible then CancelHint;
end;


procedure TBar.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if not BarShowing then Activate;
  CancelHint;
end;


procedure TBar.FormDeactivate(Sender: TObject);
begin
  if not Stay.Checked then Deactivate;
end;


procedure TBar.Deactivate;
var i : Integer;
begin
  { Suspends the taskbar until it is re-activated by the mouse }
  DisableMouseMonitor;
  Timer.Enabled := False;
  BarShowing := False;
  CancelHint;
  Top := Screen.Height - 1;
  if Animate then for i := 0 to ControlCount-1 do Controls[i].Hide;
end;


function TBar.TaskToButton(task: THandle): Integer;
begin
  { Returns the button index for a given task handle, -1 if the
    task is not shown on the bar }

  with ButtonList do
    for Result := 0 to Count-1 do
      if task = Buttons[Result].Task then Exit;
  Result := -1;
end;


function TBar.WndToButton(Wnd : HWnd): Integer;
begin
  { Returns the button index for a given window handle, -1 if the
  task is not shown on the bar }

  with ButtonList do
    for Result := 0 to Count-1 do
      if Wnd = Buttons[Result].Window then Exit;
  Result := -1;
end;


procedure TBar.Press(Wnd: HWND);
var
  i: Integer;
begin
  { Called when a window receives a WM_ACTIVATE message.  If there is
    a button for that window or the task it belongs to, then that
    button is pressed }

  i := WndToButton(Wnd);
  if i = -1 then i := TaskToButton(GetWindowTask(Wnd));

  with ButtonList do
    if i > -1 then
      Buttons[i].Down := True
    else if (Pressed > -1) and (Pressed < Count) then
      Buttons[Pressed].Down := False;

  Pressed := i;
end;


procedure TBar.UpdateButtons;
begin
  RefreshWindows;
  ArrangeButtons;
  Press(GetActiveWindow);
end;


procedure TBar.Activate;
var
  i : Integer;
  Wnd : HWND;
begin
  Timer.Enabled := True;
  SetClock(FormatDateTime(ConciseDT, Now));
  UpdateButtons;

  { Move the form up 5 pixels at a time and then show the buttons }

  if Animate then begin
    i := Screen.Height - 1;
    while i >= Screen.Height - ClientHeight + 5 do begin
      Top := i;
      Dec(i, 5);
    end;
    Top := Screen.Height - ClientHeight;
  end;

  if not StartBtn.Visible then
    for i := 0 to ControlCount-1 do Controls[i].Show;

  Top := Screen.Height - ClientHeight;
  BarShowing := True;
  EnableMouseMonitor;
end;


procedure TBar.FormPaint(Sender: TObject);
begin
  with Canvas do begin
    if BarShowing then begin
      { Paint the 3D effect around the edges }
      Pen.Color := clBtnHighLight;
      MoveTo(0, ClientHeight-1);
      LineTo(0, 1);
      LineTo(ClientWidth-1, 1);
      Pen.Color := clBtnShadow;
      LineTo(ClientWidth-1, ClientHeight-1);
    end;

    { Draw a black line across the top }
    Pen.Color := clBlack;
    MoveTo(0, 0);
    LineTo(ClientWidth, 0);
  end;
end;


procedure TBar.ArrangeButtons;
var i, t, h, w, x, avail: Integer;
begin
  { w is the width of a button plus the gap to its right}

  avail := ClientWidth - StartBtn.Width - Clock.Width - 8;

  case ButtonList.Count of
    0: Exit;
    1..2: w := avail div 3;
  else
    w := avail div ButtonList.Count;
  end;

  { x is initialised to the left side of the first button }

  x := StartBtn.Left + StartBtn.Width + 3;
  t := StartBtn.Top;
  h := StartBtn.Height;

  with ButtonList do
    for i := 0 to Count-1 do begin
      Buttons[i].SetBounds(x, t, w - 3, h);
      Inc(x, w);
    end;

  RefreshCaptions;
end;



procedure TBar.RefreshCaptions;
var
  i: Integer;
begin
  with ButtonList do
    for i := 0 to Count-1 do Buttons[i].RefreshCaption;
end;


procedure TBar.RefreshWindows;
var
  i: Integer;
  Wnd : HWND;
begin
  { remove any windows that no longer exist or have disappeared }

  i := 0;
  with ButtonList do
  for i := Count-1 downto 0 do begin
    Wnd := Buttons[i].Window;
    if not IsWindow(Wnd) or not IsWindowVisible(Wnd)
      or (GetWindowTextLength(Buttons[i].Window) = 0) then begin
      Buttons[i].Free;
      Delete(i);
    end;
  end;
end;


procedure TBar.AddButton(Wnd : HWND);
var
  button : TTaskButton;
begin
  if WndToButton(Wnd) <> -1 then Exit;

  button := TTaskButton.Create(self);

  with button do begin
    Left := -64;
    Parent := self;
    Window := Wnd;
    OnClick := TaskClick;
    OnMouseDown := TaskMouseDown;
    OnMouseMove := ClockMouseMove;
  end;

  if not IsWindow(Wnd) then begin
    button.Free;
    Exit;
  end;
  ButtonList.Add(button);
  if BarShowing then ArrangeButtons;
end;


procedure TBar.DeleteButton(Wnd : HWND);
var i: Integer;
begin
  { When Wnd is destroyed, look for a button with the matching window
    and remove it, then rearrange the other buttons }

  with ButtonList do
  for i := 0 to Count-1 do
    if Buttons[i].Window = Wnd then begin
      Buttons[i].Free;
      Delete(i);
      ArrangeButtons;
      Exit;
    end;
end;


procedure TBar.TaskClick(Sender : TObject);
var
  wnd : HWND;
  i : Integer;
begin
  { This is the event handler for normal task buttons.

    Disabled child windows are skipped in case they cover up the
    active window (e.g. if an icon window covers up a modal dialog,
    there is no way to end the modal state).

    The SendMessage trick is required to access full screen DOS boxes
    because of a bug (solution provided by Microsoft) }

  Wnd := (Sender as TTaskButton).Window;

  if not IsWindowEnabled(Wnd) and (
    TTaskButton(Sender).WindowType <> wtGeneral) then begin
    MessageBeep(0);
    Exit;
  end;

  InTaskClick := True;
  SendMessage(Wnd, WM_ACTIVATE, WA_ACTIVE, MakeLong(Wnd, Word(True)));
  InTaskClick := False;

  if IsIconic(Wnd) then ShowWindow(Wnd, SW_RESTORE)
  else BringWindowToTop(Wnd);
end;



function TBar.ShouldExclude(Wnd : HWND): Boolean;
var
  fname, cname: string[127];
begin
  { Returns True if Wnd should be excluded from the bar }

  GetModuleAndClass(Wnd, fname, cname);
  fname := ExtractFilename(fname);

  Result := (Excludes.IndexOf(fname) > -1) or
            (Excludes.IndexOf(Format('%s %s', [fname, cname])) > -1);
end;


procedure TBar.ShellWndCreate(var Msg : TMessage);
begin
  { Called by the shell hook when a top-level window is created }

  with msg do
    if not ShouldExclude(wParam) then
      if IsHiddenTaskWindow(wParam) then
        HiddenList.Add(Pointer(wParam))
      else if IsVisibleTaskWindow(wParam) then begin
        AddButton(wParam);
        if IsIconic(wParam) then Perform(WM_HIDEQUERY, wParam, 0);
      end;
end;


procedure TBar.ShellWndDestroy(var Msg : TMessage);
var i: Integer;
begin
  { Called by the shell hook when a top-level window is created }
  i := HiddenList.IndexOf(Pointer(msg.wParam));
  if i > -1 then HiddenList.Delete(i)
  else DeleteButton(msg.wParam);
end;


procedure TBar.FormDestroy(Sender: TObject);
var i: Integer;
begin
  StopMouseMonitor;
  StopTaskMonitor;
  UnhookWndHook;

  { Apps which have had their icon moved off the screen must be restored
    properly.  If Calmira is active, then its ArrangeIcons function is
    called, but the icons must be moved above Screen.Height so that
    Calmira knows that they are not supposed to be hidden }

  if (CalmiraWindow > 0) then begin
    for i := 0 to ButtonList.Count-1 do
      MoveDesktopIcon(ButtonList.Buttons[i].Window,
      Point(0, Screen.Height-1));
    PostMessage(CalmiraWnd, WM_CALMIRA, CM_ARRANGEICONS, 0)
  end
  else
    ArrangeIconicWindows(GetDesktopWindow);

  Excludes.Free;
  HiddenList.Free;
  ButtonList.Free;
  FolderBmp.Free;
  ExplorerBmp.Free;

  ini.Free;
end;


procedure TBar.StartBtnClick(Sender: TObject);
var
  p: TPoint;
begin
  DisableMouseMonitor;
  p := Point(0, Top);
  PostMessage(CalmiraWindow, WM_CALMIRA, CM_STARTMENU, Longint(p))
end;


procedure TBar.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  control : TControl;
  i : Integer;
begin
  { "Terminate" mode distinguished by the cursor being crNoDrop }

  if Cursor = crNoDrop then begin

    if Button = mbLeft then begin
      control := ControlAtPos(Point(X, Y), True);
      if control is TTaskButton then
        TerminateApp(TTaskButton(control).Task, NO_UAE_BOX);
    end;

    for i := 0 to ControlCount-1 do Controls[i].Enabled := True;
    Cursor := crDefault;
  end;
end;


procedure TBar.TaskMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var p: TPoint;
begin
  { To remember which button the right mouse button was pressed over,
    tha Tag is used rather than using the PopupComponent property --
    just in case the button gets deleted before the menu click occurs }

  if Button = mbLeft then exit;
  TaskMenu.Tag := (Sender as TTaskButton).Window;
  DisableMouseMonitor;
  GetCursorPos(p);
  TaskMenu.Popup(p.X, p.Y);
  EnableMouseMonitor;
end;

procedure TBar.RestoreClick(Sender: TObject);
begin
  ShowWindow(TaskMenu.Tag, SW_RESTORE);
end;

procedure TBar.MinimizeClick(Sender: TObject);
begin
  CloseWindow(TaskMenu.Tag);
end;

procedure TBar.MaximizeClick(Sender: TObject);
begin
  ShowWindow(TaskMenu.Tag, SW_SHOWMAXIMIZED);
end;

procedure TBar.CloseItemClick(Sender: TObject);
begin
  PostMessage(TaskMenu.Tag, WM_CLOSE, 0, 0);
end;


procedure TBar.TaskMenuPopup(Sender: TObject);
var
  Wnd : HWND;
  Zoomed, Iconic, E: Boolean;
  Style : Longint;
begin
  with TaskMenu do begin
    Wnd := Tag;
    Zoomed := IsZoomed(Wnd);
    Iconic := IsIconic(Wnd);
    Style := GetWindowLong(Wnd, GWL_STYLE);

    E := IsWindowEnabled(Wnd);
    Restore.Enabled := E and (Zoomed or Iconic);
    Minimize.Enabled := E and not Iconic and (Style and WS_MINIMIZEBOX <> 0);
    Maximize.Enabled := E and not Zoomed and (Style and WS_MAXIMIZEBOX <> 0);
    CloseItem.Enabled := E;
  end;
end;



procedure TBar.TerminateClick(Sender: TObject);
var i: Integer;
begin
  { Start terminate mode by disabling buttons and setting crNoDrop cursor }

  StartBtn.Enabled := False;
  with ButtonList do
  for i := 0 to Count-1 do begin
    Buttons[i].Down := False;
    Buttons[i].Enabled := False;
  end;
  Cursor := crNoDrop;
  Pressed := -1;
end;


procedure TBar.StartBtnMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var p: TPoint;
begin
  if Button = mbRight then begin
    DisableMouseMonitor;
    GetCursorPos(p);
    SysMenu.Popup(p.X, p.Y);
    EnableMouseMonitor;
  end
  else if not StartMouseUp then begin
    { Restore start button state by simulating a mouse click }
    StartBtnClick(self);
    PostMessage(Handle, WM_LBUTTONUP, 0,
      MakeLong(StartBtn.Left + 3, StartBtn.Top + 3));
  end;
end;


procedure TBar.QuitClick(Sender: TObject);
begin
  Close;
end;


procedure TBar.SysMenuPopup(Sender: TObject);
begin
  Terminate.Enabled := ControlCount > 3;
end;


procedure TBar.FormResize(Sender: TObject);
begin
  Clock.Left := ClientWidth - 3 - Clock.Width;
end;


procedure TBar.TimerTimer(Sender: TObject);
const
  MouseButtons : array[Boolean] of Word = (VK_LBUTTON, VK_RBUTTON);
begin
  if GetAsyncKeyState(MouseButtons[Bool(
    GetSystemMetrics(SM_SWAPBUTTON))]) >= 0 then
   SetClock(FormatDateTime(ConciseDT, Now));

  if BarShowing then UpdateButtons;
end;



procedure TBar.ClockMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SetClock(IntToStr(GetFreeSpace(0) div 1024) + ' KB');
end;


procedure TBar.ClockMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SetClock(FormatDateTime(ConciseDT, Now));
end;

procedure TBar.ClockMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if (HintControl = Sender) or ((Sender is TTaskButton) and not ButtonHints) or
      ((Sender = Clock) and not (PopupRes or PopupDate)) then Exit;

  HintControl := Sender as TControl;

  if Hintwindow.Visible then
    ActivateHint(HintControl.ClientToScreen(Point(X, Y)))
  else
    HintTimer.Enabled := True;
end;


procedure TBar.ShowMinimized(Wnd : HWND);
begin
  if not IsIconic(Wnd) and
    (GetWindowLong(Wnd, GWL_STYLE) and WS_MINIMIZEBOX <> 0) then begin
    Perform(WM_HIDEQUERY, Wnd, 0);
    ShowWindow(Wnd, SW_SHOWMINIMIZED);
  end;
end;

procedure TBar.AppMessage(var Msg : TMsg; var Handled : Boolean);
var
  p: TPoint;
  control : TControl;
  i : Integer;
  Wnd : HWND;
begin
  { Application.OnMessage handler. }

  if (Msg.Message = WM_SYSCOMMAND) and (Msg.wParam = SC_SCREENSAVE) then
    Deactivate

  else if Msg.Message = WM_DROPFILES then begin
    { Find the target window and check that it accepts files before
      forwarding the message on }
    DragQueryPoint(Msg.wParam, p);
    control := ControlAtPos(p, False);
    if control <> nil then begin
      i := ButtonList.IndexOf(control);
      if (i > -1) and (ButtonList.Buttons[i].WindowType = wtGeneral) then begin
        Wnd := ButtonList.Buttons[i].Window;
        if GetWindowLong(Wnd, GWL_EXSTYLE) and WS_EX_ACCEPTFILES <> 0 then begin
          PostMessage(Wnd, WM_DROPFILES, Msg.wParam, Msg.lParam);
          Exit;
        end;
      end;
    end;
    { release files after an error }
    DragFinish(Msg.wParam);
    MessageBeep(0);
  end

  else if Msg.Message = WM_CALMIRA then begin
    Handled := True;
    case Msg.wParam of
      CM_TASKCONFIG    : Configure;
      CM_STARTCLOSE    : begin
                           StartBtn.Down := False;
                           GetCursorPos(p);
                           if not (Stay.Checked or PtInRect(BoundsRect, p)) then Deactivate;
                           EnableMouseMonitor;
                         end;
      CM_UNLOADTASKBAR : Application.Terminate;
      CM_ADDCALWINDOW  : if ShowCalWindows then AddButton(LoWord(Msg.lParam));
      CM_DELCALWINDOW  : DeleteButton(Msg.lParam);
      CM_MINIMIZEALL   : with ButtonList do
                           for i := 0 to Count-1 do
                             ShowMinimized(Buttons[i].Window);
      CM_STARTKEYPOPUP : begin
                           if Top > Screen.Height-3 then Activate;
                           StartBtn.Down := True;
                           StartBtnClick(self);
                         end;
    end;
  end

  else if HintWindow.IsHintMsg(Msg) then CancelHint
end;


procedure TBar.Configure;
var
  i : Integer;
  TrayApps : TStringList;
  s : string;
begin
  { reads settings and adjusts controls to reflect the changes }

  Excludes.Free;
  Excludes := TStringList.Create;

  with ini do begin
    ReadStrings('Exclude', Excludes);
    Timer.Interval     := ReadInteger('Taskbar', 'Refresh', 5) * 1000;
    MinAppHeight       := ReadInteger('Taskbar', 'MinAppHeight', 60);
    HintTimer.Interval := ReadInteger('Taskbar', 'HintDelay', 800);
    UseMouseHook       := ReadBool('Taskbar', 'UseMouseHook', True);
    Stay.Checked       := ReadBool('Taskbar', 'StayVisible', False);
    ShrinkMax          := ReadBool('Taskbar', 'ShrinkMax', True);
    Clock24            := ReadBool('Taskbar', 'Clock24', False);
    PopupRes           := ReadBool('Taskbar', 'PopupRes', True);
    PopupDate          := ReadBool('Taskbar', 'PopupDate', True);
    Animate            := ReadBool('Taskbar', 'Animate', True);
    ButtonHints        := ReadBool('Taskbar', 'ButtonHints', True);
    ArrangeMin         := ReadBool('Taskbar', 'ArrangeMin', True);
    HideMinApps        := ReadBool('Taskbar', 'MideMinApps', True);
    ShowCalWindows     := ReadBool('Taskbar', 'ShowCalWindows', True);
    DocNameFirst       := ReadBool('Taskbar', 'DocNameFirst', False);
    DocNameLower       := ReadBool('Taskbar', 'DocNameLower', False);
    StartMouseUp       := ReadBool('Start Menu', 'StartMouseUp', True);
    FullFolderPath     := ReadBool('Taskbar', 'FullFolderPath', False);
    AlternateIconStretch := ReadBool('Taskbar', 'AlternateStretch', False);
    IgnoreGPF            := ReadBool('Taskbar', 'IgnoreGPF', False);
    ShowNoActivate := ReadBool('Taskbar', 'ShowNoActivate', True);

    if Clock24 then
      ConciseDT := ReadString('Taskbar', '24HourFormat', 'h:mm')
    else
      ConciseDT := ReadString('Taskbar', '12HourFormat', 'h:mm AM/PM');

    FullDT := ReadString('Taskbar', 'FullDateTime', 'dddd, mmmm d, yyyy');
    Color := StringToColor(ReadString('Colors', 'Taskbar', 'clSilver'));

    with StartBtn do begin
      Caption := ReadString('Start button', 'Caption', 'Start');
      Left := ReadInteger('Start button', 'Left', Left);
      Width := ReadInteger('Start button', 'Width', Width);
      s := ApplicationPath + 'startbtn.bmp';
      if FileExists(s) then Glyph.LoadFromFile(s);
    end;

    ReadFont('Taskbar', Font);
    ReadFont('Start button', StartBtn.Font);
  end;

  if not StartMouseUp then StartBtn.OnClick := nil
  else StartBtn.OnClick := StartBtnClick;

  SetMaxEnabled(Stay.Checked and ShrinkMax);


  { Clear Calmira buttons if they have been turned off, and also
    adjust button states }

  with ButtonList do
    for i := Count-1 downto 0 do with Buttons[i] do
      if not ShowCalWindows and (WindowType <> wtGeneral) then begin
        Free;
        ButtonList.Delete(i)
      end else begin
        GroupIndex := 1;
        Down := False;
      end;

  { Clear the Applet Tray }

  with Clock do begin
    i := ControlCount * 20;
    Left := Left + i;
    Width := Width - i;
    while ControlCount > 0 do Controls[0].Free;
  end;
  Clock.Alignment := taCenter;

  TrayApps := TStringList.Create;
  ini.ReadSectionValues('Applet Tray', TrayApps);

  { Load Applet Tray programs }

  if TrayApps.Count > 0 then begin
    Clock.Alignment := taRightJustify;
    for i := 0 to TrayApps.Count-1 do begin
      s := TrayApps[i];

      with Clock do begin
        Left := Left - 20;
        Width := Width + 20;
      end;

      with TTrayProgram.Create(self) do begin
        SetProgram(GetStrValue(s));
        Hint := GetStrKey(s);
        Parent := Clock;
        OnMouseMove := ClockMouseMove;
      end;
      Excludes.Add(ExtractFilename(GetStrValue(s)));
    end;
  end;

  TrayApps.Free;

  TimerTimer(self);
end;


procedure TBar.StayClick(Sender: TObject);
begin
  Stay.Checked := not Stay.Checked;
  SetMaxEnabled(Stay.Checked and ShrinkMax);
  EnableMouseMonitor;
end;


procedure TBar.HideBarClick(Sender: TObject);
begin
  Deactivate;
end;


procedure TBar.CancelHint;
begin
  with HintWindow do begin
    Visible := False;
    if HandleAllocated then ShowWindow(Handle, SW_HIDE);
  end;
  HintControl := nil;
end;


procedure TBar.ActivateHint(P: TPoint);
var
  HintStr: string;
  fname, cname: string[127];
  r : TRect;

procedure AddField(const s: string);
begin
  if HintStr > '' then AppendStr(HintStr, '  ');
  AppendStr(Hintstr, s);
end;

begin
  if HintControl = nil then Exit;
  if HintWindow.HandleAllocated then ShowWindow(HintWindow.Handle, SW_HIDE);

    if HintControl = Clock then begin
      HintStr := '';
      if PopupDate then AddField(FormatDateTime(FullDT, Now));
      if PopupRes then AddField(
        Format('sys %d%%  gdi %d%%  user %d%%',
        [GetFreeSystemResources(GFSR_SYSTEMRESOURCES),
         GetFreeSystemResources(GFSR_GDIRESOURCES),
         GetFreeSystemResources(GFSR_USERRESOURCES)]));
    end
    else if HintControl is TTaskButton then begin
      HintStr := HintControl.Hint;
      if Spy.Checked then begin
        GetModuleAndClass(TTaskButton(HintControl).Window, fname, cname);
        AppendStr(HintStr, Format('   %s(%s)', [ExtractFilename(fname), cname]));
      end;
    end
    else HintStr := HintControl.Hint;

  r.Left := HintControl.ClientToScreen(Point(0, 0)).X;
  r.Right := r.Left + HintWindow.Canvas.TextWidth(HintStr) + 6;
  r.Bottom := Top - 2;
  r.Top := r.Bottom - Abs(HintWindow.Canvas.Font.Height) - 4;
  HintWindow.ActivateHint(r, HintStr);
  HintWindow.Visible := True;
end;


procedure TBar.HintTimerTimer(Sender: TObject);
var
  P: TPoint;
  Control: TControl;
begin
  GetCursorPos(P);
  Control := FindDragTarget(P, True);
  if Control = HintControl then ActivateHint(P);
  HintTimer.Enabled := False;
end;


procedure TBar.SpyClick(Sender: TObject);
begin
  with Spy do Checked := not Checked;
end;


procedure TBar.WMHideQuery(var Msg : TMessage);
var
  i: Integer;
begin
  if HideMinApps then begin
    i := WndToButton(Msg.wParam);
    if i > -1 then begin
      MoveDesktopIcon(Msg.wParam, Point(0, Screen.Height));
      Exit;
    end;
  end;

  if ArrangeMin then RaiseWindow(Msg.wParam);
end;


procedure TBar.WMWinActivate(var Msg : TMessage);
var i: Integer;
begin
  if not InTaskClick then begin
    i := HiddenList.IndexOf(Pointer(Msg.wParam));
    if (i > -1) and IsVisibleTaskWindow(Msg.wParam) then begin
      if not ShouldExclude(msg.wParam) then
        PostMessage(Handle, WM_ADDBUTTON, Word(HiddenList[i]), 0);
      HiddenList.Delete(i);
    end
    else Press(Msg.WParam);
  end;
end;


procedure TBar.WMMouseActivate(var Msg : TWMMouseActivate);
begin
  Msg.Result := MA_NOACTIVATE;
end;


procedure TBar.WMAddButton(var Msg : TMessage);
begin
  AddButton(Msg.wParam);
  Press(Msg.wParam);
end;


procedure TBar.Startproperties1Click(Sender: TObject);
begin
  PostMessage(CalmiraWindow, WM_CALMIRA, CM_STARTPROP, 0);
end;


procedure TBar.Properties1Click(Sender: TObject);
begin
  PostMessage(CalmiraWindow, WM_CALMIRA, CM_TASKPROP, 0);
end;

procedure TBar.SetClock(const s : string);
begin
  if Clock.ControlCount > 0 then Clock.Caption := s + '  '
  else Clock.Caption := s;
end;

procedure TBar.CMShowingChanged(var Message: TMessage);
const
  ShowModes : array[Boolean] of Word = (SW_HIDE, SW_SHOWNOACTIVATE);
begin
  if ShowNoActivate then ShowWindow(Handle, ShowModes[Showing])
  else inherited;
end;


procedure TBar.AppException(Sender: TObject; E: Exception);
begin
  if not (IgnoreGPF and (E is EGPFault)) then
    Application.ShowException(E);
end;


procedure TBar.ClockDblClick(Sender: TObject);
var buf: array[0..255] of Char;
begin
  WinExec(StrPCopy(buf,
    ini.ReadString('Taskbar', 'AdjustClock', 'control Date/Time')), SW_SHOW);
end;


initialization
  ApplicationPath := ExtractFilePath(ParamStr(0));
  WinPath[0] := Chr(GetWindowsDirectory(@WinPath[1], 79));
  AppendStr(WinPath, '\');
end.
