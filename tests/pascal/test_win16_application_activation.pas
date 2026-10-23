program ApplicationActivationTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages,
  native_application, native_application_window, native_window, native_form;
const ReadyMessage = WM_USER + 231; FinishedMessage = WM_USER + 232;
type TD = object
  Activations, Deactivations, FormActivations, Guards, NativeMessages: Integer;
  BeforeActivate, BeforeDeactivate, ReadyCalls, FinishedCalls: Integer;
  FailActivate, FailDeactivate, GuardEvent, ConsumeActivation, SenderValid: Boolean;
  procedure Activated(Sender: TObject);
  procedure Deactivated(Sender: TObject);
  procedure FormActivated(Sender: TObject);
  procedure Launch(Sender: TObject);
  procedure TestGuards;
  function Hook(var M: TMessage): Boolean;
end;
var App: TNativeApplication; Main, Peer: TNativeForm; Driver: TD;
  Failed, Rejected, ActiveBefore: Boolean; Before: Integer; Raw: HWND; Queue: TMsg;
  I, PoolGDI, PoolUSER: Integer;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TD.TestGuards;
begin
  try App.OnActivate := nil; except on ENativeApplicationError do Inc(Guards); end;
  try App.OnDeactivate := nil; except on ENativeApplicationError do Inc(Guards); end;
  try App.Title := 'Reentrant'; except on ENativeWindowError do Inc(Guards); end;
  try App.HookMainWindow(Hook); except on ENativeWindowError do Inc(Guards); end;
  try App.UnhookMainWindow(Hook); except on ENativeWindowError do Inc(Guards); end;
  try App.ProcessMessages(1); except on ENativeApplicationError do Inc(Guards); end;
  try App.Run; except on ENativeApplicationError do Inc(Guards); end;
end;
procedure TD.Activated(Sender: TObject);
begin
  Inc(Activations); SenderValid := SenderValid and (Sender = App);
  if GuardEvent then TestGuards;
  if FailActivate then raise Exception.Create('task activation failure');
end;
procedure TD.Deactivated(Sender: TObject);
begin
  Inc(Deactivations); SenderValid := SenderValid and (Sender = App);
  if FailDeactivate then raise Exception.Create('task deactivation failure');
end;
procedure TD.FormActivated(Sender: TObject);
begin Inc(FormActivations); end;
function TD.Hook(var M: TMessage): Boolean;
begin
  Result := False;
  if M.Msg = WM_ACTIVATEAPP then
  begin Inc(NativeMessages); Result := ConsumeActivation; if Result then M.Result := -77; end
  else if M.Msg = ReadyMessage then
  begin
    Inc(ReadyCalls); Result := True;
    Check(InSendMessage and (Word(M.LParam) <> App.TaskHandle) and
      (GetWindowTask(HWND(M.WParam)) = Word(M.LParam)), 'visible helper runs in independent Win16 task');
    Check((GetCurrentTask = App.TaskHandle) and not App.Active and
      (Deactivations > BeforeDeactivate), 'real task switch deactivates application not just form');
    SetActiveWindow(Main.Handle);
    Check(App.Active and (Activations > BeforeActivate), 'return to main task activates application');
    M.Result := -1234567;
  end
  else if M.Msg = FinishedMessage then
  begin
    Inc(FinishedCalls); Result := True; KillTimer(App.Handle, 778);
    Check((M.LParam = -1234567) and (ReadyCalls = 1), 'activation handshake preserves signed cross-task reply');
    PostMessage(Main.Handle, WM_CLOSE, 0, 0);
  end
  else if (M.Msg = WM_TIMER) and (M.WParam = 778) then
  begin
    KillTimer(App.Handle, 778); Result := True;
    Check(False, 'activation helper timeout'); App.Terminate(-99);
  end;
end;
procedure TD.Launch(Sender: TObject);
begin
  SetActiveWindow(Main.Handle); BeforeActivate := Activations; BeforeDeactivate := Deactivations;
  Check(SetTimer(App.Handle, 778, 10000, nil) <> 0, 'activation helper watchdog armed');
  Check(WinExec('C:\APPSEND.EXE', SW_SHOWNORMAL) > 31, 'visible activation helper launched');
