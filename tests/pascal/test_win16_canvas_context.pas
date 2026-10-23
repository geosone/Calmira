program TestWin16CanvasContext;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, gdi_canvas,
  native_loop, native_window;
type
  TBox = class(TGraphicControl)
  public
    property Canvas;
  end;
  TIdleProbe = class
    InUseAtIdle: Boolean;
    Called: Boolean;
    procedure Start(Sender: TObject);
    procedure Idle(Sender: TObject; var Done: Boolean);
  end;
var Root, Child: TCustomControl; Boxes: array[0..5] of TBox; Box: TBox; Failed: Boolean;
  Loop: TNativeMessageLoop; Probe: TIdleProbe; Width1: Integer; I: Integer; Own: HDC;
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
