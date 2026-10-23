{ SPDX-License-Identifier: GPL-2.0-or-later
  Win16 GDI foundation for the Calmira VCL port, not a complete Graphics unit. }
unit gdi_canvas;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This GDI adapter requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes;
type
  TColor = LongInt;
  EGDIError = class(Exception);
  TPenStyle = (psSolid, psDash, psDot, psDashDot, psDashDotDot, psClear, psInsideFrame);
  TBrushStyle = (bsSolid, bsClear, bsHorizontal, bsVertical, bsFDiagonal,
    bsBDiagonal, bsCross, bsDiagCross);
  TFontStyle = (fsBold, fsItalic, fsUnderline, fsStrikeOut);
  TFontStyles = set of TFontStyle;
  TFillStyle = (fsSurface, fsBorder);
  TGDIGraphic = class(TPersistent)
  private
    FOnChange: TNotifyEvent;
  protected
    procedure Changed;
    function GetWidth: SmallInt; virtual; abstract;
    function GetHeight: SmallInt; virtual; abstract;
    function GetEmpty: Boolean; virtual; abstract;
  public
    procedure DrawTo(Destination: HDC; X, Y: SmallInt); virtual; abstract;
    procedure StretchTo(Destination: HDC; const Area: TRect); virtual;
    property Width: SmallInt read GetWidth;
    property Height: SmallInt read GetHeight;
    property Empty: Boolean read GetEmpty;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;
  TGDIResource = class(TPersistent)
  private
    FHandle: HGDIOBJ;
    FOwned: Boolean;
  protected
    procedure ReleaseHandle;
  public
    destructor Destroy; override;
    procedure Invalidate;
  end;
  TGDIPen = class(TGDIResource)
  private
    FColor: TColor;
    FWidth: SmallInt;
    FStyle: TPenStyle;
    procedure SetColor(Value: TColor);
    procedure SetWidth(Value: SmallInt);
    procedure SetStyle(Value: TPenStyle);
    function GetHandle: HPEN;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
    property Color: TColor read FColor write SetColor;
    property Width: SmallInt read FWidth write SetWidth;
    property Style: TPenStyle read FStyle write SetStyle;
    property Handle: HPEN read GetHandle;
  end;
  TGDIBrush = class(TGDIResource)
  private
    FPattern: HBITMAP;
    FColor: TColor;
    FStyle: TBrushStyle;
    procedure SetColor(Value: TColor);
    procedure SetStyle(Value: TBrushStyle);
    function GetHandle: HBRUSH;
    procedure ReplacePattern(Value: HBITMAP);
  protected
    procedure SetPattern(Source: HDC; Width, Height: SmallInt);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property Color: TColor read FColor write SetColor;
    property Style: TBrushStyle read FStyle write SetStyle;
    property Handle: HBRUSH read GetHandle;
  end;
  TGDIFont = class(TGDIResource)
  private
    FOnChange: TNotifyEvent;
    FNotifying: Boolean;
    FName: string;
    FHeight: SmallInt;
    FColor: TColor;
    FStyle: TFontStyles;
    FPixelsPerInch: SmallInt;
    procedure SetName(const Value: string);
    procedure SetHeight(Value: SmallInt);
    procedure SetStyle(Value: TFontStyles);
    procedure SetColor(Value: TColor);
    procedure Changed;
    function GetHandle: HFONT;
    function GetSize: SmallInt;
    procedure SetSize(Value: SmallInt);
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
    property Name: string read FName write SetName;
    property Height: SmallInt read FHeight write SetHeight;
    property Color: TColor read FColor write SetColor;
    property Style: TFontStyles read FStyle write SetStyle;
    property Size: SmallInt read GetSize write SetSize;
    property PixelsPerInch: SmallInt read FPixelsPerInch;
    property Handle: HFONT read GetHandle;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;
  TGDICanvas = class
  private
    FOnChange: TNotifyEvent;
    FHandle: HDC;
    FPen: TGDIPen;
    FBrush: TGDIBrush;
    FFont: TGDIFont;
    procedure Changed;
    procedure RequireHandle;
    function BeginDraw: SmallInt;
    procedure EndDraw(State: SmallInt);
    procedure SelectFont;
    function GetPixel(X, Y: SmallInt): TColor;
    procedure SetPixel(X, Y: SmallInt; Value: TColor);
    procedure SetPen(Value: TGDIPen);
    procedure SetBrush(Value: TGDIBrush);
    procedure SetFont(Value: TGDIFont);
  protected
    function CreateBrush: TGDIBrush; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure MoveTo(X, Y: SmallInt);
    procedure LineTo(X, Y: SmallInt);
    procedure PolyLine(const Points: array of TPoint);
    procedure Rectangle(Left, Top, Right, Bottom: SmallInt);
    procedure Pie(Left, Top, Right, Bottom, StartX, StartY, EndX, EndY: SmallInt);
    procedure FloodFill(X, Y: SmallInt; Color: TColor; FillStyle: TFillStyle);
    procedure FillRect(const Area: TRect);
    procedure DrawFocusRect(const Area: TRect);
    procedure TextRect(const Area: TRect; X, Y: SmallInt; const Text: string);
    procedure CopyRect(const Destination: TRect; Source: TGDICanvas;
      const SourceRect: TRect);
    procedure Draw(X, Y: SmallInt; Graphic: TGDIGraphic);
    procedure StretchDraw(const Area: TRect; Graphic: TGDIGraphic);
    procedure CopyTransparent(const Destination: TRect; Source: TGDICanvas;
      const SourceRect: TRect; KeyColor: TColor);
    procedure BrushCopy(const Destination: TRect; Source: TGDICanvas;
      const SourceRect: TRect; KeyColor: TColor);
    procedure TextOut(X, Y: SmallInt; const Text: string);
    function TextExtent(const Text: string): TPoint;
    function TextWidth(const Text: string): SmallInt;
    function TextHeight(const Text: string): SmallInt;
    procedure RefreshSystemColors;
    property Handle: HDC read FHandle write FHandle;
    property Pen: TGDIPen read FPen write SetPen;
    property Brush: TGDIBrush read FBrush write SetBrush;
    property Font: TGDIFont read FFont write SetFont;
    property Pixels[X, Y: SmallInt]: TColor read GetPixel write SetPixel;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;
