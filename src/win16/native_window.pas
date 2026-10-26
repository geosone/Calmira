{ SPDX-License-Identifier: GPL-2.0-or-later
  Native window/dispatch foundation, not the VCL Controls or Forms API. }
unit native_window;
{$mode delphi}{$H-}{$K+}
{$IFNDEF WIN16}{$FATAL This window adapter requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Messages, control_base;
type
  ENativeWindowError = class(Exception);
  TNativeWindow = class(TControl)
  private
    FHandle: HWND;
    FCreating, FDestroying: Boolean;
    FCallbackErrors: Word;
    FLastCallbackError: string;
    procedure RecordCallbackError(const Text: string);
    procedure RecordCallbackException(E: Exception);
  protected
    procedure ControlOperation(Operation: TControlOperation; var Value: Boolean); override;
    function NativeClassName: PChar; virtual;
    procedure WndProc(var Message: TMessage); virtual;
    function GetControlBounds: TRect; override;
    procedure SetControlBounds(const Value: TRect); override;
  public
    destructor Destroy; override;
    procedure DefaultHandler(var Message); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); virtual;
    procedure DestroyHandle;
    function Perform(Id, WParam: Word; LParam: LongInt): LongInt;
    procedure ClearCallbackError;
    property Handle: HWND read FHandle;
    property CallbackErrors: Word read FCallbackErrors;
    property LastCallbackError: string read FLastCallbackError;
  end;
procedure RegisterNativeSuperclass(SourceName, PrivateName: PChar; var Original: WNDPROC);
procedure EnsureNativeWindowClass(Name: PChar);
{ The managed object behind a window of this task, or nil for foreign windows. }
function FindNativeWindow(Window: HWND): TNativeWindow;
implementation
uses WinProcs, native_cursors;
const WindowClassName = 'CalmiraNativeWindow';
var ClassRegistered: Boolean;
  { Child control IDs; WM_MEASUREITEM names a control only by its ID. }
  NextChildId: Word;

function NativeWindowProc(Window: HWND; Id: UINT; WP: WPARAM;
  LP: LPARAM): LRESULT; export;
