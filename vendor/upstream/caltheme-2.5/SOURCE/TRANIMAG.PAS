{
  The propose of this component is to display a REAL TRANSPARENT image
  and detect when your mouse cursor is on top of the transparent
  part or not.

  My name's Nuno Antunes and I'm from Portugal (sorry about the 
  english).
  Most of the code presented in this component was copied from
  the TAnimated component made by L. David Baldwin (greetings).
  Why a REAL TRANSPARENT IMAGE?
  Because most of the components that circle the net and say
  that are Transparent, are not. Most of them replaces the selected
  color (known as transparent) with the color of the form or panel
  that's behind. If you have a bitmap in the back, you are unable to
  see it.
  
  This component has been tested on top of BMPs, GIFs and PCXs and
  works fine. You are now able to see the grafic thats behind your 
  component.

  In my programs I needed to know when the
  mouse is over the picture or is over the transparent part.
  With this in mind I've created a property called
  < CursorOverImage > that gives the value in that moment.
  The best place to test this property is on the events <OnMouse...>

  I've used this component in Delphi 1, but I suppose that it works 
  fine in Delphi 2.

  Any questions please feel free to e-mail me. <nuno.antunes@rumos.pt>

  Like it was then, this component is freeware and should be distributed
  as such.
  When distribuiting this component leave this message intact, and if you
  use it for any purpose give credit to the authors.
  If you improve the component please tell the authors, they would like
  to know.

  Check my other component TIPS, you can find it on my homepage
  http://www.rumos.pt/~nma/
  or in the Delphi Super Page
  http://sunsite.icm.edu.pl/delphi/
}

unit Tranimag;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, StdCtrls, ExtCtrls, XParBMP;

type
  TTranImage = class(TGraphicControl)
  private
    FBitMap : TBitmap;
    FTransparentColor : TColor;
    FOver : Boolean;
    procedure SetBitMap(Value : TBitMap);
    procedure SetTransparentColor(Value : TColor);

    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    function OnGlyphP(X, Y: integer): boolean;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property BitMap : TBitMap read FBitMap write SetBitMap;
    property TransparentColor : TColor read FTransparentColor
             write SetTransparentColor default clSilver;
    property CursorOverImage: Boolean read FOver;
    property Height default 30;
    property Width default 30;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property Visible;

  end;

procedure Register;

implementation

constructor TTranImage.Create(AOwner: TComponent);
begin
inherited Create(AOwner);
Width := 30;
Height := 30;
FBitMap := TBitMap.Create;
ControlStyle := ControlStyle +[csOpaque];
FTransparentColor := clSilver;
end;

destructor TTranImage.Destroy;
begin
FBitMap.Free;
inherited Destroy;
end;

procedure TTranImage.SetBitMap(Value : TBitMap);
begin
FBitMap.Assign(Value);
Height := FBitMap.Height;
Width := FBitmap.Width;
if Height = 0 then Height := 30;
if Width = 0 then Width := 30;
end;

procedure TTranImage.SetTransparentColor(Value : TColor);
begin
if Value <> FTransparentColor then
  begin
  FTransparentColor := Value;
  Invalidate;
  end;
end;

procedure TTranImage.Paint;
var
  ARect, BRect : TRect;
  Tmp : TBitMap;
begin
ARect := Rect(0,0,Width,Height);
if FBitMap.Height > 0 then
  begin
  if (FTransparentColor >= 0) and (FTransparentColor <= $7FFFFFFF) then
    begin

    Tmp := TBitmap.Create;
    Tmp.Height := FBitMap.Height;
    Tmp.Width := FBitMap.Width;
    Tmp.Canvas.CopyRect(ARect, FBitmap.Canvas, ARect);
    DrawTransparentBitmap( Canvas.Handle, Tmp, 0, 0, FTransparentColor );
    Tmp.Free;

    end
  else
    Canvas.CopyRect(ARect, FBitmap.Canvas, ARect);
  end
else
  begin
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(BoundsRect);
  end;
if csDesigning in ComponentState then
  begin
  Canvas.Pen.Style := psDash;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(0, 0, Width, Height);
  end;
end;

{event handlers}

function TTranImage.OnGlyphP(X, Y: integer): boolean;
begin
  Result := PtInRect(ClientRect, Point(X, Y)) and
            (FBitmap.Canvas.Pixels[X, Y] <> FTransparentColor);
end;

procedure TTranImage.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  FOver := OnGlyphP(X, Y);
  Inherited MouseMove(Shift, X, Y);
end;

procedure Register;
begin
  RegisterComponents('MyStuff', [TTranImage]);
end;

end.
