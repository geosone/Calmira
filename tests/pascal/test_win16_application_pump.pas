program ApplicationPumpTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls, native_application,
  native_form, native_modal, native_button, native_loop;
const Work = WM_USER + 291; Probe = WM_USER + 292;
  ModalProbe = WM_USER + 293; Trail = WM_USER + 294;
type
  TFrame = class(TNativeForm)
  public
    constructor Create(AOwner: TComponent); override;
    procedure Operation(var M: TMessage); message Work;
  end;
  TDialog = class(TNativeModalForm)
  public
    procedure Operation(var M: TMessage); message Work;
  end;
  TD = object
    Calls, Guards, IdleCalls, WrongFilters, Trails, FactoryGuards: Integer;
    Cancelled, FailFilter: Boolean;
    function Filter(var M: TMsg): Boolean;
    function Hook(var M: TMessage): Boolean;
    function Help(Command: Word; Data: LongInt; var CallHelp: Boolean): Boolean;
    procedure ExceptionRaised(Sender: TObject; E: Exception);
    procedure Click(Sender: TObject);
    procedure Start(Sender: TObject);
    procedure DialogStart(Sender: TObject);
    procedure Idle(Sender: TObject; var Done: Boolean);
  end;
var App: TNativeApplication; Main: TFrame; Dialog: TDialog;
  Button, DialogButton: TButton; Driver: TD; Successor: TNativeMessageLoop;
  Failed, Rejected: Boolean; Before: Integer;
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
constructor TFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  try App.ProcessMessages; except on ENativeApplicationError do Inc(Driver.FactoryGuards); end;
end;
function TD.Filter(var M: TMsg): Boolean;
begin
  Result := True;
  case M.message of
    Probe:
      begin
        if FailFilter then raise Exception.Create('application drain filter failure');
        Inc(Calls);
        try App.ProcessMessages; except on ENativeApplicationError do Inc(Guards); end;
        try App.ProcessMessages(1); except on ENativeApplicationError do Inc(Guards); end;
        try App.Run; except on ENativeApplicationError do Inc(Guards); end;
      end;
    ModalProbe: Inc(WrongFilters);
    Trail: Inc(Trails);
    else Result := False;
  end;
end;
function TD.Hook(var M: TMessage): Boolean;
begin
  Result := M.Msg = Probe;
  if Result then
  begin
    try App.ProcessMessages; except on ENativeApplicationError do Inc(Guards); end;
    M.Result := 1;
  end;
end;
function TD.Help(Command: Word; Data: LongInt; var CallHelp: Boolean): Boolean;
begin
  try App.ProcessMessages; except on ENativeApplicationError do Inc(Guards); end;
  CallHelp := False; Result := True;
end;
procedure TD.ExceptionRaised(Sender: TObject; E: Exception);
begin
  try App.ProcessMessages; except on ENativeApplicationError do Inc(Guards); end;
end;
procedure TD.Click(Sender: TObject);
begin Cancelled := True; end;
procedure TD.Start(Sender: TObject);
begin PostMessage(Main.Handle, Work, 0, 0); end;
procedure TD.DialogStart(Sender: TObject);
begin PostMessage(Dialog.Handle, Work, 0, 0); end;
procedure TD.Idle(Sender: TObject; var Done: Boolean);
begin
  Inc(IdleCalls);
  try App.ProcessMessages; except on ENativeApplicationError do Inc(Guards); end;
  Done := True; App.Terminate(-62);
end;
procedure TDialog.Operation(var M: TMessage);
var Previous: Integer;
begin
  Check(App.Running and ModalRunning and not IsWindowEnabled(Main.Handle), 'modal operation retains suspended root and disabled owner');
  Previous := Driver.WrongFilters; Driver.Cancelled := False;
  PostAppMessage(GetCurrentTask, ModalProbe, 0, 0);
  PostMessage(DialogButton.Handle, WM_KEYDOWN, VK_RETURN, 1);
  App.ProcessMessages;
  Check(Driver.Cancelled and (ModalResult = mrOK) and (Driver.WrongFilters = Previous),
    'application drain inherits actual modal default-button routing without root filter');
  Check(not IsWindowEnabled(Main.Handle), 'drain does not prematurely restore modal owner');
