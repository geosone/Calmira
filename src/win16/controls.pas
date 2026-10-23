{ SPDX-License-Identifier: GPL-2.0-or-later
  Initial windowed Controls subset for ported components, not a full VCL. }
unit Controls;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Controls adapter requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Menus, native_input, native_cursors, control_base;
type
  TControl = control_base.TControl;
  TPoint = WinTypes.TPoint;
  TCursor = native_cursors.TCursor;
  TRect = WinTypes.TRect;
  TMouseButton = native_input.TMouseButton;
  TShiftState = native_input.TShiftState;
  TModalResult = SmallInt;
  TControlViewAction = (cvaShow, cvaHide, cvaFront, cvaBack);
  TAlign = control_base.TAlign;
  TDragMode = control_base.TDragMode;
  TDragState = control_base.TDragState;
  TDragDropEvent = control_base.TDragDropEvent;
  TDragOverEvent = control_base.TDragOverEvent;
  TEndDragEvent = control_base.TEndDragEvent;
  TMouseEvent = native_input.TMouseEvent;
  TMouseMoveEvent = native_input.TMouseMoveEvent;
const
  { Delphi 1 component messages that Calmira's own controls handle. }
  CM_BASE = $0F00;
  CM_ENABLEDCHANGED = CM_BASE + 12;
  CM_MOUSEENTER = CM_BASE + 19;
  CM_MOUSELEAVE = CM_BASE + 20;
  CM_BUTTONPRESSED = CM_BASE + 24;
  { Delphi 1 notifications reflected from a parent to the child they concern. }
  CN_BASE = $2000;
  CN_CHARTOITEM = CN_BASE + WM_CHARTOITEM;
  CN_COMMAND = CN_BASE + WM_COMMAND;
  CN_COMPAREITEM = CN_BASE + WM_COMPAREITEM;
  CN_CTLCOLOR = CN_BASE + WM_CTLCOLOR;
  CN_DELETEITEM = CN_BASE + WM_DELETEITEM;
  CN_DRAWITEM = CN_BASE + WM_DRAWITEM;
  CN_HSCROLL = CN_BASE + WM_HSCROLL;
  CN_MEASUREITEM = CN_BASE + WM_MEASUREITEM;
  CN_PARENTNOTIFY = CN_BASE + WM_PARENTNOTIFY;
  CN_VKEYTOITEM = CN_BASE + WM_VKEYTOITEM;
  CN_VSCROLL = CN_BASE + WM_VSCROLL;
  CN_KEYDOWN = CN_BASE + WM_KEYDOWN;
  CN_KEYUP = CN_BASE + WM_KEYUP;
  CN_CHAR = CN_BASE + WM_CHAR;
  CN_SYSKEYDOWN = CN_BASE + WM_SYSKEYDOWN;
  CN_SYSCHAR = CN_BASE + WM_SYSCHAR;
  alNone = control_base.alNone; alTop = control_base.alTop; alBottom = control_base.alBottom;
  alLeft = control_base.alLeft; alRight = control_base.alRight; alClient = control_base.alClient;
  dmManual = control_base.dmManual; dmAutomatic = control_base.dmAutomatic;
  dsDragEnter = control_base.dsDragEnter; dsDragLeave = control_base.dsDragLeave;
  dsDragMove = control_base.dsDragMove;
type
  TGraphicControl = class;
  TCustomControl = class(TNativeInputWindow)
  private
    FGraphics: TList;
    FWindows: TList;
    FControls: TList;
    FParent: TCustomControl;
    FChanging: Boolean;
    FCompositing: Boolean;
    FLeft, FTop, FWidth, FHeight: Integer;
    FEnabled, FVisible: Boolean;
    FTabStop: Boolean;
    FHelpContext: LongInt;
    FAlignLevel: Integer;
    FCtl3D, FParentCtl3D: Boolean;
    FAligning, FAlignPending: Boolean;
    FMouseControl, FCaptureControl: TGraphicControl;
    FPopupMenu: TPopupMenu;
    procedure SetPopupMenu(Value: TPopupMenu);
    procedure SetHelpContext(Value: LongInt);
    function GraphicAt(X, Y: Integer; AllowDisabled: Boolean = False): TGraphicControl;
    procedure SetMouseControl(Value: TGraphicControl);
    procedure CheckMouseControl;
    procedure ForgetGraphic(Control: TGraphicControl);
    function RouteGraphicMouse(var M: TMessage): Boolean;
    function GetTabOrder: Integer;
    procedure SetTabOrder(Value: Integer);
    procedure SetTabStop(Value: Boolean);
    procedure CollectFocusControls(List: TList);
    function FindDialogKey(Key: Word): Boolean;
    function FindMnemonic(Key: Char; Root: TCustomControl): Boolean;
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetEnabled: Boolean;
    function GetVisible: Boolean;
    procedure ReadBounds;
    function GetBoundsRect: TRect;
    function GetClientWidth: Integer;
    function GetClientHeight: Integer;
    function GetLeft: Integer;
    function GetTop: Integer;
    procedure SetLeft(Value: Integer);
    procedure SetTop(Value: Integer);
    procedure SetBoundsRect(const Value: TRect);
    procedure SetParent(Value: TCustomControl);
    procedure SetWidth(Value: Integer);
    procedure SetHeight(Value: Integer);
    procedure SetEnabled(Value: Boolean);
    procedure SetVisible(Value: Boolean);
    function FindWindowedChild(Window: HWND): TCustomControl;
    function IsVisualChild(Child: TControl): Boolean;
    function GetControlCount: Integer;
    function GetControl(Index: Integer): TControl;
  protected
    procedure ControlOperation(Operation: TControlOperation; var Value: Boolean); override;
    function GetClientRect: TRect; virtual;
    procedure ChangeView(Action: TControlViewAction); virtual;
    { Model-only teardown restoration; never moves a live HWND. }
    procedure StoreBounds(const Area: TRect);
    function ControlDialogKey(Key: Word): Boolean; virtual;
    function ControlMnemonic(Key: Char): Boolean; virtual;
    function ControlCommand(Code: Word): Boolean; virtual;
    function ControlDrawItem(var Item: TDrawItemStruct): Boolean; virtual;
    function ControlMeasureItem(var Item: TMeasureItemStruct): Boolean; virtual;
    { As in Delphi, the parent reflects WM_DRAWITEM/WM_MEASUREITEM to the child
      as CN_*; these defaults call ControlDrawItem/ControlMeasureItem. }
    procedure CNDrawItem(var M: TWMDrawItem); message CN_DRAWITEM;
    procedure CNMeasureItem(var M: TWMMeasureItem); message CN_MEASUREITEM;
    procedure WMMeasureItem(var M: TWMMeasureItem); message WM_MEASUREITEM;
    { Delivers a CN_* message straight to Child's WndProc, as Delphi's
      Perform does, so a failure unwinds into the parent's handler. }
    function Reflect(Child: TCustomControl; Msg, WParam: Word; LParam: LongInt): LongInt;
    { True for internal USER children (e.g. a combo box's edit) that act as Self. }
    function OwnsNativeChild(Window: HWND): Boolean; virtual;
    { Delphi 1 layout: alTop, alBottom, alLeft, alRight, then alClient, each
      ordered by position, inside Rect (initially ClientRect). }
    procedure AlignControls(AControl: TControl; var Rect: TRect); virtual;
    procedure RequestAlign; override;
    function ParentControl: TControl; override;
    procedure NotifyChildren; override;
    procedure ApplyFont; override;
    procedure FontChanged; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    { Delphi's window hooks. Here they surround the native window instead of
      creating it: CreateWnd runs once the window and its native state exist
      (for children created through CreateControl), DestroyWnd at WM_DESTROY
      or when the control is freed, while the window and its contents still
      exist. }
    procedure CreateWnd; virtual;
    procedure DestroyWnd; virtual;
    { Ctl3D is kept and inherited as in Delphi; no CTL3D.DLL drawing yet. }
    procedure Ctl3DChanged; virtual;
    procedure SetCtl3D(Value: Boolean);
    procedure SetParentCtl3D(Value: Boolean);
    procedure WMCommand(var M: TWMCommand); message WM_COMMAND;
    procedure WMDrawItem(var M: TWMDrawItem); message WM_DRAWITEM;
    procedure WMGetDlgCode(var M: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure PaintOverlay; override;
    procedure WMMove(var M: TMessage); message WM_MOVE;
    procedure WMSize(var M: TMessage); message WM_SIZE;
    procedure WMNCDestroy(var M: TMessage); message WM_NCDESTROY;
    procedure WndProc(var Message: TMessage); override;
    function GetControlBounds: TRect; override;
    procedure SetControlBounds(const Value: TRect); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure CreateControl(ParentWindow: HWND);
    procedure SetBounds(X, Y, AWidth, AHeight: Integer); virtual;
    procedure DisableAlign;
    procedure EnableAlign;
    procedure Realign;
    procedure Invalidate; override;
    procedure Update;
    procedure Show;
    procedure Hide;
    procedure BringToFront;
    procedure SendToBack;
    function ClientToScreen(const Position: TPoint): TPoint;
    function ScreenToClient(const Position: TPoint): TPoint;
    function FindControl(Window: HWND): TCustomControl;
    function HandleAllocated: Boolean;
    function ResolveHelpContext: LongInt;
    function FocusNext(Forward: Boolean): Boolean;
    function DispatchDialogKey(Key: Word): Boolean;
    function DispatchMnemonic(Key: Char): Boolean;
    procedure ApplyModalResult(Value: TModalResult); virtual;
    { Opened at the cursor on a right-button release when AutoPopup is set. }
    property PopupMenu: TPopupMenu read FPopupMenu write SetPopupMenu;
    property TabStop: Boolean read FTabStop write SetTabStop;
    property HelpContext: LongInt read FHelpContext write SetHelpContext;
    property TabOrder: Integer read GetTabOrder write SetTabOrder;
    property Width: Integer read GetWidth write SetWidth;
    property Height: Integer read GetHeight write SetHeight;
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property Visible: Boolean read GetVisible write SetVisible;
    property Left: Integer read GetLeft write SetLeft;
    property Top: Integer read GetTop write SetTop;
    property BoundsRect: TRect read GetBoundsRect write SetBoundsRect;
    property ClientRect: TRect read GetClientRect;
    property ClientWidth: Integer read GetClientWidth;
    property ClientHeight: Integer read GetClientHeight;
    property Parent: TCustomControl read FParent write SetParent;
    property ControlCount: Integer read GetControlCount;
    property Controls[Index: Integer]: TControl read GetControl;
    procedure ParentPropertiesChanged; override;
    property Ctl3D: Boolean read FCtl3D write SetCtl3D default True;
    property ParentCtl3D: Boolean read FParentCtl3D write SetParentCtl3D default True;
  end;
  TGraphicControl = class(TControl)
  private
    FParent: TCustomControl;
    FCanvas: TCanvas;
    FLeft, FTop, FWidth, FHeight: Integer;
    FVisible, FEnabled: Boolean;
    FOnClick, FOnDblClick: TNotifyEvent;
    FOnMouseDown, FOnMouseUp: TMouseEvent;
    FOnMouseMove: TMouseMoveEvent;
    FPopupMenu: TPopupMenu;
    procedure SetPopupMenu(Value: TPopupMenu);
    procedure SetParent(Value: TCustomControl);
    procedure MouseMessage(Msg, Keys: Word; X, Y: Integer);
    procedure SetLeft(Value: Integer);
    procedure SetTop(Value: Integer);
    procedure SetWidth(Value: Integer);
    procedure SetHeight(Value: Integer);
    procedure SetVisible(Value: Boolean);
    procedure SetEnabled(Value: Boolean);
    function GetBoundsRect: TRect;
    function GetClientRect: TRect;
    procedure SetBoundsRect(const Value: TRect);
    procedure DirtyBounds;
    procedure PaintOn(DC: HDC);
    procedure ChangeOrder(Front: Boolean);
  protected
    { False for controls that decide themselves when a press is a click. }
    FClickEvents: Boolean;
    procedure ControlOperation(Operation: TControlOperation; var Value: Boolean); override;
    procedure RequestAlign; override;
    function ParentControl: TControl; override;
    procedure ApplyFont; override;
    procedure FontChanged; override;
    procedure ColorChanged; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Paint; virtual;
    function GetControlBounds: TRect; override;
    procedure SetControlBounds(const Value: TRect); override;
    function DialogChar(Key: Char; Root: TCustomControl): Boolean; virtual;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); virtual;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); virtual;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); virtual;
    procedure DblClick; virtual;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Click; virtual;
    function Perform(Msg, WParam: Word; LParam: LongInt): LongInt;
    procedure SetBounds(X, Y, AWidth, AHeight: Integer); virtual;
    procedure Invalidate;
    procedure Show;
    procedure Hide;
    procedure Update;
    procedure Repaint;
    procedure BringToFront;
    procedure SendToBack;
    function ClientToScreen(const Position: TPoint): TPoint;
    function ScreenToClient(const Position: TPoint): TPoint;
    property Parent: TCustomControl read FParent write SetParent;
    property Canvas: TCanvas read FCanvas;
    property PopupMenu: TPopupMenu read FPopupMenu write SetPopupMenu;
    property Left: Integer read FLeft write SetLeft;
    property Top: Integer read FTop write SetTop;
    property Width: Integer read FWidth write SetWidth;
    property Height: Integer read FHeight write SetHeight;
    property BoundsRect: TRect read GetBoundsRect write SetBoundsRect;
    property ClientRect: TRect read GetClientRect;
    property ClientWidth: Integer read FWidth;
    property ClientHeight: Integer read FHeight;
    property Visible: Boolean read FVisible write SetVisible;
    property Enabled: Boolean read FEnabled write SetEnabled;
  end;
  { Delphi 1 TCustomControl descends from TWinControl; here they are one class. }
  TWinControl = TCustomControl;
  { A canvas on a control outside its Paint: the window's DC, or the parent's
    clipped to the bounds of a graphic control. }
  TControlCanvas = class(TCanvas)
  private
    FControl: TControl;
    FWindow: HWND;
    FContext: HDC;
    procedure SetControl(Value: TControl);
    procedure FreeContext;
  public
    destructor Destroy; override;
    property Control: TControl read FControl write SetControl;
  end;
  { Delphi 1's hint popup: a bordered WS_POPUP showing Caption, created by
    the first ActivateHint and kept until ReleaseHandle. }
  THintWindow = class(TCustomControl)
  private
    FCaption: string;
    procedure SetCaption(const Value: string);
  protected
    procedure Paint; override;
    procedure HandleNeeded; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ActivateHint(Rect: TRect; const AHint: string); virtual;
    function IsHintMsg(var Msg: TMsg): Boolean; virtual;
    procedure ReleaseHandle;
    property Caption: string read FCaption write SetCaption;
    property Color;
    property Canvas;
  end;
  THintWindowClass = class of THintWindow;
const
  crDefault = native_cursors.crDefault; crNone = native_cursors.crNone;
  crArrow = native_cursors.crArrow; crCross = native_cursors.crCross;
  crIBeam = native_cursors.crIBeam; crSize = native_cursors.crSize;
  crSizeNESW = native_cursors.crSizeNESW; crSizeNS = native_cursors.crSizeNS;
  crSizeNWSE = native_cursors.crSizeNWSE; crSizeWE = native_cursors.crSizeWE;
  crUpArrow = native_cursors.crUpArrow; crHourGlass = native_cursors.crHourGlass;
  crDrag = native_cursors.crDrag; crNoDrop = native_cursors.crNoDrop;
  crHSplit = native_cursors.crHSplit; crVSplit = native_cursors.crVSplit;
  crMultiDrag = native_cursors.crMultiDrag; crSQLWait = native_cursors.crSQLWait;
  mrNone = 0; mrOK = 1; mrCancel = 2; mrAbort = 3; mrRetry = 4;
  mrIgnore = 5; mrYes = 6; mrNo = 7; mrAll = 8;
  mbLeft = native_input.mbLeft; mbRight = native_input.mbRight; mbMiddle = native_input.mbMiddle;
  ssShift = native_input.ssShift; ssCtrl = native_input.ssCtrl; ssAlt = native_input.ssAlt;
  ssLeft = native_input.ssLeft; ssRight = native_input.ssRight;
  ssMiddle = native_input.ssMiddle; ssDouble = native_input.ssDouble;
function Point(X, Y: Integer): TPoint;
{ The control under the screen point Pos: a windowed control, or the graphic
  child of one at that point. Disabled graphic controls count only with
  AllowDisabled; USER never reports disabled windows. }
function FindDragTarget(const Pos: TPoint; AllowDisabled: Boolean): TControl;
{ The parts of a hint before and after its first '|'. }
function GetShortHint(const Hint: string): string;
function GetLongHint(const Hint: string): string;
function PtInRect(const Area: TRect; const Position: TPoint): Boolean;
var
  { Delphi 1: True only on Windows 4.x, where controls get the new look. }
  NewStyleControls: Boolean;
implementation
uses SysUtils, WinProcs, Win31, native_window, gdi_canvas;

type
  { Outside painting a graphic control draws on its parent's window DC,
    moved and clipped to the control as during painting. }
  TGraphicCanvas = class(TCanvas)
  private
    FControl: TGraphicControl;
    FWindow: HWND;
  protected
    function AcquireContext: HDC; override;
    procedure ReleaseContext(Context: HDC); override;
  end;
function TGraphicCanvas.AcquireContext: HDC;
begin
  Result := 0; FWindow := 0;
  if (FControl.Parent = nil) or (FControl.Parent.Handle = 0) then Exit;
  FWindow := FControl.Parent.Handle;
  Result := GetDC(FWindow);
  if Result = 0 then begin FWindow := 0; Exit; end;
  SetViewportOrg(Result, FControl.Left, FControl.Top);
  IntersectClipRect(Result, 0, 0, FControl.Width, FControl.Height);
end;
procedure TGraphicCanvas.ReleaseContext(Context: HDC);
begin ReleaseDC(FWindow, Context); FWindow := 0; end;

{ Delphi 1: releasing the right button over a control whose PopupMenu has
  AutoPopup opens the menu at the cursor instead of reporting MouseUp. }
function PopupAt(Control: TControl; Menu: TPopupMenu; const Position: TPoint): Boolean;
begin
  Result := (Menu <> nil) and Menu.AutoPopup;
  if not Result then Exit;
  Menu.PopupComponent := Control;
  Menu.Popup(Position.X, Position.Y);
end;
procedure TCustomControl.SetPopupMenu(Value: TPopupMenu);
begin
  if Value = FPopupMenu then Exit;
  if FPopupMenu <> nil then FPopupMenu.RemoveFreeNotification(Self);
  FPopupMenu := Value;
  if Value <> nil then Value.FreeNotification(Self);
end;
procedure TCustomControl.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FPopupMenu) then FPopupMenu := nil;
end;
procedure TGraphicControl.SetPopupMenu(Value: TPopupMenu);
begin
  if Value = FPopupMenu then Exit;
  if FPopupMenu <> nil then FPopupMenu.RemoveFreeNotification(Self);
  FPopupMenu := Value;
  if Value <> nil then Value.FreeNotification(Self);
end;
procedure TGraphicControl.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FPopupMenu) then FPopupMenu := nil;
end;
function TranslatePosition(const Position, Origin: TPoint; Inverse: Boolean): TPoint;
var X, Y: LongInt;
begin
  if Inverse then
  begin X := LongInt(Position.X) - Origin.X; Y := LongInt(Position.Y) - Origin.Y; end
  else
  begin X := LongInt(Position.X) + Origin.X; Y := LongInt(Position.Y) + Origin.Y; end;
  if (X < -32768) or (X > 32767) or (Y < -32768) or (Y > 32767) then
    raise ENativeWindowError.Create('Coordinate overflow');
  Result.X := X; Result.Y := Y;
