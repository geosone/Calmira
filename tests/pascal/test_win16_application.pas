program ApplicationTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, native_application,
  native_form, native_loop;
const ProbeMessage = WM_USER + 151;
type
  TFrame = class(TNativeForm)
  public
    Calls: Integer;
    destructor Destroy; override;
    procedure Probe(var M: TMessage); message ProbeMessage;
    procedure Timer(var M: TMessage); message WM_TIMER;
  end;
  THost = class(TNativeFormHost)
  public
    Calls: Integer;
    procedure Bind(Value: TNativeForm);
    procedure FormClosed(Value: TNativeForm); override;
  end;
  TD = object
    Mode, Queries, Shows, Rejections: Integer;
    StartFailure, FilterFailure, HideFailure: Boolean;
    procedure Shown(Sender: TObject);
    procedure Query(Sender: TObject; var Allowed: Boolean);
    procedure Closing(Sender: TObject; var Action: TNativeCloseAction);
    procedure Hidden(Sender: TObject);
    function Filter(var Message: TMsg): Boolean;
  end;
var App, Peer: TNativeApplication; Main, Second: TFrame; Driver: TD;
  Failed, Rejected: Boolean; Deaths, Mode: Integer; Queue: TMsg;
  Successor: TNativeMessageLoop;
  Host: THost;
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
destructor TFrame.Destroy;
begin Inc(Deaths); inherited Destroy; end;
procedure THost.Bind(Value: TNativeForm);
begin AttachForm(Value); end;
procedure THost.FormClosed(Value: TNativeForm);
begin
  { A host notification must run after the form's close guard is released. }
  Value.Show; Value.Hide; Inc(Calls);
end;
procedure TFrame.Probe(var M: TMessage);
var Victim: TFrame;
begin
  Inc(Calls);
  case Driver.Mode of
    1:
      begin
        Check(Main.Visible and not App.QuitRequested, 'main close veto remains running');
        PostMessage(Main.Handle, WM_CLOSE, 0, 0);
      end;
    2: SendMessage(Handle, WM_SYSCOMMAND, SC_CLOSE, 0);
    4: begin Victim := Main; Main := nil; Victim.Free; end;
    5: App.UnregisterForm(Main);
  end;
end;
procedure TFrame.Timer(var M: TMessage);
begin
  KillTimer(Handle, M.WParam); App.Terminate(-21); App.Terminate(88);
end;
procedure TD.Query(Sender: TObject; var Allowed: Boolean);
begin
  Inc(Queries); Allowed := (Mode <> 1) or (Queries > 1);
end;
procedure TD.Closing(Sender: TObject; var Action: TNativeCloseAction);
begin
  if Mode = 2 then Action := ncaDestroy;
  if Mode = 8 then Action := ncaNone;
end;
procedure TD.Hidden(Sender: TObject);
begin if HideFailure then raise Exception.Create('hide failure'); end;
function TD.Filter(var Message: TMsg): Boolean;
begin
  Result := False;
  if FilterFailure and (Message.message = ProbeMessage) then
    raise Exception.Create('filter failure');
end;
procedure TD.Shown(Sender: TObject);
var Other: TNativeMessageLoop;
begin
  Inc(Shows);
  if StartFailure then raise Exception.Create('startup failure');
  Other := TNativeMessageLoop.Create;
  try
    try Other.ProcessMessages(1); except on ENativeLoopError do Inc(Rejections); end;
  finally Other.Free; end;
  try App.ProcessMessages(1); except on ENativeApplicationError do Inc(Rejections); end;
  try App.MainForm := Second; except on ENativeApplicationError do Inc(Rejections); end;
  case Mode of
    1:
      begin
        Second.Show; PostMessage(Second.Handle, WM_CLOSE, 0, 0);
        PostMessage(Main.Handle, WM_CLOSE, 0, 0); PostMessage(Main.Handle, ProbeMessage, 0, 0);
      end;
    2: PostMessage(Main.Handle, ProbeMessage, 0, 0);
    3: if SetTimer(Main.Handle, 45, 55, nil) = 0 then raise Exception.Create('timer');
    4, 5: begin Second.Show; PostMessage(Second.Handle, ProbeMessage, 0, 0); end;
    6: PostQuitMessage(-33);
    7: PostMessage(Main.Handle, ProbeMessage, 0, 0);
  end;
end;
procedure Cleanup;
begin
  if App <> nil then
    if App.QuitRequested and not App.Terminated then App.ProcessMessages(500);
  App.Free; App := nil; Peer.Free; Peer := nil;
  Host.Free; Host := nil;
  Main.Free; Main := nil; Second.Free; Second := nil;
  Check(not PeekMessage(Queue, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE), 'no residual quit');
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0);
  App := TNativeApplication.Create(nil); App.Initialize; App.Initialize;
  Main := TFrame.Create(nil); Second := TFrame.Create(nil);
  Main.Caption := 'Main'; Second.Caption := 'Second';
  Main.SetBounds(10, 10, 180, 90); Second.SetBounds(210, 10, 180, 90);
  App.RegisterForm(Main, True); App.RegisterForm(Second);
  Main.OnShow := Driver.Shown; Main.OnCloseQuery := Driver.Query; Main.OnClose := Driver.Closing;
