/* SPDX-License-Identifier: GPL-3.0-or-later
 * Shared Win3.1 COMMDLG/verified Office hooks. Return native DOS names.
 * Never patch COMMDLG code or write/delete the application's document data. */
#include "clfnhook.h"
#include "clfnstore.h"
#include "../portable/lfn_store.h"
#include <string.h>

#define MAX_DIALOGS 8
#define MAX_MAP 32760U
#define FILE_LIST 0x0460
#define FILE_EDIT 0x0480
#define FILE_TYPES 0x0470
#define REFRESH_TIMER 0x6f11
#define OFFICE_ALIASES 0x6f12
#define OFFICE_SHOW_NAMES 0x6f20
#define ARCHIVE_PREVIEW 0x6f30
/* A global callback runs in a foreign task. Never borrow its DS, even if
 * the NE loader did not rewrite the legacy export prologue. */
#define EXPORT __export __loadds

typedef struct {
    HWND dialog, original, display;
    WNDPROC previous;
    HGLOBAL map_handle;
    LPSTR map;
    UINT map_length;
    DWORD fingerprint;
    int save_slot;
    BOOL accepting;
    HWND edit, panel;
    BOOL office, attempt_pending;
    char attempted_name[LFN_NAME_MAX + 1], attempted_alias[13];
} DIALOG_STATE;
typedef void (FAR PASCAL *OEM_CONVERTER)(LPCSTR, LPSTR);

static HINSTANCE dll_instance;
static HINSTANCE keepalive;
static HHOOK cbt_hook;
static HHOOK message_hook;
static BOOL office_class_registered;
static WORD attached_count;
static WORD activation_count, last_reason;
static OEM_CONVERTER oem_to_ansi;
static DIALOG_STATE dialogs[MAX_DIALOGS];
static char property_name[] = "OpenLFN.LfnDialog.1";
static char office_class[] = "OpenLFN.OfficeNames.1";

LRESULT CALLBACK EXPORT OfficeDialogProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK EXPORT OfficePanelProc(HWND, UINT, WPARAM, LPARAM);

static BOOL same_ascii(LPCSTR left, LPCSTR right, UINT count)
{
    UINT i;
    for (i = 0; i < count; i++) {
        char a = left[i], b = right[i];
        if (a >= 'a' && a <= 'z') a -= 'a' - 'A';
        if (b >= 'a' && b <= 'z') b -= 'a' - 'A';
        if (a != b) return FALSE;
    }
    return TRUE;
}

static void read_map(DIALOG_STATE *state)
{
    HFILE file;
    char extra;
    UINT length;
    state->map_length = 0;
    file = _lopen("DESCRIPT.ION", OF_READ | OF_SHARE_DENY_NONE);
    if (file == HFILE_ERROR) return;
    length = _lread(file, state->map, MAX_MAP);
    if (length != (UINT)-1 && _lread(file, &extra, 1) == 0) {
        state->map_length = length;
        state->map[length] = 0;
    }
    _lclose(file);
}

static void display_name(DIALOG_STATE *state, LPCSTR alias, LPSTR text)
{
    UINT pos = 0, name_length = lstrlen(alias);
    lstrcpy(text, alias);
    while (pos < state->map_length) {
        UINT start = pos, end, value, length;
        while (pos < state->map_length && state->map[pos] != '\r' &&
               state->map[pos] != '\n') pos++;
        end = pos;
        while (pos < state->map_length && (state->map[pos] == '\r' ||
               state->map[pos] == '\n')) pos++;
        if (end - start <= name_length ||
            !same_ascii(state->map + start, alias, name_length)) continue;
        value = start + name_length;
        if (state->map[value] != ' ' && state->map[value] != '\t') continue;
        while (value < end && (state->map[value] == ' ' || state->map[value] == '\t')) value++;
        for (length = 0; value + length < end && state->map[value + length] != 4; length++) ;
        while (length && state->map[value + length - 1] == ' ') length--;
        if (!length || length > 240) return;
        _fmemcpy(text, state->map + value, length);
        text[length] = 0;
        if (oem_to_ansi) oem_to_ansi(text, text);
        return;
    }
}

static DWORD hash_text(DWORD hash, LPCSTR text)
{
    while (*text) hash = (hash * 33UL) ^ (BYTE)*text++;
    return hash;
}

static BOOL item_text(HWND list, int index, LPSTR text)
{
    LONG length = SendMessage(list, LB_GETTEXTLEN, index, 0);
    if (length < 0 || length > 255) return FALSE;
    return SendMessage(list, LB_GETTEXT, index, (LPARAM)text) != LB_ERR;
}

