# Microsoft WinFile Win16 Port

The implementation base is the MIT-licensed Microsoft C source in
`vendor/reference/microsoft-winfile`, not a new Pascal file manager.
The GeosOne fork's `win16/` directory contains the OpenWatcom build, platform
adapter and native acceptance tests. Existing source algorithms are compiled
directly; they are not reimplemented in the test program.

## What WIN31 Means Here

`src/winfile.h` defines `WIN31`, but the current tree contains no conditional
`#ifdef WIN31` implementation. The same header also enables NTFS and includes
Win32 networking/common-control headers. The source still uses Win32 Unicode,
threads and filesystem APIs. Defining WIN31 alone cannot select a Win16 build.

The [Microsoft original_plus tag](https://github.com/microsoft/winfile/tree/original_plus)
is an NT4 source release, not the Win3.1 source. The
[osFree fork README](https://github.com/osfree-project/WIN16/blob/master/applications/winfile/README.md)
also identifies NT3.51 as its working target. These trees remain useful source
material, but neither removes the need for platform adaptation.

## Working Original Modules

| Original source | Win16 adaptation |
| --- | --- |
| `src/lfnmisc.c` | Original path canonicalization and wildcard rename-mask algorithms, ANSI platform types |
| `src/wfmem.c`, `src/wfmem.h` | Original linked directory blocks, far byte pointers and global-memory allocator |
| `src/numfmt.c` | Original 64-bit size formatting with native Win16 resource strings |

The memory port preserves linked blocks, allowing directory data beyond a
single 64-KiB segment. It rejects oversized records before 16-bit arithmetic
can wrap or a fixed block can overflow, and returns NULL at the end of
iteration. Long names use ANSI characters; this does not yet implement DOSLFN
enumeration or file operations.

```sh
WATCOM=/opt/watcom make winfile16-core
WIN311_IMAGE=/path/to/prepared/win311.img make winfile16-core-runtime-test
```

`build/winfile-port/WINFILE.LIB` contains the ported Microsoft modules.
`WFCORE.EXE` is a test runner, not a file manager. Native WfW 3.11 tests check
canonicalization, rename masks, output boundaries, a 1,500-entry directory
across far segments, clone lifetime, oversized-record rejection and sizes
above 4 GiB. The raw image is copied before testing and is never committed.

## Full Application Still Incomplete

`make winfile16` now attempts to compile the original application; it does
not fall back to the drive demo. It currently fails in the original Win32
networking/header layer (`mpr.h` requires `lmcons.h` and Win32 types).
Remaining work includes the ANSI/Win16 application headers, DOS/DOSLFN file
adapters, cooperative replacements for threaded workers, original MDI tree
and directory windows, dialog/resources and file-operation integration.
Unsupported NT features must not become silent success stubs.

After that, integrate DOS/ASPI media-change polling and safe eject. Preserve
the existing WinFile commands and UI flow, and keep driver internals behind
DOS/VxD APIs. A full Win3.1 file-operation acceptance suite is required before
shipping a replacement `WINFILE.EXE`.

## Separate Diagnostic Probe

The former Pascal demo is now `src/win16/drive_probe.pas`. `make drive-probe`
creates `build/drive-probe/DRVPROBE.EXE`; `make pack-drive-probe` creates an
optional compressed test copy. Its class and translated title identify it as
a drive probe. It is not installed, is not used by the C port and must never
be distributed as a working WinFile replacement. Older generated
`build/winfile16/WINFILE.EXE` files are obsolete development artifacts.
