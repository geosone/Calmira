program TestWin16Input;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,4096}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages,
  native_window, native_input;
type
  TProbe = class(TNativeInputWindow)
  public
    ForwardCount: Integer;
    ForwardId, ForwardKey: Word;
    procedure DefaultHandler(var M); override;
  end;
  TObserver = class
    Downs, Ups, Moves, KeyDowns, KeyUps, Chars, Enters, Exits: Integer;
    X, Y, Mode: Integer;
    Button: TMouseButton; Shift: TShiftState; Key: Word; Character: Char;
    RaiseNext, EnterFocused: Boolean;
    procedure MouseDown(Sender: TObject; B: TMouseButton; S: TShiftState; AX, AY: Integer);
    procedure MouseUp(Sender: TObject; B: TMouseButton; S: TShiftState; AX, AY: Integer);
    procedure MouseMove(Sender: TObject; S: TShiftState; AX, AY: Integer);
    procedure KeyDown(Sender: TObject; var K: Word; S: TShiftState);
    procedure KeyUp(Sender: TObject; var K: Word; S: TShiftState);
    procedure KeyPress(Sender: TObject; var K: Char);
    procedure Enter(Sender: TObject);
    procedure ExitEvent(Sender: TObject);
  end;
var ParentWindow, A, B: TProbe; Observer: TObserver; Failed, Rejected: Boolean;
  Saved, Fake: TKeyboardState; Raw: HWND; Before, I, Pool: Integer;
