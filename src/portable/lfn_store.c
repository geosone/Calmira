/* SPDX-License-Identifier: GPL-3.0-or-later
 * Recoverable, append-only DESCRIPT.ION updates over an injected DOS-like IO
 * interface. No allocation, Windows calls, actual-target creation or deletion.
 * CLFN.SAV serializes cooperating saves in one directory. Unexpected sidecars
 * are never overwritten or adopted; interrupted transactions need inspection.
 */
#include "lfn_store.h"
#include <stddef.h>

static unsigned length(LfnText text)
{
    unsigned n = 0;
    while (text[n]) n++;
    return n;
}

static void copy(LfnBuffer destination, LfnText source)
{
    while ((*destination++ = *source++) != 0) ;
}

static char upper(char c)
{
    return c >= 'a' && c <= 'z' ? c - ('a' - 'A') : c;
}

static int equal(LfnText a, LfnText b, unsigned count)
{
    unsigned i;
    for (i = 0; i < count; i++) if (upper(a[i]) != upper(b[i])) return 0;
    return 1;
}

static int dos_char(char c)
{
    LfnText punctuation = "$%'-_@~`!(){}^#&";
    c = upper(c);
    if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) return 1;
    while (*punctuation) if (*punctuation++ == c) return 1;
    return 0;
}

static int device(LfnText name, unsigned size)
{
    return (size == 3 && (equal(name, "CON", 3) || equal(name, "PRN", 3) ||
        equal(name, "AUX", 3) || equal(name, "NUL", 3))) ||
        (size == 4 && (equal(name, "COM", 3) || equal(name, "LPT", 3)) &&
         name[3] >= '1' && name[3] <= '9');
}

int LFN_API lfn_is_dos_name(LfnText name)
{
    unsigned n = length(name), dot = n, i;
    if (!n || n > 12) return 0;
    for (i = 0; i < n; i++) {
        if (name[i] == '.') {
            if (dot != n) return 0;
            dot = i;
        } else if (!dos_char(name[i])) return 0;
    }
    return dot && dot <= 8 && (dot == n || (n > dot + 1 && n - dot - 1 <= 3)) &&
        !device(name, dot);
}

int LFN_API lfn_valid_leaf(LfnText name)
{
    unsigned n = length(name), i;
    LfnText bad = "\\/:*?\"<>|";
    if (!n || n > LFN_NAME_MAX || name[n - 1] == ' ' || name[n - 1] == '.') return 0;
    for (i = 0; i < n; i++) {
        LfnText p = bad;
        if ((unsigned char)name[i] < 32) return 0;
        while (*p) if (name[i] == *p++) return 0;
    }
    return 1;
}

void LFN_API lfn_make_alias(LfnText name, unsigned serial, LfnBuffer alias)
{
    unsigned n = length(name), dot = n, i, used = 0, digits = 0, limit;
    char number[6];
    if (lfn_is_dos_name(name)) {
        for (i = 0; i <= n; i++) alias[i] = upper(name[i]);
        return;
    }
    if (!serial) serial = 1;
    do {
        number[digits++] = (char)('0' + serial % 10);
        serial /= 10;
    } while (serial && digits < 5);
    for (i = 1; i < n; i++) if (name[i] == '.') dot = i;
    limit = 7 - digits;
    for (i = 0; i < dot && used < limit; i++) {
        if (name[i] == ' ' || name[i] == '.') continue;
        alias[used++] = dos_char(name[i]) ? upper(name[i]) : '_';
    }
    if (!used) {
        LfnText fallback = "FILE";
        while (*fallback && used < limit) alias[used++] = *fallback++;
    }
    alias[used++] = '~';
    while (digits) alias[used++] = number[--digits];
    if (dot < n) {
        unsigned ext = 0;
        alias[used++] = '.';
        for (i = dot + 1; i < n && ext < 3; i++) {
            if (name[i] == ' ' || name[i] == '.') continue;
            alias[used++] = dos_char(name[i]) ? upper(name[i]) : '_';
            ext++;
        }
    }
    alias[used] = 0;
}

static void path(LfnBuffer result, const LfnSave LFN_FAR *save, LfnText leaf)
{
    copy(result, save->directory);
    copy(result + length(result), leaf);
}

static int fail(LfnSave LFN_FAR *save, int error)
{
    save->error = error;
    return error;
}

