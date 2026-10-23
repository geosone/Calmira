program TestWin16Gauge;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls, BarGauge;
var Window: TCustomControl; Gauge: TWin95Gauge; Bar: TBarGauge;
  Failed, Rejected: Boolean; I, X, Y, Ink, PoolGDI, PoolUSER: Integer;
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
function Pixel(X, Y: SmallInt): TColor;
var DC: HDC;
begin
  DC := GetDC(Window.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect gauge pixels');
  try Result := GetPixel(DC, X, Y); finally ReleaseDC(Window.Handle, DC); end;
end;
procedure Flush;
begin UpdateWindow(Window.Handle); end;
begin
  LogLine('STEP original BarGauge and Win95Gauge port');
  try
    Window := TCustomControl.Create(nil); Window.Color := clWhite;
    Window.CreateHandle(0, 'Original gauge controls', WS_POPUP or WS_VISIBLE,
      20, 20, 240, 160);
    Gauge := TWin95Gauge.Create(nil); Bar := TBarGauge.Create(nil);
    Gauge.ForeColor := clLime; Gauge.BackColor := clBlue;
    TGraphicControl(Gauge).SetBounds(8, 8, 108, 23); Gauge.Parent := Window;
    Bar.SetBounds(8, 60, 103, 33); Bar.ShowText := False;
    Bar.BorderStyle := bsNone; Bar.ForeColor := clRed; Bar.BackColor := clYellow;
    Bar.Parent := Window; Window.Repaint;
    Check((Gauge.Width = 103) and (GetWindow(Window.Handle, GW_CHILD) = 0),
      'original gauges retain segment sizing without allocating child HWNDs');
    Gauge.Width := 118;
    Check(Gauge.Width = 113, 'base width property dispatches original gauge sizing override');
    Gauge.Width := 103;
    Check(Pixel(12, 16) = clBlue, 'zero horizontal progress paints no segment');
    Gauge.Progress := 25; Flush;
    Check((Pixel(32, 16) = clLime) and (Pixel(42, 16) = clBlue) and
      (Pixel(18, 16) = clBlue), 'horizontal segments and gaps use explicit foreground and background');
    Gauge.Progress := 10; Flush;
    Check((Pixel(12, 16) = clLime) and (Pixel(32, 16) = clBlue),
      'decreasing progress erases old segments in buffered rendering');
    Gauge.Progress := 100; Flush;
    Check((Pixel(104, 16) = clLime) and (Pixel(108, 16) = clBlue),
      'full horizontal progress fills final segment without overwriting margin');
    Gauge.Kind := bkVertical; Gauge.SetBounds(130, 8, 23, 108); Gauge.Progress := 0; Flush;
    Check((Gauge.Height = 103) and (Pixel(138, 12) = clBlue),
      'zero vertical progress draws no spurious first segment');
    Gauge.Progress := 50; Flush;
    Check((Pixel(138, 52) = clLime) and (Pixel(138, 72) = clBlue) and
      (Pixel(138, 18) = clBlue), 'vertical segment count follows height rather than width');
    Gauge.Progress := 100; Flush;
    Check(Pixel(138, 104) = clLime, 'full vertical progress reaches final height-based segment');
    Bar.Progress := 50; Flush;
    Check((Pixel(30, 70) = clRed) and (Pixel(90, 70) = clYellow),
      'original solid bar renders horizontal percentage');
    Bar.Kind := bkVertical; Bar.SetBounds(8, 60, 23, 53); Flush;
    Check((Pixel(18, 65) = clYellow) and (Pixel(18, 105) = clRed),
      'original solid vertical bar fills upward from bottom');
    Bar.Kind := bkHorizontal; Bar.SetBounds(8, 125, 103, 23);
    Bar.ForeColor := clWhite; Bar.BackColor := clWhite; Bar.ShowText := True;
    Bar.Canvas.Font.Color := clBlack; Flush; Ink := 0;
    for Y := 126 to 146 do for X := 9 to 109 do
      if Pixel(X, Y) = clBlack then Inc(Ink);
    Check(Ink > 0, 'original percent text renders through actual native font drawing');
    Bar.ShowText := False; Bar.ForeColor := clRed; Bar.Progress := 100; Flush;
    Check((Pixel(15, 130) = clRed) and (Pixel(100, 130) = clRed),
      'paint restores solid brush after previous transparent text drawing');
    Bar.BorderStyle := bsSingle; Bar.Ctl3D := True; Flush;
    Check((Pixel(8, 125) = ColorToRGB(clBtnShadow)) and (Pixel(9, 126) = clBlack),
      'original solid bar retains sunken outer and black inner frames');
    Gauge.MinValue := Low(LongInt); Gauge.MaxValue := High(LongInt); Gauge.Progress := 0;
    Check(Gauge.PercentDone = 50, 'full signed 32-bit range computes percent without subtraction overflow');
    Gauge.Progress := High(LongInt); Gauge.AddProgress(High(LongInt));
    Check((Gauge.Progress = High(LongInt)) and (Gauge.PercentDone = 100),
      'positive progress addition saturates before 32-bit conversion');
    Gauge.Progress := Low(LongInt); Gauge.AddProgress(Low(LongInt));
    Check(Gauge.Progress = Low(LongInt), 'negative progress addition cannot wrap past minimum');
    Gauge.AddProgress(High(LongInt)); Check(Gauge.Progress = -1, 'wide addition preserves valid signed intermediate result');
    Gauge.Progress := 100; Gauge.MaxValue := 20;
    Check(Gauge.Progress = 20, 'lower maximum clamps existing progress');
    Gauge.MinValue := 20;
    Check(Gauge.PercentDone = 0, 'zero-span gauge range is defined as zero percent');
    Rejected := False;
    try Gauge.MinValue := 21; except on ERangeError do Rejected := True; end;
    Check(Rejected and (Gauge.MinValue = 20), 'inverted minimum is rejected transactionally');
    Rejected := False;
    try Gauge.MaxValue := 19; except on ERangeError do Rejected := True; end;
    Check(Rejected and (Gauge.MaxValue = 20), 'inverted maximum is rejected transactionally');
    Gauge.Progress := 21; Check(Gauge.Progress = 20, 'direct out-of-range progress keeps original ignore semantics');
    Gauge.MinValue := 0; Gauge.MaxValue := 100; Gauge.Progress := 0;
    Gauge.SetBounds(130, 8, 2, 2); Flush;
    Check((Gauge.Width = 2) and (Gauge.Height = 2), 'tiny gauge sizes do not round upward or create negative geometry');
    Bar.SetBounds(8, 125, 2, 2); Flush;
    Check(Window.CallbackErrors = 0, 'tiny double-framed solid bar skips exhausted interior safely');
    Bar.SetBounds(8, 125, 103, 23);
    Rejected := False;
    try Gauge.SetBounds(130, 8, -1, 20); except on Exception do Rejected := True; end;
    Check(Rejected and (Gauge.Width = 2) and (Gauge.Height = 2),
      'negative gauge dimensions are rejected without replacing stored bounds');
    Gauge.SetBounds(130, 8, 2, 103); Gauge.Progress := 100; Flush;
    Check(Window.CallbackErrors = 0, 'thin full-progress gauge skips inverted segment interior');
    Gauge.SetBounds(130, 8, 0, 0); Flush;
    Check((Gauge.Width = 0) and (Gauge.Height = 0) and (Window.CallbackErrors = 0),
      'zero-size gauge invalidates old bounds without drawing a surface');
    Gauge.SetBounds(130, 8, 23, 103);
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 0 to 100 do begin Gauge.Progress := I; Flush; end;
    Check((Window.CallbackErrors = 0) and (Gauge.Canvas.Handle = 0) and (Bar.Canvas.Handle = 0),
      'all gauge paints finish without callback errors or retained canvas HDCs');
    Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2),
      'gauge redraw cycles retain GDI and USER resources');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Gauge.Free; Bar.Free; Window.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
