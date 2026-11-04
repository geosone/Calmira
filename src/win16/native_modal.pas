{ SPDX-License-Identifier: GPL-2.0-or-later
  Explicit owner-scoped modal forms; not Forms.Application or system modality. }
unit native_modal;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This modal form requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Controls, native_form, native_loop;
type
  TNativeModalForm = class(TNativeForm)
  private
    FModalResult: TModalResult;
    FModalRunning, FPreparing: Boolean;
    FTaskQuit: Boolean;
    FTaskExitCode: SmallInt;
    FModalLoop: TNativeMessageLoop;
    procedure SetModalResult(Value: TModalResult);
    function ContinueModal: Boolean;
  protected
    procedure DoHide; override;
    procedure WndProc(var M: TMessage); override;
  public
    function ShowModal(OwnerWindow: HWND = 0): TModalResult;
    procedure ApplyModalResult(Value: TModalResult); override;
    property ModalResult: TModalResult read FModalResult write SetModalResult;
    property ModalRunning: Boolean read FModalRunning;
    property TaskQuit: Boolean read FTaskQuit;
    property TaskExitCode: SmallInt read FTaskExitCode;
  end;
implementation
uses SysUtils, WinProcs, native_window;
var ActiveModal: TNativeModalForm;
procedure TNativeModalForm.SetModalResult(Value: TModalResult);
begin
  if Value < 0 then raise ENativeWindowError.Create('Invalid modal operation');
  FModalResult := Value;
  { Sent callbacks can complete a dialog while GetMessage is waiting. A task
    wakeup also works after HWND destruction. A full queue is already awake. }
  if FModalRunning then PostAppMessage(GetCurrentTask, WM_NULL, 0, 0);
end;
procedure TNativeModalForm.ApplyModalResult(Value: TModalResult);
begin ModalResult := Value; end;
procedure TNativeModalForm.DoHide;
begin
  if FModalRunning and (FModalResult = mrNone) then ModalResult := mrCancel;
  inherited DoHide;
end;
procedure TNativeModalForm.WndProc(var M: TMessage);
begin
  if (M.Msg = WM_DESTROY) and FModalRunning and (FModalResult = mrNone) then
    ModalResult := mrCancel;
  inherited WndProc(M);
end;
function TNativeModalForm.ContinueModal: Boolean;
begin
  Result := False;
  if (Handle = 0) or not Visible then Exit;
  if FModalResult <> mrNone then
  begin
    { Reuse the actual lifecycle guard, query, close action and events. A veto
      leaves the window visible; direct Hide/Close was already handled above. }
    Close;
    if (Handle <> 0) and Visible then FModalResult := mrNone;
  end;
  Result := (Handle <> 0) and Visible and (FModalResult = mrNone);
end;
function UsableWindow(Window: HWND): Boolean;
var Current: HWND;
begin
  Result := False;
  if (Window = 0) or not IsWindow(Window) then Exit;
  if (GetWindowTask(Window) <> GetCurrentTask) or not IsWindowVisible(Window) then Exit;
  Current := Window;
  while Current <> 0 do
  begin
    if not IsWindowEnabled(Current) then Exit;
    if DWORD(GetWindowLong(Current, GWL_STYLE)) and WS_CHILD = 0 then Break;
    Current := GetParent(Current);
  end;
  Result := True;
end;
{ As Delphi's DisableTaskWindows: every visible, enabled top-level window of
  this task is disabled while a modal form runs. }
function DisableTaskWindows(Modal: HWND): TList;
var Window: HWND;
begin
  Result := TList.Create;
  try
    Window := GetWindow(GetDesktopWindow, GW_CHILD);
    while Window <> 0 do
    begin
      if (Window <> Modal) and (GetWindowTask(Window) = GetCurrentTask) and
        IsWindowVisible(Window) and IsWindowEnabled(Window) then
        Result.Add(Pointer(LongInt(Window)));
      Window := GetWindow(Window, GW_HWNDNEXT);
    end;
  except Result.Free; raise; end;
end;
procedure DisableWindows(List: TList);
var I: Integer;
begin
  for I := 0 to List.Count - 1 do EnableWindow(HWND(LongInt(List[I])), False);
end;
procedure EnableTaskWindows(List: TList);
var I: Integer; Window: HWND;
begin
  if List = nil then Exit;
  for I := List.Count - 1 downto 0 do
  begin
    Window := HWND(LongInt(List[I]));
    if IsWindow(Window) then EnableWindow(Window, True);
  end;
  List.Free;
