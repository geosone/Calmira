program ApplicationOriginalTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls, Incsrch,
  native_application, native_form;
type TD = object
  Shows, ModalRuns, SearchCalls, Mode: Integer;
  Last: string[15];
  procedure MainShown(Sender: TObject);
  procedure DialogShown(Sender: TObject);
  procedure Search(Sender: TObject; const Text: string);
end;
var App: TNativeApplication; Main: TNativeForm; Dialog: TIncSearchDlg; Driver: TD;
  Failed: Boolean; Queue: TMsg;
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
procedure TD.DialogShown(Sender: TObject);
begin
  Dialog.FormShow(Sender);
  Check((Sender = Dialog) and not IsWindowEnabled(Main.Handle), 'modal owner disabled');
  if Mode = 1 then PostMessage(Dialog.Edit.Handle, WM_CHAR, Ord('w'), 1)
  else PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, VK_ESCAPE, 1);
end;
procedure TD.Search(Sender: TObject; const Text: string);
begin
  Inc(SearchCalls); Last := Text;
  Check(Sender = Dialog, 'original search sender');
  if Text = 'qw' then PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, VK_RETURN, 1);
end;
procedure TD.MainShown(Sender: TObject);
begin
  Inc(Shows);
  { Exercise the original generated constructor while the root pump is active. }
  App.CreateForm(TIncSearchDlg, Dialog);
  Check((App.FormCount = 2) and (App.MainForm = Main) and
    (Dialog.Owner = App) and (Dialog.LifecycleHost = App), 'original factory ownership');
  Check((Dialog.Edit <> nil) and (Dialog.Label1 <> nil) and
    (Dialog.Edit.Handle = 0), 'original DFM lazy controls');
  Dialog.OnShow := DialogShown; Dialog.OnSearch := Search;
  Dialog.InitialChar := 'Q'; Mode := 1;
  if Dialog.ShowModal(Main.Handle) = mrCancel then Inc(ModalRuns);
  Check((Last = 'qw') and (SearchCalls = 2), 'original search and Enter');
  Check(IsWindowEnabled(Main.Handle) and not App.QuitRequested, 'secondary keeps task alive');
  Dialog.DestroyHandle; Dialog.InitialChar := #0; Mode := 2;
  if Dialog.ShowModal(Main.Handle) = mrCancel then Inc(ModalRuns);
  Check((Last = '') and (SearchCalls = 3) and IsWindowEnabled(Main.Handle), 'recreated search and Escape');
  PostMessage(Main.Handle, WM_CLOSE, 0, 0);
end;
procedure Exercise;
begin
  FillChar(Driver, SizeOf(Driver), 0);
  try
    App := TNativeApplication.Create(nil); App.Initialize;
    App.CreateForm(TNativeForm, Main); Main.Caption := 'Factory';
    Main.SetBounds(10, 10, 230, 120); Main.OnShow := Driver.MainShown;
    Check(App.Run = 0, 'native run');
    Check((Driver.Shows = 1) and (Driver.ModalRuns = 2) and not Dialog.ModalRunning and
      (Dialog.CallbackErrors = 0) and (Dialog.Edit.CallbackErrors = 0), 'original search accepted');
    Dialog.Free; Dialog := nil;
    Check((App.FormCount = 1) and (App.MainForm = Main), 'secondary unregisters');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  if App <> nil then
    if App.QuitRequested and not App.Terminated then App.ProcessMessages(500);
  App.Free; App := nil; Main := nil; Dialog := nil;
  Check(not PeekMessage(Queue, 0, WM_QUIT, WM_QUIT, PM_NOREMOVE), 'no residual quit');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP original factory');
  Exercise;
  Check(StackGuardIntact, 'stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
