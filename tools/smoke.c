/* smoke: dos.library calls on a mounted volume: write and read back, reads
 * across sector and cluster boundaries, seeks, SetFileSize, a long name,
 * rename across directories, delete. Works in <volume>smoke and removes it.
 *
 *   smoke FA0:
 *
 * Prints a FAIL line per failed check and a PASS or FAIL summary; exit 20
 * on a failure.
 *
 * Build: make smoke
 */
#include <exec/types.h>
#include <dos/dos.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <string.h>

static const char ver[] = "$VER: smoke 1.0 (17.11.2026)";

#define TOTAL 131073L /* 128 KiB + 1 */

static char top[128], nested[128], file[128], moved[128];
static UBYTE buf[2053]; /* odd size: transfers do not line up with sectors */
static int failures;

static void join(char *out, const char *volume, const char *path)
{
    strcpy(out, volume);
    strcat(out, path);
}

static int check(int ok, const char *what)
{
    LONG err = IoErr();
    char msg[80];

    if (!ok) {
        Fault(err, NULL, msg, sizeof(msg));
        Printf("FAIL: %s: %ld %s\n", (LONG)what, err, (LONG)msg);
        failures++;
    }
    return ok;
}

static UBYTE pattern(LONG offset)
{
    return (UBYTE)(offset * 37 + (offset >> 8));
}

static int verify(BPTR fh, LONG offset, LONG count)
{
    LONG done, n, i;

    if (!check(Seek(fh, offset, OFFSET_BEGINNING) != -1, "seek to read"))
        return 0;
    for (done = 0; done < count; done += n) {
        n = count - done < (LONG)sizeof(buf) ? count - done : (LONG)sizeof(buf);
        if (!check(Read(fh, buf, n) == n, "read length"))
            return 0;
        for (i = 0; i < n; i++)
            if (buf[i] != pattern(offset + done + i)) {
                Printf("FAIL: content at %ld\n", offset + done + i);
                failures++;
                return 0;
            }
    }
    return 1;
}

static void gone(const char *path, const char *what)
{
    BPTR lock;

    check(DeleteFile((STRPTR)path) != 0, what);
    lock = Lock((STRPTR)path, ACCESS_READ);
    check(lock == 0 && IoErr() == ERROR_OBJECT_NOT_FOUND, "deleted object gone");
    if (lock)
        UnLock(lock);
}

static void body(void)
{
    BPTR fh, lock;
    LONG done, n, i;

    fh = Open((STRPTR)file, MODE_NEWFILE);
    if (!check(fh != 0, "create a file with a long name"))
        return;
    for (done = 0; done < TOTAL; done += n) {
        n = TOTAL - done < (LONG)sizeof(buf) ? TOTAL - done : (LONG)sizeof(buf);
        for (i = 0; i < n; i++)
            buf[i] = pattern(done + i);
        if (!check(Write(fh, buf, n) == n, "write length"))
            break;
    }
    check(Close(fh) != 0, "close after writing");

    fh = Open((STRPTR)file, MODE_OLDFILE);
    if (!check(fh != 0, "open again"))
        return;
    verify(fh, 0, TOTAL);
    check(Read(fh, buf, 1) == 0, "end of file");
    /* across 512, 4096 and 65536 */
    verify(fh, 509, 7);
    verify(fh, 4093, 7);
    verify(fh, 65533, 7);
    check(Seek(fh, -7, OFFSET_CURRENT) == 65540, "relative seek returns the old position");
    check(Seek(fh, 0, OFFSET_CURRENT) == 65533, "relative seek position");
    check(Seek(fh, -1, OFFSET_END) == 65533, "seek from the end returns the old position");
    check(Seek(fh, 0, OFFSET_CURRENT) == TOTAL - 1, "seek from the end position");
    check(SetFileSize(fh, 513, OFFSET_BEGINNING) == 513, "truncate to 513");
    verify(fh, 0, 513);
    check(Read(fh, buf, 1) == 0, "end of the truncated file");
    check(SetFileSize(fh, 4097, OFFSET_BEGINNING) == 4097, "extend to 4097");
    verify(fh, 0, 513); /* the extension's content is undefined */
    check(Close(fh) != 0, "close after resizing");

    check(Rename((STRPTR)file, (STRPTR)moved) != 0, "rename into the parent directory");
    lock = Lock((STRPTR)file, ACCESS_READ);
    check(lock == 0 && IoErr() == ERROR_OBJECT_NOT_FOUND, "old name gone");
    if (lock)
        UnLock(lock);
    fh = Open((STRPTR)moved, MODE_OLDFILE);
    if (!check(fh != 0, "open under the new name"))
        return;
    Seek(fh, 0, OFFSET_END);
    check(Seek(fh, 0, OFFSET_CURRENT) == 4097, "size kept after close and rename");
    verify(fh, 0, 513);
    check(Close(fh) != 0, "close the renamed file");
    gone(moved, "delete the file");
}

int main(int argc, char **argv)
{
    BPTR lock;

    if (argc != 2 || strlen(argv[1]) > 40) {
        PutStr("usage: smoke <volume>\n");
        return 20;
    }
    join(top, argv[1], "smoke");
    join(nested, argv[1], "smoke/nested");
    join(file, argv[1], "smoke/nested/Boundary data with a long name.bin");
    join(moved, argv[1], "smoke/moved.bin");

    lock = CreateDir((STRPTR)top);
    if (check(lock != 0, "create the directory")) {
        UnLock(lock);
        lock = CreateDir((STRPTR)nested);
        if (check(lock != 0, "create a directory in it")) {
            UnLock(lock);
            body();
            gone(nested, "delete the inner directory");
        }
        gone(top, "delete the directory");
    }
    Printf("%s: smoke, %ld failures\n", (LONG)(failures ? "FAIL" : "PASS"), (LONG)failures);
    return failures ? 20 : 0;
}
