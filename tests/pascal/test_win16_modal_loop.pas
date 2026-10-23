program TestWin16ModalLoop;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, native_window, native_loop;
const Sentinel = WM_USER + 131;
type
  TProbe = class(TNativeWindow)
  public
    Mode, Checks, Filters, Sentinels: Integer;
    Outer, Peer: TNativeMessageLoop;
    function ContinueOuter: Boolean;
    function ContinuePeer: Boolean;
    function Filter(var M: TMsg): Boolean;
    procedure Seen(var M: TMessage); message Sentinel;
  end;
var Probe: TProbe; Loop, Peer, Successor: TNativeMessageLoop;
  Failed, Rejected: Boolean; I: Integer;
procedure LogLine(const Text: string);
var F: HFILE; Line: string; Data: array[0..255] of Char;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Data, Line);
  _lwrite(F, @Data, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
function TProbe.ContinueOuter: Boolean;
begin
  Inc(Checks); Result := False;
  case Mode of
    1: raise Exception.Create('condition failure');
    2: begin
      Peer.RunModal(ContinuePeer);
      PostMessage(Handle, Sentinel, 0, 0);
      Result := True;
    end;
  end;
end;
function TProbe.ContinuePeer: Boolean;
begin PostQuitMessage(-31); Result := True; end;
function TProbe.Filter(var M: TMsg): Boolean;
begin Inc(Filters); Result := False; end;
procedure TProbe.Seen(var M: TMessage);
begin Inc(Sentinels); end;
begin
  LogLine('STEP modal loop edges');
  try
    Probe := TProbe.Create(nil); Probe.CreateHandle(0, 'Pump', WS_POPUP, 0, 0, 10, 10);
    Loop := TNativeMessageLoop.Create; Peer := TNativeMessageLoop.Create;
    Successor := TNativeMessageLoop.Create; Probe.Outer := Loop; Probe.Peer := Peer;
    Loop.ProcessMessages(100); Rejected := False;
    try Loop.RunModal(nil); except on ENativeLoopError do Rejected := True; end;
    Check(Rejected, 'nil condition rejected');
    PostMessage(Probe.Handle, Sentinel, 0, 0);
    Check((Loop.RunModal(Probe.ContinueOuter) = 0) and (Probe.Sentinels = 0),
      'false condition does not dequeue');
    Loop.ProcessMessages(100); Check(Probe.Sentinels = 1, 'queued message survives');
    Probe.Mode := 1; Rejected := False;
    try Loop.RunModal(Probe.ContinueOuter); except on Exception do Rejected := True; end;
    Loop.ProcessMessages(100); Peer.ProcessMessages(100);
    Check(Rejected, 'condition exception releases pump');
    Probe.Mode := 2; Loop.OnMessage := Probe.Filter;
    Check((Loop.RunModal(Probe.ContinueOuter) = -31) and Loop.Terminated and
      Peer.Terminated and (Probe.Filters = 0) and (Probe.Sentinels = 1),
      'condition quit stops before GetMessage');
    I := Probe.Checks; Loop.RunModal(Probe.ContinueOuter);
    Check(Probe.Checks = I, 'terminated modal pump stays sticky');
    Successor.ProcessMessages(100);
    Check((Probe.Sentinels = 2) and not Successor.Terminated, 'successor sees no reposted quit');
    Loop.OnMessage := nil;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Loop <> nil then Loop.OnMessage := nil;
  Probe.Free; Loop.Free; Peer.Free; Successor.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
