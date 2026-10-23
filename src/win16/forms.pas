{ SPDX-License-Identifier: GPL-2.0-or-later
  Initial Forms compatibility layer over the tested native application, screen
  and modal-form foundations. It supplies the global Application/Screen pair,
  typed TForm access and deferred Release; it is not the complete Delphi Forms
  unit. caMinimize, runtime DFM streaming, menus, hints, Icon and form styles
  are absent and must fail to compile rather than be silently aliased. }
unit Forms;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Forms layer requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Messages, Controls, native_form, native_modal,
  native_application, native_screen;
type
  EFormsError = class(Exception);
  TCloseAction = TNativeCloseAction;
  TCloseEvent = TNativeCloseEvent;
  TCloseQueryEvent = TNativeCloseQueryEvent;
  TWindowState = native_form.TWindowState;
  TForm = class(TNativeModalForm)
  protected
    procedure DoClose(var Action: TCloseAction); override;
  public
    { Deferred free through the application window, never inside this form's
      own dispatch. The caller must not touch the form after the next pump. }
    procedure Release;
  end;
  TFormClass = class of TForm;
  TApplication = class(TNativeApplication)
  private
    FReleases: TList;
    FReleaseHooked: Boolean;
    function ReleaseHook(var Message: TMessage): Boolean;
    procedure FreeReleases;
    function GetMainForm: TForm;
    procedure SetMainForm(Value: TForm);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure QueueRelease(Form: TForm);
    property MainForm: TForm read GetMainForm write SetMainForm;
    property PendingReleases: TList read FReleases;
  end;
  TScreen = class(TNativeScreen)
  private
    function GetForm(Index: Integer): TForm;
    function GetActiveForm: TForm;
  public
    { Registered forms that are not TForm descendants are rejected, not cast. }
    property Forms[Index: Integer]: TForm read GetForm;
    { A foreign active native form reads as nil, as no TForm is active. }
    property ActiveForm: TForm read GetActiveForm;
  end;
const
  caNone = ncaNone; caHide = ncaHide; caFree = ncaDestroy;
var
  Application: TApplication;
  Screen: TScreen;
implementation
uses WinProcs;
var ReleaseMessage: Word;
procedure TForm.DoClose(var Action: TCloseAction);
begin
  inherited DoClose(Action);
  { Delphi's caFree hides now and frees later; the native destroy-handle
    action would keep a dead model object instead. }
  if Action = caFree then begin Action := caHide; Release; end;
end;
procedure TForm.Release;
begin
  if Application = nil then raise EFormsError.Create('Invalid form release');
  Application.QueueRelease(Self);
end;
constructor TApplication.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); FReleases := TList.Create;
end;
procedure TApplication.QueueRelease(Form: TForm);
begin
  if (Form = nil) or ShuttingDown then raise EFormsError.Create('Invalid form release');
  if FReleases.IndexOf(Form) >= 0 then Exit;
  if not FReleaseHooked then begin HookMainWindow(ReleaseHook); FReleaseHooked := True; end;
  FReleases.Add(Form);
  try
    Form.FreeNotification(Self);
    if not PostMessage(Handle, ReleaseMessage, 0, 0) then
      raise EFormsError.Create('Cannot queue form release');
  except FReleases.Remove(Form); raise; end;
end;
procedure TApplication.FreeReleases;
var Form: TForm;
begin
  { Notification removes each entry as its form is freed; take the last one
    first so a destructor that releases another form cannot skip an entry. }
  while FReleases.Count <> 0 do
  begin
    Form := TForm(FReleases.Last); FReleases.Delete(FReleases.Count - 1);
    Form.RemoveFreeNotification(Self); Form.Free;
  end;
end;
function TApplication.ReleaseHook(var Message: TMessage): Boolean;
begin
  Result := Message.Msg = ReleaseMessage;
  if Result then begin Message.Result := 0; FreeReleases; end;
end;
procedure TApplication.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if (Operation = opRemove) and (FReleases <> nil) then FReleases.Remove(AComponent);
  inherited Notification(AComponent, Operation);
end;
function TApplication.GetMainForm: TForm;
begin Result := TNativeApplication(Self).MainForm as TForm; end;
procedure TApplication.SetMainForm(Value: TForm);
begin TNativeApplication(Self).MainForm := Value; end;
destructor TApplication.Destroy;
begin
  { Pending releases are freed before the owned forms, so unowned released
    forms do not leak when the queued message is never dispatched. }
  if FReleases <> nil then FreeReleases;
  if FReleaseHooked and Initialized and not ShuttingDown then
    UnhookMainWindow(ReleaseHook);
  FReleaseHooked := False;
  FReleases.Free; FReleases := nil;
  inherited Destroy;
end;
function TScreen.GetForm(Index: Integer): TForm;
var Form: TNativeForm;
begin
  Form := TNativeScreen(Self).Forms[Index];
  if not (Form is TForm) then raise ENativeScreenError.Create('Invalid screen form');
  Result := TForm(Form);
end;
function TScreen.GetActiveForm: TForm;
var Form: TNativeForm;
begin
  Form := TNativeScreen(Self).ActiveForm; Result := nil;
  if Form is TForm then Result := TForm(Form);
end;
initialization
  ReleaseMessage := RegisterWindowMessage('CalmiraFormRelease');
  Application := TApplication.Create(nil); Application.Initialize;
  Screen := TScreen.Create(nil); Screen.Application := Application;
finalization
  Application.Free; Application := nil;
  Screen.Free; Screen := nil;
end.
