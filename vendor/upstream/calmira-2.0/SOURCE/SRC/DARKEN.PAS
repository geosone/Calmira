procedure DarkenScreen;
var
  pattern : HBitmap;
  dc : HDC;
  i, j: Integer;
  brush, oldbrush : HBrush;
begin
  pattern := LoadBitmap(HInstance, 'SCREENMESH');
  brush := CreatePatternBrush(pattern);

  dc := GetDC(0);
  oldbrush := SelectObject(dc, brush);
  PatBlt(dc, 0, 0, Screen.Width, Screen.Height, $A000C9);
  SelectObject(dc, oldbrush);

  ReleaseDC(0, dc);
  DeleteObject(brush);
  DeleteObject(pattern);
end;