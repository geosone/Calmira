program TestWin16Paint;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,4096}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Graphics,
  native_window, native_paint;
type
  TProbe = class(TNativePaintWindow)
  public
    PaintCount: Integer;
    FillColor: TColor;
    FillEnabled, RaisePaint, NestedPaint, NestedOkay, SawCanvas: Boolean;
    LastArea: TRect;
    procedure Paint; override;
  end;
var Probe: TProbe; Failed, Rejected: Boolean;
  Before, I, PoolGDI, PoolUSER: Integer; Area: TRect;
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
var Saved: HDC;
begin
  Inc(PaintCount); LastArea := PaintRect;
  SawCanvas := Painting and (Canvas.Handle <> 0);
  if NestedPaint then
  begin
    Saved := Canvas.Handle; Perform(WM_PAINT, 0, 0);
    NestedOkay := Painting and (Canvas.Handle = Saved);
  end;
  if FillEnabled then
  begin
    Canvas.Brush.Color := FillColor;
    Canvas.FillRect(Rect(0, 0, 64, 64));
  end;
  if RaisePaint then
  begin
    SetROP2(Canvas.Handle, R2_XORPEN);
    raise Exception.Create('paint test exception');
  end;
end;
function Pixel(X, Y: SmallInt): TColor;
var DC: HDC;
begin
  DC := GetDC(Probe.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect window pixels');
  try Result := WinProcs.GetPixel(DC, X, Y); finally ReleaseDC(Probe.Handle, DC); end;
end;
begin
  LogLine('STEP scoped native paint and clipped window pixels');
  try
    Probe := TProbe.Create(nil); Probe.Color := clBlue;
    Probe.CreateHandle(0, 'Paint probe', WS_POPUP or WS_VISIBLE, 20, 20, 64, 64);
    SetWindowPos(Probe.Handle, HWND_TOP, 20, 20, 64, 64, SWP_SHOWWINDOW);
    UpdateWindow(Probe.Handle);
    Check(Probe.SawCanvas and (Probe.Canvas.Handle = 0) and not Probe.Painting,
      'WM_PAINT lends a canvas only during virtual Paint');
    Check(Pixel(1, 1) = clBlue, 'native paint fills configured background');
    Check(not GetUpdateRect(Probe.Handle, Area, False), 'EndPaint validates completed update region');
    Probe.Color := clLime; UpdateWindow(Probe.Handle);
    Check(Pixel(1, 1) = clLime, 'Color change invalidates and redraws actual window');
    Probe.FillEnabled := True; Probe.FillColor := clRed; Probe.Repaint;
    Check(Pixel(20, 20) = clRed, 'virtual Paint draws through public Graphics canvas');
    Probe.FillColor := clBlue; Before := Probe.PaintCount;
    Probe.InvalidateArea(Rect(4, 4, 12, 12)); UpdateWindow(Probe.Handle);
    Check((Pixel(6, 6) = clBlue) and (Pixel(20, 20) = clRed) and
      (Probe.PaintCount = Before + 1), 'partial update clips drawing without replacing outside pixels');
    Check((Probe.LastArea.Left = 4) and (Probe.LastArea.Top = 4) and
      (Probe.LastArea.Right = 12) and (Probe.LastArea.Bottom = 12),
      'PaintRect reports native update bounds');
    Probe.FillColor := clWhite;
    Probe.InvalidateArea(Rect(0, 0, 4, 4)); Probe.InvalidateArea(Rect(12, 12, 16, 16));
    UpdateWindow(Probe.Handle);
    Check((Pixel(1, 1) = clWhite) and (Pixel(13, 13) = clWhite) and
      (Pixel(8, 8) = clBlue), 'disjoint update regions preserve pixels inside their bounding gap');
    Before := Probe.PaintCount; Probe.Perform(WM_PAINT, 0, 0);
    Check(Probe.PaintCount = Before, 'empty WM_PAINT does not invoke virtual drawing');
    Probe.NestedPaint := True; Probe.Repaint; Probe.NestedPaint := False;
    Check(Probe.NestedOkay and (Probe.PaintCount = Before + 1),
      'nested WM_PAINT does not replace active canvas or recurse');
    Probe.RaisePaint := True; Probe.Repaint;
    Check((Probe.CallbackErrors = 1) and (Probe.LastCallbackError = 'paint test exception') and
      (Probe.Canvas.Handle = 0) and not Probe.Painting and
      not GetUpdateRect(Probe.Handle, Area, False), 'paint exception still detaches canvas and ends native paint');
    Probe.RaisePaint := False; Probe.FillColor := clLime; Probe.Repaint;
    Check(Pixel(20, 20) = clLime, 'window remains drawable after paint exception');
    Rejected := False;
    try Probe.Canvas.FillRect(Rect(0, 0, 4, 4)); except on Exception do Rejected := True; end;
    Check(Rejected, 'drawing outside paint is rejected without acquiring an unscoped DC');
    Before := Probe.PaintCount; Probe.InvalidateArea(Rect(0, 0, 0, 4)); UpdateWindow(Probe.Handle);
    Check(Probe.PaintCount = Before, 'empty invalidation does not schedule paint');
    Rejected := False;
    try Probe.InvalidateArea(Rect(12, 4, 4, 12)); except on Exception do Rejected := True; end;
    Check(Rejected, 'mirrored invalidation is rejected');
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 150 do
    begin
      Probe.RaisePaint := I mod 2 = 0; Probe.Repaint;
    end;
    Probe.RaisePaint := False;
    Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2),
      'normal and failing paint cycles do not drain GDI or USER pool');
    Probe.DestroyHandle;
    Check((Probe.Canvas.Handle = 0) and not Probe.Painting, 'window teardown leaves canvas detached');
    Rejected := False;
    try Probe.Repaint; except on Exception do Rejected := True; end;
    Check(Rejected, 'Repaint rejects a detached window');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Probe.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
