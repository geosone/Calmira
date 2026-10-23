program TestWin16GDI;
{$APPTYPE GUI}{$mode delphi}{$H-}
{ Leave room in DGROUP for the loader's stack/local-heap reservation.
  Far Pascal allocations still use the global heap, not this local heap. }
{$M 4096,4096}
uses WinTypes, WinProcs, Win31, SysUtils, gdi_canvas, gdi_bitmap, gdi_icon;
var
  Failed, Rejected: Boolean;
  ScreenDC, MemoryDC: HDC;
  Bitmap, OldBitmap: HBITMAP;
  SentinelPen, OldPen: HPEN;
  SentinelBrush, OldBrush: HBRUSH;
  SentinelFont, OldFont: HFONT;
  Canvas, CopyCanvas: TGDICanvas;
  Area: TRect;
  I, X, Y, RedPixels, BeforeResources, AfterResources: Integer;
  Extent: TPoint;
  Image, ResourceImage: TGDIBitmap;
  SavedImage: HBITMAP;
procedure LogLine(const Text: string);
var FileHandle: HFILE; Buffer: array[0..255] of Char; Line: string;
begin
  FileHandle := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if FileHandle = HFILE_ERROR then FileHandle := _lcreat('C:\GDITEST.LOG', 0);
  if FileHandle = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(FileHandle, 0, 2);
  Line := Text + #13#10; StrPCopy(Buffer, Line);
  _lwrite(FileHandle, FarPointer(@Buffer), Length(Line));
  _lclose(FileHandle);
end;
procedure Check(Okay: Boolean; const Description: string);
begin
  if Okay then LogLine('PASS ' + Description)
  else begin LogLine('FAIL ' + Description); Failed := True; end;
end;
procedure CheckSelectedObjects;
var Previous: HGDIOBJ;
begin
  Previous := SelectObject(MemoryDC, GetStockObject(BLACK_PEN));
  Check(Previous = SentinelPen, 'caller pen restored');
  SelectObject(MemoryDC, Previous);
  Previous := SelectObject(MemoryDC, GetStockObject(WHITE_BRUSH));
  Check(Previous = SentinelBrush, 'caller brush restored');
  SelectObject(MemoryDC, Previous);
  Previous := SelectObject(MemoryDC, GetStockObject(SYSTEM_FONT));
  Check(Previous = SentinelFont, 'caller font restored');
  SelectObject(MemoryDC, Previous);
end;
function Box(Left, Top, Right, Bottom: SmallInt): TRect;
begin Result.Left := Left; Result.Top := Top; Result.Right := Right; Result.Bottom := Bottom; end;
procedure CheckBitmapEditing;
var SavedCanvas: TGDICanvas; OldHandle: HBITMAP; Bad: Boolean;
  SavedStretch: SmallInt; X, Y, Strip: Integer;
