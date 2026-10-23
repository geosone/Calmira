#!/bin/sh
# Native GDI tests in a copy only, with software emulation by default.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared Windows 3.1x raw disk image}"
test_seconds=${GDI_TEST_SECONDS:-20}
case "$test_seconds" in
    [1-9]|[1-5][0-9]|60) ;;
    *) echo 'GDI_TEST_SECONDS must be 1..60' >&2; exit 2;;
esac
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/gdi-native.XXXXXX")
echo "GDI artifacts: $work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nWIN C:\\GDITEST.EXE\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" \
    "${GDI_TEST_EXE:-$root/build/tests/win16-gdi/GDITEST.EXE}" ::/
mcopy -o -i "$partition" "$root/bmp/bin.bmp" ::/PROBE.BMP
if [ -n "${GDI_HELPER_EXE:-}" ]; then
    mcopy -o -i "$partition" "$GDI_HELPER_EXE" ::/APPSEND.EXE
fi
if [ -n "${GDI_HELP_FILE:-}" ]; then
    mmd -i "$partition" ::/HELPDOCS
    mcopy -o -i "$partition" "$GDI_HELP_FILE" ::/HELPDOCS/CALMIRA.HLP
fi
mcopy -o -i "$partition" "$root/bmp/shutdown.bmp" ::/LARGE.BMP
# Deliberately invalid image to test transactional failure after a successful load.
printf 'not a bitmap\r\n' > "$work/BAD.BMP"
mcopy -o -i "$partition" "$work/BAD.BMP" ::/BAD.BMP
python3 "$root/tests/bitmap_fixtures.py" "$work"
mcopy -o -i "$partition" "$work/BITS1.BMP" "$work/BITS8.BMP" "$work/BITS24.BMP" "$work/SHORT.BMP" ::/
if [ -n "${GDI_CATALOG_DIR:-}" ]; then
    python3 "$root/tests/form_catalog_fixtures.py" "$work"
    mcopy -o -i "$partition" "$GDI_CATALOG_DIR/en.LNG" "$GDI_CATALOG_DIR/de.LNG" \
        "$GDI_CATALOG_DIR/fr.LNG" "$work/PROBE.LNG" ::/
fi
set --
if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
if [ "${GDI_TRACE:-0}" = 1 ]; then set -- "$@" -d int -D "$work/cpu.log"; fi
{ sleep "$test_seconds"; echo "screendump $work/screen.ppm"; sleep 2; echo quit; } \
| qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
    -display none -vga std -monitor stdio -nic none \
    -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/qemu.log" 2>&1
mcopy -i "$partition" ::/GDITEST.LOG "$work/GDITEST.LOG"
tr -d '\r' < "$work/GDITEST.LOG"
grep -q '^RESULT PASS' "$work/GDITEST.LOG"
if grep -q '^FAIL ' "$work/GDITEST.LOG"; then exit 1; fi
