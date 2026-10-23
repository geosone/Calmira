{ SPDX-License-Identifier: GPL-2.0-or-later
  Image, notebook and header subset; not the complete Delphi ExtCtrls framework. }
unit ExtCtrls;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This ExtCtrls subset requires Win16}{$ENDIF}
interface
uses Classes, Graphics, Controls, native_notebook, native_header;
type
  TNotebook = native_notebook.TNotebook;
  TPage = native_notebook.TPage;
  THeader = native_header.THeader;
  TSectionEvent = native_header.TSectionEvent;
  TImage = class(TGraphicControl)
  private
    FPicture: TPicture;
    FStretch, FCenter, FAutoSize: Boolean;
    function GetPictureCanvas: TCanvas;
    procedure SetPicture(Value: TPicture);
    procedure SetStretch(Value: Boolean);
    procedure SetCenter(Value: Boolean);
    procedure SetAutoSize(Value: Boolean);
    procedure PictureChanged(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Canvas: TCanvas read GetPictureCanvas;
  published
    property Picture: TPicture read FPicture write SetPicture;
    property Stretch: Boolean read FStretch write SetStretch default False;
    property Center: Boolean read FCenter write SetCenter default False;
    property AutoSize: Boolean read FAutoSize write SetAutoSize default False;
    property Color;
    property Visible;
  end;
{ Delphi 1 bevel: Width nested frames, top/left in TopColor; Rect shrinks by Width. }
procedure Frame3D(Canvas: TCanvas; var Rect: TRect; TopColor, BottomColor: TColor;
  Width: Integer);
implementation
uses WinProcs, native_window;
constructor TImage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPicture := TPicture.Create; FPicture.OnChange := PictureChanged;
  SetBounds(0, 0, 105, 105);
end;
destructor TImage.Destroy;
begin
  if FPicture <> nil then begin FPicture.OnChange := nil; FPicture.Free; end;
  inherited Destroy;
end;
procedure TImage.SetPicture(Value: TPicture);
begin FPicture.Assign(Value); end;
function TImage.GetPictureCanvas: TCanvas;
begin
  if FPicture.Graphic = nil then FPicture.Bitmap.SetSize(Width, Height);
  if not (FPicture.Graphic is TBitmap) then
    raise ENativeWindowError.Create('Image canvas requires a bitmap picture');
  Result := FPicture.Bitmap.Canvas;
end;
procedure TImage.SetStretch(Value: Boolean);
begin if Value <> FStretch then begin FStretch := Value; Invalidate; end; end;
procedure TImage.SetCenter(Value: Boolean);
begin if Value <> FCenter then begin FCenter := Value; Invalidate; end; end;
procedure TImage.SetAutoSize(Value: Boolean);
begin
  if Value = FAutoSize then Exit;
  if Value and not FPicture.Empty then SetBounds(Left, Top, FPicture.Width, FPicture.Height);
  FAutoSize := Value; Invalidate;
end;
procedure TImage.PictureChanged(Sender: TObject);
begin
  { Picture changes are already committed before its OnChange notification. }
  Invalidate;
  if FAutoSize and not FPicture.Empty then
    SetBounds(Left, Top, FPicture.Width, FPicture.Height);
end;
procedure TImage.Paint;
var X, Y: Integer; Surface: TBitmap; Painter: TCanvas;
begin
  Painter := TGraphicControl(Self).Canvas;
  if Painter.Handle = 0 then begin Invalidate; Exit; end;
  if FPicture.Empty then Exit;
  if FStretch then
  begin
    if (FPicture.Graphic is TIcon) and
      ((Width <> FPicture.Width) or (Height <> FPicture.Height)) then
    begin
      { Win16 DrawIcon has no scaled variant. Flatten its native mask against
        this opaque image's background before scaling the temporary bitmap. }
      Surface := TBitmap.Create;
      try
        Surface.SetSize(FPicture.Width, FPicture.Height);
        Surface.Canvas.Brush.Color := Color;
        Surface.Canvas.FillRect(Rect(0, 0, Surface.Width, Surface.Height));
        Surface.Canvas.Draw(0, 0, FPicture.Graphic);
        Painter.StretchDraw(Rect(0, 0, Width, Height), Surface);
      finally Surface.Free; end;
    end
    else Painter.StretchDraw(Rect(0, 0, Width, Height), FPicture.Graphic);
  end
  else
  begin
    X := 0; Y := 0;
    if FCenter then
    begin X := (Width - FPicture.Width) div 2; Y := (Height - FPicture.Height) div 2; end;
    Painter.Draw(X, Y, FPicture.Graphic);
  end;
end;
procedure Frame3D(Canvas: TCanvas; var Rect: TRect; TopColor, BottomColor: TColor;
  Width: Integer);
begin
  Canvas.Pen.Width := 1;
  Dec(Rect.Bottom); Dec(Rect.Right);
  while Width > 0 do
  begin
    Dec(Width);
    Canvas.Pen.Color := TopColor;
    Canvas.PolyLine([Point(Rect.Left, Rect.Bottom), Point(Rect.Left, Rect.Top),
      Point(Rect.Right, Rect.Top)]);
    Canvas.Pen.Color := BottomColor;
    Canvas.PolyLine([Point(Rect.Right, Rect.Top), Point(Rect.Right, Rect.Bottom),
      Point(Rect.Left - 1, Rect.Bottom)]);
    InflateRect(Rect, -1, -1);
  end;
  Inc(Rect.Bottom); Inc(Rect.Right);
end;
end.
