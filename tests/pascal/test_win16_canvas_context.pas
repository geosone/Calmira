program TestWin16CanvasContext;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, gdi_canvas,
  native_loop, native_window;
type
  TBox = class(TGraphicControl)
  public
    property Canvas;
  end;
  TPane = class(TCustomControl)
  public
    property Color;
  end;
  TIdleProbe = class
    InUseAtIdle: Boolean;
    Called: Boolean;
    procedure Start(Sender: TObject);
    procedure Idle(Sender: TObject; var Done: Boolean);
  end;
var Root, Child: TCustomControl; Pane: TPane; Boxes: array[0..5] of TBox; Box: TBox; Failed: Boolean;
  Loop: TNativeMessageLoop; Probe: TIdleProbe; Width1: Integer; I: Integer; Own: HDC; Empty, Copy: TBitmap;
  Recolour: TBitmap; X, Y: Integer; Start, GetTicks, SetTicks: LongInt; Mode: Integer;
  First, Second: TFont; Shared: HFONT; Description: TLogFont; Assigned: TCanvas; Face: array[0..31] of Char;
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
function ScreenPixel(Window: HWND; X, Y: Integer): TColorRef;
var DC: HDC;
begin
  DC := GetDC(Window); Result := GetPixel(DC, X, Y); ReleaseDC(Window, DC);
end;
procedure TIdleProbe.Start(Sender: TObject);
begin
  UpdateWindow(Root.Handle);
  Box.Canvas.TextWidth('Idle');
  if not DeviceContextsInUse then LogLine('INFO no context before idle');
end;
procedure TIdleProbe.Idle(Sender: TObject; var Done: Boolean);
begin
  Called := True; InUseAtIdle := DeviceContextsInUse;
  PostQuitMessage(0);