static void refresh(DIALOG_STATE *state)
{
    int i, count = (int)SendMessage(state->original, LB_GETCOUNT, 0, 0);
    DWORD hash = 5381;
    char alias[256], text[256];
    if (count < 0) return;
    read_map(state);
    for (i = 0; i < count; i++) {
        if (!item_text(state->original, i, alias)) return;
        display_name(state, alias, text);
        hash = hash_text(hash_text(hash, alias), text) + 1;
    }
    if (hash != state->fingerprint) {
        int widest = 0;
        HDC dc = GetDC(state->display);
        HFONT font = (HFONT)SendMessage(state->display, WM_GETFONT, 0, 0);
        HFONT old_font = NULL;
        if (dc && font) old_font = SelectObject(dc, font);
        SendMessage(state->display, WM_SETREDRAW, FALSE, 0);
        SendMessage(state->display, LB_RESETCONTENT, 0, 0);
        for (i = 0; i < count; i++) {
            if (!item_text(state->original, i, alias)) break;
            display_name(state, alias, text);
            if (SendMessage(state->display, LB_ADDSTRING, 0, (LPARAM)(LPSTR)text) < 0) break;
            if (dc) {
                int width = LOWORD(GetTextExtent(dc, text, lstrlen(text)));
                if (width > widest) widest = width;
            }
        }
        if (dc) {
            if (old_font) SelectObject(dc, old_font);
            ReleaseDC(state->display, dc);
        }
        SendMessage(state->display, LB_SETHORIZONTALEXTENT, widest + 8, 0);
        SendMessage(state->display, WM_SETREDRAW, TRUE, 0);
        if (i != count) {
            ShowWindow(state->display, SW_HIDE);
            ShowWindow(state->original, SW_SHOW);
            return;
        }
        state->fingerprint = hash;
        InvalidateRect(state->display, NULL, TRUE);
    }
    if (GetWindowLong(state->original, GWL_STYLE) & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL)) {
        for (i = 0; i < count; i++)
            SendMessage(state->display, LB_SETSEL,
                (WPARAM)SendMessage(state->original, LB_GETSEL, i, 0), i);
    } else {
        LONG selection = SendMessage(state->original, LB_GETCURSEL, 0, 0);
        SendMessage(state->display, LB_SETCURSEL, (WPARAM)selection, 0);
    }
}

static void sync_selection(DIALOG_STATE *state)
{
    int i, count;
    if (GetWindowLong(state->original, GWL_STYLE) & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL)) {
        count = (int)SendMessage(state->display, LB_GETCOUNT, 0, 0);
        for (i = 0; i < count; i++)
            SendMessage(state->original, LB_SETSEL,
                (WPARAM)SendMessage(state->display, LB_GETSEL, i, 0), i);
        SendMessage(state->original, LB_SETCARETINDEX,
            (WPARAM)SendMessage(state->display, LB_GETCARETINDEX, 0, 0), FALSE);
    } else
        SendMessage(state->original, LB_SETCURSEL,
            (WPARAM)SendMessage(state->display, LB_GETCURSEL, 0, 0), 0);
}

static void release_state(DIALOG_STATE *state)
{
    if (state->save_slot) ClfnCancelSave(state->save_slot);
    if (state->map_handle) {
        GlobalUnlock(state->map_handle);
        GlobalFree(state->map_handle);
    }
    _fmemset(state, 0, sizeof(*state));
}

static int resolve_display_name(DIALOG_STATE *state, LPCSTR name, LPSTR result)
{
    unsigned pos = 0;
    char alias[13], display[256];
    int found = 0;
    read_map(state);
    /* Parse all aliases, not only files visible under the current filter. */
    while (pos < state->map_length) {
        unsigned start = pos, end, token;
        while (pos < state->map_length && state->map[pos] != '\r' && state->map[pos] != '\n') pos++;
        end = pos;
        while (pos < state->map_length && (state->map[pos] == '\r' || state->map[pos] == '\n')) pos++;
        token = start;
        while (token < end && state->map[token] != ' ' && state->map[token] != '\t') token++;
        if (token == start || token - start > 12) continue;
        _fmemcpy(alias, state->map + start, token - start);
        alias[token - start] = 0;
        if (!lfn_is_dos_name(alias)) continue;
        display_name(state, alias, display);
        if (lstrcmpi(display, name)) continue;
        if (found && lstrcmpi(result, alias)) return -1;
        lstrcpy(result, alias);
        found = 1;
    }
    return found;
}

static BOOL is_common_dialog_instance(HWND window)
{
    char actual[128], expected[128];
    UINT actual_length, expected_length;
    HMODULE common = GetModuleHandle("COMMDLG");
    if (!common) return FALSE;
    /* Win16 module and instance handles differ. Compare their canonical
     * module paths, not the numeric HMODULE and GWW_HINSTANCE values. */
    actual_length = GetModuleFileName((HINSTANCE)GetWindowWord(window, GWW_HINSTANCE),
                                     actual, sizeof(actual));
    expected_length = GetModuleFileName(common, expected, sizeof(expected));
    return actual_length && actual_length < sizeof(actual) &&
           expected_length && expected_length < sizeof(expected) &&
           !lstrcmpi(actual, expected);
}

