# Build Status

## Working Targets

Run commands from the repository root with OpenWatcom in `/opt/watcom`:

| Command | Current result |
| --- | --- |
| `make test` | Portable Pascal programs including shared diagnostic-buffer fault tests, host help-service harness, portable C and Python tests |
| `make win16-ui` | Builds twenty-seven isolated UI acceptance probes; `win16-ui-runtime-test` runs their private-image tests and supports `make -j4` |
| `make fpc-win16-fixed-compiler` | Isolated i8086 class/class-reference comparison correction; existing compiler and vendor checkout remain untouched |
| `make win16-fixed-regression` | All 86 native suites pass under the huge data model with the corrected compiler/private RTL, including the Forms/Dialogs/ShellAPI/IniFiles/Menus/Clipbrd units, radio buttons, combo boxes and list boxes, mixed children, heap shrink bounds and password resource cycles |
| `make win16-realloc-runtime-test` | Adjacent live heap guard and prefix preservation across small/global resizing, nil allocation and zero-size release |
| `make win16-application` | Explicit application/weak-form registry, main close/quit policy, startup guard, owned teardown and exception recovery; not full Forms |
| `make win16-application-dialog` | Multi-form keyboard/filter routing and startup-modal completion/quit/error recovery |
| `make win16-application-factory` | Virtual form construction, early reference publication, failure rollback and hidden-main startup |
| `make win16-application-original` | Original DFM-based incremental-search dialog created by the application during native startup |
| `make win16-application-window` | Hidden TApplication/Calmira transport, sent/queued hooks, title/lifetime/error guards and independent Win16 sender |
| `make win16-application-activation` | Live task Active, native application events, callback guards and independent visible-task acceptance |
| `make win16-idle` | Empty-queue idle slices, blocking default wait, modal inheritance/override and callback/pump recovery |
| `make win16-application-idle` | Application OnIdle sender/guards, inherited modal completion/quit/errors and root recovery |
| `make win16-application-exception` | Explicit active-exception routing, borrowed lifetime, native/default presentation and handler/USER-boundary recovery |
| `make win16-application-help` | Guarded OnHelp/HelpFile, native context/JumpID dispatch, localized missing-file dialogs and silent help teardown |
| `make win16-help-key` | Binary-DFM HelpContext metadata, focused F1 inheritance, queue/control priority, modal recovery and real WinHelp launch |
| `make win16-control-view` | Guarded Show/Hide and native child/form ordering, polymorphic form lifecycle, descendant input cleanup and modal Hide |
| `make win16-view-order` | Real NextForm/BringToFront screen integration, windowless overlap pixels, retained graphic order and GDI/USER/DC checks |
| `make win16-coordinates` | Live USER client/screen conversion, windowless parent offsets, graphic rectangle accessors, overflow and paint guards |
| `make win16-children` | Shared real TControl identity; mixed direct-child enumeration, view/property dispatch and callback-safe membership rollback |
| `make win16-drain` | Scoped queue drain, live modal/root filters, recursive/idle guards and nested signed-quit propagation |
| `make win16-application-pump` | Parameterless ProcessMessages during real operations, native Cancel/modal default clicks, callback guards and root recovery |
| `make win16-identity` | Actual loaded NE identity, wrapper-aware package/data paths, bounded metadata and callback/CWD/quit checks |
| `make win16-identity-package-runtime-test` | Plain and real-UPX launches from separate working/temp directories, including source-sidecar negative cases |
| `make win16-screen` | Weak task-local application view, native form Z-order, live active form/control, metrics and teardown/resource guards |
| `make win16-screen-modal` | Registered/unregistered modal screen state, real EDIT focus, owner restoration, startup failure and signed quit |
| `make win16-cursor` | Scoped screen/control cursors, nesting, borrowed registry, capture, callback/teardown guards and native resource checks |
| `make win16-cursor-modal` | Registered/unregistered modal cursor scope, popup-owner separation, error recovery and signed quit |
| `make win16-form-activation` | Native form activation events, live child focus, reentry guards, modal restoration and lifetime tests |
| `make win16-form-resize` | Native client metrics, virtual Resize/OnResize, child layout, reentry guards and modal/recreation tests |
| `make win16-form-state` | Deferred/live min/max/normal state, retained normal placement, focus guards, modal startup and recreation |
| `make win16-forms` | Initial `Forms` unit: global Application/Screen, typed TForm/MainForm/Screen views, deferred caFree/Release and unit finalization |
| `make win16-dialogs` | Initial `Dialogs`: MessageDlg/ShowMessage with real native buttons, icons, Delphi default/cancel rules, wrapping and localized captions |
| `make win16-input-query` | InputQuery/InputBox: selected initial text, typed accept, Escape cancel and resource cycles |
| `make win16-shellapi` | SHELL.DLL imports: registration database round trip, icon extraction, associations, drag-acceptance style |
| `make win16-inifiles` | TIniFile: strings, hex/long integers, booleans, sections, erase and disk flush |
| `make win16-menus` | Menus: handle contents, in-place Checked/Enabled, rebuilds, dispatch, TrackPopupMenu, menu bar, resources |
| `make win16-system-dlls` | ToolHelp TimerCount and VER.DLL version blocks of USER.EXE (fixed info, translation, strings) |
| `make win16-clipbrd` | TClipboard: text round trip, application ownership, truncation, several formats per Open, enumeration, clear |
| `make winfile16-core` | Original Microsoft filename, directory-memory and size-format modules |
| `make drive-probe` | Separate `DRVPROBE.EXE` diagnostic, not a file manager |
| `make win16-helpers` | FPC SHOWDESK, SCRNSAVE, EXPLORER and CTASKMAN executables |
| `make ctl3d` | Open-source CTL3DV2.DLL replacement |
| `make languages` | Shared English, German and French catalogues |
| `make help` | Updated Reloaded WinHelp from RTF/BMP, pinned Python compiler; no Windows host required |
| `make help-path-runtime-test` | Plain/UPX-packed help launch and German missing-file error probe in private Win3.1x image copies |
| `make win16-messages` | Native message-record subset and typed-dispatch probe, using the private GUI RTL |
| `make win16-gdi` | Native pen/brush/font/canvas and bounded BMP/resource loader with pixel probe; not complete Graphics |
| `make win16-graphics` | Public Graphics subset and unchanged CalColor probe: typed canvas/bitmap/icon, original BrushCopy argument, font and color APIs |
| `make win16-handles` | Native image ownership probe: adopt/copy/detach, failure preservation, private/shared icons and GDI/USER pool guards |
| `make win16-picture` | Owned bitmap/icon picture container, deep copies and managed drawing/change notifications; native lifetime/error-path probe |
| `make win16-drawing` | Pattern brushes, clipped text, focus, Pie/fills and bitmap StretchDraw including self-copy; native pixel/DC probe |
| `make win16-window` | Owned native HWNDs, far-pointer object association, message dispatch and exception/cleanup boundaries; not Controls/Forms |
| `make win16-paint` | BeginPaint/EndPaint-scoped canvas, background/partial/disjoint updates and exception cleanup on real window pixels |
| `make win16-input` | Mouse/key events, mutable/consumed keys, real USER focus/capture and callback error recovery; not full Controls |
| `make win16-draw` | Explicit GetDC drawing scopes, nested paint/DC restoration, mouse-driven drawing and exception/resource cleanup |
| `make win16-slider` | First original VCL component: slider builds on real windowed Controls subset; native pixels, value/drag/focus and resize checks |
| `make win16-graphic` | True HWND-free graphic children, local Enabled state, guarded composition/clipping/lifetime and the original Win95 pie chart |
| `make win16-hierarchy` | Windowed object parents, native-preserving reparent, outer/client bounds, recursive handle creation and failure cleanup |
| `make win16-loop` | Explicit task message loop, bounded nonblocking dispatch, native keyboard translation, timer wakeup and signed quit handling; not Forms.Application |
| `make win16-form` | Modeless native frame, title/show/hide, queued close veto/actions, child HWND recreation and event cleanup; not full TForm/DFM |
| `make win16-gauge` | Original BarGauge/Win95Gauge, solid/segmented pixels, vertical/range fixes, percentage text, borders and redraw/resource guards |
| `make win16-label` | Real HWND-free StdCtrls label, disabled system-gray text, alignment/wrapping/prefix text, owned fonts and native pixel/event tests |
| `make win16-image` | HWND-free ExtCtrls image, deep-owned picture/bitmap canvas, center/crop/stretch, icon scaling and graphic visibility/update tests |
| `make win16-progress-ui` | Combined native form/label/image/original-gauge timer test, close/Escape cancellation and HWND recreation; not the original complete Progress dialog |
| `make win16-button` | Real USER BUTTON superclass, command routing, native mouse/Space/font, reparent/recreation and callback/resource tests |
| `make win16-bitbtn` | Native owner-drawn bitmap button and original PicBtn loading policy, supplied glyph states, caption/layout and paint cleanup |
| `make win16-progress-button` | Form/label/original-gauge integration with actual native Cancel-button mouse activation; separate from the image profile for data-segment headroom |
| `make win16-dialog` | Managed Tab/Shift+Tab order, focused/default/cancel button keys and explicit pretranslation filter; native queue/error/recreation tests, not modal Forms |
| `make win16-edit` | Real single-line EDIT: bounded ANSI text, selection, password/read-only/limit, clipboard/undo, changes and HWND-state restoration |
| `make win16-checkbox` | Native checkbox: two-/three-state toggling, managed notifications, real mouse/Space/font and reparent/recreation checks |
| `make win16-input-dialog` | Combined edit/checkbox/default/cancel validation through the USER queue; test-only modeless form, not an original completed Calmira dialog |
| `make win16-incsrch` | Original incremental-search methods on native edit/label/modal-capable form; retained modeless/DFM-geometry acceptance, not general DFM loading |
| `make win16-modal` | Owner-scoped ShowModal, result buttons/veto, focus/enable cleanup, nested forms and quit propagation; not full Forms.Application |
| `make win16-incsrch-modal` | Actual original search dialog via ShowModal, queued search/Enter/Escape, automatic owner and recreation |
| `make win16-form-resources` | Strict build-time DFM constructor compiler; original search layout/events generated from unchanged resource, not full runtime streaming |
| `make win16-form-text` | Same original-dialog EXE with runtime German/French/English LNG captions, fallback and bounded profile values; no automatic localized layout |
| `make win16-askdrop` | Original drag/drop DFM and methods, original embedded copy/move bitmaps, native icon/rendering, Loaded policy and resource-cycle tests |
| `make win16-askdrop-modal` | Same original dialog: copy/move/cancel results, owner scope, queued keys/mouse, close and HWND recreation; not file operations |
| `make win16-askdrop-language` | Same EXE creates German/French/English original drag/drop dialogs, including standard Cancel captions |
| `make win16-mnemonic` | Scoped Alt activation, weak label FocusControl, button/checkbox activation and native callback/lifetime tests |
| `make win16-select` | Original selection dialog: native mask/callback behavior, callback recovery, mnemonics, recreation and resource cycles |
| `make win16-select-language` | One original-dialog EXE with German/French/English captions/actions and public-field/focus-reference lifetime checks |
| `make win16-password` | Original password DFM/methods, explicit create/change mode, bounded legacy codec, native validation/modal/owner/resource tests |
| `make win16-password-language` | One EXE with German/French/English numeric strings, partial-initialization rejection and stack guards |
| `make win16-resource-text` | Lightweight numeric LNG provider with original bound resources, bounded lookup and scoped fallback/restoration |
| `make win16-gui-stdio` | Private GUI ANSI Text/FileRec ABI, shared diagnostic output aliases and explicit full-buffer Text file I/O |
| `make win16-gui-buffer` | Shared production diagnostic algorithm under Win16 with bounds/overflow checks and mocked allocation/lock failures |
| `make win16-gui-diagnostics` | Actual System output and native MessageBoxes: partial/full capacity, Close suffix and NoErrMsg |
| `make win16-modal-loop` | Explicit nested pump edge cases: predicate/exception cleanup, sticky signed quit and preserved successor queue |
| `make pack-win16` | Verified UPX release copies in `build/packed/` |
| `make clfn-hook` | Experimental global dialog hook and explicit resident test loader |
| `make window-inventory` | Private-VM window/control diagnostic |
| `make archive-host-test` | Full 7-Zip host reference and eight controlled-fixture tests; not Win16 |
| `make archive-reader-host-test` | Actual bounded ZIP backend and generated-fixture tests on the host |
| `make archive-dos` | OpenWatcom DOS/32A ZIP reader, `OLFNLIST.EXE` |
| `make archive-viewer` | Win16 read-only ZIP viewer and its DOS helper |
| `make archive-package` | Standalone experimental GDI add-on, independent of shell build |
| `make openlfn` | Independent OpenLFN Loader and hook, neutral `OLFN*` filenames |
| `make openlfn-dist` | Local deterministic `OPENLFN.ZIP` binary bundle plus SHA-256 |

