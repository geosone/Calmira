{ SPDX-License-Identifier: GPL-2.0-or-later
  Owned native bitmap adapter, not the complete VCL TBitmap interface. }
unit gdi_bitmap;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This bitmap adapter requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, gdi_canvas;
type
  TGDIBitmap = class(TGDIGraphic)
  private
    FHandle: HBITMAP;
    FDC: HDC;
    FOldBitmap: HGDIOBJ;
    FWidth, FHeight: SmallInt;
    FCanvas: TGDICanvas;
    FTransparent: Boolean;
    FTransparentColor: TColor;
    procedure ReleaseBitmap;
    procedure AdoptBitmap(Value: HBITMAP; DeleteOnFailure: Boolean = True);
    procedure SetWidth(Value: SmallInt);
    procedure SetHeight(Value: SmallInt);
    procedure SetTransparent(Value: Boolean);
    procedure SetTransparentColor(Value: TColor);
    procedure CanvasChanged(Sender: TObject);
  protected
    function CreateCanvas: TGDICanvas; virtual;
    function GetWidth: SmallInt; override;
    function GetHeight: SmallInt; override;
    function GetEmpty: Boolean; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure TakeHandle(Value: HBITMAP);
    procedure CopyFromHandle(Value: HBITMAP);
    function ReleaseHandle: HBITMAP;
    procedure Assign(Source: TPersistent); override;
    procedure SetSize(NewWidth, NewHeight: SmallInt);
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromResource(Instance: HINST; Name: PChar);
    procedure DrawTo(Destination: HDC; X, Y: SmallInt); override;
    procedure StretchTo(Destination: HDC; const Area: TRect); override;
    property Handle: HBITMAP read FHandle write TakeHandle;
    property Width: SmallInt read FWidth write SetWidth;
    property Height: SmallInt read FHeight write SetHeight;
    property Canvas: TGDICanvas read FCanvas;
    property Transparent: Boolean read FTransparent write SetTransparent;
    property TransparentColor: TColor read FTransparentColor write SetTransparentColor;
  end;
implementation
uses WinProcs, bmp_reader, gdi_colorkey;

{ Make a complete, unselected replacement. White initialization is deliberate:
  growing an icon strip must not expose uninitialized display-memory pixels. }
function CopySurface(Width, Height: SmallInt; Source: HDC;
  CopyWidth, CopyHeight: SmallInt): HBITMAP;
var Display, Reference, TempDC: HDC; Value: HBITMAP;
  Previous: HGDIOBJ; Area: TRect;
begin
  Display := 0; TempDC := 0; Value := 0; Previous := 0;
  try
    Reference := Source;
    if Reference = 0 then
    begin
      Display := GetDC(0); Reference := Display;
      if Display = 0 then raise EGDIError.Create('Cannot acquire display DC');
    end;
    Value := CreateCompatibleBitmap(Reference, Width, Height);
    if Value = 0 then raise EGDIError.Create('Cannot allocate bitmap surface');
    TempDC := CreateCompatibleDC(Reference);
    if TempDC = 0 then raise EGDIError.Create('Cannot create surface DC');
    Previous := SelectObject(TempDC, Value);
    if Previous = 0 then raise EGDIError.Create('Cannot select surface');
    Area.Left := 0; Area.Top := 0; Area.Right := Width; Area.Bottom := Height;
    if WinProcs.FillRect(TempDC, @Area, GetStockObject(WHITE_BRUSH)) = 0 then
      raise EGDIError.Create('Cannot initialize bitmap surface');
    if (Source <> 0) and (CopyWidth > 0) and (CopyHeight > 0) then
      if not BitBlt(TempDC, 0, 0, CopyWidth, CopyHeight, Source, 0, 0, SRCCOPY) then
        raise EGDIError.Create('Cannot copy bitmap surface');
  except
    if (TempDC <> 0) and (Previous <> 0) then SelectObject(TempDC, Previous);
    if TempDC <> 0 then DeleteDC(TempDC);
    if Value <> 0 then DeleteObject(Value);
    if Display <> 0 then ReleaseDC(0, Display);
    raise;
  end;
  SelectObject(TempDC, Previous); DeleteDC(TempDC);
  if Display <> 0 then ReleaseDC(0, Display);
  Result := Value;
