#!/bin/sh
# Build the small-model MS-DOS RTL for Calmira's Turbo Pascal DOS helpers
# (COUNTTIP, DIREXIST, DOSRUN) from the same staged, patched sources as Win16.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source=${FPC_SOURCE:-"$root/vendor/reference/freepascal"}
compiler=${FPC_WIN16:-"$root/build/toolchains/fpc-win16/lib/fpc/3.3.1/ppcross8086"}
output=${FPC_MSDOS_RTL:-"$root/build/msdos-rtl/units-small"}
mkdir -p "$output"
stage=$(python3 "$root/tools/prepare_win16_rtl.py" --source "$source" --output "$root/build/win16-rtl/sources")
PATH="$root/build/toolchains/bin:$PATH" make -C "$stage/rtl/msdos" -j"${JOBS:-2}" all \
    CPU_TARGET=i8086 OS_TARGET=msdos FPC="$compiler" PP="$compiler" \
    BINUTILSPREFIX= OPT="-O2 -CX -WmSmall" NASM_OPT=-DCALMIRA_MSDOS_MAXHEAP \
    COMPILER_UNITTARGETDIR="$output"
