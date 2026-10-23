{ SPDX-License-Identifier: GPL-2.0-or-later
  Windowless Delphi 1 TSpeedButton: up/disabled/down/exclusive states, group
  exclusivity through CM_BUTTONPRESSED, AllowAllUp and four-frame glyph strips.
  Descendants (Calmira's TStyleSpeed) read FState and handle CM_BUTTONPRESSED,
  CM_MOUSEENTER and CM_MOUSELEAVE. }
unit native_speedbutton;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This speed button requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls;
type
  TButtonState = (bsUp, bsDisabled, bsDown, bsExclusive);
  TButtonLayout = (blGlyphLeft, blGlyphRight, blGlyphTop, blGlyphBottom);
  TSpeedButton = class(TGraphicControl)
  private
    FGlyph: Graphics.TBitmap;
    FGroupIndex: Integer;
    FDown, FAllowAllUp, FDragging: Boolean;
    FCaption: string;
    FLayout: TButtonLayout;
    FMargin, FSpacing, FNumGlyphs: Integer;
    procedure SetGlyph(Value: Graphics.TBitmap);
    procedure GlyphChanged(Sender: TObject);
    procedure SetDown(Value: Boolean);
    procedure SetAllowAllUp(Value: Boolean);
    procedure SetGroupIndex(Value: Integer);
    procedure SetCaption(const Value: string);
    procedure SetLayout(Value: TButtonLayout);
    procedure SetMargin(Value: Integer);
    procedure SetSpacing(Value: Integer);
    procedure SetNumGlyphs(Value: Integer);
    procedure UpdateExclusive;
    procedure CMButtonPressed(var Message: TMessage); message CM_BUTTONPRESSED;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
  protected
    FState: TButtonState;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property AllowAllUp: Boolean read FAllowAllUp write SetAllowAllUp default False;
    property GroupIndex: Integer read FGroupIndex write SetGroupIndex default 0;
    property Down: Boolean read FDown write SetDown default False;
    property Caption: string read FCaption write SetCaption;
    property Font;
    property Glyph: Graphics.TBitmap read FGlyph write SetGlyph;
    property Layout: TButtonLayout read FLayout write SetLayout default blGlyphLeft;
    property Margin: Integer read FMargin write SetMargin default -1;
    property NumGlyphs: Integer read FNumGlyphs write SetNumGlyphs default 1;
    property Spacing: Integer read FSpacing write SetSpacing default 4;
    property Enabled;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;
implementation
uses SysUtils, WinProcs, native_window;
constructor TSpeedButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyph := Graphics.TBitmap.Create; FGlyph.OnChange := GlyphChanged;
  FMargin := -1; FSpacing := 4; FNumGlyphs := 1; FClickEvents := False;
  Color := clBtnFace;
  SetBounds(0, 0, 25, 25);
end;
destructor TSpeedButton.Destroy;
begin
  if FGlyph <> nil then begin FGlyph.OnChange := nil; FGlyph.Free; end;
  inherited Destroy;
end;
procedure TSpeedButton.CMEnabledChanged(var Message: TMessage);
begin
  FDragging := False;
  if not Enabled then FState := bsDisabled
  else if FDown then FState := bsExclusive
  else FState := bsUp;
  Invalidate;
end;
procedure TSpeedButton.SetGlyph(Value: Graphics.TBitmap);
begin FGlyph.Assign(Value); end;
procedure TSpeedButton.GlyphChanged(Sender: TObject);
begin Invalidate; end;
procedure TSpeedButton.SetCaption(const Value: string);
begin if FCaption <> Value then begin FCaption := Value; Invalidate; end; end;
procedure TSpeedButton.SetLayout(Value: TButtonLayout);
begin if FLayout <> Value then begin FLayout := Value; Invalidate; end; end;
procedure TSpeedButton.SetMargin(Value: Integer);
begin
  if Value < -1 then raise ENativeWindowError.Create('Invalid glyph margin');
  if FMargin <> Value then begin FMargin := Value; Invalidate; end;
end;
procedure TSpeedButton.SetSpacing(Value: Integer);
begin
  if Value < -1 then raise ENativeWindowError.Create('Invalid glyph spacing');
  if FSpacing <> Value then begin FSpacing := Value; Invalidate; end;
end;
procedure TSpeedButton.SetNumGlyphs(Value: Integer);
begin
  if (Value < 1) or (Value > 4) then raise ENativeWindowError.Create('Invalid glyph frame count');
  if FNumGlyphs <> Value then begin FNumGlyphs := Value; Invalidate; end;
end;
procedure TSpeedButton.SetDown(Value: Boolean);
begin
  if FGroupIndex = 0 then Value := False;
  if Value = FDown then Exit;
  { The last down button of a group stays down unless AllowAllUp. }
  if FDown and not FAllowAllUp then Exit;
  FDown := Value;
  if not Enabled then FState := bsDisabled
  else if Value then FState := bsExclusive
  else FState := bsUp;
  Invalidate;
  if Value then UpdateExclusive;
end;
procedure TSpeedButton.SetAllowAllUp(Value: Boolean);
begin
  if FAllowAllUp = Value then Exit;
  FAllowAllUp := Value;
  UpdateExclusive;
end;
procedure TSpeedButton.SetGroupIndex(Value: Integer);
begin
  if FGroupIndex = Value then Exit;
  FGroupIndex := Value;
  UpdateExclusive;
end;
procedure TSpeedButton.UpdateExclusive;
var I: Integer; Sibling: TControl;
begin
  if (FGroupIndex = 0) or (Parent = nil) then Exit;
  for I := 0 to Parent.ControlCount - 1 do
  begin
    Sibling := Parent.Controls[I];
    if (Sibling <> Self) and (Sibling is TGraphicControl) then
      TGraphicControl(Sibling).Perform(CM_BUTTONPRESSED, FGroupIndex, LongInt(Pointer(Self)));
  end;
end;
procedure TSpeedButton.CMButtonPressed(var Message: TMessage);
var Sender: TSpeedButton;
begin
  if Message.WParam <> FGroupIndex then Exit;
  Sender := TSpeedButton(Pointer(Message.LParam));
  if Sender = Self then Exit;
  if Sender.Down and FDown then
  begin
    FDown := False;
    if Enabled then FState := bsUp else FState := bsDisabled;
    Invalidate;
  end;
  FAllowAllUp := Sender.AllowAllUp;
end;
procedure TSpeedButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then Exit;
  if not FDown then begin FState := bsDown; Invalidate; end;
  FDragging := True;
end;
procedure TSpeedButton.MouseMove(Shift: TShiftState; X, Y: Integer);
var NewState: TButtonState;
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging then Exit;
  if FDown then NewState := bsExclusive else NewState := bsUp;
  if (X >= 0) and (X < Width) and (Y >= 0) and (Y < Height) then
    if FDown then NewState := bsExclusive else NewState := bsDown;
  if NewState <> FState then begin FState := NewState; Invalidate; end;
end;
procedure TSpeedButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var DoClick: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not FDragging or (Button <> mbLeft) then Exit;
  FDragging := False;
  DoClick := (X >= 0) and (X < Width) and (Y >= 0) and (Y < Height);
  if FGroupIndex = 0 then
  begin
    FState := bsUp;
    Invalidate;
  end
  else if DoClick then
  begin
    SetDown(not FDown);
    { SetDown refused (last button of a group): restore its look. }
    if FDown then FState := bsExclusive;
    Invalidate;
  end
  else
  begin
    if FDown then FState := bsExclusive else FState := bsUp;
    Invalidate;
  end;
  if DoClick then Click;
end;
procedure Edge(Canvas: TCanvas; var R: TRect; TopColor, BottomColor: TColor);
begin
  if (R.Right - R.Left < 2) or (R.Bottom - R.Top < 2) then Exit;
  Canvas.Brush.Color := TopColor;
  Canvas.FillRect(Graphics.Rect(R.Left, R.Top, R.Right - 1, R.Top + 1));
  Canvas.FillRect(Graphics.Rect(R.Left, R.Top, R.Left + 1, R.Bottom - 1));
  Canvas.Brush.Color := BottomColor;
  Canvas.FillRect(Graphics.Rect(R.Left, R.Bottom - 1, R.Right, R.Bottom));
  Canvas.FillRect(Graphics.Rect(R.Right - 1, R.Top, R.Right, R.Bottom));
  InflateRect(R, -1, -1);
end;
const
  { 8x8 checkerboard, one word per monochrome scan line. }
  Checker: array[0..7] of Word = ($AA, $55, $AA, $55, $AA, $55, $AA, $55);
procedure DitherFace(DC: HDC; Area: TRect);
var Pattern: HBITMAP; Brush: HBRUSH; OldText, OldBack: TColorRef;
begin
  { A down group button shows a dithered face, as in Delphi 1. }
  Pattern := CreateBitmap(8, 8, 1, 1, @Checker);
  if Pattern = 0 then Exit;
  try
    Brush := CreatePatternBrush(Pattern);
    if Brush = 0 then Exit;
    try
      OldText := SetTextColor(DC, ColorToRGB(clBtnFace));
      OldBack := SetBkColor(DC, ColorToRGB(clBtnHighlight));
      WinProcs.FillRect(DC, Area, Brush);
      SetTextColor(DC, OldText); SetBkColor(DC, OldBack);
    finally DeleteObject(Brush); end;
  finally DeleteObject(Pattern); end;
end;
procedure TSpeedButton.Paint;
var R, Source, Target, TextArea: TRect; Frame, GW, GH, TW, TH, Gap, Shift: Integer;
  GroupW, GroupH, X, Y, GX, GY, TX, TY: Integer; Pressed: Boolean; Key: TColor;
  Buffer: array[0..255] of Char; DC: HDC;
begin
  DC := Canvas.Handle;
  if DC = 0 then Exit;
  R := Graphics.Rect(0, 0, Width, Height);
  Pressed := FState in [bsDown, bsExclusive];
  Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := clBtnFace; Canvas.FillRect(R);
  { Delphi 1 frame: window frame, then the raised or sunken bevel. }
  Edge(Canvas, R, clWindowFrame, clWindowFrame);
  if Pressed then Edge(Canvas, R, clBtnShadow, clBtnFace)
  else Edge(Canvas, R, clBtnHighlight, clBtnShadow);
  if FState = bsExclusive then DitherFace(DC, Graphics.Rect(R.Left + 1, R.Top + 1, R.Right, R.Bottom));
  GW := 0; GH := 0; Frame := 0;
  if not FGlyph.Empty and (FGlyph.Width mod FNumGlyphs = 0) then
  begin
    GW := FGlyph.Width div FNumGlyphs; GH := FGlyph.Height;
    case FState of
      bsDisabled: if FNumGlyphs >= 2 then Frame := 1;
      bsDown: if FNumGlyphs >= 3 then Frame := 2;
      bsExclusive: if FNumGlyphs >= 4 then Frame := 3 else if FNumGlyphs >= 3 then Frame := 2;
      bsUp: Frame := 0;
    end;
  end;
  TW := 0; TH := 0;
  if FCaption <> '' then
  begin
    SelectObject(DC, Font.Handle);
    StrPCopy(Buffer, FCaption); TextArea := Graphics.Rect(0, 0, 0, 0);
    DrawText(DC, Buffer, Length(FCaption), TextArea, DT_CALCRECT or DT_SINGLELINE);
    TW := TextArea.Right; TH := TextArea.Bottom;
  end;
  if (GW <> 0) and (TW <> 0) then
  begin
    if FSpacing >= 0 then Gap := FSpacing
    else if FLayout in [blGlyphLeft, blGlyphRight] then Gap := (Width - GW - TW) div 3
    else Gap := (Height - GH - TH) div 3;
    if Gap < 0 then Gap := 0;
  end
  else Gap := 0;
  if FLayout in [blGlyphLeft, blGlyphRight] then
  begin GroupW := GW + Gap + TW; GroupH := GH; if TH > GroupH then GroupH := TH; end
  else
  begin GroupH := GH + Gap + TH; GroupW := GW; if TW > GroupW then GroupW := TW; end;
  X := (Width - GroupW) div 2; Y := (Height - GroupH) div 2;
  if FMargin >= 0 then
    case FLayout of
      blGlyphLeft: X := FMargin;
      blGlyphRight: X := Width - FMargin - GroupW;
      blGlyphTop: Y := FMargin;
      blGlyphBottom: Y := Height - FMargin - GroupH;
    end;
  Shift := Ord(Pressed); Inc(X, Shift); Inc(Y, Shift);
  GX := X; GY := Y; TX := X; TY := Y;
  case FLayout of
    blGlyphLeft: begin Inc(TX, GW + Gap); Inc(GY, (GroupH - GH) div 2); Inc(TY, (GroupH - TH) div 2); end;
    blGlyphRight: begin Inc(GX, TW + Gap); Inc(GY, (GroupH - GH) div 2); Inc(TY, (GroupH - TH) div 2); end;
    blGlyphTop: begin Inc(TY, GH + Gap); Inc(GX, (GroupW - GW) div 2); Inc(TX, (GroupW - TW) div 2); end;
    blGlyphBottom: begin Inc(GY, TH + Gap); Inc(GX, (GroupW - GW) div 2); Inc(TX, (GroupW - TW) div 2); end;
  end;
  if GW > 0 then
  begin
    Source := Graphics.Rect(Frame * GW, 0, (Frame + 1) * GW, GH);
    Target := Graphics.Rect(GX, GY, GX + GW, GY + GH);
    if FGlyph.Transparent then Key := FGlyph.TransparentColor
    else Key := FGlyph.Canvas.Pixels[0, GH - 1];
    Canvas.CopyTransparent(Target, FGlyph.Canvas, Source, Key);
  end;
  if TW > 0 then
  begin
    TextArea := Graphics.Rect(TX, TY, TX + TW, TY + TH);
    StrPCopy(Buffer, FCaption); SelectObject(DC, Font.Handle); SetBkMode(DC, TRANSPARENT);
    if FState = bsDisabled then SetTextColor(DC, ColorToRGB(clGrayText))
    else SetTextColor(DC, ColorToRGB(Font.Color));
    DrawText(DC, Buffer, Length(FCaption), TextArea, DT_LEFT or DT_SINGLELINE);
  end;
end;
end.
