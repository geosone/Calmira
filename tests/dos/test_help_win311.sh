#!/bin/sh
# Native WinHelp checks in copies only. No KVM or original-image writes.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared Windows 3.1x raw disk image}"
watcom=${WATCOM:-/opt/watcom}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/help-native.XXXXXX")
echo "Help test artifacts: $work"
"$watcom/binl64/wcc" -q -bt=windows -ml -zW -zu -s -os -w4 -we \
    -i="$watcom/h" -i="$watcom/h/win" -fo="$work/client.obj" \
    -fr="$work/client.err" "$root/tests/c/help_client.c"
"$root/build/toolchains/bin/jwlink" option quiet format windows name "$work/HELPTEST.EXE" \
    file "$work/client.obj" libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
    library windows,clibl option stack=12k option version=3.10
for profile in ${HELP_PROFILES:-C M W B R Q G T}; do
    mkdir "$work/$profile"
    cp --reflink=auto "$WIN311_IMAGE" "$work/$profile/test.img"
    partition="$work/$profile/test.img@@${WIN311_OFFSET:-32256}"
    printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/$profile/CONFIG.SYS"
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\WINDOWS\\WIN C:\\HELPTEST.EXE %s\r\n' "$profile" > "$work/$profile/AUTOEXEC.BAT"
    mcopy -o -i "$partition" "$work/$profile/CONFIG.SYS" "$work/$profile/AUTOEXEC.BAT" "$work/HELPTEST.EXE" ::/
    mcopy -o -i "$partition" "${HELP_FILE:-$root/build/help/calmira.hlp}" ::/CALMIRA.HLP
    set --
    if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
    { sleep 8; echo "screendump $work/$profile/screen.ppm"; sleep 2; echo quit; } \
    | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
        -display none -vga std -monitor stdio -nic none \
        -drive "if=ide,index=0,format=raw,file=$work/$profile/test.img" > "$work/$profile/qemu.log" 2>&1
    mcopy -i "$partition" ::/HELPTEST.LOG "$work/$profile/HELPTEST.LOG"
    tr -d '\r' < "$work/$profile/HELPTEST.LOG"
    grep -q '^HELP_CALL=1' "$work/$profile/HELPTEST.LOG"
    grep -q '^RESULT PASS' "$work/$profile/HELPTEST.LOG"
done
