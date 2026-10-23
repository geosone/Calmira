{ SPDX-License-Identifier: GPL-2.0-or-later
  Explicit Win16 task message loop, not Forms.Application. }
unit native_loop;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This message loop requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes;
type
  ENativeLoopError = class(Exception);
  TNativeMessageFilter = function(var Message: TMsg): Boolean of object;
  TNativeModalCondition = function: Boolean of object;
  TNativeIdleEvent = procedure(Sender: TObject; var Done: Boolean) of object;
  TNativeMessageLoop = class(TObject)
  private
    FTerminated: Boolean;
    FExitCode: SmallInt;
    FOnMessage: TNativeMessageFilter;
    FOnStart: TNotifyEvent;
    FPreviousActive: TNativeMessageLoop;
    FOnIdle: TNativeIdleEvent;
    FIdling: Boolean;
    FDraining: Boolean;
    procedure SetOnIdle(Value: TNativeIdleEvent);
    function IdleProvider: TNativeMessageLoop;
    function PrepareWait(var IdleCalled: Boolean): Boolean;
    procedure EnterPump;
    function ForwardFilter(var Message: TMsg): Boolean;
    function Deliver(var Message: TMsg): Boolean;
  public
    function Run: SmallInt;
    function ProcessMessages(Limit: Word): Word;
    procedure DrainMessages;
    function RunModal(ContinueWhile: TNativeModalCondition): SmallInt;
    property Terminated: Boolean read FTerminated;
    property ExitCode: SmallInt read FExitCode;
    { True consumes the message before translation. The receiver must outlive
      this assignment; clear it before freeing a form. WM_QUIT bypasses it. }
    property OnMessage: TNativeMessageFilter read FOnMessage write FOnMessage;
    { Run startup occurs inside the active root pump, before waiting for input.
      Modal dialogs opened by startup callbacks must inherit WM_QUIT. }
    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    property OnIdle: TNativeIdleEvent read FOnIdle write SetOnIdle;
    property Idling: Boolean read FIdling;
  end;
implementation
uses WinProcs, gdi_canvas;
var ActiveLoop: TNativeMessageLoop;

procedure TNativeMessageLoop.EnterPump;
begin
  { The USER queue belongs to the task, not to an object or HWND. }
  if ActiveLoop <> nil then
    raise ENativeLoopError.Create('Nested task pump');
  ActiveLoop := Self;
end;
procedure TNativeMessageLoop.SetOnIdle(Value: TNativeIdleEvent);
begin
  if FIdling then raise ENativeLoopError.Create('Invalid idle callback');
  FOnIdle := Value;
end;
function TNativeMessageLoop.IdleProvider: TNativeMessageLoop;
begin
  Result := Self;
  while (Result <> nil) and not Assigned(Result.FOnIdle) do Result := Result.FPreviousActive;
end;
function TNativeMessageLoop.PrepareWait(var IdleCalled: Boolean): Boolean;
var Provider: TNativeMessageLoop; Pending: TMsg; Done: Boolean;
begin
  Result := True; IdleCalled := False;
  { As Delphi does at idle, give back DCs borrowed for drawing outside paint
    (USER has only five common DCs). }
  if DeviceContextsInUse and not PeekMessage(Pending, 0, 0, 0, PM_NOREMOVE) then
    FreeDeviceContexts;
  Provider := IdleProvider;
  { Modal children inherit the nearest active parent's idle service. Do not
    recursively call a provider whose callback opened this modal child. }
  if Provider = nil then Exit;
  if Provider.FIdling then Exit;
  if PeekMessage(Pending, 0, 0, 0, PM_NOREMOVE) then Exit;
  { PeekMessage may dispatch sent callbacks. They may end a nested pump or
    rebind idle handlers, so do not retain the pre-query provider decision. }
  if FTerminated then Exit;
  Provider := IdleProvider;
  if Provider = nil then Exit;
  if Provider.FIdling then Exit;
  Done := True; Provider.FIdling := True; IdleCalled := True;
  try Provider.FOnIdle(Self, Done);
  finally Provider.FIdling := False; end;
  if not Done then
  begin
    { Done=False explicitly requests another work slice. Cooperate with other
      Win16 tasks and recheck the unfiltered queue before repeating. }
    WinProcs.Yield; Result := False;
  end;
end;
function TNativeMessageLoop.ForwardFilter(var Message: TMsg): Boolean;
begin
  Result := False;
  if Assigned(FOnMessage) then Result := FOnMessage(Message);
