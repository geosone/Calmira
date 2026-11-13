#!/bin/sh
# Install the complete Calmira package with GDI's silent setup on a disposable
# DOS 6.22/Windows 3.11 copy, start Windows with the installed shell, then
# uninstall it again and check that the host configuration is restored.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared raw DOS/Windows image}"
: "${CALMIRA_PACKAGE:?Set the staged package directory (make package)}"
package=$CALMIRA_PACKAGE
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/package-install.XXXXXX")
echo "Package installer artifacts: $work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
for directory in CALMIRA CALSRC; do
    if mdir -i "$partition" "::/$directory" >/dev/null 2>&1; then
        echo "Test requires an image without C:\\$directory" >&2; exit 1
    fi
done
# A SYSTEM.INI that grew with drivers and updates (2.5 KB already stopped
# GDI 1.16.2 with "not enough memory"): 150 more lines, about 5 KB.
mcopy -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/system-grown.ini"
{ printf '\r\n[Grown]\r\n'; for i in $(seq 1 150); do printf 'Setting%d=a value an update program wrote\r\n' "$i"; done; } >> "$work/system-grown.ini"
mcopy -o -i "$partition" "$work/system-grown.ini" ::/WINDOWS/SYSTEM.INI
mcopy -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/system-before.ini"
mcopy -i "$partition" ::/WINDOWS/SYSTEM/CTL3DV2.DLL "$work/ctl3dv2-before.dll"
mcopy -i "$partition" ::/WINDOWS/WIN.INI "$work/win-before.ini"
mcopy -i "$partition" ::/WINDOWS/CONTROL.INI "$work/control-before.ini"
mmd -i "$partition" ::/CALSRC
mcopy -s -i "$partition" "$package/"* ::/CALSRC/
# A German country code must preselect the German catalogue.
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=60\r\nCOUNTRY=049,850,C:\\COUNTRY.SYS\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\CALSRC\\INSTALL.EXE /S\r\nIF ERRORLEVEL 1 GOTO FAILED\r\nECHO PASS INSTALL>C:\\CALPKG.LOG\r\nGOTO END\r\n:FAILED\r\nECHO FAIL INSTALL>C:\\CALPKG.LOG\r\n:END\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" ::/
run() {
    phase=$1 seconds=$2
    shift 2
    {
        sleep 3
        for key in "$@"; do
            case $key in
                wait:*) sleep "${key#wait:}" ;;   # until the dialog is up
                shot:*) echo "screendump $work/${key#shot:}.ppm"; sleep 1 ;;
                *) echo "sendkey $key"; sleep 2 ;;
            esac
        done
        sleep "$seconds"
        echo "screendump $work/$phase-end.ppm"
        echo quit
    } | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 32 \
        -display none -vga std -monitor stdio -nic none \
        -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/$phase-qemu.log" 2>&1
}
fail() { echo "FAIL $*" >&2; exit 1; }
# ini_value FILE SECTION KEY: a value of an INI file, sections and keys in any case
ini_value() {
    tr -d '\r' < "$1" | awk -v s="[$2]" -v k="$3" '
        /^\[/ { in_s = (tolower($0) == tolower(s)); next }
        in_s { i = index($0, "="); if (i && tolower(substr($0, 1, i - 1)) == tolower(k)) { print substr($0, i + 1); exit } }'
}

run install 60
mcopy -o -i "$partition" ::/CALPKG.LOG "$work/install.log"
grep -q '^PASS INSTALL' "$work/install.log" || fail 'silent setup did not finish'
mkdir "$work/installed"
mcopy -s -i "$partition" ::/CALMIRA "$work/installed/"
installed="$work/installed/CALMIRA"
for file in CALMIRA.EXE CALMIRA.HLP COUNTTIP.EXE CTASKMAN.EXE DIREXIST.EXE DOSRUN.EXE \
    EXPLORER.EXE SCRNSAVE.EXE SHOWDESK.EXE WNDHOOKS.DLL LFNPROBE.EXE START.INI TIPS.TXT \
    LANG/de.LNG LANG/en.LNG TRAY/EXPLORER.ALS \
    DOSLFN/DOSLFN.COM LICENSE.TXT LICENSES/CTL3D.TXT INSTALL.EXE INSTALL.INI; do
    # FAT keeps short names in upper case
    cmp "$package/$file" "$installed/$(printf '%s' "$file" | tr '[:lower:]' '[:upper:]')" ||
        fail "$file differs from the package"
done
# Windows does not search the shell's directory at startup, so the private
# DLL goes to its system directory; the CTL3DV2.DLL Windows has stays.
mcopy -o -i "$partition" ::/WINDOWS/SYSTEM/LFNFUNCS.DLL "$work/lfnfuncs-installed.dll"
cmp "$package/SYSTEM/LFNFUNCS.DLL" "$work/lfnfuncs-installed.dll" || fail 'LFNFUNCS.DLL is not in the Windows system directory'
mcopy -o -i "$partition" ::/WINDOWS/SYSTEM/CTL3DV2.DLL "$work/ctl3dv2-installed.dll"
cmp "$work/ctl3dv2-before.dll" "$work/ctl3dv2-installed.dll" || fail 'the existing CTL3DV2.DLL was replaced'
[ ! -e "$installed/SYSTEM" ] || fail 'a SYSTEM directory Windows never searches was created'
# Option 5 (OpenLFN Loader) is off by default.
[ ! -e "$installed/OLFNHOOK.DLL" ] || fail 'the experimental OpenLFN Loader was installed by default'
tr -d '\r' < "$installed/CALMIRA.INI" | grep -qx 'Selected=de' ||
    fail 'the German country code did not select the German catalogue'
mcopy -o -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/system-installed.ini"
tr -d '\r' < "$work/system-installed.ini" | grep -qix 'shell=C:\\CALMIRA\\CALMIRA.EXE' ||
    fail 'Calmira did not become the Windows shell'
mcopy -o -i "$partition" ::/AUTOEXEC.BAT "$work/autoexec-installed.bat"
# DOS 6.22 has no long filenames, so the DOSLFN option is on by default.
tr -d '\r' < "$work/autoexec-installed.bat" | grep -qix 'LH C:\\CALMIRA\\DOSLFN\\DOSLFN.COM' ||
    fail 'the DOSLFN driver line was not added'
echo 'PASS GDI installed Calmira silently: files, shell, DOSLFN and German catalogue'

# Options 6 and 7 are on by default: the Windows 95 colours, active in
# CONTROL.INI, and the wallpaper in the Windows directory.
mcopy -o -i "$partition" ::/WINDOWS/WIN.INI "$work/win-installed.ini"
mcopy -o -i "$partition" ::/WINDOWS/CONTROL.INI "$work/control-installed.ini"
mcopy -o -i "$partition" ::/WINDOWS/RELOADED.BMP "$work/reloaded-installed.bmp" ||
    fail 'the wallpaper is not in the Windows directory'
cmp "$package/RELOADED.BMP" "$work/reloaded-installed.bmp" || fail 'the wallpaper differs from the package'
mcopy -o -i "$partition" ::/WINDOWS/CALM256.BMP "$work/calm256-installed.bmp" ||
    fail 'the 256-colour wallpaper is not in the Windows directory'
cmp "$package/CALM256.BMP" "$work/calm256-installed.bmp" || fail 'the 256-colour wallpaper differs from the package'
[ "$(ini_value "$work/win-installed.ini" Desktop Wallpaper)" = RELOADED.BMP ] ||
    fail 'the wallpaper is not set in WIN.INI'
[ "$(ini_value "$work/win-installed.ini" colors Background)" = '0 128 128' ] ||
    fail 'the Windows 95 colours are not set in WIN.INI'
[ "$(ini_value "$work/win-installed.ini" colors ButtonHilight)" = '255 255 255' ] ||
    fail 'the Windows 95 colours are incomplete in WIN.INI'
[ "$(ini_value "$work/control-installed.ini" current 'color schemes')" = 'Windows 95 standard' ] ||
    fail 'the Windows 95 scheme is not the current one in CONTROL.INI'
echo 'PASS Setup chose the Windows 95 colours and the Calmira Reloaded wallpaper'

# Start Windows with the installed shell and driver, then shut it down from
# Calmira: the welcome box and the tip close first, then Shut Down asks.
printf '@ECHO OFF\r\nLH C:\\CALMIRA\\DOSLFN\\DOSLFN.COM\r\nPATH C:\\;C:\\WINDOWS\r\nSET TEMP=C:\\TEMP\r\nC:\\SHARE.EXE /F:8192 /L:100\r\nC:\\WINDOWS\\WIN\r\nECHO PASS SHUTDOWN>C:\\CALSHUT.LOG\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/AUTOEXEC.BAT" ::/
run windows 30 wait:87 shot:windows-desktop alt-f4 wait:4 alt-f4 wait:4 alt-f4 wait:4 shot:windows-shutdown ret
python3 - "$work/windows-desktop.ppm" <<'PY' || fail 'no Calmira taskbar after starting Windows'
import sys
data = open(sys.argv[1], 'rb').read()
# P6 header: magic, width height, maximum, then exactly one whitespace byte
header, offset = [], 0
while len(header) < 4:
    while data[offset:offset + 1].isspace():
        offset += 1
    end = offset
    while not data[end:end + 1].isspace():
        end += 1
    header.append(data[offset:end])
    offset = end
width, height = int(header[1]), int(header[2])
pixels = data[offset + 1:]
# Calmira's taskbar has a white highlight edge across the whole screen near
# the bottom; the desktop has the same grey as the taskbar face.
white = [sum(1 for x in range(width)
             if pixels[(y * width + x) * 3:(y * width + x) * 3 + 3] == b'\xff\xff\xff')
         for y in range(height - 40, height)]
print(f'widest white row near the bottom: {max(white)}/{width}')
# The wallpaper's sky: clearly blue pixels across the desktop.
sky = sum(1 for i in range(0, width * (height - 40) * 3, 3 * 7)
          if pixels[i + 2] > 150 and pixels[i + 2] > pixels[i] + 60)
print(f'sky samples: {sky}')
sys.exit(0 if max(white) == width and sky > 1000 else 1)
PY
echo 'PASS Windows starts with the installed Calmira shell'
# Shut Down must end Windows, not only Calmira: as the shell it offers no
# "Close Calmira" and Windows returns to DOS.
mcopy -o -i "$partition" ::/CALSHUT.LOG "$work/shutdown.log" 2>/dev/null ||
    fail 'Shut Down did not return to DOS'
grep -q '^PASS SHUTDOWN' "$work/shutdown.log" || fail 'Shut Down did not return to DOS'
echo 'PASS Shut Down ends Windows and returns to DOS'

printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\CALMIRA\\INSTALL.EXE /U\r\nIF ERRORLEVEL 1 GOTO FAILED\r\nECHO PASS UNINSTALL>C:\\CALUN.LOG\r\nGOTO END\r\n:FAILED\r\nECHO FAIL UNINSTALL>C:\\CALUN.LOG\r\n:END\r\n' > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/AUTOEXEC.BAT" ::/
# The removal question defaults to Cancel: Left selects Remove.
run uninstall 20 wait:20 left ret ret
mcopy -o -i "$partition" ::/CALUN.LOG "$work/uninstall.log"
grep -q '^PASS UNINSTALL' "$work/uninstall.log" || fail 'uninstall did not finish'
# GDI removes what it installed; the start menu caches Calmira wrote itself
# at run time stay, and nothing else may.
left=$(mdir -b -i "$partition" ::/CALMIRA 2>/dev/null | tr -d '\r' | sed 's|.*/||' | sort | tr '\n' ' ')
case $left in
    ''|'BMPCACHE.BMP IMGINDEX.DAT '|'BMPCACHE.BMP '|'IMGINDEX.DAT ') ;;
    *) fail "files remain after uninstall: $left" ;;
