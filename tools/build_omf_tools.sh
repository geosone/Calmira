#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_root="$project_root/vendor/build-deps"
build_root=${OMF_BUILD_DIR:-"$project_root/build/toolchains/omf"}
install_root=${OMF_BIN_DIR:-"$project_root/build/toolchains/bin"}
jobs=${JOBS:-2}

for tool in gcc make; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required host tool not found: $tool" >&2
        exit 1
    fi
done

mkdir -p "$build_root/jwasm" "$build_root/jwlink" \
    "$build_root/wres" "$install_root"

make -C "$source_root/geosone-jwasm" -f GccUnix.mak -j"$jobs" \
    OUTD="$build_root/jwasm"
make -C "$source_root/geosone-jwlink" -f GccUnix.mak -j"$jobs" \
    OUTD="$build_root/jwlink" outd_wres="$build_root/wres"

install -m 0755 "$build_root/jwasm/jwasm" "$install_root/jwasm"
install -m 0755 "$build_root/jwlink/jwlink" "$install_root/jwlink"
ln -sfn jwlink "$install_root/wlink"

echo "Pinned JWasm/JWlink installed in $install_root"