const
  clBlack = TColor($000000); clWhite = TColor($FFFFFF);
  clRed = TColor($0000FF); clLime = TColor($00FF00); clBlue = TColor($FF0000);
  { Delphi 1 system colours: -(COLOR_x) - 1. }
  clWindow = TColor(-6); clBtnFace = TColor(-16);
function ColorToRGB(Color: TColor): LongInt;
implementation
uses WinProcs, gdi_colorkey;

function CopyPattern(Source: HDC): HBITMAP;
var Temp: HDC; Value: HBITMAP; Previous: HGDIOBJ;
begin
  Temp := 0; Value := 0; Previous := 0;
  try
    Temp := CreateCompatibleDC(Source);
    if Temp = 0 then raise EGDIError.Create('Cannot create pattern DC');
    Value := CreateCompatibleBitmap(Source, 8, 8);
    if Value = 0 then raise EGDIError.Create('Cannot create pattern bitmap');
    Previous := SelectObject(Temp, Value);
    if Previous = 0 then raise EGDIError.Create('Cannot select pattern bitmap');
    if not BitBlt(Temp, 0, 0, 8, 8, Source, 0, 0, SRCCOPY) then
      raise EGDIError.Create('Cannot copy pattern pixels');
  except
    if (Temp <> 0) and (Previous <> 0) then SelectObject(Temp, Previous);
    if Temp <> 0 then DeleteDC(Temp);
    if Value <> 0 then DeleteObject(Value);
    raise;
  end;
  SelectObject(Temp, Previous); DeleteDC(Temp); Result := Value;
end;

procedure TGDIGraphic.Changed;
begin if Assigned(FOnChange) then FOnChange(Self); end;
procedure TGDIGraphic.StretchTo(Destination: HDC; const Area: TRect);
begin
  if (LongInt(Area.Right) - Area.Left <> Width) or
    (LongInt(Area.Bottom) - Area.Top <> Height) then
    raise EGDIError.Create('Scaling is not supported for this graphic');
  DrawTo(Destination, Area.Left, Area.Top);
end;
procedure TGDICanvas.Changed;
begin if Assigned(FOnChange) then FOnChange(Self); end;

function ColorToRGB(Color: TColor): LongInt;
begin
  if Color < 0 then Result := GetSysColor(-(Color + 1))
  else Result := Color and $FFFFFF;
