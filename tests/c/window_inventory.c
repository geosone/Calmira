/* SPDX-License-Identifier: GPL-3.0-or-later
 * Disposable-VM diagnostic. Records visible window classes and child IDs;
 * never sends private control messages or changes another application's UI. */
#include <windows.h>
#include <stdio.h>
#include <string.h>

static FILE *output;
static char window_class[] = "CalmiraWindowInventory";

static void record(HWND window)
{
    char cls[96], text[160], direct[160], module[128];
    RECT rect;
    int i;
    cls[0] = text[0] = module[0] = 0;
    GetClassName(window, cls, sizeof(cls));
    GetWindowText(window, text, sizeof(text));
    direct[0] = 0;
    SendMessage(window, WM_GETTEXT, sizeof(direct), (LPARAM)(LPSTR)direct);
    direct[sizeof(direct) - 1] = 0;
    GetModuleFileName((HINSTANCE)GetWindowWord(window, GWW_HINSTANCE),
                      module, sizeof(module));
    for (i = 0; text[i]; i++)
        if ((unsigned char)text[i] < 32) text[i] = ' ';
    for (i = 0; direct[i]; i++)
        if ((unsigned char)direct[i] < 32) direct[i] = ' ';
    GetWindowRect(window, &rect);
    fprintf(output, "%04x parent=%04x id=%u class=%s module=%s "
        "rect=%d,%d,%d,%d text=%s direct=%s\n", (unsigned)window,
        (unsigned)GetParent(window), (unsigned)GetWindowWord(window, GWW_ID),
        cls, module, rect.left, rect.top, rect.right, rect.bottom, text, direct);
}

BOOL CALLBACK __export __loadds InventoryChild(HWND window, LPARAM unused)
{
    (void)unused;
    if (IsWindowVisible(window)) record(window);
    return TRUE;
}

BOOL CALLBACK __export __loadds InventoryTop(HWND window, LPARAM unused)
{
    (void)unused;
    if (IsWindowVisible(window)) {
        record(window);
        EnumChildWindows(window, InventoryChild, 0);
    }
    return TRUE;
}

LRESULT CALLBACK __export __loadds InventoryProc(HWND window, UINT message,
                                                WPARAM wp, LPARAM lp)
{
    if (message == WM_TIMER) {
        output = fopen("C:\\WINTREE.LOG", "w");
        if (output) {
            EnumWindows(InventoryTop, 0);
            fclose(output);
            output = NULL;
        }
        return 0;
    }
    if (message == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProc(window, message, wp, lp);
}

int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    WNDCLASS cls;
    HWND window;
    MSG message;
    (void)previous; (void)show;
    memset(&cls, 0, sizeof(cls));
    cls.hInstance = instance;
    cls.lpfnWndProc = InventoryProc;
    cls.lpszClassName = window_class;
    if (!RegisterClass(&cls)) return 1;
    window = CreateWindow(window_class, "Window inventory (test only)",
                          WS_OVERLAPPEDWINDOW, 0, 0, 240, 80,
                          NULL, NULL, instance, NULL);
    if (!window || !SetTimer(window, 1, 2000, NULL)) return 2;
    if (command[0] && WinExec(command, SW_SHOW) < 32) return 3;
    while (GetMessage(&message, NULL, 0, 0)) {
        TranslateMessage(&message);
        DispatchMessage(&message);
    }
    return 0;
}
