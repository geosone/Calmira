program ControlViewTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls, native_form,
  native_modal, native_edit, native_window;
const DoneMessage = WM_USER + 280;
type
  TDialog = class(TNativeModalForm)
    procedure Done(var M: TMessage); message DoneMessage;
  end;
  TD = object
    Shows, Hides, Guards: Integer;
    FailExit, FailActivate, GuardActivate: Boolean;
    procedure Shown(Sender: TObject);
    procedure Hidden(Sender: TObject);
    procedure Exited(Sender: TObject);
    procedure Activated(Sender: TObject);
    procedure Painted(Sender: TObject);
    procedure DialogShown(Sender: TObject);
  end;
var A, B, Lazy: TNativeForm; Panel, First, Second, Deferred: TCustomControl;
  Edit: TEdit; Dialog: TDialog; Driver: TD; Failed: Boolean;
  Before, TabA, TabB: Integer; FocusBefore: HWND; Area, Actual: TRect;
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
procedure TD.Shown(Sender: TObject);
begin Inc(Shows); end;
procedure TD.Hidden(Sender: TObject);
begin Inc(Hides); end;
procedure TD.Exited(Sender: TObject);
begin
  try Panel.Show; except on ENativeWindowError do Inc(Guards); end;
  if FailExit then raise Exception.Create('view exit failure');
end;
procedure TD.Activated(Sender: TObject);
begin
  if GuardActivate then
  begin
    try B.BringToFront; except on ENativeWindowError do Inc(Guards); end;
    try B.SendToBack; except on ENativeWindowError do Inc(Guards); end;
    try TCustomControl(B).Hide; except on ENativeWindowError do Inc(Guards); end;
  end;
  if FailActivate then raise Exception.Create('view activation failure');
end;
procedure TD.Painted(Sender: TObject);
begin
  try Panel.Show; except on ENativeWindowError do Inc(Guards); end;
  try Panel.Hide; except on ENativeWindowError do Inc(Guards); end;
  try Panel.BringToFront; except on ENativeWindowError do Inc(Guards); end;
  try Panel.SendToBack; except on ENativeWindowError do Inc(Guards); end;
  try Edit.Hide; except on ENativeWindowError do Inc(Guards); end;
end;
procedure TD.DialogShown(Sender: TObject);
begin PostMessage(Dialog.Handle, DoneMessage, 0, 0); end;
procedure TDialog.Done(var M: TMessage);
begin
  Check(not IsWindowEnabled(A.Handle), 'modal owner disabled before generic hide');
  TControl(Self).Hide;
end;
procedure Setup;
begin
  A := TNativeForm.Create(nil); A.SetBounds(10, 10, 260, 150);
  B := TNativeForm.Create(nil); B.SetBounds(300, 10, 200, 120);
  B.OnActivate := Driver.Activated;
  Lazy := TNativeForm.Create(nil); Lazy.OnShow := Driver.Shown; Lazy.OnHide := Driver.Hidden;
  Deferred := TCustomControl.Create(nil); Deferred.Hide; Deferred.SendToBack; Deferred.BringToFront;
  Check((Deferred.Handle = 0) and not Deferred.Visible, 'handleless control view actions do not allocate HWND');
  Deferred.Show; Check(Deferred.Visible and (Deferred.Handle = 0), 'handleless Show changes only deferred visibility');
  Lazy.BringToFront; Lazy.SendToBack;
  Check((Lazy.Handle = 0) and not Lazy.Visible, 'handleless form z order does not create or expose window');
  TCustomControl(Lazy).Show; TCustomControl(Lazy).Hide;
  Check((Lazy.Handle <> 0) and not Lazy.Visible and (Driver.Shows = 1) and (Driver.Hides = 1),
    'base control Show Hide preserve form construction and lifecycle events');
  Before := Driver.Shows; Lazy.BringToFront; Lazy.SendToBack;
  Check(not Lazy.Visible and (Driver.Shows = Before), 'hidden form z order never shows it');
  Panel := TCustomControl.Create(A); Panel.Parent := A; Panel.SetBounds(5, 5, 180, 60);
  Edit := TEdit.Create(A); Edit.Parent := Panel; Edit.SetBounds(4, 4, 120, 20); Edit.OnExit := Driver.Exited;
  First := TCustomControl.Create(A); First.Parent := A; First.SetBounds(20, 90, 80, 30);
  Second := TCustomControl.Create(A); Second.Parent := A; Second.SetBounds(30, 95, 80, 30);
  A.Show; B.Show; A.BringToFront; Edit.SetFocus;
