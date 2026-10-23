# Calmira Reloaded

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
- `vcl/`, `bmp/`, `help/`: maintained libraries and resources.
- `assets/branding/`: source artwork for the neutral Calmira graphics.
- `vendor/upstream/`: extracted Calmira releases and Reborn history.
- `vendor/reference/`: WinFile, DOSLFN, compiler and pinned 7-Zip sources.
- `vendor/build-deps/`: tracked GeosOne JWasm/JWlink source snapshots.
- `archives/original/`: unmodified downloaded artifacts.
- `docs/`: provenance, comparison results and integration design.
- `src/portable/`: OS-independent Pascal and C logic, including Save transactions.
- `install/`: GeosOne DOS Installer definition.

Owned source filenames use lowercase, including `makefile` and documentation.
`AGENTS.md`, unchanged vendor/archive trees and generated DOS package names are
intentional exceptions. See [branding and resource updates](docs/branding.md).

## Useful commands

```sh
make compare
make test
make omf-toolchain
make toolchain-smoke
make doslfn
make doslfn-test
make lfn-probe
make winfile16-core
make win16-helpers
make languages
make pack-win16
make ctl3d
make clfn-hook
make package GDI=../gdi
```

`make compare` compares normalized source/text files against Reborn. `make test`
compiles portable Pascal/C logic and runs host tests. The complete GUI is still being migrated from
Delphi 1 VCL to the FPC Win16 target; see `docs/toolchains.md`. `make package`
expects built binaries and uses `gdi/build/INSTALL.EXE`.

`make doslfn` fetches and checksum-verifies the upstream DOSLFN v0.42a driver,
its Windows 3.x translator, code-page tables and translations. The source is
tracked through the `geosone/doslfn` submodule for the ongoing TASM-to-JWasm
port. `make lfn-probe` builds the DOS host-capability detector used to select a
real 71xx LFN provider, the `DESCRIPT.ION` virtual-LFN fallback, and the
optional FAT32 WIN386 patch without conflating those separate capabilities.

Initialize the WinFile reference fork after cloning with
`git submodule update --init --recursive`. The submodule follows the
`calmira-hotplug` branch of `geosone/winfile`. The Win16 port compiles original
Microsoft C modules using OpenWatcom: `make winfile16-core` builds the first
ported modules, and `make winfile16-core-runtime-test` runs them in a supplied
Windows 3.11 image. `make winfile16` attempts the full original application
but still fails on unported Win32 dependencies. There is no finished WinFile
replacement yet; see [`docs/winfile16.md`](docs/winfile16.md).
The old Pascal drive demo is a separate `DRVPROBE.EXE`, not WinFile.

The shared runtime-language payload and installer selection are described in
[`docs/localization.md`](docs/localization.md). Full-shell build blockers and
UPX compression details are tracked in [`docs/build_status.md`](docs/build_status.md).

The first [Win16 VCL port layer](docs/vcl_port.md) provides native message
records and a private RTL dispatch adaptation, tested with real Windows
messages. Forms/Controls/Graphics and the complete desktop are still unfinished.

The experimental global Open/Save hook supports existing descriptions and
new long-name Save through reserved DOS aliases. ClarisWorks Save/Open was
tested natively without IFA. Start it explicitly with `OLFNLOAD.EXE`; it is
not installed automatically. See [native results](docs/file_dialog_tests.md)
and [transaction limits](docs/lfn_save_transactions.md). An independent Office
adapter passes Word/Excel Save/Open tests on DOS 6.22; see
[Office-specific limits](docs/office_dialog_tests.md). `make archive-viewer`
builds a read-only ZIP viewer using the pinned 7-Zip ZIP reader under DOS/32A.
With `OLFNVIEW.EXE` and `OLFNLIST.EXE` beside the hook, select a ZIP in the
file dialog and use its system menu's **View ZIP contents** command.
The native Win16 bridge is tested on enhanced Windows 3.1x with DOS 6.22;
DOS 7.x Windows launches are currently blocked safely. Standalone DOS 7.1
listing works. Extraction and other native formats remain unimplemented.
See [usage and limits](docs/archive_viewer.md) and [porting status](docs/archives.md).
`make archive-package GDI=../gdi` creates a standalone experimental GDI
installer under `build/openlfn-package/`, without requiring the full shell.
Installation does not enable the global hook automatically.
The independent product is now **OpenLFN Loader**: `make openlfn-package`
builds its neutral GDI installer without the shell. Calmira bundles the same
`OLFN*.EXE`/`OLFNHOOK.DLL` payload. See [OpenLFN](docs/openlfn.md).

Calmira also synchronizes validated Program Manager `.GRP` files into an owned
Start-menu subtree at startup; see [`docs/program_groups.md`](docs/program_groups.md).

The optional W95ICONS.DLL is no longer shipped. `make ctl3d` builds the GPL
Open386MAX replacement for CTL3DV2.DLL with OpenWatcom and JWlink; see
[`docs/binary_dependencies.md`](docs/binary_dependencies.md).

The historical add-on and branch review, including recovered CalTheme and
Clean Start sources, is in [`docs/addons.md`](docs/addons.md).

`make help` builds the updated **Calmira Reloaded** WinHelp manual from its
RTF and bitmap sources using the pinned Open386MAX compiler. The manual
documents the extensions and their current limits; see [help build and native
verification](docs/help.md). Historical changelogs remain explicitly historical.

