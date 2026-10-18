# Pinned OMF Build Dependencies

These source snapshots are part of the repository, not Git submodules. This
ensures a normal GitHub clone contains the exact assembler and linker needed
to build the project.

- `geosone-jwasm/` is `geosone/JWasm` branch `386max`, commit `e9462f1`.
  It adds the MASM 5.1 compatibility required by the legacy assembly sources.
- `geosone-jwlink/` is `geosone/jwlink` branch `386max`, commit `c3f7e93`.
  It combines GCC 14+ host fixes, Microsoft LINK compatibility, and Win3.x
  VxD output fixes.

The full revisions and origins are recorded in `LOCK`. Build both tools with
`make omf-toolchain`; generated files are written only below `build/`.

Both projects retain their upstream license files. Review
`geosone-jwasm/Html/License.html` and `geosone-jwlink/Ver/license.txt` before
redistributing modified binaries.
