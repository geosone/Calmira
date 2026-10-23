#!/bin/sh
# Isolated compiler correction; retain the existing installed cross toolchain.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source=${FPC_SOURCE:-"$root/vendor/reference/freepascal"}
output=${FPC_FIXED_ROOT:-"$root/build/toolchains/fpc-class-pointer"}
bootstrap=${FPC_BOOTSTRAP:-fpc}
host_cpu=$("$bootstrap" -iTP)
host_os=$("$bootstrap" -iTO)
version=$("$bootstrap" -iV)
stage=$(python3 "$root/tools/prepare_fpc_compiler.py" --source "$source" \
    --output "$output/sources" --build-id "$version-$host_cpu-$host_os")
make -C "$stage/compiler" -j"${JOBS:-2}" compiler PPC_TARGET=i8086 \
    CPU_TARGET="$host_cpu" OS_TARGET="$host_os" FPC="$bootstrap" FPCDIR="$stage" OPT=-O2
if ! cmp -s "$stage/compiler/ppc8086" "$output/ppcross8086"; then
    install -m 755 "$stage/compiler/ppc8086" "$output/ppcross8086.new"
    mv "$output/ppcross8086.new" "$output/ppcross8086"
fi
cp "$stage/calmira-compiler.json" "$output/compiler.json"
echo "Corrected i8086 compiler: $output/ppcross8086"
