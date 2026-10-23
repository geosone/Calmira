# DOS 7.1 Bridge Diagnosis

Current qualification: QEMU 10.2.3 TCG has a separately reproduced
[ENTER allocation error](qemu_tcg_diagnosis.md), independent of DOS/Windows.
The new TCG ZIP controls fail on DOS 6.22 as well as DOS 7.1, so they cannot yet
establish DOS compatibility. The VSHARE matrix below records the historical
KVM experiments, not a completed TCG acceptance run.

## Reproduced ZIP Failure

The tested DOS 7.1 profile does not fail to launch every DOS program. A tiny
COM and a bare MZ executable, with neither C runtime nor extender, both create
their marker files. A separate COM also completes DOS version querying and
memory-block shrinking. The production DOS/32A ZIP helper instead raises the
Windows system-integrity/general-protection dialog with the original sharing
configuration, producing no index.

The ZIP failure is isolated to the interaction between DOS 7.1 and the older
`VSHARE.386` in that profile. Swapping only that file for the privately supplied
Office update makes the **unchanged helper** produce a valid two-entry ZIP
index. The input ZIP and helper are identical in the four control experiments:

| Host | Original VSHARE | Office-updated VSHARE |
| --- | --- | --- |
| DOS 6.22 + Windows 3.1x | Valid ZIP index | Valid ZIP index |
| DOS 7.1 + Windows 3.1x | GPF, no index | Valid ZIP index |

Independent host decoding checked framing, lengths and CRC of each successful
index. This is a direct helper test, not full Open/Save/installer acceptance.
The exact failing instruction inside VSHARE has not been localized.

## Driver Identity Matters

Both files advertise `FileVersion=3.11` and device version 1.01. Their sizes and
SHA-256 values distinguish the actual tested binaries; the version string alone
is not a safe compatibility detector.

- Original, 14,925 bytes (copyright 1991–1993):
  `a48bc9d63a4b81b55f7d923e2723e713e0ecbd2d8d97b2da71491805b76dbaaf`
- Office update, 14,933 bytes (copyright 1991–1994):
  `47e2a3421ef7d2f7714d129f1724b648cb4c2d8ebb87b593ec993b5ec39baaac`

`SYSTEM.INI`, HIMEM, WIN.COM, WIN386.EXE, KRNL386.EXE, DOSX.EXE, SYSTEM.DRV,
WINOA386.MOD, VGA.3GR, IFSMGR.386 and VCACHE.386 compare byte-identically between
the baseline images. Besides the DOS boot files, VSHARE is the observed
difference among these Windows components. The controlled swap proves more
than a comparison of the two initially different installations.

Removing IFSMGR, VCACHE or VSHARE individually also allows the ZIP helper to
finish. That can disable part of the dependent file-access stack; it does not
prove that all three drivers independently contain a bug. Disabling Watcom's
LFN calls with `LFN=N` does **not** fix the original ZIP failure.

## Separate 16-Bit MZ Relocation Failure

Host qualification: both VirtualBox (`vboxdrv`, `vboxnetflt`, `vboxnetadp`)
and KVM (`kvm_intel`, `kvm`) modules were loaded on the investigation host.
The historical KVM results below are environment-specific observations, not
proof of a DOS defect. Module coexistence alone does not prove the cause either.
All VM runners now default to QEMU software emulation (`-accel tcg`); no host
modules are unloaded or reconfigured. Revalidate compatibility under TCG before
drawing product conclusions from KVM-only failures.

The second failure is **not a general C-runtime or heap failure**. Minimal
Watcom C and `malloc`/`free` probes reach `main` on DOS 7.1. Bare assembly MZ
controls also work with a nonzero entry IP, four relocations and an image over
8 KiB. The file-I/O C probe instead fails before `main` in some disk layouts.

A single-step startup trace shows a concrete failure mechanism: the instruction
loading DGROUP retains the file-relative operand `01B6`, instead of the runtime
segment `14D2` (`CS=131C` plus `01B6`). Startup subsequently loads this wrong
segment into ES and SS. This locates the immediate damage before C file-I/O
initializers; it does not yet identify the faulty loader instruction.

Exact-image replays distinguish placement from executable contents. All rows
below use the same C executable (SHA-256
`777b1c5a1f7ce1d3811b6bb0d08634f6ceba575ee1b034ee11314402c8566f5b`)
and `-cpu qemu32`. Each accelerator receives a separate copy of the prepared
image, and extraction after the run verifies the executable remains unchanged.

| File layout on the private DOS 7.1 image | KVM | TCG |
| --- | --- | --- |
| Original chain: 10748–10749, 10752–10753 | Fails before main | Reaches main |
| Identical file copied to 12394–12397 | Reaches main | Reaches main |
| New fragmented chain: 12394–12395, 12398–12399 | Reaches main | Reaches main |
| New chain, original directory slot | Reaches main | Not tested |
| Original chain, new directory slot | Fails before main | Not tested |

