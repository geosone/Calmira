/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "../../src/portable/archive_index.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned checks;
static ArcByte data[ARC_INDEX_MAX];
#define CHECK(x) do { checks++; if (!(x)) { fprintf(stderr, "archive-index line %d\n", __LINE__); exit(1); } } while (0)
static unsigned make_index(const ArcByte *name, unsigned n, unsigned flags)
{
    unsigned end = 16;
    memset(data, 0, sizeof(data)); memcpy(data, "CLARCI1", 7);
    arc_put16(data + 10, ARC_ZIP);
    if (name) {
        arc_put16(data + 8, 1); arc_put16(data + 16, (ArcU16)n);
        arc_put16(data + 18, (ArcU16)flags); arc_put16(data + 36, 8);
        memcpy(data + 40, name, n); end += 24 + n;
    }
    arc_put32(data + 12, (ArcU32)(end - 16));
    arc_put32(data + end, arc_crc(0xffffffffUL, data, end) ^ 0xffffffffUL);
    memcpy(data + end + 4, "END!", 4);
    return end + 8;
}
static void fix_crc(unsigned length)
{ arc_put32(data + length - 8, arc_crc(0xffffffffUL, data, length - 8) ^ 0xffffffffUL); }
int main(void)
{
    ArcIndex index;
    ArcEntry entry;
    char text[1500];
    unsigned n, i;
    ArcU32 random = 0x12345678UL;
    static const ArcByte unicode[] = "Gr\303\274\303\237e.txt";
    static const ArcByte invalid[][4] = {{0xc0,0x80,0,0},{0xed,0xa0,0x80,0},{0xf4,0x90,0x80,0x80},{0xe2,0,0,0}};
    CHECK((arc_crc(0xffffffffUL, (const ArcByte *)"123456789", 9) ^ 0xffffffffUL) == 0xcbf43926UL);
    n = make_index(NULL, 0, 0);
    CHECK(arc_index_validate(data, n, &index) && !index.count);
    CHECK(!arc_index_entry(&index, 0, &entry));
    n = make_index((const ArcByte *)"folder/report.txt", 17, 0);
    CHECK(arc_index_validate(data, n, &index) && index.count == 1);
    CHECK(arc_index_entry(&index, 0, &entry) && entry.method == 8);
    CHECK(arc_entry_display(&entry, text, sizeof(text)) && !strcmp(text, "folder/report.txt"));
    CHECK(!arc_entry_display(&entry, text, 5) && !text[0]);
    for (i = 0; i < n; i++) CHECK(!arc_index_validate(data, i, &index));
    for (i = 0; i < n; i++) {
        data[i] ^= 1; CHECK(!arc_index_validate(data, n, &index)); data[i] ^= 1;
    }
    CHECK(!arc_index_validate(data, n + 1, &index));
    data[10] = 2; fix_crc(n); CHECK(!arc_index_validate(data, n, &index));
    n = make_index(unicode, sizeof(unicode) - 1, ARC_UTF8);
    CHECK(arc_index_validate(data, n, &index)); CHECK(arc_index_entry(&index, 0, &entry));
    CHECK(arc_entry_display(&entry, text, sizeof(text)) && !strcmp(text, "Gr\\u00FC\\u00DFe.txt"));
    n = make_index((const ArcByte *)"a\n\\\033", 4, 0);
    CHECK(arc_index_validate(data, n, &index)); CHECK(arc_index_entry(&index, 0, &entry));
    CHECK(arc_entry_display(&entry, text, sizeof(text)) && !strcmp(text, "a\\x0A\\\\\\x1B"));
    for (i = 0; i < 4; i++) {
        unsigned length = i == 0 ? 2 : i == 1 ? 3 : i == 2 ? 4 : 1;
        n = make_index(invalid[i], length, ARC_UTF8);
        CHECK(!arc_index_validate(data, n, &index));
    }
    n = make_index((const ArcByte *)"a\0b", 3, 0); CHECK(!arc_index_validate(data, n, &index));
    n = make_index((const ArcByte *)"a", 1, 8); CHECK(!arc_index_validate(data, n, &index));
    n = make_index((const ArcByte *)"a", 1, 0);
    data[38] = 1; fix_crc(n); CHECK(!arc_index_validate(data, n, &index));
    n = make_index((const ArcByte *)"a", 1, 0);
    arc_put16(data + 8, ARC_COUNT_MAX + 1); fix_crc(n); CHECK(!arc_index_validate(data, n, &index));
    memset(text, 'a', ARC_NAME_MAX + 1);
    n = make_index((const ArcByte *)text, ARC_NAME_MAX, 0); CHECK(arc_index_validate(data, n, &index));
    n = make_index((const ArcByte *)text, ARC_NAME_MAX + 1, 0); CHECK(!arc_index_validate(data, n, &index));
    arc_decimal(0, 0, text); CHECK(!strcmp(text, "0"));
    arc_decimal(0xffffffffUL, 0, text); CHECK(!strcmp(text, "4294967295"));
    arc_decimal(0, 1, text); CHECK(!strcmp(text, "4294967296"));
    arc_decimal(0xffffffffUL, 0xffffffffUL, text); CHECK(!strcmp(text, "18446744073709551615"));
    for (i = 0; i < 1000; i++) {
        unsigned pos;
        n = make_index((const ArcByte *)"simple.txt", 10, 0);
        random ^= random << 13; random ^= random >> 17; random ^= random << 5;
        pos = (unsigned)(random % n); data[pos] ^= (ArcByte)((random >> 8) | 1);
        fix_crc(n);
        if (arc_index_validate(data, n, &index)) {
            CHECK(arc_index_entry(&index, 0, &entry));
            CHECK(arc_entry_display(&entry, text, sizeof(text)));
        } else CHECK(!index.data);
    }
    printf("archive-index: %u checks passed\n", checks);
    return 0;
}
