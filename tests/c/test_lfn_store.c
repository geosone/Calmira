/* SPDX-License-Identifier: GPL-3.0-or-later */
#include "../../src/portable/lfn_store.h"
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define CHECK(value) do { checks++; if (!(value)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #value); exit(1); } } while (0)
static int checks, fail_write, fail_publish, fail_restore, blocked, fail_remove_lock, fail_remove_journal;
static char scratch[LFN_MAP_MAX + 1], root[80], file[LFN_PATH_MAX];
static const char original[] = "REPORT~1.TXT Old report\004owner=other-tool\r\n"
    "MYREPO~2.TXT Another file\r\n# unknown record, preserve it\r\n";

static int ends(const char *text, const char *suffix)
{
    size_t a = strlen(text), b = strlen(suffix);
    return a >= b && !strcmp(text + a - b, suffix);
}
static int create_new(const char *name) { return open(name, O_WRONLY | O_CREAT | O_EXCL, 0600); }
static int open_read(const char *name) { return open(name, O_RDONLY); }
static int open_exclusive(const char *name) { return blocked ? -1 : open_read(name); }
static unsigned read_data(int fd, char *data, unsigned n)
{
    ssize_t got = read(fd, data, n);
    return got < 0 ? 0xffffU : (unsigned)got;
}
static unsigned write_data(int fd, const char *data, unsigned n)
{
    ssize_t got;
    if (fail_write) return 0xffffU;
    got = write(fd, data, n);
    return got < 0 ? 0xffffU : (unsigned)got;
}
static int rename_file(const char *from, const char *to)
{
    if ((fail_publish && ends(from, "CLFN.NEW")) ||
        (fail_restore && ends(from, "CLFN.BAK"))) return -1;
    /* POSIX rename replaces its destination; DOS rename must not. */
    if (link(from, to)) return -1;
    return unlink(from);
}
static unsigned attributes(const char *name)
{
    struct stat info;
    if (stat(name, &info)) return 0xffffU;
    return (S_ISDIR(info.st_mode) ? 0x10U : 0) | (!(info.st_mode & S_IWUSR) ? 1U : 0);
}
static int set_attributes(const char *name, unsigned value)
{
    return chmod(name, value & 1 ? 0400 : 0600);
}
static int remove_file(const char *name)
{
    if ((fail_remove_lock && ends(name, "CLFN.LCK")) ||
        (fail_remove_journal && ends(name, "CLFN.SAV"))) return -1;
    return unlink(name);
}
static const LfnIo io = {create_new, open_read, open_exclusive, read_data, write_data,
    close, fsync, rename_file, remove_file, attributes, set_attributes};

static const char *path(const char *leaf)
{
    snprintf(file, sizeof(file), "%s%s", root, leaf);
    return file;
}
static void put(const char *leaf, const char *data)
{
    int fd = open(path(leaf), O_CREAT | O_TRUNC | O_WRONLY, 0600);
    CHECK(fd >= 0);
    CHECK(write(fd, data, strlen(data)) == (ssize_t)strlen(data));
    CHECK(!close(fd));
}
static int exists(const char *leaf) { return !access(path(leaf), F_OK); }
static void matches(const char *leaf, const char *expected)
{
    char buffer[2048];
    int fd = open_read(path(leaf));
    ssize_t n;
    CHECK(fd >= 0);
    n = read(fd, buffer, sizeof(buffer));
    CHECK(n == (ssize_t)strlen(expected));
    CHECK(!memcmp(buffer, expected, (size_t)n));
    CHECK(!close(fd));
}
static void setup(LfnSave *save, int with_original)
{
    char pattern[] = "build/tests/lfn-store.XXXXXX";
    char *directory = mkdtemp(pattern);
    CHECK(directory != NULL);
    snprintf(root, sizeof(root), "%s/", directory);
    memset(save, 0, sizeof(*save));
    fail_write = fail_publish = fail_restore = blocked = fail_remove_lock = fail_remove_journal = 0;
    if (with_original) put("DESCRIPT.ION", original);
}
static int reserve(LfnSave *save)
{
    return lfn_reserve(&io, root, "My report final.txt", save, scratch);
}
static void created(LfnSave *save)
{
    CHECK(lfn_accept(save) == LFN_DONE);
    put(save->alias, "document data\r\n");
}

int main(void)
{
    LfnSave save, second;
    char alias[13], expected[1024];
    int fd;
    unsigned i;
    CHECK(lfn_is_dos_name("README.TXT"));
    CHECK(!lfn_is_dos_name("CON.TXT"));
    CHECK(!lfn_is_dos_name("FILE."));
    CHECK(!lfn_valid_leaf("../escape.txt"));
    CHECK(!lfn_valid_leaf("bad\004name.txt"));
    CHECK(!lfn_valid_leaf("bad name.txt "));
    lfn_make_alias("My Report Final.docx", 1, alias);
    CHECK(!strcmp(alias, "MYREPO~1.DOC"));
    lfn_make_alias("Another.long.extension", 12, alias);
    CHECK(!strcmp(alias, "ANOTH~12.EXT"));

    setup(&save, 1);
    CHECK(reserve(&save) == LFN_DONE);
    CHECK(exists("CLFN.SAV"));
    CHECK(!exists(save.alias)); /* never fool COMMDLG with a placeholder */
    matches("DESCRIPT.ION", original);
    memset(&second, 0, sizeof(second));
    CHECK(reserve(&second) == LFN_BUSY);
    CHECK(lfn_discard(&io, &save) == LFN_DONE);
    CHECK(!exists("CLFN.SAV"));
    matches("DESCRIPT.ION", original);

    setup(&save, 1);
    put("MYREPO~1.TXT", "existing file");
    CHECK(reserve(&save) == LFN_DONE);
    CHECK(!strcmp(save.alias, "MYREPO~3.TXT")); /* file + orphan mapping */
    CHECK(lfn_accept(&save) == LFN_DONE);
    CHECK(lfn_commit(&io, &save, scratch) == LFN_WAIT);
    matches("DESCRIPT.ION", original);
    put(save.alias, "new document");
    blocked = 1;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_WAIT);
    matches("DESCRIPT.ION", original);
    blocked = 0;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_DONE);
    snprintf(expected, sizeof(expected), "%sMYREPO~3.TXT My report final.txt\r\n", original);
    matches("DESCRIPT.ION", expected);
    matches("MYREPO~1.TXT", "existing file");
    CHECK(!exists("CLFN.SAV") && !exists("CLFN.NEW") && !exists("CLFN.BAK") && !exists("CLFN.LCK"));

    setup(&save, 1);
    CHECK(!chmod(path("DESCRIPT.ION"), 0400));
    CHECK(reserve(&save) == LFN_READONLY);
    CHECK(!exists("CLFN.SAV"));
    matches("DESCRIPT.ION", original);

    setup(&save, 1);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    fail_write = 1;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_IO_ERROR);
    matches("DESCRIPT.ION", original);
    CHECK(!exists("CLFN.NEW") && !exists("CLFN.BAK") && !exists("CLFN.LCK"));
    CHECK(exists("CLFN.SAV"));
    fail_write = 0;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_DONE);

    setup(&save, 1);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    fail_publish = 1;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_IO_ERROR);
    matches("DESCRIPT.ION", original); /* rollback succeeded */
    CHECK(exists("CLFN.SAV") && !exists("CLFN.BAK"));
    fail_publish = 0;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_DONE);

    setup(&save, 1);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    fail_publish = fail_restore = 1;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_RECOVERY);
    matches("CLFN.BAK", original); /* last good copy must never be deleted */
    CHECK(exists("CLFN.SAV") && exists("CLFN.NEW") && exists("CLFN.LCK"));

    setup(&save, 1);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    put("CLFN.BAK", "unrelated user file");
    CHECK(lfn_commit(&io, &save, scratch) == LFN_RECOVERY);
    matches("CLFN.BAK", "unrelated user file");
    matches("DESCRIPT.ION", original);

    setup(&save, 1);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    put("CLFN.SAV", "changed by someone else");
    CHECK(lfn_commit(&io, &save, scratch) == LFN_CONFLICT);
    CHECK(lfn_discard(&io, &save) == LFN_CONFLICT);
    matches("CLFN.SAV", "changed by someone else");
    matches("DESCRIPT.ION", original);

    setup(&save, 0);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    CHECK(lfn_commit(&io, &save, scratch) == LFN_DONE);
    matches("DESCRIPT.ION", "MYREPO~1.TXT My report final.txt\r\n");

    setup(&save, 0);
    put("DESCRIPT.ION", "README.TXT Preserve the missing newline");
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    CHECK(lfn_commit(&io, &save, scratch) == LFN_DONE);
    matches("DESCRIPT.ION", "README.TXT Preserve the missing newline\r\n"
        "MYREPO~1.TXT My report final.txt\r\n");

    setup(&save, 0);
    fd = create_new(path("DESCRIPT.ION"));
    CHECK(fd >= 0);
    for (i = 0; i < 33; i++) {
        char chunk[1024];
        memset(chunk, 'x', sizeof(chunk));
        CHECK(write(fd, chunk, sizeof(chunk)) == sizeof(chunk));
    }
    CHECK(!close(fd));
    CHECK(reserve(&save) == LFN_TOO_LARGE);
    CHECK(!exists("CLFN.SAV"));

    setup(&save, 1);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    snprintf(expected, sizeof(expected), "%s%s Someone else's mapping\r\n", original, save.alias);
    put("DESCRIPT.ION", expected);
    CHECK(lfn_commit(&io, &save, scratch) == LFN_CONFLICT);
    matches("DESCRIPT.ION", expected);

    setup(&save, 0);
    put("DESCRIPT.ION", "OTHER~1.TXT My report final.txt\r\n");
    CHECK(reserve(&save) == LFN_CONFLICT);
    CHECK(!exists("CLFN.SAV"));
    matches("DESCRIPT.ION", "OTHER~1.TXT My report final.txt\r\n");

    setup(&save, 0);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    fail_remove_lock = 1;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_RECOVERY);
    CHECK(save.state == LFN_ACCEPTED);
    CHECK(exists("CLFN.SAV") && exists("CLFN.LCK"));
    matches("DESCRIPT.ION", "MYREPO~1.TXT My report final.txt\r\n");
    fail_remove_lock = 0;
    CHECK(!unlink(path("CLFN.LCK"))); /* explicit test recovery of our own lock */
    CHECK(lfn_commit(&io, &save, scratch) == LFN_DONE);
    matches("DESCRIPT.ION", "MYREPO~1.TXT My report final.txt\r\n");

    setup(&save, 0);
    CHECK(reserve(&save) == LFN_DONE);
    created(&save);
    fail_remove_journal = 1;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_IO_ERROR);
    CHECK(save.state == LFN_ACCEPTED && exists("CLFN.SAV"));
    fail_remove_journal = 0;
    CHECK(lfn_commit(&io, &save, scratch) == LFN_DONE);
    matches("DESCRIPT.ION", "MYREPO~1.TXT My report final.txt\r\n");
    printf("lfn-store: %d checks passed\n", checks);
    return 0;
}