end;
procedure TGDIResource.ReleaseHandle;
begin
  if FOwned and (FHandle <> 0) then
    if not DeleteObject(FHandle) then raise EGDIError.Create('Cannot release GDI object');
  FHandle := 0; FOwned := False;
end;
procedure TGDIResource.Invalidate;
begin ReleaseHandle; end;
destructor TGDIResource.Destroy;
begin ReleaseHandle; inherited Destroy; end;
constructor TGDIPen.Create;
begin inherited Create; FWidth := 1; end;
procedure TGDIPen.SetColor(Value: TColor);
begin if Value <> FColor then begin ReleaseHandle; FColor := Value; end; end;
procedure TGDIPen.SetWidth(Value: SmallInt);
begin
  if Value < 0 then raise EGDIError.Create('Pen width must not be negative');
  if Value <> FWidth then begin ReleaseHandle; FWidth := Value; end;
end;
procedure TGDIPen.SetStyle(Value: TPenStyle);
begin if Value <> FStyle then begin ReleaseHandle; FStyle := Value; end; end;
function TGDIPen.GetHandle: HPEN;
begin
  if FHandle = 0 then
  begin
    if FStyle = psClear then FHandle := GetStockObject(NULL_PEN)
    else begin FHandle := CreatePen(Ord(FStyle), FWidth, ColorToRGB(FColor)); FOwned := True; end;
    if FHandle = 0 then raise EGDIError.Create('Cannot create GDI pen');
  end;
  Result := FHandle;
end;
procedure TGDIPen.Assign(Source: TPersistent);
begin
  if Source = Self then Exit;
  if Source is TGDIPen then
  begin ReleaseHandle; FColor := TGDIPen(Source).FColor; FWidth := TGDIPen(Source).FWidth;
    FStyle := TGDIPen(Source).FStyle; end
  else inherited Assign(Source);
end;
constructor TGDIBrush.Create;
begin inherited Create; FColor := clWhite; end;
procedure TGDIBrush.ReplacePattern(Value: HBITMAP);
begin
  try ReleaseHandle;
  except if Value <> 0 then DeleteObject(Value); raise; end;
  if FPattern <> 0 then DeleteObject(FPattern);
  FPattern := Value; FStyle := bsSolid;
end;
procedure TGDIBrush.SetPattern(Source: HDC; Width, Height: SmallInt);
begin
  if Source = 0 then begin ReplacePattern(0); Exit; end;
  if (Width <> 8) or (Height <> 8) then raise EGDIError.Create('Pattern bitmap must be 8 by 8');
  ReplacePattern(CopyPattern(Source));
end;
destructor TGDIBrush.Destroy;
begin ReplacePattern(0); inherited Destroy; end;
procedure TGDIBrush.SetColor(Value: TColor);
begin
  { Even assigning the existing color must leave bitmap-pattern mode. }
  if FPattern <> 0 then ReplacePattern(0);
  if Value <> FColor then begin ReleaseHandle; FColor := Value; end;
end;
procedure TGDIBrush.SetStyle(Value: TBrushStyle);
begin
  if FPattern <> 0 then ReplacePattern(0);
  if Value <> FStyle then begin ReleaseHandle; FStyle := Value; end;
end;
function TGDIBrush.GetHandle: HBRUSH;
begin
  if FHandle = 0 then
  begin
    if FPattern <> 0 then
    begin FHandle := CreatePatternBrush(FPattern); FOwned := True; end
    else
    case FStyle of
      bsClear: FHandle := GetStockObject(NULL_BRUSH);
      bsSolid: begin FHandle := CreateSolidBrush(ColorToRGB(FColor)); FOwned := True; end;
    else FHandle := CreateHatchBrush(Ord(FStyle) - 2, ColorToRGB(FColor)); FOwned := True;
    end;
    if FHandle = 0 then raise EGDIError.Create('Cannot create GDI brush');
  end;
  Result := FHandle;
end;
procedure TGDIBrush.Assign(Source: TPersistent);
var Copy: HBITMAP; Temp: HDC; Previous: HGDIOBJ;
begin
  if Source = Self then Exit;
  if Source is TGDIBrush then
  begin
    Copy := 0;
    if TGDIBrush(Source).FPattern <> 0 then
    begin
      Temp := CreateCompatibleDC(0);
      if Temp = 0 then raise EGDIError.Create('Cannot create pattern source DC');
      Previous := 0;
      try
        Previous := SelectObject(Temp, TGDIBrush(Source).FPattern);
        if Previous = 0 then raise EGDIError.Create('Cannot select source pattern');
        Copy := CopyPattern(Temp);
      finally
        if Previous <> 0 then SelectObject(Temp, Previous);
        DeleteDC(Temp);
      end;
    end;
    ReplacePattern(Copy); FColor := TGDIBrush(Source).FColor; FStyle := TGDIBrush(Source).FStyle;
  end
  else inherited Assign(Source);
