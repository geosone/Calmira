program TestWin16BitBtn;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls, Buttons, PicBtn, native_window;
type
  TPicProbe = class(TPicBtn)
  public
    FailDraw, TestReentry: Boolean;
    Rejections: Integer;
    procedure FinishLoading;
    procedure DrawButton(var Item: TDrawItemStruct); override;
    function HasDrawDC: Boolean;
  end;
  TObserver = class
    Calls: Integer;
    procedure Clicked(Sender: TObject);
  end;
var Root: TCustomControl; Button, Plain: TPicProbe; Source: Graphics.TBitmap;
  Observer: TObserver; Failed, Rejected: Boolean; I, X, Y, Ink, Before, PoolUSER, PoolGDI: Integer;
  LeftX, RightX, TopY, BottomY: Integer; Saved: Graphics.TBitmap;
procedure LogLine(const Text: string);
var F: HFILE; Data: array[0..255] of Char; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Data, Line);
  _lwrite(F, @Data, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TObserver.Clicked(Sender: TObject);
begin Inc(Calls); end;
procedure TPicProbe.FinishLoading;
begin Loaded; end;
function TPicProbe.HasDrawDC: Boolean;
begin Result := Drawing or (Canvas.Handle <> 0); end;
procedure TPicProbe.DrawButton(var Item: TDrawItemStruct);
begin
  if TestReentry then
  begin
    try Parent.Update; except on ENativeWindowError do Inc(Rejections); end;
    try Click; except on ENativeWindowError do Inc(Rejections); end;
  end;
  if FailDraw then raise Exception.Create('bitmap button paint failure');
  inherited DrawButton(Item);
end;
function Pixel(X, Y: Integer): TColor;
var DC: HDC;
begin
  DC := GetDC(Button.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect bitmap button');
  try Result := GetPixel(DC, X, Y); finally ReleaseDC(Button.Handle, DC); end;
end;
procedure RedBounds(var MinX, MinY: Integer);
var DC: HDC; X, Y: Integer;
begin
  MinX := 1000; MinY := 1000; DC := GetDC(Button.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect glyph layout');
  try
    for Y := 0 to Button.Height - 1 do for X := 0 to Button.Width - 1 do
      if GetPixel(DC, X, Y) = DWORD(clRed) then
      begin if X < MinX then MinX := X; if Y < MinY then MinY := Y; end;
  finally ReleaseDC(Button.Handle, DC); end;
end;
begin
  LogLine('STEP original PicBtn and native owner-drawn bitmap button');
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Bitmap button parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 20, 20, 210, 130);
    Source := Graphics.TBitmap.Create; Source.SetSize(12, 4);
    Source.Canvas.Brush.Color := clWhite; Source.Canvas.FillRect(Rect(0, 0, 12, 4));
    Source.Canvas.Brush.Color := clRed; Source.Canvas.FillRect(Rect(1, 1, 3, 3));
    Source.Canvas.Brush.Color := clBlue; Source.Canvas.FillRect(Rect(5, 1, 7, 3));
    Source.Canvas.Brush.Color := clLime; Source.Canvas.FillRect(Rect(9, 1, 11, 3));
    Plain := TPicProbe.Create(nil); Plain.Glyph := Source; PicBtnGlyphs := False;
    Plain.FinishLoading;
    Check(Plain.Glyph.Empty and (Plain.Margin = -1) and (Plain.Spacing = -1) and (Plain.Height = 21),
      'original PicBtn Loaded removes disabled glyphs and applies original height delta');
    PicBtnGlyphs := True; Button := TPicProbe.Create(nil); Button.Glyph := Source;
    Button.NumGlyphs := 3; Button.FinishLoading; Source.Free; Source := nil;
    Check(not Button.Glyph.Empty and (Button.Margin = 4) and (Button.Spacing = -1) and (Button.Height = 23),
      'original PicBtn Loaded retains enabled glyph and original spacing policy');
    Observer := TObserver.Create; Button.OnClick := Observer.Clicked;
    Button.SetBounds(8, 8, 80, 24); Button.Parent := Root; Button.Update;
    Check((Pixel(7, 11) = clRed) and (Pixel(6, 10) = ColorToRGB(clBtnFace)),
      'owner-draw paints normal glyph and preserves transparent-key button face');
    Button.Perform(WM_LBUTTONDOWN, MK_LBUTTON, $00080008); Button.Update;
    Check(Pixel(8, 12) = clLime, 'native pressed state selects pressed strip frame and one-pixel offset');
    Button.Perform(WM_LBUTTONUP, 0, $00080008); Button.Update;
    Check((Observer.Calls = 1) and (Pixel(7, 11) = clRed), 'native release invokes bitmap button click and restores normal glyph');
    Button.Default := True; Button.Cancel := True; Root.SetFocus;
    Before := Observer.Calls;
    Check((DWORD(GetWindowLong(Button.Handle, GWL_STYLE)) and $F = BS_OWNERDRAW) and
      Root.DispatchDialogKey(VK_RETURN) and Root.DispatchDialogKey(VK_ESCAPE) and
      (Observer.Calls = Before + 2), 'bitmap default and cancel retain owner-draw style');
    Button.Default := False; Button.Cancel := False;
    Button.Enabled := False; Button.Update;
    Check(Pixel(7, 11) = clBlue, 'disabled native state selects supplied disabled glyph frame');
    Button.Enabled := True; Button.Caption := 'GO'; Button.Font.Color := clBlue; Button.Margin := -1;
    Button.Height := 50; Button.Update; Ink := 0;
    for Y := 0 to 49 do for X := 0 to 79 do if Pixel(X, Y) = clBlue then Inc(Ink);
    Check(Ink > 0, 'owner-drawn caption uses configured font and text color');
    Button.Layout := blGlyphLeft; Button.Update; RedBounds(LeftX, TopY);
    Button.Layout := blGlyphRight; Button.Update; RedBounds(RightX, BottomY);
    Check((LeftX < RightX) and (RightX < 80), 'glyph left and right layouts reposition supplied bitmap');
    Button.Layout := blGlyphTop; Button.Update; RedBounds(LeftX, TopY);
    Button.Layout := blGlyphBottom; Button.Update; RedBounds(RightX, BottomY);
    Check((TopY < BottomY) and (BottomY < 50), 'glyph top and bottom layouts reposition supplied bitmap');
    Button.Margin := 4; Button.Layout := blGlyphRight; Button.Update; RedBounds(RightX, BottomY);
    Check(RightX = 71, 'explicit right margin is measured inward from right content edge');
    Button.Layout := blGlyphBottom; Button.Update; RedBounds(RightX, BottomY);
    Check(BottomY = 41, 'explicit bottom margin is measured inward from bottom content edge');
    Button.Margin := -1;
    Rejected := False;
    try Button.Margin := -2; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Button.Margin = -1), 'invalid glyph margin preserves previous value');
    Rejected := False;
    try Button.NumGlyphs := 5; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Button.NumGlyphs = 3), 'invalid glyph frame count preserves strip policy');
    Button.TestReentry := True; Button.Repaint; Button.TestReentry := False;
    Check((Button.Rejections = 2) and not Button.HasDrawDC and (Root.CallbackErrors = 0),
      'owner-draw guards parent update and activation while releasing borrowed DC');
    Before := Root.CallbackErrors; Button.FailDraw := True; Button.Repaint; Button.FailDraw := False;
    Check((Root.CallbackErrors > Before) and (Root.LastCallbackError = 'bitmap button paint failure') and
      not Button.HasDrawDC, 'owner-draw failure is contained by parent and releases DC and rendering guard');
    Button.Repaint; RedBounds(LeftX, TopY);
    Check(LeftX < 80, 'bitmap button paint recovers after callback failure');
    Saved := Button.Glyph; Button.Glyph := nil; Button.Update;
    Check((Button.Glyph = Saved) and Button.Glyph.Empty, 'nil glyph clears stable owned bitmap without replacing container');
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES); PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for I := 1 to 60 do
    begin Button.Caption := IntToStr(I); Button.Update; Button.Click; end;
    Check((Observer.Calls = 63) and (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2), 'bitmap button redraw and activation cycles retain USER and GDI resources');
    Check(not Button.HasDrawDC and (Button.CallbackErrors = 0), 'bitmap button retains no borrowed draw context after use');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Button.Free; Plain.Free; Source.Free; Root.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
