# Virtual Long Filenames for Windows 3.1

Instant File Access demonstrated a useful fallback: keep real files under DOS
8.3 names and store their display names in `DESCRIPT.ION`. This works without
VFAT and therefore does not require FAT32. It is not a replacement for a real
filesystem LFN API: unaware DOS programs continue to see the aliases.

Calmira already has mature `DESCRIPT.ION` support in `SRC/FOURDOS.PAS`.
`src/portable/virtual_lfn.pas` now supplies the independent mapping core:

- validate real DOS 8.3 names and reject reserved devices such as `CON`;
- derive deterministic `NAME~1.EXT` aliases, with a caller-selected collision
  number;
- parse and emit `ALIAS.EXT Long Display Name.ext` lines;
- preserve 4DOS data following the Ctrl-D metadata separator.

## Win16 Integration

The planned GPL component `CLFNHOOK.DLL` installs a shared Win16 hook and
subclasses Windows 3.1 common Open/Save dialogs. Lists show mapped long names,
while the application receives the real alias. A Save operation allocates an
unused alias and updates `DESCRIPT.ION` through a locked temporary file. Calmira
uses the same service for rename, copy, move, delete, recycle-bin restore, and
removable-media refresh, avoiding two competing mapping implementations.

Private application dialogs cannot be made compatible reliably and remain an
explicit limitation. Unaware tools may rename or delete an alias without
updating the mapping; the service therefore prunes missing aliases, preserves
unknown description lines, and never deletes a real file during repair.

## Provider Selection

1. Prefer a working native `INT 21h/AX=71xx` provider (Win9x or DOSLFN).
2. Otherwise offer virtual LFN mode on any writable FAT12/16/32 volume.
3. Fall back to plain 8.3 on read-only media or when mapping updates fail.

Tests cover alias collisions, reserved names, Ctrl-D metadata, concurrent map
updates, copy/move consistency, hot removal, and display-name-to-alias round
trips through a real Windows 3.1 common dialog.
