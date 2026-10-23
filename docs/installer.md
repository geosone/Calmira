# Installer Architecture

The GeosOne DOS Installer remains a generic engine. No Calmira-specific code
belongs in `/home/mario/mars/gdi`; products describe themselves through an
`INSTALL.INI` and a staged file tree.

Calmira's descriptor is `install/install.ini`. `make package GDI=../gdi`
validates the compiled artifacts and stages them with GDI's `INSTALL.EXE` under
`build/package/`. It also offers an opt-in, signature-checked WIN386.EXE patch
for Windows 3.1/3.11 on DOS 7.1 FAT32. GDI requires exactly two occurrences,
keeps a numbered backup, recognizes an already patched file, and reverses the
change during uninstall. It never relies on language-specific file offsets.
`LFNPROBE.EXE` supplies the package-defined `LFN`, `FAT32`, and `DOS71`
detections; FAT32 selects the patch by default, but the user retains control.

If WfW 3.11 networking is installed, the descriptor also detects `NDIS.386`
and applies the fast-CPU startup fix automatically. A missing driver is skipped;
an existing unknown binary is never modified. The 24-byte signature was checked
against all 20 WfW 3.11 language variants in the local 16-bit archive. GDI's
upstream attribution and audit procedure are in
[`docs/ndis386-cpu-speed.md`](https://github.com/geosone/gdi/blob/main/docs/ndis386-cpu-speed.md).

Setup asks whether Calmira should become the default Windows shell; the choice
is enabled by default. GDI's generic `[System.ini] Set=` transaction replaces
`[boot] shell=...`, records the exact former line in `%DIR%\SYSTEM.SET`, and
restores it on uninstall. If the administrator changes the shell again after
installation, uninstall preserves that later choice.

The descriptor also offers one application-language choice. All catalogues
share the same executable payload; GDI writes `[Language] Selected` in the
installed `CALMIRA.INI`. See [runtime languages](localization.md) for coverage
and limitations. The staging workflow uses UPX-packed FPC helper copies;
the complete shell and remaining payload still need a successful build.

## OpenLFN Loader and ZIP Preview

Option 5 installs `OLFNHOOK.DLL`, `OLFNLOAD.EXE`, `OLFNVIEW.EXE`,
`OLFNLIST.EXE` and `ARCINFO.TXT` together, beside the shell. It is off by
default and does not add automatic startup, replace Windows DLLs or change
the shell selection. Start `OLFNLOAD.EXE` explicitly; stop it only after
pending saves finish. Close the hook and all viewers before update/uninstall.
ZIP GUI acceptance is limited to enhanced Windows 3.1x on DOS 6.22;
DOS 7.x Windows helper startup is currently blocked safely.

The same payload can be built independently of the unfinished Calmira shell:

```sh
make openlfn-package GDI=../gdi
```

The result is `build/openlfn-package/INSTALL.EXE` with the standalone
`install/archive.ini` descriptor renamed to `INSTALL.INI` and a default target
of `C:\OPENLFN`. It performs no host configuration edits or binary patches.
The package uses four license prompts; the combined main descriptor uses six
(including Calmira and CTL3D), within GDI's nine-license limit.
License paths use DOS-safe names under `LICENSES`. `tools/stage_archive.py`
preflights all payload inputs and rejects symlink output redirection.
The main `make package` still requires a complete compiled shell.
See [viewer usage and limitations](archive_viewer.md).

Future combined media should compose independent descriptors rather than add
product branches to GDI:

- Calmira shell and LFN components;
- an LFN provider selected according to `docs/lfn_hosts.md`;
- EUSBASPI plus its VxD and safe-eject tools;
- AHCIASPI plus optional drive-letter and FastDisk components.

Each package must remain installable and uninstallable alone. A meta-package may
offer them as choices, but it should delegate their configuration to the same
generic INI mechanisms used by every other GDI product.
