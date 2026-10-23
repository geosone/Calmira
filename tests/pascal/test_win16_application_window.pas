program ApplicationWindowTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, CalMsgs,
  native_application, native_form, native_application_window, native_window;
const ProbeMessage = WM_USER + 181; NestedMessage = WM_USER + 182;
  GuardMessage = WM_USER + 183; RaiseMessage = WM_USER + 184;
type TD = object
  OldCalls, NewCalls, Filtered, Sent, Posted, Rejections, Order: Integer;
  Consume, AllowClose, ConsumeQueue, DenyTitle: Boolean;
  function Older(var M: TMessage): Boolean;
  function Newer(var M: TMessage): Boolean;
  function Filter(var M: TMsg): Boolean;
  procedure Query(Sender: TObject; var Allowed: Boolean);
  procedure Launch(Sender: TObject);
end;
var App: TNativeApplication; Main: TNativeForm; Driver, Peer: TD;
  Failed, Rejected: Boolean; Raw: HWND; Buffer: array[0..255] of Char;
  Queue: TMsg; TitleValue: string; I: Integer; Info: TWndClass; Task: HTASK;
{$I win16_stack_guard.inc}
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
function ForeignProc(Window: HWND; Id: UINT; WP: WPARAM; LP: LPARAM): LRESULT; export;
begin Result := DefWindowProc(Window, Id, WP, LP); end;
function TD.Older(var M: TMessage): Boolean;
begin
  Result := False;
  if M.Msg = ProbeMessage then begin Inc(OldCalls); Order := Order * 10 + 1; end;
end;
function TD.Newer(var M: TMessage): Boolean;
begin
  Result := False;
  if M.Msg = ProbeMessage then
  begin
    Inc(NewCalls); Order := Order * 10 + 2; Result := Consume;
    if Result then M.Result := -1234567;
  end
  else if M.Msg = NestedMessage then
  begin M.Result := SendMessage(App.Handle, ProbeMessage, 0, 0); Result := True; end
  else if M.Msg = GuardMessage then
  begin
    try App.UnhookMainWindow(Newer); except on ENativeWindowError do Inc(Rejections); end;
    try App.HookMainWindow(Older); except on ENativeWindowError do Inc(Rejections); end;
    try App.Title := 'Reentrant'; except on ENativeWindowError do Inc(Rejections); end;
    try App.ProcessMessages(1); except on ENativeApplicationError do Inc(Rejections); end;
    try App.Run; except on ENativeApplicationError do Inc(Rejections); end;
    Result := True;
  end
  else if (M.Msg = WM_SETTEXT) and DenyTitle then
  begin M.Result := 0; Result := True; end
  else if M.Msg = RaiseMessage then raise Exception.Create('window hook failure')
  else if M.Msg = WM_CALMIRA then
  begin
    Result := True;
    case M.WParam of
      CM_PREVINSTANCE:
        begin
          Inc(Sent); Check(InSendMessage and (Word(M.LParam) <> Task), 'separate task synchronous send');
          Check((GetCurrentTask = Task) and (GetWindowTask(App.Handle) = Task), 'sent callback retains receiving task');
          M.Result := -1234567;
        end;
      CM_TOGGLEDESKTOP:
        begin
          Inc(Posted); Check((M.LParam = -1234567) and (Sent = 1) and (Filtered = 1),
            'cross-task signed reply and queued filter');
          KillTimer(App.Handle, 777); PostMessage(Main.Handle, WM_CLOSE, 0, 0);
        end;
    end;
  end
  else if (M.Msg = WM_TIMER) and (M.WParam = 777) then
  begin
    KillTimer(App.Handle, 777); Check(False, 'helper timeout'); App.Terminate(-99); Result := True;
  end;
end;
function TD.Filter(var M: TMsg): Boolean;
begin
  if (M.message = ProbeMessage) or (M.message = WM_CALMIRA) then Inc(Filtered);
  Result := ConsumeQueue and (M.message = ProbeMessage);
end;
procedure TD.Query(Sender: TObject; var Allowed: Boolean);
begin Allowed := AllowClose; end;
procedure TD.Launch(Sender: TObject);
begin
  Check(SetTimer(App.Handle, 777, 10000, nil) <> 0, 'helper timeout armed');
  Check(WinExec('C:\APPSEND.EXE', SW_HIDE) > 31, 'independent sender launched');
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0); FillChar(Peer, SizeOf(Peer), 0);
  App := TNativeApplication.Create(nil); App.Initialize;
  App.CreateForm(TNativeForm, Main); Main.Caption := 'Main'; Main.SetBounds(10, 10, 180, 100);
  Main.OnCloseQuery := Driver.Query; Task := GetCurrentTask;
end;
procedure Cleanup;
begin
  if App <> nil then
    if App.QuitRequested and not App.Terminated then App.ProcessMessages(500);
  App.Free; App := nil; Main := nil;
  Check(not PeekMessage(Queue, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE), 'no transport quit residue');
end;
procedure ClassCollision;
begin
  App := TNativeApplication.Create(nil); Rejected := False;
  try Raw := App.Handle; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'transport requires initialization'); Cleanup;
  FillChar(Info, SizeOf(Info), 0); Info.hInstance := HInstance;
  Info.lpfnWndProc := @ForeignProc; Info.lpszClassName := 'TApplication';
  Check(WinProcs.RegisterClass(Info), 'foreign local class registered'); Setup; Rejected := False;
  try Raw := App.Handle; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'foreign class collision rejected');
  Check(WinProcs.UnregisterClass('TApplication', HInstance), 'foreign class released');
  Raw := App.Handle; Check(Raw <> 0, 'class collision recovery'); Cleanup;
  Check(not IsWindow(Raw), 'application destroys transport');
