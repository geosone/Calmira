program CTaskMan;

{$R *.RES}

uses WinTypes, WinProcs, CalMsgs;

begin
  if FindWindow('TApplication', 'Calmira') = 0 then
    WinExec('taskman.exe', SW_SHOW)
  else
    PostMessage(HWND_BROADCAST, WM_CALMIRA, CM_TASKMAN, 0);
end.