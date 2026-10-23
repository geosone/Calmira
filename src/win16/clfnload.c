/* SPDX-License-Identifier: GPL-3.0-or-later
 * Explicit, reversible resident loader for native compatibility testing.
 * This is not installed automatically and does not replace Windows files. */
#include <windows.h>
#include <string.h>

typedef BOOL (WINAPI *HOOK_ACTION)(void);
typedef WORD (WINAPI *HOOK_POLL)(void);
static HOOK_ACTION stop_hook;
static HOOK_POLL poll_saves;
static HINSTANCE library;
static char window_class[] = "OpenLFNLoader";

LRESULT CALLBACK __export __loadds LoaderProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    if (message == WM_COMMAND && wp == 1) {
        SendMessage(window, WM_CLOSE, 0, 0);
        return 0;
    }
    if (message == WM_TIMER && wp == 1) {
        if (poll_saves) poll_saves();
        return 0;
    }
    if (message == WM_CLOSE) {
        if (stop_hook && !stop_hook()) {
            MessageBox(window, "A save is still pending, or another subclass references the hook.\n"
                "Finish/close the saving application and try again.\n"
                "An interrupted transaction may need CLFN.SAV/BAK/NEW recovery.",
                "OpenLFN Loader remains loaded", MB_OK | MB_ICONEXCLAMATION);
            return 0;
        }
        KillTimer(window, 1);
        DestroyWindow(window);
        return 0;
    }
    if (message == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(window, message, wp, lp);
}

int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    char path[128];
    int length, separator;
    WNDCLASS cls;
    HWND window;
    MSG message;
    HOOK_ACTION start_hook;
    WNDPROC procedure;
    (void)show;
    if (GetModuleHandle("CLFNHOOK")) {
        MessageBox(NULL, "Stop the previous file-dialog hook before starting OpenLFN Loader.",
            "OpenLFN Loader", MB_OK | MB_ICONEXCLAMATION);
        return 1;
    }
    if (previous || FindWindow(window_class, NULL)) {
        MessageBox(NULL, "The LFN hook loader is already running.", "OpenLFN Loader", MB_OK);
        return 1;
    }
    length = GetModuleFileName(instance, path, sizeof(path));
    if (!length || length >= sizeof(path)) return 2;
    separator = length;
    while (separator && path[separator - 1] != '\\' && path[separator - 1] != '/') separator--;
    if (separator + 13 > sizeof(path)) return 2;
    lstrcpy(path + separator, "OLFNHOOK.DLL");
    library = LoadLibrary(path);
    if ((UINT)library < 32) {
        MessageBox(NULL, "Cannot load OLFNHOOK.DLL beside OLFNLOAD.EXE.", "OpenLFN Loader", MB_OK);
        return 2;
    }
    start_hook = (HOOK_ACTION)GetProcAddress(library, "STARTFILEDIALOGHOOK");
    stop_hook = (HOOK_ACTION)GetProcAddress(library, "STOPFILEDIALOGHOOK");
    poll_saves = (HOOK_POLL)GetProcAddress(library, "POLLFILEDIALOGSAVES");
    if (!start_hook || !stop_hook || !poll_saves || !start_hook()) {
        MessageBox(NULL, "Cannot install the global file-dialog hook.", "OpenLFN Loader", MB_OK);
        FreeLibrary(library);
        return 2;
    }
    _fmemset(&cls, 0, sizeof(cls));
    procedure = (WNDPROC)MakeProcInstance((FARPROC)LoaderProc, instance);
    cls.hInstance = instance;
    cls.lpfnWndProc = procedure;
    cls.lpszClassName = window_class;
    cls.hCursor = LoadCursor(NULL, IDC_ARROW);
    cls.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    window = NULL;
    if (RegisterClass(&cls)) {
        window = CreateWindow(window_class, "OpenLFN Loader (experimental)",
            WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
            20, 20, 320, 130, NULL, NULL, instance, NULL);
    }
    if (!window) {
        stop_hook();
        FreeProcInstance((FARPROC)procedure);
        FreeLibrary(library);
        return 2;
    }
    CreateWindow("STATIC", "Long-name Save uses queued mapping.\n"
        "Keep this loader running until saves finish.", WS_CHILD | WS_VISIBLE,
        12, 10, 290, 34, window, NULL, instance, NULL);
    CreateWindow("BUTTON", "Stop hook and exit", WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        75, 56, 160, 24, window, (HMENU)1, instance, NULL);
    ShowWindow(window, SW_SHOW);
    UpdateWindow(window);
    if (!SetTimer(window, 1, 250, NULL)) {
        SendMessage(window, WM_CLOSE, 0, 0);
        FreeProcInstance((FARPROC)procedure);
        FreeLibrary(library);
        return 2;
    }
    if (*command && WinExec(command, SW_SHOW) < 32)
        MessageBox(window, "Could not start the requested application.", "OpenLFN Loader", MB_OK);
    while (GetMessage(&message, NULL, 0, 0)) {
        TranslateMessage(&message);
        DispatchMessage(&message);
    }
    FreeProcInstance((FARPROC)procedure);
    FreeLibrary(library);
    return 0;
}
