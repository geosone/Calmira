program TestWin16Window;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,4096}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, native_window;
const ProbeMessage = WM_USER + 71; NestedMessage = WM_USER + 72;
  RaiseMessage = WM_USER + 73;
type
  TProbe = class(TNativeWindow)
  public
    Calls, Creates, Destroys: Integer;
    RejectCreate, RejectNC, RaiseDestroy, BoundAtCreate, SpawnPeer: Boolean;
    Peer: TProbe;
    procedure Probe(var M: TMessage); message ProbeMessage;
    procedure Nested(var M: TMessage); message NestedMessage;
    procedure RaiseProbe(var M: TMessage); message RaiseMessage;
    procedure CreateProbe(var M: TMessage); message WM_CREATE;
    procedure NCProbe(var M: TMessage); message WM_NCCREATE;
    procedure DestroyProbe(var M: TMessage); message WM_NCDESTROY;
  end;
var Failed, Rejected: Boolean; A, B, Child, Owned: TProbe; Owner: TComponent;
  Raw, ChildRaw: HWND; I, PoolBefore: Integer;
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
procedure TProbe.Probe(var M: TMessage);
begin Inc(Calls); M.Result := LongInt(M.WParam) * 30000 + M.LParam; end;
procedure TProbe.Nested(var M: TMessage);
begin M.Result := Peer.Perform(ProbeMessage, $FFFF, -1234567); end;
procedure TProbe.RaiseProbe(var M: TMessage);
begin raise Exception.Create('callback test exception'); end;
procedure TProbe.CreateProbe(var M: TMessage);
begin
  Inc(Creates); BoundAtCreate := (Handle <> 0) and IsWindow(Handle);
  if RejectCreate then raise Exception.Create('create rejected');
  if SpawnPeer then Peer.CreateHandle(Handle, 'Nested child', WS_CHILD, 0, 0, 20, 20);
  inherited DefaultHandler(M);
end;
procedure TProbe.NCProbe(var M: TMessage);
begin
  if RejectNC then raise Exception.Create('nonclient create rejected');
  inherited DefaultHandler(M);
end;
procedure TProbe.DestroyProbe(var M: TMessage);
begin
  Inc(Destroys);
  if RaiseDestroy then raise Exception.Create('destroy callback exception');
  inherited DefaultHandler(M);
