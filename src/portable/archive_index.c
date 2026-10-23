/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "archive_index.h"
typedef char arc_check_u32[sizeof(ArcU32) == 4 ? 1 : -1];
typedef char arc_check_u16[sizeof(ArcU16) == 2 ? 1 : -1];

ArcU16 ARC_API arc_get16(const ArcByte ARC_FAR *p) { return (ArcU16)(p[0] | ((ArcU16)p[1] << 8)); }
ArcU32 ARC_API arc_get32(const ArcByte ARC_FAR *p)
{ return (ArcU32)arc_get16(p) | ((ArcU32)arc_get16(p + 2) << 16); }
void ARC_API arc_put16(ArcByte ARC_FAR *p, ArcU16 value)
{ p[0] = (ArcByte)value; p[1] = (ArcByte)(value >> 8); }
void ARC_API arc_put32(ArcByte ARC_FAR *p, ArcU32 value)
{ arc_put16(p, (ArcU16)value); arc_put16(p + 2, (ArcU16)(value >> 16)); }
ArcU32 ARC_API arc_crc(ArcU32 crc, const ArcByte ARC_FAR *p, unsigned count)
{
    unsigned bit;
    while (count--) {
        crc ^= *p++;
        for (bit = 0; bit < 8; bit++) crc = (crc >> 1) ^ ((crc & 1) ? 0xedb88320UL : 0);
    }
    return crc;
}

static int utf8_next(const ArcByte ARC_FAR *p, unsigned left, ArcU32 ARC_FAR *value)
{
    unsigned n, i;
    ArcU32 v, minimum;
    if (!left) return 0;
    if (p[0] < 128) { *value = p[0]; return 1; }
    if (p[0] >= 0xc2 && p[0] <= 0xdf) { n = 2; v = p[0] & 31; minimum = 128; }
    else if (p[0] >= 0xe0 && p[0] <= 0xef) { n = 3; v = p[0] & 15; minimum = 0x800; }
    else if (p[0] >= 0xf0 && p[0] <= 0xf4) { n = 4; v = p[0] & 7; minimum = 0x10000UL; }
    else return 0;
    if (left < n) return 0;
    for (i = 1; i < n; i++) {
        if ((p[i] & 0xc0) != 0x80) return 0;
        v = (v << 6) | (p[i] & 63);
    }
    if (v < minimum || v > 0x10ffffUL || (v >= 0xd800 && v <= 0xdfff)) return 0;
    *value = v; return (int)n;
}

int ARC_API arc_index_validate(const ArcByte ARC_FAR *data, unsigned length, ArcIndex ARC_FAR *index)
{
    static const char magic[8] = {'C','L','A','R','C','I','1',0};
    unsigned i, count, pos, end;
    ArcU32 payload;
    index->data = 0; index->length = index->count = index->format = 0;
    if (!data || length < 24 || length > ARC_INDEX_MAX) return 0;
    for (i = 0; i < 8; i++) if (data[i] != (ArcByte)magic[i]) return 0;
    count = arc_get16(data + 8); payload = arc_get32(data + 12);
    if (count > ARC_COUNT_MAX || arc_get16(data + 10) != ARC_ZIP || payload != length - 24U) return 0;
    end = length - 8U;
    if (data[end + 4] != 'E' || data[end + 5] != 'N' || data[end + 6] != 'D' || data[end + 7] != '!') return 0;
    if ((arc_crc(0xffffffffUL, data, end) ^ 0xffffffffUL) != arc_get32(data + end)) return 0;
    pos = 16;
    for (i = 0; i < count; i++) {
        unsigned n, flags, j;
        if (end - pos < ARC_RECORD_SIZE) return 0;
        n = arc_get16(data + pos); flags = arc_get16(data + pos + 2);
        if (!n || n > ARC_NAME_MAX || (flags & ~7U) || arc_get16(data + pos + 22)) return 0;
        pos += ARC_RECORD_SIZE;
        if (end - pos < n) return 0;
        for (j = 0; j < n;) {
            ArcU32 value;
            int used = (flags & ARC_UTF8) ? utf8_next(data + pos + j, n - j, &value) : 1;
            if (!used || !data[pos + j]) return 0;
            j += (unsigned)used;
        }
        pos += n;
    }
    if (pos != end) return 0;
    index->data = data; index->length = length; index->count = count; index->format = ARC_ZIP;
    return 1;
}

int ARC_API arc_index_entry(const ArcIndex ARC_FAR *index, unsigned row, ArcEntry ARC_FAR *entry)
{
    unsigned i, pos = 16;
    const ArcByte ARC_FAR *p;
    if (!index->data || row >= index->count) return 0;
    for (i = 0; i < row; i++) pos += ARC_RECORD_SIZE + arc_get16(index->data + pos);
    p = index->data + pos;
    entry->name_length = arc_get16(p); entry->flags = arc_get16(p + 2);
    entry->unpacked_lo = arc_get32(p + 4); entry->unpacked_hi = arc_get32(p + 8);
    entry->packed_lo = arc_get32(p + 12); entry->packed_hi = arc_get32(p + 16);
    entry->method = arc_get16(p + 20); entry->name = p + ARC_RECORD_SIZE;
    return 1;
}

int ARC_API arc_entry_display(const ArcEntry ARC_FAR *entry, char ARC_FAR *text, unsigned capacity)
{
    static const char hex[] = "0123456789ABCDEF";
    unsigned pos = 0, out = 0;
    if (!capacity) return 0;
    text[0] = 0;
    while (pos < entry->name_length) {
        ArcU32 v = entry->name[pos];
        unsigned digits, i, used = 1, needed;
        if (entry->flags & ARC_UTF8) {
            int n = utf8_next(entry->name + pos, entry->name_length - pos, &v);
            if (!n) { text[0] = 0; return 0; }
            used = (unsigned)n;
        }
        digits = v < 256 ? 2 : v < 65536UL ? 4 : 8;
        if (entry->flags & ARC_UTF8) digits = v <= 65535UL ? 4 : 8;
        needed = v >= 32 && v < 127 ? (v == '\\' ? 2 : 1) : digits + 2;
        if (capacity - out <= needed) { text[0] = 0; return 0; }
        if (v >= 32 && v < 127) {
            if (v == '\\') text[out++] = '\\';
            text[out++] = (char)v;
        } else {
            text[out++] = '\\'; text[out++] = digits == 2 ? 'x' : digits == 4 ? 'u' : 'U';
            for (i = digits; i; i--) text[out++] = hex[(unsigned)((v >> ((i - 1) * 4)) & 15)];
        }
        pos += used;
    }
    text[out] = 0; return 1;
}

void ARC_API arc_decimal(ArcU32 lo, ArcU32 hi, char ARC_FAR *text)
{
    unsigned char digits[20];
    unsigned i, j, first = 0;
    for (i = 0; i < 20; i++) digits[i] = 0;
    for (i = 0; i < 8; i++) {
        ArcU32 part = i < 4 ? hi : lo;
        unsigned carry = (unsigned)((part >> ((3 - (i & 3)) * 8)) & 255);
        for (j = 20; j; j--) {
            unsigned value = (unsigned)digits[j - 1] * 256 + carry;
            digits[j - 1] = (unsigned char)(value % 10); carry = value / 10;
        }
    }
    while (first < 19 && !digits[first]) first++;
    for (i = first; i < 20; i++) *text++ = (char)('0' + digits[i]);
    *text = 0;
}
