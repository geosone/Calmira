# OpenLFN Loader

OpenLFN Loader is the independent GPL-3.0-or-later Win16 file-dialog component.
It works without the Calmira shell; Calmira bundles the same binaries, not a
separate product-specific implementation. This is an experimental build, not
yet a published standalone repository or stable release.

## Build and Package

```sh
make openlfn                         # hook and resident loader only
make openlfn-package GDI=../gdi       # standalone GDI package, with ZIP preview
make openlfn-dist GDI=../gdi          # deterministic OPENLFN.ZIP and SHA-256
```

The package is in `build/openlfn-package/`. OpenWatcom defaults to
`/opt/watcom`; JWasm/JWlink and the 7-Zip ZIP subset are built from pinned
sources. Building this component does not require Free Pascal, Delphi VCL or
a working Calmira shell build. GDI must already supply `build/INSTALL.EXE`.
The older `clfn-hook` and `archive-package` make targets remain aliases;
new packages use only the neutral filenames below.
`build/dist/OPENLFN.ZIP` contains only the eleven explicit package files under
`OPENLFN/`, not arbitrary contents of the build directory. Check it with
`cd build/dist && sha256sum -c OPENLFN.SHA`. This is a local experimental
binary bundle, not a public source release.

| File | Purpose |
| --- | --- |
| `OLFNLOAD.EXE` | Explicit resident owner, polling and safe stop |
| `OLFNHOOK.DLL` | Standard COMMDLG and verified Word/Excel SDM adapters |
| `OLFNVIEW.EXE` | Read-only ZIP contents window |
| `OLFNLIST.EXE` | Bounded 7-Zip ZIP reader for DOS/32A |

Run `INSTALL.EXE`, default target `C:\OPENLFN`. Start `OLFNLOAD.EXE` explicitly
in Windows. The installer neither changes the desktop shell nor adds automatic
startup. Finish pending saves, stop the loader and close viewers before
updating or running the installed `INSTALL.EXE /U`. Uninstall an older package
before switching package versions; in-place migration is not implemented.
The main Calmira installer offers the identical payload as option 5, off by
default. The standalone installer and user readme have independent branding.

## Verification

`make test` includes thirteen offline packaging/distribution checks, including
neutral branding, DOS 8.3 filenames, license/payload closure, symlink rejection,
reproducible ZIP contents and preservation of an older ZIP on build failure.
Native acceptance passes for explicit loader start/stop, legacy-hook rejection,
standard Open/Save and independent Word/Excel fixtures. Actual installed German
Word/Excel also pass missing-ZIP feedback, contents preview and cancellation.
GDI install/uninstall is tested at the new `C:\OPENLFN` destination without host
configuration changes. These tests use disposable image copies, never original
media. The DOS 7.x Windows guard remains in place.

## Scope and Compatibility

This is **not** a DOSLFN filesystem driver. DOS aliases and `DESCRIPT.ION`
provide display-name mappings; Save transactions use the existing `CLFN.*`
journal/recovery filenames for compatibility. Never rename or discard those
files blindly. The new hook refuses to start while the old `CLFNHOOK` module
is loaded; exit the old loader first. Do not run two versions concurrently.
The old internal journal signature is retained too; branding changes do not
invalidate an existing interrupted transaction.

ZIP GUI acceptance is on enhanced Windows 3.1x/DOS 6.22 with a 386+; DOS 7.x
Windows helper startup remains blocked. Standalone DOS 7.1 ZIP listing works.
Word/Excel typed new-name Save currently requires Enter in the filename edit;
mapping commit can require document close. Crash recovery is manual.
Native non-ZIP formats, extraction and Win9x acceptance remain open.
The DOS 7.1 ZIP failure is now isolated to its interaction with the older
VSHARE driver; a private driver-swap control makes the unchanged helper work.
This is not yet a production DOS 7.x enablement; see [diagnosis](dos71_diagnosis.md).

See [Save precautions](lfn_save_transactions.md), [Office tests](office_dialog_tests.md)
and [ZIP limits](archive_viewer.md). Separate GPL, 7-Zip, LGPL and DOS/32A
notices travel with the package. A public release must also provide the
corresponding sources/build instructions and pinned dependency/patch details;
renaming the installer alone is not a source release.
