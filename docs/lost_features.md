# Features Dropped Between Calmira Versions

Reviewed on 2026-11-03. Calmira Reloaded follows Calmira Reborn (3.3 plus
LFN). This list records what older or parallel versions offered and Reborn
lacks, and which add-ons can be added. It extends [addons.md](addons.md).

Method: every INI key that a version reads (`Read*('Section', 'Key'`) was
compared with Reborn, then each missing key was traced to its use. Units
that exist in no Reborn `SRC`/`VCL` file were read individually. Renamed or
reorganised settings, for example the taskbar slide speeds and DOS scripts,
are still present and not listed.

## Removed from the Shell

| Feature | Last version | What it did | Effort | Decision |
| --- | --- | --- | --- | --- |
| Animated drop cursor (`AnimCursor`) | 3.1 beta 3 | While dragging over a window that accepts a drop (`DropServer.CanDrop`), showed the animated `crFlutter` cursor | Small: cursor resource and three `MouseMove` checks | Candidate; needs a freely licensed cursor |
| Confirm before quitting (`QueryQuit`) | 3.1 beta 3 | Option to skip the quit question in the system window and in Run | Small | Candidate; 3.3 always shows the Quit dialog |
| Separate time column (`TimeColWidth`) | 3.1 beta 3 | Details view showed date and time in separate, resizable columns | Medium: header, layout and settings | Candidate |
| Close file pane from tree (`TreeCloseFilePane`) | 2.2 | Explorer option to close the file pane when using the tree only | Small | Low priority |
| Browse buttons (`ShowBrowseBtns`) | 2.2 | Back/up buttons in folder windows | — | Superseded by 3.x toolbars; the key is still in `src/calmira.ini` but nothing reads it |
| Taskbar options of the 1.0 `TASKBAR.EXE` (`24HourFormat`, `ButtonHint`, `CalIcons`, `ShowCalWindows`, `NoOverlap`, `Highlight`) | 1.0 | Separate taskbar program with its own options | — | Superseded by the integrated taskbar; the clock format comes from `[intl]` |
| 1.0 preferences (`HollowDrag`, `KeyBreak`, `ShowList`, `RefreshFolders`, `FindVersion`) | 1.0 | Early drag and folder options, replaced by the 2.x property pages | — | Not needed |
| Restart delay (`RestartSleepTime`) | 3.1 beta 3 | Pause before a restart | — | Not needed |

## Not in Reborn, Source Available

| Component | Source and licence | What it is | Decision |
| --- | --- | --- | --- |
| CalTheme 2.5 | Delphi, GPL v2 (`vendor/upstream/caltheme-2.5`) | Icon theme selection, preview and reset | Best add-on candidate: port to FPC as an optional helper |
| Clean Start | Assembler, public domain (`vendor/upstream/clean-start`) | DOS helper for a clean exit and first start | Candidate; port to NASM/FPC |
| XP `XPPROP`, `XPBUTTON`, `CHANGBMP` | Delphi, GPL (`calmira-xp-3.33`) | Classic/XP colour scheme, custom-painted buttons, user picture | Optional theme; `XPBUTTON` needs lifecycle fixes (see addons.md) |
| 3.1 beta 3 `CFSCD`, `CFSNET` | Delphi, GPL | Raw CD reader and an unfinished network file system | Reference only |

## Reimplement, No Source

| Add-on | What we would rebuild |
| --- | --- |
| Address Bar 1.1 | Run box with autocompletion from history and the file system |
| MiniMon | Tray applet with free memory and system resources, using `GetFreeSystemResources` |
| DiskUtil 2.1 | Floppy format and copy front end |

CalClean, the Desktop Icons Menu, the COMMDLG replacement and the Registry
Editor stay out for the reasons in [addons.md](addons.md).

## Search for Further Add-ons

The web search in November 2026 found nothing beyond the
[calmira.de catalogue](http://calmira.de/downloads/index.htm):

- `www.calmira.net` only answers with a placeholder page.
- Mirrors such as pieter.com hold the plain 3.3 package; its parts
  (`W95ICONS.DLL`, tray `.ALS` aliases, the helpers) are already ported.
- The Calmira NT Shell is mentioned in articles, but no source was found.
