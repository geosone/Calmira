program TestWin16Modal;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Controls,
  native_button, native_form, native_modal, native_loop, native_window;
const Act = WM_USER + 121; BeginModal = WM_USER + 122; Sentinel = WM_USER + 123;
type
  TModalProbe = class(TNativeModalForm)
  public
    Mode, Queries, Hides, Clicks, Rejections: Integer;
    OwnerBlocked, OwnerLinked, FailShow, FailHide, Veto, VetoClick, DestroyClose: Boolean;
    Button: TButton;
    Child: TModalProbe;
    OuterLoop: TNativeMessageLoop;
    ChildResult: TModalResult;
    ChildRestored: Boolean;
    constructor Create(AOwner: TComponent); override;
    procedure Action(var M: TMessage); message Act;
    procedure Clicked(Sender: TObject);
    procedure FocusReentry(Sender: TObject);
    function KeepRunning: Boolean;
  protected
    procedure DoShow; override;
    procedure DoHide; override;
    function CloseQuery: Boolean; override;
    procedure DoClose(var A: native_form.TNativeCloseAction); override;
  end;
  TDriver = class(TCustomControl)
  public
    Dialog: TModalProbe;
    Loop: TNativeMessageLoop;
    Returned: TModalResult;
    Sentinels: Integer;
    procedure BeginProbe(var M: TMessage); message BeginModal;
    procedure Seen(var M: TMessage); message Sentinel;
  end;
var Owner, Host: TDriver; Focus: TCustomControl; Form, Child: TModalProbe;
  Loop, Successor: TNativeMessageLoop; Failed, Rejected: Boolean;
  I, PoolUser, Before: Integer; ResultCode: TModalResult;
procedure LogLine(const Text: string);
var F: HFILE; Line: string; Data: array[0..255] of Char;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Data, Line);
  _lwrite(F, @Data, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
constructor TModalProbe.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); SetBounds(20, 20, 170, 100);
  Button := TButton.Create(Self); Button.Parent := Self;
  Button.SetBounds(8, 8, 75, 23); Button.ModalResult := mrOK;
  Button.Default := True; Button.OnClick := Clicked;
end;
procedure TModalProbe.DoShow;
var NativeOwner: HWND;
begin
  inherited DoShow; NativeOwner := GetParent(Handle);
  OwnerBlocked := (NativeOwner <> 0) and not IsWindowEnabled(NativeOwner);
  OwnerLinked := NativeOwner <> 0;
  if FailShow then raise Exception.Create('probe failure');
  if Mode = 10 then
    try Child.ShowModal(Handle); except on ENativeWindowError do Inc(Rejections); end;
  if Mode = 11 then begin ModalResult := mrYes; Exit; end;
  if (Mode = 8) or (Mode = 9) then
  begin
    if Mode = 8 then PostMessage(Button.Handle, WM_KEYDOWN, VK_RETURN, 1)
    else PostMessage(Button.Handle, WM_KEYDOWN, VK_ESCAPE, 1);
  end
  else PostMessage(Handle, Act, 0, 0);
end;
procedure TModalProbe.DoHide;
begin
  Inc(Hides); inherited DoHide;
  if FailHide then raise Exception.Create('probe failure');
end;
function TModalProbe.CloseQuery: Boolean;
begin
  Inc(Queries); Result := not Veto;
  if Veto then begin Veto := False; PostMessage(Handle, Act, 0, 0); end;
end;
procedure TModalProbe.DoClose(var A: native_form.TNativeCloseAction);
begin inherited DoClose(A); if DestroyClose then A := native_form.ncaDestroy; end;
procedure TModalProbe.Clicked(Sender: TObject);
begin
  if ModalResult <> Button.ModalResult then raise Exception.Create('result ordering');
  Inc(Clicks);
  if VetoClick then
  begin VetoClick := False; ModalResult := mrNone; PostMessage(Handle, Act, 0, 0); end;
end;
procedure TModalProbe.FocusReentry(Sender: TObject);
begin
  if ModalRunning then
    try ShowModal(Host.Handle); except on ENativeWindowError do Inc(Rejections); end;
