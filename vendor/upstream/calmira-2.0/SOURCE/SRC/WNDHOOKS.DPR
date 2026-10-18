{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.0                                                    }
{    Copyright (C) 1997  Li-Hsin Huang                                     }
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

library WndHooks;

{$C FIXED}

{ Calmira's Windows hooks and other low level stuff.

  This DLL implements:

  Shell hook - detects and reports top-level windows being created or
    destroyed (perfect for a taskbar)

  WndProc hook - detects and reports WM_ACTIVATE messages sent to
    any window.  Detects user maximizing a window, and can adjust its
    size so as not to overlap with the taskbar.

  Mouse hook - detects and reports WM_MOUSEMOVE messages sent to
    any window (used by taskbar to hide after the cursor has moved off).
    Also detects WM_NCRBUTTONDOWN so that right clicks on minimize or
    maximize boxes can be used to close a window.

  Desktop WndProc - detects and reports the user right clicking on
    the desktop, so that host program can display a popup menu.

  Thanks to Ralf Scheiner for the code to constrain maximized windows.
}

uses WinProcs, WinTypes, Messages, CalMsgs;

type
  LongRec = record
    Lo, Hi: Word;
  end;

const
  MaxEnabled : Boolean = False;
  MouseEnabled : Boolean = False;
  RCloseEnabled : Boolean = False;
  RButtonUpClose : Boolean = True;

var
  CallBackWnd : HWND;

  TaskHook  : HHook;
  WndHook   : HHook;
  MouseHook : HHook;

  ScreenWidth, ScreenHeight, YLimit: Integer;


  DeskWndProc : TFarProc;
  DeskCallBack: HWND;

  KeyHook     : HHook;
  KeyCallBack : HWND;


{ shell hook }

function ShellProc(Code : Integer; wParam: Word; lParam: Longint): Longint; export;
begin
  case Code of
  HSHELL_WINDOWCREATED   : PostMessage(CallbackWnd, WM_SHELLWNDCREATE, wParam, lParam);
  HSHELL_WINDOWDESTROYED : PostMessage(CallBackWnd, WM_SHELLWNDDESTROY, wParam, lParam);
  end;
  Result := CallNextHookEx(TaskHook, Code, wParam, lParam);
end;


procedure StopTaskMonitor; export;
begin
  if TaskHook > 0 then UnhookWindowsHookEx(TaskHook);
  TaskHook := 0;
end;

procedure StartTaskMonitor; export;
begin
  StopTaskMonitor;
  TaskHook := SetWindowsHookEx(WH_SHELL, ShellProc, HInstance, 0);
end;


{ WndProc hook }

function WndProcHook(code: integer; wParam:word; lParam:Longint):LongInt; export;
type
  PHookMsg=^THookMsg;

  THookMsg=record
   lParam: Longint;
   wParam: Word;
   uMsg: Word;
   hWnd: THandle;
  end;
var
  Wnd: HWnd;
begin
  if code >= 0 then with PHookMsg(lParam)^ do

    if MaxEnabled and (uMsg = WM_WINDOWPOSCHANGING) then begin
      { Adjust size of maximized window }
      with pWindowPos(lParam)^ do
        if (Y+cY>ScreenHeight+2) and (X+cX>ScreenWidth+2) then begin
          cY := YLimit - Y;
          if GetWindowLong(HWnd, GWL_STYLE) and WS_THICKFRAME > 0 then
            Inc(cY, GetSystemMetrics(SM_CYFRAME))
          else
            Inc(cY);
        end;
    end
    else if MaxEnabled and (uMsg = WM_SYSCOMMAND) and (wParam = SC_MOVE + 2) and
      IsZoomed(HWnd) then begin
      wParam := 0;
      lParam := 0;
    end

    else if (uMsg = WM_ACTIVATE) and (CallBackWnd > 0) then
      { inform host program about activation message }
      case wParam of
        WA_INACTIVE    : if Bool(LongRec(lParam).Hi) then
                         SendMessage(CallBackWnd, WM_HIDEQUERY, hWnd, 0);
        WA_ACTIVE      : SendMessage(CallBackWnd, WM_WINACTIVE, hWnd, 1);
        WA_CLICKACTIVE : SendMessage(CallBackWnd, WM_WINACTIVE, hWnd, 1);
      end;

  Result := CallNextHookEx(WndHook,Code,wParam,lParam);
end;

procedure SetYLimit(y: Integer); export;
begin
   YLimit := y;
end;

procedure UnhookWndHook; export;
begin
  if WndHook> 0 then UnHookWindowsHookEx(WndHook);
  WndHook:= 0;
end;

procedure SetWndHook; export;
begin
  UnhookWndHook;
  WndHook := SetWindowsHookEx(WH_CallWndProc,WndProcHook,hInstance,0);
end;

{ Mouse hook }

function MouseProc(Code : Integer; wParam: Word; lParam: Longint): Longint; export;
const
  ButtonUp : array[Boolean] of Word = (WM_NCRBUTTONDOWN, WM_NCRBUTTONUP);
var
  y: Integer;