begin
  LogLine('STEP bitmap editing');
  Image.Clear; ResourceImage.Clear;
  SavedCanvas := Image.Canvas;
  Image.Width := 4;
  Check((Image.Width = 4) and (Image.Height = 0) and (Image.Handle = 0),
    'width can be set before height without allocating a bitmap');
  Image.Height := 4;
  Check((Image.Handle <> 0) and (Image.Canvas.Pixels[3, 3] = clWhite),
    'new color bitmap starts white');
  Image.Canvas.Pixels[0, 0] := clRed; Image.Canvas.Pixels[3, 3] := clBlue;
  ResourceImage.Assign(Image);
  Bad := False;
  for Y := 0 to 3 do for X := 0 to 3 do
    if ResourceImage.Canvas.Pixels[X, Y] <> Image.Canvas.Pixels[X, Y] then Bad := True;
  Check(not Bad and (Image.Handle <> ResourceImage.Handle), 'Assign copies pixels into independent handle');
  ResourceImage.Canvas.Pixels[0, 0] := clLime;
  Check(Image.Canvas.Pixels[0, 0] = clRed, 'editing assigned bitmap does not change source');
  Image.Clear;
  Check((ResourceImage.Width = 4) and (ResourceImage.Canvas.Pixels[0, 0] = clLime),
    'assigned bitmap survives release of source handle');
  Image.Assign(ResourceImage); Image.Canvas.Pixels[0, 0] := clRed;
  OldHandle := Image.Handle; Image.Assign(Image);
  Check(Image.Handle = OldHandle, 'self Assign preserves handle');
  Image.SetSize(6, 5);
  Check((Image.Canvas = SavedCanvas) and (Image.Canvas.Pixels[0, 0] = clRed) and
    (Image.Canvas.Pixels[3, 3] = clBlue) and (Image.Canvas.Pixels[5, 4] = clWhite),
    'growth preserves overlap and canvas object and initializes new pixels');
  Image.Width := 2; Image.Height := 2; Image.SetSize(4, 4);
  Check((Image.Canvas.Pixels[0, 0] = clRed) and (Image.Canvas.Pixels[3, 3] = clWhite),
    'shrink crops discarded pixels before regrowth');
  OldHandle := Image.Handle; Image.SetSize(4, 4);
  Check(Image.Handle = OldHandle, 'unchanged dimensions avoid reallocating');
  Bad := False;
  try Image.SetSize(-1, 4); except on EGDIError do Bad := True; end;
  Check(Bad and (Image.Handle = OldHandle) and (Image.Width = 4), 'invalid resize preserves bitmap');
  Bad := False;
  try Image.Assign(Canvas.Pen); except on EConvertError do Bad := True; end;
  Check(Bad and (Image.Handle = OldHandle), 'incompatible Assign preserves bitmap');
  ResourceImage.Assign(nil);
  Check((ResourceImage.Width = 0) and (ResourceImage.Handle = 0), 'Assign nil clears bitmap');
  Bad := False;
  try Canvas.CopyRect(Box(0, 0, 2, 2), ResourceImage.Canvas, Box(0, 0, 2, 2));
  except on EGDIError do Bad := True; end;
  Check(Bad, 'source canvas without a bitmap DC rejected');
  ResourceImage.Height := 7;
  Image.Assign(ResourceImage);
  Check((Image.Width = 0) and (Image.Height = 7) and (Image.Handle = 0),
    'Assign copies pending empty dimensions');
  Image.LoadFromFile('C:\BITS24.BMP'); ResourceImage.SetSize(8, 8);
  ResourceImage.Canvas.CopyRect(Box(2, 2, 4, 4), Image.Canvas, Box(0, 0, 2, 2));
  Check((ResourceImage.Canvas.Pixels[2, 2] = clRed) and
    (ResourceImage.Canvas.Pixels[3, 2] = clLime) and
    (ResourceImage.Canvas.Pixels[2, 3] = clBlue) and
    (ResourceImage.Canvas.Pixels[0, 0] = clWhite), 'CopyRect copies subrectangle without changing surrounding pixels');
  SavedStretch := GetStretchBltMode(MemoryDC);
  SetStretchBltMode(MemoryDC, BLACKONWHITE);
  Canvas.CopyRect(Box(80, 40, 88, 48), Image.Canvas, Box(0, 0, 2, 2));
  Check((Canvas.Pixels[82, 42] = clRed) and (Canvas.Pixels[86, 42] = clLime) and
    (Canvas.Pixels[82, 46] = clBlue) and (Canvas.Pixels[86, 46] = clWhite),
    'scaled CopyRect produces expected color quadrants');
  Check((GetStretchBltMode(MemoryDC) = BLACKONWHITE) and (GetROP2(MemoryDC) = R2_XORPEN),
    'CopyRect restores caller stretch and raster modes');
  SetStretchBltMode(MemoryDC, SavedStretch);
  ResourceImage.Canvas.CopyRect(Box(3, 2, 5, 4), ResourceImage.Canvas, Box(2, 2, 4, 4));
  Check((ResourceImage.Canvas.Pixels[3, 2] = clRed) and
    (ResourceImage.Canvas.Pixels[4, 2] = clLime), 'overlapping same-size self-copy');
  Bad := False;
  try Canvas.CopyRect(Box(-32768, 0, 32767, 2), Image.Canvas, Box(0, 0, 2, 2));
  except on EGDIError do Bad := True; end;
  Check(Bad, 'rectangle width validated in 32 bits');
  Bad := False;
  try Canvas.CopyRect(Box(2, 0, 0, 2), Image.Canvas, Box(0, 0, 2, 2));
  except on EGDIError do Bad := True; end;
  Check(Bad, 'mirrored copy rectangle rejected');
  Bad := False;
  try Canvas.CopyRect(Box(0, 0, 2, 2), nil, Box(0, 0, 2, 2));
  except on EGDIError do Bad := True; end;
  Check(Bad, 'nil source canvas rejected');
  Bad := False;
  try Image.Canvas.CopyRect(Box(0, 0, 1, 1), Image.Canvas, Box(0, 0, 2, 2));
  except on EGDIError do Bad := True; end;
  Check(Bad and (Image.Canvas.Pixels[0, 0] = clRed), 'scaled self-copy rejected without altering pixels');
  Canvas.CopyRect(Box(80, 40, 80, 48), Image.Canvas, Box(0, 0, 2, 2));
  Check(Canvas.Pixels[82, 42] = clRed, 'zero-size CopyRect is a no-op');
  { Model the original TStartImages strip growth and subrectangle insertion. }
  ResourceImage.SetSize(32, 16);
  for Strip := 0 to 3 do
  begin
    ResourceImage.Height := ResourceImage.Height + 16;
    ResourceImage.Canvas.CopyRect(Box(0, Strip * 16, 2, Strip * 16 + 2),
      Image.Canvas, Box(0, 0, 2, 2));
  end;
  Check((ResourceImage.Canvas.Pixels[0, 0] = clRed) and
    (ResourceImage.Canvas.Pixels[0, 48] = clRed), 'start-menu style strip growth retains earlier icons');