static void preview_archive(DIALOG_STATE *state)
{
    char typed[LFN_NAME_MAX + 2], alias[13], viewer[128], command[256];
    OFSTRUCT parsed;
    HFILE probe;
    UINT length;
    int separator, resolved;
    LPSTR extension;
    typed[0] = 0;
    if (state->office)
        SendMessage(state->edit, WM_GETTEXT, sizeof(typed), (LPARAM)(LPSTR)typed);
    else GetDlgItemText(state->dialog, FILE_EDIT, typed, sizeof(typed));
    typed[sizeof(typed) - 1] = 0;
    resolved = resolve_display_name(state, typed, alias);
    if (resolved > 0) lstrcpy(typed, alias);
    extension = _fstrrchr(typed, '.');
    if (resolved < 0 || !extension || lstrcmpi(extension, ".ZIP") ||
        _fstrchr(typed, '*') || _fstrchr(typed, '?')) {
        MessageBox(state->dialog, "Select an existing ZIP filename first.\n"
            "The initial native archive viewer is read-only and ZIP-only.", "OpenLFN archive preview", MB_OK);
        return;
    }
    probe = _lopen(typed, OF_READ | OF_SHARE_DENY_NONE);
    if (probe == HFILE_ERROR) {
        MessageBox(state->dialog, "Cannot read the selected ZIP file.\n"
            "Check that it exists and is accessible.", "OpenLFN archive preview", MB_OK | MB_ICONEXCLAMATION);
        return;
    }
    _lclose(probe);
    if (OpenFile(typed, &parsed, OF_PARSE) == HFILE_ERROR) {
        MessageBox(state->dialog, "Cannot resolve the selected ZIP path.",
            "OpenLFN archive preview", MB_OK | MB_ICONEXCLAMATION);
        return;
    }
    length = GetModuleFileName(dll_instance, viewer, sizeof(viewer));
    if (!length || length >= sizeof(viewer)) return;
    separator = length;
    while (separator && viewer[separator - 1] != '\\') separator--;
    if (separator + 12 >= sizeof(viewer)) return;
    lstrcpy(viewer + separator, "OLFNVIEW.EXE");
    wsprintf(command, "%s %s", (LPSTR)viewer, (LPSTR)parsed.szPathName);
    if (WinExec(command, SW_SHOW) < 32)
        MessageBox(state->dialog, "Place OLFNVIEW.EXE and OLFNLIST.EXE beside OLFNHOOK.DLL.\n"
            "Build them with make archive-viewer.", "Cannot start archive preview", MB_OK | MB_ICONEXCLAMATION);
}

/* Office SDM lists/buttons are painted by the dialog itself. Never send LB_*
 * to them or infer their identity from translated captions or pixel offsets.
 * This companion list contains mapped, existing files only; native controls
 * and format/overwrite validation remain owned by Office. */
static void refresh_office(DIALOG_STATE *state)
{
    unsigned pos = 0, added = 0;
    char alias[13];
    read_map(state);
    SendMessage(state->original, LB_RESETCONTENT, 0, 0);
    while (pos < state->map_length && added < 512) {
        unsigned start = pos, end, token;
        HFILE file;
        while (pos < state->map_length && state->map[pos] != '\r' && state->map[pos] != '\n') pos++;
        end = pos;
        while (pos < state->map_length && (state->map[pos] == '\r' || state->map[pos] == '\n')) pos++;
        token = start;
        while (token < end && state->map[token] != ' ' && state->map[token] != '\t') token++;
        if (token == start || token - start > 12 || token == end) continue;
        _fmemcpy(alias, state->map + start, token - start);
        alias[token - start] = 0;
        if (!lfn_is_dos_name(alias)) continue;
        file = _lopen(alias, OF_READ | OF_SHARE_DENY_NONE);
        if (file == HFILE_ERROR) continue;
        _lclose(file);
        if (SendMessage(state->original, LB_ADDSTRING, 0, (LPARAM)(LPSTR)alias) < 0) break;
        added++;
    }
    refresh(state);
}

