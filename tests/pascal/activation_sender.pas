{ Independent visible Win16 task; exercises real USER task activation. }
program ActivationSender;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs;
const ReadyMessage = WM_USER + 231; FinishedMessage = WM_USER + 232;
var Info: TWndClass; Window, Target: HWND; Reply: LongInt;
function WindowProc(Window: HWND; Id: UINT; WP: WPARAM; LP: LPARAM): LRESULT; export;
begin Result := DefWindowProc(Window, Id, WP, LP); end;
begin
  FillChar(Info, SizeOf(Info), 0); Info.hInstance := HInstance;
  Info.lpfnWndProc := @WindowProc; Info.lpszClassName := 'CalmiraActivationPeer';
  if not RegisterClass(Info) then Halt(1);
  Window := CreateWindow(Info.lpszClassName, 'Independent activation peer',
    WS_OVERLAPPEDWINDOW, 300, 180, 250, 120, 0, 0, HInstance, nil);
  if Window = 0 then Halt(2);
  ShowWindow(Window, SW_SHOWNORMAL); SetActiveWindow(Window); UpdateWindow(Window);
  Target := FindWindow('TApplication', 'Calmira');
  if Target <> 0 then
  begin
    Reply := SendMessage(Target, ReadyMessage, Window, LongInt(GetCurrentTask));
    SendMessage(Target, FinishedMessage, Window, Reply);
  end;
  DestroyWindow(Window);
end.
