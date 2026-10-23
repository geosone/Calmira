program TestWin16Minimize;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Controls, StdCtrls, Forms, apholder;
type
  TComponentAccess = class(TComponent);
  TEvents = class
    Minimized, Restored, ControlChanges, FormChanges: Integer;
    ChangesAtEnter: Integer;
    procedure AppMinimize(Sender: TObject);
    procedure AppRestore(Sender: TObject);
    procedure ControlChange(Sender: TObject);
    procedure FormChange(Sender: TObject);
    procedure EditEnter(Sender: TObject);
  end;
var Main, Other: TForm; Edit1, Edit2: TEdit; Events: TEvents; Holder: TAppHolder; Failed: Boolean;
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
procedure TEvents.AppMinimize(Sender: TObject); begin Inc(Minimized); end;
procedure TEvents.AppRestore(Sender: TObject); begin Inc(Restored); end;
procedure TEvents.ControlChange(Sender: TObject); begin Inc(ControlChanges); end;
procedure TEvents.FormChange(Sender: TObject); begin Inc(FormChanges); end;
procedure TEvents.EditEnter(Sender: TObject); begin ChangesAtEnter := ControlChanges; end;
procedure Pump(Ms: LongInt);
var Start: LongInt;
begin
  { SysUtils also declares GetTickCount. }
  Start := WinProcs.GetTickCount;
  repeat Application.ProcessMessages; Yield; until WinProcs.GetTickCount - Start >= Ms;
end;
function Shown(Form: TForm): Boolean;
begin Result := IsWindowVisible(Form.Handle); end;
begin
  LogLine('STEP minimize');
  Events := TEvents.Create;
  try
    Application.CreateForm(TForm, Main); Main.SetBounds(20, 20, 200, 120); Main.Caption := 'Main';
    { Not registered through CreateForm, like most of Calmira's windows. }
    Other := TForm.Create(Application); Other.SetBounds(250, 20, 200, 120); Other.Caption := 'Other';
    Edit1 := TEdit.Create(Main); Edit1.SetBounds(10, 10, 100, 24); Edit1.Parent := Main;
    Edit2 := TEdit.Create(Main); Edit2.SetBounds(10, 50, 100, 24); Edit2.Parent := Main;
    Application.MainForm := Main;
    Screen.OnActiveControlChange := Events.ControlChange;
    Screen.OnActiveFormChange := Events.FormChange;
    Main.Show; Other.Show; Pump(100);

    Events.FormChanges := 0;
    SetActiveWindow(Main.Handle); Pump(50);
    Check(Events.FormChanges = 1, 'activating another form calls OnActiveFormChange');
    SetActiveWindow(Main.Handle); Pump(50);
    Check(Events.FormChanges = 1, 'reactivating the same form does not');
    Edit1.OnEnter := Events.EditEnter;
    Edit2.SetFocus; Events.ControlChanges := 0;
    Edit1.SetFocus;
    Check(Events.ControlChanges = 1, 'focusing a control calls OnActiveControlChange');
    Check(Events.ChangesAtEnter = 1, 'OnActiveControlChange runs before OnEnter');
    Edit1.Free; Edit1 := nil;
    Events.ControlChanges := 0;
    Edit2.SetFocus;
    Check(Events.ControlChanges = 1, 'focus after the focused control is freed is reported');

    Application.OnMinimize := Events.AppMinimize;
    Application.OnRestore := Events.AppRestore;
    Application.Minimize;
    Check(IsIconic(Application.Handle) and IsWindowVisible(Application.Handle),
      'Minimize shows the application as an icon');
    Check(not Shown(Main) and not Shown(Other), 'Minimize hides the forms');
    Check(Events.Minimized = 1, 'Minimize calls OnMinimize');
    Application.Minimize;
    Check(Events.Minimized = 1, 'a second Minimize does nothing');
    Check(SendMessage(Application.Handle, WM_QUERYDRAGICON, 0, 0) <> 0, 'the icon answers WM_QUERYDRAGICON');
    SendMessage(Application.Handle, WM_SYSCOMMAND, SC_RESTORE, 0);
    Check(Shown(Main) and Shown(Other) and not IsWindowVisible(Application.Handle),
      'restoring the icon shows the forms and hides the application window');
    Check(Events.Restored = 1, 'Restore calls OnRestore');
    Application.Restore;
    Check(Events.Restored = 1, 'Restore when not minimized does nothing');

    SendMessage(Other.Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
    Check(IsIconic(Other.Handle) and Shown(Main) and (Events.Minimized = 1),
      'minimizing another form minimizes only that form');
    ShowWindow(Other.Handle, SW_RESTORE);
    SendMessage(Main.Handle, WM_SYSCOMMAND, SC_MINIMIZE, 0);
    Check((Events.Minimized = 2) and not Shown(Main) and not Shown(Other) and IsIconic(Application.Handle),
      'minimizing the main form minimizes the application');
    Other.Free; Other := nil;
    PostMessage(Application.Handle, WM_SYSCOMMAND, SC_RESTORE, 0); Pump(100);
    Check(Shown(Main) and (Events.Restored = 2), 'a form freed while minimized is skipped on restore');
    Check(GetActiveWindow = Main.Handle, 'restore activates the previously active form');

    { TAppHolder assigns these through "with Application do"; they must
      reach the application, not the holder's own properties. }
    Holder := TAppHolder.Create(nil);
    Holder.OnMinimize := Events.AppMinimize;
    Holder.OnActiveFormChange := Events.FormChange;
    TComponentAccess(Holder).Loaded;
    Check(Assigned(Application.OnMinimize) and Assigned(Screen.OnActiveFormChange),
      'TAppHolder hands its events to Application and Screen');
    Holder.Free;
    Check(not Assigned(Application.OnMinimize) and not Assigned(Screen.OnActiveFormChange),
      'freeing TAppHolder clears them');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Application.WindowCallbackErrors <> 0 then
    LogLine('FAIL callback ' + Application.LastWindowCallbackError);
  Screen.OnActiveControlChange := nil; Screen.OnActiveFormChange := nil;
  Application.OnMinimize := nil; Application.OnRestore := nil;
  Other.Free; Main.Free; Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
