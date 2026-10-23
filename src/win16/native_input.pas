{ SPDX-License-Identifier: GPL-2.0-or-later
  Native input/focus events, not the complete VCL Controls API. }
unit native_input;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This input adapter requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, native_paint, native_cursors;
type
  TMouseButton = (mbLeft, mbRight, mbMiddle);
  TShiftState = set of (ssShift, ssAlt, ssCtrl, ssLeft, ssRight, ssMiddle, ssDouble);
  TMouseEvent = procedure(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Integer) of object;
  TMouseMoveEvent = procedure(Sender: TObject; Shift: TShiftState; X, Y: Integer) of object;
  TKeyEvent = procedure(Sender: TObject; var Key: Word; Shift: TShiftState) of object;
  TKeyPressEvent = procedure(Sender: TObject; var Key: Char) of object;
  TNativeInputWindow = class(TNativePaintWindow)
  private
    FOnMouseDown, FOnMouseUp: TMouseEvent;
    FOnMouseMove: TMouseMoveEvent;
    FOnKeyDown, FOnKeyUp: TKeyEvent;
    FOnKeyPress: TKeyPressEvent;
    FOnEnter, FOnExit: TNotifyEvent;
    FCursor: TCursor;
    FChangingCursor: Boolean;
    procedure SetCursor(Value: TCursor);
    procedure WMSetCursor(var M: TMessage); message WM_SETCURSOR;
    function GetFocused: Boolean;
    function GetMouseCapture: Boolean;
    procedure SetMouseCapture(Value: Boolean);
    procedure MouseMessage(var M: TWMMouse);
    procedure KeyMessage(var M: TMessage);
    procedure CharMessage(var M: TMessage);
    procedure WMMove(var M: TWMMouse); message WM_MOUSEMOVE;
    procedure WMLDown(var M: TWMMouse); message WM_LBUTTONDOWN;
    procedure WMLUp(var M: TWMMouse); message WM_LBUTTONUP;
    procedure WMLDouble(var M: TWMMouse); message WM_LBUTTONDBLCLK;
    procedure WMRDown(var M: TWMMouse); message WM_RBUTTONDOWN;
    procedure WMRUp(var M: TWMMouse); message WM_RBUTTONUP;
    procedure WMRDouble(var M: TWMMouse); message WM_RBUTTONDBLCLK;
    procedure WMMDown(var M: TWMMouse); message WM_MBUTTONDOWN;
    procedure WMMUp(var M: TWMMouse); message WM_MBUTTONUP;
    procedure WMMDouble(var M: TWMMouse); message WM_MBUTTONDBLCLK;
    procedure WMKeyDown(var M: TMessage); message WM_KEYDOWN;
    procedure WMKeyUp(var M: TMessage); message WM_KEYUP;
    procedure WMSysKeyDown(var M: TMessage); message WM_SYSKEYDOWN;
    procedure WMSysKeyUp(var M: TMessage); message WM_SYSKEYUP;
    procedure WMChar(var M: TMessage); message WM_CHAR;
    procedure WMSysChar(var M: TMessage); message WM_SYSCHAR;
    procedure WMSetFocus(var M: TMessage); message WM_SETFOCUS;
    procedure WMKillFocus(var M: TMessage); message WM_KILLFOCUS;
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); virtual;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); virtual;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); virtual;
    procedure KeyDown(var Key: Word; Shift: TShiftState); virtual;
    procedure KeyUp(var Key: Word; Shift: TShiftState); virtual;
    procedure KeyPress(var Key: Char); virtual;
    procedure DoEnter; virtual;
    procedure DoExit; virtual;
  public
    function CanFocus: Boolean;
    procedure SetFocus;
    property Focused: Boolean read GetFocused;
    property MouseCapture: Boolean read GetMouseCapture write SetMouseCapture;
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
    property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
    property OnKeyUp: TKeyEvent read FOnKeyUp write FOnKeyUp;
    property OnKeyPress: TKeyPressEvent read FOnKeyPress write FOnKeyPress;
    property OnEnter: TNotifyEvent read FOnEnter write FOnEnter;
    property OnExit: TNotifyEvent read FOnExit write FOnExit;
    property Cursor: TCursor read FCursor write SetCursor;
  end;
