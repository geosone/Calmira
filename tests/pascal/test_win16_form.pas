program TestWin16Form;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Controls, native_form,
  native_loop, native_window;
type
  TObserver = class
    Shows, Hides, Queries, Closes, Rejections: Integer;
    Veto, FailQuery, FailShow, FailHide, ReenterShow, ShowState, HideState: Boolean;
    Action: TNativeCloseAction;
    procedure Shown(Sender: TObject);
    procedure Hidden(Sender: TObject);
    procedure Query(Sender: TObject; var CanClose: Boolean);
    procedure Closing(Sender: TObject; var A: TNativeCloseAction);
    procedure CloseDuringDraw(Sender: TObject);
  end;
var Failed, Rejected: Boolean; Form: TNativeForm; Child, Temporary: TCustomControl;
  Observer: TObserver; Loop: TNativeMessageLoop; Raw, ChildRaw: HWND;
  Buffer: array[0..255] of Char; I, PoolBefore: Integer;
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
procedure TObserver.Shown(Sender: TObject);
begin
  Inc(Shows); ShowState := Form.Visible and IsWindowVisible(Form.Handle) and (Child.Handle <> 0);
  if ReenterShow then
    try Form.Close; except on ENativeWindowError do Inc(Rejections); end;
  if FailShow then raise Exception.Create('show event failure');
end;
procedure TObserver.Hidden(Sender: TObject);
begin
  Inc(Hides); HideState := not Form.Visible and not IsWindowVisible(Form.Handle);
  if FailHide then raise Exception.Create('hide event failure');
end;
procedure TObserver.Query(Sender: TObject; var CanClose: Boolean);
begin
  Inc(Queries);
  if FailQuery then raise Exception.Create('close query failure');
  CanClose := not Veto;
end;
procedure TObserver.Closing(Sender: TObject; var A: TNativeCloseAction);
begin Inc(Closes); A := Action; end;
procedure TObserver.CloseDuringDraw(Sender: TObject);
begin
  try Form.Close; except on ENativeWindowError do Inc(Rejections); end;
end;
procedure QueuedClose;
begin
  if not PostMessage(Form.Handle, WM_CLOSE, 0, 0) then raise Exception.Create('Cannot post close');
  Loop.ProcessMessages(100);
