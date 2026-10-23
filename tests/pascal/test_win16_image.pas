program TestWin16Image;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls, ExtCtrls, native_window;
type
  TTestImage = class(TImage)
  public
    TryUpdate: Boolean;
    Rejections: Integer;
    procedure Paint; override;
  end;
var Window: TCustomControl; Image: TTestImage; Detached: TImage;
  Source, NativeIcon, ScaledIcon: Graphics.TBitmap; External: TPicture;
  SavedPicture: TPicture; SavedGraphic: TGraphic; Borrowed: TCanvas;
  Failed, Rejected, EqualPixels: Boolean; X, Y, I, PoolGDI, PoolUSER: Integer;
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
  if DC = 0 then raise Exception.Create('Cannot inspect image pixels');
  try Result := GetPixel(DC, X, Y); finally ReleaseDC(Window.Handle, DC); end;
end;
procedure TTestImage.Paint;
begin
  if TryUpdate then
  begin
    try Update; except on ENativeWindowError do Inc(Rejections); end;
    try Parent.Update; except on ENativeWindowError do Inc(Rejections); end;
  end;
  inherited Paint;
end;
begin
  LogLine('STEP image control and graphic update lifecycle');
  try
    Image := TTestImage.Create(nil); Detached := TImage.Create(nil);
    Image.Hide; Image.Update; Image.Repaint; Image.Show;
    Check(Image.Visible and Image.Picture.Empty, 'detached graphic visibility and update allocate no picture or window');
    Window := TCustomControl.Create(nil); Window.Color := clWhite;
    Window.CreateHandle(0, 'Image probe', WS_POPUP or WS_VISIBLE, 20, 20, 180, 130);
    Source := Graphics.TBitmap.Create; Source.SetSize(4, 4);
    Source.Canvas.Brush.Color := clBlue; Source.Canvas.FillRect(Rect(0, 0, 4, 4));
    Source.Canvas.Brush.Color := clRed; Source.Canvas.FillRect(Rect(0, 0, 2, 2));
    Source.Canvas.Brush.Color := clLime; Source.Canvas.FillRect(Rect(0, 2, 2, 4));
    Source.Canvas.Brush.Color := clWhite; Source.Canvas.FillRect(Rect(2, 2, 4, 4));
    Image.Color := clYellow; Image.SetBounds(8, 8, 40, 40); Image.Parent := Window;
    Image.Picture.Bitmap := Source; Source.Free; Source := nil; Image.Update;
    Check((GetWindow(Window.Handle, GW_CHILD) = 0) and (Pixel(8, 8) = clRed) and
      (Pixel(11, 11) = clWhite) and (Pixel(20, 20) = clYellow),
      'image owns copied bitmap and renders native dimensions without child HWND');
    Image.Center := True; Image.Update;
    Check((Pixel(26, 26) = clRed) and (Pixel(8, 8) = clYellow), 'center moves native image and clears old position');
    Image.SetBounds(8, 8, 2, 2); Image.Update;
    Check((Pixel(8, 8) = clRed) and (Pixel(9, 8) = clBlue) and
      (Pixel(8, 9) = clLime) and (Pixel(9, 9) = clWhite) and (Pixel(10, 8) = clWhite),
      'oversized centered bitmap clips negative origin to image bounds');
    Image.SetBounds(8, 8, 40, 40);
    Image.Stretch := True; Image.Update;
    Check((Pixel(12, 12) = clRed) and (Pixel(38, 12) = clBlue) and
      (Pixel(12, 38) = clLime) and (Pixel(38, 38) = clWhite),
      'stretch fills image bounds with scaled bitmap quadrants');
    Image.Picture.Bitmap.Canvas.Pixels[0, 0] := clLime; Image.Update;
    Check(Pixel(9, 9) = clLime, 'owned bitmap mutation notifies image and schedules repaint');
    Borrowed := Image.Canvas; Borrowed.Pixels[1, 0] := clYellow; Image.Update;
    Check((Borrowed = Image.Picture.Bitmap.Canvas) and (Pixel(20, 12) = clYellow),
      'public image Canvas draws into persistent owned bitmap rather than paint HDC');
    Image.Picture.Bitmap.TransparentColor := clWhite; Image.Picture.Bitmap.Transparent := True;
    Image.Update;
    Check((Pixel(38, 38) = clYellow) and (Pixel(38, 12) = clBlue),
      'transparent bitmap key preserves opaque image background when scaled');
    Image.Hide; Image.Update;
    Check(Pixel(9, 9) = clWhite, 'Hide plus Update clears old graphic region through parent');
    Image.Show; Image.Repaint;
    Check(Pixel(9, 9) = clLime, 'Show plus Repaint restores image synchronously');
    Image.AutoSize := True;
    Check((Image.Width = 4) and (Image.Height = 4), 'AutoSize adopts existing picture dimensions');
    Image.Picture.Bitmap.SetSize(6, 5);
    Image.Picture.Bitmap.Canvas.Brush.Color := clBlue;
    Image.Picture.Bitmap.Canvas.FillRect(Rect(0, 0, 6, 5)); Image.Update;
    Check((Image.Width = 6) and (Image.Height = 5) and (Pixel(13, 12) = clBlue) and
      (Pixel(14, 12) = clWhite), 'picture resize updates image bounds and erases previous larger area');
    SavedGraphic := Image.Picture.Graphic; Rejected := False;
    try Image.Picture.LoadFromFile('C:\BAD.BMP'); except on Exception do Rejected := True; end;
    Check(Rejected and (Image.Picture.Graphic = SavedGraphic) and (Image.Width = 6),
      'failed picture replacement preserves owned graphic and image geometry');
    Image.Picture.Assign(nil); Image.Update;
    Check(Image.Picture.Empty and (Image.Width = 6) and (Image.Height = 5) and
      (Pixel(9, 9) = clYellow), 'clearing an auto-sized picture retains its box and erases content');
    Image.AutoSize := False; Image.SetBounds(8, 8, 40, 40); SavedPicture := Image.Picture;
    Image.Picture := nil; Image.Update;
    Check((Image.Picture = SavedPicture) and Image.Picture.Empty and (Pixel(9, 9) = clYellow),
      'nil picture assignment clears content but retains owned container and bounds');
    Image.Canvas.Brush.Color := clRed; Image.Canvas.FillRect(Rect(0, 0, 40, 40)); Image.Update;
    Check((Image.Picture.Width = 40) and (Pixel(9, 9) = clRed),
      'first image Canvas access creates a bitmap at explicit control dimensions');
    Image.Picture.Icon.LoadFromResource(0, IDI_APPLICATION); Image.Update;
    NativeIcon := Graphics.TBitmap.Create; NativeIcon.SetSize(Image.Picture.Width, Image.Picture.Height);
    NativeIcon.Canvas.Brush.Color := clYellow;
    NativeIcon.Canvas.FillRect(Rect(0, 0, NativeIcon.Width, NativeIcon.Height));
    NativeIcon.Canvas.Draw(0, 0, Image.Picture.Graphic);
    ScaledIcon := Graphics.TBitmap.Create; ScaledIcon.SetSize(40, 40);
    ScaledIcon.Canvas.StretchDraw(Rect(0, 0, 40, 40), NativeIcon); EqualPixels := True;
    for Y := 0 to 6 do for X := 0 to 6 do
      if Pixel(8 + X * 6, 8 + Y * 6) <> ScaledIcon.Canvas.Pixels[X * 6, Y * 6] then EqualPixels := False;
    Check(EqualPixels, 'scaled icon matches native masked icon flattened against image color');
    SavedGraphic := Image.Picture.Graphic; Rejected := False;
    try Borrowed := Image.Canvas; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Image.Picture.Graphic = SavedGraphic), 'icon Canvas access is rejected without converting or losing icon');
    External := TPicture.Create; External.Assign(Image.Picture); Image.Picture := External;
    External.Assign(nil); External.Free; External := nil; Image.Repaint;
    Check(not Image.Picture.Empty and (Image.Picture.Graphic is Graphics.TIcon),
      'picture assignment copies contained icon independently of source lifetime');
    Detached.SetBounds(32760, 0, 1, 1); Detached.Picture.Bitmap.SetSize(32, 32); Rejected := False;
    try Detached.AutoSize := True; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and not Detached.AutoSize and (Detached.Width = 1),
      'overflowing AutoSize enable leaves flag and bounds unchanged');
    Image.TryUpdate := True; Image.Repaint; Image.TryUpdate := False;
    Check((Image.Rejections = 2) and (Window.CallbackErrors = 0) and
      (TGraphicControl(Image).Canvas.Handle = 0), 'nested graphic and parent Update reject paint reentry and clean borrowed DC');
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 60 do
    begin Image.Picture.Icon.LoadFromResource(0, IDI_APPLICATION); Image.Repaint; end;
    Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2),
      'repeated icon replacement and scaled rendering retain GDI and USER resources');
    Window.Free; Window := nil;
    Check(Image.Parent = nil, 'parent destruction detaches surviving image object');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Image.Free; Detached.Free; Window.Free; Source.Free; NativeIcon.Free; ScaledIcon.Free; External.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
