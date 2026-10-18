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

The legacy Delphi GUI uses this API for 3D controls. `make ctl3d` now builds
the GPL-3.0 Open386MAX implementation with OpenWatcom and the pinned JWlink
fork, producing `build/win16/ctl3d/CTL3DV2.DLL`. The active package uses this
build output instead of distributing the historical Microsoft binary.

The committed source snapshot is from
[geosone/Open386MAX](https://github.com/geosone/Open386MAX/tree/82d33fc5861e5c4ff8b21d480e8730f11b312379/CTL3D),
revision `82d33fc5861e5c4ff8b21d480e8730f11b312379`. Its source, definition file,
header and license live under `vendor/build-deps/open386max-ctl3d/` and are
recorded in `vendor/build-deps/LOCK`. It implements control painting, dialog
subclassing, automatic CBT hooks and system-colour changes for Windows 3.x.
This is a separately built C DLL; Pascal callers keep the existing Win16 ABI.

The build checks the NE DLL flag, shared data, exported module name and all
export names/ordinals against the source definition. Native Windows 3.1/3.11
dialog rendering, focus, keyboard operation and colour-change acceptance
tests with the finished Calmira GUI remain outstanding. Do not infer full
Microsoft API equivalence from a successful build or export check.

The original binary remains in the archived Reborn tree only. The package
includes the replacement's license as `LICENSES/CTL3D.TXT` and displays it
alongside Calmira's license. A future Free Pascal control implementation may
remove the DLL interface entirely.

`WNDHOOKS.DLL` and `LFNFUNCS.DLL` are separate Calmira libraries with source
projects under `src/`; they are not the two historical binaries above.
