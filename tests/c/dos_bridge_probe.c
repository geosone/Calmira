/* SPDX-License-Identifier: GPL-3.0-or-later
 * Diagnostic only: launch a requested DOS child, without the viewer's guard.
 * Use exclusively in disposable VMs; a broken host may fault. */
#include <windows.h>
#include <stdio.h>
#include <string.h>
static UINT child;
static unsigned ticks;
LRESULT CALLBACK __export __loadds BridgeProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    if (message == WM_TIMER) {
        FILE *log = fopen("C:\\BRIDGE.LOG", "a");
        if (log) {
            fprintf(log, "tick=%u child_usage=%u\n", ++ticks,
                child >= 32 ? GetModuleUsage((HINSTANCE)child) : 0);
            fclose(log);
        }
        if (ticks >= 10) { KillTimer(window, 1); DestroyWindow(window); PostQuitMessage(0); }
        return 0;
    }
    return DefWindowProc(window, message, wp, lp);
}
int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    FILE *log;
    WNDCLASS cls;
    HWND window;
    MSG message;
    (void)previous; (void)show;
    memset(&cls, 0, sizeof(cls)); cls.hInstance = instance;
    cls.lpszClassName = "OpenLFN.DosBridgeProbe"; cls.lpfnWndProc = BridgeProc;
    if (!RegisterClass(&cls)) return 2;
    window = CreateWindow(cls.lpszClassName, "DOS bridge diagnostic (disposable VM only)",
        WS_OVERLAPPEDWINDOW, 0, 0, 250, 90, NULL, NULL, instance, NULL);
    if (!window || !SetTimer(window, 1, 500, NULL)) return 2;
    log = fopen("C:\\BRIDGE.LOG", "w"); if (!log) return 2;
    fprintf(log, "version=%08lx flags=%08lx command=%s\n", GetVersion(), GetWinFlags(), command);
    fclose(log);
    child = WinExec(command, SW_HIDE);
    log = fopen("C:\\BRIDGE.LOG", "a"); if (!log) return 2;
    fprintf(log, "WinExec=%u\n", child); fclose(log);
    while (GetMessage(&message, NULL, 0, 0)) { TranslateMessage(&message); DispatchMessage(&message); }
    return 0;
}
