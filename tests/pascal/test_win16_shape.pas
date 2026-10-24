program TestWin16Shape;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls;
type
  TEvents = class
    Paints, Changes: Integer;
    procedure Paint(Sender: TObject);
    procedure Change(Sender: TObject);
  end;
var Events: TEvents; Main: TForm; Shape: TShape; Box: TPaintBox; Edit: TEdit; Pen: TPen;
  Failed: Boolean; DC: HDC; Area: TRect;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure Pump;
var Msg: TMsg; Start: LongInt;
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < 150 do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure TEvents.Paint(Sender: TObject);
begin
  Inc(Paints);
  Box.Canvas.Brush.Color := clRed;
  Box.Canvas.FillRect(Rect(0, 0, 10, 10));
end;
procedure TEvents.Change(Sender: TObject); begin Inc(Changes); end;
function PixelAt(X, Y: Integer): TColorRef;
begin
  DC := GetDC(Main.Handle);
  Result := GetPixel(DC, X, Y);
  ReleaseDC(Main.Handle, DC);
end;
begin
  LogLine('STEP shape');
  Events := TEvents.Create;
  try
    Area.TopLeft := Point(1, 2); Area.BottomRight := Point(3, 4);
    Check((Area.Left = 1) and (Area.Top = 2) and (Area.Right = 3) and (Area.Bottom = 4),
      'TRect TopLeft and BottomRight overlay the coordinates');
    Pen := TPen.Create; Pen.OnChange := Events.Change;
    Pen.Color := clRed; Pen.Color := clRed; Pen.Width := 2;
    Check(Events.Changes = 2, 'a pen reports each real change');
    Pen.Free;

    Main := TForm.Create(nil); Main.SetBounds(10, 10, 300, 200); Main.Color := clWhite;
    Shape := TShape.Create(Main);
    Check((Shape.Width = 65) and (Shape.Height = 65) and (Shape.Shape = stRectangle) and
      (Shape.Brush.Color = clWhite) and (Shape.Pen.Color = clBlack), 'TShape has Delphi''s defaults');
    Shape.Parent := Main; Shape.SetBounds(10, 10, 60, 40);
    Box := TPaintBox.Create(Main); Box.Parent := Main; Box.SetBounds(100, 10, 40, 40);
    Box.OnPaint := Events.Paint;
    Edit := TEdit.Create(Main); Edit.Parent := Main; Edit.SetBounds(10, 100, 100, 24);
    Main.Show; Pump;
    Shape.Brush.Color := clBlue; Pump;
    Check((PixelAt(10, 10) = ColorToRGB(clBlack)) and (PixelAt(40, 30) = ColorToRGB(clBlue)),
      'changing the brush repaints the shape');
    Shape.Shape := stEllipse; Pump;
    Check((PixelAt(11, 11) = ColorToRGB(clWhite)) and (PixelAt(40, 30) = ColorToRGB(clBlue)),
      'an ellipse leaves the corners unpainted');
    Shape.Shape := stCircle; Pump;
    Check((PixelAt(15, 30) = ColorToRGB(clWhite)) and (PixelAt(40, 30) = ColorToRGB(clBlue)),
      'a circle uses the shorter side');
    Check((Events.Paints > 0) and (PixelAt(105, 15) = ColorToRGB(clRed)) and (PixelAt(125, 30) = ColorToRGB(clWhite)),
      'TPaintBox paints through OnPaint');

    Check((FindControl(Main.Handle) = Main) and (FindControl(Edit.Handle) = Edit) and
      (FindControl(GetDesktopWindow) = nil) and (FindControl(0) = nil), 'FindControl maps handles to controls');
    Check(Edit.Showing and Main.Showing, 'visible controls are showing');
    Main.Hide;
    Check(not Edit.Showing and Edit.Visible, 'a hidden parent hides its children');
    Main.Show; Pump;
    Check(GetCaptureControl = nil, 'without capture there is no capture control');
    SetCapture(Edit.Handle);
    Check(GetCaptureControl = Edit, 'GetCaptureControl finds the capturing control');
    ReleaseCapture;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Main.Free;
  Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
