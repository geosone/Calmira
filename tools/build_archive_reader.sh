#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
watcom=${WATCOM:-/opt/watcom}
build=${ARCHIVE_BUILD_DIR:-$root/build/archive-dos}
mode=${1:-dos}
diagnostic_flags=''
if [ -n "${ARCHIVE_DIAGNOSTIC:-}" ]; then
    if [ "$mode" != dos ] || [ -z "${ARCHIVE_BUILD_DIR:-}" ]; then
        echo 'Diagnostic instrumentation requires DOS mode and an isolated ARCHIVE_BUILD_DIR.' >&2
        exit 1
    fi
    diagnostic_flags=-dARC_DIAGNOSTIC
fi
sanitizer_flags=''
if [ "$mode" = host ] && [ "${ARCHIVE_SANITIZE:-}" = 1 ]; then
    sanitizer_flags='-fsanitize=address,undefined -fno-omit-frame-pointer'
fi
src="$build/source"
pin=9128b80e3a471108678e2b3ec3c985861c8d7b0f
test "$(git -C "$root/vendor/reference/7zip" rev-parse HEAD)" = "$pin" || {
    echo 'Initialize the pinned 7-Zip submodule.' >&2; exit 1;
}
mkdir -p "$src" "$build/obj"
cp -a "$root/vendor/reference/7zip/C" "$root/vendor/reference/7zip/CPP" "$src/"
patch --fuzz=0 --no-backup-if-mismatch -d "$src" -p1 < "$root/tools/patches/7zip-watcom.patch"
if [ "$mode" = dos ]; then
    cpp="$watcom/binl64/wpp386"
    cc="$watcom/binl64/wcc386"
elif [ "$mode" = host ]; then
    cpp=${ARCHIVE_CXX:-clang++}
    cc=${ARCHIVE_CC:-clang}
else
    echo 'Expected dos or host.' >&2; exit 1
fi
compile_cpp() {
    name=$1
    source=$2
    if [ "$mode" = dos ]; then
        "$cpp" -q -bt=dos -mf -3r -s -os -xs -w4 -we $diagnostic_flags -i="$watcom/h" \
            -dCALMIRA_PORTABLE_LOADS -i="$src/CPP" -i="$src/C" -fo="$build/obj/$name.obj" \
            -fr="$build/obj/$name.err" "$source"
    else
        "$cpp" $sanitizer_flags -std=c++11 -O1 -g -Wall -Wextra -Werror -DCALMIRA_PORTABLE_LOADS -I"$src/CPP" -I"$src/C" \
            -c "$source" -o "$build/obj/$name.obj"
    fi
}
compile_c() {
    name=$1
    source=$2
    shift 2
    if [ "$mode" = dos ]; then
        "$cc" -q -bt=dos -mf -3r -s -os -w4 -we -i="$watcom/h" \
            -dCALMIRA_PORTABLE_LOADS -dZ7_CRC_NUM_TABLES=1 -fo="$build/obj/$name.obj" \
            -fr="$build/obj/$name.err" "$@" "$source"
    else
        "$cc" $sanitizer_flags -O1 -g -Wall -Wextra -Werror -DCALMIRA_PORTABLE_LOADS -DZ7_CRC_NUM_TABLES=1 \
            "$@" -c "$source" -o "$build/obj/$name.obj"
    fi
}
compile_cpp archive_list "$root/src/dos/archive/archive_list.cpp"
compile_cpp archive_memory "$root/src/dos/archive/archive_memory.cpp"
compile_c archive_index "$root/src/portable/archive_index.c"
for unit in Common/MyString Common/StringToInt Common/IntToString Common/UTFConvert \
    Common/MyWindows Common/StringConvert Windows/PropVariant 7zip/Common/StreamUtils \
    7zip/Archive/Zip/ZipIn 7zip/Archive/Zip/ZipItem 7zip/Archive/Common/ItemNameUtils; do
    compile_cpp "${unit##*/}" "$src/CPP/$unit.cpp"
done
if [ "$mode" = dos ]; then
    compile_c Alloc "$src/C/Alloc.c" -dCALMIRA_BOUNDED_ALLOC -dmalloc=arc_mem_alloc -dfree=arc_mem_free -drealloc=arc_mem_realloc
else
    compile_c Alloc "$src/C/Alloc.c" -DCALMIRA_BOUNDED_ALLOC -Dmalloc=arc_mem_alloc -Dfree=arc_mem_free -Drealloc=arc_mem_realloc
fi
compile_c 7zCrc "$src/C/7zCrc.c"
if [ "$mode" = dos ]; then
    # Link explicit validated object names, not directory globs/stale objects.
    set --
    for name in archive_list archive_memory archive_index MyString StringToInt IntToString \
        UTFConvert MyWindows StringConvert PropVariant StreamUtils ZipIn ZipItem ItemNameUtils Alloc 7zCrc; do
        set -- "$@" file "$build/obj/$name.obj"
    done
    "${JWLINK:-$root/build/toolchains/bin/jwlink}" option quiet format os2 le \
        option osname='DOS/4G' option stub="$watcom/binw/dos32a.exe" \
        name "$build/OLFNLIST.EXE" "$@" libpath "$watcom/lib386/dos" \
        libpath "$watcom/lib386" option stack=64k option map="$build/OLFNLIST.map"
else
    set --
    for name in archive_list archive_memory archive_index MyString StringToInt IntToString \
        UTFConvert MyWindows StringConvert PropVariant StreamUtils ZipIn ZipItem ItemNameUtils Alloc 7zCrc; do
        set -- "$@" "$build/obj/$name.obj"
    done
    "$cpp" $sanitizer_flags "$@" -o "$build/clarclst"
fi
# Native reference artifacts carry their upstream notices even before package
# integration. No RAR code, compression engine or extraction API is linked.
cp "$root/vendor/reference/7zip/DOC/License.txt" "$build/7ZIP-LICENSE.txt"
cp "$root/vendor/reference/7zip/DOC/copying.txt" "$build/7ZIP-LGPL.txt"
cp "$root/vendor/reference/open-watcom-v2/contrib/extender/dos32a/license.txt" "$build/DOS32A-LICENSE.txt"
cp "$root/docs/licenses/gpl-3.0.txt" "$build/GPL-3.0.txt"
cp "$root/docs/archive_viewer.md" "$build/ARCHIVE_VIEWER.md"
