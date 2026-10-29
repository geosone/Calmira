program FormStateTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Controls,
  native_window, native_form, native_modal, native_edit;
const ProbeMessage = WM_USER + 221;
type
  TDialog = class(TNativeModalForm)
    procedure Probe(var M: TMessage); message ProbeMessage;
  end;
  TD = object
    Expected: TWindowState;
    Shows, Guards: Integer;
    ObserveState, Valid, FailResize: Boolean;
    procedure Shown(Sender: TObject);
    procedure Resized(Sender: TObject);
    procedure Closing(Sender: TObject; var Action: TNativeCloseAction);
    procedure DialogShown(Sender: TObject);
  end;
var Form: TNativeForm; Edit: TEdit; Dialog: TDialog; DialogEdit: TEdit;
  Driver: TD; Failed, Rejected: Boolean; Normal, Actual: TRect;
  Placement: TWindowPlacement; Queue: TMsg; Raw: HWND;
  I, Mode, PoolGDI, PoolUSER: Integer; BadState: Byte;
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
function SameRect(const A, B: TRect): Boolean;
begin Result := (A.Left = B.Left) and (A.Top = B.Top) and
  (A.Right = B.Right) and (A.Bottom = B.Bottom); end;
procedure TD.Shown(Sender: TObject);
begin Inc(Shows); Valid := Valid and (Form.WindowState = Expected); end;
procedure TD.Resized(Sender: TObject);
var NativeState: TWindowState;
begin
  NativeState := wsNormal;
  if IsIconic(Form.Handle) then NativeState := wsMinimized
  else if IsZoomed(Form.Handle) then NativeState := wsMaximized;
  Valid := Valid and (Form.WindowState = NativeState);
  if ObserveState then
  begin
    try Form.WindowState := wsNormal; except on ENativeWindowError do Inc(Guards); end;
    try Form.SetBounds(10, 10, 200, 100); except on ENativeWindowError do Inc(Guards); end;
    try Form.Hide; except on ENativeWindowError do Inc(Guards); end;
  end;
  if FailResize then raise Exception.Create('state resize failure');
end;
procedure TD.Closing(Sender: TObject; var Action: TNativeCloseAction);
begin Action := ncaDestroy; end;
procedure TD.DialogShown(Sender: TObject);
begin PostMessage(Dialog.Handle, ProbeMessage, 0, 0); end;
procedure TDialog.Probe(var M: TMessage);
begin
  Check(not IsWindowEnabled(Form.Handle), 'state modal disables native owner');
  if Mode = 1 then
    Check((WindowState = wsMaximized) and IsZoomed(Handle), 'modal starts with deferred maximized state')
  else Check((WindowState = wsMinimized) and IsIconic(Handle) and not DialogEdit.Focused and
    (ActiveControl = nil), 'minimized modal does not focus descendant');
  WindowState := wsNormal; SetActiveWindow(Handle); ActiveControl := DialogEdit;
  Check((WindowState = wsNormal) and DialogEdit.Focused, 'modal restore enables explicit child focus');
  ModalResult := mrOK;
end;
procedure Setup;
begin
  Driver.Valid := True; Form := TNativeForm.Create(nil);
  Form.SetBounds(30, 35, 240, 150); Edit := TEdit.Create(Form); Edit.Parent := Form;
  Edit.SetBounds(5, 5, 150, 20); Form.InitialControl := Edit;
  Form.OnShow := Driver.Shown; Form.OnResize := Driver.Resized;
  Form.WindowState := wsMinimized;
  Check((Form.Handle = 0) and (Edit.Handle = 0) and not Form.Visible and
    (Form.WindowState = wsMinimized), 'deferred minimized state allocates no HWND');
  Driver.Expected := wsMinimized; Form.Show;
  Check(IsIconic(Form.Handle) and not Edit.Focused and (Form.ActiveControl = nil) and Driver.Valid,
    'first Show applies minimized state before OnShow without initial child focus');
  Rejected := False;
  try Form.ActiveControl := Edit; except on ENativeWindowError do Rejected := True; end;
  FillChar(Queue, SizeOf(Queue), 0); Queue.hwnd := Edit.Handle;
  Queue.message := WM_KEYDOWN; Queue.wParam := VK_TAB;
  Check(Rejected and not Form.ProcessDialogMessage(Queue), 'minimized form rejects child focus and dialog-key routing');
  Form.WindowState := wsNormal; GetWindowRect(Form.Handle, Normal);
  Check((Form.WindowState = wsNormal) and (Normal.Right - Normal.Left = 240) and
    (Normal.Bottom - Normal.Top = 150), 'restore retains configured normal geometry');
