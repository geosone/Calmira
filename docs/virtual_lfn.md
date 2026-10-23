# Virtual Long Filenames for Windows 3.1

Instant File Access demonstrated a useful fallback: keep real files under DOS
8.3 names and store their display names in `DESCRIPT.ION`. This works without
VFAT and therefore does not require FAT32. It is not a replacement for a real
filesystem LFN API: unaware DOS programs continue to see the aliases.

Calmira already has mature `DESCRIPT.ION` support in `src/fourdos.pas`.
`src/portable/virtual_lfn.pas` now supplies the independent mapping core:

- validate real DOS 8.3 names and reject reserved devices such as `CON`;
- derive deterministic `NAME~1.EXT` aliases, with a caller-selected collision
  number;
- parse and emit `ALIAS.EXT Long Display Name.ext` lines;
- preserve 4DOS data following the Ctrl-D metadata separator.

## Win16 Integration

The experimental GPL component `OLFNHOOK.DLL` installs a shared Win16 hook and
subclasses Windows 3.1 common Open/Save dialogs. Lists show mapped long names,
while the application receives the real alias. A Save operation allocates an
unused alias and updates `DESCRIPT.ION` only after the application creates
its file, through a journal/temporary/backup sequence. The portable transaction
core is `src/portable/lfn_store.c`; `OLFNLOAD.EXE` owns periodic commit polling.
See [transaction limits](lfn_save_transactions.md). Sharing this service with
Calmira rename/copy/move/delete/recycle operations is still future integration.

Private application dialogs need explicit, application-specific adapters; a
common-dialog hook alone is insufficient. IFA's "All To Common" mechanism and
Word/Excel dialog profiles demonstrate a separate compatibility layer, not
universal support. The first independent Word/Excel adapter now passes native
Save/Open round trips on DOS 6.22. It retains Office's own format controls and
uses a companion list; newly typed names require Enter in the filename edit.
See [Office-specific evidence and limits](office_dialog_tests.md).
Unaware tools may rename or delete an alias without
updating the mapping; automatic pruning and repair remain future work. Current
transactions preserve unknown description lines and never delete real files.

## Provider Selection

1. Prefer a working native `INT 21h/AX=71xx` provider (Win9x or DOSLFN).
2. Otherwise offer virtual LFN mode on any writable FAT12/16/32 volume.
3. Fall back to plain 8.3 on read-only media or when mapping updates fail.

Current automated tests cover alias formatting, reserved names, mapping
parsing/serialization, Ctrl-D metadata and an independently generated IFA
mapping fixture. C fault-injection tests additionally cover collision
allocation, reservations, rollback and preserved metadata. Native long-name
Save/Open, Cancel, application veto and pending-unload tests pass. Copy/move
consistency, unrelated-writer races and hot removal remain unverified. See
[native dialog status](file_dialog_tests.md).

## IFA 4.00 Behavioral Reference

A local installation test of IFA 4.00 (About: build 366) succeeded with German
ClarisWorks 1.0 under WfW 3.11 on a disposable FAT16 image. Both Open and Save
gained a toolbar and properties area; the Open dialog retained ClarisWorks'
Import Options control. Saving `calmira langer dateiname.cwk` produced a real
`CALMIR~1.CWK` file and this independently generated mapping:

```text
CALMIR~1.CWK calmira langer dateiname.cwk
```

After closing the document, IFA displayed the long name and successfully
reopened it, while ClarisWorks' title showed the DOS alias. The disk mapping
was confirmed after stopping the VM. This verifies the reference program,
**not** our experimental hook. Screenshots and the modified test image are
under ignored `build/tests/ifa400.6ZGn8l/`.

Implement comparable behavior independently in our open-source components.
Do not vendor IFA binaries, registration data, dialog databases or proprietary
implementation code. In particular, new-file Save needs collision-safe alias
reservation and a recoverable mapping update after the application actually
creates the file; a display-only list overlay is insufficient.
