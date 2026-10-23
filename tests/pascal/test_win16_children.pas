program MixedChildrenTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Graphics, Controls,
  native_window, native_form;
type
  TTile = class(TGraphicControl)
  public
    FillColor: TColor;
    procedure Paint; override;
  end;
  TReject = class(TCustomControl)
  public
    RejectCreate, Inspect, Observed: Boolean;
    Source, Target: TCustomControl;
    Before, After: TControl;
    ExpectedTarget: Integer;
    procedure WndProc(var M: TMessage); override;
  end;
  TD = object
    Armed, Observed: Boolean;
    Exits, Shows, Hides: Integer;
    procedure Exited(Sender: TObject);
    procedure Shown(Sender: TObject);
    procedure Hidden(Sender: TObject);
    procedure Drawing(Sender: TObject);
  end;
var A, B, First, Second: TCustomControl; Red, Green: TTile;
  Raw: TNativeWindow; Form: TNativeForm; Driver: TD;
  Failed, Rejected: Boolean; I, PoolGDI, PoolUSER: Integer; C: TControl;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10;
  _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TTile.Paint;
begin Canvas.Brush.Color := FillColor; Canvas.FillRect(ClientRect); end;
procedure TReject.WndProc(var M: TMessage);
begin
  if M.Msg = WM_CREATE then
  begin
    if Inspect then
      Observed := (Source.ControlCount = 2) and (Source.Controls[0] = Before) and
        (Source.Controls[1] = After) and (Target.ControlCount = ExpectedTarget) and
        (Target.Controls[ExpectedTarget - 1] = Self);
    if RejectCreate then raise Exception.Create('Reject mixed child');
  end;
  inherited WndProc(M);
end;
procedure TD.Exited(Sender: TObject);
begin
  if not Armed then Exit;
  Inc(Exits);
  Observed := (A.ControlCount = 4) and (B.ControlCount = 0) and
    (A.Controls[0] = First) and (First.Parent = A);
end;
procedure TD.Shown(Sender: TObject);
begin Inc(Shows); end;
procedure TD.Hidden(Sender: TObject);
begin Inc(Hides); end;
procedure TD.Drawing(Sender: TObject);
begin Red.Parent := B; end;
procedure Root(Window: TCustomControl; X: Integer);
begin
  Window.Color := clWhite;
  Window.CreateHandle(0, 'Mixed children', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN,
    X, 20, 220, 140);
end;
function Pixel: TColor;
var DC: HDC;
begin
  DC := GetDC(A.Handle);
  if DC = 0 then raise Exception.Create('Pixel DC');
  try Result := GetPixel(DC, 12, 12); finally ReleaseDC(A.Handle, DC); end;
