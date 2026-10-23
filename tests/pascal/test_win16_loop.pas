program TestWin16Loop;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, native_window, native_loop;
const ProbeMessage = WM_USER + 81; ReenterMessage = WM_USER + 82;
  RaiseMessage = WM_USER + 83; ChainMessage = WM_USER + 84;
type
  TProbe = class(TNativeWindow)
  public
    Calls, Characters, Rejections, Timers: Integer;
    LastKey: Word;
    Chains: Integer;
    StopChain: Boolean;
    Loop, PeerLoop: TNativeMessageLoop;
    procedure Probe(var M: TMessage); message ProbeMessage;
    procedure Reenter(var M: TMessage); message ReenterMessage;
    procedure RaiseProbe(var M: TMessage); message RaiseMessage;
    procedure Character(var M: TMessage); message WM_CHAR;
    procedure Timer(var M: TMessage); message WM_TIMER;
    procedure Chain(var M: TMessage); message ChainMessage;
  end;
var Failed, Rejected: Boolean; A: TProbe; Loop, Peer, QuitLoop: TNativeMessageLoop;
  I: Integer; N: Word; QueueMessage: TMsg;
procedure LogLine(const Text: string);
var F: HFILE; Buffer: array[0..255] of Char; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Buffer, Line);
  _lwrite(F, @Buffer, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure Post(Kind, WP: Word; LP: LongInt);
begin
  if not PostMessage(A.Handle, Kind, WP, LP) then
    raise Exception.Create('Cannot post probe message');
end;
procedure TProbe.Probe(var M: TMessage);
begin Inc(Calls); end;
procedure TProbe.Reenter(var M: TMessage);
begin
  try Loop.ProcessMessages(1); except on ENativeLoopError do Inc(Rejections); end;
  try PeerLoop.Run; except on ENativeLoopError do Inc(Rejections); end;
end;
procedure TProbe.RaiseProbe(var M: TMessage);
begin raise Exception.Create('queued callback failure'); end;
procedure TProbe.Character(var M: TMessage);
begin Inc(Characters); LastKey := M.WParam; end;
procedure TProbe.Timer(var M: TMessage);
begin
  KillTimer(Handle, M.WParam); Inc(Timers); PostQuitMessage(-37);
end;
procedure TProbe.Chain(var M: TMessage);
begin
  Inc(Chains);
  if not StopChain then Post(ChainMessage, 0, 0);
end;
begin
  LogLine('STEP explicit native task message loop');
  try
    A := TProbe.Create(nil); Loop := TNativeMessageLoop.Create;
    Peer := TNativeMessageLoop.Create; QuitLoop := TNativeMessageLoop.Create;
    A.Loop := Loop; A.PeerLoop := Peer;
    A.CreateHandle(0, 'Loop probe', WS_OVERLAPPEDWINDOW, 0, 0, 120, 80);
    Loop.ProcessMessages(100);
    Check(Loop.ProcessMessages(10) = 0, 'empty nonblocking pump returns without waiting');
    Rejected := False;
    try Loop.ProcessMessages(0); except on ENativeLoopError do Rejected := True; end;
    Check(Rejected, 'zero dispatch budget is rejected');
    Post(ProbeMessage, 0, 0); Post(ProbeMessage, 0, 0); Post(ProbeMessage, 0, 0);
    N := Loop.ProcessMessages(2);
    Check((N = 2) and (A.Calls = 2), 'bounded pump leaves excess queued messages untouched');
    Loop.ProcessMessages(100);
    Check(A.Calls = 3, 'next pump delivers remaining queued window message');
    Post(ReenterMessage, 0, 0); Post(ProbeMessage, 0, 0);
    Loop.ProcessMessages(100);
    Check((A.Rejections = 2) and (A.Calls = 4),
      'same and different object nested pumps cannot steal the task queue');
    Post(RaiseMessage, 0, 0); Post(ProbeMessage, 0, 0);
    Loop.ProcessMessages(100);
    Check((A.CallbackErrors = 1) and (A.LastCallbackError = 'queued callback failure') and
      (A.Calls = 5), 'native callback exception does not stop queued dispatch');
    Post(WM_KEYDOWN, Ord('A'), $001E0001); Post(WM_KEYUP, Ord('A'), LongInt($C01E0001));
    Loop.ProcessMessages(100);
    Check((A.Characters = 1) and ((A.LastKey = Ord('a')) or (A.LastKey = Ord('A'))),
      'TranslateMessage produces real ANSI character delivery');
    for I := 1 to 100 do
    begin Post(ProbeMessage, 0, 0); Loop.ProcessMessages(100); end;
    Check(A.Calls = 105, 'repeated pumping releases task queue ownership');
    Post(ChainMessage, 0, 0); N := Loop.ProcessMessages(7);
    Check((N = 7) and (A.Chains = 7),
      'self-posting callback cannot exceed the bounded dispatch budget');
    A.StopChain := True; Loop.ProcessMessages(100);
    Check(A.Chains = 8, 'self-posted remainder survives until the next explicit pump');
    if SetTimer(A.Handle, 42, 55, nil) = 0 then
      raise Exception.Create('Cannot schedule native wakeup timer');
    LogLine('PASS native timer scheduled for waiting loop');
    Check((Loop.Run = -37) and Loop.Terminated and (Loop.ExitCode = -37) and
      (A.Timers = 1), 'blocking loop wakes for timer and retains signed WM_QUIT exit code');
    Post(ProbeMessage, 0, 0);
    Check((Loop.ProcessMessages(100) = 0) and (Loop.Run = -37) and (A.Calls = 105),
      'terminated loop never consumes subsequent messages');
    Peer.ProcessMessages(100);
    Check(A.Calls = 106, 'finished loop releases queue ownership for explicit successor');
    Post(WM_CLOSE, 0, 0); Peer.ProcessMessages(100);
    Check((A.Handle = 0) and not Peer.Terminated,
      'closing one native window does not silently terminate the task loop');
    PostQuitMessage(123);
    Check((QuitLoop.ProcessMessages(100) = 0) and QuitLoop.Terminated and
      (QuitLoop.ExitCode = 123), 'nonblocking pump handles WM_QUIT without dispatch or counting');
    Check(not PeekMessage(QueueMessage, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE),
      'WM_QUIT is consumed once rather than reposted into task queue');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  A.Free; Loop.Free; Peer.Free; QuitLoop.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
