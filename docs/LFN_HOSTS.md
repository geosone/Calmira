# DOS, FAT32, and Long Filename Support

FAT32 and long filenames are related but independent. VFAT long-name directory
entries also work on FAT12 and FAT16; FAT32 is needed for large volumes, not for
LFN itself. Calmira consumes the DOS `INT 21h/AX=71xx` API through
`LFNFUNCS.DLL`, so a compatible provider must be resident before Windows starts.

## Supported Host Profiles

| Host | Filesystem | LFN provider | Windows 3.1 requirements |
|---|---|---|---|
| MS-DOS 7.10 | FAT16/FAT32 | DOSLFNMS candidate | Apply the checked WIN386 patch only on FAT32; disable 32-bit file access. |
| FreeDOS | FAT16/FAT32 | full DOSLFN candidate | Use a kernel build verified for Windows 3.x Enhanced Mode; test each kernel release. |
| SvarDOS/EDR-DOS | FAT12/FAT16 initially | full DOSLFN candidate | Treat Windows compatibility and FAT32 support as separate capabilities. |
| MS-DOS 5/6 or DR-DOS 7 | FAT12/FAT16 | full DOSLFN candidate | No FAT32 patch. |

The current DOSLFN source says it targets DOS 4+ on a 386+, has been checked on
MS-DOS 7.10 FAT32, and may work on FreeDOS. It also documents that Windows 3.11
32-bit file access forces fallback mode because of VCACHE.386; 32-bit disk
access may remain enabled. These constraints must become automated boot tests,
not assumptions.

## Driver Work

Use `vendor/reference/doslfn` as the behavioral reference for the `71xx` API,
Unicode/code-page conversion, FAT12/16/32 directory entries, removable-media
cache invalidation, and the Windows 3.x translation VxD. Before distributing a
derived binary, record explicit license terms; the GitHub tree currently has no
machine-readable license file.

The implementation should expose a small installation contract:

- `LFNPROBE.EXE` reports DOS identity/version, FAT type and active LFN API; CPU
  and Windows Enhanced-Mode probes remain to be added;
- the TSR refuses to stack over another `71xx` provider;
- removable-drive caches expire on media change and never survive hot removal;
- `LFNXLAT.386` translates protected-mode calls without requiring Win32s;
- unloading is optional; a reboot is the reliable rollback boundary.

The test matrix must boot each host in QEMU, create/rename/enumerate Unicode and
8.3-collision cases on every supported FAT type, run Calmira under Windows 3.1,
and repeat the operations after USB/ZIP media replacement.
