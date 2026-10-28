program SelectTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Select, select_dfm, Controls, PicBtn;
type
  TD = object
    Calls, FailOnCall: Integer;
    Selected, SenderOkay: Boolean;
    Tokens: string;
    procedure Selection(Sender: TObject; const Mask: string; Selecting: Boolean);
  end;
  PD = ^TD;
var Dialog: TSelectFileDlg; Driver: PD; Failed, Rejected: Boolean; I, BeforeUSER, BeforeGDI: Integer;
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
procedure TD.Selection(Sender: TObject; const Mask: string; Selecting: Boolean);
begin
  Inc(Calls); Tokens := Tokens + Mask + '|'; Selected := Selecting;
  SenderOkay := Sender = Dialog;
  if Calls = FailOnCall then raise Exception.Create('selection');
end;
procedure Pump;
var M: TMsg; N: Integer;
begin
  for N := 1 to 100 do
    if PeekMessage(M, 0, 0, 0, PM_REMOVE) then
    begin
      if M.message = WM_QUIT then raise Exception.Create('quit');
      if not Dialog.ProcessDialogMessage(M) then begin TranslateMessage(M); DispatchMessage(M); end;
    end;
end;
procedure Alt(Key: Char);
begin PostMessage(GetFocus, WM_SYSCHAR, Ord(Key), $20000001); Pump; end;
procedure ResetCalls;
begin Driver^.Calls := 0; Driver^.Tokens := ''; Driver^.SenderOkay := False; end;
begin
  LogLine('STEP original select');
  try
    New(Driver); FillChar(Driver^, SizeOf(Driver^), 0);
    PicBtnGlyphs := False; Dialog := TSelectFileDlg.Create(nil);
    Dialog.OnSelectFiles := Driver^.Selection;
    Check((Dialog.Handle = 0) and not Dialog.Image.Picture.Empty and
      (Dialog.Label1.FocusControl = Dialog.Edit), 'DFM/create');
    Dialog.Show; SetActiveWindow(Dialog.Handle); BringWindowToTop(Dialog.Handle);
    Check(Dialog.Edit.Focused and (Dialog.Edit.Text = '*.*'), 'initial');
    Dialog.SelectBtn.SetFocus; Alt('f'); Check(Dialog.Edit.Focused, 'label mnemonic');
    Dialog.Edit.Text := '*.TXT;;;*.DOC;;'; ResetCalls; Alt('s');
    Check((Driver^.Calls = 2) and (Driver^.Tokens = '*.txt|*.doc|') and
      Driver^.Selected and Driver^.SenderOkay and Dialog.Visible, 'select');
    ResetCalls; Driver^.FailOnCall := 2; Rejected := False;
    try Dialog.SelectBtn.Click; except on Exception do Rejected := True; end;
    Check(Rejected and (Driver^.Calls = 2) and Dialog.Visible, 'callback error');
    Driver^.FailOnCall := 0; ResetCalls; Dialog.SelectBtn.Click;
    Check((Driver^.Calls = 2) and Driver^.SenderOkay, 'callback recovery');
    ResetCalls; Alt('d');
    Check((Driver^.Calls = 2) and not Driver^.Selected and Driver^.SenderOkay and
      (Driver^.Tokens = '*.txt|*.doc|') and Dialog.Visible, 'deselect');
    Dialog.Edit.Text := ''; ResetCalls; Dialog.SelectBtn.Click;
    Check((Driver^.Calls = 1) and (Driver^.Tokens = '|'), 'empty');
    Dialog.Edit.Text := ';;*.PAS'; ResetCalls; Dialog.SelectBtn.Click;
    Check((Driver^.Calls = 2) and (Driver^.Tokens = '|*.pas|'), 'leading delimiter');
    Alt('c'); Check(not Dialog.Visible, 'close mnemonic');
    Dialog.Show; PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, VK_ESCAPE, 1); Pump;
    Check(not Dialog.Visible, 'Escape');
    Dialog.DestroyHandle; Dialog.Show; ResetCalls; Alt('s');
    Check(Dialog.Visible and Driver^.SenderOkay and (Driver^.Calls = 2), 'recreate');
    Check((Dialog.CallbackErrors = 0) and (Dialog.Edit.CallbackErrors = 0), 'callbacks');
    Dialog.Free; Dialog := nil;
    BeforeUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    BeforeGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for I := 1 to 20 do
    begin
      PicBtnGlyphs := Odd(I); Dialog := TSelectFileDlg.Create(nil);
      Dialog.Show; Dialog.Free; Dialog := nil;
    end;
    Check((GetFreeSystemResources(GFSR_USERRESOURCES) >= BeforeUSER - 2) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= BeforeGDI - 2), 'resources');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Dialog.Free; if Driver <> nil then Dispose(Driver);
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
