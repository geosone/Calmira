program TestWin16Timer;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Controls, Forms, ExtCtrls, native_window;
type
  TEvents = class
    Ticks, Errors: Integer;
    Fail: Boolean;
    procedure Tick(Sender: TObject);
    procedure Error(Sender: TObject; E: Exception);
  end;
  { Calmira's TCalForm and TTaskbar parent themselves to the desktop. }
  TDesktopForm = class(TForm)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;
  TBadForm = class(TForm)
  public
    Change: Integer;
    OwnerWnd: HWND;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;
var Events: TEvents; Timer: TTimer; Desk: TDesktopForm; Bad: TBadForm; Failed, Raised: Boolean;
  Buffer: array[0..63] of Char; Before: Integer;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure Pump(Duration: LongInt);
var Msg: TMsg; Start: LongInt;
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < Duration do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure TEvents.Tick(Sender: TObject);
begin
  Inc(Ticks);
  if Fail then raise Exception.Create('tick failed');
end;
procedure TEvents.Error(Sender: TObject; E: Exception);
begin Inc(Errors); end;
procedure TDesktopForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.WndParent := GetDesktopWindow;
  Params.Caption := 'From params';
  Params.X := 40;
end;
procedure TBadForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  case Change of
    0: Params.ExStyle := $00000008; { WS_EX_TOPMOST }
    1: Params.WndParent := OwnerWnd;
    2: Params.WinClassName[0] := 'X';
  end;
end;
procedure TryBad(Change: Integer; Owner: HWND; const Text: string);
begin
  Bad := TBadForm.CreateNew(nil); Bad.Change := Change; Bad.OwnerWnd := Owner; Raised := False;
  try Bad.Show; except on ENativeWindowError do Raised := True; end;
  Check(Raised and (Bad.Handle = 0), Text);
  Bad.Free; Bad := nil;
end;
begin
  LogLine('STEP timer');
  Events := TEvents.Create;
  Application.OnException := Events.Error;
  try
    Timer := TTimer.Create(nil);
    Check(Timer.Enabled and (Timer.Interval = 1000) and not Assigned(Timer.OnTimer), 'TTimer has Delphi''s defaults');
    Timer.Interval := 100;
    Timer.OnTimer := Events.Tick;
    Pump(700);
    Check(Events.Ticks >= 3, 'an enabled timer with OnTimer ticks');
    Timer.Enabled := False; Pump(50); Events.Ticks := 0;
    Pump(400);
    Check(Events.Ticks = 0, 'a disabled timer is silent');
    Timer.Enabled := True; Timer.Interval := 0; Pump(50); Events.Ticks := 0;
    Pump(400);
    Check(Events.Ticks = 0, 'Interval 0 stops the timer');
    Timer.Interval := 100; Timer.OnTimer := nil; Pump(50); Events.Ticks := 0;
    Pump(400);
    Check(Events.Ticks = 0, 'without OnTimer nothing runs');
    Timer.OnTimer := Events.Tick; Events.Fail := True;
    Pump(500);
    Before := Events.Ticks;
    Check((Before >= 2) and (Events.Errors >= 2), 'a failing OnTimer is reported and the timer goes on');
    Events.Fail := False;
    Timer.Free; Timer := nil; Before := Events.Ticks;
    Pump(400);
    Check(Events.Ticks = Before, 'a freed timer stops');

    Desk := TDesktopForm.CreateNew(nil);
    Desk.SetBounds(10, 10, 200, 100); Desk.Caption := 'Desk';
    Desk.Show; Pump(50);
    GetWindowText(Desk.Handle, Buffer, SizeOf(Buffer));
    Check(StrPas(Buffer) = 'From params', 'CreateParams can change the caption');
    Check(Desk.Left = 40, 'CreateParams can move the window');
    Check(GetWindow(Desk.Handle, GW_OWNER) = 0, 'the desktop as WndParent leaves the form unowned');
    TryBad(0, 0, 'extended styles raise');
    TryBad(1, Desk.Handle, 'an owner window raises');
    TryBad(2, 0, 'another window class raises');
    Desk.Free; Desk := nil;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Application.OnException := nil;
  Timer.Free; Desk.Free; Bad.Free;
  Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
