# Calmira Reloaded Help

`help/calmira.rtf` is the maintained WinHelp source, not a generated export.
The current product name is **Calmira Reloaded**. Original authors, licenses,
historical changelogs and legacy configuration keys retain their names.

The contents page links to **Calmira Reloaded: extensions and status**.
It covers GDI installation and shell selection, OpenLFN Loader and its
Open/Save hooks, read-only ZIP listing, Program Manager group synchronization,
language selection, icon-library changes, build tools and experimental UPX.
It explicitly distinguishes implemented helpers from unfinished full-shell,
WinFile/hotplug and DOS 7.1 work. Native DOSLFN services, FAT32 storage and
virtual `DESCRIPT.ION` names are not interchangeable.

Three linked practical topics provide step-by-step instructions:

- **OpenLFN and ZIP quick start** (context 901): explicit loader startup,
  Open/Save, read-only ZIP inspection and safe stop/update/uninstall.
- **Program Manager groups and application language** (902): one-way group
  synchronization, the managed menu subtree, manual refresh and catalogue
  selection without promising complete shell localization.
- **Reloaded troubleshooting and safe recovery** (903): missing dependencies,
  pending Save journals, ZIP limits, DOS 7.x guard, packed-program startup and
  reproducible reports. Private VSHARE experiments are not an update recipe.

All seven contents views expose the status page and all three guides directly,
including partially expanded books. The historical descriptions/LFN,
troubleshooting and translation topics link to their current counterparts.

Old copy-only installation, CTL3D download and compiler instructions were
corrected or identified as historical. The old blanket instruction to disable
32-bit file access was removed, as was the suggestion to move every shell file
into the Windows directory. The help-build section now documents `make help`,
not a mandatory HCP download. The manual remains English; shared application
language catalogues do not translate WinHelp automatically. Old screenshots
illustrate inherited Calmira features, not proof of a complete Reloaded build.

## Rebuild and package

```sh
make help
python3 -m unittest discover -s tests -p 'test_help_build.py'
```

The build uses Python 3 and the pinned GPL-3.0 Open386MAX `whc.py` snapshot in
`vendor/build-deps/open386max-whc/`. No proprietary help compiler, Windows
host or sibling checkout is needed. The build stages the historical HPJ input
name `calmira0.rtf` from `calmira.rtf`; do not maintain a second RTF copy.
Local compiler fixes preserve Word table rows and per-cell text offsets.
See the snapshot's `origin.json` and `readme.md` for provenance.

Output is `build/help/calmira.hlp` with an audit report alongside it. Builds
default to a fixed timestamp; set `SOURCE_DATE_EPOCH` for a release timestamp.
Warnings, broken references and topics unreachable from Contents fail the build
without replacing an existing HLP. The JSON report includes `reachable_topics`;
the maintained manual currently reports 64 of 64. Cyclic links are allowed,
but merely having a keyword or numeric context does not replace navigation.
`make package` rebuilds and packages this output, not a stale upstream HLP.
The checked-in `help/calmira.hlp` is the verified default-timestamp build;
update it only after tests, never by copying an incomplete compiler result.

## Application help calls

The build also reads the owned binary DFM files and literal
`Application.HelpJump(...)` calls in Pascal sources. All 23 explicit form/menu
contexts, the `CALMIRA.HLP` filename and five literal jumps currently resolve.
Unmapped form contexts, stale help filenames and unknown literal targets fail
the build. Form context zero inherits normal VCL behavior; dynamically computed
exception contexts cannot be proven by this static check.

The Computer popup's inherited numeric context 201 now aliases Computer (21),
without modifying the historical DFM binary. Both icon-window and extended
Open-dialog **Contents** handlers open `Contents` directly rather than
dereferencing a possibly absent `ActiveControl`. Context-sensitive F1 handling
remains separate from those menu actions.

These source checks and standalone WinHelp probes do not demonstrate a working
full-shell F1 route: the VCL port still blocks that build.

## Help launch errors