end;
function TNativeModalForm.ShowModal(OwnerWindow: HWND): TModalResult;
var PreviousModal: TNativeModalForm; OldFocus, OldActive, OldOwner, Candidate: HWND;
  DisabledOwner, KeepOwner: Boolean; TaskWindows: TList;
begin
  if FModalRunning or Visible or Painting or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Invalid modal operation');
  if ActiveModal <> nil then
    if ActiveModal.FPreparing then raise ENativeWindowError.Create('Invalid modal operation');
  { A form owned by the application window keeps its owner, as in Delphi. }
  { The owner, not GetParent: USER answers GetParent with the owner only for
    popups, and forms are overlapped as in the original. }
  KeepOwner := (OwnerWindow = 0) and (Handle <> 0) and (GetWindow(Handle, GW_OWNER) <> 0);
  if (OwnerWindow = 0) and not KeepOwner then
  begin
    Candidate := GetActiveWindow;
    if (Candidate <> 0) and (Candidate <> Handle) then
      if IsWindow(Candidate) and (GetWindowTask(Candidate) = GetCurrentTask) then
        OwnerWindow := Candidate;
  end;
  if OwnerWindow <> 0 then
  begin
    if not IsWindow(OwnerWindow) then raise ENativeWindowError.Create('Invalid modal operation');
    if (OwnerWindow = Handle) or (GetWindowTask(OwnerWindow) <> GetCurrentTask) or
      (DWORD(GetWindowLong(OwnerWindow, GWL_STYLE)) and WS_CHILD <> 0) then
      raise ENativeWindowError.Create('Invalid modal operation');
  end;
  OldFocus := GetFocus; OldActive := GetActiveWindow; OldOwner := 0; DisabledOwner := False;
  TaskWindows := nil;
  FModalLoop := TNativeMessageLoop.Create;
  PreviousModal := ActiveModal; ActiveModal := Self;
  FModalRunning := True; FPreparing := True; FModalResult := mrNone;
  FTaskQuit := False; FTaskExitCode := 0;
  try
    if Handle = 0 then
      CreateHandle(0, Caption, WS_OVERLAPPEDWINDOW or WS_CLIPCHILDREN or WS_CLIPSIBLINGS,
        Left, Top, Width, Height);
    OldOwner := GetWindow(Handle, GW_OWNER);
    if not KeepOwner then
    begin
      SetWindowWord(Handle, GWW_HWNDPARENT, OwnerWindow);
      if GetWindow(Handle, GW_OWNER) <> OwnerWindow then raise ENativeWindowError.Create('Modal owner link failed');
    end;
    TaskWindows := DisableTaskWindows(Handle);
    DisableWindows(TaskWindows);
    if OwnerWindow <> 0 then
      if IsWindowEnabled(OwnerWindow) then
      begin DisabledOwner := True; EnableWindow(OwnerWindow, False); end;
    Show;
    if (Handle <> 0) and Visible then
    begin
      SetActiveWindow(Handle);
      if not IsIconic(Handle) and (FindControl(GetFocus) = nil) then
        if not FocusNext(True) then SetFocus;
    end;
    FPreparing := False;
    FModalLoop.OnMessage := ProcessDialogMessage;
    FModalLoop.RunModal(ContinueModal);
    FTaskQuit := FModalLoop.Terminated; FTaskExitCode := FModalLoop.ExitCode;
    if FModalLoop.Terminated or (FModalResult = mrNone) then FModalResult := mrCancel;
    Result := FModalResult;
  finally
    FPreparing := True; FModalLoop.OnMessage := nil;
    try
      if (Handle <> 0) and Visible then Hide else Visible := False;
    finally
      if Handle <> 0 then
      begin
        if (OldOwner <> 0) and not IsWindow(OldOwner) then OldOwner := 0;
        SetWindowWord(Handle, GWW_HWNDPARENT, OldOwner);
      end;
      if DisabledOwner and IsWindow(OwnerWindow) then EnableWindow(OwnerWindow, True);
      EnableTaskWindows(TaskWindows);
      try
        FModalLoop.Free; FModalLoop := nil;
        if UsableWindow(OldActive) then SetActiveWindow(OldActive);
        if UsableWindow(OldFocus) then WinProcs.SetFocus(OldFocus);
      finally
        { Focus/activation callbacks are still cleanup, not a fresh modal entry. }
        ActiveModal := PreviousModal; FModalRunning := False; FPreparing := False;
      end;
    end;
  end;
end;
end.
