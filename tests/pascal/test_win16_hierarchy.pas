program TestWin16Hierarchy;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Graphics, Controls;
type
  TRejectControl = class(TCustomControl)
  public
    RejectCreate: Boolean;
    procedure WndProc(var M: TMessage); override;
    procedure ChangeDuringDraw(Sender: TObject);
  end;
var A, B, Child, Grand, Deferred: TCustomControl; Bad: TRejectControl;
  Failed, Rejected: Boolean; Raw, GrandRaw: HWND; Area: TRect;
  Origin: TPoint; I, Pool: Integer;
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
procedure TRejectControl.WndProc(var M: TMessage);
begin
  if (M.Msg = WM_CREATE) and RejectCreate then raise Exception.Create('reject hierarchy creation');
  inherited WndProc(M);
end;
procedure TRejectControl.ChangeDuringDraw(Sender: TObject);
begin Left := Left + 1; end;
procedure CreateRoot(Window: TCustomControl; X: SmallInt);
begin Window.CreateHandle(0, 'Control hierarchy', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN,
  X, 20, 160, 120); end;
begin
  LogLine('STEP managed window hierarchy and bounds');
  try
    A := TCustomControl.Create(nil); B := TCustomControl.Create(nil);
    Child := TCustomControl.Create(nil); Grand := TCustomControl.Create(nil);
    Child.SetBounds(12, 14, 60, 50); Grand.SetBounds(3, 4, 20, 16);
    Grand.Parent := Child; Child.Parent := A;
    Check((Child.Handle = 0) and (Grand.Handle = 0), 'uncreated parent keeps descendants model-only');
    CreateRoot(A, 20);
    B.CreateHandle(0, 'Bordered parent', WS_OVERLAPPEDWINDOW or WS_VISIBLE or WS_CLIPCHILDREN,
      220, 20, 160, 120);
    Area := B.ClientRect;
    Check((B.Width = 160) and (B.Height = 120) and (Area.Right < 160) and (Area.Bottom < 120),
      'decorated window distinguishes outer dimensions from client area');
    Check((GetParent(Child.Handle) = A.Handle) and (GetParent(Grand.Handle) = Child.Handle),
      'parent creation recursively creates managed descendant HWNDs');
    GetWindowRect(Child.Handle, Area); Origin.X := Area.Left; Origin.Y := Area.Top;
    ScreenToClient(A.Handle, Origin);
    Check((Origin.X = 12) and (Origin.Y = 14) and (Child.Width = 60) and (Child.Height = 50),
      'stored control bounds map to actual parent client coordinates');
    Child.BoundsRect := Rect(20, 22, 90, 78); Area := Child.BoundsRect;
    Check((Area.Left = 20) and (Area.Top = 22) and (Area.Right = 90) and (Area.Bottom = 78),
      'BoundsRect applies position and size together');
    SetWindowPos(Child.Handle, 0, 24, 26, 72, 58, SWP_NOZORDER or SWP_NOACTIVATE);
    Check((Child.Left = 24) and (Child.Top = 26) and (Child.Width = 72) and (Child.Height = 58),
      'external USER move and resize update cached model bounds');
    Area := Child.ClientRect;
    Check((Area.Left = 0) and (Area.Top = 0) and (Area.Right = 72) and (Area.Bottom = 58),
      'ClientRect is separate from parent-relative outer bounds');
    Raw := Child.Handle; GrandRaw := Grand.Handle;
    SetActiveWindow(A.Handle); Grand.SetFocus; Grand.MouseCapture := True;
    Child.Parent := B;
    Check((Child.Handle = Raw) and (Grand.Handle = GrandRaw) and (GetParent(Raw) = B.Handle) and
      (Child.Parent = B), 'live reparent preserves child and descendant handles');
    Check((GetCapture <> GrandRaw) and (GetFocus <> GrandRaw), 'reparent releases focus and capture in moved subtree');
    GetWindowRect(Child.Handle, Area); Origin.X := Area.Left; Origin.Y := Area.Top;
    ScreenToClient(B.Handle, Origin);
    Check((Origin.X = 24) and (Origin.Y = 26), 'reparent retains requested new-parent client position');
    Rejected := False;
    try B.Parent := Grand; except on Exception do Rejected := True; end;
    Check(Rejected and (B.Parent = nil), 'descendant parent cycle is rejected before native change');
    Rejected := False;
    try Child.Parent := Child; except on Exception do Rejected := True; end;
    Check(Rejected and (Child.Parent = B) and (Child.Handle = Raw), 'self-parent assignment preserves live hierarchy');
    Rejected := False;
    try Child.SetBounds(32760, 0, 20, 20); except on Exception do Rejected := True; end;
    Check(Rejected and (Child.Left = 24), 'overflow bounds fail without moving native control');
    Child.Parent := nil;
    Check((Child.Handle = 0) and (Grand.Handle = 0) and (Grand.Parent = Child) and
      (Child.Width = 72) and (Child.Left = 24) and (Child.Top = 26) and
      (Grand.Left = 3) and (Grand.Top = 4),
      'detaching destroys HWND subtree but retains descendant objects and bounds');
    Child.Parent := A;
    Check((GetParent(Child.Handle) = A.Handle) and (Grand.Handle <> 0), 'reattaching recreates the managed HWND subtree');
    A.DestroyHandle;
    Check((Child.Handle = 0) and (Child.Parent = A), 'native parent destruction preserves object parenting');
    CreateRoot(A, 20);
    Check((Child.Handle <> 0) and (Grand.Handle <> 0) and (Child.Left = 24) and
      (Child.Top = 26) and (Grand.Left = 3) and (Grand.Top = 4),
      'recreating parent restores its managed descendants');
    Bad := TRejectControl.Create(nil); Bad.SetBounds(100, 0, 30, 30); Bad.RejectCreate := True;
    Rejected := False;
    try Bad.Parent := A; except on Exception do Rejected := True; end;
    Check(Rejected and (Bad.Parent = nil) and (Bad.Handle = 0), 'failed auto-creation rolls back object parent membership');
    Bad.RejectCreate := False; Bad.Parent := A;
    Rejected := False;
    try Bad.DrawNow(Bad.ChangeDuringDraw); except on Exception do Rejected := True; end;
    Check(Rejected and (Bad.Left = 100) and (Bad.Canvas.Handle = 0), 'bounds mutation during direct drawing is rejected after clean scope exit');
    Bad.Parent := nil;
    Deferred := TCustomControl.Create(nil); Bad.RejectCreate := True; Bad.Parent := Deferred;
    Rejected := False;
    try CreateRoot(Deferred, 400); except on Exception do Rejected := True; end;
    Check(Rejected and (Deferred.Handle = 0) and (Bad.Handle = 0) and (Bad.Parent = Deferred),
      'failed deferred descendant creation destroys partial HWND tree but preserves model');
    Bad.RejectCreate := False; CreateRoot(Deferred, 400);
    Check(Bad.Handle <> 0, 'deferred hierarchy can retry after creation failure');
    Pool := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 100 do begin Child.Parent := B; Child.Parent := A; end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= Pool - 2, 'reparent cycles do not drain USER pool');
    A.Free; A := nil;
    Check((Child.Parent = nil) and (Child.Handle = 0) and (Grand.Parent = Child),
      'freeing parent detaches independently owned child objects');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Bad.Free; Grand.Free; Child.Free; A.Free; B.Free; Deferred.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
