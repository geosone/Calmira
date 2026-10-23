program ApplicationDialogTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls, native_form,
  native_application, native_loop, native_modal, native_edit, native_button;
const ProbeMessage = WM_USER + 161;
type
  TFrame = class(TNativeForm)
  public
    Calls: Integer;
    procedure Probe(var M: TMessage); message ProbeMessage;
  end;
  TD = object
    FirstClicks, SecondClicks, QuitSeen, ShownCount: Integer;
    Consume, AllowClose, ModalQuit, ModalFailure, OwnerDisabled: Boolean;
    ResultValue: TModalResult;
    procedure Clicked(Sender: TObject);
    procedure Query(Sender: TObject; var Allowed: Boolean);
    function Filter(var Message: TMsg): Boolean;
    procedure MainShown(Sender: TObject);
    procedure ModalShown(Sender: TObject);
  end;
var App: TNativeApplication; Main, Second, Third: TFrame;
  EditA, EditB: TEdit; ButtonA, ButtonB, Cancel: TButton;
  Dialog: TNativeModalForm; Driver: TD; Failed, Rejected: Boolean; I: Integer;
  Successor: TNativeMessageLoop;
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
procedure TFrame.Probe(var M: TMessage);
begin Inc(Calls); end;
procedure TD.Clicked(Sender: TObject);
begin
  if Sender = ButtonA then Inc(FirstClicks)
  else if Sender = ButtonB then
  begin Inc(SecondClicks); Third.Free; Third := nil; end;
end;
procedure TD.Query(Sender: TObject; var Allowed: Boolean);
begin Allowed := AllowClose; end;
function TD.Filter(var Message: TMsg): Boolean;
begin
  if Message.message = WM_QUIT then Inc(QuitSeen);
  Result := Consume and (Message.message = WM_KEYDOWN) and (Message.wParam = VK_RETURN);
end;
procedure TD.MainShown(Sender: TObject);
begin
  Inc(ShownCount); ResultValue := Dialog.ShowModal(Main.Handle);
  if not ModalQuit then PostMessage(Main.Handle, WM_CLOSE, 0, 0);
end;
procedure TD.ModalShown(Sender: TObject);
begin
  OwnerDisabled := not IsWindowEnabled(Main.Handle);
  if ModalFailure then raise Exception.Create('modal startup failure');
  if ModalQuit then
    PostQuitMessage(-37)
  else PostMessage(Cancel.Handle, WM_KEYDOWN, VK_ESCAPE, 1);
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0);
  App := TNativeApplication.Create(nil); App.Initialize;
  Main := TFrame.Create(nil); Main.SetBounds(10, 10, 190, 100); Main.Caption := 'Main';
  App.RegisterForm(Main, True);
end;
procedure Cleanup;
begin
  App.Free; App := nil; Main.Free; Main := nil;
  Second.Free; Second := nil; Third.Free; Third := nil; Dialog.Free; Dialog := nil;
  EditA := nil; EditB := nil; ButtonA := nil; ButtonB := nil; Cancel := nil;