end;
procedure CheckGraphicsDrawing;
var Icon, IconCopy: TGDIIcon; RawIcon, SharedIcon, SavedIcon: HICON;
  AndBits, XorBits: array[0..127] of Byte; N, X, Y, PoolBefore: Integer;
  Bad: Boolean; OriginalBk, OriginalOrigin: LongInt;
begin
  LogLine('STEP graphic drawing and color keys');
  Image.LoadFromFile('C:\BITS24.BMP'); Image.Transparent := True;
  Image.TransparentColor := clWhite;
  ResourceImage.SetSize(40, 40);
  ResourceImage.Canvas.Brush.Color := clLime;
  ResourceImage.Canvas.FillRect(Box(0, 0, 40, 40));
  OriginalBk := GetBkColor(Image.Canvas.Handle);
  ResourceImage.Canvas.Draw(2, 2, Image);
  Check((ResourceImage.Canvas.Pixels[2, 2] = clRed) and
    (ResourceImage.Canvas.Pixels[3, 2] = clLime) and
    (ResourceImage.Canvas.Pixels[2, 3] = clBlue) and
    (ResourceImage.Canvas.Pixels[3, 3] = clLime), 'generic bitmap Draw preserves background under color key');
  Check((Image.Canvas.Pixels[1, 1] = clWhite) and
    (GetBkColor(Image.Canvas.Handle) = OriginalBk), 'transparent drawing leaves source pixels and DC unchanged');
  ResourceImage.Assign(Image);
  Check(ResourceImage.Transparent and (ResourceImage.TransparentColor = clWhite),
    'bitmap Assign copies transparency settings');
  ResourceImage.SetSize(40, 40); ResourceImage.Transparent := False;
  ResourceImage.Canvas.Brush.Color := clBlue;
  ResourceImage.Canvas.FillRect(Box(0, 0, 40, 40));
  ResourceImage.Canvas.Brush.Color := clLime;
  ResourceImage.Canvas.BrushCopy(Box(4, 4, 8, 8), Image.Canvas, Box(0, 0, 2, 2), clWhite);
  Check((ResourceImage.Canvas.Pixels[4, 4] = clRed) and
    (ResourceImage.Canvas.Pixels[7, 7] = clLime) and
    (ResourceImage.Canvas.Pixels[3, 3] = clBlue), 'BrushCopy scales source and replaces key with brush color');
  ResourceImage.Canvas.Brush.Style := bsClear;
  ResourceImage.Canvas.BrushCopy(Box(10, 4, 12, 6), Image.Canvas, Box(0, 0, 2, 2), clWhite);
  Check(ResourceImage.Canvas.Pixels[11, 5] = clBlue, 'clear BrushCopy preserves background under key');
  ResourceImage.Canvas.Brush.Style := bsSolid;
  OriginalOrigin := GetBrushOrg(ResourceImage.Canvas.Handle);
  SetBrushOrg(ResourceImage.Canvas.Handle, 3, 2);
  ResourceImage.Canvas.Brush.Style := bsHorizontal;
  ResourceImage.Canvas.Brush.Color := clRed;
  ResourceImage.Canvas.FillRect(Box(24, 8, 32, 16));
  ResourceImage.Canvas.BrushCopy(Box(24, 16, 32, 24), Image.Canvas, Box(1, 1, 2, 2), clWhite);
  Bad := False;
  for Y := 0 to 7 do for X := 0 to 7 do
    if ResourceImage.Canvas.Pixels[24 + X, 8 + Y] <>
      ResourceImage.Canvas.Pixels[24 + X, 16 + Y] then Bad := True;
  Check(not Bad, 'BrushCopy hatch aligns with caller brush origin');
  ResourceImage.Canvas.Brush.Style := bsSolid;
  SetBrushOrg(ResourceImage.Canvas.Handle, SmallInt(LoWord(OriginalOrigin)), SmallInt(HiWord(OriginalOrigin)));
  ResourceImage.Canvas.CopyTransparent(Box(20, 0, 22, 2), Image.Canvas, Box(-1, -1, 1, 1), clWhite);
  Check((ResourceImage.Canvas.Pixels[20, 0] = clBlue) and
    (ResourceImage.Canvas.Pixels[21, 1] = clRed), 'clipped source pixels remain transparent rather than uninitialized');
  Image.Transparent := False;
  ResourceImage.Canvas.Draw(14, 4, Image);
  Check(ResourceImage.Canvas.Pixels[15, 5] = clWhite, 'opaque generic bitmap Draw does not apply color key');
  ResourceImage.Canvas.CopyTransparent(Box(15, 4, 17, 6), ResourceImage.Canvas, Box(14, 4, 16, 6), clWhite);
  Check((ResourceImage.Canvas.Pixels[15, 4] = clRed) and
    (ResourceImage.Canvas.Pixels[16, 5] = clBlue), 'overlapping transparent copy snapshots source before output');
  Bad := False;
  try Canvas.CopyTransparent(Box(-32768, 0, 32767, 1), Image.Canvas, Box(0, 0, 2, 2), clWhite);
  except on EGDIError do Bad := True; end;
  Check(Bad, 'oversized transparent copy rejected');
  Bad := False;
  try Canvas.Draw(0, 0, nil); except on EGDIError do Bad := True; end;
  Check(Bad, 'nil graphic rejected');
  Image.Transparent := True;
  Bad := False;
  try Image.DrawTo(MemoryDC, 32767, 0); except on EGDIError do Bad := True; end;
  Check(Bad, 'transparent bitmap destination coordinate overflow rejected');
  Image.Transparent := False;
  LogLine('STEP native icon ownership and masks');
  Icon := nil; IconCopy := nil; RawIcon := 0;
  try
    for N := 0 to 31 do
    begin
      AndBits[N * 4] := $FF; AndBits[N * 4 + 1] := 0;
      AndBits[N * 4 + 2] := 0; AndBits[N * 4 + 3] := $FF;
      XorBits[N * 4] := 0; XorBits[N * 4 + 1] := $FF;
      XorBits[N * 4 + 2] := 0; XorBits[N * 4 + 3] := $FF;
    end;
    RawIcon := CreateIcon(HInstance, 32, 32, 1, 1, @AndBits, @XorBits);
    if RawIcon = 0 then raise EGDIError.Create('Cannot create icon test fixture');
    Icon := TGDIIcon.Create; IconCopy := TGDIIcon.Create;
    Icon.CopyFromHandle(RawIcon);
    Check(Icon.Handle <> RawIcon, 'icon copies caller handle instead of taking ownership');
    DestroyIcon(RawIcon); RawIcon := 0;
    IconCopy.Assign(Icon); SavedIcon := IconCopy.Handle;
    Icon.Clear;
    ResourceImage.Canvas.Brush.Color := clLime;
    ResourceImage.SetSize(80, 40);
    ResourceImage.Canvas.FillRect(Box(0, 0, 80, 40));
    ResourceImage.Canvas.Draw(0, 0, IconCopy);
    LogLine('ICON PIXELS ' + IntToHex(ResourceImage.Canvas.Pixels[2, 2], 6) + ' ' +
      IntToHex(ResourceImage.Canvas.Pixels[10, 2], 6) + ' ' +
      IntToHex(ResourceImage.Canvas.Pixels[18, 2], 6) + ' ' +
      IntToHex(ResourceImage.Canvas.Pixels[26, 2], 6));
    Check((ResourceImage.Canvas.Pixels[2, 2] = clLime) and
      (ResourceImage.Canvas.Pixels[10, 2] = clWhite) and
      (ResourceImage.Canvas.Pixels[18, 2] = clBlack) and
      (ResourceImage.Canvas.Pixels[26, 2] <> clLime), 'generic icon Draw handles transparent white black and inverted masks');
    { XOR inverts device color indices, not necessarily 24-bit RGB. Compare
      against real DrawIcon rather than assuming a particular VGA palette. }
    if not WinProcs.DrawIcon(ResourceImage.Canvas.Handle, 40, 0, IconCopy.Handle) then
      raise EGDIError.Create('Cannot draw icon reference');
    Bad := False;
    for Y := 0 to 31 do for X := 0 to 31 do
      if ResourceImage.Canvas.Pixels[X, Y] <> ResourceImage.Canvas.Pixels[40 + X, Y] then Bad := True;
    Check(not Bad, 'all generic icon pixels match direct native DrawIcon');
    IconCopy.Assign(IconCopy);
    Check(IconCopy.Handle = SavedIcon, 'icon self Assign keeps handle');
    Bad := False;
    try IconCopy.LoadFromResource(HInstance, 'ABSENT'); except on EGDIError do Bad := True; end;
    Check(Bad and (IconCopy.Handle = SavedIcon), 'missing icon resource preserves previous icon');
    Icon.LoadFromResource(HInstance, PChar(201));
    IconCopy.LoadFromResource(HInstance, 'ICONPROBE');
    ResourceImage.Canvas.FillRect(Box(0, 0, 40, 40));
    ResourceImage.Canvas.Draw(0, 0, IconCopy);
    Check((Icon.Handle <> 0) and (ResourceImage.Canvas.Pixels[10, 2] = clWhite) and
      (ResourceImage.Canvas.Pixels[2, 2] = clLime), 'named and numeric icon resources draw with native masks');
    SharedIcon := LoadIcon(HInstance, PChar(201)); Icon.Clear;
    Check(WinProcs.DrawIcon(ResourceImage.Canvas.Handle, 0, 0, SharedIcon),
      'clearing copied icon does not destroy shared resource');
    IconCopy.Assign(nil);
    Bad := False;
    try IconCopy.DrawTo(MemoryDC, 0, 0); except on EGDIError do Bad := True; end;
    Check(Bad and (IconCopy.Handle = 0), 'empty icon drawing rejected');
    Icon.LoadFromResource(0, IDI_APPLICATION);
    Canvas.Draw(0, 0, Icon);
    Check((GetTextColor(MemoryDC) = clBlue) and (GetBkColor(MemoryDC) = clLime) and
      (GetROP2(MemoryDC) = R2_XORPEN), 'generic icon Draw restores caller DC state');
    PoolBefore := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for N := 1 to 100 do
    begin
      Icon.LoadFromResource(HInstance, PChar(201)); IconCopy.Assign(Icon);
      ResourceImage.Canvas.Draw(0, 0, IconCopy);
      Canvas.CopyTransparent(Box(80, 40, 84, 44), Image.Canvas, Box(0, 0, 2, 2), clWhite);
      Canvas.BrushCopy(Box(90, 40, 94, 44), Image.Canvas, Box(0, 0, 2, 2), clWhite);
    end;
    Check(GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolBefore - 2,
      'repeated icon and color-key drawing does not drain GDI pool');
    Check((GetTextColor(MemoryDC) = clBlue) and (GetBkColor(MemoryDC) = clLime) and
      (GetROP2(MemoryDC) = R2_XORPEN) and (GetBkMode(MemoryDC) = TRANSPARENT),
      'color-key operations restore caller text background and raster state');
  finally
    IconCopy.Free; Icon.Free;
    if RawIcon <> 0 then DestroyIcon(RawIcon);
  end;
