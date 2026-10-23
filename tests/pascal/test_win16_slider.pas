program TestWin16Slider;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Graphics,
  native_input, Controls, Slider;
type
  TObserver = class
    Count: Integer;
    procedure Change(Sender: TObject);
  end;
var ParentWindow: TNativeInputWindow; S: TSlider; Observer: TObserver;
  Failed, Rejected: Boolean; Before, I, PoolGDI, PoolUSER: Integer;
  TestArea: TRect; TestPoint: TPoint;
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
procedure TObserver.Change(Sender: TObject);
begin Inc(Count); end;
function Pixel(X, Y: SmallInt): TColor;
var DC: HDC;
begin
  DC := GetDC(S.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect slider pixels');
  try Result := WinProcs.GetPixel(DC, X, Y); finally ReleaseDC(S.Handle, DC); end;
end;
begin
  LogLine('STEP original slider on native Controls subset');
  try
    ParentWindow := TNativeInputWindow.Create(nil); Observer := TObserver.Create;
    ParentWindow.CreateHandle(0, 'Slider integration', WS_POPUP or WS_VISIBLE, 20, 20, 160, 140);
    SetActiveWindow(ParentWindow.Handle); ParentWindow.SetFocus;
    S := TSlider.Create(nil); S.OnChange := Observer.Change;
    S.Color := clBlue; S.ThumbColor := clRed; S.FocusColor := clLime;
    S.Ctl3D := False; S.ShowTicks := False; S.Value := 50;
    Check((S.Width = 24) and (S.Height = 100) and (S.Handle = 0) and
      (Observer.Count = 1), 'original slider configures values before native handle creation');
    S.CreateControl(ParentWindow.Handle); S.Repaint;
    Check((GetParent(S.Handle) = ParentWindow.Handle) and
      (Pixel(3, 48) = clRed) and (Pixel(3, 20) = clBlue),
      'original vertical slider paints actual thumb and background pixels');
    Before := Observer.Count; S.Value := 80;
    Check((Pixel(3, 21) = clRed) and (Pixel(3, 48) = clBlue) and
      (Observer.Count = Before + 1) and (S.Canvas.Handle = 0),
      'Value setter moves thumb outside Paint and restores saved background');
    Before := Observer.Count; S.Value := 80;
    Check(Observer.Count = Before, 'unchanged slider value does not notify twice');
    S.InvalidateArea(Rect(0, 0, 4, 4)); UpdateWindow(S.Handle); S.Value := 70;
    Check((Pixel(3, 30) = clRed) and (Pixel(3, 21) = clBlue),
      'partial paint invalidates thumb cache before the next value change');
    S.Value := 50; S.Perform(WM_KEYDOWN, VK_UP, 1);
    Check(S.Value = 60, 'original keyboard handler advances vertical slider value');
    S.Value := 50;
    TestArea := Rect(0, 45, 24, 55); TestPoint := Point(3, 48);
    Check(PtInRect(TestArea, TestPoint) and not PtInRect(TestArea, Point(24, 48)) and
      not PtInRect(TestArea, Point(3, 55)), 'typed hit-test includes interior and excludes right bottom edges');
    S.Perform(WM_LBUTTONDOWN, MK_LBUTTON, LongInt($00300003));
    Check(S.Focused and (GetCapture = S.Handle), 'thumb drag acquires real focus and mouse capture');
    S.Perform(WM_MOUSEMOVE, MK_LBUTTON, LongInt($001E0003));
    Check(S.Value = 70, 'original drag arithmetic updates value from mouse movement');
    S.Perform(WM_LBUTTONUP, 0, LongInt($001E0003));
    Check(GetCapture <> S.Handle, 'mouse up releases slider capture');
    S.Repaint; Before := 0;
    for I := 2 to 8 do if Pixel(3, 27 + I) = clLime then Inc(Before);
    Check(Before > 0, 'focused original thumb uses real checkerboard brush pixels');
    S.ThumbColor := clBlue; S.Repaint; Before := 0;
    for I := 2 to 8 do if Pixel(3, 27 + I) = clRed then Inc(Before);
    Check(Before = 0, 'focus pattern cache follows changed thumb colors');
    S.ThumbColor := clRed; S.Repaint;
    ParentWindow.SetFocus; UpdateWindow(S.Handle);
    Check(Pixel(3, 30) = clRed, 'focus loss redraws solid thumb instead of focus pattern');
    S.Value := 50; S.Perform(WM_LBUTTONDOWN, MK_LBUTTON, LongInt($00300003));
    S.Perform(WM_MOUSEMOVE, MK_LBUTTON, LongInt($80000003)); S.Perform(WM_LBUTTONUP, 0, 0);
    Check(S.Value = S.Maximum, 'extreme signed drag clamps before narrowing to Win16 Integer');
    S.Value := 50; S.Perform(WM_LBUTTONDOWN, MK_LBUTTON, LongInt($00300003));
    ParentWindow.MouseCapture := True;
    S.Perform(WM_MOUSEMOVE, MK_LBUTTON, LongInt($001E0003));
    Check(S.Value = 50, 'capture stolen by peer cancels stale internal slider drag');
    ParentWindow.MouseCapture := False; ParentWindow.SetFocus;
    S.Orientation := slHorizontal; S.Width := 100; S.Height := 24; S.Repaint;
    Check(Pixel(48, 3) = clRed, 'orientation change recreates horizontal thumb backing');
    S.Width := 140; S.Repaint; S.Value := 80;
    Check((S.Width = 140) and (Pixel(106, 3) = clRed) and (Pixel(66, 3) = clBlue),
      'native resize retains correct saved-strip dimensions and thumb position');
    Rejected := False;
    try S.Maximum := S.Minimum; except on Exception do Rejected := True; end;
    Check(Rejected and (S.Maximum = 100), 'zero slider range is rejected before division');
    Rejected := False;
    try S.ThumbHeight := 0; except on Exception do Rejected := True; end;
    Check(Rejected and (S.ThumbHeight = 10), 'invalid thumb height preserves previous geometry');
    S.Orientation := slVertical; S.Width := 24; S.Height := 10; S.Repaint;
    Check(S.CallbackErrors = 0, 'degenerate travel geometry skips division safely');
    S.Height := 100; S.Repaint;
    S.MouseCapture := True; S.Enabled := False;
    Check(not IsWindowEnabled(S.Handle) and (GetCapture <> S.Handle), 'Enabled property updates native child window');
    S.Enabled := True; S.MouseCapture := True; S.Visible := False;
    Check(not IsWindowVisible(S.Handle) and (GetCapture <> S.Handle), 'Visible property hides native child window');
    S.Visible := True; S.Repaint;
    Check(S.Perform(WM_GETDLGCODE, 0, 0) and DLGC_WANTARROWS <> 0,
      'original slider requests arrow keys from dialog-code handler');
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 100 do begin S.Value := I mod 100; S.Repaint; end;
    Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2) and (S.CallbackErrors = 0),
      'original slider redraw cycles do not drain GDI or USER pool');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  S.Free; ParentWindow.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
