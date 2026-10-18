# Compiler Toolchains

The port uses Free Pascal for Pascal, OpenWatcom for 16-bit C, and pinned
GeosOne JWasm/JWlink forks for OMF assembly and linking. Reference trees live
under `vendor/reference/` as pinned submodules; build dependencies are committed under
`vendor/build-deps/`; generated compilers and objects belong under `build/`.

## Gentoo host setup

Install the native bootstrap compiler and build tools:

```sh
sudo emerge --ask dev-lang/fpc dev-vcs/git sys-devel/make dev-lang/nasm
```

The Gentoo package currently supplies FPC 3.2.2. The pinned development source
is used for i8086 Win16 because that target continues to evolve. Build and
install it locally with:

```sh
WATCOM=/opt/watcom make fpc-win16-toolchain
```

Use `FPC_REBUILD=1` to force rebuilding an already installed cross compiler.

This first builds the repository's pinned OMF tools, then invokes
`tools/build_fpc_win16.sh` and installs under `build/toolchains/fpc-win16/`.
FPC emits OMF objects internally; its Win16 RTL startup files use
`nasm -f obj`, and its external linker driver calls the pinned JWlink through
the `wlink` compatibility name.
The build deliberately sets an empty `BINUTILSPREFIX`; otherwise FPC looks for
a nonstandard executable named `i8086-win16-nasm` instead of Gentoo's `nasm`.
It also uses `-CX` so the growing RTL is emitted as smart-linkable sections;
without it, the current development RTL exceeds Win16's 64-KiB code segment.

## OpenWatcom, JWasm, and JWlink

For the existing OpenWatcom installation:

```sh
export WATCOM=/opt/watcom
export PATH="$WATCOM/binl64:$WATCOM/binl:$PATH"
export INCLUDE="$WATCOM/h:$WATCOM/h/win"
```

Use `wcc -bt=windows` for 16-bit Windows C objects and `wcc386` only for
32-bit helpers. Build the assembler and linker selected for this project with:

```sh
make omf-toolchain
```

This compiles the vendored GeosOne sources and installs `jwasm`, `jwlink`, and
a `wlink` compatibility link under `build/toolchains/bin/`. The locked JWasm
revision adds MASM 5.1 compatibility. The locked JWlink revision includes
GCC 14+ host fixes, Microsoft LINK compatibility, and Win3.x VxD support.
OpenWatcom's linker remains a fallback for comparison and diagnostics.

Run `make toolchain-info` to show detected tools and pinned revisions, and
`make toolchain-smoke` to compile one 16-bit C object and one OMF assembly
object without producing a runnable program.

## Port boundary

`src/portable/` must compile on the native FPC host without Windows units.
Win16 APIs, DFM loading, segmented-memory details, and driver calls belong in
platform adapters. The original Delphi/VCL code remains a behavioral reference
while those adapters and forms are ported incrementally.

The first native application milestone is built with `make winfile16`. It
produces `build/winfile16/WINFILE.EXE`, a Windows 3.x NE executable with drive
enumeration and polling-based hotplug detection.
