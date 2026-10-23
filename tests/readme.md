# Tests

`make test` builds the host Pascal test programs with Free Pascal and runs
Python `unittest` checks without network access. Historical RC/DFM fixtures are
the checked-in upstream trees. `fixtures/language_settings.ini` checks that
ordinary INI paths are not interpreted as language-catalogue escape sequences.

`make c-test` builds the portable Save transaction core with the host C compiler
and runs 283 checks over temporary directories under `build/tests/lfn-store.*`.
The injected IO layer simulates locked targets, write failures, failed publish
and failed rollback; original bytes and recovery backups are checked directly.
The same target also runs 1,706 archive-index checks: framing, CRC, UTF-8,
64-bit sizes, boundary cases and deterministic mutation tests.

For native language tests, first run `make drive-probe` (or `make pack-drive-probe`),
then use a legally supplied, prepared WfW 3.11 raw disk image:

```sh
WIN311_IMAGE=/path/to/win311.img LANG_CODE=de \
  sh tests/dos/test_language_win311.sh
```

Repeat with `en` and `fr`. Set `DRIVE_PROBE_EXE=$PWD/build/packed-probe/DRVPROBE.EXE` to test
the compressed prototype. These tests check localization, not file-manager
completeness. They copy the source image into unique directories under
`build/tests/`, retaining logs and screenshots for diagnosis. Required tools:
QEMU, mtools, OpenWatcom and the built JWlink. The default partition offset is
32256; override `WIN311_OFFSET` if necessary. All runners default to software
emulation (`-accel tcg`), without KVM. `QEMU_ACCEL` is an explicit diagnostic
override; do not enable KVM for the current VirtualBox-equipped host baseline.
No Windows images or binaries are checked in.

The installed QEMU 10.2.3 TCG currently fails an independent large-`ENTER`
allocation probe. Run `sh tools/analysis/check_qemu_enter.sh` before interpreting
new ZIP GUI failures as DOS incompatibility. Its expected mismatch exit 1 on
this installation is separate from `make test`. Current Pascal control/UI
acceptance below uses the isolated corrected emulator, not the installed binary;
it does not qualify the separate DOS 7.x archive-host matrix. See
[TCG diagnostic](../docs/qemu_tcg_diagnosis.md).

## Native UI acceptance batch

`make win16-ui` builds twenty-seven isolated control probes: image, image-progress UI,
label, original pie/graphic children, original gauges, original slider, modeless
form, managed window hierarchy, native button, original PicBtn/bitmap button,
button-progress UI, modeless dialog navigation, edit, checkbox, combined input
dialog, original incremental search, modal lifecycle, modal original search and
runtime multilingual original search captions, and original drag/drop resource,
modal and multilingual profiles, scoped Alt mnemonics/weak label focus targets,
and original selection-dialog behavior and multilingual profiles, plus original
password-dialog behavior/modal decisions and multilingual numeric-string profiles.
On the current QEMU 10.2.3 host, first build
the corrected private emulator using `sh tools/analysis/build_qemu_enter.sh`, then:

```sh
PATH="$PWD/build/toolchains/qemu-enter/compiled:$PATH" \
  QEMU_DATA_DIR=/usr/share/qemu WIN311_IMAGE=/path/to/baseline.img \
  make -j4 win16-ui-runtime-test
```

Each runner gets its own image copy and retained artifacts, allowing parallel
acceptance without modifying the baseline. The default accelerator remains TCG;
no KVM or VirtualBox module changes are needed. This batch complements `make
test` and tests only the listed subsets, not a finished shell or all VCL APIs.

The extended 38-suite batch also includes the window/input/paint/immediate-draw,
basic-loop and explicit-modal-loop foundations, private GUI stdio and original
component/stream/exception acceptance, shared diagnostic-buffer fault tests and
actual GUI diagnostic MessageBoxes and numeric resource-catalogue fallback. With the corrected emulator
environment above, run:

```sh
PATH="$PWD/build/toolchains/qemu-enter/compiled:$PATH" QEMU_DATA_DIR=/usr/share/qemu \
  GDI_TEST_SECONDS=30 WIN311_IMAGE=/path/to/baseline.img make -j4 \
  win16-ui-runtime-test win16-window-runtime-test win16-input-runtime-test \
  win16-paint-runtime-test win16-draw-runtime-test win16-loop-runtime-test \
  win16-modal-loop-runtime-test win16-gui-stdio-runtime-test \
  win16-gui-buffer-runtime-test win16-gui-diagnostics-runtime-test \
  win16-resource-text-runtime-test fpc-win16-classes-runtime-test
```

Avoid overlapping full batches. The 101-cycle font/label probe can exceed its
default 20-second TCG budget under additional load; a partial log without RESULT
PASS is a failed run, not acceptance. The 30-second setting changes only the run
budget, not checks, stack/heap sizes or the NE guard.

`test_compile_dfm.py` checks the strict build-time constructor compiler, including
all truncations of the original search resource, schema/type/range failures,
unsafe identifiers, unsupported components, event order and atomic CLI output.
`make win16-form-resources-report` records migration blockers for other DFM files.
The native search probes now use generated constructors, not copied layout data.
`win16-form-text-runtime-test` copies the actual English/German/French catalogues
and controlled INI edge cases into its private guest. One EXE tests language
selection, native captions/focus/recreation, English/default fallback, empty
values, escaped text and overflow rejection. The provider is restored before
its receiver is freed; it is not automatically lifetime-managed.

`win16-password-runtime-test` uses the original DFM/glyphs and bound locale
strings. It covers explicit create/change mode, initialization, username and
127-byte legacy storage limits, empty/long old values, modal Enter/retry/Escape/
close, owner restoration, native validation MessageBox and 20 resource cycles.
`win16-password-language-runtime-test` checks German/French/English in one EXE,
caption-independent decisions and rejection of partial initialization after a
provider error. Neither test modifies real accounts or password files.

`win16-resource-text-runtime-test` independently exercises numeric `[Strings]`
lookups, bound resources, English/caller fallback, empty/marker values, escapes,
truncation/expansion rejection and provider restoration. Portable
`test_legacy_password.pas` verifies the legacy ROT13/hex codec, not cryptographic
security. Native edit and password fixtures use 64-byte stack-bottom canaries in
addition to the static NE budget; they retain 4-KiB stacks/2-KiB heaps.