end;
function TModalProbe.KeepRunning: Boolean;
begin Result := True; end;
procedure TModalProbe.Action(var M: TMessage);
begin
  case Mode of
    0, 10: ModalResult := mrOK;
    1: Close;
    2: Hide;
    3: DestroyHandle;
    4: Button.Click;
    5: begin
      ChildResult := Child.ShowModal(Handle);
      ChildRestored := IsWindowEnabled(Handle) and not IsWindowEnabled(Host.Handle);
      ModalResult := mrOK;
    end;
    6: PostQuitMessage(-19);
    7: begin
      try ShowModal(Host.Handle); except on ENativeWindowError do Inc(Rejections); end;
      try OuterLoop.ProcessMessages(1); except on ENativeLoopError do Inc(Rejections); end;
      try OuterLoop.RunModal(KeepRunning); except on ENativeLoopError do Inc(Rejections); end;
      ModalResult := mrOK;
    end;
  end;
end;
procedure TDriver.BeginProbe(var M: TMessage);
begin
  Returned := Dialog.ShowModal(Handle);
  if not Loop.Terminated then PostQuitMessage(0)
  else PostMessage(Handle, Sentinel, 0, 0);
end;
procedure TDriver.Seen(var M: TMessage);
begin Inc(Sentinels); end;
begin
  LogLine('STEP modal lifecycle');
  try
    Owner := TDriver.Create(nil); Host := Owner;
    Owner.CreateHandle(0, 'Owner', WS_OVERLAPPEDWINDOW or WS_VISIBLE,
      0, 0, 220, 140);
    Focus := TCustomControl.Create(Owner); Focus.SetBounds(5, 5, 40, 20); Focus.Parent := Owner;
    SetActiveWindow(Owner.Handle); Focus.SetFocus;
    Form := TModalProbe.Create(nil); Child := TModalProbe.Create(nil); Form.Child := Child;
    ResultCode := Form.ShowModal(Owner.Handle);
    Check((ResultCode = mrOK) and Form.OwnerBlocked and Form.OwnerLinked and
      IsWindowEnabled(Owner.Handle) and (GetFocus = Focus.Handle), 'owner and focus restored');
    Check(not Form.Visible and not Form.ModalRunning and (Form.Queries = 1) and
      (Form.Hides = 1) and (GetParent(Form.Handle) = 0), 'result closes via lifecycle');
    Focus.OnEnter := Form.FocusReentry; Before := Form.Rejections;
    Check((Form.ShowModal(Owner.Handle) = mrOK) and (Form.Rejections = Before + 1),
      'focus cleanup rejects reentry');
    Focus.OnEnter := nil;
    SetActiveWindow(Owner.Handle);
    Check((Form.ShowModal = mrOK) and Form.OwnerBlocked, 'active owner inferred');
    Before := Form.Queries; Form.Mode := 1;
    Check((Form.ShowModal(Owner.Handle) = mrCancel) and (Form.Queries = Before + 1), 'direct close queried once');
    Form.Mode := 2; Before := Form.Queries;
    Check((Form.ShowModal(Owner.Handle) = mrCancel) and (Form.Queries = Before), 'hide cancels directly');
    Form.Mode := 3;
    Check((Form.ShowModal(Owner.Handle) = mrCancel) and (Form.Handle = 0), 'native destroy cancels');
    Form.Mode := 4; Before := Form.Clicks;
    Check((Form.ShowModal(Owner.Handle) = mrOK) and (Form.Clicks = Before + 1), 'button result before event');
    Form.VetoClick := True; Before := Form.Clicks;
    Check((Form.ShowModal(Owner.Handle) = mrOK) and (Form.Clicks = Before + 2), 'click can clear result');
    Form.Mode := 0; Form.Veto := True; Before := Form.Queries;
    Check((Form.ShowModal(Owner.Handle) = mrOK) and (Form.Queries = Before + 2), 'close query can veto result');
    Form.DestroyClose := True;
    Check((Form.ShowModal(Owner.Handle) = mrOK) and (Form.Handle = 0), 'close action destroys HWND');
    Form.DestroyClose := False; EnableWindow(Owner.Handle, False);
    Check((Form.ShowModal(Owner.Handle) = mrOK) and not IsWindowEnabled(Owner.Handle), 'disabled owner stays disabled');
    EnableWindow(Owner.Handle, True); Form.FailShow := True; Rejected := False;
    try Form.ShowModal(Owner.Handle); except on Exception do Rejected := True; end;
    Form.FailShow := False;
    Check(Rejected and IsWindowEnabled(Owner.Handle) and not Form.ModalRunning and
      not Form.Visible, 'show failure restores owner');
    Form.FailHide := True; Rejected := False;
    try Form.ShowModal(Owner.Handle); except on Exception do Rejected := True; end;
    Form.FailHide := False;
    Check(Rejected and IsWindowEnabled(Owner.Handle) and not Form.ModalRunning,
      'hide failure releases modal pump');
    Check(Form.ShowModal(Owner.Handle) = mrOK, 'modal recovery after errors');
    Form.Mode := 8;
    Check(Form.ShowModal(Owner.Handle) = mrOK, 'queued Enter accepts');
    Form.Mode := 9; Form.Button.Cancel := True; Form.Button.ModalResult := mrCancel;
    Check(Form.ShowModal(Owner.Handle) = mrCancel, 'queued Escape cancels');
    Form.Button.ModalResult := mrOK;
    Form.Mode := 10; Before := Form.Rejections;
    Check((Form.ShowModal(Owner.Handle) = mrOK) and (Form.Rejections = Before + 1),
      'lifecycle nesting rejected');
    Form.Mode := 11;
    Check(Form.ShowModal(Owner.Handle) = mrYes, 'show event result accepted');
    Form.Mode := 5; Child.Mode := 0;
    Check((Form.ShowModal(Owner.Handle) = mrOK) and (Form.ChildResult = mrOK) and
      Form.ChildRestored and Child.OwnerBlocked, 'nested modal owner stack');
    Form.Mode := 7; Before := Form.Rejections;
    Loop := TNativeMessageLoop.Create; Form.OuterLoop := Loop;
    Owner.Dialog := Form; Owner.Loop := Loop; PostMessage(Owner.Handle, BeginModal, 0, 0);
    Check((Loop.Run = 0) and (Owner.Returned = mrOK) and (Form.Rejections = Before + 3),
      'only explicit modal nesting allowed');
    Loop.Free; Loop := TNativeMessageLoop.Create; Owner.Loop := Loop;
    Form.Mode := 5; Child.Mode := 6; PostMessage(Owner.Handle, BeginModal, 0, 0);
    Check((Loop.Run = -19) and Loop.Terminated and (Owner.Returned = mrCancel) and
      (Form.ChildResult = mrCancel) and Form.TaskQuit and Child.TaskQuit and
      (Form.TaskExitCode = -19) and IsWindowEnabled(Owner.Handle), 'quit unwinds every pump once');
    Check(Owner.Sentinels = 0, 'quit leaves later messages queued');
    Successor := TNativeMessageLoop.Create; Successor.ProcessMessages(100);
    Check((Owner.Sentinels = 1) and not Successor.Terminated, 'quit not reposted to successor');
    Form.Mode := 6;
    Check((Form.ShowModal(Owner.Handle) = mrCancel) and Form.TaskQuit and
      (Form.TaskExitCode = -19), 'standalone quit reported');
    Form.Mode := 0; PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 40 do Form.ShowModal(Owner.Handle);
    Check(not Form.TaskQuit and (Form.TaskExitCode = 0) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2), 'modal resource stability');
    Rejected := False;
    try Form.ShowModal(Focus.Handle); except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and IsWindowEnabled(Owner.Handle) and not Form.ModalRunning,
      'child owner rejected safely');
    Check((Form.CallbackErrors = 0) and (Child.CallbackErrors = 0) and
      (Owner.CallbackErrors = 0), 'no callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Form.Free; Child.Free; Owner.Free; Loop.Free; Successor.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
