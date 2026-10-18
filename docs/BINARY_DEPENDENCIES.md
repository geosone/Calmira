# Historical binary dependencies

## W95ICONS.DLL

The historical DLL is an optional icon collection. The maintained default
configuration does not refer to it; Calmira already embeds its own icon
resources in `src/ICONS.RES` and `src/CALICONS.RES`. The active installer and
release scripts therefore no longer distribute W95ICONS.DLL.

The original remains in `vendor/upstream/calmira-reborn/VENDOR/` for archival
comparison. User-created configurations that explicitly refer to its icon
indexes need to select an embedded icon instead. No index-compatible icon
replacement has been claimed or generated from the historical binary.

## CTL3DV2.DLL

The legacy Delphi GUI requires this library for its 3D controls, as documented
in `HELP/Calmira.rtf`. Its dependency comes from the Delphi framework; the
framework implementation is not supplied by this repository's `VCL/`
extension units. Simply removing the DLL from the legacy package does not
produce a working open-source GUI.

Wine provides LGPL-2.1-or-later sources at
[dlls/ctl3dv2.dll16/ctl3d.c](https://github.com/wine-mirror/wine/blob/master/dlls/ctl3dv2.dll16/ctl3d.c).
That implementation explicitly consists of API stubs, uses Wine's 16-bit
compatibility headers and does not implement the original 3D rendering.
It is an API reference, not a tested drop-in DLL for native Windows 3.1.

The Free Pascal GUI port should draw controls with the native Windows 3.1
USER/GDI APIs and owned Pascal code. Its final EXE and helper DLL import tables
must be checked for CTL3D/CTL3DV2 imports before dropping CTL3DV2.DLL from the
package. Dialog rendering, focus, keyboard operation and colour changes must
then be exercised under Windows 3.1/3.11. Until that port exists, the historical
DLL remains an explicit dependency of the legacy package.

`WNDHOOKS.DLL` and `LFNFUNCS.DLL` are separate Calmira libraries with source
projects under `src/`; they are not the two historical binaries above.
