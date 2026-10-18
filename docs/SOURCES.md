# Imported Sources

All upstream trees are kept separate so later merges remain auditable. ZIP
archives were tested with `unzip -t`; no path traversal entries were found.

| Tree | Origin | Role |
|---|---|---|
| `calmira-1.0`, `2.0`, `2.2` | calmira.de | Early source releases |
| `calmira-3.02`, `3.1b3`, `3.2`, `3.3` | OS/2 Site and calmira.de | Standard lineage |
| `calmira-lfn-3.3` | Wayback copy of `callfnsrc.zip` | LFN 3.32 source |
| `calmira-reborn` | gitlab.com/huntertur/calmira | Selected baseline, commit `9cadc358` |
| `calmira-lfn-de`, `de-3.3`, `fr-3.3` | surviving mirrors | Localization/reference |
| `calmira-xp-3.33` | Abandoned Zone mirror | Optional UI features |
| `calmira-mark-lfn-binary` | gaby.de | Binary/readme feature reference; source unavailable |
| `microsoft-winfile` | github.com/geosone/winfile | Submodule fork with removable-drive refresh, branch `calmira-hotplug`, commit `8bfcd03` |
| `doslfn` | github.com/adoxa/doslfn | DOS LFN driver/API reference, commit `7fd985de` |
| `freepascal` | gitlab.com/freepascal.org/fpc/source | Win16/i8086 compiler and RTL, commit `25d18a56` |
| `open-watcom-v2` | github.com/open-watcom/open-watcom-v2 | 16-bit C/OMF toolchain, commit `ddf97390` |
| `jwasm` | github.com/JWasm/JWasm | MASM-compatible OMF assembler, commit `a5c4ea03` |
| `jwlink` | github.com/JWasm/JWlink | Alternative OMF linker, commit `06131990` |
| `geosone-jwasm` | github.com/geosone/JWasm | Pinned build dependency with MASM 5.1 patches, commit `e9462f1e` |
| `geosone-jwlink` | github.com/geosone/jwlink | Pinned build dependency with MS LINK/VxD/GCC patches, commit `c3f7e937` |

The original archives are in `archives/original/`. Their SHA-256 values are in
`archives/original/SHA256SUMS`. Reborn's Git history is retained in its cloned
tree. Microsoft WinFile is not a Windows 3.1 Win16 source release; the GeosOne
fork is kept for algorithms and UI behavior that can be reimplemented cleanly.
The two GeosOne build dependencies are plain, tracked source snapshots (not
submodules), so they are included when this repository is pushed or cloned.

Calmira/Reborn is GPL-2.0-or-later. Microsoft WinFile is MIT. DOSLFN describes
itself as freeware with sources, so treat it as an external dependency until
redistribution terms are confirmed. The sibling EUSBASPI, AHCIASPI and GDI
projects are GPL-3.0. Prefer process/API boundaries for driver integration;
copied GPL-3.0 code would change the combined work's licensing obligations.

