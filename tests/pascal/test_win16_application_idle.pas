program ApplicationIdleTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls,
  native_application, native_form, native_modal, native_loop;
type
  TDialog = class(TNativeModalForm)
    procedure Timer(var M: TMessage); message WM_TIMER;
  end;
  TD = object
    Mode, Calls, Guards: Integer;
    Valid, Raised: Boolean;
    ResultValue: TModalResult;
    procedure Idle(Sender: TObject; var Done: Boolean);
    procedure MainShown(Sender: TObject);
    procedure DialogShown(Sender: TObject);
  end;
var App: TNativeApplication; Main: TNativeForm; Dialog: TDialog;
  Driver: TD; Failed, Rejected: Boolean; I: Integer; Queue: TMsg;
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
procedure TD.Idle(Sender: TObject; var Done: Boolean);
begin
  Inc(Calls); Valid := Valid and (Sender = App) and Done and App.Running;
  case Mode of
    1: begin
      if Calls = 1 then
      begin
        try App.OnIdle := nil; except on ENativeApplicationError do Inc(Guards); end;
        try App.ProcessMessages(1); except on ENativeApplicationError do Inc(Guards); end;
        try App.Run; except on ENativeApplicationError do Inc(Guards); end;
      end;
      Done := False; if Calls = 3 then App.Terminate(-72);
    end;
    2: raise Exception.Create('app idle failure');
    3: App.Terminate(-73);
    4: begin
      Valid := Valid and Dialog.ModalRunning and not IsWindowEnabled(Main.Handle);
      Dialog.ModalResult := mrOK;
    end;
    5: begin
      if Calls > 1 then begin Valid := False; Dialog.ModalResult := mrCancel; Exit; end;
      ResultValue := Dialog.ShowModal(Main.Handle);
      Valid := Valid and (ResultValue = mrOK) and IsWindowEnabled(Main.Handle);
      App.Terminate(-74);
    end;
    6: begin
      Valid := Valid and Dialog.ModalRunning;
      App.Terminate(-75);
    end;
    7: raise Exception.Create('modal idle failure');
  end;
end;
procedure TDialog.Timer(var M: TMessage);
begin KillTimer(Handle, M.WParam); ModalResult := mrOK; end;
procedure TD.DialogShown(Sender: TObject);
begin
  if Mode = 5 then
    Check(SetTimer(Dialog.Handle, 809, 200, nil) <> 0, 'idle-opened modal timer armed');
end;
procedure TD.MainShown(Sender: TObject);
begin
  SetActiveWindow(Main.Handle); Main.SetFocus;
  ResultValue := Dialog.ShowModal(Main.Handle);
  if Mode <> 6 then App.Terminate(0);
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0); Driver.Valid := True;
  App := TNativeApplication.Create(nil); App.Initialize;
  App.CreateForm(TNativeForm, Main); Main.SetBounds(10, 10, 200, 110);
  App.ShowMainForm := False; App.OnIdle := Driver.Idle;
end;
procedure ModalSetup;
begin
  Setup; App.ShowMainForm := True;
  App.CreateForm(TDialog, Dialog); Dialog.SetBounds(40, 40, 180, 90);
  Dialog.OnShow := Driver.DialogShown; Main.OnShow := Driver.MainShown;
end;
procedure Cleanup;
begin
  App.OnIdle := nil; App.Free; App := nil; Main := nil; Dialog := nil;
  Successor := TNativeMessageLoop.Create;
  Successor.ProcessMessages(500); Successor.Free; Successor := nil;
  Check(not PeekMessage(Queue, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE), 'application idle leaves no quit residue');
end;
procedure BasicAndFailure;
begin
  App := TNativeApplication.Create(nil); Rejected := False;
  try App.OnIdle := Driver.Idle; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'idle registration requires initialized application'); App.Free; App := nil;
  Setup; Driver.Mode := 1;
  Check((FindWindow('TApplication', 'Calmira') = 0) and (Main.Handle = 0),
    'idle registration creates no native transport or form HWND');
  Check((App.ProcessMessages(100) = 0) and (Driver.Calls = 0), 'application bounded pump does not call idle');
  Check(App.Run = -72, 'application idle slices preserve signed quit');
  Check((Driver.Calls = 3) and (Driver.Guards = 3) and Driver.Valid and
    not App.Running and App.Terminated and Assigned(App.OnIdle), 'application idle sender guards and run flags'); Cleanup;
  Setup; Driver.Mode := 2; Rejected := False;
  try App.Run; except on E: Exception do Rejected := E.Message = 'app idle failure'; end;
  Check(Rejected and not App.Running and not App.Terminated, 'application idle error propagates outside USER with guards released');
  App.OnIdle := nil; App.ProcessMessages(1); App.OnIdle := Driver.Idle; Driver.Mode := 3;
  Check(App.Run = -73, 'application can rebind and rerun after idle error'); Cleanup;
end;
procedure ModalCases;
begin
  ModalSetup; Driver.Mode := 4;
  Check(App.Run = 0, 'startup modal inherits application idle service');
  Check((Driver.Calls = 1) and Driver.Valid and (Driver.ResultValue = mrOK) and
    not Dialog.ModalRunning and IsWindowEnabled(Main.Handle), 'modal idle completes dialog and restores owner'); Cleanup;
  ModalSetup; Driver.Mode := 5; Main.OnShow := nil;
  Main.Show; SetActiveWindow(Main.Handle); App.ProcessMessages(500);
  Check(App.Run = -74, 'application idle can open and complete modal dialog');
  Check((Driver.Calls = 1) and Driver.Valid and not Dialog.ModalRunning,
    'idle-opened modal skips busy inherited provider'); Cleanup;
  ModalSetup; Driver.Mode := 6;
  Check(App.Run = -75, 'modal idle signed quit reaches suspended root');
  Check(Driver.Valid and Dialog.TaskQuit and (Dialog.TaskExitCode = -75) and
    not Dialog.ModalRunning and IsWindowEnabled(Main.Handle), 'modal idle quit preserves cleanup and enable state'); Cleanup;
  ModalSetup; Driver.Mode := 7; Rejected := False;
  try App.Run; except on E: Exception do Rejected := E.Message = 'modal idle failure'; end;
  Check(Rejected and not App.Running and not Dialog.ModalRunning and IsWindowEnabled(Main.Handle),
    'modal inherited idle exception restores owner and root pump');
  App.OnIdle := nil; Main.OnShow := nil; App.OnIdle := Driver.Idle; Driver.Mode := 3;
  Check(App.Run = -73, 'root recovers after inherited modal idle error'); Cleanup;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native application idle');
  try BasicAndFailure; ModalCases;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  App.Free; Successor.Free;
  Check(StackGuardIntact, 'application idle stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
