{ Independent Win16 task using the original Calmira discovery/message contract. }
program ApplicationSender;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, CalMsgs;
var Target: HWND; Reply: LongInt;
begin
  Target := FindWindow('TApplication', 'Calmira');
  if Target <> 0 then
  begin
    Reply := SendMessage(Target, WM_CALMIRA, CM_PREVINSTANCE, LongInt(GetCurrentTask));
    PostMessage(Target, WM_CALMIRA, CM_TOGGLEDESKTOP, Reply);
  end;
end.
