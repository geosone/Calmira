program FormResizeTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Controls,
  native_window, native_form, native_modal, native_edit;
const ProbeMessage = WM_USER + 220;
type
  TProbeForm = class(TNativeForm)
  public
    Calls: Integer;
    procedure ForceResize;
  protected
    procedure Resize; override;
  end;
  TDialog = class(TNativeModalForm)
    procedure Probe(var M: TMessage); message ProbeMessage;
  end;
  TD = object
    Events, Guards, ModalEvents: Integer;
    Valid, FailResize, GuardResize, ShownAfterResize: Boolean;
    procedure Resized(Sender: TObject);
    procedure Shown(Sender: TObject);
    procedure DialogResized(Sender: TObject);
    procedure DialogShown(Sender: TObject);
  end;
var Form: TProbeForm; Panel: TCustomControl; Edit: TEdit;
  Dialog: TDialog; DialogEdit: TEdit; Driver: TD;
  Failed, Rejected: Boolean; I, Before, PoolGDI, PoolUSER: Integer;
  Area, BoundsBefore: TRect; Raw: HWND;
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
procedure TProbeForm.Resize;
begin Inc(Calls); inherited Resize; end;
procedure TProbeForm.ForceResize;
begin Resize; end;
procedure TD.Resized(Sender: TObject);
var NativeArea: TRect;
begin
  Inc(Events); WinProcs.GetClientRect(Form.Handle, NativeArea);
  Valid := Valid and (Sender = Form) and (Form.ClientWidth = NativeArea.Right) and
    (Form.ClientHeight = NativeArea.Bottom) and (Form.Width >= Form.ClientWidth) and
    (Form.Height >= Form.ClientHeight);
  Panel.SetBounds(4, 4, Form.ClientWidth - 8, Form.ClientHeight - 8);
  Edit.SetBounds(3, 3, Panel.ClientWidth - 6, 20);
  if GuardResize then
  begin
    try Form.Width := Form.Width + 1; except on ENativeWindowError do Inc(Guards); end;
    try Form.BoundsRect := Form.BoundsRect; except on ENativeWindowError do Inc(Guards); end;
    try TCustomControl(Form).SetBounds(1, 1, 100, 100); except on ENativeWindowError do Inc(Guards); end;
    try Form.Show; except on ENativeWindowError do Inc(Guards); end;
    try Form.Hide; except on ENativeWindowError do Inc(Guards); end;
    try Form.Close; except on ENativeWindowError do Inc(Guards); end;
  end;
  if FailResize then raise Exception.Create('resize failure');
end;
procedure TD.Shown(Sender: TObject);
begin ShownAfterResize := (Events > 0) and (Form.Calls = Events); end;
procedure TD.DialogResized(Sender: TObject);
begin
  Inc(ModalEvents);
  DialogEdit.SetBounds(5, 5, Dialog.ClientWidth - 10, 20);
