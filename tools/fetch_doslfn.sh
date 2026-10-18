#!/bin/sh
set -eu

version=0.42a
archive_sha256=7e630d35db1d9ff41ef6407e0829c52330e5058e951fa53208a7a1d8379bbeeb
url="https://github.com/adoxa/doslfn/releases/download/v${version}/doslfn.zip"

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
download_dir="$root/build/downloads"
archive="$download_dir/doslfn-${version}.zip"
output=${1:-"$root/build/dos/doslfn"}

command -v sha256sum >/dev/null 2>&1 || {
    echo "sha256sum is required" >&2
    exit 1
}
command -v unzip >/dev/null 2>&1 || {
    echo "unzip is required" >&2
    exit 1
}

mkdir -p "$download_dir" "$output/NLS"

if [ ! -f "$archive" ] ||
   ! printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum -c - >/dev/null 2>&1; then
    part="$archive.part"
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$part" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$part" "$url"
    else
        echo "curl or wget is required" >&2
        exit 1
    fi
    printf '%s  %s\n' "$archive_sha256" "$part" | sha256sum -c -
    mv "$part" "$archive"
fi

printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum -c -
unzip -oq "$archive" -d "$output" \
    doslfn.com doslfnms.com doslfn.txt lfnxlat.386 fmlfn.drv \
    'cp*uni.tbl' c1258uni.tbl 'NLS/*'

test -s "$output/doslfn.com"
test -s "$output/doslfnms.com"
test -s "$output/lfnxlat.386"
printf 'DOSLFN v%s staged in %s\n' "$version" "$output"
