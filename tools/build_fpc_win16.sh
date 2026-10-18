#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fpc_source=${FPC_SOURCE:-"$project_root/vendor/reference/freepascal"}
install_prefix=${FPC_WIN16_PREFIX:-"$project_root/build/toolchains/fpc-win16"}
bootstrap_fpc=${FPC_BOOTSTRAP:-fpc}
watcom_root=${WATCOM:-/opt/watcom}
omf_bin_dir=${OMF_BIN_DIR:-"$project_root/build/toolchains/bin"}
jobs=${JOBS:-2}

if [ ! -f "$fpc_source/Makefile" ]; then
    echo "Free Pascal source tree not found: $fpc_source" >&2
    exit 1
fi
if ! command -v "$bootstrap_fpc" >/dev/null 2>&1; then
    echo "Bootstrap compiler not found: $bootstrap_fpc" >&2
    exit 1
fi
if ! command -v nasm >/dev/null 2>&1; then
    echo "NASM is required for the Win16 RTL startup objects." >&2
    exit 1
fi

if [ -x "$omf_bin_dir/wlink" ]; then
    PATH="$omf_bin_dir:$PATH"
elif [ -x "$watcom_root/binl64/wlink" ]; then
    PATH="$watcom_root/binl64:$watcom_root/binl:$PATH"
elif [ -x "$watcom_root/binl/wlink" ]; then
    PATH="$watcom_root/binl:$PATH"
fi
export PATH

if ! command -v wlink >/dev/null 2>&1; then
    echo "wlink not found; run 'make omf-toolchain' or set WATCOM." >&2
    exit 1
fi

make -C "$fpc_source" -j"$jobs" crossall \
    FPC="$bootstrap_fpc" CPU_TARGET=i8086 OS_TARGET=win16 \
    BINUTILSPREFIX= OPT='-O2 -CX'
make -C "$fpc_source" crossinstall \
    FPC="$bootstrap_fpc" CPU_TARGET=i8086 OS_TARGET=win16 \
    BINUTILSPREFIX= OPT='-O2 -CX' INSTALL_PREFIX="$install_prefix"

echo "Free Pascal Win16 cross toolchain installed in $install_prefix"
