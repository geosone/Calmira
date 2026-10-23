#!/bin/sh
# Independent CPU-emulation check; no Windows media or hardware acceleration.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
for tool in nasm ld qemu-i386; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 2; }
done
mkdir -p "$root/build/tests"
work=$(mktemp -d "$root/build/tests/enter-check.XXXXXX")
echo "ENTER diagnostic artifacts: $work"
qemu-i386 --version | head -n 1
nasm -f elf32 "$root/tests/asm/enter_frame_probe.asm" -o "$work/probe.o"
ld -m elf_i386 "$work/probe.o" -o "$work/probe"
"$work/probe" > "$work/native.bin" || {
    echo 'Native i386 baseline failed or is unavailable; comparison invalid.' >&2
    exit 2
}
status=0
qemu-i386 "$work/probe" > "$work/tcg.bin" || status=$?
echo 'Expected: 00007fff 00008000 0000846c 0000ffff'
echo 'Native:'
od -An -tx4 "$work/native.bin"
echo 'TCG:'
od -An -tx4 "$work/tcg.bin"
if [ "$status" -ne 0 ] || ! cmp -s "$work/native.bin" "$work/tcg.bin"; then
    echo 'FAIL: TCG ENTER allocation differs from native execution.' >&2
    exit 1
fi
echo 'PASS: TCG ENTER allocations match native execution.'
