/* SPDX-License-Identifier: GPL-3.0-or-later
 * Read-only Win16 ZIP viewer. Decoding stays in the bounded DOS helper. */
#include <windows.h>
#include <commdlg.h>
#include <direct.h>
#include <stdio.h>
#include <string.h>
#include "../portable/archive_index.h"

#define INDEX_LIST 100
#define INDEX_STATUS 101
static char class_name[] = "OpenLFN.ArchiveViewer.1";
static char input[128], helper[128], reservation[144], work[144], original[144];
static HINSTANCE helper_task;
static HGLOBAL index_memory;
static ArcIndex index_data;
static HWND list, status;
static BOOL pending, retained;
static DWORD launched;

static void status_text(LPCSTR text) { SetWindowText(status, text); }

static int load_index(void)
{
    HFILE file;
    LONG length;
    ArcByte FAR *data;
    unsigned i, displayed = 0;
    char name[ARC_NAME_MAX * 6 + 1], line[ARC_NAME_MAX * 6 + 80], size[21];
    file = _lopen("INDEX.BIN", OF_READ | OF_SHARE_DENY_WRITE);
    if (file == HFILE_ERROR) return 0;
    length = _llseek(file, 0, 2);
    if (length < 24 || length > ARC_INDEX_MAX || _llseek(file, 0, 0) != 0) { _lclose(file); return -1; }
    index_memory = GlobalAlloc(GMEM_MOVEABLE, (DWORD)length);
    if (!index_memory) { _lclose(file); return -1; }
    data = GlobalLock(index_memory);
    if (!data) { _lclose(file); return -1; }
    if (_lread(file, data, (UINT)length) != (UINT)length ||
        !arc_index_validate(data, (unsigned)length, &index_data)) { _lclose(file); return -1; }
    _lclose(file);
    for (i = 0; i < index_data.count; i++) {
        ArcEntry entry;
        if (!arc_index_entry(&index_data, i, &entry) || !arc_entry_display(&entry, name, sizeof(name))) return -1;
        arc_decimal(entry.unpacked_lo, entry.unpacked_hi, size);
        wsprintf(line, "%s%s%s  [%s bytes]", entry.flags & ARC_DIRECTORY ? "[dir] " : "",
            entry.flags & ARC_ENCRYPTED ? "[locked] " : "", (LPSTR)name, (LPSTR)size);
        /* Bound the old Windows listbox's string heap as well as the protocol. */
        displayed += (unsigned)lstrlen(line) + 1;
        if (displayed > 24000 || SendMessage(list, LB_ADDSTRING, 0, (LPARAM)(LPSTR)line) < 0) return -1;
    }
    wsprintf(line, "%u entries. Read-only: nothing is extracted or executed. Names use visible escapes.", index_data.count);
    status_text(line);
    return 1;
}

static void cleanup(void)
{
    char path[160];
    if (index_memory) { GlobalUnlock(index_memory); GlobalFree(index_memory); index_memory = NULL; }
    if (retained) return; /* A still-running DOS task may own these paths. */
    if (work[0]) {
        lstrcpy(path, work); lstrcat(path, "\\INDEX.BIN"); remove(path);
        if (original[0]) chdir(original);
        rmdir(work);
    }
    if (reservation[0]) remove(reservation);
}

LRESULT CALLBACK __export __loadds ViewerProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    if (message == WM_SIZE && list && status) {
        int width = LOWORD(lp), height = HIWORD(lp);
        MoveWindow(list, 8, 8, width > 16 ? width - 16 : 1, height > 64 ? height - 64 : 1, TRUE);
        MoveWindow(status, 8, height > 48 ? height - 48 : 0, width > 16 ? width - 16 : 1, 40, TRUE);
        return 0;
    }
    if (message == WM_TIMER && wp == 1 && pending) {
        DWORD elapsed = GetTickCount() - launched;
        if (!GetModuleUsage(helper_task) && elapsed > 500) {
            int loaded = load_index();
            if (loaded || elapsed > 2000) {
                pending = FALSE; KillTimer(window, 1);
                if (loaded != 1) {
                    SendMessage(list, LB_RESETCONTENT, 0, 0);
                    status_text("Cannot list ZIP: invalid/unsupported input, resource limit, or DOS helper failure.");
                }
            }
        } else if (elapsed > 25000UL) {
            retained = TRUE; pending = FALSE; KillTimer(window, 1);
            status_text("DOS helper timeout. Close its DOS session if necessary; private temporary files are retained.");
        }
        return 0;
    }
    if (message == WM_CLOSE && pending) {
        MessageBox(window, "The archive helper is still running. Wait, or close its DOS session first.",
                   "OpenLFN archive viewer", MB_OK | MB_ICONINFORMATION);
        return 0;
    }
    if (message == WM_DESTROY) { KillTimer(window, 1); cleanup(); PostQuitMessage(0); return 0; }
    return DefWindowProc(window, message, wp, lp);
}

static BOOL ascii_path(LPCSTR path)
{
    while (*path) { if ((BYTE)*path < 32 || (BYTE)*path >= 127 || *path == '"') return FALSE; path++; }
    return TRUE;
}

