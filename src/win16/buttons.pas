{ SPDX-License-Identifier: GPL-2.0-or-later
  Owner-drawn Win16 bitmap button subset, using USER's real button behavior. }
unit Buttons;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Buttons subset requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Graphics, native_button, native_speedbutton;
type
  TButtonLayout = native_speedbutton.TButtonLayout;
  { Delphi 1 BitBtn/MessageDlg look; only the new 3D look is drawn. }
  TButtonStyle = (bsAutoDetect, bsWin31, bsNew);
  { Standard buttons: Kind sets the translated caption, ModalResult and
    Default or Cancel. Delphi's stock glyphs are not provided at run time;
    generated form loaders supply a drawn one for bkCancel. }
  TBitBtnKind = (bkCustom, bkOK, bkCancel, bkHelp, bkYes, bkNo, bkClose,
    bkAbort, bkRetry, bkIgnore, bkAll);
  TButtonState = native_speedbutton.TButtonState;
  TSpeedButton = native_speedbutton.TSpeedButton;
const
  blGlyphLeft = native_speedbutton.blGlyphLeft; blGlyphRight = native_speedbutton.blGlyphRight;
  blGlyphTop = native_speedbutton.blGlyphTop; blGlyphBottom = native_speedbutton.blGlyphBottom;
  bsUp = native_speedbutton.bsUp; bsDisabled = native_speedbutton.bsDisabled;
  bsDown = native_speedbutton.bsDown; bsExclusive = native_speedbutton.bsExclusive;
type
  TBitBtn = class(TButton)
  private
    FGlyph: Graphics.TBitmap;
    FMargin, FSpacing, FNumGlyphs: Integer;
    FLayout: TButtonLayout;
    FKind: TBitBtnKind;
    FStyle: TButtonStyle;
    procedure SetKind(Value: TBitBtnKind);
    procedure SetGlyph(Value: Graphics.TBitmap);
    procedure GlyphChanged(Sender: TObject);
    procedure SetMargin(Value: Integer);
    procedure SetSpacing(Value: Integer);
    procedure SetNumGlyphs(Value: Integer);
    procedure SetLayout(Value: TButtonLayout);
  protected
    function ButtonStyle: Word; override;
    procedure DrawButton(var Item: TDrawItemStruct); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { bkClose closes the parent form; bkHelp shows the nearest help context. }
    procedure Click; override;
  published
    property Kind: TBitBtnKind read FKind write SetKind default bkCustom;
    { Stored only: the new 3D look is always drawn. }
    property Style: TButtonStyle read FStyle write FStyle default bsAutoDetect;
    property Glyph: Graphics.TBitmap read FGlyph write SetGlyph;
    property Margin: Integer read FMargin write SetMargin default -1;
    property Spacing: Integer read FSpacing write SetSpacing default 4;
    property NumGlyphs: Integer read FNumGlyphs write SetNumGlyphs default 1;
    property Layout: TButtonLayout read FLayout write SetLayout default blGlyphLeft;
  end;
implementation
uses SysUtils, WinProcs, Controls, Forms, native_window, form_text;
const
  KindCaptions: array[TBitBtnKind] of string[7] = ('', 'OK', 'Cancel', '&Help',
    '&Yes', '&No', '&Close', 'Abort', '&Retry', '&Ignore', '&All');
  { Keys of the translated captions, as in Delphi's string-table captions. }
  KindNames: array[TBitBtnKind] of string[6] = ('', 'OK', 'Cancel', 'Help',
    'Yes', 'No', 'Close', 'Abort', 'Retry', 'Ignore', 'All');
  KindResults: array[TBitBtnKind] of TModalResult = (mrNone, mrOK, mrCancel, mrNone,
    mrYes, mrNo, mrNone, mrAbort, mrRetry, mrIgnore, mrAll);
procedure TBitBtn.SetKind(Value: TBitBtnKind);
begin
  if Value = FKind then Exit;
  FKind := Value;
  if Value = bkCustom then Exit;
  Default := Value in [bkOK, bkYes];
  Cancel := Value in [bkCancel, bkNo];
  { A streamed custom caption is kept. }
  if not (csLoading in ComponentState) or (Caption = '') then
    Caption := FormText('TStandardButtons', KindNames[Value], 'Caption', KindCaptions[Value]);
  ModalResult := KindResults[Value];
end;
procedure TBitBtn.Click;
var Form: TForm; Context: LongInt;
begin
  case FKind of
    bkClose:
      begin
        Form := GetParentForm(Self);
        if Form <> nil then begin Form.Close; Exit; end;
      end;
    bkHelp:
      begin
        Context := ResolveHelpContext;
        if (Context <> 0) and (Application <> nil) then begin Application.HelpContext(Context); Exit; end;
      end;
  end;
  inherited Click;
end;
constructor TBitBtn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyph := Graphics.TBitmap.Create; FGlyph.OnChange := GlyphChanged;
  FMargin := -1; FSpacing := 4; FNumGlyphs := 1;
end;
destructor TBitBtn.Destroy;
begin
  if FGlyph <> nil then begin FGlyph.OnChange := nil; FGlyph.Free; end;
  inherited Destroy;
end;
function TBitBtn.ButtonStyle: Word;
begin Result := BS_OWNERDRAW; end;
procedure TBitBtn.SetGlyph(Value: Graphics.TBitmap);
begin FGlyph.Assign(Value); end;
procedure TBitBtn.GlyphChanged(Sender: TObject);
begin Invalidate; end;
procedure TBitBtn.SetMargin(Value: Integer);
begin
  if Value < -1 then raise ENativeWindowError.Create('Invalid glyph margin');
  if Value <> FMargin then begin FMargin := Value; Invalidate; end;
end;
procedure TBitBtn.SetSpacing(Value: Integer);
begin
  if Value < -1 then raise ENativeWindowError.Create('Invalid glyph spacing');
  if Value <> FSpacing then begin FSpacing := Value; Invalidate; end;
end;
procedure TBitBtn.SetNumGlyphs(Value: Integer);
begin
  if (Value < 1) or (Value > 4) then raise ENativeWindowError.Create('Invalid glyph frame count');
  if not FGlyph.Empty and (FGlyph.Width mod Value <> 0) then
    raise ENativeWindowError.Create('Glyph strip width is not divisible by frame count');
  if Value <> FNumGlyphs then begin FNumGlyphs := Value; Invalidate; end;
end;
procedure TBitBtn.SetLayout(Value: TButtonLayout);
begin if Value <> FLayout then begin FLayout := Value; Invalidate; end; end;
function Coordinate(Value: LongInt): SmallInt;
begin
  if (Value < -32768) or (Value > 32767) then
    raise ENativeWindowError.Create('Button layout exceeds Win16 coordinates');
  Result := Value;
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
procedure TBitBtn.DrawButton(var Item: TDrawItemStruct);
var R, TextArea, Source, Target: TRect; Frame, GW, GH, TW, TH, Gap, Shift: Integer;
  GroupW, GroupH, GX, GY, TX, TY, StartX, StartY, FreeSpace: LongInt;
  Pressed, Disabled: Boolean; Key: TColor; Buffer: array[0..255] of Char;
begin
  R := Item.rcItem; Pressed := Item.itemState and ODS_SELECTED <> 0;
  Disabled := Item.itemState and (ODS_DISABLED or ODS_GRAYED) <> 0;
  Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := clBtnFace; Canvas.FillRect(R);
  if Pressed then Edge(Canvas, R, clBtnShadow, clBtnHighlight)
  else Edge(Canvas, R, clBtnHighlight, clBtnShadow);
  Edge(Canvas, R, clBtnFace, clBtnFace);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  GW := 0; GH := 0; Frame := 0;
  if not FGlyph.Empty then
  begin
    if FGlyph.Width mod FNumGlyphs <> 0 then raise ENativeWindowError.Create('Invalid glyph strip');
    GW := FGlyph.Width div FNumGlyphs; GH := FGlyph.Height;
    if Disabled and (FNumGlyphs >= 2) then Frame := 1
    else if Pressed and (FNumGlyphs >= 3) then Frame := 2;
  end;
  TW := 0; TH := 0;
  if Caption <> '' then
  begin
    if SelectObject(Item.hDC, Font.Handle) = 0 then raise ENativeWindowError.Create('Cannot select button font');
    StrPCopy(Buffer, Caption); TextArea := Graphics.Rect(0, 0, 0, 0);
    if DrawText(Item.hDC, Buffer, Length(Caption), TextArea, DT_CALCRECT or DT_SINGLELINE) = 0 then
      raise ENativeWindowError.Create('Cannot measure button caption');
    TW := TextArea.Right; TH := TextArea.Bottom;
  end;
  Gap := 0;
  if (GW <> 0) and (TW <> 0) then
  begin
    if FSpacing = -1 then
    begin
      if FLayout in [blGlyphLeft, blGlyphRight] then
        FreeSpace := LongInt(R.Right) - R.Left - GW - TW
      else FreeSpace := LongInt(R.Bottom) - R.Top - GH - TH;
      if FMargin = -1 then FreeSpace := FreeSpace div 3
      else FreeSpace := (FreeSpace - FMargin) div 2;
      if FreeSpace < 0 then FreeSpace := 0;
      Gap := Coordinate(FreeSpace);
    end
    else Gap := FSpacing;
  end;
  if FLayout in [blGlyphLeft, blGlyphRight] then
  begin GroupW := LongInt(GW) + Gap + TW; GroupH := GH; if TH > GroupH then GroupH := TH; end
  else
  begin GroupH := LongInt(GH) + Gap + TH; GroupW := GW; if TW > GroupW then GroupW := TW; end;
  StartX := R.Left + (LongInt(R.Right) - R.Left - GroupW) div 2;
  StartY := R.Top + (LongInt(R.Bottom) - R.Top - GroupH) div 2;
  if FMargin >= 0 then
    case FLayout of
      blGlyphLeft: StartX := LongInt(R.Left) + FMargin;
      blGlyphRight: StartX := LongInt(R.Right) - FMargin - GroupW;
      blGlyphTop: StartY := LongInt(R.Top) + FMargin;
      blGlyphBottom: StartY := LongInt(R.Bottom) - FMargin - GroupH;
    end;
  Shift := Ord(Pressed); Inc(StartX, Shift); Inc(StartY, Shift);
  GX := StartX; GY := StartY; TX := StartX; TY := StartY;
  case FLayout of
    blGlyphLeft: begin Inc(TX, GW + LongInt(Gap)); Inc(GY, (GroupH - GH) div 2); Inc(TY, (GroupH - TH) div 2); end;
    blGlyphRight: begin Inc(GX, TW + LongInt(Gap)); Inc(GY, (GroupH - GH) div 2); Inc(TY, (GroupH - TH) div 2); end;
    blGlyphTop: begin Inc(TY, GH + LongInt(Gap)); Inc(GX, (GroupW - GW) div 2); Inc(TX, (GroupW - TW) div 2); end;
    blGlyphBottom: begin Inc(GY, TH + LongInt(Gap)); Inc(GX, (GroupW - GW) div 2); Inc(TX, (GroupW - TW) div 2); end;
  end;
  if GW > 0 then
  begin
    Source := Graphics.Rect(Frame * GW, 0, (Frame + 1) * GW, GH);
    Target := Graphics.Rect(Coordinate(GX), Coordinate(GY), Coordinate(GX + GW), Coordinate(GY + GH));
    if FGlyph.Transparent then Key := FGlyph.TransparentColor
    else Key := FGlyph.Canvas.Pixels[0, GH - 1];
    Canvas.CopyTransparent(Target, FGlyph.Canvas, Source, Key);
  end;
  if TW > 0 then
  begin
    TextArea := Graphics.Rect(Coordinate(TX), Coordinate(TY), Coordinate(TX + TW), Coordinate(TY + TH));
    StrPCopy(Buffer, Caption); SelectObject(Item.hDC, Font.Handle); SetBkMode(Item.hDC, TRANSPARENT);
    if Disabled then SetTextColor(Item.hDC, ColorToRGB(clGrayText))
    else SetTextColor(Item.hDC, ColorToRGB(Font.Color));
    DrawText(Item.hDC, Buffer, Length(Caption), TextArea, DT_LEFT or DT_SINGLELINE);
  end;
  if Item.itemState and ODS_FOCUS <> 0 then
  begin R := Item.rcItem; InflateRect(R, -3, -3); Canvas.DrawFocusRect(R); end;
end;
end.