LRESULT CALLBACK EXPORT OfficePanelProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    UINT slot = (UINT)GetProp(window, property_name);
    DIALOG_STATE *state;
    if (!slot || slot > MAX_DIALOGS) return DefWindowProc(window, message, wp, lp);
    state = &dialogs[slot - 1];
    if (message == WM_CLOSE) { ShowWindow(window, SW_HIDE); return 0; }
    if (message == WM_COMMAND && wp == CLFN_LIST_ID &&
        (HIWORD(lp) == LBN_SELCHANGE || HIWORD(lp) == LBN_DBLCLK)) {
        char alias[256];
        int index = (int)SendMessage(state->display, LB_GETCURSEL, 0, 0);
        if (index >= 0 && item_text(state->original, index, alias)) {
            SendMessage(state->edit, WM_SETTEXT, 0, (LPARAM)(LPSTR)alias);
            if (HIWORD(lp) == LBN_DBLCLK) {
                SetActiveWindow(state->dialog);
                SetFocus(state->edit);
                PostMessage(state->edit, WM_KEYDOWN, VK_RETURN, 1L);
                PostMessage(state->edit, WM_KEYUP, VK_RETURN, 0xc0000001L);
            }
        }
        return 0;
    }
    return DefWindowProc(window, message, wp, lp);
}

LRESULT CALLBACK EXPORT OfficeDialogProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    UINT slot = (UINT)GetProp(window, property_name);
    DIALOG_STATE *state;
    WNDPROC previous;
    if (!slot || slot > MAX_DIALOGS) return DefWindowProc(window, message, wp, lp);
    state = &dialogs[slot - 1];
    previous = state->previous;
    if (message == WM_SYSCOMMAND && (wp & 0xfff0) == ARCHIVE_PREVIEW) {
        preview_archive(state); return 0;
    }
    if (message == WM_SYSCOMMAND && (wp & 0xfff0) == OFFICE_SHOW_NAMES) {
        ShowWindow(state->panel, SW_SHOWNOACTIVATE);
        return 0;
    }
    if (message == WM_TIMER && wp == REFRESH_TIMER) {
        if (state->attempt_pending && IsWindowVisible(window)) {
            char current[LFN_NAME_MAX + 2];
            if (state->save_slot) ClfnCancelSave(state->save_slot);
            state->save_slot = 0;
            state->accepting = FALSE;
            current[0] = 0;
            SendMessage(state->edit, WM_GETTEXT, sizeof(current), (LPARAM)(LPSTR)current);
            current[sizeof(current) - 1] = 0;
            if (!lstrcmpi(current, state->attempted_alias))
                SendMessage(state->edit, WM_SETTEXT, 0, (LPARAM)(LPSTR)state->attempted_name);
            state->attempt_pending = FALSE;
        }
        refresh_office(state);
        return 0;
    }
    if (message == WM_CLOSE) state->accepting = FALSE;
    if (message == WM_NCDESTROY) {
        if (state->save_slot) {
            if (state->accepting) ClfnAcceptSave(state->save_slot);
            else ClfnCancelSave(state->save_slot);
            state->save_slot = 0;
        }
        KillTimer(window, REFRESH_TIMER);
        RemoveProp(window, property_name);
        SetWindowLong(window, GWL_WNDPROC, (LONG)previous);
        DestroyWindow(state->panel);
        release_state(state);
    }
    return CallWindowProc(previous, window, message, wp, lp);
}