int PASCAL WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show)
{
    OPENFILENAME ofn;
    WNDCLASS cls;
    HWND window;
    MSG message;
    int n, separator;
    char launch[256];
    DWORD version = GetVersion();
    (void)previous; (void)show;
    /* A stock DOS 7.1/Win3.1 test host faults during WinOldApp startup. Do not
     * discover that unsafe capability by launching a probe in a user's session. */
    if (!(GetWinFlags() & WF_ENHANCED) || HIBYTE(HIWORD(version)) >= 7) {
        MessageBox(NULL, "The experimental DOS bridge is verified on DOS 6.22 / enhanced Windows only.\n"
            "DOS 7.x / Windows DOS-session compatibility is unresolved.\n"
            "OLFNLIST.EXE can still be used from plain DOS.", "OpenLFN archive viewer", MB_OK | MB_ICONEXCLAMATION);
        return 2;
    }
    while (*command == ' ') command++;
    n = lstrlen(command);
    if (n >= sizeof(input)) return 2;
    if (n >= 2 && command[0] == '"' && command[n - 1] == '"') {
        _fmemcpy(input, command + 1, n - 2); input[n - 2] = 0;
    } else lstrcpy(input, command);
    if (!input[0]) {
        memset(&ofn, 0, sizeof(ofn)); ofn.lStructSize = sizeof(ofn);
        ofn.hInstance = instance; ofn.lpstrFile = input; ofn.nMaxFile = sizeof(input);
        ofn.lpstrFilter = "ZIP archives\0*.ZIP\0\0";
        ofn.lpstrTitle = "View ZIP contents (read-only)";
        ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST;
        if (!GetOpenFileName(&ofn)) return 0;
    }
    /* Native file-dialog callers pass absolute 8.3 paths. Resolve a manual
     * relative argument before changing the helper's working directory. */
    {
        OFSTRUCT parsed;
        if (OpenFile(input, &parsed, OF_PARSE) == HFILE_ERROR || lstrlen(parsed.szPathName) >= sizeof(input)) return 2;
        lstrcpy(input, parsed.szPathName);
    }
    n = GetModuleFileName(instance, helper, sizeof(helper));
    if (!n || n >= sizeof(helper)) return 2;
    separator = n;
    while (separator && helper[separator - 1] != '\\') separator--;
    if (separator + 13 >= sizeof(helper)) return 2;
    lstrcpy(helper + separator, "OLFNLIST.EXE");
    if (!ascii_path(input) || !ascii_path(helper) || _fstrchr(input, ' ') || _fstrchr(helper, ' ') ||
        lstrlen(input) + lstrlen(helper) + 12 > 120) {
        MessageBox(NULL, "Use short ASCII DOS paths for this experimental bridge.", "OpenLFN archive viewer", MB_OK);
        return 2;
    }
    if (!getcwd(original, sizeof(original)) || !GetTempFileName(0, "CAV", 0, reservation)) return 2;
    lstrcpy(work, reservation); n = lstrlen(work);
    if (n < 4) { cleanup(); return 2; }
    lstrcpy(work + n - 3, "ARC");
    if (!ascii_path(work) || mkdir(work)) { work[0] = 0; cleanup(); return 2; }
    if (chdir(work)) { cleanup(); return 2; }
    memset(&cls, 0, sizeof(cls));
    cls.hInstance = instance; cls.lpfnWndProc = ViewerProc; cls.lpszClassName = class_name;
    cls.hCursor = LoadCursor(NULL, IDC_ARROW); cls.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    if (!RegisterClass(&cls)) { cleanup(); return 2; }
    window = CreateWindow(class_name, "OpenLFN ZIP contents (experimental, read-only)",
        WS_OVERLAPPEDWINDOW, 20, 35, 600, 380, NULL, NULL, instance, NULL);
    if (!window) { cleanup(); return 2; }
    list = CreateWindow("LISTBOX", "", WS_CHILD | WS_VISIBLE | WS_VSCROLL | WS_HSCROLL |
        WS_BORDER | WS_TABSTOP, 8, 8, 576, 280, window, (HMENU)INDEX_LIST, instance, NULL);
    status = CreateWindow("STATIC", "Starting bounded DOS archive reader...", WS_CHILD | WS_VISIBLE,
        8, 295, 576, 40, window, (HMENU)INDEX_STATUS, instance, NULL);
    if (!list || !status) { DestroyWindow(window); return 2; }
    SendMessage(list, WM_SETFONT, (WPARAM)GetStockObject(ANSI_FIXED_FONT), FALSE);
    SendMessage(list, LB_SETHORIZONTALEXTENT, 1600, 0);
    ShowWindow(window, SW_SHOW); UpdateWindow(window);
    wsprintf(launch, "%s %s INDEX.BIN", (LPSTR)helper, (LPSTR)input);
    if (!SetTimer(window, 1, 250, NULL)) { DestroyWindow(window); return 2; }
    launched = GetTickCount(); helper_task = (HINSTANCE)WinExec(launch, SW_HIDE);
    if ((UINT)helper_task < 32) {
        KillTimer(window, 1); status_text("Cannot start OLFNLIST.EXE beside the viewer.");
    } else pending = TRUE;
    while (GetMessage(&message, NULL, 0, 0)) { TranslateMessage(&message); DispatchMessage(&message); }
    return 0;
}
