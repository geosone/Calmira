{ SPDX-License-Identifier: GPL-2.0-or-later
  Hidden task-window transport, not a complete Forms application service.
  Hook receivers must outlive their registration; never free the window or its
  application from a callback. No exception may escape the native USER boundary. }
unit native_application_window;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This task window requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Messages, native_window;
type
  TNativeWindowHook = function(var Message: TMessage): Boolean of object;
  TNativeActivationEvent = procedure(Sender: TObject; Activating: Boolean) of object;
  TNativeApplicationWindow = class(TNativeWindow)
  private
    FHooks: TList;
    FTitle: AnsiString;
    FDispatchDepth: Word;
    FOnClose: TNotifyEvent;
    FOnActivation: TNativeActivationEvent;
    procedure SetOnActivation(Value: TNativeActivationEvent);
    function GetTitle: string;
    procedure SetTitle(const Value: string);
    function GetHookCount: Integer;
    function GetDispatching: Boolean;
    procedure CheckMutable;
  protected
    function NativeClassName: PChar; override;
    procedure WndProc(var Message: TMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EnsureHandle;
    procedure HookMainWindow(Hook: TNativeWindowHook);
    procedure UnhookMainWindow(Hook: TNativeWindowHook);
    property Title: string read GetTitle write SetTitle;
    property HookCount: Integer read GetHookCount;
    property Dispatching: Boolean read GetDispatching;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnActivation: TNativeActivationEvent read FOnActivation write SetOnActivation;
  end;
implementation
uses WinProcs;
type PWindowHook = ^TNativeWindowHook;
const ApplicationClassName = 'TApplication';
  { Posted to itself: hand the focus on to a form, as Delphi's CM_ENTER. }
  WM_ACTIVATEFORM = WM_USER + $7000;
function SameHook(A, B: TNativeWindowHook): Boolean;
begin
  Result := (TMethod(A).Code = TMethod(B).Code) and (TMethod(A).Data = TMethod(B).Data);
end;
constructor TNativeApplicationWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); FTitle := 'Calmira'; FHooks := TList.Create;
end;
function TNativeApplicationWindow.NativeClassName: PChar;
begin EnsureNativeWindowClass(ApplicationClassName); Result := ApplicationClassName; end;
procedure TNativeApplicationWindow.CheckMutable;
begin
  if Dispatching then raise ENativeWindowError.Create('Application window is dispatching');
end;
function TNativeApplicationWindow.GetDispatching: Boolean;
begin Result := FDispatchDepth <> 0; end;
procedure TNativeApplicationWindow.SetOnActivation(Value: TNativeActivationEvent);
begin CheckMutable; FOnActivation := Value; end;
function TNativeApplicationWindow.GetHookCount: Integer;
begin Result := FHooks.Count; end;
function TNativeApplicationWindow.GetTitle: string;
begin Result := FTitle; end;
procedure TNativeApplicationWindow.SetTitle(const Value: string);
var Buffer: array[0..255] of Char;
begin
  CheckMutable;
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('Invalid application title');
  if Handle <> 0 then
  begin
    StrPCopy(Buffer, Value);
    SetWindowText(Handle, Buffer);
    GetWindowText(Handle, Buffer, SizeOf(Buffer));
    if StrPas(Buffer) <> Value then raise ENativeWindowError.Create('Cannot set application title');
  end;
  FTitle := Value;
end;
procedure TNativeApplicationWindow.EnsureHandle;
begin
  if Handle <> 0 then Exit;
  CheckMutable;
  { As Delphi 1's TApplication.CreateHandle: a zero-sized popup in the middle
    of the screen, measured in the original as style $940A0000 (no caption).
    It owns the forms and stands for the program in Windows' task list. }
  CreateHandle(0, Title, WS_POPUP or WS_CLIPSIBLINGS or WS_SYSMENU or WS_MINIMIZEBOX,
    GetSystemMetrics(SM_CXSCREEN) div 2, GetSystemMetrics(SM_CYSCREEN) div 2, 0, 0);
  ShowWindow(Handle, SW_SHOWNA);
end;
{ The topmost visible, enabled window this one owns, as Delphi's
  FindTopMostWindow. }
{ As Delphi's FindTopMostWindow: the topmost visible, enabled window of the
  task other than the application window that is not WS_EX_TOPMOST, else
  the first stay-on-top one. Calmira's off-screen splash (the main form) is
  topmost; after minimizing a program from the taskbar the original
  activates the Recycle Bin. Its icon title comes first: focusing it
  activates the icon, which focusing the iconic window itself does not. }
function TopTaskWindow(App: HWND): HWND;
const WS_EX_TOPMOST = $00000008;
var Window: HWND; Task: THandle;
begin
  Result := 0; Task := GetWindowTask(App);
  Window := GetWindow(GetDesktopWindow, GW_CHILD);
  while Window <> 0 do
  begin
    if (Window <> App) and (GetWindowTask(Window) = Task) and
      IsWindowVisible(Window) and IsWindowEnabled(Window) then
      if GetWindowLong(Window, GWL_EXSTYLE) and WS_EX_TOPMOST = 0 then
      begin Result := Window; Exit; end
      else if Result = 0 then Result := Window;
    Window := GetWindow(Window, GW_HWNDNEXT);
  end;
end;
procedure TNativeApplicationWindow.HookMainWindow(Hook: TNativeWindowHook);
var Index: Integer; Item: PWindowHook;
begin
  CheckMutable;
  if not Assigned(Hook) then raise ENativeWindowError.Create('Invalid application window hook');
  for Index := 0 to FHooks.Count - 1 do
    if SameHook(PWindowHook(FHooks[Index])^, Hook) then Exit;
  New(Item); Item^ := Hook;
  try FHooks.Add(Item); except Dispose(Item); raise; end;
end;
procedure TNativeApplicationWindow.UnhookMainWindow(Hook: TNativeWindowHook);
var Index: Integer; Item: PWindowHook;
begin
  CheckMutable;
  for Index := FHooks.Count - 1 downto 0 do
  begin
    Item := PWindowHook(FHooks[Index]);
    if SameHook(Item^, Hook) then begin FHooks.Delete(Index); Dispose(Item); Exit; end;
  end;
end;
procedure TNativeApplicationWindow.WndProc(var Message: TMessage);
var Index: Integer; Window: HWND;
begin
  { Native association/teardown belongs to the base and cannot be swallowed. }
  if (Message.Msg = WM_NCCREATE) or (Message.Msg = WM_CREATE) or
    (Message.Msg = WM_DESTROY) or (Message.Msg = WM_NCDESTROY) then
  begin inherited WndProc(Message); Exit; end;
  if FDispatchDepth = High(Word) then raise ENativeWindowError.Create('Application window recursion');
  Inc(FDispatchDepth);
  try
    { Newest hook first. Mutation is rejected until every nested send returns. }
    for Index := FHooks.Count - 1 downto 0 do
      if PWindowHook(FHooks[Index])^(Message) then Exit;
    { The zero-sized window itself cannot be used. As Delphi's application
      window (WM_SETFOCUS posting CM_ENTER), hand the focus on to the form on
      top, for instance when the active form was closed or hidden. }
    if Message.Msg = WM_SETFOCUS then PostMessage(Handle, WM_ACTIVATEFORM, 0, 0)
    else if Message.Msg = WM_ACTIVATEFORM then
    begin
      Message.Result := 0;
      if not IsIconic(Handle) and (GetFocus = Handle) then
      begin
        Window := TopTaskWindow(Handle);
        if Window <> 0 then WinProcs.SetFocus(Window);
      end;
      Exit;
    end;
    if Message.Msg = WM_CLOSE then
    begin
      Message.Result := 0;
      if Assigned(FOnClose) then FOnClose(Self);
    end
    else
    begin
      inherited WndProc(Message);
      if (Message.Msg = WM_ACTIVATEAPP) and Assigned(FOnActivation) then
        FOnActivation(Self, Message.WParam <> 0);
    end;
  finally Dec(FDispatchDepth); end;
end;
destructor TNativeApplicationWindow.Destroy;
var Item: PWindowHook;
begin
  FOnClose := nil; FOnActivation := nil;
  if FHooks <> nil then
    while FHooks.Count <> 0 do
    begin Item := PWindowHook(FHooks.Last); FHooks.Delete(FHooks.Count - 1); Dispose(Item); end;
  FHooks.Free; FHooks := nil;
  inherited Destroy;
end;
end.
