{ SPDX-License-Identifier: GPL-2.0-or-later
  The TOOLHELP.DLL subset Calmira uses: task termination and the VM timer. }
unit ToolHelp;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This ToolHelp unit requires Win16}{$ENDIF}
interface
uses WinTypes;
type
  PTimerInfo = ^TTimerInfo;
  TTimerInfo = record
    dwSize: LongInt;
    dwmsSinceStart: LongInt;
    dwmsThisVM: LongInt;
  end;
const
  UAE_BOX = 0;
  NO_UAE_BOX = 1;
function TimerCount(lpTimer: PTimerInfo): Bool; external 'TOOLHELP';
procedure TerminateApp(hTask: THandle; wFlags: Word); external 'TOOLHELP';
implementation
end.
