program TestWin16SpeedButton;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, native_speedbutton;
type
  TProbe = class(TSpeedButton)
  public
    Enters, Leaves, Pressed, Clicks: Integer;
    function State: TButtonState;
    procedure Click; override;
    procedure CMButtonPressed(var Message: TMessage); message CM_BUTTONPRESSED;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  end;
  TObserver = class
    ParentDowns: Integer;
    procedure ParentDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  end;
var Root: TCustomControl; A, B, C: TProbe; Observer: TObserver; Failed: Boolean;
  Surface: TControlCanvas; DC: HDC; Pixel1, Pixel2, Pixel3: TColorRef;
  Origin: TPoint; Start: LongInt; Msg: TMsg;
function TProbe.State: TButtonState; begin Result := FState; end;
procedure TProbe.Click; begin Inc(Clicks); inherited Click; end;
procedure TProbe.CMButtonPressed(var Message: TMessage); begin Inc(Pressed); inherited; end;
procedure TProbe.CMMouseEnter(var Message: TMessage); begin Inc(Enters); inherited; end;
procedure TProbe.CMMouseLeave(var Message: TMessage); begin Inc(Leaves); inherited; end;
procedure TObserver.ParentDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin Inc(ParentDowns); end;
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
procedure Mouse(Msg, Keys: Word; X, Y: Integer);
begin Root.Perform(Msg, Keys, MakeLong(X, Y)); end;
procedure ClickAt(X, Y: Integer);
begin Mouse(WM_LBUTTONDOWN, MK_LBUTTON, X, Y); Mouse(WM_LBUTTONUP, 0, X, Y); end;
function NewProbe(X: Integer; Group: Integer): TProbe;
begin
  Result := TProbe.Create(nil); Result.SetBounds(X, 10, 30, 30);
  Result.GroupIndex := Group; Result.Parent := Root;
