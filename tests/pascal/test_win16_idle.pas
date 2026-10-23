program IdleLoopTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, native_loop, native_window;
const WorkMessage = WM_USER + 241;
type
  TProbe = class(TNativeWindow)
    procedure Work(var M: TMessage); message WorkMessage;
    procedure Timer(var M: TMessage); message WM_TIMER;
  end;
  TD = object
    Mode, IdleCalls, ChildCalls, WorkCalls, TimerCalls, Guards: Integer;
    ContinueChild, Valid: Boolean;
    Started: LongInt;
    procedure Idle(Sender: TObject; var Done: Boolean);
    procedure ChildIdle(Sender: TObject; var Done: Boolean);
    procedure Startup(Sender: TObject);
    function ContinueModal: Boolean;
  end;
var Root, Child, Spare: TNativeMessageLoop; Probe: TProbe; Driver: TD;
  Failed, Rejected: Boolean; Queue: TMsg; Code: SmallInt;
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
procedure TProbe.Work(var M: TMessage);
begin Inc(Driver.WorkCalls); end;
procedure TProbe.Timer(var M: TMessage);
begin
  KillTimer(Handle, M.WParam); Inc(Driver.TimerCalls);
  if Driver.Mode = 1 then PostQuitMessage(0)
  else Driver.ContinueChild := False;
  M.Result := 0;
end;
function TD.ContinueModal: Boolean;
begin Result := ContinueChild; end;
procedure TD.ChildIdle(Sender: TObject; var Done: Boolean);
begin
  Inc(ChildCalls); Valid := Valid and (Sender = Child) and Root.Idling and Child.Idling;
  ContinueChild := False;
end;
procedure TD.Idle(Sender: TObject; var Done: Boolean);
begin
  Inc(IdleCalls); Valid := Valid and Done;
  if Mode = 6 then Valid := Valid and (Sender = Child) and Root.Idling and not Child.Idling
  else Valid := Valid and (Sender = Root) and Root.Idling;
  case Mode of
    1: ; { Done defaults to True: GetMessage must wait for the native timer. }
    2: begin
      Done := False;
      if IdleCalls = 3 then PostMessage(Probe.Handle, WorkMessage, 0, 0);
      if IdleCalls = 4 then
      begin Valid := Valid and (WorkCalls = 1); PostQuitMessage(-12); end;
    end;
    3: begin Done := False; PostQuitMessage(-41); end;
    4: raise Exception.Create('idle failure');
    5: ContinueChild := False;
    6: begin
      try Root.OnIdle := nil; except on ENativeLoopError do Inc(Guards); end;
      try Root.ProcessMessages(1); except on ENativeLoopError do Inc(Guards); end;
      try Spare.Run; except on ENativeLoopError do Inc(Guards); end;
      ContinueChild := False;
    end;
    7, 8: begin
      if IdleCalls > 1 then begin Valid := False; ContinueChild := False; Exit; end;
      ContinueChild := True;
      if Mode = 7 then
        Check(SetTimer(Probe.Handle, 805, 200, nil) <> 0, 'nested idle modal timer armed')
      else Child.OnIdle := ChildIdle;
      Child.RunModal(ContinueModal);
      PostQuitMessage(-61);
    end;
  end;
end;
procedure TD.Startup(Sender: TObject);
begin
  ContinueChild := True; Child.RunModal(ContinueModal); PostQuitMessage(-51);
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0); Driver.Valid := True;
  Root := TNativeMessageLoop.Create; Child := TNativeMessageLoop.Create; Spare := TNativeMessageLoop.Create;
  Probe := TProbe.Create(nil); Probe.CreateHandle(0, 'Idle probe', WS_POPUP, 0, 0, 10, 10);
  Root.ProcessMessages(100); Root.OnIdle := Driver.Idle;
end;
procedure Cleanup;
begin
  Root.OnIdle := nil; Child.OnIdle := nil; Root.OnStart := nil;
  Spare.ProcessMessages(100);
  Check(not PeekMessage(Queue, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE), 'idle scenario leaves no quit residue');
  Probe.Free; Probe := nil; Root.Free; Root := nil; Child.Free; Child := nil; Spare.Free; Spare := nil;
