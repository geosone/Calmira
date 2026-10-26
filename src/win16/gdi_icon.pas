{ SPDX-License-Identifier: GPL-2.0-or-later }
unit gdi_icon;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This icon adapter requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, gdi_canvas;
type
  TGDIIcon = class(TGDIGraphic)
  private
    FHandle: HICON;
  protected
    function GetWidth: SmallInt; override;
    function GetHeight: SmallInt; override;
    function GetEmpty: Boolean; override;
  public
    destructor Destroy; override;
    procedure Clear;
    procedure TakeHandle(Value: HICON);
    function ReleaseHandle: HICON;
    procedure Assign(Source: TPersistent); override;
    procedure CopyFromHandle(Value: HICON);
    procedure LoadFromResource(Instance: HINST; Name: PChar);
    { Reads one .ICO file image list and uses its first image. }
    procedure LoadFromStream(Stream: TStream);
    { Writes a 16-colour .ICO image of the system icon size. }
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);
    procedure DrawTo(Destination: HDC; X, Y: SmallInt); override;
    property Handle: HICON read FHandle write TakeHandle;
  end;
implementation
uses SysUtils, WinProcs, Win31, ShellAPI;
type
  TIconDirEntry = packed record
    Width, Height, ColorCount, Reserved: Byte;
    Planes, BitCount: Word;
    BytesInRes, ImageOffset: LongInt;
  end;
  TIconDir = packed record
    Reserved, ResType, Count: Word;
  end;
  { A 4-bit DIB header with its 16-colour table. }
  TIconInfoHeader = packed record
    Header: TBitmapInfoHeader;
    Colors: array[0..15] of LongInt;
  end;
function TGDIIcon.GetWidth: SmallInt;
begin if FHandle = 0 then Result := 0 else Result := GetSystemMetrics(SM_CXICON); end;
function TGDIIcon.GetHeight: SmallInt;
begin if FHandle = 0 then Result := 0 else Result := GetSystemMetrics(SM_CYICON); end;
function TGDIIcon.GetEmpty: Boolean;
begin Result := FHandle = 0; end;
procedure TGDIIcon.Clear;
begin
  if FHandle = 0 then Exit;
  DestroyIcon(FHandle);
  FHandle := 0;
  Changed;
end;
destructor TGDIIcon.Destroy;
begin OnChange := nil; Clear; inherited Destroy; end;
procedure TGDIIcon.TakeHandle(Value: HICON);
var Probe: HICON;
begin
  if Value = 0 then begin Clear; Exit; end;
  if Value = 1 then raise EGDIError.Create('ExtractIcon error value is not an icon');
  if Value = FHandle then Exit;
  { Requires a private, caller-owned icon, not a shared LoadIcon resource.
    Validate by making/releasing a temporary copy before committing. }
  Probe := CopyIcon(HInstance, Value);
  if Probe = 0 then raise EGDIError.Create('Cannot validate icon handle');
  DestroyIcon(Probe);
  if FHandle <> 0 then DestroyIcon(FHandle);
  FHandle := Value; Changed;
end;
function TGDIIcon.ReleaseHandle: HICON;
begin
  Result := FHandle; FHandle := 0;
  if Result <> 0 then
    try Changed; except DestroyIcon(Result); raise; end;
