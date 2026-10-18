{*********************************************************}
{                                                         }
{    Calmira System Library 3.1                           }
{    by Erwin Dokter,                                     }
{    released into the public domain july 2000            }
{                                                         }
{*********************************************************}

unit Win95Pie;

{ This component draws a windows style pie chart as seen in
  Windows 95's Disk Properties dialog.

  Original unit written by David Beale:
  http://www.geocities.com/CapeCanaveral/9646/

  'Calmira-ized' by Erwin Dokter, ie. un-needed code has been
  stripped, the remainder optimized and a few bugs have been fixed.
  This to keep code as small and efficient as possible.

  Properties
    Value - Value to be displayed on the pie chart.
    Maximum - Largest value the pie chart can display.
    Depth - Depth of the pie chart.
    Color - Background color of the control.
    LineColor - Color of pie charts lines.
    FreeColor - Color of the free top part of the pie.
    FreeShadowColor - Color of the free side part of the pie.
    UsedColor - Color of the used top part of the pie.
    UsedShadowColor - Color of the used side part of the pie.

  Methods
    Paint - Paints the pie chart. Usefull for forcing the painting
            of the pie chart. }

interface

uses SysUtils, WinTypes, WinProcs, Classes, Graphics, Controls;

type
  TWin95PieChart = class(TGraphicControl)
  private
    { Private declarations }
    FDepth: Integer;
    FValue, FMaximum: Longint;
    FUsedColor, FUsedShadowColor, FFreeColor, FFreeShadowColor,
      FLineColor: TColor;
    procedure DrawPie;
    procedure SetValue(Value: Longint);
    procedure SetMaximum(Maximum: Longint);
    procedure SetDepth(Depth: Integer);
    Procedure SetUsedColor(Color: TColor);
    Procedure SetUsedShadowColor(Color: TColor);
    Procedure SetFreeColor(Color: TColor);
    Procedure SetFreeShadowColor(Color: TColor);
    Procedure SetLineColor(Color: TColor);
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    procedure Paint; override;
    function GetPercent: Integer;
  published
    { Published declarations }
    property Value: Longint read FValue write SetValue;
    property Maximum: Longint read FMaximum write SetMaximum;
    property Depth: integer read FDepth write SetDepth;
    property UsedColor: TColor read FUsedColor write SetUsedColor;
    property UsedShadowColor: TColor read FUsedShadowColor write SetUsedShadowColor;
    property FreeColor: TColor read FFreeColor write SetFreeColor;
    property FreeShadowColor: TColor read FFreeShadowColor write SetFreeShadowColor;
    property LineColor: TColor read FLineColor write SetLineColor;
    property Align;
    property Color;
    property Hint;
    property ParentColor;
    property ParentShowHint;
    property ShowHint;
    property Visible;
  end;

procedure Register;

implementation

constructor TWin95PieChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := '';
  Width := 122;
  Height := 62;
  FValue := 80;
  FMaximum := 100;
  FDepth := 10;
  FUsedColor := clBlue;
  FUsedShadowColor := clNavy;
  FFreeColor := clFuchsia;
  FFreeShadowColor := clPurple;
  FLineColor := clBlack;
end;

procedure TWin95PieChart.Paint;
begin
  inherited Paint;
  DrawPie;
end;

procedure TWin95PieChart.DrawPie;
var
   X1, Y1, X2, Y2, Angle: Integer;
   DegreeCount: Real;
begin
  Angle := Trunc((FValue / FMaximum) * 360);
  DegreeCount := 270 - Angle;
  X1 := Trunc(0.5 * Width * Sin((DegreeCount * Pi) / 180));
  Y1 := Trunc(0.5 * (Height - FDepth) * Cos((DegreeCount * Pi) / 180));
  X1 := X1 + (Width div 2);
  Y1 := Y1 + ((Height - FDepth) div 2);
  X2 := 0;
  Y2 := (Height - FDepth) div 2;
  with Canvas do
  begin
    Brush.color := Color;
    FillRect(Rect(0, 0, Width, Height));
    { draw the bottom layer of the pie, front 180º only }
    Brush.Color := FFreeShadowColor;
    Pen.Color := FLineColor;
    Pie(0, FDepth, Width, Height, 0, (Height + FDepth) div 2,
      Width, (Height + FDepth) div 2);
    { remove the top border line from the bottom pie }
    Pen.Color := FFreeShadowColor;
    MoveTo(X2 + 1, Y2 + FDepth);
    LineTo(Width - 1, Y2 + FDepth);
    { draw left side boundary }
    Pen.Color := FLineColor;
    MoveTo(X2, Y2);
    LineTo(X2, Y2 + FDepth);
    { draw right side boundary }
    MoveTo(Width - 1, Y2);
    LineTo(Width - 1, Y2 + FDepth);
    { draw the top layer of the pie }
    Brush.Color := FFreeColor;
    Pie(0, 0, Width, Height - FDepth, X2, Y2, X2, Y2);
    { draw the 'used' section over it }
    Brush.Color := FUsedColor;
    if FValue > 0 then Pie(0, 0, Width, Height - FDepth, X1, Y1, X2, Y2);
    { color the front side... }
    Brush.Color := FFreeShadowColor;
    FloodFill(Width div 2, Height - 2, FLineColor, fsBorder);
    if FValue > (FMaximum div 2) then
    begin
      { draw front side devider }
      MoveTo(X1, Y1);
      LineTo(X1, Y1 + FDepth);
      { color the 'used' part }
      Brush.Color := FUsedShadowColor;
      FloodFill(X1 + 1 ,Y1 + FDepth - 2, FLineColor, fsBorder);
    end;
  end;
end;

function TWin95PieChart.GetPercent: Integer;
begin
  Result := Trunc((FValue / FMaximum) * 100);
end;

procedure TWin95PieChart.SetValue(Value: Longint);
begin
  if Value < 0 then Exit;
  FValue := Value;
  DrawPie;
end;

procedure TWin95PieChart.SetMaximum(Maximum: Longint);
begin
  if Maximum < 1 then Exit;
  FMaximum := Maximum;
  DrawPie;
end;

procedure TWin95PieChart.SetDepth(Depth: Integer);
begin
  if Depth < 0 then Exit;
  FDepth := Depth;
  DrawPie;
end;

Procedure TWin95PieChart.SetUsedColor(Color: TColor);
begin
  FUsedColor := Color;
  DrawPie;
end;

Procedure TWin95PieChart.SetUsedShadowColor(Color: TColor);
begin
  FUsedShadowColor := Color;
  DrawPie;
end;

Procedure TWin95PieChart.SetFreeColor(Color: TColor);
begin
  FFreeColor := Color;
  DrawPie;
end;

Procedure TWin95PieChart.SetFreeShadowColor(Color: TColor);
begin
  FFreeShadowColor := Color;
  DrawPie;
end;

Procedure TWin95PieChart.SetLineColor(Color: TColor);
begin
  FLineColor := Color;
  DrawPie;
end;

procedure Register;
begin
  RegisterComponents('Calmira', [TWin95PieChart]);
end;

end.