The 2026-10-19 resource-constructor checkpoint passes `make test` (224 Python
tests plus the portable Pascal/C suites) and the complete 25-suite native UI/
window/input/paint/draw/loop batch using the corrected private TCG emulator.
Logs: `build/tests/dfm-portable-regression.log` and
`build/tests/dfm-accepted-regression.log`. The multilingual fixture keeps its
4-KiB stack/2-KiB heap and uses 64,336 bytes of the guarded Win16 data budget;
diagnostic strings were shortened after a larger fixture failed native startup.
That was the earlier checkpoint. The resource inventory now also accepts drag/
drop and password layouts; at that checkpoint only drag/drop's original Pascal
unit had additionally been ported. Bitmap payloads are generated as bound native resources. The private
GUI RTL now uses shared diagnostic output aliases and ANSI filename fields while
preserving full file buffers and application stack/heap budgets. See
[port and ABI boundaries](vcl_port.md#private-gui-text-file-abi).

The subsequent bitmap/dialog checkpoint passes `make test` (248 Python tests
plus portable Pascal/C) and the complete 30-suite native batch, including GUI
stdio and the original component/stream/exception tests. Logs:
`build/tests/dfm-image-portable-regression.log` and
`build/tests/dfm-image-accepted-regression.log`. The original drag/drop resource,
modal and language profiles use 64,080 / 64,480 / 64,352 bytes respectively of
the guarded data budget, all with unchanged 4-KiB stacks and 2-KiB heaps. These
remain close to the native loader limit: a static budget pass alone is not
acceptance. The full shell still needs the Forms/application framework.

The next mnemonic checkpoint passes `make test` (263 Python tests plus portable
Pascal/C) and all 31 extended native suites on disposable Windows 3.11 images
with the corrected private TCG emulator. Logs:
`build/tests/mnemonic-portable-regression.log` and
`build/tests/mnemonic-accepted-regression.log`. New coverage includes weak label
FocusControl, scoped Alt activation, button/checkbox behavior and recovery from
focus/click callback failures. DFM constructors resolve forward references and
clear typed child fields through inherited-compatible Notification overrides.
The additional original-search lifetime check also passes after explicitly
freeing its edit: generated field, InitialControl and label FocusControl all
become nil (`build/tests/mnemonic-field-lifetime.log`).

At that checkpoint, original selection-dialog sources and resources compiled, including bounded
legacy glyph-padding normalization and conflict-checked original icon-resource
merging. Its 64,960-byte static budget passes, but Windows 3.11 rejects startup
for insufficient memory; the experimental fixture was excluded from acceptance.
The diagnostic-buffer relocation described in the port guide now resolves that
startup blocker and retains 4-KiB stacks/2-KiB heaps. The expanded original
selection fixture uses 64,000 guarded bytes; its multilingual fixture uses
64,384. `make calmira` still fails at missing Forms; these are ported individual
dialogs, not a complete shell release.

The 2026-10-21 diagnostic-buffer/selection checkpoint passes `make test` (268
Python tests plus portable Pascal/C) and all 35 extended native suites under
the corrected private TCG emulator. Logs:
`build/tests/gui-buffer-portable-regression.log` and
`build/tests/gui-buffer-accepted-regression.log`. The unchanged DFM resources and
pinned Free Pascal checkout remain intact. Shared host/Win16 fault tests cover
full diagnostic capacity, split-write payloads, canaries, allocation/lock failures
and balanced ownership. Real GUI output additionally verifies full/partial
MessageBoxes, Close suffix flushing and NoErrMsg suppression. The private channel
now uses a custom-device handle so Close actually invokes its close callback.
The full-shell build still fails at missing Forms; the separate evidence is in
`build/tests/gui-buffer-shell-build.log`.

The subsequent password-dialog checkpoint passes `make test` (276 Python tests
plus portable Pascal/C) and all 38 extended native suites, including 27 UI
profiles, under the corrected private TCG emulator. Logs:
`build/tests/password-portable-regression.log` and
`build/tests/password-accepted-regression.log`. The original password DFM and
numeric resources now drive create/change, modal and German/French/English
acceptance. Native stack canaries exposed and verified fixes for excessive
temporary string copies in nested callbacks/catalogue lookups; 4-KiB stacks and
2-KiB heaps remain unchanged. A separate known-failing large-object constructor
diagnostic is excluded from acceptance and documented in the port guide.
`make calmira` still stops at missing Forms
(`build/tests/password-shell-build.log`); no complete shell release is claimed.

The corrected-compiler checkpoint passes `make test` (282 Python tests plus
portable Pascal/C) and all 39 native suites via `make win16-fixed-regression`.
Logs: `build/tests/class-pointer-portable-regression.log` and
`build/tests/class-pointer-accepted-regression.log`. A targeted i8086 patch makes
four-byte class/class-reference comparisons include both segment and offset;
real zero-offset allocations now run constructors, lifetime hooks, failed-
construction cleanup and large TComponent owner/child destruction correctly.
The same fixture fails as expected with the stock compiler
(`build/tests/class-pointer-stock-native.log`). The vendor pin and installed
stock compiler remain unchanged. Corrected compiler, RTL and application caches
are isolated by fingerprint; language and RTL test paths now honor that tree.
The corrected full-shell build still stops at missing Forms
(`build/tests/class-pointer-shell-build.log`); this is not a finished shell.

The subsequent application-lifecycle checkpoint passes `make test` (288 Python
tests plus portable Pascal/C) and all 41 native suites via
`make win16-fixed-regression`. Logs:
`build/tests/application-portable-regression.log` and
`build/tests/application-accepted-regression.log`. The explicit native application
now manages a nonowning form registry, main-window close/quit policy, per-form
dialog-key routing and startup-modal cleanup. Tests retain 4-KiB stacks, 2-KiB
heaps and stack canaries, including registry mutation and failure recovery.
This is an application foundation, not a replacement `Forms` unit: the corrected
full-shell build still stops at `Can't find unit Forms used by Calmira`
(`build/tests/application-shell-build.log`).

The application-factory checkpoint passes `make test` (292 Python tests plus
portable Pascal/C) and all 43 native suites with `GDI_TEST_SECONDS=60` under the
corrected private TCG emulator. Logs:
`build/tests/application-factory-portable-regression.log` and
`build/tests/application-factory-accepted-60s.log`. The initial 30-second batch
was truncated during the existing label redraw stress test, not an assertion
failure; its 60-second isolated and complete reruns pass without reducing stress
iterations, stacks, heaps or canaries. The factory publishes references before
virtual construction, owns/registers successful forms, rolls back failures and
supports hidden-main startup. The original DFM-generated search dialog passes
factory/modal/recreation integration. The larger password/application combination
still fails native loading despite a passing static size guard and is not qualified.
The full shell remains blocked by missing Forms
(`build/tests/application-factory-shell-build.log`).

The hidden-window checkpoint passes `make test` (298 Python tests plus portable
Pascal/C) and all 44 native suites with the corrected private TCG emulator and
`GDI_TEST_SECONDS=60`. Logs: `build/tests/application-window-portable-regression.log`
and `build/tests/application-window-accepted-regression.log`. The separate hidden
TApplication/Calmira HWND now supplies lazy Handle, verified 255-byte titles,
guarded window hooks, exception diagnostics, native recreation and main close
delegation. A second Win16 executable verifies cross-task SendMessage, receiving
task context and a signed posted reply through the original registered message
contract. Existing form/factory/window tests also pass; their stacks/heaps and
canaries are unchanged. This qualifies transport, not the shell's command handlers
or full AppHolder services. The full shell still stops at missing Forms
(`build/tests/application-window-shell-build.log`).

The screen-view checkpoint passes `make test` (304 Python tests plus portable
Pascal/C) and all 46 native suites with the corrected private TCG emulator and
`GDI_TEST_SECONDS=60`. Logs: `build/tests/screen-portable-regression.log` and
`build/tests/screen-accepted-regression.log`; focused checks are in
`build/tests/screen-focused.log`. The explicit weak application view now reads
native form order, lazy model fallback, active registered form/managed control
and real screen dimensions/DPI. Native checks cover three-form desktop-style
cycling, reparent/hide/free/unregister, application teardown and registered/
unregistered modal focus, owner restoration, startup failure and signed quit.
The new probes retain 4-KiB stacks, 2-KiB heaps and stack canaries; resource checks
verify repeated screen DC and temporary-list use. At this checkpoint global
Forms.Screen, automatic activation events, cursor management and Screen.Canvas
remained absent; the cursor policy is added subsequently.
The complete shell still fails at missing Forms
(`build/tests/screen-shell-build.log`).

The cursor-policy checkpoint passes `make test` (312 Python tests plus portable
Pascal/C) and all 48 native suites with the corrected private TCG emulator and
`GDI_TEST_SECONDS=60`; the aggregate exits successfully. Logs:
`build/tests/cursor-portable-regression.log` and
`build/tests/cursor-accepted-regression.log`. The policy adds opt-in screen/control
cursor priority, nested overrides, borrowed custom resources, same-task/modal
scope and guarded mutation/teardown. Focused guard checks are recorded in
`build/tests/cursor-guards.log`. Both new probes retain 4-KiB stacks, 2-KiB heaps
and canaries; existing native suites also pass without reducing those budgets.
These controlled pointer/message tests do not establish physical-input desktop
acceptance, automatic Screen events or Screen.Canvas. The complete shell still
stops at missing Forms (`build/tests/cursor-shell-build.log`).

The native form-activation checkpoint passes `make test` (316 Python tests plus
portable Pascal/C) and all 49 native suites with the corrected private TCG
emulator and `GDI_TEST_SECONDS=60`; aggregate exit is 0. Accepted logs:
`build/tests/form-activation-portable-regression.log` and
`build/tests/form-activation-final-regression.log`. Forms now expose native
OnActivate/OnDeactivate, task-local Active and live ActiveControl assignment,
with model/native ancestry validation, callback reentry guards, exception
recovery, nested transitions and modal owner/focus restoration. InitialControl
remains the distinct deferred-focus API; inactive forms do not remember an
ActiveControl. The new probe retains its 4-KiB stack, 2-KiB heap and canary.

The first full attempt (`build/tests/form-activation-accepted-regression.log`)
failed before the selection-language probe started: Win3.11's loader reported
insufficient memory despite a passing static budget of 64,528 bytes. Compact,
shared form diagnostics reduce it to 64,464 bytes without shrinking stack/heap,
removing checks or changing resources. All four loader-focused profiles then
pass (`build/tests/form-activation-loader-focused.log`), followed by the complete
49-profile final run. Keep that failed attempt as diagnostic evidence, not an
acceptance log. The full shell still stops at missing Forms
(`build/tests/form-activation-shell-build.log`); automatic application-wide
activation, Screen change events and complete Forms/DFM remain unported.

The native form-resize checkpoint passes `make test` (320 Python tests plus
portable Pascal/C) and all 50 native suites with the corrected private TCG
emulator and `GDI_TEST_SECONDS=60`; aggregate exit is 0. Accepted logs:
`build/tests/form-resize-portable-regression.log` and
`build/tests/form-resize-final-regression.log`. Controls now expose read-only
ClientWidth/ClientHeight and virtual SetBounds; forms provide virtual Resize/
OnResize with native client-change detection, descendant layout, own-bounds/
lifecycle guards, error recovery, hidden resize, recreation and modal owner/
focus restoration. The new probe retains its 4-KiB stack, 2-KiB heap and canary.

The first focused attempt (`build/tests/form-resize-focused.log`) exposed another
selection-language loader failure at 64,512 bytes and a missing active-owner
precondition in the new modal fixture. The fixture now explicitly activates and
focuses the recreated owner before testing restoration, and asserts restored
child focus too. Shared control lifecycle diagnostics reduce the final language
profile to 64,384 bytes without removing checks or reducing stack/heap. The four
corrected focused profiles pass (`build/tests/form-resize-loader-focused.log`),
followed by the final complete batch. Writable client dimensions, automatic
alignment, WindowState/restore bounds and full Forms/DFM remain absent; the shell
still stops at missing Forms (`build/tests/form-resize-shell-build.log`).

The native window-state checkpoint passes `make test` (325 Python tests plus
portable Pascal/C) and all 51 native suites with the corrected private TCG
emulator and `GDI_TEST_SECONDS=60`; aggregate exit is 0. Accepted logs:
`build/tests/form-state-portable-regression.log` and
`build/tests/form-state-final-regression.log`. Four initial native profiles also
pass (`build/tests/form-state-focused.log`). The final batch includes the added
state-transition event-exception/recovery checks.

Per-form WindowState now supports deferred hidden/lazy requests, live USER
min/max/normal state, explicit normal versus native restore-to-maximized,
minimized focus/key suppression and guarded transitions. Win3.1 normal placement
is retained in model bounds across min/max HWND teardown, destroy-close and
recreation; lazy bounds changes configure the next normal rectangle. Native
tests cover OnShow/resize state, external system commands, invalid states,
callback guards/recovery, max/min modal startup, owner/focus restoration and
30 three-state resource cycles. The new probe retains its 4-KiB stack, 2-KiB
heap and canary; the selection-language budget remains loader-tested at 64,416
bytes. AGENTS.md, original DFM/locale resources and the pinned FPC checkout are
unchanged. This does not supply Application.Minimize, global Forms objects or
DFM loading. The shell still stops at missing Forms
(`build/tests/form-state-shell-build.log`).

The native application-activation checkpoint passes `make test` (330 Python
tests plus portable Pascal/C) and all 52 native suites with the corrected private
TCG emulator and `GDI_TEST_SECONDS=60`; aggregate exit is 0. Accepted logs:
`build/tests/application-activation-portable-regression.log` and
`build/tests/application-activation-final-regression.log`. The initial four
focused profiles also pass (`build/tests/application-activation-focused.log`);
the final batch additionally verifies notification-HWND recreation.

Application.Active now reads real native task activation independently of its
main form or message flags. Opt-in OnActivate/OnDeactivate events use the hidden
task window and preserve hook/default processing, sender identity, mutation/pump
guards and callback diagnostics. A separate visible Win16 task proves actual
deactivate/reactivate transitions and receiving-task context through a signed
synchronous handshake; switching two forms within the application must not
synthesize app events. Separate protocol checks cover consumption, both event
exceptions/recovery, clearing/rebinding, resource retention and transport
recreation/cleanup. Both EXEs retain 4-KiB stacks and 2-KiB heaps; the main probe
checks its stack canary. Original resources, AGENTS.md and the pinned FPC checkout
remain unchanged. The original Computer/AppHolder error-mode handlers still need
full-shell integration; application minimization, Help/hints and Forms/DFM remain
separate work. The full shell still stops at missing Forms
(`build/tests/application-activation-shell-build.log`).

The cooperative-idle checkpoint passes `make test` (336 Python tests plus
portable Pascal/C) and all 54 native suites with the corrected private TCG
emulator and `GDI_TEST_SECONDS=60`; aggregate exit is 0. Accepted logs:
`build/tests/idle-portable-regression.log` and
`build/tests/idle-final-regression.log`. The four initial focused profiles also
pass (`build/tests/idle-focused.log`); the final batch includes the post-PeekMessage
termination/provider revalidation guards.

Application.OnIdle now runs at an empty task queue with Done=True by default,
returning to blocking GetMessage. Done=False explicitly requests more work,
yields cooperatively and rechecks pending messages before repeating. Bounded
ProcessMessages never calls idle. Modal loops inherit the nearest idle service,
skip an already executing provider and may override it explicitly. Conditions
are rechecked after idle so a modal can complete without posted input. Tests
cover default timer waits, message/quit priority, provider/pump guards, native
application Sender/run flags, exceptions/rebinding/retry, modal inheritance,
idle-opened dialogs and signed modal quit with owner/root cleanup. Both new
probes retain 4-KiB stacks, 2-KiB heaps and stack canaries. Existing profiles pass
without reducing their budgets or changing original resource fixtures.

This does not implement automatic hints/actions, exception presentation or the
original AppHolder's complete Forms service. AGENTS.md, original DFM/locale
resources and the pinned FPC checkout remain unchanged. The complete shell
still stops at missing Forms (`build/tests/idle-shell-build.log`).

The explicit-application-exception checkpoint passes `make test` (341 Python
tests plus portable Pascal/C) and all 55 corrected-compiler native suites under
private-image Win3.11/TCG with `GDI_TEST_SECONDS=60`, aggregate exit 0. Logs are
`build/tests/application-exception-portable-regression.log` and
`build/tests/application-exception-final-regression.log`. Four initial focused
profiles also pass in `build/tests/application-exception-focused.log`.

OnException registration is handle-free. HandleException uses active ExceptObject
while preserving Sender, subclass, Message, HelpContext and RTL ownership; EAbort
is silent. Default handling and explicit ShowException use real application-owned
native dialogs with bounded, NUL-safe ANSI text and title/class fallback.
ShowException bypasses the event and retains caller ownership. Tests verify
recursion/rebinding/pump guards, exactly-once release, handler failure recovery,
native USER-boundary containment and unchanged unrouted callback diagnostics.
There is no automatic global error hook: idle errors still propagate directly.
The new probe uses 54,032 bytes of the static NE budget with its unchanged
4-KiB stack, 2-KiB heap and intact stack canary.

The complete shell still stops at `Can't find unit Forms used by Calmira`
(`build/tests/application-exception-shell-build.log`, make exit 2). This is not
complete Forms/Application/DFM or original Computer/AppHolder integration.
AGENTS.md, original DFM/locale resources and the pinned FPC checkout remain
unchanged. See [the exception contract](vcl_port.md#explicit-application-exception-handling).

The application-help checkpoint passes `make test` (346 Python tests plus
portable Pascal/C) and all 56 corrected-compiler native suites under Win3.11/TCG,
using private images and `GDI_TEST_SECONDS=60`; aggregate exit is 0. Accepted logs:
`build/tests/application-help-portable-regression.log` and
`build/tests/application-help-final-regression.log`. The four focused profiles
pass in `build/tests/application-help-focused-final.log`. The initial exploratory
help probe stalled in its generic-clock wait; the accepted probe explicitly uses
WinProcs.GetTickCount and completes its dialog/cleanup/stack checks.

The application now supplies HelpFile, OnHelp, HelpCommand, HelpContext and
HelpJump through the shared localized WinHelp service. Native tests verify
interception without an HWND, handler/default Boolean results, signed context,
live macro-pointer data, injection rejection, recursion/rebinding/pump guards,
handler failure recovery and real foreign-task WinHelp visibility. The rebuilt
help opens from an explicit installed path despite a different current directory;
numeric/context-string requests produce no WinHelp error dialog. Explicit quit,
reopening, silent destructor cleanup and actual English/German/French missing-file
dialogs pass. The new probe uses 54,336 bytes of the static NE budget, retaining
its 4-KiB stack, 2-KiB heap and intact stack canary. No existing budgets were reduced.

The full shell still fails at `Can't find unit Forms used by Calmira`
(`build/tests/application-help-shell-build.log`, make exit 2). This is explicit
WinHelp dispatch, not automatic F1 routing, full AppHolder/Forms/DFM or application
minimization. Custom/intercepted backends own their cleanup; send HELP_QUIT before
externally destroying the transport HWND. AGENTS.md, original DFM/locale resources
and the pinned FPC checkout remain unchanged. See
[the application-help contract](vcl_port.md#application-winhelp-service).

The focused-F1 checkpoint passes `make test` (355 Python tests plus portable
Pascal/C) and all 57 corrected-compiler native suites under private-image
Win3.11/TCG with `GDI_TEST_SECONDS=60`, aggregate exit 0. Accepted logs are
`build/tests/help-key-portable-regression.log` and
`build/tests/help-key-final-regression.log`. Four initial runtime profiles pass
in `build/tests/help-key-focused-final.log`; four further profiles including the
final end-to-end F1 probe pass in `build/tests/help-key-end-to-end-focused.log`.

Windowed controls now carry nonnegative LongInt HelpContext metadata with live
parent-chain inheritance and contents fallback. The strict binary DFM compiler
emits form/child contexts, rejects invalid types/ranges and still explicitly
rejects graphic-only help metadata. Native tests compile a separate binary DFM,
check lazy/32-bit/reparented context lookup, actual focus/modifiers/key ownership,
filter priority, exactly-once consumption, unregistered fallback and current-form
detach/free during help. Root and modal help errors release guards and restore
owner/loop state. A real queued F1 opens installed help in a separate WinHelp task
and explicitly quits it. The probe retains a 4-KiB stack, 2-KiB heap and intact
stack canary, using 63,344 bytes of its static NE budget. Existing budgets and
original resource fixtures remain unchanged.

This is focused F1 routing for registered forms, not a global keyboard hook,
Shift+F1/mouse-context help or complete Forms/DFM. The full shell still stops at
`Can't find unit Forms used by Calmira` (`build/tests/help-key-shell-build.log`,
make exit 2). AGENTS.md and the pinned FPC checkout remain unchanged. See
[the F1 contract](vcl_port.md#focused-f1-context-help-routing).

The control-view checkpoint passes `make test` (361 Python tests plus portable
Pascal/C) and all 59 corrected-compiler native suites under private-image
Win3.11/TCG with `GDI_TEST_SECONDS=60`, aggregate exit 0. Accepted logs are
`build/tests/control-view-portable-regression.log` and
`build/tests/control-view-final-regression.log`. Four initial runtime profiles
pass in `build/tests/control-view-focused-final.log`; four integration profiles,
including repeated real composition/resource checks, pass in
`build/tests/control-view-integration-focused.log`.

Windowed controls now provide guarded Show/Hide/BringToFront/SendToBack through
one virtual view-policy hook. Base-control references retain form construction,
events and modal Hide cleanup. Hiding a container releases descendant native
focus/capture. Child ordering preserves tab order, bounds and focus; visible
enabled forms also request native activation on BringToFront without implicitly
showing hidden frames or restoring icons. Reentry and callback-error tests pass.
The actual NextForm policy now runs against the real method/live screen view.
Windowless siblings reorder their composition list with verified overlap pixels,
retained order after parent recreation and guarded paint mutation. Repeated
composition retains GDI/USER pools, releases all DC scopes and creates no HWNDs.

The two new probes use 60,080 and 60,944 bytes of static NE data budget with
unchanged 4-KiB stacks, 2-KiB heaps and intact stack canaries. The existing
selection-language probe now uses 64,464 bytes and still loads/passes natively;
no stack/heap reservations were reduced. Native child order is not retained
through HWND recreation, and graphic order cannot cross native child HWNDs.

The full shell still stops at `Can't find unit Forms used by Calmira`
(`build/tests/control-view-shell-build.log`, make exit 2). Full desktop/Forms/DFM,
application minimization, hints and automatic screen-change events remain open.
AGENTS.md, original DFM/locale resources and the pinned FPC checkout remain
unchanged. See [the view contract](vcl_port.md#control-visibility-and-native-view-order).

The coordinate checkpoint passes `make test` (366 Python tests plus portable
Pascal/C) and all 60 corrected-compiler native suites under private-image
Win3.11/TCG with `GDI_TEST_SECONDS=60`, aggregate exit 0. Accepted logs are
`build/tests/coordinates-portable-regression.log` and
`build/tests/coordinates-final-regression.log`. Four focused native profiles
also pass in `build/tests/coordinates-focused.log`.

Windowed and windowless controls now expose typed ClientToScreen/ScreenToClient
using live USER client origins and checked signed-coordinate arithmetic.
Graphic controls also have writable BoundsRect and zero-origin ClientRect,
ClientWidth and ClientHeight, retaining virtual SetBounds and paint guards.
Native tests cover actual frame offsets, external moves, reparenting,
hidden/disabled queries, overflow, invalid rectangles and HWND recreation.
Handleless/orphan mappings reject without allocating windows; intermediate
origins must also fit signed Win16 coordinates. This is not deferred VCL mapping.

The new probe uses 57,024 bytes of static NE data budget, a 4-KiB stack, 2-KiB
heap and intact stack canary. The existing selection-language probe remains
at 64,464 bytes and passes natively. No stack/heap reservations were reduced.
AGENTS.md, original DFM/locale resources and the pinned FPC checkout are unchanged.

The separate full-shell check still fails at `Can't find unit Forms used by
Calmira` (`build/tests/coordinates-shell-build.log`, make exit 2). At that checkpoint,
mixed ControlCount/Controls[] enumeration remained unimplemented: ownership,
window tab order and graphic composition order are not interchangeable.
See [the coordinate contract](vcl_port.md#control-coordinate-conversion-and-graphic-geometry).

The parameterless-pump checkpoint passes `make test` (372 Python tests plus
portable Pascal/C). The full 62-suite corrected-compiler Win3.11/TCG run passes
with `GDI_TEST_SECONDS=60`, aggregate exit 0, in
`build/tests/pump-final-regression.log`. That full run precedes the final
DrainMessages-only sticky-exit guard: an already terminated caller must not
inherit a different active frame's later exit code. The final source and added
regression case pass four native profiles (new drain/application-pump plus
existing root/modal loops), aggregate exit 0, in
`build/tests/pump-sticky-focused.log`. The full batch was not repeated after
that last guard. Earlier four-profile runs also pass in
`build/tests/pump-focused.log` and `build/tests/pump-integration-focused.log`.
Host results are in `build/tests/pump-portable-regression.log`.

The new parameterless ProcessMessages overload drains queued work during an
active operation without calling idle or altering root Run state. It retains
the live current modal/root filter, guarded recursion, owner policy and signed
quit propagation. Native default-button clicks exercise cancellation and modal
completion. Construction/idle/transport/help/exception guards and filter-error
recovery pass. A nested modal quit inside a filter prevents subsequent native
dispatch of the original item. The bounded API remains unchanged in scope.

The final two probes use 51,360 and 62,912 bytes of static NE data budget with
4-KiB stacks, 2-KiB heaps and intact canaries. Existing reservations are not
reduced; selection-language passed the full run at its unchanged 64,464 bytes.
AGENTS.md, original DFM/locale fixtures and the pinned FPC checkout are unchanged.
Parameterless draining intentionally has no message/time budget and continuously
reposted work can keep it busy; it is not arbitrary VCL reentrancy. Original
file-operation/Forms integration is not established by the cancellation probe.
The shell still fails at missing Forms (`build/tests/pump-shell-build.log`,
make exit 2). See [the drain contract](vcl_port.md#parameterless-application-message-service).

The executable-identity checkpoint passes `make test`: 382 Python tests plus
portable Pascal/C, including 52 runtime-path text/buffer cases, in
`build/tests/identity-portable-regression.log`. Final native acceptance uses nine
Win3.11/TCG profiles: four in `build/tests/identity-focused-final.log` (identity,
application help, focused F1 help and selection language), plain/real-UPX package
launches in `build/tests/identity-package-final.log`, and the existing three
plain/packed/missing-help profiles in `build/tests/identity-help-path-regression.log`.
All three commands exit 0. The first six profiles use GDI_TEST_SECONDS=60;
the legacy help-path runner retains its normal timed WinHelp/dialog schedule.
The expanded 63-suite full batch is configured but was not run at this checkpoint.

ExeName/RuntimeExecutableName now identify the loaded resource-bearing NE file;
RuntimePackageExecutableName/RuntimeDirectory separately resolve installed
wrapper/data locations. Queries preserve CWD, lazy form/transport state and
callback/quit policy. Native tests open the actual NE file, load its bound icon,
mutate/restore source metadata and reject missing, relative, nonexistent, NUL,
multiline and overlong sidecars while accepting CRLF. Module buffers and metadata
reads are bounded; metadata targets must be readable drive-rooted files. This is
not authenticated package discovery or a completed IconDlg/ExtractIcon port.

Packed negative-case diagnostics exposed managed string-temporary cleanup
failures with intact stack guards. The final resolver uses portable ShortString
path operations and bounded native file handles instead of managed path
temporaries/large text records. No general compiler fix is claimed. The pack tool
also strips the colliding UPX tool-path environment variable from all three
pack/test/unpack child calls; real byte-exact round trips and host failure/output
preservation tests pass.

The identity probe uses 55,536 bytes of static NE data budget, with unchanged
4-KiB stack/2-KiB heap and intact canary in plain and packed runs. Focused F1 uses
63,392 bytes; selection-language remains at 64,464 bytes and passes. AGENTS.md,
original DFM/locale fixtures and the pinned FPC checkout are unchanged. The full
shell still stops at missing Forms (`build/tests/identity-shell-build.log`, make
exit 2). See [the identity contract](vcl_port.md#executable-and-installed-package-identity).

The windowless-enabled checkpoint passes `make test`: 386 Python tests plus
portable Pascal/C in `build/tests/graphic-enabled-portable-final.log`.
Eight corrected-compiler Win3.11/TCG profiles pass at GDI_TEST_SECONDS=60:
graphic, label, mnemonic and selection-language in
`build/tests/graphic-enabled-focused-final.log`; image, form-text, view-order
and focused F1 help in `build/tests/graphic-enabled-integration.log`.
Both native commands exit 0. The full configured 63-suite batch was not repeated.

Graphic Enabled state is local, defaults to True and survives reparenting,
detachment and native-window recreation. Disabling does not hide graphics.
Real state changes during painting/composition reject without state/DC damage,
including sibling changes; same-value writes remain harmless. Disabled labels
use system gray without changing Font, and mnemonic traversal skips them in
favor of eligible duplicates. Typed DFM Boolean assignments now support labels
and images without enabling graphic tab/help properties. This does not implement
automatic ancestor-disabled graying; at that checkpoint a common TControl and
mixed Controls[] also remained absent.

Publishing Label.Enabled initially raised selection-language static NE data to
64,512 bytes; that native run produced no application log and failed acceptance
(`build/tests/graphic-enabled-focused.log`). Keeping the property public instead
removes unnecessary RTTI, restoring its accepted 64,464-byte budget. Final F1
remains at 63,392 bytes. The expanded graphic/label/mnemonic probes use
59,232/58,256/61,792 bytes, unchanged 4-KiB stacks/2-KiB heaps and intact
64-byte stack canaries. No reservations or public capacities were reduced.
AGENTS.md, original DFM/locale resources and the pinned FPC checkout remain
unchanged. The full shell still fails at missing Forms
(`build/tests/graphic-enabled-shell-build.log`, make exit 2).
See [enabled-state scope](vcl_port.md#windowless-enabled-state).

### Historical mixed-control checkpoint (before the heap correction)

The mixed-control checkpoint implements a genuine shared abstract TControl and
ControlCount/Controls[] for direct native/windowless children. Public operations
route to the existing native, graphic and form policies; the separate mixed
list follows attachment order without changing tab or paint order. Staged
records are filtered by actual model Parent during callbacks, preserving exact
old positions on failed creation. Parent/owner independence, index errors,
original Enabled/free loops, actual graphic pixels and modal Hide are tested.
Label properties remain typed/public rather than carrying unused property RTTI.
Common geometry/Parent/Font/hint APIs and full Forms integration remain open.

That original checkpoint was NOT fully green or release-ready. The complete corrected
Win3.11/TCG command in `build/tests/mixed-controls-final-regression.log` exits 2:
54 of its 55 private GDI runs pass, but win16-password reports
`Invalid string catalogue` during resource cycles. The remaining eight GDI
profiles and separate classes fixture pass in
`build/tests/mixed-controls-tail-regression.log` (exit 0). This accounts for all
64 configured suites across batches: 63 have passed, with password still failing.
Do not count raw RESULT PASS lines as suites: diagnostic stdout can duplicate
markers. The initial four targeted profiles also pass in
`build/tests/mixed-controls-focused.log` before the final added Enabled-loop case;
the final child fixture is exercised by the complete run and later focused runs.

The password failure reproduces from its unchanged saved EXE and a clean normal
compile; adding diagnostic code or using the external assembler can mask it.
A private failure-hold build observed string ID 1203 returning Count=255 with
embedded NULs, whereas original type 6/block 76 contains the 15-byte string
`Enter password:`. Provider is nil and HInstance is retained. This establishes
an invalid buffer/count, not its underlying cause; resource-cache, ABI or other
memory corruption remains under investigation. The NUL validation is retained.
Detailed captured addresses are in
`build/tests/mixed-controls-resource-observation.md`; intentional hold builds
under build/tests are not acceptance targets or shipping code.

The optional provider call now has its own helper, reducing LocalLoadStr's
bound-only generated frame from 514 to 258 bytes without changing static budget,
public capacities or provider validation. This optimization did NOT fix the
password regression (`build/tests/mixed-controls-resource-focused.log`, exit 2).
Temporary production diagnostics and resource-cycle logging have been removed.
Host/source guards cover the separated frames; the compiler/pinned RTL are not
modified. See [mixed-child scope](vcl_port.md#shared-control-identity-and-mixed-children).

Final-source checks: `make test` passes 392 Python tests plus portable Pascal/C
in `build/tests/mixed-controls-portable-regression.log`. The final four-profile
command in `build/tests/mixed-controls-final-focused.log` exits 2: mixed children,
numeric resources and password-language pass, while plain password reproduces
the same failure. No final full-green result is claimed.

The child fixture uses 59,552 static NE bytes with unchanged 4-KiB stack/2-KiB
heap and intact 64-byte canary. Selection-language passes at 64,432 bytes,
focused F1 at 63,760 bytes. Password uses 64,128 and its language fixture 63,712;
passing canaries do not rule out arbitrary memory corruption. AGENTS.md,
original DFM/locale resources and the pinned FPC checkout remain unchanged.
The independent shell check still fails at missing Forms
(`build/tests/mixed-controls-shell-build.log`, make exit 2).

### Private Win16 RTL heap-shrink correction

The subsequent investigation finds a reproducible overwrite in the pinned RTL:
`SysGlobalReAllocMem` allocates the new small block but copies the whole old
allocation, even when shrinking. The minimal native probe places a 16-byte hole
directly before a live 128-byte guard and verifies that a 128-to-16 resize reuses
that hole. The old RTL overwrites the guard
(`build/tests/realloc-baseline.log`, make exit 2). The baseline's additional
prefix failure was coupled to the guard result; it is not evidence of lost
prefix bytes. Those assertions are now independent.

`tools/patches/fpc-win16-realloc-bounds.patch` bounds this copy by both lengths,
behind `CALMIRA_WIN16_REALLOC_BOUNDS` in the private GUI RTL. The original branch
is preserved when the flag is absent. Pinned sources, resource bytes, validation,
4-KiB stack/2-KiB heap and canary checks are unchanged. Allocation failure
semantics are outside this correction. A direct KERNEL resource-reader experiment
instead reached `Invalid bitmap dimensions`; it was not adopted as a workaround.

The first corrected normal-build batch passes the new shrink probe, original
password resource cycles, password-language and numeric-resource profiles
(`build/tests/realloc-focused.log`, exit 0). The fixture now additionally covers
odd and one-byte shrink destinations, small/global growth and shrink, same-size,
nil and zero-size behavior. The expanded four-profile batch also passes
(`build/tests/realloc-final-focused.log`, exit 0). `make test` passes 396 Python
tests plus portable Pascal/C (`build/tests/realloc-portable-regression.log`).
The complete normal-build `make -j4 win16-fixed-regression` also passes
(`build/tests/realloc-final-regression.log`, exit 0): 64 distinct private GDI
artifact logs and the separate classes fixture, all 65 configured suites.
This includes the previously failing original password's native validation
message and all 20 resource cycles. Result markers are counted per artifact,
not duplicated stdout lines. Runs use private Win3.11 image copies, corrected
QEMU TCG, at most four VMs, compiler profile `a5bfe73158371376800c` and staged
RTL source `4b0adcd8bdd26a10ec4a`. No diagnostic hold or alternate assembler is
used for acceptance.

The new probe uses 25,632 guarded bytes; password/password-language remain at
64,128 / 63,712 and selection-language at 64,432. Stack and heap reservations
are unchanged. AGENTS.md, original DFM/locale resources and the pinned FPC
checkout are unchanged. This resolves the tested foundation regression, not
the remaining full-shell port.
The independent shell build still stops at missing Forms
(`build/tests/realloc-shell-build.log`, make exit 2).

The helpers' original `.RES` resources are bound after FPC linking using
OpenWatcom `wrc`, because this FPC target cannot use Delphi's `{$R *.RES}`.

`WIN311_IMAGE=/path/to/win311.img make clfn-hook-runtime-test` passes native
cross-task Open, new long-name Save, Cancel/FILEOK veto, application-hook
preservation, tab-order and clean-unhook checks. A manual ClarisWorks test
saved and reopened a new long-named document without IFA. Native DOSLFN
enumeration, adapters for other private dialogs and automatic crash recovery
remain missing; this is not a complete IFA replacement.
See [file dialog acceptance](file_dialog_tests.md).
The first Word/Excel SDM adapter passes manual new-name Save/Open round trips
on DOS 6.22 with SHARE and independent native fixture tests through
`make clfn-office-runtime-test`. Newly typed long names currently require Enter
in the filename edit; Office on the DOS 7.1 test host is unresolved.
See [Office evidence and limits](office_dialog_tests.md).
7-Zip 26.04 source is pinned as a submodule. Its ZIP handler now runs as a
bounded DOS/32A helper, connected to a Win16 list window through a validated
binary index. The file-dialog system menu launches this separate viewer.
Standalone DOS 7.1 listing and the enhanced Windows 3.1x/DOS 6.22 bridge pass
native tests. DOS 7.x Windows launches are blocked because the tested host
faults when starting the helper. No extraction or native non-ZIP formats yet;
the complete shell remains unfinished. The add-on has a standalone GDI package
and an off-by-default option in the main descriptor; the hook starts explicitly.
`make archive-office-runtime-test` additionally exercises the ZIP menu in
actual Word/Excel from a privately supplied German Office installation;
this is separate from the SDM-shaped adapter fixtures.
See [usage](archive_viewer.md) and [porting status](archives.md).

## Full Shell Blockers

The original Microsoft WinFile application is a separate C port. Its core
modules build with OpenWatcom and run in Win3.11, but `make winfile16` still
fails in the Win32 networking/header layer. See [WinFile status](winfile16.md).

`make calmira` currently fails with `Can't find unit Forms used by Calmira`.
FPC's Win16 RTL is present, but it does not supply the Delphi 1 VCL. Adding the
local `vcl/` directory does not supply the framework. Graphics and Controls now
have tested subsets, including the original slider, pie chart, progress gauges,
standard label/image and native push/bitmap buttons. The original PicBtn now
also compiles and its Loaded policy passes native tests. Timer-driven progress
integration covers close/Escape and native Cancel-button mouse activation in
separate image/button profiles. This is not the original Progress form or a
complete VCL port. Combining both profiles exceeded the test's Win16 data budget
or failed native loading; the tested 1-KiB local heaps are not a final shell policy.

The first native message layer now covers the records used by the maintained
components. A private, opt-in Win16 RTL patch also adapts `TObject.Dispatch`
to their 16-bit message IDs; stock DWORD dispatch otherwise combines Msg with
WPARAM. Native checks exercise real SendMessage calls and typed handlers.
This is a foundation, not a Forms replacement. See [VCL port](vcl_port.md).

The GDI foundation now passes native pixel, text, DC-restoration and repeated
resource-change checks. Bitmap files load by scan line, including images above
64 KiB; resource/file pixels, 1/4/8/24-bit input and failed replacement are
checked under native Windows 3.11. This is not complete Graphics or Forms.
Deep bitmap assignment, overlap-preserving resize and scaled/overlapping
`CopyRect` now also pass native pixel checks, including start-menu style strip
growth. New bitmap areas initialize white; zero-sized images retain pending
dimensions. Generic bitmap/icon dispatch, native icon resource ownership and
color-key/brush-background compositing now also pass native tests. The final
Graphics compatibility subset now exposes typed public canvas/bitmap/icon
classes, bitmap-argument BrushCopy, native rectangles, point-size fonts and
color conversions; the unchanged original CalColor unit passes a native probe.
Writable image handles now have explicit transfer/copy/detach semantics, with
native lifetime tests. Shared-icon and borrowed-bitmap source paths are adapted;
taskbar icon cleanup distinguishes private extractions from class icons. The
legacy UI modules themselves are not runtime-verified while Forms is absent.
`TPicture` now owns and deep-copies bitmap/icon children, propagates managed
drawing changes and handles failed replacement/notification cases in a native
probe. Picture getters intentionally switch active image types. This is not
TImage/Forms integration or a generic codec/DFM implementation.
Native-tested 8x8 pattern snapshots now support original Brush.Bitmap setters,
with copied ownership and focus-color transitions. TextRect, DrawFocusRect,
Pie and border/surface FloodFill also have native pixel tests. Pattern getters,
arbitrary-size tiles and the actual visual controls are not implemented.
Bitmap StretchDraw supports opaque/transparent scaling and overlapping
self-stretch using snapshots, with native pixel/event/DC checks for the
wallpaper preview path. Arbitrary icon scaling and DFM/ICO streaming remain
before the original visual components can fully use this layer.
Its deliberate error tests exposed the stock Win16
Catch-wrapper return failure. The private GUI RTL now also enables an explicit
far tail-call compatibility fix, tested with native raise/re-raise/finally.
The stock RTL and pinned checkout remain unchanged. Complete Graphics/DFM
integration, complete Controls and Forms are still missing. The larger graphics probe
uses an explicit 4-KiB local heap and a build-time conservative NE data-budget
guard to prevent the Win3.11 startup memory error seen with its former default.

The separate `TNativeWindow` foundation now owns real HWNDs, binds four-byte
object pointers at WM_NCCREATE, dispatches typed messages and falls back to
DefWindowProc. Native tests cover reentrant creation/sends, callback exception
containment, creation failure, parent/child handle teardown and component owner
cleanup. It supplies neither a Controls API nor painting, input/focus events or
an application loop. Callback receivers must not be synchronously freed inside
their own handlers; deferred release is not implemented yet.
`TNativePaintWindow` now adds scoped virtual Paint with native update clipping,
background color, invalidation/repaint and cleanup even on paint exceptions.
Its visible-window pixel probe checks partial/disjoint updates and recovery.
`DrawNow` now permits explicit GetDC-backed callbacks outside Paint and reuses
active contexts for nested drawing. Reentrant WM_PAINT restores the outer HDC;
finally blocks restore/release owned contexts even on callback exceptions.
This is not a transparent legacy control canvas: automatic Canvas.Handle
acquisition, PaintTo and Forms integration still need separate work.
`TNativeInputWindow` now adds mouse/key and
focus events, native focus/capture ownership and key replacement/consumption.
Synthetic messages exercise real HWND callbacks; focus/capture use actual USER
APIs. This input class does not implement full Controls, click/drag synthesis or
IME. Tab/dialog routing and task pumping are supplied by the separate native
form/application layers, not implicitly by input callbacks. The class enables
CS_DBLCLKS for USER double clicks.

The initial Controls unit supplies real child-window size/visible/enabled
properties and explicitly creates handles for TCustomControl. The original
slider now uses these APIs, scoped drawing and native capture; no replacement
slider was written. Its conditional FPC path fixes stale saved strips after
partial paint/resize, focus-pattern colors and 16-bit narrowing of drag values.
Native acceptance covers vertical/horizontal drawing and actual thumb pixels.
The probe needs its tested 2-KiB local heap; the previous 4-KiB setting failed
native startup near the segment limit. Full TControl/TWinControl,
complete windowed hierarchy/Forms lifecycle, hints/help, click/drag-drop and Tab
navigation remain absent; an initial managed parenting subset is now available.
The nonwindowed TGraphicControl subset now composites opaque children into a
TCustomControl parent's paint/update regions without additional HWNDs. It has
explicit bounds, visibility, invalidation, reparenting and detach-on-parent-free.
The original Win95Pie component renders using its retained drawing algorithm;
native pixel/lifetime tests cover 0%/100%, clipping, exceptions and redraw cycles.
Graphics render to temporary full-size bitmaps before clipped parent copying;
direct partial rendering reproduced incorrect FloodFill shadows. A differential
partial-shadow test guards equivalence with the full render.
This does not implement interactive graphic hit routing, transparent controls,
inherited ParentColor, alignment or Forms/DFM.

Windowed controls now support stored/live Left/Top/BoundsRect, native move/size
synchronization and distinct outer/client dimensions. Managed Parent links create
descendant HWNDs recursively, preserve live handles during USER reparenting, and
retain model objects/bounds across native teardown/recreation. Failure tests cover
automatic and deferred child creation; parent destruction detaches independently
owned children. Native moves release subtree focus/capture and reject cycles.
This remains TCustomControl-specific, not the complete VCL or an automatic mirror
of arbitrary external USER reparenting. See the hierarchy acceptance target.

The earlier 64-KiB `CLASSES_TEXT` link failure is resolved by building a
consistent Win16 RTL with FPC's `-Wh` huge-code option. `make fpc-win16-gui-rtl`
keeps this RTL separate in `build/win16-rtl/units`; do not mix its PPUs with
the original large-code RTL. Its patched sources are now prepared separately
under `build/win16-rtl/sources/`, leaving the pinned checkout unchanged.
`make calmira` uses the huge-code RTL.
Native WfW 3.11 tests passed component RTTI/caption translation, TStringList
allocation/indexing and memory streams. Run them with
`WIN311_IMAGE=/path/to/win311.img make fpc-win16-classes-runtime-test`.
This fixes the nonvisual runtime, not the missing Forms/Controls framework.

`NHEADER.PAS` is integrated into the component registration and its portable
hit-testing core is tested. The GUI component itself still depends on the
unported VCL; it has not passed a complete Win16 build.

Consequently `make package` is a staging workflow, not a finished release. It
requires the remaining compiled shell/payload files and does not substitute
historical binaries silently. Do not publish the drive-list prototype as a
finished WinFile replacement or overwrite Windows' WINFILE.EXE with it.

## Executable Compression

Use the pinned, locally built GeosOne UPX fork, not stock UPX. `make pack-win16`
packs release copies only, runs `upx -t`, decompresses each copy and verifies
byte-identical restoration. Sizes and SHA-256 hashes go into
`build/packed/compression.json`. Compiler artifacts remain unchanged.

This fork's NE support extracts to a temporary EXE at startup; it is not an
in-place NE segment loader. Temporary writable disk space is required. DLL
packing is not supported. GDI separately packs both its DOS MZ engine and its
Win16 NE frontend. Compression does not fix missing application functionality.

## Initial Forms Unit

`src/win16/forms.pas` now provides the `Forms` unit name over the tested native
application, screen and modal-form layers. Unit initialization creates and
initializes the global `Application` and binds the global `Screen`;
finalization frees both, including owned forms. `TForm` derives from the native
modal form, so Show and ShowModal reuse the existing lifecycle. `MainForm`,
`Screen.Forms[]` and `Screen.ActiveForm` are typed as `TForm`; a registered
foreign native form is rejected by index and reads as no active TForm.

`caFree` and `TForm.Release` hide immediately and free the form later through a
registered message on the hidden application window, never inside the form's
own dispatch. Repeated Release queues once, an explicit Free cancels a pending
release and pending forms are freed during application teardown. A form whose
handler is still active below a nested pump must not be released; this matches
Delphi's own restriction.

`make win16-forms-runtime-test` checks these cases natively (23 checks,
including finalization). The probe keeps the 4-KiB stack/2-KiB heap and uses
63,504 bytes of the guarded data budget. `caMinimize`, form Icon/Menu,
FormStyle, hints and runtime DFM streaming are deliberately absent. With this
unit `make calmira` stopped at the next missing unit, `Dialogs`.

The complete `make -j4 win16-fixed-regression` passes with this suite added
(`build/tests/forms-final-regression.log`, exit 0): 65 distinct private GDI
artifact logs plus the separate classes fixture, all 66 configured suites.

## Initial Dialogs Unit

`src/win16/dialogs.pas` supplies the Delphi 1 `TMsgDlgType`/`TMsgDlgBtn`
types, `CreateMessageDialog`, `MessageDlg`, `ShowMessage`, `InputQuery` and
`InputBox`. Dialogs are real modal native forms with USER buttons, a shared
system icon and an EDIT control, not `MessageBox`, so every original button
combination works, including `mbYesNoCancel + [mbAll]` from fileman.pas.
OK, otherwise Yes, is the default button; Cancel, otherwise No, otherwise OK
handles Escape. Without OK/Yes the first button receives focus. Text wraps at
half the screen width. Titles and buttons use the form-text provider with
`TMessageForm.<Key>.Caption` entries in English, German and French; Cancel
reuses `TStandardButtons.Cancel.Caption`. A Help button calls
`Application.HelpContext` with the dialog's HelpContext.

`win16-dialogs-runtime-test` and `win16-input-query-runtime-test` drive the
dialogs from inside `Application.Run` through queued keys, mouse clicks and
characters, then read caption, button order, focus and edit selection back
through USER. They also cycle dialogs to check form, window and GDI release.
The common dialogs (TOpenDialog, TFontDialog, TColorDialog) are not provided
yet. `make calmira` now stops at the next missing unit, `ShellAPI`.
The complete `make -j4 win16-fixed-regression` passes with both suites added
(`build/tests/dialogs-final-regression.log`, exit 0): all 68 configured suites.

### DGROUP pressure (resolved by the huge data model)

In the large model both dialog probes needed a 1-KiB local heap: at 65,376
bytes Windows 3.11 refused to start the message probe with "not enough
memory". The FPC RTL alone (SysUtils, Classes, System, SysConst/RTLConsts
resource strings) occupied more than 40 KiB of DGROUP, plus VMTs and RTTI.
All GUI builds now use FPC's huge data model (see `docs/toolchains.md`): the
dialog probe's DGROUP drops from 64,352 to 5,136 bytes and the probes are back
to a 2-KiB heap. Two huge-model startup defects in the pinned RTL had to be
patched first; before that, the startup values (HInstance and others) were
written into DGROUP instead of the system unit's segment (window class, cursor
and module-path suites failed) and the stack bounds pointed into foreign
memory (text-file I/O faulted after the stack-guard fill). Expected trade-off,
not yet exercised by a test: Windows 3.x runs a program with several writable
data segments only once, so a second CALMIRA.EXE start is refused by Windows.

## Initial ShellAPI, IniFiles and Menus Units

`src/win16/shellapi.pas` imports SHELL.DLL with the Delphi 1 signatures
(registration database, drag-and-drop, ExtractIcon, ShellExecute,
FindExecutable). The registration-database ERROR_* values are SHELL's own
results, not DOS error numbers; Calmira's `vcl/files.pas` keeps declaring its
DOS codes locally. `make win16-shellapi-runtime-test` creates, queries,
enumerates and deletes a registration key, counts and extracts PROGMAN.EXE
icons, resolves the WIN.INI association and toggles WS_EX_ACCEPTFILES.

`src/win16/inifiles.pas` provides Delphi 1 `TIniFile` over the private
profile API (shared USER cache, `0x` hexadecimal integers, 8-KiB section key
buffer). `make win16-inifiles-runtime-test` reads a prepared file, writes and
rereads values, erases sections and checks the flushed file.

`src/win16/menus.pas` provides TMenuItem, TMenu, TMainMenu, TPopupMenu, the
shortcut conversions and the NewItem/NewLine/NewSubMenu/NewMenu/NewPopupMenu
helpers. Handles are created on demand; Caption, Visible, Break, ShortCut and
structural changes rebuild the parent's handle, while Checked and Enabled
update it in place as in Delphi 1, so a handle customized with ModifyMenu
(Calmira's owner-drawn start menu) survives them. Popup menus dispatch
WM_COMMAND/WM_INITMENUPOPUP through one hidden window (`PopupListWindow`).
`make win16-menus-runtime-test` checks real handle contents and flags,
in-place updates, rebuilds, FindItem/DispatchCommand, a TrackPopupMenu choice
by mnemonic, menu-bar attach/detach and USER resource release. Not provided
yet: form Menu/PopupMenu properties, keyboard shortcut dispatch, hints, menu
merging (GroupIndex) and menus in generated DFM code.

`src/win16/toolhelp.pas` (TimerCount, TerminateApp) and `src/win16/ver.pas`
(VER.DLL with the Delphi 1 signatures and VS_/VOS_/VFT_ constants) cover what
Calmira imports; `make win16-system-dlls-runtime-test` reads the real version
resource of USER.EXE. `src/win16/clipbrd.pas` provides TClipboard for text and
raw handles, owned by `Application.Handle` as in Delphi 1; graphic/component
formats are not provided yet. `make win16-clipbrd-runtime-test` covers it.

The full `make -j4 win16-fixed-regression` under the huge data model passed
all 70 then-configured suites (`build/tests/huge-regression.log`, exit 0);
Menus, system DLLs and Clipbrd were added afterwards and pass individually.

`make calmira` now compiles with `-Sh-` (Delphi 1 short strings) and Calmira's
directories ahead of the RTL. `TabNotBk` is an intentionally empty unit:
Calmira imports it but its DFMs page with ExtCtrls TNotebook/TPage, and no
source uses TTabbedNotebook. The build now reaches `vcl/miscutil.pas`, which
needs TRadioButton/TComboBox (StdCtrls), TSpeedButton (Buttons) and
TNotebook/THeader (ExtCtrls). Remaining missing units: Grids, Spin, Outline,
DdeMan, FileCtrl, Tabs.

## Radio Buttons, Combo Boxes, Notebook and Header

`src/win16/native_radio.pas` provides Delphi 1 TRadioButton on a private
BUTTON superclass with BS_RADIOBUTTON: the sibling grouping (checking one
unchecks the other radio buttons of the same parent), tab stop on the checked
button only, OnClick when a button becomes checked, Alignment and mnemonics.
Arrow-key movement within a group is not provided yet.
`make win16-radio-runtime-test` covers it.

`src/win16/native_combobox.pas` provides TComboBox for csDropDown, csSimple
and csDropDownList (owner-draw styles raise): Items mirrored into the native
list (sorted insertion, recreation with the edit text restored), ItemIndex,
Text, DroppedDown, DropDownCount (the native height includes the list),
MaxLength, SelectAll and OnChange/OnClick/OnDropDown/OnEnter/OnExit. Focus
rests on the internal edit, so TCustomControl gained `OwnsNativeChild` (used by
FindControl) and the input layer's `GetFocused` became virtual.
`make win16-combobox-runtime-test` covers it.

`src/win16/native_notebook.pas` provides TNotebook/TPage: Pages as a TStrings
whose Objects are the TPage controls (Delphi starts with a `Default` page),
PageIndex, ActivePage by caption and OnPageChanged. Pages fill the client area
on resize; a page whose handle Calmira freed (`FreePageHandles`) is recreated
with its children when shown. `src/win16/native_header.pas` provides THeader
with Sections (widths in Sections.Objects, default 64), SectionWidth[],
AllowResize and live divider dragging (OnSizing per move, OnSized at release)
instead of Delphi's XOR track line. `make win16-notebook-runtime-test` covers
both. They are not yet exported through ExtCtrls.

The full `make -j4 win16-fixed-regression` passed all 75 configured suites
(`build/tests/controls-regression.log`, exit 0) with the radio/combo box
changes to the shared Controls layer; the notebook/header suite was added
afterwards and passes individually.

### DFM inventory

Only 4 of 38 DFMs compile so far. The parser now accepts unnamed components
(Delphi 1 streams notebook pages without names); the compiler still rejects
them explicitly. Seven DFMs (filefind, fileprop, iconwin, opendlg, taskman,
taskprop, wastebin) do not parse yet because `THeader.Sections` encodes each
width as `#0width#0text`; those values now parse as a separate `nulstring`
kind that only `header_sections()` accepts, so all 38 DFMs parse. Most frequent unsupported classes: TMenuItem (103),
TBevel (31), TStyleSpeed (31), TPage (23), TComboBox (14), TRadioButton (13),
TListBox (10), TNotebook/TTabPanel/TPanel/TSpinEdit (9 each), TPopupMenu and
TOpenDialog (8 each).

## Graphic-Control Mouse Routing, Drag and Drop, Speed Buttons

The Delphi 1.02 install media are unpacked (outside git) into
`build/reference/delphi1/` and serve as the reference for constants and
signatures; this corrected `CM_BASE` to `$0F00` (`CM_ENABLEDCHANGED` +12,
`CM_MOUSEENTER` +19, `CM_MOUSELEAVE` +20, `CM_BUTTONPRESSED` +24).

`TCustomControl.WndProc` routes mouse messages to the topmost visible, enabled
graphic child, holds that child as capture target between button down and up,
and sends `CM_MOUSEENTER`/`CM_MOUSELEAVE` (a 100 ms timer detects leaving the
window). `TGraphicControl` gained MouseDown/Up/Move, Click/DblClick and their
events. `WindowFromPoint` is called through a packed `MakeLong(X, Y)` import
because the stock POINT-by-value declaration fails on Win16.

Drag and drop follows Delphi 1: `TControl.BeginDrag`/`EndDrag`, `DragMode`
(`dmAutomatic` for windowed and graphic controls), `DragCursor`, OnDragOver,
OnDragDrop and OnEndDrag (Target nil when not dropped), a 5 pixel delayed-drag
threshold, and a hidden capture window owned by `TNativeDragManager`.
`TControl.BoundsRect` and `TWinControl = TCustomControl` were added.

`src/win16/native_speedbutton.pas` provides TSpeedButton (GroupIndex, Down,
AllowAllUp via `CM_BUTTONPRESSED`, the checkered exclusive face, glyph frames);
Buttons exports it with TButtonLayout/TButtonState. Also new: `TControlCanvas`
(draws a graphic control through its parent DC with offset and clip),
`TCanvas.PolyLine`, ExtCtrls `Frame3D`, `TBrush.Bitmap`, and the ExtCtrls
aliases for TNotebook/TPage/THeader.

Two RTL patches keep Delphi 1 call sites compiling: `fpc-win16-const-rects`
makes the read-only RECT parameters of FillRect, FrameRect, IntersectRect and
friends `constref` (Delphi 1 passed them as const), and the Delphi 1 strings
patch now also declares `TFileName = ShortString` and a ShortString
`DateTimeToString`. `vcl/miscutil.pas` needed two `{$IFDEF FPC}` edits
(NormalizeRect, BOOL IntersectRect); the Calmira build now gets past MiscUtil
and stops at the first `{$R *.DFM}` (about.pas).

`make win16-speedbutton-runtime-test` and `make win16-drag-runtime-test` cover
the slice; the full `make -j4 -k win16-fixed-regression` passed all 77 suites
(`build/tests/drag-regression.log`, exit 0).

## Delphi 1 Fidelity Fixes, Spin and Bevel

An audit of the compat units against the Delphi 1.02 `*.INT` files found
Delphi 2+ values that are now corrected:

- System colours use the Delphi 1 encoding `TColor(-COLOR_x - 1)`
  (`clBtnFace = -16`), and `ColorToRGB` maps them back with
  `GetSysColor(-(Color + 1))`. `clNone`/`clDefault` (absent in Delphi 1) were
  removed; `clLtGray`/`clDkGray` were added.
- `TFillStyle = (fsSurface, fsBorder)` and
  `TMsgDlgBtn = (mbYes, mbNo, mbOK, mbCancel, mbAbort, mbRetry, mbIgnore, mbAll, mbHelp)`
  follow the Delphi order; FloodFill maps the style explicitly.
- `caMinimize` minimizes the form instead of closing it (a main form still ends
  the application, as in Delphi).
- `Application.OnMessage` has the Delphi 1 `TMessageEvent`
  `(var Msg: TMsg; var Handled: Boolean)` signature over the native filter.
- `TEdit.MaxLength` defaults to 0 (no limit; Text stays a 255-byte ShortString).
- `GetClientRect` is protected and virtual, as `TabPanel` overrides it.
- Graphics is compiled with ShortStrings like the other units and declares the
  Delphi 1 `TGetStrProc`; the RTL strings patch adds a ShortString `FmtStr`.
- Buttons declares `TButtonStyle`; Dialogs has `MsgDlgButtonStyle`,
  `MsgDlgGlyphs` (source compatibility only) and `MsgDlgBtnSize`, which sizes
  the dialog buttons (Delphi default 77x27).

`src/win16/native_spin.pas` (unit `Spin`) provides TSpinButton (400/100 ms
auto-repeat) and TSpinEdit (embedded button, `EM_SETRECTNP`, Value clamping,
MinValue/MaxValue/Increment, arrow keys, digit filter, clamp on exit);
`native_bevel.pas` provides TBevel, exported through ExtCtrls. Covered by
`make win16-spin-runtime-test` and `make win16-bevel-runtime-test`.

In Calmira's own VCL, `apholder`, `drives`, `dropserv` and `extform` got small
`{$IFDEF FPC}` edits (field order, `INT 21h` for the missing DOS3Call import,
the `Win31` unit). 24 of the 32 VCL units now compile standalone.

The full regression passed (`build/tests/audit-regression.log`, exit 0).

## Delphi 1 Types, List Boxes and Form Frames

- The RTL strings patch now declares `AppendStr`, `DateTimeToString` and the
  ShortString `FmtStr` with `OpenString` parameters, matching Delphi 1 `{$P+}`.
- `tools/patches/fpc-win16-delphi1-types.patch` (enabled by
  `CALMIRA_WIN16_DELPHI1_TYPES`) makes WinTypes declare only the Delphi 1
  record names `TPoint`/`TRect`, so `Point(...)` and `Rect(...)` are the
  Classes/Graphics functions again instead of FPC's `POINT`/`RECT` types.
- `src/win16/native_listbox.pas` adds TCustomListBox/TListBox (exported by
  StdCtrls): Items, ItemIndex, TopIndex, Selected, MultiSelect/ExtendedSelect,
  Sorted, Columns, IntegralHeight, owner-draw fixed/variable with
  OnDrawItem/OnMeasureItem, ItemAtPos/ItemRect and state kept across handle
  recreation. Covered by `make win16-listbox-runtime-test`.
- TForm has `BorderStyle`, `BorderIcons`, `Position` (`poScreenCenter`),
  `FormStyle` (`fsStayOnTop`; MDI is rejected), `Icon` (drawn and dragged while
  minimized, falling back to `Application.Icon`, which loads `MAINICON`),
  `Designer` (always nil) and `GetParentForm`. `TFormBorderStyle` and
  `TBorderStyle = bsNone..bsSingle` live in `control_base`.
- Forms has `AllocateHWnd`/`DeallocateHWnd` with `TWndMethod`; Controls has
  `NewStyleControls` (False on Windows 3.x).
- `{$R ...}` lines in `vcl/chklist.pas`, `vcl/extform.pas`, `vcl/sorthdr.pas`
  and `src/resource.pas` are guarded with `{$IFNDEF FPC}`. The final Calmira
  link must bind icons.res, bitmaps.res, cursors.res, chklist.res,
  capbtns.res, sorthdr.res, locale.res and calmira.res with wrc after linking.

`extform` and `sorthdr` now compile standalone. The full regression passed
(`build/tests/forms-regression.log`, 80 suites, exit 0).

## Align and Parent Properties

- `TControl.Align` (public, as in Delphi 1) with `alTop`/`alBottom`/`alLeft`/
  `alRight`/`alClient`. `TCustomControl.AlignControls` lays children out in
  that order, each group sorted by position. Parent resizes, child
  visibility/size/parent changes realign; `DisableAlign`/`EnableAlign` defer
  layout and `Realign` forces it. Covered by `make win16-align-runtime-test`.
- `Font`, `Color`, `ParentFont`, `ParentColor`, `ShowHint`, `ParentShowHint`
  and `Hint` moved into `control_base.TControl`; `TCustomControl` adds `Ctl3D`
  and `ParentCtl3D`. Assigning a value clears its `Parent*` flag, setting the
  flag re-reads the parent, and changes cascade to children (native ones get
  `WM_SETFONT`). `Font` is now separate from `Canvas.Font`, which is only
  refreshed from it, so paint-time canvas changes no longer alter the control.
  The nine controls with copied Font accessors now override `FontChanged`.
  TEdit, TComboBox and TListBox start with `clWindow` and `ParentColor = False`.
  `Ctl3D` and the hint properties are state only: nothing draws through
  CTL3D.DLL and there are no hint windows yet. Covered by
  `make win16-parent-runtime-test`.
- Dialogs and DFM-generated forms set the form's `Font`, and children inherit
  it instead of copying `Canvas.Font`. The DFM compiler accepts `ParentFont`,
  `ParentColor`, `Ctl3D`, `ParentCtl3D` (windowed controls only), `ShowHint`,
  `ParentShowHint` and `Hint`.

A plain `make win16-<name>` builds with the unpatched compiler in
`build/toolchains/fpc-win16`, which miscompiles these larger classes (a
TEdit reported a stray `Canvas.Handle`). Only the `win16-fixed-regression`
builds (`build/class-pointer/...`, `fpc-class-pointer`) are authoritative.

The full regression passed (`build/tests/parent-regression.log`, 82 suites, exit 0).

## Owner Draw, Popup Menus and Window Hooks

- Child windows get distinct control IDs (from `$100`), so a parent can route
  `WM_MEASUREITEM`, which names a control only by its ID. The parent reflects
  `WM_DRAWITEM`/`WM_MEASUREITEM` to the child as `CN_DRAWITEM`/`CN_MEASUREITEM`,
  as in Delphi. Controls declares the Delphi 1 `CN_*` constants (`CN_BASE = $2000`).
  The default handlers call `ControlDrawItem`/`ControlMeasureItem`, so Calmira's
  `TPathComboBox` can intercept and call `inherited`.
- `lbOwnerDrawVariable` list boxes ask `OnMeasureItem` for each item.
  `TComboBox` supports `csOwnerDrawFixed`/`csOwnerDrawVariable` with
  `ItemHeight` (default 16), `OnDrawItem`, `OnMeasureItem` and default
  text drawing, plus `OnDblClick` (`CBN_DBLCLK`).
- `PopupMenu` on TCustomControl and TGraphicControl: releasing the right button
  opens an `AutoPopup` menu at the cursor with `PopupComponent` set, instead
  of reporting MouseUp. A freed menu is cleared from its controls.
- `CreateWnd`/`DestroyWnd` are virtual hooks around the native window:
  CreateWnd runs after a child window and its native state (for example list
  items) exist, and DestroyWnd runs at `WM_DESTROY` or when the control is
  freed. Unlike Delphi, they do not create the window themselves.
- `TEdit.AutoSelect` (default True) selects all text when the edit is entered
  other than by mouse. `TEdit.BorderStyle` (`bsSingle`/`bsNone`) cannot change
  after the window is created.
  The DFM compiler now emits `AutoSelect` (IncSearch's edit sets it to False).
  The parent hands `CN_*` messages straight to the child's WndProc, as Delphi's
  `Perform` does, so an owner-draw failure is still recorded by the parent.

Covered by `make win16-ownerdraw-runtime-test` and the PopupMenu checks in
`make win16-parent-runtime-test`. `chklist`, `labelsel` and `pathcmbo` now
compile, so 29 of the 34 VCL units compile standalone. The remaining ones
need TApplication events (`apholder`, `calvcl`) and the Grids, Tabs and
DdeMan units.

The full regression passed (`build/tests/ownerdraw2-regression.log`, 83 suites, exit 0).

## Drawing Outside Painting

Calmira measures and draws through `Canvas` outside `Paint` (TextWidth for
column layout, drag feedback, hint sizing). As with Delphi's `TControlCanvas`,
a canvas without an assigned `Handle` now borrows a device context on demand:

- `TCustomControl.Canvas` uses `GetDC` on its own window. `TGraphicControl.Canvas`
  uses the parent window's DC, with the origin moved to the control and the
  clip limited to its bounds.
- `Canvas.Handle` stays 0 while a context is borrowed, so `Handle <> 0` still
  means "inside paint or owner draw". Assigning a Handle gives the borrowed
  context back first.
- Borrowed contexts are released when the message loop goes idle, when a
  window is destroyed, when a graphic control moves or changes parent, and
  when a canvas is freed. At most four are held at once; USER has only five
  common DCs, so the oldest is released first.

Covered by `make win16-canvas-context-runtime-test`.
`win16-paint-runtime-test` now checks that drawing outside paint borrows a
DC instead of raising.

The full regression ran with 84 suites (`build/tests/canvas-context.log`); the
only failure was the old paint check for the previous behaviour, which passes
after the update above.

## Application Hints

- Controls has Delphi 1's `THintWindow` (`ActivateHint`, `IsHintMsg`,
  `ReleaseHandle`, `Caption`, `Color`, `Canvas`), `THintWindowClass`,
  `FindDragTarget`, `GetShortHint`/`GetLongHint` and
  `TCustomControl.HandleAllocated`. Measuring text on a hint window's canvas
  creates its (hidden) window, as Delphi's `HandleNeeded` does.
- `TCanvas.ContextHandle` is what Delphi's `Canvas.Handle` returns: the DC,
  borrowed outside painting, with the font selected. `Handle` itself stays
  raw, so `Handle <> 0` still means "painting". Calmira's taskbar measures
  hint text this way (one `{$IFDEF FPC}` line in `task.pas`).
- `TApplication` has `Hint`/`OnHint` (the long hint of the control under
  the mouse, or of its nearest parent with a hint), `ShowHint` (off by
  default), `HintColor` (`$80FFFF`), `HintPause` (800 ms), `OnShowHint` with
  `THintInfo`, `CancelHint` and `HintWindowClass`. A hint pops up below the
  control after `HintPause`. Moving to another control while a hint shows
  replaces it after 50 ms. Keys, clicks and commands hide it. When
  `OnShowHint` refuses a hint, the next mouse move asks again, which
  Calmira's file grid needs to show hints only over files.
- Forms declares `TExceptionEvent`, `TIdleEvent` and `TWindowHook` as Delphi
  1 does, over the matching native types.
- `WinProcs.PtInRect` takes USER's packed POINT and gives wrong answers for a
  Pascal `TPoint`; use `Controls.PtInRect`.

Covered by `make win16-hints-runtime-test`. `calvcl` still needs the Grids
unit.

The full regression passed (`build/tests/hints.log`, 85 suites, exit 0).

## Minimize, Restore and Screen Events

- `Application.Minimize` hides every visible form of the task, registered
  through `CreateForm` or not, and shows the application window as a desktop
  icon titled `Application.Title` and drawn with `Application.Icon`. In
  Delphi 1 all forms are owned by the application window and USER hides
  them; here forms are not owned, so the application hides them itself.
- Opening the icon (double click, `SC_RESTORE`, `WM_QUERYOPEN`) or calling
  `Restore` shows those forms again, skipping any freed meanwhile. It hides
  the application window and reactivates the form that was active.
  `OnMinimize`/`OnRestore` run once per change.
- As in Delphi 1, `SC_MINIMIZE` on the main form minimizes the application.
  Other forms minimize on their own.
- One difference: while the application is minimized, a hidden form's
  `Visible` reads False, because it follows `WS_VISIBLE`.
- `Screen.OnActiveFormChange` runs when a different form is activated.
  `Screen.OnActiveControlChange` runs when a different control gets the
  focus, before that control's `OnEnter`, as Delphi's `SetFocusedControl`
  does. Freed controls and forms are dropped through `FreeNotification`.
- Before this, `vcl/apholder.pas` compiled even though these members were
  missing: inside `with Application do`, FPC bound `OnMinimize := FOnMinimize`
  to TAppHolder's own property. That made the assignment a silent no-op. The
  native test now checks that TAppHolder's events reach Application and
  Screen, and that freeing it clears them.

Covered by `make win16-minimize-runtime-test`.

The full regression passed (`build/tests/minimize.log`, 86 suites, exit 0).
