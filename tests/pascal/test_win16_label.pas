program TestWin16Label;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls, StdCtrls;
type
  TInk = record Count, Left, Top, Right, Bottom: Integer; end;
  TObserver = class
    Calls: Integer;
    Reenter, FailEvent, Complete: Boolean;
    procedure Changed(Sender: TObject);
  end;
var Window: TCustomControl; LabelControl: TLabel; OtherFont, EventFont: TFont;
  Observer: TObserver; Failed, Rejected: Boolean; Ink, LeftInk, RightInk: TInk;
  I, Before, PoolGDI, PoolUSER: Integer;
{$I win16_stack_guard.inc}
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
function Scan(Color: TColor): TInk;
var DC: HDC; X, Y: Integer;
begin
  Result.Count := 0; Result.Left := 240; Result.Top := 180;
  Result.Right := -1; Result.Bottom := -1;
  DC := GetDC(Window.Handle);
  if DC = 0 then raise Exception.Create('Cannot inspect label pixels');
  try
    for Y := 8 to 87 do for X := 8 to 127 do
      if GetPixel(DC, X, Y) = DWORD(ColorToRGB(Color)) then
      begin
        Inc(Result.Count);
        if X < Result.Left then Result.Left := X;
        if X > Result.Right then Result.Right := X;
        if Y < Result.Top then Result.Top := Y;
        if Y > Result.Bottom then Result.Bottom := Y;
      end;
  finally ReleaseDC(Window.Handle, DC); end;
end;
procedure Flush;
begin UpdateWindow(Window.Handle); end;
procedure TObserver.Changed(Sender: TObject);
begin
  Inc(Calls); Complete := (Sender = EventFont) and (EventFont.Handle <> 0);
  if Reenter then EventFont.Style := [fsBold];
  if FailEvent then raise Exception.Create('font notification failure');
