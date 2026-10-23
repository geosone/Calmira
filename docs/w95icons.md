# W95ICONS.DLL Audit

## Historical Purpose

The archived Reborn help describes `w95icons.dll` as an icon collection for
customizing Calmira. Its upgrade instructions recommend copying the DLL and
the default INI files for the new appearance. This is Windows-95-style icon
customization inside Calmira, not installation of a Windows 3.11 logo patch.

The archived Win16 NE DLL contains 101 icon images (`RT_ICON`) and 101 icon
groups (`RT_GROUP_ICON`), with no bitmap resources. Its only named export is
`WEP`. The inspected imports are KERNEL `LOCALINIT`, `GETWINFLAGS`, `__AHINCR`
and USER `MESSAGEBOX`: runtime support, not a shell hook or system-file patch.
The historical help's description says “95 icons”; the actual resource count
in this binary is 101. No replacement of boot/shutdown logos was found.

## Concrete Consumers

- Original `SRC/TRAY/SHOWDESK.ALS`: `%calmira%\w95icons.dll`, icon index 18
  (group resource ID 20).
- Original `SRC/TRAY/EXPLORER.ALS`: the same DLL, index 19 (group ID 22).

`src/referenc.pas` implements custom `IconFile`/`IconIndex` through `ExtractIcon`;
empty or failed sources fall back to normal application/Calmira icons.
`src/resource.pas` also supports configured file-type icon sources. These are
resource consumers, not a mechanism for globally replacing Windows icons.

The active default aliases no longer name the DLL, and packaging excludes it.
However, `.als` files contain a serialized icon after the reference fields.
`src/alias.pas` loads that cached icon directly before installing its change
handler. `tools/normalize_tray_aliases.py` deliberately retains the cache.
Consequently the former artwork can remain visible even with an empty
`IconFile`; an actual artwork migration must replace/regenerate that cache.

## Open-Source Replacement Options

A compatible replacement is technically feasible: build a Win16 NE resource
DLL with independently created, explicitly licensed icons using the existing
OpenWatcom/JWlink/resource toolchain. No resident patcher is needed. For old
configurations, preserve the 101-group extraction order and original resource
IDs, including gaps. `ExtractIcon` indexes are not the same as resource IDs.

Alternatively embed new icons in Calmira and migrate old aliases/configuration
references plus their cached images. This removes the separate DLL dependency.
Neither option has been implemented by this audit. Do not infer permission to
redistribute historical artwork from the DLL filename or copy it into a newly
licensed replacement. Original media remain unchanged under `vendor/`.
