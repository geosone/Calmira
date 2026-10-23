program ApplicationFactoryTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages,
  native_application, native_form;
const ProbeMessage = WM_USER + 171;
type
  TMarker = class(TComponent)
  public
    destructor Destroy; override;
  end;
  TFactoryFrame = class(TNativeForm)
  public
    class function NewInstance: TObject; override;
    constructor Create(AOwner: TComponent); override;
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;
  TD = object
    Shows: Integer;
    procedure MainShown(Sender: TObject);
    function Filter(var Message: TMsg): Boolean;
  end;
var App: TNativeApplication; Main, Other: TFactoryFrame;
  Slot: ^TNativeForm; Mode, Deaths, Markers, GuardCount, Afters: Integer;
  Failed, Rejected: Boolean; Driver: TD; Queue: TMsg;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
destructor TMarker.Destroy;
begin Inc(Markers); inherited Destroy; end;
class function TFactoryFrame.NewInstance: TObject;
begin
  if Mode = 4 then raise Exception.Create('allocation failure');
  Result := inherited NewInstance;
end;
constructor TFactoryFrame.Create(AOwner: TComponent);
var Nested: TNativeForm;
begin
  Check((Slot <> nil) and (Slot^ = Self), 'reference published before virtual constructor');
  if Mode = 1 then raise Exception.Create('early constructor failure');
  inherited Create(AOwner); TMarker.Create(Self);
  Check((Owner = App) and (LifecycleHost = nil), 'ownership precedes registration');
  Nested := nil;
  try App.CreateForm(TNativeForm, Nested); except on ENativeApplicationError do Inc(GuardCount); end;
  Check(Nested = nil, 'nested factory leaves reference empty');
  try App.ProcessMessages(1); except on ENativeApplicationError do Inc(GuardCount); end;
  try App.Run; except on ENativeApplicationError do Inc(GuardCount); end;
  try App.RegisterForm(Self); except on ENativeApplicationError do Inc(GuardCount); end;
  try App.ShowMainForm := False; except on ENativeApplicationError do Inc(GuardCount); end;
  if Mode = 2 then raise Exception.Create('owned constructor failure');
  if Mode = 3 then App.Terminate(-42);
  Caption := 'Factory main'; SetBounds(10, 10, 230, 120);
end;
destructor TFactoryFrame.Destroy;
begin Inc(Deaths); inherited Destroy; end;
procedure TFactoryFrame.AfterConstruction;
begin
  Inc(Afters); inherited AfterConstruction;
  if Mode = 5 then raise Exception.Create('after-construction failure');
end;
procedure TD.MainShown(Sender: TObject);
begin
  Inc(Shows);
  PostMessage(Main.Handle, WM_CLOSE, 0, 0);
end;
function TD.Filter(var Message: TMsg): Boolean;
begin
  Result := Message.message = ProbeMessage;
  if Result then
  begin
    Check((Main.Handle = 0) and not Main.Visible and (Shows = 0), 'hidden main stays uncreated during run');
    Rejected := False;
    try App.ShowMainForm := True; except on ENativeApplicationError do Rejected := True; end;
    Check(Rejected, 'show-main policy immutable during pump');
    App.Terminate(-17);
  end;
end;
procedure Cleanup;
begin
  if App <> nil then
    if App.QuitRequested and not App.Terminated then App.ProcessMessages(500);
  App.Free; App := nil; Main := nil; Other := nil; Slot := nil;
  Check(not PeekMessage(Queue, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE), 'factory leaves no task quit');
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0); Mode := 0; GuardCount := 0;
  Deaths := 0; Markers := 0; Afters := 0; Main := nil; Other := nil;
  App := TNativeApplication.Create(nil); App.Initialize; Slot := @Main;
end;
procedure Validation;
begin
  App := TNativeApplication.Create(nil); Rejected := False;
  try App.CreateForm(TFactoryFrame, Main); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and (Main = nil) and (App.ComponentCount = 0), 'factory requires initialization');
  App.Initialize; Rejected := False;
  try App.CreateForm(nil, Main); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and (Main = nil) and (App.FormCount = 0), 'nil form class rejected'); Cleanup;
  Setup; App.CreateForm(TFactoryFrame, Main);
  Check(App.ShowMainForm and (App.MainForm = Main) and (App.FormCount = 1) and
    (App.ComponentCount = 1) and (Main.Handle = 0), 'factory selects first owned main without showing');
  Rejected := False;
  try App.CreateForm(TFactoryFrame, Main); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and (App.MainForm = Main) and (App.FormCount = 1), 'live reference is never overwritten');
  Slot := @Other; App.CreateForm(TFactoryFrame, Other);
  Check((App.MainForm = Main) and (App.FormCount = 2) and (GuardCount = 10) and
    (Afters = 2), 'secondary factory and constructor guards');
  App.Free; App := nil; Main := nil; Other := nil;
  Check((Deaths = 2) and (Markers = 2), 'factory forms and children freed exactly once'); Cleanup;
end;
procedure FailureRecovery;
var FailureMode: Integer;
begin
  for FailureMode := 1 to 5 do
  begin
    Setup; Mode := FailureMode; Rejected := False;
    try App.CreateForm(TFactoryFrame, Main); except on Exception do Rejected := True; end;
    Check(Rejected and (Main = nil) and (App.MainForm = nil) and
      (App.FormCount = 0) and (App.ComponentCount = 0), 'factory failure rolls back reference registry and ownership');
    case FailureMode of
      1: Check((Deaths = 1) and (Markers = 0), 'early constructor cleanup once');
      2: Check((Deaths = 1) and (Markers = 1), 'owned constructor cleanup once');
      3:
        begin
          Check((Deaths = 1) and (Markers = 1), 'post-constructor registration failure cleanup once');
          Check(App.Run = -42, 'constructor requested quit preserved');
        end;
      4: Check((Deaths = 0) and (Markers = 0), 'allocation failure does not destroy unallocated object');
      5: Check((Deaths = 1) and (Markers = 1) and (Afters = 1), 'after-construction failure cleanup once');
    end;
    if FailureMode <> 3 then
    begin
      Mode := 0; App.CreateForm(TFactoryFrame, Main);
      Check((Main <> nil) and (App.MainForm = Main), 'factory recovers after allocation or constructor failure');
    end;
    Cleanup;
  end;
end;
procedure Running;
begin
  Setup; App.CreateForm(TFactoryFrame, Main); App.ShowMainForm := False;
  Main.OnShow := Driver.MainShown; App.OnMessage := Driver.Filter;
  PostAppMessage(GetCurrentTask, ProbeMessage, 0, 0);
  Check(App.Run = -17, 'hidden main application quit');
  Rejected := False;
  try App.CreateForm(TFactoryFrame, Other); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and (Other = nil) and (App.FormCount = 1), 'factory rejects terminated application'); Cleanup;
  Setup; App.CreateForm(TFactoryFrame, Main); Main.OnShow := Driver.MainShown;
  Check(App.Run = 0, 'factory main completes native run');
  Check(Driver.Shows = 1, 'factory main shown once'); Cleanup;
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native application factory');
  try Validation; FailureRecovery; Running;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; Check(StackGuardIntact, 'factory stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
