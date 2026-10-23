{ SPDX-License-Identifier: GPL-2.0-or-later
  Scoped native window painting, not the VCL TCustomControl interface. }
unit native_paint;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This painting adapter requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, native_window;
type
  { Draws on the window through GetDC when used outside painting. }
  TWindowCanvas = class(TCanvas)
  private
    FOwner: TNativeWindow;
    FWindow: HWND;
  protected
    function AcquireContext: HDC; override;
    procedure ReleaseContext(Context: HDC); override;
  public
    constructor Create(Owner: TNativeWindow);
  end;
  TNativePaintWindow = class(TNativeWindow)
  private
    FCanvas: TCanvas;
    FPainting: Boolean;
    FPaintRect: TRect;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMEraseBackground(var Message: TMessage); message WM_ERASEBKGND;
  protected
    procedure Paint; virtual;
    procedure PaintOverlay; virtual;
    procedure ColorChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Invalidate; virtual;
    procedure InvalidateArea(const Area: TRect);
    procedure Repaint;
    procedure DrawNow(Painter: TNotifyEvent);
    property Canvas: TCanvas read FCanvas;
    property Painting: Boolean read FPainting;
    property PaintRect: TRect read FPaintRect;
  end;
implementation
uses WinProcs;

constructor TNativePaintWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCanvas := TWindowCanvas.Create(Self);
end;
destructor TNativePaintWindow.Destroy;
begin
  try inherited Destroy; finally FCanvas.Free; end;
end;
constructor TWindowCanvas.Create(Owner: TNativeWindow);
begin inherited Create; FOwner := Owner; end;
function TWindowCanvas.AcquireContext: HDC;
begin
  Result := 0; FWindow := FOwner.Handle;
  if FWindow = 0 then Exit;
  Result := GetDC(FWindow);
  if Result = 0 then FWindow := 0;
end;
procedure TWindowCanvas.ReleaseContext(Context: HDC);
begin ReleaseDC(FWindow, Context); FWindow := 0; end;
procedure TNativePaintWindow.ColorChanged;
begin if Handle <> 0 then Invalidate; end;
procedure TNativePaintWindow.Paint;
begin end;
procedure TNativePaintWindow.PaintOverlay;
begin end;
procedure TNativePaintWindow.WMEraseBackground(var Message: TMessage);
begin
  { The paint transaction fills its clipped update area before virtual Paint. }
  Message.Result := 1;
end;
procedure TNativePaintWindow.WMPaint(var Message: TWMPaint);
var Window: HWND; DC, PreviousDC: HDC; PS: TPaintStruct; State: SmallInt; Background: HBRUSH;
begin
  Message.Result := 0;
  if FPainting then Exit;
  Window := Handle; PreviousDC := FCanvas.Handle; FPainting := True;
  try
    FillChar(PS, SizeOf(PS), 0);
    DC := BeginPaint(Window, PS);
    if DC = 0 then raise ENativeWindowError.Create('Cannot begin native paint');
    try
      FPaintRect := PS.rcPaint;
      if (FPaintRect.Right <= FPaintRect.Left) or
        (FPaintRect.Bottom <= FPaintRect.Top) then Exit;
      State := SaveDC(DC);
      if State = 0 then raise ENativeWindowError.Create('Cannot save native paint DC');
      try
        FCanvas.Handle := DC;
        Background := CreateSolidBrush(ColorToRGB(Color));
        if Background = 0 then raise ENativeWindowError.Create('Cannot create paint background');
        try
          if WinProcs.FillRect(DC, FPaintRect, Background) = 0 then
            raise ENativeWindowError.Create('Cannot fill paint background');
        finally DeleteObject(Background); end;
        Paint;
        PaintOverlay;
      finally
        FCanvas.Handle := PreviousDC;
        RestoreDC(DC, State);
      end;
    finally EndPaint(Window, PS); end;
  finally
    FPainting := False;
    FillChar(FPaintRect, SizeOf(FPaintRect), 0);
  end;
end;
procedure TNativePaintWindow.Invalidate;
begin
  if Handle = 0 then raise ENativeWindowError.Create('Missing native window');
  InvalidateRect(Handle, nil, False);
end;
procedure TNativePaintWindow.InvalidateArea(const Area: TRect);
var W, H: LongInt;
begin
  if Handle = 0 then raise ENativeWindowError.Create('Missing native window');
  W := LongInt(Area.Right) - Area.Left; H := LongInt(Area.Bottom) - Area.Top;
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then
    raise ENativeWindowError.Create('Invalid native update area');
  if (W = 0) or (H = 0) then Exit;
  InvalidateRect(Handle, @Area, False);
end;
procedure TNativePaintWindow.Repaint;
begin Invalidate; UpdateWindow(Handle); end;
procedure TNativePaintWindow.DrawNow(Painter: TNotifyEvent);
var Window: HWND; DC, PreviousDC: HDC; State: SmallInt; Acquired: Boolean;
begin
  if not Assigned(Painter) then raise ENativeWindowError.Create('Missing drawing callback');
  Window := Handle;
  if Window = 0 then raise ENativeWindowError.Create('Missing native window');
  PreviousDC := FCanvas.Handle; DC := PreviousDC; Acquired := DC = 0;
  if Acquired then DC := GetDC(Window);
  if DC = 0 then raise ENativeWindowError.Create('Cannot acquire native drawing DC');
  try
    State := SaveDC(DC);
    if State = 0 then raise ENativeWindowError.Create('Cannot save native drawing DC');
    try
      FCanvas.Handle := DC;
      Painter(Self);
      if Acquired and not FPainting then PaintOverlay;
    finally
      FCanvas.Handle := PreviousDC;
      RestoreDC(DC, State);
    end;
  finally
    if Acquired then ReleaseDC(Window, DC);
  end;
end;
end.