var Instance: TNativeWindow; Message: TMessage; ObjectOffset: SmallInt;
begin
  { Preserve the original extra bytes of a private superclassed USER control. }
  ObjectOffset := GetClassWord(Window, GCW_CBWNDEXTRA) - SizeOf(Pointer);
  Instance := TNativeWindow(Pointer(GetWindowLong(Window, ObjectOffset)));
  if Id = WM_NCCREATE then
  begin
    Instance := TNativeWindow(PCREATESTRUCT(Pointer(LP))^.lpCreateParams);
    if Instance = nil then begin Result := 0; Exit; end;
    SetWindowLong(Window, ObjectOffset, LongInt(Pointer(Instance)));
    Instance.FHandle := Window;
  end;
  if Instance = nil then
  begin Result := DefWindowProc(Window, Id, WP, LP); Exit; end;
  Message.Msg := Id; Message.WParam := WP; Message.LParam := LP; Message.Result := 0;
  try
    { No Pascal exception may unwind through USER's native callback frames. }
    try
      if Instance.FDestroying then Instance.DefaultHandler(Message)
      else if (Id = WM_SETCURSOR) and ApplyNativeCursor(Window, HWND(WP), SmallInt(Word(LP))) then
        Message.Result := 1
      else Instance.WndProc(Message);
    except
      on E: Exception do
      begin Instance.RecordCallbackException(E); Message.Result := 0;
        if Id = WM_CREATE then Message.Result := -1; end;
      else
      begin Instance.RecordCallbackError('Non-Exception callback failure'); Message.Result := 0;
        if Id = WM_CREATE then Message.Result := -1; end;
    end;
    Result := Message.Result;
  finally
    if Id = WM_NCDESTROY then
    begin
      SetWindowLong(Window, ObjectOffset, 0);
      Instance.FHandle := 0;
    end;
  end;
end;

procedure RegisterNativeSuperclass(SourceName, PrivateName: PChar; var Original: WNDPROC);
var Info: TWndClass; Previous: WNDPROC;
begin
  if Assigned(Original) then Exit;
  FillChar(Info, SizeOf(Info), 0);
  if not GetClassInfo(0, SourceName, Info) then
    raise ENativeWindowError.Create('Cannot find USER control class');
  Previous := Info.lpfnWndProc;
  if (Info.cbWndExtra < 0) or (Info.cbWndExtra > 32763) then
    raise ENativeWindowError.Create('Invalid superclass extra bytes');
  Inc(Info.cbWndExtra, SizeOf(Pointer));
  Info.style := Info.style and not CS_GLOBALCLASS;
  Info.hInstance := HInstance; Info.lpfnWndProc := @NativeWindowProc;
  Info.lpszClassName := PrivateName;
  if not RegisterClass(Info) then raise ENativeWindowError.Create('Cannot register private USER superclass');
  Original := Previous;
end;

procedure EnsureWindowClass;
begin
  if ClassRegistered then Exit;
  EnsureNativeWindowClass(WindowClassName); ClassRegistered := True;
end;
procedure EnsureNativeWindowClass(Name: PChar);
var Info: TWndClass; Actual: Pointer;
begin
  if (Name = nil) or (Name^ = #0) then
    raise ENativeWindowError.Create('Invalid native window class');
  FillChar(Info, SizeOf(Info), 0);
  if GetClassInfo(HInstance, Name, Info) then
  begin
    Move(Info.lpfnWndProc, Actual, SizeOf(Actual));
    if (Actual <> Pointer(@NativeWindowProc)) or
      (Info.cbWndExtra <> SizeOf(Pointer)) or (Info.hInstance <> HInstance) then
      raise ENativeWindowError.Create('Native window class collision');
    Exit;
  end;
  FillChar(Info, SizeOf(Info), 0);
  Info.hInstance := HInstance; Info.lpfnWndProc := @NativeWindowProc;
  Info.style := CS_DBLCLKS;
  Info.hCursor := LoadCursor(0, IDC_ARROW);
  Info.cbWndExtra := SizeOf(Pointer); Info.lpszClassName := Name;
  if not RegisterClass(Info) then raise ENativeWindowError.Create('Cannot register native window class');
end;
function TNativeWindow.GetControlBounds: TRect;
var Corner: TPoint; Parent: HWND;
begin
  if FHandle = 0 then raise ENativeWindowError.Create('Missing native window');
  GetWindowRect(FHandle, Result);
  Parent := GetParent(FHandle);
  if Parent = 0 then Exit;
  Corner.X := Result.Left; Corner.Y := Result.Top; WinProcs.ScreenToClient(Parent, Corner);
  OffsetRect(Result, Corner.X - Result.Left, Corner.Y - Result.Top);
end;
procedure TNativeWindow.SetControlBounds(const Value: TRect);
begin
  if FHandle = 0 then raise ENativeWindowError.Create('Missing native window');
  MoveWindow(FHandle, Value.Left, Value.Top, Value.Right - Value.Left, Value.Bottom - Value.Top, True);
end;
function FindNativeWindow(Window: HWND): TNativeWindow;
var Actual: Pointer; Proc: LongInt;
begin
  Result := nil;
  if (Window = 0) or not IsWindow(Window) then Exit;
  { Another instance shares the code segment, so also match the data instance. }
  if GetWindowWord(Window, GWW_HINSTANCE) <> HInstance then Exit;
  Proc := GetClassLong(Window, GCL_WNDPROC);
  Move(Proc, Actual, SizeOf(Actual));
  if Actual <> Pointer(@NativeWindowProc) then Exit;
  Result := TNativeWindow(Pointer(GetWindowLong(Window,
    GetClassWord(Window, GCW_CBWNDEXTRA) - SizeOf(Pointer))));
end;
procedure TNativeWindow.RecordCallbackError(const Text: string);
begin
  FLastCallbackError := Text;
  if FCallbackErrors < High(Word) then Inc(FCallbackErrors);
end;
procedure TNativeWindow.RecordCallbackException(E: Exception);
begin
  { Convert the managed exception text only on failure, not in every native
    callback's stack frame. Nested EDIT notifications have a 4-KiB budget. }
  RecordCallbackError(E.Message);
end;
procedure TNativeWindow.ClearCallbackError;
begin FCallbackErrors := 0; FLastCallbackError := ''; end;
procedure TNativeWindow.ControlOperation(Operation: TControlOperation; var Value: Boolean);
var Order: HWND;
begin
  { Raw windows have no deferred visual model. Managed Controls override this. }
  if Handle = 0 then raise ENativeWindowError.Create('Missing native window');
  case Operation of
    coReadEnabled: Value := IsWindowEnabled(Handle);
    coWriteEnabled: EnableWindow(Handle, Value);
    coReadVisible: Value := DWORD(GetWindowLong(Handle, GWL_STYLE)) and WS_VISIBLE <> 0;
    coWriteVisible, coShow, coHide:
      begin
        if Operation = coShow then Value := True;
        if Operation = coHide then Value := False;
        if Value then ShowWindow(Handle, SW_SHOWNOACTIVATE) else ShowWindow(Handle, SW_HIDE);
      end;
    coFront, coBack:
      begin
        if Operation = coFront then Order := HWND_TOP else Order := HWND_BOTTOM;
        if not SetWindowPos(Handle, Order, 0, 0, 0, 0,
          SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE) then
          raise ENativeWindowError.Create('Cannot reorder control');
      end;
  end;
end;
procedure TNativeWindow.WndProc(var Message: TMessage);
begin Dispatch(Message); end;
function TNativeWindow.NativeClassName: PChar;
begin EnsureWindowClass; Result := WindowClassName; end;
procedure TNativeWindow.DefaultHandler(var Message);
begin
  with TMessage(Message) do Result := DefWindowProc(FHandle, Msg, WParam, LParam);
end;
procedure TNativeWindow.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
var Buffer: array[0..255] of Char; Created: HWND; ClassName: PChar; Id: Word;
begin
  if FCreating or FDestroying or (FHandle <> 0) then
    raise ENativeWindowError.Create('Window already exists or is changing');
  if (Width < 0) or (Height < 0) or (Pos(#0, Caption) <> 0) then
    raise ENativeWindowError.Create('Invalid native window dimensions or caption');
  if ((Parent <> 0) and not IsWindow(Parent)) or
    (((Style and WS_CHILD) <> 0) and (Parent = 0)) then
    raise ENativeWindowError.Create('Invalid native parent window');
  ClassName := NativeClassName;
  Id := 0;
  if Style and WS_CHILD <> 0 then
  begin
    { Above the dialog IDs IDOK..IDNO; unique among live siblings in practice. }
    if (NextChildId < $100) or (NextChildId >= $7FFF) then NextChildId := $100
    else Inc(NextChildId);
    Id := NextChildId;
  end;
  StrPCopy(Buffer, Caption); FCreating := True;
  try
    Created := CreateWindow(ClassName, Buffer, Style, X, Y, Width, Height,
      Parent, HMENU(Id), HInstance, Pointer(Self));
  finally FCreating := False; end;
  if Created = 0 then
  begin
    { USER need not send WM_NCDESTROY after a rejected WM_NCCREATE. }
    FHandle := 0;
    raise ENativeWindowError.Create('Cannot create native window');
  end;
end;
procedure TNativeWindow.DestroyHandle;
begin
  if FCreating then raise ENativeWindowError.Create('Cannot destroy window during creation');
  if FHandle <> 0 then
    if not DestroyWindow(FHandle) then raise ENativeWindowError.Create('Cannot destroy native window');
end;
function TNativeWindow.Perform(Id, WParam: Word; LParam: LongInt): LongInt;
begin
  if FHandle = 0 then raise ENativeWindowError.Create('Missing native window');
  Result := SendMessage(FHandle, Id, WParam, LParam);
end;
destructor TNativeWindow.Destroy;
begin
  FDestroying := True;
  DestroyHandle;
  inherited Destroy;
end;
end.
