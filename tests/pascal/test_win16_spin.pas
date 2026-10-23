program TestWin16Spin;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Controls, native_edit, Spin;
type
  TObserver = class
    Changes: Integer;
    procedure Changed(Sender: TObject);
  end;
var Root: TCustomControl; Spin: TSpinEdit; Other: TEdit; Observer: TObserver; Failed: Boolean;
  R: TRect; Before: LongInt; Msg: TMsg; Start: LongInt;
procedure TObserver.Changed(Sender: TObject); begin Inc(Changes); end;
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
procedure Pump(Milliseconds: LongInt);
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < Milliseconds do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure Press(Y: Integer);
var P: TPoint;
begin
  { Capture follows the real cursor, so place it over the pressed half. }
  P := Spin.Button.ClientToScreen(Point(5, Y)); SetCursorPos(P.X, P.Y);
  Spin.Button.Perform(WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(5, Y));
end;
procedure Release(Y: Integer);
begin Spin.Button.Perform(WM_LBUTTONUP, 0, MakeLong(5, Y)); end;
begin
  LogLine('STEP spin edit');
  Observer := TObserver.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Spin parent', WS_POPUP or WS_VISIBLE, 10, 10, 300, 100);
    Spin := TSpinEdit.Create(nil);
    Check((Spin.Value = 0) and (Spin.Increment = 1) and (Spin.Text = '0') and Spin.EditorEnabled,
      'Delphi defaults');
    Spin.MinValue := 0; Spin.MaxValue := 10;
    Spin.SetBounds(10, 10, 60, 24); Spin.Parent := Root; Spin.OnChange := Observer.Changed;
    Other := TEdit.Create(nil); Other.SetBounds(100, 10, 60, 24); Other.Parent := Root;
    Check((Spin.Button.Handle <> 0) and (GetParent(Spin.Button.Handle) = Spin.Handle) and
      (Spin.Button.Left = Spin.ClientWidth - Spin.Button.Width), 'button is a child at the right edge');
    Spin.Perform(EM_GETRECT, 0, LongInt(@R));
    Check(R.Right <= Spin.Button.Left, 'text area stops before the button');
    Check(Spin.Perform(WM_GETDLGCODE, 0, 0) and DLGC_WANTALLKEYS = 0, 'Tab and Enter stay with the dialog');
    Spin.Value := 15;
    Check((Spin.Value = 10) and (Spin.Text = '10'), 'value clamps to MaxValue');
    Spin.Value := -3;
    Check(Spin.Value = 0, 'value clamps to MinValue');
    Observer.Changes := 0;
    Press(2); Release(2);
    Check((Spin.Value = 1) and (Observer.Changes >= 1), 'up click');
    Press(Spin.Button.Height - 2); Release(Spin.Button.Height - 2);
    Check(Spin.Value = 0, 'down click');
    Press(2); Pump(900);
    Before := Spin.Value;
    Check(Before >= 4, 'holding repeats');
    LogLine('INFO repeated to ' + IntToStr(Before));
    Release(2); Pump(400);
    Check(Spin.Value = Before, 'release stops repeating');
    Spin.Value := 5;
    Spin.Perform(WM_KEYDOWN, VK_UP, 0);
    Check(Spin.Value = 6, 'up arrow key');
    Spin.Perform(WM_KEYDOWN, VK_DOWN, 0); Spin.Perform(WM_KEYDOWN, VK_DOWN, 0);
    Check(Spin.Value = 4, 'down arrow key');
    Spin.SelectAll;
    Spin.Perform(WM_CHAR, Ord('a'), 0);
    Check(Spin.Text = '4', 'letters are rejected');
    Spin.Perform(WM_CHAR, Ord('7'), 0);
    Check(Spin.Text = '7', 'digits are accepted');
    Spin.Text := 'xyz';
    Check(Spin.Value = 0, 'invalid text reads as MinValue');
    Spin.SetFocus; Spin.Text := '99';
    Other.SetFocus;
    Check((Spin.Value = 10) and (Spin.Text = '10'), 'leaving clamps the text');
    Spin.Free; Spin := nil;
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Spin.Free; Other.Free; Root.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
