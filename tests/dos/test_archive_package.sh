#!/bin/sh
# Exercise the real standalone GDI descriptor on a disposable DOS disk copy.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared raw DOS/Windows image}"
package=${ARCHIVE_PACKAGE:-$root/build/openlfn-package}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/archive-install.XXXXXX")
echo "Archive installer artifacts: $work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
for directory in OPENLFN ARCSRC; do
    if mdir -i "$partition" "::/$directory" >/dev/null 2>&1; then
        echo "Test requires an image without C:\\$directory" >&2; exit 1
    fi
done
mcopy -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/system-before.ini"
mmd -i "$partition" ::/ARCSRC
mcopy -s -i "$partition" "$package/"* ::/ARCSRC/
printf 'FILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\ARCSRC\\INSTALL.EXE\r\nIF ERRORLEVEL 1 GOTO FAILED\r\nECHO PASS INSTALL>C:\\ARCPKG.LOG\r\nGOTO END\r\n:FAILED\r\nECHO FAIL INSTALL>C:\\ARCPKG.LOG\r\n:END\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" ::/
boot() {
    phase=$1
    {
        sleep 3
        if [ "$phase" = install ]; then
            # GDI's text viewer needs Enter to focus, then Enter to accept
            # each of the four licenses; other prompts need one Enter.
            for step in 1 2 3 4 5 6 7 8 9 10 11 12; do
                echo "screendump $work/install-$step.ppm"
                echo 'sendkey ret'
                sleep 1
            done
        else
            echo 'sendkey left'
            sleep 1
            echo 'sendkey ret'
            sleep 2
            echo 'sendkey ret'
        fi
        sleep 2
        echo "screendump $work/$phase-end.ppm"
        echo quit
    } | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 32 \
        -display none -vga std -monitor stdio -nic none \
        -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/$phase-qemu.log" 2>&1
}
unchanged() {
    mcopy -o -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/system-after.ini"
    mcopy -o -i "$partition" ::/CONFIG.SYS "$work/config-after.sys"
    mcopy -o -i "$partition" ::/AUTOEXEC.BAT "$work/autoexec-after.bat"
    cmp "$work/system-before.ini" "$work/system-after.ini"
    cmp "$work/CONFIG.SYS" "$work/config-after.sys"
    cmp "$work/AUTOEXEC.BAT" "$work/autoexec-after.bat"
}
boot install
mcopy -o -i "$partition" ::/ARCPKG.LOG "$work/install.log"
grep -q '^PASS INSTALL' "$work/install.log"
mkdir "$work/installed"
mcopy -s -i "$partition" ::/OPENLFN "$work/installed/"
for file in OLFNHOOK.DLL OLFNLOAD.EXE OLFNVIEW.EXE OLFNLIST.EXE ARCINFO.TXT INSTALL.EXE INSTALL.INI \
    LICENSES/GPL3.TXT LICENSES/7ZIP.TXT LICENSES/LGPL21.TXT LICENSES/DOS32A.TXT; do
    cmp "$package/$file" "$work/installed/OPENLFN/$file"
done
unchanged
echo 'PASS GDI installed all 11 files byte-identically without host configuration changes'
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\OPENLFN\\INSTALL.EXE /U\r\nIF ERRORLEVEL 1 GOTO FAILED\r\nECHO PASS UNINSTALL>C:\\ARCUN.LOG\r\nGOTO END\r\n:FAILED\r\nECHO FAIL UNINSTALL>C:\\ARCUN.LOG\r\n:END\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/AUTOEXEC.BAT" ::/
boot uninstall
mcopy -o -i "$partition" ::/ARCUN.LOG "$work/uninstall.log"
grep -q '^PASS UNINSTALL' "$work/uninstall.log"
if mdir -i "$partition" ::/OPENLFN >/dev/null 2>&1; then
    echo 'FAIL installed directory remains after uninstall' >&2; exit 1
fi
unchanged
echo 'PASS GDI uninstalled the add-on without host configuration changes'
