program CoordinateTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Graphics, Controls, native_window;
type
  TBlock = class(TGraphicControl)
  public
    BoundsCalls, PaintGuards: Integer;
    TestPaint: Boolean;
    procedure SetBounds(X, Y, AWidth, AHeight: Integer); override;
    procedure Paint; override;
  end;
var A, B, Panel, Lazy: TCustomControl; Block: TBlock;
  Failed, Rejected: Boolean; P, Q, Origin: TPoint; Area, Before: TRect;
  FocusBefore, CaptureBefore: HWND; I: Integer;
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
function SamePoint(const L, R: TPoint): Boolean;
begin Result := (L.X = R.X) and (L.Y = R.Y); end;
procedure TBlock.SetBounds(X, Y, AWidth, AHeight: Integer);
begin Inc(BoundsCalls); inherited SetBounds(X, Y, AWidth, AHeight); end;
procedure TBlock.Paint;
var R: TRect;
begin
  if not TestPaint then Exit;
  R := BoundsRect; Inc(R.Right);
  try BoundsRect := R; except on ENativeWindowError do Inc(PaintGuards); end;
  P := ClientToScreen(Point(2, 3)); Q := ScreenToClient(P);
  Check(SamePoint(Q, Point(2, 3)), 'coordinate queries remain safe inside graphic paint');
end;
procedure NativeCases;
begin
  A := TCustomControl.Create(nil); B := TCustomControl.Create(nil);
  Lazy := TCustomControl.Create(nil); Panel := TCustomControl.Create(nil);
  Block := TBlock.Create(nil);
  Rejected := False;
  try P := Lazy.ClientToScreen(Point(0, 0)); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Lazy.Handle = 0), 'handleless conversion rejects without allocating window');
  Rejected := False;
  try P := Lazy.ScreenToClient(Point(0, 0)); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'inverse handleless conversion rejects');
  Rejected := False;
  try P := Block.ClientToScreen(Point(0, 0)); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'orphan graphic conversion rejects');
  A.CreateHandle(0, 'Coordinates', WS_OVERLAPPEDWINDOW or WS_VISIBLE, 25, 35, 260, 180);
  B.CreateHandle(0, 'Other origin', WS_POPUP or WS_VISIBLE, 350, 60, 180, 140);
  Panel.Parent := A; Panel.SetBounds(13, 17, 140, 90);
  Origin := Point(0, 0); WinProcs.ClientToScreen(Panel.Handle, Origin);
  P := Panel.ClientToScreen(Point(-5, 7)); Q := P; WinProcs.ScreenToClient(Panel.Handle, Q);
  Check((P.X = Origin.X - 5) and (P.Y = Origin.Y + 7) and SamePoint(Q, Point(-5, 7)),
    'nested conversion matches actual USER client origin and native inverse');
  Check(SamePoint(Panel.ScreenToClient(P), Q), 'windowed inverse round trip');
  P := A.ClientToScreen(Point(0, 0)); GetWindowRect(A.Handle, Area);
  Check((P.X > Area.Left) and (P.Y > Area.Top), 'frame conversion includes real nonclient border and caption');
  MoveWindow(Panel.Handle, 27, 31, 140, 90, False);
  P := Panel.ClientToScreen(Point(0, 0)); Q := Point(27, 31); WinProcs.ClientToScreen(A.Handle, Q);
  Check(SamePoint(P, Q), 'external native move is reflected without cached geometry');
  Panel.Parent := B; P := Panel.ClientToScreen(Point(0, 0)); Q := Point(Panel.Left, Panel.Top);
  WinProcs.ClientToScreen(B.Handle, Q);
  Check(SamePoint(P, Q), 'native reparent conversion follows current HWND parent');
  Rejected := False;
  try P := Panel.ClientToScreen(Point(32767, 0)); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'positive coordinate overflow does not wrap');
  Rejected := False;
  try P := Panel.ScreenToClient(Point(-32768, 0)); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'negative inverse coordinate overflow does not wrap');