static int read_map(const LfnIo LFN_FAR *io, LfnText file, LfnBuffer data,
                    unsigned LFN_FAR *size, unsigned LFN_FAR *attributes)
{
    int handle;
    char extra;
    unsigned got, total = 0;
    *attributes = io->attributes(file);
    *size = 0;
    data[0] = 0;
    if (*attributes == 0xffffU) return LFN_DONE;
    if (*attributes & 0x11) return LFN_READONLY;
    handle = io->open_read(file);
    if (handle < 0) return LFN_IO_ERROR;
    do {
        got = io->read(handle, data + total, LFN_MAP_MAX - total);
        if (got == 0xffffU) { io->close(handle); return LFN_IO_ERROR; }
        total += got;
    } while (got && total < LFN_MAP_MAX);
    got = io->read(handle, &extra, 1);
    if (io->close(handle) || got == 0xffffU) return LFN_IO_ERROR;
    if (got) return LFN_TOO_LARGE;
    data[total] = 0;
    *size = total;
    return LFN_DONE;
}

/* 0: absent, 1: same alias/name, -1: alias or display-name conflict. */
static int mapping(LfnText data, unsigned size, LfnText alias, LfnText name)
{
    unsigned pos = 0, alias_size = length(alias), name_size = name ? length(name) : 0;
    while (pos < size) {
        unsigned start = pos, end, token, value, text_end;
        while (pos < size && data[pos] != '\r' && data[pos] != '\n') pos++;
        end = pos;
        while (pos < size && (data[pos] == '\r' || data[pos] == '\n')) pos++;
        token = start;
        while (token < end && data[token] != ' ' && data[token] != '\t') token++;
        value = token;
        while (value < end && (data[value] == ' ' || data[value] == '\t')) value++;
        text_end = value;
        while (text_end < end && data[text_end] != 4) text_end++;
        while (text_end > value && (data[text_end - 1] == ' ' || data[text_end - 1] == '\t')) text_end--;
        if (token - start == alias_size && equal(data + start, alias, alias_size)) {
            return name && text_end - value == name_size && equal(data + value, name, name_size) ? 1 : -1;
        }
        if (name && text_end - value == name_size && equal(data + value, name, name_size)) return -1;
    }
    return 0;
}

static unsigned journal_text(const LfnSave LFN_FAR *save, LfnBuffer text)
{
    copy(text, "CALMIRA-LFN-1\r\n");
    copy(text + length(text), save->alias);
    copy(text + length(text), " ");
    copy(text + length(text), save->name);
    copy(text + length(text), "\r\n");
    return length(text);
}

static int own_journal(const LfnIo LFN_FAR *io, const LfnSave LFN_FAR *save)
{
    char file[LFN_PATH_MAX], expected[272], actual[272];
    unsigned n = journal_text(save, expected), got, i;
    int handle, okay;
    path(file, save, "CLFN.SAV");
    handle = io->open_read(file);
    if (handle < 0) return 0;
    got = io->read(handle, actual, sizeof(actual));
    okay = got == n;
    for (i = 0; okay && i < n; i++) if (actual[i] != expected[i]) okay = 0;
    if (io->close(handle)) okay = 0;
    return okay;
}

int LFN_API lfn_reserve(const LfnIo LFN_FAR *io, LfnText directory,
    LfnText name, LfnSave LFN_FAR *save, LfnBuffer scratch)
{
    char file[LFN_PATH_MAX], journal[272];
    unsigned size, attributes, serial, n;
    int handle, result;
    if (save->state) return fail(save, LFN_BUSY);
    n = length(directory);
    if (!lfn_valid_leaf(name) || lfn_is_dos_name(name) || !n || n >= sizeof(save->directory) ||
        (directory[n - 1] != '\\' && directory[n - 1] != '/')) return fail(save, LFN_INVALID);
    copy(save->directory, directory);
    copy(save->name, name);
    path(file, save, "CLFN.SAV");
    handle = io->create_new(file);
    if (handle < 0) return fail(save, LFN_BUSY);
    path(file, save, "DESCRIPT.ION");
    result = read_map(io, file, scratch, &size, &attributes);
    if (result == LFN_DONE && mapping(scratch, size, "", name)) result = LFN_CONFLICT;
    if (result == LFN_DONE) {
        for (serial = 1; serial <= 9999; serial++) {
            lfn_make_alias(name, serial, save->alias);
            path(file, save, save->alias);
            if (io->attributes(file) == 0xffffU && !mapping(scratch, size, save->alias, NULL)) break;
        }
        if (serial > 9999) result = LFN_CONFLICT;
    }
    if (result == LFN_DONE) {
        n = journal_text(save, journal);
        if (io->write(handle, journal, n) != n || io->flush(handle)) result = LFN_IO_ERROR;
    }
    if (io->close(handle)) result = LFN_IO_ERROR;
    if (result != LFN_DONE) {
        path(file, save, "CLFN.SAV");
        io->remove(file); /* only the journal just exclusively created above */
        return fail(save, result);
    }
    save->state = LFN_RESERVED;
    save->error = 0;
    return LFN_DONE;
}

