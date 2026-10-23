#!/bin/sh
# Build a separate, consistent huge-code RTL; never mix it with large-code PPUs.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source=${FPC_SOURCE:-"$root/vendor/reference/freepascal"}
compiler=${FPC_WIN16:-"$root/build/toolchains/fpc-win16/lib/fpc/3.3.1/ppcross8086"}
output=${FPC_WIN16_RTL:-"$root/build/win16-rtl/units"}
mkdir -p "$output"
stage=$(python3 "$root/tools/prepare_win16_rtl.py" --source "$source" --output "$root/build/win16-rtl/sources")
PATH="$root/build/toolchains/bin:$PATH" make -C "$stage/rtl/win16" -j"${JOBS:-2}" all \
    CPU_TARGET=i8086 OS_TARGET=win16 FPC="$compiler" PP="$compiler" \
    BINUTILSPREFIX= OPT='-O2 -CX -Wh -dCALMIRA_WIN16_MESSAGE_ABI -dCALMIRA_WIN16_SJLJ_TAILCALL -dCALMIRA_WIN16_GUI_STDIO -dCALMIRA_WIN16_REALLOC_BOUNDS' COMPILER_UNITTARGETDIR="$output"
