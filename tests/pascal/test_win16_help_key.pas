program HelpKeyTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Graphics, Controls,
  native_application, native_form, native_modal, native_edit;
const DoneMessage = WM_USER + 273;
type
  TContextForm = class(TNativeModalForm)
  public
    Edit, Inner: TEdit; Panel: TCustomControl;
    constructor Create(AOwner: TComponent); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Done(var M: TMessage); message DoneMessage;
  end;
  TGrabber = class(TCustomControl)
  public
    WantAll: Boolean;
    procedure WndProc(var M: TMessage); override;
  end;
  TD = object
    Calls, Keys: Integer; Command: Word; Data: LongInt;
    Consume, RaiseError, Detach, Remove: Boolean;
    function Help(C: Word; D: LongInt; var CallHelp: Boolean): Boolean;
    function Filter(var M: TMsg): Boolean;
    procedure Key(Sender: TObject; var Code: Word; Shift: TShiftState);
    procedure Shown(Sender: TObject);
  end;
var App: TNativeApplication; Main: TNativeForm; Frame: TContextForm;
  Grab: TGrabber; Driver: TD; Failed, Rejected: Boolean;
  Before, Keys, I: Integer; M: TMsg; Saved, Modified: TKeyboardState;
  HelpWindow: HWND;
{$I win16_stack_guard.inc}
{$I help_context_form.inc}
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
procedure TGrabber.WndProc(var M: TMessage);
begin
  if (M.Msg = WM_GETDLGCODE) and WantAll then begin M.Result := DLGC_WANTALLKEYS; Exit; end;
  inherited WndProc(M);
end;
function TD.Help(C: Word; D: LongInt; var CallHelp: Boolean): Boolean;
begin
  Inc(Calls); Command := C; Data := D; CallHelp := False; Result := False;
  if RaiseError then raise Exception.Create('F1 handler failure');
  if Detach then App.UnregisterForm(Frame);
  if Remove then begin Frame.Free; Frame := nil; Grab := nil; end;
end;
function TD.Filter(var M: TMsg): Boolean;
begin Result := Consume and (M.message = WM_KEYDOWN) and (M.wParam = VK_F1); end;
procedure TD.Key(Sender: TObject; var Code: Word; Shift: TShiftState);
begin if Code = VK_F1 then Inc(Keys); end;
procedure TD.Shown(Sender: TObject);
begin
  PostMessage(Frame.Inner.Handle, WM_KEYDOWN, VK_F1, 1);
  if not RaiseError then PostMessage(Frame.Handle, DoneMessage, 0, 0);
end;
procedure TContextForm.Done(var M: TMessage);
begin
  Check(ModalRunning and not IsWindowEnabled(Main.Handle) and Inner.Focused and
    (Driver.Command = HELP_CONTEXT) and (Driver.Data = 65536), 'modal F1 uses registered host and nearest parent context');
  ModalResult := mrOK;
end;
procedure Focus(Control: TCustomControl);
begin SetActiveWindow(Frame.Handle); Control.SetFocus; end;
procedure Press(Control: TCustomControl);
begin
  Focus(Control); PostMessage(Control.Handle, WM_KEYDOWN, VK_F1, 1); App.ProcessMessages(500);
end;
procedure Pump(Milliseconds: DWORD);
var Started: DWORD;
begin
  Started := WinProcs.GetTickCount;
  repeat App.ProcessMessages(500); WinProcs.Yield;
  until WinProcs.GetTickCount - Started >= Milliseconds;
end;
function FindHelp: HWND;
var W: HWND; Caption: array[0..255] of Char;
begin
  Result := 0; W := GetWindow(GetDesktopWindow, GW_CHILD);
  while W <> 0 do
  begin
    GetWindowText(W, Caption, SizeOf(Caption));
    if IsWindowVisible(W) and (GetWindowTask(W) <> GetCurrentTask) and
      (Pos('Calmira Reloaded', StrPas(Caption)) <> 0) then begin Result := W; Exit; end;
    W := GetWindow(W, GW_HWNDNEXT);
  end;
end;
procedure BasicCases;
begin
  App := TNativeApplication.Create(nil); App.Initialize;
  App.CreateForm(TNativeForm, Main); Main.SetBounds(5, 5, 150, 100);
  App.CreateForm(TContextForm, Frame); App.OnHelp := Driver.Help; App.OnMessage := Driver.Filter;
  Check((Frame.HelpContext = 900) and (Frame.Edit.HelpContext = 901) and
    (Frame.Inner.ResolveHelpContext = 65536) and (Frame.Handle = 0) and
    (Frame.Inner.Handle = 0), 'binary DFM loads 32-bit help contexts without HWNDs');
  Rejected := False;
  try Frame.Edit.HelpContext := -1; except on Exception do Rejected := True; end;
  Check(Rejected and (Frame.Edit.HelpContext = 901), 'negative metadata preserves previous context');
  Grab := TGrabber.Create(Frame); Grab.Parent := Frame; Grab.SetBounds(170, 10, 50, 25);
  Grab.HelpContext := 902; Grab.OnKeyDown := Driver.Key;
  Frame.Edit.OnKeyDown := Driver.Key; Frame.Inner.OnKeyDown := Driver.Key;
  Main.Show; Frame.Show; Press(Frame.Edit);
  Check((Driver.Calls = 1) and (Driver.Data = 901) and (Driver.Keys = 0), 'F1 is consumed even when OnHelp returns false');
  Frame.Edit.HelpContext := 0; Press(Frame.Edit);
  Check(Driver.Data = 900, 'zero child context inherits form');
  Press(Frame.Inner); Check(Driver.Data = 65536, 'nearest container context is not narrowed');
  Frame.Panel.HelpContext := 0; Press(Frame.Inner); Check(Driver.Data = 900, 'parent context change is live');
  Frame.HelpContext := 0; Press(Frame.Inner);
  Check((Driver.Command = HELP_CONTENTS) and (Driver.Data = 0), 'all-zero chain opens help contents');
  Frame.Panel.HelpContext := 2147483647; Frame.Edit.Parent := Frame.Panel; Press(Frame.Edit);
  Check(Driver.Data = 2147483647, 'reparented context lookup preserves full LongInt');
  Frame.Edit.Parent := Frame; Frame.HelpContext := 900; Frame.Panel.HelpContext := 65536;
  Driver.Consume := True; Before := Driver.Calls; Press(Frame.Edit); Driver.Consume := False;
  Check(Driver.Calls = Before, 'application queue filter precedes F1');
  Grab.WantAll := True; Keys := Driver.Keys; Press(Grab);
  Check((Driver.Calls = Before) and (Driver.Keys = Keys + 1), 'DLGC_WANTALLKEYS keeps F1 in the native control');
  Grab.WantAll := False; Press(Grab); Check(Driver.Data = 902, 'ordinary control F1 routes to host');