end;
procedure Pump(Milliseconds: LongInt);
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < Milliseconds do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
begin
  LogLine('STEP speed buttons');
  Observer := TObserver.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Speed parent', WS_POPUP or WS_VISIBLE, 40, 40, 300, 100);
    Root.OnMouseDown := Observer.ParentDown;
    A := NewProbe(10, 1); B := NewProbe(50, 1); C := NewProbe(90, 0);
    Mouse(WM_LBUTTONDOWN, MK_LBUTTON, 100, 20);
    Check((C.State = bsDown) and (Observer.ParentDowns = 0) and Root.MouseCapture,
      'press routes to the graphic child and captures');
    Mouse(WM_MOUSEMOVE, MK_LBUTTON, 200, 20);
    Check(C.State = bsUp, 'dragging off pops the button up');
    Mouse(WM_MOUSEMOVE, MK_LBUTTON, 95, 15);
    Check(C.State = bsDown, 'dragging back presses again');
    Mouse(WM_MOUSEMOVE, MK_LBUTTON, 200, 20); Mouse(WM_LBUTTONUP, 0, 200, 20);
    Check((C.Clicks = 0) and (C.State = bsUp) and not Root.MouseCapture, 'release outside does not click');
    ClickAt(100, 20);
    Check((C.Clicks = 1) and (C.State = bsUp) and not C.Down, 'ungrouped click');
    Mouse(WM_LBUTTONDOWN, MK_LBUTTON, 200, 20); Mouse(WM_LBUTTONUP, 0, 200, 20);
    Check(Observer.ParentDowns = 1, 'empty area reaches the parent');
    ClickAt(20, 20);
    Check(A.Down and (A.State = bsExclusive) and (A.Clicks = 1) and (B.Pressed >= 1), 'group button stays down');
    ClickAt(60, 20);
    Check(B.Down and not A.Down and (A.State = bsUp) and (B.State = bsExclusive), 'group is exclusive');
    ClickAt(60, 20);
    Check(B.Down and (B.State = bsExclusive) and (B.Clicks = 2), 'last group button cannot pop up');
    B.AllowAllUp := True;
    Check(A.AllowAllUp, 'AllowAllUp propagates through the group');
    ClickAt(60, 20);
    Check(not B.Down and not A.Down and (B.State = bsUp), 'AllowAllUp lets the group go empty');
    A.Down := True; B.Down := True;
    Check(B.Down and not A.Down, 'programmatic Down is exclusive');
    C.Down := True;
    Check(not C.Down, 'ungrouped button cannot stay down');
    C.Enabled := False;
    Check(C.State = bsDisabled, 'disabled state');
    ClickAt(100, 20);
    Check((C.Clicks = 1) and (Observer.ParentDowns = 2), 'disabled button passes clicks to the parent');
    C.Enabled := True;
    Check(C.State = bsUp, 'enabled again');
    Mouse(WM_MOUSEMOVE, 0, 200, 20);
    A.Enters := 0; A.Leaves := 0; B.Enters := 0; B.Leaves := 0;
    Mouse(WM_MOUSEMOVE, 0, 20, 20);
    Check((A.Enters = 1) and (A.Leaves = 0), 'mouse enter');
    Mouse(WM_MOUSEMOVE, 0, 25, 25);
    Check(A.Enters = 1, 'no repeated enter');
    Mouse(WM_MOUSEMOVE, 0, 60, 20);
    Check((A.Leaves = 1) and (B.Enters = 1), 'moving between buttons');
    Mouse(WM_MOUSEMOVE, 0, 200, 20);
    Check(B.Leaves = 1, 'leaving to the parent area');
    { Real cursor: entering through USER, then leaving the window detected by polling. }
    Origin := Root.ClientToScreen(Point(20, 20));
    SetCursorPos(Origin.X, Origin.Y); Pump(300);
    Check((A.Enters = 2) and (A.Leaves = 1), 'real cursor enters and stays');
    SetCursorPos(Origin.X + 400, Origin.Y + 300); Pump(500);
    Check(A.Leaves = 2, 'leaving the parent window is detected');
    LogLine('INFO hover ' + IntToStr(A.Enters) + '/' + IntToStr(A.Leaves) + ' ' + IntToStr(B.Enters) + '/' + IntToStr(B.Leaves));
    Mouse(WM_MOUSEMOVE, 0, 100, 20);
    C.Free; C := nil;
    Mouse(WM_MOUSEMOVE, 0, 100, 20); Mouse(WM_LBUTTONDOWN, MK_LBUTTON, 100, 20); Mouse(WM_LBUTTONUP, 0, 100, 20);
    Check(Observer.ParentDowns = 3, 'freed hovered button is forgotten');
    Mouse(WM_LBUTTONDOWN, MK_LBUTTON, 20, 20); A.Free; A := nil;
    Mouse(WM_MOUSEMOVE, MK_LBUTTON, 20, 20); Mouse(WM_LBUTTONUP, 0, 20, 20);
    Check(not Root.MouseCapture, 'freeing the captured button releases capture');
    { TStyleSpeed draws its separator through a TControlCanvas on the parent. }
    Surface := TControlCanvas.Create;
    try
      Surface.Control := B;
      Surface.Pen.Color := clRed;
      Surface.PolyLine([Point(0, 0), Point(5, 0), Point(5, 5)]);
      Surface.Pixels[100, 0] := clRed;
      Surface.Control := nil;
      DC := GetDC(Root.Handle);
      Pixel1 := GetPixel(DC, B.Left + 3, B.Top); Pixel2 := GetPixel(DC, B.Left + 5, B.Top + 4);
      Pixel3 := GetPixel(DC, B.Left + 100, B.Top);
      ReleaseDC(Root.Handle, DC);
      Check((Pixel1 = RGB(255, 0, 0)) and (Pixel2 = RGB(255, 0, 0)) and (Pixel3 <> RGB(255, 0, 0)),
        'control canvas polyline at graphic origin, clipped');
    finally Surface.Free; end;
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  A.Free; B.Free; C.Free; Root.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
