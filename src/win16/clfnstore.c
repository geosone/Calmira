/* SPDX-License-Identifier: GPL-3.0-or-later
 * Win16 adapter for the portable transaction core. DOS create-new/rename
 * deliberately do not truncate existing sidecars or replace destinations.
 */
#include "clfnstore.h"
#include "../portable/lfn_store.h"
#include <string.h>

#define SAVE_SLOTS 8
static LfnSave saves[SAVE_SLOTS];
static HTASK owners[SAVE_SLOTS];
static BOOL cancelled[SAVE_SLOTS];
static BOOL busy;

static int dos_create_new(LfnText name);
#pragma aux dos_create_new = \
    "push ds" "mov ds,dx" "mov dx,ax" "xor cx,cx" \
    "mov ax,5b00h" "int 21h" "jnc done" "mov ax,0ffffh" \
    "done: pop ds" parm [dx ax] value [ax] modify [cx dx];

static int dos_open_exclusive(LfnText name);
#pragma aux dos_open_exclusive = \
    "push ds" "mov ds,dx" "mov dx,ax" "mov ax,3d10h" \
    "int 21h" "jnc done" "mov ax,0ffffh" "done: pop ds" \
    parm [dx ax] value [ax] modify [dx];

static int dos_open_read(LfnText name);
#pragma aux dos_open_read = \
    "push ds" "mov ds,dx" "mov dx,ax" "mov ax,3d20h" \
    "int 21h" "jnc done" "mov ax,0ffffh" "done: pop ds" \
    parm [dx ax] value [ax] modify [dx];

static int dos_rename(LfnText old_name, LfnText new_name);
#pragma aux dos_rename = \
    "push ds" "push es" "push di" "mov ds,dx" "mov dx,ax" \
    "mov es,cx" "mov di,bx" "mov ax,5600h" "int 21h" \
    "sbb ax,ax" "pop di" "pop es" "pop ds" \
    parm [dx ax] [cx bx] value [ax] modify [dx];

static int dos_remove(LfnText name);
#pragma aux dos_remove = \
    "push ds" "mov ds,dx" "mov dx,ax" "mov ah,41h" "int 21h" \
    "sbb ax,ax" "pop ds" parm [dx ax] value [ax] modify [dx];

static unsigned dos_attributes(LfnText name);
#pragma aux dos_attributes = \
    "push ds" "mov ds,dx" "mov dx,ax" "mov ax,4300h" "int 21h" \
    "jnc okay" "mov cx,0ffffh" "okay: mov ax,cx" "pop ds" \
    parm [dx ax] value [ax] modify [cx dx];

static int dos_set_attributes(LfnText name, unsigned attributes);
#pragma aux dos_set_attributes = \
    "push ds" "mov ds,dx" "mov dx,ax" "mov ax,4301h" "int 21h" \
    "sbb ax,ax" "pop ds" parm [dx ax] [cx] value [ax] modify [dx];

static int dos_flush(int handle);
#pragma aux dos_flush = "mov ah,68h" "int 21h" "sbb ax,ax" \
    parm [bx] value [ax];

static unsigned dos_drive(void);
#pragma aux dos_drive = "mov ah,19h" "int 21h" "xor ah,ah" value [ax];

static int dos_directory(LfnBuffer buffer);
#pragma aux dos_directory = \
    "push ds" "push si" "mov ds,dx" "mov si,ax" "xor dx,dx" \
    "mov ah,47h" "int 21h" "sbb ax,ax" "pop si" "pop ds" \
    parm [dx ax] value [ax] modify [dx];

