/* A separate, ordinary COMMDLG client: no hook DLL installation or API shim. */
#include <windows.h>
#include <commdlg.h>
#include <stdio.h>
#include <string.h>
#include "../../src/win16/clfnhook.h"

static FILE *log_file;
static int failures, plain, cancel_dialog, ticks, app_hook_calls;
static char dialog_title[24];
static int timer_entered;
static int app_list_focus;
static int new_mode, new_submitted, veto_calls;
static UINT file_ok_message;

void CALLBACK __export __loadds Automate(HWND window, UINT message, UINT timer, DWORD tick);

static void check(int okay, const char *name)
{
    fprintf(log_file, "%s %s\n", okay ? "PASS" : "FAIL", name);
    fflush(log_file);
    fclose(log_file);
    log_file = fopen(plain ? "C:\\HKPLAIN.LOG" : "C:\\HKCHILD.LOG", "a");
    if (!okay) failures++;
}

UINT CALLBACK __export __loadds ExistingHook(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    (void)window; (void)wp; (void)lp;
    if (message == WM_INITDIALOG) app_hook_calls++;
    if (message == WM_COMMAND && wp == 0x0460 && HIWORD(lp) == LBN_SETFOCUS)
        app_list_focus++;
    if (new_mode == 3 && message == file_ok_message) { veto_calls++; return 1; }
    return 0;
}

LRESULT CALLBACK __export __loadds ClientProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    if (message == WM_TIMER) {
        HWND dialog;
        HWND list;
        int i, count, found = -1, umlaut_found = 0;
        char text[256];
        if (!timer_entered) {
            timer_entered = 1;
            check(1, "timer callback entered");
        }
        dialog = FindWindow(NULL, dialog_title);
        if (!dialog) return 0;
        ticks++;
        if (ticks == 1) {
            char module[128], cls[32];
            GetClassName(dialog, cls, sizeof(cls));
            GetModuleFileName((HINSTANCE)GetWindowWord(dialog, GWW_HINSTANCE), module, sizeof(module));
            fprintf(log_file, "Dialog class=%s instance=%s\n", cls, module);
            fflush(log_file);
        }
        list = GetDlgItem(dialog, CLFN_LIST_ID);
        if (!plain && !list && ticks < 10) return 0;
        check(plain ? !list : !!list, plain ? "native dialog after unhook" :
            "global hook reached another task");
        if (list) check(GetNextDlgTabItem(dialog, GetDlgItem(dialog, 0x0480), FALSE) == list,
            "replacement preserves native file-list tab order");
        if (new_mode) {
            if (!new_submitted) {
                LPCSTR name = new_mode == 2 ? "Cancelled long report.txt" :
                    new_mode == 3 ? "Vetoed long report.txt" :
                    new_mode == 4 ? "Never created name.txt" :
                    new_mode == 6 ? "Neue Gr\374\337e 2026.txt" :
                    new_mode == 7 ? "Mapped hidden report.bin" : "New annual report 2026.txt";
                new_submitted = 1;
                SetDlgItemText(dialog, 0x0480, name);
                PostMessage(dialog, WM_COMMAND, new_mode == 2 ? IDCANCEL : IDOK, 0);
            } else if (new_mode == 3 && (veto_calls || ticks > 10))
                PostMessage(dialog, WM_COMMAND, IDCANCEL, 0);
            return 0;
        }
        if (cancel_dialog || (!plain && !list)) {
            PostMessage(dialog, WM_COMMAND, IDCANCEL, 0);
            return 0;
        }
        if (!list) list = GetDlgItem(dialog, 0x0460);
        count = (int)SendMessage(list, LB_GETCOUNT, 0, 0);
        for (i = 0; i < count; i++) {
            if (SendMessage(list, LB_GETTEXTLEN, i, 0) >= (LONG)sizeof(text)) continue;
            SendMessage(list, LB_GETTEXT, i, (LPARAM)(LPSTR)text);
            if (!lstrcmpi(text, plain ? "report~1.txt" : "Annual report 2026.txt")) found = i;
            if (!lstrcmp(text, "Gr\374\337e aus K\366ln.txt")) umlaut_found = 1;
        }
        if (!plain) check(umlaut_found, "OEM descriptions convert to Windows ANSI");
        check(found >= 0, plain ? "native alias remains visible" : "DESCRIPT.ION display name");
        if (found < 0) {
            for (i = 0; i < count && i < 5; i++) {
                SendMessage(list, LB_GETTEXT, i, (LPARAM)(LPSTR)text);
                fprintf(log_file, "List[%d]=%s\n", i, text);
            }
            PostMessage(dialog, WM_COMMAND, IDCANCEL, 0);
            return 0;
        }
        SetFocus(list);
        SendMessage(list, LB_SETCURSEL, found, 0);
        SendMessage(dialog, WM_COMMAND, plain ? 0x0460 : CLFN_LIST_ID,
            MAKELONG(list, LBN_SELCHANGE));
        PostMessage(dialog, WM_COMMAND, IDOK, 0);
        return 0;
    }
    return DefWindowProc(window, message, wp, lp);
}

