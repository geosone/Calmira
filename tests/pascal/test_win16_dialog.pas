program TestWin16Dialog;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, Controls, native_form,
  native_button, native_loop, native_window;
const FilterMessage = WM_USER + 91;
type
  TProbe = class(TCustomControl)
  public
    Want: Word;
    Keys, Chars: Integer;
    procedure DialogCode(var M: TMessage); message WM_GETDLGCODE;
    procedure Key(var M: TMessage); message WM_KEYDOWN;
    procedure Character(var M: TMessage); message WM_CHAR;
  end;
  TObserver = class
  public
    Accepts, Cancels, Others, Filters, Rejections: Integer;
    FailFilter, Chain: Boolean;
    procedure Click(Sender: TObject);
    procedure ReorderDuringDraw(Sender: TObject);
    function Filter(var M: TMsg): Boolean;
  end;
var Form, Peer: TNativeForm; Group: TCustomControl; Input: TProbe;
  Accept, Cancel, Other: TButton; Loop, QuitLoop: TNativeMessageLoop;
  Observer: TObserver; Failed, Rejected: Boolean; M: TMsg;
  Keyboard, SavedKeyboard: TKeyboardState; I: Integer; N: Word;
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
procedure TProbe.DialogCode(var M: TMessage);
begin M.Result := Want; end;
procedure TProbe.Key(var M: TMessage);
begin Inc(Keys); end;
procedure TProbe.Character(var M: TMessage);
begin Inc(Chars); end;
procedure TObserver.Click(Sender: TObject);
begin
  if Sender = Accept then Inc(Accepts)
  else if Sender = Cancel then Inc(Cancels) else Inc(Others);
end;
procedure TObserver.ReorderDuringDraw(Sender: TObject);
begin
  try Other.TabOrder := 0; except on ENativeWindowError do Rejected := True; end;
end;
function TObserver.Filter(var M: TMsg): Boolean;
begin
  if M.message <> FilterMessage then begin Result := False; Exit; end;
  Inc(Filters);
  try Loop.ProcessMessages(1); except on ENativeLoopError do Inc(Rejections); end;
  if FailFilter then raise Exception.Create('filter failure');
  if Chain then PostMessage(Form.Handle, FilterMessage, 0, 0);
  Result := True;
end;
function DialogKey(Target: HWND; Key: Word): Boolean;
begin
  FillChar(M, SizeOf(M), 0); M.hwnd := Target;
  M.message := WM_KEYDOWN; M.wParam := Key;
  Result := Form.ProcessDialogMessage(M);
end;
procedure QueueKey(Target: HWND; Key: Word);
begin
  PostMessage(Target, WM_KEYDOWN, Key, 1);
  PostMessage(Target, WM_KEYUP, Key, LongInt($C0000001));
  Loop.ProcessMessages(100);
