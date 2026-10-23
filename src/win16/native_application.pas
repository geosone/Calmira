{ SPDX-License-Identifier: GPL-2.0-or-later
  Explicit task application lifecycle; not a substitute for the full Forms API.
  The application must outlive every Run/ProcessMessages call and its callbacks. }
unit native_application;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This application layer requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, native_form, native_loop, native_application_window;
type
  ENativeApplicationError = class(Exception);
  TNativeExceptionEvent = procedure(Sender: TObject; E: Exception) of object;
  TNativeHelpEvent = function(Command: Word; Data: LongInt;
    var CallHelp: Boolean): Boolean of object;
  TNativeApplication = class(TNativeFormHost)
  private
    FForms: TList;
    FLoop: TNativeMessageLoop;
    FWindow: TNativeApplicationWindow;
    FMainForm: TNativeForm;
    FTask: HTASK;
    FInitialized, FRunning, FPumping, FShuttingDown, FQuitRequested: Boolean;
    FCreatingForm, FShowMainForm: Boolean;
    FDraining: Boolean;
    FOnMessage: TNativeMessageFilter;
    FOnActivate, FOnDeactivate: TNotifyEvent;
    FOnIdle: TNativeIdleEvent;
    FOnException: TNativeExceptionEvent;
    FHandlingException: Boolean;
    FHelpFile: AnsiString;
    FOnHelp: TNativeHelpEvent;
    FHelping, FHelpOpen: Boolean;
    procedure SetHelpFile(const Value: string);
    function GetHelpFile: string;
    procedure SetOnHelp(Value: TNativeHelpEvent);
    procedure SetOnException(Value: TNativeExceptionEvent);
    procedure PresentException(E: Exception);
    procedure SetOnIdle(Value: TNativeIdleEvent);
    procedure Idle(Sender: TObject; var Done: Boolean);
    function GetActive: Boolean;
    procedure SetOnActivate(Value: TNotifyEvent);
    procedure SetOnDeactivate(Value: TNotifyEvent);
    procedure WindowActivation(Sender: TObject; Activating: Boolean);
    procedure CheckEventMutable;
    procedure CheckReady;
    procedure Start(Sender: TObject);
    function Filter(var Message: TMsg): Boolean;
    function GetFormCount: Integer;
    function GetForm(Index: Integer): TNativeForm;
    function GetTerminated: Boolean;
    function GetExitCode: SmallInt;
    procedure SetMainForm(Value: TNativeForm);
    procedure SetShowMainForm(Value: Boolean);
    function GetHandle: HWND;
    function GetTitle: string;
    function GetExeName: string;
    procedure SetTitle(const Value: string);
    procedure WindowClose(Sender: TObject);
    function GetWindowErrors: Word;
    function GetLastWindowError: string;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure FormClosed(Value: TNativeForm); override;
    function FormHelp(Value: TNativeForm; Context: LongInt): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Initialize;
    procedure CreateForm(FormClass: TNativeFormClass; var Reference);
    procedure RegisterForm(Value: TNativeForm; IsMain: Boolean = False);
    procedure UnregisterForm(Value: TNativeForm);
    function Run: SmallInt;
    function ProcessMessages(Limit: Word): Word; overload;
    procedure ProcessMessages; overload;
    function CloseMainForm: Boolean;
    procedure Terminate(Code: SmallInt = 0);
    procedure HookMainWindow(Hook: TNativeWindowHook);
    procedure UnhookMainWindow(Hook: TNativeWindowHook);
    procedure ClearWindowCallbackError;
    procedure HandleException(Sender: TObject);
    procedure ShowException(E: Exception);
    function HelpCommand(Command: Word; Data: LongInt): Boolean;
    function HelpContext(Context: LongInt): Boolean;
    function HelpJump(const Context: string): Boolean;
    property HelpFile: string read GetHelpFile write SetHelpFile;
    property OnHelp: TNativeHelpEvent read FOnHelp write SetOnHelp;
    property Handle: HWND read GetHandle;
    property Title: string read GetTitle write SetTitle;
    property ExeName: string read GetExeName;
    property WindowCallbackErrors: Word read GetWindowErrors;
    property LastWindowCallbackError: string read GetLastWindowError;
    property Initialized: Boolean read FInitialized;
    property TaskHandle: HTASK read FTask;
    property ShuttingDown: Boolean read FShuttingDown;
    property Running: Boolean read FRunning;
    property QuitRequested: Boolean read FQuitRequested;
    property Terminated: Boolean read GetTerminated;
    property ExitCode: SmallInt read GetExitCode;
    property MainForm: TNativeForm read FMainForm write SetMainForm;
    property ShowMainForm: Boolean read FShowMainForm write SetShowMainForm;
    property FormCount: Integer read GetFormCount;
    property Forms[Index: Integer]: TNativeForm read GetForm;
    property OnMessage: TNativeMessageFilter read FOnMessage write FOnMessage;
    property Active: Boolean read GetActive;
    property OnActivate: TNotifyEvent read FOnActivate write SetOnActivate;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write SetOnDeactivate;
    property OnIdle: TNativeIdleEvent read FOnIdle write SetOnIdle;
    property OnException: TNativeExceptionEvent read FOnException write SetOnException;
  end;
