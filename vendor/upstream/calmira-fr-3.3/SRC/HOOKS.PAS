{**************************************************************************}
{                                                                          }
{    Calmira II shell pour Microsoft® Windows(TM) 3.1                      }
{    Version française 3.3                                                 }
{    Copyright (C) 2000-2002 Jean Blanchard                                }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ce programme est libre ; vous pouvez le redistribuer et/ou le         }
{    modifier selon les termes de la Licence Publique Générale GNU telle   }
{   que publiée par la Free Software Foundation ; version 2 de la licence  }
{    ou (au choix) n'importe quelle version plus récente.                  }
{                                                                          }
{    Ce programme est distibué dans l'espoir qu'il sera utile, mais SANS   }
{    AUCUNE GARANTIE ; sans même la garantie implicite de                  }
{    COMMERCIALISATION ou d'APTITUDE A UN USAGE PARTICULIER. Voir la       }
{    licence publique générale pour plus de détails.                                        }
{                                                                          }
{    Vous devriez avoir reçue une copie de la licence publique générale    }
{    avec ce programme; si ce n'est pas le cas, écrivez à la Free          }
{    Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.    }
{                                                                          }
{--------------------------------------------------------------------------}

unit Hooks;

{ This unit declares the WndHooks.dll interface }

interface

uses WinTypes, Messages;

var
  StartTaskMonitor    : procedure;
  StopTaskMonitor     : procedure;
  SetWndHook          : procedure;
  UnhookWndHook       : procedure;
  SetYLimit           : procedure(yt: Integer; y: Integer);
  StartMouseMonitor   : procedure;
  StopMouseMonitor    : procedure;
  EnableMouseMonitor  : procedure;
  DisableMouseMonitor : procedure;
  SetCallBackWnd      : procedure(Wnd: HWND);
  SetMaxEnabled       : procedure(value: Boolean);
  SetRCloseEnabled    : procedure(Enable: Boolean);
  SetDesktopHook      : procedure(CallBack: HWND);
  ReleaseDesktopHook  : procedure;
  SetKeyboardHook     : procedure(CallBack: HWND);
  ReleaseKeyboardHook : procedure;
  SetRButtonUpClose   : procedure(Value: Boolean);
  IsHotKey            : function(wParam: Word; lParam: Longint): Boolean;
  SetWin95KeyEnabled  : procedure(value: Boolean);
  { 3.2 }
  StartFileMonitor    : function(CallBack: HWND): Boolean;
  StopFileMonitor     : procedure;

implementation

uses SysUtils, WinProcs, Files;

const
  WndHooks = 'WNDHOOKS.DLL';

var
  WndHookDLL: THandle;

procedure LinkLibrary;
var
  buf: array[0..79] of Char;
begin
  { Load the Windows hook DLL and obtain pointers to the procedures we need }
  WndHookDLL := LoadLibrary(StrPCopy(buf, ApplicationPath + WndHooks));
  @StartTaskMonitor    := GetProcAddress(WndHookDLL, 'STARTTASKMONITOR');
  @StopTaskMonitor     := GetProcAddress(WndHookDLL, 'STOPTASKMONITOR');
  @SetWndHook          := GetProcAddress(WndHookDLL, 'SETWNDHOOK');
  @UnhookWndHook       := GetProcAddress(WndHookDLL, 'UNHOOKWNDHOOK');
  @SetYLimit           := GetProcAddress(WndHookDLL, 'SETYLIMIT');
  @StartMouseMonitor   := GetProcAddress(WndHookDLL, 'STARTMOUSEMONITOR');
  @StopMouseMonitor    := GetProcAddress(WndHookDLL, 'STOPMOUSEMONITOR');
  @EnableMouseMonitor  := GetProcAddress(WndHookDLL, 'ENABLEMOUSEMONITOR');
  @DisableMouseMonitor := GetProcAddress(WndHookDLL, 'DISABLEMOUSEMONITOR');
  @SetCallBackWnd      := GetProcAddress(WndHookDLL, 'SETCALLBACKWND');
  @SetMaxEnabled       := GetProcAddress(WndHookDLL, 'SETMAXENABLED');
  @SetRCloseEnabled    := GetProcAddress(WndHookDLL, 'SETRCLOSEENABLED');
  @SetDesktopHook      := GetProcAddress(WndHookDLL, 'SETDESKTOPHOOK');
  @ReleaseDesktopHook  := GetProcAddress(WndHookDLL, 'RELEASEDESKTOPHOOK');
  @SetKeyboardHook     := GetProcAddress(WndHookDLL, 'STARTKEYBOARDHOOK');
  @ReleaseKeyboardHook := GetProcAddress(WndHookDLL, 'STOPKEYBOARDHOOK');
  @SetRButtonUpClose   := GetProcAddress(WndHookDLL, 'SETRBUTTONUPCLOSE');
  @IsHotKey            := GetProcAddress(WndHookDLL, 'ISHOTKEY');
  @SetWin95KeyEnabled  := GetProcAddress(WndHookDLL, 'SETWIN95KEYENABLED');
  @StartFileMonitor    := GetProcAddress(WndHookDLL, 'STARTFILEMONITOR');
  @StopFileMonitor     := GetProcAddress(WndHookDLL, 'STOPFILEMONITOR');
end;

procedure DoneLibrary; far;
begin
  FreeLibrary(WndHookDLL);
end;

initialization
  LinkLibrary;
  AddExitProc(DoneLibrary);
end.

