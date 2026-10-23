program TestWin16Drag;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Controls, control_base;
type
  TTarget = class(TCustomControl)
  public
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property DragMode;
  end;
  TMark = class(TGraphicControl)
  public
    property OnDragOver;
    property OnMouseDown;
    property DragMode;
  end;
  TObserver = class
    Enters, Moves, Leaves, Drops, Ends, Downs, LastX, LastY: Integer;
    AcceptSource: TObject;
    DropSender, DropSource, EndTarget: TObject;
    procedure Over(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure Dropped(Sender, Source: TObject; X, Y: Integer);
    procedure Ended(Sender, Target: TObject; X, Y: Integer);
    procedure Down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Reset;
  end;
var Root: TCustomControl; Source, Target: TTarget; Mark, AutoMark: TMark; Observer: TObserver;
  Failed: Boolean; Capture: HWND;
procedure TObserver.Over(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  case State of
    dsDragEnter: Inc(Enters);
    dsDragMove: Inc(Moves);
    dsDragLeave: Inc(Leaves);
  end;
  LastX := X; LastY := Y;
  Accept := Source = AcceptSource;
end;
procedure TObserver.Dropped(Sender, Source: TObject; X, Y: Integer);
begin Inc(Drops); DropSender := Sender; DropSource := Source; LastX := X; LastY := Y; end;
procedure TObserver.Ended(Sender, Target: TObject; X, Y: Integer);
begin Inc(Ends); EndTarget := Target; end;
procedure TObserver.Down(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin Inc(Downs); end;
procedure TObserver.Reset;
begin Enters := 0; Moves := 0; Leaves := 0; Drops := 0; Ends := 0; DropSender := nil; DropSource := nil; EndTarget := nil; end;
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
{ Moves the real cursor to a Root client point and lets the capture window see it. }
procedure MoveTo(X, Y: Integer);
var P: TPoint;
begin
  P := Root.ClientToScreen(Point(X, Y));
  SetCursorPos(P.X, P.Y);
  SendMessage(GetCapture, WM_MOUSEMOVE, MK_LBUTTON, 0);
end;
procedure Release;
begin SendMessage(GetCapture, WM_LBUTTONUP, 0, 0); end;
begin
  LogLine('STEP drag and drop');
  Observer := TObserver.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Drag parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 20, 20, 400, 200);
    Source := TTarget.Create(nil); Source.SetBounds(10, 10, 80, 80); Source.Parent := Root;
    Target := TTarget.Create(nil); Target.SetBounds(150, 10, 80, 80); Target.Parent := Root;
    Mark := TMark.Create(nil); Mark.SetBounds(300, 10, 40, 40); Mark.Parent := Root;
    Target.OnDragOver := Observer.Over; Target.OnDragDrop := Observer.Dropped;
    Mark.OnDragOver := Observer.Over; Source.OnEndDrag := Observer.Ended;
    Observer.AcceptSource := Source;
    Check((Source.DragCursor = crDrag) and (Source.DragMode = dmManual) and not Source.Dragging, 'defaults');

    MoveTo(40, 40); Source.BeginDrag(False); Capture := GetCapture;
    Check(Source.Dragging and (Capture <> 0) and (Capture <> Source.Handle), 'drag captures the mouse');
    MoveTo(42, 41);
    Check(Observer.Enters + Observer.Moves = 0, 'delayed drag waits for the threshold');
    MoveTo(160, 30);
    Check((Observer.Enters = 1) and (Observer.LastX = 10) and (Observer.LastY = 20), 'enter in target coordinates');
    MoveTo(170, 35);
    Check((Observer.Moves = 1) and (Observer.LastX = 20), 'move over target');
    MoveTo(310, 20);
    Check((Observer.Leaves = 1) and (Observer.Enters = 2) and (Observer.LastX = 10), 'graphic child is a drop target');
    MoveTo(250, 150);
    Check(Observer.Leaves = 2, 'leaving to a control without OnDragOver');
    Release;
    Check(not Source.Dragging and (Observer.Drops = 0) and (Observer.Ends = 1) and
      (Observer.EndTarget = nil) and (GetCapture <> Capture), 'drop on a refusing control');

    Observer.Reset;
    MoveTo(40, 40); Source.BeginDrag(True);
    MoveTo(180, 50); Release;
    Check((Observer.Drops = 1) and (Observer.DropSender = Target) and (Observer.DropSource = Source) and
      (Observer.LastX = 30) and (Observer.LastY = 40), 'drop on an accepting control');
    Check((Observer.Ends = 1) and (Observer.EndTarget = Target), 'end drag names the target');

    Observer.Reset;
    MoveTo(40, 40); Source.BeginDrag(True); MoveTo(180, 50);
    Source.EndDrag(False);
    Check((Observer.Drops = 0) and (Observer.Leaves = 1) and (Observer.EndTarget = nil) and
      not Source.Dragging, 'EndDrag(False) cancels');

    Observer.Reset; Observer.AcceptSource := nil;
    MoveTo(40, 40); Source.BeginDrag(True); MoveTo(180, 50); Release;
    Check((Observer.Drops = 0) and (Observer.Leaves = 1) and (Observer.Ends = 1), 'target can refuse the source');
    Observer.AcceptSource := Source;

    Observer.Reset;
    MoveTo(40, 40); Source.BeginDrag(True); MoveTo(320, 20);
    Mark.Free; Mark := nil;
    MoveTo(330, 30); Release;
    Check((Observer.Drops = 0) and (Observer.Ends = 1) and not Source.Dragging, 'freed target is forgotten');

    MoveTo(40, 40); Source.BeginDrag(True);
    Source.Free; Source := nil;
    Check((DragSource = nil) and (GetCapture <> Capture), 'freed source ends the drag');

    AutoMark := TMark.Create(nil); AutoMark.SetBounds(300, 100, 40, 40); AutoMark.Parent := Root;
    AutoMark.OnMouseDown := Observer.Down; AutoMark.DragMode := dmAutomatic;
    Root.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(310, 110));
    Check(AutoMark.Dragging and (Observer.Downs = 0) and not Root.MouseCapture, 'automatic drag of a graphic control');
    AutoMark.EndDrag(False);
    Target.DragMode := dmAutomatic;
    Target.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(5, 5));
    Check(Target.Dragging, 'automatic drag of a windowed control');
    Target.EndDrag(False);
    Check(not Target.Dragging and (DragSource = nil), 'drag finished');
    Check((Root.CallbackErrors = 0) and (Target.CallbackErrors = 0), 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  AutoMark.Free; Mark.Free; Source.Free; Target.Free; Root.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