static int LFN_API create_new(LfnText name) { return dos_create_new(name); }
static int LFN_API open_read(LfnText name) { return dos_open_read(name); }
static int LFN_API open_exclusive(LfnText name) { return dos_open_exclusive(name); }
static unsigned LFN_API read_data(int handle, LfnBuffer data, unsigned n) { return _lread(handle, data, n); }
static unsigned LFN_API write_data(int handle, LfnText data, unsigned n) { return _lwrite(handle, data, n); }
static int LFN_API close_file(int handle) { return _lclose(handle) == HFILE_ERROR ? -1 : 0; }
static int LFN_API flush_file(int handle) { return dos_flush(handle); }
static int LFN_API rename_file(LfnText from, LfnText to) { return dos_rename(from, to); }
static int LFN_API remove_file(LfnText name) { return dos_remove(name); }
static unsigned LFN_API attributes(LfnText name) { return dos_attributes(name); }
static int LFN_API set_attributes(LfnText name, unsigned value) { return dos_set_attributes(name, value); }
static const LfnIo io = {create_new, open_read, open_exclusive, read_data, write_data,
    close_file, flush_file, rename_file, remove_file, attributes, set_attributes};

WORD ClfnPendingSaves(void)
{
    WORD count = 0;
    int i;
    for (i = 0; i < SAVE_SLOTS; i++) if (saves[i].state) count++;
    return count;
}

int ClfnReserveSave(LPCSTR name, LPSTR alias)
{
    char directory[80], oem[LFN_NAME_MAX + 1];
    unsigned n;
    HGLOBAL memory;
    LPSTR scratch;
    int i, result;
    if (busy || lstrlen(name) > LFN_NAME_MAX) return 0;
    for (i = 0; i < SAVE_SLOTS && saves[i].state; i++) ;
    if (i == SAVE_SLOTS) return 0;
    directory[0] = (char)('A' + dos_drive());
    directory[1] = ':';
    directory[2] = '\\';
    if (dos_directory(directory + 3)) return 0;
    n = lstrlen(directory);
    if (n > sizeof(directory) - 2) return 0;
    if (directory[n - 1] != '\\') { directory[n++] = '\\'; directory[n] = 0; }
    AnsiToOem(name, oem);
    memory = GlobalAlloc(GMEM_MOVEABLE, LFN_MAP_MAX + 1UL);
    if (!memory) return 0;
    scratch = GlobalLock(memory);
    if (!scratch) { GlobalFree(memory); return 0; }
    busy = TRUE;
    result = lfn_reserve(&io, directory, oem, &saves[i], scratch);
    if (result == LFN_DONE) {
        owners[i] = GetCurrentTask();
        cancelled[i] = FALSE;
        lstrcpy(alias, saves[i].alias);
    }
    busy = FALSE;
    GlobalUnlock(memory);
    GlobalFree(memory);
    return result == LFN_DONE ? i + 1 : 0;
}

void ClfnAcceptSave(int slot)
{
    if (slot > 0 && slot <= SAVE_SLOTS) lfn_accept(&saves[slot - 1]);
}

void ClfnCancelSave(int slot)
{
    if (slot < 1 || slot > SAVE_SLOTS) return;
    cancelled[slot - 1] = TRUE;
    if (!busy) lfn_discard(&io, &saves[slot - 1]);
}

WORD ClfnPollSaves(void)
{
    HGLOBAL memory;
    LPSTR scratch;
    int i;
    char target[LFN_PATH_MAX];
    if (busy || !ClfnPendingSaves()) return ClfnPendingSaves();
    memory = GlobalAlloc(GMEM_MOVEABLE, LFN_MAP_MAX + 1UL);
    if (!memory) return ClfnPendingSaves();
    scratch = GlobalLock(memory);
    if (!scratch) { GlobalFree(memory); return ClfnPendingSaves(); }
    busy = TRUE;
    for (i = 0; i < SAVE_SLOTS; i++) {
        if (!saves[i].state) continue;
        if (cancelled[i]) lfn_discard(&io, &saves[i]);
        else if (saves[i].state == LFN_ACCEPTED) {
            int result = lfn_commit(&io, &saves[i], scratch);
            if (result == LFN_WAIT && !IsTask(owners[i])) {
                lstrcpy(target, saves[i].directory);
                lstrcat(target, saves[i].alias);
                if (dos_attributes(target) == 0xffffU) lfn_discard(&io, &saves[i]);
            }
        }
    }
    busy = FALSE;
    GlobalUnlock(memory);
    GlobalFree(memory);
    return ClfnPendingSaves();
}
