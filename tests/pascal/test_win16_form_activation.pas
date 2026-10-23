program FormActivationTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Controls,
  native_window, native_form, native_modal, native_edit;
const ProbeMessage = WM_USER + 219;
type
  TDialog = class(TNativeModalForm)
    procedure Probe(var M: TMessage); message ProbeMessage;
  end;
  TD = object
    Activations, Deactivations, Guards, FocusGuards: Integer;
    GuardEvents, Redirect, RaiseActivate, RaiseDeactivate, GuardFocus: Boolean;
    procedure Activated(Sender: TObject);
    procedure Deactivated(Sender: TObject);
    procedure Entered(Sender: TObject);
    procedure DialogShown(Sender: TObject);
  end;
var A, B: TNativeForm; Dialog: TDialog; LeftEdit, RightEdit, DialogEdit: TEdit;
  Driver: TD; Failed, Rejected: Boolean; I, Before, PoolGDI, PoolUSER: Integer;
  Raw: HWND;
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
procedure TD.Activated(Sender: TObject);
var Form: TNativeForm;
begin
  Inc(Activations); Form := TNativeForm(Sender);
  if GuardEvents then
  begin
    try Form.Show; except on ENativeWindowError do Inc(Guards); end;
    try Form.Hide; except on ENativeWindowError do Inc(Guards); end;
    try Form.Close; except on ENativeWindowError do Inc(Guards); end;
  end;
  if RaiseActivate then raise Exception.Create('activation failure');
  if Redirect and (Form = A) then
  begin Redirect := False; SetActiveWindow(B.Handle); Exit; end;
  if Form = B then B.ActiveControl := RightEdit;
end;
procedure TD.Deactivated(Sender: TObject);
begin
  Inc(Deactivations);
  if RaiseDeactivate then raise Exception.Create('deactivation failure');
end;
procedure TD.Entered(Sender: TObject);
begin
  if GuardFocus then
    try B.ActiveControl := RightEdit; except on ENativeWindowError do Inc(FocusGuards); end;
end;
procedure TD.DialogShown(Sender: TObject);
begin PostMessage(Dialog.Handle, ProbeMessage, 0, 0); end;
procedure TDialog.Probe(var M: TMessage);
begin
  Check(Active and (ActiveControl = DialogEdit) and not A.Active and
    not IsWindowEnabled(A.Handle), 'modal activation and live child focus');
  ModalResult := mrOK;
end;
procedure Setup;
begin
  A := TNativeForm.Create(nil); B := TNativeForm.Create(nil);
  A.SetBounds(10, 10, 210, 130); B.SetBounds(250, 10, 210, 130);
  LeftEdit := TEdit.Create(A); LeftEdit.Parent := A; LeftEdit.SetBounds(5, 5, 140, 20);
  RightEdit := TEdit.Create(B); RightEdit.Parent := B; RightEdit.SetBounds(5, 5, 140, 20);
  Check(not A.Active and (A.ActiveControl = nil), 'lazy form has no native active state');
  Rejected := False;
  try A.ActiveControl := LeftEdit; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (A.Handle = 0) and (LeftEdit.Handle = 0), 'hidden focus assignment rejects without creating handles');
  A.InitialControl := LeftEdit; A.Show; B.Show;
  A.OnActivate := Driver.Activated; A.OnDeactivate := Driver.Deactivated;
  B.OnActivate := Driver.Activated; B.OnDeactivate := Driver.Deactivated;
  RightEdit.OnEnter := Driver.Entered;