end;
constructor TGDIBitmap.Create;
begin
  inherited Create; FCanvas := CreateCanvas; FCanvas.OnChange := CanvasChanged;
  FTransparentColor := clWhite;
end;
function TGDIBitmap.GetWidth: SmallInt;
begin Result := FWidth; end;
function TGDIBitmap.GetHeight: SmallInt;
begin Result := FHeight; end;
function TGDIBitmap.GetEmpty: Boolean;
begin Result := FHandle = 0; end;
procedure TGDIBitmap.CanvasChanged(Sender: TObject);
begin Changed; end;
procedure TGDIBitmap.SetTransparent(Value: Boolean);
begin if FTransparent <> Value then begin FTransparent := Value; Changed; end; end;
procedure TGDIBitmap.SetTransparentColor(Value: TColor);
begin if FTransparentColor <> Value then begin FTransparentColor := Value; Changed; end; end;
function TGDIBitmap.CreateCanvas: TGDICanvas;
begin Result := TGDICanvas.Create; end;
procedure TGDIBitmap.ReleaseBitmap;
begin
  if FCanvas <> nil then FCanvas.Handle := 0;
  if FDC <> 0 then
  begin SelectObject(FDC, FOldBitmap); DeleteDC(FDC); end;
  if FHandle <> 0 then DeleteObject(FHandle);
  FDC := 0; FHandle := 0; FOldBitmap := 0; FWidth := 0; FHeight := 0;
end;
destructor TGDIBitmap.Destroy;
begin ReleaseBitmap; FCanvas.Free; inherited Destroy; end;
procedure TGDIBitmap.Clear;
begin
  if (FHandle = 0) and (FWidth = 0) and (FHeight = 0) then Exit;
  ReleaseBitmap; Changed;
end;
procedure TGDIBitmap.TakeHandle(Value: HBITMAP);
begin
  if Value = 0 then begin Clear; Exit; end;
  if Value = FHandle then Exit;
  { Caller transfers ownership only if the replacement succeeds. }
  AdoptBitmap(Value, False);
  Changed;
end;
function TGDIBitmap.ReleaseHandle: HBITMAP;
begin
  Result := FHandle;
  if (FHandle = 0) and (FWidth = 0) and (FHeight = 0) then Exit;
  if FDC <> 0 then
  begin
    if SelectObject(FDC, FOldBitmap) = 0 then
      raise EGDIError.Create('Cannot detach bitmap');
    if not DeleteDC(FDC) then
    begin
      SelectObject(FDC, FHandle);
      raise EGDIError.Create('Cannot release bitmap DC');
    end;
  end;
  FCanvas.Handle := 0; FDC := 0; FOldBitmap := 0; FHandle := 0;
  FWidth := 0; FHeight := 0;
  try Changed;
  except
    if Result <> 0 then DeleteObject(Result);
    raise;
  end;
end;
procedure TGDIBitmap.CopyFromHandle(Value: HBITMAP);
var Description: WinTypes.TBitmap; BorrowDC: HDC;
  Previous: HGDIOBJ; CopyHandle: HBITMAP;
begin
  if Value = 0 then begin Clear; Exit; end;
  if Value = FHandle then Exit;
  if (GetObject(Value, SizeOf(Description), @Description) <> SizeOf(Description)) or
    (Description.bmWidth <= 0) or (Description.bmHeight <= 0) then
    raise EGDIError.Create('Cannot query borrowed bitmap');
  BorrowDC := CreateCompatibleDC(0);
  if BorrowDC = 0 then raise EGDIError.Create('Cannot create borrowed bitmap DC');
  Previous := 0;
  try
    Previous := SelectObject(BorrowDC, Value);
    if Previous = 0 then raise EGDIError.Create('Borrowed bitmap must be unselected');
    CopyHandle := CopySurface(Description.bmWidth, Description.bmHeight,
      BorrowDC, Description.bmWidth, Description.bmHeight);
  finally
    if Previous <> 0 then SelectObject(BorrowDC, Previous);
    DeleteDC(BorrowDC);
  end;
  AdoptBitmap(CopyHandle);
  Changed;
