program TestWin16Draw;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,4096}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Graphics,
  native_window, native_input;
type
  TProbe = class(TNativeInputWindow)
  public
    PaintCalls: Integer;
    NestedOkay, ReentrantOkay, PaintDraw, MouseDraw, FailDraw: Boolean;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure RedDraw(Sender: TObject);
    procedure NestedDraw(Sender: TObject);
    procedure OuterDraw(Sender: TObject);
    procedure FailingDraw(Sender: TObject);
  end;
var Probe: TProbe; Failed, Rejected: Boolean; Area: TRect;
  I, PoolGDI, PoolUSER: Integer;
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
procedure TProbe.Paint;
begin
  Inc(PaintCalls);
  if PaintDraw then DrawNow(RedDraw);
end;
procedure TProbe.RedDraw(Sender: TObject);
begin
  Canvas.Brush.Color := clRed;
  Canvas.FillRect(Rect(0, 0, 64, 64));
end;
procedure TProbe.NestedDraw(Sender: TObject);
begin
  SetROP2(Canvas.Handle, R2_BLACK);
  Canvas.Brush.Color := clLime;
  Canvas.FillRect(Rect(4, 4, 12, 12));
end;
procedure TProbe.OuterDraw(Sender: TObject);
var Saved: HDC; Before: Integer;
begin
  Saved := Canvas.Handle; SetROP2(Saved, R2_XORPEN);
  DrawNow(NestedDraw);
  NestedOkay := (Canvas.Handle = Saved) and (GetROP2(Saved) = R2_XORPEN);
  Before := PaintCalls;
  InvalidateArea(Rect(0, 0, 4, 4)); UpdateWindow(Handle);
  ReentrantOkay := (Canvas.Handle = Saved) and (GetROP2(Saved) = R2_XORPEN) and
    (PaintCalls = Before + 1) and not Painting;
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(Rect(20, 20, 24, 24));
end;
procedure TProbe.FailingDraw(Sender: TObject);
begin
  RedDraw(Sender); SetROP2(Canvas.Handle, R2_XORPEN);
  if FailDraw then raise Exception.Create('draw callback exception');
end;
procedure TProbe.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if MouseDraw then DrawNow(FailingDraw);
  inherited MouseDown(Button, Shift, X, Y);
end;
function Pixel(X, Y: SmallInt): TColor;
var DC: HDC;
begin
  DC := GetDC(Probe.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect drawing pixels');
  try Result := WinProcs.GetPixel(DC, X, Y); finally ReleaseDC(Probe.Handle, DC); end;
end;
begin
  LogLine('STEP scoped drawing outside paint and reentrant paint');
  try
    Probe := TProbe.Create(nil); Rejected := False;
    try Probe.DrawNow(Probe.RedDraw); except on Exception do Rejected := True; end;
    Check(Rejected and (Probe.Canvas.Handle = 0), 'detached object rejects scoped drawing');
    Probe.Color := clBlue;
    Probe.CreateHandle(0, 'Scoped drawing', WS_POPUP or WS_VISIBLE, 20, 20, 64, 64);
    SetWindowPos(Probe.Handle, HWND_TOP, 20, 20, 64, 64, SWP_SHOWWINDOW); UpdateWindow(Probe.Handle);
    Rejected := False;
    try Probe.DrawNow(nil); except on Exception do Rejected := True; end;
    Check(Rejected and (Probe.Canvas.Handle = 0), 'nil drawing callback is rejected before DC acquisition');
    Probe.DrawNow(Probe.RedDraw);
    Check((Pixel(20, 20) = clRed) and (Probe.Canvas.Handle = 0) and not Probe.Painting,
      'DrawNow draws actual pixels outside paint and detaches its DC');
    Probe.DrawNow(Probe.OuterDraw);
    Check(Probe.NestedOkay and (Pixel(6, 6) = clLime), 'nested drawing reuses canvas and restores native DC state');
    Check(Probe.ReentrantOkay and (Pixel(1, 1) = clBlue) and (Pixel(21, 21) = clWhite),
      'reentrant WM_PAINT restores outer drawing DC and its unclipped area');
    Probe.PaintDraw := True; Probe.InvalidateArea(Rect(0, 0, 4, 4)); UpdateWindow(Probe.Handle);
    Check((Pixel(1, 1) = clRed) and (Pixel(21, 21) = clWhite) and
      (Probe.Canvas.Handle = 0), 'DrawNow inside Paint retains native update clipping');
    Probe.PaintDraw := False; Probe.InvalidateArea(Rect(8, 8, 12, 12));
    Probe.DrawNow(Probe.RedDraw);
    Check(GetUpdateRect(Probe.Handle, Area, False), 'immediate drawing does not validate pending update regions');
    UpdateWindow(Probe.Handle);
    Check(Pixel(9, 9) = clBlue, 'later WM_PAINT remains authoritative after immediate drawing');
    Probe.FailDraw := True; Rejected := False;
    try Probe.DrawNow(Probe.FailingDraw);
    except on E: Exception do Rejected := E.Message = 'draw callback exception'; end;
    Check(Rejected and (Probe.Canvas.Handle = 0) and not Probe.Painting,
      'direct drawing exception propagates after DC cleanup');
    Probe.MouseDraw := True; Probe.Perform(WM_LBUTTONDOWN, MK_LBUTTON, 0);
    Check((Probe.CallbackErrors = 1) and (Probe.Canvas.Handle = 0),
      'drawing from mouse callback uses native exception containment');
    Probe.FailDraw := False; Probe.Perform(WM_LBUTTONDOWN, MK_LBUTTON, 0);
    Check(Pixel(20, 20) = clRed, 'mouse-driven drawing remains usable after callback failure');
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 150 do
    begin
      Probe.FailDraw := I mod 2 = 0;
      try Probe.DrawNow(Probe.FailingDraw); except on Exception do ; end;
    end;
    Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2),
      'normal and failing GetDC scopes do not drain GDI or USER pool');
    Probe.DestroyHandle;
    Check(Probe.Canvas.Handle = 0, 'native window teardown has no cached drawing DC');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Probe.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