end;
procedure TD.DialogShown(Sender: TObject);
begin PostMessage(Dialog.Handle, ProbeMessage, 0, 0); end;
procedure TDialog.Probe(var M: TMessage);
begin
  Check((Driver.ModalEvents > 0) and (DialogEdit.Width = ClientWidth - 10) and
    not IsWindowEnabled(Form.Handle), 'modal resize lays out child before probe');
  SetWindowPos(Handle, 0, 0, 0, 240, 120, SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
  Check(DialogEdit.Width = ClientWidth - 10, 'modal native resize updates child layout');
  ModalResult := mrOK;
end;
procedure Setup;
begin
  Driver.Valid := True; Form := TProbeForm.Create(nil); Form.SetBounds(10, 10, 280, 160);
  Panel := TCustomControl.Create(Form); Panel.Parent := Form;
  Edit := TEdit.Create(Form); Edit.Parent := Panel;
  Check((Form.Handle = 0) and (Form.ClientWidth = 280) and (Form.ClientHeight = 160),
    'lazy client metrics use model without allocating HWND');
  Form.OnResize := Driver.Resized; Form.OnShow := Driver.Shown;
  Form.Show; SetActiveWindow(Form.Handle); Form.ActiveControl := Edit;
  Check(Driver.Valid and Driver.ShownAfterResize and (Form.Calls = Driver.Events),
    'native client dimensions reach virtual Resize before OnShow');
  Check((Panel.Width = Form.ClientWidth - 8) and (Edit.Width = Panel.ClientWidth - 6),
    'resize handler arranges nested controls');
  WinProcs.GetClientRect(Form.Handle, Area);
  Check((Form.ClientWidth = Area.Right) and (Form.ClientHeight = Area.Bottom) and
    (Form.Width > Form.ClientWidth) and (Form.Height > Form.ClientHeight),
    'decorated form distinguishes outer and actual client dimensions');
end;
procedure NativeChanges;
begin
  Before := Driver.Events; Form.SetBounds(Form.Left, Form.Top, Form.Width, Form.Height);
  Form.Left := Form.Left + 5;
  SendMessage(Form.Handle, WM_SIZE, SIZE_RESTORED, LongInt(1) or (LongInt(2) shl 16));
  Check(Driver.Events = Before, 'same bounds move and forged size produce no resize event');
  Driver.GuardResize := True;
  Check(SetWindowPos(Form.Handle, 0, 0, 0, 300, 180,
    SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE), 'external native size accepted');
  Driver.GuardResize := False;
  Check((Driver.Events = Before + 1) and (Driver.Guards = 6) and Driver.Valid and
    (Form.CallbackErrors = 0), 'resize rejects own bounds and lifecycle reentry before mutation');
  Before := Driver.Events; Form.Width := 310;
  Check((Driver.Events = Before + 1) and (Panel.Width = Form.ClientWidth - 8),
    'property setter dispatches virtual bounds and native resize once');
  BoundsBefore := Form.BoundsRect; Rejected := False;
  try Form.Width := -1; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Form.Width = BoundsBefore.Right - BoundsBefore.Left) and
    (Driver.Events = Before + 1), 'invalid bounds preserve geometry and event count');
  Before := Driver.Events; Form.ForceResize;
  Check((Driver.Events = Before + 1) and (Form.Calls = Driver.Events),
    'explicit virtual Resize remains available for layout refresh');
end;
procedure ErrorsAndLifetime;
begin
  Driver.FailResize := True; Form.Width := 320; Driver.FailResize := False;
  Check((Form.CallbackErrors = 1) and (Form.LastCallbackError = 'resize failure') and
    (Form.Width = 320), 'native resize exception preserves completed geometry');
  Form.ClearCallbackError; Before := Driver.Events; Form.Width := 330;
  Check((Driver.Events = Before + 1) and (Form.CallbackErrors = 0),
    'resize exception releases bounds and event guards');
  Form.Hide; Before := Driver.Events; Form.Width := 340;
  Check(not Form.Visible and (Driver.Events = Before + 1), 'hidden native resize does not show form');
  Form.Show; Raw := Form.Handle; Before := Driver.Events; Form.DestroyHandle;
  Check(not IsWindow(Raw) and (Form.Handle = 0), 'native resize probe tears down HWND');
  Form.Show;
  Check((Driver.Events > Before) and Driver.Valid and (Panel.Handle <> 0) and
    (Edit.Handle <> 0), 'recreated HWND resets resize baseline and retains nested layout');
  { Show intentionally does not force activation. Establish the restoration
    precondition after recreating the native owner and its child HWNDs. }
  SetActiveWindow(Form.Handle); Form.ActiveControl := Edit;
  Check(Form.Active and Edit.Focused, 'modal resize starts with active owner and child focus');
  Dialog := TDialog.Create(nil); Dialog.SetBounds(50, 50, 220, 100);
  DialogEdit := TEdit.Create(Dialog); DialogEdit.Parent := Dialog;
  Dialog.OnResize := Driver.DialogResized; Dialog.OnShow := Driver.DialogShown;
  Check(Dialog.ShowModal(Form.Handle) = mrOK, 'modal resize exits normally');
  Check(Form.Active and (Form.ActiveControl = Edit) and (Dialog.CallbackErrors = 0),
    'modal resize restores owner activation');
  Dialog.Free; Dialog := nil; DialogEdit := nil;
  PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES); PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
  Before := Driver.Events;
  for I := 1 to 50 do begin Form.Width := 350; Form.Width := 340; end;
  Check((Driver.Events = Before + 100) and Driver.Valid and (Form.CallbackErrors = 0),
    'repeated resize notifies once per client change');
  Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2), 'resize cycles retain USER and GDI resources');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native form resize');
  try Setup; NativeChanges; ErrorsAndLifetime;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Dialog.Free; Form.Free;
  Check(StackGuardIntact, 'form resize stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
