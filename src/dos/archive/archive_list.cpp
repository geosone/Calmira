/* SPDX-License-Identifier: GPL-3.0-or-later
 * Read-only ZIP index using the actual pinned 7-Zip CInArchive, not a new ZIP
 * parser. DOS/32A and host reference share this source. No extraction APIs. */
#define INITGUID
#include "Common/Common.h"
#include "7zip/Archive/IArchive.h"
#include "7zip/Archive/Zip/ZipIn.h"
#include "7zCrc.h"
#include "../../portable/archive_index.h"
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <time.h>
#ifdef __WATCOMC__
#include <io.h>
#include <share.h>
#else
#include <unistd.h>
#define O_BINARY 0
#endif

#ifdef ARC_DIAGNOSTIC
/* Disposable VM builds only: raw port output does not use DOS or file IO. */
static void arc_trace(unsigned char code);
#pragma aux arc_trace = "mov dx,0e9h" "out dx,al" __parm [__al] __modify [__dx]
#else
#define arc_trace(code) ((void)0)
#endif

#define ARC_FILE_LIMIT (64UL * 1024 * 1024)
#define ARC_READ_LIMIT (16UL * 1024 * 1024)
static time_t started;
static clock_t cpu_started;
static bool time_ok()
{
    return difftime(time(NULL), started) < 15 &&
        (double)(clock() - cpu_started) / CLOCKS_PER_SEC < 15;
}

Z7_CLASS_IMP_IInStream(CArchiveFile)
public:
    FILE *file;
    long length;
    UInt32 read_total;
    CArchiveFile(): file(NULL), length(0), read_total(0) {}
#ifdef __WATCOMC__
    virtual /* Watcom has no final-class marker used by the upstream macro. */
#endif
    ~CArchiveFile() { if (file) fclose(file); }
};
Z7_COM7F_IMF(CArchiveFile::Read(void *data, UInt32 size, UInt32 *processed))
{
    size_t count;
    if (processed) *processed = 0;
    if (!time_ok() || size > ARC_READ_LIMIT - read_total) return E_ABORT;
    count = fread(data, 1, size, file);
    read_total += (UInt32)count;
    if (processed) *processed = (UInt32)count;
    return ferror(file) ? E_FAIL : S_OK;
}
Z7_COM7F_IMF(CArchiveFile::Seek(Int64 offset, UInt32 origin, UInt64 *position))
{
    long base, target;
    if (!time_ok() || origin > 2) return E_ABORT;
    base = origin == STREAM_SEEK_SET ? 0 : origin == STREAM_SEEK_END ? length : ftell(file);
    if (base < 0 || offset < -(Int64)base || offset > (Int64)length - base) return E_FAIL;
    target = base + (long)offset;
    if (fseek(file, target, SEEK_SET)) return E_FAIL;
    if (position) *position = (UInt64)target;
    return S_OK;
}

Z7_CLASS_IMP_COM_1(CArchiveLimits, IArchiveOpenCallback)
public:
#ifdef __WATCOMC__
    virtual
#endif
    ~CArchiveLimits() {}
};
Z7_COM7F_IMF(CArchiveLimits::SetTotal(const UInt64 *files, const UInt64 *bytes))
{
    (void)bytes;
    return time_ok() && (!files || *files <= ARC_COUNT_MAX) ? S_OK : E_ABORT;
}
Z7_COM7F_IMF(CArchiveLimits::SetCompleted(const UInt64 *files, const UInt64 *bytes))
{
    (void)bytes;
    return time_ok() && (!files || *files <= ARC_COUNT_MAX) ? S_OK : E_ABORT;
}