static void attach_office(HWND window, LPCSTR cls)
{
    char name[40], module[128];
    LPCSTR expected;
    UINT edit_id;
    UINT module_length;
    HWND edit;
    DIALOG_STATE *state;
    int slot, left, top;
    HMENU menu;
    if (!lstrcmp(cls, "bosa_sdm_Microsoft Word 6.0")) {
        expected = "WINWORD.EXE"; edit_id = 1818;
    } else if (!lstrcmp(cls, "bosa_sdm_XL")) {
        expected = "EXCEL.EXE"; edit_id = 4864;
    } else return;
    module_length = GetModuleFileName((HINSTANCE)GetWindowWord(window, GWW_HINSTANCE), module, sizeof(module));
    if (!module_length || module_length >= sizeof(module)) return;
    {
        LPSTR leaf = _fstrrchr(module, '\\');
        if (lstrcmpi(leaf ? leaf + 1 : module, expected)) return;
    }
    edit = GetDlgItem(window, edit_id);
    if (!edit || !GetClassName(edit, name, sizeof(name)) ||
        lstrcmp(name, edit_id == 1818 ? "OpusFedt" : "EDTBX")) return;
    /* Other SDM dialogs can contain edit fields; require the independently
     * observed file-list and directory-list scrollbar IDs as well. */
    if (!GetDlgItem(window, edit_id + 1) ||
        !GetDlgItem(window, edit_id == 1818 ? 1283 : 4866)) return;
    for (slot = 0; slot < MAX_DIALOGS && dialogs[slot].dialog; slot++) ;
    if (slot == MAX_DIALOGS) return;
    state = &dialogs[slot];
    state->map_handle = GlobalAlloc(GMEM_MOVEABLE, MAX_MAP + 1UL);
    if (!state->map_handle) return;
    state->map = GlobalLock(state->map_handle);
    if (!state->map) { release_state(state); return; }
    state->dialog = window; state->edit = edit; state->office = TRUE;
    left = GetSystemMetrics(SM_CXSCREEN) - 235;
    top = GetSystemMetrics(SM_CYSCREEN) - 110;
    state->panel = CreateWindow(office_class, "OpenLFN: mapped long names", WS_POPUP |
        WS_CAPTION | WS_BORDER | WS_SYSMENU, left, top, 235, 110, window, NULL, dll_instance, NULL);
    if (!state->panel) { release_state(state); return; }
    state->original = CreateWindow("LISTBOX", "", WS_CHILD, 0, 0, 1, 1,
        state->panel, (HMENU)OFFICE_ALIASES, dll_instance, NULL);
    state->display = CreateWindow("LISTBOX", "", WS_CHILD | WS_VISIBLE | WS_VSCROLL |
        WS_HSCROLL | WS_TABSTOP | LBS_NOTIFY | WS_BORDER, 0, 0, 227, 80,
        state->panel, (HMENU)CLFN_LIST_ID, dll_instance, NULL);
    if (!state->original || !state->display ||
        !SetProp(state->panel, property_name, (HANDLE)(slot + 1)) ||
        !SetProp(window, property_name, (HANDLE)(slot + 1))) {
        RemoveProp(window, property_name);
        DestroyWindow(state->panel); release_state(state); return;
    }
    state->previous = (WNDPROC)GetWindowLong(window, GWL_WNDPROC);
    if (!SetWindowLong(window, GWL_WNDPROC, (LONG)(WNDPROC)OfficeDialogProc)) {
        RemoveProp(window, property_name);
        DestroyWindow(state->panel); release_state(state); return;
    }
    if (!SetTimer(window, REFRESH_TIMER, 250, NULL)) {
        SetWindowLong(window, GWL_WNDPROC, (LONG)state->previous);
        RemoveProp(window, property_name);
        DestroyWindow(state->panel); release_state(state); return;
    }
    SendMessage(state->display, WM_SETFONT, (WPARAM)GetStockObject(ANSI_VAR_FONT), FALSE);
    menu = GetSystemMenu(window, FALSE);
    if (menu) AppendMenu(menu, MF_STRING, OFFICE_SHOW_NAMES, "OpenLFN long names");
    if (menu) AppendMenu(menu, MF_STRING, ARCHIVE_PREVIEW, "View ZIP contents (read-only)");
    refresh_office(state);
    ShowWindow(state->panel, SW_SHOWNOACTIVATE);
    attached_count++;
}

/* SDM consumes Enter in its dialog loop before a normal window subclass sees
 * it. Convert only an explicit Enter in the verified filename edit; never on
 * WM_GETTEXT, which Word also sends for every character and on cancellation. */
LRESULT CALLBACK EXPORT OfficeMessageProc(int code, WPARAM wp, LPARAM lp)
{
    MSG FAR *event = (MSG FAR *)lp;
    int i;
    if (code >= 0 && wp && event->message == WM_LBUTTONDOWN) {
        for (i = 0; i < MAX_DIALOGS; i++) {
            DIALOG_STATE *state = &dialogs[i];
            if (state->office && state->save_slot && state->attempt_pending &&
                (event->hwnd == state->dialog || IsChild(state->dialog, event->hwnd)))
                state->accepting = FALSE; /* mouse cancellation can precede the veto timer */
        }
    }
    if (code >= 0 && wp && ((event->message >= WM_MOUSEFIRST && event->message <= WM_MOUSELAST) ||
        (event->message >= WM_KEYFIRST && event->message <= WM_KEYLAST))) {
        for (i = 0; i < MAX_DIALOGS; i++) {
            DIALOG_STATE *state = &dialogs[i];
            if (state->panel && (event->hwnd == state->panel || IsChild(state->panel, event->hwnd))) {
                /* SDM's modal loop otherwise consumes modeless companion input
                 * before DispatchMessage. Deliver only our own windows' input. */
                SendMessage(event->hwnd, event->message, event->wParam, event->lParam);
                event->message = WM_NULL;
                break;
            }
        }
    }
    if (code >= 0 && wp && event->message == WM_KEYDOWN) {
        for (i = 0; i < MAX_DIALOGS; i++) {
            DIALOG_STATE *state = &dialogs[i];
            char typed[LFN_NAME_MAX + 2], alias[13];
            int resolved;
            if (!state->dialog || !state->office ||
                (event->hwnd != state->dialog && !IsChild(state->dialog, event->hwnd))) continue;
            if (event->wParam == VK_ESCAPE) state->accepting = FALSE;
            if (event->wParam != VK_RETURN || GetFocus() != state->edit ||
                GetKeyState(VK_CONTROL) < 0 || GetKeyState(VK_MENU) < 0) break;
            typed[0] = 0;
            SendMessage(state->edit, WM_GETTEXT, sizeof(typed), (LPARAM)(LPSTR)typed);
            typed[sizeof(typed) - 1] = 0;
            if (lfn_is_dos_name(typed) || !lfn_valid_leaf(typed)) break;
            resolved = resolve_display_name(state, typed, alias);
            if (resolved < 0 || lstrlen(typed) > LFN_NAME_MAX) goto reject_office;
            if (!resolved) {
                LPSTR extension = _fstrrchr(typed, '.');
                if (!extension || extension == typed || !extension[1]) goto reject_office;
                if (state->save_slot) ClfnCancelSave(state->save_slot);
                state->save_slot = ClfnReserveSave(typed, alias);
                if (!state->save_slot) goto reject_office;
            }
            lstrcpy(state->attempted_name, typed);
            lstrcpy(state->attempted_alias, alias);
            state->accepting = TRUE;
            state->attempt_pending = TRUE;
            SendMessage(state->edit, WM_SETTEXT, 0, (LPARAM)(LPSTR)alias);
            break;
reject_office:
            event->message = WM_NULL;
            MessageBox(state->dialog, "Cannot use this long filename. Include an extension,\n"
                "and check pending saves or transaction recovery files.", "OpenLFN long filename",
                MB_OK | MB_ICONEXCLAMATION);
            break;
        }
    }
    return CallNextHookEx(message_hook, code, wp, lp);
}