end;
constructor TGDIFont.Create;
var Display: HDC;
begin
  inherited Create; FName := 'MS Sans Serif'; FHeight := -11;
  FPixelsPerInch := 96; Display := GetDC(0);
  if Display <> 0 then
  begin
    FPixelsPerInch := GetDeviceCaps(Display, LOGPIXELSY);
    ReleaseDC(0, Display);
    if FPixelsPerInch <= 0 then FPixelsPerInch := 96;
  end;
end;
function TGDIFont.GetSize: SmallInt;
var Points: LongInt;
begin
  Points := (Abs(LongInt(FHeight)) * 72 + FPixelsPerInch div 2) div FPixelsPerInch;
  if Points > 32767 then raise EGDIError.Create('Font point size exceeds Win16 range');
  Result := Points;
end;
procedure TGDIFont.SetSize(Value: SmallInt);
var Pixels: LongInt;
begin
  if Value < 0 then raise EGDIError.Create('Font size must not be negative');
  Pixels := (LongInt(Value) * FPixelsPerInch + 36) div 72;
  if Pixels > 32767 then raise EGDIError.Create('Font size exceeds Win16 height');
  SetHeight(-Pixels);
end;
procedure TGDIFont.SetName(const Value: string);
begin
  if Length(Value) >= LF_FACESIZE then raise EGDIError.Create('Font name is too long');
  if Value <> FName then begin ReleaseHandle; FName := Value; Changed; end;
end;
procedure TGDIFont.SetHeight(Value: SmallInt);
begin if Value <> FHeight then begin ReleaseHandle; FHeight := Value; Changed; end; end;
procedure TGDIFont.SetStyle(Value: TFontStyles);
begin if Value <> FStyle then begin ReleaseHandle; FStyle := Value; Changed; end; end;
procedure TGDIFont.SetColor(Value: TColor);
begin if Value <> FColor then begin FColor := Value; Changed; end; end;
procedure TGDIFont.Changed;
begin
  if FNotifying or not Assigned(FOnChange) then Exit;
  FNotifying := True;
  try FOnChange(Self); finally FNotifying := False; end;
end;
function TGDIFont.GetHandle: HFONT;
var Description: TLogFont;
begin
  if FHandle = 0 then
  begin
    FillChar(Description, SizeOf(Description), 0);
    Description.lfHeight := FHeight;
    Description.lfWeight := FW_NORMAL;
    if fsBold in FStyle then Description.lfWeight := FW_BOLD;
    Description.lfItalic := Ord(fsItalic in FStyle);
    Description.lfUnderline := Ord(fsUnderline in FStyle);
    Description.lfStrikeOut := Ord(fsStrikeOut in FStyle);
    Description.lfCharSet := DEFAULT_CHARSET;
    StrPCopy(Description.lfFaceName, FName);
    FHandle := CreateFontIndirect(Description); FOwned := True;
    if FHandle = 0 then raise EGDIError.Create('Cannot create GDI font');
  end;
  Result := FHandle;
end;
procedure TGDIFont.Assign(Source: TPersistent);
begin
  if Source = Self then Exit;
  if Source is TGDIFont then
  begin
    if (FName = TGDIFont(Source).FName) and (FHeight = TGDIFont(Source).FHeight) and
      (FColor = TGDIFont(Source).FColor) and (FStyle = TGDIFont(Source).FStyle) and
      (FPixelsPerInch = TGDIFont(Source).FPixelsPerInch) then Exit;
    ReleaseHandle; FName := TGDIFont(Source).FName; FHeight := TGDIFont(Source).FHeight;
    FColor := TGDIFont(Source).FColor; FStyle := TGDIFont(Source).FStyle;
    FPixelsPerInch := TGDIFont(Source).FPixelsPerInch; Changed; end
  else inherited Assign(Source);
end;
constructor TGDICanvas.Create;
begin
  inherited Create; FPen := TGDIPen.Create; FBrush := CreateBrush; FFont := TGDIFont.Create;
