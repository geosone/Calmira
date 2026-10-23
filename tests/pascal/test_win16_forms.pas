program FormsTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Controls, Forms, native_form;
type
  TMainForm = class(TForm)
  protected
    procedure DoShow; override;
  end;
  TChildForm = class(TForm)
  public
    FreeMode: Boolean;
    destructor Destroy; override;
    procedure CloseHandler(Sender: TObject; var Action: TCloseAction);
    procedure ModalShow(Sender: TObject);
  end;
  TTeardownProbe = class(TComponent)
  public
    destructor Destroy; override;
  end;
var MainForm: TMainForm; Child, Modal, Loose: TChildForm; Foreign: TNativeForm;
  Freed, Rejected, Failed, ShownMain: Boolean; Count, ModalCode: Integer;
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
procedure TMainForm.DoShow;
begin
  inherited DoShow; ShownMain := True;
  PostMessage(Handle, WM_CLOSE, 0, 0);
end;
destructor TChildForm.Destroy;
begin
  Freed := True;
  if Self = Child then Child := nil;
  if Self = Modal then Modal := nil;
  if Self = Loose then Loose := nil;
  inherited Destroy;
end;
procedure TChildForm.CloseHandler(Sender: TObject; var Action: TCloseAction);
begin
  if FreeMode then Action := caFree;
end;
procedure TChildForm.ModalShow(Sender: TObject);
begin
  ModalResult := mrOk;
end;
destructor TTeardownProbe.Destroy;
begin
  { Runs from the Forms finalization, after RESULT has been written; a FAIL
    line here still fails the native runner. }
  Check(Application.ShuttingDown and (Application.PendingReleases = nil),
    'finalization frees the global application and its owned components');
  inherited Destroy;
end;
procedure Globals;
begin
  Check((Application <> nil) and Application.Initialized and
    (Application.TaskHandle = GetCurrentTask), 'global application is initialized for this task');
  Check((Screen <> nil) and (Screen.Application = Application) and (Screen.FormCount = 0),
    'global screen is bound to the application without forms');
  Check(Application.MainForm = nil, 'no implicit main form');
  Application.Initialize;
  Check(Application.Initialized, 'repeated Initialize is accepted');
  Check((caNone = ncaNone) and (caHide = ncaHide), 'close actions share native values');
end;
procedure Creation;
begin
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TChildForm, Child);
  Check((Application.MainForm = MainForm) and (MainForm.Owner = Application) and
    (Child.Owner = Application), 'CreateForm publishes typed main form and application owner');
  MainForm.SetBounds(20, 20, 200, 120); Child.SetBounds(240, 20, 200, 120);
  Check((Screen.FormCount = 2) and (Screen.Forms[0] is TMainForm) and (Screen.Forms[1] is TChildForm),
    'typed screen forms before native handles');
  Child.Show; BringWindowToTop(Child.Handle); SetActiveWindow(Child.Handle);
  Check((Screen.ActiveForm = Child) and (Screen.Forms[0] = Child), 'typed active form follows USER');
end;
procedure ForeignForms;
begin
  Foreign := TNativeForm.Create(nil);
  Application.RegisterForm(Foreign);
  Foreign.SetBounds(60, 160, 160, 100); Foreign.Show;
  BringWindowToTop(Foreign.Handle); SetActiveWindow(Foreign.Handle);
  Check(Screen.ActiveForm = nil, 'foreign active native form reads as no TForm');
  Rejected := False;
  try if Screen.Forms[0] <> nil then ; except on Exception do Rejected := True; end;
  Check(Rejected, 'foreign form index is rejected rather than cast');
  Foreign.Free; Foreign := nil;
  Check(Screen.FormCount = 2, 'freed foreign form leaves the registry');
end;
procedure CloseFree;
begin
  Child.OnClose := Child.CloseHandler; Child.FreeMode := True; Freed := False;
  BringWindowToTop(Child.Handle); SetActiveWindow(Child.Handle);
  Child.Close;
  Check((Child <> nil) and not Freed and not Child.Visible and
    (Application.PendingReleases.Count = 1), 'caFree hides now and defers the free');
  Application.ProcessMessages;
  Check(Freed and (Child = nil) and (Application.PendingReleases.Count = 0) and
    (Screen.FormCount = 1), 'queued release frees the form outside its dispatch');
end;
procedure ReleaseEdges;
begin
  Loose := TChildForm.Create(nil); Loose.SetBounds(240, 160, 160, 100); Loose.Show;
  Freed := False; Loose.Release; Loose.Release;
  Check(Application.PendingReleases.Count = 1, 'repeated Release queues one free');
  Application.ProcessMessages;
  Check(Freed and (Loose = nil), 'unowned released form is freed');
  Loose := TChildForm.Create(nil); Freed := False; Loose.Release; Loose.Free;
  Check(Freed and (Loose = nil) and (Application.PendingReleases.Count = 0),
    'explicit free cancels the pending release');
  Application.ProcessMessages;
  Check(Application.PendingReleases.Count = 0, 'stale release message is harmless');
  Rejected := False;
  try Application.QueueRelease(nil); except on EFormsError do Rejected := True; end;
  Check(Rejected, 'nil release rejected');
end;
procedure ModalFree;
begin
  Application.CreateForm(TChildForm, Modal);
  Modal.SetBounds(100, 100, 200, 120); Modal.OnShow := Modal.ModalShow;
  Modal.OnClose := Modal.CloseHandler; Modal.FreeMode := True; Freed := False;
  ModalCode := Modal.ShowModal;
  Check((ModalCode = mrOk) and not Freed and (Modal <> nil) and not Modal.Visible,
    'modal caFree returns the result before the deferred free');
  Application.ProcessMessages;
  Check(Freed and (Modal = nil) and (Screen.FormCount = 1), 'modal form freed by the next pump');
end;
procedure RunMain;
begin
  TTeardownProbe.Create(Application);
  ShownMain := False; Count := Application.Run;
  Check(ShownMain and Application.Terminated and (Count = 0) and (MainForm <> nil) and
    not MainForm.Visible, 'Run shows the main form and closing it ends the task loop');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP global Forms layer');
  try Globals; Creation; ForeignForms; CloseFree; ReleaseEdges; ModalFree; RunMain;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'forms stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