begin
  if MouseEnabled and (wParam = WM_MOUSEMOVE) then begin
    { inform host about mouse movement }
    y := TMouseHookStruct(Pointer(lParam)^).Pt.y;
    if y < YLimit then SendMessage(CallbackWnd, WM_MOUSEHOOK, y, 0);
    { PostMessage() crashes Alt-Tab }
  end

  else if RCloseEnabled and (wParam = ButtonUp[RButtonUpClose]) then begin
    { close the window if right click on minimize/maximize boxes }
    with TMouseHookStruct(Pointer(lParam)^) do
      if (wHitTestCode = HTMAXBUTTON) or (wHitTestCode = HTMINBUTTON) then begin
        Result := 1;
        PostMessage(hWnd, WM_CLOSE, 0, 0);
        Exit;
      end;
  end;

  Result := CallNextHookEx(MouseHook, Code, wParam, lParam);
end;


procedure StopMouseMonitor; export;
begin
  if MouseHook > 0 then UnhookWindowsHookEx(MouseHook);
  MouseHook := 0;
end;

procedure StartMouseMonitor; export;
begin
  StopMouseMonitor;
  MouseHook := SetWindowsHookEx(WH_MOUSE, MouseProc, HInstance, 0);
end;

procedure EnableMouseMonitor; export;
begin
  MouseEnabled := True;
end;

procedure DisableMouseMonitor; export;
begin
  MouseEnabled := False;
end;

procedure SetRButtonUpClose(value: Boolean); export;
begin
  RButtonUpClose := value;
end;


procedure SetCallBackWnd(Wnd: HWND); export;
begin
  CallBackWnd := Wnd;
end;

procedure SetMaxEnabled(value : Boolean); export;
begin
  MaxEnabled := value;
end;

{ Desktop window procedure to catch right clicks }

function NewDeskWndProc(Handle: HWND; Msg: Word; wParam: Word;
  lParam: Longint): Longint; export;
const
  MouseButtons : array[Boolean] of Word = (VK_LBUTTON, VK_RBUTTON);
begin
  if (Msg = WM_RBUTTONDOWN) then
    if GetAsyncKeyState(
      MouseButtons[Bool(GetSystemMetrics(SM_SWAPBUTTON))]) < 0 then

      PostMessage(DeskCallBack, WM_DESKACTIVATE, wParam, lParam)
    else
      PostMessage(DeskCallBack, WM_DESKMENU, wParam, lParam);

  Result := CallWindowProc(DeskWndProc, Handle, Msg, wParam, lParam);
end;

procedure ReleaseDesktopHook; export;
begin
  { restore Windows's wndproc }
  if DeskWndProc <> nil then begin
    SetWindowLong(GetDesktopWindow, GWL_WNDPROC, Longint(DeskWndProc));
    DeskWndProc := nil;
  end;
end;

procedure SetDesktopHook(CallBack : HWND); export;
begin
  { replace desktop wndproc with our one }
  ReleaseDesktopHook;
  DeskCallback := CallBack;
  DeskWndProc := Pointer(SetWindowLong(GetDesktopWindow, GWL_WNDPROC,
    Longint(@NewDeskWndProc)));
end;


{ Right click on min/max buttons to close }

procedure SetRCloseEnabled(value : Boolean); export;
begin
  RCloseEnabled := value;
end;

function IsHotKey(wParam : Word; lParam: Longint): Boolean; export;
const
  AltMask = $20000000; { forms.pas }
begin
  {
    The key is not Ctrl, Alt or Shift
    The key is being pressed, not released
    This is not typematic key repeat
    Two or more keys out of [Ctrl, Alt, Shift] are pressed
  }
  Result := (LoWord(lParam) = 1) and (lParam >= 0) and
   (wParam <> VK_CONTROL) and (wParam <> VK_MENU) and (wParam <> VK_SHIFT) and
   (Ord(lParam and AltMask <> 0) + Ord(GetKeyState(VK_CONTROL) < 0) +
    Ord(GetKeyState(VK_SHIFT) < 0) >= 2)
end;

{ Keyboard hook }

function KeyboardProc(code : Integer; wParam : Word; lParam: Longint): Longint; export;
begin
  Result := 0;

  if (code >= 0) and IsHotKey(wParam, lParam)then
    Result := SendMessage(KeyCallBack, WM_KEYBOARDHOOK, wParam, lParam);

  if CallNextHookEx(KeyHook, code, wParam, lParam) > 0 then Result := 1;
end;

procedure StopKeyboardHook; export;
begin
  if KeyHook > 0 then UnhookWindowsHookEx(KeyHook);
  KeyHook := 0;
end;

procedure StartKeyboardHook(CallBack: HWND); export;
begin
  StopKeyboardHook;
  KeyCallBack := CallBack;
  KeyHook := SetWindowsHookEx(WH_KEYBOARD, KeyboardProc, HInstance, 0);
end;


exports
  StartTaskMonitor index 1,
  StopTaskMonitor index 2,
  SetWndHook index 3,
  UnhookWndHook index 4,
  SetYLimit index 5,
  StartMouseMonitor index 6,
  StopMouseMonitor index 7,
  EnableMouseMonitor index 8,
  DisableMouseMonitor index 9,
  SetCallBackWnd index 10,
  SetMaxEnabled index 11,
  SetRCloseEnabled index 12,
  SetDesktopHook index 13,
  ReleaseDesktopHook index 14,
  StartKeyboardHook index 15,
  StopKeyboardHook index 16,
  SetRButtonUpClose index 17,
  IsHotKey index 18;

begin
  ScreenWidth := GetSystemMetrics(SM_CXSCREEN);
  ScreenHeight := GetSystemMetrics(SM_CYSCREEN);
  YLimit := ScreenHeight - 32;
end.
