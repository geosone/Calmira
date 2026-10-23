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
    procedure DrawTo(Destination: HDC; X, Y: SmallInt); override;
    property Handle: HICON read FHandle write TakeHandle;
  end;
implementation
uses WinProcs, Win31;
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
