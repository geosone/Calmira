# OpenLFN Experimental ZIP Viewer

Build with `make archive-viewer clfn-hook`. The native files are under
`build/win16/archive/`; put `OLFNVIEW.EXE` and `OLFNLIST.EXE` beside
`OLFNHOOK.DLL` and the explicit `OLFNLOAD.EXE` loader. Retain the supplied
license/readme files. The hook is never enabled automatically.

## GDI Installation

`make openlfn-package GDI=../gdi` stages the independent OpenLFN Loader add-on in
`build/openlfn-package/`, using the existing GDI `build/INSTALL.EXE`.
Run that package's installer and choose a dedicated directory (default
`C:\OPENLFN`). Start the installed `OLFNLOAD.EXE` explicitly in Windows.
No Windows files, shell settings or automatic startup entries are changed.
Stop the hook after saves finish and close all viewers before running the
installed `INSTALL.EXE /U`. Do not update or uninstall loaded executables.
`ARCINFO.TXT` describes Save recovery precautions and compatibility limits.

The main Calmira descriptor also offers the component as option 5, off by
default. Its full package still requires the unfinished shell build.
Both packages retain separate GPL, 7-Zip, LGPL and DOS/32A notice files under
`LICENSES`, with DOS 8.3 filenames. No DLL is UPX-packed; these initial viewer
and helper copies are also uncompressed.

## Opening a ZIP

With the hook running, select an existing ZIP filename in a standard Open/Save
dialog or a verified Office dialog. Open the dialog's system menu (Alt+Space)
and choose **View ZIP contents (read-only)**. This starts a separate viewer;
it does not accept the application's file dialog. Alternatively run
`OLFNVIEW.EXE C:\TEST.ZIP`, or run it without arguments to choose a ZIP.
An unreadable/missing ZIP now shows an explicit error and leaves the original
filename edit unchanged. Fix the selection and invoke the menu again.

The initial native implementation lists **ZIP only**, using the pinned
7-Zip ZIP reader. It does not extract, execute, edit or check member-data CRCs.
Stored/Deflate tests establish listing, not decompression. UTF-8 names and
validated Unicode extra fields are preserved; non-ASCII/control characters
are displayed as explicit `\uXXXX` / `\xNN` escapes. Paths such as `../x` are
displayed, never followed. Directory/encryption flags and uncompressed sizes
are shown. Unknown legacy name encodings remain byte escapes.

## Supported Test Profile and Limits

The passing native GUI results below predate the switch to TCG. The installed
QEMU 10.2.3 TCG has a confirmed large-ENTER-frame emulation error, reproduced
without Windows; current TCG helper tests are not passing acceptance on either
DOS baseline. See [emulator diagnosis](qemu_tcg_diagnosis.md). Do not attribute
these new failures solely to DOS 7.1 or treat the old KVM runs as TCG coverage.

- Standalone `OLFNLIST.EXE INPUT.ZIP NEW.IDX` passes under DOS 7.1.
- The Win16 bridge passes under enhanced Windows 3.1x on DOS 6.22, with a 386+
  and a working DOS/DPMI session. It needs a writable ASCII DOS temp path.
- The ZIP menu flow has also been exercised in actual Word and Excel from
  the locally supplied German Office installation, not only SDM-shaped
  fixtures. See [Office acceptance](office_dialog_tests.md) for the exact scope.
- Windows on DOS 7.x has no verified production ZIP bridge in these tests.
  The viewer refuses that profile **before** launching the helper. This is
  not a claim that every patched DOS 7.x/Windows installation is incompatible.
  Diagnosis now isolates the ZIP fault to DOS 7.1 plus the older VSHARE driver;
  the direct helper succeeds with the privately supplied Office VSHARE update.
  The production guard remains until wider acceptance; the separate 16-bit
  startup issue did not reproduce in the unchanged-image TCG control.
  See [controlled experiments](dos71_diagnosis.md).
- At most 128 entries, 240 name bytes, 64 MiB input, 16 MiB cumulative parser
  reads and 8 MiB accounted parser allocations. CRT/extender overhead is extra.
  Progress/read checks enforce a cooperative 15-second budget, not a hard
  timeout for stalled filesystem/device IO. Split/SFX/damaged archives fail.
- Existing output is never overwritten. The GUI uses its own reserved temp
  directory and removes it after normal completion. On a helper timeout,
  private files are retained rather than deleting a running task's files.

These bounds intentionally reject some otherwise valid ZIPs. There is no
7z/TAR/gzip native viewer yet; those formats currently have host-reference
tests only. Automatic crash recovery and automatic hook startup remain open.

## Notices

The new viewer/bridge/protocol sources are GPL-3.0-or-later, separately from the
historical repository license. 7-Zip Copyright (C) 1999-2026 Igor Pavlov; its
selected modules retain their upstream LGPL-2.1-or-later/public-domain notices.
The pinned sources and separate port patch are retained for rebuilding.

This product uses DOS/32 Advanced DOS Extender technology.

See `7ZIP-LICENSE.txt`, `7ZIP-LGPL.txt`, `DOS32A-LICENSE.txt` and
`GPL-3.0.txt` in the build output; the OpenWatcom runtime's own distribution
terms also apply. These experimental files are not a finished Calmira release.