end;
procedure NativeTransitions;
begin
  Driver.ObserveState := True; Form.WindowState := wsMaximized;
  Driver.ObserveState := False;
  Check(IsZoomed(Form.Handle) and (Form.WindowState = wsMaximized) and
    (Driver.Guards >= 3) and Driver.Valid and (Form.CallbackErrors = 0),
    'maximized resize sees real state and rejects state bounds lifecycle reentry');
  { As in Delphi, bounds of a maximized or minimized form are its restore placement. }
  Form.Width := 200;
  Check(IsZoomed(Form.Handle), 'nonnormal bounds assignment keeps the maximized state');
  Form.WindowState := wsMinimized; Actual := Form.BoundsRect;
  Check(IsIconic(Form.Handle) and (Actual.Right - Actual.Left = 200), 'icon reports the changed restore placement');
  Form.SetBounds(Normal.Left, Normal.Top, Normal.Right - Normal.Left, Normal.Bottom - Normal.Top);
  Actual := Form.BoundsRect;
  Check(IsIconic(Form.Handle) and IsWindowVisible(Form.Handle) and SameRect(Normal, Actual),
    'icon bounds set the restore placement without restoring');
  Form.WindowState := wsNormal; GetWindowRect(Form.Handle, Actual);
  Check(not IsZoomed(Form.Handle) and not IsIconic(Form.Handle) and SameRect(Normal, Actual),
    'explicit normal from maximized icon restores normal not maximized geometry');
  BadState := 99; Rejected := False;
  try Form.WindowState := TWindowState(BadState); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Form.WindowState = wsNormal), 'invalid state preserves actual window state');
  SendMessage(Form.Handle, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
  Check(Form.WindowState = wsMaximized, 'getter observes external native maximize');
  SendMessage(Form.Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
  Check(Form.WindowState = wsMinimized, 'getter observes external native minimize');
  SendMessage(Form.Handle, WM_SYSCOMMAND, SC_RESTORE, 0);
  Check(Form.WindowState = wsMaximized, 'native restore-to-maximized policy remains USER-owned');
  Form.WindowState := wsNormal;
  Driver.FailResize := True; Form.WindowState := wsMaximized; Driver.FailResize := False;
  Check((Form.WindowState = wsMaximized) and (Form.CallbackErrors > 0) and
    (Form.LastCallbackError = 'state resize failure'), 'state event exception preserves completed native transition');
  Form.ClearCallbackError; Form.WindowState := wsNormal; GetWindowRect(Form.Handle, Actual);
  Check(SameRect(Normal, Actual) and (Form.CallbackErrors = 0), 'state event exception releases transition guards');
end;
procedure HiddenAndTeardown;
begin
  Form.Hide; Form.WindowState := wsMaximized;
  Check(not IsWindowVisible(Form.Handle) and not Form.Visible and
    (Form.WindowState = wsMaximized), 'hidden state assignment is deferred without showing HWND');
  Driver.Expected := wsMaximized; Form.Show;
  Check(IsZoomed(Form.Handle) and Driver.Valid, 'hidden maximized request applied before OnShow');
  Form.Hide; Driver.Expected := wsMaximized; Form.Show;
  Check(Form.WindowState = wsMaximized, 'hide show preserves maximized state');
  Form.WindowState := wsMinimized; Raw := Form.Handle; Form.DestroyHandle;
  Actual := Form.BoundsRect;
  Check((Form.Handle = 0) and not IsWindow(Raw) and (Edit.Handle = 0) and
    (Form.WindowState = wsMinimized) and SameRect(Normal, Actual),
    'minimized teardown retains state and normal bounds rather than icon geometry');
  Form.SetBounds(45, 50, 260, 160); Driver.Expected := wsMinimized; Form.Show;
  Check(IsIconic(Form.Handle) and Driver.Valid, 'recreated HWND reapplies minimized state');
  Form.WindowState := wsNormal; GetWindowRect(Form.Handle, Actual);
  Check((Actual.Left = 45) and (Actual.Top = 50) and
    (Actual.Right - Actual.Left = 260) and (Actual.Bottom - Actual.Top = 160),
    'lazy bounds changes update next normal restore geometry');
  Normal := Actual; Form.WindowState := wsMaximized; Form.OnClose := Driver.Closing; Form.Close;
  Actual := Form.BoundsRect;
  Check((Form.Handle = 0) and not Form.Visible and (Form.WindowState = wsMaximized) and
    SameRect(Normal, Actual), 'destroy close snapshots maximized normal placement');
  Driver.Expected := wsMaximized; Form.Show; Form.WindowState := wsNormal; Form.OnClose := nil;
  GetWindowRect(Form.Handle, Actual);
  Check(SameRect(Normal, Actual) and (Form.CallbackErrors = 0), 'normal placement survives close destroy recreate');
end;
procedure ModalAndResources;
begin
  for Mode := 1 to 2 do
  begin
    SetActiveWindow(Form.Handle); Form.ActiveControl := Edit;
    Dialog := TDialog.Create(nil); Dialog.SetBounds(50, 50, 200, 120);
    DialogEdit := TEdit.Create(Dialog); DialogEdit.Parent := Dialog; Dialog.InitialControl := DialogEdit;
    Dialog.OnShow := Driver.DialogShown;
    if Mode = 1 then Dialog.WindowState := wsMaximized else Dialog.WindowState := wsMinimized;
    Check(Dialog.ShowModal(Form.Handle) = mrOK, 'state modal completes');
    Check(Form.Active and Edit.Focused and IsWindowEnabled(Form.Handle) and
      (Dialog.CallbackErrors = 0), 'state modal restores owner focus and enable state');
    Dialog.Free; Dialog := nil; DialogEdit := nil;
  end;
  FillChar(Placement, SizeOf(Placement), 0); Placement.length := SizeOf(Placement);
  Check(GetWindowPlacement(Form.Handle, @Placement) and SameRect(Placement.rcNormalPosition, Normal),
    'native placement agrees with retained normal bounds');
  PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES); PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
  for I := 1 to 30 do
  begin Form.WindowState := wsMaximized; Form.WindowState := wsMinimized; Form.WindowState := wsNormal; end;
  GetWindowRect(Form.Handle, Actual);
  Check(SameRect(Normal, Actual) and Driver.Valid and (Form.CallbackErrors = 0),
    'repeated state transitions preserve native normal placement and callback guards');
  Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2), 'state cycles retain USER and GDI resources');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native form state');
  try Setup; NativeTransitions; HiddenAndTeardown; ModalAndResources;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Dialog.Free; Form.Free;
  Check(StackGuardIntact, 'form state stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
