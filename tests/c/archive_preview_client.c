/* SPDX-License-Identifier: GPL-3.0-or-later
 * Native acceptance: ordinary COMMDLG -> system menu -> separate viewer task.
 * Observes only documented listbox/window APIs; no private media required. */
#include <windows.h>
#include <commdlg.h>
#include <stdio.h>
#include <string.h>
typedef BOOL (WINAPI *HOOK_ACTION)(void);
static FILE *log_file;
static int stage, failures, blocked;
static DWORD started;
static HMODULE old_dos_module;
static void check(int okay, const char *name)
{
    fprintf(log_file, "%s %s\n", okay ? "PASS" : "FAIL", name);
    fflush(log_file); if (!okay) failures++;
}
static void test_explicit_loader(void)
{
    UINT task = WinExec("C:\\OLFNLOAD.EXE", SW_SHOW);
    DWORD until = GetTickCount() + 4000UL;
    HWND loader = NULL;
    MSG message;
    char title[100];
    check(task >= 32, "independent OpenLFN loader starts");
    while (task >= 32 && GetTickCount() < until && !loader) {
        while (PeekMessage(&message, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&message); DispatchMessage(&message);
        }
        Yield(); loader = FindWindow("OpenLFNLoader", NULL);
    }
    title[0] = 0;
    if (loader) GetWindowText(loader, title, sizeof(title));
    check(loader && strstr(title, "OpenLFN Loader") && !strstr(title, "Calmira"),
        "resident loader has independent product title");
    if (loader) PostMessage(loader, WM_CLOSE, 0, 0);
    until = GetTickCount() + 4000UL;
    while (task >= 32 && GetModuleUsage((HINSTANCE)task) && GetTickCount() < until) {
        while (PeekMessage(&message, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&message); DispatchMessage(&message);
        }
        Yield();
    }
    check(!FindWindow("OpenLFNLoader", NULL) && !GetModuleHandle("OLFNHOOK"),
        "explicit stop unloads loader and hook before reuse");
}
LRESULT CALLBACK __export __loadds PreviewTestProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    if (message == WM_TIMER) {
        HWND dialog = FindWindow(NULL, "Archive preview acceptance");
        HWND viewer = FindWindow("OpenLFN.ArchiveViewer.1", NULL);
        if (GetTickCount() - started > 12000UL) {
            check(0, "archive preview timed out");
            if (dialog) PostMessage(dialog, WM_COMMAND, IDCANCEL, 0);
            KillTimer(window, 1); return 0;
        }
        if (!dialog) return 0;
        if (!stage) {
            HMENU menu = GetSystemMenu(dialog, FALSE);
            check(menu && GetMenuState(menu, 0x6f30, MF_BYCOMMAND) != (UINT)-1,
                "standard dialog exposes read-only archive command");
            SetDlgItemText(dialog, 0x0480, "C:\\DEFLATE.ZIP");
            PostMessage(dialog, WM_SYSCOMMAND, 0x6f30, 0);
            stage = 1; return 0;
        }
        if (stage == 1 && blocked) {
            HWND warning = FindWindow(NULL, "OpenLFN archive viewer");
            if (warning) {
                check(GetModuleHandle("WINOLDAP") == old_dos_module, "unsupported host starts no DOS session");
                PostMessage(warning, WM_COMMAND, IDOK, 0);
                stage = 2;
            }
        } else if (stage == 1 && viewer) {
            HWND list = GetDlgItem(viewer, 100), status = GetDlgItem(viewer, 101);
            char text[160];
            if (SendMessage(list, LB_GETCOUNT, 0, 0) != 2) return 0;
            SendMessage(list, LB_GETTEXT, 0, (LPARAM)(LPSTR)text);
            check(strstr(text, "Gr\\u00FC\\u00DFe 2026.txt") != NULL, "UTF-8 name is displayed unambiguously");
            SendMessage(list, LB_GETTEXT, 1, (LPARAM)(LPSTR)text);
            check(strstr(text, "line\\x0APath = fake.txt") != NULL, "embedded newline cannot forge a displayed record");
            SendMessage(status, WM_GETTEXT, sizeof(text), (LPARAM)(LPSTR)text);
            check(strstr(text, "Read-only") != NULL, "viewer reports read-only contents");
            PostMessage(viewer, WM_CLOSE, 0, 0); stage = 2;
        }
        if (stage == 2 && !FindWindow("OpenLFN.ArchiveViewer.1", NULL)) {
            stage = 3; PostMessage(dialog, WM_COMMAND, IDCANCEL, 0);
        }
        return 0;
    }
    return DefWindowProc(window, message, wp, lp);
}
int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    HINSTANCE library;
    HOOK_ACTION start, stop;
    WNDCLASS cls;
    HWND window;
    OPENFILENAME ofn;
    char name[128] = "C:\\DEFLATE.ZIP";
    (void)previous; (void)show;
    blocked = command[0] == 'B';
    log_file = fopen("C:\\ARCPREV.LOG", "w");
    if (!log_file) return 2;
    test_explicit_loader();
    old_dos_module = GetModuleHandle("WINOLDAP");
    library = LoadLibrary("C:\\OLFNHOOK.DLL");
    if ((UINT)library < 32) return 2;
    start = (HOOK_ACTION)GetProcAddress(library, "STARTFILEDIALOGHOOK");
    stop = (HOOK_ACTION)GetProcAddress(library, "STOPFILEDIALOGHOOK");
    check(start && stop && start(), "archive-aware hook installed");
    memset(&cls, 0, sizeof(cls)); cls.hInstance = instance;
    cls.lpfnWndProc = PreviewTestProc; cls.lpszClassName = "ArchivePreviewAcceptance";
    RegisterClass(&cls);
    window = CreateWindow(cls.lpszClassName, "Archive preview acceptance owner", WS_OVERLAPPEDWINDOW,
        0, 0, 200, 80, NULL, NULL, instance, NULL);
    SetTimer(window, 1, 250, NULL); started = GetTickCount();
    memset(&ofn, 0, sizeof(ofn)); ofn.lStructSize = sizeof(ofn); ofn.hwndOwner = window;
    ofn.lpstrTitle = "Archive preview acceptance"; ofn.lpstrFile = name; ofn.nMaxFile = sizeof(name);
    ofn.lpstrFilter = "ZIP archives\0*.ZIP\0\0";
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
    check(!GetOpenFileName(&ofn), "preview does not accept/open the application's file");
    check(stage == 3, blocked ? "unsupported bridge rejected safely" : "separate viewer completed and closed");
    KillTimer(window, 1); DestroyWindow(window);
    check(stop && stop(), "archive menu/subclass cleanly unhooked");
    FreeLibrary(library);
    fprintf(log_file, "RESULT %s\n", failures ? "FAIL" : "PASS"); fclose(log_file);
    return failures ? 1 : 0;
}