implementation
uses WinProcs, native_window;

procedure TNativeInputWindow.SetCursor(Value: TCursor);
var HandleValue: HCURSOR; Target: HWND;
begin
  if FChangingCursor then raise ENativeWindowError.Create('Invalid cursor');
  FChangingCursor := True;
  try
    if not LookupNativeCursor(Value, HandleValue) then raise ENativeWindowError.Create('Invalid cursor');
    FCursor := Value; Target := CursorTarget;
    if (Handle <> 0) and ((Target = Handle) or IsChild(Handle, Target)) then RefreshNativeCursor(Target);
  finally FChangingCursor := False; end;
end;
procedure TNativeInputWindow.WMSetCursor(var M: TMessage);
var Value: HCURSOR; Target: HWND;
begin
  Target := HWND(M.WParam);
  if (SmallInt(Word(M.LParam)) = HTCLIENT) and (FCursor <> crDefault) and
    ((Target = Handle) or IsChild(Handle, Target)) then
    if LookupNativeCursor(FCursor, Value) then
    begin WinProcs.SetCursor(Value); M.Result := 1; Exit; end;
  DefaultHandler(M);
end;

function KeyboardShift: TShiftState;
begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
end;
procedure TNativeInputWindow.MouseMessage(var M: TWMMouse);
var Shift: TShiftState; Button: TMouseButton;
begin
  Shift := [];
  if M.Keys and MK_SHIFT <> 0 then Include(Shift, ssShift);
  if M.Keys and MK_CONTROL <> 0 then Include(Shift, ssCtrl);
  if M.Keys and MK_LBUTTON <> 0 then Include(Shift, ssLeft);
  if M.Keys and MK_RBUTTON <> 0 then Include(Shift, ssRight);
  if M.Keys and MK_MBUTTON <> 0 then Include(Shift, ssMiddle);
  if GetKeyState(VK_MENU) < 0 then Include(Shift, ssAlt);
  if M.Msg = WM_MOUSEMOVE then MouseMove(Shift, M.XPos, M.YPos)
  else
  begin
    case M.Msg of
      WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK: Button := mbLeft;
      WM_RBUTTONDOWN, WM_RBUTTONUP, WM_RBUTTONDBLCLK: Button := mbRight;
      else Button := mbMiddle;
    end;
    case M.Msg of
      WM_LBUTTONDBLCLK, WM_RBUTTONDBLCLK, WM_MBUTTONDBLCLK: Include(Shift, ssDouble);
    end;
    case M.Msg of
      WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP: MouseUp(Button, Shift, M.XPos, M.YPos);
      else MouseDown(Button, Shift, M.XPos, M.YPos);
    end;
  end;
  DefaultHandler(M);
end;
procedure TNativeInputWindow.KeyMessage(var M: TMessage);
var Key: Word; Shift: TShiftState;
begin
  Key := M.WParam; Shift := KeyboardShift;
  if (M.LParam and $20000000) <> 0 then Include(Shift, ssAlt);
  if (M.Msg = WM_KEYDOWN) or (M.Msg = WM_SYSKEYDOWN) then KeyDown(Key, Shift)
  else KeyUp(Key, Shift);
  M.WParam := Key;
  if Key = 0 then M.Result := 0 else DefaultHandler(M);
end;
procedure TNativeInputWindow.CharMessage(var M: TMessage);
var Key: Char;
begin
  { This adapter handles single-byte ANSI characters, not packed DBCS input. }
  if M.WParam > 255 then begin DefaultHandler(M); Exit; end;
  Key := Char(M.WParam); KeyPress(Key); M.WParam := Ord(Key);
  if Key = #0 then M.Result := 0 else DefaultHandler(M);