end;
procedure TGDIBitmap.SetWidth(Value: SmallInt);
begin SetSize(Value, FHeight); end;
procedure TGDIBitmap.SetHeight(Value: SmallInt);
begin SetSize(FWidth, Value); end;
procedure TGDIBitmap.SetSize(NewWidth, NewHeight: SmallInt);
var CopyWidth, CopyHeight: SmallInt;
begin
  if (NewWidth < 0) or (NewHeight < 0) then
    raise EGDIError.Create('Bitmap dimensions must not be negative');
  if (NewWidth = FWidth) and (NewHeight = FHeight) then Exit;
  { Allow Width := N; Height := M on an initially empty bitmap. }
  if (NewWidth = 0) or (NewHeight = 0) then
  begin ReleaseBitmap; FWidth := NewWidth; FHeight := NewHeight; Changed; Exit; end;
  CopyWidth := FWidth; if CopyWidth > NewWidth then CopyWidth := NewWidth;
  CopyHeight := FHeight; if CopyHeight > NewHeight then CopyHeight := NewHeight;
  AdoptBitmap(CopySurface(NewWidth, NewHeight, FDC, CopyWidth, CopyHeight));
  Changed;
end;
procedure TGDIBitmap.Assign(Source: TPersistent);
var Bitmap: TGDIBitmap;
begin
  if Source = Self then Exit;
  if Source = nil then begin Clear; Exit; end;
  if not (Source is TGDIBitmap) then begin inherited Assign(Source); Exit; end;
  Bitmap := TGDIBitmap(Source);
  if Bitmap.FHandle = 0 then
  begin ReleaseBitmap; FWidth := Bitmap.FWidth; FHeight := Bitmap.FHeight; end
  else AdoptBitmap(CopySurface(Bitmap.FWidth, Bitmap.FHeight, Bitmap.FDC,
    Bitmap.FWidth, Bitmap.FHeight));
  FTransparent := Bitmap.FTransparent; FTransparentColor := Bitmap.FTransparentColor;
  Changed;
end;
procedure TGDIBitmap.AdoptBitmap(Value: HBITMAP; DeleteOnFailure: Boolean);
var Description: WinTypes.TBitmap; NewDC: HDC; Previous: HGDIOBJ;
begin
  { Internal loaders own their result even on failure. Public TakeHandle
    instead leaves failed inputs with the caller. Prepare the replacement before
    releasing the old image. Never select a bitmap into two DCs. }
  NewDC := 0;
  try
    if (Value = 0) or (GetObject(Value, SizeOf(Description), @Description) <> SizeOf(Description)) then
      raise EGDIError.Create('Cannot query bitmap');
    if (Description.bmWidth <= 0) or (Description.bmHeight <= 0) then
      raise EGDIError.Create('Invalid bitmap dimensions');
    NewDC := CreateCompatibleDC(0);
    if NewDC = 0 then raise EGDIError.Create('Cannot create bitmap DC');
    Previous := SelectObject(NewDC, Value);
    if Previous = 0 then raise EGDIError.Create('Cannot select bitmap');
  except
    if NewDC <> 0 then DeleteDC(NewDC);
    if DeleteOnFailure and (Value <> 0) then DeleteObject(Value);
    raise;
  end;
  ReleaseBitmap;
  FHandle := Value; FDC := NewDC; FOldBitmap := Previous;
  FWidth := Description.bmWidth; FHeight := Description.bmHeight;
  FCanvas.Handle := FDC;
end;
procedure TGDIBitmap.LoadFromResource(Instance: HINST; Name: PChar);
var Value: HBITMAP;
begin
  Value := LoadBitmap(Instance, Name);
  if Value = 0 then raise EGDIError.Create('Cannot load bitmap resource');
  AdoptBitmap(Value);
  Changed;