end;
procedure TGDIIcon.CopyFromHandle(Value: HICON);
var NewHandle: HICON;
begin
  if Value = 0 then begin Clear; Exit; end;
  if Value = 1 then raise EGDIError.Create('ExtractIcon error value is not an icon');
  { LoadIcon resources are shared; CopyIcon creates our independently owned
    icon. Never destroy the caller's resource/extracted icon. }
  NewHandle := CopyIcon(HInstance, Value);
  if NewHandle = 0 then raise EGDIError.Create('Cannot copy icon');
  if FHandle <> 0 then DestroyIcon(FHandle);
  FHandle := NewHandle; Changed;
end;
procedure TGDIIcon.Assign(Source: TPersistent);
begin
  if Source = Self then Exit;
  if Source = nil then begin Clear; Exit; end;
  if Source is TGDIIcon then CopyFromHandle(TGDIIcon(Source).FHandle)
  else inherited Assign(Source);
end;
procedure TGDIIcon.LoadFromResource(Instance: HINST; Name: PChar);
var Value: HICON;
begin
  Value := LoadIcon(Instance, Name);
  if Value = 0 then raise EGDIError.Create('Cannot load icon resource');
  CopyFromHandle(Value);
end;
procedure TGDIIcon.LoadFromStream(Stream: TStream);
var Dir: TIconDir; Entry: TIconDirEntry; Data: PByteArray; Size, Last: LongInt; I: Integer;
  Name: array[0..143] of Char; Temp: TFileStream; Value: HICON;
begin
  Stream.ReadBuffer(Dir, SizeOf(Dir));
  if (Dir.Reserved <> 0) or (Dir.ResType <> 1) or (Dir.Count = 0) or (Dir.Count > 64) then
    raise EGDIError.Create('Invalid icon stream');
  { The images follow the directory; the furthest one ends the icon. }
  Size := SizeOf(Dir) + LongInt(Dir.Count) * SizeOf(Entry);
  Last := Size;
  Data := nil;
  for I := 1 to Dir.Count do
  begin
    Stream.ReadBuffer(Entry, SizeOf(Entry));
    if (Entry.ImageOffset < Size) or (Entry.BytesInRes <= 0) then raise EGDIError.Create('Invalid icon stream');
    if Entry.ImageOffset + Entry.BytesInRes > Last then Last := Entry.ImageOffset + Entry.BytesInRes;
  end;
  if Last > 60000 then raise EGDIError.Create('Icon stream too large');
  GetMem(Data, Last);
  try
    Stream.Seek(-Size, soFromCurrent);
    Stream.ReadBuffer(Data^, Last);
    { USER builds device icons from files: hand it a temporary .ICO file. }
    if GetTempFileName(#0, 'ico', 0, Name) = 0 then raise EGDIError.Create('Cannot name temporary icon');
    { The shell recognises icon files by their extension. }
    DeleteFile(StrPas(Name));
    StrPCopy(Name, ChangeFileExt(StrPas(Name), '.ICO'));
    Temp := TFileStream.Create(StrPas(Name), fmCreate);
    try Temp.WriteBuffer(Data^, Last); finally Temp.Free; end;
    try
      Value := ExtractIcon(HInstance, Name, 0);
    finally DeleteFile(StrPas(Name)); end;
    if Value <= 1 then raise EGDIError.Create('Cannot read icon image');
    TakeHandle(Value);
  finally FreeMem(Data, Last); end;
end;
procedure TGDIIcon.SaveToStream(Stream: TStream);
var Dir: TIconDir; Entry: TIconDirEntry; Info: ^TIconInfoHeader;
  OnWhite, OnBlack, Mask: PByteArray; Size, Rows, ColorBytes, MaskBytes, X, Y, I: Integer;
  Display, DC: HDC; Bitmap, Previous: HBITMAP; Pass: Integer; Nibble: Byte;
  function Pixel(Bits: PByteArray; X, Y: Integer): Byte;
  begin
    Result := Bits^[Y * ColorBytes + X div 2];
    if not Odd(X) then Result := Result shr 4 else Result := Result and $F;
  end;
begin
  if FHandle = 0 then raise EGDIError.Create('Cannot save an empty icon');
  Size := GetSystemMetrics(SM_CXICON); Rows := GetSystemMetrics(SM_CYICON);
  ColorBytes := ((Size * 4 + 31) div 32) * 4; MaskBytes := ((Size + 31) div 32) * 4;
  Info := nil; OnWhite := nil; OnBlack := nil; Mask := nil; DC := 0; Bitmap := 0; Display := 0;
  try
    New(Info);
    GetMem(OnWhite, ColorBytes * Rows); GetMem(OnBlack, ColorBytes * Rows); GetMem(Mask, MaskBytes * Rows);
    Display := GetDC(0);
    if Display = 0 then raise EGDIError.Create('Cannot acquire display DC');
    DC := CreateCompatibleDC(Display);
    Bitmap := CreateCompatibleBitmap(Display, Size, Rows);
    if (DC = 0) or (Bitmap = 0) then raise EGDIError.Create('Cannot create icon surface');
    { Over white and black, mask pixels differ and keep their XOR colour on
      black; opaque pixels are the same on both. }
    for Pass := 0 to 1 do
    begin
      Previous := SelectObject(DC, Bitmap);
      if Previous = 0 then raise EGDIError.Create('Cannot select icon surface');
      if Pass = 0 then PatBlt(DC, 0, 0, Size, Rows, WHITENESS) else PatBlt(DC, 0, 0, Size, Rows, BLACKNESS);
      WinProcs.DrawIcon(DC, 0, 0, FHandle);
      SelectObject(DC, Previous);
      FillChar(Info^, SizeOf(Info^), 0);
      Info^.Header.biSize := SizeOf(TBitmapInfoHeader);
      Info^.Header.biWidth := Size; Info^.Header.biHeight := Rows;
      Info^.Header.biPlanes := 1; Info^.Header.biBitCount := 4;
      if Pass = 0 then I := GetDIBits(Display, Bitmap, 0, Rows, OnWhite, PBitmapInfo(Info)^, DIB_RGB_COLORS)
      else I := GetDIBits(Display, Bitmap, 0, Rows, OnBlack, PBitmapInfo(Info)^, DIB_RGB_COLORS);
      if I <> Rows then raise EGDIError.Create('Cannot read icon pixels');
    end;
    FillChar(Mask^, MaskBytes * Rows, 0);
    for Y := 0 to Rows - 1 do
      for X := 0 to Size - 1 do
        if Pixel(OnWhite, X, Y) <> Pixel(OnBlack, X, Y) then
          Mask^[Y * MaskBytes + X div 8] := Mask^[Y * MaskBytes + X div 8] or ($80 shr (X mod 8));
    Dir.Reserved := 0; Dir.ResType := 1; Dir.Count := 1;
    Entry.Width := Size; Entry.Height := Rows; Entry.ColorCount := 16; Entry.Reserved := 0;
    Entry.Planes := 1; Entry.BitCount := 4;
    Entry.BytesInRes := SizeOf(TIconInfoHeader) + LongInt(ColorBytes + MaskBytes) * Rows;
    Entry.ImageOffset := SizeOf(Dir) + SizeOf(Entry);
    { An icon DIB header counts the XOR and AND rows together. }
    Info^.Header.biHeight := Rows * 2;
    Info^.Header.biSizeImage := LongInt(ColorBytes + MaskBytes) * Rows;
    Info^.Header.biClrUsed := 0; Info^.Header.biClrImportant := 0;
    Stream.WriteBuffer(Dir, SizeOf(Dir));
    Stream.WriteBuffer(Entry, SizeOf(Entry));
    Stream.WriteBuffer(Info^, SizeOf(TIconInfoHeader));
    Stream.WriteBuffer(OnBlack^, ColorBytes * Rows);
    Stream.WriteBuffer(Mask^, MaskBytes * Rows);
  finally
    if Bitmap <> 0 then DeleteObject(Bitmap);
    if DC <> 0 then DeleteDC(DC);
    if Display <> 0 then ReleaseDC(0, Display);
    if Mask <> nil then FreeMem(Mask, MaskBytes * Rows);
    if OnBlack <> nil then FreeMem(OnBlack, ColorBytes * Rows);
    if OnWhite <> nil then FreeMem(OnWhite, ColorBytes * Rows);
    if Info <> nil then Dispose(Info);
  end;
end;
procedure TGDIIcon.LoadFromFile(const FileName: string);
var Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try LoadFromStream(Stream); finally Stream.Free; end;
end;
procedure TGDIIcon.SaveToFile(const FileName: string);
var Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try SaveToStream(Stream); finally Stream.Free; end;
end;
procedure TGDIIcon.DrawTo(Destination: HDC; X, Y: SmallInt);
var State: SmallInt;
begin
  if (Destination = 0) or (FHandle = 0) then raise EGDIError.Create('Missing icon or destination DC');
  State := SaveDC(Destination);
  if State = 0 then raise EGDIError.Create('Cannot save icon DC');
  try
    if not WinProcs.DrawIcon(Destination, X, Y, FHandle) then raise EGDIError.Create('Cannot draw icon');
  finally
    if not RestoreDC(Destination, State) then raise EGDIError.Create('Cannot restore icon DC');
  end;
end;
end.