int LFN_API lfn_accept(LfnSave LFN_FAR *save)
{
    if (save->state != LFN_RESERVED) return fail(save, LFN_INVALID);
    save->state = LFN_ACCEPTED;
    return LFN_DONE;
}

int LFN_API lfn_discard(const LfnIo LFN_FAR *io, LfnSave LFN_FAR *save)
{
    char journal[LFN_PATH_MAX];
    if (!save->state) return LFN_DONE;
    if (!own_journal(io, save)) return fail(save, LFN_CONFLICT);
    path(journal, save, "CLFN.SAV");
    if (io->remove(journal)) return fail(save, LFN_IO_ERROR);
    save->state = 0;
    return LFN_DONE;
}

int LFN_API lfn_commit(const LfnIo LFN_FAR *io, LfnSave LFN_FAR *save, LfnBuffer scratch)
{
    char target[LFN_PATH_MAX], lock[LFN_PATH_MAX], temporary[LFN_PATH_MAX];
    char backup[LFN_PATH_MAX], description[LFN_PATH_MAX], line[256];
    unsigned size, attributes, n, target_attributes;
    int target_handle, lock_handle, output, result, found, original_moved = 0;
    if (save->state != LFN_ACCEPTED) return LFN_WAIT;
    if (!own_journal(io, save)) return fail(save, LFN_CONFLICT);
    path(target, save, save->alias);
    target_attributes = io->attributes(target);
    if (target_attributes == 0xffffU) return LFN_WAIT;
    if (target_attributes & 0x10) return fail(save, LFN_CONFLICT);
    target_handle = io->open_exclusive(target);
    if (target_handle < 0) return LFN_WAIT;
    path(lock, save, "CLFN.LCK");
    path(temporary, save, "CLFN.NEW");
    path(backup, save, "CLFN.BAK");
    path(description, save, "DESCRIPT.ION");
    lock_handle = io->create_new(lock);
    if (lock_handle < 0) { io->close(target_handle); return fail(save, LFN_BUSY); }
    result = read_map(io, description, scratch, &size, &attributes);
    if (result != LFN_DONE) goto release_lock;
    found = mapping(scratch, size, save->alias, save->name);
    if (found < 0) { result = LFN_CONFLICT; goto release_lock; }
    if (found == 1) goto mapped;
    if (io->attributes(backup) != 0xffffU) { result = LFN_RECOVERY; goto release_lock; }
    n = length(save->alias);
    copy(line, save->alias);
    line[n++] = ' ';
    copy(line + n, save->name);
    n += length(save->name);
    line[n++] = '\r';
    line[n++] = '\n';
    if (size + n + 2 > LFN_MAP_MAX) { result = LFN_TOO_LARGE; goto release_lock; }
    output = io->create_new(temporary);
    if (output < 0) { result = LFN_BUSY; goto release_lock; }
    result = LFN_DONE;
    if (size && io->write(output, scratch, size) != size) result = LFN_IO_ERROR;
    if (size && scratch[size - 1] != '\n') {
        LfnText newline = scratch[size - 1] == '\r' ? "\n" : "\r\n";
        unsigned count = length(newline);
        if (io->write(output, newline, count) != count) result = LFN_IO_ERROR;
    }
    if (io->write(output, line, n) != n || io->flush(output)) result = LFN_IO_ERROR;
    if (io->close(output)) result = LFN_IO_ERROR;
    if (result != LFN_DONE) { io->remove(temporary); goto release_lock; }
    if (attributes != 0xffffU) {
        if (io->rename(description, backup)) {
            io->remove(temporary);
            result = LFN_IO_ERROR;
            goto release_lock;
        }
        original_moved = 1;
    }
    if (io->rename(temporary, description)) {
        if (original_moved && io->rename(backup, description)) {
            io->close(lock_handle);
            io->close(target_handle);
            return fail(save, LFN_RECOVERY); /* retain lock, backup, temp and journal */
        }
        io->remove(temporary);
        result = LFN_IO_ERROR;
        goto release_lock;
    }
    if ((attributes != 0xffffU && io->set_attributes(description, attributes)) ||
        (original_moved && io->remove(backup))) {
        io->close(lock_handle);
        io->close(target_handle);
        return fail(save, LFN_RECOVERY);
    }
mapped:
    result = LFN_DONE;
release_lock:
    if (io->close(lock_handle) || io->remove(lock)) result = LFN_RECOVERY;
    if (io->close(target_handle)) result = LFN_RECOVERY;
    /* The journal must outlive all transaction cleanup. Otherwise a failed
     * lock removal could look like a finished save to the resident owner. */
    if (result == LFN_DONE) result = lfn_discard(io, save);
    return result < 0 ? fail(save, result) : result;
}
