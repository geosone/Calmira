/* SPDX-License-Identifier: GPL-3.0-or-later
 * Independent SDM-shaped regression fixture, not Microsoft Office code.
 * Its modal loop consumes Enter before DispatchMessage, like observed Office.
 * Actual Office acceptance remains a separate, manually supplied-media test. */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <direct.h>

static FILE *log_file;
static HINSTANCE app;
static UINT edit_id;
static char dialog_class[80], edit_class[20];
static int failures, mode, ticks;
static HWND edit_window;
static char result_name[256];

static void check(int okay, const char *name)
{
    fprintf(log_file, "%s %s\n", okay ? "PASS" : "FAIL", name);
    fflush(log_file);
    if (!okay) failures++;
}

static int exists(const char *name)
{
    FILE *file = fopen(name, "rb");
    if (!file) return 0;
    fclose(file); return 1;
}

static int mapped(const char *name)
{
    char line[300];
    FILE *file = fopen("DESCRIPT.ION", "rb");
    int found = 0;
    if (!file) return 0;
    while (fgets(line, sizeof(line), file)) if (strstr(line, name)) found = 1;
    fclose(file); return found;
}

LRESULT CALLBACK __export __loadds FixtureProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    if (message == WM_TIMER && wp == 1) {
        ticks++;
        if (ticks == 1) {
            char text[256];
            LPCSTR typed = mode == 0 ? "Annual report 2026.txt" :
                mode == 2 ? "Cancelled Office name.txt" :
                mode == 3 ? "Rejected Office name.txt" :
                mode == 5 ? "Mouse cancel report.txt" : "Office new report 2026.txt";
            SendMessage(edit_window, WM_SETTEXT, 0, (LPARAM)typed);
            SendMessage(edit_window, WM_GETTEXT, sizeof(text), (LPARAM)(LPSTR)text);
            check(!lstrcmp(text, typed), "reading edit does not translate a name");
            check(!exists("CLFN.SAV"), "reading edit creates no reservation");
            check(FindWindow("OpenLFN.OfficeNames.1", NULL) != NULL, "verified SDM dialog has companion list");
            SetActiveWindow(window); SetFocus(edit_window);
            PostMessage(edit_window, WM_KEYDOWN, mode == 2 ? VK_ESCAPE : VK_RETURN, 1L);
        } else if (mode == 3 && ticks >= 4) {
            char text[256];
            SendMessage(edit_window, WM_GETTEXT, sizeof(text), (LPARAM)(LPSTR)text);
            check(!exists("CLFN.SAV"), "validation veto cancels its reservation");
            check(!lstrcmp(text, "Rejected Office name.txt"), "validation veto restores typed name");
            DestroyWindow(window);
        }
        return 0;
    }
    return DefWindowProc(window, message, wp, lp);
}

static void run_dialog(int test)
{
    HWND window;
    MSG message;
    DWORD start;
    FILE *file;
    mode = test; ticks = 0; result_name[0] = 0;
    window = CreateWindow(dialog_class, "Independent SDM fixture", WS_POPUP | WS_CAPTION |
        WS_SYSMENU, 40, 40, 400, 250, NULL, NULL, app, NULL);
    edit_window = CreateWindow(edit_class, "", WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        10, 10, 220, 24, window, (HMENU)edit_id, app, NULL);
    CreateWindow("SCROLLBAR", "", WS_CHILD | WS_VISIBLE | SBS_VERT,
        220, 40, 16, 100, window, (HMENU)(edit_id + 1), app, NULL);
    CreateWindow("SCROLLBAR", "", WS_CHILD | WS_VISIBLE | SBS_VERT,
        350, 40, 16, 100, window, (HMENU)(edit_id == 1818 ? 1283 : 4866), app, NULL);
    ShowWindow(window, SW_SHOW); SetFocus(edit_window);
    SetTimer(window, 1, 150, NULL);
    start = GetTickCount();
    while (IsWindow(window) && GetTickCount() - start < 2500UL) {
        if (!PeekMessage(&message, NULL, 0, 0, PM_REMOVE)) { Yield(); continue; }
        if (test == 5 && message.hwnd == window && message.message == WM_LBUTTONDOWN) {
            DestroyWindow(window); continue;
        }
        if (message.hwnd == edit_window && message.message == WM_KEYDOWN) {
            if (message.wParam == VK_ESCAPE) { DestroyWindow(window); continue; }
            if (message.wParam == VK_RETURN) {
                SendMessage(edit_window, WM_GETTEXT, sizeof(result_name), (LPARAM)(LPSTR)result_name);
                check(!lstrcmp(result_name, test == 0 ? "REPORT~1.TXT" :
                    test == 3 ? "REJECT~1.TXT" : test == 5 ? "MOUSEC~1.TXT" : "OFFICE~1.TXT"),
                    "Enter supplies a real DOS alias to SDM");
                if (test == 5) PostMessage(window, WM_LBUTTONDOWN, MK_LBUTTON, MAKELONG(5, 5));
                else if (test != 3) DestroyWindow(window);
                continue;
            }
        }
        TranslateMessage(&message); DispatchMessage(&message);
    }
    check(!IsWindow(window), "modal fixture completes");
    if (IsWindow(window)) DestroyWindow(window);
    if (test == 1 && !lstrcmp(result_name, "OFFICE~1.TXT")) {
        check(!exists(result_name), "reservation creates no placeholder document");
        file = fopen(result_name, "wb");
        check(file != NULL, "ordinary caller creates returned alias");
        if (file) { fputs("independent Office adapter fixture\r\n", file); fclose(file); }
    }
    start = GetTickCount();
    while (GetTickCount() - start < 700UL) {
        while (PeekMessage(&message, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&message); DispatchMessage(&message);
        }
        Yield();
    }
    check(!exists("CLFN.SAV"), "no pending journal after completed/cancelled operation");
    if (test == 1 || test == 4) check(mapped("Office new report 2026.txt"), "new display mapping committed");
    check(!mapped("Cancelled Office name.txt") && !mapped("Rejected Office name.txt") &&
        !mapped("Mouse cancel report.txt"),
        "cancel and veto create no mappings");
}