end;
function Point(X, Y: Integer): TPoint;
begin Result.X := X; Result.Y := Y; end;
function PtInRect(const Area: TRect; const Position: TPoint): Boolean;
begin
  { Avoid the failing foreign POINT-by-value call; right/bottom are exclusive. }
  Result := (Position.X >= Area.Left) and (Position.X < Area.Right) and
    (Position.Y >= Area.Top) and (Position.Y < Area.Bottom);
end;
constructor TCustomControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); FEnabled := True; FVisible := True;
  FCtl3D := True; FParentCtl3D := True;
end;
function TCustomControl.ParentControl: TControl;
begin Result := FParent; end;
procedure TCustomControl.NotifyChildren;
var I: Integer;
begin
  if FControls <> nil then
    for I := 0 to FControls.Count - 1 do TControl(FControls[I]).ParentPropertiesChanged;
end;
procedure TCustomControl.ApplyFont;
begin Canvas.Font.Assign(Font); end;
procedure TCustomControl.FontChanged;
begin Invalidate; end;
procedure TCustomControl.Ctl3DChanged;
begin end;
procedure TCustomControl.SetCtl3D(Value: Boolean);
begin
  if not Inheriting then FParentCtl3D := False;
  if Value = FCtl3D then Exit;
  FCtl3D := Value;
  Ctl3DChanged;
  NotifyChildren;