LRESULT CALLBACK EXPORT FileDialogProc(HWND window, UINT message, WPARAM wp, LPARAM lp)
{
    UINT slot = (UINT)GetProp(window, property_name);
    DIALOG_STATE *state;
    WNDPROC previous;
    if (!slot || slot > MAX_DIALOGS) return DefWindowProc(window, message, wp, lp);
    state = &dialogs[slot - 1];
    previous = state->previous;
    if (message == WM_SYSCOMMAND && (wp & 0xfff0) == ARCHIVE_PREVIEW) {
        preview_archive(state); return 0;
    }
    if (message == WM_COMMAND && wp == IDOK) {
        char typed[LFN_NAME_MAX + 1], alias[13];
        LRESULT result;
        int saved_slot = 0;
        if (GetWindowTextLength(GetDlgItem(window, FILE_EDIT)) > LFN_NAME_MAX) return 0;
        GetDlgItemText(window, FILE_EDIT, typed, sizeof(typed));
        if (!lfn_is_dos_name(typed) && lfn_valid_leaf(typed)) {
            int resolved = resolve_display_name(state, typed, alias);
            if (resolved < 0) {
                MessageBox(window, "More than one DOS alias has this display name.\n"
                    "Select a file explicitly instead of guessing.", "OpenLFN long filename",
                    MB_OK | MB_ICONEXCLAMATION);
                return 0;
            }
            if (!resolved) {
                LPSTR extension = _fstrrchr(typed, '.');
                if (!extension || extension == typed || !extension[1]) {
                    MessageBox(window, "Include the file extension in a new long filename.",
                        "OpenLFN long filename", MB_OK | MB_ICONEXCLAMATION);
                    return 0;
                }
                saved_slot = ClfnReserveSave(typed, alias);
                if (!saved_slot) {
                    MessageBox(window, "Cannot reserve a long filename. The directory may be read-only,\n"
                        "have a pending save (CLFN.SAV), or need transaction recovery.\n"
                        "Existing metadata was not overwritten.", "OpenLFN long filename",
                        MB_OK | MB_ICONEXCLAMATION);
                    return 0;
                }
            }
            state->save_slot = saved_slot;
            state->accepting = TRUE;
            SetDlgItemText(window, FILE_EDIT, alias);
            result = CallWindowProc(previous, window, message, wp, lp);
            /* A validation error or application FILEOK veto kept the dialog
             * alive. Restore the user's input and cancel only our reservation. */
            if (IsWindow(window) && IsWindowVisible(window) &&
                GetProp(window, property_name) == (HANDLE)slot) {
                if (state->save_slot) ClfnCancelSave(state->save_slot);
                state->save_slot = 0;
                state->accepting = FALSE;
                GetDlgItemText(window, FILE_EDIT, alias, sizeof(alias));
                if (lfn_is_dos_name(alias)) SetDlgItemText(window, FILE_EDIT, typed);
            }
            return result;
        }
    }
    if ((message == WM_COMMAND && wp == IDCANCEL) || message == WM_CLOSE)
        state->accepting = FALSE;
    if (message == WM_COMMAND && wp == CLFN_LIST_ID) {
        UINT notification = HIWORD(lp);
        HWND original = state->original;
        if (notification == LBN_SELCHANGE || notification == LBN_DBLCLK) {
            sync_selection(state);
        }
        /* COMMDLG also tracks focus/selection-cancel notifications. Forward
         * the whole notification protocol, not only clicks. */
        return CallWindowProc(previous, window, WM_COMMAND, FILE_LIST,
                              MAKELONG(original, notification));
    } else if (message == WM_TIMER && wp == REFRESH_TIMER) {
        refresh(state);
        return 0;
    } else if (message == WM_NCDESTROY) {
        if (state->save_slot) {
            if (state->accepting) ClfnAcceptSave(state->save_slot);
            else ClfnCancelSave(state->save_slot);
            state->save_slot = 0;
        }
        KillTimer(window, REFRESH_TIMER);
        RemoveProp(window, property_name);
        SetWindowLong(window, GWL_WNDPROC, (LONG)previous);
        release_state(state);
    }
    return CallWindowProc(previous, window, message, wp, lp);
}

