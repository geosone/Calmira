# Calmira Unified

This repository develops a curated Windows 3.1 shell from the strongest parts
of the surviving Calmira source releases. Calmira Reborn 5.0, itself descended
from Calmira LFN 3.32, is the working baseline. Historical trees remain
unchanged under `vendor/upstream/`; downloaded archives and checksums are kept
under `archives/original/`.

The first priorities are reliable long-file-name handling, removable-media
refresh and safe eject for the sibling `eusbaspi`/`ahciaspi` drivers, followed
by a GeosOne DOS Installer package. Inno Setup is intentionally not used.

## Layout

- `src/`: maintained Calmira implementation and Delphi project files.
- `VCL/`, `BMP/`, `HELP/`, `VENDOR/`: supporting libraries and resources.
- `vendor/upstream/`: extracted Calmira releases and Reborn history.
- `vendor/reference/`: Microsoft WinFile and DOSLFN reference sources.
- `vendor/build-deps/`: tracked GeosOne JWasm/JWlink source snapshots.
- `archives/original/`: unmodified downloaded artifacts.
- `docs/`: provenance, comparison results and integration design.
- `src/portable/`: OS-independent Pascal code compiled by Free Pascal.
- `install/`: GeosOne DOS Installer definition.

## Useful commands

```sh
make compare
make test
make omf-toolchain
make toolchain-smoke
make doslfn
make doslfn-test
make lfn-probe
make winfile16
make ctl3d
make package GDI=../gdi
```

`make compare` compares normalized source/text files against Reborn. `make test`
compiles portable units with FPC. The complete GUI is still being migrated from
Delphi 1 VCL to the FPC Win16 target; see `docs/TOOLCHAINS.md`. `make package`
expects built binaries and uses `gdi/build/INSTALL.EXE`.

`make doslfn` fetches and checksum-verifies the upstream DOSLFN v0.42a driver,
its Windows 3.x translator, code-page tables and translations. The source is
tracked through the `geosone/doslfn` submodule for the ongoing TASM-to-JWasm
port. `make lfn-probe` builds the DOS host-capability detector used to select a
real 71xx LFN provider, the `DESCRIPT.ION` virtual-LFN fallback, and the
optional FAT32 WIN386 patch without conflating those separate capabilities.

Initialize the WinFile reference fork after cloning with
`git submodule update --init --recursive`. The submodule follows the
`calmira-hotplug` branch of `geosone/winfile`; Calmira's Win16 implementation
uses its notification flow as a reference, not its Win32 API calls directly.
`make winfile16` builds the first native Windows 3.1 replacement milestone at
`build/winfile16/WINFILE.EXE`; it currently provides drive discovery, a manual
refresh command, and periodic hotplug detection.

Calmira also synchronizes validated Program Manager `.GRP` files into an owned
Start-menu subtree at startup; see [`docs/PROGRAM_GROUPS.md`](docs/PROGRAM_GROUPS.md).

The optional W95ICONS.DLL is no longer shipped. `make ctl3d` builds the GPL
Open386MAX replacement for CTL3DV2.DLL with OpenWatcom and JWlink; see
[`docs/BINARY_DEPENDENCIES.md`](docs/BINARY_DEPENDENCIES.md).

