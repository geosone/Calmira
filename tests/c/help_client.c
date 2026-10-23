/* SPDX-License-Identifier: GPL-3.0-or-later */
#include <windows.h>
#include <string.h>
static unsigned ticks;
static int found;
static void log_line(const char *line, int fresh)
{
    HFILE file = fresh ? _lcreat("C:\\HELPTEST.LOG", 0) : _lopen("C:\\HELPTEST.LOG", OF_WRITE);
    if (file == HFILE_ERROR) return;
    if (!fresh) _llseek(file, 0, 2);
    _lwrite(file, line, strlen(line));
    _lclose(file);
}
BOOL CALLBACK __export __loadds inspect(HWND window, LPARAM unused)
{
    char title[160];
    (void)unused;
    GetWindowText(window, title, sizeof(title));
    if (strstr(title, "Calmira Reloaded") && IsWindowVisible(window)) found = 1;
    return TRUE;
}
LRESULT CALLBACK __export __loadds procedure(HWND window, UINT msg, WPARAM wp, LPARAM lp)
{
    if (msg == WM_TIMER && ++ticks == 4) {
        EnumWindows(inspect, 0);
        log_line(found ? "RESULT PASS\r\n" : "RESULT FAIL\r\n", 0);
        KillTimer(window, 1);
        return 0;
    }
    return DefWindowProc(window, msg, wp, lp);
}
int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR args, int show)
{
    WNDCLASS cls;
    HWND window;
    MSG msg;
    BOOL okay;
    DWORD context;
    UINT command;
    (void)previous; (void)show;
    memset(&cls, 0, sizeof(cls));
    cls.hInstance = instance; cls.lpfnWndProc = procedure; cls.lpszClassName = "Calmira.HelpTest";
    if (!RegisterClass(&cls)) return 2;
    window = CreateWindow(cls.lpszClassName, "Help test", WS_OVERLAPPEDWINDOW,
        0, 0, 100, 80, NULL, NULL, instance, NULL);
    if (!window || !SetTimer(window, 1, 1000, NULL)) return 2;
    command = HELP_CONTEXT;
    switch (*args) {
    case 'C': command = HELP_CONTENTS; context = 0; break;
    case 'B': command = HELP_KEY; context = (DWORD)(LPSTR)"custom bitmaps"; break;
    case 'M': context = 21; break;
    case 'W': context = 201; break;
    case 'R': context = 900; break;
    case 'Q': context = 901; break;
    case 'G': context = 902; break;
    case 'T': context = 903; break;
    default: return 2;
    }
    okay = WinHelp(window, "C:\\CALMIRA.HLP", command, context);
    log_line(okay ? "HELP_CALL=1\r\n" : "HELP_CALL=0\r\n", 1);
    while (GetMessage(&msg, NULL, 0, 0)) { TranslateMessage(&msg); DispatchMessage(&msg); }
    return 0;
}
