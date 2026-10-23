program CursorModalTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls, native_edit,
  native_application, native_form, native_modal, native_screen;
const ProbeMessage = WM_USER + 201;
type
  TDialog = class(TNativeModalForm)
  public procedure Probe(var M: TMessage); message ProbeMessage;
  end;
  TD = object
    Mode, Probes: Integer;
    procedure MainShown(Sender: TObject);
    procedure DialogShown(Sender: TObject);
  end;
var App: TNativeApplication; View: TNativeScreen; Main: TNativeForm;
  Dialog: TDialog; MainEdit, DialogEdit: TEdit; Driver: TD;
  Failed, Rejected: Boolean; Mode: Integer; Beam, WaitCursor, Cross: HCURSOR;
  SavedPosition: TPoint;
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
function CurrentCursor: HCURSOR;
begin Result := WinProcs.SetCursor(0); WinProcs.SetCursor(Result); end;
procedure PointAt(Window: HWND);
var Position: TPoint;
begin
  Position.X := 5; Position.Y := 5; ClientToScreen(Window, @Position);
  SetCursorPos(Position.X, Position.Y);
end;
procedure CursorMessage(Window: HWND; Hit: SmallInt);
begin SendMessage(Window, WM_SETCURSOR, Window, LongInt(Word(Hit)) or (LongInt(WM_MOUSEMOVE) shl 16)); end;
procedure TDialog.Probe(var M: TMessage);
begin
  Inc(Driver.Probes); PointAt(DialogEdit.Handle);
  CursorMessage(DialogEdit.Handle, HTCLIENT);
  Check(not IsWindowEnabled(Main.Handle), 'cursor modal owner disabled');
  if Driver.Mode = 2 then
    Check(CurrentCursor = Beam, 'unregistered modal retains native cursor')
  else Check(CurrentCursor = WaitCursor, 'registered modal inherits screen busy override');
  View.PushCursor(crNone); CursorMessage(DialogEdit.Handle, HTCLIENT);
  if Driver.Mode = 2 then Check(CurrentCursor = Beam, 'unregistered modal ignores none override')
  else Check(CurrentCursor = 0, 'modal nested none cursor');
  if Driver.Mode = 4 then begin PostQuitMessage(-81); Exit; end;
  View.PopCursor; View.Cursor := crDefault; CursorMessage(DialogEdit.Handle, HTCLIENT);
  Check(CurrentCursor = Beam, 'popup does not inherit owner control cursor');
  View.Cursor := crHourGlass; CursorMessage(Handle, HTCAPTION);
  Check(CurrentCursor <> WaitCursor, 'modal nonclient cursor remains native');
  PostMessage(Handle, WM_CLOSE, 0, 0);
end;
procedure TD.DialogShown(Sender: TObject);
begin
  if Mode = 3 then raise Exception.Create('cursor modal startup failure');
  PostMessage(Dialog.Handle, ProbeMessage, 0, 0);
end;
procedure TD.MainShown(Sender: TObject);
begin
  SetActiveWindow(Main.Handle); MainEdit.SetFocus; PointAt(MainEdit.Handle);
  View.Cursor := crHourGlass;
  try Dialog.ShowModal(Main.Handle);
  finally
    if View.CursorDepth > 0 then View.PopCursor;
  end;
  PointAt(MainEdit.Handle); CursorMessage(MainEdit.Handle, HTCLIENT);
  Check((CurrentCursor = WaitCursor) and (View.CursorDepth = 0) and IsWindowEnabled(Main.Handle),
    'modal exit restores outer busy state');
  View.Cursor := crDefault;
  Check(CurrentCursor = Cross, 'modal exit restores owner child cursor');
  if Mode <> 4 then PostMessage(Main.Handle, WM_CLOSE, 0, 0);
end;
procedure Setup;
begin
  FillChar(Driver, SizeOf(Driver), 0); Driver.Mode := Mode;
  App := TNativeApplication.Create(nil); App.Initialize;
  View := TNativeScreen.Create(nil); View.Application := App;
  App.CreateForm(TNativeForm, Main); Main.SetBounds(10, 10, 220, 130); Main.Cursor := crCross;
  App.CreateForm(TDialog, Dialog); Dialog.SetBounds(40, 40, 180, 90);
  MainEdit := TEdit.Create(Main); MainEdit.Parent := Main; MainEdit.SetBounds(5, 5, 150, 20); MainEdit.Cursor := crCross;
  DialogEdit := TEdit.Create(Dialog); DialogEdit.Parent := Dialog; DialogEdit.SetBounds(5, 5, 140, 20);
  Main.InitialControl := MainEdit; Dialog.InitialControl := DialogEdit;
  Main.OnShow := Driver.MainShown; Dialog.OnShow := Driver.DialogShown;
  if Mode = 2 then App.UnregisterForm(Dialog);
end;
procedure Cleanup;
begin
  View.Free; View := nil; App.Free; App := nil;
  Main := nil; Dialog := nil; MainEdit := nil; DialogEdit := nil;
end;
procedure Exercise;
begin
  for Mode := 1 to 4 do
  begin
    Setup;
    if Mode = 3 then
    begin
      Rejected := False;
      try App.Run; except on Exception do Rejected := True; end;
      Check(Rejected and not App.Running and not Dialog.ModalRunning and
        (View.Cursor = crHourGlass) and (View.CursorDepth = 0) and IsWindowEnabled(Main.Handle),
        'modal startup failure preserves outer cursor');
      Driver.Mode := 1; Main.Hide;
    end;
    if Mode = 4 then Check(App.Run = -81, 'cursor modal signed quit reaches root')
    else Check(App.Run = 0, 'cursor modal run');
    Check((Driver.Probes = 1) and (View.CursorDepth = 0) and (Dialog.CallbackErrors = 0) and
      (Main.CallbackErrors = 0), 'cursor modal acceptance'); Cleanup;
  end;
end;
begin
  FillChar(StackBottom^, 64, $A5); GetCursorPos(@SavedPosition); LogLine('STEP cursor modal');
  Beam := LoadCursor(0, IDC_IBEAM); WaitCursor := LoadCursor(0, IDC_WAIT); Cross := LoadCursor(0, IDC_CROSS);
  try Exercise;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Cleanup; SetCursorPos(SavedPosition.X, SavedPosition.Y); WinProcs.SetCursor(LoadCursor(0, IDC_ARROW));
  Check(StackGuardIntact, 'cursor modal stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
