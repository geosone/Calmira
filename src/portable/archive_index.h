/* SPDX-License-Identifier: GPL-3.0-or-later
 * Length-delimited, little-endian read-only archive index, not a ZIP parser. */
#ifndef CALMIRA_ARCHIVE_INDEX_H
#define CALMIRA_ARCHIVE_INDEX_H
#ifdef __WATCOMC__
typedef unsigned long ArcU32;
#else
#include <stdint.h>
typedef uint32_t ArcU32;
#endif
typedef unsigned short ArcU16;
typedef unsigned char ArcByte;
#ifdef _M_I86
#define ARC_FAR __far
#define ARC_API __far __cdecl
#else
#define ARC_FAR
#define ARC_API
#endif
#ifdef __cplusplus
extern "C" {
#endif
#define ARC_COUNT_MAX 128
#define ARC_NAME_MAX 240
#define ARC_HEADER_SIZE 16
#define ARC_RECORD_SIZE 24
#define ARC_INDEX_MAX (24U + ARC_COUNT_MAX * (ARC_RECORD_SIZE + ARC_NAME_MAX))
#define ARC_DIRECTORY 1
#define ARC_ENCRYPTED 2
#define ARC_UTF8 4
#define ARC_ZIP 1
typedef struct {
    const ArcByte ARC_FAR *data;
    unsigned length, count, format;
} ArcIndex;
typedef struct {
    const ArcByte ARC_FAR *name;
    unsigned name_length, flags, method;
    ArcU32 unpacked_lo, unpacked_hi, packed_lo, packed_hi;
} ArcEntry;
ArcU16 ARC_API arc_get16(const ArcByte ARC_FAR *p);
ArcU32 ARC_API arc_get32(const ArcByte ARC_FAR *p);
void ARC_API arc_put16(ArcByte ARC_FAR *p, ArcU16 value);
void ARC_API arc_put32(ArcByte ARC_FAR *p, ArcU32 value);
ArcU32 ARC_API arc_crc(ArcU32 crc, const ArcByte ARC_FAR *p, unsigned count);
int ARC_API arc_index_validate(const ArcByte ARC_FAR *data, unsigned length, ArcIndex ARC_FAR *index);
int ARC_API arc_index_entry(const ArcIndex ARC_FAR *index, unsigned row, ArcEntry ARC_FAR *entry);
/* ASCII-escaped display: never inject controls, normalize paths or open entries.
 * Returns 0 on insufficient capacity, never silently truncates a name. */
int ARC_API arc_entry_display(const ArcEntry ARC_FAR *entry, char ARC_FAR *text, unsigned capacity);
void ARC_API arc_decimal(ArcU32 lo, ArcU32 hi, char ARC_FAR *text);
#ifdef __cplusplus
}
#endif
#endif
