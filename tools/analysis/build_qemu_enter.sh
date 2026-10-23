#!/bin/sh
# Build an isolated diagnostic emulator; never install it or enable KVM.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
archive=${QEMU_SOURCE_ARCHIVE:-/var/cache/distfiles/qemu-10.2.3.tar.xz}
expected=b91e151d41856c54276e8ab348cbfc322f8c88a140276c77f72dcdbdfea71fc49db1519ca6a2974af7b5a7966cc30d530ee4ad62176503261da351333a8676b1
if [ ! -f "$archive" ]; then
    echo 'Set QEMU_SOURCE_ARCHIVE to the official qemu-10.2.3.tar.xz archive.' >&2
    exit 2
fi
actual=$(sha512sum "$archive")
actual=${actual%% *}
if [ "$actual" != "$expected" ]; then
    echo 'QEMU source archive SHA-512 mismatch; refusing extraction.' >&2
    exit 2
fi
work="$root/build/toolchains/qemu-enter"
source="$work/qemu-10.2.3"
compiled="$work/compiled"
fix="$root/tools/patches/qemu-10.2.3-enter-unsigned.patch"
mkdir -p "$work"
if [ ! -e "$source" ]; then
    tar -xf "$archive" -C "$work"
fi
# Require the expected ENTER context, either unpatched or already patched.
if patch --dry-run --batch --forward --fuzz=0 -d "$source" -p1 < "$fix" >/dev/null 2>&1; then
    patch --batch --forward --fuzz=0 -d "$source" -p1 < "$fix"
elif ! patch --dry-run --batch --reverse --fuzz=0 -d "$source" -p1 < "$fix" >/dev/null 2>&1; then
    echo 'Unexpected ENTER emitter contents; preserving the existing tree.' >&2
    exit 2
fi
mkdir -p "$compiled"
cd "$compiled"
../qemu-10.2.3/configure --target-list=i386-softmmu,i386-linux-user \
    --without-default-features --enable-tcg --enable-pixman --disable-kvm \
    --disable-docs --disable-werror --disable-download > configure.log 2>&1
ninja -j "${QEMU_BUILD_JOBS:-8}" qemu-system-i386 qemu-i386 > build.log 2>&1
echo "Diagnostic QEMU binaries: $compiled"
PATH="$compiled:$PATH" sh "$root/tools/analysis/check_qemu_enter.sh"
