# QEMU TCG ENTER Diagnostic

## Confirmed Local Emulator Error

The installed QEMU 10.2.3 TCG incorrectly sign-extends the 16-bit allocation
immediate of a 32-bit `ENTER` instruction. A small Linux i386 executable
reproduces this without DOS, Windows, DPMI, disk images or KVM. Native execution
of exactly the same executable gives the expected unsigned allocations:

| ENTER immediate | Native EBP − ESP | qemu-i386 10.2.3 EBP − ESP |
| --- | --- | --- |
| `7FFF` | `00007FFF` | `00007FFF` |
| `8000` | `00008000` | `FFFF8000` |
| `846C` | `0000846C` | `FFFF846C` |
| `FFFF` | `0000FFFF` | `FFFFFFFF` |

The upstream [10.2.3 decoder](https://github.com/qemu/qemu/blob/v10.2.3/target/i386/tcg/decode-new.c.inc)
declares ENTER's operands as signed immediates (`I,w` / `I,b`);
the [emitter](https://github.com/qemu/qemu/blob/v10.2.3/target/i386/tcg/emit.c.inc)
passes the decoded allocation directly to `gen_enter`. This agrees with the
local boundary test. A private 10.2.3 build with the allocation explicitly
converted to `uint16_t` now passes all four boundary cases. It is a local
diagnostic patch, not a claim about an upstream release or installed fix.

## Reproduction

```sh
sh tools/analysis/check_qemu_enter.sh
```

Requires x86 Linux with native i386 execution, NASM, GNU ld and `qemu-i386`.
The script retains its executable and both raw results under `build/tests/`.
Exit 0 means matching allocations, 1 means an emulation mismatch, and 2 means
the comparison could not be established. On the tested installation, exit 1
is the expected diagnostic result, not a failing repository unit test.

## Consequences for ZIP Acceptance

Under TCG, the unchanged helper returns 3 without an index on DOS 7.1 with
either tested VSHARE version. `LFN=N` instead returns 5. The DOS 6.22 control
reaches index writing and faults at code offset `1:495`.

Optional port-E9 instrumentation records `MTFLAOSDCZW` before that fault.
Watcom's disassembly shows `write_index` uses `ENTER 846Ch,0`; the crash stack
is displaced upward by 64 KiB relative to the intended frame, matching the
independent CPU probe. The DOS 7.1 path records `MTFLAOSDCZ`, so its precise
failure within archive parsing remains unlocalized.

These TCG ZIP results cannot qualify DOS compatibility until the emulator
error is removed and the complete matrix is rerun. Existing historical KVM
results are not substitutes. No host emulator, kernel module, production
viewer guard or Windows binary has been patched.

## Isolated Corrected Build

```sh
sh tools/analysis/build_qemu_enter.sh
PATH="$PWD/build/toolchains/qemu-enter/compiled:$PATH" \
  QEMU_DATA_DIR=/usr/share/qemu BRIDGE_CASES='archive cmdarchive' \
  WIN311_IMAGE=/path/to/private.img sh tests/dos/diagnose_dos_bridge.sh
```

The builder verifies the pinned release archive's SHA-512, applies
`tools/patches/qemu-10.2.3-enter-unsigned.patch` and builds only i386 user/system
emulators under ignored `build/toolchains/qemu-enter/`. It never installs them;
`-accel help` lists TCG only. Set `QEMU_SOURCE_ARCHIVE` if the verified tarball
is not in Gentoo's `/var/cache/distfiles/`; `QEMU_BUILD_JOBS` defaults to 8.
The source digest was independently compared with the local Gentoo Manifest.

Both direct and batch launches now produce valid two-entry indexes on the
DOS 6.22 control, with either VSHARE. DOS 7.1 is still inconsistent: the initial
old-VSHARE direct launch fails while its batch launch succeeds; the updated
VSHARE direct launch succeeds while its batch launch returns 3. Thus the
historical KVM VSHARE matrix is not yet reproduced as a stable TCG result.
The original helper was unchanged. Its warning 9004 also occurs on successful
runs and is not sufficient evidence of failure.

Private fixed-TCG evidence under `build/tests/`: `enter-check.AAoWsb` and
`enter-check.GbeMhe`; `dos-bridge.N4iKoF` / `u8pKI6` (DOS 6.22 new/old VSHARE),
`dos-bridge.xi6CWj` / `WBJHQL` (DOS 7.1 old/new VSHARE).
