#!/bin/sh
# Real module/package identity, plain and pinned-UPX packed; private TCG images.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared Windows 3.1x raw disk image}"
: "${IDENTITY_TEST_EXE:?Build the corrected-compiler identity probe first}"
upx=${UPX:-"$root/build/tools/upx/upx"}
test_seconds=${GDI_TEST_SECONDS:-60}
profile_filter=${IDENTITY_PATH_PROFILE:-all}
case "$profile_filter" in all|plain|packed) ;; *) echo 'Invalid identity profile' >&2; exit 2;; esac
case "$test_seconds" in
    [1-9]|[1-5][0-9]|60) ;;
    *) echo 'GDI_TEST_SECONDS must be 1..60' >&2; exit 2;;
esac
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/identity-paths.XXXXXX")
echo "Identity path artifacts: $work"
python3 "$root/tools/pack_executables.py" --upx "$upx" \
    --output "$work/packed-exe" "$IDENTITY_TEST_EXE"
for profile in plain packed; do
    if [ "$profile_filter" != all ] && [ "$profile_filter" != "$profile" ]; then continue; fi
    mkdir "$work/$profile"
    executable=$IDENTITY_TEST_EXE
    if [ "$profile" = packed ]; then executable="$work/packed-exe/$(basename "$IDENTITY_TEST_EXE")"; fi
    cp --reflink=auto "$WIN311_IMAGE" "$work/$profile/test.img"
    partition="$work/$profile/test.img@@${WIN311_OFFSET:-32256}"
    mmd -i "$partition" ::/IDENTPKG ::/TEMPPATH
    printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/$profile/CONFIG.SYS"
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nSET TEMP=C:\\TEMPPATH\r\nSET TMP=C:\\TEMPPATH\r\nCD \\WINDOWS\r\nWIN C:\\IDENTPKG\\IDENTITY.EXE %s\r\n' "$profile" > "$work/$profile/AUTOEXEC.BAT"
    mcopy -o -i "$partition" "$work/$profile/CONFIG.SYS" "$work/$profile/AUTOEXEC.BAT" ::/
    mcopy -o -i "$partition" "$executable" ::/IDENTPKG/IDENTITY.EXE
    set --
    if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
    { sleep "$test_seconds"; echo "screendump $work/$profile/screen.ppm"; sleep 2; echo quit; } \
    | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
        -display none -vga std -monitor stdio -nic none \
        -drive "if=ide,index=0,format=raw,file=$work/$profile/test.img" > "$work/$profile/qemu.log" 2>&1
    mcopy -i "$partition" ::/GDITEST.LOG "$work/$profile/GDITEST.LOG"
    tr -d '\r' < "$work/$profile/GDITEST.LOG"
    grep -q '^RESULT PASS' "$work/$profile/GDITEST.LOG"
    if grep -q '^FAIL ' "$work/$profile/GDITEST.LOG"; then exit 1; fi
    grep -Fq 'PACKAGE=C:\IDENTPKG\IDENTITY.EXE' "$work/$profile/GDITEST.LOG"
    grep -Fq 'DIRECTORY=C:\IDENTPKG\' "$work/$profile/GDITEST.LOG"
    if [ "$profile" = packed ]; then
        grep -Eq '^ACTUAL=C:\\TEMPPATH\\~?UPX' "$work/$profile/GDITEST.LOG"
        grep -q 'PASS restored wrapper sidecar recovers package data location but not ExeName' "$work/$profile/GDITEST.LOG"
    else
        grep -Fq 'ACTUAL=C:\IDENTPKG\IDENTITY.EXE' "$work/$profile/GDITEST.LOG"
    fi
done