end;
function TGDICanvas.CreateBrush: TGDIBrush;
begin Result := TGDIBrush.Create; end;
destructor TGDICanvas.Destroy;
begin FFont.Free; FBrush.Free; FPen.Free; inherited Destroy; end;
procedure TGDICanvas.SetPen(Value: TGDIPen);
begin FPen.Assign(Value); end;
procedure TGDICanvas.SetBrush(Value: TGDIBrush);
begin FBrush.Assign(Value); end;
procedure TGDICanvas.SetFont(Value: TGDIFont);
begin FFont.Assign(Value); end;
procedure TGDICanvas.RequireHandle;
begin if FHandle = 0 then raise EGDIError.Create('Canvas has no device context'); end;
function TGDICanvas.BeginDraw: SmallInt;
begin
  RequireHandle; Result := SaveDC(FHandle);
  if Result = 0 then raise EGDIError.Create('Cannot save GDI context');
end;
procedure TGDICanvas.EndDraw(State: SmallInt);
begin if not RestoreDC(FHandle, State) then raise EGDIError.Create('Cannot restore GDI context'); end;
procedure TGDICanvas.MoveTo(X, Y: SmallInt);
begin RequireHandle; WinProcs.MoveTo(FHandle, X, Y); end;
procedure TGDICanvas.LineTo(X, Y: SmallInt);
var State: SmallInt;
begin
  State := BeginDraw;
  try
    if SelectObject(FHandle, FPen.GetHandle) = 0 then raise EGDIError.Create('Cannot select pen');
    SetROP2(FHandle, R2_COPYPEN);
    if not WinProcs.LineTo(FHandle, X, Y) then raise EGDIError.Create('Cannot draw line');
  finally EndDraw(State); end;
  WinProcs.MoveTo(FHandle, X, Y);
  Changed;
end;
procedure TGDICanvas.PolyLine(const Points: array of TPoint);
var State: SmallInt;
begin
  if High(Points) < 0 then Exit;
  State := BeginDraw;
  try
    if SelectObject(FHandle, FPen.GetHandle) = 0 then raise EGDIError.Create('Cannot select pen');
    SetROP2(FHandle, R2_COPYPEN);
    if not WinProcs.Polyline(FHandle, @Points[0], High(Points) + 1) then
      raise EGDIError.Create('Cannot draw polyline');
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.Rectangle(Left, Top, Right, Bottom: SmallInt);
var State: SmallInt;
begin
  State := BeginDraw;
  try
    if (SelectObject(FHandle, FPen.GetHandle) = 0) or
      (SelectObject(FHandle, FBrush.GetHandle) = 0) then raise EGDIError.Create('Cannot select drawing objects');
    SetROP2(FHandle, R2_COPYPEN);
    if not WinProcs.Rectangle(FHandle, Left, Top, Right, Bottom) then raise EGDIError.Create('Cannot draw rectangle');
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.FillRect(const Area: TRect);
var State: SmallInt;
begin
  RequireHandle;
  if FBrush.Style = bsClear then Exit;
  State := BeginDraw;
  try
    SetROP2(FHandle, R2_COPYPEN);
    if WinProcs.FillRect(FHandle, @Area, FBrush.GetHandle) = 0 then raise EGDIError.Create('Cannot fill rectangle');
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.SelectFont;
begin
  if SelectObject(FHandle, FFont.GetHandle) = 0 then raise EGDIError.Create('Cannot select font');