procedure LogLine(const Text: string);
var F: HFILE; Buffer: array[0..255] of Char; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Buffer, Line);
  _lwrite(F, @Buffer, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TProbe.DefaultHandler(var M);
begin
  case TMessage(M).Msg of
    WM_KEYDOWN, WM_KEYUP, WM_SYSKEYDOWN, WM_SYSKEYUP, WM_CHAR, WM_SYSCHAR:
    begin Inc(ForwardCount); ForwardId := TMessage(M).Msg; ForwardKey := TMessage(M).WParam; end;
  end;
  inherited DefaultHandler(M);
end;
procedure TObserver.MouseDown(Sender: TObject; B: TMouseButton; S: TShiftState; AX, AY: Integer);
begin Inc(Downs); Button := B; Shift := S; X := AX; Y := AY; end;
procedure TObserver.MouseUp(Sender: TObject; B: TMouseButton; S: TShiftState; AX, AY: Integer);
begin Inc(Ups); Button := B; Shift := S; X := AX; Y := AY; end;
procedure TObserver.MouseMove(Sender: TObject; S: TShiftState; AX, AY: Integer);
begin Inc(Moves); Shift := S; X := AX; Y := AY; end;
procedure TObserver.KeyDown(Sender: TObject; var K: Word; S: TShiftState);
begin
  Inc(KeyDowns); Key := K; Shift := S;
  if RaiseNext then begin RaiseNext := False; raise Exception.Create('input callback exception'); end;
  if Mode = 1 then K := Ord('B') else if Mode = 2 then K := 0;
end;
procedure TObserver.KeyUp(Sender: TObject; var K: Word; S: TShiftState);
begin Inc(KeyUps); Key := K; Shift := S; if Mode = 2 then K := 0; end;
procedure TObserver.KeyPress(Sender: TObject; var K: Char);
begin Inc(Chars); Character := K; if Mode = 1 then K := 'z' else if Mode = 2 then K := #0; end;
procedure TObserver.Enter(Sender: TObject);
begin Inc(Enters); EnterFocused := TNativeInputWindow(Sender).Focused; end;
procedure TObserver.ExitEvent(Sender: TObject);
begin Inc(Exits); end;
begin
  LogLine('STEP native keyboard mouse focus and capture');
  GetKeyboardState(@Saved);
  try
    ParentWindow := TProbe.Create(nil); A := TProbe.Create(nil); B := TProbe.Create(nil);
    Observer := TObserver.Create;
    ParentWindow.CreateHandle(0, 'Input probe', WS_POPUP or WS_VISIBLE, 20, 20, 96, 64);
    A.CreateHandle(ParentWindow.Handle, 'A', WS_CHILD or WS_VISIBLE, 0, 0, 32, 32);
    B.CreateHandle(ParentWindow.Handle, 'B', WS_CHILD or WS_VISIBLE, 40, 0, 32, 32);
    SetActiveWindow(ParentWindow.Handle); B.SetFocus;
    A.OnMouseDown := Observer.MouseDown; A.OnMouseUp := Observer.MouseUp;
    A.OnMouseMove := Observer.MouseMove; A.OnKeyDown := Observer.KeyDown;
    A.OnKeyUp := Observer.KeyUp; A.OnKeyPress := Observer.KeyPress;
    A.OnEnter := Observer.Enter; A.OnExit := Observer.ExitEvent;
    Check(GetClassWord(A.Handle, GCW_STYLE) and CS_DBLCLKS <> 0,
      'native window class enables USER double-click generation');
    Fake := Saved; Fake[VK_SHIFT] := #128; Fake[VK_CONTROL] := #128; Fake[VK_MENU] := #0;
    SetKeyboardState(@Fake);
    A.Perform(WM_MOUSEMOVE, MK_LBUTTON, LongInt($FFECFFF6));
    Check((Observer.Moves = 1) and (Observer.X = -10) and (Observer.Y = -20) and
      (Observer.Shift = [ssLeft]), 'mouse uses signed Win16 coordinates and message modifier flags');
    A.Perform(WM_RBUTTONDOWN, MK_RBUTTON or MK_SHIFT or MK_CONTROL, 0);
    Check((Observer.Downs = 1) and (Observer.Button = mbRight) and
      (Observer.Shift = [ssRight, ssShift, ssCtrl]), 'right button down reports button and modifiers');
    Fake[VK_MENU] := #128; SetKeyboardState(@Fake);
    A.Perform(WM_MOUSEMOVE, MK_CONTROL, 0);
    Check(Observer.Shift = [ssAlt, ssCtrl], 'mouse Alt comes from native key state without inventing Shift');
    Fake[VK_MENU] := #0; SetKeyboardState(@Fake);
    A.Perform(WM_MBUTTONUP, 0, 0);
    Check((Observer.Ups = 1) and (Observer.Button = mbMiddle) and (Observer.Shift = []),
      'middle button up does not invent a pressed-button flag');
    A.Perform(WM_LBUTTONDBLCLK, MK_LBUTTON, 0);
    Check((Observer.Button = mbLeft) and (Observer.Shift = [ssLeft, ssDouble]),
      'double-click message marks a second mouse down');
    A.Perform(WM_KEYDOWN, Ord('A'), 1);
    Check((Observer.Key = Ord('A')) and (Observer.Shift = [ssShift, ssCtrl]) and
      (A.ForwardKey = Ord('A')), 'keyboard modifiers use native key state and retain default processing');
    Observer.Mode := 1; A.Perform(WM_KEYDOWN, Ord('A'), 1);
    Check(A.ForwardKey = Ord('B'), 'var Key replacement reaches native default handler');
    Before := A.ForwardCount; Observer.Mode := 2; A.Perform(WM_KEYDOWN, Ord('A'), 1);
    A.Perform(WM_KEYUP, Ord('A'), LongInt($C0000001));
    Check((A.ForwardCount = Before) and (Observer.KeyUps = 1), 'zero Key consumes key down and key up');
    Observer.Mode := 0; Fake[VK_SHIFT] := #0; Fake[VK_CONTROL] := #0; SetKeyboardState(@Fake);
    A.Perform(WM_SYSKEYDOWN, Ord('A'), $20000001);
    Check((Observer.Shift = [ssAlt]) and (A.ForwardId = WM_SYSKEYDOWN),
      'system-key context bit preserves Alt and original message identity');
    A.Perform(WM_SYSKEYUP, Ord('A'), LongInt($E0000001));
    Check((Observer.Shift = [ssAlt]) and (A.ForwardId = WM_SYSKEYUP),
      'system key up keeps its native message and modifier context');
    Observer.Mode := 1; A.Perform(WM_CHAR, Ord('a'), 1);
    Check((Observer.Character = 'a') and (A.ForwardKey = Ord('z')), 'ANSI KeyPress can replace the forwarded character');
    Before := A.ForwardCount; Observer.Mode := 2; A.Perform(WM_SYSCHAR, Ord('a'), 1);
    Check(A.ForwardCount = Before, 'NUL KeyPress consumes system character');
    Observer.Mode := 0; A.Perform(WM_CHAR, $E4, 1);
    Check((Ord(Observer.Character) = $E4) and (A.ForwardKey = $E4),
      'single-byte ANSI KeyPress preserves the high character bit');
    Observer.Mode := 0; Before := Observer.Chars; A.Perform(WM_CHAR, $8140, 1);
    Check((Observer.Chars = Before) and (A.ForwardKey = $8140), 'packed DBCS character is forwarded without truncation');
    Observer.RaiseNext := True; A.Perform(WM_KEYDOWN, Ord('A'), 1);
    Check((A.CallbackErrors = 1) and (A.LastCallbackError = 'input callback exception'),
      'input callback exception is contained by native boundary');
    A.Perform(WM_KEYDOWN, Ord('B'), 1);
    Check(Observer.Key = Ord('B'), 'input dispatch recovers after callback exception');
    Before := Observer.Enters; A.SetFocus;
    Check(A.Focused and not B.Focused and Observer.EnterFocused and
      (Observer.Enters = Before + 1), 'real focus transfer invokes OnEnter with current native focus');
    Before := Observer.Exits; B.SetFocus;
    Check(not A.Focused and B.Focused and (Observer.Exits = Before + 1),
      'real focus loss invokes OnExit');
    EnableWindow(ParentWindow.Handle, False);
    Check(not A.CanFocus, 'disabled ancestor prevents child focus');
    Rejected := False;
    try A.SetFocus; except on Exception do Rejected := True; end;
    Check(Rejected, 'SetFocus rejects a disabled parent chain');
    EnableWindow(ParentWindow.Handle, True); ShowWindow(A.Handle, SW_HIDE);
    Check(not A.CanFocus, 'hidden window cannot receive requested focus');
    ShowWindow(A.Handle, SW_SHOWNOACTIVATE);
    A.MouseCapture := True;
    Check(A.MouseCapture and (GetCapture = A.Handle), 'mouse capture uses real USER ownership');
    B.MouseCapture := True; A.MouseCapture := False;
    Check(B.MouseCapture, 'releasing nonowned capture does not release peer capture');
    B.MouseCapture := False;
    Check(GetCapture = 0, 'capture owner can explicitly release mouse');
    Pool := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 150 do
    begin A.MouseCapture := True; A.MouseCapture := False; A.Perform(WM_MOUSEMOVE, 0, 0); end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= Pool - 2, 'input and capture cycles do not drain USER pool');
    A.MouseCapture := True; Raw := A.Handle; A.DestroyHandle;
    Check((GetCapture <> Raw) and not A.MouseCapture and not A.Focused and not A.CanFocus,
      'native destruction clears focus and capture ownership');
    Rejected := False;
    try A.SetFocus; except on Exception do Rejected := True; end;
    Check(Rejected, 'detached object cannot request focus');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  SetKeyboardState(@Saved);
  A.Free; B.Free; ParentWindow.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
