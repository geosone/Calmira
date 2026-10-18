/* Native Windows 3.1 CTL3D acceptance probe. GPL-2.0-or-later. */
#include <windows.h>
#include <stdio.h>

typedef BOOL (WINAPI *InstanceCall)(HANDLE);
typedef BOOL (WINAPI *DialogCall)(HWND, WORD);
typedef WORD (WINAPI *VersionCall)(void);
typedef BOOL (WINAPI *ColorCall)(void);

static HINSTANCE instance;
static HINSTANCE library;
static DialogCall subclass_dialog;
static ColorCall color_change;
static FILE *report;
static int failed, automatic;

static void check(int result, const char *name)
{
    fprintf(report, "%s %s\n", result ? "PASS" : "FAIL", name);
    fflush(report);
    if (!result) failed = 1;
}

static BOOL FAR PASCAL dialog_proc(HWND dialog, UINT msg,
    WPARAM wp, LPARAM lp)
{
    HWND edit;
    (void)wp;
    (void)lp;
    switch (msg) {
    case WM_INITDIALOG:
        SetWindowText(dialog, automatic ? "CTL3D automatic subclass" :
            "CTL3D explicit subclass");
        if (!automatic)
            check(subclass_dialog(dialog, 0xFFFF), "explicit subclass");
        SendDlgItemMessage(dialog, 103, LB_ADDSTRING, 0, (LPARAM)(LPCSTR)"Drive C:");
        SendDlgItemMessage(dialog, 104, CB_ADDSTRING, 0, (LPARAM)(LPCSTR)"Windows 3.11");
        SendDlgItemMessage(dialog, 104, CB_SETCURSEL, 0, 0);
        SetTimer(dialog, 1, 6000, NULL);
        return TRUE;
    case WM_TIMER:
        KillTimer(dialog, 1);
        edit = GetDlgItem(dialog, 102);
        check(GetProp(edit, "Ctl3dK") != NULL, automatic ?
            "automatic control subclass" : "explicit control subclass");
        SetFocus(edit);
        check(GetFocus() == edit, "edit focus");
        SetWindowText(edit, "Calmira test");
        check(GetWindowTextLength(edit) == 12, "edit text");
        SendDlgItemMessage(dialog, 101, BM_SETCHECK, 1, 0);
        check(SendDlgItemMessage(dialog, 101, BM_GETCHECK, 0, 0) == 1,
            "checkbox state");
        check(color_change(), "system color refresh");
        InvalidateRect(dialog, NULL, TRUE);
        UpdateWindow(dialog);
        EndDialog(dialog, 1);
        return TRUE;
    }
    return FALSE;
}

int PASCAL WinMain(HINSTANCE current, HINSTANCE previous, LPSTR cmd, int show)
{
    InstanceCall reg, unreg, autosub;
    VersionCall version;
    FARPROC proc;
    int result;
    (void)previous; (void)cmd; (void)show;
    instance = current;
    report = fopen("C:\\CTLTEST.LOG", "w");
    if (!report) return 2;
    library = LoadLibrary("C:\\WINDOWS\\SYSTEM\\CTL3DV2.DLL");
    check((UINT)library >= 32, "LoadLibrary");
    if ((UINT)library < 32) goto done;
    version = (VersionCall)GetProcAddress(library, MAKEINTRESOURCE(1));
    subclass_dialog = (DialogCall)GetProcAddress(library, MAKEINTRESOURCE(2));
    color_change = (ColorCall)GetProcAddress(library, MAKEINTRESOURCE(6));
    reg = (InstanceCall)GetProcAddress(library, MAKEINTRESOURCE(12));
    unreg = (InstanceCall)GetProcAddress(library, MAKEINTRESOURCE(13));
    autosub = (InstanceCall)GetProcAddress(library, MAKEINTRESOURCE(16));
    check(version && subclass_dialog && color_change && reg && unreg && autosub,
        "required ordinal lookups");
    if (!version || !subclass_dialog || !color_change || !reg || !unreg || !autosub)
        goto unload;
    check(version() == 0x0231, "version 2.31");
    check(reg(instance), "register");
    proc = MakeProcInstance((FARPROC)dialog_proc, instance);
    result = DialogBox(instance, MAKEINTRESOURCE(1), NULL, (DLGPROC)proc);
    check(result == 1, "explicit dialog completed");
    automatic = 1;
    check(autosub(instance), "enable automatic subclass");
    result = DialogBox(instance, MAKEINTRESOURCE(1), NULL, (DLGPROC)proc);
    check(result == 1, "automatic dialog completed");
    FreeProcInstance(proc);
    check(unreg(instance), "unregister");
unload:
    FreeLibrary(library);
done:
    fprintf(report, "RESULT %s\n", failed ? "FAIL" : "PASS");
    fclose(report);
    return failed ? 1 : 0;
}
