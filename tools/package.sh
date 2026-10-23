#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gdi=${GDI:-"$root/../gdi"}
stage="$root/build/package"

required="
build/calmira/CALMIRA.EXE
build/help/calmira.hlp
src/counttip.exe
build/packed/CTASKMAN.EXE
src/direxist.exe
src/dosrun.exe
build/packed/EXPLORER.EXE
build/packed/SCRNSAVE.EXE
build/packed/SHOWDESK.EXE
src/wndhooks.dll
src/lfnfuncs.dll
build/dos/lfn/LFNPROBE.EXE
build/dos/doslfn/doslfn.com
build/dos/doslfn/doslfnms.com
build/dos/doslfn/lfnxlat.386
build/win16/ctl3d/CTL3DV2.DLL
build/lang/en.LNG
build/lang/de.LNG
build/lang/fr.LNG
build/win16/clfnhook/OLFNHOOK.DLL
build/win16/clfnhook/OLFNLOAD.EXE
build/win16/archive/OLFNVIEW.EXE
build/win16/archive/OLFNLIST.EXE
build/win16/archive/GPL-3.0.txt
build/win16/archive/7ZIP-LICENSE.txt
build/win16/archive/7ZIP-LGPL.txt
build/win16/archive/DOS32A-LICENSE.txt
install/archive.txt
"

for relative in $required; do
    if [ ! -f "$root/$relative" ]; then
        echo "Missing $relative; see docs/build_status.md for remaining build blockers." >&2
        exit 1
    fi
done

if [ ! -f "$gdi/build/INSTALL.EXE" ]; then
    echo "Missing $gdi/build/INSTALL.EXE; build GDI first." >&2
    exit 1
fi

python3 "$root/tools/pack_executables.py" --upx "$root/build/tools/upx/upx" \
    --output "$root/build/packed/shell" "$root/build/calmira/CALMIRA.EXE"

mkdir -p "$stage/SYSTEM" "$stage/TRAY" "$stage/DOSLFN/NLS" "$stage/LANG"
cp "$root/build/lang/"*.LNG "$stage/LANG/"
cp "$gdi/build/INSTALL.EXE" "$stage/"
cp "$root/install/install.ini" "$stage/INSTALL.INI"
cp "$root/license" "$stage/LICENSE.TXT"
cp "$root/readme.md" "$stage/README.TXT"
cp "$root/build/packed/shell/CALMIRA.EXE" "$stage/"
cp "$root/build/help/calmira.hlp" "$stage/CALMIRA.HLP"
cp "$root/src/calmira.ini" "$stage/CALMIRA.INI"
for helper in counttip direxist dosrun; do
    payload=$(printf '%s' "$helper" | tr '[:lower:]' '[:upper:]')
    cp "$root/src/$helper.exe" "$stage/$payload.EXE"
done
for helper in CTASKMAN EXPLORER SCRNSAVE SHOWDESK; do
    cp "$root/build/packed/$helper.EXE" "$stage/"
done
cp "$root/bmp/shutdown.bmp" "$stage/SHUTDOWN.BMP"
cp "$root/src/start.bat" "$stage/START.BAT"
cp "$root/src/start.ini" "$stage/START.INI"
cp "$root/src/tips.txt" "$stage/TIPS.TXT"
cp "$root/src/wndhooks.dll" "$stage/WNDHOOKS.DLL"
cp "$root/build/dos/lfn/LFNPROBE.EXE" "$stage/"
cp "$root/build/dos/doslfn/doslfn.com" "$stage/DOSLFN/DOSLFN.COM"
cp "$root/build/dos/doslfn/doslfnms.com" "$stage/DOSLFN/DOSLFNMS.COM"
cp "$root/build/dos/doslfn/doslfn.txt" "$stage/DOSLFN/DOSLFN.TXT"
cp "$root/build/dos/doslfn/lfnxlat.386" "$stage/DOSLFN/LFNXLAT.386"
cp "$root/build/dos/doslfn/fmlfn.drv" "$stage/DOSLFN/FMLFN.DRV"
for table in "$root/build/dos/doslfn/"*uni.tbl; do
    table_name=$(basename "$table" | tr '[:lower:]' '[:upper:]')
    cp "$table" "$stage/DOSLFN/$table_name"
done
cp "$root/build/dos/doslfn/NLS/"* "$stage/DOSLFN/NLS/"
cp "$root/build/win16/ctl3d/CTL3DV2.DLL" "$stage/SYSTEM/"
cp "$root/src/lfnfuncs.dll" "$stage/SYSTEM/LFNFUNCS.DLL"
mkdir -p "$stage/LICENSES"
cp "$root/vendor/build-deps/open386max-ctl3d/LICENSE" "$stage/LICENSES/CTL3D.TXT"
python3 "$root/tools/stage_archive.py" --output "$stage"
for alias in "$root/src/tray/"*.als; do
    payload=$(basename "$alias" | tr '[:lower:]' '[:upper:]')
    cp "$alias" "$stage/TRAY/$payload"
done

echo "Package staged in $stage"

