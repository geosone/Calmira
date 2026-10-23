#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set WIN311_IMAGE to a prepared Windows 3.11 raw disk image}"
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/win16-classes.XXXXXX")
printf 'Test artifacts: %s\n' "$work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\WINDOWS\\WIN C:\\RTLTEST.EXE\r\n' > "$work/AUTOEXEC.BAT"
mmd -i "$partition" ::/LANG
mcopy -o -i "$partition" "${RTL_TEST_EXE:-$root/build/tests/win16-classes/RTLTEST.EXE}" \
    "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" ::/
mcopy -o -i "$partition" "${RTL_CATALOG_DIR:-$root/build/lang}/"*.LNG ::/LANG/
set --
if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
{ sleep 12; echo quit; } | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
    -display none -vga std -monitor stdio -nic none \
    -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/monitor.log" 2>&1
mcopy -o -i "$partition" ::/RTLTEST.LOG "$work/RTLTEST.LOG"
tr -d '\r' < "$work/RTLTEST.LOG"
grep -q '^RESULT PASS' "$work/RTLTEST.LOG"