esac
mcopy -o -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/system-after.ini"
cmp "$work/system-before.ini" "$work/system-after.ini" || fail 'SYSTEM.INI was not restored'
mcopy -o -i "$partition" ::/AUTOEXEC.BAT "$work/autoexec-after.bat"
! tr -d '\r' < "$work/autoexec-after.bat" | grep -qi 'CALMIRA\\DOSLFN' ||
    fail 'the DOSLFN line stays in AUTOEXEC.BAT after uninstall'
if mdir -i "$partition" ::/WINDOWS/SYSTEM/LFNFUNCS.DLL >/dev/null 2>&1; then
    fail 'LFNFUNCS.DLL remains after uninstall'
fi
mcopy -o -i "$partition" ::/WINDOWS/SYSTEM/CTL3DV2.DLL "$work/ctl3dv2-after.dll"
cmp "$work/ctl3dv2-before.dll" "$work/ctl3dv2-after.dll" || fail 'CTL3DV2.DLL changed by uninstall'
mcopy -o -i "$partition" ::/WINDOWS/WIN.INI "$work/win-after.ini"
mcopy -o -i "$partition" ::/WINDOWS/CONTROL.INI "$work/control-after.ini"
for key in Background ActiveTitle ButtonFace Hilight ButtonHilight; do
    [ "$(ini_value "$work/win-after.ini" colors $key)" = "$(ini_value "$work/win-before.ini" colors $key)" ] ||
        fail "the colour $key was not restored"
done
for key in Wallpaper TileWallpaper; do
    [ "$(ini_value "$work/win-after.ini" Desktop $key)" = "$(ini_value "$work/win-before.ini" Desktop $key)" ] ||
        fail "the desktop $key was not restored"
done
[ "$(ini_value "$work/control-after.ini" current 'color schemes')" = "$(ini_value "$work/control-before.ini" current 'color schemes')" ] ||
    fail 'the current colour scheme was not restored'
for bitmap in RELOADED.BMP CALM256.BMP; do
    if mdir -i "$partition" ::/WINDOWS/$bitmap >/dev/null 2>&1; then
        fail "the wallpaper $bitmap remains after uninstall"
    fi
done
echo 'PASS GDI uninstalled Calmira and restored SYSTEM.INI, AUTOEXEC.BAT, colours and wallpaper'