end;
begin
  FillChar(StackBottom^, 64, $A5);
  LogLine('STEP real StdCtrls label and font notifications');
  try
    Window := TCustomControl.Create(nil); Window.Color := clWhite;
    Window.CreateHandle(0, 'Label probe', WS_POPUP or WS_VISIBLE, 20, 20, 240, 180);
    LabelControl := TLabel.Create(nil); LabelControl.Color := clWhite;
    { Alignment, wrapping and prefixes are drawn within fixed bounds. }
    LabelControl.AutoSize := False;
    LabelControl.SetBounds(8, 8, 120, 30); LabelControl.Font.Color := clRed;
    LabelControl.Font.Height := -16; LabelControl.Caption := 'MMM'; LabelControl.Parent := Window;
    Window.Repaint; LeftInk := Scan(clRed);
    Check((GetWindow(Window.Handle, GW_CHILD) = 0) and (LeftInk.Count > 0) and
      (LeftInk.Left < 14), 'windowless label paints real left-aligned ANSI glyphs');
    LabelControl.Alignment := taRightJustify; Flush; RightInk := Scan(clRed);
    Check((RightInk.Count > 0) and (RightInk.Left > LeftInk.Left + 40) and (RightInk.Right < 128),
      'right alignment repositions glyphs within clipped label bounds');
    LabelControl.Alignment := taCenter; Flush; Ink := Scan(clRed);
    Check((Ink.Left > LeftInk.Left) and (Ink.Left < RightInk.Left),
      'center alignment lies between left and right renderings');
    LabelControl.Font.Color := clBlue; Flush; Ink := Scan(clRed); LeftInk := Scan(clBlue);
    Check((Ink.Count = 0) and (LeftInk.Count > 0), 'direct font color change invalidates label and erases old glyphs');
    Check(LabelControl.Enabled, 'graphic controls default to enabled');
    LabelControl.Enabled := False; Flush; Ink := Scan(clBlue);
    RightInk := Scan(GetSysColor(COLOR_GRAYTEXT));
    Check((Ink.Count = 0) and (RightInk.Count > 0) and
      (LabelControl.Font.Color = clBlue) and LabelControl.Visible,
      'disabled label paints system gray without changing font or visibility');
    LabelControl.Font.Color := clRed; Flush; Ink := Scan(clRed);
    Check((Ink.Count = 0) and (LabelControl.Font.Color = clRed),
      'disabled font changes stay stored without painting enabled color');
    LabelControl.Enabled := True; Flush; Ink := Scan(clRed);
    Check(Ink.Count > 0, 'reenabling label restores latest stored font color');
    LabelControl.Hide; LabelControl.Enabled := False; Flush;
    Ink := Scan(GetSysColor(COLOR_GRAYTEXT));
    Check((Ink.Count = 0) and not LabelControl.Visible,
      'disabling hidden graphic does not show it');
    LabelControl.Show; Flush; Ink := Scan(GetSysColor(COLOR_GRAYTEXT));
    Check((Ink.Count > 0) and not LabelControl.Enabled,
      'showing disabled label preserves disabled appearance');
    LabelControl.Enabled := True; LabelControl.Font.Color := clBlue;
    LabelControl.Caption := ''; Flush; Ink := Scan(clBlue);
    Check(Ink.Count = 0, 'empty caption erases previous label text');
    LabelControl.Alignment := taLeftJustify; LabelControl.SetBounds(8, 8, 50, 80);
    LabelControl.Caption := 'MMMM MMMM MMMM'; LabelControl.WordWrap := False; Flush;
    LeftInk := Scan(clBlue); LabelControl.WordWrap := True; Flush; RightInk := Scan(clBlue);
    Check((RightInk.Count > 0) and (RightInk.Bottom > LeftInk.Bottom + 10),
      'word wrap produces actual additional native text lines');
    LabelControl.SetBounds(8, 8, 120, 80); LabelControl.WordWrap := False;
    LabelControl.Caption := 'M'#13#10'M'; Flush; Ink := Scan(clBlue);
    Check(Ink.Bottom > LeftInk.Bottom + 10, 'explicit CRLF preserves multiline rendering without word wrap');
    LabelControl.Caption := '&M'; LabelControl.ShowAccelChar := True; Flush; LeftInk := Scan(clBlue);
    LabelControl.ShowAccelChar := False; Flush; RightInk := Scan(clBlue);
    Check(RightInk.Right > LeftInk.Right, 'ShowAccelChar switches between mnemonic prefix and literal ampersand');
    OtherFont := TFont.Create; OtherFont.Color := clLime; OtherFont.Height := -20;
    LabelControl.Font := OtherFont; OtherFont.Color := clRed; OtherFont.Free; OtherFont := nil;
    Flush; Ink := Scan(clLime);
    Check((LabelControl.Font.Color = clLime) and (LabelControl.Font.Height = -20) and
      (Ink.Count > 0), 'font assignment deep-copies state and survives source destruction');
    Rejected := False;
    try LabelControl.Font := nil; except on Exception do Rejected := True; end;
    Check(Rejected and (LabelControl.Font.Color = clLime), 'nil font assignment preserves owned font');
    Rejected := False;
    try LabelControl.Caption := 'bad'#0'caption'; except on Exception do Rejected := True; end;
    Check(Rejected and (LabelControl.Caption = '&M'), 'NUL caption is rejected without losing stored label text');
    EventFont := TFont.Create; Observer := TObserver.Create; EventFont.OnChange := Observer.Changed;
    EventFont.Color := clRed;
    Check((Observer.Calls = 1) and Observer.Complete, 'font event observes completed state and usable native handle');
    EventFont.Color := clRed; EventFont.Assign(EventFont);
    Check(Observer.Calls = 1, 'same-value font setter and self-assign emit no notification');
    Observer.Reenter := True; EventFont.Height := -20;
    Check((Observer.Calls = 2) and (fsBold in EventFont.Style), 'font notification suppresses recursion while retaining nested state change');
    Observer.Reenter := False; Observer.FailEvent := True; Rejected := False;
    try EventFont.Color := clBlue; except on Exception do Rejected := True; end;
    Observer.FailEvent := False; Before := Observer.Calls; EventFont.Color := clRed;
    Check(Rejected and (Observer.Calls = Before + 1) and (EventFont.Color = clRed),
      'font event exception propagates after releasing notification guard');
    OtherFont := TFont.Create; OtherFont.Name := 'Courier New'; OtherFont.Height := -18;
    OtherFont.Color := clLime; Before := Observer.Calls; EventFont.Assign(OtherFont);
    EventFont.Assign(OtherFont);
    Check((Observer.Calls = Before + 1) and (EventFont.Name = 'Courier New') and
      (EventFont.Color = clLime), 'changed font Assign emits once after full copy and identical Assign stays quiet');
    Before := Observer.Calls; Rejected := False;
    try EventFont.Size := -1; except on Exception do Rejected := True; end;
    Check(Rejected and (Observer.Calls = Before), 'invalid font size emits no change event');
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 0 to 100 do
    begin
      LabelControl.Enabled := not Odd(I);
      if Odd(I) then LabelControl.Font.Color := clRed else LabelControl.Font.Color := clBlue;
      LabelControl.Font.Height := -12 - I mod 5; Flush;
    end;
    Check((Window.CallbackErrors = 0) and (LabelControl.Canvas.Handle = 0),
      'label redraws finish without callback errors or retained DC');
    Check((GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2) and
      (GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2),
      'font replacement and label rendering retain GDI and USER resources');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Check(StackGuardIntact, 'label stack boundary');
  LabelControl.Free; Window.Free; EventFont.Free; OtherFont.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
