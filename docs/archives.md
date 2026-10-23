# Multi-format Archive Reader

The selected upstream is the official [7-Zip source](https://github.com/ip7z/7zip),
stored as submodule `vendor/reference/7zip`, pinned to tag **26.04**, commit
`9128b80e3a471108678e2b3ec3c985861c8d7b0f`. Updates must change the pin explicitly;
do not build from a floating branch.

```sh
git submodule update --init vendor/reference/7zip
```

The first goal is read-only archive listing/preview for the file dialog, not
an automatic extractor. Target ZIP first, then additional 7-Zip-supported
formats through the same backend interface. Keep format code separate from
Win16 windows and make the eventual C ABI callable from Pascal. Do not add a
modern Windows-only `7z.exe` dependency to the installer.

## Porting Evidence

`make archive-host-test` now builds the full pinned `7zz` host reference into
`build/tools/7zip-reference/`, outside the source submodule, with upstream's
single-thread configuration and RAR handlers/codecs disabled. It runs eight
controlled-fixture acceptance tests: stored ZIP, Deflate ZIP with UTF-8 names,
listing traversal names without extraction, TAR, gzip, 7z, corrupt input and
encrypted headers with a noninteractive wrong-password failure. Listing must
leave inputs and the directory tree unchanged. These are listing tests, not
decompression-integrity, resource-exhaustion or Win16 UI acceptance tests.

The tested Gentoo configuration is Clang 22.1.8, automatically selected from
`/usr/lib/llvm/22/bin/` when installed. Otherwise the build uses PATH's Clang.
Override `SEVENZIP_HOST_CC` and `SEVENZIP_HOST_CXX` for another toolchain, and
use a separate `BUILD_DIR` when switching compilers. Unmodified GCC 16.2.1
fails upstream's array-bounds warning-as-error in `HandlerCont.cpp`; Clang 23
fails its new lifetime-annotation suggestion in `FileFind.cpp`. Neither warning
has been disabled. Clang 22 builds with upstream warning/error settings intact.

This executable is a **host reference only**, not a shipped DOS helper or a
Win16 dependency. No CLI technical-listing output is treated as a safe GUI
protocol: untrusted filenames can contain delimiters/newlines. The native
backend uses length-delimited binary records, never `7zz -slt` text.

Initial decoder-only experiments with `/opt/watcom` established:

- A direct 16-bit `LzmaDec.c` compile silently chooses 16-bit `UInt32` unless
  `Z7_DECL_Int32_AS_long` is defined. The uncorrected object is invalid.
- With that type switch and warnings-as-errors, Win16 compilation still
  rejects the large dictionary masks in `LzmaDec.c` (SizeT is 16-bit). Do not
  suppress these warnings or ship the resulting decoder without size guards.
- The unmodified LZMA decoder compiles warning-free as a 32-bit DOS object
  using `wcc386 -bt=dos -mf -3r -dZ7_LZMA_SIZE_OPT -w4 -we`. This is a compile
  check only, **not** a linked DOS backend or a Win3.1 compatibility test.

Those initial logs/objects are under ignored `build/tests/7zip-watcom/`.
The SDK's ANSI-C 7z/LZMA code is not a ZIP/multi-format reader by itself.

## Native ZIP Implementation

`make archive-dos` now compiles the actual upstream C++ ZIP handler with
OpenWatcom and JWlink, bound to DOS/32A. Compatibility patches are applied to
build-directory copies, not the pinned checkout. Byte-wise upstream integer
loads avoid unaligned-pointer undefined behavior; no warning is suppressed.
`make archive-reader-host-test` checks this same backend on the host, including
malformed archives, invalid UTF-8, memory/entry/name limits and foreign outputs.
ASan/UBSan builds are supported by `tools/build_archive_reader.sh`.

`make archive-viewer clfn-hook` builds the Win16 list window and menu integration.
The helper emits a bounded `CLARCI1` index with explicit lengths, 64-bit sizes,
flags, CRC and end marker. The viewer validates the entire index before use,
escapes ambiguous names and never extracts or executes entries.
Limits: 64 MiB source, 128 entries, 240-byte names, 8 MiB parser allocations,
16 MiB cumulative reads and cooperative time checks. No hard I/O timeout.

Native tests pass standalone on DOS 7.1 and through the common-dialog menu on
enhanced Windows 3.1x with DOS 6.22. Input ZIPs remain byte-identical and normal
completion removes private temporary files. DOS 7.x Windows helper startup is
blocked after the tested profile faulted; the guard itself is tested.
The actual installed Word/Excel ZIP menu flow also has a private-media native
acceptance runner, `make archive-office-runtime-test`; it is distinct from
the independently written SDM fixtures. See [Office test details](office_dialog_tests.md).
Native 7z/TAR/gzip and extraction remain open. `make archive-package` stages
the standalone GDI add-on; the main descriptor has an off-by-default component.
See [viewer instructions and compatibility limits](archive_viewer.md) and
[test commands](../tests/readme.md).

## Safety and Notices

Cap header/dictionary memory, entry count, decompressed preview bytes and
processing time. Read-only viewing must not execute entries. Future extraction
must reject absolute/drive/UNC paths, traversal, links and destination escapes;
never overwrite files automatically.

Retain the upstream notices in `DOC/License.txt` and per-file headers. The full
source has LGPL, BSD, public-domain and RAR-specific notices; it is not all
covered by the SDK's public-domain status. RAR is outside the first porting
scope. The viewer build includes upstream notices and its GPL-3.0 text; the
installer packages retain these notices under DOS-safe `LICENSES` filenames.
Installing the payload never enables the global hook automatically.