static void attach(HWND window)
{
    int slot;
    char name[80];
    HWND original;
    DIALOG_STATE *state;
    RECT rect;
    DWORD style;
    HFONT font;
    HWND previous_sibling;
    last_reason = 1;
    if (GetProp(window, property_name)) return;
    last_reason = 2;
    if (!GetClassName(window, name, sizeof(name))) return;
    if (lstrcmp(name, "#32770")) { attach_office(window, name); return; }
    last_reason = 3;
    if (!is_common_dialog_instance(window)) return;
    last_reason = 4;
    original = GetDlgItem(window, FILE_LIST);
    if (!original || !GetDlgItem(window, FILE_EDIT) || !GetDlgItem(window, FILE_TYPES)) return;
    if (!GetClassName(original, name, sizeof(name)) || lstrcmpi(name, "LISTBOX")) return;
    for (slot = 0; slot < MAX_DIALOGS && dialogs[slot].dialog; slot++) ;
    if (slot == MAX_DIALOGS) return;
    state = &dialogs[slot];
    state->map_handle = GlobalAlloc(GMEM_MOVEABLE, MAX_MAP + 1UL);
    if (!state->map_handle) return;
    state->map = GlobalLock(state->map_handle);
    if (!state->map) { release_state(state); return; }
    state->dialog = window;
    state->original = original;
    state->fingerprint = 0;
    GetWindowRect(original, &rect);
    ScreenToClient(window, (POINT FAR *)&rect.left);
    ScreenToClient(window, (POINT FAR *)&rect.right);
    style = WS_CHILD | WS_BORDER | WS_VSCROLL | WS_HSCROLL | WS_TABSTOP | LBS_NOTIFY |
        (GetWindowLong(original, GWL_STYLE) & (LBS_MULTIPLESEL | LBS_EXTENDEDSEL));
    state->display = CreateWindow("LISTBOX", "", style,
        rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top,
        window, (HMENU)CLFN_LIST_ID, dll_instance, NULL);
    if (!state->display || !SetProp(window, property_name, (HANDLE)(slot + 1))) {
        if (state->display) DestroyWindow(state->display);
        release_state(state);
        return;
    }
    state->previous = (WNDPROC)GetWindowLong(window, GWL_WNDPROC);
    if (!SetWindowLong(window, GWL_WNDPROC, (LONG)(WNDPROC)FileDialogProc)) {
        RemoveProp(window, property_name);
        DestroyWindow(state->display);
        release_state(state);
        return;
    }
    font = (HFONT)SendMessage(original, WM_GETFONT, 0, 0);
    if (!font) font = (HFONT)SendMessage(window, WM_GETFONT, 0, 0);
    if (!font) font = GetStockObject(ANSI_VAR_FONT);
    SendMessage(state->display, WM_SETFONT, (WPARAM)font, FALSE);
    previous_sibling = GetWindow(original, GW_HWNDPREV);
    SetWindowPos(state->display, previous_sibling ? previous_sibling : HWND_TOP,
                 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    refresh(state);
    if (!SetTimer(window, REFRESH_TIMER, 250, NULL)) {
        SetWindowLong(window, GWL_WNDPROC, (LONG)state->previous);
        RemoveProp(window, property_name);
        DestroyWindow(state->display);
        release_state(state);
        return;
    }
    ShowWindow(original, SW_HIDE);
    ShowWindow(state->display, SW_SHOW);
    {
        HMENU menu = GetSystemMenu(window, FALSE);
        if (menu) AppendMenu(menu, MF_STRING, ARCHIVE_PREVIEW, "View ZIP contents (read-only)");
    }
    attached_count++;
    last_reason = 0;
}

LRESULT CALLBACK EXPORT FileDialogCbtProc(int code, WPARAM wp, LPARAM lp)
{
    if (code == HCBT_ACTIVATE) { activation_count++; attach((HWND)wp); }
    return CallNextHookEx(cbt_hook, code, wp, lp);
}

BOOL WINAPI EXPORT StartFileDialogHook(void)
{
    char path[260];
    HMODULE keyboard;
    WNDCLASS cls;
    if (cbt_hook) return TRUE;
    /* A legacy DLL has independent global state but the same metadata journal.
     * Never install two competing versions into the shared Win16 desktop. */
    if (GetModuleHandle("CLFNHOOK")) return FALSE;
    keyboard = GetModuleHandle("KEYBOARD");
    if (!keyboard) keyboard = GetModuleHandle("KEYBOARD.DRV");
    if (keyboard) oem_to_ansi = (OEM_CONVERTER)GetProcAddress(keyboard, "OEMTOANSI");
    if (!keepalive) {
        if (!GetModuleFileName(dll_instance, path, sizeof(path))) return FALSE;
        keepalive = LoadLibrary(path);
        if ((UINT)keepalive < 32) { keepalive = 0; return FALSE; }
    }
    if (!office_class_registered) {
        _fmemset(&cls, 0, sizeof(cls));
        cls.style = CS_GLOBALCLASS;
        cls.hInstance = dll_instance;
        cls.lpfnWndProc = OfficePanelProc;
        cls.lpszClassName = office_class;
        cls.hCursor = LoadCursor(NULL, IDC_ARROW);
        cls.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        office_class_registered = RegisterClass(&cls) != 0;
    }
    if (office_class_registered) {
        message_hook = SetWindowsHookEx(WH_GETMESSAGE, (HOOKPROC)OfficeMessageProc, dll_instance, 0);
        if (message_hook)
            cbt_hook = SetWindowsHookEx(WH_CBT, (HOOKPROC)FileDialogCbtProc, dll_instance, 0);
    }
    if (!cbt_hook) {
        if (message_hook) UnhookWindowsHookEx(message_hook);
        message_hook = 0;
        if (office_class_registered && UnregisterClass(office_class, dll_instance))
            office_class_registered = FALSE;
        FreeLibrary(keepalive); keepalive = 0;
    }
    return cbt_hook != 0;
}

BOOL WINAPI EXPORT StopFileDialogHook(void)
{
    int i;
    BOOL okay = TRUE;
    if (ClfnPollSaves()) return FALSE; /* resident owner must finish/recover pending saves */
    if (message_hook && !UnhookWindowsHookEx(message_hook)) return FALSE;
    message_hook = 0;
    if (cbt_hook && !UnhookWindowsHookEx(cbt_hook)) return FALSE;
    cbt_hook = 0;
    for (i = 0; i < MAX_DIALOGS; i++) {
        DIALOG_STATE *state = &dialogs[i];
        if (!state->dialog) continue;
        if (IsWindow(state->dialog)) {
            if ((WNDPROC)GetWindowLong(state->dialog, GWL_WNDPROC) !=
                (state->office ? OfficeDialogProc : FileDialogProc) ||
                (state->office && (WNDPROC)GetWindowLong(state->panel, GWL_WNDPROC) != OfficePanelProc)) {
                okay = FALSE;
                continue; /* A later subclass still calls us; DLL must stay loaded. */
            }
            SetWindowLong(state->dialog, GWL_WNDPROC, (LONG)state->previous);
            KillTimer(state->dialog, REFRESH_TIMER);
            RemoveProp(state->dialog, property_name);
            {
                HMENU menu = GetSystemMenu(state->dialog, FALSE);
                if (menu) RemoveMenu(menu, ARCHIVE_PREVIEW, MF_BYCOMMAND);
            }
            if (state->office) {
                HMENU menu = GetSystemMenu(state->dialog, FALSE);
                if (menu) RemoveMenu(menu, OFFICE_SHOW_NAMES, MF_BYCOMMAND);
                DestroyWindow(state->panel);
            } else {
                DestroyWindow(state->display);
                ShowWindow(state->original, SW_SHOW);
            }
        }
        release_state(state);
    }
    if (okay && office_class_registered) {
        okay = UnregisterClass(office_class, dll_instance);
        if (okay) office_class_registered = FALSE;
    }
    if (okay && keepalive) {
        HINSTANCE held = keepalive;
        keepalive = 0;
        FreeLibrary(held);
    }
    return okay;
}

WORD WINAPI EXPORT FileDialogHookCount(void) { return attached_count; }
DWORD WINAPI EXPORT FileDialogHookDiagnostics(void) { return MAKELONG(last_reason, activation_count); }
WORD WINAPI EXPORT PollFileDialogSaves(void) { return ClfnPollSaves(); }
WORD WINAPI EXPORT PendingFileDialogSaves(void) { return ClfnPendingSaves(); }

int WINAPI LibMain(HINSTANCE instance, WORD data_segment, WORD heap, LPSTR command)
{
    (void)data_segment; (void)heap; (void)command;
    dll_instance = instance;
    return 1;
}

int CALLBACK EXPORT WEP(int reason)
{
    (void)reason;
    return 1;
}
