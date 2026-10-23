program TestWin16Drawing;
{$mode delphi}{$H+}{$APPTYPE GUI}{$M 4096,4096}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics;
type
  TObserver = class
    Canvas: TCanvas;
    Count: Integer;
    BadState: Boolean;
    procedure Change(Sender: TObject);
  end;
var Picture: TPicture; Image, Pattern, Before: Graphics.TBitmap;
  Brush: TBrush; Observer: TObserver; Canvas: TCanvas;
  X, Y, I, ChangedPixels, RedPixels, CountBefore, PoolBefore: Integer;
  SavedPen, Previous: HGDIOBJ; SavedBrush: HGDIOBJ;
  Failed, Bad, Rejected: Boolean; OldBrush: HBRUSH;
procedure LogLine(const Text: string);
var F: HFILE; Buffer: array[0..255] of Char; Line: ShortString;
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
begin
  Inc(Count);
  if (GetROP2(Canvas.Handle) <> R2_XORPEN) or
    (GetTextColor(Canvas.Handle) <> clLime) or (GetBkColor(Canvas.Handle) <> clBlue) or
    (GetBkMode(Canvas.Handle) <> OPAQUE) or
    (GetStretchBltMode(Canvas.Handle) <> BLACKONWHITE) then BadState := True;
end;
procedure CheckPattern;
var X, Y: Integer; Expected: TColor; Bad: Boolean;
begin
  Bad := False;
  for Y := 0 to 15 do for X := 0 to 15 do
  begin
    if X mod 2 = Y mod 2 then Expected := clRed else Expected := clBlue;
    if Canvas.Pixels[X, Y] <> Expected then Bad := True;
  end;
  Check(not Bad, '8 by 8 checkerboard tiles with exact copied colors');
end;
procedure WhiteBackground;
begin
  Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := clWhite;
  Canvas.FillRect(Rect(0, 0, 64, 64));
end;
procedure CheckStretch;
var Source: Graphics.TBitmap; CountBefore, State: Integer; Rejected: Boolean;
procedure ResetCallerState;
begin
  SetROP2(Canvas.Handle, R2_XORPEN); SetTextColor(Canvas.Handle, clLime);
  SetBkColor(Canvas.Handle, clBlue); SetBkMode(Canvas.Handle, OPAQUE);
  SetStretchBltMode(Canvas.Handle, BLACKONWHITE); SetBrushOrg(Canvas.Handle, 0, 0);
  Picture.OnChange := Observer.Change;
end;
procedure ResizeImage(W, H: SmallInt);
begin
  { Resizing replaces the native DC; only drawing must preserve its state. }
  Picture.OnChange := nil; Image.SetSize(W, H); ResetCallerState;
