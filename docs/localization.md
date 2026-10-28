# Runtime Languages

The intended distribution has one set of executables, not one build per
language. `make languages` writes `build/lang/<code>.LNG` from historical
translations. New UI text belongs in `locales/extra.json`. Generated files use
the language's Windows ANSI code page (CP1252; CP1250 for Polish) and CRLF,
with short-string limits checked before writing.

| Code | Language | Historical source | Catalogue entries |
|---|---|---|---|
| en | English | `src` (RC and DFM) | 1060 |
| de | Deutsch | `calmira-lfn-de` DFMs, messages from `calmira-de-3.3/SRC/LOCALE.RES` | 1051 |
| fr | Francais | `calmira-fr-3.3` (RC and DFM) | 1001 |
| nl | Nederlands | `calmira-nl-3.3/CALMIRA.EXE` | 999 |
| pl | Polski | `calmira-pl-3.3/CALMIRA.EXE`, CP1250 | 1000 |
| it | Italiano | `calmira-it-3.2/CALMIRA.EXE` | 998 |
| es | Espanol | `calmira-es-2.3/CALMIRA.EXE` | 915 |

English entries other catalogues lack are mostly internal identifiers,
runtime placeholders and copyright lines, which are not translated.

- **Stale translations are dropped.** Each historical translation is compared
  with the English release it was made from (`BASES` in
  `tools/build_languages.py`: LFN 3.3 for German forms, 3.3, 3.2, or 2.2 for
  Spanish).
  - An entry is kept only while that English text, ignoring case and
    spacing, is still today's English text.
  - Dialogs were reordered and reworded since those releases. For example,
    the French 3.3 "Général" would label today's "Wallpaper" tab, and the
    Spanish 2.3 licence text would sit where the About box shows the MS-DOS
    version.
  - `coverage.json` reports the dropped count as `stale`.
- **Project translations.** `locales/translated/<code>.json` holds texts no
  usable historical translation covers. These were translated for this
  project, not taken from old packages.
  - They fill keys that are missing or stale.
  - They also replace a historical text that fails the format or length
    check, which is still listed under `omitted`.
  - Language-neutral words (Internet, CD-Rom, Alias, 4DOS / LFN) are left to
    the English fallback.
  - Native speakers are welcome to correct them.
- **German messages.** The German 3.3 translator edited the compiled
  `LOCALE.RES` and left `LOCALE.RC` in English (see its `EXPLAIN.TXT`). The
  German LFN build has an English string table too. Until now `de.LNG`
  therefore had English messages.
- **Binary-only translations** (nl, pl, it, es). These come from the
  string table and the `TPF0` form resources of the translated
  `CALMIRA.EXE`.
  - A string's number is mapped to its name through the `LOCALE.PAS` of the
    English release it was translated from (3.3, 3.2, or 2.2 for the
    Spanish 2.3).
  - Every mapped message with placeholders matches that release's English
    text.
- **Provenance.** `vendor/upstream/calmira-<code>-<version>/PROVENANCE.TXT`
  records each download URL and the SHA-256 checksums.
- **Not available:**
  - the Czech translation exists only for Calmira 2.2, on Simtel FTP
    mirrors that no longer exist;
  - the Polish source package is gone with its host.
  - The Web Archive was unreachable when these were looked for.

## Installer Selection

`install/install.ini` uses GDI's generic application-language feature:

```ini
[Languages]
Default=en
Choice=en|English
Choice=de|Deutsch
Choice=fr|Francais
Choice=nl|Nederlands
Choice=it|Italiano
Choice=es|Espanol
Choice=pl|Polski (Windows CP1250)
Config=CALMIRA.INI|Language|Selected
```

All catalogues are installed under `LANG\`. Polish needs a Windows with
code page 1250 (a Central European Windows 3.1, or matching fonts). GDI writes the selected code
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
