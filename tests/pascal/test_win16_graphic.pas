program TestWin16Graphic;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls, Win95Pie;
type
  TBlock = class(TGraphicControl)
  public
    FillColor: TColor;
    FailPaint, ReparentInPaint, ResizeInPaint, DisableInPaint: Boolean;
    Other: TCustomControl;
    DisableSibling: TGraphicControl;
    procedure Paint; override;
    procedure Underlay(Sender: TObject);
  end;
var A, B: TCustomControl; Chart: TWin95PieChart; Block: TBlock;
  Failed, Rejected: Boolean; I, PoolGDI, PoolUSER: Integer;
  Shadow: array[0..7] of TColor;
{$I win16_stack_guard.inc}
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
procedure TBlock.Paint;
begin
  if ReparentInPaint then Parent := Other;
  if ResizeInPaint then Width := Width + 1;
  Enabled := Enabled; { Same-value writes remain harmless during paint. }
  if DisableInPaint then Enabled := False;
  if DisableSibling <> nil then DisableSibling.Enabled := False;
  Canvas.Brush.Color := FillColor; Canvas.FillRect(Rect(-10, -10, 50, 50));
  if FailPaint then raise Exception.Create('graphic paint test');
end;
function Pixel(Window: TCustomControl; X, Y: SmallInt): TColor;
var DC: HDC;
begin
  DC := GetDC(Window.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect graphic pixels');
  try Result := WinProcs.GetPixel(DC, X, Y); finally ReleaseDC(Window.Handle, DC); end;
end;
procedure TBlock.Underlay(Sender: TObject);
begin
  with TCustomControl(Sender).Canvas do
  begin Brush.Color := clWhite; FillRect(Rect(0, 0, 160, 110)); end;
end;
procedure CreateParent(Window: TCustomControl; X: SmallInt);
begin
  Window.Color := clWhite;
  Window.CreateHandle(0, 'Graphic controls', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN,
    X, 20, 160, 110);
end;
begin
  FillChar(StackBottom^, 64, $A5);
  LogLine('STEP true windowless graphic controls and original pie');
  try
    A := TCustomControl.Create(nil); B := TCustomControl.Create(nil);
    CreateParent(A, 20); CreateParent(B, 210);
    Chart := TWin95PieChart.Create(nil); Chart.Color := clWhite; Chart.Value := 0;
    Chart.SetBounds(8, 8, 122, 62); Chart.Parent := A;
    Block := TBlock.Create(nil); Block.FillColor := clRed;
    Block.Enabled := False;
    Check(not Block.Enabled and Block.Visible and (Block.Parent = nil),
      'orphan graphic stores enabled state without a native window');
    Block.Enabled := True;
    Block.SetBounds(4, 80, 20, 20); Block.Parent := A; A.Repaint;
    Check(GetWindow(A.Handle, GW_CHILD) = 0, 'graphic children allocate no native child HWNDs');
    Check(Pixel(A, 69, 28) = clFuchsia, 'original zero-used pie paints free-color pixels at parent offset');
    Check((Pixel(A, 5, 85) = clRed) and (Pixel(A, 3, 85) = clWhite) and
      (Pixel(A, 24, 85) = clWhite), 'oversized child painting is clipped to translated bounds');
    A.DrawNow(Block.Underlay);
    Check((Pixel(A, 69, 28) = clFuchsia) and (Pixel(A, 5, 85) = clRed),
      'immediate parent drawing composites graphic children above the underlay');
    Chart.Value := Chart.Maximum; UpdateWindow(A.Handle);
    Check((Chart.GetPercent = 100) and (Pixel(A, 69, 28) = clBlue), 'original full-used pie repaints through parent invalidation');
    for I := 0 to 7 do Shadow[I] := Pixel(A, 48 + (I mod 4) * 10, 63 + (I div 4) * 2);
    A.InvalidateArea(Rect(48, 63, 88, 67)); UpdateWindow(A.Handle); Rejected := False;
    for I := 0 to 7 do
      if Shadow[I] <> Pixel(A, 48 + (I mod 4) * 10, 63 + (I div 4) * 2) then Rejected := True;
    Check(not Rejected, 'partial pie shadow repaint matches full-render flood-fill pixels');
    Chart.Value := 1000; Check(Chart.Value = Chart.Maximum, 'pie value clamps to current maximum');
    Chart.Maximum := 50; Check((Chart.Value = 50) and (Chart.GetPercent = 100), 'lower maximum clamps existing pie value');
    Rejected := False;
    try Chart.Depth := Chart.Height; except on Exception do Rejected := True; end;
    Check(Rejected and (Chart.Depth = 10), 'invalid pie depth preserves geometry');
    Block.Left := 30; UpdateWindow(A.Handle);
    Check((Pixel(A, 5, 85) = clWhite) and (Pixel(A, 32, 85) = clRed), 'moving graphic invalidates old and new parent regions');
    Block.Visible := False; UpdateWindow(A.Handle);
    Check(Pixel(A, 32, 85) = clWhite, 'hiding graphic restores parent background');
    Block.Visible := True; UpdateWindow(A.Handle); Block.FillColor := clLime;
    A.InvalidateArea(Rect(31, 82, 34, 85)); UpdateWindow(A.Handle);
    Check((Pixel(A, 32, 83) = clLime) and (Pixel(A, 32, 88) = clRed), 'child painting retains partial parent update clip');
    Block.Parent := B; UpdateWindow(A.Handle); UpdateWindow(B.Handle);
    Check((Pixel(A, 32, 83) = clWhite) and (Pixel(B, 32, 83) = clLime), 'reparenting removes old graphic and paints new parent');
    Rejected := False;
    try Block.SetBounds(32760, 80, 20, 20); except on Exception do Rejected := True; end;
    Check(Rejected and (Block.Left = 30), 'overflowing graphic bounds are rejected before mutation');
    Block.Parent := A; Block.FailPaint := True; A.Repaint;
    Check((A.CallbackErrors = 1) and (Block.Canvas.Handle = 0) and (A.Canvas.Handle = 0),
      'graphic paint exception detaches child and parent canvases');
    Block.FailPaint := False; Block.Other := B; Block.ReparentInPaint := True; A.Repaint;
    Check((A.CallbackErrors = 2) and (Block.Parent = A), 'reparenting during paint is rejected without changing lists');
    Rejected := False;
    try A.DrawNow(Block.Underlay); except on Exception do Rejected := True; end;
    Check(Rejected and (Block.Parent = A) and (A.Canvas.Handle = 0) and
      (Block.Canvas.Handle = 0), 'immediate composition also rejects hierarchy mutation and cleans DCs');
    Block.ReparentInPaint := False; Block.ResizeInPaint := True; A.Repaint;
    Check((A.CallbackErrors = 3) and (Block.Width = 20), 'graphic geometry cannot change during buffered rendering');
    Block.ResizeInPaint := False; A.Repaint;
    Check(Pixel(A, 32, 83) = clLime, 'graphic composition recovers after callback failures');
    Block.DisableInPaint := True; A.Repaint;
    Check((A.CallbackErrors = 4) and Block.Enabled and
      (Block.Canvas.Handle = 0) and (A.Canvas.Handle = 0),
      'enabled mutation during graphic paint is rejected without state or DC damage');
    Block.DisableInPaint := False; Block.Enabled := False; A.Repaint;
    Check((Pixel(A, 32, 83) = clLime) and not Block.Enabled,
      'disabled graphic still paints rather than becoming hidden');
    Block.Parent := B;
    Check(not Block.Enabled, 'graphic enabled state survives reparenting');
    Block.Parent := A; Block.Enabled := True; A.Repaint;
    Check((A.CallbackErrors = 4) and Block.Enabled,
      'enabled changes recover after rejected paint mutation');
    Block.DisableSibling := Chart; A.Repaint;
    Check((A.CallbackErrors = 5) and Chart.Enabled and (Chart.Canvas.Handle = 0),
      'sibling enabled mutation is also rejected during parent composition');
    Block.DisableSibling := nil; A.Repaint;
    Block.Enabled := False; Block.Parent := B; B.Free; B := nil;
    Check((Block.Parent = nil) and (Block.Canvas.Handle = 0) and not Block.Enabled,
      'parent destruction detaches independently owned graphics');
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 0 to 100 do begin Chart.Value := I mod 51; A.Repaint; end;
    Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2), 'pie redraw cycles retain GDI and USER pool stability');
    Check(Chart.Canvas.Handle = 0, 'windowless canvas has no cached HDC');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Check(StackGuardIntact, 'graphic stack boundary');
  Chart.Free; Block.Free; A.Free; B.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