The last two controls exchange directory records or starting-cluster words
offline, leaving both payloads unchanged. Thus the failure follows the original
data-cluster chain, not its root-directory slot. Fragmentation alone is not
sufficient: an equivalently fragmented new copy works. Additional working
controls start at the last sector of a 63-sector track or cross a FAT-sector
boundary; neither boundary alone explains the original failure.

With the original chain preserved, updated VSHARE and removal of all three
file-access drivers still fail under KVM. Earlier `LFN=N` and `NO87=1` controls
also failed. This is separate from the ZIP helper's VSHARE interaction.
TCG is not a general ZIP workaround: its old-VSHARE helper control produced
no index, and a redirected launch reported DOS/32A warning 9004 and nonzero exit.

The remaining question is why this particular chain, Windows DOS loading and
KVM interact to leave a relocation unapplied. Copying a file is a diagnostic
control, **not a supported fix**. The general DOS 7.x production guard remains
unchanged; there is no claim of DOS 7.1 or full-dialog acceptance.

## Reproduce Safely

```sh
WIN311_IMAGE=/path/to/private.img make dos-bridge-diagnose
BRIDGE_CASES='mz steps' WIN311_IMAGE=/path/to/private.img make dos-bridge-diagnose
BRIDGE_VSHARE_FILE=/path/to/legally-supplied/VSHARE.386 \
  BRIDGE_CASES=archive WIN311_IMAGE=/path/to/private.img make dos-bridge-diagnose
# Preserve an already failing image instead of rebuilding/restaging it:
BRIDGE_SOURCE_IMAGE=build/tests/dos-bridge.EXAMPLE/real/test.img \
  sh tests/dos/replay_dos_bridge.sh
# Move only the test file in a disposable copy:
BRIDGE_RELOCATE_FILE=1 \
  BRIDGE_SOURCE_IMAGE=build/tests/dos-bridge.EXAMPLE/real/test.img \
  sh tests/dos/replay_dos_bridge.sh
```

The runner changes only disposable image copies under `build/tests/dos-bridge.*`.
`BRIDGE_NO_LFN=1`, `BRIDGE_NO87=1`, `BRIDGE_NO_VFAT=1` and
`BRIDGE_OMIT_DEVICE=ifsmgr|vcache|vshare` select diagnostic controls. These
options are not installer defaults or supported fixes. The diagnostic launcher
intentionally bypasses the viewer by invoking a DOS child directly; never run
it on a valuable live session. No original image or Windows file is patched.

Replay controls include `BRIDGE_FRAGMENT_FILE=1`, `BRIDGE_PAD_BYTES=N`,
`BRIDGE_ACCELS=tcg` (the default), and the VSHARE/
no-VFAT controls above. With `BRIDGE_RELOCATE_FILE=1`, choose either
`BRIDGE_SWAP_ENTRIES=1` or `BRIDGE_SWAP_CHAINS=1` to separate directory position
from payload location. The metadata editor accepts only disposable
`build/tests/.../prepared.img` files, rejecting symlinks and hard links.
`BRIDGE_TRACE_INIT=1`, `BRIDGE_ENTRY_TRACE=1` and the `relocprobe` case are
optional startup instrumentation in the diagnostic builder. Instrumentation
can alter placement; always retain an unchanged-image replay as a control.
An explicit `BRIDGE_ACCELS='kvm tcg'` enables the historical comparison only
when deliberately investigating an appropriate host; it is not the baseline.

`tools/analysis/compare_dos_hosts.py FIRST SECOND --output NEW_DIRECTORY`
records component hashes through read-only mtools extraction. Logs, extracted
Microsoft binaries and screenshots stay private in ignored `build/`.
No VSHARE binary has been added to the package or repository.

Private evidence: original profiles `dos-bridge.4vWxhZ` / `dos-bridge.SFfhBp`;
DOS 6.22 with original VSHARE `dos-bridge.T33ASb`; DOS 7.1 with Office VSHARE
`dos-bridge.O15hdv`; primitive controls `dos-bridge.ASVf5B`; CRT with updated
VSHARE `dos-bridge.iS2Kl6`. Each name is beneath `build/tests/`.

Startup trace: `dos-bridge.JXnp9X/startup-trace.log`. Exact-image replays:
`bridge-replay.ySNZY3` (original), `J4no0K` (copied), `p0ySAt` (fragmented),
`tItrqv` (original directory slot), `75adeb` (original chain/new slot),
`GAkZQz` (original chain/no VFAT), `xTjt0N` (original chain/new VSHARE).
Short names in that replay list share the `bridge-replay.` prefix.