end;
begin
  LogLine('STEP native modeless form lifecycle');
  try
    Form := TNativeForm.Create(nil); Child := TCustomControl.Create(nil);
    Observer := TObserver.Create; Loop := TNativeMessageLoop.Create;
    Observer.Action := ncaHide;
    Form.OnShow := Observer.Shown; Form.OnHide := Observer.Hidden;
    Form.OnCloseQuery := Observer.Query; Form.OnClose := Observer.Closing;
    Form.Caption := 'Modeless probe'; Form.SetBounds(20, 20, 180, 130);
    Child.SetBounds(8, 8, 40, 24); Child.Parent := Form;
    Form.InitialControl := Child;
    Temporary := TCustomControl.Create(nil); Rejected := False;
    try Form.InitialControl := Temporary; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Form.InitialControl = Child), 'invalid initial focus preserves reference');
    Temporary.Parent := Form; Form.InitialControl := Temporary;
    Temporary.Free; Temporary := nil;
    Check(Form.InitialControl = nil, 'initial focus weak reference clears on free');
    Form.InitialControl := Child;
    Form.Close; Form.Hide;
    Check((Form.Handle = 0) and not Form.Visible and (Observer.Queries = 0),
      'construction and detached close do not allocate a native form');
    Rejected := False;
    try Form.CreateControl(0); except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Form.Handle = 0), 'form rejects accidental native child creation');
    Observer.ReenterShow := True; Form.Show; Observer.ReenterShow := False;
    Raw := Form.Handle; ChildRaw := Child.Handle;
    Check(GetFocus = ChildRaw, 'DFM initial focus after show');
    Check(Observer.ShowState and (Observer.Shows = 1) and (Observer.Rejections = 1) and
      (GetParent(Child.Handle) = Form.Handle), 'show creates frame and managed children before guarded show event');
    GetWindowText(Form.Handle, Buffer, SizeOf(Buffer));
    Check(StrPas(Buffer) = 'Modeless probe', 'precreation caption reaches actual native frame');
    Form.Caption := 'Updated title'; GetWindowText(Form.Handle, Buffer, SizeOf(Buffer));
    Check(StrPas(Buffer) = 'Updated title', 'caption setter updates live native title');
    Rejected := False;
    try Form.Caption := 'bad'#0'title'; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Form.Caption = 'Updated title'), 'NUL caption rejection preserves stored title');
    Form.Show; Check((Form.Handle = Raw) and (Observer.Shows = 1), 'repeated show preserves HWND and avoids duplicate event');
    Child.SetFocus; Child.MouseCapture := True;
    Form.Hide;
    Check(Observer.HideState and (Form.Handle = Raw) and (Child.Handle = ChildRaw) and
      (GetCapture <> ChildRaw) and (GetFocus <> ChildRaw), 'hide preserves HWND subtree and releases descendant focus and capture');
    Form.Hide; Check(Observer.Hides = 1, 'repeated hide avoids duplicate event');
    Form.Show; Observer.Veto := True; QueuedClose;
    Check(Form.Visible and (Observer.Queries = 1) and (Observer.Closes = 0),
      'queued WM_CLOSE obeys close-query veto without invoking close action');
    Observer.Veto := False; Observer.Action := ncaNone; QueuedClose;
    Check(Form.Visible and (Observer.Closes = 1), 'close action can cancel after successful query');
    Observer.FailQuery := True; Rejected := False;
    try Form.Close; except on Exception do Rejected := True; end;
    Check(Rejected and Form.Visible and (Form.Handle = Raw), 'direct query exception preserves window and propagates');
    QueuedClose;
    Check((Form.CallbackErrors = 1) and (Form.LastCallbackError = 'close query failure') and Form.Visible,
      'queued query exception is contained at native callback boundary');
    Observer.FailQuery := False; Form.OnClose := nil; QueuedClose;
    Check(not Form.Visible and (Form.Handle = Raw) and not Loop.Terminated,
      'default hide close keeps native object and does not post task quit');
    Form.Show; Form.DrawNow(Observer.CloseDuringDraw);
    Check((Observer.Rejections = 2) and (Form.Canvas.Handle = 0) and Form.Visible,
      'close during drawing is rejected without losing canvas or HWND');
    Form.OnClose := Observer.Closing; Observer.Action := ncaDestroy; QueuedClose;
    Check((Form.Handle = 0) and not Form.Visible and (Child.Handle = 0) and (Child.Parent = Form) and
      not IsWindow(Raw) and not IsWindow(ChildRaw), 'destroy close removes HWND subtree but retains model and Pascal objects');
    Form.Show; GetWindowText(Form.Handle, Buffer, SizeOf(Buffer));
    Check((Form.Handle <> 0) and (Child.Handle <> 0) and Form.Visible and
      (StrPas(Buffer) = 'Updated title'), 'show after destroy recreates titled form and managed descendants');
    Observer.FailHide := True; Rejected := False;
    try Form.Hide; except on Exception do Rejected := True; end;
    Check(Rejected and not Form.Visible and (Form.Handle <> 0),
      'hide event exception preserves completed visibility transition');
    Observer.FailHide := False; Observer.FailShow := True; Rejected := False;
    try Form.Show; except on Exception do Rejected := True; end;
    Check(Rejected and Form.Visible and (Child.Handle <> 0),
      'show event exception preserves visible HWND and resets lifecycle guard');
    Observer.FailShow := False; Form.Hide; Form.Show;
    PoolBefore := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 60 do begin Form.Close; Form.Show; end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolBefore - 2,
      'repeated modeless recreation does not drain USER resources');
    Form.Hide; Child.Parent := nil; Form.Show;
    Check((Form.InitialControl = Child) and (Child.Handle = 0),
      'detached initial control is not focused');
    Child.Parent := Form;
    Form.Free; Form := nil;
    Check((Child.Parent = nil) and (Child.Handle = 0), 'freeing form detaches independently owned child object');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Form.Free; Child.Free; Temporary.Free; Observer.Free; Loop.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