end;
procedure Transitions;
begin
  SetActiveWindow(A.Handle); A.ActiveControl := LeftEdit;
  Check(A.Active and (A.ActiveControl = LeftEdit) and not B.Active and
    (B.ActiveControl = nil), 'actual top-level and focused child are distinct');
  Before := Driver.Activations; SetActiveWindow(A.Handle);
  Check(Driver.Activations = Before, 'already-active USER request emits no duplicate transition');
  Driver.GuardEvents := True; Before := Driver.Deactivations;
  SetActiveWindow(B.Handle); Driver.GuardEvents := False;
  Check(B.Active and (B.ActiveControl = RightEdit) and (GetFocus = RightEdit.Handle) and
    (Driver.Deactivations > Before), 'native transition notifies and activation handler focuses edit');
  Check((Driver.Guards = 3) and (B.CallbackErrors = 0), 'activation callbacks reject recursive form lifecycle');
  Rejected := False;
  try B.ActiveControl := LeftEdit; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (B.ActiveControl = RightEdit), 'foreign focus assignment preserves native focus');
  SetParent(RightEdit.Handle, A.Handle); B.SetFocus; Rejected := False;
  try B.ActiveControl := RightEdit; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (B.ActiveControl = nil), 'external native reparent cannot bypass model ancestry');
  SetParent(RightEdit.Handle, B.Handle); B.ActiveControl := RightEdit;
  Rejected := False;
  try B.ActiveControl := B; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'frame is not its own managed active child');
  B.ActiveControl := nil;
  Check((GetFocus = B.Handle) and (B.ActiveControl = nil), 'nil active child focuses frame');
  Driver.GuardFocus := True; B.ActiveControl := RightEdit; Driver.GuardFocus := False;
  Check((Driver.FocusGuards = 1) and (RightEdit.CallbackErrors = 0) and
    (B.ActiveControl = RightEdit), 'focus callback cannot recursively assign active control');
  RightEdit.Enabled := False; B.SetFocus; Rejected := False;
  try B.ActiveControl := RightEdit; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (GetFocus = B.Handle), 'disabled active child assignment rejected');
  RightEdit.Enabled := True; RightEdit.Visible := False; Rejected := False;
  try B.ActiveControl := RightEdit; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'hidden active child assignment rejected'); RightEdit.Visible := True;
  B.ActiveControl := RightEdit; RightEdit.Parent := A;
  Check(B.ActiveControl = nil, 'reparented focused child leaves no stale active reference');
  RightEdit.Parent := B; B.ActiveControl := RightEdit;
end;
procedure FailuresAndNesting;
begin
  SetActiveWindow(A.Handle); Driver.RaiseActivate := True; SetActiveWindow(B.Handle);
  Driver.RaiseActivate := False;
  Check(B.Active and (B.CallbackErrors = 1) and (B.LastCallbackError = 'activation failure'),
    'activation exception stays inside USER boundary');
  B.Hide; B.Show; SetActiveWindow(B.Handle); B.ActiveControl := RightEdit;
  Check(B.Active and (B.ActiveControl = RightEdit), 'activation failure releases lifecycle and focus guards');
  B.ClearCallbackError; Driver.RaiseDeactivate := True; SetActiveWindow(A.Handle);
  Driver.RaiseDeactivate := False;
  Check((B.CallbackErrors = 1) and (B.LastCallbackError = 'deactivation failure') and A.Active,
    'deactivation exception preserves native transition'); B.ClearCallbackError;
  SetActiveWindow(B.Handle); Driver.Redirect := True; Before := Driver.Deactivations;
  SetActiveWindow(A.Handle);
  Check(B.Active and not A.Active and (Driver.Deactivations > Before) and
    (B.ActiveControl = RightEdit), 'nested cross-form activation follows live USER state');
  Check((A.CallbackErrors = 0) and (B.CallbackErrors = 0), 'nested activation leaves no callback errors');
end;
procedure ModalAndLifetime;
begin
  SetActiveWindow(A.Handle); A.ActiveControl := LeftEdit;
  Dialog := TDialog.Create(nil); Dialog.SetBounds(50, 50, 200, 100);
  DialogEdit := TEdit.Create(Dialog); DialogEdit.Parent := Dialog;
  DialogEdit.SetBounds(5, 5, 140, 20); Dialog.InitialControl := DialogEdit;
  Dialog.OnActivate := Driver.Activated; Dialog.OnDeactivate := Driver.Deactivated;
  Dialog.OnShow := Driver.DialogShown; Before := Driver.Activations;
  Check(Dialog.ShowModal(A.Handle) = mrOK, 'modal completes through native activation events');
  Check(A.Active and (A.ActiveControl = LeftEdit) and not Dialog.Active and
    (Dialog.ActiveControl = nil) and (Driver.Activations > Before), 'modal exit restores owner activation and child focus');
  Dialog.Free; Dialog := nil; DialogEdit := nil;
  SetActiveWindow(B.Handle); B.ActiveControl := RightEdit; RightEdit.Free; RightEdit := nil;
  B.OnActivate := nil;
  Check(B.ActiveControl = nil, 'freed focused child leaves no cached pointer');
  Raw := B.Handle; B.DestroyHandle;
  Check(not B.Active and (B.ActiveControl = nil) and not IsWindow(Raw), 'native teardown clears live activation state');
  B.Show; SetActiveWindow(B.Handle); Check(B.Active, 'recreated form can activate after teardown');
  PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES); PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
  for I := 1 to 50 do begin SetActiveWindow(A.Handle); SetActiveWindow(B.Handle); end;
  Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2), 'repeated activation retains USER and GDI resources');
  Check((A.CallbackErrors = 0) and (B.CallbackErrors = 0), 'activation teardown and recreation remain guarded');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native form activation');
  try Setup; Transitions; FailuresAndNesting; ModalAndLifetime;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Dialog.Free; B.Free; A.Free;
  Check(StackGuardIntact, 'form activation stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
