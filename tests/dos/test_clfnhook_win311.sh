#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set WIN311_IMAGE to a prepared Windows 3.11 raw disk image}"
watcom=${WATCOM:-/opt/watcom}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/clfnhook.XXXXXX")
printf 'Test artifacts: %s\n' "$work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
if [ -n "${WIN16_DRWATSON:-}" ]; then
    mcopy -i "$partition" ::/WINDOWS/WIN.INI "$work/WIN.ORIG"
    awk '{ sub(/\r$/, ""); if ($0 ~ /^load=/) print "load=C:\\DRWATSON.EXE\r"; else print $0 "\r"; }' \
        "$work/WIN.ORIG" > "$work/WIN.INI"
    mcopy -o -i "$partition" "$work/WIN.INI" ::/WINDOWS/WIN.INI
    mcopy -o -i "$partition" "$WIN16_DRWATSON" ::/DRWATSON.EXE
fi
# A foreign callback can enter with another task's DS. __loadds establishes
# ours, but Watcom's stack check would execute before it; -s avoids that.
# A normal Win16 local heap is required by the C runtime (link below).
for source in client manager; do
    "$watcom/binl64/wcc" -q -bt=windows -ml -zW -zu -s -os -w4 -we \
        -i="$watcom/h" -i="$watcom/h/win" -fr="$work/$source.err" \
        -fo="$work/$source.obj" "$root/tests/c/clfnhook_$source.c"
    "$root/build/toolchains/bin/jwlink" option quiet format windows \
        name "$work/HK$source.EXE" file "$work/$source.obj" \
        libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
        library windows,commdlg,clibl option stack=12k option heapsize=1k option version=3.10
done
"$watcom/binl64/wcc" -q -bt=windows -ms -bd -zW -zu -s -os -w4 -we \
    -i="$watcom/h" -i="$watcom/h/win" -fo="$work/legacy.obj" \
    -fr="$work/legacy.err" "$root/tests/c/legacy_hook_stub.c"
"$root/build/toolchains/bin/jwlink" option quiet format windows dll \
    name "$work/LEGACY.DLL" option modname=CLFNHOOK file "$work/legacy.obj" \
    file "$watcom/lib286/win/libentry.obj" libpath "$watcom/lib286/win" \
    libpath "$watcom/lib286" library windows option version=3.10 option heapsize=1k
mcopy -o -i "$partition" "$work/LEGACY.DLL" ::/
if [ -n "${HOOK_OFFICE_FIXTURE:-}" ]; then
    "$watcom/binl64/wcc" -q -bt=windows -ml -zW -zu -s -os -w4 -we \
        -i="$watcom/h" -i="$watcom/h/win" -fr="$work/office.err" \
        -fo="$work/office.obj" "$root/tests/c/office_dialog_client.c"
    for app in WINWORD EXCEL; do
        "$root/build/toolchains/bin/jwlink" option quiet format windows \
            name "$work/$app.EXE" file "$work/office.obj" \
            libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
            library windows,clibl option stack=12k option heapsize=1k option version=3.10
        mcopy -o -i "$partition" "$work/$app.EXE" ::/
    done
fi
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
if [ -n "${HOOK_CLIENT_ONLY:-}" ]; then
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\WINDOWS\\WIN C:\\HKCLIENT.EXE P\r\n' > "$work/AUTOEXEC.BAT"
else
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nDIR C:\\OLFNHOOK.DLL > C:\\HOOKDIR.LOG\r\nC:\\WINDOWS\\WIN C:\\HKMGR.EXE\r\n' > "$work/AUTOEXEC.BAT"
fi
if [ -n "${HOOK_OFFICE_FIXTURE:-}" ]; then
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nC:\\WINDOWS\\WIN C:\\HKMGR.EXE O\r\n' > "$work/AUTOEXEC.BAT"
fi
printf 'REPORT~1.TXT Annual report 2026.txt\004metadata-preserved\r\nUMLAUT~1.TXT Gr\201\341e aus K\224ln.txt\r\nHIDDEN~1.BIN Mapped hidden report.bin\r\n' > "$work/DESCRIPT.ION"
printf 'test data must remain unchanged\r\n' > "$work/REPORT.TXT"
mmd -i "$partition" ::/LFDTEST
mcopy -o -i "$partition" "$root/build/win16/clfnhook/OLFNHOOK.DLL" \
    "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" ::/
mcopy -o -i "$partition" "$root/build/win16/clfnhook/OLFNHOOK.DLL" ::/WINDOWS/SYSTEM/
mcopy -o -i "$partition" "$work/HKmanager.EXE" ::/HKMGR.EXE
mcopy -o -i "$partition" "$work/HKclient.EXE" ::/HKCLIENT.EXE
mcopy -o -i "$partition" "$work/DESCRIPT.ION" ::/LFDTEST/
mcopy -o -i "$partition" "$work/REPORT.TXT" ::/LFDTEST/REPORT~1.TXT
mcopy -o -i "$partition" "$work/REPORT.TXT" ::/LFDTEST/UMLAUT~1.TXT
mcopy -o -i "$partition" "$work/REPORT.TXT" ::/LFDTEST/NEWANN~1.TXT
mcopy -o -i "$partition" "$work/REPORT.TXT" ::/LFDTEST/HIDDEN~1.BIN
if [ -n "${HOOK_OFFICE_FIXTURE:-}" ]; then
    for fixture in OFFWORD OFFEXCEL; do
        mmd -i "$partition" "::/$fixture"
        mcopy -o -i "$partition" "$work/DESCRIPT.ION" "::/$fixture/"
        mcopy -o -i "$partition" "$work/REPORT.TXT" "::/$fixture/REPORT~1.TXT"
    done