end;
procedure ChildCases;
begin
  FocusBefore := GetFocus; Area := First.BoundsRect; TabA := First.TabOrder; TabB := Second.TabOrder;
  First.BringToFront;
  Check((GetWindow(A.Handle, GW_CHILD) = First.Handle) and (GetFocus = FocusBefore),
    'child BringToFront changes native order without stealing focus');
  First.SendToBack;
  Check((GetWindow(First.Handle, GW_HWNDNEXT) = 0) and (GetFocus = FocusBefore),
    'child SendToBack preserves native focus');
  Actual := First.BoundsRect;
  Check(EqualRect(Area, Actual) and (First.TabOrder = TabA) and (Second.TabOrder = TabB),
    'z order leaves geometry and logical tab order unchanged');
  Edit.MouseCapture := True; Before := Driver.Guards; Panel.Hide;
  Check(not Panel.Visible and Edit.Visible and not IsWindowVisible(Edit.Handle) and
    (GetCapture <> Edit.Handle) and (GetFocus <> Edit.Handle) and (Driver.Guards = Before + 1),
    'parent Hide releases descendant input and rejects exit callback reentry');
  Panel.Show; A.BringToFront; Edit.SetFocus; Driver.FailExit := True; Panel.Hide; Driver.FailExit := False;
  Check((Edit.CallbackErrors = 1) and (Edit.LastCallbackError = 'view exit failure') and not Panel.Visible,
    'hide completes while native boundary contains exit event failure');
  Edit.ClearCallbackError; Panel.Show;
  Check(Panel.Visible and IsWindowVisible(Edit.Handle), 'show recovers and retains child visibility');
  Before := Driver.Guards; Panel.DrawNow(Driver.Painted);
  Check((Driver.Guards >= Before + 5) and (Panel.CallbackErrors = 0), 'drawing scope rejects own and descendant view mutations');
  Panel.Hide; Panel.Show;
end;
procedure FormCases;
begin
  A.BringToFront; Edit.SetFocus; FocusBefore := GetFocus; A.BringToFront;
  Check(A.Active and (GetFocus = FocusBefore), 'already active form raise preserves focused descendant');
  Before := Driver.Guards; Driver.GuardActivate := True; B.BringToFront; Driver.GuardActivate := False;
  Check(B.Active and (Driver.Guards = Before + 3) and (B.CallbackErrors = 0),
    'form raise activates natively and guards activation callback view reentry');
  FocusBefore := GetActiveWindow; B.SendToBack;
  Check(GetActiveWindow = FocusBefore, 'form SendToBack does not explicitly activate another window');
  A.BringToFront; Driver.FailActivate := True; B.BringToFront; Driver.FailActivate := False;
  Check(B.Active and (B.CallbackErrors = 1) and (B.LastCallbackError = 'view activation failure'),
    'form raise retains completed activation after callback error');
  B.ClearCallbackError; A.BringToFront; B.BringToFront;
  Check(B.Active and (B.CallbackErrors = 0), 'form raise releases guards after activation error');
  A.BringToFront; B.Enabled := False; B.BringToFront;
  Check(A.Active and not B.Active, 'disabled form cannot steal activation'); B.Enabled := True;
  B.WindowState := wsMinimized; B.BringToFront;
  Check(IsIconic(B.Handle) and (B.WindowState = wsMinimized), 'raise does not silently restore minimized state');
  B.WindowState := wsNormal; A.BringToFront;
  Dialog := TDialog.Create(nil); Dialog.SetBounds(40, 40, 180, 90); Dialog.OnShow := Driver.DialogShown;
  Check(Dialog.ShowModal(A.Handle) = mrCancel, 'base control Hide completes modal form');
  Check(IsWindowEnabled(A.Handle) and not Dialog.ModalRunning and not Dialog.Visible,
    'generic modal hide preserves owner and cleanup policy');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native control visibility and z order');
  try Setup; ChildCases; FormCases;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Dialog.Free; Deferred.Free; Lazy.Free; B.Free; A.Free;
  Check(StackGuardIntact, 'control view stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
