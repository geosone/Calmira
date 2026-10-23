program ScreenModalTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls, native_edit,
  native_application, native_form, native_modal, native_screen;
const ProbeMessage = WM_USER + 191;
type
  TDialog = class(TNativeModalForm)
  public procedure Probe(var M: TMessage); message ProbeMessage;
  end;
  TD = object
    Mode, Probes: Integer;
    procedure MainShown(Sender: TObject);
    procedure DialogShown(Sender: TObject);
  end;
var App: TNativeApplication; View: TNativeScreen; Main: TNativeForm;
  Dialog: TDialog; MainEdit, DialogEdit: TEdit; Driver: TD;
  Failed, Rejected: Boolean; Mode: Integer; Value: TModalResult;
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
procedure TDialog.Probe(var M: TMessage);
begin
  Inc(Driver.Probes);
  Check(not IsWindowEnabled(Main.Handle), 'modal owner disabled');
  if Driver.Mode = 2 then
    Check((View.ActiveForm = nil) and (View.ActiveControl = nil) and (View.FormCount = 1), 'unregistered modal does not impersonate owner')
  else
    Check((View.ActiveForm = Dialog) and (View.ActiveControl = DialogEdit) and
      (View.Forms[0] = Dialog), 'registered modal is active front with edit focus');
  if Driver.Mode = 4 then PostQuitMessage(-71)
  else PostMessage(Handle, WM_CLOSE, 0, 0);
end;
procedure TD.DialogShown(Sender: TObject);
begin
  if Mode = 3 then raise Exception.Create('modal startup failure');
  PostMessage(Dialog.Handle, ProbeMessage, 0, 0);
end;
procedure TD.MainShown(Sender: TObject);
begin
  SetActiveWindow(Main.Handle); MainEdit.SetFocus;
  Value := Dialog.ShowModal(Main.Handle);
  Check((View.ActiveForm = Main) and (View.ActiveControl = MainEdit) and IsWindowEnabled(Main.Handle),
    'modal exit restores actual owner and focus view');
  if Mode <> 4 then PostMessage(Main.Handle, WM_CLOSE, 0, 0);
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0); Driver.Mode := Mode;
  App := TNativeApplication.Create(nil); App.Initialize;
  View := TNativeScreen.Create(nil); View.Application := App;
  App.CreateForm(TNativeForm, Main); Main.SetBounds(10, 10, 200, 110);
  App.CreateForm(TDialog, Dialog); Dialog.SetBounds(40, 40, 170, 90);
  MainEdit := TEdit.Create(Main); MainEdit.Parent := Main; MainEdit.SetBounds(5, 5, 130, 20);
  DialogEdit := TEdit.Create(Dialog); DialogEdit.Parent := Dialog; DialogEdit.SetBounds(5, 5, 130, 20);
  Main.InitialControl := MainEdit; Dialog.InitialControl := DialogEdit;
  Main.OnShow := Driver.MainShown; Dialog.OnShow := Driver.DialogShown;
  if Mode = 2 then App.UnregisterForm(Dialog);
end;
procedure Cleanup;
begin
  View.Free; View := nil; App.Free; App := nil;
  Main := nil; Dialog := nil; MainEdit := nil; DialogEdit := nil;
end;
procedure Exercise;
begin
  for Mode := 1 to 4 do
  begin
    Setup;
    if Mode = 3 then
    begin
      Rejected := False;
      try App.Run; except on Exception do Rejected := True; end;
      Check(Rejected and not App.Running and not Dialog.ModalRunning and
        (View.ActiveForm = Main) and (View.ActiveControl = MainEdit), 'startup error restores screen state');
      Driver.Mode := 1; Main.Hide;
    end;
    if Mode = 4 then Check(App.Run = -71, 'modal signed quit reaches root')
    else Check(App.Run = 0, 'screen modal run');
    Check((Driver.Probes = 1) and (Value = mrCancel) and not Dialog.ModalRunning and
      (Dialog.CallbackErrors = 0) and (Main.CallbackErrors = 0), 'modal screen acceptance');
    Cleanup;
  end;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP modal screen view');
  try Exercise;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; Check(StackGuardIntact, 'modal screen stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