end;
begin
  LogLine('STEP canvas-context');
  Probe := nil; Loop := nil;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Canvas context', WS_POPUP or WS_VISIBLE, 10, 10, 300, 200);
    UpdateWindow(Root.Handle);
    { As Delphi's TWinControl.WMEraseBkgnd: a control just shown is filled
      with its Color before it paints, not left showing what was below
      (the Explorer's panes while a folder loads). }
    Pane := TPane.Create(nil);
    try
      Pane.Color := clLime;
      Pane.CreateHandle(0, '', WS_POPUP, 340, 10, 60, 40);
      ShowWindow(Pane.Handle, SW_SHOWNOACTIVATE);
      Check(ScreenPixel(Pane.Handle, 30, 20) = RGB(0, 255, 0), 'a control just shown is filled with its colour');
    finally Pane.Free; end;
    Root.Canvas.Font.Name := 'System';
    Width1 := Root.Canvas.TextWidth('Calmira');
    Check(Width1 > 0, 'TextWidth works outside painting');
    Check(Root.Canvas.Handle = 0, 'Handle stays 0 with a borrowed context');
    Check(DeviceContextsInUse, 'the borrowed context is kept until idle');
    Root.Canvas.Brush.Color := clRed;
    Root.Canvas.FillRect(Rect(100, 100, 110, 110));
    Check(ScreenPixel(Root.Handle, 105, 105) = RGB(255, 0, 0), 'FillRect outside painting reaches the window');
    Root.Canvas.Pen.Color := clBlue;
    Root.Canvas.MoveTo(120, 100); Root.Canvas.LineTo(140, 100); Root.Canvas.LineTo(140, 120);
    Check((ScreenPixel(Root.Handle, 130, 100) = RGB(0, 0, 255)) and
      (ScreenPixel(Root.Handle, 140, 110) = RGB(0, 0, 255)), 'MoveTo/LineTo keep the pen position');
    Own := GetDC(Root.Handle);
    Root.Canvas.Handle := Own;
    Check(not DeviceContextsInUse, 'an assigned Handle replaces the borrowed context');
    Root.Canvas.Handle := 0; ReleaseDC(Root.Handle, Own);
    Root.Canvas.TextWidth('x');
    FreeDeviceContexts;
    Check(not DeviceContextsInUse and (Root.Canvas.Handle = 0), 'FreeDeviceContexts releases it');

    Box := TBox.Create(nil); Box.SetBounds(20, 30, 40, 20); Box.Parent := Root;
    UpdateWindow(Root.Handle);
    Box.Canvas.Brush.Color := clBlue;
    Box.Canvas.FillRect(Rect(0, 0, 60, 20));
    Check(ScreenPixel(Root.Handle, 20, 30) = RGB(0, 0, 255), 'a graphic canvas starts at the control origin');
    Check(ScreenPixel(Root.Handle, 65, 35) <> RGB(0, 0, 255), 'a graphic canvas is clipped to the control');
    Check(Box.Canvas.Handle = 0, 'graphic Handle stays 0');
    Box.SetBounds(150, 30, 40, 20);
    Check(not DeviceContextsInUse, 'moving a graphic control drops its context');
    UpdateWindow(Root.Handle);
    Box.Canvas.Brush.Color := clLime;
    Box.Canvas.FillRect(Rect(0, 0, 5, 5));
    Check(ScreenPixel(Root.Handle, 151, 31) = RGB(0, 255, 0), 'a moved graphic control draws at its new place');
    Box.Parent := nil;
    Check(not DeviceContextsInUse, 'reparenting drops the context');

    Child := TCustomControl.Create(nil);
    Child.CreateHandle(Root.Handle, '', WS_CHILD or WS_VISIBLE, 200, 150, 50, 30);
    Box.Parent := Child;
    Child.Canvas.TextWidth('a'); Box.Canvas.TextWidth('b');
    Check(DeviceContextsInUse, 'child and graphic contexts are borrowed');
    Child.Free; Child := nil;
    Check(not DeviceContextsInUse, 'destroying a window releases contexts');
    Box.Free; Box := nil;

    for I := 0 to High(Boxes) do
    begin
      Boxes[I] := TBox.Create(nil); Boxes[I].SetBounds(I * 10, 0, 8, 8); Boxes[I].Parent := Root;
    end;
    for I := 0 to High(Boxes) do Boxes[I].Canvas.FillRect(Rect(0, 0, 8, 8));
    Check(True, 'more canvases than common DCs draw without exhausting USER');
    for I := 0 to High(Boxes) do begin Boxes[I].Free; Boxes[I] := nil; end;
    Check(not DeviceContextsInUse, 'freeing canvases releases their contexts');

    { Calmira's MinimizeString measures text on a new, empty TBitmap. }
    Empty := TBitmap.Create;
    try
      Empty.Canvas.Font.Name := 'System';
      Check((Empty.Canvas.TextWidth('Calmira') > 0) and Empty.Empty and (Empty.Canvas.Handle <> 0),
        'an empty bitmap canvas measures text on a memory DC, as in Delphi');
      Empty.Width := 4; Empty.Height := 4;
      Empty.Canvas.Pixels[1, 1] := clRed;
      Check((Empty.Canvas.Handle <> 0) and (Empty.Canvas.Pixels[1, 1] = RGB(255, 0, 0)),
        'sizing the bitmap gives its canvas the bitmap DC');
      FreeDeviceContexts;
      Check(not DeviceContextsInUse, 'a bitmap gives its DC back at idle, as Delphi''s FreeMemoryContexts');
      Check(Empty.Canvas.Pixels[1, 1] = RGB(255, 0, 0), 'the bitmap keeps its pixels and takes a new DC on demand');
      Copy := TBitmap.Create;
      try
        Copy.Assign(Empty); FreeDeviceContexts;
        Check(Copy.Canvas.Pixels[1, 1] = RGB(255, 0, 0), 'a copy made from a bitmap without a DC keeps the pixels');
      finally Copy.Free; end;
    finally Empty.Free; end;
    Check(not DeviceContextsInUse, 'a freed bitmap leaves no memory DC borrowed');

    { Calmira's ReplaceBitmapColors recolours the Explorer's tree images pixel
      by pixel when a folder window opens: setting a pixel costs about as
      much as reading one, and a raster mode the caller chose stays. }
    Recolour := TBitmap.Create;
    try
      Recolour.Width := 96; Recolour.Height := 32;
      Start := GetTickCount;
      for X := 0 to 95 do for Y := 0 to 31 do
        if Recolour.Canvas.Pixels[X, Y] = clRed then Recolour.Canvas.Pixels[X, Y] := clBlue;
      GetTicks := GetTickCount - Start;
      Start := GetTickCount;
      for X := 0 to 95 do for Y := 0 to 31 do Recolour.Canvas.Pixels[X, Y] := clLime;
      SetTicks := GetTickCount - Start;
      LogLine('INFO pixels: read ' + IntToStr(GetTicks) + ' ms, set ' + IntToStr(SetTicks) + ' ms');
      Check(SetTicks <= 2 * GetTicks + 110, 'setting a pixel costs about as much as reading one');
      SetROP2(Recolour.Canvas.Handle, R2_NOT);
      Recolour.Canvas.Pixels[2, 2] := clRed;
      Mode := GetROP2(Recolour.Canvas.Handle);
      Check((Recolour.Canvas.Pixels[2, 2] = RGB(255, 0, 0)) and (Mode = R2_NOT),
        'a pixel is set as given and the raster mode stays');
      SetROP2(Recolour.Canvas.Handle, R2_COPYPEN);
    finally Recolour.Free; end;

    First := TFont.Create; Second := TFont.Create;
    try
      First.Name := 'Arial'; First.Size := 10; Second.Name := 'Arial'; Second.Size := 10;
      Check(First.Handle = Second.Handle, 'fonts with the same description share one GDI font, as in Delphi');
      Shared := First.Handle;
      Second.Style := [fsBold];
      Check((Second.Handle <> Shared) and (First.Handle = Shared), 'changing a shared font gives it its own GDI font');
      Second.Style := [];
      First.Free; First := nil;
      Check(GetObject(Second.Handle, SizeOf(Description), @Description) > 0,
        'a shared font stays valid while another TFont uses it');
    finally First.Free; Second.Free; end;

    { Owner draw hands the canvas a DC; reading Handle selects the canvas's
      objects into it, as Delphi's RequiredState. }
    Own := GetDC(Root.Handle); Assigned := TCanvas.Create;
    try
      Assigned.Font.Name := 'Arial'; Assigned.Font.Size := 8; Assigned.Font.Color := clRed;
      Assigned.Brush.Color := clBlue; Assigned.Handle := Own;
      GetTextFace(Assigned.Handle, SizeOf(Face), Face);
      Check((StrComp(Face, 'Arial') = 0) and (GetTextColor(Own) = ColorToRGB(clRed)) and
        (GetBkColor(Own) = ColorToRGB(clBlue)) and (GetBkMode(Own) = OPAQUE),
        'Handle selects font, text colour and an opaque brush-coloured background, as Delphi');
      Assigned.Brush.Style := bsClear; Assigned.Font.Name := 'Courier New'; Assigned.Font.Color := clLime;
      GetTextFace(Assigned.Handle, SizeOf(Face), Face);
      Check((StrComp(Face, 'Courier New') = 0) and (GetBkMode(Own) = TRANSPARENT) and
        (GetTextColor(Own) = ColorToRGB(clLime)), 'a changed font and a clear brush reach the DC on the next Handle');
      SelectObject(Assigned.Handle, GetStockObject(ANSI_FIXED_FONT)); GetTextFace(Assigned.Handle, SizeOf(Face), Face);
      Check(StrComp(Face, 'Courier New') <> 0, 'a font the caller selected stays until the canvas font changes, as Delphi');
      Assigned.Handle := 0;
      GetTextFace(Own, SizeOf(Face), Face);
      Check(StrComp(Face, 'System') = 0, 'setting Handle to 0 puts the stock objects back, as DeselectHandles');
    finally Assigned.Free; ReleaseDC(Root.Handle, Own); end;
    Box := TBox.Create(nil); Box.SetBounds(20, 30, 40, 20); Box.Parent := Root;
    Probe := TIdleProbe.Create;
    Loop := TNativeMessageLoop.Create;
    Loop.OnStart := Probe.Start; Loop.OnIdle := Probe.Idle;
    Loop.Run;
    Check(Probe.Called and not Probe.InUseAtIdle, 'the message loop releases contexts before idle');
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Loop.Free; Probe.Free; Box.Free; Child.Free; Root.Free;
  Check(not DeviceContextsInUse, 'nothing left borrowed');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