The FPC `TAppHolder` help bridge delegates to an assigned custom `OnHelp`
handler first, respecting its `CallHelp=False` decision. Otherwise it consumes
the request once and calls the VCL-independent `help_service.LaunchHelp`.
A re-entry guard prevents recursive dispatch and is cleared in `finally`.
This follows the [FPC help-event interface](https://docs.freepascal.org/docs-html/rtl/classes/thelpevent.html);
the actual complete-shell event lifecycle remains unverified.

The service checks that the requested file exists before launching WinHelp.
Missing files and a false WinHelp return produce separate messages, including
the attempted path. The title and messages use `[Help]` entries from the shared
English/German/French catalogues, with built-in English fallback. A plain OK
message box has no Help button and cannot recursively request help itself.
`HELP_QUIT` skips the file check and never displays a shutdown error. A corrupt
HLP accepted by the WinHelp API can still produce WinHelp's own diagnostic;
this service is not a help-file format validator.

`make help-service-test` exercises the actual service on the host using isolated
recording WinTypes/WinProcs substitutes. It covers all three languages, long
path text, empty/missing files, failed/successful calls, argument preservation
and quiet cleanup. These substitutes never enter the native build. The native
probe additionally opens real WinHelp in plain/packed profiles and displays a
German missing-file message; screenshots and logs passed on Windows 3.11.

## Help beside a packed executable

Under Free Pascal, `TAppHolder.Loaded` resolves its relative `HelpFile` through
`runtime_paths.RuntimeDirectory`, as language/configuration loading already
does. The pinned UPX NE wrapper writes a `.SRC` sidecar beside its temporary
EXE; the existing resolver uses that record to locate the original executable.
Without a valid sidecar it retains the actual module directory. Legacy Delphi
builds retain their original `ExtractFilePath(ExeName)` behavior.

```sh
WIN311_IMAGE=/path/to/baseline.img make help-path-runtime-test
```

The native Free Pascal probe calls the real resolver and help service, once plain
and once through the pinned UPX wrapper. Help is installed only beside the
original EXE in `C:\HELPPKG`, and TEMP/TMP point to `C:\TEMPHLP`. The packed
case must report a temporary `~UPX*.EXE` module while resolving and opening
`C:\HELPPKG\CALMIRA.HLP`. Packing includes integrity and byte-identical
unpacking checks. No original disk image or compiler artifact is overwritten.

Both opening profiles passed under Windows 3.11 with QEMU TCG; screenshots showed the
Reloaded contents page. The additional `missing` profile loads the German
catalogue, requests `MISSING.HLP` and captures its error dialog before dismissing
it. The log must report the expected failed call without treating it as a
successful help launch. Per-build executable sizes are in `compression.json`.
This verifies the shared resolver and WinHelp launch, not `TAppHolder`'s entire
VCL event lifecycle. End-to-end packed shell/F1 acceptance remains pending the
complete GUI build. The probe does not establish missing-sidecar recovery or
other hosts' compatibility.

## Native acceptance

```sh
WIN311_IMAGE=/path/to/disposable-baseline.img make help-runtime-test
```

The runner makes private image copies and defaults to QEMU TCG, not KVM.
It calls WinHelp contents, contexts 21 and 201, keyword `custom bitmaps`, and contexts
900–903 (status and practical guides). Logs check successful calls and a visible
help window; inspect
the accompanying screenshots for rendering, which these checks cannot prove.
No Windows image or proprietary runtime is distributed with the repository.

Native Windows for Workgroups 3.11 testing passed all seven calls in private
image copies using TCG. Screenshots confirmed the contents, context topic,
status page and all three practical guides. Structural checks cover 64 topics,
all inherited contexts and numeric mappings, 221 native table rows,
26 embedded bitmaps, and internal links/keyword targets. The corrected banner
is embedded in the HLP, not merely placed beside it.

The added context-201 probe also passed in native Windows 3.11; its screenshot
shows the Computer topic, not a missing-topic dialog. The expanded default
runner now has eight profiles. This checks the numeric alias in WinHelp, not
the unfinished full shell's popup event dispatch.

Open386MAX's `qhelp.py` instead handles the DOS **QuickHelp** format. A `.HLP`
extension alone does not establish compatibility. Its DOS `HHELP` WinHelp
reader is a separate consumer; graphics/layout acceptance there has not been
established by the Windows test. DOS-reader support must be tested separately.