end;
begin
  GetKeyboardState(SavedKeyboard); FillChar(Keyboard, SizeOf(Keyboard), 0);
  SetKeyboardState(Keyboard);
  LogLine('STEP modeless dialog navigation');
  try
    Form := TNativeForm.Create(nil); Peer := TNativeForm.Create(nil);
    Group := TCustomControl.Create(Form); Input := TProbe.Create(Form);
    Accept := TButton.Create(Form); Cancel := TButton.Create(Form);
    Other := TButton.Create(Form); Observer := TObserver.Create;
    Loop := TNativeMessageLoop.Create; QuitLoop := TNativeMessageLoop.Create;
    Group.SetBounds(5, 5, 160, 70); Group.Parent := Form;
    Input.SetBounds(4, 4, 40, 20); Input.TabStop := True; Input.Parent := Group;
    Accept.SetBounds(4, 30, 60, 23); Accept.Parent := Group;
    Cancel.SetBounds(5, 85, 60, 23); Cancel.Parent := Form;
    Other.SetBounds(75, 85, 60, 23); Other.Parent := Form;
    Accept.Caption := 'Accept'; Accept.Default := True; Accept.OnClick := Observer.Click;
    Cancel.Caption := 'Cancel'; Cancel.Cancel := True; Cancel.OnClick := Observer.Click;
    Other.OnClick := Observer.Click; Form.Show; Peer.Show;
    SetActiveWindow(Form.Handle); Input.SetFocus;
    Loop.ProcessMessages(100);
    Check((Accept.TabOrder = 1) and (Cancel.TabOrder = 1), 'initial sibling tab order');
    Check((Form.FindControl(Accept.Handle) = Accept) and
      (Form.FindControl(Peer.Handle) = nil), 'managed descendant lookup');
    Check(DialogKey(Input.Handle, VK_TAB) and Accept.Focused, 'Tab descends group');
    Check(DialogKey(Accept.Handle, VK_TAB) and Cancel.Focused, 'Tab leaves group');
    Keyboard[VK_SHIFT] := #128; SetKeyboardState(Keyboard);
    Check(DialogKey(Cancel.Handle, VK_TAB) and Accept.Focused, 'Shift Tab reverses');
    Keyboard[VK_SHIFT] := #0; SetKeyboardState(Keyboard);
    Other.SetFocus;
    Check(DialogKey(Other.Handle, VK_TAB) and Input.Focused, 'Tab wraps');
    Other.TabOrder := 0; Other.SetFocus;
    Check((Other.TabOrder = 0) and DialogKey(Other.Handle, VK_TAB) and Input.Focused,
      'live sibling reorder');
    Other.TabOrder := 100;
    Check(Other.TabOrder = 2, 'oversize order clamps');
    Rejected := False;
    try Other.TabOrder := -1; except on ENativeWindowError do Rejected := True; end;
    Check(Rejected and (Other.TabOrder = 2), 'negative order preserves model');
    Rejected := False; Form.DrawNow(Observer.ReorderDuringDraw);
    Check(Rejected and (Other.TabOrder = 2), 'drawing rejects tab reorder');
    Accept.TabStop := False; Input.SetFocus;
    Check(DialogKey(Input.Handle, VK_TAB) and Cancel.Focused and
      (DWORD(GetWindowLong(Accept.Handle, GWL_STYLE)) and WS_TABSTOP = 0),
      'TabStop updates native style and traversal');
    Accept.SetFocus;
    Check(DialogKey(Accept.Handle, VK_TAB) and Cancel.Focused, 'nonstop focus keeps position');
    Accept.TabStop := True; Group.Enabled := False; Other.SetFocus;
    Check(DialogKey(Other.Handle, VK_TAB) and Cancel.Focused, 'disabled ancestor skipped');
    Group.Enabled := True; Group.Visible := False; Other.SetFocus;
    Check(DialogKey(Other.Handle, VK_TAB) and Cancel.Focused, 'hidden ancestor skipped');
    Group.Visible := True; Input.SetFocus; Input.Want := DLGC_WANTTAB;
    Check(not DialogKey(Input.Handle, VK_TAB) and Input.Focused, 'control retains wanted Tab');
    Input.Want := DLGC_WANTALLKEYS;
    Check(not DialogKey(Input.Handle, VK_RETURN) and (Observer.Accepts = 0),
      'control retains all dialog keys');
    Input.Want := 0; Keyboard[VK_CONTROL] := #128; SetKeyboardState(Keyboard);
    Check(not DialogKey(Input.Handle, VK_TAB), 'Ctrl Tab not intercepted');
    Keyboard[VK_CONTROL] := #0; Keyboard[VK_MENU] := #128; SetKeyboardState(Keyboard);
    Check(not DialogKey(Input.Handle, VK_RETURN), 'Alt Enter not intercepted');
    Keyboard[VK_MENU] := #0; SetKeyboardState(Keyboard);
    Check(not DialogKey(Peer.Handle, VK_ESCAPE), 'foreign form not intercepted');
    Check(DialogKey(Input.Handle, VK_RETURN) and (Observer.Accepts = 1), 'default Enter');
    Accept.Enabled := False;
    Check(not DialogKey(Input.Handle, VK_RETURN), 'disabled default ignored');
    Accept.Enabled := True;
    Other.SetFocus;
    Check(DialogKey(Other.Handle, VK_RETURN) and (Observer.Others = 1) and
      (Observer.Accepts = 1), 'focused button wins over default');
    Check(DialogKey(Other.Handle, VK_ESCAPE) and (Observer.Cancels = 1), 'cancel Escape');
    Cancel.Enabled := False;
    Check(not DialogKey(Other.Handle, VK_ESCAPE), 'disabled cancel ignored');
    Cancel.Enabled := True; Group.Visible := False; Other.TabStop := False;
    Other.SetFocus; Cancel.TabStop := False;
    Check(not Form.FocusNext(True), 'empty tab set is harmless');
    Cancel.TabStop := True; Other.TabStop := True; Group.Visible := True;
    Accept.Default := False;
    Check(DWORD(GetWindowLong(Accept.Handle, GWL_STYLE)) and $F = BS_PUSHBUTTON,
      'default style removed live');
    Accept.Default := True;
    Check(DWORD(GetWindowLong(Accept.Handle, GWL_STYLE)) and $F = BS_DEFPUSHBUTTON,
      'default style applied live');
    Loop.OnMessage := Form.ProcessDialogMessage; Input.SetFocus;
    QueueKey(Input.Handle, VK_RETURN);
    Check((Observer.Accepts = 2) and (Input.Keys = 0) and (Input.Chars = 0),
      'queued Enter consumed before translation');
    QueueKey(Input.Handle, VK_TAB);
    Check(Accept.Focused and (Input.Chars = 0), 'queued Tab changes native focus');
    Input.SetFocus; Input.Want := DLGC_WANTALLKEYS;
    QueueKey(Input.Handle, VK_RETURN);
    Check((Input.Keys = 1) and (Input.Chars = 1) and (Observer.Accepts = 2),
      'wanted key reaches native translation');
    Input.Want := 0; Loop.OnMessage := Observer.Filter;
    PostMessage(Form.Handle, FilterMessage, 0, 0); Observer.Chain := True;
    N := Loop.ProcessMessages(3); Observer.Chain := False; Loop.ProcessMessages(100);
    Check((N = 3) and (Observer.Filters = 4) and (Observer.Rejections = 4),
      'consumed chain obeys budget and nesting guard');
    Observer.FailFilter := True; PostMessage(Form.Handle, FilterMessage, 0, 0);
    Rejected := False;
    try Loop.ProcessMessages(100); except on Exception do Rejected := True; end;
    Observer.FailFilter := False; Loop.ProcessMessages(100);
    Check(Rejected, 'filter exception releases pump guard');
    QuitLoop.OnMessage := Observer.Filter; I := Observer.Filters;
    PostQuitMessage(-19); QuitLoop.ProcessMessages(100);
    Check(QuitLoop.Terminated and (QuitLoop.ExitCode = -19) and (Observer.Filters = I),
      'quit bypasses message filter');
    Loop.OnMessage := nil; QuitLoop.OnMessage := nil;
    Form.DestroyHandle; Form.Show; Input.SetFocus;
    Check(Form.FocusNext(True) and Accept.Focused and Accept.TabStop and Accept.Default,
      'recreation retains dialog settings');
    Check((Form.CallbackErrors = 0) and (Accept.CallbackErrors = 0), 'no callback failures');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Loop <> nil then Loop.OnMessage := nil;
  if QuitLoop <> nil then QuitLoop.OnMessage := nil;
  Form.Free; Peer.Free; Loop.Free; QuitLoop.Free; Observer.Free;
  SetKeyboardState(SavedKeyboard);
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
