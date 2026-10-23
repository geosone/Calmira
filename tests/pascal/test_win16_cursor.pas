program CursorTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Messages, Controls, native_edit,
  native_application, native_form, native_screen, native_cursors, native_cursor_policy, native_window;
type TFrame = class(TNativeForm)
  public
    Reenter: Boolean;
    Rejections: Integer;
    procedure HitTest(var M: TMessage); message WM_NCHITTEST;
end;
var App: TNativeApplication; View, Other: TNativeScreen; Main: TFrame;
  Edit: TEdit; Foreign: TNativeForm; Failed, Rejected: Boolean;
  Arrow, Beam, WaitCursor, Cross, Custom: HCURSOR;
  SavedPosition: TPoint; MaskAND, MaskXOR: array[0..127] of Byte;
  BeforeGDI, BeforeUSER, BeforeShow, I: Integer;
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
procedure PointAt(Window: HWND; X, Y: SmallInt);
var Position: TPoint;
begin
  Position.X := X; Position.Y := Y; ClientToScreen(Window, @Position);
  SetCursorPos(Position.X, Position.Y);
end;
procedure CursorMessage(Window: HWND; Hit: SmallInt);
begin SendMessage(Window, WM_SETCURSOR, Window, LongInt(Word(Hit)) or (LongInt(WM_MOUSEMOVE) shl 16)); end;
procedure TFrame.HitTest(var M: TMessage);
begin
  if Reenter then
    try View.PushCursor(crArrow); except on ENativeCursorError do Inc(Rejections); end;
  inherited DefaultHandler(M);
end;
procedure Setup;
begin
  GetCursorPos(@SavedPosition); BeforeShow := ShowCursor(True); ShowCursor(False);
  Arrow := LoadCursor(0, IDC_ARROW); Beam := LoadCursor(0, IDC_IBEAM);
  WaitCursor := LoadCursor(0, IDC_WAIT); Cross := LoadCursor(0, IDC_CROSS);
  App := TNativeApplication.Create(nil); App.Initialize; App.CreateForm(TFrame, Main);
  Main.SetBounds(10, 10, 260, 180); Main.Caption := 'Cursor';
  Edit := TEdit.Create(Main); Edit.Parent := Main; Edit.SetBounds(10, 10, 160, 24);
  View := TNativeScreen.Create(nil); View.Application := App;
  Other := TNativeScreen.Create(nil); Other.Application := App;
  Main.Show; BringWindowToTop(Main.Handle); SetActiveWindow(Main.Handle);
  PointAt(Edit.Handle, 10, 10);
  Check(CursorTarget = Edit.Handle, 'packed POINT hit testing finds real EDIT');
  CursorMessage(Edit.Handle, HTCLIENT); Check(CurrentCursor = Beam, 'native EDIT default cursor preserved');
  Rejected := False;
  try Edit.Cursor := 1234; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Edit.Cursor = crDefault) and (CurrentCursor = Beam), 'invalid control cursor preserves state');
end;
procedure PriorityAndStack;
begin
  Main.Cursor := crCross; CursorMessage(Edit.Handle, HTCLIENT);
  Check(CurrentCursor = Cross, 'default child inherits explicit parent cursor');
  Edit.Cursor := crArrow; Check(CurrentCursor = Arrow, 'child cursor refreshes immediately');
  View.Cursor := crHourGlass;
  Check((View.Cursor = crHourGlass) and (CurrentCursor = WaitCursor), 'screen override beats child cursor immediately');
  View.PushCursor(crCross); View.PushCursor(crNone);
  Check((View.CursorDepth = 2) and (View.Cursor = crNone) and (CurrentCursor = 0), 'nested none cursor hides image');
  View.PopCursor; Check((View.Cursor = crCross) and (CurrentCursor = Cross), 'inner pop restores outer cursor');
  View.PopCursor; Check((View.CursorDepth = 0) and (CurrentCursor = WaitCursor), 'outer pop restores busy cursor');
  Rejected := False;
  try View.PushCursor(1234); except on ENativeCursorError do Rejected := True; end;
  Check(Rejected and (View.CursorDepth = 0) and (View.Cursor = crHourGlass), 'invalid push preserves state');
  Rejected := False;
  try View.PopCursor; except on ENativeCursorError do Rejected := True; end;
  Check(Rejected and (CurrentCursor = WaitCursor), 'empty pop preserves image');
  CursorMessage(Main.Handle, HTLEFT);
  Check((CurrentCursor <> WaitCursor) and (View.Cursor = crHourGlass), 'nonclient cursor remains under USER control');
  CursorMessage(Edit.Handle, HTCLIENT); View.Cursor := crDefault;
  Check(CurrentCursor = Arrow, 'default restores child override');
  Edit.Cursor := crDefault; Check(CurrentCursor = Cross, 'child default restores parent override');
  Main.Cursor := crDefault; Check(CurrentCursor = Beam, 'parent default restores native EDIT cursor');
