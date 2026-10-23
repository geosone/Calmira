#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${WIN311_IMAGE:?Set a prepared raw DOS/Windows image}"
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/archive-dos.XXXXXX")
echo "Archive DOS artifacts: $work"
cp --reflink=auto "$WIN311_IMAGE" "$work/test.img"
partition="$work/test.img@@${WIN311_OFFSET:-32256}"
python3 "$root/tests/archive_reader_acceptance.py" --fixtures "$work/fixtures"
printf 'DEVICE=C:\\HIMEM.SYS\r\nFILES=40\r\nSHELL=C:\\COMMAND.COM C:\\ /P\r\n' > "$work/CONFIG.SYS"
mcopy -o -i "$partition" "$root/build/archive-dos/OLFNLIST.EXE" "$work/CONFIG.SYS" "$work/fixtures/"* ::/
{
    sleep 6
    echo "screendump $work/dos.ppm"
    sleep 2
    echo quit
} | qemu-system-i386 -machine pc -accel "${QEMU_ACCEL:-tcg}" -m 32 -display none \
    -monitor stdio -nic none -drive "if=ide,index=0,format=raw,file=$work/test.img" > "$work/qemu.log" 2>&1
mcopy -o -i "$partition" ::/ARCTEST.LOG "$work/ARCTEST.LOG"
grep -q DONE "$work/ARCTEST.LOG"
if grep -q FAIL "$work/ARCTEST.LOG"; then tr -d '\r' < "$work/ARCTEST.LOG"; exit 1; fi
mcopy -o -i "$partition" ::/DOSOUT.LOG "$work/DOSOUT.LOG"
if grep -Eiq 'exception|fatal|stack overflow' "$work/DOSOUT.LOG"; then
    echo 'DOS helper reported a runtime fault.' >&2; exit 1
fi
for name in STORED DEFLATE EMPTY PATHS MAXCOUNT LONGOK LEGACY UNICODEX; do
    mcopy -o -i "$partition" "::/$name.IDX" "$work/$name.IDX"
    mcopy -o -i "$partition" "::/$name.ZIP" "$work/$name.ZIP"
    cmp "$work/fixtures/$name.ZIP" "$work/$name.ZIP"
done
for name in BIGCOUNT LONGNAME MEMLIMIT BAD BADUTF DEVICE; do
    if mtype -i "$partition" "::/$name.IDX" >/dev/null 2>&1; then
        echo "Unexpected index for rejected archive: $name" >&2; exit 1
    fi
done
mcopy -o -i "$partition" ::/KEEP.IDX "$work/KEEP.IDX"
printf 'foreign-output\r\n' > "$work/KEEP-EXPECTED.IDX"
cmp "$work/KEEP-EXPECTED.IDX" "$work/KEEP.IDX"
python3 - "$root" "$work" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]) / "tests"))
from archive_reader_acceptance import decode
work = Path(sys.argv[2])
for path in sorted(work.glob("*.IDX")):
    if path.name.startswith("KEEP"):
        continue
    items = decode(path)
    print(f"PASS native DOS index {path.name}: {len(items)} entries")
assert decode(work / "UNICODEX.IDX")[0][0] == "Grüße aus Köln.txt".encode("utf-8")
assert decode(work / "DEFLATE.IDX")[0][4] == 8
assert decode(work / "LEGACY.IDX")[0][0] == b"\x82.txt"
PY
