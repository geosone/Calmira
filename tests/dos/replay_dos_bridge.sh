#!/bin/sh
# Replay exactly the same private diagnostic disk contents under both CPUs.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${BRIDGE_SOURCE_IMAGE:?Set a previously generated dos-bridge real/test.img}"
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/bridge-replay.XXXXXX")
echo "Replay artifacts: $work"
cp --reflink=auto "$BRIDGE_SOURCE_IMAGE" "$work/prepared.img"
partition="$work/prepared.img@@${WIN311_OFFSET:-32256}"
probe=${BRIDGE_REPLAY_FILE:-REAL16.EXE}
case "$probe" in REAL16.EXE|OLFNLIST.EXE) ;; *) echo 'Unknown replay executable' >&2; exit 2 ;; esac
mcopy -i "$partition" "::/$probe" "$work/$probe"
sha256sum "$work/$probe"
if [ -n "${BRIDGE_RELOCATE_FILE:-}${BRIDGE_FRAGMENT_FILE:-}${BRIDGE_EXE_OVERRIDE:-}${BRIDGE_PAD_BYTES:-}" ]; then
    if [ "$probe" != REAL16.EXE ]; then echo 'Placement controls require REAL16.EXE' >&2; exit 2; fi
    if mdir -i "$partition" ::/OLDREAL.EXE >/dev/null 2>&1; then
        echo 'Diagnostic name OLDREAL.EXE already exists' >&2; exit 1
    fi
    mren -i "$partition" ::/REAL16.EXE ::/OLDREAL.EXE
    if [ -n "${BRIDGE_PAD_BYTES:-}" ]; then
        case "$BRIDGE_PAD_BYTES" in *[!0-9]*|'') exit 2 ;; esac
        if mdir -i "$partition" ::/PAD.BIN >/dev/null 2>&1; then
            echo 'Diagnostic name PAD.BIN already exists' >&2; exit 1
        fi
        truncate -s "$BRIDGE_PAD_BYTES" "$work/pad.bin"
        mcopy -i "$partition" "$work/pad.bin" ::/PAD.BIN
    fi
    if [ -n "${BRIDGE_FRAGMENT_FILE:-}" ]; then
        for name in GAP1.BIN GAP2.BIN; do
            if mdir -i "$partition" "::/$name" >/dev/null 2>&1; then
                echo "Diagnostic name already exists: $name" >&2; exit 1
            fi
        done
        truncate -s 4096 "$work/filler.bin"
        mcopy -i "$partition" "$work/filler.bin" ::/GAP1.BIN
        mcopy -i "$partition" "$work/filler.bin" ::/GAP2.BIN
        # Delete only the newly generated filler in the private copy; retain
        # GAP2 so the executable has to span the first hole and another extent.
        mdel -i "$partition" ::/GAP1.BIN
    fi
    if [ -n "${BRIDGE_EXE_OVERRIDE:-}" ]; then
        cp "$BRIDGE_EXE_OVERRIDE" "$work/REAL16.EXE"
        sha256sum "$work/REAL16.EXE"
    fi
    mcopy -i "$partition" "$work/REAL16.EXE" ::/REAL16.EXE
fi
if [ -n "${BRIDGE_SWAP_ENTRIES:-}${BRIDGE_SWAP_CHAINS:-}" ]; then
    mode=entries
    if [ -n "${BRIDGE_SWAP_CHAINS:-}" ]; then mode=chains; fi
    python3 "$root/tools/analysis/swap_probe_entries.py" "$work/prepared.img" \
        --mode "$mode" --offset "${WIN311_OFFSET:-32256}"
fi
mshowfat -i "$partition" ::/REAL16.EXE
if [ -n "${BRIDGE_NO_VFAT:-}${BRIDGE_VSHARE_FILE:-}" ]; then
    mcopy -i "$partition" ::/WINDOWS/SYSTEM.INI "$work/SYSTEM.ORIG"
    if [ -n "${BRIDGE_NO_VFAT:-}" ]; then
        sed -E '/^device=(ifsmgr|vcache|vshare)\.386\r?$/Id' "$work/SYSTEM.ORIG" > "$work/SYSTEM.INI"
        mcopy -o -i "$partition" "$work/SYSTEM.INI" ::/WINDOWS/SYSTEM.INI
    fi
    if [ -n "${BRIDGE_VSHARE_FILE:-}" ]; then
        mcopy -o -i "$partition" "$BRIDGE_VSHARE_FILE" ::/WINDOWS/SYSTEM/VSHARE.386
    fi
fi
for marker in BRIDGE.LOG ENTRY.LOG REAL16.LOG MZENTRY.LOG RESULT.IDX ARCOUT.LOG; do
    mdel -i "$partition" "::/$marker" 2>/dev/null || true
done
for accel in ${BRIDGE_ACCELS:-tcg}; do
    mkdir "$work/$accel"
    cp --reflink=auto "$work/prepared.img" "$work/$accel/test.img"
    set --
    if [ -n "${QEMU_DATA_DIR:-}" ]; then set -- -L "$QEMU_DATA_DIR"; fi
    {
        sleep 8
        echo "screendump $work/$accel/screen.ppm"
        echo 'info registers'
        sleep 2
        echo quit
    } | qemu-system-i386 -machine pc -accel "$accel" -cpu qemu32 "$@" -m 32 \
        -display none -vga std -monitor stdio -nic none \
        -debugcon "file:$work/$accel/debug-port.log" \
        -drive "if=ide,index=0,format=raw,file=$work/$accel/test.img" > "$work/$accel/qemu.log" 2>&1
    after="$work/$accel/test.img@@${WIN311_OFFSET:-32256}"
    for marker in BRIDGE.LOG ENTRY.LOG REAL16.LOG MZENTRY.LOG RESULT.IDX ARCOUT.LOG; do
        mcopy -i "$after" "::/$marker" "$work/$accel/$marker" 2>/dev/null || true
    done
    mcopy -i "$after" "::/$probe" "$work/$accel/$probe"
    cmp "$work/$probe" "$work/$accel/$probe"
    echo "Accelerator $accel, unchanged executable"
    if [ -f "$work/$accel/BRIDGE.LOG" ]; then tr -d '\r' < "$work/$accel/BRIDGE.LOG"; fi
    if [ -f "$work/$accel/REAL16.LOG" ]; then tr -d '\r' < "$work/$accel/REAL16.LOG"; fi
    if [ -f "$work/$accel/MZENTRY.LOG" ]; then echo 'Bare assembly MZ reached its file marker'; fi
    if [ -f "$work/$accel/ARCOUT.LOG" ]; then tr -d '\r' < "$work/$accel/ARCOUT.LOG"; fi
    if [ -f "$work/$accel/RESULT.IDX" ]; then
        PYTHONPATH="$root/tests" python3 -c \
            'from pathlib import Path; import sys; from archive_reader_acceptance import decode; print("Validated archive index entries:", len(decode(Path(sys.argv[1]))))' \
            "$work/$accel/RESULT.IDX"
    fi
done
