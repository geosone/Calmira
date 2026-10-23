#!/bin/sh
# Observational VM experiment, NOT a bypass for the production safety guard.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared raw DOS/Windows image; only a copy will be changed}"
watcom=${WATCOM:-/opt/watcom}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/dos-bridge.XXXXXX")
echo "Bridge diagnostic artifacts: $work"
"$root/build/toolchains/bin/jwasm" -q -bin -Fo"$work/TINY.COM" "$root/tests/asm/dos_bridge_tiny.asm"
"$root/build/toolchains/bin/jwasm" -q -bin -Fo"$work/STEPS.COM" "$root/tests/asm/dos_bridge_steps.asm"
"$root/build/toolchains/bin/jwasm" -q -omf -Fo"$work/mz.obj" "$root/tests/asm/dos_bridge_mz.asm"
"$root/build/toolchains/bin/jwlink" option quiet format dos name "$work/MZBARE.EXE" file "$work/mz.obj"
"$root/build/toolchains/bin/jwasm" -q -omf -DPAD_ENTRY -Fo"$work/padmz.obj" "$root/tests/asm/dos_bridge_mz.asm"
"$root/build/toolchains/bin/jwlink" option quiet format dos name "$work/MZPAD.EXE" file "$work/padmz.obj"
"$root/build/toolchains/bin/jwasm" -q -omf -DPAD_ENTRY -DFOUR_RELOCS -Fo"$work/pad4.obj" "$root/tests/asm/dos_bridge_mz.asm"
"$root/build/toolchains/bin/jwlink" option quiet format dos name "$work/MZPAD4.EXE" file "$work/pad4.obj"
"$root/build/toolchains/bin/jwasm" -q -omf -DPAD_ENTRY -DFOUR_RELOCS -DLARGE_IMAGE -Fo"$work/bigmz.obj" "$root/tests/asm/dos_bridge_mz.asm"
"$root/build/toolchains/bin/jwlink" option quiet format dos name "$work/BIGMZ.EXE" file "$work/bigmz.obj"
trace_flag=''
if [ -n "${BRIDGE_TRACE_INIT:-}" ]; then trace_flag=-dBRIDGE_TRACE_INIT; fi
"$watcom/binl64/wcc" -q -bt=dos -ms -0 -s -os -w4 -we $trace_flag -i="$watcom/h" \
    -fo="$work/real.obj" -fr="$work/real.err" "$root/tests/c/dos_bridge_real.c"
set --
if [ -n "${BRIDGE_ENTRY_TRACE:-}" ]; then
    "$root/build/toolchains/bin/jwasm" -q -omf -Fo"$work/entry.obj" "$root/tests/asm/dos_bridge_entry.asm"
    set -- file "$work/entry.obj" option start=TraceEntry
fi
"$root/build/toolchains/bin/jwlink" option quiet format dos name "$work/REAL16.EXE" \
    "$@" file "$work/real.obj" libpath "$watcom/lib286/dos" libpath "$watcom/lib286" \
    library clibs option stack=2k option map="$work/real.map"
case " ${BRIDGE_CASES:-tiny real archive} " in
    *' relocprobe '*)
        python3 "$root/tools/analysis/patch_dos_startup_probe.py" "$work/REAL16.EXE" "$work/TRACE16.EXE" ;;
esac
"$watcom/binl64/wcc" -q -bt=dos -ms -0 -s -os -w4 -we -dBRIDGE_MINIMAL -i="$watcom/h" \
    -fo="$work/min.obj" -fr="$work/min.err" "$root/tests/c/dos_bridge_real.c"
"$root/build/toolchains/bin/jwlink" option quiet format dos name "$work/MIN16.EXE" \
    file "$work/min.obj" libpath "$watcom/lib286/dos" libpath "$watcom/lib286" \
    library clibs option stack=2k option map="$work/min.map"
"$watcom/binl64/wcc" -q -bt=dos -ms -0 -s -os -w4 -we -dBRIDGE_HEAP -i="$watcom/h" \
    -fo="$work/heap.obj" -fr="$work/heap.err" "$root/tests/c/dos_bridge_real.c"
