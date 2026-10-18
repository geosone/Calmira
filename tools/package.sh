#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
gdi=${GDI:-"$root/../gdi"}
stage="$root/build/package"

required="
src/CALMIRA.EXE
HELP/CALMIRA.HLP
src/COUNTTIP.EXE
src/CTASKMAN.EXE
src/DIREXIST.EXE
src/DOSRUN.EXE
src/EXPLORER.EXE
src/SCRNSAVE.EXE
src/SHOWDESK.EXE
src/WNDHOOKS.DLL
src/LFNFUNCS.DLL
build/dos/lfn/LFNPROBE.EXE
build/dos/doslfn/doslfn.com
build/dos/doslfn/doslfnms.com
build/dos/doslfn/lfnxlat.386
"

for relative in $required; do
    if [ ! -f "$root/$relative" ]; then
        echo "Missing $relative; build the Delphi projects first." >&2
        exit 1
    fi
done

if [ ! -f "$gdi/build/INSTALL.EXE" ]; then
    echo "Missing $gdi/build/INSTALL.EXE; build GDI first." >&2
    exit 1
fi

mkdir -p "$stage/SYSTEM" "$stage/TRAY" "$stage/DOSLFN/NLS"
cp "$gdi/build/INSTALL.EXE" "$root/install/INSTALL.INI" "$stage/"
cp "$root/LICENSE" "$stage/LICENSE.TXT"
cp "$root/README.md" "$stage/README.TXT"
cp "$root/src/CALMIRA.EXE" "$root/HELP/CALMIRA.HLP" "$root/src/CALMIRA.INI" "$stage/"
cp "$root/src/COUNTTIP.EXE" "$root/src/CTASKMAN.EXE" "$root/src/DIREXIST.EXE" "$stage/"
cp "$root/src/DOSRUN.EXE" "$root/src/EXPLORER.EXE" "$root/src/SCRNSAVE.EXE" "$stage/"
cp "$root/src/SHOWDESK.EXE" "$root/BMP/SHUTDOWN.BMP" "$root/src/START.BAT" "$stage/"
cp "$root/src/START.INI" "$root/src/TIPS.TXT" "$root/VENDOR/W95ICONS.DLL" "$stage/"
cp "$root/src/WNDHOOKS.DLL" "$stage/"
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
cp "$root/VENDOR/CTL3DV2.DLL" "$root/src/LFNFUNCS.DLL" "$stage/SYSTEM/"
cp "$root/src/TRAY/"*.ALS "$stage/TRAY/"

echo "Package staged in $stage"