void CALLBACK __export __loadds Automate(HWND window, UINT message, UINT timer, DWORD tick)
{
    (void)window; (void)message; (void)timer; (void)tick;
    ClientProc(NULL, WM_TIMER, 0, 0);
}

static void run_dialog(HWND owner, int save, int cancel, int use_existing_hook)
{
    OPENFILENAME ofn;
    char filename[256] = "";
    BOOL result;
    FARPROC app_hook = NULL;
    cancel_dialog = cancel;
    ticks = 0;
    lstrcpy(dialog_title, save ? "CLFN Save Test" : "CLFN Open Test");
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = owner;
    ofn.lpstrFilter = "Text files\0*.TXT\0All files\0*.*\0\0";
    ofn.lpstrFile = filename;
    ofn.nMaxFile = sizeof(filename);
    ofn.lpstrInitialDir = "C:\\LFDTEST";
    ofn.lpstrTitle = dialog_title;
    ofn.Flags = OFN_PATHMUSTEXIST | (save ? 0 : OFN_FILEMUSTEXIST);
    if (use_existing_hook) {
        ofn.Flags |= OFN_ENABLEHOOK;
        app_hook = MakeProcInstance((FARPROC)ExistingHook, GetWindowWord(owner, GWW_HINSTANCE));
        ofn.lpfnHook = (LPOFNHOOKPROC)app_hook;
    }
    check(1, "entering native COMMDLG call");
    result = save ? GetSaveFileName(&ofn) : GetOpenFileName(&ofn);
    if (app_hook) FreeProcInstance(app_hook);
    check(cancel ? !result && !CommDlgExtendedError() : !!result,
        cancel ? "native cancel semantics" : save ? "native GetSaveFileName succeeds" :
        "native GetOpenFileName succeeds");
    if (result) {
        fprintf(log_file, "Returned=%s\n", filename);
        check(!lstrcmpi(filename, "C:\\LFDTEST\\REPORT~1.TXT"),
            "caller receives real DOS path, not display name");
    }
}

static int exists(LPCSTR path)
{
    HFILE file = _lopen(path, OF_READ | OF_SHARE_DENY_NONE);
    if (file == HFILE_ERROR) return 0;
    _lclose(file);
    return 1;
}

static int map_contains(LPCSTR text)
{
    char data[4096];
    FILE *file = fopen("C:\\LFDTEST\\DESCRIPT.ION", "rb");
    unsigned n;
    if (!file) return 0;
    n = fread(data, 1, sizeof(data) - 1, file);
    fclose(file);
    data[n] = 0;
    return strstr(data, text) != NULL;
}

static void pump_for(DWORD milliseconds)
{
    DWORD start = GetTickCount();
    while (GetTickCount() - start < milliseconds) {
        MSG message;
        while (PeekMessage(&message, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&message);
            DispatchMessage(&message);
        }
        Yield();
    }
}

