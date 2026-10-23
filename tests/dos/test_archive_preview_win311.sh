#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared raw Windows 3.1x image on DOS 6.22 for GUI acceptance}"
watcom=${WATCOM:-/opt/watcom}
archive_dir=${ARCHIVE_PACKAGE:-$root/build/win16/archive}
hook_dir=${ARCHIVE_PACKAGE:-$root/build/win16/clfnhook}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/archive-preview.XXXXXX")
echo "Archive preview artifacts: $work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
# Snapshot pre-existing temp names; our viewer must remove only its own files.
mdir -b -i "$partition" ::/TEMP > "$work/temp-before.txt" 2>/dev/null || true
python3 "$root/tests/archive_reader_acceptance.py" --fixtures "$work/fixtures"
"$watcom/binl64/wcc" -q -bt=windows -ml -zW -zu -s -os -w4 -we \
    -i="$watcom/h" -i="$watcom/h/win" -fo="$work/client.obj" \
    -fr="$work/client.err" "$root/tests/c/archive_preview_client.c"
"$root/build/toolchains/bin/jwlink" option quiet format windows name "$work/ARCTEST.EXE" \
    file "$work/client.obj" libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
    library windows,commdlg,clibl option stack=12k option heapsize=1k option version=3.10
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
mode=''
if [ -n "${ARCHIVE_EXPECT_BLOCKED:-}" ]; then mode=B; fi
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nSET TEMP=C:\\TEMP\r\nC:\\WINDOWS\\WIN C:\\ARCTEST.EXE %s\r\n' "$mode" > "$work/AUTOEXEC.BAT"
mmd -i "$partition" ::/TEMP 2>/dev/null || true
mcopy -o -i "$partition" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" "$work/ARCTEST.EXE" \
    "$hook_dir/OLFNHOOK.DLL" "$hook_dir/OLFNLOAD.EXE" "$archive_dir/OLFNVIEW.EXE" \
    "$archive_dir/OLFNLIST.EXE" "$work/fixtures/DEFLATE.ZIP" ::/
{
    sleep 7
    echo "screendump $work/screen.ppm"
    sleep 10
    echo quit
} | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 32 -display none -vga std \
    -monitor stdio -nic none -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/qemu.log" 2>&1
mcopy -o -i "$partition" ::/ARCPREV.LOG "$work/ARCPREV.LOG"
tr -d '\r' < "$work/ARCPREV.LOG"
grep -q '^RESULT PASS' "$work/ARCPREV.LOG"
mcopy -o -i "$partition" ::/DEFLATE.ZIP "$work/AFTER.ZIP"
cmp "$work/fixtures/DEFLATE.ZIP" "$work/AFTER.ZIP"
mdir -b -i "$partition" ::/TEMP > "$work/temp-after.txt" 2>/dev/null || true
cmp "$work/temp-before.txt" "$work/temp-after.txt"
