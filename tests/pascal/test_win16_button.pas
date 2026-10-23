program TestWin16Button;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls, StdCtrls;
type
  TObserver = class
    Calls, PeerCalls: Integer;
    FailClick: Boolean;
    Button: TButton;
    procedure Clicked(Sender: TObject);
    procedure PeerClicked(Sender: TObject);
  end;
var Root, Other: TCustomControl; A, B: TButton; Observer: TObserver;
  Failed, Rejected: Boolean; Raw: HWND; Original: TWndClass;
  Buffer: array[0..255] of Char; I, Before, PoolUSER, PoolGDI: Integer;
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
procedure TObserver.Clicked(Sender: TObject);
begin
  if Sender <> Button then raise Exception.Create('Wrong button sender');
  Inc(Calls); if FailClick then raise Exception.Create('button click failure');
end;
procedure TObserver.PeerClicked(Sender: TObject);
begin Inc(PeerCalls); end;
procedure MouseClick(Button: TButton);
begin Button.Perform(WM_LBUTTONDOWN, MK_LBUTTON, $00080008); Button.Perform(WM_LBUTTONUP, 0, $00080008); end;
begin
  LogLine('STEP native USER button and managed notifications');
  try
    Root := TCustomControl.Create(nil); Other := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Button parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 20, 20, 210, 100);
    Other.CreateHandle(0, 'Other parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 250, 20, 160, 100);
    Observer := TObserver.Create; A := TButton.Create(nil); B := TButton.Create(nil);
    Observer.Button := A; A.Caption := 'Cancel'; A.OnClick := Observer.Clicked;
    A.SetBounds(8, 8, 80, 24); A.Parent := Root;
    B.Caption := 'Peer'; B.OnClick := Observer.PeerClicked; B.SetBounds(100, 8, 80, 24); B.Parent := Root;
    Root.Update; GetClassInfo(0, 'BUTTON', Original);
    Check(GetClassWord(A.Handle, GCW_CBWNDEXTRA) = Original.cbWndExtra + SizeOf(Pointer),
      'private superclass preserves native BUTTON extra bytes before far object pointer');
    GetWindowText(A.Handle, Buffer, SizeOf(Buffer));
    Check((StrPas(Buffer) = 'Cancel') and (A.Handle <> B.Handle), 'native buttons retain separate handles and ANSI caption');
    A.Perform(WM_LBUTTONDOWN, MK_LBUTTON, $00080008);
    Check(GetCapture = A.Handle, 'USER button owns capture while mouse is held');
    A.Perform(WM_LBUTTONUP, 0, $00080008);
    Check((Observer.Calls = 1) and (Observer.PeerCalls = 0) and (GetCapture <> A.Handle),
      'native mouse release routes exactly one BN_CLICKED to matching managed child');
    MouseClick(B); Check((Observer.PeerCalls = 1) and (Observer.Calls = 1), 'peer click notification does not target another object');
    A.SetFocus; A.Perform(WM_KEYDOWN, VK_SPACE, 1); A.Perform(WM_KEYUP, VK_SPACE, LongInt($C0000001));
    Check(Observer.Calls = 2, 'native focused Space key activates button');
    A.Perform(WM_LBUTTONDOWN, MK_LBUTTON, $00080008);
    A.Perform(WM_MOUSEMOVE, MK_LBUTTON, $00080070); A.Perform(WM_LBUTTONUP, 0, $00080070);
    Check(Observer.Calls = 2, 'native release outside button cancels click');
    A.Enabled := False; A.Click;
    Root.Perform(WM_COMMAND, 0, LongInt(A.Handle));
    Check(Observer.Calls = 2, 'disabled button ignores direct and routed activation'); A.Enabled := True;
    A.Visible := False; Root.Perform(WM_COMMAND, 0, LongInt(A.Handle)); A.Visible := True;
    Check(Observer.Calls = 2, 'hidden native button ignores routed activation');
    Root.Perform(WM_COMMAND, 1, LongInt(A.Handle));
    Root.Perform(WM_COMMAND, 0, LongInt(A.Handle) or (LongInt(42) shl 16));
    Check(Observer.Calls = 2, 'wrong control ID and unhandled notification do not dispatch click');
    Raw := CreateWindow('BUTTON', 'Foreign', WS_CHILD, 0, 40, 60, 23, Root.Handle, 0, HInstance, nil);
    if Raw = 0 then raise Exception.Create('Cannot create foreign button');
    Root.Perform(WM_COMMAND, 0, LongInt(Raw)); DestroyWindow(Raw);
    Check(Observer.Calls = 2, 'unmanaged child notification never interprets foreign window bytes as objects');
    Observer.FailClick := True; MouseClick(A); Observer.FailClick := False;
    Check((Root.CallbackErrors = 1) and (Root.LastCallbackError = 'button click failure'),
      'click exception is contained by receiving parent callback boundary');
    MouseClick(A); Check(Observer.Calls = 4, 'native button remains usable after failed click event');
    A.Font.Size := 12;
    Check(A.Perform(WM_GETFONT, 0, 0) = A.Font.Handle, 'font changes update native BUTTON font handle');
    Rejected := False;
    try A.Caption := 'bad'#0'title'; except on Exception do Rejected := True; end;
    Check(Rejected and (A.Caption = 'Cancel'), 'invalid button title preserves stored caption');
    Raw := A.Handle; A.Parent := Other; MouseClick(A);
    Check((A.Handle = Raw) and (GetParent(Raw) = Other.Handle) and (Observer.Calls = 5),
      'live button reparent preserves native handle and routes through new parent');
    Other.DestroyHandle; Check(A.Handle = 0, 'parent destruction detaches superclassed native button');
    Other.CreateHandle(0, 'Other parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 250, 20, 160, 100);
    MouseClick(A); Check(Observer.Calls = 6, 'managed recreation restores button association and native click behavior');
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES); PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    Before := Observer.Calls;
    for I := 1 to 60 do begin A.Parent := Root; A.Parent := Other; MouseClick(A); end;
    Check((Observer.Calls = Before + 60) and (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2), 'button reparent and activation cycles retain USER and GDI resources');
    Check((A.CallbackErrors = 0) and (A.Canvas.Handle = 0), 'native button does not borrow framework paint DC or leak callback failures');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  A.Free; B.Free; Root.Free; Other.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