static void run_new_name(HWND owner, int mode, LPCSTR expected)
{
    OPENFILENAME ofn;
    char filename[256] = "";
    FARPROC hook = NULL;
    BOOL result;
    FILE *file;
    LPCSTR description = mode == 6 ? "Neue Gr\201\341e 2026.txt" : "New annual report 2026.txt";
    new_mode = mode;
    new_submitted = ticks = 0;
    cancel_dialog = 0;
    lstrcpy(dialog_title, (mode == 5 || mode == 7) ? "CLFN Typed Open" : "CLFN New Save");
    memset(&ofn, 0, sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = owner;
    ofn.lpstrFilter = "Text files\0*.TXT\0\0";
    ofn.lpstrFile = filename;
    ofn.nMaxFile = sizeof(filename);
    ofn.lpstrInitialDir = "C:\\LFDTEST";
    ofn.lpstrTitle = dialog_title;
    ofn.lpstrDefExt = "TXT";
    ofn.Flags = OFN_PATHMUSTEXIST | ((mode == 5 || mode == 7) ? OFN_FILEMUSTEXIST : 0);
    if (mode == 3) {
        ofn.Flags |= OFN_ENABLEHOOK;
        hook = MakeProcInstance((FARPROC)ExistingHook, GetWindowWord(owner, GWW_HINSTANCE));
        ofn.lpfnHook = (LPOFNHOOKPROC)hook;
    }
    result = (mode == 5 || mode == 7) ? GetOpenFileName(&ofn) : GetSaveFileName(&ofn);
    if (hook) FreeProcInstance(hook);
    if (mode == 2 || mode == 3) {
        check(!result && !CommDlgExtendedError(), "new long-name cancel/veto returns false");
        check(!exists("C:\\LFDTEST\\CLFN.SAV"), "cancel/veto removes its own reservation");
        if (mode == 3) check(veto_calls == 1, "existing application can veto FILEOK");
        new_mode = 0;
        return;
    }
    check(result, "long-name dialog accepted by native COMMDLG");
    fprintf(log_file, "New path=%s\n", filename);
    check(!lstrcmpi(filename, expected), "long-name caller receives collision-safe DOS alias");
    if (!result || lstrcmpi(filename, expected)) { new_mode = 0; return; }
    if (mode == 5 || mode == 7) {
        check(!exists("C:\\LFDTEST\\CLFN.SAV"), "typed existing long name reuses mapping without reservation");
    } else if (mode == 4) {
        HFILE flag = _lcreat("C:\\HKWAIT.FLG", 0);
        if (flag != HFILE_ERROR) _lclose(flag);
        pump_for(1000);
        check(exists("C:\\LFDTEST\\CLFN.SAV"), "uncreated file keeps a recoverable reservation");
        check(!map_contains("Never created name.txt"), "no mapping for an application that never creates its file");
    } else {
        check(!map_contains(description), "no metadata entry before the application creates its file");
        check(!exists(filename), "reservation does not create a fake document");
        check(exists("C:\\LFDTEST\\CLFN.SAV"), "accepted save retains its journal until file creation");
        file = fopen(filename, "wb");
        check(file != NULL, "ordinary application creates returned alias");
        if (file) {
            fputs("saved through ordinary Win16 application\r\n", file);
            fclose(file);
        }
        pump_for(1000);
        check(map_contains(description), "resident commits mapping after actual file creation");
        check(!exists("C:\\LFDTEST\\CLFN.SAV"), "successful commit removes reservation");
    }
    new_mode = 0;
}

int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    WNDCLASS cls;
    HWND owner;
    UINT timer;
    FARPROC automation;
    (void)previous; (void)show;
    plain = command[0] == 'P';
    file_ok_message = RegisterWindowMessage("commdlg_FileNameOK");
    log_file = fopen(plain ? "C:\\HKPLAIN.LOG" : "C:\\HKCHILD.LOG", "w");
    if (!log_file) return 2;
    check(1, "client initialized");
    memset(&cls, 0, sizeof(cls));
    cls.hInstance = instance;
    cls.lpfnWndProc = ClientProc;
    cls.lpszClassName = "ClfnHookClient";
    if (!RegisterClass(&cls)) return 3;
    owner = CreateWindow(cls.lpszClassName, "COMMDLG test client", WS_OVERLAPPEDWINDOW,
        0, 0, 300, 180, NULL, NULL, instance, NULL);
    automation = MakeProcInstance((FARPROC)Automate, instance);
    timer = SetTimer(NULL, 0, 200, (TIMERPROC)automation);
    run_dialog(owner, 0, 0, 0);
    {
        run_dialog(owner, 1, 0, 0);
        run_dialog(owner, 0, 1, 0);
        run_dialog(owner, 0, 0, 1);
        check(app_hook_calls == 1, "existing application OFN hook is preserved");
        check(app_list_focus > 0, "application receives native file-list focus notification");
    }
    if (!plain) {
        run_new_name(owner, 1, "C:\\LFDTEST\\NEWANN~2.TXT");
        run_new_name(owner, 5, "C:\\LFDTEST\\NEWANN~2.TXT");
        run_new_name(owner, 7, "C:\\LFDTEST\\HIDDEN~1.BIN");
        run_new_name(owner, 2, "");
        run_new_name(owner, 3, "");
        run_new_name(owner, 6, "C:\\LFDTEST\\NEUEGR~1.TXT");
        run_new_name(owner, 4, "C:\\LFDTEST\\NEVERC~1.TXT");
    }
    KillTimer(NULL, timer);
    FreeProcInstance(automation);
    DestroyWindow(owner);
    fprintf(log_file, "RESULT %s\n", failures ? "FAIL" : "PASS");
    fclose(log_file);
    return failures ? 1 : 0;
}