end;
procedure Input;
begin
  Setup;
  Second := TFrame.Create(nil); Second.SetBounds(220, 10, 190, 100); Second.Caption := 'Second';
  Third := TFrame.Create(nil); Third.SetBounds(10, 140, 190, 100);
  App.RegisterForm(Second); App.RegisterForm(Third);
  EditA := TEdit.Create(Main); EditA.Parent := Main; EditA.SetBounds(5, 5, 140, 20);
  ButtonA := TButton.Create(Main); ButtonA.Parent := Main; ButtonA.SetBounds(5, 35, 80, 24);
  ButtonA.Caption := '&Alpha'; ButtonA.Default := True; ButtonA.TabOrder := 1; ButtonA.OnClick := Driver.Clicked;
  EditB := TEdit.Create(Second); EditB.Parent := Second; EditB.SetBounds(5, 5, 140, 20);
  ButtonB := TButton.Create(Second); ButtonB.Parent := Second; ButtonB.SetBounds(5, 35, 80, 24);
  ButtonB.Caption := '&Beta'; ButtonB.Default := True; ButtonB.TabOrder := 1; ButtonB.OnClick := Driver.Clicked;
  Main.InitialControl := EditA; Second.InitialControl := EditB;
  Main.Show; Second.Show; Third.Show; App.OnMessage := Driver.Filter;
  SetActiveWindow(Main.Handle); EditA.SetFocus;
  PostMessage(EditA.Handle, WM_KEYDOWN, VK_TAB, 1); App.ProcessMessages(500);
  Check(ButtonA.Focused, 'application Tab routing');
  PostMessage(ButtonA.Handle, WM_KEYDOWN, VK_RETURN, 1); App.ProcessMessages(500);
  Check((Driver.FirstClicks = 1) and (Driver.SecondClicks = 0), 'main default button');
  SetActiveWindow(Second.Handle); EditB.SetFocus;
  PostMessage(EditB.Handle, WM_KEYDOWN, VK_RETURN, 1); App.ProcessMessages(500);
  Check((Driver.FirstClicks = 1) and (Driver.SecondClicks = 1) and (Third = nil) and
    (App.FormCount = 2), 'secondary scoped default and registry mutation');
  SetActiveWindow(Main.Handle); EditA.SetFocus;
  PostMessage(EditA.Handle, WM_SYSCHAR, Ord('a'), $20000001); App.ProcessMessages(500);
  Check((Driver.FirstClicks = 2) and (Driver.SecondClicks = 1), 'application mnemonic routing');
  Driver.Consume := True;
  SetActiveWindow(Second.Handle); EditB.SetFocus;
  PostMessage(EditB.Handle, WM_KEYDOWN, VK_RETURN, 1); App.ProcessMessages(500);
  Check(Driver.SecondClicks = 1, 'client filter consumes before dialog routing');
  Main.Hide; Check(not App.QuitRequested, 'Hide is not task termination'); Main.Show;
  Main.OnCloseQuery := Driver.Query;
  Check(not App.CloseMainForm and Main.Visible and not App.QuitRequested, 'explicit main close veto');
  Driver.AllowClose := True;
  Check(App.CloseMainForm and App.QuitRequested and not Main.Visible, 'accepted main close requests quit');
  App.ProcessMessages(500);
  Check(App.Terminated and (App.ExitCode = 0) and (Driver.QuitSeen = 0), 'quit bypasses client filter');
  Check((Main.CallbackErrors = 0) and (Second.CallbackErrors = 0), 'input callbacks'); Cleanup;
end;
procedure SetupModal;
begin
  Setup; Dialog := TNativeModalForm.Create(nil); Dialog.SetBounds(40, 40, 180, 90);
  Cancel := TButton.Create(Dialog); Cancel.Parent := Dialog; Cancel.SetBounds(5, 5, 80, 24);
  Cancel.Caption := 'Cancel'; Cancel.Cancel := True; Cancel.ModalResult := mrCancel;
  Dialog.OnShow := Driver.ModalShown; Main.OnShow := Driver.MainShown;
end;
procedure Modal;
begin
  for I := 1 to 2 do
  begin
    SetupModal; Driver.ModalQuit := I = 2;
    if I = 2 then Check(App.Run = -37, 'startup modal signed quit reaches root')
    else Check(App.Run = 0, 'startup modal completion');
    Check(Driver.OwnerDisabled and IsWindowEnabled(Main.Handle) and not Dialog.Visible and
      not Dialog.ModalRunning and (Driver.ResultValue = mrCancel), 'modal owner and lifetime restored');
    Check(Dialog.TaskQuit = (I = 2), 'modal quit identity');
    if I = 2 then
    begin
      PostMessage(Main.Handle, ProbeMessage, 0, 0);
      Check(App.Run = -37, 'sticky startup modal exit code');
      Check(Driver.ShownCount = 1, 'terminated startup never repeats');
      Check(Main.Calls = 0, 'modal successor remains queued');
      Successor := TNativeMessageLoop.Create;
      try Successor.ProcessMessages(500); finally Successor.Free; Successor := nil; end;
      Check(Main.Calls = 1, 'modal quit preserves queued successor');
    end;
    Cleanup;
  end;
  SetupModal; Driver.ModalFailure := True; Rejected := False;
  try App.Run; except on Exception do Rejected := True; end;
  Check(Rejected and not App.Running and not App.Terminated and IsWindowEnabled(Main.Handle) and
    not Dialog.ModalRunning, 'modal startup failure restores application');
  Driver.ModalFailure := False; Main.Hide;
  Check(App.Run = 0, 'modal startup recovery'); Cleanup;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP application dialogs');
  try Input; Modal;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; Check(StackGuardIntact, 'stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