end;
procedure TCustomControl.SetParentCtl3D(Value: Boolean);
begin
  if Value = FParentCtl3D then Exit;
  FParentCtl3D := Value;
  if Value then ParentPropertiesChanged;
end;
procedure TCustomControl.ParentPropertiesChanged;
begin
  inherited ParentPropertiesChanged;
  if not FParentCtl3D or (FParent = nil) then Exit;
  Inheriting := True;
  try SetCtl3D(FParent.FCtl3D);
  finally Inheriting := False; end;
end;
procedure TCustomControl.SetHelpContext(Value: LongInt);
begin
  if Value < 0 then raise ENativeWindowError.Create('Invalid help context');
  FHelpContext := Value;
end;
function TCustomControl.ResolveHelpContext: LongInt;
var Current: TCustomControl;
begin
  Result := 0; Current := Self;
  while Current <> nil do
  begin
    if Current.FHelpContext <> 0 then begin Result := Current.FHelpContext; Exit; end;
    Current := Current.FParent;
  end;
end;
function TCustomControl.GetTabOrder: Integer;
begin
  Result := 0;
  if FParent <> nil then Result := FParent.FWindows.IndexOf(Self);
end;
procedure TCustomControl.SetTabOrder(Value: Integer);
var List: TList; Current: TCustomControl;
begin
  if Value < 0 then raise ENativeWindowError.Create('Negative tab order');
  if FParent = nil then Exit;
  Current := Self;
  while Current <> nil do
  begin
    if Current.FChanging or Current.Painting or Current.FCompositing or
      (Current.Canvas.Handle <> 0) then
      raise ENativeWindowError.Create('Cannot reorder while drawing or changing');
    Current := Current.FParent;
  end;
  List := FParent.FWindows;
  if Value >= List.Count then Value := List.Count - 1;
  List.Move(List.IndexOf(Self), Value);
end;
procedure TCustomControl.SetTabStop(Value: Boolean);
var Style: LongInt;
begin
  FTabStop := Value;
  if Handle = 0 then Exit;
  Style := GetWindowLong(Handle, GWL_STYLE) and not LongInt(WS_TABSTOP);
  if Value then Style := Style or LongInt(WS_TABSTOP);
  SetWindowLong(Handle, GWL_STYLE, Style);
end;
function TCustomControl.OwnsNativeChild(Window: HWND): Boolean;
begin Result := False; end;
function TCustomControl.FindControl(Window: HWND): TCustomControl;
var I: Integer; Child: TCustomControl;
begin
  Result := nil;
  if (Handle = 0) or (Window = 0) then Exit;
  if (Window = Handle) or OwnsNativeChild(Window) then begin Result := Self; Exit; end;
  if FWindows = nil then Exit;
  for I := 0 to FWindows.Count - 1 do
  begin
    Child := TCustomControl(FWindows[I]);
    if FindWindowedChild(Child.Handle) <> Child then Continue;
    Result := Child.FindControl(Window);
    if Result <> nil then Exit;
  end;
end;
procedure TCustomControl.CollectFocusControls(List: TList);
var I: Integer; Child: TCustomControl;
begin
  if not CanFocus or (FWindows = nil) then Exit;
  for I := 0 to FWindows.Count - 1 do
  begin
    Child := TCustomControl(FWindows[I]);
    if (FindWindowedChild(Child.Handle) <> Child) or not Child.CanFocus then Continue;
    List.Add(Child);
    Child.CollectFocusControls(List);
  end;
end;
function TCustomControl.FocusNext(Forward: Boolean): Boolean;
var List: TList; Index, I: Integer; Candidate: TCustomControl;
begin
  Result := False; List := TList.Create;
  try
    CollectFocusControls(List);
    if List.Count = 0 then Exit;
    Index := List.IndexOf(FindControl(GetFocus));
    for I := 1 to List.Count do
    begin
      if Forward then begin Inc(Index); if Index >= List.Count then Index := 0; end
      else begin Dec(Index); if Index < 0 then Index := List.Count - 1; end;
      Candidate := TCustomControl(List[Index]);
      if not Candidate.TabStop then Continue;
      Candidate.SetFocus;
      Result := Candidate.Focused;
      Exit;
    end;
  finally List.Free; end;
end;
function TCustomControl.ControlDialogKey(Key: Word): Boolean;
begin Result := False; end;
function TCustomControl.ControlMnemonic(Key: Char): Boolean;
begin Result := False; end;
function TGraphicControl.DialogChar(Key: Char; Root: TCustomControl): Boolean;
begin Result := False; end;
function TCustomControl.FindMnemonic(Key: Char; Root: TCustomControl): Boolean;
var I: Integer; Child: TCustomControl; Graphic: TGraphicControl;
begin
  Result := False;
  if not CanFocus then Exit;
  if FGraphics <> nil then
    for I := 0 to FGraphics.Count - 1 do
    begin
      Graphic := TGraphicControl(FGraphics[I]);
      if (Graphic.Parent = Self) and Graphic.Visible and Graphic.Enabled then
        if Graphic.DialogChar(Key, Root) then begin Result := True; Exit; end;
    end;
  if ControlMnemonic(Key) then begin Result := True; Exit; end;
  if FWindows <> nil then
    for I := 0 to FWindows.Count - 1 do
    begin
      Child := TCustomControl(FWindows[I]);
      if FindWindowedChild(Child.Handle) = Child then
        if Child.FindMnemonic(Key, Root) then begin Result := True; Exit; end;
    end;
end;
function TCustomControl.DispatchMnemonic(Key: Char): Boolean;
begin
  Result := False;
  if Key <> #0 then Result := FindMnemonic(Key, Self);
end;
procedure TCustomControl.ApplyModalResult(Value: TModalResult);
begin if FParent <> nil then FParent.ApplyModalResult(Value); end;
function TCustomControl.FindDialogKey(Key: Word): Boolean;
var I: Integer; Child: TCustomControl;
begin
  Result := False;
  if not CanFocus then Exit;
  if ControlDialogKey(Key) then begin Result := True; Exit; end;
  if FWindows = nil then Exit;
  for I := 0 to FWindows.Count - 1 do
  begin
    Child := TCustomControl(FWindows[I]);
    if FindWindowedChild(Child.Handle) <> Child then Continue;
    if Child.FindDialogKey(Key) then begin Result := True; Exit; end;
  end;
end;
function TCustomControl.DispatchDialogKey(Key: Word): Boolean;
var Current: TCustomControl;
begin
  Result := False;
  if not CanFocus then Exit;
  Current := FindControl(GetFocus);
  if (Current <> nil) and Current.CanFocus then
    if Current.ControlDialogKey(Key) then begin Result := True; Exit; end;
  Result := FindDialogKey(Key);
end;
destructor TCustomControl.Destroy;
begin
  { WM_DESTROY no longer reaches WndProc once the object is being destroyed. }
  if Handle <> 0 then DestroyWnd;
  if FParent <> nil then
  begin FParent.FWindows.Remove(Self); FParent.FControls.Remove(Self); end;
  FParent := nil;
  if FWindows <> nil then
  begin
    while FWindows.Count <> 0 do TCustomControl(FWindows[FWindows.Count - 1]).Parent := nil;
    FWindows.Free; FWindows := nil;
  end;
  if FGraphics <> nil then
  begin
    while FGraphics.Count <> 0 do TGraphicControl(FGraphics[FGraphics.Count - 1]).Parent := nil;
    FGraphics.Free; FGraphics := nil;
  end;
  FControls.Free; FControls := nil;
  inherited Destroy;
