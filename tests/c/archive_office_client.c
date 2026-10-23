/* SPDX-License-Identifier: GPL-3.0-or-later
 * Private-media acceptance driver for actual Word/Excel, not an SDM fixture.
 * Uses observed classes/IDs and documented Windows messages, no Office code. */
#include <windows.h>
#include <stdio.h>
#include <string.h>

typedef BOOL (WINAPI *HOOK_ACTION)(void);
static FILE *log_file;
static HWND dialog, filename_edit;
static UINT edit_id;
static LPCSTR dialog_class;
static DWORD started;
static int stage, failures, finished;

static void check(int okay, LPCSTR name)
{
    fprintf(log_file, "%s %s\n", okay ? "PASS" : "FAIL", name);
    fflush(log_file);
    if (!okay) failures++;
}

BOOL CALLBACK __export __loadds FindOfficeDialog(HWND window, LPARAM unused)
{
    char cls[80];
    (void)unused;
    if (IsWindowVisible(window) && GetClassName(window, cls, sizeof(cls)) &&
        !lstrcmp(cls, dialog_class) && GetDlgItem(window, edit_id) &&
        GetDlgItem(window, edit_id + 1) && GetDlgItem(window, edit_id == 1818 ? 1283 : 4866)) {
        dialog = window; filename_edit = GetDlgItem(window, edit_id);
        return FALSE;
    }
    return TRUE;
}