end;
begin
  LogLine('STEP startup');
  Canvas := nil; CopyCanvas := nil;
  Image := nil; ResourceImage := nil;
  ScreenDC := 0; MemoryDC := 0; Bitmap := 0;
  SentinelPen := 0; SentinelBrush := 0; SentinelFont := 0;
    try
      LogLine('STEP GetDC');
      ScreenDC := GetDC(0);
      LogLine('STEP CreateCompatibleDC');
      MemoryDC := CreateCompatibleDC(ScreenDC);
      LogLine('STEP CreateCompatibleBitmap');
      Bitmap := CreateCompatibleBitmap(ScreenDC, 128, 96);
      Check((ScreenDC <> 0) and (MemoryDC <> 0) and (Bitmap <> 0), 'real color memory DC');
      if (ScreenDC = 0) or (MemoryDC = 0) or (Bitmap = 0) then raise Exception.Create('Missing GDI fixture');
      OldBitmap := SelectObject(MemoryDC, Bitmap);
      SentinelPen := CreatePen(PS_SOLID, 1, clLime);
      SentinelBrush := CreateSolidBrush(clBlue);
      SentinelFont := CreateFont(-11, 0, 0, 0, FW_NORMAL, 0, 0, 0,
        DEFAULT_CHARSET, 0, 0, 0, 0, 'System');
      OldPen := SelectObject(MemoryDC, SentinelPen);
      OldBrush := SelectObject(MemoryDC, SentinelBrush);
      OldFont := SelectObject(MemoryDC, SentinelFont);
      SetTextColor(MemoryDC, clBlue); SetBkColor(MemoryDC, clLime);
      SetBkMode(MemoryDC, TRANSPARENT); SetROP2(MemoryDC, R2_XORPEN);
      LogLine('STEP create canvas');
      Canvas := TGDICanvas.Create;
      LogLine('STEP missing DC exception');
      Rejected := False;
      try Canvas.LineTo(10, 10); except on EGDIError do Rejected := True; end;
      Check(Rejected, 'missing DC rejected before drawing');
      LogLine('STEP draw');
      Canvas.Handle := MemoryDC;
      Area.Left := 0; Area.Top := 0; Area.Right := 128; Area.Bottom := 96;
      Canvas.Brush.Color := clWhite; Canvas.FillRect(Area);
      Check(Canvas.Pixels[10, 10] = clWhite, 'solid fill pixels');
      Canvas.Pen.Color := clRed;
      Canvas.MoveTo(2, 2); Canvas.LineTo(30, 2);
      Check(Canvas.Pixels[10, 2] = clRed, 'line uses canvas pen');
      Check(GetCurrentPosition(MemoryDC) = LongInt($0002001E), 'line advances pen position');
      Canvas.Brush.Color := clBlue;
      Canvas.Rectangle(10, 10, 30, 30);
      Check((Canvas.Pixels[10, 10] = clRed) and (Canvas.Pixels[20, 20] = clBlue),
        'rectangle pen and brush');
      Canvas.Brush.Style := bsClear;
      Canvas.Rectangle(15, 15, 25, 25);
      Check(Canvas.Pixels[20, 20] = clBlue, 'clear brush preserves interior');
      Canvas.FillRect(Area);
      Check(Canvas.Pixels[20, 20] = clBlue, 'clear fill is a no-op');
      Canvas.Pen.Style := psClear;
      Canvas.Brush.Style := bsSolid; Canvas.Brush.Color := clLime;
      Canvas.Rectangle(40, 10, 60, 30);
      Check(Canvas.Pixels[50, 20] = clLime, 'clear pen with solid brush');
      Canvas.Pixels[4, 4] := clBlue;
      Check(Canvas.Pixels[4, 4] = clBlue, 'pixel write and read');
      Canvas.Font.Color := clRed; Canvas.Font.Style := [fsBold, fsItalic];
      Extent := Canvas.TextExtent('Calmira');
      Check((Extent.X > 0) and (Extent.Y > 0), 'font extent from real GDI');
      Check((Canvas.TextWidth('Calmira') = Extent.X) and
        (Canvas.TextHeight('Calmira') = Extent.Y), 'text width and height agree');
      Canvas.TextOut(2, 40, 'Calmira');
      RedPixels := 0;
      for Y := 40 to 60 do for X := 0 to 100 do
        if Canvas.Pixels[X, Y] = clRed then Inc(RedPixels);
      Check(RedPixels > 0, 'TextOut draws actual font-color pixels');
      Check((GetTextColor(MemoryDC) = clBlue) and (GetBkColor(MemoryDC) = clLime) and
        (GetBkMode(MemoryDC) = TRANSPARENT) and (GetROP2(MemoryDC) = R2_XORPEN),
        'caller text colors mode and ROP restored');
      CheckSelectedObjects;
      CopyCanvas := TGDICanvas.Create; CopyCanvas.Handle := MemoryDC;
      CopyCanvas.Pen.Assign(Canvas.Pen); CopyCanvas.Brush.Assign(Canvas.Brush);
      CopyCanvas.Font.Assign(Canvas.Font);
      Check((CopyCanvas.Font.Style = Canvas.Font.Style) and
        (CopyCanvas.Font.Height = Canvas.Font.Height) and
        (CopyCanvas.Pen.Style = Canvas.Pen.Style) and
        (CopyCanvas.Brush.Color = Canvas.Brush.Color), 'resource Assign copies state');
      Canvas.Font.Height := -20;
      Check(CopyCanvas.Font.Height <> Canvas.Font.Height, 'assigned resources are independent');
      Rejected := False;
      try Canvas.Pen.Width := -1; except on EGDIError do Rejected := True; end;
      Check(Rejected and (Canvas.Pen.Width = 1), 'invalid pen width keeps previous state');
      Rejected := False;
      try Canvas.Font.Name := StringOfChar('x', LF_FACESIZE); except on EGDIError do Rejected := True; end;
      Check(Rejected and (Canvas.Font.Name = 'MS Sans Serif'), 'invalid font name keeps previous state');
      Check(ColorToRGB(clWindow) = GetSysColor(COLOR_WINDOW), 'system color resolution');
      Canvas.RefreshSystemColors;
      LogLine('STEP bitmap loading');
      Image := TGDIBitmap.Create; ResourceImage := TGDIBitmap.Create;
      Image.LoadFromFile('C:\PROBE.BMP');
      ResourceImage.LoadFromResource(HInstance, PChar(101));
      Check((Image.Width = 16) and (Image.Height = 16), 'BMP file dimensions');
      Check((Image.Width = ResourceImage.Width) and (Image.Height = ResourceImage.Height),
        'numeric resource dimensions match file');
      Rejected := False;
      for Y := 0 to 15 do for X := 0 to 15 do
        if Image.Canvas.Pixels[X, Y] <> ResourceImage.Canvas.Pixels[X, Y] then Rejected := True;
      Check(not Rejected, 'all file pixels equal native resource including orientation');
      Image.DrawTo(MemoryDC, 100, 75);
      Rejected := False;
      for Y := 0 to 15 do for X := 0 to 15 do
        if Canvas.Pixels[100 + X, 75 + Y] <> Image.Canvas.Pixels[X, Y] then Rejected := True;
      Check(not Rejected, 'bitmap blit draws matching destination pixels');
      SavedImage := Image.Handle;
      Rejected := False;
      try Image.LoadFromFile('C:\BAD.BMP'); except on EGDIError do Rejected := True; end;
      Check(Rejected and (Image.Handle = SavedImage), 'invalid file preserves loaded bitmap');
      Rejected := False;
      try Image.LoadFromFile('C:\SHORT.BMP'); except on EGDIError do Rejected := True; end;
      Check(Rejected and (Image.Handle = SavedImage), 'truncated pixel data preserves loaded bitmap');
      Rejected := False;
      try Image.LoadFromResource(HInstance, 'ABSENT'); except on EGDIError do Rejected := True; end;
      Check(Rejected and (Image.Handle = SavedImage), 'missing resource preserves loaded bitmap');
      ResourceImage.LoadFromResource(HInstance, 'PROBE');
      Check((ResourceImage.Width = 24) and (ResourceImage.Height = 256), 'named resource bitmap');
      Image.LoadFromFile('C:\BITS1.BMP');
      Check((Image.Canvas.Pixels[0, 0] = clBlack) and (Image.Canvas.Pixels[1, 0] = clWhite) and
        (Image.Canvas.Pixels[0, 1] = clWhite) and (Image.Canvas.Pixels[1, 1] = clBlack),
        '1-bit scan lines padding and orientation');
      Image.LoadFromFile('C:\BITS24.BMP');
      Check((Image.Canvas.Pixels[0, 0] = clRed) and (Image.Canvas.Pixels[1, 0] = clLime) and
        (Image.Canvas.Pixels[0, 1] = clBlue) and (Image.Canvas.Pixels[1, 1] = clWhite),
        '24-bit BGR scan lines padding and orientation');
      Image.LoadFromFile('C:\BITS8.BMP');
      Check((Image.Width = 256) and (Image.Height = 300) and
        (Image.Canvas.Pixels[0, 0] = clRed) and (Image.Canvas.Pixels[255, 0] = clLime) and
        (Image.Canvas.Pixels[0, 299] = clBlue) and (Image.Canvas.Pixels[255, 299] = clBlack) and
        (Image.Canvas.Pixels[0, 149] = clRed) and (Image.Canvas.Pixels[0, 150] = clBlue),
        '8-bit pixels across 64 KiB boundary and both image halves');
      Image.LoadFromFile('C:\LARGE.BMP');
      Check((Image.Width = 320) and (Image.Height = 400), 'BMP larger than 64 KiB loads by scan line');
      Image.Clear;
      Check((Image.Handle = 0) and (Image.Canvas.Handle = 0) and (Image.Width = 0),
        'clear releases bitmap and detaches canvas');
      Rejected := False;
      try Image.DrawTo(MemoryDC, 0, 0); except on EGDIError do Rejected := True; end;
      Check(Rejected, 'drawing empty bitmap rejected');
      CheckBitmapEditing;
      CheckGraphicsDrawing;
      CheckSelectedObjects;
      BeforeResources := GetFreeSystemResources(GFSR_GDIRESOURCES);
      for I := 1 to 300 do
      begin
        CopyCanvas.Font.Height := -10 - (I mod 3);
        CopyCanvas.Font.Style := [];
        CopyCanvas.Brush.Style := TBrushStyle(I mod 8);
        CopyCanvas.Brush.Color := I mod 2 * clRed;
        CopyCanvas.Pen.Style := TPenStyle(I mod 7);
        CopyCanvas.Rectangle(70, 10, 100, 30);
        CopyCanvas.TextOut(2, 70, 'Test');
        if I mod 2 = 0 then Image.LoadFromFile('C:\PROBE.BMP')
        else Image.LoadFromResource(HInstance, PChar(101));
        Image.DrawTo(MemoryDC, 100, 75);
        ResourceImage.Assign(Image);
        ResourceImage.SetSize(18, 18);
        ResourceImage.SetSize(8, 8);
      end;
      Image.Free; Image := nil; ResourceImage.Free; ResourceImage := nil;
      CopyCanvas.Free; CopyCanvas := nil;
      Canvas.Free; Canvas := nil;
      AfterResources := GetFreeSystemResources(GFSR_GDIRESOURCES);
      Check(AfterResources >= BeforeResources - 2, 'repeated invalidation does not drain GDI pool');
      CheckSelectedObjects;
    except on E: Exception do begin LogLine('FAIL exception ' + E.Message); Failed := True; end; end;
  begin
    Image.Free; ResourceImage.Free; CopyCanvas.Free; Canvas.Free;
    if MemoryDC <> 0 then
    begin
      if SentinelPen <> 0 then begin SelectObject(MemoryDC, OldPen); DeleteObject(SentinelPen); end;
      if SentinelBrush <> 0 then begin SelectObject(MemoryDC, OldBrush); DeleteObject(SentinelBrush); end;
      if SentinelFont <> 0 then begin SelectObject(MemoryDC, OldFont); DeleteObject(SentinelFont); end;
      if Bitmap <> 0 then SelectObject(MemoryDC, OldBitmap);
      DeleteDC(MemoryDC);
    end;
    if Bitmap <> 0 then DeleteObject(Bitmap);
    if ScreenDC <> 0 then ReleaseDC(0, ScreenDC);
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
  if Failed then Halt(1);
end.
