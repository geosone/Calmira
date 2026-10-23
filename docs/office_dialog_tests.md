# Office Private File Dialogs

## Independently Observed Interface

The locally supplied `Microsoft Office 4.3c Professional [German] (ISO).7z`
contains an ISO whose root installer identifies itself as **Office 4.2c**.
The minimal Word/Excel/PowerPoint installation completed in a disposable image.
No Office binaries, keys, IFA database or decompiled proprietary code are part
of this implementation.

| Application | Dialog class | Filename edit | File/directory scrollbars |
| --- | --- | --- | --- |
| Word | `bosa_sdm_Microsoft Word 6.0` | `OpusFedt`, ID 1818 | 1819 / 1283 |
| Excel | `bosa_sdm_XL` | `EDTBX`, ID 4864 | 4865 / 4866 |

These IDs/classes were recorded from the actual applications with
`make window-inventory`. Run `WININV.EXE C:\MSOFFICE\WINWORD\WINWORD.EXE`
in a private VM; it periodically replaces `C:\WINTREE.LOG`. It records visible
captions, paths and edit contents, so keep logs private under ignored `build/`.
Unlike `GetWindowText`, an explicit `WM_GETTEXT` reads the private filename
edit correctly across tasks. File lists and buttons are painted by SDM, not
ordinary LISTBOX/Button child windows. Word also reads the edit while typing.

## Current Adapter

`OLFNLOAD.EXE` enables both standard COMMDLG and verified Office dialogs.
Recognition requires the application filename, dialog class, filename edit
class/ID and both scrollbar IDs, not localized captions. Other SDM dialogs
remain untouched.

A separate **Calmira: mapped long names** list displays up to 512 mapped,
readable files in the current directory, independently of Office's type filter.
A click transfers the DOS alias; a double-click accepts it through Office's
normal Enter processing. The dialog system menu can reopen a hidden list.
Office's original directory navigation, format options and validation remain
available.

For a new long name, type a leaf name **with extension**, then press **Enter
while the filename edit has focus**. Mouse-clicking Office's virtual OK button
does not yet convert a newly typed long name. Reading an edit alone never
reserves or changes metadata. A native validation veto restores the typed name
and cancels the reservation when the original dialog remains visible.

## Native Acceptance and Limits

Manual tests passed under **DOS 6.22 with SHARE**, using the prepared Windows
3.1x installation:

- Word: existing mapped name Open, new-name Save, close, typed-name reopen
  with document text preserved, and companion-list double-click Open.
- Excel: new-name Save including its subsequent File Info dialog, close and
  typed-name reopen with cell A1 still containing `12345`.
- Escape cancels typed new names without mappings; the original Word fixture
  remains byte-identical. Closing Office then the loader succeeds without
  pending/recovery files.

Office retains file locks during editing. The conservative transaction core
commits DESCRIPT.ION only after it can exclusively open the document, usually
after document close. Keep the loader running. The shared one-pending-save-
per-directory limit and interrupted-save recovery still apply; see
[transaction limits](lfn_save_transactions.md).

The DOS 7.1 test host still makes Word request SHARE: its supplied SHARE rejects
the DOS version, and SETVER removes that rejection but does not make Word
recognize sharing. **Office acceptance on DOS 7.1 is not established.** CD-ROM
driver failures were avoided using a separate FAT16 source disk.

Private manual artifacts: `build/tests/office43/`, including `word-reopened.png`,
`word-panel-open2.png`, `excel-reopened.png`, `unloaded.png`, and the final maps.

## Automated Regression

```sh
WIN311_IMAGE=/path/to/prepared.img make clfn-office-runtime-test
WIN311_IMAGE=/path/to/prepared.img make clfn-hook-runtime-test
```

The first uses independently written SDM-shaped fixtures, not Office binaries.
It checks the private modal Enter path, read-without-reservation, existing/new
names, cancellation, validation veto, mouse cancellation before the veto timer,
rejection of wrong edit classes/missing controls, preserved original bytes,
committed maps and hook teardown for both class/ID sets. Real Office tests above remain
separate; mocks do not establish all Office behavior. Latest passing fixture
artifacts: `build/tests/clfnhook.rvaw8l/`; standard-dialog regression:
`build/tests/clfnhook.pkmASZ/`.

## Actual Office ZIP Preview

```sh
WIN311_IMAGE=/path/to/dos622-installed-office.img make archive-office-runtime-test
```

Unlike the SDM fixtures above, this runner launches the actual installed
`C:\MSOFFICE\WINWORD\WINWORD.EXE` and `C:\MSOFFICE\EXCEL\EXCEL.EXE`
in separate disposable image copies. The image must also contain
`C:\SHARE.EXE`, Windows under `C:\WINDOWS`, and no `C:\ARCDATA` directory.
The startup keystrokes target the locally supplied German Office profile,
including Word's Tips window. Other installations may need different startup
preparation; this is not an all-Office-version compatibility claim.

The driver identifies each actual file dialog by its independently observed
class and control IDs, invokes the hook's ZIP menu command and inspects the
separate viewer. It checks UTF-8/newline escaping, read-only status, the still
open Office dialog and unchanged filename edit, Escape cancellation and clean
hook teardown. A missing ZIP must show an error without launching the viewer
or changing the typed name; a subsequent valid ZIP must still work.
The script compares the original ZIP bytes and rejects newly created
DESCRIPT.ION or Save-transaction sidecars in the fixture directory.

The test performs no Office Open/Save on the ZIP and edits no document. It
requires legally supplied private media; no Office executable or key is
checked in. Set `ARCHIVE_PACKAGE=$PWD/build/openlfn-package` to test staged
payload copies. Artifacts remain private under `build/tests/archive-office.*`.
Native 7z/TAR/gzip and Office on DOS 7.x remain unsupported/unverified.