fi
{
    sleep 6
    echo "screendump $work/screen.ppm"
    sleep 18
    echo quit
} | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 32 \
    -display none -vga std -monitor stdio -nic none \
    -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/monitor.log" 2>&1
logs='HKMGR HKCHILD HKPLAIN'
if [ -n "${HOOK_OFFICE_FIXTURE:-}" ]; then logs='HKMGR OFFWORD OFFEXCEL'; fi
if [ -n "${WIN16_DRWATSON:-}" ]; then
    mcopy -o -i "$partition" ::/DRWATSON.LOG "$work/DRWATSON.LOG" 2>/dev/null || \
        mcopy -o -i "$partition" ::/WINDOWS/DRWATSON.LOG "$work/DRWATSON.LOG" 2>/dev/null || true
fi
if [ -n "${HOOK_CLIENT_ONLY:-}" ]; then logs=HKPLAIN; fi
result=0
for log in $logs; do
    if ! mcopy -o -i "$partition" "::/$log.LOG" "$work/$log.LOG"; then
        result=1
        continue
    fi
    tr -d '\r' < "$work/$log.LOG"
    grep -q '^RESULT PASS' "$work/$log.LOG" || result=1
done
if [ -n "${HOOK_OFFICE_FIXTURE:-}" ]; then
    cp "$work/DESCRIPT.ION" "$work/OFFICE-EXPECTED.ION"
    printf 'OFFICE~1.TXT Office new report 2026.txt\r\n' >> "$work/OFFICE-EXPECTED.ION"
    printf 'independent Office adapter fixture\r\n' > "$work/OFFICE-EXPECTED.TXT"
    for fixture in OFFWORD OFFEXCEL; do
        mcopy -o -i "$partition" "::/$fixture/DESCRIPT.ION" "$work/$fixture.ION"
        mcopy -o -i "$partition" "::/$fixture/REPORT~1.TXT" "$work/$fixture-ORIGINAL.TXT"
        mcopy -o -i "$partition" "::/$fixture/OFFICE~1.TXT" "$work/$fixture-SAVED.TXT"
        cmp "$work/OFFICE-EXPECTED.ION" "$work/$fixture.ION"
        cmp "$work/REPORT.TXT" "$work/$fixture-ORIGINAL.TXT"
        cmp "$work/OFFICE-EXPECTED.TXT" "$work/$fixture-SAVED.TXT"
        for sidecar in CLFN.SAV CLFN.BAK CLFN.NEW CLFN.LCK; do
            if mtype -i "$partition" "::/$fixture/$sidecar" >/dev/null 2>&1; then
                echo "Unexpected Office transaction artifact: $fixture/$sidecar" >&2
                result=1
            fi
        done
    done
    exit "$result"
fi
mcopy -o -i "$partition" ::/LFDTEST/DESCRIPT.ION "$work/AFTER.ION"
mcopy -o -i "$partition" ::/LFDTEST/REPORT~1.TXT "$work/AFTER.TXT"
mcopy -o -i "$partition" ::/LFDTEST/UMLAUT~1.TXT "$work/AFTER2.TXT"
mcopy -o -i "$partition" ::/LFDTEST/NEWANN~1.TXT "$work/COLLISION.TXT"
mcopy -o -i "$partition" ::/LFDTEST/HIDDEN~1.BIN "$work/HIDDEN.TXT"
cp "$work/DESCRIPT.ION" "$work/EXPECTED.ION"
if [ -z "${HOOK_CLIENT_ONLY:-}" ]; then
    printf 'NEWANN~2.TXT New annual report 2026.txt\r\nNEUEGR~1.TXT Neue Gr\201\341e 2026.txt\r\n' >> "$work/EXPECTED.ION"
    printf 'saved through ordinary Win16 application\r\n' > "$work/SAVED.TXT"
    mcopy -o -i "$partition" ::/LFDTEST/NEWANN~2.TXT "$work/NEWASCII.TXT"
    mcopy -o -i "$partition" ::/LFDTEST/NEUEGR~1.TXT "$work/NEWUMLAUT.TXT"
    cmp "$work/SAVED.TXT" "$work/NEWASCII.TXT"
    cmp "$work/SAVED.TXT" "$work/NEWUMLAUT.TXT"
    for sidecar in CLFN.SAV CLFN.BAK CLFN.NEW CLFN.LCK NEVERC~1.TXT; do
        if mtype -i "$partition" "::/LFDTEST/$sidecar" >/dev/null 2>&1; then
            echo "Unexpected pending/recovery artifact: $sidecar" >&2
            result=1
        fi
    done
fi
cmp "$work/EXPECTED.ION" "$work/AFTER.ION"
cmp "$work/REPORT.TXT" "$work/AFTER.TXT"
cmp "$work/REPORT.TXT" "$work/AFTER2.TXT"
cmp "$work/REPORT.TXT" "$work/COLLISION.TXT"
cmp "$work/REPORT.TXT" "$work/HIDDEN.TXT"
exit "$result"