end;
procedure BasicCases;
begin
  A := TCustomControl.Create(nil); B := TCustomControl.Create(nil);
  First := TCustomControl.Create(nil); First.SetBounds(80, 50, 40, 20); First.Parent := A;
  Red := TTile.Create(B); Red.FillColor := clRed; Red.SetBounds(8, 8, 24, 20); Red.Parent := A;
  Second := TCustomControl.Create(nil); Second.SetBounds(130, 50, 40, 20); Second.Parent := A;
  Green := TTile.Create(A); Green.FillColor := clLime; Green.SetBounds(8, 8, 24, 20); Green.Parent := A;
  TComponent.Create(A);
  Check((A.ControlCount = 4) and (A.Controls[0] = First) and (A.Controls[1] = Red) and
    (A.Controls[2] = Second) and (A.Controls[3] = Green) and (First.Handle = 0),
    'mixed attachment order includes real handleless children but not owners components');
  Check((A.Controls[1] is TTile) and (A.Controls[0] is TCustomControl) and
    not (A.Controls[1] is TCustomControl), 'typed enumeration preserves actual object identity and ancestry');
  Root(A, 20); Root(B, 270);
  Raw := TNativeWindow.Create(A);
  Raw.CreateHandle(A.Handle, '', WS_CHILD or WS_VISIBLE, 180, 80, 15, 15);
  Check((A.ControlCount = 4) and (A.ComponentCount = 3) and (B.ComponentCount = 1),
    'raw child HWNDs and nonvisual owned components are not managed visual members');
  Rejected := False;
  try C := A.Controls[-1]; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'negative child index rejects');
  Rejected := False;
  try C := A.Controls[A.ControlCount]; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (A.ControlCount = 4), 'past-end child index rejects without mutation');
  Second.TabOrder := 0; First.BringToFront; Red.Parent := A;
  Check((A.Controls[0] = First) and (A.Controls[1] = Red) and (A.Controls[2] = Second) and
    (A.Controls[3] = Green), 'tab native z order and same-parent writes preserve enumeration order');
  C := Red; C.BringToFront; A.Repaint;
  Check(Pixel = clRed, 'common control BringToFront reaches real graphic composition');
  C.SendToBack; A.Repaint; Check(Pixel = clLime, 'common control SendToBack reaches graphic composition');
  C := Green; C.Hide; A.Repaint;
  Check(not C.Visible and (Pixel = clRed), 'common graphic Hide updates local state and pixels');
  C.Show; C.Enabled := False; A.Repaint;
  Check(C.Visible and not C.Enabled and (Pixel = clLime), 'common graphic Enabled does not hide custom painting');
  C.Visible := False; Check(not Green.Visible, 'common visible property reaches graphic policy');
  C.Visible := True; C.Enabled := True;
  C := First; C.Enabled := False;
  Check(not C.Enabled and not IsWindowEnabled(First.Handle), 'common native Enabled reaches USER');
  C.Enabled := True; C.Hide;
  Check(not C.Visible and not First.Visible, 'common native Hide reaches managed view policy');
  C.Show; C.Visible := False; C.Visible := True;
  Check(C.Visible and C.Enabled, 'common native properties retain live USER state');
  for I := 0 to A.ControlCount - 1 do A.Controls[I].Enabled := False;
  Check(not First.Enabled and not Second.Enabled and not Red.Enabled and not Green.Enabled,
    'original indexed Enabled loop applies to both native and graphic children');
  for I := 0 to A.ControlCount - 1 do A.Controls[I].Enabled := True;
  Check(First.Enabled and Second.Enabled and Red.Enabled and Green.Enabled,
    'mixed indexed Enabled loop restores every child');
  C := Raw; C.Enabled := False; C.Hide;
  Check(not C.Enabled and not C.Visible, 'common raw-window operations use actual HWND state');
  C.Enabled := True; C.Show; C.BringToFront; C.SendToBack;
  Raw.DestroyHandle; Rejected := False;
  try C.Show; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Raw.Handle = 0), 'handleless raw-window operation rejects without fabrication');
  First.OnExit := Driver.Exited; SetActiveWindow(A.Handle); First.SetFocus;
  Driver.Armed := True; First.Parent := B; Driver.Armed := False;
  Check((Driver.Exits = 1) and Driver.Observed and (A.ControlCount = 3) and
    (B.ControlCount = 1) and (B.Controls[0] = First),
    'focus callback cannot see provisional membership before model parent changes');
  First.Parent := A;
  Check((A.Controls[3] = First) and (B.ControlCount = 0), 'successful reattachment appends exactly once');
  Rejected := False;
  try A.DrawNow(Driver.Drawing); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (A.ControlCount = 4) and (B.ControlCount = 0) and
    (Red.Parent = A) and (A.Canvas.Handle = 0), 'direct drawing rejects reparent without list or DC damage');
  A.DestroyHandle;
  Check((A.ControlCount = 4) and (First.Handle = 0) and (A.Controls[3] = First),
    'native destruction preserves mixed model membership and order');
  Root(A, 20); A.Repaint;
  Check((First.Handle <> 0) and (A.ControlCount = 4) and (Pixel = clLime),
    'recreated HWND tree restores rendering without duplicating mixed members');