implementation
uses WinProcs, exception_text, help_service, help_jump, runtime_paths;
var ActiveApplication: TNativeApplication;
constructor TNativeApplication.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); FTask := GetCurrentTask; FShowMainForm := True;
  FForms := TList.Create; FLoop := TNativeMessageLoop.Create;
  FWindow := TNativeApplicationWindow.Create(nil); FWindow.OnClose := WindowClose;
  FWindow.OnActivation := WindowActivation;
  FLoop.OnStart := Start; FLoop.OnMessage := Filter;
end;
function TNativeApplication.GetHandle: HWND;
begin
  CheckReady;
  if (FQuitRequested or FLoop.Terminated) and (FWindow.Handle = 0) then
    raise ENativeApplicationError.Create('Invalid application operation');
  FWindow.EnsureHandle; Result := FWindow.Handle;
end;
function TNativeApplication.GetTitle: string;
begin Result := FWindow.Title; end;
function TNativeApplication.GetExeName: string;
begin CheckReady; Result := RuntimeExecutableName; end;
procedure TNativeApplication.SetTitle(const Value: string);
begin CheckReady; FWindow.Title := Value; end;
function TNativeApplication.GetWindowErrors: Word;
begin Result := FWindow.CallbackErrors; end;
function TNativeApplication.GetLastWindowError: string;
begin Result := FWindow.LastCallbackError; end;
procedure TNativeApplication.ClearWindowCallbackError;
begin CheckReady; FWindow.ClearCallbackError; end;
procedure TNativeApplication.HookMainWindow(Hook: TNativeWindowHook);
begin
  CheckReady; GetHandle; FWindow.HookMainWindow(Hook);
end;
procedure TNativeApplication.UnhookMainWindow(Hook: TNativeWindowHook);
begin CheckReady; FWindow.UnhookMainWindow(Hook); end;
procedure TNativeApplication.WindowClose(Sender: TObject);
begin
  if FMainForm <> nil then CloseMainForm else Terminate;
end;
procedure TNativeApplication.CheckReady;
begin
  if not FInitialized or FShuttingDown or (GetCurrentTask <> FTask) then
    raise ENativeApplicationError.Create('Invalid application operation');
end;
procedure TNativeApplication.CheckEventMutable;
begin
  CheckReady;
  if FWindow.Dispatching then raise ENativeApplicationError.Create('Invalid application operation');
end;
procedure TNativeApplication.SetOnActivate(Value: TNotifyEvent);
begin
  CheckEventMutable;
  if Assigned(Value) then GetHandle;
  FOnActivate := Value;
end;
procedure TNativeApplication.SetOnDeactivate(Value: TNotifyEvent);
begin
  CheckEventMutable;
  if Assigned(Value) then GetHandle;
  FOnDeactivate := Value;
end;
function TNativeApplication.GetActive: Boolean;
var Window: HWND;
begin
  CheckReady; Window := GetActiveWindow;
  Result := (Window <> 0) and IsWindow(Window) and (GetWindowTask(Window) = FTask);