end;
procedure Registry;
begin
  App := TNativeApplication.Create(nil); Rejected := False;
  try App.Run; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and not App.Initialized, 'initialize required');
  App.Initialize; Peer := TNativeApplication.Create(nil); Rejected := False;
  try Peer.Initialize; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and App.Initialized, 'one application per task'); Peer.Free; Peer := nil;
  Main := TFrame.Create(nil); Second := TFrame.Create(nil);
  Host := THost.Create(nil); Host.Bind(Main); Rejected := False;
  try App.RegisterForm(Main, True); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and (App.FormCount = 0) and (Main.LifecycleHost = Host), 'foreign host registration is atomic');
  Main.OnClose := Driver.Closing; Main.Show; Driver.Mode := 8;
  Check(not Main.TryClose and Main.Visible and (Host.Calls = 0), 'none close action does not notify host');
  Driver.Mode := 0; Driver.HideFailure := True; Main.OnHide := Driver.Hidden; Rejected := False;
  try Main.TryClose; except on Exception do Rejected := True; end;
  Check(Rejected and (Host.Calls = 0), 'failed close does not notify host');
  Main.OnHide := nil; Driver.HideFailure := False; Main.Show;
  Check(Main.TryClose and (Host.Calls = 1), 'host notification follows successful close and unlock');
  Host.Free; Host := nil; Check(Main.LifecycleHost = nil, 'weak host lifetime');
  Main.OnClose := nil;
  App.RegisterForm(Main, True); App.RegisterForm(Main); App.RegisterForm(Second);
  Check((App.FormCount = 2) and (App.Forms[0] = Main) and (Main.LifecycleHost = App), 'weak registry and duplicate registration');
  Rejected := False;
  try if App.Forms[-1] = nil then Rejected := False; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'form index bound');
  App.UnregisterForm(Second); Check((Second.LifecycleHost = nil) and (App.FormCount = 1), 'detach secondary');
  App.RegisterForm(Second); Second.Free; Second := nil;
  Check((App.FormCount = 1) and (App.MainForm = Main), 'weak secondary lifetime');
  Main.Show; App.Free; App := nil;
  Check((Main.LifecycleHost = nil) and IsWindow(Main.Handle), 'nonowned form survives application'); Cleanup;
  App := TNativeApplication.Create(nil); App.Initialize; Deaths := 0;
  App.RegisterForm(TFrame.Create(App), True); App.RegisterForm(TFrame.Create(App));
  App.Free; App := nil; Check(Deaths = 2, 'owned forms destroyed once'); Cleanup;
end;
procedure Running;
begin
  for Mode := 1 to 6 do
  begin
    Setup; Driver.Mode := Mode;
    if Mode = 3 then Check(App.Run = -21, 'asynchronous first quit code wins')
    else if Mode = 6 then Check(App.Run = -33, 'external signed quit')
    else Check(App.Run = 0, 'application run');
    Check(App.Terminated and not App.Running and (Driver.Rejections = 3), 'startup inside root pump and guards');
    if Mode = 1 then Check((Driver.Queries = 2) and not Main.Visible and not Second.Visible, 'secondary close and main veto');
    if Mode = 2 then Check(Main.Handle = 0, 'sent system close destroys main HWND');
    if Mode = 3 then
    begin
      { PostQuitMessage is deferred by USER. Test successor ownership after
        actual quit consumption, not an assumed position in the task queue. }
      PostMessage(Main.Handle, ProbeMessage, 0, 0);
      Check(App.Run = -21, 'sticky application exit code');
      Check(App.ProcessMessages(100) = 0, 'terminated application stops pumping');
      Check(Main.Calls = 0, 'sticky quit preserves successor');
      Successor := TNativeMessageLoop.Create;
      try Successor.ProcessMessages(500); finally Successor.Free; Successor := nil; end;
      Check(Main.Calls = 1, 'explicit successor receives retained message');
    end;
    if Mode in [4, 5] then Check((App.MainForm = nil) and (App.FormCount = 1), 'main removal ends active application');
    Cleanup;
  end;
end;
procedure Recovery;
begin
  Setup; Driver.StartFailure := True; Rejected := False;
  try App.Run; except on Exception do Rejected := True; end;
  Check(Rejected and not App.Running and not App.Terminated, 'startup exception releases pump');
  Driver.StartFailure := False; Driver.Mode := 2; Main.Hide;
  Check(App.Run = 0, 'startup recovery'); Cleanup;
  Setup; Driver.Mode := 7; Driver.FilterFailure := True; App.OnMessage := Driver.Filter; Rejected := False;
  try App.Run; except on Exception do Rejected := True; end;
  Check(Rejected and not App.Running and not App.Terminated, 'filter exception releases pump');
  App.OnMessage := nil; PostMessage(Main.Handle, WM_CLOSE, 0, 0);
  Check(App.Run = 0, 'filter recovery'); Cleanup;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native application');
  try Registry; Running; Recovery;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; Check(StackGuardIntact, 'stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