end;
procedure FailureCases;
var Lazy: TCustomControl; Before, After: TTile; Bad: TReject; Count: Integer;
begin
  Lazy := nil; Before := nil; After := nil; Bad := nil;
  try
    Lazy := TCustomControl.Create(nil);
    Before := TTile.Create(nil); Before.Parent := Lazy;
    Bad := TReject.Create(nil); Bad.SetBounds(50, 50, 30, 20); Bad.Parent := Lazy;
    After := TTile.Create(nil); After.Parent := Lazy;
    Count := B.ControlCount; Bad.Source := Lazy; Bad.Target := B;
    Bad.Before := Before; Bad.After := After; Bad.ExpectedTarget := Count + 1;
    Bad.Inspect := True; Bad.RejectCreate := True; Rejected := False;
    try Bad.Parent := B; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and Bad.Observed and (Bad.Parent = Lazy) and (Bad.Handle = 0) and
      (Lazy.ControlCount = 3) and (Lazy.Controls[1] = Bad) and (B.ControlCount = Count),
      'failed creation restores old mixed position after callback-visible model transition');
    Bad.RejectCreate := False; Bad.Parent := B;
    Check((Lazy.ControlCount = 2) and (B.ControlCount = Count + 1) and
      (B.Controls[Count] = Bad), 'failed child can retry without stale or duplicate membership');
    Bad.Inspect := False; Bad.Parent := Lazy; Bad.RejectCreate := True; Rejected := False;
    try Root(Lazy, 520); except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Lazy.Handle = 0) and (Bad.Handle = 0) and
      (Lazy.ControlCount = 3) and (Lazy.Controls[2] = Bad),
      'deferred HWND creation failure retains all mixed model children');
    Bad.RejectCreate := False; Root(Lazy, 520);
    Check((Bad.Handle <> 0) and (Lazy.ControlCount = 3), 'deferred mixed tree retries after native failure');
    Lazy.Free; Lazy := nil;
    Check((Bad.Parent = nil) and (Before.Parent = nil) and (After.Parent = nil),
      'parent teardown detaches independently owned mixed children');
  finally Bad.Free; Before.Free; After.Free; Lazy.Free; end;
end;
procedure LifetimeCases;
var Host, Owner: TCustomControl; Window: TCustomControl; Graphic: TTile;
begin
  Host := TCustomControl.Create(nil); Owner := TCustomControl.Create(nil);
  try
    Window := TCustomControl.Create(Owner); Window.Parent := Host;
    Graphic := TTile.Create(Owner); Graphic.Parent := Host;
    TComponent.Create(Host);
    Check((Host.ControlCount = 2) and (Host.ComponentCount = 1) and (Owner.ComponentCount = 2),
      'visual parent and component owner remain independent');
    while Host.ControlCount > 0 do Host.Controls[0].Free;
    Check((Host.ControlCount = 0) and (Host.ComponentCount = 1) and (Owner.ComponentCount = 0),
      'original Controls zero Free loop removes both kinds without skipping or double freeing');
  finally Host.Free; Owner.Free; end;
end;
procedure FormCases;
begin
  Form := TNativeForm.Create(nil); Form.OnShow := Driver.Shown; Form.OnHide := Driver.Hidden;
  C := Form; C.Show; C.Show;
  Check((Form.Handle <> 0) and C.Visible and (Driver.Shows = 1), 'common control Show preserves lazy form lifecycle');
  C.Hide; C.Hide;
  Check(not C.Visible and (Driver.Hides = 1), 'common control Hide preserves form lifecycle');
end;
begin
  FillChar(StackBottom^, 64, $A5); FillChar(Driver, SizeOf(Driver), 0);
  LogLine('STEP real mixed control children');
  try
    BasicCases; FailureCases; LifetimeCases; FormCases;
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 100 do begin Red.Parent := B; Red.Parent := A; A.Repaint; end;
    Check((A.ControlCount = 4) and (A.Controls[3] = Red) and (B.ControlCount = 0) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2),
      'mixed reparent cycles retain membership and GDI USER pools');
    Check((A.CallbackErrors = 0) and (B.CallbackErrors = 0) and
      (Red.Canvas.Handle = 0) and (Green.Canvas.Handle = 0), 'mixed operations leave no callback or canvas damage');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'mixed children stack boundary');
  First.Free; Second.Free; Red.Free; Green.Free; Raw.Free; Form.Free; A.Free; B.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