end;
procedure CreateProbeWindow(Probe: TProbe);
begin Probe.CreateHandle(0, 'Native dispatch probe', WS_OVERLAPPEDWINDOW, 0, 0, 100, 80); end;
begin
  LogLine('STEP native window ownership and callback dispatch');
  try
    A := TProbe.Create(nil); B := TProbe.Create(nil); Child := TProbe.Create(nil);
    CreateProbeWindow(A); CreateProbeWindow(B); A.Peer := B;
    Check((A.Handle <> 0) and (A.Handle <> B.Handle) and A.BoundAtCreate and
      (A.Creates = 1), 'separate windows bind objects before WM_CREATE');
    Check(A.Perform(ProbeMessage, 1234, -7654321) = 29365679,
      'native message directive preserves nonzero WPARAM and signed result');
    Check((A.Calls = 1) and (B.Calls = 0), 'window association isolates receiver instances');
    Check(A.Perform(ProbeMessage, 0, -7654321) = -7654321,
      'negative 32-bit handler result survives native callback return');
    Check((A.Perform(NestedMessage, 0, 0) = 1964815433) and (B.Calls = 1),
      'nested SendMessage dispatch targets peer instance');
    Check(A.Perform(WM_GETTEXTLENGTH, 0, 0) = 21, 'unhandled messages reach DefWindowProc');
    Check((A.Perform(RaiseMessage, 0, 0) = 0) and (A.CallbackErrors = 1) and
      (A.LastCallbackError = 'callback test exception'), 'callback exceptions are recorded without unwinding USER');
    Check(A.Perform(ProbeMessage, 1, 7) = 30007, 'dispatch remains usable after callback exception');
    A.ClearCallbackError;
    Check((A.CallbackErrors = 0) and (A.LastCallbackError = ''), 'callback error state can be reset explicitly');
    Raw := A.Handle; Rejected := False;
    try CreateProbeWindow(A); except on Exception do Rejected := True; end;
    Check(Rejected and (A.Handle = Raw), 'duplicate creation preserves existing window');
    Child.CreateHandle(A.Handle, 'Child', WS_CHILD, 0, 0, 20, 20); ChildRaw := Child.Handle;
    Check(GetParent(ChildRaw) = A.Handle, 'child uses actual native parent');
    A.DestroyHandle;
    Check((A.Handle = 0) and (Child.Handle = 0) and not IsWindow(Raw) and
      not IsWindow(ChildRaw), 'parent destruction detaches parent and child objects');
    Check((A.Destroys = 1) and (Child.Destroys = 1), 'normal NC destruction dispatches once');
    A.DestroyHandle; A.Peer := Child; A.SpawnPeer := True; CreateProbeWindow(A);
    Check(Child.BoundAtCreate and (Child.Handle <> A.Handle) and
      (GetParent(Child.Handle) = A.Handle), 'reentrant creation binds child without replacing parent receiver');
    A.SpawnPeer := False; A.DestroyHandle; CreateProbeWindow(A);
    Check(A.Handle <> 0, 'detached object can recreate its window');
    A.RaiseDestroy := True; A.DestroyHandle;
    Check((A.Handle = 0) and (A.CallbackErrors = 1), 'NC destroy exception still clears handle association');
    A.RaiseDestroy := False; A.RejectCreate := True; Rejected := False;
    try CreateProbeWindow(A); except on Exception do Rejected := True; end;
    Check(Rejected and (A.Handle = 0), 'WM_CREATE exception aborts creation without stale handle');
    A.RejectCreate := False; A.RejectNC := True; Rejected := False;
    try CreateProbeWindow(A); except on Exception do Rejected := True; end;
    Check(Rejected and (A.Handle = 0), 'WM_NCCREATE exception aborts creation without stale handle');
    A.RejectNC := False;
    Rejected := False;
    try A.CreateHandle(0, 'No parent', WS_CHILD, 0, 0, 20, 20);
    except on Exception do Rejected := True; end;
    Check(Rejected and (A.Handle = 0), 'child without parent is rejected before native creation');
    Rejected := False;
    try A.CreateHandle(0, 'Negative size', WS_OVERLAPPEDWINDOW, 0, 0, -1, 20);
    except on Exception do Rejected := True; end;
    Check(Rejected and (A.Handle = 0), 'negative size is rejected before native creation');
    Rejected := False;
    try A.CreateHandle(0, 'Bad'#0'caption', WS_OVERLAPPEDWINDOW, 0, 0, 20, 20);
    except on Exception do Rejected := True; end;
    Check(Rejected and (A.Handle = 0), 'embedded NUL caption is rejected without truncation');
    Rejected := False;
    try A.Perform(ProbeMessage, 0, 0); except on Exception do Rejected := True; end;
    Check(Rejected, 'Perform rejects detached objects');
    CreateProbeWindow(A); A.Perform(WM_CLOSE, 0, 0);
    Check(A.Handle = 0, 'default WM_CLOSE destroys and detaches the window');
    Owner := TComponent.Create(nil); Owned := TProbe.Create(Owner); CreateProbeWindow(Owned);
    Raw := Owned.Handle; Owner.Free; Owner := nil; Owned := nil;
    Check(not IsWindow(Raw), 'component owner frees its native windows');
    PoolBefore := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 150 do begin CreateProbeWindow(A); A.DestroyHandle; end;
    for I := 1 to 50 do
    begin
      A.RejectNC := True;
      try CreateProbeWindow(A); except on Exception do ; end;
      A.RejectNC := False; A.RejectCreate := True;
      try CreateProbeWindow(A); except on Exception do ; end;
      A.RejectCreate := False;
    end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolBefore - 2,
      'successful and rejected creation cycles do not drain USER pool');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  A.Free; B.Free; Child.Free; Owner.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
