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

For the GUI port, `make fpc-win16-gui-rtl` builds a separate complete RTL with
`-Wh` (huge code per unit), not just a replacement Classes PPU. This prevents
the Classes code from exceeding Win16's 64-KiB segment and avoids incompatible
large-/huge-code unit mixtures. The GUI RTL and every GUI program also use
FPC's huge data model (`WIN16_MEMORY_MODEL ?= Huge`, i.e. `-WmHuge`): each
unit's initialized data, VMTs and RTTI live in its own far data segment, so
DGROUP keeps only the startup header, stack and local heap. Output:
`build/win16-rtl/units-$(WIN16_MEMORY_MODEL)`; FPC also rejects PPUs of a
different memory model. Two startup defects of the pinned huge model are
patched by `fpc-win16-huge-startup.patch`: `prt0comn.asm` stored HInstance,
HPrevInst, CmdLine, PrefixSeg and SelectorInc DS-relative into DGROUP instead
of the system unit's segment, and `system.pp` read the task header (stack
bounds) through DS instead of SS. The small/medium/large startup objects are
byte-identical to the unpatched ones. A program with several writable data
segments runs as a single instance under Windows 3.x; starting a second copy
is refused by Windows rather than forwarded through HPrevInst. This GUI RTL
uses the opt-in `CALMIRA_WIN16_MESSAGE_ABI` dispatch adaptation as well.
It also enables `CALMIRA_WIN16_SJLJ_TAILCALL` for native exception round trips;
this compatibility option requires far code/data and is not enabled in the
ordinary helper RTL.
The GUI RTL also enables `CALMIRA_WIN16_REALLOC_BOUNDS`: suballocated
`ReAllocMem` copies only the smaller of the old and requested sizes. The pinned
implementation otherwise copies the entire old allocation into a smaller new
block, overwriting neighboring heap contents. `make win16-realloc-runtime-test`
checks an adjacent live guard, prefix preservation, small/global resizing and
nil/zero-size branches. This is a bounded-copy fix, not a redesign of allocation
failure semantics.
For Calmira's Delphi 1 sources the GUI RTL enables two further options.
`CALMIRA_WIN16_DOS_NO_STRINGS` gives the `dos` unit private StrLen/StrPCopy
instead of `uses strings`, because Calmira's own `Strings` unit has the same
name and one program cannot contain both. `CALMIRA_WIN16_DELPHI1_STRINGS` adds
the Delphi 1 short-string overload of `AppendStr`, whose var parameter must
match exactly.
Tracked RTL sources are fingerprinted and patched in private copies below
`build/win16-rtl/sources/`, not in the pinned checkout. See
[VCL port and native ABI tests](vcl_port.md).
`make calmira`
selects this RTL and the same `-Wh` setting. The original lean RTL remains
available for independent helpers.

`src/portable/` must compile on the native FPC host without Windows units.
Win16 APIs, DFM loading, segmented-memory details, and driver calls belong in
platform adapters. The original Delphi/VCL code remains a behavioral reference
while those adapters and forms are ported incrementally.

The Microsoft WinFile port uses its original C sources with OpenWatcom:
`make winfile16-core` builds the first modules, while `make winfile16` exposes
the remaining full-application dependencies. The earlier FPC drive demo is
now a separate `make drive-probe` / `DRVPROBE.EXE` diagnostic. See
[WinFile port status](winfile16.md); no finished replacement is claimed.
