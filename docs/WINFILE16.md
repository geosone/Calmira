# WinFile 3.1 Replacement

`src/win16/winfile16.pas` is the new native Win16 `WINFILE.EXE`. It is built
with Free Pascal's `i8086-win16` target and the pinned GeosOne JWlink. The
Microsoft WinFile submodule supplies MIT-licensed behavior and algorithms, but
its NT4/Win32 API layer is not copied into the Windows 3.1 executable.

## Current Milestone

The initial executable creates a normal Windows 3.x main window, enumerates
drive letters through the Win16 `GetDriveType` API, and refreshes the drive list
manually or when its polling snapshot changes. Polling is intentional: Windows
3.1 has no Win32 `WM_DEVICECHANGE`, while EUSBASPI and AHCIASPI expose devices
through DOS drive letters.

Build it on Gentoo with:

```sh
WATCOM=/opt/watcom make winfile16
```

The result is `build/winfile16/WINFILE.EXE`.

## Porting Order

1. Add directory and file panes using small Win16 platform adapters.
2. Reuse the portable media-change state machine for insert, remove, and
   same-letter media replacement; add an optional ASPI change counter.
3. Port copy, move, rename, delete, and search behavior with deterministic
   tests outside the GUI.
4. Add DOSLFN/Calmira LFN calls behind one filesystem interface, retaining
   short-name fallback.
5. Integrate icons, associations, drag/drop, safe eject, and Calmira shell
   services, then package through the generic GeosOne DOS Installer.

Keep drivers and the file manager separated by documented DOS/VxD APIs. The
GUI must never depend directly on EUSBASPI or AHCIASPI internal structures.
