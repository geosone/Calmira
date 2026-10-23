/* Install globally, then launch a different task that calls normal COMMDLG. */
#include <windows.h>
#include <stdio.h>
typedef BOOL (FAR PASCAL *HOOK_ACTION)(void);
typedef WORD (FAR PASCAL *HOOK_COUNT)(void);
typedef DWORD (FAR PASCAL *HOOK_DIAGNOSTICS)(void);
static HOOK_COUNT poll_saves;
static HOOK_ACTION stop_for_test;
static int refused_pending;

static void pump(void)
{
    MSG message;
    while (PeekMessage(&message, NULL, 0, 0, PM_REMOVE)) {
        TranslateMessage(&message);
        DispatchMessage(&message);
    }
    Yield();
    if (poll_saves) poll_saves();
}

static int run_client(LPSTR command, HOOK_DIAGNOSTICS diagnostics, HOOK_COUNT count)
{
    UINT result = WinExec(command, SW_SHOW);
    DWORD start = GetTickCount();
    DWORD reported = start;
    if (result < 32) return 0;
    while (GetModuleUsage((HINSTANCE)result) && GetTickCount() - start < 12000UL) {
        pump();
        if (stop_for_test && !refused_pending) {
            HFILE flag = _lopen("C:\\HKWAIT.FLG", OF_READ);
            if (flag != HFILE_ERROR) {
                FILE *log;
                _lclose(flag);
                refused_pending = stop_for_test() ? -1 : 1;
                log = fopen("C:\\HKMGR.LOG", "a");
                if (log) {
                    fputs(refused_pending > 0 ? "PASS unload refused while save is pending\n" :
                        "FAIL hook unloaded with pending save\n", log);
                    fclose(log);
                }
            }
        }
        if (diagnostics && GetTickCount() - reported >= 1000UL) {
            FILE *log = fopen("C:\\HKMGR.LOG", "a");
            if (log) {
                fprintf(log, "Hook diagnostics=%lu attached=%u\n", diagnostics(), count());
                fclose(log);
            }
            reported = GetTickCount();
        }
    }
    return !GetModuleUsage((HINSTANCE)result);
}

int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    HINSTANCE library;
    HOOK_ACTION start_hook, stop_hook;
    HOOK_COUNT count_hook;
    HOOK_DIAGNOSTICS diagnostics;
    FILE *log = fopen("C:\\HKMGR.LOG", "w");
    int okay = 1, office = command[0] == 'O';
    HFILE probe;
    FILE *disk;
    char path[128];
    (void)instance; (void)previous; (void)show;
    if (!log) return 2;
    disk = fopen("C:\\WINDOWS\\SYSTEM\\OLFNHOOK.DLL", "rb");
    fprintf(log, "CRT DLL=%s\n", disk ? "present" : "missing");
    if (disk) fclose(disk);
    GetModuleFileName(instance, path, sizeof(path));
    fprintf(log, "Manager=%s\n", path);
    probe = _lopen("C:\\HKMGR.EXE", OF_READ);
    fprintf(log, "Self file=%d\n", probe);
    if (probe != HFILE_ERROR) _lclose(probe);
    probe = _lopen("C:\\WINDOWS\\SYSTEM\\OLFNHOOK.DLL", OF_READ);
    fprintf(log, "DLL file handle=%d kernel=%u user=%u\n", probe,
        (UINT)GetModuleHandle("KERNEL"), (UINT)GetModuleHandle("USER"));
    if (probe != HFILE_ERROR) _lclose(probe);
    fflush(log);
    fclose(log);
    log = fopen("C:\\HKMGR.LOG", "a");
    lstrcpy(path, "C:\\WINDOWS\\SYSTEM\\OLFNHOOK.DLL");
    library = LoadLibrary(path);
    if (library < 32) { fprintf(log, "RESULT FAIL: LoadLibrary %u\n", (UINT)library); fclose(log); return 1; }
    start_hook = (HOOK_ACTION)GetProcAddress(library, "STARTFILEDIALOGHOOK");
    stop_hook = (HOOK_ACTION)GetProcAddress(library, "STOPFILEDIALOGHOOK");
    count_hook = (HOOK_COUNT)GetProcAddress(library, "FILEDIALOGHOOKCOUNT");
    diagnostics = (HOOK_DIAGNOSTICS)GetProcAddress(library, "FILEDIALOGHOOKDIAGNOSTICS");
    poll_saves = (HOOK_COUNT)GetProcAddress(library, "POLLFILEDIALOGSAVES");
    stop_for_test = stop_hook;
    {
        HINSTANCE legacy = LoadLibrary("C:\\LEGACY.DLL");
        int rejected = (UINT)legacy >= 32 && GetModuleHandle("CLFNHOOK") &&
            start_hook && !start_hook() && count_hook && !count_hook();
        fprintf(log, "%s OpenLFN refuses a concurrently loaded legacy hook\n", rejected ? "PASS" : "FAIL");
        if (!rejected) okay = 0;
        if ((UINT)legacy >= 32) FreeLibrary(legacy);
    }
    if (!start_hook || !stop_hook || !count_hook || !poll_saves || !start_hook()) okay = 0;
    fputs(okay ? "PASS global hook installed\n" : "FAIL install/export\n", log);
    fflush(log);
    fclose(log);
    log = fopen("C:\\HKMGR.LOG", "a");
    fclose(log);
    if (office) {
        stop_for_test = NULL;
        if (okay && !run_client("C:\\WINWORD.EXE", diagnostics, count_hook)) okay = 0;
        if (okay && !run_client("C:\\EXCEL.EXE", diagnostics, count_hook)) okay = 0;
    } else if (okay && !run_client("C:\\HKCLIENT.EXE", diagnostics, count_hook)) okay = 0;
    stop_for_test = NULL;
    if (!office && refused_pending != 1) okay = 0;
    if (poll_saves) {
        DWORD until = GetTickCount() + 3000UL;
        while (poll_saves() && GetTickCount() < until) pump();
        if (poll_saves()) okay = 0;
    }
    log = fopen("C:\\HKMGR.LOG", "a");
    if (diagnostics) fprintf(log, "Hook diagnostics=%lu attached=%u\n", diagnostics(), count_hook());
    if (okay && count_hook() < 4) okay = 0;
    if (stop_hook && !stop_hook()) okay = 0;
    fputs(okay ? "PASS global hook removed\n" : "FAIL hook lifecycle\n", log);
    fflush(log);
    fclose(log);
    if (!office && stop_hook && !run_client("C:\\HKCLIENT.EXE P", NULL, NULL)) okay = 0;
    log = fopen("C:\\HKMGR.LOG", "a");
    if (stop_hook) stop_hook();
    FreeLibrary(library);
    fprintf(log, "RESULT %s\n", okay ? "PASS" : "FAIL");
    fclose(log);
    return okay ? 0 : 1;
}