end;
procedure Transport;
begin
  Setup; Raw := App.Handle;
  GetClassName(Raw, Buffer, SizeOf(Buffer));
  Check((StrPas(Buffer) = 'TApplication') and (FindWindow('TApplication', 'Calmira') = Raw) and
    (Main.Handle = 0) and not IsWindowVisible(Raw) and (GetParent(Raw) = 0), 'independent hidden application identity');
  Check(SendMessage(Raw, WM_GETTEXTLENGTH, 0, 0) = 7, 'native default handler');
  App.Title := 'Renamed'; GetWindowText(Raw, Buffer, SizeOf(Buffer));
  Check((App.Title = 'Renamed') and (StrPas(Buffer) = 'Renamed'), 'native and stored title agree');
  Rejected := False;
  try App.Title := 'Bad'#0'title'; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (App.Title = 'Renamed'), 'NUL title preserves state');
  TitleValue := ''; for I := 1 to 255 do TitleValue := TitleValue + 'x';
  App.Title := TitleValue; GetWindowText(Raw, Buffer, SizeOf(Buffer));
  Check((App.Title = TitleValue) and (StrLen(Buffer) = 255), 'full 255-byte title'); App.Title := 'Calmira';
  App.HookMainWindow(Driver.Older); App.HookMainWindow(Driver.Newer); App.HookMainWindow(Driver.Newer);
  Driver.DenyTitle := True; Rejected := False;
  try App.Title := 'Vetoed'; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (App.Title = 'Calmira'), 'hook title veto preserves stored state'); Driver.DenyTitle := False;
  SendMessage(Raw, ProbeMessage, 0, 0);
  Check((Driver.Order = 21) and (Driver.OldCalls = 1) and (Driver.NewCalls = 1), 'newest-first duplicate-safe hooks');
  App.HookMainWindow(Peer.Older); SendMessage(Raw, ProbeMessage, 0, 0);
  Check(Peer.OldCalls = 1, 'same method distinct receiver'); App.UnhookMainWindow(Peer.Older);
  Driver.Consume := True; I := Driver.OldCalls;
  Check((SendMessage(Raw, NestedMessage, 0, 0) = -1234567) and (Driver.OldCalls = I), 'nested send signed result and consumption');
  SendMessage(Raw, GuardMessage, 0, 0);
  Check((Driver.Rejections = 5) and (App.WindowCallbackErrors = 0), 'dispatch mutation and pump guards');
  Check((SendMessage(Raw, RaiseMessage, 0, 0) = 0) and (App.WindowCallbackErrors = 1) and
    (App.LastWindowCallbackError = 'window hook failure'), 'hook exception stays inside USER boundary');
  Check(SendMessage(Raw, ProbeMessage, 0, 0) = -1234567, 'hook recovery after exception');
  App.ClearWindowCallbackError;
  Check((App.WindowCallbackErrors = 0) and (App.LastWindowCallbackError = ''), 'window diagnostics clear explicitly');
  App.OnMessage := Driver.Filter; Driver.ConsumeQueue := True; I := Driver.NewCalls;
  PostMessage(Raw, ProbeMessage, 0, 0); App.ProcessMessages(500);
  Check((Driver.Filtered = 1) and (Driver.NewCalls = I), 'queued filter can consume before window hook');
  Driver.ConsumeQueue := False; PostMessage(Raw, ProbeMessage, 0, 0); App.ProcessMessages(500);
  Check((Driver.Filtered = 2) and (Driver.NewCalls = I + 1), 'unconsumed post reaches both layers');
  App.UnhookMainWindow(Driver.Newer); App.UnhookMainWindow(Driver.Newer);
  I := Driver.NewCalls; SendMessage(Raw, ProbeMessage, 0, 0);
  Check((Driver.NewCalls = I) and (Driver.OldCalls > 1), 'unhook is idempotent');
  Check(DestroyWindow(Raw), 'external native transport destruction');
  Raw := App.Handle; Check(IsWindow(Raw) and not App.QuitRequested, 'transport recreates without quitting');
  Main.Show; SendMessage(Raw, WM_CLOSE, 0, 0);
  Check(Main.Visible and not App.QuitRequested and IsWindow(Raw), 'application close honors main veto');
  Driver.AllowClose := True; SendMessage(Raw, WM_CLOSE, 0, 0); App.ProcessMessages(500);
  Check(App.Terminated and not Main.Visible and IsWindow(Raw), 'application close delegates without destroying transport');
  Cleanup; Check(not IsWindow(Raw), 'final transport release');
  App := TNativeApplication.Create(nil); App.Initialize; Raw := App.Handle;
  SendMessage(Raw, WM_CLOSE, 0, 0); App.ProcessMessages(500);
  Check(App.Terminated and IsWindow(Raw), 'mainless application close requests quit'); Cleanup;
end;
procedure CrossTask;
begin
  Setup; Raw := App.Handle; App.HookMainWindow(Driver.Newer); App.OnMessage := Driver.Filter;
  Driver.AllowClose := True; Main.OnShow := Driver.Launch;
  Check(App.Run = 0, 'cross-task transport run');
  Check((Driver.Sent = 1) and (Driver.Posted = 1) and (Driver.Filtered = 1) and
    (App.WindowCallbackErrors = 0), 'cross-task hook and filter separation'); Cleanup;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP application window transport');
  try ClassCollision; Transport; CrossTask;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; Check(StackGuardIntact, 'transport stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
