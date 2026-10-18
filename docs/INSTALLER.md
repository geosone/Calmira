# Installer Architecture

The GeosOne DOS Installer remains a generic engine. No Calmira-specific code
belongs in `/home/mario/mars/gdi`; products describe themselves through an
`INSTALL.INI` and a staged file tree.

Calmira's descriptor is `install/INSTALL.INI`. `make package GDI=../gdi`
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

The descriptor intentionally does not replace `SYSTEM.INI`'s shell line because
GDI must first gain a generic, reversible “replace setting and restore on
uninstall” operation.

Future combined media should compose independent descriptors rather than add
product branches to GDI:

- Calmira shell and LFN components;
- an LFN provider selected according to `docs/LFN_HOSTS.md`;
- EUSBASPI plus its VxD and safe-eject tools;
- AHCIASPI plus optional drive-letter and FastDisk components.

Each package must remain installable and uninstallable alone. A meta-package may
offer them as choices, but it should delegate their configuration to the same
generic INI mechanisms used by every other GDI product.
