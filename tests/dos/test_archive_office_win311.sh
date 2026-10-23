#!/bin/sh
# Requires legally supplied installed Office; never adds private media to Git.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a DOS 6.22 Windows image with Office installed under C:\MSOFFICE}"
watcom=${WATCOM:-/opt/watcom}
archive_dir=${ARCHIVE_PACKAGE:-$root/build/win16/archive}
hook_dir=${ARCHIVE_PACKAGE:-$root/build/win16/clfnhook}
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/archive-office.XXXXXX")
echo "Actual Office ZIP artifacts: $work"
"$watcom/binl64/wcc" -q -bt=windows -ml -zW -zu -s -os -w4 -we \
    -i="$watcom/h" -i="$watcom/h/win" -fr="$work/client.err" \
    -fo="$work/client.obj" "$root/tests/c/archive_office_client.c"
"$root/build/toolchains/bin/jwlink" option quiet format windows name "$work/ARCOFF.EXE" \
    file "$work/client.obj" libpath "$watcom/lib286/win" libpath "$watcom/lib286" \
    library windows,clibl option stack=12k option heapsize=1k option version=3.10
python3 "$root/tests/archive_reader_acceptance.py" --fixtures "$work/fixtures"
for profile in W E; do
    mkdir "$work/$profile"
    cp --reflink=auto "$WIN311_IMAGE" "$work/$profile/test.img"
    partition="$work/$profile/test.img@@${WIN311_OFFSET:-32256}"
    for file in SHARE.EXE MSOFFICE/WINWORD/WINWORD.EXE MSOFFICE/EXCEL/EXCEL.EXE; do
        mdir -i "$partition" "::/$file" >/dev/null
    done
    if mdir -i "$partition" ::/ARCDATA >/dev/null 2>&1; then
        echo 'Test requires no existing C:\ARCDATA directory' >&2; exit 1
    fi
    mmd -i "$partition" ::/ARCDATA
    mmd -i "$partition" ::/TEMP 2>/dev/null || true
    printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/$profile/CONFIG.SYS"
    printf '@ECHO OFF\r\nPATH C:\\;C:\\WINDOWS\r\nSET TEMP=C:\\TEMP\r\nC:\\SHARE.EXE /L:500 /F:5100\r\nC:\\WINDOWS\\WIN C:\\ARCOFF.EXE %s\r\n' "$profile" > "$work/$profile/AUTOEXEC.BAT"
    mcopy -o -i "$partition" "$work/$profile/CONFIG.SYS" "$work/$profile/AUTOEXEC.BAT" \
        "$work/ARCOFF.EXE" "$hook_dir/OLFNHOOK.DLL" "$archive_dir/OLFNVIEW.EXE" \
        "$archive_dir/OLFNLIST.EXE" ::/
    mcopy -i "$partition" "$work/fixtures/DEFLATE.ZIP" ::/ARCDATA/
    {
        sleep 7
        echo "screendump $work/$profile/app.ppm"
        # The supplied Word profile opens its first-run Tips window. Accept
        # it before File Open; in Excel Enter moves the empty selection.
        echo 'sendkey ret'
        sleep 2
        if [ "$profile" = W ]; then
            # File Open shortcut for the supplied German Word profile.
            echo 'sendkey ctrl-f12'
        else
            echo 'sendkey ctrl-o'
        fi
        sleep 6
        echo "screendump $work/$profile/preview.ppm"
        # Acknowledge the missing-ZIP error using genuine keyboard input.
        # The test driver waits for it to close before trying the valid ZIP.
        echo 'sendkey ret'
        sleep 17
        echo "screendump $work/$profile/end.ppm"
        echo quit
    } | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 32 -display none \
        -vga std -monitor stdio -nic none \
        -drive "if=ide,index=0,format=raw,file=$work/$profile/test.img" > "$work/$profile/qemu.log" 2>&1
    mcopy -o -i "$partition" ::/ARCOFF.LOG "$work/$profile/ARCOFF.LOG"
    tr -d '\r' < "$work/$profile/ARCOFF.LOG"
    grep -q '^RESULT PASS' "$work/$profile/ARCOFF.LOG"
    mcopy -o -i "$partition" ::/ARCDATA/DEFLATE.ZIP "$work/$profile/AFTER.ZIP"
    cmp "$work/fixtures/DEFLATE.ZIP" "$work/$profile/AFTER.ZIP"
    # Preview alone must not reserve a Save or create a display-name mapping.
    for sidecar in DESCRIPT.ION CLFN.SAV CLFN.BAK CLFN.NEW CLFN.LCK; do
        if mdir -i "$partition" "::/ARCDATA/$sidecar" >/dev/null 2>&1; then
            echo "Unexpected preview artifact: $sidecar" >&2; exit 1
        fi
    done
done