static int write_index(const char *output, const CObjectVector<NArchive::NZip::CItemEx> &items)
{
    ArcByte buffer[ARC_INDEX_MAX];
    unsigned pos = 16, i;
    int descriptor, okay;
    FILE *file;
    ArcIndex checked;
    memset(buffer, 0, 16);
    memcpy(buffer, "CLARCI1", 7);
    arc_put16(buffer + 8, (ArcU16)items.Size()); arc_put16(buffer + 10, ARC_ZIP);
    FOR_VECTOR(i_item, items) {
        const NArchive::NZip::CItemEx &item = items[i_item];
        AString name = item.Name;
        unsigned flags = (item.IsDir() ? ARC_DIRECTORY : 0) |
            (item.IsEncrypted() ? ARC_ENCRYPTED : 0) | (item.IsUtf8() ? ARC_UTF8 : 0);
        unsigned n;
        if (!item.IsUtf8()) {
            const CObjectVector<NArchive::NZip::CExtraSubBlock> &extra = item.GetMainExtra().SubBlocks;
            FOR_VECTOR(k, extra) {
                if (extra[k].ID != NArchive::NZip::NFileHeader::NExtraID::kIzUnicodeName) continue;
                if (extra[k].CheckIzUnicode(item.Name)) {
                    UString unicode;
                    item.GetUnicodeString(unicode, item.Name, false, false, 0);
                    ConvertUnicodeToUTF8(unicode, name);
                    flags |= ARC_UTF8;
                }
                break;
            }
        }
        n = name.Len();
        if (!n || n > ARC_NAME_MAX || pos > ARC_INDEX_MAX - 8U - ARC_RECORD_SIZE - n) return 4;
        memset(buffer + pos, 0, ARC_RECORD_SIZE);
        arc_put16(buffer + pos, (ArcU16)n); arc_put16(buffer + pos + 2, (ArcU16)flags);
        arc_put32(buffer + pos + 4, (ArcU32)item.Size);
        arc_put32(buffer + pos + 8, (ArcU32)(item.Size >> 32));
        arc_put32(buffer + pos + 12, (ArcU32)item.PackSize);
        arc_put32(buffer + pos + 16, (ArcU32)(item.PackSize >> 32));
        arc_put16(buffer + pos + 20, item.Method);
        pos += ARC_RECORD_SIZE;
        for (i = 0; i < n; i++) buffer[pos++] = (ArcByte)name[i];
    }
    arc_put32(buffer + 12, (ArcU32)(pos - 16U));
    arc_put32(buffer + pos, arc_crc(0xffffffffUL, buffer, pos) ^ 0xffffffffUL);
    memcpy(buffer + pos + 4, "END!", 4); pos += 8;
    if (!arc_index_validate(buffer, pos, &checked)) return 4;
#ifdef __WATCOMC__
    descriptor = _sopen(output, O_CREAT | O_EXCL | O_WRONLY | O_BINARY,
                        SH_DENYRW, S_IREAD | S_IWRITE);
#else
    descriptor = open(output, O_CREAT | O_EXCL | O_WRONLY, 0600);
#endif
    if (descriptor < 0) return 6; /* Never overwrite an existing file. */
    file = fdopen(descriptor, "wb");
    if (!file) { close(descriptor); remove(output); return 6; }
    okay = fwrite(buffer, 1, pos, file) == pos;
    if (fflush(file)) okay = 0;
    if (fclose(file)) okay = 0;
    if (!okay) { remove(output); return 6; }
    return 0;
}

int main(int argc, char **argv)
{
    arc_trace('M');
    started = time(NULL); cpu_started = clock();
    arc_trace('T');
    if (argc != 3) {
        fputs("Usage: OLFNLIST input.zip new-index.bin\nRead-only listing; output must not exist.\n", stderr);
        return 1;
    }
    try {
        CArchiveFile *file = new CArchiveFile;
        arc_trace('F');
        CMyComPtr<IInStream> stream = file;
        CArchiveLimits *limits = new CArchiveLimits;
        arc_trace('L');
        CMyComPtr<IArchiveOpenCallback> callback = limits;
        NArchive::NZip::CInArchive archive;
        CObjectVector<NArchive::NZip::CItemEx> items;
        UInt64 search = 0;
        arc_trace('A');
        HRESULT result;
        int descriptor;
        struct stat attributes;
#ifdef __WATCOMC__
        descriptor = _sopen(argv[1], O_RDONLY | O_BINARY, SH_DENYWR);
#else
        descriptor = open(argv[1], O_RDONLY | O_NONBLOCK);
#endif
        arc_trace('O');
        if (descriptor < 0) return 2;
        if (fstat(descriptor, &attributes) || (attributes.st_mode & S_IFMT) != S_IFREG ||
            attributes.st_size < 0 || (unsigned long)attributes.st_size > ARC_FILE_LIMIT) {
            close(descriptor); return 4;
        }
        file->length = (long)attributes.st_size;
        arc_trace('S');
        file->file = fdopen(descriptor, "rb");
        if (!file->file) { close(descriptor); return 2; }
        arc_trace('D');
        CrcGenerateTable();
        arc_trace('C');
        archive.Disable_VolsRead = true;
        result = archive.Open(stream, &search, callback, items);
        arc_trace('Z');
        if (result != S_OK || !archive.IsArc || archive.AreThereErrors() ||
            archive.NoCentralDir || archive.IsMultiVol || archive.ArcInfo.Base != 0 ||
            archive.ArcInfo.ThereIsTail || items.Size() > ARC_COUNT_MAX) return 3;
        arc_trace('W');
        return write_index(argv[2], items);
    } catch (const std::bad_alloc &) { arc_trace('B'); return 5; }
    catch (...) { arc_trace('E'); return 3; }
}