end;
function TCustomControl.IsVisualChild(Child: TControl): Boolean;
begin
  { Allocation is staged before USER callbacks. Only the current model parent
    exposes a staged entry; rollback retains the old parent's original slot. }
  if Child is TCustomControl then Result := TCustomControl(Child).FParent = Self
  else if Child is TGraphicControl then Result := TGraphicControl(Child).FParent = Self
  else Result := False;
end;
function TCustomControl.GetControlCount: Integer;
var I: Integer;
begin
  Result := 0;
  if FControls <> nil then
    for I := 0 to FControls.Count - 1 do
      if IsVisualChild(TControl(FControls[I])) then Inc(Result);
end;
function TCustomControl.GetControl(Index: Integer): TControl;
var I: Integer; Child: TControl;
begin
  if (Index >= 0) and (FControls <> nil) then
    for I := 0 to FControls.Count - 1 do
    begin
      Child := TControl(FControls[I]);
      if not IsVisualChild(Child) then Continue;
      if Index = 0 then begin Result := Child; Exit; end;
      Dec(Index);
    end;
  raise ENativeWindowError.Create('Invalid control index');
end;
procedure TCustomControl.ControlOperation(Operation: TControlOperation; var Value: Boolean);
begin
  case Operation of
    coReadEnabled: Value := GetEnabled;
    coWriteEnabled: SetEnabled(Value);
    coReadVisible: Value := GetVisible;
    coWriteVisible: SetVisible(Value);
    coShow: ChangeView(cvaShow);
    coHide: ChangeView(cvaHide);
    coFront: ChangeView(cvaFront);
    coBack: ChangeView(cvaBack);
  end;
end;
procedure TCustomControl.PaintOverlay;
var I: Integer;
begin
  inherited PaintOverlay;
  if FCompositing then Exit;
  FCompositing := True;
  try
    if FGraphics <> nil then
      for I := 0 to FGraphics.Count - 1 do TGraphicControl(FGraphics[I]).PaintOn(Canvas.Handle);
  finally FCompositing := False; end;
end;
function TCustomControl.FindWindowedChild(Window: HWND): TCustomControl;
var I: Integer;
begin
  Result := nil;
  if (Window = 0) or (FWindows = nil) or not IsWindow(Window) then Exit;
  if WinProcs.GetParent(Window) <> Handle then Exit;
  for I := 0 to FWindows.Count - 1 do
    if TCustomControl(FWindows[I]).Handle = Window then
    begin Result := TCustomControl(FWindows[I]); Exit; end;
end;
function TCustomControl.ControlCommand(Code: Word): Boolean;
begin Result := False; end;
function TCustomControl.ControlDrawItem(var Item: TDrawItemStruct): Boolean;
begin Result := False; end;
function TCustomControl.ControlMeasureItem(var Item: TMeasureItemStruct): Boolean;
begin Result := False; end;
procedure TCustomControl.CNDrawItem(var M: TWMDrawItem);
begin M.Result := Ord(ControlDrawItem(M.DrawItemStruct^)); end;
procedure TCustomControl.CNMeasureItem(var M: TWMMeasureItem);
begin M.Result := Ord(ControlMeasureItem(M.MeasureItemStruct^)); end;
function TCustomControl.Reflect(Child: TCustomControl; Msg, WParam: Word; LParam: LongInt): LongInt;
var Message: TMessage;
begin
  Message.Msg := Msg; Message.WParam := WParam; Message.LParam := LParam; Message.Result := 0;
  Child.WndProc(Message);
  Result := Message.Result;
end;
procedure TCustomControl.WMMeasureItem(var M: TWMMeasureItem);
var I: Integer; Child: TCustomControl;
begin
  { Sent while the child is still inside CreateWindow, before it is known by
    handle, so the control ID identifies it. }
  if (M.MeasureItemStruct <> nil) and (FWindows <> nil) then
    for I := 0 to FWindows.Count - 1 do
    begin
      Child := TCustomControl(FWindows[I]);
      if (Child.Handle <> 0) and
        (Word(GetWindowWord(Child.Handle, GWW_ID)) = M.MeasureItemStruct^.CtlID) then
      begin
        Reflect(Child, CN_MEASUREITEM, M.IDCtl, LongInt(M.MeasureItemStruct));
        M.Result := 1;
        Exit;
      end;
    end;
  DefaultHandler(M);
end;
procedure TCustomControl.WMCommand(var M: TWMCommand);
var Child: TCustomControl;
begin
  Child := FindWindowedChild(M.Ctl);
  if (Child <> nil) and (M.ItemID = Word(GetDlgCtrlID(M.Ctl))) and
    Child.ControlCommand(M.NotifyCode) then M.Result := 0
  else DefaultHandler(M);
end;
procedure TCustomControl.WMDrawItem(var M: TWMDrawItem);
var Child: TCustomControl; Previous: Boolean; Handled: Boolean;
begin
  if M.DrawItemStruct <> nil then
  begin
    Child := FindWindowedChild(M.DrawItemStruct^.hwndItem);
    if Child <> nil then
    begin
      Previous := FCompositing; FCompositing := True;
      try Handled := Reflect(Child, CN_DRAWITEM, M.Ctl, LongInt(M.DrawItemStruct)) <> 0;
      finally FCompositing := Previous; end;
      if Handled then begin M.Result := 1; Exit; end;
    end;
  end;
  DefaultHandler(M);
end;
procedure TCustomControl.CreateControl(ParentWindow: HWND);
var Style: DWORD;
begin
  Style := WS_CHILD or WS_CLIPSIBLINGS or WS_CLIPCHILDREN;
  if FTabStop then Style := Style or WS_TABSTOP;
  if FVisible then Style := Style or WS_VISIBLE;
  if not FEnabled then Style := Style or WS_DISABLED;
  CreateHandle(ParentWindow, '', Style, FLeft, FTop, FWidth, FHeight);
  CreateWnd;
end;
procedure TCustomControl.CreateWnd;
begin end;
procedure TCustomControl.DestroyWnd;
begin end;
procedure TCustomControl.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
var I: Integer;
begin
  if FChanging then raise ENativeWindowError.Create('Control lifecycle reentry');
  if (FParent <> nil) and ((Parent = 0) or (Parent <> FParent.Handle)) then
    raise ENativeWindowError.Create('Managed parent handle mismatch');
  if (Width < 0) or (Height < 0) or (LongInt(X) + Width > 32767) or
    (LongInt(Y) + Height > 32767) then raise ENativeWindowError.Create('Invalid control bounds');
  FChanging := True;
  try
    inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);
    try
      ReadBounds;
      if FWindows <> nil then
        for I := 0 to FWindows.Count - 1 do
          if TCustomControl(FWindows[I]).Handle = 0 then
            TCustomControl(FWindows[I]).CreateControl(Handle);
    except DestroyHandle; raise; end;
  finally FChanging := False; end;
end;
procedure TCustomControl.Invalidate;
begin if Handle <> 0 then inherited Invalidate; end;
procedure TCustomControl.Update;
begin
  if Handle = 0 then Exit;
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  UpdateWindow(Handle);
end;
procedure TCustomControl.Show;
begin ChangeView(cvaShow); end;
procedure TCustomControl.Hide;
begin ChangeView(cvaHide); end;
procedure TCustomControl.BringToFront;
begin ChangeView(cvaFront); end;
procedure TCustomControl.SendToBack;
begin ChangeView(cvaBack); end;
procedure TCustomControl.ChangeView(Action: TControlViewAction);
var Current, Order: HWND;
begin
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  if FParent <> nil then
    if FParent.FChanging or FParent.Painting or FParent.FCompositing or (FParent.Canvas.Handle <> 0) then
      raise ENativeWindowError.Create('Control lifecycle reentry');
  FChanging := True;
  try
    case Action of
      cvaShow: SetVisible(True);
      cvaHide:
        begin
          if Handle <> 0 then
          begin
            Current := GetCapture;
            if (Current = Handle) or IsChild(Handle, Current) then ReleaseCapture;
            Current := GetFocus;
            if (Current = Handle) or IsChild(Handle, Current) then WinProcs.SetFocus(0);
          end;
          SetVisible(False);
        end;
      cvaFront, cvaBack:
        if Handle <> 0 then
        begin
          if Action = cvaFront then Order := HWND_TOP else Order := HWND_BOTTOM;
          if not SetWindowPos(Handle, Order, 0, 0, 0, 0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE) then
            raise ENativeWindowError.Create('Cannot reorder control');
        end;
    end;
  finally FChanging := False; end;
end;
function TCustomControl.GetWidth: Integer;
begin
  ReadBounds; Result := FWidth;
end;
function TCustomControl.GetHeight: Integer;
begin
  ReadBounds; Result := FHeight;
end;
procedure TCustomControl.SetWidth(Value: Integer);
begin
  SetBounds(GetLeft, GetTop, Value, GetHeight);
end;
procedure TCustomControl.SetHeight(Value: Integer);
begin
  SetBounds(GetLeft, GetTop, GetWidth, Value);
end;
procedure TCustomControl.ReadBounds;
var Area: TRect; Origin: TPoint; NativeParent: HWND;
begin
  if Handle = 0 then Exit;
  GetWindowRect(Handle, Area); Origin.X := Area.Left; Origin.Y := Area.Top;
  NativeParent := WinProcs.GetParent(Handle);
  if (DWORD(GetWindowLong(Handle, GWL_STYLE)) and WS_CHILD <> 0) and (NativeParent <> 0) then
    WinProcs.ScreenToClient(NativeParent, Origin);
  FLeft := Origin.X; FTop := Origin.Y;
  FWidth := Area.Right - Area.Left; FHeight := Area.Bottom - Area.Top;
end;
function TCustomControl.GetBoundsRect: TRect;
begin
  ReadBounds; Result.Left := FLeft; Result.Top := FTop;
  Result.Right := FLeft + FWidth; Result.Bottom := FTop + FHeight;
end;
function TCustomControl.GetClientRect: TRect;
var Area: TRect;
begin
  Area.Left := 0; Area.Top := 0; Area.Right := FWidth; Area.Bottom := FHeight;
  if Handle <> 0 then WinProcs.GetClientRect(Handle, Area);
  Result := Area;
