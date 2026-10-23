program DrainTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, native_loop, native_window;
const Probe = WM_USER + 290;
type
  TTarget = class(TNativeWindow)
  public
    Calls: Integer;
    procedure Seen(var M: TMessage); message Probe;
  end;
  TD = object
    Calls, Left, Guards, IdleCalls, ModalCalls: Integer;
    FailFilter, CheckGuards, SwapFilter, QuitInFilter: Boolean;
    function Filter(var M: TMsg): Boolean;
    function ModalFilter(var M: TMsg): Boolean;
    function ModalCondition: Boolean;
    function QuitCondition: Boolean;
    function PostedQuitCondition: Boolean;
    procedure Start(Sender: TObject);
    procedure QuitStart(Sender: TObject);
    procedure FilterQuitStart(Sender: TObject);
    procedure Idle(Sender: TObject; var Done: Boolean);
  end;
var Root, Peer, Modal, Successor, Retired: TNativeMessageLoop; Driver: TD;
  Target: TTarget;
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
procedure Enqueue;
begin
  if not PostAppMessage(GetCurrentTask, Probe, 0, 0) then raise Exception.Create('post');
end;
procedure TTarget.Seen(var M: TMessage);
begin Inc(Calls); end;
function TD.Filter(var M: TMsg): Boolean;
begin
  Result := M.message = Probe;
  if not Result then Exit;
  if FailFilter then raise Exception.Create('drain filter failure');
  if QuitInFilter then
  begin
    QuitInFilter := False; Modal.RunModal(PostedQuitCondition);
    Result := False; Exit;
  end;
  Inc(Calls);
  if SwapFilter then
  begin
    SwapFilter := False; Root.OnMessage := ModalFilter; Enqueue;
  end;
  if CheckGuards then
  begin
    try Root.DrainMessages; except on ENativeLoopError do Inc(Guards); end;
    try Peer.DrainMessages; except on ENativeLoopError do Inc(Guards); end;
    try Peer.ProcessMessages(1); except on ENativeLoopError do Inc(Guards); end;
  end;
  if Left > 0 then begin Dec(Left); Enqueue; end;
end;
function TD.ModalFilter(var M: TMsg): Boolean;
begin
  Result := M.message = Probe;
  if Result then Inc(ModalCalls);
end;
function TD.ModalCondition: Boolean;
begin
  Enqueue; Peer.DrainMessages;
  Result := False;
end;
procedure TD.Start(Sender: TObject);
var Previous: Integer; Caught: Boolean;
begin
  Previous := Calls; Enqueue; Root.DrainMessages;
  Check(Calls = Previous + 1, 'root startup can explicitly drain through active root filter');
  Previous := Calls; Enqueue; FailFilter := True; Caught := False;
  try Root.DrainMessages; except on Exception do Caught := True; end;
  FailFilter := False; Enqueue; Root.DrainMessages;
  Check(Caught and (Calls = Previous + 1), 'filter exception restores suspended root and permits next drain');
  Previous := Calls; Modal.OnMessage := ModalFilter; ModalCalls := 0;
  Modal.RunModal(ModalCondition);
  Check((Calls = Previous) and (ModalCalls = 1), 'drain called on peer retains active modal filter rather than peer or root filter');
end;
procedure TD.Idle(Sender: TObject; var Done: Boolean);
begin
  Inc(IdleCalls);
  try Root.DrainMessages; except on ENativeLoopError do Inc(Guards); end;
  try Peer.DrainMessages; except on ENativeLoopError do Inc(Guards); end;
  Done := True; PostQuitMessage(-47);
end;
function TD.QuitCondition: Boolean;
begin
  PostQuitMessage(-73); Peer.DrainMessages;
  Check(Root.Terminated and Modal.Terminated and Peer.Terminated and
    (Root.ExitCode = -73) and (Modal.ExitCode = -73) and (Peer.ExitCode = -73),
    'drained signed quit reaches modal root and unrelated caller loop');
  Retired.DrainMessages;
  Check(Retired.Terminated and (Retired.ExitCode = -47),
    'already terminated caller retains first exit code across another terminating root');
  Enqueue; Result := True;
end;
procedure TD.QuitStart(Sender: TObject);
begin
  Modal.RunModal(QuitCondition);
  Check(Root.Terminated, 'root remains terminated after modal drain returns');
end;
function TD.PostedQuitCondition: Boolean;
begin PostQuitMessage(-74); Result := True; end;
procedure TD.FilterQuitStart(Sender: TObject);
begin
  PostMessage(Target.Handle, Probe, 0, 0); Root.DrainMessages;
end;
procedure Cleanup;
begin
  Root.Free; Root := nil; Peer.Free; Peer := nil; Modal.Free; Modal := nil;
end;
procedure Setup;
begin
  Root := TNativeMessageLoop.Create; Peer := TNativeMessageLoop.Create;
  Modal := TNativeMessageLoop.Create; Root.OnMessage := Driver.Filter;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP scoped task queue drain');
  try
    Setup; Root.OnIdle := Driver.Idle;
    Driver.Left := 511; Enqueue; Root.DrainMessages;
    Check((Driver.Calls = 512) and (Driver.IdleCalls = 0), 'drain processes finite repost chain through empty queue without idle');
    Before := Driver.Calls; Root.DrainMessages;
    Check((Driver.Calls = Before) and (Driver.IdleCalls = 0), 'empty drain returns without blocking or idle');
    Driver.SwapFilter := True; Enqueue; Root.DrainMessages;
    Check((Driver.Calls = Before + 1) and (Driver.ModalCalls = 1), 'drain observes source filter reassignment on the next message');
    Root.OnMessage := Driver.Filter;
    Driver.CheckGuards := True; Enqueue; Root.DrainMessages; Driver.CheckGuards := False;
    Check(Driver.Guards = 3, 'same peer drain and bounded recursion cannot steal active drain queue');
    Root.OnStart := Driver.Start;
    Check(Root.Run = -47, 'root resumes after startup drain and wakes for signed idle quit');
    Check((Driver.IdleCalls = 1) and (Driver.Guards = 5), 'draining from active idle provider is rejected across loop objects');
    Retired := Root; Root := nil; Cleanup; Setup; Root.OnStart := Driver.QuitStart;
    Before := Driver.Calls;
    Check(Root.Run = -73, 'quit consumed in nested drain ends suspended root run');
    Root.DrainMessages;
    Check(Driver.Calls = Before, 'terminated drain leaves later messages untouched');
    Successor := TNativeMessageLoop.Create; Successor.OnMessage := Driver.Filter;
    Successor.DrainMessages;
    Check((Driver.Calls = Before + 1) and not Successor.Terminated,
      'successor receives sentinel without reposted quit or stale active frame');
    Successor.Free; Successor := nil; Cleanup; Setup;
    Target := TTarget.Create(nil); Target.CreateHandle(0, 'Drain quit', WS_POPUP, 0, 0, 10, 10);
    Root.OnStart := Driver.FilterQuitStart; Driver.QuitInFilter := True;
    Check((Root.Run = -74) and (Target.Calls = 0),
      'modal quit inside drain filter prevents later native dispatch of original message');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; Successor.Free; Retired.Free; Target.Free;
  Check(StackGuardIntact, 'drain stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
