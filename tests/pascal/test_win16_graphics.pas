program TestWin16Graphics;
{$mode delphi}{$H+}{$APPTYPE GUI}{$M 4096,4096}
{ Intentionally use only the public compatibility API and the unchanged
  original CalColor unit, not the foundation unit names. }
uses WinTypes, WinProcs, Classes, SysUtils, Graphics, CalColor;
type
  TTestResource = class(Graphics.TBitmap)
  public constructor Load;
  end;
  TColorCollector = class
    Count: Integer;
    procedure Visit(const Name: string);
  end;
var Image, CopyImage: Graphics.TBitmap; Resource: TTestResource;
  Icon: Graphics.TIcon; Canvas: TCanvas; Font: TFont; Collector: TColorCollector;
  Failed, Rejected: Boolean; N, OldHeight: SmallInt;
  OldCanvas: TCanvas; Value: LongInt; Name: string; OldHandle: HBITMAP;
  Area: TRect;
procedure LogLine(const Text: string);
var F: HFILE; Buffer: array[0..255] of Char; Line: ShortString;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Buffer, Line);
  _lwrite(F, @Buffer, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Description: string);
begin
  if Okay then LogLine('PASS ' + Description)
  else begin Failed := True; LogLine('FAIL ' + Description); end;
end;
constructor TTestResource.Load;
begin inherited Create; LoadFromResourceName(HInstance, 'PROBE'); end;
procedure TColorCollector.Visit(const Name: string);
var Color: LongInt;
begin Check(IdentToColor(Name, Color), 'enumerated graphics color parses'); Inc(Count); end;
begin
  LogLine('STEP Graphics compatibility');
  try
    Check((SizeOf(TRect) = 8) and (SizeOf(TPoint) = 4), 'public rectangle and point have Win16 ABI');
    Area := Bounds(3, 4, 16, 16);
    Check((Area.Left = 3) and (Area.Top = 4) and (Area.Right = 19) and (Area.Bottom = 20),
      'public Bounds returns native rectangle');
    Rejected := False;
    try Bounds(32767, 0, 1, 1); except on Exception do Rejected := True; end;
    Check(Rejected, 'public Bounds rejects coordinate overflow');
    Image := Graphics.TBitmap.Create; CopyImage := Graphics.TBitmap.Create;
    Icon := Graphics.TIcon.Create; Canvas := TCanvas.Create; Font := TFont.Create;
    Check(Image.Empty and Icon.Empty, 'new public graphics are empty');
    Image.Width := 16; Image.Height := 16;
    OldCanvas := Image.Canvas;
    Check(Image.Canvas is TCanvas, 'bitmap factory supplies public TCanvas');
    Image.Canvas.Brush.Color := clBlue; Image.Canvas.FillRect(Rect(0, 0, 16, 16));
    Image.Canvas.Pixels[0, 0] := clWhite; Image.Canvas.Pixels[1, 0] := clRed;
    CopyImage.Width := 16; CopyImage.Height := 16;
    CopyImage.Canvas.Brush.Color := clLime;
    CopyImage.Canvas.BrushCopy(Bounds(0, 0, 16, 16), Image, Rect(0, 0, 16, 16), clWhite);
    Check((CopyImage.Canvas.Pixels[0, 0] = clLime) and
      (CopyImage.Canvas.Pixels[1, 0] = clRed), 'original bitmap-argument BrushCopy signature');
    Image.Height := 32;
    Check((Image.Canvas = OldCanvas) and (Image.Canvas.Pixels[1, 0] = clRed),
      'public canvas identity and pixels survive resize');
    CopyImage.Assign(Image);
    CopyImage.Canvas.Pixels[1, 0] := clBlack;
    Check((Image.Canvas.Pixels[1, 0] = clRed) and (CopyImage.Canvas is TCanvas),
      'public Assign stays independent with public canvas');
    Canvas.Handle := CopyImage.Canvas.Handle;
    Font.Size := 8; Font.Color := clRed;
    Canvas.Font := Font;
    Check((Canvas.Font <> Font) and (Canvas.Font.Size = 8), 'font property assignment copies state');
    Font.Size := 12;
    Check(Canvas.Font.Size = 8, 'assigned font is not aliased');
    Check((Font.Height < 0) and (Font.Size = 12) and (Font.PixelsPerInch > 0),
      'point size uses native display DPI and character height');
    OldHeight := Font.Height; Rejected := False;
    try Font.Size := -1; except on Exception do Rejected := True; end;
    Check(Rejected and (Font.Height = OldHeight), 'negative point size preserves font');
    Canvas.Brush := Image.Canvas.Brush; Canvas.Pen := Image.Canvas.Pen;
    Check((Canvas.Brush <> Image.Canvas.Brush) and (Canvas.Pen <> Image.Canvas.Pen),
      'pen and brush property assignment do not alias objects');
    Check((Canvas.Pen.Handle <> 0) and (Canvas.Brush.Handle <> 0) and
      (Canvas.Font.Handle <> 0), 'public resource handles are native GDI objects');
    Canvas.Font.Color := clRed; Canvas.TextOut(0, 16, 'Calmira');
    Resource := TTestResource.Load;
    Check((Resource.Width = 24) and (Resource.Height = 256), 'derived bitmap resource constructor');
    Resource.LoadFromResourceID(HInstance, 101);
    Check((Resource.Width = 16) and (Resource.Height = 16), 'public numeric resource loader');
    OldHandle := Resource.Handle; Rejected := False;
    try Resource.LoadFromResourceName(HInstance, 'PROBE' + #0 + 'suffix');
    except on Exception do Rejected := True; end;
    Check(Rejected and (Resource.Handle = OldHandle), 'embedded NUL resource name rejected transactionally');
    Canvas.Draw(0, 0, Resource);
    Icon.LoadFromResource(HInstance, PChar(201)); Canvas.Draw(0, 0, Icon);
    Check(not Icon.Empty, 'public icon draws through common graphic interface');
    Value := 0; Name := '';
    Check(IdentToColor('clBtnFace', Value) and (Value = clBtnFace), 'Graphics color identifier');
    Check(ColorToIdent(clBtnFace, Name) and (Name = 'clBtnFace'), 'Graphics color name');
    Check(ColorToRGB(clWindow) = GetSysColor(COLOR_WINDOW), 'public system-color resolution');
    Check(StringToColor(ColorToString($123456)) = $123456, 'public numeric color round trip');
    Rejected := False;
    try StringToColor('$FFFFFFFFFFFFFFFF'); except on EConvertError do Rejected := True; end;
    Check(Rejected, 'public numeric color rejects 64-bit overflow');
    Check(CalColorToString(CalColor.clCream) = 'clCream', 'unchanged CalColor extension name');
    Check(StringToCalColor('CLMONEYGREEN') = CalColor.clMoneyGreen, 'unchanged CalColor extension parser');
    Check(StringToCalColor('$00123456') = $123456, 'unchanged CalColor numeric fallback');
    Collector := TColorCollector.Create;
    GetColorValues(Collector.Visit); N := Collector.Count;
    Check(N = 39, 'public color enumeration callback');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Collector.Free; Resource.Free; Font.Free; Canvas.Free; Icon.Free; CopyImage.Free; Image.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
