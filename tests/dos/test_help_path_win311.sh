#!/bin/sh
# Native data-path acceptance, plain and UPX-packed; disposable image copies.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared Windows 3.1x raw disk image}"
compiler=${FPC_WIN16:-"$root/build/toolchains/fpc-win16/lib/fpc/3.3.1/ppcross8086"}
units=${FPC_WIN16_UNITS:-"$root/build/toolchains/fpc-win16/lib/fpc/3.3.1/units/win16/rtl"}
upx=${UPX:-"$root/build/tools/upx/upx"}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/help-path.XXXXXX")
echo "Help path test artifacts: $work"
mkdir "$work/units" "$work/plain" "$work/packed"
PATH="$root/build/toolchains/bin:$PATH" "$compiler" -Twin16 -Pi8086 -Mdelphi -CX \
    -Fu"$units" -Fu"$root/src/win16" -Fu"$root/src/portable" -FU"$work/units" \
    -FE"$work/plain" -oHELPATH.EXE "$root/tests/pascal/test_help_path_win16.pas"
python3 "$root/tools/pack_executables.py" --upx "$upx" \
    --output "$work/packed" "$work/plain/HELPATH.EXE"
for profile in plain packed missing; do
    argument=''
    executable="$work/$profile/HELPATH.EXE"
    if [ "$profile" = missing ]; then
        mkdir "$work/missing"
        executable="$work/plain/HELPATH.EXE"
        argument=' missing'
    fi
    cp --reflink=auto "$WIN311_IMAGE" "$work/$profile/test.img"
    partition="$work/$profile/test.img@@${WIN311_OFFSET:-32256}"
    mmd -i "$partition" ::/HELPPKG ::/TEMPHLP
    printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/$profile/CONFIG.SYS"
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nSET TEMP=C:\\TEMPHLP\r\nSET TMP=C:\\TEMPHLP\r\nCD \\WINDOWS\r\nWIN C:\\HELPPKG\\HELPATH.EXE%s\r\n' "$argument" > "$work/$profile/AUTOEXEC.BAT"
    mcopy -o -i "$partition" "$work/$profile/CONFIG.SYS" "$work/$profile/AUTOEXEC.BAT" ::/
    mcopy -o -i "$partition" "$executable" ::/HELPPKG/
    mcopy -o -i "$partition" "${HELP_FILE:-$root/build/help/calmira.hlp}" ::/HELPPKG/CALMIRA.HLP
    if [ "$profile" = missing ]; then
        mmd -i "$partition" ::/HELPPKG/LANG
        mcopy -o -i "$partition" "$root/build/lang/de.LNG" ::/HELPPKG/LANG/
        printf '[Language]\r\nSelected=de\r\n' > "$work/$profile/CALMIRA.INI"
        mcopy -o -i "$partition" "$work/$profile/CALMIRA.INI" ::/HELPPKG/
    fi
    set --
    if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
    { sleep 8; echo "screendump $work/$profile/screen.ppm"; echo 'sendkey ret'; sleep 2; echo quit; } \
    | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
        -display none -vga std -monitor stdio -nic none \
        -drive "if=ide,index=0,format=raw,file=$work/$profile/test.img" > "$work/$profile/qemu.log" 2>&1
    mcopy -i "$partition" ::/HLPATH.LOG "$work/$profile/HLPATH.LOG"
    tr -d '\r' < "$work/$profile/HLPATH.LOG"
    if [ "$profile" = missing ]; then
        grep -Fq 'HELP=C:\HELPPKG\MISSING.HLP' "$work/$profile/HLPATH.LOG"
        grep -q '^HELP_CALL=0' "$work/$profile/HLPATH.LOG"
    else
        grep -Fq 'HELP=C:\HELPPKG\CALMIRA.HLP' "$work/$profile/HLPATH.LOG"
        grep -q '^HELP_CALL=1' "$work/$profile/HLPATH.LOG"
    fi
    grep -q '^RESULT PASS' "$work/$profile/HLPATH.LOG"
    if [ "$profile" = packed ]; then
        grep -Eq '^MODULE=C:\\TEMPHLP\\~?UPX' "$work/$profile/HLPATH.LOG"
    fi
done