LRESULT CALLBACK __export __loadds OfficePreviewProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    if (message == WM_TIMER) {
        HWND viewer = FindWindow("OpenLFN.ArchiveViewer.1", NULL);
        char text[160];
        if (GetTickCount() - started > 25000UL) {
            check(0, "actual Office preview timed out");
            finished = 1; KillTimer(window, 1); PostQuitMessage(1); return 0;
        }
        if (!stage) {
            dialog = NULL;
            EnumWindows(FindOfficeDialog, 0);
            if (dialog) {
                HMENU menu = GetSystemMenu(dialog, FALSE);
                check(menu && GetMenuState(menu, 0x6f30, MF_BYCOMMAND) != (UINT)-1,
                    "actual Office dialog exposes ZIP preview command");
                check(FindWindow("OpenLFN.OfficeNames.1", NULL) != NULL,
                    "verified actual Office dialog has companion list");
                SendMessage(filename_edit, WM_SETTEXT, 0, (LPARAM)(LPSTR)"C:\\ARCDATA\\MISSING.ZIP");
                PostMessage(dialog, WM_SYSCOMMAND, 0x6f30, 0);
                stage = 1;
            }
        } else if (stage == 1) {
            HWND warning = FindWindow(NULL, "OpenLFN archive preview");
            if (warning) {
                check(!viewer && !GetModuleHandle("OLFNVIEW"), "missing ZIP starts no viewer");
                check(IsWindow(dialog) && IsWindowVisible(dialog), "missing ZIP leaves Office dialog open");
                SendMessage(filename_edit, WM_GETTEXT, sizeof(text), (LPARAM)(LPSTR)text);
                check(!lstrcmp(text, "C:\\ARCDATA\\MISSING.ZIP"), "missing ZIP leaves typed name unchanged");
                /* The runner acknowledges this modal box with a native
                 * Enter key. Do not depend on cross-task WM_COMMAND injection. */
                stage = 2;
            }
        } else if (stage == 2 && !FindWindow(NULL, "OpenLFN archive preview")) {
            SendMessage(filename_edit, WM_SETTEXT, 0, (LPARAM)(LPSTR)"C:\\ARCDATA\\DEFLATE.ZIP");
            PostMessage(dialog, WM_SYSCOMMAND, 0x6f30, 0); stage = 3;
        } else if (stage == 3 && viewer) {
            HWND list = GetDlgItem(viewer, 100);
            if (SendMessage(list, LB_GETCOUNT, 0, 0) != 2) return 0;
            SendMessage(list, LB_GETTEXT, 0, (LPARAM)(LPSTR)text);
            check(strstr(text, "Gr\\u00FC\\u00DFe 2026.txt") != NULL,
                "actual Office launch displays UTF-8 ZIP entry");
            SendMessage(list, LB_GETTEXT, 1, (LPARAM)(LPSTR)text);
            check(strstr(text, "line\\x0APath = fake.txt") != NULL,
                "actual Office launch escapes embedded newline");
            GetDlgItemText(viewer, 101, text, sizeof(text));
            check(strstr(text, "Read-only") != NULL, "actual Office launch is read-only");
            check(IsWindow(dialog) && IsWindowVisible(dialog),
                "preview leaves actual Office file dialog open");
            SendMessage(filename_edit, WM_GETTEXT, sizeof(text), (LPARAM)(LPSTR)text);
            check(!lstrcmp(text, "C:\\ARCDATA\\DEFLATE.ZIP"),
                "preview leaves actual Office filename edit unchanged");
            PostMessage(viewer, WM_CLOSE, 0, 0); stage = 4;
        } else if (stage == 4 && !viewer) {
            SetActiveWindow(dialog); SetFocus(filename_edit);
            PostMessage(filename_edit, WM_KEYDOWN, VK_ESCAPE, 1L); stage = 5;
        } else if (stage == 5 && (!IsWindow(dialog) || !IsWindowVisible(dialog))) {
            check(1, "actual Office dialog cancels after preview");
            finished = 1; KillTimer(window, 1); PostQuitMessage(0);
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
    MSG message;
    int word = command[0] == 'W';
    (void)previous; (void)show;
    edit_id = word ? 1818 : 4864;
    dialog_class = word ? "bosa_sdm_Microsoft Word 6.0" : "bosa_sdm_XL";
    log_file = fopen("C:\\ARCOFF.LOG", "w");
    if (!log_file) return 2;
    library = LoadLibrary("C:\\OLFNHOOK.DLL");
    if ((UINT)library < 32) { check(0, "hook library loads"); fclose(log_file); return 2; }
    start = (HOOK_ACTION)GetProcAddress(library, "STARTFILEDIALOGHOOK");
    stop = (HOOK_ACTION)GetProcAddress(library, "STOPFILEDIALOGHOOK");
    if (!start || !stop || !start()) { check(0, "hook starts"); fclose(log_file); return 2; }
    memset(&cls, 0, sizeof(cls)); cls.hInstance = instance;
    cls.lpfnWndProc = OfficePreviewProc; cls.lpszClassName = "ActualOfficeArchiveAcceptance";
    if (!RegisterClass(&cls)) { check(0, "test class registers"); return 2; }
    window = CreateWindow(cls.lpszClassName, "Actual Office ZIP acceptance", WS_OVERLAPPEDWINDOW,
        0, 0, 100, 60, NULL, NULL, instance, NULL);
    started = GetTickCount();
    if (!window || !SetTimer(window, 1, 250, NULL)) { check(0, "test timer starts"); return 2; }
    check(WinExec(word ? "C:\\MSOFFICE\\WINWORD\\WINWORD.EXE" :
        "C:\\MSOFFICE\\EXCEL\\EXCEL.EXE", SW_SHOW) >= 32, "actual Office application starts");
    while (GetMessage(&message, NULL, 0, 0)) {
        TranslateMessage(&message); DispatchMessage(&message);
    }
    DestroyWindow(window);
    check(finished && stage == 5, "complete actual Office preview/cancel flow");
    if (stop()) { check(1, "hook cleanly stops after actual Office preview"); FreeLibrary(library); }
    else check(0, "hook cleanly stops after actual Office preview");
    fprintf(log_file, "RESULT %s\n", failures ? "FAIL" : "PASS"); fclose(log_file);
    return failures ? 1 : 0;
}
