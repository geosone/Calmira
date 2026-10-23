program ApplicationExceptionTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, Messages, native_application,
  native_window, exception_text;
type
  TTrackedException = class(Exception)
    destructor Destroy; override;
  end;
  TProbe = class(TNativeWindow)
    procedure Raised(var M: TMessage); message WM_USER + 91;
  end;
  TD = object
    Calls, Guards: Integer;
    FailHandler, GuardHandler, Valid: Boolean;
    procedure Raised(Sender: TObject; E: Exception);
  end;
var App: TNativeApplication; Probe: TProbe; Driver: TD;
  Failed, Rejected: Boolean; Expected: Exception; ExpectedSender: TObject;
  Freed, Boxes, DialogGuards, I, Before: Integer; Timer: UINT;
  Payload, Display: AnsiString; ExpectedCaption: string;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10;
  _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
destructor TTrackedException.Destroy;
begin Inc(Freed); inherited Destroy; end;
procedure TD.Raised(Sender: TObject; E: Exception);
begin
  Inc(Calls);
  Valid := Valid and (Sender = ExpectedSender) and (E = Expected) and
    (ExceptObject = E) and (E is TTrackedException) and
    (E.Message = 'borrowed') and (E.HelpContext = 321);
  if GuardHandler then
  begin
    try App.HandleException(Sender); except on ENativeApplicationError do Inc(Guards); end;
    try App.ShowException(E); except on ENativeApplicationError do Inc(Guards); end;
    try App.OnException := nil; except on ENativeApplicationError do Inc(Guards); end;
    try App.Run; except on ENativeApplicationError do Inc(Guards); end;
    try App.ProcessMessages(1); except on ENativeApplicationError do Inc(Guards); end;
  end;
  if FailHandler then raise Exception.Create('handler failure');
end;
procedure TProbe.Raised(var M: TMessage);
begin
  if M.WParam = 1 then raise Exception.Create('unhandled callback');
  try raise TTrackedException.CreateHelp('borrowed', 321);
  except on E: Exception do
    begin Expected := E; ExpectedSender := Self; App.HandleException(Self); end;
  end;
end;
procedure BorrowedCase(SenderIsException: Boolean);
begin
  Before := Freed;
  try raise TTrackedException.CreateHelp('borrowed', 321);
  except on E: Exception do
    begin
      Expected := E; ExpectedSender := Probe;
      if SenderIsException then ExpectedSender := E;
      App.HandleException(ExpectedSender);
      Check(Freed = Before, 'active exception remains borrowed inside handler scope');
    end;
  end;
  Check(Freed = Before + 1, 'RTL releases active exception exactly once');
end;
procedure Tick(Window: HWND; Message, Event: UINT; Time: DWORD); export;
var Box, Child: HWND; Name: array[0..63] of Char;
begin
  try
    Box := GetActiveWindow;
    if (Box = 0) or (GetWindowTask(Box) <> GetCurrentTask) then Exit;
    GetClassName(Box, Name, SizeOf(Name));
    if StrComp(Name, '#32770') <> 0 then Exit;
    GetWindowText(Box, Name, SizeOf(Name));
    Check((StrPas(Name) = ExpectedCaption) and (GetParent(Box) = App.Handle),
      'native exception dialog uses application caption and owner');
    try App.ProcessMessages(1); except on ENativeApplicationError do Inc(DialogGuards); end;
    try App.Run; except on ENativeApplicationError do Inc(DialogGuards); end;
    Child := GetWindow(Box, GW_CHILD);
    while Child <> 0 do
    begin
      GetClassName(Child, Name, SizeOf(Name));
      if StrIComp(Name, 'Button') = 0 then
      begin
        Inc(Boxes);
        SendMessage(Box, WM_COMMAND, GetDlgCtrlID(Child), LongInt(Child)); Exit;
      end;
      Child := GetWindow(Child, GW_HWNDNEXT);
    end;
    Failed := True;
  except Failed := True; end;
