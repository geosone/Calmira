#!/bin/sh
# Exercise real Windows messages and typed Pascal dispatch in an image copy.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared Windows 3.1x raw disk image}"
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/messages-native.XXXXXX")
echo "Message ABI artifacts: $work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nWIN C:\\MSGTEST.EXE\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" \
    "${MESSAGE_TEST_EXE:-$root/build/tests/win16-messages/MSGTEST.EXE}" ::/
set --
if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
{ sleep 8; echo "screendump $work/screen.ppm"; sleep 2; echo quit; } \
| qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
    -display none -vga std -monitor stdio -nic none \
    -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/qemu.log" 2>&1
mcopy -i "$partition" ::/MSGTEST.LOG "$work/MSGTEST.LOG"
tr -d '\r' < "$work/MSGTEST.LOG"
grep -q '^RESULT PASS' "$work/MSGTEST.LOG"
if grep -q '^FAIL ' "$work/MSGTEST.LOG"; then exit 1; fi
