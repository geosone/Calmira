#!/bin/sh
# Runs only on a disposable copy of a user-supplied WfW 3.11 image.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set WIN311_IMAGE to a bootable Windows 3.11 raw disk image}"
watcom=${WATCOM:-/opt/watcom}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/ctl3d-vm.XXXXXX")
printf 'Test artifacts: %s\n' "$work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
"$watcom/binl64/wcc" -q -bt=windows -ml -zW -os \
    -i="$watcom/h" -i="$watcom/h/win" \
    -fo="$work/probe.obj" "$root/tests/c/ctl3d_runtime.c"
"$watcom/binl64/wrc" -q -r -bt=windows -i="$watcom/h" \
    -i="$watcom/h/win" -fo="$work/probe.res" "$root/tests/c/ctl3d_runtime.rc"
"$root/build/toolchains/bin/jwlink" option quiet format windows \
    name "$work/CTLTEST.EXE" file "$work/probe.obj" \
    libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
    library windows,clibl option stack=8k option version=3.10 \
    option resource="$work/probe.res"
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nBUFFERS=20\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\WINDOWS\\WIN C:\\CTLTEST.EXE\r\nTYPE C:\\CTLTEST.LOG > AUX\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/CTLTEST.EXE" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" ::/
mcopy -o -i "$partition" "$root/build/win16/ctl3d/CTL3DV2.DLL" ::/WINDOWS/SYSTEM/
{
    sleep 4
    echo "screendump $work/dialog-1.ppm"
    sleep 6
    echo "screendump $work/dialog-2.ppm"
    sleep 20
    echo quit
} | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-kvm}" -m 32 \
    -display none -vga std -monitor stdio -nic none \
    -drive "if=ide,index=0,format=raw,file=$work/test.img" \
    -serial "file:$work/serial.log" > "$work/monitor.log" 2>&1
mcopy -o -i "$partition" ::/CTLTEST.LOG "$work/CTLTEST.LOG"
tr -d '\r' < "$work/CTLTEST.LOG"
if grep -q '^FAIL ' "$work/CTLTEST.LOG" || ! grep -q '^RESULT PASS' "$work/CTLTEST.LOG"; then
    exit 1
fi
