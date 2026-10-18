{*********************************************************}
{                                                         }
{    Calmira System Library 3.1                           }
{    by Li-Hsin Huang & Erwin Dokter                      }
{    released into the public domain january 2002         }
{                                                         }
{*********************************************************}

unit StylSped;

{ TStyleSpeed is the descendant which overrides Paint to draw a new
  border style over TSpeedButton's border.  There doesn't seem to
  be any noticeable impact on performance.  TStyleSpeed provides
  a new Style property to change between the old TSpeedButton, a
  Windows 95-like button and a flat IE4-like button.

  Changes in 3.12:
  - Removed sbBitBtn style, since it is not any different form sbSpeed.
  - Added BoldOnDown property. When set to True, it sets the font's
    fsBold flag when the button is down.
  - Added Seperator property. When set to True and Style is set to bsFlat,
    draws a bevel style seperator to the left of the button. }

interface

uses SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Buttons;

type
  TSpeedStyle = (sbSpeed, sbWin95, sbFlat);

  TStyleSpeed = class(TSpeedButton)
  private
    { Private declarations }
    FStyle: TSpeedStyle;
    FBoldOnDown: Boolean;
    FSeperator: Boolean;
    FMouseOver: Boolean;
    procedure SetStyle(Value: TSpeedStyle);
  protected
    { Protected declarations }
    procedure Paint; override;
    procedure CMButtonPressed(var Message: TMessage); message CM_BUTTONPRESSED;
    procedure WMMouseMove(var Message: TWMMouseMove); message WM_MOUSEMOVE;
  published
    { Published declarations }
    property Style: TSpeedStyle read FStyle write SetStyle default sbSpeed;
    property BoldOnDown: Boolean read FBoldOnDown write FBoldOnDown default False;
    property Seperator: Boolean read FSeperator write FSeperator default False;  property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
  end;

procedure Register;

implementation

procedure TStyleSpeed.SetStyle(Value : TSpeedStyle);
begin
  if Value <> FStyle then
  begin
    FStyle := Value;
    Invalidate;
  end;
end;

procedure TStyleSpeed.Paint;
const
  FlatColors: array[Boolean] of TColor = (clBtnShadow, clBtnHighlight);
var
  ParentClass: TClass;
  x: Integer;
begin
  inherited Paint;
  case Style of
    sbWin95:
      with Canvas do
      if FState in [bsDown, bsExclusive] then begin
        Pen.Color := clBtnHighlight;
        PolyLine([Point(Width - 1, 1),
                  Point(Width - 1, Height - 1),
                  Point(0, Height - 1)]);
      end
      else
      begin
        Pen.Color := clBtnHighlight;
        PolyLine([Point(0, Height - 1),
                  Point(0, 0),
                  Point(Width - 1, 0)]);
        Pen.Color := clBtnFace;
        PolyLine([Point(1, Height - 2),
                  Point(1, 1),
                  Point(Width - 2 , 1)]);
        Pixels[0, Height - 1] := clWindowFrame;
        Pixels[1, Height - 2] := clBtnShadow;
      end;
    sbFlat: { 3.1 }
      with Canvas do
      begin
        Pen.Color := clBtnFace;
        Rectangle(1, 1, Width - 1, Height - 1);
        if not (FMouseOver or (FState in [bsDown, bsExclusive])) then
          Rectangle(0, 0, Width, Height)
        else
        begin
          Pen.Color := FlatColors[not (FState in [bsDown, bsExclusive])];
          PolyLine([Point(0, Height - 1),
                    Point(0, 0),
                    Point(Width - 1, 0)]);
          Pen.Color := FlatColors[FState in [bsDown, bsExclusive]];
          PolyLine([Point(Width - 1, 0),
                    Point(Width - 1, Height - 1),
                    Point(0, Height - 1)]);
        end;
        { 3.2 }
        if FSeperator then with TControlCanvas.Create do
        try
          Control := Parent;
          x := Left - 5;
          Pen.Color := clBtnShadow;
          MoveTo(x, Top);
          LineTo(x, Top + Height);
          Pen.Color := clBtnHighlight;
          MoveTo(x + 1, Top);
          LineTo(x + 1, Top + Height);
        finally
          Free;
        end;
      end;
  end;
end;

procedure TStyleSpeed.CMButtonPressed(var Message: TMessage);
begin
  inherited;
  if FBoldOnDown then
    if Down then Font.Style := [fsBold]
    else Font.Style := [];
end;

procedure TStyleSpeed.WMMouseMove(var Message: TWMMouseMove);
begin
  inherited;
  if Style = sbFlat then
  begin
    if not MouseCapture then
    { The Mouse has entered the button}
    begin
      SetCaptureControl(Self);
      if Enabled and Visible Then
      begin
        FMouseOver := True;
        Invalidate;
      end;
    end;
    if MouseCapture and FMouseOver and ((message.XPos < 0) or (Message.YPos < 0)
      or (message.Xpos > Width) or (message.YPos > Height)) then
    { The Mouse has left the button}
    begin
      FMouseOver := False;
      Invalidate;
      SetCaptureControl(nil);
    end;
  end;
end;

procedure Register;
begin
  RegisterComponents('Calmira', [TStyleSpeed]);
end;

end.