end;
procedure TGDICanvas.DrawFocusRect(const Area: TRect);
var State: SmallInt;
begin
  RequireHandle;
  if (Area.Right <= Area.Left) or (Area.Bottom <= Area.Top) then Exit;
  State := BeginDraw;
  try
    SetTextColor(FHandle, 0); SetBkColor(FHandle, $FFFFFF);
    WinProcs.DrawFocusRect(FHandle, @Area);
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.TextRect(const Area: TRect; X, Y: SmallInt; const Text: string);
var State: SmallInt; Buffer: array[0..255] of Char; Options: Word;
begin
  RequireHandle;
  if (Area.Right <= Area.Left) or (Area.Bottom <= Area.Top) then Exit;
  State := BeginDraw;
  try
    SelectFont; StrPCopy(Buffer, Text); Options := ETO_CLIPPED;
    SetROP2(FHandle, R2_COPYPEN);
    SetTextAlign(FHandle, TA_LEFT or TA_TOP or TA_NOUPDATECP);
    { Fill with the real brush, including hatch/pattern, not just its color. }
    if FBrush.Style <> bsClear then
      if WinProcs.FillRect(FHandle, @Area, FBrush.GetHandle) = 0 then
        raise EGDIError.Create('Cannot fill text rectangle');
    SetTextColor(FHandle, ColorToRGB(FFont.Color));
    SetBkMode(FHandle, TRANSPARENT);
    if not ExtTextOut(FHandle, X, Y, Options, @Area, Buffer, Length(Text), nil) then
      raise EGDIError.Create('Cannot draw clipped text');
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.Pie(Left, Top, Right, Bottom, StartX, StartY, EndX, EndY: SmallInt);
var State: SmallInt;
begin
  State := BeginDraw;
  try
    if (SelectObject(FHandle, FPen.GetHandle) = 0) or
      (SelectObject(FHandle, FBrush.GetHandle) = 0) then raise EGDIError.Create('Cannot select pie resources');
    SetROP2(FHandle, R2_COPYPEN);
    if not WinProcs.Pie(FHandle, Left, Top, Right, Bottom, StartX, StartY, EndX, EndY) then
      raise EGDIError.Create('Cannot draw pie');
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.FloodFill(X, Y: SmallInt; Color: TColor; FillStyle: TFillStyle);
var State: SmallInt; Drawn: Boolean; Mode: Word;
begin
  RequireHandle;
  if FBrush.Style = bsClear then Exit;
  State := BeginDraw;
  try
    if SelectObject(FHandle, FBrush.GetHandle) = 0 then raise EGDIError.Create('Cannot select fill brush');
    SetROP2(FHandle, R2_COPYPEN);
    if FillStyle = fsSurface then Mode := FLOODFILLSURFACE else Mode := FLOODFILLBORDER;
    Drawn := ExtFloodFill(FHandle, X, Y, ColorToRGB(Color), Mode);
  finally EndDraw(State); end;
  if Drawn then Changed;
end;
procedure TGDICanvas.Draw(X, Y: SmallInt; Graphic: TGDIGraphic);
var State: SmallInt;
begin
  if Graphic = nil then raise EGDIError.Create('Missing graphic');
  State := BeginDraw;
  try Graphic.DrawTo(FHandle, X, Y); finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.StretchDraw(const Area: TRect; Graphic: TGDIGraphic);
var State: SmallInt; W, H: LongInt;
begin
  if Graphic = nil then raise EGDIError.Create('Missing graphic');
  RequireHandle;
  W := LongInt(Area.Right) - Area.Left; H := LongInt(Area.Bottom) - Area.Top;
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then
    raise EGDIError.Create('Invalid stretch destination size');
  if (W = 0) or (H = 0) or Graphic.Empty then Exit;
  State := BeginDraw;
  try Graphic.StretchTo(FHandle, Area); finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.CopyTransparent(const Destination: TRect; Source: TGDICanvas;
  const SourceRect: TRect; KeyColor: TColor);
begin
  RequireHandle;
  if Source = nil then raise EGDIError.Create('Missing source canvas');
  Source.RequireHandle;
  ColorKeyCopy(FHandle, Destination, Source.FHandle, SourceRect, ColorToRGB(KeyColor), 0);
  if (Destination.Right > Destination.Left) and (Destination.Bottom > Destination.Top) and
    (SourceRect.Right > SourceRect.Left) and (SourceRect.Bottom > SourceRect.Top) then Changed;
end;
procedure TGDICanvas.BrushCopy(const Destination: TRect; Source: TGDICanvas;
  const SourceRect: TRect; KeyColor: TColor);
begin
  RequireHandle;
  if Source = nil then raise EGDIError.Create('Missing source canvas');
  Source.RequireHandle;
  if FBrush.Style = bsClear then
    ColorKeyCopy(FHandle, Destination, Source.FHandle, SourceRect, ColorToRGB(KeyColor), 0)
  else ColorKeyCopy(FHandle, Destination, Source.FHandle, SourceRect,
    ColorToRGB(KeyColor), FBrush.GetHandle);
  if (Destination.Right > Destination.Left) and (Destination.Bottom > Destination.Top) and
    (SourceRect.Right > SourceRect.Left) and (SourceRect.Bottom > SourceRect.Top) then Changed;
