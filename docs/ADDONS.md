# Calmira Add-on and Branch Review

Reviewed on 2026-10-18 against the local historical source trees and the
[Calmira download catalogue](http://calmira.de/downloads/index.htm).
These extensions are mostly standalone programs, tray applets, configuration
editors or source patches; they do not constitute one shared DLL plugin API.
The maintained tray already supports applets and `.ALS` quick-launch aliases.

## Downloaded add-ons

Archives remain under `build/downloads/calmira-addons/`. Their SHA-256 values
are recorded in `docs/addons/SHA256SUMS`; run
`python3 tools/audit_addons.py build/downloads/calmira-addons` to verify them,
check ZIP CRCs and list actual source files. Downloads were obtained over
HTTP from the historical sites; these are observed checksums, not publisher
signatures. No downloaded executable or DLL was run or installed.

| Add-on | Source and terms found | Integration decision |
|---|---|---|
| CalTheme 2.5 | Delphi sources, GPL notice in DPR, GPL v2 text | Best candidate: icon-theme selection, preview and reset. Imported as reference source; FPC GUI port still needed. |
| Clean Start | `CS.86`, explicit public-domain header | Useful optional DOS clean-exit/first-start helper; assembler syntax needs porting. Imported as source reference. |
| Address Bar 1.1 | EXE and HTML help only | Autocompletion is useful; reimplement in portable Pascal unless source is recovered. |
| Calmira Registry Editor | EXE only | Keep separate; source and licensing needed before adoption. |
| DiskUtil 2.1 | EXE, HLP and readme only | Floppy formatting fits later utility work; no source adoption yet. |
| MiniMon | EXE only | Resource monitoring is useful; implement with documented Win16 APIs if no source is found. |
| CalClean | EXE and free-of-charge readme; no source grant | Do not enable automatic deletion: its readme explicitly describes lost entries/icons for absent removable media. |
| Desktop Icons Menu beta | Three EXEs, unmodified-redistribution-only terms | No source merge. Show-desktop and tiling already overlap maintained shell actions. |
| COMMDLG replacement | DLL and brief instructions only | No integration: no auditable implementation or replacement license supplied. |
| CalPaint 2.0 | Installer from author's site; page says GPL, no source download found | Candidate for themes/system colours; installer was not executed and source availability remains unconfirmed. |

The first two imports are not enabled in the installer. CalTheme's bundled
Verdana font, compiled DCUs, EXE and other generated files were excluded.
Its explicit source notice identifies David Burgess and December 2000.

## Other Calmira branches

| Component | Actual finding | Decision |
|---|---|---|
| XP `CHANGBMP.PAS` | User-picture selection dialog, not wallpaper management | Optional user-picture feature after the settings model is ported. |
| XP `XPPROP.PAS` | Classic/XP colour and button-style settings | Retain as reference for optional themes. |
| XP `XPBUTTON.PAS` | Custom-painted button; constructor/destructor need lifecycle review | Do not copy unchanged: its constructor omits inherited setup and destructor frees Canvas directly. |
| French `TRAD.PAS` | Translator credits/contact form | Preserve attribution; it is not a translation engine. |
| Beta `CFSNET.PAS` | Unfinished network abstraction, empty FindNext/Close functions and incomplete syntax | Architecture reference only; not a functioning network plugin. |
| Beta `CFSCD.PAS` | Raw MSCDEX/DPMI CD sector reader | Keep separate from the existing LFN path; audit bounds and media changes before considering a port. |
| Older exit/ExitExec helpers | Functions already present in the shell/DOSRUN flow | No duplicate binaries needed. |

## Recovered sources and download locations

- `vendor/upstream/caltheme-2.5/`: source/resources and license selected from
  `http://calmira.de/downloads/files/david/calthem2.zip`.
- `vendor/upstream/clean-start/CS.86`: source selected from
  `http://calmira.de/downloads/files/talisoft/cs.zip`.
- Other catalogue paths: `erwin/cregedit.zip`, `maxim/address.zip`,
  `ramon/dskutl21.zip`, `ramon/minimon.zip`, `BB/calclean.zip`,
  `commdlg/commdlg.zip`, `carlos/cdimbeta.zip`, all relative to
  `http://calmira.de/downloads/files/`.
- CalPaint installer: `http://www.calpaint.de/cpntinst.exe`, linked from the
  [author's download page](http://www.calpaint.de/downloads.htm).

Imported trees remain unchanged so later ports can retain their authorship
and licenses. An adopted feature needs an FPC build and Win3.1 runtime tests
before being presented as an installed extension.
