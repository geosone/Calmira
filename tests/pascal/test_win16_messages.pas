program TestWin16Messages;
{$APPTYPE GUI}{$mode delphi}{$H-}{$K+}
uses WinTypes, WinProcs, Messages;
type
  TReceiver = class
    procedure Command(var M: TWMCommand); message WM_COMMAND;
    procedure Scroll(var M: TWMVScroll); message WM_VSCROLL;
    procedure Activate(var M: TWMActivate); message WM_ACTIVATE;
    procedure Mouse(var M: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure Limits(var M: TWMGetMinMaxInfo); message WM_GETMINMAXINFO;
    procedure Custom(var M: TMessage); message $F123;
  end;
var
  Log: Text;
  Failed, Testing: Boolean;
  Calls: Integer;
  Receiver: TReceiver;
procedure Check(Okay: Boolean; const Description: string);
begin
  if Okay then WriteLn(Log, 'PASS ', Description)
  else begin WriteLn(Log, 'FAIL ', Description); Failed := True; end;
end;
procedure TReceiver.Command(var M: TWMCommand);
begin
  Inc(Calls);
  Check((M.ItemID = $1234) and (M.Ctl = $5678) and (M.NotifyCode = $9ABC),
    'WM_COMMAND Win16 word order');
  M.Result := $12345678;
end;
procedure TReceiver.Scroll(var M: TWMVScroll);
begin
  Inc(Calls);
  Check((M.ScrollCode = SB_THUMBTRACK) and (M.Pos = -12345) and
    (M.ScrollBar = $8765), 'WM_VSCROLL signed position and handle');
  M.Result := 234567;
end;
procedure TReceiver.Activate(var M: TWMActivate);
begin
  Inc(Calls);
  Check((M.Active = WA_ACTIVE) and (M.ActiveWindow = $4321) and M.Minimized,
    'WM_ACTIVATE Win16 word order');
  M.Result := 345678;
end;
procedure TReceiver.Mouse(var M: TWMLButtonDown);
begin
  Inc(Calls);
  Check((M.Keys = MK_SHIFT) and (M.XPos = -10) and (M.YPos = -20) and
    (M.Pos.X = -10) and (M.Pos.Y = -20), 'signed mouse coordinates and point alias');
  M.Result := 456789;
end;
procedure TReceiver.Limits(var M: TWMGetMinMaxInfo);
begin
  Inc(Calls);
  M.MinMaxInfo^.ptMaxSize.X := 321;
  M.Result := 567890;
end;
procedure TReceiver.Custom(var M: TMessage);
begin
  Inc(Calls);
  Check((M.Msg = $F123) and (M.WParam = $FFFF) and (M.LParam = -7654321),
    'unsigned high message ID and nonzero parameter');
  M.Result := -1234567;
end;
function WindowProc(Window: HWND; Id: UINT; WP: WPARAM; LP: LPARAM): LRESULT; export;
var M: TMessage;
begin
  if Testing then
  begin
    M.Msg := Id; M.WParam := WP; M.LParam := LP; M.Result := 0;
    Receiver.Dispatch(M);
    WindowProc := M.Result;
  end
  else WindowProc := DefWindowProc(Window, Id, WP, LP);
end;
var
  Info: TWndClass;
  Window: HWND;
  Limits: TMinMaxInfo;
  M: TMessage;
begin
  AssignFile(Log, 'C:\MSGTEST.LOG'); Rewrite(Log);
  Check((SizeOf(TMessage) = 12) and (SizeOf(TWMCommand) = 12) and
    (SizeOf(TWMVScroll) = 12) and (SizeOf(TWMActivate) = 12) and
    (SizeOf(TWMDrawItem) = 12) and (SizeOf(TWMMeasureItem) = 12) and
    (SizeOf(TWMGetMinMaxInfo) = 12) and (SizeOf(TWMMouse) = 12) and
    (SizeOf(TWMNoParams) = 12) and (SizeOf(TWMPaint) = 12) and
    (SizeOf(TWMEnable) = 12) and (SizeOf(TWMNCHitMessage) = 12) and
    (SizeOf(TWMSysCommand) = 12) and (SizeOf(TWMMouseActivate) = 12) and
    (SizeOf(TWMDropFiles) = 12), '12-byte message records');
  Check((SizeOf(HWND) = 2) and (SizeOf(WPARAM) = 2) and (SizeOf(LPARAM) = 4),
    'native Win16 API widths');
  FillChar(M, SizeOf(M), 0);
  M.WParam := $1234; M.LParam := $56789ABC; M.Result := $12345678;
  Check((M.WParamLo = $34) and (M.WParamHi = $12) and (M.LParamLo = $9ABC) and
    (M.LParamHi = $5678) and (M.ResultLo = $5678) and (M.ResultHi = $1234),
    'generic byte and word aliases');
  Receiver := TReceiver.Create;
  FillChar(Info, SizeOf(Info), 0);
  Info.hInstance := HInstance; Info.lpfnWndProc := @WindowProc;
  Info.lpszClassName := 'CalmiraMessageTest';
  Check(RegisterClass(Info), 'register native window');
  Window := CreateWindow('CalmiraMessageTest', 'Message ABI test', WS_OVERLAPPEDWINDOW,
    0, 0, 100, 80, 0, 0, HInstance, nil);
  Check(Window <> 0, 'create native window');
  if Window <> 0 then
  begin
    Testing := True;
    Check(SendMessage(Window, WM_COMMAND, $1234, LongInt($9ABC5678)) = $12345678,
      'message directive dispatch and 32-bit result');
    Check(SendMessage(Window, WM_VSCROLL, SB_THUMBTRACK, LongInt($8765CFC7)) = 234567,
      'scroll return');
    Check(SendMessage(Window, WM_ACTIVATE, WA_ACTIVE, $00014321) = 345678,
      'activate return');
    Check(SendMessage(Window, WM_LBUTTONDOWN, MK_SHIFT, LongInt($FFECFFF6)) = 456789,
      'mouse return');
    FillChar(Limits, SizeOf(Limits), 0);
    Check(SendMessage(Window, WM_GETMINMAXINFO, 0, LongInt(@Limits)) = 567890,
      'far structure pointer return');
    Check(Limits.ptMaxSize.X = 321, 'far structure pointer mutation');
    Check(SendMessage(Window, $F123, $FFFF, -7654321) = -1234567,
      'high message ID and negative 32-bit return');
    Testing := False;
    DestroyWindow(Window);
    Check(Calls = 6, 'six typed handlers called');
  end;
  Receiver.Free;
  if Failed then WriteLn(Log, 'RESULT FAIL') else WriteLn(Log, 'RESULT PASS');
  CloseFile(Log);
  if Failed then Halt(1);
end.
