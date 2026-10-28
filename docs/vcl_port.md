# Win16 VCL Port

The full shell still stops at `Can't find unit Forms used by Calmira`.
There is no completed Forms/Controls/Graphics implementation and no replacement
desktop binary. This port adapts the existing sources in small native-tested
layers; it does not treat empty compatibility units as a working framework.
A deliberately small Controls subset now runs the ported original slider and
the original windowless Win95 pie chart;
this does not supply the rest of the shell's control/form hierarchy.

`make win16-ui` builds the twenty-five current control-layer probes together;
`make -j4 win16-ui-runtime-test` runs them in separate disposable image copies.
See [test setup](../tests/readme.md#native-ui-acceptance-batch) for the prepared
image and corrected private TCG emulator environment used on this host. This is
a regression batch, not a completed shell build.

## Message layer

`src/win16/messages.pas` adapts the used record subset from the pinned Free
Pascal RTL. Its provenance is in `messages.origin.json`; LGPL and the RTL
linking-exception texts are under `docs/licenses/`. Historical authorship is
retained. The original source and ordinary installed FPC RTL are not modified.

The adapter rejects non-Win16 targets. Records use two-byte alignment, a
16-bit message ID and WPARAM, a four-byte LPARAM/far pointer and a four-byte
result: twelve bytes overall. Coordinates and scroll positions are signed.

| Message | Win16 parameter layout |
| --- | --- |
| `WM_COMMAND` | WPARAM = item ID; LPARAM low = control handle, high = notification |
| `WM_VSCROLL` | WPARAM = scroll code; LPARAM low = position, high = scrollbar handle |
| `WM_ACTIVATE` | WPARAM = activation; LPARAM low = window handle, high = minimized |
| Mouse buttons | WPARAM = keys; LPARAM low/high = signed X/Y coordinates |
| Owner draw/min/max | LPARAM = native far pointer to the relevant structure |

These are not the Win32 layouts. Constants and base API types continue to
come from FPC's existing `WinTypes`/`WinProcs`, not copied Win32 headers.

## Private RTL dispatch compatibility

Stock FPC `TObject.Dispatch` reads a DWORD message ID. A Delphi-1-style Win16
record instead starts with `Word Msg; Word WParam`: a nonzero parameter then
becomes part of the dispatch ID and handlers are missed. The initial native
test reproduced exactly that failure; a zero-WPARAM min/max request passed.

`tools/patches/fpc-win16-message-dispatch.patch` adds the 16-bit read only when
both `WIN16` and `CALMIRA_WIN16_MESSAGE_ABI` are defined. The huge-code GUI RTL
build enables that compatibility option. This changes the private GUI RTL's
dispatch convention; do not use it for generic DWORD message-ID protocols.
The unpatched/default branch retains normal FPC behavior.

`prepare_win16_rtl.py` fingerprints tracked RTL contents and the patch, then
creates a separate source tree below `build/win16-rtl/sources/`. Patching fails
closed if its expected context differs. Identical inputs reuse that tree;
changed inputs get a new one without overwriting the old copy. Generated
objects and all modified sources stay outside the pinned FPC checkout.
Do not mix its huge-code PPUs with the stock large-code units.

### Private GUI text-file ABI

The GUI RTL also enables `CALMIRA_WIN16_GUI_STDIO` through a scoped patch to
`rtl/win16/system.pp`. It uses FPC's existing ANSI Text/FileRec name option and
true standard-stream aliases: Output, StdOut, ErrOutput and StdErr share one
native MessageBox diagnostic channel. Independent DOS stdout/stderr redirection
is deliberately **not** part of this private GUI ABI; redirecting one output
name redirects all four. Use explicit Text variables or file handles for logs.
Input remains a separate record. Initialization and exit close each record once.

Filename capacity remains 256 bytes, text buffers remain 256 bytes, and Unicode
string support, RTTI, exceptions and explicit file/stream I/O are retained.
This removes roughly 3 KiB of otherwise duplicated static records without
reducing application stacks/heaps or bypassing the NE budget guard. Rebuild all
GUI units together; do not mix old/new Text/FileRec PPUs. The vendor checkout
and stock compiler runtime remain untouched. `win16-gui-stdio-runtime-test`
checks alias addresses, file ABI, shared redirection/restoration and 600-character
text reads/writes across full-size buffer boundaries. The original component/
stream/exception acceptance remains `fpc-win16-classes-runtime-test`.

### GUI diagnostic storage and close behavior

The private GUI branch stages `src/win16/rtl_gui_error.inc` alongside the patched
System source. Its full 1,024-byte diagnostic capacity plus NUL now lives in one
fixed Windows global-memory block, allocated/reused at GUI stdio initialization
and released at task exit. It no longer consumes automatic DGROUP. Allocation
or lock failure falls back to complete, bounded 256-byte stack chunks without
using the Pascal heap. This does not reduce application stacks/local heaps or
the 256-byte TextRec buffers. The selection fixture saves 1,008 guarded bytes
from this storage change before additional test coverage is linked.

The GUI channel uses a custom-device handle, not DOS stderr: FPC's generic Close
otherwise skips its CloseFunc for console handles, leaving partial diagnostics
undisplayed until task exit. Close now flushes that suffix through ErrorClose.
Full/partial output honors NoErrMsg. A write crossing the 1,024-byte boundary
advances its source pointer correctly rather than repeating its prefix.
Recursive diagnostic writes from a MessageBox callback remain unsupported.

`test_gui_error_buffer.pas` compiles the identical include on host and Win16 with
range/overflow checks. Mocked Windows APIs verify exact text, canaries, full and
split boundaries, allocation/lock failures and balanced release/reuse. This is
algorithmic fault injection, not exhaustion of the guest's global heap.
`win16-gui-diagnostics-runtime-test` separately exercises the real System output
and actual USER MessageBoxes: partial buffering, full emission, Close suffix
flush and NoErrMsg. Its timer closes only this task's boxes using their actual
button IDs, without queuing Enter into the next box.

RTL staging fingerprints both patches and overlay contents; schema-2 manifests
record the overlay SHA-256. Historical staged trees and the pinned vendor source
remain untouched. Provenance and the RTL linking exception are retained in
`rtl_gui_error.origin.json` and `docs/licenses/`.

## Native window foundation

`src/win16/native_window.pas` supplies `TNativeWindow(TComponent)`, an owned
native window and message-dispatch base, not a `Controls` or `Forms` substitute.
It registers process-lifetime private classes. Each HWND stores its
object's complete four-byte far pointer at the end of its private window bytes, populated from
`CREATESTRUCT.lpCreateParams` during WM_NCCREATE. No global "current object"
is used, so simultaneous windows and reentrant creation remain independent.
The ordinary window class uses offset zero. USER control superclasses append
the pointer after the original class's extra bytes, leaving its native data
untouched. The private message-compatible GUI RTL is required for `message` handlers.

`CreateHandle(Parent, Caption, Style, X, Y, Width, Height)` creates explicitly;
the constructor does not allocate a window. Captions are ANSI ShortStrings,
without embedded NULs. Negative dimensions, invalid parents, parentless child
styles and duplicate/reentrant creation on the same object are rejected.
`Perform` sends synchronously and rejects detached objects. Unhandled messages
go to DefWindowProc for ordinary windows; control superclasses forward through
their original USER procedure. There is no application loop, automatic painting
or PostQuitMessage policy here. This is private class registration, not attachment
or subclassing of arbitrary foreign HWNDs.

WM_NCDESTROY always clears the association and object handle, even if a handler
raises. Native parent destruction also detaches its child windows without
freeing the Pascal child objects. Component ownership separately frees objects
and their windows. `DestroyHandle` is idempotent; a detached object can recreate
its window. Destruction during creation is rejected. Object destruction bypasses
derived message handlers while native cleanup still runs.

Callback exceptions never unwind into USER: bounded `LastCallbackError` and a
saturating `CallbackErrors` counter retain diagnostic state until explicitly
cleared. WM_NCCREATE/WM_CREATE exceptions reject creation; other failures return
zero. Creation failure clears even a provisional handle when USER omits
WM_NCDESTROY. Handlers must not free their receiver or its component owner
synchronously; defer object destruction until callback return. Queued release
and full control parenting APIs remain future layers; scoped painting, input
and focus events are supplied by the separate descendants below.

```sh
make win16-window
WIN311_IMAGE=/path/to/baseline.img make win16-window-runtime-test
```

The native probe checks object isolation, high WPARAM/signed LPARAM/results,
nested SendMessage and child creation, default processing/close, callback errors,
parent/child destruction, owner cleanup, rejected creation and USER-pool stability
across 150 successful and 100 failed creation cycles. It uses disposable image
copies with the existing TCG-only test setup; no installed desktop is replaced.

## Explicit task message loop

`native_loop.pas` supplies `TNativeMessageLoop`, the queue foundation used by the
explicit application layer below, not a `Forms.Application` placeholder. `Run` waits
through native GetMessage, then TranslateMessage/DispatchMessage. The whole
task queue is read without an HWND filter, including native timer callbacks.
`ProcessMessages(Limit)` removes at most that many messages without waiting;
the positive limit prevents a self-posting handler from monopolizing the caller.
Its result counts completed dispatch/filter items, excluding WM_QUIT and an
item abandoned because a nested modal filter terminated the frame.

Either entry point consumes WM_QUIT once, retains its signed 16-bit `ExitCode`
and sets `Terminated`. Later calls do not consume more messages; Run returns
the stored code. Termination is permanent for that instance. Use native
PostQuitMessage explicitly; closing an arbitrary window does not automatically
terminate the loop. A deliberate successor instance can process remaining queue
items after the previous pump returns. Do not run multiple logical application
loops concurrently: the USER queue belongs to the task, not the object.

Run/bounded-ProcessMessages reentry, including through another instance during a
callback, is rejected before touching the queue. A finally block releases task ownership.
Native-window callback exceptions retain the window's existing diagnostic and
containment behavior; later messages continue. Do not free the loop while one
of its entry points is active. The optional OnMessage method filter runs before
TranslateMessage/DispatchMessage; True consumes the item. WM_QUIT always bypasses
the filter. Filter exceptions propagate after releasing the pump guard; unlike
native HWND callbacks they are not recorded in a window's diagnostic. The filter
receiver must outlive its assignment: clear OnMessage before freeing it.
Explicit modal pumps and the opt-in DrainMessages entry below have separate
controlled entry points.
The optional OnStart callback runs inside Run's task-ownership guard and finally
region, before the first GetMessage. It is skipped for terminated loops and is
not called by ProcessMessages. Startup can therefore open a modal child without
losing propagation of its WM_QUIT to the root. IsDialogMessage and accelerators
remain unimplemented. Cooperative idle is a separate opt-in layer below;
main-form policy belongs to the application layer, not an arbitrary message-loop
instance.

```sh
make win16-loop
WIN311_IMAGE=/path/to/baseline.img make win16-loop-runtime-test
```

The native probe checks posted message ordering/budgets (including self-posting
handlers), empty pumping, window close without implicit task exit, nested
queue guards, callback recovery, actual TranslateMessage character generation,
repeated pumping, timer-driven blocking wakeup, signed quit codes and retained
post-termination queue items. Keyboard events are synthetic, not physical-input
or full Forms acceptance. Existing synchronous input probes remain separate.

## Explicit native application lifecycle

`native_application.TNativeApplication` is an explicit, task-affine component,
not a global Application object or a substitute `Forms` unit. Initialize is
required and idempotent; only one initialized application may exist in a task.
RegisterForm adds a nonowning, duplicate-safe weak registration. MainForm must
be registered and cannot be reassigned during a pump. TComponent ownership is
separate: construct a form with the application as AOwner only when it should
be freed with the application. Readonly Forms/FormCount expose the registry.

```pascal
App := TNativeApplication.Create(nil);
try
  App.Initialize;
  Main := TNativeForm.Create(App);  { owned explicitly, not by registration }
  App.RegisterForm(Main, True);
  Main.Caption := 'Application';
  App.Run;
finally
  App.Free;
end;
```

Run shows MainForm through the loop's guarded OnStart entry point unless
ShowMainForm is False. The policy defaults to True and may be changed only
outside construction and pumping; disabling it leaves an uncreated main HWND
uncreated. This supports a hidden shell lifetime window without showing it as
a side effect of starting the task. ProcessMessages(Limit)
is bounded and nonblocking and does not automatically show it. Run and this
bounded overload reject reentry and clear application state after startup/filter
exceptions. The parameterless overload below deliberately permits draining from
an active root/modal operation, with its own recursion guards. The client
OnMessage filter runs before scoped registered-form Tab/Enter/Escape/Alt routing;
a consumed item is not dispatched. Activation may remove other registered forms:
lookup completes before invoking a form and iteration does not resume afterward.

Forms attach to a weak TNativeFormHost through readonly LifecycleHost. TryClose
returns whether a hide/destroy close action completed; no host notification is
sent for veto, ncaNone or a failed close. Notification occurs after the lifecycle
guard is released, without replacing OnCloseQuery, OnClose or OnHide. The
application requests quit only for its current main form, including native sent
WM_CLOSE/system-close paths. Hide is not Close; closing a secondary form does
not stop the task. Freeing/unregistering the main form during a pump also requests
quit; secondary destruction only removes its registry entry. Application teardown
detaches hosts before inherited component destruction and does not synthesize quit.

Terminate posts native task quit once; the first Terminate call's signed code wins.
QuitRequested is immediate, while Terminated/ExitCode describe actual WM_QUIT
consumption. USER may defer PostQuitMessage behind pending work: no FIFO position
relative to arbitrary window messages is assumed. After consumption, repeated
Run/ProcessMessages neither repeat startup nor steal a successor's queued work.
WM_QUIT bypasses client filters. Owner-scoped modal dialogs opened during startup run
under the already active root pump, preserving signed quit, owner enable/focus
cleanup and startup-error recovery.

Use the application as the task's root pump and keep it alive throughout every
pump/callback. Standalone modal pumps before Run are not automatically coordinated
with this object: callers must honor their TaskQuit/TaskExitCode instead of
reentering Run after another root consumed quit. Freeing the application from
its own callbacks is unsupported. Cross-task transport to its hidden window is
tested below; hosting the application object in another task or DLL is not qualified.
There is no reflective component streaming, global Screen,
exception UI policy, idle handling, accelerators,
full runtime DFM streaming or completed shell integration.

`win16-application-runtime-test` covers initialization/registry bounds, foreign
hosts, weak/owned lifetimes, veto/none/failing close, queued and sent system close,
main removal, timer quit, successor preservation and startup/filter recovery.
`win16-application-dialog-runtime-test` covers multi-form native edit/button
routing, registry mutation during activation, filter priority, close policy and
normal/quit/failing modal startup. Both retain 4-KiB stacks and 2-KiB heaps and
check stack-bottom canaries. They are included in win16-fixed-regression.

### Executable and installed-package identity

The original IconDlg uses Application.ExeName as an icon-resource filename.
TNativeApplication now exposes a read-only ExeName matching KERNEL's actual
loaded module, with initialization/task-affinity checks. It creates no transport
or form and remains readable during sent/help/exception callbacks and after quit.
This is an explicit application property, not a new global Forms.Application.

| API | Meaning when launched through the pinned UPX wrapper |
| --- | --- |
| ExeName / RuntimeExecutableName | Actual temporary NE executable containing original resources |
| RuntimePackageExecutableName | Installed wrapper named by a valid readable source sidecar; otherwise the actual NE path |
| RuntimeDirectory | Directory of that package executable, for help/catalogue/configuration data |

Do not substitute a package directory or wrapper filename for a resource-bearing
NE file, or persist the temporary loaded filename across launches. Plain starts
use the same file for module and package identity. Paths do not follow CWD.
The UPX basename/source-sidecar convention is a location heuristic, not package
authentication; UNC sidecar targets remain outside its drive-rooted contract.

The module API buffer is initialized and decoded by explicit count/capacity,
terminator and embedded-NUL checks, with a 255-byte public limit. Failure raises
EInvalidOp rather than searching relative to CWD. Package metadata is read through
a bounded Windows file handle (258 bytes), accepting a single path with optional
CR/LF and rejecting truncation, NUL, multiline, relative and overlong data. A
readable installed file is required; invalid/missing metadata falls back to the
actual loaded module. Small ShortString path helpers avoid managed path-temporary
cleanup failures exposed by the packed negative-case probe. No general compiler
or filesystem-driver fix is claimed.

The identity probe checks actual KERNEL names, NE file headers, bound original
icon resources, CWD independence, callback/quit scopes and a stack canary with
unchanged 4-KiB stack/2-KiB heap. The package runner installs the executable under
IDENTPKG, runs from WINDOWS with a separate TEMPPATH, and tests plain and real
UPX-packed launches, source-sidecar mutations/restoration and overlong reads.
This prepares identity access for IconDlg; it does not port its full Forms/UI or
qualify Shell.ExtractIcon. The pack tool removes UPX from child environments:
our runners use it as a tool path, whereas UPX interprets it as option text.
Explicit pack/test/unpack arguments retain byte-exact round-trip verification.

### Parameterless application message service

Original fileman/filefind/progress/start code calls Application.ProcessMessages
without a limit, often inside a dispatched operation callback. The explicit
TNativeApplication now provides that procedure overload alongside the unchanged
bounded function. It drains the task queue until empty or terminated, including
new messages posted by callbacks, without waiting, running startup or calling
OnIdle. There is no artificial Word-sized message cap; an endlessly replenished
queue can keep this call busy. The bounded API remains available for standalone
bounded pumps, not as a newly reentrant in-operation API.

The low-level DrainMessages operation creates a temporary child pump frame,
retains the current modal/root filter through a live forwarding method, and
restores the suspended frame in finally. Outside an active pump it forwards its
caller's filter. Filter reassignment is observed on the next item; modal routing
is not replaced with the application's root filter. Native default-button
activation can therefore deliver a real cancellation while a long operation is
inside its callback, and also complete an active modal dialog with its owner
still disabled until normal modal teardown.

Recursive drains, including through another loop object or a modal descendant
of an active drain, are rejected before reading the queue. Run/bounded pumps
also remain rejected while draining. Drains from active idle providers are
rejected across the ancestor chain. At application level initialization and task
affinity are required; construction, sent transport hooks, help and exception
callbacks remain guarded. Outside Run the saved pumping flag is restored rather
than pretending that Run started; inside Run its Running/pumping state survives
normal completion and filter exceptions. Receivers, forms and the application
must still outlive their active methods/callbacks.

WM_QUIT bypasses filters, is consumed once and retains its signed exit code.
The child marks all suspended root/modal ancestors terminated, and also marks
an unrelated explicit caller loop. Subsequent calls on terminated instances do
not drain more work or overwrite the caller's first exit code with another
frame's later termination code. A filter that opens a modal child which consumes quit must
not subsequently dispatch the original item; the central delivery path now
checks termination before filters and again before native translation/dispatch.

`win16-drain-runtime-test` covers finite repost chains, empty queues, live filter
mutation, same/peer recursion, idle guards, filter-error recovery, active modal
filter inheritance, nested signed quit and successor isolation. It also verifies
sticky caller exit codes across another terminating root and that modal quit
inside a drain filter suppresses actual native dispatch.
`win16-application-pump-runtime-test` checks the parameterless overload with a
real Cancel/default-button click from an operation handler, nested modal routing,
owner restoration, root flags/quit, construction/idle/transport/help/exception
guards and successor/error recovery. Both retain 4-KiB stacks, 2-KiB heaps and
stack-bottom canaries. This is scoped controlled draining, not arbitrary VCL
reentrancy or complete Forms integration.

### Class-reference form creation

`CreateForm(TNativeFormClass, var Reference)` invokes the actual virtual
constructor, including constructors generated from supported original DFMs.
The caller must supply a nil variable of the requested form class (or a compatible
ancestor); the untyped Delphi-style `var` cannot check variable types at runtime.
The reference is published before construction so FormCreate code can find it.
Only successful construction is followed by registration. The first factory-created
form becomes MainForm when none is selected; later forms keep that selection.
All factory-created forms are owned by the application, but are not shown yet:

```pascal
Main := nil;
App.CreateForm(TNativeForm, Main);
App.ShowMainForm := False;  { optional hidden shell root }
```

Allocation, constructor and AfterConstruction failures clear the reference and
leave no registered/owned partial form. A failure after successful construction
frees the completed instance exactly once. An existing nonnil reference is rejected
without overwriting it. Nested factories, pumping and manual self-registration
during construction are rejected; ordinary secondary creation during Run is allowed.
The application and form must not free themselves or rewrite the reference from
construction callbacks. References are not automatically cleared on later form
destruction: their callers must not reuse dangling variables.

`win16-application-factory-runtime-test` covers these boundaries, virtual lifetime
hooks, recovery and hidden-main startup. `win16-application-original-runtime-test`
creates the original incremental-search dialog through the factory during startup,
then tests original search/Enter, empty Escape, native owner restoration and HWND
recreation under the active root loop. Both keep 4-KiB stacks, 2-KiB heaps and
stack canaries. The original password-dialog combination was attempted but refused
native startup at 64,704 and 64,512 guarded bytes despite passing the static size
check (`build/tests/application-original-local.log` and
`build/tests/application-original-compact.log`); its integration is not qualified.
The separate existing password tests remain required. No generic runtime DFM
streamer or global Forms.Application is introduced by this factory.

### Hidden application window and hooks

`native_application_window.pas` supplies the separate, lazy `Application.Handle`
transport. The explicit TNativeApplication object still requires Initialize;
reading Handle creates an invisible, zero-size, parentless WS_POPUP, not the main
form. Its module-local class is `TApplication` and its initial Title is `Calmira`,
matching the original helper programs' FindWindow contract. Changing Title changes
discovery too. Titles retain the 255-byte ANSI interface, reject embedded NULs
and are checked against USER after SetWindowText (a procedure in the Win16 API).
An intercepted, unsuccessful title change does not update the cached value.

Native class reuse verifies its procedure, four-byte object slot and module;
an incompatible local class is rejected rather than overwritten. The handle is
released before application-owned forms are destroyed. External HWND destruction
clears the association without posting quit; a later Handle access recreates it
unless task termination has begun. No promise is made to replay messages posted
to a destroyed HWND. Initialize alone and ordinary registration need not allocate
the transport HWND.

HookMainWindow/UnhookMainWindow register method callbacks returning True to
consume a TMessage. Hooks run newest first, preserve signed results and compare
both code and receiver for duplicate/removal checks. Removing an absent hook is
harmless. Registering a hook ensures the HWND exists before that hook is attached.
Hooks do not intercept native creation/destruction association messages. Mutating
hooks/title or entering Run/ProcessMessages while dispatching is rejected, including
nested sends. Receivers must outlive registration and must not free the application
or transport from their callbacks. Exceptions remain inside the existing native
USER boundary: result zero, WindowCallbackErrors/LastWindowCallbackError recorded,
then later messages can recover. ClearWindowCallbackError resets diagnostics.

Queued messages pass through OnMessage before native dispatch: a consumed post
does not reach the window hook. Synchronous SendMessage bypasses that queue filter
but reaches hooks. WM_CLOSE, unless consumed by a hook, delegates to the main
form's real query/close policy; without a main form it requests task quit. It does
not destroy the transport or bypass a main-form veto. This does not implement
session-save policy, minimization, hints or Help. Task activation and the explicit
screen view are separate layers below.

`win16-application-window-runtime-test` verifies class-collision recovery, hidden
identity, 255-byte titles/veto, full method identity/order, nested sends, mutation/
pump rejection, exception recovery, queued filtering, native recreation and close
policy. A separately launched APPSEND.EXE locates TApplication/Calmira, sends the
original registered WM_CALMIRA message and posts a signed reply through that same
protocol. Tests verify distinct sender/receiver tasks, InSendMessage, the receiving
task context and separation from OnMessage. This qualifies message transport,
not the shell actions assigned to those command IDs. The native test retains
its 4-KiB stack, 2-KiB heap and stack-bottom canary; the runner installs the helper
only into its disposable image copy.

### Cooperative idle service

TNativeMessageLoop exposes OnIdle(Sender, var Done), and TNativeApplication
forwards it as Application.OnIdle with the application as Sender. Registration
requires an initialized, task-local application but allocates no HWND. The event
receiver must outlive registration and every active root/modal pump. Clear the
event before freeing its receiver; never free the loop/application from callbacks.
Rebinding the currently executing provider and entering Run/ProcessMessages
recursively are rejected. Idle exceptions propagate to the Pascal caller rather
than being presented as native window callback errors; all pump/provider guards
clear in finally so callers can recover, rebind and retry.

Idle runs only when an unfiltered PM_NOREMOVE query finds no pending messages.
That query may dispatch sent callbacks, so termination and the nearest handler
are rechecked afterward. No pending message is removed by the idle check.
Done starts True on every call. Leaving it True returns to blocking GetMessage;
it does not repeatedly poll an empty queue. Done=False explicitly requests another
work slice, yields cooperatively to Win16 tasks and rechecks the unfiltered queue
before repeating. A handler that always requests more work may consume CPU by
design; keep slices bounded and leave Done True when finished. Queued work and
WM_QUIT take precedence. The bounded, nonblocking ProcessMessages API does not
invoke idle or extend its message budget with idle work. Without a handler,
ordinary Run/RunModal retain their direct blocking GetMessage path.

A modal loop uses its own handler or inherits the nearest active parent's service.
The low-level Sender is the current pump, not necessarily the provider; application
forwarding still uses the application object. If that provider is already executing
an idle callback which opened the modal loop, inherited idle is skipped until it
returns. A modal child may supply an independent handler explicitly. Modal
conditions are rechecked after idle before blocking, allowing an idle callback to
finish a condition without posting a message. Existing signed-quit propagation
still terminates suspended ancestors once, without reposting quit.

`win16-idle-runtime-test` checks bounded-pump separation, default blocking timer
wait, cooperative slices interrupted by queued work, signed/sticky quit, callback
exceptions/recovery, condition completion without a wakeup, provider mutation
guards, modal inheritance, busy-parent suppression and an explicit child override.
`win16-application-idle-runtime-test` checks registration without handles, correct
Sender/run flags, recursion/rebind rejection, root error recovery, startup-modal
idle completion, a modal opened from idle, inherited modal quit and exception
cleanup/retry. Both retain 4-KiB stacks, 2-KiB heaps and stack canaries. They do
not supply automatic hints/actions, exception dialogs or complete AppHolder/Forms
integration.

### Explicit application exception handling

TNativeApplication supplies OnException(Sender, E), HandleException(Sender) and
ShowException(E). HandleException must be called inside an active except block:
it reads ExceptObject, not a cast of Sender. Sender is forwarded unchanged, so
both original call patterns (Self or the exception object) work. EAbort is silent.
Other non-Exception objects and calls without an active exception are rejected.
The exception is borrowed: its subclass, full Message and HelpContext remain
unchanged, and the RTL releases it after the except block. Never free or retain
that object in the handler. The handler receiver must outlive registration;
clear OnException before freeing it and never destroy the application in callbacks.

Registration requires an initialized, task-local application but creates no HWND.
With no event, HandleException shows a native warning MessageBox owned by the
hidden application transport. The caption is Application.Title or Calmira when
empty. Presentation snapshots at most 1024 ANSI bytes, replaces embedded NULs
with spaces and marks truncation with an ellipsis; an empty Message uses the
exception class name. Managed text avoids a large DGROUP or stack buffer.
ShowException accepts a caller-owned exception outside an except block, bypasses
OnException, and never frees it; nil is rejected.

Recursive handling/presentation, event rebinding and application Run/ProcessMessages
during handling are rejected. The guard clears in finally even when a handler
fails. Direct Pascal handler failures propagate to the caller. Explicit routing
inside a native window callback remains inside that window's existing USER
exception boundary, which records handler failures without recursively routing
them. Unrouted callback errors still use existing per-window diagnostics; idle
errors still propagate to the Pascal pump caller. No automatic global exception
hook, full Forms.Application or original Computer/AppHolder integration is claimed.

`win16-application-exception-runtime-test` checks borrowed identity/lifetime,
Sender, HelpContext, EAbort, recursion/rebind/pump guards, direct and native
handler failures/recovery, unchanged unrouted diagnostics, bounded ANSI text and
real default/explicit dialogs with native owner/caption checks. Its timer closes
each actual button by its native ID and contains all timer-callback errors.
The probe retains a 4-KiB stack, 2-KiB heap and stack canary. Portable formatter
tests additionally cover exact-capacity boundaries, fallback and source retention.

### Application WinHelp service

TNativeApplication now exposes HelpFile, OnHelp(Command, Data, var CallHelp),
HelpCommand, HelpContext and HelpJump. Set an explicit installed HelpFile path;
AppHolder's existing RuntimeDirectory policy remains responsible for locating
the original installation beside a packed executable. The service does not
guess a help path from the temporary module name or silently change the current
directory. HelpFile and event registration require an initialized task-local
application but do not create an HWND. Embedded NULs in the path are rejected.

OnHelp runs first with CallHelp=True. Setting it False suppresses native dispatch
and preserves the handler's Boolean result, even False. Otherwise the return
value is the real LaunchHelp/WinHelp result, not the event's result. This also
supports the existing AppHolder bridge, which dispatches itself and sets
CallHelp=False to prevent duplicate launches. Event receivers must outlive
registration; clear OnHelp before freeing them. Raw HelpCommand data is an
unchanged 32-bit value; any pointed-to ANSI data must remain valid for the entire
synchronous call and must not be retained by a handler afterward.

HelpContext sends HELP_CONTEXT without narrowing the value. HelpJump uses
HELP_COMMAND with a live managed ANSI JumpID macro, rather than confusing a
textual topic identifier with a numeric map ID. The
[Windows 3.1 SDK JumpID reference](https://www.bitsavers.org/pdf/microsoft/windows_3.1/Microsoft_Windows_3.1_SDK_1992/PC30211-0492_Programmers_Reference_Volume_4_199204.pdf)
documents the filename/context-string arguments. The portable builder doubles
DOS backslashes, rejects control characters/quotes in filenames and accepts only
ASCII letters, digits, underscores and periods in nonempty context IDs (maximum
255 bytes). Invalid macro input raises EConvertError before event dispatch;
the generated request is never truncated to a Pascal short string. This is a
bounded context-jump helper, not a general-purpose macro escaping API.

Recursive help requests, HelpFile/OnHelp mutation and application pumping during
a request are rejected. Direct handler failures propagate after the help guard
clears in finally; existing native USER exception boundaries remain unchanged.
The shared help_service supplies localized missing/open-file errors. HELP_QUIT
does not require a file or show an error. Successful native launches are tracked:
application destruction sends a silent native HELP_QUIT before releasing its
existing transport, without invoking OnHelp or creating a new HWND. Intercepted
requests belong to the custom handler. Send HELP_QUIT before externally destroying
the transport HWND; automatic recovery of a help session after external HWND
destruction is not qualified.

`win16-application-help-runtime-test` checks interception/results, signed context,
macro pointer lifetime, invalid input, recursion/rebind/pump guards and recovery.
It opens the rebuilt help from C:\HELPDOCS after changing the current directory,
checks actual foreign-task WinHelp visibility, context/macro requests without a
WinHelp error dialog, explicit quit, reopening and application teardown. Actual
English/German/French missing-file dialogs verify owner, caption and reentry
guards. A contained timer closes their real native button IDs. The probe retains
a 4-KiB stack, 2-KiB heap and stack canary; its waits use WinProcs.GetTickCount,
not the generic SysUtils clock. Portable tests cover macro bounds and injection
rejection. F1 routing is layered separately below; complete AppHolder/Forms
loading, automatic hints and application minimization remain unimplemented.

### Focused F1 context-help routing

Windowed TCustomControl descendants now expose nonnegative LongInt HelpContext
metadata. Zero inherits the nearest nonzero value in the current managed Parent
chain; ResolveHelpContext performs a fresh, handle-free lookup. Reparenting and
later context changes therefore take effect immediately. An all-zero chain
requests HELP_CONTENTS. Context IDs are not narrowed to 16 bits. Negative metadata
is rejected without changing the previous value; the low-level application
HelpContext API remains an unchanged 32-bit request channel.

The strict binary DFM compiler emits HelpContext for forms and supported windowed
children before assigning events. It accepts integers from 0 through 2147483647
and rejects other types/ranges. Graphic-only labels/images still reject this
property explicitly; they cannot receive keyboard focus and no mouse-context-help
service is supplied. Original resources are not rewritten.

TNativeForm.ProcessDialogMessage handles plain first-press WM_KEYDOWN/VK_F1 only
for its actual focused, usable native target. Hidden/disabled/minimized forms,
stale target HWNDs, Shift/Ctrl/Alt combinations, system-key messages, keyup and
autorepeat do not request help. WM_GETDLGCODE/DLGC_WANTALLKEYS takes priority, so
a control owning all keys retains normal F1 delivery. The root application's
OnMessage filter still runs before form routing. Modal loops retain their own
form filter; they do not acquire an implicit copy of the root OnMessage handler.

A registered form forwards the resolved context through its lifecycle host to
the existing application HelpContext/HelpCommand service and OnHelp. The F1 key
is consumed after one help attempt even if OnHelp suppresses it with False or
the backend returns failure; it is not dispatched again as OnKeyDown. An
unregistered form or a host without a help service leaves F1 to normal dispatch.
No native-owner-chain inference or task-global keyboard hook is installed.
Registered modal forms use the same host while their owner is disabled.

Queue-filter help failures propagate to the Pascal pump caller, releasing help
and pump guards. Modal failures restore owner enable/focus and loop state.
Routing never resumes traversal after a help callback, allowing that callback
to detach or free the current secondary form safely outside USER dispatch.
The application itself and handler receivers must still outlive active calls.

`win16-help-key-runtime-test` compiles a test-only binary DFM with form, child
and nested-container contexts, checks lazy construction and live context lookup,
native focus/modifiers/key ownership, filter priority, exactly-once consumption,
registry mutation and root/modal error recovery. A queued F1 also opens the rebuilt
installed help in a real foreign WinHelp task and explicitly quits it. The probe
retains its 4-KiB stack, 2-KiB heap and stack canary. This is focused registered-form
F1 help, not complete Forms/DFM, Shift+F1, mouse-context help or automatic hints.

### Control coordinate conversion and graphic geometry

TCustomControl and TGraphicControl expose typed ClientToScreen/ScreenToClient
methods. The native client origin comes from USER on every call, including real
frame/caption offsets, external moves, native reparenting and HWND recreation;
cached Left/Top values are not used for windowed origins. A graphic control adds
its visual-parent-relative position without allocating its own HWND or DC.
Queries neither show/enable controls nor change focus/capture and remain valid
inside graphic paint. Both directions use LongInt intermediate arithmetic and
reject signed 16-bit coordinate overflow instead of wrapping.

These are explicit existing-window operations: an orphan graphic control, a
handleless visual parent, or a windowed control without a live HWND raises
ENativeWindowError without creating a window. Intermediate client origins must
also fit signed Win16 coordinates. This is not deferred coordinate mapping for
an uncreated hierarchy or a full VCL handle-creation policy.

Windowless controls also provide writable BoundsRect and read-only ClientRect,
ClientWidth and ClientHeight. Client rectangles start at (0,0); BoundsRect is
relative to Parent. Rectangle setters validate dimensions before narrowing and
dispatch through virtual SetBounds, retaining descendant behavior, invalidation
and the existing paint-mutation guard. Inverted/oversized rectangles preserve
the previous geometry; zero sizes and negative positions are supported.

`make win16-coordinates-runtime-test` checks these contracts against real USER
coordinates with native round trips, nonclient frames, external movement,
reparenting, hidden/disabled controls, graphic paint, HWND destruction/recreation,
overflow rejection and unchanged input/DC/child-window state. It retains the
4-KiB stack, 2-KiB heap and stack-bottom canary.

### Control visibility and native view order

Windowed TCustomControl now exposes Show, Hide, BringToFront and SendToBack.
A single virtual ChangeView policy hook preserves form-specific behavior even
through a TCustomControl reference without adding four VMT slots to every
descendant. Generic Show/Hide use existing visibility state; a handleless generic
control stays deferred until normal hierarchy creation. A form still creates its
native frame through its existing Show path and delivers OnShow/OnHide with the
usual state/lifecycle guards. Generic Hide of a registered modal form therefore
also completes its modal lifecycle instead of silently bypassing DoHide.

Hiding a live windowed container releases native focus/capture held by itself or
any descendant before hiding its HWND. Child objects retain their own Visible
state; effective native visibility also depends on ancestors. Native exit-handler
failures stay inside the existing USER callback boundary, while the hide completes
and the view guard clears. View methods reject calls during their own lifecycle,
painting/drawing scope or a managed parent's changing/painting/composition scope.
These are method contracts; direct low-level Visible-property assignments are
not upgraded into a complete VCL visibility-notification system.

Child-window ordering uses SetWindowPos with HWND_TOP/HWND_BOTTOM and
SWP_NOMOVE/SWP_NOSIZE/SWP_NOACTIVATE. It changes neither bounds nor logical
TabOrder and does not explicitly change activation/focus. No HWND is allocated
just to reorder. Windowed order belongs to USER, not a cached model list: it is
not retained as a deferred request or guaranteed across native HWND recreation.
Hidden child HWNDs are not shown by an order operation.

For an existing visible form, BringToFront also requests native activation when
enabled, so the original desktop's bottom-of-pack NextForm policy can use the
actual method rather than test-only RaiseWindow helpers. An already active form
keeps its focused descendant; new activation/default focus processing remains
USER-owned, not a retained ActiveControl cache. Disabled forms do not steal
activation. Hidden/handleless forms remain hidden/handleless. Raising an iconic
form does not implicitly restore WindowState. SendToBack never explicitly
activates another window. Form lifecycle/activation/resize guards also cover
these operations, and callback errors preserve completed native transitions.

Windowless TGraphicControl siblings expose BringToFront/SendToBack by moving the
parent's graphic composition list and invalidating the affected rectangle.
Later list entries paint above earlier entries. This model order survives parent
HWND recreation and neither allocates an HWND nor changes focus. Reordering
during graphic paint, parent composition/drawing or parent lifecycle changes is
rejected. This orders graphics among graphics; it cannot raise a windowless
object above an actual native child HWND and is not full mixed VCL z-ordering.

`win16-control-view-runtime-test` covers deferred state, base-reference form
events, real child order/focus/tab/bounds, descendant input cleanup, drawing and
activation reentry, callback failure recovery, iconic/disabled/hidden forms and
generic modal Hide cleanup. `win16-view-order-runtime-test` exercises the actual
NextForm selection/BringToFront sequence through the live screen view, graphic
overlap pixels, visibility, paint guards and parent recreation. Repeated real
reordering/composition checks GDI/USER pools, released DCs, no child HWNDs and
unchanged focus. Both retain 4-KiB stacks, 2-KiB heaps and stack canaries.

### Native application activation

TNativeApplication exposes Active, OnActivate and OnDeactivate separately from
per-form activation. Active reads the actual GetActiveWindow/GetWindowTask state
in the initialized application's task. It neither aliases MainForm.Active nor
caches WM_ACTIVATEAPP flags, and reading it does not create a transport HWND.
An active peer/unregistered window in the same task still means this application
task is active. This is not a promise that the main form has focus.

Assigning a non-nil activation handler ensures the separate hidden TApplication
window exists before publishing the handler. Clearing a handler does not create
one. Registration requires initialization, the owning task and no current
application-window dispatch; it does not replay an earlier activation event.
Receivers are borrowed and must outlive registration. Clear handlers before
freeing their receivers; never destroy the application/transport during callbacks.

The transport delivers native WM_ACTIVATEAPP after its normal hook/default path.
A consuming HookMainWindow hook suppresses the notification. Per-form switches
within one task do not synthesize application activation. Each unconsumed native
notification invokes the matching method with the application as Sender; a
synthetic notification cannot change the independently queried Active state.
Native transition timing is preserved, not normalized into an atomic focus
snapshot inside the callback.

Events remain inside the transport dispatch guard and USER exception boundary.
Rebinding activation handlers, mutating title/hooks or entering Run/ProcessMessages
from that callback is rejected; exceptions record WindowCallbackErrors and
LastWindowCallbackError, with guards released for recovery. Shutdown suppresses
application notifications and clears the transport callback before its HWND is
destroyed. Recreating an externally destroyed transport retains object-level
handlers/hooks but does not replay events missed while no HWND existed.

`win16-application-activation-runtime-test` creates two native forms and a second,
visible Win16 executable. Same-task form switches must leave application counters
unchanged; the independent task must deactivate the application and returning
to its main HWND must reactivate it. A signed synchronous handshake verifies
distinct tasks and the receiving task context; a watchdog prevents a missing
helper handshake from hanging acceptance. Separate injected-message checks cover
hook consumption, live-state independence, sender identity, reentry rejection,
both event exceptions/recovery, handler rebinding, HWND recreation and cleanup.
Both EXEs retain 4-KiB stacks and 2-KiB heaps; the principal probe checks its stack
canary and USER/GDI retention. This qualifies the event service used by the
original AppActivate/AppDeactivate error-mode handlers, not the complete original
TComputer/AppHolder integration, application minimization or global Forms/DFM.

### Explicit screen/form view

`native_screen.pas` now supplies a separate TNativeScreen component. Bind its
Application property to an initialized TNativeApplication in the same task; the
binding is weak and does not own either the application or its forms. A failed
rebind preserves the existing application. Unbound/destroyed/shutting-down
applications produce zero FormCount and nil ActiveForm/ActiveControl. The
application exposes readonly TaskHandle/ShuttingDown for these lifetime checks.
All view operations remain task-local; this is not global Forms.Screen or a DLL
hosting interface.
TComponent ownership is separate: use a nil component owner when the view must
outlive the application, and free the view explicitly afterward.

Forms[Index] collects current USER front-to-back top-level order, restricted to
the bound application's registered forms. Every remaining registered model,
including uncreated/destroyed HWNDs, follows once in registration order. Reading
the view does not create or activate windows. Negative/upper indexes raise;
temporary ordering lists are always freed. Each query is live: returned references
are borrowed and must not be retained through destruction, and several indexed
reads are not an atomic snapshot across intervening activation/registration changes.
The application registration order itself remains unchanged.

ActiveForm matches GetActiveWindow only when it is a registered, visible, enabled
window in the current task. An unregistered popup/modal is not misidentified as
its owner. ActiveControl resolves GetFocus through that form's managed control
tree, excludes the form itself and unusable children, and returns nil otherwise.
No cached active object can survive a native hide, free, reparent or unregister.
These are read queries, not OnActiveFormChange/OnActiveControlChange events.

Width/Height use USER screen metrics. PixelsPerInch reads vertical LOGPIXELSY
through a short-lived screen DC, released in finally; acquisition/invalid-resolution
failures raise rather than substituting a guessed value. The view does not retain
a drawing DC or provide Screen.Canvas, automatic registration of every TForm or
a full Forms compatibility API. Cursor control is a separate opt-in policy below;
constructing/querying an ordinary screen view does not install it.

`win16-screen-runtime-test` covers lazy models, live native order, the original
desktop's bottom-of-pack selection across three eligible forms, nested/reparented/
disabled/freed focus, unregistered windows, recreation, rebind and application
teardown. Real metrics and repeated queries check DC/USER/GDI retention.
`win16-screen-modal-runtime-test` verifies registered and unregistered modal
activation with actual EDIT focus, owner restoration, startup-error recovery and
signed modal quit under the root application pump. Both retain 4-KiB stacks,
2-KiB heaps and stack-bottom canaries. These tests qualify the explicit view,
not the original complete TDesktop or automatic Screen events.

### Scoped cursor policy

TNativeScreen now exposes Cursor, Cursors[Index], PushCursor, PopCursor,
CursorDepth and DisableCursors. The first cursor mutation installs one controller
per task/module; other screen views may still read form state, but cannot steal
that controller. DisableCursors releases it, restores the current eligible native
cursor where possible, clears saved states and resets Cursor to crDefault.
Detach, application destruction and view destruction also release it. The
application/view must outlive cursor operations; never free or rebind them from
cursor/hit-test callbacks. No global Forms.Screen or system-wide hook is added.

The small `native_cursors.pas` dispatch layer has no component/class registry.
It runs WM_SETCURSOR resolution inside the existing native USER exception
boundary. The heavier `native_cursor_policy.pas` is pulled in by the screen view,
not by every control. Screen overrides apply only to visible registered forms
and their native child windows. Unregistered/owner-only popups are outside that
scope. Cursor priority is screen override, explicit child/ancestor control cursor,
then USER class behavior. Thus crDefault restores an EDIT's native I-beam, while
the generic private window class supplies an arrow. Nonclient hit tests remain
under USER control; automatic refresh verifies HTCLIENT rather than inventing it.

TCursor/compatibility names are exposed through Controls. Stock arrow, cross,
I-beam, hourglass, up-arrow and sizing cursors load from Win16 USER. crNone selects
a null image with SetCursor, never ShowCursor, so nesting does not change the
system display counter. Other IDs (including Calmira's negative resource IDs)
require explicit Cursors registration; missing drag/split/custom resources are
not silently replaced with guessed images. Registered handles are borrowed:
neither unregister nor policy destruction calls DestroyCursor. Callers must keep
them valid while in use. A zero registry assignment removes an entry; crDefault/
crNone cannot be replaced, and IDs used by the current/saved screen state cannot
be replaced/removed. A removed control-specific ID falls back to USER processing.

Push saves the current logical index and Pop restores it. Invalid values and
empty Pop raise without changing logical cursor/stack state. Direct Cursor
assignment changes the current state, not saved outer states. Mutation guards
cover validation, allocation and native refresh; callbacks cannot recursively
push/pop/change registrations. Rebinding clears nesting; cursor resources remain
borrowed registry entries until removed or the view is freed. Unregistering an
inactive entry is allowed even after detaching the application.

Immediate refresh selects the task's capture window or the window under the
pointer, and does not send to another task. A scalar four-byte WindowFromPoint
import avoids the stock POINT-by-value ABI issue already reproduced for PtInRect.
Actual cursor messages remain authoritative; no message pump, focus change,
ShowCursor balancing or forced cursor update over another application is used.

`win16-cursor-runtime-test` checks native cursor handles, actual EDIT hit testing,
parent/child precedence, nested busy/none, invalid IDs, underflow, custom negative
IDs, caller-owned resource destruction, competing views, capture, callback
reentry, detach/teardown, display-count stability and repeated resource cycles.
`win16-cursor-modal-runtime-test` covers registered/unregistered modal scope,
popup-owner separation, native nonclient behavior, startup-error recovery and
signed quit with an outstanding cursor scope. Both keep 4-KiB stacks, 2-KiB
heaps and canaries. Tests inspect handles through Win16 SetCursor's returned
previous handle; they do not assume a Win32 GetCursor API or physical-mouse tests.
The original desktop/resource loader and its remaining Forms services are still
unported; this is their cursor foundation, not a complete shell release.

## Explicit modeless dialog navigation

Assign `Loop.OnMessage := Form.ProcessDialogMessage` before pumping, and clear
it before freeing the form. This opt-in connection consumes handled WM_KEYDOWN
before TranslateMessage, so Tab/Enter/Escape do not generate stray WM_CHAR.
Only this form and its managed, live HWND descendants qualify; unrelated windows,
Ctrl/Alt combinations and system keys continue through the native loop.
WM_GETDLGCODE receives the actual far MSG pointer. DLGC_WANTTAB and
DLGC_WANTALLKEYS let a control retain the relevant keys.

Windowed controls expose TabStop (False by default; True on buttons) and sibling
TabOrder. Assign TabOrder after Parent: it moves the control within the managed
sibling list, clamps past-end values and rejects negative values or drawing/
creation reentry. It does not change native Z order. Detaching/reparenting appends
to the new parent's order. Traversal is depth-first, skips hidden/disabled native
ancestor trees, wraps in either direction and respects the position of focused
non-tab controls. Empty tab sets are harmless. `Form.FocusNext(True)` explicitly
selects an initial control; Show does not implicitly activate or move focus.

Enter activates the focused managed button first, otherwise the first eligible
Default=True button in tree order; Escape selects the first eligible Cancel=True
button. Multiple designated buttons are deterministic, not a uniqueness error.
Native push buttons update BS_DEFPUSHBUTTON live; bitmap buttons preserve their
BS_OWNERDRAW type (no additional default-border rendering). Hidden/disabled
buttons and ancestors cannot activate. These properties survive HWND recreation.
Callbacks must not synchronously free their receiver/owner or the active loop.
Modal results are provided by the separate modal form layer. There is no
mnemonic/accelerator manager, arrow-group traversal, automatic modeless hook
registration or complete Forms.Application implementation.

## Owner-scoped modal forms

`native_modal.TNativeModalForm(TNativeForm)` implements real blocking ShowModal
without introducing a placeholder Forms unit. It creates native popup frames,
links the requested top-level HWND owner, disables that owner before OnShow and
restores its prior native owner, enable state, activation and eligible focus in
nested finally blocks. An already disabled owner is not re-enabled. Only the
selected owner is disabled, not every task window or another application's UI.
OwnerWindow=0 infers the active window of this USER task (excluding self); with
no eligible active window it runs unowned. Explicit foreign-task/child/invalid
owners are rejected before modal state changes. TComponent.Owner is independent.
The caller and owner must outlive the call and must not be freed/replaced inside
callbacks. ShowModal rejects an already visible or modal instance and drawing
reentry. Nested modal forms are supported from queued handlers, not during
OnShow/OnHide preparation/cleanup or activation/focus restoration. Modal state
stays guarded until those callbacks have returned. This is not system-wide modality.

Controls defines TModalResult and mrNone/mrOK/mrCancel/mrAbort/mrRetry/mrIgnore/
mrYes/mrNo/mrAll. Nonnegative custom results are allowed. Set a native push or
bitmap button's ModalResult to bubble that value through its managed parents to
the modal form, without coupling the button unit to modal implementation code.
The result is applied before OnClick, so validation may reset Form.ModalResult
to mrNone. Default/Cancel determines keyboard routing, not a result by itself.
Closing a positive result uses the existing guarded Close path: CloseQuery and
OnClose can veto; vetoed results reset to mrNone and keep pumping. Successful
Hide/Close/native destruction returns cancel when no other result was set.
Direct Close is queried once, not again by modal teardown. Normal result closure
honors ncaHide/ncaDestroy. HWND/model objects are not implicitly freed.

Each ShowModal owns a fresh message loop and installs/clears its own dialog
filter, leaving an outer loop's filter untouched. RunModal(ContinueWhile) is the
only explicit nested-pump entry point; it saves/restores task ownership and
rejects nil predicates and reuse of any active ancestor instance. Predicates
run before blocking GetMessage; false never dequeues the next item. Ordinary
Run/ProcessMessages remain non-reentrant, including inside modal callbacks.
The queue stays task-wide so timers and other windows continue to dispatch.
Do not free an active loop or callback receiver.

WM_QUIT bypasses filters and is consumed once. Its signed exit code and terminated
state propagate to every suspended ancestor pump; WM_NULL task wakeups unblock
waiting USER calls without reposting quit. A predicate that triggers nested quit
cannot proceed into GetMessage afterward. Quit cancels modal forms and unwinds
owner/focus state regardless of close-query veto. TaskQuit/TaskExitCode expose
termination to a caller with no outer registered loop; honor them before starting
a new application loop. These fields reset on the next valid ShowModal entry.
Callback exceptions keep native containment; predicate/lifecycle exceptions
propagate after releasing modal ownership and restoring the owner. This is not
VCL-compatible arbitrary Application.ProcessMessages recursion or a complete
application/main-form lifecycle.

```sh
make win16-modal win16-modal-loop win16-incsrch-modal
WIN311_IMAGE=/path/to/baseline.img make -j3 \
  win16-modal-runtime-test win16-modal-loop-runtime-test win16-incsrch-modal-runtime-test
```

Native tests cover scoped owner/focus and nested restoration, result ordering,
event/query veto, close/hide/destroy, initially disabled owners, preparation and
reentry guards, lifecycle/condition errors, queued Enter/Escape, three-level quit
unwinding, standalone quit reporting, successor queues and resource cycles.
The original search has separate modal and retained modeless acceptance. Physical
keyboard input, general DFM streaming, complete owned/modeless form policies and
Forms.Application remain outside this layer.

```sh
make win16-dialog
WIN311_IMAGE=/path/to/baseline.img make win16-dialog-runtime-test
```

The native probe covers nested order/wrap, live reorder and TabStop styles,
modifier/dialog-code opt-outs, focused/default/cancel precedence, native character
translation, filter budgets/nesting/exceptions, quit bypass and HWND recreation.
Keyboard messages are synthetic through real USER queues, not physical-key tests.

## Original progress gauges

The original `vcl/bargauge.pas` now builds both `TBarGauge` and `TWin95Gauge`
against the windowless Controls subset. The latter is the component referenced
by `src/progress.pas`; this does not yet build that complete dialog. Original
solid/segmented rendering, orientation, text, border settings and segment-aligned
bounds remain in the maintained unit, with conditional FPC adaptations rather
than a replacement gauge. Graphic SetBounds is virtual so original dimension
overrides also work through base references and Width/Height setters.

The FPC path invalidates its parent asynchronously and renders into the existing
full-child buffer. It fills gaps/background explicitly, so decreasing progress
does not retain old segments or depend on the parent's color. A vertical gauge
uses Height for its segment count and paints no segment at zero. Segmented
rounding uses nearest with half-up ties. Tiny sizes remain bounded; exhausted
solid-bar interiors are skipped. Solid rendering restores a solid brush before
each paint, including after percentage text used a transparent brush.

Percentage arithmetic widens operands before subtraction over the signed 32-bit
range. AddProgress uses a wide intermediate and saturates at MinValue/MaxValue;
direct out-of-range Progress assignments retain the original ignore behavior.
Range setters reject inverted bounds before mutation and clamp existing values;
equal bounds produce zero percent. These changes are FPC-only; the historical
Delphi path retains its previous behavior and is source-guarded, not newly compiled.

Unsupported Align, hints, Font and ParentFont properties are not published
in the FPC branch. Percentage text uses the real owned `Canvas.Font`; changing
that font directly requires explicit Invalidate. There is no inherited-font,
layout or DFM support. Border drawing is a small local implementation, not a
placeholder ExtCtrls unit. Enabled is inherited as local graphic-control state;
the gauge does not automatically gray its custom painting. Historical
public-domain attribution remains intact.

```sh
make win16-gauge
WIN311_IMAGE=/path/to/baseline.img make win16-gauge-runtime-test
```

The native probe inspects horizontal/vertical foreground, gaps, margins, erased
old segments, solid fill, percentage glyphs and borders. It exercises signed
range/overflow cases, virtual sizing, tiny/invalid bounds, canvas detachment and
101 redraws with coarse GDI/USER-resource checks.

## Windowless standard label and font notifications

`src/win16/stdctrls.pas` provides a real `TLabel(TGraphicControl)` subset, not
dummy declarations for all StdCtrls classes. It paints native ANSI text through
DrawText into the existing full-child buffer; it allocates no HWND. Explicit
bounds clip the text. Alignment supports left/right/center, WordWrap enables
native word breaking, CRLF remains multiline without wrapping, and ShowAccelChar
switches between mnemonic-prefix rendering and literal ampersands. Typed
FocusControl and scoped Alt activation are described below. Empty captions erase old
text through parent invalidation; embedded NULs are rejected before mutation.
The label is opaque and uses its own Color, not transparent parent painting.

Font refers to the owned canvas font. Assignment copies state, never ownership,
and rejects nil. Direct changes such as `Label.Font.Color := clRed` invalidate
the label automatically. Do not replace the label font's internal OnChange
handler. Native font selection, text color and background mode are restored in
finally, and the graphic canvas is detached by the existing parent compositor.

The shared TFont now has OnChange notifications for changed Name, Height, Size,
Style and Color, plus a single notification after changed Assign. Equal setters,
self/identical Assign and failed validation are quiet. Assign does not copy the
source's handler. Events observe completed state; exceptions propagate without
undoing the change, after releasing the notification guard. Reentrant changes
are retained but do not recursively notify. Do not free the font or its owner
inside its event. Fonts outside a label do not automatically invalidate an
arbitrary owning control; that owner must subscribe explicitly.

```sh
make win16-label
WIN311_IMAGE=/path/to/baseline.img make win16-label-runtime-test
```

Native checks inspect glyph positions/colors, actual wrapping and CRLF, prefix
handling, old-text cleanup, deep font ownership, event recovery and 101 repeated
font/render changes with coarse GDI/USER-resource guards. This is manually
constructed fixed-bounds text, not completed Progress or Forms. AutoSize,
ParentFont/ParentColor, transparent labels,
label mouse/click routing and DFM streaming remain missing. Native edit/checkbox
controls are separate implementations described below, not painted label variants.

### Windowless enabled state

`TGraphicControl.Enabled` defaults to True, independently of Visible and Parent.
Changing it invalidates visible graphics without allocating an HWND, changing
focus, or hiding the control. State survives reparenting, native parent-window
recreation and detachment. Same-value assignments do nothing. Actual changes
during parent drawing/composition or native hierarchy transitions are rejected
before mutation, including changes to a sibling whose canvas is not active.

Mnemonic traversal ignores disabled graphic controls and continues to an eligible
duplicate. Existing native ancestor/target eligibility checks still apply;
disabling a container does not overwrite a label's local Enabled flag.
Labels render disabled text using current `COLOR_GRAYTEXT` without modifying
their owned Font. Reenabling restores the latest stored font color. This is local
disabled appearance, not automatic ancestor-disabled graying for every custom
graphic component. Images and custom graphics keep their own paint policies.

The typed DFM compiler accepts Boolean Enabled assignments for labels and images;
windowed TabOrder/TabStop and graphic HelpContext remain unsupported. Label
properties are public, not published: typed assignment does not need their NE
property RTTI. This offsets the shared control hierarchy's VMT cost without
reducing text capacities or stack/heap reservations. There is no new runtime
DFM streaming contract. Mixed enumeration is described below.

### Shared control identity and mixed children

`control_base.TControl`, exported as `Controls.TControl`, is a real abstract
`TComponent` descendant shared by native windows and windowless graphics.
It exposes Enabled, Visible, Show, Hide, BringToFront and SendToBack through
one virtual operation hook. Managed controls retain their existing policies:
form Show/Hide still run lifecycle/modal cleanup, graphic ordering still changes
composition, and native properties still query USER. This is neither a proxy nor
a TComponent alias. Graphic controls still contain no HWND. Raw TNativeWindow
implements live-HWND operations; handleless raw operations reject rather than
inventing a deferred control model.

`TCustomControl.ControlCount` and zero-based `Controls[Index]: TControl` enumerate
direct logical visual children, including hidden, disabled and handleless ones.
Real object identity supports `is`/casts and inherited Free. Ownership components,
grandchildren and foreign/raw child HWNDs are excluded. Indexes below zero or at
or beyond Count raise ENativeWindowError. Use managed Parent setters, not external
USER reparenting, to change logical membership.

The mixed list records successful attachment order, independently of the native
tab-order list and graphic paint-order list. Same-parent writes, TabOrder,
BringToFront/SendToBack and HWND recreation do not reorder it; moving away and
back appends once. This is a defined local contract, not a claim of identical
Delphi mixed z-order indexing. Count/index queries are live scans, not snapshots.
For deleting every visual child, use the original safe pattern:

```pascal
while ControlCount > 0 do Controls[0].Free;
```

List allocation is staged before native callbacks. Getters expose entries only
when their actual model Parent matches the queried parent. A callback before
the model transition cannot see provisional target membership; a WM_CREATE
callback after it sees the new model. If creation fails, the old mixed position
is restored without allocation and target entries are removed. Parent destruction
detaches surviving independently owned children; TComponent ownership separately
decides which objects are freed. Direct drawing and composition reject graphic
reparenting before list mutation. Allocation rollback is source-guarded; native
failure injection currently exercises WM_CREATE, not allocator exhaustion.

`win16-children-runtime-test` checks real overlap pixels, typed operations on both
kinds and raw windows, callbacks during reparent/failure, index bounds, independent
owners, retry/recreation, free loops and resource cycles. It retains a 4-KiB stack,
2-KiB heap and 64-byte stack canary. Existing view tests additionally exercise
modal Hide through TControl. Common geometry, Parent assignment, Font, hints,
alignment and input events are not yet exposed on this shared base; concrete
native/graphic types retain their existing geometry APIs. Full Forms and the
original shell therefore remain unfinished.

The original hierarchy checkpoint was not release acceptance: its native run exposed
a layout-sensitive password resource-cycle failure. A private stopped build
observes string ID 1203 returning 255 bytes with NULs instead of its original
15-byte bound text. Clean normal compilation reproduces the failure; diagnostic
variants can hide it. The resource provider return temporary is now isolated,
reducing the bound-only LocalLoadStr frame from 514 to 258 bytes, but this does
not resolve the failure. The later private RTL heap-shrink correction below
restores the normal password probe; isolated mixed-child success alone was not
evidence of a stable port. NUL validation, capacities, stack/heap reservations and
original resource bytes are unchanged. See [current evidence](build_status.md)
for the failed original aggregate and subsequent regression checks.

### Win16 heap shrink bounds

The pinned `SysGlobalReAllocMem` small-block branch allocates the requested new
size but copies `SysGlobalMemSize(p)` bytes unconditionally. Shrinking therefore
overwrites memory beyond the destination. The private
`fpc-win16-realloc-bounds.patch`, enabled only with
`CALMIRA_WIN16_REALLOC_BOUNDS`, copies `min(old size, new size)` instead. Other
branches, allocation failure behavior and the vendor checkout remain unchanged.
RTL source fingerprints include the patch, forcing a new staged build.
This path is also used by managed ANSI strings: `fpc_AnsiStr_SetLength` can
shrink a uniquely owned allocation, including temporaries reused by implicit
short-string conversions for `StrPCopy`. Passing stack canaries therefore did
not exclude this independent heap overwrite.

`win16-realloc-runtime-test` first positions a 16-byte free hole immediately
before a live 128-byte guard, then shrinks a separate 128-byte allocation into
that exact hole. The old RTL overwrites the guard; the corrected RTL preserves
both guard and requested prefix. Further cases cover odd/one-byte destinations,
growth, transitions to direct global allocations, global shrinking/growth,
same-size resizing and nil/zero-size behavior. The probe keeps the 4-KiB stack,
2-KiB heap and 64-byte stack canary. The normal password, password-language and
numeric-resource probes pass with this correction, without diagnostic source
changes or the external assembler. Full-suite evidence is recorded in
[build status](build_status.md): all 65 corrected native suites pass in the
subsequent complete run. A complete Calmira shell remains blocked by Forms.

## Scoped Alt mnemonics and weak focus targets

`native_mnemonic.CaptionMatches` handles single ampersands, escaped `&&`, trailing
ampersands and Win16 ANSI case mapping; it is not Unicode/DBCS normalization.
`TNativeForm.ProcessDialogMessage` consumes WM_SYSCHAR only with the Alt-context
bit, a bounded nonzero ANSI character, no Control modifier and a managed,
focusable originating HWND. Unmatched messages continue through USER normally;
this does not intercept Alt-F4 or install a global accelerator/menu hook.

Labels expose a typed, non-published FocusControl reference. FreeNotification
clears destroyed targets, and activation rechecks their current managed form,
visibility and enabled ancestors. Hidden labels and disabled/foreign targets
are skipped. The first eligible match wins in deterministic graphic/child order;
duplicate mnemonics do not cycle. Buttons focus then invoke their existing Click;
checkboxes toggle once. A focus request is consumed once attempted; callback
vetoes do not activate another matching control. SetFocus failure still raises
the existing native focus error. Do not synchronously free an event receiver or
its owner inside callbacks.

`win16-mnemonic-runtime-test` verifies real focus/toggle behavior, escaped prefixes,
ANSI case, weak references, reparenting, nested/disabled containers, foreign
origins, focus vetoes, exception recovery and HWND recreation with the unchanged
4-KiB stack/2-KiB heap. DFM FocusControl references resolve after all children and
before events/OnCreate, including forward references; invalid targets fail closed.
Generated Notification overrides clear typed owned-child fields and retain the
inherited notification chain, without requiring designer field RTTI.

## Native edit and checkbox controls

`StdCtrls.TEdit` aliases the real `native_edit.TEdit(TCustomControl)`.
Its private EDIT superclass retains USER's original window bytes and native
procedure: Windows owns text editing, focus, selection, scrolling and painting.
The public short-string interface is ANSI and limited to 255 bytes, matching the
Delphi 1 filename/password uses. Embedded NULs and oversized native WM_SETTEXT
are rejected before mutation; foreign text scanning examines at most 256 bytes.
MaxLength accepts 1..255 and limits interactive input, not programmatic Text.
CharCase selects native normal/upper/lowercase input styles, including live
changes and recreation; changing the style does not itself rewrite existing
text. Zero/unlimited, multiline text, TMemo/Lines, AutoSelect and HideSelection are not
implemented. PasswordChar changes native masking only; it is not encryption or
secure erasure. ReadOnly blocks user edits but permits programmatic Text changes.

SelStart/SelLength use the packed Win16 EM_SETSEL ABI, clamp to the current text,
and SelText replacement rejects a 255-byte overflow. Clear, SelectAll,
ClearSelection, CopyToClipboard, CutToClipboard, PasteFromClipboard, CanUndo and
Undo use USER editing operations; clipboard/undo methods need a live HWND.
Modified maps to EM_GETMODIFY/EM_SETMODIFY. Text, selection and Modified are
snapshotted before WM_DESTROY and restored on recreation, alongside password,
limit, read-only and font settings. Undo history is native-only and not restored.
Live reparenting retains the existing native buffer and selection.

EN_CHANGE from a managed parent updates the stored text before OnChange. A local
fallback supports CreateControl(HWND) without a Pascal parent; notifications are
not duplicated. Equal text/no-op replacements are quiet. Nested event mutations
are retained without recursive notification. Direct detached-event errors
propagate; native notifications use the receiving window's exception boundary.
Creation/recreation does not synthesize text-change events. Fonts are deep-owned;
keep their reserved OnChange handler. Font color uses native system edit colors,
not owner-drawn VCL color rendering. Raw external style/limit mutations are not
a supported way to bypass the wrapper's text bounds or stored configuration.

`StdCtrls.TCheckBox` aliases `native_checkbox.TCheckBox`, a native BUTTON
superclass using manual BS_3STATE, not a push-button subclass or painted glyph.
Mouse/Space emits BN_CLICKED and toggles exactly once. With AllowGrayed=False,
Click alternates unchecked/checked; True cycles unchecked/grayed/checked/unchecked.
Explicit State may select cbGrayed even when AllowGrayed=False; Checked means
exactly cbChecked. Programmatic changed State/Checked fires OnClick once, including
while disabled. Native activation is filtered while hidden/disabled; direct
Click is enabled-only. Nested state changes are retained without recursive events.
Set Parent to receive native activation notifications; CreateControl(HWND) alone
does not establish managed command routing. State is queried from BM_GETCHECK and snapshotted on native destruction; creation,
reparenting and recreation do not synthesize OnClick. Enter is not a checkbox
toggle: a form may still route it to its designated push button. Radio groups,
mnemonic activation and complete StdCtrls remain unimplemented.

```sh
make win16-edit win16-checkbox win16-input-dialog
WIN311_IMAGE=/path/to/baseline.img make -j3 \
  win16-edit-runtime-test win16-checkbox-runtime-test win16-input-dialog-runtime-test
```

Separate probes check native text/selection/password/read-only/clipboard/undo,
limits, events, error recovery, fonts, reparent/recreation and USER/GDI resources.
The combined test manually constructs edit/checkbox/default/cancel controls,
validates text via OnChange and drives Tab/Space/Enter/Escape through the real
USER queue. It checks accepted values, invalid-input rejection, cancellation,
quiet HWND recreation and continued task operation. This is not the original
Calmira dialog, DFM loading, modal Forms or physical keyboard acceptance.

## Original incremental search dialog

`src/incsrch.pas` is a plain TForm on both compilers. The original
EditChange, FormShow and EditKeyDown methods still perform the search callback,
initial lowercase character/caret positioning and Enter/Escape close. No duplicate
search implementation or placeholder Forms unit is introduced.
The FPC path maps an unset InitialChar (#0) to empty text: the original icon
window's `.` command opens the dialog without assigning an initial character.

Its components come from the loader unit `incsrch_dfm`, generated from the
unchanged `incsrch.dfm` by `tools/dfm_loader.py` into `build/generated/forms/`
(see "Form Loaders" in `docs/build_status.md`); no handwritten layout remains.
It preserves the 171x41 client area, child bounds, names, fonts, lowercase
policy and the original event bindings.
`ActiveControl=Edit` maps to `TNativeForm.InitialControl`, a weak descendant
reference focused after OnShow. Freeing clears it; detached, hidden or disabled
controls are not focused. This is initial-focus policy, not full ActiveControl.
The original copyright/license and binary resource remain unchanged.

```sh
make win16-incsrch
WIN311_IMAGE=/path/to/baseline.img make win16-incsrch-runtime-test
```

The native probe instantiates the actual original class, checks empty/default, initial and
queued typed search callbacks, lowercase/caret/geometry, original Enter/Escape
handlers, reuse/recreation and 30 USER-resource cycles. Close hides the modeless
dialog without terminating the task. The probe installs the form message filter
explicitly and clears it before freeing the dialog. This does not establish a
finished full shell or a new Delphi compiler acceptance. The separate
win16-incsrch-modal probe runs the same original class through ShowModal. It
checks inferred owner disable/restore, actual queued search followed by Enter,
empty/default Escape and HWND recreation. The original Enter/Escape handlers
call Close and therefore return mrCancel; this dialog has no new OK result.

### Build-time resource and caption subset

`make win16-form-resources` generates the constructor; `make
win16-form-resources-report` inventories every `src/*.dfm`, recording supported
files and explicit blockers in `build/generated/forms/report.json`. The compiler
accepts raw TPF0 or one complete Win16 RCDATA wrapper, bounded CP1252 values,
and validated identifiers. Unsupported classes/properties, duplicate names,
invalid references, out-of-range coordinates, malformed/truncated resources and
non-96-DPI layouts fail the build instead of being silently dropped.

The declared subset covers labels, edits, buttons, checkboxes, images, bitmap/
picture buttons and explicitly sized TCustomControl containers. It creates values/fonts before binding events,
resolves initial focus and sibling tab order, and invokes typed OnCreate last.
Original search and drag/drop dialogs are native acceptance cases. This is not
a general runtime streamer: inherited forms, arbitrary graphic classes/custom
components, alignment, label autosizing and full VCL defaults remain unsupported.

Delphi bitmap streams (`Glyph.Data`, or `Picture.Data` tagged TBitmap) become
native RT_BITMAP resources, not large Pascal byte arrays in DGROUP. The current
format is bounded, bottom-up uncompressed Windows-3.x 4-bit BMP with a complete
16-entry palette; other formats fail explicitly. Lengths, headers, palette,
pixel bounds and frame divisibility are checked. CLI compilation with images
requires `--resources OUTPUT.res`; bind that sidecar after FPC linking with
OpenWatcom wrc, as the drag/drop targets do. Each output is atomic/idempotent;
this is not a multi-file filesystem transaction. Image AutoSize is applied only
after loading, without accidentally touching its bitmap-creating Canvas getter.
Bitmap button layout/margin/spacing/frame counts and native bsNew rendering are
supported. Only bkCustom/bkCancel are lowered; other Kind values are rejected.
Cancellation uses a new open two-frame cross from `tools/dfm_bitmaps.py`, not a
glyph extracted from the old Delphi compiled units or BUTTONS.RES.

Generated captions call `form_text.FormText`; without a provider they retain
the DFM text. A `form_catalog.TFormTextCatalog` provider reads existing LNG `[Forms]` keys
(`RootClass.Component.Caption`) through the Win16 profile API, falling back to
English and then the original caption. Use an absolute DOS catalogue directory;
SelectLanguage rejects paths and checks `[Language]Code`. Clear/restore the
provider before freeing its receiver. Switching language affects newly created
forms, not existing instances. Text is bounded ANSI; truncation and expanded
escape overflow are rejected. INI parsing follows the Windows profile API.
Geometry stays unchanged: translated long labels may need later layout work.
The provider-only form_text unit and the concrete form_catalog backend are
separate so an untranslated form does not load the catalogue adapter eagerly.
Language extras now merge into existing sections; standard cancellation text
(`TStandardButtons.Cancel.Caption`) cannot erase upstream Forms translations.

`make win16-form-text-runtime-test` uses the same EXE with German/French/English
catalogues in a private guest, checking original dialog captions/native title,
focus/recreation, fallback, explicit empty values, escapes and overflow errors.
Host compiler tests also cover atomic/idempotent output and all resource
truncations. None of this supplies the still-missing full Forms/application shell.

### Original drag/drop decision dialog

`src/askdrop.pas` is a plain TForm, loaded by the generated `askdrop_dfm`. On
FPC, FormCreate loads its own copy of USER's question icon instead of handing
the shared `LoadIcon` handle to TIcon, which would destroy it, and initializes
focus to the copy button. FormShow reads the original `MiscUtil.MsgDialogSounds`.
`Kind = bkCancel` gets a drawn stock glyph from the loader, as Delphi's
BUTTONS.RES glyphs are not redistributable. The original Copy=mrOK (1), Move=mrYes (6), Cancel=mrCancel (2) decisions
are preserved. The dialog selects an action; this probe does not copy/move files.

Separate 4-KiB-stack/2-KiB-heap probes avoid combining all diagnostic code at the
Win16 data limit: `win16-askdrop-runtime-test` checks original glyph pixels,
actual native glyph drawing/transparent color key, frame/focus, both PicBtnGlyphs
modes and 20 create/show/free cycles; `win16-askdrop-modal-runtime-test` checks
queued Enter/Tab/Escape, mouse move selection, close, owner disable/restore and
HWND recreation; `win16-askdrop-language-runtime-test` uses one EXE for German,
French and English, including translated standard cancellation and recreation.
TPicBtn.FinishLoading invokes its retained Loaded policy once, after values and
glyphs and before original OnCreate. Labels now live in native_label; StdCtrls
exports the same class as an alias, and PicBtn no longer imports unused edit/
checkbox implementations. The original password dialog is described below.

### Original password dialog and numeric strings

`src/password.pas` is a TForm loaded by the generated `password_dfm`; its FPC
branch keeps its own validation. The Delphi implementation remains separate. Explicit
mode state replaces translated-caption comparisons; initialization clears input
and modal results and becomes valid only after all captions have loaded. Visible
or running dialogs cannot be reinitialized. New usernames remain ASCII
alphanumeric, 1..8 bytes. Changing an existing password accepts the full legacy
127-byte value, including exact comparison against an empty old password.

`resource_text` supplies an optional, scoped numeric-string provider backed by
the original bound `locale.res`. `TFormTextCatalog.TranslateResource` reads the
same language files' `[Strings]` section with selected-language, English and
bound-resource fallback. It shares the existing bounded profile/escape reader;
no full LangUI/application initialization is fabricated. German password labels
and errors override the historical untranslated entries in `locales/extra.json`.

`legacy_password` preserves the original ROT13/hex representation for all
representable values. This is NOT secure encryption. The 255-byte short-string
storage interface can hold at most 127 input bytes as hex; longer input and
malformed encoding raise errors rather than silently truncating. Portable tests
cover every byte, all supported lengths, malformed hex and username bounds.
The dialog does not write user files or implement a secure account system.

Separate `win16-password-runtime-test` and `win16-password-language-runtime-test`
profiles retain 4-KiB stacks and 2-KiB local heaps (64,128 and 63,712 guarded
bytes). They test initialization, caption-independent validation, empty/long old
values, callback failure/recovery, 127-byte storage bounds, modal Enter/retry/
Escape/close, owner restoration, HWND recreation, a real owned Windows error
MessageBox and 20 resource cycles. The multilingual fixture loads German, French
and English in one EXE, rejects a failed/partial catalogue initialization and
restores both optional providers. Only synthetic credentials are used.

The multilingual test exposed genuine stack corruption despite a passing NE
static budget. Native callbacks formerly reserved a 256-byte exception-message
conversion on every invocation, and EDIT dispatch reserved another unused
short-string copy even for nested WM_GETTEXT. These copies now live in failure-
or-change-only helpers; bounded SetString copies avoid intermediate StrPas
results. Catalogue lookup reuses its result buffer, bounds numeric keys to five
digits and passes its internal constant section names directly to USER. Public
text limits, callback error containment and WM_SETTEXT failure handling are
unchanged. Native edit and password tests additionally check all 64 stack-bottom
canary bytes; the language fixture checks each phase without ignoring earlier
failures. No stack/heap reservation or public text capacity was reduced.

The private FPC previous-value field uses AnsiString to keep the dialog instance
below the Win16 RTL's 1,024-byte direct-allocation threshold. The original stock
compiler has a separate defect: a direct GlobalAlloc result at `segment:0000` is valid,
but its generated constructor checks only the offset and
skips its body. `tests/pascal/diagnostics/test_win16_large_constructor.pas`
reproduces it independently; it is deliberately not an accepted regression
target. The local compact-state workaround does not fix arbitrary large classes,
and the complete Forms/application framework remains unported.

### Corrected i8086 class-pointer comparisons

`make fpc-win16-fixed-compiler` builds a separate compiler at
`build/toolchains/fpc-class-pointer/ppcross8086`. Its scoped patch fixes the
i8086 ordinal-comparison dispatch for four-byte implicit object pointers and
class references. Their existing first pass already selects a multiword result;
the second pass previously fell through to a one-word address comparison.
Both segment and offset now participate in equality/inequality, including
constructor entry, AfterConstruction and TObject.Free. Explicit far-pointer
ordering and the two-byte near-data path are left unchanged. DOS near-data models
are not qualified by the Win16 runtime tests.

A second patch, `fpc-i8086-huge-resourcestrings.patch`, loads the segment of
a resource string's table entry in the huge model. FPC places each unit's
`RESSTR` tables in their own sections, so the linker may put them in a
different physical segment from the referencing unit's data. The unpatched
code addressed them through DS, which only worked when both happened to share
a segment. Otherwise `SysUtils.InitExceptions` read a garbage
`SOutOfMemory` and crashed before the program's first statement.

`prepare_fpc_compiler.py` stages only tracked compiler/bootstrap-RTL sources and
licenses outside the pinned checkout, applies the patches in order with zero
fuzz, and records revision, per-patch/builder hashes and bootstrap identity. Source, patch,
build-script and bootstrap-identity changes produce separate cache trees. The
installed stock compiler is not overwritten. The builder was tested on Gentoo
with host Free Pascal 3.2.2; it does not need a Windows build host.

`make win16-fixed-regression` rebuilds the private GUI RTL and all test units in
`build/class-pointer/<compiler-fingerprint>/`, then runs 65 suites: the earlier
38, a class-pointer fixture, six application-lifecycle/factory/window/activation fixtures
and two screen-view, two cursor, form-activation, form-resize, form-state and
two idle fixtures, an explicit application-exception fixture, an application-help
fixture, a focused F1-help fixture, two visibility/view-order fixtures and a
native/windowless coordinate fixture, low-level/application drain fixtures and
an actual-module/package-identity fixture, a mixed-control-children fixture and
a heap-reallocation bounds fixture. This
separation matters: reusing old PPUs would retain broken checks
inside inherited constructors and Free even with a corrected application
compiler. A changed compiler fingerprint also selects a new RTL/application
output tree automatically. Use the same corrected TCG environment and private baseline as the
other native tests. The stock-toolchain diagnostic remains outside acceptance;
it fails with the stock compiler and passes with the corrected compiler.

The new fixture compares runtime synthetic pointers without dereferencing them,
checks zero/nonzero segments and offsets, nil/Assigned/alias/class-reference
cases, and exercises real zero-offset direct allocations. Virtual/inherited
constructors, payload sentinels, AfterConstruction/BeforeDestruction, failed
construction, repeated lifetime balance and large TComponent owner/child cleanup
are tested with a 4-KiB stack, 2-KiB heap and stack-bottom canaries. This is an
opt-in corrected toolchain, not a completed Forms/application framework or an
in-place replacement of existing build caches.

### Original selection dialog

`make win16-select` compiles the original `src/select.pas`, a TForm loaded by
the generated `select_dfm`. Its modeless callbacks retain
the original sender/select-vs-deselect and semicolon-token behavior; they are not
filesystem operations. GetWord comes from the original `vcl/strings.pas`.
The FPC branch loads the bundled MULTIFILEICON; the unported configurable shell
icon cache is not emulated. Delphi's existing path remains intact.

`merge_res16.py` combines the original icon library and generated glyph resources,
preserving bytes and rejecting conflicting case-insensitive resource identities.
The legacy Deselect glyph contains 26 declared trailing zero bytes: the DFM
compiler normalizes only bounded (at most 64 bytes), declared all-zero padding
after complete 4-bit pixels. Pixels and source DFM are unchanged; nonzero,
oversized, truncated or inconsistent payloads still fail.

The earlier 64,960-byte fixture failed native startup. Moving GUI diagnostic
storage outside DGROUP resolves that blocker without reducing its 4-KiB stack
or 2-KiB heap. The expanded `win16-select-runtime-test` now uses 64,000 guarded
bytes and verifies initial/label focus, select/deselect callbacks, lowercasing,
empty/repeated delimiters, callback failure/recovery, close/Escape, HWND recreation
and 20 create/show/free cycles with USER/GDI resource guards. Earlier callbacks
are not rolled back if a later callback fails; original event semantics remain.

`win16-select-language-runtime-test` uses one 64,384-byte EXE with the original
German/French/English catalogues. It checks model/native captions, localized label
and select mnemonics, Escape, recreation and nil clearing of public typed fields,
InitialControl and FocusControl after explicit Edit.Free. Existing duplicate
catalogue mnemonics follow the shared first-match policy; Escape remains available.
Both selection profiles are included in the accepted UI batch. This does not
complete the configurable icon cache, full Forms framework or shell application.

## Native push buttons and original picture buttons

`StdCtrls.TButton` exposes the real implementation in `native_button.pas`.
It privately superclasses USER's BUTTON class rather than imitating mouse,
capture, focus and Space-key behavior. Native extra bytes are preserved and the
inherited procedure handles painting/input through CallWindowProc. Font changes
send WM_SETFONT; native text colors remain Windows-controlled. Public Click
requires Enabled; routed BN_CLICKED also requires Visible. ANSI captions reject
embedded NULs. Native post-creation font setup failures destroy the partial HWND;
replacement-font allocation failures select a safe stock font before propagating.
Those rare allocation failure paths are source-guarded, not fault-injected.

Parents route Win16 WM_COMMAND by HWND/notification layout only to direct,
managed children with matching control IDs. Unmanaged/foreign controls are not
interpreted as Pascal objects. Set managed Parent for notifications: the legacy
raw CreateControl(HWND) path does not infer object parenting. WM_DRAWITEM routes
by the managed child HWND and marks the parent as compositing during the draw.
Click/draw exceptions are recorded by the receiving parent's callback boundary;
no Pascal exception unwinds through USER. Do not free receivers/owners in events.

`Buttons.TBitBtn` keeps USER's native owner-draw button behavior and paints its
frame, caption, focus and owned bitmap glyph through the provided scoped HDC.
Glyph assignment deep-copies; nil clears the stable container. Preserve its
internal OnChange handler. Layout supports glyph left/right/top/bottom, directional
content margins and automatic margin/spacing. Caption measurement uses native
mnemonic-aware DrawText. Color-key transparency defaults to the bottom-left glyph
pixel, or uses an explicit bitmap key. Strips select normal/disabled/pressed
frames from native ODS state; a fourth frame can be stored but no exclusive mode
is provided. A missing disabled frame is not automatically synthesized.
The native HDC, selected objects and drawing guard are restored even after errors;
do not change fonts, glyphs or lifetimes inside DrawButton. Parent Update and
Click during owner drawing are explicitly rejected.

The original public-domain `vcl/picbtn.pas` now builds against that subset.
Its Loaded method retains glyph suppression, height delta, margin and spacing
policy. The FPC branch excludes the unavailable Dialogs-specific
PicBtnGlyphsChanged function rather than adding inert message-dialog globals;
the historical Delphi branch retains it. Tests call the genuine Loaded method
explicitly; there is still no DFM loader. Default/Cancel and TabOrder are provided
by the explicit modeless navigation layer. ModalResult now routes through managed
parents to the modal form; button Kind, speed buttons, drag/drop and full Buttons
remain absent.

```sh
make win16-button win16-bitbtn
WIN311_IMAGE=/path/to/baseline.img make win16-button-runtime-test win16-bitbtn-runtime-test
```

Native tests verify mouse/Space/capture, outside-release cancellation, disabled/
hidden filtering, foreign-control rejection, callback recovery, native fonts,
live reparent/recreation, original PicBtn loading policy, glyph pixels/states,
all layouts, owner-draw cleanup and 60 activation/reparent/redraw resource cycles.

## Graphic visibility, updates and owned image control

Windowless controls now expose Show/Hide and Update/Repaint. Show/Hide change
Visible and invalidate affected bounds. Update flushes the parent's pending
update without acquiring a persistent HDC or pumping the task queue; it also
flushes removal of a just-hidden graphic. Repaint invalidates first, then updates.
Detached controls do nothing. TCustomControl.Update rejects drawing/compositing
or handle-change reentry; graphic Update also rejects its own active paint scope.
This supports the label Show/Hide/Update calls used by the original Progress unit
without claiming that complete dialog now compiles.

`src/win16/extctrls.pas` adds a real `TImage(TGraphicControl)` subset. Its owned
TPicture is stable across assignment: values are deep-copied; nil clears content,
not the container. Picture/bitmap edits invalidate automatically. Do not replace
the picture's internal OnChange handler. Center offsets native-size content,
including negative origins for clipped oversized images. Stretch fills the whole
box; bitmap color-key transparency preserves the image's own background.
AutoSize tracks nonempty picture dimensions; clearing retains the existing box.
Enabling AutoSize validates bounds before committing the flag. Picture changes
are already committed before their notification, so a failed automatic bounds
change can retain new content with previous geometry. Do not mutate image data
or ancestors while painting.

Public Image.Canvas is the persistent owned bitmap canvas, not the borrowed
rendering canvas. First access with no graphic creates a bitmap at the explicit
control dimensions; icon-backed canvas access raises without replacing the icon.
For existing empty bitmaps, set dimensions before drawing. Native icons draw with
their mask; scaled icons are first flattened against Color into a temporary
bitmap, then stretched and freed in finally. The control remains opaque: no
transparent-parent rendering or alpha compositing. PNG/JPEG/ICO file decoders,
Proportional, alignment, mouse routing and other ExtCtrls classes are absent.

```sh
make win16-image
WIN311_IMAGE=/path/to/baseline.img make win16-image-runtime-test
```

Native pixel/lifetime checks cover center/crop/stretch, bitmap edits, color keys,
visibility/update, resize/clear, failed replacement, bitmap canvas semantics,
scaled icon/reference equivalence, independent picture ownership, bounds overflow,
paint-update reentry and 60 icon replacement/render cycles.

## Combined progress UI acceptance

Two programs share `tests/pascal/progress_ui_probe.inc`. The progress-ui profile
combines TNativeForm, TLabel, TImage, the original TWin95Gauge and the native task
loop. The progress-button profile substitutes a native TButton for the image;
posted mouse down/up events must invoke its Cancel handler, not a synthetic
direct OnClick call. Both inspect real timer-driven gauge pixels, recreate their
owned models after HWND destruction, complete a later run and test Escape abort.
The image profile also checks retained icon content; graphics remain HWND-free
while the button profile has exactly one child HWND. Twenty show/update/hide
cycles must not post stray task-quit messages.

```sh
make win16-progress-ui win16-progress-button
WIN311_IMAGE=/path/to/baseline.img make win16-progress-ui-runtime-test
WIN311_IMAGE=/path/to/baseline.img make win16-progress-button-runtime-test
```

Both profiles use a native-tested 4-KiB stack and 1-KiB local heap. The
former 2-KiB local heap passed the static 64-KiB NE budget check but Win3.11 refused
startup; keep loader/runtime testing in addition to that necessary size guard.
Adding both the image and native button to one executable exceeded this fixture's
data budget or failed native loading even after compacting diagnostic strings.
The profiles therefore remain separate; shrinking/ignoring the guard is not a
solution to full-shell memory organization. Pascal objects use the global heap.
These are test settings, not final shell memory requirements. The examples are
integration evidence, not replacements for `src/progress.pas`: no file operations,
DFM loading, complete TPicBtn/Buttons, modal behavior or VCL-compatible reentrant
Application.ProcessMessages is provided.

## Modeless native form lifecycle

`native_form.pas` builds `TNativeForm` on the real windowed Controls subset.
It is a form foundation, not the `Forms` unit expected by the complete shell.
Construction allocates no HWND, starts hidden and defaults to 320x200 outer
bounds. `Show` creates an unowned, decorated top-level HWND, recursively creates
managed children and makes it visible without forcing activation. `Hide` retains
the HWND tree, releasing actual focus/capture held by the form or its descendants.
`Caption` is an ANSI ShortString, validated against embedded NULs and applied
through SetWindowText when live. Native owned/child form windows are rejected;
use managed Parent only for the form's controls, not the form itself.

Explicit Show/Hide transitions invoke OnShow/OnHide after changing visibility;
repeated calls produce no duplicate event. These are method lifecycle events,
not observers of arbitrary external ShowWindow calls or raw Visible assignments.
`Close` and WM_CLOSE first invoke the Boolean OnCloseQuery veto, then OnClose's
action: `ncaNone`, `ncaHide` (default), or `ncaDestroy`. Destroy hides and removes
the native HWND tree but deliberately retains Pascal objects/model parents. A
later Show recreates the frame, stored title and managed descendants. This is
not Delphi's `caFree`; no callback synchronously frees its receiver. Detached
Close does nothing. An unhosted form does not post task WM_QUIT; an attached
lifecycle host is notified after a successful TryClose and may apply main-form
termination policy without changing the form's standalone behavior.

Lifecycle reentry and closing/showing/hiding during the form's drawing scope are
rejected. Direct event exceptions propagate after clearing the guard. Native
WM_CLOSE exceptions use the existing callback diagnostic boundary. Visibility
already changed before a failed OnShow/OnHide is not rolled back. As elsewhere,
callbacks must not free their receiver/owner, destroy native windows or mutate
ancestor lifetimes while a descendant is drawing. Component destruction does
not synthesize Close/Hide events. DFM streaming, general modeless ownership, menu
resources and full TForm remain
unimplemented. Native activation, resize and window-state layers are described below.
Owner-scoped modal behavior is provided by TNativeModalForm separately. Modeless
Tab/default/cancel navigation is an explicit additional layer, not automatic Show behavior.

```sh
make win16-form
WIN311_IMAGE=/path/to/baseline.img make win16-form-runtime-test
```

The probe runs queued WM_CLOSE through the message loop and checks veto/actions,
actual frame titles/visibility, child focus/capture release, callback exceptions,
reentry/drawing guards, recreation and surviving child objects. Sixty recreation
cycles check coarse USER-resource stability; this is not a completed Calmira form.

### Native activation and live form focus

`TNativeForm.Active` queries the real task-local active HWND. `ActiveControl`
reads the currently focused, usable managed descendant of that active form;
frame focus, inactive/lazy/destroyed forms and external children return nil.
There is no cached child reference to survive reparenting or destruction.
Assigning ActiveControl requires an already-active form and a visible, enabled
descendant whose model and native ancestry both match. Nil focuses the frame.
Assignments do not create handles, activate another form or change InitialControl;
use the weak InitialControl property for deferred focus on Show. This intentionally
does not implement Delphi's remembered ActiveControl for inactive forms.

OnActivate/OnDeactivate are driven by native WM_ACTIVATE, including click-active
and nested cross-form transitions. USER default processing runs first, even when
the subsequent event raises. Active remains a live query, not a flag inferred
from a previously delivered message. Events may focus an existing child or
activate another window, but recursive Show/Hide/Close on the notifying form
is rejected. Focus assignment is guarded across native OnEnter/OnExit callbacks;
an event cannot recursively assign ActiveControl during the same operation.
Activation depth has a recursion limit and every guard clears in finally.
Receivers/owners must outlive callbacks: defer destruction rather than freeing
the form, its target control or its native HWND from these events. Exceptions
stay inside the existing USER callback boundary and record CallbackErrors and
LastCallbackError; later activation/focus operations can recover.

`make win16-form-activation-runtime-test` verifies actual USER transitions,
live EDIT focus, callback focus assignment, same-window no-op, invalid/inactive/
hidden/disabled targets, native/model ancestry disagreement, lifecycle and focus
reentry guards, activation/deactivation exceptions, nested activation, modal
owner/focus restoration, child destruction, HWND recreation and repeated
USER/GDI resource retention. The probe retains a 4-KiB stack, 2-KiB heap and
stack canary. It does not qualify physical mouse input, full Forms/DFM integration,
application-wide activation by itself or automatic Screen change notifications.
The separate task-activation layer supplies application notifications.

The first full activation batch exposed a Win3.11 loader limit in the original
selection dialog's language profile: its static budget was 64,528 bytes and USER
reported insufficient memory before the first log line. Static NE validation is
necessary, not sufficient for native loading. Sharing/shortening form error
diagnostics lowers that profile to 64,464 bytes (the prior accepted cursor
checkpoint was 64,480); focused language and activation probes then load and pass.
No stack/heap settings, guard thresholds, original resources or assertions were
reduced. Keep both native loader acceptance and the static budget check when
extending this shared layer.

### Native resize and client dimensions

Windowed Controls now expose read-only ClientWidth/ClientHeight from their
existing ClientRect query. Live HWNDs use USER's actual client area; lazy models
report their stored dimensions without creating windows. A decorated form's
outer Width/Height are not its ClientWidth/ClientHeight. Client-size assignment,
automatic alignment and constraints are not implemented.

TNativeForm provides virtual Resize and OnResize. WM_SIZE first retains the base
native bounds/default/invalidation behavior, then reads GetClientRect rather than
trusting the message's dimensions. Only changed native client dimensions notify;
moving a window, assigning identical bounds or sending a forged WM_SIZE does not
produce an extra event. The comparison baseline is committed before notification
and reset at native teardown, so failed callbacks do not undo completed geometry
and recreated HWNDs can establish a fresh baseline. Hidden HWNDs may resize
without being shown. A descendant may explicitly call Resize to refresh layout
even when no dimensions changed, as the original AutoResize code requires.

A native resize event may arrange descendant controls. It cannot change its own
form's bounds or call Show/Hide/Close recursively. SetBounds is now virtual in
TCustomControl, so Width/Height/BoundsRect and base-typed calls also reach the form
guard before native mutation. Guard release uses finally; event exceptions remain
inside the existing USER boundary with CallbackErrors/LastCallbackError recorded.
As with other native callbacks, do not free receivers/owners, destroy HWNDs or
use raw USER calls to bypass lifecycle guards while notifying. These APIs do not
establish full VCL reentrant layout or physical drag-resize acceptance.
WindowState and retained normal placement are provided by the separate layer below.

`win16-form-resize-runtime-test` verifies real client/outer geometry, virtual/event
ordering before OnShow, nested panel/EDIT layout, no-op and forged messages,
external native changes, property/base-type mutation guards, invalid bounds,
explicit layout refresh, callback errors/recovery, hidden resize, HWND recreation,
modal child layout and owner/focus restoration. Fifty two-size cycles inspect
event counts and coarse USER/GDI retention. It retains a 4-KiB stack, 2-KiB heap
and stack canary. Initial resize callbacks may run while native descendants are
still being created; their bounds setters can prepare lazy child models.

### Native window state and restore placement

TNativeForm now exposes `TWindowState = (wsNormal, wsMinimized, wsMaximized)` and
WindowState. For a live, non-deferred HWND, the getter reads USER's IsIconic/
IsZoomed flags in the owning task, including external system-menu commands.
Before HWND creation, assignments store intent without allocating windows.
Assignments to a hidden form also remain deferred and never show it; while
pending, the getter reports that requested state rather than hidden USER flags.
Use Show/Hide for lifecycle synchronization, not raw Visible/ShowWindow changes
that bypass these transitions.

Show captures the request before creation, clears deferral, shows the native
frame and applies any remaining state transition before OnShow/initial focus.
Native resize/activation callbacks can see intermediate real states during this
sequence; it is not an atomic single-message display operation. Hide snapshots
the current request/state for the next Show. Visible changes use SW_MINIMIZE,
SW_SHOWMAXIMIZED or SW_SHOWNORMAL and verify the result. Explicit wsNormal must
mean normal: SW_RESTORE could instead restore a formerly maximized icon to
maximized. External SC_RESTORE retains USER's own restore-to-maximized policy.

State changes are guarded against lifecycle/activation/resize reentry, and their
guard clears in finally. Callback exceptions stay inside the existing USER
boundary; completed native state is not rolled back, and diagnostics remain
available. Bounds assignment to a live nonnormal frame is rejected rather than
overwriting its icon/maximized geometry or guessing restore-placement semantics.
Configure normal bounds before Show or after returning to wsNormal. A minimized
form reports no ActiveControl, rejects child-focus assignment and does not route
dialog keys. Initial-focus and modal fallback logic do not focus its descendants.

Before native teardown, an initialized Win3.1 WINDOWPLACEMENT captures the normal
rectangle. After inherited teardown handling, the protected model-only StoreBounds
helper restores that rectangle without moving an HWND or invoking resize events.
The logical state remains deferred for recreation; subsequent lazy SetBounds
changes configure the next normal rectangle. This avoids retaining icon dimensions
as a recreated frame's size. Placement-query failure records a callback error
rather than substituting guessed normal coordinates.

`win16-form-state-runtime-test` covers deferred/minimized startup, OnShow state,
focus/key suppression, native resize observation/reentry, invalid states, actual
system commands, explicit normal versus native restore-to-maximized, hidden
requests, hide/show, normal placement through min/max teardown/close/recreation,
lazy bounds changes, event exceptions/recovery and maximized/minimized modal
startup with owner/focus restoration. Thirty max/min/normal cycles inspect native
placement and USER/GDI retention. The probe retains a 4-KiB stack, 2-KiB heap and
stack canary. This does not provide Application.Minimize, a global Forms unit,
DFM streaming, persisted placement files or complete desktop acceptance.

## Scoped native painting

`native_paint.pas` adds `TNativePaintWindow`, a separate descendant of the
window foundation, not `TCustomControl`. WM_PAINT uses a real BeginPaint/EndPaint
pair and the native update-region clip. Before virtual `Paint`, it fills the
update bounds with `Color` (default clBtnFace) using a temporary owned brush;
the persistent canvas brush is not changed by that fill. WM_ERASEBKGND returns
handled because background painting belongs to this transaction.

`Canvas` is owned by the window, but its HDC is borrowed only during Paint or an
explicit DrawNow callback (see below). Brush/pen/font settings may be configured
earlier; unscoped drawing fails because Canvas.Handle is zero. Do not free the canvas, change its Handle or keep
its HDC. `Painting` and `PaintRect` describe the active transaction; PaintRect is
only the update **bounding rectangle**, not a replacement for Windows' potentially
disjoint clip region. PaintRect is cleared afterwards.

`Invalidate` schedules the whole client area; `InvalidateArea(Rect)` schedules
a bounded region. `Repaint` invalidates and synchronously calls UpdateWindow.
Detached windows and invalid rectangles are rejected; zero-area invalidation
does nothing. Empty WM_PAINT messages do not call Paint. Reentrant WM_PAINT is
ignored without replacing the active canvas. This is not PaintTo/printing or a
WM_PAINT-with-external-HDC protocol.

The paint wrapper restores DC state, detaches the canvas and calls EndPaint even
when Paint raises; the existing native callback boundary records the exception.
The update is then validated, not automatically retried. Use a later explicit
invalidation/repaint after resolving the failure. Paint callbacks must not free
their receiver/owner or destroy its HWND. Deferred release and a transparent,
VCL-compatible control-canvas lifecycle remain unimplemented; original controls
still need adaptation beyond these explicit scopes. The slider's FPC path now
uses them explicitly; see the component acceptance section below.

```sh
make win16-paint
WIN311_IMAGE=/path/to/baseline.img make win16-paint-runtime-test
```

The native probe inspects real visible-window pixels, full/partial/disjoint
updates, background changes, update validation, empty/reentrant paint, recovery
after exceptions, detached-canvas errors and 150 normal/failing paint cycles
with coarse GDI/USER resource guards. It does not validate full Controls/Forms.

## Immediate drawing scopes

`TNativePaintWindow.DrawNow(Painter: TNotifyEvent)` supplies explicit, synchronous
drawing outside WM_PAINT. The method passes Self to the callback, which may use
the existing Canvas or borrowed Canvas.Handle. A scope without an active canvas
acquires GetDC and releases it in finally. Nested scopes reuse the current HDC,
including Paint's update clip, and SaveDC/RestoreDC isolates raw native DC state.
An intervening WM_PAINT temporarily binds its own paint HDC and restores the
outer drawing binding instead of clearing it. No persistent GetDC cache is held.

For example, a method `DrawThumb(Sender: TObject)` may draw through Canvas;
an input handler calls `DrawNow(DrawThumb)`. This is an explicit API, not automatic
HDC acquisition for arbitrary `Canvas.Handle` access in the unchanged legacy
controls. Do not free the receiver/owner, destroy the HWND, replace Canvas.Handle
or retain the borrowed HDC inside the callback.

Nil callbacks and detached windows are rejected before acquiring a DC. Direct
callback exceptions propagate to the caller after cleanup; drawing invoked by a
native input callback instead reaches the existing callback diagnostic boundary.
Pixels already drawn are not rolled back. Immediate drawing neither validates
pending update regions nor replaces the control state needed by later Paint.
Canvas style properties persist, but temporary native DC state is restored.

```sh
make win16-draw
WIN311_IMAGE=/path/to/baseline.img make win16-draw-runtime-test
```

The native probe checks actual window pixels, nested and Paint-nested scopes,
WM_PAINT during immediate drawing, unchanged outside pixels/clip state, pending
updates, direct/mouse-callback exception cleanup and 150 successful/failing scopes
with coarse GDI/USER resource guards. These are not full original slider tests.

## Native input and focus events

`native_input.pas` adds `TNativeInputWindow` on top of scoped painting, not a
`Controls` unit. Virtual MouseDown/Up/Move, KeyDown/Up/Press and DoEnter/DoExit
methods dispatch the corresponding OnMouse*, OnKey*, OnEnter and OnExit events.
Left/right/middle mouse messages use signed Win16 coordinates and WPARAM button,
Shift and Ctrl flags; Alt comes from GetKeyState. Double-click messages deliver
a second MouseDown with ssDouble. The private native window class now registers
CS_DBLCLKS so USER can generate these messages. No OnClick/OnDblClick synthesis,
automatic mouse-down focus, drag/drop or wheel protocol is supplied.

Keyboard modifiers use GetKeyState, with the LPARAM context bit retaining Alt
for system keys. A var Key may replace the value passed to DefWindowProc; zero
suppresses default processing of that message. This does not remove independently
queued character messages. KeyPress handles single-byte ANSI WM_CHAR/WM_SYSCHAR,
including high-bit characters; #0 consumes the message. Packed DBCS characters
are forwarded unchanged without a truncated event. Dead keys/IME, translation,
accelerators, Tab navigation and a dialog/application message loop remain outside
this adapter. Unconsumed system keys keep their original message identity.

Focused queries GetFocus instead of caching events. SetFocus requires a visible
window and enabled child/ancestor chain, invokes USER and verifies the resulting
focus; OnEnter/OnExit follow real focus messages. MouseCapture also queries USER:
acquisition is explicit, release affects only the owning HWND, and native window
destruction releases ownership. It does not implement Win32 capture-change events
or a drag cancellation state machine. Event exceptions use the inherited callback
diagnostic boundary, not rollback. Receivers/owners must not be freed synchronously
inside events, and canvas drawing requires Paint or an explicit DrawNow scope.

```sh
make win16-input
WIN311_IMAGE=/path/to/baseline.img make win16-input-runtime-test
```

The native probe delivers synthetic keyboard/mouse messages through real HWNDs
and tests actual USER focus/capture transfers, disabled/hidden windows, key
replacement/consumption, ANSI/DBCS boundaries, exception recovery and resource
stability. It saves/restores the VM's keyboard state. This is not end-to-end
physical keyboard/mouse, accelerator or full original-control acceptance.

## First original control: slider

`src/win16/controls.pas` is an initial windowed subset, exposing TCustomControl
on the native input/paint base. Width/Height configure precreation sizes and
resize live child HWNDs; Enabled and Visible map to USER and release owned
capture when disabling/hiding. Invalidate is a no-op
before creation. `CreateControl(ParentHWND)` explicitly creates a child at its
stored bounds. Managed object parenting is now also supported (see below).
This is not a complete TWinControl implementation,
alignment engine, DFM loader or full Controls API. Graphic parenting is a separate
subset described below. Native Point/PtInRect helpers
avoid a reproduced failing foreign POINT-by-value hit test; right/bottom edges
are excluded. The pinned RTL remains unchanged.

The **original `vcl/slider.pas`**, not a replacement implementation, now builds
and runs with Free Pascal. Conditional FPC adaptations use DrawNow for immediate
thumb updates and real capture for dragging, cancel stale drag state when capture
is lost, and invalidate on native focus events. Saved thumb bitmaps are replaced
on Paint for current orientation/size and always deselected in finally. Partial
paint or property/size invalidation marks the saved background dirty; the next
value update repaints fully rather than restoring an invalid cached strip.
The focus checkerboard cache tracks both colors. Zero/inverted/too-wide ranges,
nonpositive track/thumb sizes and zero travel divisions are guarded. Drag/key
arithmetic clamps as LongInt before conversion to the Win16 Integer property.

The Delphi branch retains its original properties/focus protocol; host conditional
guards check it, but this does not claim a new Delphi compiler run. Unsupported
FPC properties (hints/help, click/drag-drop) are not published as inert
placeholders. Functional TabStop/TabOrder are inherited from TCustomControl;
set TabStop explicitly to include a slider in modeless traversal.
Supported value/style, visibility/enabling and input/focus events
remain available. Other original controls and the full desktop are not implied.

```sh
make win16-slider
WIN311_IMAGE=/path/to/baseline.img make win16-slider-runtime-test
```

This native probe uses a tested 4-KiB stack/2-KiB local heap: its former 4-KiB
local heap failed Win3.11 startup despite passing the static 64-KiB budget guard.
Passing that guard alone is not proof a near-limit executable loads. Pixel and
behavior checks cover the original vertical/horizontal thumb, immediate value
updates, partial redraw, keyboard/drag/capture, focus patterns/color changes,
resize, degenerate/invalid geometry, extreme signed coordinates and 100 redraw
cycles with coarse GDI/USER pool guards. Input messages are synthetic; USER HWND,
focus, capture and drawing are real. No Forms/DFM or physical-input loop is tested.

## Windowless graphics and the original pie chart

`TGraphicControl` derives from the shared TControl/TComponent base, not the
windowed TCustomControl.
It owns a persistent canvas but no HWND. Explicit `Parent: TCustomControl` and
Left/Top/Width/Height/SetBounds describe its parent-client rectangle. The parent
composites visible graphic children in attachment order after its own virtual
Paint, even when that override does not call inherited Paint. Top-level DrawNow
also composites graphics after immediate parent drawing; nested/Paint scopes do
not composite them prematurely.

Each child renders fully into a temporary compatible bitmap under its own scoped
canvas. The parent HDC is saved, its viewport offset, and its update clip intersected
with the child bounds before the final SRCCOPY. The opaque Color background and
full geometry are available to Paint even for a tiny update. This avoids the
reproduced pie-shadow mismatch when FloodFill's seed lies outside an update clip.
Both temporary bitmap and child canvas binding are cleaned up in finally. Moving,
hiding, changing or reparenting invalidates old/new regions. Parents detach
surviving graphics on destruction; TComponent ownership separately decides which
objects are freed. Reparenting during paint/composition is rejected. Bounds are
checked with LongInt before Win16 coordinate conversion.

The original `vcl/win95pie.pas` now builds and renders through this path. Its
existing geometry, trigonometry, Pie and FloodFill implementation is retained.
FPC setters invalidate when outside Paint; values are clamped to Maximum and
invalid depth/degenerate geometry is guarded. Unsupported Align, hint and
ParentColor properties remain excluded from FPC, with the Delphi branches kept.
The source's legacy comment encoding was mechanically normalized to UTF-8.

```sh
make win16-graphic
WIN311_IMAGE=/path/to/baseline.img make win16-graphic-runtime-test
```

Native checks cover original 0%/100% pie pixels at nonzero offsets, absence of
child HWNDs, clipping, immediate underlay drawing, partial updates, old-region
cleanup, reparenting, hierarchy-mutation rejection, paint exceptions, parent
destruction and repeated chart redraws. This is an opaque, noninteractive graphic
subset: mouse hit routing, transparent controls, inherited ParentColor, alignment,
complete TWinControl integration and Forms/DFM remain unimplemented. Paint callbacks
must not free receivers/parents, change the hierarchy or synchronously repaint
their parent. Bounds changes during child Paint are rejected. Their canvases may
be used only during their own Paint callback; whole-child buffering costs
temporary GDI memory proportional to child size.

## Windowed bounds and managed parenting

TCustomControl now has Left/Top, SetBounds and writable BoundsRect. Bounds are
parent-client-relative for children and screen-relative for top-level windows;
Width/Height are outer dimensions, with ClientRect exposing the separate drawing
area. LongInt checks reject inverted/overflowing rectangles before changing the
window. WM_MOVE/WM_SIZE and native queries refresh stored geometry, including
external USER moves. Bounds survive native destruction and later recreation.
Drawing/composition/creation scopes reject geometry and hierarchy mutation.

`Parent: TCustomControl` is a managed object relationship, separate from Owner.
Assigning a live parent creates a missing child HWND; assigning an uncreated
parent retains a model-only child. Parent handle creation then creates the
descendant tree. Moving a live child between live parents uses USER SetParent,
preserves descendant HWNDs and reapplies its parent-client position. Focus and
capture in the moved subtree are released. Object/native ancestry checks reject
cycles; live top-level HWNDs cannot be converted into child windows by this API.

Parent := nil destroys the native subtree but retains child objects, descendant
relationships and bounds. DestroyHandle alone retains object parenting, so
recreating the parent restores its native descendants. Freeing a parent instead
detaches surviving child objects; Owner separately determines object deletion.
Failed automatic creation rolls back list membership. Failure while building a
deferred subtree destroys the partial native tree but keeps its model retryable.
Native reposition failure attempts rollback; if rollback itself fails, the HWND
subtree is destroyed rather than leaving a mismatched native/object parent.
That exceptional USER-failure branch has source guards, not injected native tests.

```sh
make win16-hierarchy
WIN311_IMAGE=/path/to/baseline.img make win16-hierarchy-runtime-test
```

Native tests cover actual parent-relative positions, decorated outer/client sizes,
external movement, handle-preserving reparent, nested focus/capture, detach/retry,
cycles, bounds errors, partial creation failure and USER-resource stability.
The legacy CreateControl(HWND) API does not infer a Pascal parent; direct native
reparenting does not update the managed model. Same-parent assignments are no-ops;
explicit CreateControl remains available after manual child-handle destruction.
Alignment, docking, full TControl/TWinControl, DFM/Forms lifecycle and
destruction from within callbacks remain outside this subset.

## GDI drawing foundation

`src/win16/gdi_canvas.pas` supplies `TGDICanvas`, persistent pen/brush/font state,
and lazy native GDI handles. It deliberately does not masquerade as a complete
`Graphics` unit. A tested public compatibility subset now exposes these
primitives (see below); complete original visual-component integration is not
done yet.

The canvas borrows its HDC: callers create/release the DC and any selected
bitmap. It owns its three drawing resources and must be freed before the DC.
Drawing saves/restores the borrowed DC, including its selected pen, brush,
font, text colors/background mode and raster mode. Line operations intentionally
advance the current pen position. Copy drawing is independent of a caller's
XOR raster mode; pixel writes must explicitly select `R2_COPYPEN` as well.

Available operations are lines, rectangles, solid/hatch/clear brushes, basic
font style/height/name/color, text measurement/output, pixels and system-color
resolution. Changing a resource invalidates its cached handle; Assign copies
state without sharing handles. Stock null pen/brush handles are borrowed, not
deleted. `RefreshSystemColors` explicitly invalidates cached resources; automatic
theme notifications are part of the future control layer.

Native tests draw into a real compatible color bitmap and inspect pixels,
including font-color pixels. They verify DC restoration, invalid input, separate
assigned state and 300 change/draw cycles without a material GDI-pool decrease.
The percentage-based pool check is a coarse regression guard, not proof of
zero resource leaks. HDC-zero checks are not a complete invalid-handle validator.
No palette manager, printer canvas, Pen.Mode API, full DPI-notification support
or DFM graphics streaming is supplied.

```sh
make win16-gdi
WIN311_IMAGE=/path/to/baseline.img make win16-gdi-runtime-test
```

## Bitmap files and resources

`src/win16/gdi_bitmap.pas` adds an explicitly owned `TGDIBitmap`, not the full
VCL `TBitmap`. It loads BMP files and named/numeric native bitmap resources,
exposes a drawing canvas and copies opaque pixels through `DrawTo`/`SRCCOPY`.
The bitmap owns its memory DC and restores the original selected bitmap before
releasing its handles. Treat retrieved `Handle` and `Canvas` as borrowed: do not delete
or select the bitmap elsewhere, free the canvas, or replace its HDC.
Loading prepares a complete replacement first; failure retains the old image.
`Clear` empties the bitmap and detaches the canvas.

Bitmaps are persistent objects with deep `Assign`: copies own distinct handles,
and editing or freeing one does not affect the other. Self-assignment is a no-op;
`Assign(nil)` clears, while incompatible persistent objects are rejected.
Assignment copies pixels, dimensions and transparency settings, not the canvas's
pen/brush/font state.
`SetSize`, writable `Width` and `Height` retain the top-left overlapping pixels
and initialize newly exposed pixels white. Shrinking discards cropped pixels.
Setting one dimension to zero releases the image but retains the requested
dimensions, supporting the existing `Width := N; Height := M` initialization
pattern. The canvas object itself remains stable across replacement. Invalid
negative dimensions fail before modifying the old image; allocation and copy
are prepared before committing a positive-size replacement.

`TGDICanvas.CopyRect` copies subrectangles using `SRCCOPY`, scaling through
`COLORONCOLOR` when their dimensions differ, and restores the destination DC's
stretch/raster state. Equal-size overlapping self-copies use `BitBlt`.
Zero-area rectangles are no-ops; mirrored rectangles, dimensions above 32767
and scaled copies within the same DC are rejected. This is not the complete
VCL CopyMode/graphic-drawing interface.

The portable `bmp_reader.pas` checks signature, lengths, dimensions, pixel offset,
palette and overflow-safe row sizes before native allocation. Supported files
use the 40-byte Windows DIB header, bottom-up uncompressed 1/4/8/24-bit pixels
and full palettes for indexed images. Declared file length must equal actual
length. RLE, top-down, reduced palettes, OS/2/extended headers and other codecs
are deliberately rejected. Dimensions must fit positive signed Win16 words;
each padded row is limited to 60,000 bytes. Scan-line loading avoids a whole
image allocation, including for the existing 129,078-byte shutdown bitmap.
Resource decoding is delegated to Windows `LoadBitmap`, not this file parser.

`make fpc-test` runs parser boundary/error tests with range/overflow checking
and validates all 58 repository BMPs. The native GDI probe compares every pixel
of the same file/resource image, checks known 1/8/24-bit pixels and orientation,
crosses the 64-KiB image boundary, exercises failed replacement, blitting,
clear and 300 alternating file/resource reloads. WRC binds the test resources
after FPC linking. No palette realization or exact arbitrary 24-bit color
reproduction on a lower-color display is promised.
Native editing checks additionally cover independent copies, grow/shrink,
empty dimensions, invalid operations, scaled/overlapping subrectangles and a
strip-growth sequence modeled on `TStartImages`. The 300-cycle check also
clones and resizes bitmaps; GDI pool percentages remain only a coarse guard.

## Graphic dispatch, icons and color keys

`TGDIGraphic` is the persistent abstract drawing base. `TGDICanvas.Draw` dispatches
to bitmap/icon implementations while preserving the destination DC.
`gdi_icon.pas` owns private `CopyIcon` copies, including when loading shared
named/numeric `LoadIcon` resources. `CopyFromHandle` borrows its input only long
enough to copy it; the caller remains responsible for extracted/created icons.
Deep `Assign`, self-assignment, `Clear` and `Assign(nil)` are supported. Failed
resource loads preserve the old icon. Drawing uses native Win16 `DrawIcon` and
its AND/XOR masks, including transparent and inverted pixels. Inversion depends
on device color indices, not necessarily bitwise inversion of 24-bit RGB.
There is no ICO file loader, icon resizing or Win32 `DrawIconEx` implementation.

Bitmaps expose `Transparent` (default false) and explicit `TransparentColor`
(default white, not an automatic corner-pixel rule). `CopyTransparent` preserves
the destination under key pixels; `BrushCopy` replaces them with the canvas's
brush background. A clear brush preserves the destination instead. Both take
a source **canvas**, not the final VCL bitmap argument, and can scale rectangles.
The future compatibility wrapper must adapt the original `BrushCopy` signature.

`gdi_colorkey.pas` creates private color/monochrome scratch surfaces, builds the
key mask and composites using `SRCAND`/`SRCPAINT`. It snapshots inputs before
output, making overlapping copies safe without editing the source bitmap/DC.
Uncovered source pixels start as key pixels instead of uninitialized memory.
Scratch handles are released on success and exceptions. Brush origin and caller
DC state are preserved; no Win32 transparency API, per-pixel alpha, custom
palette realization or arbitrary mapping-mode compatibility is provided.

Native checks compare icon pixels against direct `DrawIcon`, inspect known
monochrome masks and resource ownership, and verify transparent/opaque output,
brush replacement, overlap, source clipping and hatch alignment. Repeated
icon/color-key draws have a coarse GDI-pool regression guard. This does not prove
absence of every USER/GDI resource leak or out-of-memory behavior.

The larger combined probe uses an explicit 4-KiB local heap and 4-KiB stack;
far Pascal allocations use the global heap. The former default 8-KiB local heap
made this probe fail to start under Win3.11 with a memory error. The build runs
`tools/check_win16_budget.py`, conservatively requiring automatic data allocation
plus requested stack and local heap to fit within 64 KiB. This is a probe budget
guard, not a general NE executable validator or a complete shell memory solution.

## Public Graphics compatibility subset

`src/win16/graphics.pas` now exposes real `TCanvas`, `TBitmap`, `TIcon`, `TGraphic`,
pen/brush/font aliases and their enum names. This is a limited adapter over the
native-tested foundation, not an empty unit that merely lets compilation pass.
Bitmap canvas creation is virtual: original-style derived bitmap constructors
receive an actual public `TCanvas`, retaining its identity across resize/load.
The public `BrushCopy` takes a bitmap, matching the original component call.
`Empty`, resource-name/ID loading, drawing, assignment and resizing are available.

`TRect`, `TPoint`, `Rect` and `Bounds` explicitly use Win16 coordinates/layout,
avoiding FPC's conflicting 32-bit Types records. Bounds arithmetic rejects
out-of-range coordinates. Resource names reject embedded NULs rather than
silently loading a truncated name. Pen/brush/font property assignment copies
state, not object ownership. Their exposed native handles are borrowed: do not
delete them or cache them across property changes. Font `Size` converts points
to negative character height using native display `LOGPIXELSY`; negative sizes
and heights exceeding signed Win16 range are rejected. This is not a full
font DPI-notification/pitch/charset implementation.

The portable `color_names.pas` implements 39 canonical RGB/Win3.1-system/sentinel
names, case-insensitive lookup, enumeration and numeric round trips. Numeric
input is bounded to signed-negative/unsigned-positive 32-bit bit patterns;
64-bit hexadecimal values cannot wrap into valid colors. Graphics forwards
these routines using AnsiString-compatible signatures. The original, unchanged
`vcl/calcolor.pas` compiles and runs against them, including its extra named
colors and numeric fallback. `make fpc-test` also exercises the portable registry
with range/overflow checks.

```sh
make win16-graphics
WIN311_IMAGE=/path/to/baseline.img make win16-graphics-runtime-test
```

The separate native public-API probe uses `Graphics`/`CalColor` only, not the
foundation names. It verifies record sizes, bitmap-argument BrushCopy, derived
resource constructors, canvas identity, independent assignment, font/resource
properties, resource-name validation and color callbacks. It reuses the
private-image GDI runner and writes `GDITEST.LOG`; generated output is under
`build/tests/win16-graphics/`.

Important gaps remain deliberate compile-time omissions: ICO/BMP stream
serialization, metafiles and DFM graphics
properties. There is no silent no-op fallback.
Forms and Controls still prevent building the full desktop.

## Image handle ownership

Image `Handle := Value` now delegates to explicit `TakeHandle`: a successful
nonzero assignment takes ownership of an unselected bitmap or private icon.
Replacing/clearing/destroying the object releases its old native resource;
self-assignment is harmless. `Handle := 0` means clear/delete, **not detach**.
`ReleaseHandle` empties the object and returns a live native handle to its caller,
who must eventually delete/destroy it or transfer it to another owner. Bitmap
detach restores the memory DC's original stock bitmap before deleting that DC.
The public canvas object remains stable but is detached from its HDC.

Failed bitmap transfer leaves both the old image and caller's input object
alone. Internal file/resource loaders still clean up their own failed inputs.
`CopyFromHandle` borrows its input and creates an independent private copy.
Borrowed bitmap inputs must be unselected; use `Assign` between bitmap objects
whose images are already selected into their own DCs. Self-handle copies are
no-ops. Private icon adoption checks a temporary `CopyIcon` before committing;
this is not a general invalid-memory-safe handle validator. The `ExtractIcon`
sentinel 1 is rejected without destroying the previous image.

Never adopt a shared `LoadIcon` resource: use `LoadFromResource` or
`CopyFromHandle` instead. FPC branches in the resource store, question dialogs,
logon and desktop-properties preview now follow that rule; Delphi branches
retain their prior resource-loading path. `ShrinkBitmap` copies its borrowed
input inside its try/finally rather than pretending `Handle := 0` detaches it.
Unconditional extracted-icon assignments are guarded against 0/1. Taskbar glyph
loading tracks class icons as borrowed and `ProvideLastIcon`/`ExtractIcon`
results as owned, with finally cleanup and a standard-icon fallback.

```sh
make win16-handles
WIN311_IMAGE=/path/to/baseline.img make win16-handles-runtime-test
```

The native probe verifies transfer identity, replacement/destructor deletion,
failure preservation using a real non-bitmap GDI object, detach/reattach, every
pixel of a borrowed bitmap copy, and private/shared icon lifetimes. A 150-cycle
test guards against coarse GDI and USER pool drain, not every possible leak.
Offline conditional-source checks guard the FPC/Delphi migration branches.
The actual dialog/taskbar modules still depend on unfinished Forms/Controls;
their full UI lifecycle is not established by these primitive-level tests.

## Picture containers and change notifications

`Graphics.TPicture` owns at most one bitmap/icon, with `Graphic`, `Bitmap`,
`Icon`, read-only dimensions/`Empty`, `Assign`, BMP-only `LoadFromFile` and
`OnChange`. A new picture has no graphic; metadata reads do not allocate one.
Reading `Bitmap`/`Icon` creates that type if necessary and discards the previous
type. Child references are borrowed and become invalid on replacement/destruction.
Property assignment and `Assign` deep-copy the supported bitmap/icon family
into public classes, never take ownership of the caller's object. Custom
subclass-specific state and additional graphic formats are not copied.
Self-assignment is a no-op; `Assign(nil)` clears. File loads and copies prepare
a private replacement before committing; preparation errors keep the old image.
Icon dimensions use native standard icon metrics, not an ICO-file decoder.

`TGraphic` now exposes dimensions, `Empty` and `OnChange`. Bitmap changes and
managed canvas drawing forward through the owned picture, covering the original
`Picture.Icon.Assign(...)` and `Picture.Bitmap.Handle := ...` usage patterns.
Notifications occur after committing final fields and restoring drawing DC
state; source drawing/metadata reads and known zero-area copies do not notify.
SetPixel failures/clipping use unsigned `$FFFFFFFF` and do not report a change.
Repeated valid operations may notify even when their resulting pixels match.
Direct WinAPI writes through borrowed HDCs cannot be observed automatically.
Do not replace a picture-owned graphic's OnChange handler or its bitmap canvas's
internal callback. Future image controls must hook the picture-level event.

Replacement/type switching inside the picture's own callback is rejected,
preventing destruction of the active child; recursive child notifications are
coalesced while that callback runs. Keep callbacks read-only apart from marking
controls dirty, and never free the sender/owner/child from its own notification.
Callback exceptions propagate after commit, not rollback. If a callback raises
during `ReleaseHandle`, the now-unreturned native handle is destroyed so the
exception cannot orphan it. Destruction disconnects internal events before
freeing children. These rules are not a general event-loop/reentrancy framework.

```sh
make win16-picture
WIN311_IMAGE=/path/to/baseline.img make win16-picture-runtime-test
```

The native probe checks ownership, deep copies, getter/type-switch semantics,
metadata, all managed canvas drawing events, unsupported inputs, failed file
loads, callback exceptions/replacement guards and destructor behavior. A
150-cycle switch/copy/clear test checks coarse GDI/USER pool stability. The old
GDI/public-Graphics/handle probes remain separate regressions. `TPicture` still
does not implement ICO loading, format registration or DFM/stream persistence;
Calmira's actual TImage/Forms controls are not implemented by this container.

## Pattern brushes and original drawing operations

The public canvas creates a real public `TBrush` through a virtual factory.
Its `Bitmap` property supports **assignment only**: a nonempty 8-by-8 image is
snapshotted into a private unselected bitmap and rendered with native
`CreatePatternBrush`. Original slider/desktop-pattern setters now have a real
implementation; there is no getter returning a borrowed or dangling bitmap.
Source edits require reassignment; the source may be freed immediately after
assignment. Invalid sizes preserve the previous pattern/cache. `Brush.Assign`
deep-copies patterns, while invalidating a native brush retains its source pixels.
Pattern handles and bitmaps are released separately in the correct order.

Assigning `Color`, even its existing value, leaves pattern mode and returns to
solid fill, matching the slider's focused/unfocused transition. Setting `Style`
also discards the pattern; `Bitmap := nil` returns to the retained solid color.
Ordinary non-pattern hatch style behavior remains as in the foundation. Native
scratch DCs belong to pattern copying only; the canvas still borrows its HDC.
This is not a general brush-bitmap editor or arbitrary-size tile implementation.

Additional managed operations are `TextRect`, `DrawFocusRect`, `Pie` and
`FloodFill` with `fsBorder`/`fsSurface`. TextRect clips ANSI glyphs to the target
rectangle and fills with the actual solid/hatch/pattern brush unless it is
clear, intersecting the DC's existing clip. Focus drawing uses the Win16 void
USER API and is reversible when applied twice. Pie/fill operations support
the original disk-usage chart and start-menu paths. Flood seeds outside the
drawable area return without a change event. Drawing restores caller DC state
before notifying an owning picture. Text input uses the existing ShortString
adapter limit, not Unicode or a new text-layout engine.

```sh
make win16-drawing
WIN311_IMAGE=/path/to/baseline.img make win16-drawing-runtime-test
```

The separate native pixel probe models the slider checkerboard, frees its source
and copied brush, recreates caches and checks invalid-size preservation. It also
checks clipped/clear text backgrounds, reversible focus pixels, border/surface
fills, a full-circle Pie, event-time DC restoration and a 150-cycle resource
guard. These primitive tests do not instantiate original UI components; the
slider and pie chart now have separate native component acceptance probes.

`Canvas.StretchDraw(Rect, Graphic)` dispatches bitmap scaling through
`COLORONCOLOR` StretchBlt, preserving the destination clip and DC state before
one change notification. Opaque self-stretch first copies the source into a
private bitmap; transparent drawing uses the color-key compositor's source and
background snapshots. This supports `deskprop.pas` shrinking wallpaper in place
before changing Width/Height. StretchDraw itself never resizes the source.
Empty graphics/zero-area targets are no-ops; mirrored or oversized destinations
are rejected. Icons and other graphic subclasses only support their native
size through the default dispatcher; arbitrary icon scaling is not implemented.
The native drawing probe checks exact quadrants, overlapping self-stretch,
transparent self-stretch, clipping, events and repeated snapshot cleanup.

## Exception round trips

The GDI error-path probe exposed a separate native exception failure: the
stock Pascal `fpc_SetJmp` wrapper returned after calling Windows `Catch`, leaving
its captured wrapper frame obsolete. Throwing an expected exception later
faulted on return. Successful draws alone would not have caught this issue.

`fpc-win16-exception-tailcall.patch`, enabled only by
`CALMIRA_WIN16_SJLJ_TAILCALL`, tail-jumps directly to Windows `Catch`/`Throw`.
It preserves their native stack handling while eliminating the temporary frame.
The i8086 assembler cannot emit this direct far jump reliably through `jmp far`;
the patch uses opcode `$EA` with explicit offset/selector relocations. The
compatibility option requires far code and data and rejects near models.
The original implementation remains available when the option is disabled.

Windows saves the caller's instruction/stack/frame pointers in the catch
buffer; see the [Wine kernel implementation's documented Win16 layout](https://github.com/wine-mirror/wine/blob/master/dlls/krnl386.exe16/thunk.c).
Acceptance here is on native Windows 3.11, not merely Wine. The updated component
probe checks exception message preservation, re-raising and finally execution;
the GDI probe also checks expected drawing/loading errors. This does not promise
that exceptions may safely escape arbitrary OS callbacks or cross languages.

## Verification

```sh
make win16-messages
WIN311_IMAGE=/path/to/baseline.img make win16-messages-runtime-test
WIN311_IMAGE=/path/to/baseline.img make fpc-win16-classes-runtime-test
make test
```

The native probe registers a hidden real Windows window and uses `SendMessage`
through its exported window procedure into Pascal `message` handlers. Checks
cover record sizes, byte/word overlays, command/scroll/activate/mouse fields,
signed 32-bit return values, a high unsigned message ID with WPARAM `$FFFF`,
and mutation through a far min/max pointer. It writes
`MSGTEST.LOG` in a disposable image copy. This is not just a host layout test.
Default emulation is TCG. Host tests ensure every message-record name currently
referenced by owned sources is declared and that RTL preparation preserves
the original checkout. They cannot replace the native ABI test.

## Next layers

The explicit native application foundation now covers registered forms, main-window
close policy, class-reference creation, hidden-main startup, hidden task-window
transport, native task activation, cooperative root/modal idle, explicit exception
handling, WinHelp requests, focused registered-form F1 help, an explicit live
screen/form view, native/windowless view ordering and coordinate conversion,
scoped cursor management, controlled parameterless message draining, dialog-key routing
and startup-modal lifecycle. An initial `Forms` unit now supplies the global
`Application`/`Screen`, typed `TForm` views and deferred `caFree`/`Release`
(see [build status](build_status.md#initial-forms-unit)). It does not yet
provide the original shell's full `Forms` API or runtime DFM loading. Those remain to be ported alongside the remaining
Graphics interface (including DFM/ICO streaming and arbitrary icon scaling), full
Controls integration, broader control-canvas lifetime and menus. Each extension
needs native behavior tests before original Calmira components can rely on it;
the current foundations do not constitute a complete desktop.

Mixed visual-child enumeration now has a scoped implementation for the original
ControlCount/Controls[] Show/Hide, Enabled, type-check and Free patterns. Native
and graphic children share real TControl identity; a separate attachment-order
list does not conflate ownership, tab order or graphic composition. See
[mixed children](#shared-control-identity-and-mixed-children). The common base
still needs geometry/Parent/Font/hint APIs used by task.pas, miscutil.pas and
extform.pas; this subset alone does not compile those original units or Forms.

The original startup calls CreateForm for Splash, Computer, Bin, Progress and
Taskbar. Bridging these calls also requires the original form/control APIs and
resources; class-reference construction alone cannot compile them. In particular,
Application.Handle is used by taskbar filtering and CM_RELOADOPTIONS delivery;
the separate native transport now supplies that identity and sent/queued hooks,
but original taskbar/Computer handlers still need integration. The explicit
screen view now supplies native form order, active form/control, real metrics
and scoped cursors; native forms also provide activation events, live focus
assignment and guarded Resize/OnResize with native client metrics.
Per-form WindowState now preserves normal placement across native teardown;
application-wide minimize/restore remains separate. Automatic Screen change
events are still absent. The apparent
`Screen.Canvas` consumer in deskprop.pas actually declares a local TBitmap named
Screen; it is not evidence that the global screen view needs a drawing canvas.
No global screen canvas is provided. Explicit exception handling/presentation is
available separately above, as are explicit WinHelp dispatch and focused F1
routing; automatic exception routing, Shift+F1, mouse-context help, hints and
minimization remain distinct application services. Qualify these before exposing a
global Forms compatibility layer; do not silently alias missing services.
`TDesktop.NextForm` depends on the changing front-to-back Screen.Forms order,
not just the application's registration order; the explicit view now tests that
selection policy and its real BringToFront activation/order behavior, but the
original desktop still requires full Forms integration.
Its SetCursor/ReleaseCursor pair also nests saved cursor states. The explicit
cursor policy now tests equivalent nesting, but the original desktop/resource
loader still requires porting and its custom cursor registrations.
The companion SHOWDESK/EXPLORER/CTASKMAN programs locate class `TApplication`
with title `Calmira`. The original AppHolder additionally distinguishes queued
OnMessage filtering from a WndProc hook for sent messages. Both transport paths
are now tested, but the complete AppHolder event/property service remains unported.
Any eventual full package using this adapter must retain its FPC license and
exception notices in addition to the existing component notices.