end;
function TNativeMessageLoop.Deliver(var Message: TMsg): Boolean;
var Previous: TNativeMessageLoop;
begin
  { USER may have dispatched sent callbacks while retrieving this item. }
  if FTerminated then begin Result := False; Exit; end;
  Result := Message.message <> WM_QUIT;
  if not Result then
  begin
    FTerminated := True;
    FExitCode := SmallInt(Message.wParam);
    { A modal child consumes quit once, then terminates its suspended ancestors.
      Never repost WM_QUIT or let an outer loop resume normal dispatch. }
    Previous := FPreviousActive;
    while Previous <> nil do
    begin
      Previous.FTerminated := True; Previous.FExitCode := FExitCode;
      Previous := Previous.FPreviousActive;
    end;
    if FPreviousActive <> nil then PostAppMessage(GetCurrentTask, WM_NULL, 0, 0);
    Exit;
  end;
  if Assigned(FOnMessage) then
    if FOnMessage(Message) then Exit;
  { A filter can open a modal child that consumes quit for this suspended
    frame. Never dispatch the original message after that child returns. }
  if FTerminated then begin Result := False; Exit; end;
  TranslateMessage(Message);
  DispatchMessage(Message);
end;
function TNativeMessageLoop.RunModal(ContinueWhile: TNativeModalCondition): SmallInt;
var Message: TMsg; Previous: TNativeMessageLoop; IdleCalled: Boolean;
begin
  if not Assigned(ContinueWhile) then raise ENativeLoopError.Create('Invalid modal pump');
  Previous := ActiveLoop;
  while Previous <> nil do
  begin
    if Previous = Self then raise ENativeLoopError.Create('Invalid modal pump');
    if Previous.FTerminated then
    begin FTerminated := True; FExitCode := Previous.FExitCode; end;
    Previous := Previous.FPreviousActive;
  end;
  FPreviousActive := ActiveLoop; ActiveLoop := Self;
  try
    while not FTerminated do
    begin
      if not ContinueWhile then Break;
      if FTerminated then Break;
      if not PrepareWait(IdleCalled) then Continue;
      if FTerminated then Break;
      { An idle callback may complete the modal condition without posting input. }
      if IdleCalled then
      begin
        if not ContinueWhile then Break;
        if FTerminated then Break;
      end;
      if not GetMessage(Message, 0, 0, 0) then
        if Message.message <> WM_QUIT then
          raise ENativeLoopError.Create('GetMessage stopped without WM_QUIT');
      Deliver(Message);
    end;
    Result := FExitCode;
  finally ActiveLoop := FPreviousActive; FPreviousActive := nil; end;
end;
function TNativeMessageLoop.Run: SmallInt;
var Message: TMsg; IdleCalled: Boolean;
begin
  EnterPump;
  try
    if not FTerminated and Assigned(FOnStart) then FOnStart(Self);
    while not FTerminated do
    begin
      if not PrepareWait(IdleCalled) then Continue;
      if FTerminated then Break;
      { Unfiltered task queue, including WM_QUIT and timer callbacks.
        Done=True/default returns to GetMessage's blocking USER wait. }
      if not GetMessage(Message, 0, 0, 0) then
      begin
        if Message.message <> WM_QUIT then
          raise ENativeLoopError.Create('GetMessage stopped without WM_QUIT');
      end;
      Deliver(Message);
    end;
    Result := FExitCode;
  finally ActiveLoop := nil; end;
end;
procedure TNativeMessageLoop.DrainMessages;
var Child, Current: TNativeMessageLoop; Message: TMsg;
begin
  Current := ActiveLoop;
  while Current <> nil do
  begin
    if Current.FDraining or Current.FIdling then
      raise ENativeLoopError.Create('Nested task pump');
    if Current.FTerminated and not FTerminated then
    begin FTerminated := True; FExitCode := Current.FExitCode; end;
    Current := Current.FPreviousActive;
  end;
  if FTerminated then Exit;
  Child := TNativeMessageLoop.Create;
  { Preserve the current modal/root filter, not an unrelated caller's filter.
    A separate frame lets Deliver propagate quit through suspended pumps. }
  if ActiveLoop <> nil then Child.FOnMessage := ActiveLoop.ForwardFilter
  else Child.FOnMessage := ForwardFilter;
  Child.FPreviousActive := ActiveLoop; Child.FDraining := True;
  ActiveLoop := Child;
  try
    while not Child.FTerminated do
    begin
      if not PeekMessage(Message, 0, 0, 0, PM_REMOVE) then Break;
      if not Child.Deliver(Message) then Break;
    end;
  finally
    if Child.FTerminated then
    begin FTerminated := True; FExitCode := Child.FExitCode; end;
    ActiveLoop := Child.FPreviousActive;
    Child.FPreviousActive := nil; Child.Free;
  end;
end;
function TNativeMessageLoop.ProcessMessages(Limit: Word): Word;
var Message: TMsg;
begin
  if Limit = 0 then raise ENativeLoopError.Create('Message limit must be positive');
  EnterPump;
  try
    Result := 0;
    while (not FTerminated) and (Result < Limit) do
    begin
      if not PeekMessage(Message, 0, 0, 0, PM_REMOVE) then Break;
      if not Deliver(Message) then Break;
      Inc(Result);
    end;
  finally ActiveLoop := nil; end;
end;
end.