end;
procedure Setup;
begin
  Driver.SenderValid := True; App := TNativeApplication.Create(nil); Rejected := False;
  try ActiveBefore := App.Active; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'active query requires initialized application'); Rejected := False;
  try App.OnActivate := Driver.Activated; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'activation registration requires initialization');
  App.Initialize; App.OnActivate := nil; App.OnDeactivate := nil; ActiveBefore := App.Active;
  Check(FindWindow('TApplication', 'Calmira') = 0, 'active read and clearing events do not allocate task HWND');
  App.CreateForm(TNativeForm, Main); Main.SetBounds(10, 10, 220, 120);
  App.CreateForm(TNativeForm, Peer); Peer.SetBounds(260, 10, 220, 120);
  Main.Show; Peer.Show; SetActiveWindow(Main.Handle);
  Main.OnActivate := Driver.FormActivated; Peer.OnActivate := Driver.FormActivated;
  App.OnActivate := Driver.Activated; App.OnDeactivate := Driver.Deactivated;
  Raw := App.Handle; App.HookMainWindow(Driver.Hook);
  Check(IsWindow(Raw) and not IsWindowVisible(Raw) and App.Active,
    'event registration creates independent hidden notification HWND');
  Before := Driver.Activations + Driver.Deactivations;
  SetActiveWindow(Peer.Handle); SetActiveWindow(Main.Handle);
  Check((Driver.Activations + Driver.Deactivations = Before) and
    (Driver.FormActivations >= 2) and App.Active, 'same-task form switches do not synthesize app activation');
end;
procedure MessageContracts;
begin
  { Explicit protocol probes are separate from the independent-task test below. }
  ActiveBefore := App.Active; Before := Driver.Activations;
  Driver.ConsumeActivation := True;
  Check(SendMessage(Raw, WM_ACTIVATEAPP, 1, 0) = -77, 'window hook can consume activation notification');
  Check((Driver.Activations = Before) and (App.Active = ActiveBefore), 'consumed notification leaves event and real state unchanged');
  Driver.ConsumeActivation := False; Driver.GuardEvent := True;
  SendMessage(Raw, WM_ACTIVATEAPP, 1, 0); Driver.GuardEvent := False;
  Check((Driver.Guards = 7) and (App.WindowCallbackErrors = 0), 'activation event guards registration hooks title and pumps');
  Driver.FailActivate := True; SendMessage(Raw, WM_ACTIVATEAPP, 1, 0); Driver.FailActivate := False;
  Check((App.WindowCallbackErrors = 1) and (App.LastWindowCallbackError = 'task activation failure'),
    'application activation exception stays inside USER boundary'); App.ClearWindowCallbackError;
  Driver.FailDeactivate := True; SendMessage(Raw, WM_ACTIVATEAPP, 0, 0); Driver.FailDeactivate := False;
  Check((App.WindowCallbackErrors = 1) and (App.LastWindowCallbackError = 'task deactivation failure'),
    'application deactivation exception stays inside USER boundary'); App.ClearWindowCallbackError;
  App.Title := 'Calmira'; App.OnActivate := Driver.Activated; App.OnDeactivate := Driver.Deactivated;
  Before := Driver.Deactivations; SendMessage(Raw, WM_ACTIVATEAPP, 0, 0);
  Check((Driver.Deactivations = Before + 1) and (App.Active = ActiveBefore) and Driver.SenderValid,
    'notifications do not overwrite native Active and sender is application');
  PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES); PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
  for I := 1 to 50 do begin App.OnActivate := nil; App.OnActivate := Driver.Activated; end;
  Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2), 'event rebinding retains USER and GDI resources');
  Check(DestroyWindow(Raw) and not IsWindow(Raw), 'activation transport native HWND destroyed');
  Raw := App.Handle; Before := Driver.Activations;
  SendMessage(Raw, WM_ACTIVATEAPP, 1, 0);
  Check(IsWindow(Raw) and not IsWindowVisible(Raw) and (Driver.Activations = Before + 1) and
    (App.WindowCallbackErrors = 0), 'notification HWND recreation retains activation callbacks and hooks');
end;
procedure IndependentTask;
begin
  Peer.Hide; Main.Hide; Main.OnShow := Driver.Launch;
  Check(App.Run = 0, 'independent activation task completes root run');
  Check((Driver.ReadyCalls = 1) and (Driver.FinishedCalls = 1) and Driver.SenderValid and
    (App.WindowCallbackErrors = 0), 'cross-task activation events complete without callback errors');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native application activation');
  try Setup; MessageContracts; IndependentTask;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  App.Free; App := nil;
  Check(not IsWindow(Raw), 'application teardown releases activation HWND');
  Check(not PeekMessage(Queue, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE), 'activation run leaves no quit residue');
  Check(StackGuardIntact, 'application activation stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
