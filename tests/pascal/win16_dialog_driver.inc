{ Shared native driver for modal Dialogs probes. Steps run from a message on
  the hidden application window inside Application.Run; the inherited root
  idle service then answers each modal dialog through the real USER queue. }
const WM_RUNSTEPS = WM_USER + 1;
type
  TActionKind = (akKey, akClick, akChars);
  TDriver = class
    Kind: TActionKind;
    Key: Word;
    Target: string[20];
    Acted: Boolean;
    Caption, Children, FocusText: string[60];
    SelStart, SelEnd: Word;
    Width, Height: Integer;
    procedure Idle(Sender: TObject; var Done: Boolean);
    function Hook(var Message: TMessage): Boolean;
  end;
var Driver: TDriver; MainForm: TForm; Failed: Boolean;
  PoolGDI, PoolUSER, Owned, I: Integer;
{$I win16_stack_guard.inc}
procedure RunSteps; forward;
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
function WindowText(Window: HWND): string;
var Buffer: array[0..255] of Char;
begin
  Buffer[0] := #0; GetWindowText(Window, Buffer, SizeOf(Buffer)); Result := StrPas(Buffer);
end;
procedure PostKey(Window: HWND; Value: Word);
begin
  PostMessage(Window, WM_KEYDOWN, Value, 1);
  PostMessage(Window, WM_KEYUP, Value, LongInt($C0000001));
end;
procedure TDriver.Idle(Sender: TObject; var Done: Boolean);
var Dialog, Child, Focus: HWND; Area: TRect; Index: Integer; Selection: LongInt;
begin
  Done := True;
  Dialog := GetActiveWindow;
  if Acted or (Dialog = 0) or (Dialog = MainForm.Handle) then Exit;
  Acted := True;
  Caption := WindowText(Dialog); Children := '';
  Child := GetWindow(Dialog, GW_CHILD);
  while Child <> 0 do
  begin
    if Children <> '' then Children := Children + '|';
    Children := Children + WindowText(Child);
    Child := GetWindow(Child, GW_HWNDNEXT);
  end;
  GetClientRect(Dialog, Area); Width := Area.Right; Height := Area.Bottom;
  Focus := GetFocus; FocusText := WindowText(Focus);
  Selection := SendMessage(Focus, EM_GETSEL, 0, 0);
  SelStart := LoWord(Selection); SelEnd := HiWord(Selection);
  case Kind of
    akKey: PostKey(Focus, Key);
    akClick:
      begin
        Child := GetWindow(Dialog, GW_CHILD);
        while (Child <> 0) and (WindowText(Child) <> Target) do Child := GetWindow(Child, GW_HWNDNEXT);
        if Child = 0 then begin PostKey(Focus, VK_ESCAPE); Exit; end;
        PostMessage(Child, WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(5, 5));
        PostMessage(Child, WM_LBUTTONUP, 0, MakeLong(5, 5));
      end;
    akChars:
      begin
        for Index := 1 to Length(Target) do PostMessage(Focus, WM_CHAR, Ord(Target[Index]), 1);
        PostKey(Focus, VK_RETURN);
      end;
  end;
end;
function TDriver.Hook(var Message: TMessage): Boolean;
begin
  Result := Message.Msg = WM_RUNSTEPS;
  if not Result then Exit;
  try RunSteps;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  MainForm.Close;
end;
procedure Script(AKind: TActionKind; AKey: Word; const ATarget: string);
begin
  Driver.Kind := AKind; Driver.Key := AKey; Driver.Target := ATarget; Driver.Acted := False;
  Driver.Caption := ''; Driver.Children := ''; Driver.FocusText := '';
end;
procedure StartResources;
begin
  Owned := Application.ComponentCount;
  PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
  PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
end;
function ResourcesKept: Boolean;
begin
  Result := (Application.ComponentCount = Owned) and
    (GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2);
end;
procedure RunDriver(const Title: string);
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP ' + Title);
  try
    Driver := TDriver.Create; Application.OnIdle := Driver.Idle;
    Application.HookMainWindow(Driver.Hook);
    Application.CreateForm(TForm, MainForm);
    MainForm.SetBounds(10, 10, 200, 100);
    PostMessage(Application.Handle, WM_RUNSTEPS, 0, 0);
    Application.Run;
    Check(Application.Terminated, 'loop end');
    Application.UnhookMainWindow(Driver.Hook);
    Application.OnIdle := nil; Driver.Free; Driver := nil;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'stack');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end;
