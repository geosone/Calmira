# Calmira DOS LFN Provider

This directory is the integration point for a redistributable DOS long-file-
name provider. The complete reference implementation is pinned at
`vendor/reference/doslfn` from the `geosone/doslfn` fork. It implements the
Windows 9x-compatible `INT 21h/AX=71xx` API, FAT12/16/32 directory access,
code-page conversion, and the `LFNXLAT.386` protected-mode bridge needed by
Windows 3.1.

Do not ship a renamed or partly functional TSR. Until the provider passes the
host matrix in `docs/LFN_HOSTS.md`, Calmira must choose either an already active
71xx provider or the `DESCRIPT.ION` virtual-LFN fallback.

`lfnprobe.c` is the first independently buildable component. It reports whether
the selected drive exposes the 71xx API and whether the filesystem is FAT32.
GDI packages can use its exit code through `[Detect]`:

```ini
[Detect]
LFN=LFNPROBE.EXE /Q /LFN C:\
FAT32=LFNPROBE.EXE /Q /FAT32 C:\
DOS71=LFNPROBE.EXE /Q /DOS71
```

Build it with `make lfn-probe`. OpenWatcom compiles the 16-bit C source and the
vendored patched JWlink links `build/dos/lfn/LFNPROBE.EXE`.