end;
procedure TFrame.Operation(var M: TMessage);
var Previous: Integer;
begin
  Check(App.Running, 'operation callback runs inside root application pump');
  Driver.Cancelled := False; Previous := Driver.Calls;
  PostAppMessage(GetCurrentTask, Probe, 0, 0);
  PostMessage(Button.Handle, WM_KEYDOWN, VK_RETURN, 1);
  App.ProcessMessages;
  Check(Driver.Cancelled and (Driver.Calls = Previous + 1) and App.Running,
    'parameterless drain processes real Cancel click while long operation callback is active');
  Check(Dialog.ShowModal(Main.Handle) = mrOK, 'modal operation returns after inner drain and default click');
  Check(IsWindowEnabled(Main.Handle) and App.Running, 'modal drain restores owner and suspended root pump');
  App.Terminate(-61); App.ProcessMessages;
  Check(App.Terminated and (App.ExitCode = -61), 'drained quit terminates active application with signed exit code');
  PostAppMessage(GetCurrentTask, Trail, 0, 0);
end;
procedure Setup;
begin
  App := TNativeApplication.Create(nil); App.Initialize;
  App.CreateForm(TFrame, Main); Main.SetBounds(20, 20, 220, 130);
  Button := TButton.Create(Main); Button.Parent := Main; Button.Default := True;
  Button.Caption := 'Cancel'; Button.OnClick := Driver.Click;
  Button.SetBounds(10, 10, 80, 24);
  App.OnMessage := Driver.Filter;
end;
procedure Cleanup;
begin
  Dialog.Free; Dialog := nil; App.Free; App := nil; Main := nil;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP parameterless application message service');
  try
    App := TNativeApplication.Create(nil); Rejected := False;
    try App.ProcessMessages; except on ENativeApplicationError do Rejected := True; end;
    Check(Rejected, 'parameterless pump requires initialized application'); App.Free; App := nil;
    Setup; App.OnIdle := Driver.Idle; App.ProcessMessages;
    Check((Driver.IdleCalls = 0) and not App.Running and (Main.Handle = 0),
      'empty parameterless application pump does not run idle show main or enter Run');
    App.OnIdle := nil; Driver.FailFilter := True; Rejected := False;
    PostAppMessage(GetCurrentTask, Probe, 0, 0);
    try App.ProcessMessages; except on Exception do Rejected := True; end;
    Driver.FailFilter := False; PostAppMessage(GetCurrentTask, Probe, 0, 0); App.ProcessMessages;
    Check(Rejected and (Driver.Calls = 1) and (Driver.Guards = 3),
      'filter failure releases application drain guards and recursive pumps remain rejected');
    Before := Driver.Guards; App.HookMainWindow(Driver.Hook);
    SendMessage(App.Handle, Probe, 0, 0); App.UnhookMainWindow(Driver.Hook);
    App.OnHelp := Driver.Help; Check(App.HelpContext(1), 'suppressed help callback completes'); App.OnHelp := nil;
    App.OnException := Driver.ExceptionRaised;
    try raise Exception.Create('explicit exception'); except on Exception do App.HandleException(Main); end;
    App.OnException := nil;
    Check(Driver.Guards = Before + 3, 'sent transport help and exception callbacks reject parameterless reentry');
    Dialog := TDialog.Create(nil); Dialog.SetBounds(40, 40, 180, 100); Dialog.OnShow := Driver.DialogStart;
    DialogButton := TButton.Create(Dialog); DialogButton.Parent := Dialog;
    DialogButton.Default := True; DialogButton.ModalResult := mrOK;
    DialogButton.OnClick := Driver.Click; DialogButton.SetBounds(10, 10, 80, 24);
    Main.OnShow := Driver.Start;
    Check(App.Run = -61, 'root Run exits after quit consumed by operation drain');
    App.ProcessMessages;
    Check(Driver.Trails = 0, 'terminated application drain does not dequeue later sentinel');
    Check((Main.CallbackErrors = 0) and (Dialog.CallbackErrors = 0) and (App.WindowCallbackErrors = 0),
      'nested native operations complete without swallowed callback failures');
    Cleanup;
    Successor := TNativeMessageLoop.Create; Successor.OnMessage := Driver.Filter; Successor.DrainMessages;
    Check((Driver.Trails = 1) and not Successor.Terminated, 'successor sees sentinel without leaked quit or pump guards');
    Successor.Free; Successor := nil;
    Setup; Main.OnShow := nil; App.OnIdle := Driver.Idle; Before := Driver.Guards;
    Check(App.Run = -62, 'idle service can still terminate root after application drain recovery');
    Check((Driver.IdleCalls = 1) and (Driver.Guards = Before + 1) and (Driver.FactoryGuards = 2),
      'parameterless pump rejects active idle and factory construction callbacks');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; Successor.Free;
  Check(StackGuardIntact, 'application pump stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
