# Installer Architecture

The GeosOne DOS Installer remains a generic engine. No Calmira-specific code
belongs in `/home/mario/mars/gdi`; products describe themselves through an
`INSTALL.INI` and a staged file tree.

Calmira's descriptor is `install/install.ini`. `make package GDI=../gdi`
builds and validates the compiled artifacts of one build tree and stages them
with GDI's `INSTALL.EXE` under `$(BUILD_DIR)/package/`; GDI's `gdicheck` then
checks the staged `INSTALL.INI`. A release uses the fixed compiler's tree
(`BUILD_DIR=build/class-pointer/...`), so no stale file from another build is
mixed in. It needs GDI 1.16.3 or newer: older versions ran out of near heap
writing the 5.5 KB `CALMIRA.INI`, loading `WIN.INI` during uninstall and
editing a SYSTEM.INI of a few KB, and kept `Remove=` text unexpanded.

`make package-runtime-test` installs the package silently on a copy of the
DOS 6.22/Windows 3.11 image with `COUNTRY=049`, checks every file, the
`shell=` line, DOSLFN and the German catalogue, starts Windows with the
installed shell, then uninstalls it and compares `SYSTEM.INI` and
`CTL3DV2.DLL` with the originals.

Windows does not search the shell's own directory when it starts the shell,
so `LFNFUNCS.DLL` goes to `%WINDIR%\SYSTEM` like in the original release.
`CTL3DV2.DLL` is shared: the Open386MAX build is installed there only when
Windows has none, and an existing one is never replaced. Without `Archive=`
GDI copies no `DIR\*` wildcard, so every file is listed by name. It also offers an opt-in, signature-checked WIN386.EXE patch
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
installed `CALMIRA.INI`. Since GDI 1.16 each choice lists the DOS/Windows
country codes of its language, so a German, Polish or Latin-American system
starts with its own catalogue selected. See [runtime languages](localization.md)
for coverage and limitations.

When Calmira is not chosen as the shell, GDI's `[ProgMan]` adds a "Calmira
Reloaded" group with the shell and its help; uninstall removes them again.
`MinWindows=3.1` stops setup early on Windows 3.0. The package ships the shell
and its helpers unpacked. UPX's NE wrapper runs a temporary copy under another
module name, so Calmira would not recognise itself as the Windows shell, and
UPX drops the resources of an NE program, so `EXPLORER.EXE` and the other
helpers had no icon. `tools/package.sh` checks each staged helper with
`tools/ne_has_icon.py`.

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