static void reject_unverified_dialogs(void)
{
    int test;
    for (test = 0; test < 2; test++) {
        HWND window = CreateWindow(dialog_class, "Not a verified file dialog",
            WS_POPUP | WS_CAPTION | WS_SYSMENU, 40, 40, 400, 250,
            NULL, NULL, app, NULL);
        CreateWindow(test ? edit_class : "EDIT", "", WS_CHILD | WS_VISIBLE,
            10, 10, 220, 24, window, (HMENU)edit_id, app, NULL);
        CreateWindow("SCROLLBAR", "", WS_CHILD | WS_VISIBLE | SBS_VERT,
            220, 40, 16, 100, window, (HMENU)(edit_id + 1), app, NULL);
        if (!test) CreateWindow("SCROLLBAR", "", WS_CHILD | WS_VISIBLE | SBS_VERT,
            350, 40, 16, 100, window, (HMENU)(edit_id == 1818 ? 1283 : 4866), app, NULL);
        ShowWindow(window, SW_SHOW);
        check(!FindWindow("OpenLFN.OfficeNames.1", NULL), test ?
            "missing directory scrollbar rejects SDM profile" :
            "wrong edit class rejects SDM profile");
        check(!exists("CLFN.SAV"), "unverified dialog reserves nothing");
        DestroyWindow(window);
    }
}

int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    char path[128];
    WNDCLASS cls;
    int word;
    (void)previous; (void)command; (void)show;
    app = instance;
    GetModuleFileName(instance, path, sizeof(path));
    word = strstr(path, "WINWORD") != NULL;
    edit_id = word ? 1818 : 4864;
    lstrcpy(dialog_class, word ? "bosa_sdm_Microsoft Word 6.0" : "bosa_sdm_XL");
    lstrcpy(edit_class, word ? "OpusFedt" : "EDTBX");
    log_file = fopen(word ? "C:\\OFFWORD.LOG" : "C:\\OFFEXCEL.LOG", "w");
    if (!log_file) return 2;
    check(!chdir(word ? "C:\\OFFWORD" : "C:\\OFFEXCEL"), "fixture directory selected");
    memset(&cls, 0, sizeof(cls));
    GetClassInfo(NULL, "EDIT", &cls);
    cls.hInstance = instance; cls.lpszClassName = edit_class;
    check(RegisterClass(&cls) != 0, "independent edit class registered");
    memset(&cls, 0, sizeof(cls));
    cls.hInstance = instance; cls.lpszClassName = dialog_class;
    cls.lpfnWndProc = FixtureProc; cls.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    check(RegisterClass(&cls) != 0, "independent dialog class registered");
    reject_unverified_dialogs();
    run_dialog(0); run_dialog(1); run_dialog(2); run_dialog(3); run_dialog(4); run_dialog(5);
    fprintf(log_file, "RESULT %s\n", failures ? "FAIL" : "PASS");
    fclose(log_file);
    return failures ? 1 : 0;
}