end;
function TCustomControl.ClientToScreen(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if (Handle = 0) or not IsWindow(Handle) then
    raise ENativeWindowError.Create('Control has no window');
  Origin := Point(0, 0); WinProcs.ClientToScreen(Handle, Origin);
  Result := TranslatePosition(Position, Origin, False);
end;
function TCustomControl.ScreenToClient(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if (Handle = 0) or not IsWindow(Handle) then
    raise ENativeWindowError.Create('Control has no window');
  Origin := Point(0, 0); WinProcs.ClientToScreen(Handle, Origin);
  Result := TranslatePosition(Position, Origin, True);
end;
function TCustomControl.GetLeft: Integer;
begin ReadBounds; Result := FLeft; end;
function TCustomControl.GetClientWidth: Integer;
var Area: TRect;
begin Area := GetClientRect; Result := Area.Right - Area.Left; end;
function TCustomControl.GetClientHeight: Integer;
var Area: TRect;
begin Area := GetClientRect; Result := Area.Bottom - Area.Top; end;
function TCustomControl.GetTop: Integer;
begin ReadBounds; Result := FTop; end;
procedure TCustomControl.SetLeft(Value: Integer);
begin SetBounds(Value, GetTop, GetWidth, GetHeight); end;
procedure TCustomControl.SetTop(Value: Integer);
begin SetBounds(GetLeft, Value, GetWidth, GetHeight); end;
procedure TCustomControl.SetBoundsRect(const Value: TRect);
var W, H: LongInt;
begin
  W := LongInt(Value.Right) - Value.Left; H := LongInt(Value.Bottom) - Value.Top;
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then
    raise ENativeWindowError.Create('Invalid control bounds');
  SetBounds(Value.Left, Value.Top, W, H);
end;
procedure TCustomControl.SetBounds(X, Y, AWidth, AHeight: Integer);
begin
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  if (AWidth < 0) or (AHeight < 0) or (LongInt(X) + AWidth > 32767) or
    (LongInt(Y) + AHeight > 32767) then raise ENativeWindowError.Create('Invalid control bounds');
  FChanging := True;
  try
    if Handle <> 0 then
      if not SetWindowPos(Handle, 0, X, Y, AWidth, AHeight, SWP_NOZORDER or SWP_NOACTIVATE) then
        raise ENativeWindowError.Create('Cannot resize control');
    FLeft := X; FTop := Y; FWidth := AWidth; FHeight := AHeight;
  finally FChanging := False; end;
  Invalidate;
  if (Align <> alNone) and (FParent <> nil) and not FParent.FAligning then FParent.Realign;
end;
procedure TCustomControl.WMMove(var M: TMessage);
begin ReadBounds; DefaultHandler(M); end;
procedure TCustomControl.WMSize(var M: TMessage);
begin ReadBounds; DefaultHandler(M); Invalidate; Realign; end;
procedure TCustomControl.DisableAlign;
begin Inc(FAlignLevel); end;
procedure TCustomControl.EnableAlign;
begin
  if FAlignLevel = 0 then raise ENativeWindowError.Create('Unbalanced EnableAlign');
  Dec(FAlignLevel);
  if (FAlignLevel = 0) and FAlignPending then Realign;
end;
procedure TCustomControl.Realign;
var Area: TRect;
begin
  if FAlignLevel > 0 then begin FAlignPending := True; Exit; end;
  if FAligning then Exit;
  FAlignPending := False;
  Area := GetClientRect;
  AlignControls(nil, Area);
end;
procedure TCustomControl.RequestAlign;
begin if FParent <> nil then FParent.Realign; end;
procedure TCustomControl.AlignControls(AControl: TControl; var Rect: TRect);
var List: TList; A: TAlign; I, J: Integer; Control: TControl; Bounds, Target: TRect;
  W, H: Integer;
  function Key(C: TControl): Integer;
  var B: TRect;
  begin
    B := C.BoundsRect;
    case A of
      alTop: Result := B.Top;
      alBottom: Result := -B.Bottom;
      alLeft: Result := B.Left;
      alRight: Result := -B.Right;
    else Result := 0;
    end;
  end;
  function Before(X, Y: TControl): Boolean;
  begin
    { The control being moved wins a tie, as in Delphi. }
    Result := (Key(X) < Key(Y)) or ((Key(X) = Key(Y)) and (X = AControl));
  end;
begin
  if (FControls = nil) or (FControls.Count = 0) then Exit;
  FAligning := True;
  List := TList.Create;
  try
    for A := alTop to alClient do
    begin
      List.Clear;
      for I := 0 to FControls.Count - 1 do
      begin
        Control := TControl(FControls[I]);
        if (Control.Align <> A) or not Control.Visible then Continue;
        J := List.Count;
        while (J > 0) and Before(Control, TControl(List[J - 1])) do Dec(J);
        List.Insert(J, Control);
      end;
      for I := 0 to List.Count - 1 do
      begin
        Control := TControl(List[I]);
        Bounds := Control.BoundsRect;
        W := Bounds.Right - Bounds.Left; H := Bounds.Bottom - Bounds.Top;
        Target := Rect;
        case A of
          alTop: begin Target.Bottom := Rect.Top + H; Inc(Rect.Top, H); end;
          alBottom: begin Target.Top := Rect.Bottom - H; Dec(Rect.Bottom, H); end;
          alLeft: begin Target.Right := Rect.Left + W; Inc(Rect.Left, W); end;
          alRight: begin Target.Left := Rect.Right - W; Dec(Rect.Right, W); end;
        end;
        if Target.Right < Target.Left then Target.Right := Target.Left;
        if Target.Bottom < Target.Top then Target.Bottom := Target.Top;
        if (Target.Left <> Bounds.Left) or (Target.Top <> Bounds.Top) or
          (Target.Right <> Bounds.Right) or (Target.Bottom <> Bounds.Bottom) then
          Control.BoundsRect := Target;
      end;
    end;
  finally
    List.Free;
    FAligning := False;
  end;
end;
procedure TCustomControl.WMNCDestroy(var M: TMessage);
begin
  { Borrowed DCs of this window or its graphic children must not outlive it. }
  if DeviceContextsInUse then FreeDeviceContexts;
  FMouseControl := nil; FCaptureControl := nil; ReadBounds; DefaultHandler(M);
end;
const
  { Win16 has no WM_MOUSELEAVE: poll while a graphic child is hovered. }
  MouseLeaveTimer = $7E01;
  MouseLeaveInterval = 100;
{ USER's four-byte POINT by value; see native_cursors. }
function PackedWindowFromPoint(Value: LongInt): HWND; external 'USER' name 'WINDOWFROMPOINT';
function TCustomControl.GraphicAt(X, Y: Integer; AllowDisabled: Boolean): TGraphicControl;
var I: Integer; Graphic: TGraphicControl;
begin
  Result := nil;
  if FGraphics = nil then Exit;
  { Last in the list paints last, so it is topmost. }
  for I := FGraphics.Count - 1 downto 0 do
  begin
    Graphic := TGraphicControl(FGraphics[I]);
    if Graphic.FVisible and (Graphic.FEnabled or AllowDisabled) and (X >= Graphic.FLeft) and (Y >= Graphic.FTop) and
      (X < Graphic.FLeft + Graphic.FWidth) and (Y < Graphic.FTop + Graphic.FHeight) then
    begin Result := Graphic; Exit; end;
  end;
end;
procedure TCustomControl.SetMouseControl(Value: TGraphicControl);
var Previous: TGraphicControl;
begin
  if Value = FMouseControl then Exit;
  Previous := FMouseControl;
  FMouseControl := Value;
  if Previous <> nil then Previous.Perform(CM_MOUSELEAVE, 0, 0);
  if (Value <> nil) and (FMouseControl = Value) then Value.Perform(CM_MOUSEENTER, 0, 0);
  if Handle <> 0 then
    if FMouseControl <> nil then SetTimer(Handle, MouseLeaveTimer, MouseLeaveInterval, nil)
    else KillTimer(Handle, MouseLeaveTimer);
end;
procedure TCustomControl.CheckMouseControl;
var Position: TPoint;
begin
  if FCaptureControl <> nil then Exit;
  GetCursorPos(Position);
  if PackedWindowFromPoint(MakeLong(Position.X, Position.Y)) <> Handle then SetMouseControl(nil)
  else
  begin
    WinProcs.ScreenToClient(Handle, Position);
    SetMouseControl(GraphicAt(Position.X, Position.Y));
  end;
end;
procedure TCustomControl.ForgetGraphic(Control: TGraphicControl);
begin
  if FMouseControl = Control then
  begin
    FMouseControl := nil;
    if Handle <> 0 then KillTimer(Handle, MouseLeaveTimer);
  end;
  if FCaptureControl = Control then
  begin
    FCaptureControl := nil;
    MouseCapture := False;
  end;
end;
function TCustomControl.RouteGraphicMouse(var M: TMessage): Boolean;
var X, Y: Integer; Target: TGraphicControl;
begin
  Result := False;
  X := SmallInt(LoWord(M.LParam)); Y := SmallInt(HiWord(M.LParam));
  if FCaptureControl = nil then
  begin
    if M.Msg = WM_MOUSEMOVE then SetMouseControl(GraphicAt(X, Y));
    Target := GraphicAt(X, Y);
  end
  else Target := FCaptureControl;
  if Target = nil then Exit;
  case M.Msg of
    WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN,
    WM_LBUTTONDBLCLK, WM_RBUTTONDBLCLK, WM_MBUTTONDBLCLK:
      begin FCaptureControl := Target; MouseCapture := True; end;
  end;
  Target.MouseMessage(M.Msg, M.WParam, X - Target.FLeft, Y - Target.FTop);
  case M.Msg of
    WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP:
      if (M.WParam and (MK_LBUTTON or MK_RBUTTON or MK_MBUTTON) = 0) and
        (FCaptureControl <> nil) then
      begin
        FCaptureControl := nil;
        MouseCapture := False;
        SetMouseControl(GraphicAt(X, Y));
      end;
  end;
  M.Result := 0;
  Result := True;
end;
function TCustomControl.GetControlBounds: TRect;
begin Result := GetBoundsRect; end;
procedure TCustomControl.SetControlBounds(const Value: TRect);
begin SetBoundsRect(Value); end;
function TGraphicControl.GetControlBounds: TRect;
begin Result := GetBoundsRect; end;
procedure TGraphicControl.SetControlBounds(const Value: TRect);
begin SetBoundsRect(Value); end;
procedure TCustomControl.WndProc(var Message: TMessage);
var Position: TPoint;
begin
  case Message.Msg of
    WM_MOUSEMOVE..WM_MBUTTONDBLCLK:
      begin
        if RouteGraphicMouse(Message) then Exit;
        if Message.Msg = WM_RBUTTONUP then
        begin
          Position.X := SmallInt(LoWord(Message.LParam));
          Position.Y := SmallInt(HiWord(Message.LParam));
          if PopupAt(Self, FPopupMenu, ClientToScreen(Position)) then
          begin Message.Result := 0; Exit; end;
        end;
        if (Message.Msg = WM_LBUTTONDOWN) and (DragMode = dmAutomatic) and Enabled then
        begin BeginDrag(False); Message.Result := 0; Exit; end;
      end;
    WM_TIMER:
      if Message.WParam = MouseLeaveTimer then
      begin CheckMouseControl; Message.Result := 0; Exit; end;
    WM_DESTROY: DestroyWnd;
  end;
  inherited WndProc(Message);
end;
procedure TCustomControl.StoreBounds(const Area: TRect);
begin
  FLeft := Area.Left; FTop := Area.Top;
  FWidth := Area.Right - Area.Left; FHeight := Area.Bottom - Area.Top;
end;
procedure TCustomControl.SetParent(Value: TCustomControl);
var Current, Previous: TCustomControl; PreviousWindow: HWND;
  X, Y, W, H: Integer;
begin
  if Value = FParent then Exit;
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  if (FParent <> nil) and (FParent.FChanging or FParent.Painting or FParent.FCompositing) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  Current := Value;
  while Current <> nil do
  begin
    if Current = Self then raise ENativeWindowError.Create('Control parent cycle');
    if Current.FChanging or Current.Painting or Current.FCompositing then
      raise ENativeWindowError.Create('Control lifecycle reentry');
    Current := Current.FParent;
  end;
  if (Handle <> 0) and (DWORD(GetWindowLong(Handle, GWL_STYLE)) and WS_CHILD = 0) then
    raise ENativeWindowError.Create('Only child HWNDs can be reparented');
  if (Handle <> 0) and (Value <> nil) and (Value.Handle <> 0) then
    if IsChild(Handle, Value.Handle) then raise ENativeWindowError.Create('Native parent cycle');
  if Value <> nil then
  begin
    if Value.FWindows = nil then Value.FWindows := TList.Create;
    if Value.FControls = nil then Value.FControls := TList.Create;
    Value.FControls.Add(Self);
    try Value.FWindows.Add(Self);
    except Value.FControls.Remove(Self); raise; end;
  end;
  Previous := FParent;
  try
    FChanging := True;
    try
      ReadBounds; X := FLeft; Y := FTop; W := FWidth; H := FHeight;
      if Handle <> 0 then
      begin
        if (GetCapture = Handle) or IsChild(Handle, GetCapture) then ReleaseCapture;
        if (GetFocus = Handle) or IsChild(Handle, GetFocus) then WinProcs.SetFocus(0);
        if (Value = nil) or (Value.Handle = 0) then DestroyHandle
        else
        begin
          PreviousWindow := WinProcs.GetParent(Handle);
          WinProcs.SetParent(Handle, Value.Handle);
          if WinProcs.GetParent(Handle) <> Value.Handle then
            raise ENativeWindowError.Create('Cannot change native parent');
          if not SetWindowPos(Handle, 0, X, Y, W, H, SWP_NOZORDER or SWP_NOACTIVATE) then
          begin
            WinProcs.SetParent(Handle, PreviousWindow);
            if (WinProcs.GetParent(Handle) <> PreviousWindow) or
              not SetWindowPos(Handle, 0, X, Y, W, H, SWP_NOZORDER or SWP_NOACTIVATE) then
            begin
              DestroyHandle;
              FLeft := X; FTop := Y; FWidth := W; FHeight := H;
              raise ENativeWindowError.Create('Native reparent rollback failed; HWND detached');
            end;
            raise ENativeWindowError.Create('Cannot position reparented control');
          end;
        end;
      end;
      FParent := Value;
    finally FChanging := False; end;
    try
      if (Handle = 0) and (Value <> nil) and (Value.Handle <> 0) then CreateControl(Value.Handle);
    except FParent := Previous; raise; end;
    if Previous <> nil then
    begin Previous.FWindows.Remove(Self); Previous.FControls.Remove(Self); end;
  except
    if Value <> nil then
    begin Value.FWindows.Remove(Self); Value.FControls.Remove(Self); end;
    raise;
  end;
  Invalidate;
  if Align <> alNone then
  begin
    if Previous <> nil then Previous.Realign;
    if Value <> nil then Value.Realign;
  end;  if Value <> nil then ParentPropertiesChanged;
end;
function TCustomControl.GetEnabled: Boolean;
begin if Handle = 0 then Result := FEnabled else Result := IsWindowEnabled(Handle); end;
function TCustomControl.GetVisible: Boolean;
begin
  if Handle = 0 then Result := FVisible
  else Result := DWORD(GetWindowLong(Handle, GWL_STYLE)) and WS_VISIBLE <> 0;
end;
procedure TCustomControl.SetEnabled(Value: Boolean);
begin
  FEnabled := Value;
  if not Value then MouseCapture := False;
  if Handle <> 0 then EnableWindow(Handle, Value);
end;
procedure TCustomControl.SetVisible(Value: Boolean);
begin
  FVisible := Value;
  if not Value then MouseCapture := False;
  if Handle <> 0 then
    if Value then ShowWindow(Handle, SW_SHOWNOACTIVATE) else ShowWindow(Handle, SW_HIDE);
  if (Align <> alNone) and (FParent <> nil) then FParent.Realign;
end;
procedure TCustomControl.WMGetDlgCode(var M: TWMGetDlgCode);
begin DefaultHandler(M); end;

constructor TGraphicControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); FCanvas := TGraphicCanvas.Create;
  TGraphicCanvas(FCanvas).FControl := Self;
  FVisible := True; FEnabled := True; FClickEvents := True;
end;
function TGraphicControl.Perform(Msg, WParam: Word; LParam: LongInt): LongInt;
var Message: TMessage;
begin
  Message.Msg := Msg; Message.WParam := WParam; Message.LParam := LParam; Message.Result := 0;
  Dispatch(Message);
  Result := Message.Result;
end;
procedure TGraphicControl.MouseMessage(Msg, Keys: Word; X, Y: Integer);
var Shift: TShiftState; Button: TMouseButton; Position: TPoint;
begin
  if Msg = WM_RBUTTONUP then
  begin
    Position.X := X; Position.Y := Y;
    if PopupAt(Self, FPopupMenu, ClientToScreen(Position)) then Exit;
  end;
  Shift := [];
  if Keys and MK_SHIFT <> 0 then Include(Shift, ssShift);
  if Keys and MK_CONTROL <> 0 then Include(Shift, ssCtrl);
  if Keys and MK_LBUTTON <> 0 then Include(Shift, ssLeft);
  if Keys and MK_RBUTTON <> 0 then Include(Shift, ssRight);
  if Keys and MK_MBUTTON <> 0 then Include(Shift, ssMiddle);
  if GetKeyState(VK_MENU) < 0 then Include(Shift, ssAlt);
  if Msg = WM_MOUSEMOVE then begin MouseMove(Shift, X, Y); Exit; end;
  if (Msg = WM_LBUTTONDOWN) and (DragMode = dmAutomatic) then begin BeginDrag(False); Exit; end;
  case Msg of
    WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK: Button := mbLeft;
    WM_RBUTTONDOWN, WM_RBUTTONUP, WM_RBUTTONDBLCLK: Button := mbRight;
    else Button := mbMiddle;
  end;
  case Msg of
    WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP:
      begin
        MouseUp(Button, Shift, X, Y);
        if FClickEvents and (Msg = WM_LBUTTONUP) and (X >= 0) and (Y >= 0) and
          (X < FWidth) and (Y < FHeight) then Click;
      end;
    WM_LBUTTONDBLCLK, WM_RBUTTONDBLCLK, WM_MBUTTONDBLCLK:
      begin
        Include(Shift, ssDouble);
        MouseDown(Button, Shift, X, Y);
        if Msg = WM_LBUTTONDBLCLK then DblClick;
      end;
    else MouseDown(Button, Shift, X, Y);
  end;
end;
procedure TGraphicControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin if Assigned(FOnMouseDown) then FOnMouseDown(Self, Button, Shift, X, Y); end;
procedure TGraphicControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin if Assigned(FOnMouseUp) then FOnMouseUp(Self, Button, Shift, X, Y); end;
procedure TGraphicControl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin if Assigned(FOnMouseMove) then FOnMouseMove(Self, Shift, X, Y); end;
procedure TGraphicControl.Click;
begin if Assigned(FOnClick) then FOnClick(Self); end;
procedure TGraphicControl.DblClick;
begin if Assigned(FOnDblClick) then FOnDblClick(Self); end;
procedure TGraphicControl.ControlOperation(Operation: TControlOperation; var Value: Boolean);
begin
  case Operation of
    coReadEnabled: Value := FEnabled;
    coWriteEnabled: SetEnabled(Value);
    coReadVisible: Value := FVisible;
    coWriteVisible: SetVisible(Value);
    coShow: Show;
    coHide: Hide;
    coFront: BringToFront;
    coBack: SendToBack;
  end;
end;
destructor TGraphicControl.Destroy;
begin SetParent(nil); FCanvas.Free; inherited Destroy; end;
procedure TGraphicControl.Paint;
begin end;
function TGraphicControl.GetBoundsRect: TRect;
begin
  Result.Left := FLeft; Result.Top := FTop;
  Result.Right := FLeft + FWidth; Result.Bottom := FTop + FHeight;
end;
function TGraphicControl.GetClientRect: TRect;
begin
  Result.Left := 0; Result.Top := 0; Result.Right := FWidth; Result.Bottom := FHeight;
end;
procedure TGraphicControl.SetBoundsRect(const Value: TRect);
var W, H: LongInt;
begin
  W := LongInt(Value.Right) - Value.Left; H := LongInt(Value.Bottom) - Value.Top;
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then
    raise ENativeWindowError.Create('Invalid graphic bounds');
  SetBounds(Value.Left, Value.Top, W, H);
end;
function TGraphicControl.ClientToScreen(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if FParent = nil then raise ENativeWindowError.Create('Control has no window');
  Origin := FParent.ClientToScreen(Point(FLeft, FTop));
  Result := TranslatePosition(Position, Origin, False);
end;
function TGraphicControl.ScreenToClient(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if FParent = nil then raise ENativeWindowError.Create('Control has no window');
  Origin := FParent.ClientToScreen(Point(FLeft, FTop));
  Result := TranslatePosition(Position, Origin, True);
end;
procedure TGraphicControl.DirtyBounds;
begin
  if (FParent <> nil) and (FParent.Handle <> 0) then FParent.InvalidateArea(GetBoundsRect);
end;
procedure TGraphicControl.Invalidate;
begin if FVisible then DirtyBounds; end;
procedure TGraphicControl.Show;
begin Visible := True; end;
procedure TGraphicControl.Hide;
begin Visible := False; end;
procedure TGraphicControl.ChangeOrder(Front: Boolean);
var Index, Target: Integer;
begin
  if FParent = nil then Exit;
  if (FCanvas.Handle <> 0) or FParent.FChanging or FParent.Painting or
    FParent.FCompositing or (FParent.Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  Index := FParent.FGraphics.IndexOf(Self);
  if Front then Target := FParent.FGraphics.Count - 1 else Target := 0;
  if Index = Target then Exit;
  FParent.FGraphics.Move(Index, Target); DirtyBounds;
end;
procedure TGraphicControl.BringToFront;
begin ChangeOrder(True); end;
procedure TGraphicControl.SendToBack;
begin ChangeOrder(False); end;
procedure TGraphicControl.Update;
begin
  if (FParent = nil) or (FParent.Handle = 0) then Exit;
  if FCanvas.Handle <> 0 then
    raise ENativeWindowError.Create('Cannot update during graphic paint');
  FParent.Update;
end;
procedure TGraphicControl.Repaint;
begin Invalidate; Update; end;
procedure TGraphicControl.RequestAlign;
begin if FParent <> nil then FParent.Realign; end;
procedure TGraphicControl.SetParent(Value: TCustomControl);
var Previous: TCustomControl;
begin
  if Value = FParent then Exit;
  if (FCanvas.Handle <> 0) or
    ((FParent <> nil) and (FParent.FChanging or FParent.Painting or
      FParent.FCompositing or (FParent.Canvas.Handle <> 0))) or
    ((Value <> nil) and (Value.FChanging or Value.Painting or
      Value.FCompositing or (Value.Canvas.Handle <> 0))) then
    raise ENativeWindowError.Create('Cannot reparent during paint');
  if Value <> nil then
  begin
    if Value.FGraphics = nil then Value.FGraphics := TList.Create;
    if Value.FControls = nil then Value.FControls := TList.Create;
    Value.FControls.Add(Self);
    try Value.FGraphics.Add(Self);
    except Value.FControls.Remove(Self); raise; end;
  end;
  Previous := FParent;
  if Previous <> nil then Previous.ForgetGraphic(Self);
  try DirtyBounds;
  except
    if Value <> nil then
    begin Value.FGraphics.Remove(Self); Value.FControls.Remove(Self); end;
    raise;
  end;
  FCanvas.FreeContext;
  FParent := Value;
  if Previous <> nil then
  begin Previous.FGraphics.Remove(Self); Previous.FControls.Remove(Self); end;
  Invalidate;
  if Align <> alNone then
  begin
    if Previous <> nil then Previous.Realign;
    if Value <> nil then Value.Realign;
  end;  if Value <> nil then ParentPropertiesChanged;
end;
procedure TGraphicControl.SetBounds(X, Y, AWidth, AHeight: Integer);
begin
  if (AWidth < 0) or (AHeight < 0) or
    (LongInt(X) + AWidth > 32767) or (LongInt(Y) + AHeight > 32767) then
    raise ENativeWindowError.Create('Invalid graphic bounds');
  if (X = FLeft) and (Y = FTop) and (AWidth = FWidth) and (AHeight = FHeight) then Exit;
  if (FCanvas <> nil) and (FCanvas.Handle <> 0) then
    raise ENativeWindowError.Create('Cannot resize during graphic paint');
  { A borrowed context is set up for the old position. }
  if FCanvas <> nil then FCanvas.FreeContext;
  DirtyBounds; FLeft := X; FTop := Y; FWidth := AWidth; FHeight := AHeight; Invalidate;
  if (Align <> alNone) and (FParent <> nil) and not FParent.FAligning then FParent.Realign;
end;
procedure TGraphicControl.SetLeft(Value: Integer);
begin SetBounds(Value, FTop, FWidth, FHeight); end;
procedure TGraphicControl.SetTop(Value: Integer);
begin SetBounds(FLeft, Value, FWidth, FHeight); end;
procedure TGraphicControl.SetWidth(Value: Integer);
begin SetBounds(FLeft, FTop, Value, FHeight); end;
procedure TGraphicControl.SetHeight(Value: Integer);
begin SetBounds(FLeft, FTop, FWidth, Value); end;
function TGraphicControl.ParentControl: TControl;
begin Result := FParent; end;
procedure TGraphicControl.ApplyFont;
begin FCanvas.Font.Assign(Font); end;
procedure TGraphicControl.FontChanged;
begin Invalidate; end;
procedure TGraphicControl.ColorChanged;
begin Invalidate; end;
procedure TGraphicControl.SetVisible(Value: Boolean);
begin
  if Value = FVisible then Exit;
  if not Value and (FParent <> nil) then FParent.ForgetGraphic(Self);
  DirtyBounds; FVisible := Value; Invalidate;
  if (Align <> alNone) and (FParent <> nil) then FParent.Realign;
end;
procedure TGraphicControl.SetEnabled(Value: Boolean);
begin
  if Value = FEnabled then Exit;
  if (FCanvas.Handle <> 0) or ((FParent <> nil) and
    (FParent.FChanging or FParent.Painting or FParent.FCompositing or
    (FParent.Canvas.Handle <> 0))) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  if not Value and (FParent <> nil) then FParent.ForgetGraphic(Self);
  FEnabled := Value; Invalidate;
  Perform(CM_ENABLEDCHANGED, 0, 0);
end;
procedure TGraphicControl.PaintOn(DC: HDC);
var State, Clip: SmallInt; Background: HBRUSH; Area: TRect; Surface: TBitmap;
begin
  if not FVisible or (FWidth = 0) or (FHeight = 0) then Exit;
  State := SaveDC(DC);
  if State = 0 then raise ENativeWindowError.Create('Cannot save graphic DC');
  try
    OffsetViewportOrg(DC, FLeft, FTop);
    Clip := IntersectClipRect(DC, 0, 0, FWidth, FHeight);
    if Clip = 0 then raise ENativeWindowError.Create('Cannot clip graphic DC');
    if Clip = NULLREGION then Exit;
    Area.Left := 0; Area.Top := 0; Area.Right := FWidth; Area.Bottom := FHeight;
    { Flood fills require full geometry, even when USER requests a tiny fragment. }
    Surface := TBitmap.Create;
    try
      Surface.SetSize(FWidth, FHeight);
      Background := CreateSolidBrush(ColorToRGB(Color));
      if Background = 0 then raise ENativeWindowError.Create('Cannot create graphic brush');
      try
        if WinProcs.FillRect(Surface.Canvas.Handle, Area, Background) = 0 then
          raise ENativeWindowError.Create('Cannot fill graphic background');
      finally DeleteObject(Background); end;
      FCanvas.Handle := Surface.Canvas.Handle;
      try Paint; finally FCanvas.Handle := 0; end;
      if not BitBlt(DC, 0, 0, FWidth, FHeight, Surface.Canvas.Handle, 0, 0, SRCCOPY) then
        raise ENativeWindowError.Create('Cannot composite graphic pixels');
    finally Surface.Free; end;
  finally RestoreDC(DC, State); end;
end;
function FindDragTarget(const Pos: TPoint; AllowDisabled: Boolean): TControl;
var Window: HWND; Native: TNativeWindow; Local: TPoint; Graphic: TGraphicControl;
begin
  Result := nil;
  Window := PackedWindowFromPoint(MakeLong(Pos.X, Pos.Y));
  { Unmanaged USER children (a combo box's edit) belong to their managed parent. }
  while Window <> 0 do
  begin
    Native := FindNativeWindow(Window);
    if Native is TCustomControl then Break;
    Window := GetParent(Window);
  end;
  if Window = 0 then Exit;
  Result := TCustomControl(Native);
  Local := TCustomControl(Native).ScreenToClient(Pos);
  Graphic := TCustomControl(Native).GraphicAt(Local.X, Local.Y, AllowDisabled);
  if Graphic <> nil then Result := Graphic;
end;
function GetShortHint(const Hint: string): string;
var I: Integer;
begin
  I := Pos('|', Hint);
  if I = 0 then Result := Hint else Result := Copy(Hint, 1, I - 1);
end;
function GetLongHint(const Hint: string): string;
var I: Integer;
begin
  I := Pos('|', Hint);
  if I = 0 then Result := Hint else Result := Copy(Hint, I + 1, 255);
end;
function TCustomControl.HandleAllocated: Boolean;
begin Result := Handle <> 0; end;

{ THintWindow }
constructor THintWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := $80FFFF;
  Font.Name := 'MS Sans Serif'; Font.Size := 8;
  { Callers measure hint text on Canvas before the first paint. }
  Canvas.Font := Font;
end;
procedure THintWindow.SetCaption(const Value: string);
begin
  if Value = FCaption then Exit;
  FCaption := Value;
  if Handle <> 0 then Invalidate;
end;
procedure THintWindow.Paint;
var R: TRect; Text: array[0..255] of Char;
begin
  R := ClientRect; Inc(R.Left, 1);
  Canvas.Brush.Color := Color; Canvas.FillRect(ClientRect);
  Canvas.Font := Font; Canvas.Font.Color := clWindowText;
  SetBkMode(Canvas.ContextHandle, TRANSPARENT);
  DrawText(Canvas.ContextHandle, StrPCopy(Text, FCaption), -1, R,
    DT_LEFT or DT_NOPREFIX or DT_WORDBREAK);
end;
procedure THintWindow.ActivateHint(Rect: TRect; const AHint: string);
var W, H, ScreenW, ScreenH: Integer;
begin
  Caption := AHint;
  W := Rect.Right - Rect.Left; H := Rect.Bottom - Rect.Top;
  ScreenW := GetSystemMetrics(SM_CXSCREEN); ScreenH := GetSystemMetrics(SM_CYSCREEN);
  if Rect.Left + W > ScreenW then Rect.Left := ScreenW - W;
  if Rect.Top + H > ScreenH then Rect.Top := ScreenH - H;
  if Rect.Left < 0 then Rect.Left := 0;
  if Rect.Top < 0 then Rect.Top := 0;
  HandleNeeded;
  SetWindowPos(Handle, HWND_TOPMOST, Rect.Left, Rect.Top, W, H,
    SWP_SHOWWINDOW or SWP_NOACTIVATE);
  Invalidate;
end;
function THintWindow.IsHintMsg(var Msg: TMsg): Boolean;
begin
  with Msg do
    Result := ((Message >= WM_KEYFIRST) and (Message <= WM_KEYLAST)) or
      (Message = WM_COMMAND) or (Message = WM_ACTIVATEAPP) or
      ((Message > WM_MOUSEMOVE) and (Message <= WM_MOUSELAST)) or
      (Message = WM_NCMOUSEMOVE);
end;
procedure THintWindow.HandleNeeded;
begin
  { Hidden until ActivateHint; measuring text on Canvas creates it. }
  if Handle = 0 then CreateHandle(0, '', WS_POPUP or WS_BORDER, 0, 0, 0, 0);
end;
procedure THintWindow.ReleaseHandle;
begin
  if Handle <> 0 then DestroyHandle;
end;
destructor TControlCanvas.Destroy;
begin FreeContext; inherited Destroy; end;
procedure TControlCanvas.FreeContext;
begin
  if FContext = 0 then Exit;
  Handle := 0;
  ReleaseDC(FWindow, FContext);
  FContext := 0; FWindow := 0;
end;
procedure TControlCanvas.SetControl(Value: TControl);
var Graphic: TGraphicControl;
begin
  FreeContext;
  FControl := Value;
  if Value is TCustomControl then FWindow := TCustomControl(Value).Handle
  else if (Value is TGraphicControl) and (TGraphicControl(Value).Parent <> nil) then
    FWindow := TGraphicControl(Value).Parent.Handle
  else FWindow := 0;
  if FWindow = 0 then Exit;
  FContext := GetDC(FWindow);
  if FContext = 0 then raise ENativeWindowError.Create('Cannot get control DC');
  if Value is TGraphicControl then
  begin
    Graphic := TGraphicControl(Value);
    SetViewportOrg(FContext, Graphic.Left, Graphic.Top);
    IntersectClipRect(FContext, 0, 0, Graphic.Width, Graphic.Height);
  end;
  Handle := FContext;
end;
type
  { Protected TControl drag hooks, reached from the manager. }
  TDragAccess = class(TControl);
  TDragCapture = class(TNativeWindow)
  protected
    procedure WndProc(var Message: TMessage); override;
  end;
  TNativeDragManager = class(TDragManager)
  private
    FCapture: TDragCapture;
    FTarget: TControl;
    FActive, FAccepted: Boolean;
    FStart: TPoint;
    function FindTarget(const Position: TPoint): TControl;
    function TargetPoint(Target: TControl; const Position: TPoint): TPoint;
    function Notify(Target: TControl; const Position: TPoint; State: TDragState): Boolean;
    procedure ShowDragCursor;
  public
    destructor Destroy; override;
    procedure Start(Control: TControl; Immediate: Boolean); override;
    procedure Move(const Position: TPoint);
    procedure Finish(Drop: Boolean); override;
    procedure Forget(Control: TControl); override;
  end;
const
  { Pixels the mouse must travel before a delayed drag starts (Delphi 1). }
  DragThreshold = 5;
  CM_RECAPTURE = CM_BASE + 100;
var NativeDragManager: TNativeDragManager;
procedure TDragCapture.WndProc(var Message: TMessage);
var Position: TPoint;
begin
  case Message.Msg of
    WM_MOUSEMOVE:
      begin GetCursorPos(Position); NativeDragManager.Move(Position); end;
    WM_LBUTTONUP: NativeDragManager.Finish(True);
    WM_RBUTTONDOWN, WM_CANCELMODE: NativeDragManager.Finish(False);
    CM_RECAPTURE:
      { A native control may take capture back after the press that began the drag. }
      if (DragSource <> nil) and (GetCapture <> Handle) then
        if GetKeyState(VK_LBUTTON) < 0 then SetCapture(Handle)
        else NativeDragManager.Finish(True);
  else inherited WndProc(Message);
  end;
end;
destructor TNativeDragManager.Destroy;
begin
  FCapture.Free;
  inherited Destroy;
end;
function TNativeDragManager.FindTarget(const Position: TPoint): TControl;
begin Result := FindDragTarget(Position, False); end;
function TNativeDragManager.TargetPoint(Target: TControl; const Position: TPoint): TPoint;
begin
  if Target is TCustomControl then Result := TCustomControl(Target).ScreenToClient(Position)
  else if (Target is TGraphicControl) and (TGraphicControl(Target).Parent <> nil) then
    Result := TGraphicControl(Target).ScreenToClient(Position)
  else Result := Position;
end;
function TNativeDragManager.Notify(Target: TControl; const Position: TPoint;
  State: TDragState): Boolean;
var Local: TPoint;
begin
  Result := False;
  Local := TargetPoint(Target, Position);
  TDragAccess(Target).DragOver(DragSource, Local.X, Local.Y, State, Result);
end;
procedure TNativeDragManager.ShowDragCursor;
var Index: TCursor; Value: HCURSOR;
begin
  if FAccepted then Index := TDragAccess(DragSource).DragCursor else Index := crNoDrop;
  if LookupNativeCursor(Index, Value) then WinProcs.SetCursor(Value);
end;
procedure TNativeDragManager.Start(Control: TControl; Immediate: Boolean);
begin
  if (DragSource <> nil) or (Control = nil) then Exit;
  { A graphic source pressed through its parent: that capture becomes ours. }
  if (Control is TGraphicControl) and (TGraphicControl(Control).Parent <> nil) then
    TGraphicControl(Control).Parent.ForgetGraphic(TGraphicControl(Control));
  if FCapture = nil then FCapture := TDragCapture.Create(nil);
  if FCapture.Handle = 0 then FCapture.CreateHandle(0, '', WS_POPUP, 0, 0, 0, 0);
  DragSource := Control;
  FTarget := nil; FAccepted := False; FActive := Immediate;
  GetCursorPos(FStart);
  SetCapture(FCapture.Handle);
  PostMessage(FCapture.Handle, CM_RECAPTURE, 0, 0);
  if Immediate then Move(FStart);
end;
procedure TNativeDragManager.Move(const Position: TPoint);
var Target: TControl; State: TDragState;
begin
  if DragSource = nil then Exit;
  if not FActive then
  begin
    if (Abs(Position.X - FStart.X) < DragThreshold) and
      (Abs(Position.Y - FStart.Y) < DragThreshold) then Exit;
    FActive := True;
  end;
  Target := FindTarget(Position);
  if Target <> FTarget then
  begin
    if FTarget <> nil then Notify(FTarget, Position, dsDragLeave);
    { The leave handler may have ended the drag. }
    if DragSource = nil then Exit;
    FTarget := Target;
    State := dsDragEnter;
  end
  else State := dsDragMove;
  FAccepted := False;
  if Target <> nil then FAccepted := Notify(Target, Position, State);
  if DragSource <> nil then ShowDragCursor;
end;
procedure TNativeDragManager.Finish(Drop: Boolean);
var Source, Target: TControl; Position, Local: TPoint; Accepted: Boolean;
begin
  if DragSource = nil then Exit;
  Source := DragSource; Target := FTarget; Accepted := FAccepted and FActive;
  GetCursorPos(Position);
  { Clear first: the handlers below may start another drag. }
  FTarget := nil; FAccepted := False;
  if (FCapture <> nil) and (GetCapture = FCapture.Handle) then ReleaseCapture;
  if Target <> nil then
    if Drop and Accepted then
    begin
      Local := TargetPoint(Target, Position);
      DragSource := nil;
      TDragAccess(Target).DragDrop(Source, Local.X, Local.Y);
    end
    else
    begin
      Notify(Target, Position, dsDragLeave);
      Target := nil;
    end;
  DragSource := nil;
  if Target <> nil then Local := TargetPoint(Target, Position)
  else Local := TargetPoint(Source, Position);
  TDragAccess(Source).DoEndDrag(Target, Local.X, Local.Y);
  RefreshNativeCursor(CursorTarget);
end;
procedure TNativeDragManager.Forget(Control: TControl);
begin
  if FTarget = Control then begin FTarget := nil; FAccepted := False; end;
  if DragSource = Control then
  begin
    { No end-drag event for a source that is being destroyed. }
    DragSource := nil; FTarget := nil; FAccepted := False;
    if (FCapture <> nil) and (GetCapture = FCapture.Handle) then ReleaseCapture;
  end;
end;
initialization
  NewStyleControls := Lo(LoWord(GetVersion)) >= 4;
  NativeDragManager := TNativeDragManager.Create;
  DragManager := NativeDragManager;
finalization
  DragManager := nil;
  NativeDragManager.Free;
end.