"$root/build/toolchains/bin/jwlink" option quiet format dos name "$work/HEAP16.EXE" \
    file "$work/heap.obj" libpath "$watcom/lib286/dos" libpath "$watcom/lib286" \
    library clibs option stack=2k option map="$work/heap.map"
"$watcom/binl64/wcc" -q -bt=windows -ml -zW -zu -s -os -w4 -we \
    -i="$watcom/h" -i="$watcom/h/win" -fo="$work/probe.obj" -fr="$work/probe.err" \
    "$root/tests/c/dos_bridge_probe.c"
"$root/build/toolchains/bin/jwlink" option quiet format windows name "$work/BRIDGE.EXE" \
    file "$work/probe.obj" libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
    library windows,clibl option stack=12k option heapsize=1k option version=3.10
python3 "$root/tests/archive_reader_acceptance.py" --fixtures "$work/fixtures"
for mode in ${BRIDGE_CASES:-tiny real archive}; do
    mkdir "$work/$mode"
    cp --reflink=auto "$WIN311_IMAGE" "$work/$mode/test.img"
    partition="$work/$mode/test.img@@${WIN311_OFFSET:-32256}"
    case "$mode" in
        tiny) command='C:\TINY.COM' ;;
        real|real1|real2|real3|relocprobe) command='C:\REAL16.EXE' ;;
        min) command='C:\MIN16.EXE' ;;
        heap) command='C:\HEAP16.EXE' ;;
        archive) command='C:\OLFNLIST.EXE C:\STORED.ZIP C:\RESULT.IDX' ;;
        mz) command='C:\MZBARE.EXE' ;;
        padmz) command='C:\MZPAD.EXE' ;;
        pad4) command='C:\MZPAD4.EXE' ;;
        bigmz) command='C:\BIGMZ.EXE' ;;
        cmdreal) command='C:\COMMAND.COM /C C:\REAL16.EXE' ;;
        cmdarchive) command='C:\COMMAND.COM /C C:\RUNARC.BAT' ;;
        steps) command='C:\STEPS.COM' ;;
        *) echo "Unknown case $mode" >&2; exit 1 ;;
    esac
    {
        printf '@ECHO OFF\r\nC:\\OLFNLIST.EXE C:\\STORED.ZIP C:\\RESULT.IDX >C:\\ARCOUT.LOG\r\n'
        for code in 7 6 5 4 3 2 1; do
            printf 'IF ERRORLEVEL %s GOTO EXIT%s\r\n' "$code" "$code"
        done
        printf 'ECHO EXIT 0 >>C:\\ARCOUT.LOG\r\nGOTO END\r\n'
        for code in 7 6 5 4 3 2 1; do
            printf ':EXIT%s\r\nECHO EXIT %s >>C:\\ARCOUT.LOG\r\nGOTO END\r\n' "$code" "$code"
        done
        printf ':END\r\n'
    } > "$work/$mode/RUNARC.BAT"
    printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/$mode/CONFIG.SYS"
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nSET TEMP=C:\\TEMP\r\nVER >C:\\DOSVER.LOG\r\nC:\\WINDOWS\\WIN C:\\BRIDGE.EXE %s\r\n' "$command" > "$work/$mode/AUTOEXEC.BAT"
    if [ -n "${BRIDGE_NO_LFN:-}" ]; then
        sed '/^VER /i SET LFN=N\r' "$work/$mode/AUTOEXEC.BAT" > "$work/$mode/NO-LFN.BAT"
        cp "$work/$mode/NO-LFN.BAT" "$work/$mode/AUTOEXEC.BAT"
    fi
    if [ -n "${BRIDGE_NO_VFAT:-}" ]; then
        mcopy -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/$mode/SYSTEM.ORIG"
        sed -E '/^device=(ifsmgr|vcache|vshare)\.386\r?$/Id' "$work/$mode/SYSTEM.ORIG" > "$work/$mode/SYSTEM.INI"
        mcopy -o -i "$partition" "$work/$mode/SYSTEM.INI" ::/WINDOWS/SYSTEM.INI
    fi
    if [ -n "${BRIDGE_OMIT_DEVICE:-}" ]; then
        case "$BRIDGE_OMIT_DEVICE" in ifsmgr|vcache|vshare) ;; *) exit 2 ;; esac
        mcopy -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/$mode/DEVICE.ORIG"
        sed -E "/^device=$BRIDGE_OMIT_DEVICE\\.386\\r?$/Id" "$work/$mode/DEVICE.ORIG" > "$work/$mode/DEVICE.INI"
        mcopy -o -i "$partition" "$work/$mode/DEVICE.INI" ::/WINDOWS/SYSTEM.INI
    fi
    if [ -n "${BRIDGE_VSHARE_FILE:-}" ]; then
        mcopy -o -i "$partition" "$BRIDGE_VSHARE_FILE" ::/WINDOWS/SYSTEM/VSHARE.386
    fi
    if [ -n "${BRIDGE_NO87:-}" ]; then
        sed '/^VER /i SET NO87=1\r' "$work/$mode/AUTOEXEC.BAT" > "$work/$mode/NO87.BAT"
        cp "$work/$mode/NO87.BAT" "$work/$mode/AUTOEXEC.BAT"
    fi
    mcopy -o -i "$partition" "$work/$mode/CONFIG.SYS" "$work/$mode/AUTOEXEC.BAT" \
        "$work/$mode/RUNARC.BAT" "$work/BRIDGE.EXE" "$work/TINY.COM" "$work/STEPS.COM" "$work/MZBARE.EXE" "$work/MZPAD.EXE" "$work/MZPAD4.EXE" "$work/REAL16.EXE" "$work/MIN16.EXE" "$work/HEAP16.EXE" \
        "${BRIDGE_ARCHIVE_EXE:-$root/build/archive-dos/OLFNLIST.EXE}" "$work/fixtures/STORED.ZIP" ::/
    mcopy -o -i "$partition" "$work/BIGMZ.EXE" ::/
    if [ "$mode" = relocprobe ]; then
        mcopy -o -i "$partition" "$work/TRACE16.EXE" ::/REAL16.EXE
    fi
    set --
    if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
    if [ -n "${BRIDGE_CPU:-}" ]; then set -- "$@" -cpu "$BRIDGE_CPU"; fi
    if [ -n "${BRIDGE_GDB:-}" ]; then
        set -- "$@" -gdb "unix:$work/$mode/gdb.sock,server=on,wait=off"
    fi
    {
        sleep 8
        echo "screendump $work/$mode/screen.ppm"
        echo 'info registers'
        if [ -n "${BRIDGE_DUMP_CPU:-}" ]; then
            echo "pmemsave 0x700 0x1000 $work/$mode/dos-memory.bin"
        fi
        sleep "${BRIDGE_EXTRA_WAIT:-2}"
        echo quit
    } | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
        -display none -vga std -monitor stdio -nic none \
        -debugcon "file:$work/$mode/debug-port.log" \
        -drive "if=ide,index=0,format=raw,file=$work/$mode/test.img" > "$work/$mode/qemu.log" 2>&1
    for output in BRIDGE.LOG DOSVER.LOG TINY.LOG MZENTRY.LOG STEP0.LOG STEP1.LOG STEP2.LOG ENTRY.LOG REAL16.LOG RESULT.IDX ARCOUT.LOG; do
        mcopy -o -i "$partition" "::/$output" "$work/$mode/$output" 2>/dev/null || true
    done
    echo "Case $mode"
    if [ -f "$work/$mode/BRIDGE.LOG" ]; then tr -d '\r' < "$work/$mode/BRIDGE.LOG"; fi
    for output in TINY.LOG MZENTRY.LOG STEP0.LOG STEP1.LOG STEP2.LOG ENTRY.LOG REAL16.LOG; do
        if [ -f "$work/$mode/$output" ]; then echo "Child reached marker $output"; fi
    done
    if [ -f "$work/$mode/RESULT.IDX" ]; then
        PYTHONPATH="$root/tests" python3 -c \
            'from pathlib import Path; import sys; from archive_reader_acceptance import decode; print("Validated archive index entries:", len(decode(Path(sys.argv[1]))))' \
            "$work/$mode/RESULT.IDX"
    fi
    if [ -f "$work/$mode/ARCOUT.LOG" ]; then tr -d '\r' < "$work/$mode/ARCOUT.LOG"; fi
done
