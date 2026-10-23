program TestWin16Hints;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, Forms, native_window;
type
  TPanel = class(TCustomControl)
  public
    property Hint;
    property ShowHint;
    property ParentShowHint;
  end;
  TBox = class(TGraphicControl)
  public
    property Hint;
    property ShowHint;
  end;
  TProbeHint = class(THintWindow)
  public
    procedure ActivateHint(Rect: TRect; const AHint: string); override;
  end;
  TEvents = class
    HintCalls: Integer;
    ShowCalls: Integer;
    Refuse, Replace: Boolean;
    LastControl: TControl;
    procedure AppHint(Sender: TObject);
    procedure AppShowHint(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
  end;
var Root: TCustomControl; Tipped, Plain, Inner: TPanel; Box, Off: TBox; Events: TEvents;
  Shown: TProbeHint; ShownRect: TRect; ShownText: string; ActivateCount: Integer;
  Failed: Boolean; R: TRect; Below: TPoint; Buf: array[0..31] of Char; Width1: Integer;
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
procedure TProbeHint.ActivateHint(Rect: TRect; const AHint: string);
begin
  Shown := Self; ShownRect := Rect; ShownText := AHint; Inc(ActivateCount);
  inherited ActivateHint(Rect, AHint);
end;
procedure TEvents.AppHint(Sender: TObject);
begin Inc(HintCalls); end;
procedure TEvents.AppShowHint(var HintStr: string; var CanShow: Boolean; var HintInfo: THintInfo);
begin
  Inc(ShowCalls); LastControl := HintInfo.HintControl;
  if Refuse then CanShow := False;
  if Replace then begin HintStr := 'Replaced'; HintInfo.HintColor := clLime; end;
end;
procedure Pump(Ms: LongInt);
var Start: LongInt;
begin
  { SysUtils also declares GetTickCount. }
  Start := WinProcs.GetTickCount;
  repeat Application.ProcessMessages; Yield; until WinProcs.GetTickCount - Start >= Ms;
end;
{ Moves the cursor over Control's client point and reports the move. }
procedure MoveTo(Control: TCustomControl; X, Y: Integer);
var P: TPoint;
begin
  P := Control.ClientToScreen(Point(X, Y));
  SetCursorPos(P.X, P.Y);
  PostMessage(Control.Handle, WM_MOUSEMOVE, 0, MakeLong(X, Y));
end;
function HintVisible: Boolean;
begin Result := (Shown <> nil) and (Shown.Handle <> 0) and IsWindowVisible(Shown.Handle); end;
begin
  LogLine('STEP hints');
  Events := TEvents.Create;
  try
    Check((GetShortHint('Open|Opens a file') = 'Open') and (GetLongHint('Open|Opens a file') = 'Opens a file') and
      (GetShortHint('Plain') = 'Plain') and (GetLongHint('Plain') = 'Plain'), 'GetShortHint and GetLongHint split at |');
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Hints', WS_POPUP or WS_VISIBLE, 40, 40, 300, 200);
    Tipped := TPanel.Create(nil); Tipped.SetBounds(10, 10, 100, 40);
    Tipped.Hint := 'Short|Long text'; Tipped.ShowHint := True; Tipped.Parent := Root;
    Plain := TPanel.Create(nil); Plain.SetBounds(150, 10, 100, 40); Plain.Hint := 'Quiet'; Plain.Parent := Root;
    Inner := TPanel.Create(nil); Inner.SetBounds(5, 5, 20, 20); Inner.Parent := Tipped;
    Box := TBox.Create(nil); Box.SetBounds(10, 100, 50, 30); Box.Hint := 'Box'; Box.ShowHint := True; Box.Parent := Root;
    Off := TBox.Create(nil); Off.SetBounds(100, 100, 50, 30); Off.Enabled := False; Off.Parent := Root;
    UpdateWindow(Root.Handle);

    Check(FindDragTarget(Root.ClientToScreen(Point(80, 30)), False) = Tipped, 'FindDragTarget finds a windowed control');
    Check(FindDragTarget(Root.ClientToScreen(Point(20, 110)), False) = Box, 'FindDragTarget finds a graphic control');
    Check(FindDragTarget(Root.ClientToScreen(Point(110, 110)), False) = Root, 'a disabled graphic control is skipped');
    Check(FindDragTarget(Root.ClientToScreen(Point(110, 110)), True) = Off, 'AllowDisabled finds a disabled graphic control');
    Check(FindDragTarget(Point(1, GetSystemMetrics(SM_CYSCREEN) - 2), False) = nil, 'no control outside the application');

    Application.OnHint := Events.AppHint;
    MoveTo(Root, 200, 150); Pump(50);
    Events.HintCalls := 0;
    MoveTo(Tipped, 50, 30); Pump(50);
    Check((Application.Hint = 'Long text') and (Events.HintCalls = 1), 'Application.Hint takes the long hint and calls OnHint');
    MoveTo(Inner, 3, 3); Pump(50);
    Check(Application.Hint = 'Long text', 'a control without a hint uses its parent''s');
    MoveTo(Plain, 3, 3); Pump(50);
    Check((Application.Hint = 'Quiet') and (Events.HintCalls = 2), 'OnHint runs when the hint changes');
    Check(not Application.ShowHint and (ActivateCount = 0), 'pop-up hints are off by default');

    HintWindowClass := TProbeHint;
    Application.HintPause := 100;
    Application.ShowHint := True;
    MoveTo(Tipped, 50, 30); Pump(50);
    Check(ActivateCount = 0, 'no hint before HintPause');
    Pump(300);
    Check(ActivateCount = 1, 'moves inside the control do not restart the hint');
    Check(HintVisible and (ShownText = 'Short'), 'the short hint pops up after HintPause');
    Below := Tipped.ClientToScreen(Point(0, 40));
    Check((ShownRect.Left = Below.X) and (ShownRect.Top = Below.Y), 'the hint appears below the control');
    Check(Shown.Color = Application.HintColor, 'the hint uses HintColor');
    Check(Inner.ShowHint and (FindDragTarget(Inner.ClientToScreen(Point(3, 3)), False) = Inner),
      'a child inherits ShowHint through ParentShowHint');
    PostMessage(Tipped.Handle, WM_KEYDOWN, VK_SHIFT, 1); Pump(50);
    Check(not HintVisible, 'a key press cancels the hint');

    MoveTo(Root, 20, 110); Pump(400);
    Check(HintVisible and (ShownText = 'Box'), 'graphic controls show hints');
    MoveTo(Plain, 10, 10); Pump(300);
    Check(not HintVisible, 'moving to a control without ShowHint hides the hint');

    Application.OnShowHint := Events.AppShowHint;
    Events.Refuse := True; ActivateCount := 0;
    MoveTo(Tipped, 50, 30); Pump(400);
    Check((Events.ShowCalls >= 1) and (Events.LastControl = Tipped) and (ActivateCount = 0) and not HintVisible,
      'OnShowHint can refuse a hint');
    Events.Refuse := False; Events.Replace := True;
    MoveTo(Tipped, 51, 30); Pump(400);
    Check(HintVisible and (ShownText = 'Replaced') and (Shown.Color = clLime),
      'after a refusal the next move asks again; OnShowHint can change text and color');
    Application.CancelHint;
    Check(not HintVisible, 'CancelHint hides the hint');

    Check(Shown.HandleAllocated, 'HandleAllocated reports the hint window');
    Shown.ReleaseHandle;
    Check(not Shown.HandleAllocated, 'ReleaseHandle destroys the hint window');
    Shown.Canvas.Font.Name := 'MS Sans Serif'; Shown.Canvas.Font.Size := 8;
    Width1 := Shown.Canvas.TextWidth('Calmira hint');
    R := Rect(0, 0, 400, 0);
    DrawText(Shown.Canvas.ContextHandle, StrPCopy(Buf, 'Calmira hint'), -1, R, DT_CALCRECT or DT_SINGLELINE);
    Check(R.Right = Width1, 'ContextHandle measures with the canvas font');
    Application.ShowHint := False;
    Check(not Application.ShowHint, 'pop-up hints can be turned off');
    Application.OnHint := nil; Application.OnShowHint := nil;
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Off.Free; Box.Free; Inner.Free; Plain.Free; Tipped.Free; Root.Free; Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
