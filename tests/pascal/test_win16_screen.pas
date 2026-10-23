program ScreenTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Controls,
  native_application, native_form, native_screen;
type TTeardownProbe = class(TComponent)
  public destructor Destroy; override;
end;
var App, Peer: TNativeApplication; View: TNativeScreen;
  A, B, C, D, Lazy, NewModel, Unregistered, Candidate: TNativeForm;
  Outer, Inner: TCustomControl; Failed, Rejected, TeardownSeen: Boolean;
  I, PoolGDI, PoolUSER, Resolution: Integer; Display: HDC;
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
destructor TTeardownProbe.Destroy;
begin
  TeardownSeen := True;
  Check((View.FormCount = 0) and (View.ActiveForm = nil) and (View.ActiveControl = nil),
    'screen reads are empty during application teardown');
  inherited Destroy;
end;
procedure RaiseWindow(Form: TNativeForm);
begin
  BringWindowToTop(Form.Handle); SetActiveWindow(Form.Handle); Form.SetFocus;
end;
function NextCandidate: TNativeForm;
var Index: Integer; Form: TNativeForm;
begin
  Result := nil;
  { Retain the original TDesktop.NextForm's bottom-of-pack selection policy. }
  for Index := View.FormCount - 1 downto 0 do
  begin
    Form := View.Forms[Index];
    if Form.Visible and IsWindowEnabled(Form.Handle) and
      (Form <> View.ActiveForm) and (Form <> App.MainForm) then
    begin Result := Form; Exit; end;
  end;
end;
procedure Registry;
begin
  View := TNativeScreen.Create(nil);
  Check((View.FormCount = 0) and (View.ActiveForm = nil) and (View.ActiveControl = nil), 'unbound screen is empty');
  Rejected := False;
  try Candidate := View.Forms[0]; except on ENativeScreenError do Rejected := True; end;
  Check(Rejected, 'unbound index is rejected');
  App := TNativeApplication.Create(nil); Rejected := False;
  try View.Application := App; except on ENativeScreenError do Rejected := True; end;
  Check(Rejected and (View.Application = nil), 'uninitialized binding rejected');
  App.Initialize; View.Application := App; View.Application := App;
  App.CreateForm(TNativeForm, A); App.CreateForm(TNativeForm, B); App.CreateForm(TNativeForm, C);
  App.CreateForm(TNativeForm, D); App.CreateForm(TNativeForm, Lazy);
  A.SetBounds(10, 10, 170, 110); B.SetBounds(200, 10, 170, 110);
  C.SetBounds(10, 150, 170, 110); D.SetBounds(200, 150, 170, 110);
  Check((View.FormCount = 5) and (View.Forms[0] = A) and (View.Forms[4] = Lazy) and
    (A.Handle = 0) and (Lazy.Handle = 0), 'uncreated forms keep registration order without HWND allocation');
  Check((App.TaskHandle = GetCurrentTask) and not App.ShuttingDown, 'application task identity');
  Peer := TNativeApplication.Create(nil); Rejected := False;
  try View.Application := Peer; except on ENativeScreenError do Rejected := True; end;
  Check(Rejected and (View.Application = App) and (View.FormCount = 5), 'failed rebind preserves previous application');
  Peer.Free; Peer := nil;
  Rejected := False;
  try Candidate := View.Forms[-1]; except on ENativeScreenError do Rejected := True; end;
  Check(Rejected, 'negative screen index rejected');
  Rejected := False;
  try Candidate := View.Forms[5]; except on ENativeScreenError do Rejected := True; end;
  Check(Rejected, 'upper screen index rejected');
end;
procedure OrderingAndFocus;
begin
  Outer := TCustomControl.Create(A); Outer.Parent := A; Outer.SetBounds(5, 5, 130, 60);
  Inner := TCustomControl.Create(A); Inner.Parent := Outer; Inner.SetBounds(5, 5, 60, 25);
  A.Show; B.Show; C.Show; D.Show;
  RaiseWindow(D); RaiseWindow(C); RaiseWindow(B); RaiseWindow(A);
  Check((View.Forms[0] = A) and (View.Forms[1] = B) and (View.Forms[2] = C) and
    (View.Forms[3] = D) and (View.Forms[4] = Lazy), 'native front-to-back order precedes lazy models');
  RaiseWindow(B); Candidate := NextCandidate;
  Check(Candidate = D, 'bottom-of-pack cycle first'); RaiseWindow(Candidate);
  Candidate := NextCandidate; Check(Candidate = C, 'bottom-of-pack cycle second'); RaiseWindow(Candidate);
  Candidate := NextCandidate; Check(Candidate = B, 'bottom-of-pack cycle visits third form');
  RaiseWindow(A); Inner.SetFocus;
  Check((View.ActiveForm = A) and (View.ActiveControl = Inner), 'active form and deepest managed focus');
  A.SetFocus; Check(View.ActiveControl = nil, 'frame focus is not an active child');
  Inner.SetFocus; Inner.Enabled := False;
  Check(View.ActiveControl = nil, 'disabled focused child excluded'); Inner.Enabled := True;
  Inner.Parent := B; RaiseWindow(B); Inner.SetFocus;
  Check((View.ActiveForm = B) and (View.ActiveControl = Inner), 'reparented focus uses new native form');
  Inner.Free; Inner := nil; Check(View.ActiveControl = nil, 'freed focused control leaves no stale cache');
  Unregistered := TNativeForm.Create(nil); Unregistered.SetBounds(400, 20, 160, 100); Unregistered.Show;
  RaiseWindow(Unregistered);
  Check((View.ActiveForm = nil) and (View.ActiveControl = nil) and (View.FormCount = 5), 'unregistered active frame is not misidentified');
  Unregistered.Free; Unregistered := nil;
  RaiseWindow(A); A.Hide; Check(View.ActiveForm <> A, 'hidden form is not reported active'); A.Show;
  B.DestroyHandle;
  Check((View.Forms[3] = B) and (View.Forms[4] = Lazy), 'destroyed HWND returns to registration fallback');
  B.Show; RaiseWindow(B); Check(View.Forms[0] = B, 'recreated HWND returns to native front');
  App.UnregisterForm(C); Check(View.FormCount = 4, 'unregister changes screen count immediately');
  for I := 0 to View.FormCount - 1 do Check(View.Forms[I] <> C, 'unregistered form absent from ordered view');
  C.Free; C := nil;
  App.CreateForm(TNativeForm, NewModel);
  Check((View.FormCount = 5) and (View.Forms[4] = NewModel), 'late lazy form is appended');
  View.Application := nil;
  Check((View.FormCount = 0) and (View.ActiveForm = nil), 'detach does not retain active state');
  View.Application := App; RaiseWindow(B);
  Check((View.FormCount = 5) and (View.ActiveForm = B), 'rebind reads live application');
end;
procedure MetricsAndLifetime;
begin
  Display := GetDC(0);
  try Resolution := GetDeviceCaps(Display, LOGPIXELSY); finally ReleaseDC(0, Display); end;
  Check((View.Width = GetSystemMetrics(SM_CXSCREEN)) and (View.Height = GetSystemMetrics(SM_CYSCREEN)) and
    (View.PixelsPerInch = Resolution), 'screen metrics come from actual USER and GDI');
  PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES); PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
  for I := 1 to 50 do
  begin
    if View.PixelsPerInch <> Resolution then Failed := True;
    Candidate := View.Forms[0];
  end;
  Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2), 'repeated screen reads release DC and temporary list');
  TTeardownProbe.Create(App); App.Free; App := nil;
  A := nil; B := nil; D := nil; Lazy := nil; NewModel := nil; Outer := nil;
  Check(TeardownSeen and (View.Application = nil) and (View.FormCount = 0) and
    (View.ActiveForm = nil) and (View.ActiveControl = nil), 'screen outlives application without dangling binding');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native screen view');
  try Registry; OrderingAndFocus; MetricsAndLifetime;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  App.Free; App := nil; View.Free; View := nil; Unregistered.Free; Peer.Free;
  Check(StackGuardIntact, 'screen stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
