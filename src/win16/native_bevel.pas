{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 TBevel: a box, frame or single line in the 3D button colors. }
unit native_bevel;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This bevel requires Win16}{$ENDIF}
interface
uses Classes, Graphics, Controls;
type
  TBevelStyle = (bsLowered, bsRaised);
  TBevelShape = (bsBox, bsFrame, bsTopLine, bsBottomLine, bsLeftLine, bsRightLine);
  TBevel = class(TGraphicControl)
  private
    FStyle: TBevelStyle;
    FShape: TBevelShape;
    procedure SetStyle(Value: TBevelStyle);
    procedure SetShape(Value: TBevelShape);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Shape: TBevelShape read FShape write SetShape default bsBox;
    property Style: TBevelStyle read FStyle write SetStyle default bsLowered;
    property Visible;
  end;
implementation
constructor TBevel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetBounds(0, 0, 50, 50);
end;
procedure TBevel.SetStyle(Value: TBevelStyle);
begin if FStyle <> Value then begin FStyle := Value; Invalidate; end; end;
procedure TBevel.SetShape(Value: TBevelShape);
begin if FShape <> Value then begin FShape := Value; Invalidate; end; end;
procedure TBevel.Paint;
var Color1, Color2, Temp: TColor;
  procedure BevelRect(Left, Top, Right, Bottom: Integer);
  begin
    Canvas.Pen.Color := Color1;
    Canvas.PolyLine([Point(Left, Bottom), Point(Left, Top), Point(Right, Top)]);
    Canvas.Pen.Color := Color2;
    Canvas.PolyLine([Point(Right, Top), Point(Right, Bottom), Point(Left, Bottom)]);
  end;
  procedure BevelLine(C: TColor; X1, Y1, X2, Y2: Integer);
  begin
    Canvas.Pen.Color := C;
    Canvas.MoveTo(X1, Y1);
    Canvas.LineTo(X2, Y2);
  end;
begin
  Canvas.Pen.Width := 1;
  if FStyle = bsLowered then begin Color1 := clBtnShadow; Color2 := clBtnHighlight; end
  else begin Color1 := clBtnHighlight; Color2 := clBtnShadow; end;
  case FShape of
    bsBox: BevelRect(0, 0, Width - 1, Height - 1);
    bsFrame:
      begin
        { Two nested rectangles, the outer one in the first colour only. }
        Temp := Color1; Color1 := Color2;
        BevelRect(1, 1, Width - 1, Height - 1);
        Color2 := Temp; Color1 := Temp;
        BevelRect(0, 0, Width - 2, Height - 2);
      end;
    bsTopLine:
      begin BevelLine(Color1, 0, 0, Width, 0); BevelLine(Color2, 0, 1, Width, 1); end;
    bsBottomLine:
      begin BevelLine(Color1, 0, Height - 2, Width, Height - 2); BevelLine(Color2, 0, Height - 1, Width, Height - 1); end;
    bsLeftLine:
      begin BevelLine(Color1, 0, 0, 0, Height); BevelLine(Color2, 1, 0, 1, Height); end;
    bsRightLine:
      begin BevelLine(Color1, Width - 2, 0, Width - 2, Height); BevelLine(Color2, Width - 1, 0, Width - 1, Height); end;
  end;
end;
end.
