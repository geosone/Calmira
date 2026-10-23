/* SPDX-License-Identifier: GPL-3.0-or-later */
#ifndef CALMIRA_LFN_STORE_H
#define CALMIRA_LFN_STORE_H
#if defined(__WATCOMC__) && defined(__I86__)
#define LFN_FAR __far
#define LFN_API __far __cdecl
#else
#define LFN_FAR
#define LFN_API
#endif
#define LFN_MAP_MAX 32760U
#define LFN_PATH_MAX 96
#define LFN_NAME_MAX 240
#define LFN_RESERVED 1
#define LFN_ACCEPTED 2
#define LFN_WAIT 0
#define LFN_DONE 1
#define LFN_INVALID -1
#define LFN_BUSY -2
#define LFN_IO_ERROR -3
#define LFN_CONFLICT -4
#define LFN_RECOVERY -5
#define LFN_READONLY -6
#define LFN_TOO_LARGE -7

typedef const char LFN_FAR *LfnText;
typedef char LFN_FAR *LfnBuffer;
typedef struct {
    int (LFN_API *create_new)(LfnText);
    int (LFN_API *open_read)(LfnText);
    int (LFN_API *open_exclusive)(LfnText);
    unsigned (LFN_API *read)(int, LfnBuffer, unsigned);
    unsigned (LFN_API *write)(int, LfnText, unsigned);
    int (LFN_API *close)(int);
    int (LFN_API *flush)(int);
    int (LFN_API *rename)(LfnText, LfnText);
    int (LFN_API *remove)(LfnText);
    unsigned (LFN_API *attributes)(LfnText);
    int (LFN_API *set_attributes)(LfnText, unsigned);
} LfnIo;

typedef struct {
    unsigned state;
    int error;
    char directory[80]; /* absolute DOS path, with trailing separator */
    char alias[13];
    char name[LFN_NAME_MAX + 1]; /* OEM bytes, no paths/control characters */
} LfnSave;

int LFN_API lfn_is_dos_name(LfnText name);
int LFN_API lfn_valid_leaf(LfnText name);
void LFN_API lfn_make_alias(LfnText name, unsigned serial, LfnBuffer alias);
int LFN_API lfn_reserve(const LfnIo LFN_FAR *io, LfnText directory,
    LfnText name, LfnSave LFN_FAR *save, LfnBuffer scratch);
int LFN_API lfn_accept(LfnSave LFN_FAR *save);
int LFN_API lfn_discard(const LfnIo LFN_FAR *io, LfnSave LFN_FAR *save);
int LFN_API lfn_commit(const LfnIo LFN_FAR *io, LfnSave LFN_FAR *save,
    LfnBuffer scratch);
#endif
