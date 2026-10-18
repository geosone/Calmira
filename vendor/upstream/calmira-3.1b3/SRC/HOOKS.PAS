{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-2000 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    This program is free software; you can redistribute it and/or modify  }
{    it under the terms of the GNU General Public License as published by  }
{    the Free Software Foundation; either version 2 of the License, or     }
{    (at your option) any later version.                                   }
{                                                                          }
{    This program is distributed in the hope that it will be useful,       }
{    but WITHOUT ANY WARRANTY; without even the implied warranty of        }
{    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         }
{    GNU General Public License for more details.                          }
{                                                                          }
{    You should have received a copy of the GNU General Public License     }
{    along with this program; if not, write to the Free Software           }
{    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.             }
{                                                                          }
{**************************************************************************}

unit Hooks;

interface

uses WinTypes, Messages, CalMsgs;

var
  { Used by Computer }
  SetDesktopHook      : procedure(CallBack: HWND);
  ReleaseDesktopHook  : procedure;
  SetRCloseEnabled    : procedure(Enable: Boolean);
  SetKeyboardHook     : procedure(CallBack: HWND);
  ReleaseKeyboardHook : procedure;
  SetRButtonUpClose   : procedure(Value : Boolean);
  IsHotKey            : function(wParam : Word; lParam: Longint): Boolean;
  { Used by Taskbar }
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
  SetWin95KeyEnabled  : procedure(value: Boolean);

implementation

uses SysUtils, WinProcs, Files;

var
  { DLL module instance and procedure pointers }
  WndHookDLL: THandle;

procedure LinkLibrary;
var
  buf: array[0..79] of Char;
begin
  { Load the Windows hook DLL and obtain pointers to the procedures we need }
  WndHookDLL := LoadLibrary(StrPCopy(buf, ApplicationPath + 'wndhooks.dll'));
  @SetDesktopHook      := GetProcAddress(WndHookDLL, 'SETDESKTOPHOOK');
  @ReleaseDesktopHook  := GetProcAddress(WndHookDLL, 'RELEASEDESKTOPHOOK');
  @SetRCloseEnabled    := GetProcAddress(WndHookDLL, 'SETRCLOSEENABLED');
  @SetKeyboardHook     := GetProcAddress(WndHookDLL, 'STARTKEYBOARDHOOK');
  @ReleaseKeyboardHook := GetProcAddress(WndHookDLL, 'STOPKEYBOARDHOOK');
  @SetRButtonUpClose   := GetProcAddress(WndHookDLL, 'SETRBUTTONUPCLOSE');
  @IsHotKey            := GetProcAddress(WndHookDLL, 'ISHOTKEY');
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
  @SetWin95KeyEnabled  := GetProcAddress(WndHookDLL, 'SETWIN95KEYENABLED');
end;

procedure UnlinkLibrary; far;
begin
  FreeLibrary(WndHookDLL);
end;

initialization
  LinkLibrary;
  AddExitProc(UnlinkLibrary);
end.