end;
procedure RegistryAndOwnership;
begin
  FillChar(MaskAND, SizeOf(MaskAND), $FF); FillChar(MaskXOR, SizeOf(MaskXOR), 0);
  Custom := CreateCursor(HInstance, 0, 0, 32, 32, @MaskAND, @MaskXOR);
  Check(Custom <> 0, 'private borrowed cursor created');
  View.Cursors[-26] := Custom; View.Cursor := -26;
  Check((View.Cursors[-26] = Custom) and (CurrentCursor = Custom), 'legacy negative custom cursor ID');
  View.PushCursor(crHourGlass); Rejected := False;
  try View.Cursors[-26] := 0; except on ENativeCursorError do Rejected := True; end;
  Check(Rejected and (View.CursorDepth = 1), 'saved custom cursor cannot be removed');
  View.PopCursor; Rejected := False;
  try View.Cursors[-26] := Cross; except on ENativeCursorError do Rejected := True; end;
  Check(Rejected and (CurrentCursor = Custom), 'active custom cursor cannot be replaced');
  View.Cursor := crDefault; View.Cursors[-26] := 0;
  Check(DestroyCursor(Custom), 'caller retains borrowed cursor destruction'); Custom := 0;
  View.Cursors[77] := Cross; Edit.Cursor := 77;
  Check(CurrentCursor = Cross, 'control resolves registered custom cursor');
  View.Cursors[77] := 0; CursorMessage(Edit.Handle, HTCLIENT);
  Check(CurrentCursor = Beam, 'removed control cursor safely falls back to USER'); Edit.Cursor := crDefault;
  Rejected := False;
  try Other.Cursor := crCross; except on ENativeCursorError do Rejected := True; end;
  Check(Rejected and (Other.Cursor = crDefault), 'second screen cannot steal cursor controller');
  View.DisableCursors; Other.Cursor := crCross;
  Check(CurrentCursor = Cross, 'explicit release permits controller handoff'); Other.DisableCursors;
end;
procedure ScopeAndCleanup;
begin
  Foreign := TNativeForm.Create(nil); Foreign.SetBounds(320, 20, 180, 120); Foreign.Show;
  BringWindowToTop(Foreign.Handle); PointAt(Foreign.Handle, 10, 10); WinProcs.SetCursor(Arrow);
  View.Cursor := crHourGlass; CursorMessage(Foreign.Handle, HTCLIENT);
  Check(CurrentCursor = Arrow, 'unregistered window does not receive screen override');
  PointAt(Edit.Handle, 10, 10); Edit.MouseCapture := True;
  Check(CursorTarget = Edit.Handle, 'capture selects owning cursor target');
  CursorMessage(Edit.Handle, HTCLIENT); Check(CurrentCursor = WaitCursor, 'captured managed cursor remains scoped');
  Edit.MouseCapture := False; Foreign.Free; Foreign := nil;
  BringWindowToTop(Main.Handle); PointAt(Main.Handle, 10, 100); Main.Reenter := True;
  View.PushCursor(crCross); Main.Reenter := False;
  Check((Main.Rejections > 0) and (View.CursorDepth = 1) and (View.Cursor = crCross) and
    (Main.CallbackErrors = 0), 'cursor mutation from hit-test callback is rejected'); View.PopCursor;
  PointAt(Edit.Handle, 10, 10); View.PushCursor(crCross); View.Application := nil;
  Check((View.Cursor = crDefault) and (View.CursorDepth = 0) and (CurrentCursor = Beam), 'detach clears stack and restores native cursor');
  View.Application := App; View.Cursor := crHourGlass;
  Custom := CreateCursor(HInstance, 0, 0, 32, 32, @MaskAND, @MaskXOR); View.Cursors[88] := Custom;
  View.Free; View := nil; Check(CurrentCursor = Beam, 'view destruction restores hovered control');
  Check(DestroyCursor(Custom), 'registered cursor survives view destruction'); Custom := 0;
  View := TNativeScreen.Create(nil); View.Application := App;
  View.PushCursor(crHourGlass); App.Free; App := nil; Main := nil; Edit := nil;
  Check((View.Application = nil) and (View.Cursor = crDefault) and (View.CursorDepth = 0), 'application destruction cancels cursor policy');
end;
procedure Stress;
begin
  PointAt(Edit.Handle, 10, 10); BeforeGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
  BeforeUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
  for I := 1 to 50 do begin View.PushCursor(crHourGlass); View.PushCursor(crNone); View.PopCursor; View.PopCursor; end;
  Check((View.CursorDepth = 0) and (GetFreeSystemResources(GFSR_GDIRESOURCES) >= BeforeGDI - 2) and
    (GetFreeSystemResources(GFSR_USERRESOURCES) >= BeforeUSER - 2), 'cursor nesting retains GDI and USER resources');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native cursor policy');
  try Setup; PriorityAndStack; RegistryAndOwnership; Stress; ScopeAndCleanup;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Other.Free; View.Free; Foreign.Free; App.Free;
  if Custom <> 0 then DestroyCursor(Custom);
  SetCursorPos(SavedPosition.X, SavedPosition.Y); WinProcs.SetCursor(Arrow);
  I := ShowCursor(True); ShowCursor(False); Check(I = BeforeShow, 'cursor display count is unchanged');
  Check(StackGuardIntact, 'cursor stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