`pascal/diagnostics/test_win16_large_constructor.pas` is an intentionally failing
stock-compiler diagnostic, excluded from stock acceptance. The pinned i8086
compiler skips a constructor when a valid direct-allocated object has far offset
zero. See [the workaround and limit](../docs/vcl_port.md#original-password-dialog-and-numeric-strings).

### Corrected compiler acceptance

The existing installed compiler remains untouched. To build the isolated
correction and run the earlier 38 native suites, the class-pointer fixture,
six application-lifecycle/factory/window/activation fixtures, two screen fixtures,
two cursor fixtures, form-activation, form-resize, form-state, two idle fixtures and
application-exception, application-help, focused F1-help, two view-action fixtures
native/windowless coordinates, low-level/application drain, executable-identity
and mixed-control-children fixtures (64 configured total) against
matching RTL/test PPUs:

```sh
PATH="$PWD/build/toolchains/qemu-enter/compiled:$PATH" QEMU_DATA_DIR=/usr/share/qemu \
  GDI_TEST_SECONDS=60 WIN311_IMAGE=/path/to/baseline.img \
  make -j4 win16-fixed-regression
```

Results are built under `build/class-pointer/<compiler-fingerprint>/`; guest artifacts remain in unique
`build/tests/` directories. Do not overlap this with another full batch. A loaded
shared host can exhaust a 30-second window during the label redraw stress test;
60 seconds is the accepted rerun window, not a reduced assertion/iteration count.
A partial guest log without RESULT PASS is a failed run, even without a FAIL line.
The new
fixture tests runtime segment/offset comparisons, nil/Assigned/class references,
virtual/inherited constructors, failed-construction cleanup, balanced lifetime
hooks, large TComponent ownership and a stack canary. Synthetic pointers are
never dereferenced or freed. Host tests check nonmutating staging, cache
invalidation, license/provenance retention and failure cleanup. The old minimal
diagnostic's failure under the stock compiler is not a regression of the new
toolchain. See [compiler correction](../docs/vcl_port.md#corrected-i8086-class-pointer-comparisons).
The earlier compiler checkpoint logs are `build/tests/class-pointer-accepted-regression.log`
(39 native suites) and `build/tests/class-pointer-portable-regression.log`
(282 Python tests plus portable Pascal/C). The negative stock-compiler run is
retained separately in `build/tests/class-pointer-stock-native.log`.

The application layer adds `win16-application-runtime-test` and
`win16-application-dialog-runtime-test` to that corrected batch. The former
checks initialization, singleton/weak/owned registration, foreign-host rejection,
close/query/hide-error behavior, native system close, asynchronous signed quit,
main removal and startup/filter recovery. The latter checks Tab/default/Alt
routing across registered native forms, registry mutation during activation,
client-filter precedence, and startup-modal normal/quit/error cleanup. Both use
unchanged 4-KiB stacks/2-KiB heaps and 64-byte stack-bottom canaries. A successor
message is queued after WM_QUIT consumption; tests do not assume that
PostQuitMessage is an ordinary FIFO window-message post. See
[application boundaries](../docs/vcl_port.md#explicit-native-application-lifecycle).

The earlier application checkpoint passes all 41 native suites
(`build/tests/application-accepted-regression.log`) and `make test`, including
288 Python tests and portable Pascal/C
(`build/tests/application-portable-regression.log`). The separate full-shell
check remains blocked by missing `Forms`
(`build/tests/application-shell-build.log`); passing these fixtures does not
establish a working complete desktop.

The factory adds `win16-application-factory-runtime-test` (allocation, early/owned
constructor, AfterConstruction and registration failures; published references,
constructor guards, recovery, exact ownership cleanup and hidden-main startup)
and `win16-application-original-runtime-test` (the original DFM-generated
incremental-search dialog created during Run, search/Enter, empty Escape, modal
owner restoration, recreation and weak unregister). Both retain 4-KiB stacks,
2-KiB heaps and stack canaries. The larger password/application combination
failed native loading despite a passing static size guard; it is not an accepted
integration. See [factory scope and limits](../docs/vcl_port.md#class-reference-form-creation).

The accepted factory checkpoint logs are
`build/tests/application-factory-accepted-60s.log` (all 43 native suites) and
`build/tests/application-factory-portable-regression.log` (292 Python tests plus
portable Pascal/C). `build/tests/application-factory-label-check.log` also records
the isolated 60-second label rerun after the initial 30-second batch was truncated.
The full-shell check still stops at missing Forms
(`build/tests/application-factory-shell-build.log`).

The hidden transport adds `win16-application-window-runtime-test`: class-name
collision/recovery, lazy HWND identity, ANSI title/veto, method receiver identity,
newest-first hooks, nested sends, mutation/pump guards, exception diagnostics,
queued filtering, external HWND recreation and main close/veto behavior. The target
also builds APPSEND.EXE; `GDI_HELPER_EXE` makes the existing runner copy it only
into its disposable guest image. The independent task uses the original
TApplication/Calmira discovery and registered WM_CALMIRA contract to verify sent
vs queued delivery and signed results. It does not exercise shell command actions
or DLL hosting. The receiver keeps a 4-KiB stack/2-KiB heap and stack canary.
See [window transport scope](../docs/vcl_port.md#hidden-application-window-and-hooks).

The hidden-window checkpoint passes all 44 native suites
(`build/tests/application-window-accepted-regression.log`) and `make test`, including
298 Python tests and portable Pascal/C
(`build/tests/application-window-portable-regression.log`). The focused guard run
is `build/tests/application-window-guards.log`. The full shell remains blocked by
missing Forms (`build/tests/application-window-shell-build.log`).

The screen view adds `win16-screen-runtime-test` (weak binding, native front-to-back
order, lazy fallback, three-form bottom-of-pack cycling, nested/reparented/freed
focus, invalid indexes, rebind, teardown, actual metrics and resource retention)
and `win16-screen-modal-runtime-test` (registered/unregistered modal activation,
real EDIT focus, owner restoration, startup failure/recovery and signed quit).
Both retain 4-KiB stacks/2-KiB heaps and stack canaries. These are explicit,
read-only form-state queries, not global Forms.Screen, automatic activation
events or a screen canvas. Cursor tests are separate below. See
[screen-view boundaries](../docs/vcl_port.md#explicit-screenform-view).

The accepted screen checkpoint logs are `build/tests/screen-accepted-regression.log`
(all 46 native suites) and `build/tests/screen-portable-regression.log` (304 Python
tests plus portable Pascal/C). The focused two-profile check is
`build/tests/screen-focused.log`. `build/tests/screen-shell-build.log` records the
remaining missing-Forms failure; these view tests do not establish a complete shell.

`win16-cursor-runtime-test` adds actual cursor-handle/EDIT hit checks, child/parent/
screen priority, busy/none nesting, invalid/empty-stack retention, negative custom
IDs, borrowed-resource ownership, competing controllers, capture, callback guards,
teardown, display-count stability and resource cycles. The modal profile
`win16-cursor-modal-runtime-test` covers registered/unregistered popup scope,
owner/control separation, nonclient cursor preservation, startup errors and
signed quit while a cursor scope is outstanding. Both retain 4-KiB stacks,
2-KiB heaps and canaries. These are controlled native-message/pointer-position
tests, not physical-mouse tests or a complete Desktop port. See
[cursor scope and ownership](../docs/vcl_port.md#scoped-cursor-policy).

The accepted cursor checkpoint logs are
`build/tests/cursor-accepted-regression.log` (all 48 native suites, aggregate exit
0) and `build/tests/cursor-portable-regression.log` (312 Python tests plus portable
Pascal/C). `build/tests/cursor-guards.log` records the focused cursor/modal/input/
window checks. `build/tests/cursor-shell-build.log` still reports missing Forms;
passing these probes does not establish a complete Calmira shell.

`win16-application-activation-runtime-test` launches a separate visible Win16 task
and checks real application deactivate/reactivate notifications, task identity,
signed synchronous replies, same-task form-switch separation and root-pump
completion. Injected-message checks are explicitly separate: hook consumption,
native Active independence, correct Sender, event/transport/pump mutation guards,
event exceptions/recovery, resource retention, HWND recreation and cleanup.
Both EXEs retain 4-KiB stacks/2-KiB heaps; the principal probe checks its stack
canary. The runner installs this profile's helper only in its private image copy.
This does not qualify Application.Minimize or original AppHolder/Forms/DFM.
See [application activation](../docs/vcl_port.md#native-application-activation).

Accepted application-activation logs are
`build/tests/application-activation-final-regression.log` (52 native suites,
aggregate exit 0) and `build/tests/application-activation-portable-regression.log`
(330 Python tests plus portable Pascal/C). The four initial focused profiles
pass in `build/tests/application-activation-focused.log`; the complete final
batch additionally covers notification-HWND recreation before the real task
handshake. `build/tests/application-activation-shell-build.log` still reports
missing Forms; these APIs do not establish a complete Calmira shell.

`win16-idle-runtime-test` verifies the default blocking timer wait, explicit
Done=False work slices, queue/quit priority, bounded-pump separation, callback
exception recovery, modal conditions completed without posted input, inherited
provider guards, busy-parent suppression and explicit child-provider override.
`win16-application-idle-runtime-test` verifies handle-free registration, application
Sender/run flags, rebind/pump guards, root recovery and modal idle completion,
opening a modal from idle, signed modal quit and inherited idle exception cleanup.
Both probes retain 4-KiB stacks, 2-KiB heaps and stack canaries. See
[idle service contract](../docs/vcl_port.md#cooperative-idle-service).

Accepted idle logs are `build/tests/idle-final-regression.log` (all 54 native
suites, aggregate exit 0) and `build/tests/idle-portable-regression.log` (336 Python
tests plus portable Pascal/C). Four initial focused profiles pass in
`build/tests/idle-focused.log`; the complete final batch includes the additional
post-PeekMessage provider/termination guards. Existing native stack/heap budgets
and resource fixtures remain unchanged. `build/tests/idle-shell-build.log` still
reports missing Forms, so this is not a completed Calmira shell.

`win16-application-exception-runtime-test` checks explicit HandleException routing
from real active except blocks, borrowed object identity/subclass, unchanged
Sender/Message/HelpContext, RTL release exactly once, silent EAbort and rejection
of invalid/recursive calls. It verifies handler failure propagation/recovery and
existing native-window diagnostic boundaries without automatic global rerouting.
Real MessageBoxes exercise default presentation, explicit caller-owned
ShowException, application owner/title and guarded pump reentry during the
dialog. A contained native timer closes the actual button by its control ID;
it never synthesizes Enter or assumes IDOK. ANSI/NUL/truncation and empty-message
fallback are checked natively and in the portable formatter program. The probe
retains its 4-KiB stack, 2-KiB heap and stack canary. See
[exception contract](../docs/vcl_port.md#explicit-application-exception-handling).

Accepted logs are `build/tests/application-exception-final-regression.log`
(55 native suites, aggregate exit 0) and
`build/tests/application-exception-portable-regression.log` (341 Python tests plus
portable Pascal/C). Four initial focused profiles pass in
`build/tests/application-exception-focused.log`. Existing native budgets and
original resource fixtures remain unchanged. The complete shell still stops at
missing Forms in `build/tests/application-exception-shell-build.log`; this is not
full Forms/Application/DFM integration.

### Other native resource and runtime checks

`win16-children-runtime-test` checks the shared real TControl ancestor and mixed
ControlCount/Controls[] view. Its private Win3.11 image exercises real graphic
pixels, native/raw HWND operations, form lifecycle, direct-child identity,
independent component ownership, index errors and attachment order independent
of tab/paint order. Reparent callbacks inspect both lists before the model
transition; injected WM_CREATE failure checks the transitioned view and exact
old-position rollback. Deferred failure/retry, HWND recreation, independently
owned survivors, the original `while ControlCount > 0 do Controls[0].Free`
pattern and repeated resource cycles are included. The fixture retains 4-KiB
stack/2-KiB heap and a 64-byte stack-bottom canary. Existing control-view tests
exercise modal Hide through the new shared base. The public TControl API is
currently limited to Enabled/Visible/view operations; shared geometry/Font/hints
and complete original Forms integration remain open. See
[mixed-child contract](../docs/vcl_port.md#shared-control-identity-and-mixed-children).

Mixed-checkpoint evidence is not a fully passing aggregate:
`build/tests/mixed-controls-final-regression.log` exits 2, with 54 passing GDI
profiles and a password resource-cycle failure. The eight unrun GDI profiles
and separate classes fixture pass in `build/tests/mixed-controls-tail-regression.log`
(exit 0), covering all 64 distinct suites across batches with one unresolved
failure. Inspect individual artifact logs, not only aggregate PASS marker counts.
The initial four focus profiles pass in `build/tests/mixed-controls-focused.log`;
the final Enabled-loop addition is covered in the full run's child fixture.
`build/tests/mixed-controls-resource-focused.log` still fails password after
splitting the optional provider's return temporary off the bound-resource path.
This reduces its normal frame by 256 bytes but is not a demonstrated regression
fix. Diagnostic-only passing variants do not replace the normal failure.
`build/tests/mixed-controls-resource-observation.md` records the captured bad
Count/string bytes and reproducible saved EXE. Full Forms remains absent.
Final-source focused checks are in `build/tests/mixed-controls-final-focused.log`:
children, numeric resources and password-language pass; plain password fails
(aggregate exit 2). `make test` passes 392 Python tests plus portable Pascal/C in
`build/tests/mixed-controls-portable-regression.log`. Production trace code and
temporary cycle logging are removed; the intentional failure-hold source lives
only in ignored build artifacts.

Windowless Enabled acceptance extends the existing `win16-graphic-runtime-test`,
`win16-label-runtime-test` and `win16-mnemonic-runtime-test` profiles. Tests check
local/default/orphan state, visible disabled painting, system-gray label pixels,
preserved Font/color changes, hidden/show transitions, eligible duplicate
mnemonics and disabled-state retention across reparenting/native recreation.
Paint-time changes to self or siblings must reject before mutation and release
all canvas bindings. All three probes retain 4-KiB stack/2-KiB heap reservations
and now check the 64-byte stack-bottom canary; resource-cycle checks remain.

Final acceptance: `build/tests/graphic-enabled-focused-final.log` (these three
plus selection-language) and `build/tests/graphic-enabled-integration.log`
(image, form-text, view-order and F1 help), both exit 0 at GDI_TEST_SECONDS=60.
The largest selection-language probe still loads at 64,464 static NE bytes;
Enabled is public, not published, to avoid unnecessary property RTTI.
`build/tests/graphic-enabled-portable-final.log` passes 386 Python tests plus
portable Pascal/C, including typed Boolean Enabled assignments for labels/images
and continued rejection of graphic tab properties. The full 63-suite batch was
not rerun. `build/tests/graphic-enabled-shell-build.log` still fails at Forms;
at that checkpoint neither these tests nor local Enabled state established mixed
Controls[] support. The later shared-child implementation is described above.
See [enabled-state scope](../docs/vcl_port.md#windowless-enabled-state).

`win16-identity-runtime-test` compares ExeName/RuntimeExecutableName against
KERNEL's real loaded module, opens its NE header and checks bound icon resources.
It verifies lazy transport/form state, CWD independence, sent/help/exception
callbacks, read access after quit and a stack canary with 4-KiB stack/2-KiB heap.
`win16-identity-package-runtime-test` additionally packs/verifies the real EXE,
then runs plain/packed profiles from WINDOWS with separate IDENTPKG/TEMPPATH
directories in private TCG images. It mutates only that probe's temporary source
sidecar: CRLF, missing, relative, nonexistent, NUL, multiline and overlong inputs,
then restores the original. Override IDENTITY_PATH_PROFILE=packed for diagnosis;
default acceptance runs both profiles at GDI_TEST_SECONDS=60.

Use the matching corrected compiler/RTL profile above for the direct targets.
When sharing the existing pack tool, pass UPX_BUILD=build/tools/upx and
UPX="$PWD/build/tools/upx/upx". The pack target builds its UPX prerequisite;
pack_executables removes the tool-path UPX environment variable from each pack,
test and unpack child. Host tests cover all three calls, preservation of older
outputs on validation failure and rejection of changed round trips. The portable
runtime_path_text tests cover bounded buffers and allocation-free path helpers.
See [identity contract](../docs/vcl_port.md#executable-and-installed-package-identity).

Accepted final logs are `build/tests/identity-focused-final.log` (four native
profiles), `build/tests/identity-package-final.log` (plain/packed launches), and
`build/tests/identity-help-path-regression.log` (three existing WinHelp profiles),
each command exit 0. Focused/package profiles use GDI_TEST_SECONDS=60; the old
help-path runner keeps its normal timed schedule. `make test` passes 382 Python
tests plus portable Pascal/C, including 52 runtime-path cases, in
`build/tests/identity-portable-regression.log`. The 63-suite full batch was not run
at this checkpoint. The identity probe uses 55,536 bytes, retains 4-KiB stack and
2-KiB heap and passes its canary in plain/packed runs. F1/selection-language
budgets are 63,392/64,464 bytes. Full Forms/IconDlg/ExtractIcon integration remains
open; the separate shell log is `build/tests/identity-shell-build.log` (missing Forms).

`win16-drain-runtime-test` checks scoped draining of finite repost chains,
empty queues without idle/waiting, live filter changes, same/peer recursive
rejection, idle ancestry, error recovery, modal filter inheritance and signed quit
through suspended frames. A real HWND must not receive an original message after
its filter opens a modal child that consumes quit. Successors see queued sentinel
work without a reposted quit or stale active frame. An already terminated caller
keeps its first exit code across another terminating root.

`win16-application-pump-runtime-test` checks parameterless ProcessMessages from
an active operation handler: a real default-button click cancels work, modal
default routing remains scoped, owner state and root Run flags are retained,
and drained quit completes the root. Tests cover initialization, factory, idle,
sent-hook, help and exception guards, recursive calls and filter-error recovery.
Both probes retain 4-KiB stacks, 2-KiB heaps and stack canaries. Parameterless
drains have no message/time budget; continuously reposted work can keep them busy.
Existing bounded pumps are not made reentrant. See
[drain contract](../docs/vcl_port.md#parameterless-application-message-service).

The full 62-suite run passes in `build/tests/pump-final-regression.log`, aggregate
exit 0. It precedes the final DrainMessages-only sticky-exit guard. Final-source
acceptance for that guard and its new regression case is the four-profile native
run in `build/tests/pump-sticky-focused.log` (drain, application-pump, root loop,
modal loop), aggregate exit 0; the full batch was not repeated afterward.
`build/tests/pump-portable-regression.log` passes 372 Python tests plus portable
Pascal/C. Earlier focused/integration logs are `build/tests/pump-focused.log`
and `build/tests/pump-integration-focused.log`. Final new probe budgets are
51,360/62,912 bytes, with unchanged 4-KiB stacks and 2-KiB heaps and intact
canaries. Selection-language passes the full run at 64,464 bytes. Shell/Forms
and actual file-operation integration remain open (`build/tests/pump-shell-build.log`).

`win16-coordinates-runtime-test` checks live ClientToScreen/ScreenToClient on
windowed and windowless controls, including actual nonclient origins, external
native moves, reparenting and HWND recreation. It checks signed overflow,
orphan/handleless rejection without implicit HWND creation, graphic BoundsRect
virtual dispatch, zero-origin client rectangles and paint-mutation guards.
Hidden/disabled queries retain focus/capture, visibility, DC and child-window
state. The probe keeps a 4-KiB stack, 2-KiB heap and stack canary. Coordinates
require existing native origins; this is not a full deferred VCL hierarchy map.
See [coordinate contract](../docs/vcl_port.md#control-coordinate-conversion-and-graphic-geometry).

The coordinate checkpoint passes all 60 native suites with aggregate exit 0 in
`build/tests/coordinates-final-regression.log` and 366 Python tests plus portable
Pascal/C in `build/tests/coordinates-portable-regression.log`. Four focused
profiles pass in `build/tests/coordinates-focused.log`. The coordinate probe
uses 57,024 bytes of static NE data budget; selection-language remains at
64,464 bytes and passes. No stack/heap reservations or original resource fixtures
changed. `build/tests/coordinates-shell-build.log` still reports missing Forms
(make exit 2); these control methods do not establish a complete desktop.

`win16-control-view-runtime-test` checks real Show/Hide/BringToFront/SendToBack
behavior: deferred controls, generic-control references to forms, retained form
events, native child order without tab/bounds/focus mutation, descendant input
cleanup, callback guards/errors, active/iconic/disabled/hidden forms and generic
modal Hide with owner restoration. `win16-view-order-runtime-test` checks the
original bottom-of-pack NextForm policy using actual form methods and the live
screen view. Windowless order is verified through real overlap pixels, visibility,
paint guards and retained model order after parent recreation. Repeated real
composition checks GDI/USER pools, DC release, no child HWNDs and stable focus.
Both retain 4-KiB stacks, 2-KiB heaps and stack canaries. Native child order is
not a deferred or persistent tab-order policy, and graphics cannot be raised
above native child HWNDs. See
[control view contract](../docs/vcl_port.md#control-visibility-and-native-view-order).

Accepted logs are `build/tests/control-view-final-regression.log` (59 native
suites, aggregate exit 0) and `build/tests/control-view-portable-regression.log`
(361 Python tests plus portable Pascal/C). Four initial profiles pass in
`build/tests/control-view-focused-final.log`; four integration profiles with the
final resource-cycle checks pass in `build/tests/control-view-integration-focused.log`.
The existing selection-language probe still passes at 64,464 bytes; all native
stack/heap reservations and original resource fixtures remain unchanged.
`build/tests/control-view-shell-build.log` still reports missing Forms, so these
view methods do not establish a completed Calmira desktop.

`win16-help-key-runtime-test` compiles a test-only binary DFM through the actual
frontend and uses its generated constructor natively. Form/child/container
HelpContext values remain full-width and lazy; live parent changes and all-zero
contents fallback are checked. The probe exercises queued F1, current focus,
Shift/Ctrl/Alt state, system/keyup/repeat rejection, DLGC_WANTALLKEYS, root filter
priority, unregistered fallback, exactly-once consumption, current-form detach/free
and root/modal handler-error recovery with owner restoration. A queued F1 also
opens the rebuilt installed help in a separate WinHelp task and quits cleanly.
The runner copies help only into its private image; the probe retains its
4-KiB stack, 2-KiB heap and stack canary. See
[focused F1 help](../docs/vcl_port.md#focused-f1-context-help-routing).

Accepted logs are `build/tests/help-key-final-regression.log` (57 native suites,
aggregate exit 0) and `build/tests/help-key-portable-regression.log` (355 Python
tests plus portable Pascal/C). Four initial profiles pass in
`build/tests/help-key-focused-final.log`; four more including the final end-to-end
F1 probe pass in `build/tests/help-key-end-to-end-focused.log`. Original resources
and existing native budgets remain unchanged. `build/tests/help-key-shell-build.log`
still reports missing Forms; this is not a completed Calmira shell.

`win16-application-help-runtime-test` runs HelpCommand/HelpContext/HelpJump through
the actual application service. It checks handle-free registration/interception,
signed context and macro pointer data, handler/default Boolean results,
recursion/rebind/pump guards and handler failure recovery. The disposable runner
installs the rebuilt help under C:\HELPDOCS, not the current working directory.
The probe verifies foreign-task WinHelp visibility, numeric/context-string
requests without an error dialog, HELP_QUIT, reopening and silent application
teardown. Real missing-file dialogs exercise all three language catalogues,
application owner/caption, nested-call guards and actual native button IDs.
It retains the 4-KiB stack, 2-KiB heap and stack canary. Portable
`test_help_jump.pas` covers DOS separator escaping, maximum lengths and malicious
topic rejection. See [application help](../docs/vcl_port.md#application-winhelp-service).

Accepted logs are `build/tests/application-help-final-regression.log` (56 native
suites, aggregate exit 0) and `build/tests/application-help-portable-regression.log`
(346 Python tests plus portable Pascal/C). Four focused profiles pass in
`build/tests/application-help-focused-final.log`; the accepted wait uses the
native WinProcs.GetTickCount, not the generic clock used by the initial stalled
probe. No native budgets or original resource fixtures were reduced or changed.
`build/tests/application-help-shell-build.log` still reports missing Forms;
passing these service probes does not establish a complete Calmira shell.

`test_dfm_bitmaps.py` validates the original glyphs, bounded 4-bit Delphi bitmap
streams, generated RT_BITMAP resources, wrong palettes/lengths/frame counts,
image loading/AutoSize order and CLI sidecar safety. `test_win16_resource_forms.py`
guards the original Delphi branch, idempotent PicBtn loading, lightweight label/
provider dependencies and catalogue merges that retain existing translations.

The original drag/drop profiles use bound generated bitmap resources, not a
rewritten form: native pixels and both glyph policies, 20 lifetime cycles, copy/
move/cancel via queued keys/mouse, owner restoration and three runtime languages
are split across independent EXEs, all with 4-KiB stacks/2-KiB heaps. No file
operation is performed by these decision-dialog tests. The new open cancellation
glyph is not extracted from the old compiled Delphi resources.

`win16-gui-stdio-runtime-test` checks the private runtime's 256-byte ANSI filename
fields and unchanged 256-byte buffers, shared Output/StdOut/ErrOutput/StdErr
redirection and restoration, and explicit Text files across 600-byte boundaries.
The shared GUI diagnostic channel is not independent DOS stdout/stderr. The
private patched RTL must be rebuilt consistently; the pinned checkout stays clean.

The experimental system-wide Open/Save hook has a passing native acceptance
test: `WIN311_IMAGE=/path/to/win311.img make clfn-hook-runtime-test`.
It exercises a separate task, Open/new long-name Save/Cancel, application hooks
and FILEOK veto, collisions, typed names outside the active filter, tab order,
restoration after unhook and preserved files/existing map bytes. It also checks
that missing files gain no mapping and that pending saves prevent unloading.
See [file dialog test status](../docs/file_dialog_tests.md) for manual ClarisWorks
results and limitations. The fixture also covers
OEM-to-ANSI umlauts in both existing descriptions and newly saved names.

`WIN311_IMAGE=/path/to/win311.img make clfn-office-runtime-test` uses independent
SDM-shaped fixtures to check both Office class/ID profiles, explicit Enter,
new/existing names, cancellation and validation veto. These are not Microsoft
Office binaries. Actual Word/Excel manual results and remaining limits are in
[Office tests](../docs/office_dialog_tests.md). `make window-inventory` builds
the read-only native observation helper; its logs can contain edit contents
and must remain private.

`make archive-host-test` separately builds the pinned 7-Zip host reference
(tested with Gentoo LLVM 22) and runs eight generated-fixture archive tests.
It is deliberately outside `make test`, requires initialized upstream sources
and a host C++ toolchain, and does not establish DOS/Win16 archive support.
See [archive porting status](../docs/archives.md).

`make archive-reader-host-test` builds the actual bounded ZIP helper and checks
13 generated fixtures, unchanged inputs, output preservation, oversized files
and nonblocking rejection of FIFOs. For ASan/UBSan, build with
`ARCHIVE_SANITIZE=1 ARCHIVE_BUILD_DIR=$PWD/build/archive-reader-asan sh tools/build_archive_reader.sh host`,
then run `ARCHIVE_READER=$PWD/build/archive-reader-asan/clarclst python3 tests/archive_reader_acceptance.py`.
Use `UBSAN_OPTIONS=halt_on_error=1 ASAN_OPTIONS=detect_leaks=1` when testing.

Native archive checks use disposable image copies, never the originals:

```sh
WIN311_IMAGE=/path/to/dos71-win311.img make archive-dos-runtime-test
WIN311_IMAGE=/path/to/dos622-win311.img make archive-preview-runtime-test
ARCHIVE_EXPECT_BLOCKED=1 WIN311_IMAGE=/path/to/dos71-win311.img \
  make archive-preview-runtime-test
```

The DOS runner checks eight accepted indices and rejected malformed/over-limit
inputs. The Win16 test invokes the actual common-dialog system-menu command,
checks escaped names and read-only status, cancels the original dialog, and
verifies unchanged ZIP bytes and temporary-file cleanup. The blocked-profile
variant checks that DOS 7.x starts no helper. This runner covers COMMDLG;
actual Office uses the separate private-media test below.

`WIN311_IMAGE=/path/to/dos622-installed-office.img make archive-office-runtime-test`
launches the real installed Word/Excel applications from legally supplied
media, not SDM fixtures. It checks missing-ZIP feedback, valid ZIP listing,
unchanged filename edit and ZIP bytes, no Save sidecars, cancellation and
clean hook teardown. The supplied German startup profile requires Word/Excel
under `C:\MSOFFICE`, `C:\SHARE.EXE`, and no pre-existing `C:\ARCDATA` directory;
see [Office test details](../docs/office_dialog_tests.md). Logs/screenshots stay
private under ignored `build/tests/archive-office.*`.

Thirteen offline package tests in `make test` cover payload/descriptor closure,
DOS 8.3 names, license files, disabled-by-default installation, absent inputs
and symlink rejection, neutral branding, deterministic ZIP contents and failed
archive preservation. `make openlfn-package` builds the actual GDI add-on;
`make openlfn-dist` also creates `build/dist/OPENLFN.ZIP` and `OPENLFN.SHA`.
Use `ARCHIVE_PACKAGE=$PWD/build/openlfn-package` with the preview runner to
exercise the staged copies instead of compiler outputs.
`WIN311_IMAGE=/path/to/dos622-win311.img make archive-package-runtime-test`
tests the real GDI DOS installation and uninstall in a disposable disk copy,
checking all 11 installed files byte-for-byte and unchanged host configuration.
The fixture requires no existing `C:\OPENLFN` or `C:\ARCSRC` directories.
This does not establish Win16/Win9x installer-frontend acceptance.
The preview runner additionally starts/stops the actual `OLFNLOAD.EXE` and
checks its neutral title and unloaded hook before testing the ZIP dialog.
The standard/SDM hook runner loads an inert legacy-named DLL to verify that
OpenLFN refuses a competing old module and starts normally once it is unloaded.

For the actual Microsoft WinFile source port, run:

```sh
make winfile16-core
WIN311_IMAGE=/path/to/win311.img make winfile16-core-runtime-test
```

The native runner links the original `lfnmisc.c`, `wfmem.c` and `numfmt.c`
modules, checking 17 behaviors including a 1,500-entry directory beyond 64 KiB
and formatting above 4 GiB. This is not a complete GUI acceptance test. The full
`make winfile16` target is expected to fail until the remaining Win32
application dependencies have been ported.

`WIN311_IMAGE=/path/to/private.img make dos-bridge-diagnose` is a diagnostic,
not a supported workaround or normal acceptance test. It runs bare COM,
16-bit CRT and DOS/32A ZIP children in disposable copies, retaining marker
files, launch logs, CPU registers and screenshots. Optional `mz`/`steps`
cases isolate basic MZ loading, DOS version queries and memory shrinking.
Driver/environment controls and the confirmed VSHARE matrix are documented in
[DOS 7.1 diagnosis](../docs/dos71_diagnosis.md). The production viewer guard
and original disk images remain unchanged.

`tests/dos/replay_dos_bridge.sh` reuses a previously generated private image
without recompiling the child. Set `BRIDGE_SOURCE_IMAGE` to its `real/test.img`;
the default runs TCG only. An explicit `BRIDGE_ACCELS='kvm tcg'` selects a
comparison on a suitable host using copies of identical prepared contents.
Optional placement controls distinguish file contents, fragmentation,
directory position and data-cluster location. See the diagnosis for the control
matrix and limitations. Host tests cover layout-preserving startup probes and
the disposable-image directory editor; neither tool is a production patcher.

## WinHelp regression checks

`test_help_build.py` builds from the maintained RTF and BMP inputs without
network access or proprietary fixtures. It checks deterministic output,
inherited contexts, native table text offsets, embedded branding, documented
extensions, direct guide links in all seven contents views, complete topic
reachability, and safe failure on missing bitmaps. Graph fixtures cover cycles,
orphan topics and invalid destinations. Its historical comparison
uses the already archived Reborn HLP in `vendor/upstream/`.

`WIN311_IMAGE=/path/to/baseline.img make help-runtime-test` additionally needs
a privately supplied, installed Windows 3.1x raw disk image with Windows in
`C:\WINDOWS`. The default partition offset is 32256 bytes; override with
`WIN311_OFFSET`. Only temporary image copies are written. QEMU defaults to
TCG. Inspect the eight screenshots alongside the WinHelp-call/window logs;
automated window detection is not a rendering assertion. See `docs/help.md`.

Help builds additionally validate binary DFM `HelpContext`/`HelpFile` properties
and literal Pascal help jumps against the compiled HLP. Fixtures reject unknown
contexts, filenames and targets; source regressions ensure the two Contents
menu handlers do not dereference `ActiveControl`. The native `W` profile tests
the Computer popup's numeric alias 201 independently of the unfinished shell.

`WIN311_IMAGE=/path/to/baseline.img make help-path-runtime-test` builds a native
FPC probe, verifies UPX integrity and lossless unpacking, then runs both variants
in private image copies. Help exists only in `C:\HELPPKG`, while the wrapper
extracts to `C:\TEMPHLP`. Logs must show the installed help path; the packed
case must also show a temporary UPX module path. Inspect both screenshots for
the contents page. A third, uncompressed `missing` profile loads the German
catalogue and shows the expected missing-file message; the monitor dismisses
the dialog only after its screenshot. This exercises the shared runtime resolver and help service, not the full
VCL shell; `test_help_paths.py` guards its `TAppHolder` source integration and
the unchanged legacy Delphi branch. Use TCG and the same emulator precautions
described above. Required toolchains are FPC Win16, JWlink and the pinned UPX.

`make help-service-test` builds the real service with host-only recording API
substitutes from `tests/pascal/help_stubs/`, isolated in a separate unit-output
directory. It checks missing/empty paths, successful/failed WinHelp returns,
all three translated errors, long paths, preserved arguments and silent quit.
It does not emulate Windows message dispatch or prove the full VCL event bridge.

## Native Win16 message ABI

`make win16-messages` builds a real API/typed-handler probe with the private
huge-code RTL. `WIN311_IMAGE=/path/to/baseline.img make win16-messages-runtime-test`
uses a disposable image copy and TCG, checking `MSGTEST.LOG` for every handler
result. No Windows media is supplied. `QEMU_DATA_DIR` can point to the BIOS
directory when using a private emulator build.

`test_win16_messages.py` checks owned message-type coverage, source/license
provenance and fingerprinted RTL preparation in a temporary Git fixture.
It verifies caching, changed-source invalidation and unchanged input files.
See [VCL port](../docs/vcl_port.md) for the message convention and the scoped
`CALMIRA_WIN16_MESSAGE_ABI` compatibility patch. Full Forms remains missing.

## Native GDI foundation

`WIN311_IMAGE=/path/to/baseline.img make win16-gdi-runtime-test` compiles and
runs a real memory-DC/color-bitmap probe with the private huge-code RTL. It
checks line/rectangle/pixel/text drawing, copied resource state, caller DC
restoration, input errors and 300 resource-change/reload cycles. It also checks
BMP file/resource pixel equality, named/numeric resources, 1/8/24-bit fixtures,
scan-line loading beyond 64 KiB, blitting and transactional load failures.
`bitmap_fixtures.py` generates tiny known-color inputs and a larger 8-bit image;
the existing shutdown image is also loaded. WRC embeds two existing BMPs in the
probe. `make fpc-test` checks the portable parser with range/overflow checking,
malformed headers and all repository BMPs. Unsupported formats are documented
in [VCL port](../docs/vcl_port.md). Only image copies
are written; the runner defaults to TCG and reads `GDITEST.LOG`. Optional
`GDI_TRACE=1` retains a QEMU interrupt trace for diagnosis. The raw Win16 file
logger preserves the last completed step even if the tested runtime crashes.
`GDI_TEST_SECONDS` adjusts the software-emulation run budget (default 20 seconds,
accepted range 1..60); missing final results remain failures, not skipped checks.

Native bitmap-editing checks cover deep `Assign`, separate handles/pixels,
grow/shrink with preserved overlap and white new areas, pending zero dimensions,
invalid operations and same-size self-assignment. `CopyRect` tests inspect
subrectangles, scaled quadrants, overlapping self-copy, restored stretch/raster
state and oversized/mirrored/nil-source rejection. A strip-growth test models
the original start-menu image list. The 300-cycle resource guard also performs
bitmap clone/grow/shrink; it is not a precise leak measurement.

The same probe checks generic bitmap/icon drawing, independent copied icons,
shared-resource lifetime, named/numeric icon resources and direct `DrawIcon`
pixel equivalence. A generated monochrome ICO contains transparent, black,
white and inverted stripes; inverted colors are device-palette dependent.
Color-key checks cover transparency versus brush replacement, scaling, overlap,
clipped source pixels, hatch alignment, unchanged sources and caller DC state.
A 100-cycle icon/compositing check guards against coarse GDI-pool drain.

The combined probe explicitly reserves a 4-KiB stack/local heap; far Pascal
allocations use the global heap. `check_win16_budget.py` checks its final NE
header against a conservative 64-KiB data/stack/local-heap budget at build time.
`test_win16_budget.py` includes the previously failing native budget and malformed
header fixtures. This guard is not a complete NE validator or native OOM test.

`test_win16_gdi.py` guards the scoped API, enum order and native-test coverage;
it is not a host emulation of GDI. The component runtime probe additionally
tests native raise, re-raise and finally with the scoped
`CALMIRA_WIN16_SJLJ_TAILCALL` RTL patch. See [VCL port](../docs/vcl_port.md).

## Public Graphics API

`make win16-graphics` builds a separate probe using `Graphics` and the unchanged
original `vcl/calcolor.pas`. Run it with
`WIN311_IMAGE=/path/to/baseline.img make win16-graphics-runtime-test`.
It reuses the private-image GDI runner; `GDITEST.LOG` records checks for Win16
rectangle/point layout, Rect/Bounds, public typed bitmap canvases, the original
bitmap-argument BrushCopy, derived resource constructors, resize/assignment,
point-size fonts and copied resource properties. Named/numeric resources,
embedded-NUL rejection and public/extended color conversion callbacks are also
checked. Raw native resource handles remain borrowed.

`test_color_names.pas` runs offline with range/overflow checking in `make test`:
39 named-color round trips, unsigned system-color hex, invalid names and
positive/negative/64-bit-hex overflow. `test_win16_graphics.py` checks public
color-table agreement and guards scope/record declarations; these structural
checks do not replace the native probe. Graphics DFM/stream serialization remains
intentionally absent, not a fake success.

## Native image ownership

`make win16-handles` builds a public Graphics probe for writable image handles.
`WIN311_IMAGE=/path/to/baseline.img make win16-handles-runtime-test` runs it in
a disposable image copy using the GDI runner. Tests check native handle identity,
replacement/destructor deletion, self-assignment, failed transfer preserving
both old image and caller object, borrowed-copy pixel equality and lifetime,
detach/reattach and shared/private icon resource behavior. `Handle := 0` must
delete rather than detach. `ReleaseHandle` returns a live caller-owned resource.
The 150-cycle GDI/USER pool checks are coarse guards, not complete leak proofs.

`test_win16_handles.py` checks conditional source migrations: shared `LoadIcon`
uses safe copies in FPC paths, the old Delphi path remains, ShrinkBitmap copies
its borrowed input inside try/finally, and extraction sentinels are guarded.
Taskbar glyph loading must free only private extractions, never class icons.
These source guards do not execute the unfinished Forms/Controls UI modules.

## Picture container

`make win16-picture` builds a separate public `TPicture` probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-picture-runtime-test` uses the GDI
runner and a private image copy. It checks empty metadata without allocation,
typed getter switching, deep bitmap/icon/property/picture assignment and borrowed
child lifetimes. Managed pixel/fill/line/rectangle/text/copy/color-key/Draw calls
must forward a picture event after commit; positioning, measurement and known
zero-area copies must not. Unsigned SetPixel failure handling is checked with
a clipped pixel write.

Error checks cover unsupported graphics, invalid persistent assignments, failed
BMP loads, callbacks that raise, recursive replacement rejection and teardown
without callbacks. Failed release notifications must not orphan a native handle.
The 150-cycle switch/copy/clear test checks GDI and USER pool percentages only;
it is not a complete leak/OOM proof. `test_win16_picture.py` guards these API and
native-test paths structurally, without pretending to emulate GDI on the host.
ICO/DFM streaming and actual TImage/Forms integration are still missing.

## Native window lifecycle and dispatch

`make win16-window` builds the native `TNativeWindow` foundation probe.
`WIN311_IMAGE=/path/to/baseline.img make win16-window-runtime-test` runs it using
the same disposable-image runner as the GDI probes (log `C:\GDITEST.LOG`).
Checks cover per-HWND far-pointer association before WM_CREATE, nonzero/high
WPARAM and signed LPARAM/results, nested SendMessage and reentrant child creation,
DefWindowProc/default close, callback exception containment and recovery,
duplicate/invalid creation, parent-triggered child destruction, handle recreation
and TComponent owner cleanup. WM_CREATE/WM_NCCREATE rejection and an exception in
WM_NCDESTROY must leave no stale object handle. A coarse USER-pool guard covers
150 successful and 100 rejected creation cycles. These are native window tests,
not full Controls/Forms or input/paint/DFM acceptance. `test_win16_window.py`
checks ABI/lifecycle source guards; it is not a host window emulator.

## Native paint transactions

`make win16-paint` builds the scoped `TNativePaintWindow` probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-paint-runtime-test` runs it in a
disposable image copy. The probe creates a visible popup and reads actual window
pixels using a separately acquired/released inspection DC. Checks cover Color
backgrounds, drawing via Graphics, partial and disjoint update clips, PaintRect
bounds, EndPaint validation, empty messages and nested WM_PAINT. A raised Paint
exception must leave Canvas.Handle zero, reset Painting, validate the update
and still allow later drawing. Empty/invalid invalidations, detached-window
repaint and out-of-paint canvas errors are checked. There are 150 normal/failing
paint cycles with coarse GDI/USER-pool guards. This is not full Controls/Forms,
external-HDC painting or outside-Paint control-canvas acceptance.
`test_win16_paint.py` supplies source guards, not host window emulation.

## Scoped immediate drawing

`make win16-draw` builds the explicit DrawNow probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-draw-runtime-test` runs it in a
private image copy. It checks visible-window pixels outside Paint, nested GetDC
scope state restoration, WM_PAINT arriving during immediate drawing, DrawNow
inside Paint retaining its update clip, pending updates surviving immediate
drawing, and later authoritative WM_PAINT. Direct exceptions propagate only after
canvas/DC cleanup; input-callback failures use the existing native boundary.
Mouse-driven drawing must remain usable after failure. There are 150 normal/
failing scopes with coarse GDI/USER-pool checks. Nil callbacks, detached windows
and cached-HDC-free teardown are covered. `test_win16_draw.py` guards ownership
and reentrant binding paths; it is not host GDI emulation or unchanged-slider
acceptance. Arbitrary Canvas access outside these explicit scopes still fails.

## Native keyboard, mouse, focus and capture

`make win16-input` builds `TNativeInputWindow` tests;
`WIN311_IMAGE=/path/to/baseline.img make win16-input-runtime-test` runs them in a
disposable VM copy. Keyboard/mouse cases send synthetic messages through actual
HWNDs: signed coordinates, button/Shift/Ctrl/Alt flags, double-down markers,
mutable/consumed keys, system-key identity, ANSI high bits and unchanged packed
DBCS forwarding. Keyboard state is saved/restored. Focus/capture checks use
actual USER transfers, OnEnter/Exit, disabled ancestors, hidden/detached windows,
peer capture preservation and destruction cleanup. Callback exceptions must be
recorded while later input remains usable; 150 capture/input cycles check coarse
USER-pool stability. These tests do not simulate physical keyboard input through
a message pump or provide full Controls, Tab order, click/drag, IME or accelerator
acceptance. `test_win16_input.py` adds ABI/API scope guards only.

## Original slider acceptance

`make win16-slider` compiles the actual `vcl/slider.pas` against the initial
Controls subset. `WIN311_IMAGE=/path/to/baseline.img make win16-slider-runtime-test`
uses the private-image runner. The probe's 4-KiB stack/2-KiB local heap is native
tested; a former 4-KiB heap failed to load near the segment limit even though the
budget guard passed. Checks inspect real vertical/horizontal thumb pixels,
precreation values, immediate updates/OnChange, partial-paint cache recovery,
arrow keys, actual focus/capture, drag arithmetic and extreme signed coordinates,
checkerboard colors, stolen capture, resized backing surfaces, geometry guards,
visibility/enabling (including capture release) and dialog-code arrows. There
are 100 redraw/resource cycles.
Point hit testing is performed by the typed adapter (right/bottom exclusive),
not the failing foreign POINT-by-value API call. Keyboard/mouse messages are
synthetic; this is not a physical-input/application-loop or Forms/DFM test.
`test_win16_slider.py` guards supported APIs, FPC ownership/geometry paths and
retained Delphi conditionals. Unsupported legacy properties are excluded from
the FPC build, not implemented as no-ops. Other original controls remain unported.

## Windowless graphics and original pie acceptance

`make win16-graphic` builds the actual Win95Pie component plus an oversized
test graphic; `WIN311_IMAGE=/path/to/baseline.img make win16-graphic-runtime-test`
runs the private-image probe. Children must allocate no HWNDs. Checks cover
translated/clipped pixels, original 0%/100% pie rendering, value/depth bounds,
and pie-shadow partial/full pixel equivalence (direct clipped FloodFill failed
this check; full-child temporary buffering is required),
immediate parent underlay drawing, partial updates, move/hide/reparent cleanup,
overflow rejection, paint errors, mutation guards in paint and immediate scopes,
parent destruction detaching surviving children and 101 chart redraws with coarse
GDI/USER pool checks. Child and parent canvas bindings must be cleared even on
exceptions. The source's Delphi conditional path is guarded separately.
`test_win16_graphic.py` checks composition/ownership structure, not host GDI.
This does not test transparent graphics, mouse routing, alignment, inherited
ParentColor or Forms/DFM. The test uses a 4-KiB stack and 2-KiB local heap.

## Windowed hierarchy and bounds

`make win16-hierarchy` builds the managed-parent/bounds probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-hierarchy-runtime-test` uses the
disposable-image runner. Checks cover model-only children, recursive HWND creation,
parent-client coordinates, decorated outer/client dimensions, BoundsRect, external
USER moves/resizes, live reparent preserving descendant HWNDs, focus/capture release,
cycle/overflow rejection, detached subtree bounds, native recreation and parent
object destruction. Failed automatic/deferred child creation must clean partial
HWNDs while preserving rollback/retryable models. Drawing-time mutation is rejected;
200 native reparent operations check coarse USER-pool stability. The probe uses a
4-KiB stack and 2-KiB local heap. `test_win16_hierarchy.py` guards supported APIs
and cleanup paths. Rare USER positioning/rollback failures are source-guarded,
not fault-injected; alignment, DFM, Tab order and full Forms are not tested.

## Native task message loop

`make win16-loop` builds an independent message-loop probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-loop-runtime-test` runs it in a
private image copy. Real posted window messages check bounded/nonblocking queue
handling (including self-posting callbacks), remaining-message delivery,
window close without implicit task termination, rejection of same/different-instance nested
pumps, callback-error recovery and 100 repeated pump scopes. Posted key messages
must produce WM_CHAR through actual TranslateMessage. A native window timer wakes
the blocking GetMessage loop and posts a negative WM_QUIT exit code. Both blocking
and nonblocking pumps must retain termination without consuming later queue items
or reposting WM_QUIT; an explicit successor can continue after the pump returns.
The probe uses a 4-KiB stack and 2-KiB local heap. `test_win16_loop.py` adds API and
scope guards, not emulated USER behavior. This basic loop probe does not imply
full application/Forms, modal-form, accelerator or physical-keyboard acceptance;
explicit modal loops have separate tests below.

## Original progress gauges

`make win16-gauge` builds the original BarGauge/Win95Gauge components;
`WIN311_IMAGE=/path/to/baseline.img make win16-gauge-runtime-test` runs their pixel
probe in a private TCG-only image. Tests verify no child HWND allocation, virtual
segment sizing through base references/properties, horizontal/vertical zero/full
fill, explicit gaps/margins and cleanup after decreasing progress. Solid bars
must fill vertically from the bottom, draw actual percent glyphs and borders,
and reset the transparent brush used by text. Further checks cover the complete
signed 32-bit range, saturating wide addition, range-setter clamping, inverted
range rejection, zero-span percentages, original direct out-of-range ignore
behavior and tiny/invalid geometry. All canvases must detach; 101 redraws check
coarse GDI/USER-resource stability. The probe uses a 4-KiB stack and 2-KiB local
heap. `test_win16_gauge.py` guards FPC scope and retained Delphi branches; it does
not substitute for native drawing. This does not build the entire Progress form,
DFM streaming, inherited Font/ParentFont, hints, Enabled or alignment.

## Standard label and font change events

`make win16-label` builds the windowless standard-label probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-label-runtime-test` runs it in a
private TCG image. Actual glyph bounds/colors verify left/right/center alignment,
automatic redraw after direct font changes, removal of old/empty text, word wrap,
explicit CRLF and mnemonic versus literal ampersands. Assignment must deep-copy
the owned font and survive source destruction; invalid nil fonts/NUL captions
must preserve prior values. Font OnChange checks completed state/native handles,
same-value/self/identical-Assign suppression, retained reentrant mutations,
exception recovery, single full-copy notification and quiet validation failures.
There are 101 font/render cycles with canvas-detachment and coarse GDI/USER-pool
guards. The probe uses a 4-KiB stack and 2-KiB local heap. `test_win16_label.py`
adds scope/ownership guards only. Full Forms/Progress, AutoSize, transparency,
ParentFont, disabled label rendering and label mouse routing are not provided or
tested. FocusControl/Alt activation has separate acceptance through
`win16-mnemonic-runtime-test`; it covers weak-reference destruction, reparenting,
nested/disabled containers, escaped prefixes, ANSI case and callback recovery.
The original selection dialog's `win16-select-runtime-test` now passes native
startup, callback/mask semantics, callback exceptions, keyboard navigation and
resource cycles. `win16-select-language-runtime-test` runs one EXE with German,
French and English catalogues and verifies public-field/focus-reference lifetime.
Both are in the accepted batch after relocating the full diagnostic buffer
outside DGROUP; application stack/heap sizes remain 4 KiB/2 KiB. See the
[port boundary](../docs/vcl_port.md#original-selection-dialog).

`test_gui_error_buffer.pas` is the same bounds/overflow-checked harness for host
`make test` and `win16-gui-buffer-runtime-test`. It includes the production
diagnostic implementation with mocked Windows APIs, checking exact 1,024-byte
capacity, split/multiple buffers, canaries, allocation/lock failures, NoErrMsg and
100 balanced allocation/release cycles. `win16-gui-diagnostics-runtime-test`
separately uses real System Output and native MessageBoxes with automatic,
task-scoped dismissal; it checks partial/full output, suffix flushing on Close
and suppression. These are not full-guest out-of-memory fault injections.

## Images and graphic updates

`make win16-image` builds the image/graphic-update probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-image-runtime-test` uses a private
TCG image. Pixel checks cover native/centered/cropped/scaled bitmaps, negative
center origins, color-key backgrounds, bitmap edits and persistent public Canvas.
Show/Hide/Update/Repaint must flush old/new regions without allocating HWNDs or
retaining rendering DCs. AutoSize must follow nonempty pictures, preserve the box
when cleared and reject overflowing enable without changing its flag or bounds.
Failed file replacement preserves content; nil assignment retains the owned
container. Scaled icons are compared against separately flattened native-icon
references. Icon Canvas access must not silently replace the icon. Independent
picture lifetime, nested paint-update rejection, parent detachment and 60 icon
replacement/render cycles check cleanup and coarse GDI/USER resource stability.
This probe uses a 4-KiB stack and 2-KiB local heap. `test_win16_image.py` adds
ownership/scope guards; transparent-parent painting, new file decoders and the
remaining ExtCtrls classes are not tested or supplied.

## Native buttons and original PicBtn

`make win16-button win16-bitbtn` builds native USER BUTTON and owner-drawn
bitmap/PicBtn probes. Use the corresponding `win16-button-runtime-test` and
`win16-bitbtn-runtime-test` targets with the same private-image environment.
Both use a 4-KiB stack and 2-KiB local heap. Superclass extra bytes must remain
intact before the appended far object pointer. Tests send synthetic mouse/Space
messages through actual HWNDs and verify native capture, single clicks,
outside-release cancellation, disabled/hidden filtering, independent receivers,
ID/notification rejection, unmanaged HWND isolation, event-error recovery,
native font selection, reparent/recreation and 60 resource-guarded activations.
These are genuine USER notification paths, not physical keyboard/mouse tests.

The bitmap probe invokes the original PicBtn Loaded method explicitly for both
glyph policies. Native ODS states select supplied normal/disabled/pressed bitmap
frames; pixels check transparent keys, captions, all four layouts and directional
margins. Parent Update/Click reentry during owner drawing must fail safely; paint
exceptions must release the HDC/render guard and allow later drawing. Nil glyph
assignment retains the owned container; 60 redraw/activation cycles check coarse
GDI/USER resources. `test_win16_buttons.py` guards routing, ownership and retained
Delphi branches. Rare post-creation/font-allocation failures are source-guarded,
not fault-injected. Modeless default/cancel routing and TabOrder have separate
acceptance below; bitmap buttons additionally retain BS_OWNERDRAW during default
style changes and route Enter/Escape. ModalResult now has separate modal-form
acceptance below. Full Buttons/Dialogs,
synthesized disabled glyphs and DFM streaming remain outside scope.

## Combined progress UI profiles

`make win16-progress-ui win16-progress-button` builds two test-only profiles
sharing `pascal/progress_ui_probe.inc`. Their corresponding `*-runtime-test`
targets run native task loops. Timers update actual original-gauge pixels. The
image profile combines form/label/image/gauge and cancels via posted WM_CLOSE.
The button profile omits the image and cancels via native Cancel-button mouse
down/up and BN_CLICKED, not a direct event call. Both abort at five steps,
recreate the retained owned model, complete twenty steps and test posted Escape
abort at three steps. Each loop explicitly installs the form's message filter.
In the button profile Escape goes through Cancel=True, without a custom form
KeyDown handler. The image remains HWND-free and retains its icon; the
button profile has exactly one child HWND. Rendering canvases must detach and
20 show/update/hide cycles must not post additional task-quit messages.

Both native-tested profiles use a 4-KiB stack and 1-KiB local heap.
The former 2-KiB heap configuration passed the static NE budget guard but failed
native loading; a budget pass alone is not runtime acceptance. Pascal objects
use the global heap. Adding both image and native button to one executable
exceeded the static budget or failed loading even after shortening diagnostics;
profiles remain separate without lowering the stack or bypassing checks. These
fixtures do not replace the original Progress dialog or exercise real file
operations, its full TPicBtn integration, DFM, modal loops or reentrant
Application.ProcessMessages compatibility.

## Native entry controls and combined input dialog

`make win16-edit win16-checkbox win16-input-dialog` builds three independent
probes; the corresponding `*-runtime-test` targets use private Windows 3.11
image copies. All retain a 4-KiB stack and 2-KiB local heap. They complement
the existing message/paint/input tests, not a completed StdCtrls/Forms port.

The edit test checks detached/live text, packed Win16 selection, replacement,
clipboard copy/paste/cut/undo, modified state, mutable/consumed characters,
password masking, read-only typing, programmatic text, live upper/lowercase and native interactive
limits. NUL, oversized native text and replacement overflow must preserve state.
EN_CHANGE must not duplicate events; nested mutations, direct/native failures,
deep font copies, retained live reparenting, quiet destruction/recreation and
40 recreation cycles exercise cleanup. The text interface is ANSI/255 bytes;
MaxLength=0/unlimited and multiline/Memo/Lines are intentionally unsupported.

The checkbox test checks native BM_GETCHECK against mouse/Space and two-/three-
state transitions. Changed programmatic state notifies once, equal state is quiet,
disabled/hidden native activation is ignored and Enter is not a toggle. It checks
nested events, callback recovery, NUL captions, native fonts, quiet retained state
and 60 recreation cycles with coarse USER/GDI-pool guards.

The combined test creates one real edit, checkbox and two push buttons. Posted
keys must enable valid input, traverse controls, toggle the option and accept the
actual values. Deleting input disables acceptance; Enter must not bypass validation,
and Escape uses the cancel button without posting WM_QUIT. Recreated dialogs keep
their model without spurious changes and remain usable across 20 cycles.
`test_win16_entry_controls.py` adds source guards; it cannot replace these native
tests. These entry-control probes do not imply physical input, radio groups, modal results or original full dialog/DFM
acceptance is implied. Native clipboard contents live only in the private guest.

Keep integration diagnostics concise: adding CharCase metadata brought the
combined probe to 64,544 bytes including stack/heap. It passed the static NE
guard but native USER refused to load it. Shorter diagnostic strings reduced
the same test coverage to 64,304 bytes; the 4-KiB stack and 2-KiB heap are unchanged.
Always run native acceptance after a budget pass. This fixture adjustment is
not a solution to the complete shell's eventual automatic-data-segment budget.

## Original incremental search dialog

`make win16-incsrch` compiles the actual maintained `src/incsrch.pas` class,
not a test-only search rewrite. Its FPC branch constructs the edit/label from
the original binary DFM's values and connects the original methods; the Delphi
TForm/DFM branch remains intact. `win16-incsrch-runtime-test` checks its 171x41
native client area, unset/empty and lowercase initial characters, original caret/focus and search
callback, queued typing, original Enter/Escape closure, retained reuse, HWND
recreation and 30 resource cycles. The probe retains a 4-KiB stack/2-KiB local heap.

The host entry-control tests parse `src/incsrch.dfm` to compare the explicitly
constructed layout/captions and guard retained original methods/Delphi branches.
No resource is rewritten. This is one manually constructed English
dialog, not general DFM loading, translated captions, full Forms or complete
shell integration. Native acceptance uses only private image copies.

The same original class now also has ShowModal via TNativeModalForm. Use
`make win16-incsrch-modal` and `win16-incsrch-modal-runtime-test` for its separate
modal probe. This checks inferred active-owner disabling/restoration, original
FormShow/OnSearch, queued character translation before Enter, empty/default
Escape and HWND recreation. Enter and Escape use the original Close handler and
return mrCancel, not a newly invented search acceptance result.

## Owner-scoped modal forms and explicit nested pumps

`make win16-modal win16-modal-loop` builds UI-lifecycle and lower-level pump
probes. Their `*-runtime-test` targets run in separate private images; both keep
4-KiB stacks/2-KiB local heaps. The UI test checks native owner links before
OnShow, exact enable/focus restoration, automatic same-task active-owner inference,
initially disabled owners, direct close/hide/destruction and result-driven close.
Button results must be visible before OnClick, and both event and close-query
vetoes must keep the dialog open. Positive show-event results, native Enter/Escape,
show/hide error recovery, rejected lifecycle nesting and child-owner rejection
exercise cleanup without weakening the ordinary pump's recursion guard. An
owner-focus callback must also be unable to reenter while modal cleanup is still
restoring activation/focus; modal state is cleared only after that phase.

Nested modal child closure must restore its parent while the original owner
stays disabled. A three-loop nested quit must return signed -19 from the outer
task loop, cancel both dialogs, restore owners and leave later messages queued.
The successor must not receive a reposted quit. A standalone modal quit must be
reported through TaskQuit/TaskExitCode; normal subsequent runs reset these fields.
Forty cycles check coarse USER-resource stability.

The low-level probe rejects nil conditions, verifies false predicates leave
messages untouched and condition exceptions release pump ownership. A predicate
that enters another modal loop and receives quit must not call GetMessage or
the outer filter afterward; terminated instances remain sticky, while an explicit
successor sees the retained queue and no duplicate quit. WM_NULL task wakeups
are intentional, not reposted WM_QUIT. Cross-task sent-message timing is not
separately fault-injected. `test_win16_modal.py` provides API/scope guards.

Only one selected same-task top-level owner is input-disabled. This is not
system modality, automatic disabling of every task window, full Forms.Application,
general DFM streaming or support for arbitrary nested ProcessMessages. Modal
receivers/owners must not be freed or replaced inside callbacks. Nested ShowModal
is supported from dispatched handlers, not preparation/hide/focus-cleanup callbacks.

## Modeless dialog navigation

`make win16-dialog` builds the queue/navigation probe; use
`WIN311_IMAGE=/path/to/baseline.img make win16-dialog-runtime-test` for native
acceptance in a disposable image. It installs `Loop.OnMessage` explicitly and
checks nested Tab/Shift+Tab wrapping, sibling order changes, live WS_TABSTOP,
focused non-tab positions, hidden/disabled ancestor exclusion and empty lists.
Drawing-time reorder must fail without modifying order. WM_GETDLGCODE opt-outs,
Ctrl/Alt combinations and unrelated targets must remain unhandled.

Enter prioritizes a focused button over designated defaults; Escape uses Cancel.
Disabled buttons are ignored; native default styles and recreated HWND settings
must persist. Posted handled keys cannot produce stray character messages, while
wanted keys must still reach TranslateMessage. Consumed self-posting filters obey
the pump budget, nested pumps remain rejected, filter exceptions release ownership
and signed WM_QUIT bypasses the filter. Callbacks are cleared before receivers
are freed. `test_win16_dialog.py` provides source guards, not runtime substitutes.
This modeless probe does not test physical input, modal results, mnemonics or complete Forms.

## Modeless native form lifecycle

`make win16-form` builds the modeless form probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-form-runtime-test` runs in a private
image copy with the existing TCG runner. Tests inspect actual native frame titles,
visibility, managed child HWNDs, focus/capture release on hide, Show/Hide event
ordering and duplicate suppression. WM_CLOSE is posted and processed by the task
loop: query veto, no-action/default-hide/destroy actions and callback failures
must preserve documented state without quitting the task or freeing objects.
Further checks reject lifecycle reentry, close during drawing, NUL captions and
child-style form creation; show/hide event failures must release guards while
preserving completed visibility transitions. Destroyed native trees must recreate
from the retained model and title; independently owned children survive form
destruction detached. Sixty recreation cycles check coarse USER-resource stability.
The probe uses a 4-KiB stack and 2-KiB local heap. `test_win16_form.py` adds source
scope guards. No DFM loader, full Forms API, modal/owned forms, accelerator
navigation, automatic application-wide activation policy or complete desktop
acceptance is implied. Native activation/focus tests are described below.

`win16-form-activation-runtime-test` checks real native transitions, active form/
EDIT focus, event-time focus assignment, duplicate USER no-ops, model/native
ancestry validation, invalid focus targets, lifecycle/focus reentry rejection,
callback exceptions/recovery, nested activation, modal owner/focus restoration,
child destruction and HWND recreation. Fifty cycles check coarse USER/GDI
resource retention. The probe retains a 4-KiB stack, 2-KiB heap and canary.
ActiveControl is live native focus, not remembered focus on inactive forms;
InitialControl remains the separate deferred-focus API. See
[activation boundaries](../docs/vcl_port.md#native-activation-and-live-form-focus).

Accepted activation logs are `build/tests/form-activation-final-regression.log`
(49 native suites, aggregate exit 0) and
`build/tests/form-activation-portable-regression.log` (316 Python tests plus
portable Pascal/C). `build/tests/form-activation-loader-focused.log` records
four passing loader/activation profiles after compacting common diagnostics.
The earlier `form-activation-accepted-regression.log` is a failed diagnostic
attempt: the selection-language EXE passed the static NE budget but Win3.11
refused to load it. Stack/heap sizes and checks were not reduced to fix this.
`build/tests/form-activation-shell-build.log` still reports missing Forms.

`win16-form-resize-runtime-test` checks actual client/outer metrics, virtual Resize
and OnResize ordering, nested native child layout, unchanged/move/forged-message
no-ops, external size changes, property/base-type reentry guards, invalid bounds,
explicit layout refresh, callback failure/recovery, hidden resize, HWND recreation
and modal owner/focus restoration. Fifty two-size cycles check event counts and
USER/GDI retention. It retains a 4-KiB stack, 2-KiB heap and stack canary. These
probes do not provide writable client dimensions, automatic alignment or full
Forms/DFM. WindowState is tested separately below. See
[resize scope](../docs/vcl_port.md#native-resize-and-client-dimensions).

Accepted resize logs are `build/tests/form-resize-final-regression.log` (all
50 native suites, aggregate exit 0) and
`build/tests/form-resize-portable-regression.log` (320 Python tests plus portable
Pascal/C). The four corrected focused profiles pass in
`build/tests/form-resize-loader-focused.log`. The earlier
`build/tests/form-resize-focused.log` is diagnostic, not acceptance: a language
profile failed native loading and the modal fixture lacked an active-owner
precondition after HWND recreation. The corrected fixture establishes that
precondition and verifies child-focus restoration; compact shared diagnostics
provide loader reserve without shrinking stack/heap or removing assertions.
`build/tests/form-resize-shell-build.log` still reports missing Forms.

`win16-form-state-runtime-test` checks lazy/minimized startup, pending hidden
state, real native system commands, explicit normal versus native restore-to-max,
focus/dialog-key suppression, resize/state/lifecycle guards, invalid state,
callback exception/recovery and normal placement through hide, min/max teardown,
close/destroy/recreation and subsequent lazy bounds changes. Maximized/minimized
modal starts must complete and restore owner enable/focus state. Thirty three-state
cycles inspect native placement and USER/GDI retention. The probe retains a
4-KiB stack, 2-KiB heap and stack canary. These are per-form native APIs, not
Application.Minimize or a complete Forms/DFM layer. See
[state scope](../docs/vcl_port.md#native-window-state-and-restore-placement).

Accepted state logs are `build/tests/form-state-final-regression.log` (all
51 native suites, aggregate exit 0) and
`build/tests/form-state-portable-regression.log` (325 Python tests plus portable
Pascal/C). The four initial focused profiles pass in
`build/tests/form-state-focused.log`; the final batch additionally checks event
exceptions during native state changes and subsequent recovery. Existing native
profiles pass with unchanged stack/heap settings and resource fixtures.
`build/tests/form-state-shell-build.log` still reports missing Forms.

## Pattern brushes and drawing operations

`make win16-drawing` builds a public-API pixel probe;
`WIN311_IMAGE=/path/to/baseline.img make win16-drawing-runtime-test` uses the
private-image GDI runner. Checks cover 8x8 checkerboard tiling after source
destruction, independent brush Assign, cache recreation, invalid-size retention
and same-color/nil assignments leaving pattern mode. The public Brush.Bitmap
property is deliberately assignment-only and snapshots pixels.

TextRect tests inspect clipped glyphs and preserved clear-brush backgrounds.
Focus drawing must change real pixels, then restore them on the second draw.
Border and surface FloodFill inspect connected regions and boundary pixels;
the full-circle Pie models disk-usage drawing. Event handlers check restored
text/background/raster state; caller-selected objects must survive. A 150-cycle
pattern/drawing/self-stretch test checks coarse GDI-pool stability. StretchDraw
also checks exact scaled quadrants, wallpaper self-shrink before resizing,
overlapping and transparent self-copy, clipping, empty no-ops and rejected
mirrored rectangles. Callbacks must see the restored stretch mode. This primitive
probe is not component UI acceptance; the original slider and pie chart have
separate native acceptance tests above. Full Controls/Forms integration remains unfinished.
`test_win16_drawing.py` adds source/API guards, not a host GDI replacement.

