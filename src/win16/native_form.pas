{ SPDX-License-Identifier: GPL-2.0-or-later
  Modeless native form foundation; no DFM loader or Forms compatibility claim. }
unit native_form;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This form foundation requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Controls;
type
  TNativeForm = class;
  TNativeFormClass = class of TNativeForm;
  TNativeFormHost = class(TComponent)
  protected
    procedure AttachForm(Value: TNativeForm);
    procedure DetachForm(Value: TNativeForm);
    procedure FormClosed(Value: TNativeForm); virtual; abstract;
    function FormHelp(Value: TNativeForm; Context: LongInt): Boolean; virtual;
  end;
  TNativeCloseAction = (ncaNone, ncaHide, ncaDestroy, ncaMinimize);
  TWindowState = (wsNormal, wsMinimized, wsMaximized);
  TNativeCloseQueryEvent = procedure(Sender: TObject; var CanClose: Boolean) of object;
  TNativeCloseEvent = procedure(Sender: TObject; var Action: TNativeCloseAction) of object;
  TNativeForm = class(TCustomControl)
  private
    FCaption: string;
    FHost: TNativeFormHost;
    FChangingForm: Boolean;
    FChangingActiveControl: Boolean;
    FActivationDepth: Word;
    FResizing: Boolean;
    FChangingState, FPendingState: Boolean;
    FWindowState: TWindowState;
    FResizeWidth, FResizeHeight: Integer;
    FInitialControl: TCustomControl;
    FLastFocus: HWND;
    FOnShow, FOnHide: TNotifyEvent;
    FOnActivate, FOnDeactivate: TNotifyEvent;
    FOnResize: TNotifyEvent;
    FOnCloseQuery: TNativeCloseQueryEvent;
    FOnClose: TNativeCloseEvent;
    procedure SetInitialControl(Value: TCustomControl);
    function ContainsControl(Value: TCustomControl): Boolean;
    procedure SetCaption(const Value: string);
    procedure CheckChanging;
    procedure HideWindow;
    procedure WMClose(var M: TMessage); message WM_CLOSE;
    procedure WMActivate(var M: TWMActivate); message WM_ACTIVATE;
    procedure RestoreFocus;
    procedure WMSize(var M: TMessage); message WM_SIZE;
    procedure WMNCDestroy(var M: TMessage); message WM_NCDESTROY;
    procedure SetNormalBounds(X, Y, AWidth, AHeight: Integer);
    function GetActive: Boolean;
    function GetActiveControl: TCustomControl;
    procedure SetActiveControl(Value: TCustomControl);
    function ReadWindowState: TWindowState;
    function GetWindowState: TWindowState;
    procedure SetWindowState(Value: TWindowState);
    procedure ApplyWindowState(Value: TWindowState);
    function GetFormVisible: Boolean;
    procedure SetFormVisible(Value: Boolean);
  protected
    procedure ChangeView(Action: TControlViewAction); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function CloseQuery: Boolean; virtual;
    procedure DoClose(var Action: TNativeCloseAction); virtual;
    procedure DoShow; virtual;
    { Just before the window is first shown, as Delphi's CMShowingChanged. }
    procedure PlaceOnShow; virtual;
    procedure DoHide; virtual;
    procedure DoActivate; virtual;
    procedure DoDeactivate; virtual;
    procedure Resize; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetBounds(X, Y, AWidth, AHeight: Integer); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure Show;
    procedure Hide;
    procedure Close;
    function TryClose: Boolean;
    property LifecycleHost: TNativeFormHost read FHost;
    { Assign to TNativeMessageLoop.OnMessage; no implicit task-global hook. }
    function ProcessDialogMessage(var Message: TMsg): Boolean; virtual;
    property Caption: string read FCaption write SetCaption;
    property Visible: Boolean read GetFormVisible write SetFormVisible;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write FOnDeactivate;
    property OnResize: TNotifyEvent read FOnResize write FOnResize;
    property WindowState: TWindowState read GetWindowState write SetWindowState;
    property Active: Boolean read GetActive;
    { Live native focus only. Use InitialControl for deferred/hidden focus. }
    property ActiveControl: TCustomControl read GetActiveControl write SetActiveControl;
    { Whether Control is the form's active control: the focused one while
      the form is active, the one that had the focus while it is not. }
    function IsActiveControl(Control: TCustomControl): Boolean;
    property OnCloseQuery: TNativeCloseQueryEvent read FOnCloseQuery write FOnCloseQuery;
    property OnClose: TNativeCloseEvent read FOnClose write FOnClose;
    { DFM ActiveControl's initial-focus policy, not a complete VCL focus model. }
    property InitialControl: TCustomControl read FInitialControl write SetInitialControl;
  end;
implementation
uses SysUtils, WinProcs, Win31, native_window;
function TNativeFormHost.FormHelp(Value: TNativeForm; Context: LongInt): Boolean;
begin Result := False; end;
procedure TNativeFormHost.AttachForm(Value: TNativeForm);
begin
  if (Value = nil) or ((Value.FHost <> nil) and (Value.FHost <> Self)) then
    raise ENativeWindowError.Create('Form already has a host');
  if Value.FHost = Self then Exit;
  Value.FHost := Self; FreeNotification(Value);
end;
procedure TNativeFormHost.DetachForm(Value: TNativeForm);
begin
  if (Value = nil) or (Value.FHost <> Self) then Exit;
  Value.FHost := nil; RemoveFreeNotification(Value);
end;
function TNativeForm.ContainsControl(Value: TCustomControl): Boolean;
begin
  Result := False;
  if (Value = nil) or (Value = Self) then Exit;
  Value := Value.Parent;
  while Value <> nil do
  begin
    if Value = Self then begin Result := True; Exit; end;
    Value := Value.Parent;
  end;
end;
procedure TNativeForm.SetInitialControl(Value: TCustomControl);
begin
  if Value = FInitialControl then Exit;
  if (Value <> nil) and not ContainsControl(Value) then
    raise ENativeWindowError.Create('Invalid form focus');
  if FInitialControl <> nil then FInitialControl.RemoveFreeNotification(Self);
  FInitialControl := Value;
  if Value <> nil then Value.FreeNotification(Self);
end;
procedure TNativeForm.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FInitialControl) then FInitialControl := nil;
  if (Operation = opRemove) and (AComponent = FHost) then FHost := nil;
  inherited Notification(AComponent, Operation);
end;
function TNativeForm.ProcessDialogMessage(var Message: TMsg): Boolean;
var Code: Word; Current: TCustomControl;
begin
  Result := False;
  if WindowState = wsMinimized then Exit;
  if not CanFocus then Exit;
  if Message.message = WM_SYSCHAR then
  begin
    if (DWORD(Message.lParam) and $20000000 = 0) or
      (Message.wParam = 0) or (Message.wParam > 255) or (GetKeyState(VK_CONTROL) < 0) then Exit;
    Current := FindControl(Message.hwnd);
    if (Current <> nil) and Current.CanFocus then
      Result := DispatchMnemonic(Char(Message.wParam));
    Exit;
  end;
  if Message.message <> WM_KEYDOWN then Exit;
  if (Message.wParam <> VK_TAB) and (Message.wParam <> VK_RETURN) and
    (Message.wParam <> VK_ESCAPE) and (Message.wParam <> VK_F1) then Exit;
  if (GetKeyState(VK_CONTROL) < 0) or (GetKeyState(VK_MENU) < 0) then Exit;
  Current := FindControl(Message.hwnd);
  if (Current = nil) or not Current.CanFocus then Exit;
  Code := Word(SendMessage(Message.hwnd, WM_GETDLGCODE, Message.wParam,
    LongInt(Pointer(@Message))));
  { As in Delphi, Tab stays in a control only with DLGC_WANTTAB. }
  if (Message.wParam <> VK_TAB) and (Code and DLGC_WANTALLKEYS <> 0) then Exit;
  if Message.wParam = VK_F1 then
  begin
    { Only the live focused target gets plain first-press F1 help. Never keep
      using this form/control after the user help callback returns. }
    if (FHost = nil) or (GetFocus <> Message.hwnd) or
      (GetKeyState(VK_SHIFT) < 0) or
      (DWORD(Message.lParam) and $60000000 <> 0) then Exit;
    Result := FHost.FormHelp(Self, Current.ResolveHelpContext); Exit;
  end;
  if Message.wParam = VK_TAB then
  begin
    if Code and DLGC_WANTTAB <> 0 then Exit;
    Result := FocusNext(GetKeyState(VK_SHIFT) >= 0);
  end
  else Result := DispatchDialogKey(Message.wParam);
end;
constructor TNativeForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FResizeWidth := -1; FResizeHeight := -1;
  Visible := False; SetBounds(0, 0, 320, 200);
end;
procedure TNativeForm.CheckChanging;
begin
  if FChangingForm or Painting or (Canvas.Handle <> 0) or (FActivationDepth <> 0) or FResizing or FChangingState then
    raise ENativeWindowError.Create('Form lifecycle reentry');
end;
{ As Delphi's TWinControl.SetBounds for an icon: the bounds become the
  restore placement and the window keeps its state. }
procedure TNativeForm.SetNormalBounds(X, Y, AWidth, AHeight: Integer);
var Placement: TWindowPlacement;
begin
  if (AWidth < 0) or (AHeight < 0) or (LongInt(X) + AWidth > 32767) or
    (LongInt(Y) + AHeight > 32767) then raise ENativeWindowError.Create('Invalid control bounds');
  FillChar(Placement, SizeOf(Placement), 0); Placement.length := SizeOf(Placement);
  if not GetWindowPlacement(Handle, @Placement) then raise ENativeWindowError.Create('Invalid form state');
  Placement.flags := 0;
  with Placement.rcNormalPosition do
  begin Left := X; Top := Y; Right := X + AWidth; Bottom := Y + AHeight; end;
  { SetWindowPlacement shows the window with showCmd. }
  if not IsWindowVisible(Handle) then Placement.showCmd := SW_HIDE
  else if IsIconic(Handle) then Placement.showCmd := SW_SHOWMINNOACTIVE
  else Placement.showCmd := SW_SHOWMAXIMIZED;
  FChangingState := True;
  try
    if not SetWindowPlacement(Handle, @Placement) then raise ENativeWindowError.Create('Invalid form state');
  finally FChangingState := False; end;
  StoreBounds(Placement.rcNormalPosition);
end;
procedure TNativeForm.SetBounds(X, Y, AWidth, AHeight: Integer);
begin
  if FResizing or FChangingState then raise ENativeWindowError.Create('Form lifecycle reentry');
  if (Handle <> 0) and (ReadWindowState <> wsNormal) then
    SetNormalBounds(X, Y, AWidth, AHeight)
  else inherited SetBounds(X, Y, AWidth, AHeight);
end;
procedure TNativeForm.Resize;
begin if Assigned(FOnResize) then FOnResize(Self); end;
procedure TNativeForm.WMSize(var M: TMessage);
var Area: TRect; W, H: Integer;
begin
  inherited WMSize(M);
  { USER, not an untrusted message payload, supplies the current client size. }
  WinProcs.GetClientRect(Handle, Area);
  W := Area.Right - Area.Left; H := Area.Bottom - Area.Top;
  if (W = FResizeWidth) and (H = FResizeHeight) then Exit;
  FResizeWidth := W; FResizeHeight := H;
  if FResizing then Exit;
  FResizing := True;
  try Resize; finally FResizing := False; end;
end;
procedure TNativeForm.WMNCDestroy(var M: TMessage);
var Placement: TWindowPlacement; Valid: Boolean;
begin
  FWindowState := GetWindowState; FPendingState := True;
  FillChar(Placement, SizeOf(Placement), 0); Placement.length := SizeOf(Placement);
  Valid := GetWindowPlacement(Handle, @Placement);
  try inherited WMNCDestroy(M);
  finally
    if Valid then StoreBounds(Placement.rcNormalPosition);
    FResizeWidth := -1; FResizeHeight := -1;
  end;
  if not Valid then raise ENativeWindowError.Create('Invalid form state');
end;
function TNativeForm.ReadWindowState: TWindowState;
begin
  if GetWindowTask(Handle) <> GetCurrentTask then raise ENativeWindowError.Create('Invalid form state');
  Result := wsNormal;
  if IsIconic(Handle) then Result := wsMinimized
  else if IsZoomed(Handle) then Result := wsMaximized;
end;
function TNativeForm.GetWindowState: TWindowState;
begin
  { A requested state is kept only while the window is hidden; once visible,
    however it was shown, USER knows the state, as Delphi's WMSize does. }
  if (Handle <> 0) and FPendingState and IsWindowVisible(Handle) then FPendingState := False;
  if (Handle <> 0) and not FPendingState then FWindowState := ReadWindowState;
  Result := FWindowState;
end;
procedure TNativeForm.ApplyWindowState(Value: TWindowState);
var Command: Integer;
begin
  case Value of
    wsNormal: Command := SW_SHOWNORMAL;
    wsMinimized: Command := SW_MINIMIZE;
    wsMaximized: Command := SW_SHOWMAXIMIZED;
  end;
  { SW_RESTORE may restore a previously maximized icon to maximized, not normal. }
  ShowWindow(Handle, Command); FWindowState := ReadWindowState;
  if FWindowState <> Value then raise ENativeWindowError.Create('Invalid form state');
end;
procedure TNativeForm.SetWindowState(Value: TWindowState);
begin
  CheckChanging;
  if (Ord(Value) < Ord(wsNormal)) or (Ord(Value) > Ord(wsMaximized)) then
    raise ENativeWindowError.Create('Invalid form state');
  if Handle <> 0 then ReadWindowState;
  if Value = GetWindowState then Exit;
  if (Handle = 0) or not Visible then
  begin FWindowState := Value; FPendingState := True; Exit; end;
  FChangingState := True;
  try ApplyWindowState(Value); finally FChangingState := False; end;
end;
procedure TNativeForm.SetCaption(const Value: string);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('Invalid form caption');
  { Caption is new before WM_SETTEXT, as Delphi's reads the window text:
    Calmira's forms paint their own title from Caption while handling it. }
  FCaption := Value;
  if Handle <> 0 then
  begin StrPCopy(Buffer, Value); SetWindowText(Handle, Buffer); end;
end;
procedure TNativeForm.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  { Parent is the owner: a top-level window, never a child. }
  if (Style and WS_CHILD <> 0) or ((Parent <> 0) and
    (DWORD(GetWindowLong(Parent, GWL_STYLE)) and WS_CHILD <> 0)) then
    raise ENativeWindowError.Create('Invalid form parent');
  inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);
  FCaption := Caption;
end;
procedure TNativeForm.PlaceOnShow;
begin end;
procedure TNativeForm.DoShow;
begin
  if Assigned(FOnShow) then FOnShow(Self);
  if WindowState <> wsMinimized then
    if ContainsControl(FInitialControl) then
    begin
      if FInitialControl.CanFocus then FInitialControl.SetFocus;
    end;
end;
procedure TNativeForm.RestoreFocus;
var Current: TCustomControl;
begin
  Current := FindControl(GetFocus);
  if (Current <> nil) and (Current <> Self) then Exit;
  if (FLastFocus <> 0) and IsChild(Handle, FLastFocus) then
  begin
    Current := FindControl(FLastFocus);
    if (Current <> nil) and (Current <> Self) and Current.CanFocus then
    begin Current.SetFocus; Exit; end;
  end;
  if ContainsControl(FInitialControl) and FInitialControl.CanFocus then FInitialControl.SetFocus
  else FocusNext(True);
end;
procedure TNativeForm.DoHide;
begin if Assigned(FOnHide) then FOnHide(Self); end;
function TNativeForm.GetActive: Boolean;
begin
  Result := (Handle <> 0) and (GetWindowTask(Handle) = GetCurrentTask) and
    (GetActiveWindow = Handle);
end;
function TNativeForm.IsActiveControl(Control: TCustomControl): Boolean;
begin
  if (Control = nil) or not Control.HandleAllocated then Result := False
  else if Active then Result := GetFocus = Control.Handle
  else Result := (FLastFocus <> 0) and (FLastFocus = Control.Handle);
end;
function TNativeForm.GetActiveControl: TCustomControl;
begin
  Result := nil;
  if not Active or (WindowState = wsMinimized) then Exit;
  Result := FindControl(GetFocus);
  if Result = Self then Result := nil;
  if Result <> nil then
    if not Result.CanFocus then Result := nil;
end;
procedure TNativeForm.SetActiveControl(Value: TCustomControl);
begin
  if FChangingActiveControl or not Active or (WindowState = wsMinimized) then
    raise ENativeWindowError.Create('Invalid form focus');
  if Value <> nil then
  begin
    if not ContainsControl(Value) then raise ENativeWindowError.Create('Invalid form focus');
    if FindControl(Value.Handle) <> Value then raise ENativeWindowError.Create('Invalid form focus');
    if not Value.CanFocus then raise ENativeWindowError.Create('Invalid form focus');
  end;
  FChangingActiveControl := True;
  try
    if Value = nil then SetFocus else Value.SetFocus;
  finally FChangingActiveControl := False; end;
end;
procedure TNativeForm.DoActivate;
begin if Assigned(FOnActivate) then FOnActivate(Self); end;
procedure TNativeForm.DoDeactivate;
begin if Assigned(FOnDeactivate) then FOnDeactivate(Self); end;
procedure TNativeForm.WMActivate(var M: TWMActivate);
var Current: TCustomControl;
begin
  if FActivationDepth >= 32 then raise ENativeWindowError.Create('Form activation recursion');
  Inc(FActivationDepth);
  try
    { Preserve USER's focus/default processing even when an event raises.
      Notify each native transition, including nested cross-form activation. }
    if M.Active = WA_INACTIVE then
    begin
      Current := FindControl(GetFocus);
      if (Current <> nil) and (Current <> Self) then FLastFocus := Current.Handle;
    end;
    DefaultHandler(M);
    { As Delphi's SetActive: the form's active control, by default its first
      tab stop, takes the focus, so a focused button becomes the active one. }
    if (M.Active <> WA_INACTIVE) and not M.Minimized and IsWindowVisible(Handle) then RestoreFocus;
    case M.Active of
      WA_INACTIVE: DoDeactivate;
      WA_ACTIVE, WA_CLICKACTIVE: DoActivate;
    end;
  finally Dec(FActivationDepth); end;
end;
function TNativeForm.CloseQuery: Boolean;
begin
  Result := True;
  if Assigned(FOnCloseQuery) then FOnCloseQuery(Self, Result);
end;
procedure TNativeForm.DoClose(var Action: TNativeCloseAction);
begin if Assigned(FOnClose) then FOnClose(Self, Action); end;
const
  ShowCommands: array[TWindowState] of Integer = (SW_SHOWNORMAL, SW_SHOWMINNOACTIVE, SW_SHOWMAXIMIZED);
procedure TNativeForm.Show;
var Requested: TWindowState; Focus: HWND; Control: TCustomControl;
begin
  CheckChanging; FChangingForm := True;
  try
    Requested := GetWindowState;
    if Handle = 0 then
      CreateHandle(0, FCaption, WS_OVERLAPPEDWINDOW or WS_CLIPCHILDREN or WS_CLIPSIBLINGS,
        Left, Top, Width, Height);
    if Visible then Exit;
    FPendingState := False;
    PlaceOnShow;
    { As Delphi's CMShowingChanged: a normal or maximized form is activated
      when shown (Calmira's Task Manager, shown on CTASKMAN's message). }
    ShowWindow(Handle, ShowCommands[Requested]);
    if ReadWindowState <> Requested then ApplyWindowState(Requested);
    Focus := GetFocus;
    DoShow;
    { Delphi enters the focused control after OnShow: text OnShow put into
      an edit or combo box is selected (Calmira's Select Icon file name). }
    if Assigned(FOnShow) and (Focus <> 0) and (GetFocus = Focus) then
    begin
      Control := FindControl(Focus);
      if Control <> nil then Control.SelectOnEnter;
    end;
    { Delphi runs OnShow before the window appears; here it is already
      erased. What OnShow drew over the screen (Calmira's shut-down dialog
      darkens it) is painted over by the frame and every child again. }
    if Assigned(FOnShow) and IsWindowVisible(Handle) then
      RedrawWindow(Handle, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or RDW_ALLCHILDREN);
  finally FChangingForm := False; end;
end;
procedure TNativeForm.ChangeView(Action: TControlViewAction);
begin
  case Action of
    cvaShow: Show;
    cvaHide: Hide;
    else
    begin
      CheckChanging;
      if (Handle = 0) or not Visible then Exit;
      FChangingForm := True;
      try
        inherited ChangeView(Action);
        if (Action = cvaFront) and Enabled then SetActiveWindow(Handle);
      finally FChangingForm := False; end;
    end;
  end;
end;
{ As Delphi's TCustomForm.SetVisible and CMShowingChanged: Visible shows or
  hides a form the way Show and Hide do, with OnShow and OnHide (Calmira's
  taskbar, shown by its DFM, makes its system-menu helper window in OnShow). }
function TNativeForm.GetFormVisible: Boolean;
begin Result := inherited Visible; end;
procedure TNativeForm.SetFormVisible(Value: Boolean);
begin
  if not FChangingForm and (Value <> inherited Visible) and (Value or (Handle <> 0)) then
    if Value then Show else Hide
  else inherited Visible := Value;
end;
procedure TNativeForm.HideWindow;
var Current: HWND;
begin
  if (Handle = 0) or not Visible then Exit;
  FWindowState := GetWindowState; FPendingState := True;
  { A hidden form must not leave its descendants owning global input state. }
  Current := GetCapture;
  if (Current = Handle) or IsChild(Handle, Current) then ReleaseCapture;
  Current := GetFocus;
  if (Current = Handle) or IsChild(Handle, Current) then WinProcs.SetFocus(0);
  Visible := False;
  DoHide;
end;
procedure TNativeForm.Hide;
begin
  CheckChanging; FChangingForm := True;
  try HideWindow; finally FChangingForm := False; end;
end;
function TNativeForm.TryClose: Boolean;
var Action: TNativeCloseAction;
begin
  Result := False; Action := ncaNone;
  CheckChanging; FChangingForm := True;
  try
    if Handle = 0 then Exit;
    if not CloseQuery then Exit;
    Action := ncaHide; DoClose(Action);
    case Action of
      ncaNone: ;
      ncaHide: begin HideWindow; Result := True; end;
      ncaDestroy: begin HideWindow; DestroyHandle; Result := True; end;
      ncaMinimize: Result := True;
    end;
  finally FChangingForm := False; end;
  if Result and (Action = ncaMinimize) then SetWindowState(wsMinimized);
  if Result and (FHost <> nil) then FHost.FormClosed(Self);
end;
procedure TNativeForm.Close;
begin
  TryClose;
end;
procedure TNativeForm.WMClose(var M: TMessage);
begin Close; M.Result := 0; end;
end.
