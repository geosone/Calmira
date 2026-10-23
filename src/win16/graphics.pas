{ SPDX-License-Identifier: GPL-2.0-or-later
  Tested Win16 Graphics compatibility subset, not the complete Delphi VCL. }
unit Graphics;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Graphics adapter requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, gdi_canvas, gdi_bitmap, gdi_icon;
type
  TRect = WinTypes.TRect;
  TPoint = WinTypes.TPoint;
  TColor = gdi_canvas.TColor;
  { Delphi 1 Classes type with a ShortString argument (FPC's takes AnsiString). }
  TGetStrProc = procedure(const S: string) of object;
  TGraphic = TGDIGraphic;
  TPen = TGDIPen;
  TFont = TGDIFont;
  TPenStyle = gdi_canvas.TPenStyle;
  TBrushStyle = gdi_canvas.TBrushStyle;
  TFontStyle = gdi_canvas.TFontStyle;
  TFontStyles = gdi_canvas.TFontStyles;
  TFillStyle = gdi_canvas.TFillStyle;
  TBitmap = class;
  TBrush = class(TGDIBrush)
  private
    FBitmap: TBitmap;
    procedure SetBitmap(Value: TBitmap);
  public
    { The pattern is a snapshot, so the brush stays valid after the bitmap is
      freed. As in Delphi 1 the brush does not own the bitmap: the getter only
      returns the caller's reference so it can free it (Calmira's IconMesh). }
    property Bitmap: TBitmap read FBitmap write SetBitmap;
  end;
  TCanvas = class(TGDICanvas)
  private
    function GetBrush: TBrush;
    procedure SetBrush(Value: TBrush);
  protected
    function CreateBrush: TGDIBrush; override;
  public
    procedure BrushCopy(const Destination: TRect; Bitmap: TBitmap;
      const SourceRect: TRect; Color: TColor); reintroduce; overload;
    property Brush: TBrush read GetBrush write SetBrush;
  end;
  TBitmap = class(TGDIBitmap)
  private
    function GetCanvas: TCanvas;
  protected
    function CreateCanvas: TGDICanvas; override;
  public
    procedure LoadFromResourceName(Instance: HINST; const Name: string);
    procedure LoadFromResourceID(Instance: HINST; ID: Word);
    property Canvas: TCanvas read GetCanvas;
  end;
  TIcon = class(TGDIIcon)
  end;
  TPicture = class(TPersistent)
  private
    FGraphic: TGraphic;
    FOnChange: TNotifyEvent;
    FNotifying: Boolean;
    procedure CheckReplacement;
    procedure Changed;
    procedure GraphicChanged(Sender: TObject);
    procedure ReplaceGraphic(Value: TGraphic);
    procedure SetGraphic(Value: TGraphic);
    function GetBitmap: TBitmap;
    procedure SetBitmap(Value: TBitmap);
    function GetIcon: TIcon;
    procedure SetIcon(Value: TIcon);
    function GetWidth: SmallInt;
    function GetHeight: SmallInt;
    function GetEmpty: Boolean;
  public
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure LoadFromFile(const FileName: string);
    property Graphic: TGraphic read FGraphic write SetGraphic;
    property Bitmap: TBitmap read GetBitmap write SetBitmap;
    property Icon: TIcon read GetIcon write SetIcon;
    property Width: SmallInt read GetWidth;
    property Height: SmallInt read GetHeight;
    property Empty: Boolean read GetEmpty;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;
const
  psSolid = gdi_canvas.psSolid; psDash = gdi_canvas.psDash;
  psDot = gdi_canvas.psDot; psDashDot = gdi_canvas.psDashDot;
  psDashDotDot = gdi_canvas.psDashDotDot; psClear = gdi_canvas.psClear;
  psInsideFrame = gdi_canvas.psInsideFrame;
  bsSolid = gdi_canvas.bsSolid; bsClear = gdi_canvas.bsClear;
  bsHorizontal = gdi_canvas.bsHorizontal; bsVertical = gdi_canvas.bsVertical;
  bsFDiagonal = gdi_canvas.bsFDiagonal; bsBDiagonal = gdi_canvas.bsBDiagonal;
  bsCross = gdi_canvas.bsCross; bsDiagCross = gdi_canvas.bsDiagCross;
  fsBold = gdi_canvas.fsBold; fsItalic = gdi_canvas.fsItalic;
  fsUnderline = gdi_canvas.fsUnderline; fsStrikeOut = gdi_canvas.fsStrikeOut;
  fsSurface = gdi_canvas.fsSurface; fsBorder = gdi_canvas.fsBorder;
  clBlack = TColor($000000); clMaroon = TColor($000080);
  clGreen = TColor($008000); clOlive = TColor($008080);
  clNavy = TColor($800000); clPurple = TColor($800080);
  clTeal = TColor($808000); clGray = TColor($808080);
  clSilver = TColor($C0C0C0); clRed = TColor($0000FF);
  clLime = TColor($00FF00); clYellow = TColor($00FFFF);
  clBlue = TColor($FF0000); clFuchsia = TColor($FF00FF);
  clAqua = TColor($FFFF00); clWhite = TColor($FFFFFF);
  clScrollBar = TColor(-1); clBackground = TColor(-2);
  clActiveCaption = TColor(-3); clInactiveCaption = TColor(-4);
  clMenu = TColor(-5); clWindow = TColor(-6);
  clWindowFrame = TColor(-7); clMenuText = TColor(-8);
  clWindowText = TColor(-9); clCaptionText = TColor(-10);
  clActiveBorder = TColor(-11); clInactiveBorder = TColor(-12);
  clAppWorkSpace = TColor(-13); clHighlight = TColor(-14);
  clHighlightText = TColor(-15); clBtnFace = TColor(-16);
  clBtnShadow = TColor(-17); clGrayText = TColor(-18);
  clBtnText = TColor(-19); clInactiveCaptionText = TColor(-20);
  clBtnHighlight = TColor(-21);
  clLtGray = TColor($C0C0C0); clDkGray = TColor($808080);
function Rect(Left, Top, Right, Bottom: SmallInt): TRect;
function Bounds(Left, Top, Width, Height: SmallInt): TRect;
function ColorToRGB(Color: TColor): LongInt;
function IdentToColor(const Ident: string; var Color: LongInt): Boolean;
function ColorToIdent(Color: LongInt; var Ident: string): Boolean;
function StringToColor(const Text: string): TColor;
function ColorToString(Color: TColor): string;
procedure GetColorValues(Proc: TGetStrProc);
implementation
uses SysUtils, color_names;
procedure TBrush.SetBitmap(Value: TBitmap);
begin
  if Value = nil then begin SetPattern(0, 0, 0); FBitmap := nil; Exit; end;
  if Value.Empty or (Value.Width <> 8) or (Value.Height <> 8) then
    raise EGDIError.Create('Pattern bitmap must be a nonempty 8 by 8 image');
  SetPattern(Value.Canvas.Handle, Value.Width, Value.Height);
  FBitmap := Value;
end;
function TCanvas.CreateBrush: TGDIBrush;
begin Result := TBrush.Create; end;
function TCanvas.GetBrush: TBrush;
begin Result := TBrush(inherited Brush); end;
procedure TCanvas.SetBrush(Value: TBrush);
begin inherited Brush := Value; end;
function Rect(Left, Top, Right, Bottom: SmallInt): TRect;
begin Result.Left := Left; Result.Top := Top; Result.Right := Right; Result.Bottom := Bottom; end;
function Bounds(Left, Top, Width, Height: SmallInt): TRect;
var Right, Bottom: LongInt;
begin
  Right := LongInt(Left) + Width; Bottom := LongInt(Top) + Height;
  if (Right < -32768) or (Right > 32767) or (Bottom < -32768) or (Bottom > 32767) then
    raise EGDIError.Create('Bounds exceed Win16 coordinates');
  Result := Rect(Left, Top, Right, Bottom);
end;
function TBitmap.CreateCanvas: TGDICanvas;
begin Result := TCanvas.Create; end;
function TBitmap.GetCanvas: TCanvas;
begin Result := TCanvas(inherited Canvas); end;
procedure TBitmap.LoadFromResourceName(Instance: HINST; const Name: string);
var Buffer: array[0..255] of Char;
begin
  if (Name = '') or (Pos(#0, Name) <> 0) then raise EGDIError.Create('Invalid bitmap resource name');
  LoadFromResource(Instance, StrPCopy(Buffer, Name));
end;
procedure TBitmap.LoadFromResourceID(Instance: HINST; ID: Word);
begin LoadFromResource(Instance, PChar(ID)); end;
procedure TCanvas.BrushCopy(const Destination: TRect; Bitmap: TBitmap;
  const SourceRect: TRect; Color: TColor);
begin
  if Bitmap = nil then raise EGDIError.Create('Missing source bitmap');
  inherited BrushCopy(Destination, Bitmap.Canvas, SourceRect, Color);
end;
procedure TPicture.CheckReplacement;
begin
  if FNotifying then raise EGDIError.Create('Cannot replace picture during change notification');
end;
procedure TPicture.Changed;
begin
  if FNotifying or not Assigned(FOnChange) then Exit;
  FNotifying := True;
  try FOnChange(Self); finally FNotifying := False; end;
end;
procedure TPicture.GraphicChanged(Sender: TObject);
begin if Sender = FGraphic then Changed; end;
procedure TPicture.ReplaceGraphic(Value: TGraphic);
var Previous: TGraphic;
begin
  Previous := FGraphic;
  FGraphic := Value;
  if FGraphic <> nil then FGraphic.OnChange := GraphicChanged;
  if Previous <> nil then begin Previous.OnChange := nil; Previous.Free; end;
  Changed;
end;
destructor TPicture.Destroy;
begin
  if FGraphic <> nil then begin FGraphic.OnChange := nil; FGraphic.Free; end;
  inherited Destroy;
end;
procedure TPicture.SetGraphic(Value: TGraphic);
var Copy: TGraphic;
begin
  if Value = FGraphic then Exit;
  CheckReplacement;
  if Value = nil then begin ReplaceGraphic(nil); Exit; end;
  if Value is TGDIBitmap then Copy := TBitmap.Create
  else if Value is TGDIIcon then Copy := TIcon.Create
  else raise EConvertError.Create('Unsupported picture graphic');
  try Copy.Assign(Value); except Copy.Free; raise; end;
  { Commit before notification. If user code raises, Copy remains owned here. }
  ReplaceGraphic(Copy);
end;
function TPicture.GetBitmap: TBitmap;
begin
  if not (FGraphic is TBitmap) then
  begin CheckReplacement; ReplaceGraphic(TBitmap.Create); end;
  Result := TBitmap(FGraphic);
end;
procedure TPicture.SetBitmap(Value: TBitmap);
begin SetGraphic(Value); end;
function TPicture.GetIcon: TIcon;
begin
  if not (FGraphic is TIcon) then
  begin CheckReplacement; ReplaceGraphic(TIcon.Create); end;
  Result := TIcon(FGraphic);
end;
procedure TPicture.SetIcon(Value: TIcon);
begin SetGraphic(Value); end;
function TPicture.GetWidth: SmallInt;
begin if FGraphic = nil then Result := 0 else Result := FGraphic.Width; end;
function TPicture.GetHeight: SmallInt;
begin if FGraphic = nil then Result := 0 else Result := FGraphic.Height; end;
function TPicture.GetEmpty: Boolean;
begin if FGraphic = nil then Result := True else Result := FGraphic.Empty; end;
procedure TPicture.Assign(Source: TPersistent);
begin
  if Source = Self then Exit;
  if Source = nil then SetGraphic(nil)
  else if Source is TPicture then SetGraphic(TPicture(Source).FGraphic)
  else if Source is TGraphic then SetGraphic(TGraphic(Source))
  else inherited Assign(Source);
end;
procedure TPicture.LoadFromFile(const FileName: string);
var Copy: TBitmap;
begin
  CheckReplacement;
  Copy := TBitmap.Create;
  try Copy.LoadFromFile(FileName); except Copy.Free; raise; end;
  ReplaceGraphic(Copy);
end;
function ColorToRGB(Color: TColor): LongInt;
begin Result := gdi_canvas.ColorToRGB(Color); end;
function IdentToColor(const Ident: string; var Color: LongInt): Boolean;
begin Result := color_names.IdentToColor(Ident, Color); end;
function ColorToIdent(Color: LongInt; var Ident: string): Boolean;
var Name: AnsiString;
begin
  Name := Ident; Result := color_names.ColorToIdent(Color, Name);
  if Result then Ident := Name;
end;
function StringToColor(const Text: string): TColor;
begin Result := color_names.StringToColor(Text); end;
function ColorToString(Color: TColor): string;
begin Result := color_names.ColorToString(Color); end;
type
  TColorNameRelay = class
    Target: TGetStrProc;
    procedure Visit(const S: AnsiString);
  end;
procedure TColorNameRelay.Visit(const S: AnsiString);
begin Target(S); end;
procedure GetColorValues(Proc: TGetStrProc);
var Relay: TColorNameRelay;
begin
  Relay := TColorNameRelay.Create;
  try Relay.Target := Proc; color_names.GetColorValues(Relay.Visit);
  finally Relay.Free; end;
end;
end.