end;
procedure BoundedAndQueued;
begin
  Setup;
  Check((Root.ProcessMessages(100) = 0) and (Driver.IdleCalls = 0), 'bounded empty pump never invokes idle');
  PostMessage(Probe.Handle, WorkMessage, 0, 0); PostMessage(Probe.Handle, WorkMessage, 0, 0);
  PostMessage(Probe.Handle, WorkMessage, 0, 0);
  Check((Root.ProcessMessages(2) = 2) and (Driver.WorkCalls = 2) and (Driver.IdleCalls = 0),
    'bounded queue budget does not add idle work');
  PostQuitMessage(-17); Check(Root.Run = -17, 'queued work and signed quit run before idle');
  Check((Driver.WorkCalls = 3) and (Driver.IdleCalls = 0), 'idle does not consume or bypass queued messages'); Cleanup;
end;
procedure WaitingAndSlices;
begin
  Setup; Driver.Mode := 1; Driver.Started := GetTickCount;
  Check(SetTimer(Probe.Handle, 804, 300, nil) <> 0, 'default idle wait timer armed');
  Check(Root.Run = 0, 'default idle returns to blocking native wait');
  Check((Driver.IdleCalls = 1) and (Driver.TimerCalls = 1) and Driver.Valid and
    (GetTickCount - Driver.Started >= 150), 'Done true does not busy poll empty queue'); Cleanup;
  Setup; Driver.Mode := 2; Check(Root.Run = -12, 'Done false requests cooperative additional work slices');
  Check((Driver.IdleCalls = 4) and (Driver.WorkCalls = 1) and Driver.Valid,
    'queued message interrupts repeated idle slices'); Cleanup;
  Setup; Driver.Mode := 3; Check(Root.Run = -41, 'idle signed quit terminates without another idle call');
  Check((Driver.IdleCalls = 1) and Root.Terminated and Driver.Valid, 'quit remains sticky after idle'); Cleanup;
end;
procedure ExceptionsAndModal;
begin
  Setup; Driver.Mode := 4; Rejected := False;
  try Root.Run; except on E: Exception do Rejected := E.Message = 'idle failure'; end;
  Check(Rejected and not Root.Idling and not Root.Terminated, 'idle exception propagates and releases provider guard');
  Root.OnIdle := nil; Check(Root.ProcessMessages(1) = 0, 'idle exception releases active pump');
  Driver.Mode := 3; Root.OnIdle := Driver.Idle; Driver.IdleCalls := 0;
  Check(Root.Run = -41, 'same loop can recover from idle exception'); Cleanup;
  Setup; Driver.Mode := 5; Driver.ContinueChild := True;
  Check((Root.RunModal(Driver.ContinueModal) = 0) and (Driver.IdleCalls = 1) and
    not Root.Terminated, 'idle can end modal condition without posting a wakeup'); Cleanup;
  Setup; Driver.Mode := 6; Root.OnStart := Driver.Startup; Code := Root.Run;
  Check((Code = -51) and (Driver.IdleCalls = 1) and (Driver.Guards = 3) and Driver.Valid,
    'modal inherits parent idle with current-pump sender and provider mutation guard'); Cleanup;
  Setup; Driver.Mode := 7; Check(Root.Run = -61, 'modal opened from idle returns to root');
  Check((Driver.IdleCalls = 1) and (Driver.TimerCalls = 1) and Driver.Valid,
    'modal opened from idle does not recursively call busy provider'); Cleanup;
  Setup; Driver.Mode := 8; Check(Root.Run = -61, 'nested modal may supply its own idle handler');
  Check((Driver.IdleCalls = 1) and (Driver.ChildCalls = 1) and Driver.Valid,
    'nearest explicit modal provider overrides busy parent'); Cleanup;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native loop idle');
  try BoundedAndQueued; WaitingAndSlices; ExceptionsAndModal;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Probe.Free; Root.Free; Child.Free; Spare.Free;
  Check(StackGuardIntact, 'idle loop stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
