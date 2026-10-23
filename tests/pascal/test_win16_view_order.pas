program ViewOrderTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls,
  native_window, native_form, native_application, native_screen;
type TBlock = class(TGraphicControl)
  public
    Fill: TColor; GuardOrder: Boolean; Guards: Integer;
    procedure Paint; override;
end;
var App: TNativeApplication; View: TNativeScreen; A, B, C, Lazy: TNativeForm;
  Red, Blue, Orphan: TBlock; Failed: Boolean; I, PoolGDI, PoolUSER: Integer; FocusBefore: HWND;
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
procedure TBlock.Paint;
begin
  if GuardOrder then
  begin
    try BringToFront; except on ENativeWindowError do Inc(Guards); end;
    try SendToBack; except on ENativeWindowError do Inc(Guards); end;
  end;
  Canvas.Brush.Color := Fill; Canvas.FillRect(Rect(0, 0, Width, Height));
end;
function Pixel: TColor;
var DC: HDC;
begin
  DC := GetDC(A.Handle);
  if DC = 0 then raise Exception.Create('DC');
  try Result := WinProcs.GetPixel(DC, 25, 25); finally ReleaseDC(A.Handle, DC); end;
end;
function NextCandidate: TNativeForm;
var Index: Integer; Form: TNativeForm;
begin
  Result := nil;
  for Index := View.FormCount - 1 downto 0 do
  begin
    Form := View.Forms[Index];
    if Form.Visible and Form.Enabled and (Form <> View.ActiveForm) and (Form <> App.MainForm) then
      begin Result := Form; Exit; end;
  end;
end;
procedure ScreenCases;
begin
  App := TNativeApplication.Create(nil); App.Initialize; View := TNativeScreen.Create(nil); View.Application := App;
  App.CreateForm(TNativeForm, A); A.SetBounds(10, 10, 180, 120);
  App.CreateForm(TNativeForm, B); B.SetBounds(220, 10, 180, 120);
  App.CreateForm(TNativeForm, C); C.SetBounds(430, 10, 180, 120);
  App.CreateForm(TNativeForm, Lazy);
  A.Show; B.Show; C.Show; A.BringToFront; A.SetFocus;
  Check((View.Forms[0] = A) and (View.ActiveForm = A) and (View.Forms[3] = Lazy),
    'native form method updates live screen order and active view');
  Check(NextCandidate = B, 'bottom-of-pack selection starts with oldest peer');
  NextCandidate.BringToFront;
  Check((View.Forms[0] = B) and (View.ActiveForm = B) and (NextCandidate = C),
    'original NextForm policy advances through actual BringToFront method');
  NextCandidate.BringToFront;
  Check((View.ActiveForm = C) and (NextCandidate = B), 'next peer cycles without changing main-form policy');
  FocusBefore := GetActiveWindow; B.SendToBack;
  Check((View.Forms[2] = B) and (GetActiveWindow = FocusBefore), 'SendToBack is visible to screen without activation');
  Lazy.BringToFront; Check((Lazy.Handle = 0) and (View.Forms[3] = Lazy), 'lazy raise leaves screen fallback unallocated');
end;
procedure GraphicCases;
begin
  Orphan := TBlock.Create(nil); Orphan.BringToFront; Orphan.SendToBack;
  Red := TBlock.Create(A); Red.Fill := clRed; Red.Parent := A; Red.SetBounds(10, 10, 50, 50);
  Blue := TBlock.Create(A); Blue.Fill := clBlue; Blue.Parent := A; Blue.SetBounds(15, 15, 50, 50);
  A.BringToFront; A.SetFocus; FocusBefore := GetFocus; A.Repaint;
  Check(Pixel = clBlue, 'last graphic child initially covers overlap');
  Red.BringToFront; A.Update; Check(Pixel = clRed, 'graphic BringToFront changes actual overlap pixels');
  Red.SendToBack; A.Update; Check(Pixel = clBlue, 'graphic SendToBack restores overlap pixels');
  Blue.Hide; A.Update; Check(Pixel = clRed, 'hidden top graphic exposes lower sibling'); Blue.Show;
  Blue.GuardOrder := True; A.Repaint; Blue.GuardOrder := False;
  Check((Blue.Guards >= 2) and (A.CallbackErrors = 0), 'graphic paint cannot mutate composition order');
  PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES); PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
  for I := 1 to 30 do begin Red.BringToFront; A.Update; Red.SendToBack; A.Update; end;
  A.Update;
  Check((GetWindow(A.Handle, GW_CHILD) = 0) and (GetFocus = FocusBefore) and (Pixel = clBlue),
    'repeated graphic order changes allocate no HWND and preserve focus');
  Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2) and
    (A.Canvas.Handle = 0) and (Red.Canvas.Handle = 0) and (Blue.Canvas.Handle = 0),
    'repeated reordering and composition retain GDI USER pools and DC cleanup');
  A.DestroyHandle; A.Show; A.BringToFront; A.Repaint;
  Check(Pixel = clBlue, 'graphic model order survives parent HWND recreation');
  Red.BringToFront; A.Update; Check(Pixel = clRed, 'graphic order still mutable after recreation');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native screen and windowless view order');
  try ScreenCases; GraphicCases;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Orphan.Free; View.Free; App.Free;
  Check(StackGuardIntact, 'view order stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