end;
procedure GraphicCases;
begin
  Block.Parent := Panel; Area := Rect(-4, 8, 36, 28); I := Block.BoundsCalls;
  Block.BoundsRect := Area; Before := Block.BoundsRect;
  Check(EqualRect(Area, Before) and (Block.BoundsCalls = I + 1), 'graphic BoundsRect dispatches virtual SetBounds');
  Area := Block.ClientRect;
  Check((Area.Left = 0) and (Area.Top = 0) and (Area.Right = 40) and (Area.Bottom = 20) and
    (Block.ClientWidth = 40) and (Block.ClientHeight = 20), 'graphic client geometry has local zero origin');
  P := Block.ClientToScreen(Point(2, -3)); Q := Panel.ClientToScreen(Point(-2, 5));
  Check(SamePoint(P, Q) and SamePoint(Block.ScreenToClient(P), Point(2, -3)),
    'windowless conversion uses parent client origin plus graphic offset');
  Area := Rect(100, 0, -100, 10); Rejected := False;
  try Block.BoundsRect := Area; except on ENativeWindowError do Rejected := True; end;
  Area := Block.BoundsRect;
  Check(Rejected and EqualRect(Area, Before), 'inverted BoundsRect preserves old geometry');
  Area := Rect(-32768, 0, 32767, 10); Rejected := False;
  try Block.BoundsRect := Area; except on ENativeWindowError do Rejected := True; end;
  Area := Block.BoundsRect;
  Check(Rejected and EqualRect(Area, Before), 'oversized BoundsRect is checked before 16 bit narrowing');
  Panel.Enabled := False; Block.Hide;
  FocusBefore := GetFocus; CaptureBefore := GetCapture;
  for I := 1 to 30 do
  begin
    P := Block.ClientToScreen(Point(-3, 4)); Q := Block.ScreenToClient(P);
    if not SamePoint(Q, Point(-3, 4)) then Failed := True;
  end;
  Check((GetFocus = FocusBefore) and (GetCapture = CaptureBefore) and not Block.Visible and
    (Block.Canvas.Handle = 0) and (GetWindow(Panel.Handle, GW_CHILD) = 0),
    'hidden disabled geometry queries create no HWND DC input or visibility side effects');
  Panel.Enabled := True; Block.Show; Block.TestPaint := True; Panel.Repaint; Block.TestPaint := False;
  Check((Block.PaintGuards > 0) and (Panel.CallbackErrors = 0) and (Block.Canvas.Handle = 0),
    'BoundsRect retains graphic paint mutation guard and releases canvas');
  Block.Parent := A; P := Block.ClientToScreen(Point(0, 0)); Q := A.ClientToScreen(Point(Block.Left, Block.Top));
  Check(SamePoint(P, Q), 'graphic reparent conversion follows new visual parent');
  Block.Parent := Lazy; Rejected := False;
  try P := Block.ScreenToClient(Point(0, 0)); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Lazy.Handle = 0), 'graphic with handleless parent rejects without creation');
  Block.Parent := Panel; Panel.DestroyHandle; Rejected := False;
  try P := Block.ClientToScreen(Point(0, 0)); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Panel.Handle = 0), 'destroyed parent has no stale coordinate mapping');
  Panel.CreateControl(B.Handle); P := Block.ClientToScreen(Point(0, 0));
  Q := Panel.ClientToScreen(Point(Block.Left, Block.Top));
  Check(SamePoint(P, Q), 'graphic conversion recovers after parent HWND recreation');
  Block.BoundsRect := Rect(-5, -6, -5, -6); Area := Block.ClientRect;
  Check((Block.ClientWidth = 0) and (Block.ClientHeight = 0) and (Area.Right = 0) and (Area.Bottom = 0),
    'zero sized negative position graphic bounds remain valid');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native and windowless coordinate geometry');
  try NativeCases; GraphicCases;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Block.Free; Panel.Free; Lazy.Free; B.Free; A.Free;
  Check(StackGuardIntact, 'coordinate stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
