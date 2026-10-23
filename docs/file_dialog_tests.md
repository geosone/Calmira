# Win16 File Dialog Acceptance

The required behavior is system-wide interception of ordinary Windows 3.1
Open/Save dialogs in unmodified applications. `VCLOPDLG.PAS` alone does not
provide that: applications must explicitly use that component.

`make clfn-hook` builds an experimental `OLFNHOOK.DLL`. It is not installed
or started automatically. The prototype displays existing `DESCRIPT.ION`
names over the native file list while retaining DOS aliases for callers.
It also allocates new aliases with recoverable metadata transactions. It does
not enumerate native DOSLFN names or replace private application dialogs.
See [Save lifecycle and limits](lfn_save_transactions.md).

## Native test status

Run the separate COMMDLG client with a disposable, legally supplied WfW image:

```sh
WIN311_IMAGE=/path/to/win311.img make clfn-hook-runtime-test
```

The native acceptance test now passes. A separate ordinary COMMDLG client
sees mapped names with the global hook installed; Open and existing-alias
Save return the real DOS path, Cancel retains its native semantics, existing
application hooks survive and file-list tab order is retained. After stopping
the hook, the same client sees ordinary aliases again. File contents and the
existing description bytes are compared against the expected appended map
after the VM exits; unrelated document files remain byte-identical.
An OEM-encoded description containing German umlauts is also checked against
the expected Windows ANSI display text. Latest full passing artifacts:
`build/tests/clfnhook.pkmASZ/`.
The client explicitly focuses the list before selecting: forwarding only
selection/double-click events is insufficient. Native focus notifications
must also reach COMMDLG and the existing application hook.

New-file tests verify that the application receives `NEWANN~2.TXT` when
`NEWANN~1.TXT` already exists; no mapping or placeholder document exists
before the application writes. Both ASCII and umlaut names commit after
creation. Typed existing long names work even outside the current extension
filter. Cancel and FILEOK veto remove reservations. An accepted-but-never-
created file gains no mapping; task exit cleans its journal. Unloading while
that save is pending is refused. All three native test logs report PASS.

The earlier client failure was addressed by explicit callback data-segment
loading, disabling callback stack checks and providing the usual 1-KiB Win16
local heap. Native instance and module handles are not interchangeable: the
hook now verifies their canonical module paths instead of numeric equality.
`HOOK_CLIENT_ONLY=1` runs the four baseline dialogs without installing our hook.
Optionally set `WIN16_DRWATSON=/path/to/DRWATSON.EXE` for diagnostics.

The locally supplied German ClarisWorks 1.0 ISO contains its actual installer
under `CLAWORKS/DISK1`, with sibling `DISK2`. Its installer ran and copied
application files in an isolated image; setup completion hit a missing DOS
help file and a DSHELL error. ClarisWorks subsequently launched successfully;
its native Open and Save dialogs were displayed, including the Open dialog's
additional "Import-Optionen" selector. Screenshots are retained in
`build/tests/claris-media/open.png` and `save.png`; no test document was saved.
Media and Windows
binaries remain under ignored `build/tests/` and must not be committed.

Acceptance must cover Open, Save, Cancel, directory changes, existing
application hooks, unchanged file contents/metadata, and restoring native
dialogs after unhooking. Repeat with ClarisWorks and WinWord; custom dialogs
require separate investigation.

## Manual Test with Our Hook

`make clfn-hook` also builds `OLFNLOAD.EXE`, an explicit resident loader.
Keep it beside `OLFNHOOK.DLL` on a disposable Windows installation. Run it
from Program Manager, optionally passing an application command:

```text
C:\OLFNLOAD.EXE C:\CLWORKS\CLWORKS.EXE
```

Its window stays resident; **Stop hook and exit** removes the hook. If another
subclass still references it, close that application's file dialog and retry.
Pending saves also prevent unloading: keep the loader running until the
application finishes saving, or close the application if it never creates
the file. Recovery limits are documented in `LFN_SAVE_TRANSACTIONS.md`.
Nothing is added to Windows startup or the Calmira installer automatically.

On an image without IFA, ClarisWorks displayed our mapped long name, opened
the selected document by double-click and showed `CALMIR~1.CWK` in its title.
Navigating into the mapped directory refreshed the list. Import Options
remained present, and Save As displayed the same mapped name. Save As was
cancelled; both the document and map remained byte-identical. Screenshots:
`build/tests/clfn-claris.iDXcjI/{open,opened,save,loader}.png`.
The updated build was retested with tab-order/horizontal scrolling and full
list-focus notification forwarding; see `focus-open.png`, `focus-save.png`
and `loader-current.png` in the same directory. Document and metadata were
again byte-identical after opening and cancelling Save As.
The independently implemented Office adapter now also has native Word/Excel
tests; see [Office dialog evidence and limits](office_dialog_tests.md).

## Manual New-file Save with ClarisWorks

Without IFA, ClarisWorks saved `calmira neu langer name.cwk` in `C:\CLWORKS`
as `CALMIR~2.CWK` because the previous alias already existed. After closing
the document, the long name appeared in Open and typing it reopened the
same document. The resulting map contained both the unchanged old entry and
the new entry; no transaction sidecars remained after the loader stopped.
Artifacts: `build/tests/clfn-save-claris.KMIgzd/`, including `saved-new.png`,
`reopen-list.png`, `reopened.png` and `AFTER.ION`. An earlier navigation attempt
also created a test `C:\CLWORKS.CWK` in this disposable image; it is not part
of the long-name transaction or a redistributed application fixture.

## IFA reference comparison

IFA 4.00 was installed and registered using its supplied freeware information
in a separate copy of the ClarisWorks test image. Its modified Open and Save
dialogs worked in ClarisWorks. A long-name Save, document close and subsequent
Open succeeded; disk inspection confirmed the DOS alias and `DESCRIPT.ION`
mapping. See [virtual LFN observations](VIRTUAL_LFN.md#ifa-400-behavioral-reference).
This is a manual reference-program test, not a passing test of OLFNHOOK.DLL.