end;
begin
  Source := Graphics.TBitmap.Create;
  try
    Source.SetSize(2, 2);
    Source.Canvas.Pixels[0, 0] := clRed; Source.Canvas.Pixels[1, 0] := clBlue;
    Source.Canvas.Pixels[0, 1] := clLime; Source.Canvas.Pixels[1, 1] := clWhite;
    WhiteBackground; CountBefore := Observer.Count;
    Canvas.StretchDraw(Rect(0, 0, 8, 8), Source);
    Check((Canvas.Pixels[1, 1] = clRed) and (Canvas.Pixels[6, 1] = clBlue) and
      (Canvas.Pixels[1, 6] = clLime) and (Canvas.Pixels[6, 6] = clWhite) and
      (Observer.Count = CountBefore + 1), 'StretchDraw scales exact quadrants and emits one picture event');
    Canvas.StretchDraw(Rect(0, 0, 64, 64), Source);
    CountBefore := Observer.Count;
    Canvas.StretchDraw(Rect(0, 0, 16, 16), Image);
    Check((Canvas.Pixels[2, 2] = clRed) and (Canvas.Pixels[12, 2] = clBlue) and
      (Canvas.Pixels[2, 12] = clLime) and (Canvas.Pixels[12, 12] = clWhite) and
      (Image.Width = 64) and (Observer.Count = CountBefore + 1),
      'wallpaper self-shrink snapshots pixels without resizing the bitmap');
    Picture.OnChange := nil;
    Image.Width := 16; Image.Height := 16; ResetCallerState;
    Canvas.StretchDraw(Rect(4, 4, 16, 16), Image);
    Check((Canvas.Pixels[5, 5] = clRed) and (Canvas.Pixels[14, 5] = clBlue) and
      (Canvas.Pixels[5, 14] = clLime) and (Canvas.Pixels[14, 14] = clWhite),
      'overlapping self-stretch reads an immutable source snapshot');
    ResizeImage(64, 64); WhiteBackground;
    Canvas.Brush.Color := clLime; Canvas.FillRect(Rect(0, 0, 64, 64));
    Source.TransparentColor := clWhite; Source.Transparent := True;
    Canvas.StretchDraw(Rect(0, 0, 8, 8), Source);
    Check((Canvas.Pixels[6, 6] = clLime) and (Canvas.Pixels[6, 1] = clBlue),
      'transparent StretchDraw scales color key while preserving background');
    ResizeImage(8, 8); Image.Transparent := True; Image.TransparentColor := clLime;
    Canvas.StretchDraw(Rect(0, 0, 4, 4), Image);
    Check((Canvas.Pixels[0, 0] = clRed) and (Canvas.Pixels[3, 0] = clBlue) and
      (Canvas.Pixels[0, 3] = clRed) and (Canvas.Pixels[3, 3] = clRed),
      'transparent self-stretch snapshots source and destination background');
    Image.Transparent := False; ResizeImage(64, 64);
    Source.Transparent := False; WhiteBackground;
    State := SaveDC(Canvas.Handle);
    try
      IntersectClipRect(Canvas.Handle, 0, 0, 4, 4);
      Canvas.StretchDraw(Rect(0, 0, 8, 8), Source);
    finally RestoreDC(Canvas.Handle, State); end;
    Check((Canvas.Pixels[1, 1] = clRed) and (Canvas.Pixels[6, 1] = clWhite),
      'StretchDraw retains caller clipping');
    CountBefore := Observer.Count;
    Canvas.StretchDraw(Rect(0, 0, 0, 8), Source);
    Source.Clear; Canvas.StretchDraw(Rect(0, 0, 8, 8), Source);
    Check(Observer.Count = CountBefore, 'empty stretch targets and graphics emit no event');
    Rejected := False;
    try Canvas.StretchDraw(Rect(8, 0, 0, 8), Image);
    except on Exception do Rejected := True; end;
    Check(Rejected and (Observer.Count = CountBefore), 'mirrored stretch is rejected without notification');
  finally Source.Free; end;
