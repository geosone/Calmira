# Instant File Access 4.00 Analysis

## Scope and Evidence

IFA was installed and registered from locally supplied media in an isolated
WfW 3.11/FAT16 image. German ClarisWorks 1.0 passed a manual long-name Save,
document close, long-name display and Open round trip. Its real filename was
`CALMIR~1.CWK`; `DESCRIPT.ION` contained the independently generated display
name. See [acceptance observations](VIRTUAL_LFN.md#ifa-400-behavioral-reference).

Ghidra 12.1.4 imported the Win16 NE modules using
`x86:LE:16:Protected Mode`. OpenWatcom `wdump -x` independently enumerated
export names and ordinals. Ghidra inventories all recognized functions and
decompiles selected hook/LFN functions using our generic inspection script.

## Identified Modules

| Module | Export/interface evidence | Responsibility |
| --- | --- | --- |
| `IFA.EXE` | Imports IFALIB, IFAATC, IFALIBS | Resident controller and configuration entry point |
| `IFALIB.DLL` | `IFA_INIT`, `IFA_CBTPROC`, `IFA_CALLWNDPROC`, `FNOPENFILEHOOK`, `IFA_GETOPENFILENAME` | Common-dialog integration and enhancement |
| `IFALFN.DLL` | `LFN_FINDUNIQUE`, `LFN_CREATESHORTNAME`, `LFN_SETLONGNAME`, `LFN_COMMIT`, `LFN_FLUSHALL`, file/directory APIs | Name mapping, alias management and update lifecycle |
| `IFAATC.DLL` | `ATC_CBTPROC`, `ATC_CALLWNDPROC`, `ATC_FIND`, `ATC_EDIT`, `ATC_SAVE` | Application-specific dialog compatibility |
| `IFACTRL.DLL` | `TOOLBAR_CREATE`, toolbar/tooltip and miniature-window APIs | Reusable Win16 UI controls |
| `IFALIBS.DLL` | `EVENT_REGISTER`, `EVENT_CREATE`, `DB_COMMIT`, file/property/dialog helpers | Shared event, persistence and UI infrastructure |
| `VIEW_TXT.DLL`, `VIEW_ZIP.DLL` | Both export `VIEWER_SHOW` | Optional viewers |

Hook decompilation confirms calls to Windows hook/subclass APIs; the division
between CBT processing and window-message processing is real, not inferred
from filenames alone. Exported commit/hold/release/flush operations indicate
an update lifecycle; they do not by themselves prove crash-safe transactions.
`IFADLG.DB` contains application/module/control identifiers, including Word
2.0/6.0 and Excel. Do not copy that database into our replacement.

## Independent Implementation Requirements

Keep the portable mapping/provider layer separate from the Win16 hook and UI.
Implement standard COMMDLG behavior first, preserving application hooks and
custom controls such as ClarisWorks' Import Options. Add further private-dialog
adapters only against verified application interfaces, not on the assumption
that all applications use COMMDLG.

The first independent Word/Excel SDM adapter now has passing native Open/Save
round trips on DOS 6.22. It uses observed application classes/control IDs and
a companion list, not IFA's database. Mouse acceptance of newly typed long
names and Office on DOS 7.1 remain open; see [Office tests](office_dialog_tests.md).

Save needs collision-safe alias reservation, confirmation that the file was
actually created, recoverable metadata writes and safe handling of locked
files/removable media. Cancel must not leave fake mappings. Current OLFNHOOK
passes native new-name and existing-mapping Open/Save/Cancel tests with a
portable journal/backup transaction core. It is not a complete IFA lifecycle:
see [transaction limits](lfn_save_transactions.md), especially crash recovery,
unaware-writer races and the one-pending-save-per-directory limit.

## Limits and Local Artifacts

Pseudocode has unresolved segment-register/parameter types and some import
stub warnings. It is not original source, a verified ABI specification or
code suitable for direct reuse. Keep generated pseudocode and binaries out
of the source tree; implement documented behavior independently.

Local project: `build/tests/ifa400.6ZGn8l/ghidra-project/IFA-reference.gpr`.
Inventories, export lists and private pseudocode: sibling `analysis/` directory.
Input archive SHA-256:
`780ab2b8753e398f7440ea8ff14db26efda67c8ee140fb75fbba16ceb79d9fc1`.