end;
procedure BasicCases;
begin
  App := TNativeApplication.Create(nil); Rejected := False;
  try App.OnException := Driver.Raised; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'exception registration requires initialized application');
  App.Initialize; App.OnException := Driver.Raised; Driver.Valid := True;
  Check(FindWindow('TApplication', 'Calmira') = 0, 'exception registration is handle free');
  Rejected := False;
  try App.HandleException(Probe); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and (Driver.Calls = 0), 'HandleException requires active exception not sender cast');
  Rejected := False;
  try App.ShowException(nil); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'nil explicit exception rejected');
  Driver.GuardHandler := True; BorrowedCase(False); Driver.GuardHandler := False;
  BorrowedCase(True);
  Check(Driver.Valid and (Driver.Calls = 2) and (Driver.Guards = 5),
    'borrowed identity sender help context and recursion guards');
  try raise EAbort.Create('silent'); except App.HandleException(Probe); end;
  Check((Driver.Calls = 2) and (FindWindow('TApplication', 'Calmira') = 0),
    'EAbort bypasses handler and native dialog');
  Driver.FailHandler := True; Rejected := False; Before := Freed;
  try
    try raise TTrackedException.CreateHelp('borrowed', 321);
    except on E: Exception do
      begin Expected := E; ExpectedSender := Probe; App.HandleException(Probe); end;
    end;
  except on E: Exception do Rejected := E.Message = 'handler failure'; end;
  Check(Rejected and (Freed = Before + 1), 'direct handler failure propagates with original released');
  Driver.FailHandler := False; App.OnException := Driver.Raised; BorrowedCase(False);
  Check(Driver.Valid, 'handler guard recovers after failure');
end;
procedure CallbackCases;
begin
  Probe.CreateHandle(0, 'Exception probe', WS_OVERLAPPEDWINDOW, 0, 0, 120, 80);
  Before := Freed; Probe.Perform(WM_USER + 91, 0, 0);
  Check((Freed = Before + 1) and (Probe.CallbackErrors = 0) and Driver.Valid,
    'native callback can explicitly route its active exception');
  Driver.FailHandler := True; Before := Freed; Probe.Perform(WM_USER + 91, 0, 0);
  Check((Freed = Before + 1) and (Probe.CallbackErrors = 1) and
    (Probe.LastCallbackError = 'handler failure') and (App.WindowCallbackErrors = 0),
    'native boundary contains handler failure without global rerouting');
  Driver.FailHandler := False; Before := Driver.Calls;
  Probe.Perform(WM_USER + 91, 1, 0);
  Check((Driver.Calls = Before) and (Probe.CallbackErrors = 2) and
    (Probe.LastCallbackError = 'unhandled callback'), 'unrouted callback keeps existing diagnostics');
  Probe.ClearCallbackError; Probe.Perform(WM_USER + 91, 0, 0);
  Check((Probe.CallbackErrors = 0) and Driver.Valid, 'native routing recovers after handler error');
end;
procedure DialogCases;
begin
  Payload := StringOfChar('x', 2048); Payload[2] := #0; Payload[3] := #228;
  Display := ExceptionDisplayText(Payload, 'TTrackedException');
  Check((Length(Display) = 1024) and (Display[2] = ' ') and (Display[3] = #228) and
    (Copy(Display, 1022, 3) = '...') and (Payload[2] = #0),
    'native formatter bounds ANSI payload without mutating source');
  Timer := SetTimer(0, 0, 55, TFarProc(@Tick));
  if Timer = 0 then raise Exception.Create('timer');
  try
    App.OnException := nil; App.Title := 'Exception probe'; ExpectedCaption := App.Title;
    Before := Freed;
    try raise TTrackedException.Create(Payload);
    except on E: Exception do
      begin App.HandleException(Probe); Check(E.Message = Payload, 'default presentation preserves full exception'); end;
    end;
    Check((Boxes = 1) and (Freed = Before + 1), 'default handler displays and RTL releases exception');
    App.OnException := Driver.Raised; App.Title := ''; ExpectedCaption := 'Calmira';
    Expected := TTrackedException.Create(''); Before := Freed; I := Driver.Calls;
    try
      Check(ExceptionDisplayText(Expected.Message, Expected.ClassName) = 'TTrackedException',
        'empty native message falls back to exception class');
      App.ShowException(Expected);
      Check((Boxes = 2) and (Freed = Before) and (Driver.Calls = I),
        'explicit ShowException bypasses event and retains caller ownership');
    finally Expected.Free; Expected := nil; end;
    Check((Freed = Before + 1) and (DialogGuards = 4), 'dialog guards and caller release exactly once');
  finally KillTimer(0, Timer); Timer := 0; end;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native application exceptions');
  Probe := TProbe.Create(nil);
  try BasicCases; CallbackCases; DialogCases;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  if Timer <> 0 then KillTimer(0, Timer);
  Probe.Free; App.Free;
  Check(StackGuardIntact, 'application exception stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