end;
procedure TNativeInputWindow.WMMove(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMLDown(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMLUp(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMLDouble(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMRDown(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMRUp(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMRDouble(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMMDown(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMMUp(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMMDouble(var M: TWMMouse); begin MouseMessage(M); end;
procedure TNativeInputWindow.WMKeyDown(var M: TMessage); begin KeyMessage(M); end;
procedure TNativeInputWindow.WMKeyUp(var M: TMessage); begin KeyMessage(M); end;
procedure TNativeInputWindow.WMSysKeyDown(var M: TMessage); begin KeyMessage(M); end;
procedure TNativeInputWindow.WMSysKeyUp(var M: TMessage); begin KeyMessage(M); end;
procedure TNativeInputWindow.WMChar(var M: TMessage); begin CharMessage(M); end;
procedure TNativeInputWindow.WMSysChar(var M: TMessage); begin CharMessage(M); end;
procedure TNativeInputWindow.WMSetFocus(var M: TMessage);
begin DefaultHandler(M); DoEnter; end;
procedure TNativeInputWindow.WMKillFocus(var M: TMessage);
begin DefaultHandler(M); DoExit; end;
procedure TNativeInputWindow.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin if Assigned(FOnMouseDown) then FOnMouseDown(Self, Button, Shift, X, Y); end;
procedure TNativeInputWindow.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin if Assigned(FOnMouseUp) then FOnMouseUp(Self, Button, Shift, X, Y); end;
procedure TNativeInputWindow.MouseMove(Shift: TShiftState; X, Y: Integer);
begin if Assigned(FOnMouseMove) then FOnMouseMove(Self, Shift, X, Y); end;
procedure TNativeInputWindow.KeyDown(var Key: Word; Shift: TShiftState);
begin if Assigned(FOnKeyDown) then FOnKeyDown(Self, Key, Shift); end;
procedure TNativeInputWindow.KeyUp(var Key: Word; Shift: TShiftState);
begin if Assigned(FOnKeyUp) then FOnKeyUp(Self, Key, Shift); end;
procedure TNativeInputWindow.KeyPress(var Key: Char);
begin if Assigned(FOnKeyPress) then FOnKeyPress(Self, Key); end;
procedure TNativeInputWindow.DoEnter;
begin if Assigned(FOnEnter) then FOnEnter(Self); end;
procedure TNativeInputWindow.DoExit;
begin if Assigned(FOnExit) then FOnExit(Self); end;
function TNativeInputWindow.GetFocused: Boolean;
begin Result := (Handle <> 0) and (GetFocus = Handle); end;
function TNativeInputWindow.CanFocus: Boolean;
var Current: HWND;
begin
  Result := False; Current := Handle;
  if (Current = 0) or not IsWindowVisible(Current) then Exit;
  while Current <> 0 do
  begin
    if not IsWindowEnabled(Current) then Exit;
    if DWORD(GetWindowLong(Current, GWL_STYLE)) and WS_CHILD = 0 then Break;
    Current := GetParent(Current);
  end;
  Result := True;
end;
procedure TNativeInputWindow.SetFocus;
begin
  if not CanFocus then raise ENativeWindowError.Create('Window cannot receive focus');
  WinProcs.SetFocus(Handle);
  if not Focused then raise ENativeWindowError.Create('Cannot set native focus');
end;
function TNativeInputWindow.GetMouseCapture: Boolean;
begin Result := (Handle <> 0) and (GetCapture = Handle); end;
procedure TNativeInputWindow.SetMouseCapture(Value: Boolean);
begin
  if not Value then
  begin
    if GetMouseCapture then ReleaseCapture;
    Exit;
  end;
  if not CanFocus then raise ENativeWindowError.Create('Window cannot capture mouse');
  SetCapture(Handle);
  if not GetMouseCapture then raise ENativeWindowError.Create('Cannot capture native mouse');
end;
end.
