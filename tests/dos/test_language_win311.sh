#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set WIN311_IMAGE to a prepared Windows 3.11 raw disk image}"
code=${LANG_CODE:-en}
executable=${DRIVE_PROBE_EXE:-"$root/build/drive-probe/DRVPROBE.EXE"}
case "$code" in en|de|fr) ;; *) echo 'LANG_CODE must be en, de or fr' >&2; exit 1;; esac
watcom=${WATCOM:-/opt/watcom}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/language-$code.XXXXXX")
printf 'Test artifacts: %s\n' "$work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
"$watcom/binl64/wcc" -q -bt=windows -ml -zW -os \
    -i="$watcom/h" -i="$watcom/h/win" -fo="$work/check.obj" \
    "$root/tests/c/check_language_ui.c"
"$root/build/toolchains/bin/jwlink" option quiet format windows \
    name "$work/CHECK.EXE" file "$work/check.obj" \
    libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
    library windows,clibl option stack=8k option version=3.10
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\WINDOWS\\WIN C:\\CHECK.EXE\r\n' > "$work/AUTOEXEC.BAT"
printf '[Language]\r\nSelected=%s\r\n' "$code" > "$work/CALMIRA.INI"
mmd -i "$partition" ::/LANGTEST ::/LANGTEST/LANG
mcopy -o -i "$partition" "$work/CHECK.EXE" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" ::/
mcopy -o -i "$partition" "$executable" ::/LANGTEST/DRVPROBE.EXE
mcopy -o -i "$partition" "$work/CALMIRA.INI" ::/LANGTEST/
mcopy -o -i "$partition" "$root/build/lang/"*.LNG ::/LANGTEST/LANG/
{
    sleep 4
    echo "screendump $work/screen.ppm"
    sleep 10
    echo quit
} | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 32 \
    -display none -vga std -monitor stdio -nic none \
    -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/monitor.log" 2>&1
mcopy -o -i "$partition" ::/LANGTEST.LOG "$work/LANGTEST.LOG"
tr -d '\r' < "$work/LANGTEST.LOG"
grep -q '^RESULT PASS' "$work/LANGTEST.LOG"