end;
begin
  LogLine('STEP patterns focus clipped text and fills');
  try
    Picture := TPicture.Create; Image := Picture.Bitmap; Image.SetSize(64, 64);
    Canvas := Image.Canvas; Observer := TObserver.Create; Observer.Canvas := Canvas;
    SetROP2(Canvas.Handle, R2_XORPEN); SetTextColor(Canvas.Handle, clLime);
    SetBkColor(Canvas.Handle, clBlue); SetBkMode(Canvas.Handle, OPAQUE);
    SetStretchBltMode(Canvas.Handle, BLACKONWHITE);
    SetBrushOrg(Canvas.Handle, 0, 0);
    Picture.OnChange := Observer.Change;
    SavedPen := SelectObject(Canvas.Handle, GetStockObject(WHITE_PEN)); SelectObject(Canvas.Handle, SavedPen);
    SavedBrush := SelectObject(Canvas.Handle, GetStockObject(BLACK_BRUSH)); SelectObject(Canvas.Handle, SavedBrush);
    CheckStretch;
    Pattern := Graphics.TBitmap.Create; Pattern.SetSize(8, 8);
    for Y := 0 to 7 do for X := 0 to 7 do
      if X mod 2 = Y mod 2 then Pattern.Canvas.Pixels[X, Y] := clRed
      else Pattern.Canvas.Pixels[X, Y] := clBlue;
    Canvas.Brush.Bitmap := Pattern;
    Pattern.Free; Pattern := nil;
    Canvas.FillRect(Rect(0, 0, 16, 16)); CheckPattern;
    Brush := TBrush.Create; Brush.Assign(Canvas.Brush);
    Canvas.Brush.Color := Canvas.Brush.Color;
    Canvas.FillRect(Rect(0, 0, 16, 16));
    Check(Canvas.Pixels[0, 0] = clWhite, 'same-color assignment exits pattern mode for slider blur');
    Canvas.Brush := Brush; Brush.Free; Brush := nil;
    Canvas.RefreshSystemColors;
    Canvas.FillRect(Rect(0, 0, 16, 16)); CheckPattern;
    Pattern := Graphics.TBitmap.Create; Pattern.SetSize(4, 4);
    OldBrush := Canvas.Brush.Handle; Rejected := False;
    try Canvas.Brush.Bitmap := Pattern; except on Exception do Rejected := True; end;
    Check(Rejected and (Canvas.Brush.Handle = OldBrush), 'invalid pattern size preserves cached brush');
    Pattern.SetSize(8, 8);
    Canvas.Brush.Bitmap := nil; Canvas.FillRect(Rect(0, 0, 16, 16));
    Check(Canvas.Pixels[0, 0] = clWhite, 'nil bitmap clears pattern without taking caller ownership');
    WhiteBackground; Canvas.Font.Height := -16; Canvas.Font.Color := clRed;
    CountBefore := Observer.Count;
    Canvas.TextRect(Rect(8, 8, 24, 24), 4, 8, 'MMMMMMMMMMMM');
    Bad := False; RedPixels := 0;
    for Y := 0 to 63 do for X := 0 to 63 do
      if Canvas.Pixels[X, Y] = clRed then
      begin
        Inc(RedPixels);
        if (X < 8) or (X >= 24) or (Y < 8) or (Y >= 24) then Bad := True;
      end;
    Check(not Bad and (RedPixels > 0) and (Observer.Count = CountBefore + 1), 'TextRect clips glyphs and publishes one final event');
    Canvas.Brush.Color := clLime; Canvas.FillRect(Rect(0, 0, 64, 64));
    Canvas.Brush.Style := bsClear;
    Canvas.TextRect(Rect(8, 8, 24, 24), 8, 8, 'T');
    Check(Canvas.Pixels[23, 23] = clLime, 'clear TextRect brush preserves background');
    Before := Graphics.TBitmap.Create; Before.Assign(Image);
    Canvas.DrawFocusRect(Rect(4, 4, 28, 28)); ChangedPixels := 0;
    for Y := 0 to 31 do for X := 0 to 31 do
      if Canvas.Pixels[X, Y] <> Before.Canvas.Pixels[X, Y] then Inc(ChangedPixels);
    Check(ChangedPixels > 0, 'native focus rectangle changes actual edge pixels');
    Canvas.DrawFocusRect(Rect(4, 4, 28, 28)); Bad := False;
    for Y := 0 to 31 do for X := 0 to 31 do
      if Canvas.Pixels[X, Y] <> Before.Canvas.Pixels[X, Y] then Bad := True;
    Check(not Bad, 'drawing focus rectangle twice restores original pixels');
    WhiteBackground; Canvas.Pen.Color := clRed; Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(4, 4, 28, 28); Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := clBlue;
    Canvas.FloodFill(8, 8, clRed, fsBorder);
    Check((Canvas.Pixels[8, 8] = clBlue) and (Canvas.Pixels[1, 1] = clWhite) and
      (Canvas.Pixels[4, 4] = clRed), 'border flood fill respects red boundary');
    WhiteBackground; Canvas.Brush.Color := clRed; Canvas.FillRect(Rect(4, 4, 12, 12));
    Canvas.Brush.Color := clBlue; Canvas.FloodFill(6, 6, clRed, fsSurface);
    Check((Canvas.Pixels[6, 6] = clBlue) and (Canvas.Pixels[1, 1] = clWhite), 'surface flood fill replaces only connected matching color');
    CountBefore := Observer.Count; Canvas.FloodFill(-1, -1, clWhite, fsSurface);
    Check(Observer.Count = CountBefore, 'invalid flood seed does not emit a change');
    WhiteBackground; Canvas.Brush.Color := clBlue; Canvas.Pen.Color := clRed;
    Canvas.Pie(4, 4, 28, 28, 4, 16, 4, 16);
    Check((Canvas.Pixels[16, 12] = clBlue) and (Canvas.Pixels[1, 1] = clWhite), 'full-circle Pie supports disk-usage chart drawing');
    Check(not Observer.BadState, 'drawing callbacks see restored caller colors mode and raster operation');
    Previous := SelectObject(Canvas.Handle, GetStockObject(WHITE_PEN));
    Check(Previous = SavedPen, 'caller pen survives new drawing operations'); SelectObject(Canvas.Handle, Previous);
    Previous := SelectObject(Canvas.Handle, GetStockObject(BLACK_BRUSH));
    Check(Previous = SavedBrush, 'caller brush survives new drawing operations'); SelectObject(Canvas.Handle, Previous);
    PoolBefore := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for I := 1 to 150 do
    begin
      Canvas.Brush.Bitmap := Pattern;
      Canvas.FillRect(Rect(0, 0, 16, 16));
      Canvas.TextRect(Rect(16, 0, 32, 16), 16, 0, 'Test');
      Canvas.Brush.Color := clWhite;
      Canvas.DrawFocusRect(Rect(0, 0, 16, 16)); Canvas.DrawFocusRect(Rect(0, 0, 16, 16));
      Canvas.StretchDraw(Rect(0, 0, 16, 16), Image);
    end;
    Check(GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolBefore - 2, 'pattern recreate and drawing cycles do not drain GDI pool');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Brush.Free; Pattern.Free; Before.Free; Picture.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
