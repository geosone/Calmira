#!/bin/sh
# Calmira's DOS helpers under plain MS-DOS: DIREXIST exit codes, COUNTTIP
# against the Calmira 3.02 binary, and the memory DOSRUN leaves for the
# program it starts.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared Windows 3.1x raw disk image}"
: "${DOS_HELPERS_DIR:?Set the directory holding COUNTTIP.EXE, DIREXIST.EXE and DOSRUN.EXE}"
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/dos-helpers.XXXXXX")
echo "GDI artifacts: $work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
# Each DIREXIST case appends 0 or 1; IF ERRORLEVEL 1 is true for 1 and above.
# COMMAND.COM opens an IF line's redirection even when the condition is
# false, so both lines append rather than truncate.
{
    printf '@ECHO OFF\r\nPATH C:\;C:\\DOS\r\nMD C:\\OUT\r\nCD \\DOS\r\n'
    for case in 'DOS:C:\DOS' 'FILE:C:\AUTOEXEC.BAT' 'NONE:C:\NOSUCH' 'ROOT:C:\' 'UP:..' 'EMPTY:'; do
        printf 'C:\\DIREXIST.EXE %s\r\n' "${case#*:}"
        printf 'IF ERRORLEVEL 1 ECHO 1>> C:\\OUT\\%s.TXT\r\n' "${case%%:*}"
        printf 'IF NOT ERRORLEVEL 1 ECHO 0>> C:\\OUT\\%s.TXT\r\n' "${case%%:*}"
    done
    printf 'CD \\\r\n'
    printf 'C:\\COUNTTIP.EXE < C:\\TIPS.TXT > C:\\OUT\\TIPS.TXT\r\n'
    printf 'C:\\TIPORIG.EXE < C:\\TIPS.TXT > C:\\OUT\\TIPORIG.TXT\r\n'
    printf 'C:\\DOS\\MEM.EXE > C:\\OUT\\BARE.TXT\r\n'
    printf 'C:\\DOSRUN.EXE C:\\DOS\\MEM.EXE > C:\\OUT\\RUN.TXT\r\n'
    printf 'ECHO DONE> C:\\OUT\\DONE.TXT\r\n'
} > "$work/AUTOEXEC.BAT"
mcopy -o -i "$partition" "$work/CONFIG.SYS" "$work/AUTOEXEC.BAT" \
    "$DOS_HELPERS_DIR/COUNTTIP.EXE" "$DOS_HELPERS_DIR/DIREXIST.EXE" "$DOS_HELPERS_DIR/DOSRUN.EXE" ::/
mcopy -o -i "$partition" "$root/vendor/upstream/calmira-3.02/SRC/COUNTTIP.EXE" ::/TIPORIG.EXE
mcopy -o -i "$partition" "$root/src/tips.txt" ::/TIPS.TXT
set --
if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
{ sleep "${DOS_TEST_SECONDS:-40}"; echo "screendump $work/screen.ppm"; sleep 1; echo quit; } \
| qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" "$@" -m 32 \
    -display none -vga std -monitor stdio -nic none \
    -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/qemu.log" 2>&1
mkdir -p "$work/out"
mcopy -n -o -i "$partition" "::/OUT/*" "$work/out/" 2>/dev/null || true
python3 - "$work" <<'PY'
import re, sys
from pathlib import Path
work = Path(sys.argv[1]); out = work / 'out'
lines = []
def check(ok, text): lines.append(('PASS ' if ok else 'FAIL ') + text)
def read(name):
    path = out / name
    return path.read_bytes().decode('cp850').replace('\r', '') if path.exists() else ''
check(read('DONE.TXT').strip() == 'DONE', 'the DOS script ran to the end')
for name, code, text in (('DOS', '1', 'DIREXIST reports a directory'), ('FILE', '0', 'DIREXIST rejects a file'),
                         ('NONE', '0', 'DIREXIST rejects a missing path'), ('ROOT', '1', 'DIREXIST accepts a root'),
                         ('UP', '1', 'DIREXIST accepts ..'), ('EMPTY', '0', 'DIREXIST without a parameter')):
    check(read(name + '.TXT').strip() == code, text)
tips = read('TIPS.TXT')
check(tips and tips == read('TIPORIG.TXT'), 'COUNTTIP output matches Calmira 3.02')
def largest(text):
    match = re.search(r'\(([\d,.]+) Byte', text)
    return int(re.sub(r'[,.]', '', match.group(1))) if match else 0
bare, run = largest(read('BARE.TXT')), largest(read('RUN.TXT'))
check(run > 0, 'DOSRUN starts the program')
# Turbo Pascal's DOSRUN keeps about 6 KiB; FPC's code is larger. Without the
# startup patch the whole 64 KiB data segment stays allocated.
check(run > 0 and bare - run <= 32 * 1024, f'DOSRUN leaves the started program its memory ({bare - run} bytes kept)')
lines.append('RESULT ' + ('FAIL' if any(l.startswith('FAIL') for l in lines) else 'PASS'))
(work / 'GDITEST.LOG').write_text('\r\n'.join(lines) + '\r\n')
print('\n'.join(lines))
PY
grep -q '^RESULT PASS' "$work/GDITEST.LOG"
