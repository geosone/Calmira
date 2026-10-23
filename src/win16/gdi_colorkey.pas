{ SPDX-License-Identifier: GPL-2.0-or-later
  Win16 color-key compositing; no Win32 TransparentBlt/alpha API dependency. }
unit gdi_colorkey;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This color-key adapter requires Win16}{$ENDIF}
interface
uses WinTypes;
{ BackgroundBrush=0 preserves destination pixels; otherwise keys are replaced
  with this borrowed brush. Source and destination may overlap. }
procedure ColorKeyCopy(Destination: HDC; const Target: TRect; Source: HDC;
  const SourceRect: TRect; KeyColor: LongInt; BackgroundBrush: HBRUSH);
implementation
uses WinProcs, gdi_canvas;
type
  TScratch = record DC: HDC; Bitmap, Previous: HBITMAP; end;
procedure FreeScratch(var Surface: TScratch);
begin
  if (Surface.DC <> 0) and (Surface.Previous <> 0) then
    SelectObject(Surface.DC, Surface.Previous);
  if Surface.DC <> 0 then DeleteDC(Surface.DC);
  if Surface.Bitmap <> 0 then DeleteObject(Surface.Bitmap);
  FillChar(Surface, SizeOf(Surface), 0);
end;
procedure MakeScratch(var Surface: TScratch; Reference: HDC;
  Width, Height: SmallInt; Monochrome: Boolean);
begin
  Surface.DC := CreateCompatibleDC(Reference);
  if Surface.DC = 0 then raise EGDIError.Create('Cannot create compositing DC');
  if Monochrome then Surface.Bitmap := CreateBitmap(Width, Height, 1, 1, nil)
  else Surface.Bitmap := CreateCompatibleBitmap(Reference, Width, Height);
  if Surface.Bitmap = 0 then raise EGDIError.Create('Cannot create compositing bitmap');
  Surface.Previous := SelectObject(Surface.DC, Surface.Bitmap);
  if Surface.Previous = 0 then raise EGDIError.Create('Cannot select compositing bitmap');
end;
procedure RequireCopy(Okay: Boolean);
begin if not Okay then raise EGDIError.Create('Cannot composite color-key bitmap'); end;
procedure ColorKeyCopy(Destination: HDC; const Target: TRect; Source: HDC;
  const SourceRect: TRect; KeyColor: LongInt; BackgroundBrush: HBRUSH);
var Image, Mask, Output: TScratch; DW, DH, SW, SH: LongInt;
  State: SmallInt; Area: TRect; Origin: LongInt; KeyBrush: HBRUSH;
begin
  if (Destination = 0) or (Source = 0) then raise EGDIError.Create('Missing compositing DC');
  DW := LongInt(Target.Right) - Target.Left; DH := LongInt(Target.Bottom) - Target.Top;
  SW := LongInt(SourceRect.Right) - SourceRect.Left; SH := LongInt(SourceRect.Bottom) - SourceRect.Top;
  if (DW < 0) or (DH < 0) or (SW < 0) or (SH < 0) or
    (DW > 32767) or (DH > 32767) or (SW > 32767) or (SH > 32767) then
    raise EGDIError.Create('Unsupported color-key rectangle');
  if (DW = 0) or (DH = 0) or (SW = 0) or (SH = 0) then Exit;
  FillChar(Image, SizeOf(Image), 0); FillChar(Mask, SizeOf(Mask), 0);
  FillChar(Output, SizeOf(Output), 0);
  KeyBrush := 0;
  State := SaveDC(Destination);
  if State = 0 then raise EGDIError.Create('Cannot save compositing DC');
  try
    MakeScratch(Image, Destination, DW, DH, False);
    MakeScratch(Mask, Destination, DW, DH, True);
    MakeScratch(Output, Destination, DW, DH, False);
    Area.Left := 0; Area.Top := 0; Area.Right := DW; Area.Bottom := DH;
    { A clipped source read must leave key pixels, never uninitialized bits. }
    KeyBrush := CreateSolidBrush(KeyColor);
    if KeyBrush = 0 then raise EGDIError.Create('Cannot initialize color-key background');
    RequireCopy(WinProcs.FillRect(Image.DC, @Area, KeyBrush) <> 0);
    { Capture both inputs before any output: overlapping copies are safe. }
    RequireCopy(SetStretchBltMode(Image.DC, COLORONCOLOR) <> 0);
    RequireCopy(StretchBlt(Image.DC, 0, 0, DW, DH, Source,
      SourceRect.Left, SourceRect.Top, SW, SH, SRCCOPY));
    RequireCopy(BitBlt(Output.DC, 0, 0, DW, DH, Destination, Target.Left, Target.Top, SRCCOPY));
    if BackgroundBrush <> 0 then
    begin
      SetBkColor(Output.DC, GetBkColor(Destination)); SetBkMode(Output.DC, GetBkMode(Destination));
      Origin := GetBrushOrg(Destination);
      SetBrushOrg(Output.DC, SmallInt(LongInt(SmallInt(LoWord(Origin))) - Target.Left),
        SmallInt(LongInt(SmallInt(HiWord(Origin))) - Target.Top));
      RequireCopy(WinProcs.FillRect(Output.DC, @Area, BackgroundBrush) <> 0);
    end;
    { Color -> mono: key pixels become 1. Color expansion below is explicit,
      independent of the caller's text/background colors and raster mode. }
    SetBkColor(Image.DC, KeyColor);
    RequireCopy(BitBlt(Mask.DC, 0, 0, DW, DH, Image.DC, 0, 0, SRCCOPY));
    SetTextColor(Image.DC, $FFFFFF); SetBkColor(Image.DC, 0);
    RequireCopy(BitBlt(Image.DC, 0, 0, DW, DH, Mask.DC, 0, 0, SRCAND));
    SetTextColor(Output.DC, 0); SetBkColor(Output.DC, $FFFFFF);
    RequireCopy(BitBlt(Output.DC, 0, 0, DW, DH, Mask.DC, 0, 0, SRCAND));
    RequireCopy(BitBlt(Output.DC, 0, 0, DW, DH, Image.DC, 0, 0, SRCPAINT));
    RequireCopy(BitBlt(Destination, Target.Left, Target.Top, DW, DH, Output.DC, 0, 0, SRCCOPY));
  finally
    FreeScratch(Output); FreeScratch(Mask); FreeScratch(Image);
    if KeyBrush <> 0 then DeleteObject(KeyBrush);
    if not RestoreDC(Destination, State) then raise EGDIError.Create('Cannot restore compositing DC');
  end;
end;
end.
