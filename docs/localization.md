# Runtime Languages

The intended distribution has one set of executables, not one build per
language. `make languages` extracts historical English, German and French RC
messages and binary DFM captions into `build/lang/{en,de,fr}.LNG`. New UI text
belongs in `locales/extra.json`. Generated files use Windows ANSI CP1252 and
CRLF, with short-string limits checked before writing.

## Installer Selection

`install/install.ini` uses GDI's generic application-language feature:

```ini
[Languages]
Default=en
Choice=en|English
Choice=de|Deutsch
Choice=fr|Francais
Config=CALMIRA.INI|Language|Selected
```

All three catalogues are installed under `LANG\`. GDI writes the selected code
to `[Language] Selected` in the installed `CALMIRA.INI`, preserving other keys.
The selection currently runs in GDI's DOS transaction, including when launched
from its Windows frontend. It does not translate GDI's own interface.

## Application Loading

`language_catalog.pas` has no Windows or VCL dependency. Lookups fall back from
the selected catalogue to English, then to the caller's original text. Missing
or unsafe language codes select English. `LangUI` applies captions, hints and
string lists by form class/component/property keys; resource strings retain
their canonical English numeric IDs. Format-placeholder order is validated.

Win16 `runtime_paths.pas` reads our UPX wrapper's `.SRC` sidecar so packed
programs find configuration and catalogues beside the original EXE rather
than in the temporary extraction directory.

Help-launch errors use the shared `[Help]` catalogue section (title, missing
file and failed Windows launch). These error dialogs are translated separately
from the WinHelp manual, which remains English. Host service tests cover all
three languages; a native Win3.11 probe verifies the German missing-file dialog.

## Acceptance and Remaining Work

Host tests cover catalogue generation, header hit testing and component text
application. `tests/dos/test_language_win311.sh` checks window/button text in
native WfW 3.11 with the same drive-list prototype EXE and three configurations.
Build with `make drive-probe`, or `make pack-drive-probe` for the packed copy;
set `DRIVE_PROBE_EXE` to select that copy. This diagnostic is separate from the
original Microsoft C source port and is not its localization acceptance test.

This is not complete localization of the shell. The complete FPC GUI still
does not build; help, tips, remaining hardcoded strings and system-supplied
dialog buttons need separate review. Missing historical translations fall
back to English; `build/lang/coverage.json` lists omissions, not percentage
coverage. Additional languages require catalogues and, for other scripts,
compatible Windows code pages/fonts. They are not automatically supported.