end;
procedure Eligibility;
begin
  Focus(Frame.Edit); FillChar(M, SizeOf(M), 0); M.hwnd := Frame.Edit.Handle;
  M.message := WM_KEYDOWN; M.wParam := VK_F1; M.lParam := 1; Before := Driver.Calls;
  GetKeyboardState(Saved);
  try
    for I := 0 to 2 do
    begin
      Modified := Saved;
      case I of 0: Modified[VK_SHIFT] := #128; 1: Modified[VK_CONTROL] := #128; 2: Modified[VK_MENU] := #128; end;
      SetKeyboardState(Modified);
      Check(not Frame.ProcessDialogMessage(M), 'modified F1 stays outside help routing');
    end;
  finally SetKeyboardState(Saved); end;
  M.lParam := $40000001; Check(not Frame.ProcessDialogMessage(M), 'autorepeated F1 does not reopen help');
  M.lParam := $20000001; Check(not Frame.ProcessDialogMessage(M), 'Alt context bit rejects plain F1 route');
  M.lParam := 1; M.message := WM_SYSKEYDOWN; Check(not Frame.ProcessDialogMessage(M), 'system F1 is not plain F1');
  M.message := WM_KEYUP; Check(not Frame.ProcessDialogMessage(M), 'F1 keyup does not request help');
  M.message := WM_KEYDOWN; M.hwnd := Frame.Inner.Handle;
  Check(not Frame.ProcessDialogMessage(M), 'stale nonfocused target cannot request help');
  Check(Driver.Calls = Before, 'ineligible keys never invoke help');
  App.UnregisterForm(Frame); Keys := Driver.Keys; Press(Frame.Edit);
  Check((Driver.Calls = Before) and (Driver.Keys = Keys + 1), 'unregistered form retains normal F1 dispatch');
  App.RegisterForm(Frame); Driver.RaiseError := True; Rejected := False;
  try Press(Frame.Edit); except on E: Exception do Rejected := E.Message = 'F1 handler failure'; end;
  Driver.RaiseError := False; Before := Driver.Calls; Press(Frame.Edit);
  Check(Rejected and (Driver.Calls = Before + 1) and (Frame.CallbackErrors = 0), 'queued F1 error propagates and pump recovers');
  Driver.Detach := True; Press(Frame.Edit); Driver.Detach := False;
  Check((Frame.LifecycleHost = nil) and (App.FormCount = 1), 'help handler may detach current secondary form safely');
  App.RegisterForm(Frame);
end;
procedure ModalCases;
begin
  Frame.Hide; Frame.OnShow := Driver.Shown; Frame.InitialControl := Frame.Inner;
  Before := Driver.Calls;
  Check(Frame.ShowModal(Main.Handle) = mrOK, 'modal F1 completes dialog');
  Check((Driver.Calls = Before + 1) and IsWindowEnabled(Main.Handle), 'modal help called once and owner restored');
  Driver.RaiseError := True; Rejected := False;
  try Frame.ShowModal(Main.Handle); except on E: Exception do Rejected := E.Message = 'F1 handler failure'; end;
  Driver.RaiseError := False;
  Check(Rejected and not Frame.ModalRunning and IsWindowEnabled(Main.Handle), 'modal F1 error restores owner and loop');
  App.ProcessMessages(500);
  Check(Frame.ShowModal(Main.Handle) = mrOK, 'modal F1 recovers after error');
  Frame.OnShow := nil; Frame.Show;
  App.OnHelp := nil; App.HelpFile := 'C:\HELPDOCS\CALMIRA.HLP'; Frame.Edit.HelpContext := 900;
  Press(Frame.Edit); Pump(1500); HelpWindow := FindHelp;
  Check(HelpWindow <> 0, 'queued F1 really opens installed help in foreign WinHelp task');
  App.HelpCommand(HELP_QUIT, 0); Pump(500);
  Check(not IsWindow(HelpWindow) or not IsWindowVisible(HelpWindow), 'F1-opened help quits cleanly');
  App.OnHelp := Driver.Help;
  Driver.Remove := True; Press(Frame.Edit); Driver.Remove := False;
  Check((Frame = nil) and (App.FormCount = 1), 'queued help may free current secondary form without stale traversal');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native F1 help routing');
  try BasicCases; Eligibility; ModalCases;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  App.Free;
  Check(StackGuardIntact, 'F1 help stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