end;
procedure TNativeApplication.SetOnIdle(Value: TNativeIdleEvent);
begin
  CheckEventMutable;
  if FLoop.Idling then raise ENativeApplicationError.Create('Invalid application operation');
  if Assigned(Value) then FLoop.OnIdle := Idle else FLoop.OnIdle := nil;
  FOnIdle := Value;
end;
procedure TNativeApplication.Idle(Sender: TObject; var Done: Boolean);
begin
  if not FShuttingDown and Assigned(FOnIdle) then FOnIdle(Self, Done);
end;
procedure TNativeApplication.SetOnException(Value: TNativeExceptionEvent);
begin
  CheckEventMutable;
  if FHandlingException then raise ENativeApplicationError.Create('Invalid application operation');
  FOnException := Value;
end;
procedure TNativeApplication.PresentException(E: Exception);
var Text, Caption: AnsiString;
begin
  { Snapshot bounded text outside DGROUP. The exception remains caller-owned. }
  Text := ExceptionDisplayText(E.Message, E.ClassName);
  Caption := Title; if Caption = '' then Caption := 'Calmira';
  MessageBox(Handle, PChar(Text), PChar(Caption), MB_OK or MB_ICONEXCLAMATION);
end;
procedure TNativeApplication.ShowException(E: Exception);
begin
  CheckReady;
  if (E = nil) or FHandlingException then
    raise ENativeApplicationError.Create('Invalid application operation');
  FHandlingException := True;
  try PresentException(E); finally FHandlingException := False; end;
end;
procedure TNativeApplication.HandleException(Sender: TObject);
var Current: TObject;
begin
  CheckReady;
  if FHandlingException then raise ENativeApplicationError.Create('Invalid application operation');
  Current := ExceptObject;
  if not (Current is Exception) then
    raise ENativeApplicationError.Create('Invalid application operation');
  if Current is EAbort then Exit;
  FHandlingException := True;
  try
    if Assigned(FOnException) then FOnException(Sender, Exception(Current))
    else PresentException(Exception(Current));
  finally FHandlingException := False; end;
end;
procedure TNativeApplication.WindowActivation(Sender: TObject; Activating: Boolean);
begin
  if FShuttingDown then Exit;
  if Activating then
  begin if Assigned(FOnActivate) then FOnActivate(Self); end
  else if Assigned(FOnDeactivate) then FOnDeactivate(Self);