end;
procedure TGDIBitmap.LoadFromFile(const FileName: string);
var Stream: TFileStream; Header: array[0..53] of Byte;
  Info: array[0..1063] of Byte; Layout: TBMPLayout; ErrorText: string;
  Row: Pointer; Display: HDC; Value: HBITMAP; Y: Word;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  Row := nil; Display := 0; Value := 0;
  try
    if Stream.Size < SizeOf(Header) then raise EGDIError.Create('Truncated BMP header');
    Stream.ReadBuffer(Header, SizeOf(Header));
    if not ReadBMPLayout(Header, SizeOf(Header), Stream.Size, Layout, ErrorText) then
      raise EGDIError.Create(ErrorText);
    Move(Header[14], Info[0], 40);
    Stream.ReadBuffer(Info[40], Layout.PaletteBytes);
    GetMem(Row, Layout.RowBytes);
    Display := GetDC(0);
    if Display = 0 then raise EGDIError.Create('Cannot acquire display DC');
    Value := CreateDIBitmap(Display, LPBITMAPINFOHEADER(@Info), 0,
      nil, LPBITMAPINFO(@Info), DIB_RGB_COLORS);
    if Value = 0 then raise EGDIError.Create('Cannot create BMP image');
    Stream.Position := Layout.BitsOffset;
    for Y := 0 to Layout.Height - 1 do
    begin
      Stream.ReadBuffer(Row^, Layout.RowBytes);
      if SetDIBits(Display, Value, Y, 1, Row, LPBITMAPINFO(@Info), DIB_RGB_COLORS) <> 1 then
        raise EGDIError.Create('Cannot transfer BMP scan line');
    end;
  except
    if Value <> 0 then DeleteObject(Value);
    if Display <> 0 then ReleaseDC(0, Display);
    if Row <> nil then FreeMem(Row);
    Stream.Free;
    raise;
  end;
  ReleaseDC(0, Display); FreeMem(Row); Stream.Free;
  AdoptBitmap(Value);
  Changed;
end;
procedure TGDIBitmap.DrawTo(Destination: HDC; X, Y: SmallInt);
var Target, Source: TRect;
begin
  if (Destination = 0) or (FHandle = 0) then raise EGDIError.Create('Missing bitmap or destination DC');
  if FTransparent then
  begin
    if (LongInt(X) + FWidth > 32767) or (LongInt(Y) + FHeight > 32767) then
      raise EGDIError.Create('Bitmap destination exceeds Win16 coordinates');
    Target.Left := X; Target.Top := Y; Target.Right := X + FWidth; Target.Bottom := Y + FHeight;
    Source.Left := 0; Source.Top := 0; Source.Right := FWidth; Source.Bottom := FHeight;
    ColorKeyCopy(Destination, Target, FDC, Source, ColorToRGB(FTransparentColor), 0);
    Exit;
  end;
  if not BitBlt(Destination, X, Y, FWidth, FHeight, FDC, 0, 0, SRCCOPY) then
    raise EGDIError.Create('Cannot draw bitmap');
end;
procedure TGDIBitmap.StretchTo(Destination: HDC; const Area: TRect);
var W, H: LongInt; State: SmallInt; Source: TRect; Snapshot: TGDIBitmap;
begin
  if (Destination = 0) or (FHandle = 0) then
    raise EGDIError.Create('Missing bitmap or destination DC');
  W := LongInt(Area.Right) - Area.Left; H := LongInt(Area.Bottom) - Area.Top;
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then
    raise EGDIError.Create('Invalid stretch destination size');
  if (W = 0) or (H = 0) then Exit;
  Source.Left := 0; Source.Top := 0; Source.Right := FWidth; Source.Bottom := FHeight;
  if FTransparent then
  begin
    { ColorKeyCopy captures both source and background before writing the target. }
    ColorKeyCopy(Destination, Area, FDC, Source, ColorToRGB(FTransparentColor), 0);
    Exit;
  end;
  if Destination = FDC then
  begin
    { StretchBlt cannot safely read overlapping pixels as it replaces them. }
    Snapshot := TGDIBitmap.Create;
    try Snapshot.Assign(Self); Snapshot.StretchTo(Destination, Area);
    finally Snapshot.Free; end;
    Exit;
  end;
  State := SaveDC(Destination);
  if State = 0 then raise EGDIError.Create('Cannot save stretch DC');
  try
    if SetStretchBltMode(Destination, COLORONCOLOR) = 0 then
      raise EGDIError.Create('Cannot set bitmap stretch mode');
    if not StretchBlt(Destination, Area.Left, Area.Top, W, H,
      FDC, 0, 0, FWidth, FHeight, SRCCOPY) then
      raise EGDIError.Create('Cannot scale bitmap');
  finally RestoreDC(Destination, State); end;
end;
end.
