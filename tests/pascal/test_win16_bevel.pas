program TestWin16Bevel;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Graphics, Controls, ExtCtrls;
var Root: TCustomControl; Bevels: array[TBevelShape] of TBevel; Shape: TBevelShape;
  Failed: Boolean; DC: HDC; Shadow, Light: TColorRef; Msg: TMsg; Start: LongInt;
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
function At(B: TBevel; X, Y: Integer): TColorRef;
begin Result := GetPixel(DC, B.Left + X, B.Top + Y); end;
procedure Pump;
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < 300 do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
begin
  LogLine('STEP bevel');
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Bevel parent', WS_POPUP or WS_VISIBLE, 10, 10, 420, 80);
    for Shape := Low(TBevelShape) to High(TBevelShape) do
    begin
      Bevels[Shape] := TBevel.Create(nil);
      if Shape = bsBox then Check((Bevels[Shape].Width = 50) and (Bevels[Shape].Height = 50), 'default size');
      Bevels[Shape].SetBounds(10 + Ord(Shape) * 60, 10, 40, 40);
      Bevels[Shape].Shape := Shape;
      Bevels[Shape].Parent := Root;
    end;
    Check((Bevels[bsBox].Style = bsLowered) and (Bevels[bsBox].Shape = bsBox), 'Delphi defaults');
    Bevels[bsFrame].Style := bsRaised;
    Root.Repaint; Pump;
    Shadow := ColorToRGB(clBtnShadow); Light := ColorToRGB(clBtnHighlight);
    DC := GetDC(Root.Handle);
    try
      Check((At(Bevels[bsBox], 0, 20) = Shadow) and (At(Bevels[bsBox], 20, 0) = Shadow) and
        (At(Bevels[bsBox], 39, 20) = Light) and (At(Bevels[bsBox], 20, 39) = Light), 'lowered box');
      { Raised frame: outer rectangle all highlight, inner one shadow then highlight. }
      Check((At(Bevels[bsFrame], 0, 20) = Light) and (At(Bevels[bsFrame], 38, 20) = Light) and
        (At(Bevels[bsFrame], 1, 20) = Shadow) and (At(Bevels[bsFrame], 39, 20) = Shadow), 'raised frame');
      Check((At(Bevels[bsTopLine], 20, 0) = Shadow) and (At(Bevels[bsTopLine], 20, 1) = Light) and
        (At(Bevels[bsTopLine], 20, 2) <> Shadow), 'top line');
      Check((At(Bevels[bsBottomLine], 20, 38) = Shadow) and (At(Bevels[bsBottomLine], 20, 39) = Light),
        'bottom line');
      Check((At(Bevels[bsLeftLine], 0, 20) = Shadow) and (At(Bevels[bsLeftLine], 1, 20) = Light), 'left line');
      Check((At(Bevels[bsRightLine], 38, 20) = Shadow) and (At(Bevels[bsRightLine], 39, 20) = Light),
        'right line');
    finally ReleaseDC(Root.Handle, DC); end;
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  for Shape := Low(TBevelShape) to High(TBevelShape) do Bevels[Shape].Free;
  Root.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
