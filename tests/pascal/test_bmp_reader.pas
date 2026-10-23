program TestBMPReader;
{$mode delphi}{$H-}
uses Classes, SysUtils, bmp_reader;
var Header: array[0..53] of Byte; Layout: TBMPLayout; ErrorText: string;
  Checks, I: Integer; Stream: TFileStream;
procedure Check(Condition: Boolean; const Description: string);
begin
  Inc(Checks);
  if not Condition then begin WriteLn('FAIL ', Description); Halt(1); end;
end;
procedure Put32(Offset: Word; Value: LongInt);
var J: Word;
begin for J := 0 to 3 do Header[Offset + J] := (Value shr (8 * J)) and $FF; end;
procedure Base(Depth: Byte);
var Palette: LongInt;
begin
  FillChar(Header, SizeOf(Header), 0);
  Header[0] := $42; Header[1] := $4D;
  Put32(14, 40); Put32(18, 3); Put32(22, 2);
  Header[26] := 1; Header[28] := Depth;
  Palette := 0; if Depth <= 8 then Palette := (LongInt(1) shl Depth) * 4;
  Put32(10, 54 + Palette);
  Put32(2, 54 + Palette + ((3 * Depth + 31) div 32) * 4 * 2);
end;
function Valid(Size: LongInt = -1; Count: Word = 54): Boolean;
begin
  if Size = -1 then Size := LongInt(Header[2]) or (LongInt(Header[3]) shl 8);
  Result := ReadBMPLayout(Header, Count, Size, Layout, ErrorText);
end;
procedure Reject(const Description: string);
begin
  Check(not Valid, Description);
  Check((Layout.Width = 0) and (ErrorText <> ''), 'failure clears result and explains reason');
end;
begin
  for I := 0 to 53 do begin Base(4); Check(not Valid(-1, I), 'short header'); end;
  Base(1); Check(Valid and (Layout.RowBytes = 4) and (Layout.PaletteBytes = 8), '1-bit padding');
  Base(4); Check(Valid and (Layout.RowBytes = 4) and (Layout.ImageBytes = 8), '4-bit padding');
  Base(8); Check(Valid and (Layout.PaletteBytes = 1024), '8-bit palette');
  Base(24); Check(Valid and (Layout.RowBytes = 12) and (Layout.PaletteBytes = 0), '24-bit padding');
  Base(4); Header[0] := 0; Reject('signature');
  Base(4); Put32(14, 108); Reject('extended DIB header');
  Base(4); Header[26] := 2; Reject('planes');
  Base(4); Header[28] := 32; Reject('unsupported depth');
  Base(4); Put32(30, 2); Reject('RLE');
  Base(4); Put32(18, 0); Reject('zero width');
  Base(4); Put32(18, $7FFFFFFF); Reject('overflow width');
  Base(4); Put32(22, -2); Reject('top-down bitmap');
  Base(4); Put32(22, 32768); Reject('height overflow');
  Base(24); Put32(18, 32767); Reject('scan line exceeds segment budget');
  Base(4); Put32(46, 17); Reject('excess palette');
  Base(4); Put32(46, 2); Reject('reduced palette unsupported');
  Base(4); Put32(50, 17); Reject('invalid important color count');
  Base(4); Put32(10, 54); Reject('pixels overlap palette');
  Base(4); Put32(10, $7FFFFFFF); Reject('offset past file');
  Base(4); Put32(10, -1); Reject('unsigned offset overflow');
  Base(4); Check(not Valid(125), 'truncated pixels');
  Base(4); Put32(34, 7); Reject('wrong declared image size');
  Base(4); Put32(34, 8); Check(Valid, 'explicit image size');
  Base(8); Put32(18, 640); Put32(22, 200); Put32(2, 129078);
  Check(Valid(129078) and (Layout.ImageBytes = 128000), 'image larger than one segment');
  Base(8); Put32(18, 32767); Put32(22, 32767); Put32(2, 1073710134);
  Check(Valid(1073710134) and (Layout.ImageBytes = 1073709056), 'large arithmetic remains bounded');
  for I := 1 to ParamCount do
  begin
    Stream := TFileStream.Create(ParamStr(I), fmOpenRead);
    try
      Stream.ReadBuffer(Header, SizeOf(Header));
      Check(ReadBMPLayout(Header, SizeOf(Header), Stream.Size, Layout, ErrorText), ParamStr(I) + ': ' + ErrorText);
    finally Stream.Free; end;
  end;
  WriteLn('PASS ', Checks, ' BMP checks');
end.