end;
procedure TGDICanvas.TextOut(X, Y: SmallInt; const Text: string);
var State: SmallInt; Buffer: array[0..255] of Char;
begin
  State := BeginDraw;
  try
    SelectFont; StrPCopy(Buffer, Text);
    SetROP2(FHandle, R2_COPYPEN);
    SetTextAlign(FHandle, TA_LEFT or TA_TOP or TA_NOUPDATECP);
    SetTextColor(FHandle, ColorToRGB(FFont.Color));
    if FBrush.Style = bsClear then SetBkMode(FHandle, TRANSPARENT)
    else begin SetBkMode(FHandle, OPAQUE); SetBkColor(FHandle, ColorToRGB(FBrush.Color)); end;
    if not WinProcs.TextOut(FHandle, X, Y, Buffer, Length(Text)) then raise EGDIError.Create('Cannot draw text');
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.CopyRect(const Destination: TRect; Source: TGDICanvas;
  const SourceRect: TRect);
var DW, DH, SW, SH: LongInt; State: SmallInt;
begin
  RequireHandle;
  if Source = nil then raise EGDIError.Create('Missing source canvas');
  Source.RequireHandle;
  { Subtract in 32 bits: signed Win16 coordinates can span 65535 units. }
  DW := LongInt(Destination.Right) - Destination.Left;
  DH := LongInt(Destination.Bottom) - Destination.Top;
  SW := LongInt(SourceRect.Right) - SourceRect.Left;
  SH := LongInt(SourceRect.Bottom) - SourceRect.Top;
  if (DW < 0) or (DH < 0) or (SW < 0) or (SH < 0) or
    (DW > 32767) or (DH > 32767) or (SW > 32767) or (SH > 32767) then
    raise EGDIError.Create('Unsupported copy rectangle');
  if (DW = 0) or (DH = 0) or (SW = 0) or (SH = 0) then Exit;
  if (FHandle = Source.FHandle) and ((DW <> SW) or (DH <> SH)) then
    raise EGDIError.Create('Scaled self-copy requires a separate source bitmap');
  State := BeginDraw;
  try
    if (DW = SW) and (DH = SH) then
    begin
      if not BitBlt(FHandle, Destination.Left, Destination.Top, DW, DH,
        Source.FHandle, SourceRect.Left, SourceRect.Top, SRCCOPY) then
        raise EGDIError.Create('Cannot copy rectangle');
    end
    else
    begin
      if SetStretchBltMode(FHandle, COLORONCOLOR) = 0 then
        raise EGDIError.Create('Cannot set bitmap stretch mode');
      if not StretchBlt(FHandle, Destination.Left, Destination.Top, DW, DH,
        Source.FHandle, SourceRect.Left, SourceRect.Top, SW, SH, SRCCOPY) then
        raise EGDIError.Create('Cannot scale rectangle');
    end;
  finally EndDraw(State); end;
  Changed;
end;
function TGDICanvas.TextExtent(const Text: string): TPoint;
var State: SmallInt; Buffer: array[0..255] of Char; Extent: LongInt;
begin
  State := BeginDraw;
  try
    SelectFont; StrPCopy(Buffer, Text);
    Extent := GetTextExtent(FHandle, Buffer, Length(Text));
    Result.X := LoWord(Extent); Result.Y := HiWord(Extent);
  finally EndDraw(State); end;
end;
function TGDICanvas.TextWidth(const Text: string): SmallInt;
var Extent: TPoint;
begin Extent := TextExtent(Text); Result := Extent.X; end;
function TGDICanvas.TextHeight(const Text: string): SmallInt;
var Extent: TPoint;
begin Extent := TextExtent(Text); Result := Extent.Y; end;
function TGDICanvas.GetPixel(X, Y: SmallInt): TColor;
begin RequireHandle; Result := WinProcs.GetPixel(FHandle, X, Y); end;
procedure TGDICanvas.SetPixel(X, Y: SmallInt; Value: TColor);
var State: SmallInt;
begin
  State := BeginDraw;
  try
    SetROP2(FHandle, R2_COPYPEN);
    if WinProcs.SetPixel(FHandle, X, Y, ColorToRGB(Value)) = DWORD($FFFFFFFF) then Exit;
  finally EndDraw(State); end;
  Changed;
end;
procedure TGDICanvas.RefreshSystemColors;
begin FPen.Invalidate; FBrush.Invalidate; FFont.Invalidate; end;
end.