end;
procedure TNativeApplication.SetHelpFile(const Value: string);
begin
  CheckReady;
  if FHelping or (Pos(#0, Value) <> 0) then
    raise ENativeApplicationError.Create('Invalid application operation');
  FHelpFile := Value;
end;
function TNativeApplication.GetHelpFile: string;
begin Result := FHelpFile; end;
procedure TNativeApplication.SetOnHelp(Value: TNativeHelpEvent);
begin
  CheckEventMutable;
  if FHelping then raise ENativeApplicationError.Create('Invalid application operation');
  FOnHelp := Value;
end;
function TNativeApplication.HelpCommand(Command: Word; Data: LongInt): Boolean;
var CallHelp: Boolean;
begin
  CheckReady;
  if FHelping then raise ENativeApplicationError.Create('Invalid application operation');
  FHelping := True;
  try
    Result := False; CallHelp := True;
    if Assigned(FOnHelp) then Result := FOnHelp(Command, Data, CallHelp);
    if CallHelp then
    begin
      Result := LaunchHelp(Handle, HelpFile, Command, Data);
      if Command = HELP_QUIT then FHelpOpen := False
      else if Result then FHelpOpen := True;
    end;
  finally FHelping := False; end;
end;
function TNativeApplication.HelpContext(Context: LongInt): Boolean;
begin Result := HelpCommand(HELP_CONTEXT, Context); end;
function TNativeApplication.HelpJump(const Context: string): Boolean;
var Macro: AnsiString;
begin
  CheckReady;
  Macro := HelpJumpMacro(FHelpFile, Context);
  Result := HelpCommand(HELP_COMMAND, LongInt(PChar(Macro)));
end;
procedure TNativeApplication.Initialize;
begin
  if FShuttingDown or (GetCurrentTask <> FTask) or
    ((ActiveApplication <> nil) and (ActiveApplication <> Self)) then
    raise ENativeApplicationError.Create('Invalid application operation');
  ActiveApplication := Self; FInitialized := True;
end;
function TNativeApplication.GetFormCount: Integer;
begin Result := FForms.Count; end;
function TNativeApplication.GetForm(Index: Integer): TNativeForm;
begin
  if (Index < 0) or (Index >= FForms.Count) then
    raise ENativeApplicationError.Create('Invalid application form');
  Result := TNativeForm(FForms[Index]);
end;
function TNativeApplication.GetTerminated: Boolean;
begin Result := FLoop.Terminated; end;
function TNativeApplication.GetExitCode: SmallInt;
begin Result := FLoop.ExitCode; end;
procedure TNativeApplication.SetMainForm(Value: TNativeForm);
begin
  CheckReady;
  if FPumping or FCreatingForm or FQuitRequested or FLoop.Terminated or
    ((Value <> nil) and (FForms.IndexOf(Value) < 0)) then
    raise ENativeApplicationError.Create('Invalid application form');
  FMainForm := Value;
end;
procedure TNativeApplication.SetShowMainForm(Value: Boolean);
begin
  CheckReady;
  if FPumping or FCreatingForm then
    raise ENativeApplicationError.Create('Invalid application operation');
  FShowMainForm := Value;
end;
procedure TNativeApplication.CreateForm(FormClass: TNativeFormClass; var Reference);
var Instance: TNativeForm; Constructed: Boolean;
begin
  CheckReady;
  if (FormClass = nil) or (TNativeForm(Reference) <> nil) or FCreatingForm or
    FQuitRequested or FLoop.Terminated or (FPumping and (FMainForm = nil)) then
    raise ENativeApplicationError.Create('Invalid application form');
  FCreatingForm := True; Constructed := False;
  try
    { Publish before the virtual constructor, as original FormCreate handlers
      may access the caller's form variable. Failed constructors free themselves. }
    Instance := TNativeForm(FormClass.NewInstance);
    TNativeForm(Reference) := Instance;
    try
      Instance.Create(Self); Constructed := True;
      FCreatingForm := False;
      RegisterForm(Instance, FMainForm = nil);
    except
      FCreatingForm := True;
      TNativeForm(Reference) := nil;
      if Constructed then Instance.Free;
      raise;
    end;
  finally FCreatingForm := False; end;
end;
procedure TNativeApplication.RegisterForm(Value: TNativeForm; IsMain: Boolean);
begin
  CheckReady;
  if (Value = nil) or FCreatingForm or FQuitRequested or FLoop.Terminated or
    (IsMain and FPumping) or ((Value.LifecycleHost <> nil) and (Value.LifecycleHost <> Self)) then
    raise ENativeApplicationError.Create('Invalid application form');
  if FForms.IndexOf(Value) < 0 then
  begin
    FForms.Add(Value);
    try AttachForm(Value); Value.FreeNotification(Self);
    except DetachForm(Value); FForms.Remove(Value); raise; end;
  end;
  if IsMain then SetMainForm(Value);
end;
procedure TNativeApplication.UnregisterForm(Value: TNativeForm);
var WasMain: Boolean;
begin
  CheckReady;
  if (Value = nil) or (FForms.IndexOf(Value) < 0) then Exit;
  WasMain := Value = FMainForm;
  if WasMain then FMainForm := nil;
  FForms.Remove(Value); Value.RemoveFreeNotification(Self); DetachForm(Value);
  if WasMain and FPumping then Terminate;
end;
procedure TNativeApplication.Notification(AComponent: TComponent; Operation: TOperation);
var WasMain: Boolean;
begin
  if (Operation = opRemove) and (FForms <> nil) then
  begin
    WasMain := AComponent = FMainForm;
    FForms.Remove(AComponent);
    if WasMain then
    begin
      FMainForm := nil;
      if FPumping and not FShuttingDown then Terminate;
    end;
  end;
  inherited Notification(AComponent, Operation);
end;
procedure TNativeApplication.FormClosed(Value: TNativeForm);
begin
  if (Value = FMainForm) and not FShuttingDown then Terminate;
end;
function TNativeApplication.FormHelp(Value: TNativeForm; Context: LongInt): Boolean;
begin
  CheckReady; Result := False;
  if FForms.IndexOf(Value) < 0 then Exit;
  if Context = 0 then HelpCommand(HELP_CONTENTS, 0) else HelpContext(Context);
  { The key is consumed even if OnHelp suppresses the request with False or
    the native backend reports failure. It must not be dispatched a second time. }
  Result := True;
end;
procedure TNativeApplication.Start(Sender: TObject);
begin
  if FQuitRequested then Exit;
  if FMainForm = nil then raise ENativeApplicationError.Create('Missing main form');
  if FShowMainForm then FMainForm.Show;
end;
function TNativeApplication.Filter(var Message: TMsg): Boolean;
var Index: Integer; Form: TNativeForm;
begin
  Result := False;
  if Assigned(FOnMessage) then
    if FOnMessage(Message) then begin Result := True; Exit; end;
  { Locate first, invoke once, then return: an activation callback may remove
    other registered forms. Never continue iterating through a changed list. }
  for Index := 0 to FForms.Count - 1 do
  begin
    Form := TNativeForm(FForms[Index]);
    if Form.FindControl(Message.hwnd) <> nil then
    begin Result := Form.ProcessDialogMessage(Message); Exit; end;
  end;
end;
function TNativeApplication.Run: SmallInt;
begin
  CheckReady;
  if FPumping or FCreatingForm or FWindow.Dispatching or FHandlingException or FHelping then raise ENativeApplicationError.Create('Application pump already running');
  if not FLoop.Terminated and not FQuitRequested and (FMainForm = nil) then
    raise ENativeApplicationError.Create('Missing main form');
  FPumping := True; FRunning := True;
  try Result := FLoop.Run;
  finally FRunning := False; FPumping := False; end;
end;
procedure TNativeApplication.ProcessMessages;
var WasPumping: Boolean;
begin
  CheckReady;
  if FDraining or FCreatingForm or FWindow.Dispatching or FHandlingException or
    FHelping or FLoop.Idling or (FPumping and not FRunning) then
    raise ENativeApplicationError.Create('Application pump already running');
  WasPumping := FPumping; FPumping := True; FDraining := True;
  try FLoop.DrainMessages;
  finally FDraining := False; FPumping := WasPumping; end;
end;
function TNativeApplication.ProcessMessages(Limit: Word): Word;
begin
  CheckReady;
  if FPumping or FCreatingForm or FWindow.Dispatching or FHandlingException or FHelping then raise ENativeApplicationError.Create('Application pump already running');
  FPumping := True;
  try Result := FLoop.ProcessMessages(Limit);
  finally FPumping := False; end;
end;
function TNativeApplication.CloseMainForm: Boolean;
begin
  CheckReady;
  Result := False;
  if FMainForm <> nil then Result := FMainForm.TryClose;
end;
procedure TNativeApplication.Terminate(Code: SmallInt);
begin
  CheckReady;
  if FQuitRequested or FLoop.Terminated then Exit;
  FQuitRequested := True; PostQuitMessage(Code);
end;
destructor TNativeApplication.Destroy;
var Form: TNativeForm;
begin
  FShuttingDown := True;
  { Native requests belong to this HWND; teardown must not invoke user handlers,
    allocate a transport or display a missing-file/shutdown error. }
  if FHelpOpen and (FWindow <> nil) and (FWindow.Handle <> 0) then
    WinHelp(FWindow.Handle, PChar(FHelpFile), HELP_QUIT, 0);
  FWindow.Free; FWindow := nil;
  if ActiveApplication = Self then ActiveApplication := nil;
  if FForms <> nil then
    while FForms.Count <> 0 do
    begin
      Form := TNativeForm(FForms.Last); FForms.Delete(FForms.Count - 1);
      Form.RemoveFreeNotification(Self); DetachForm(Form);
    end;
  FMainForm := nil; FOnMessage := nil; FOnActivate := nil; FOnDeactivate := nil;
  FOnIdle := nil;
  FOnException := nil;
  FOnHelp := nil;
  FForms.Free; FForms := nil;
  if FLoop <> nil then begin FLoop.OnStart := nil; FLoop.OnMessage := nil; FLoop.OnIdle := nil; end;
  FLoop.Free; FLoop := nil; inherited Destroy;
end;
end.
