#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gdi=${GDI:-"$root/../gdi"}
# Every compiled payload comes from one build tree, so a release built with the
# fixed compiler (BUILD_DIR=build/class-pointer/...) never mixes in stale files.
build=${BUILD_DIR:-build}
case $build in /*) ;; *) build="$root/$build" ;; esac
stage="$build/package"

required="
calmira/CALMIRA.EXE
help/calmira.hlp
dos-helpers/COUNTTIP.EXE
dos-helpers/DIREXIST.EXE
dos-helpers/DOSRUN.EXE
packed/CTASKMAN.EXE
packed/EXPLORER.EXE
packed/SCRNSAVE.EXE
packed/SHOWDESK.EXE
wndhooks/WNDHOOKS.DLL
lfnfuncs/LFNFUNCS.DLL
dos/lfn/LFNPROBE.EXE
dos/doslfn/doslfn.com
dos/doslfn/doslfnms.com
dos/doslfn/lfnxlat.386
win16/ctl3d/CTL3DV2.DLL
lang/en.LNG
lang/de.LNG
lang/fr.LNG
lang/nl.LNG
lang/it.LNG
lang/es.LNG
lang/pl.LNG
win16/clfnhook/OLFNHOOK.DLL
win16/clfnhook/OLFNLOAD.EXE
win16/archive/OLFNVIEW.EXE
win16/archive/OLFNLIST.EXE
win16/archive/GPL-3.0.txt
win16/archive/7ZIP-LICENSE.txt
win16/archive/7ZIP-LGPL.txt
win16/archive/DOS32A-LICENSE.txt
"

for relative in $required; do
    if [ ! -f "$build/$relative" ]; then
        echo "Missing $relative; see docs/build_status.md for remaining build blockers." >&2
        exit 1
    fi
done

if [ ! -f "$root/install/archive.txt" ]; then
    echo "Missing install/archive.txt." >&2
    exit 1
fi

if [ ! -f "$gdi/build/INSTALL.EXE" ]; then
    echo "Missing $gdi/build/INSTALL.EXE; build GDI first." >&2
    exit 1
fi

rm -rf "${stage:?}"

mkdir -p "$stage/SYSTEM" "$stage/TRAY" "$stage/DOSLFN/NLS" "$stage/LANG"
cp "$build/lang/"*.LNG "$stage/LANG/"
cp "$gdi/build/INSTALL.EXE" "$stage/"
cp "$root/install/install.ini" "$stage/INSTALL.INI"
cp "$root/license" "$stage/LICENSE.TXT"
cp "$root/readme.md" "$stage/README.TXT"
# The shell is not packed: UPX's NE wrapper runs a temporary copy under
# another module name, so Calmira did not know it was the Windows shell and
# Shut Down ended only Calmira, with a GPF and a hung Windows.
cp "$build/calmira/CALMIRA.EXE" "$stage/"
cp "$build/help/calmira.hlp" "$stage/CALMIRA.HLP"
cp "$root/src/calmira.ini" "$stage/CALMIRA.INI"
for helper in COUNTTIP DIREXIST DOSRUN; do
    cp "$build/dos-helpers/$helper.EXE" "$stage/"
done
for helper in CTASKMAN EXPLORER SCRNSAVE SHOWDESK; do
    cp "$build/packed/$helper.EXE" "$stage/"
done
cp "$root/bmp/shutdown.bmp" "$stage/SHUTDOWN.BMP"
cp "$root/src/start.bat" "$stage/START.BAT"
cp "$root/src/start.ini" "$stage/START.INI"
cp "$root/src/tips.txt" "$stage/TIPS.TXT"
cp "$build/wndhooks/WNDHOOKS.DLL" "$stage/"
cp "$build/dos/lfn/LFNPROBE.EXE" "$stage/"
cp "$build/dos/doslfn/doslfn.com" "$stage/DOSLFN/DOSLFN.COM"
cp "$build/dos/doslfn/doslfnms.com" "$stage/DOSLFN/DOSLFNMS.COM"
cp "$build/dos/doslfn/doslfn.txt" "$stage/DOSLFN/DOSLFN.TXT"
cp "$build/dos/doslfn/lfnxlat.386" "$stage/DOSLFN/LFNXLAT.386"
cp "$build/dos/doslfn/fmlfn.drv" "$stage/DOSLFN/FMLFN.DRV"
for table in "$build/dos/doslfn/"*uni.tbl; do
    table_name=$(basename "$table" | tr '[:lower:]' '[:upper:]')
    cp "$table" "$stage/DOSLFN/$table_name"
done
cp "$build/dos/doslfn/NLS/"* "$stage/DOSLFN/NLS/"
cp "$build/win16/ctl3d/CTL3DV2.DLL" "$stage/SYSTEM/"
cp "$build/lfnfuncs/LFNFUNCS.DLL" "$stage/SYSTEM/"
mkdir -p "$stage/LICENSES"
cp "$root/vendor/build-deps/open386max-ctl3d/LICENSE" "$stage/LICENSES/CTL3D.TXT"
python3 "$root/tools/stage_archive.py" --build "$build" --output "$stage"
for alias in "$root/src/tray/"*.als; do
    payload=$(basename "$alias" | tr '[:lower:]' '[:upper:]')
    cp "$alias" "$stage/TRAY/$payload"
done

# GDI's own check: every file, license and condition of INSTALL.INI is present.
if [ -x "$gdi/build/gdicheck" ]; then
    "$gdi/build/gdicheck" "$stage/INSTALL.INI"
fi

echo "Package staged in $stage"

