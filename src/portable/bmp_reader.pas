{ SPDX-License-Identifier: GPL-2.0-or-later }
unit bmp_reader;
{$mode delphi}{$H-}
interface
type
  TBMPLayout = record
    Width, Height: SmallInt;
    BitsPerPixel: Word;
    PaletteBytes: Word;
    BitsOffset, RowBytes, ImageBytes: LongInt;
  end;
{ Header must contain at least the first 54 bytes. No native record casts:
  the disk layout is little endian and independent of compiler alignment. }
function ReadBMPLayout(const Header; HeaderBytes: Word; FileBytes: LongInt;
  out Layout: TBMPLayout; out ErrorText: string): Boolean;
implementation
type THeaderBytes = array[0..53] of Byte;
function ReadBMPLayout(const Header; HeaderBytes: Word; FileBytes: LongInt;
  out Layout: TBMPLayout; out ErrorText: string): Boolean;
var B: THeaderBytes absolute Header;
  W, H, Colors, DeclaredSize, Offset, ImageSize, Stride: LongInt;
  Depth: Word;
  function U16(Index: Word): Word;
  begin Result := Word(B[Index]) or (Word(B[Index + 1]) shl 8); end;
  function I32(Index: Word): LongInt;
  begin Result := LongInt(B[Index]) or (LongInt(B[Index + 1]) shl 8) or
    (LongInt(B[Index + 2]) shl 16) or (LongInt(B[Index + 3]) shl 24); end;
begin
  Result := False; FillChar(Layout, SizeOf(Layout), 0);
  ErrorText := 'Truncated BMP header';
  if (HeaderBytes < 54) or (FileBytes < 54) then Exit;
  ErrorText := 'Unsupported BMP format';
  if (U16(0) <> $4D42) or (I32(14) <> 40) or (U16(26) <> 1) or
    (I32(30) <> 0) then Exit;
  Depth := U16(28);
  if not (Depth in [1, 4, 8, 24]) then Exit;
  W := I32(18); H := I32(22);
  ErrorText := 'Unsupported BMP dimensions';
  if (W <= 0) or (W > 32767) or (H <= 0) or (H > 32767) then Exit;
  Stride := ((W * Depth + 31) div 32) * 4;
  if Stride > 60000 then Exit; { one scan line must fit a Win16 segment }
  ImageSize := Stride * H; { bounded above by 60000 * 32767 }
  Colors := 0;
  if Depth <= 8 then Colors := LongInt(1) shl Depth;
  ErrorText := 'Unsupported BMP palette';
  if (I32(46) <> 0) and (I32(46) <> Colors) then Exit;
  if (I32(50) < 0) or (I32(50) > Colors) then Exit;
  Offset := I32(10); DeclaredSize := I32(2);
  ErrorText := 'Invalid BMP length or pixel offset';
  if (Offset < 54 + Colors * 4) or (Offset > FileBytes) or
    (DeclaredSize <> FileBytes) then Exit;
  if ImageSize > FileBytes - Offset then Exit;
  if (I32(34) <> 0) and (I32(34) <> ImageSize) then Exit;
  Layout.Width := W; Layout.Height := H; Layout.BitsPerPixel := Depth;
  Layout.PaletteBytes := Colors * 4; Layout.BitsOffset := Offset;
  Layout.RowBytes := Stride; Layout.ImageBytes := ImageSize;
  ErrorText := ''; Result := True;
end;
end.
