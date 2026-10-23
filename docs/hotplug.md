# Removable-Media Integration

Calmira already centralizes drive discovery in `vcl/drives.pas` and uses one
global timer in `src/compsys.pas`. Today it detects added/removed drive letters
only when the Computer window is restored; persistent empty removable slots are
not enough to signal a media change.

## Proposed Design

1. Add a drive snapshot containing drive type, readiness and a stable media
   signature. Poll it from the existing global timer, with critical-error
   dialogs suppressed.
2. Route every detected change through one refresh operation: rebuild Computer,
   Explorer trees and path combos; close or mark windows whose media vanished.
3. Treat EUSBASPI `/H` slots as persistent letters. EUSBASPI already polls root
   ports and reports `UNIT ATTENTION / MEDIUM MAY HAVE CHANGED`; expose a small
   monotonic change counter through its existing DOS/VxD boundary if filesystem
   probing is unreliable.
4. Distinguish USB device hotplug from removable-media change. EUSBASPI supports
   actual device insertion/removal; AHCIASPI currently supplies ZIP/LS-120/CD
   devices, where media insertion/ejection is the primary event.
5. Initially launch `USBSYNC.EXE` for “Safely remove USB drive.” Later expose a
   focused API if per-drive eject is needed.

Tests must cover empty-to-present, present-to-empty, replacement in the same
letter, open Explorer windows, active copy operations, DOSLFN enabled/disabled,
and WfW 3.11 with 32-bit file access.

## WinFile Reference Implementation

`vendor/reference/microsoft-winfile` is a submodule of the GeosOne fork on
branch `calmira-hotplug`. Commit `8bfcd03` handles `WM_DEVICECHANGE` volume
arrival/removal and coalesces duplicate broadcasts into WinFile's established
refresh command. That code is Win32-only, but its single-refresh behavior is
the model for Calmira's timer/ASPI adapter.

Microsoft's released tree comes from NT4, while the WinFile copy in osFree's
WIN16 repository still targets Win32/NT 3.51. The active strategy is now to
port Microsoft's existing C modules to native Win16, retaining its file
manager rather than replacing it with a newly written demo. First core modules
run under WfW 3.11; the complete application and hotplug integration are still
unfinished. See [WinFile port status](winfile16.md).

