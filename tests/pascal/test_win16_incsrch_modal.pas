program TestWin16IncSearchModal;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Controls, Incsrch;
type
  TObserver = class
    Key: Word;
    Calls: Integer;
    Last: string;
    Blocked: Boolean;
    procedure Shown(Sender: TObject);
    procedure Search(Sender: TObject; const Text: string);
  end;
var Dialog: TIncSearchDlg; Owner: TCustomControl; Observer: TObserver;
  Failed: Boolean; Before: Integer;
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
procedure TObserver.Search(Sender: TObject; const Text: string);
begin
  Inc(Calls); Last := Text;
  if (Key = VK_RETURN) and (Text = 'qw') then
  begin
    PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, VK_RETURN, 1);
    PostMessage(Dialog.Edit.Handle, WM_KEYUP, VK_RETURN, LongInt($C0000001));
  end;
end;
procedure TObserver.Shown(Sender: TObject);
begin
  Dialog.FormShow(Sender);
  Blocked := not IsWindowEnabled(Owner.Handle) and Dialog.ModalRunning and
    (GetParent(Dialog.Handle) = Owner.Handle);
  if Key = VK_RETURN then
  begin
    PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, Ord('W'), $00110001);
    PostMessage(Dialog.Edit.Handle, WM_KEYUP, Ord('W'), LongInt($C0110001));
  end
  else
  begin
    PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, Key, 1);
    PostMessage(Dialog.Edit.Handle, WM_KEYUP, Key, LongInt($C0000001));
  end;
end;
begin
  LogLine('STEP original modal search');
  try
    Owner := TCustomControl.Create(nil);
    Owner.CreateHandle(0, 'Owner', WS_OVERLAPPEDWINDOW or WS_VISIBLE, 0, 0, 220, 140);
    SetActiveWindow(Owner.Handle); Owner.SetFocus;
    Dialog := TIncSearchDlg.Create(nil); Observer := TObserver.Create;
    Dialog.OnSearch := Observer.Search; Dialog.OnShow := Observer.Shown;
    Dialog.InitialChar := 'Q'; Observer.Key := VK_RETURN;
    Check((Dialog.ShowModal = mrCancel) and Observer.Blocked and
      IsWindowEnabled(Owner.Handle) and (GetFocus = Owner.Handle), 'modal owner restored');
    Check((Observer.Last = 'qw') and (Observer.Calls = 2) and not Dialog.Visible,
      'original search and Enter');
    Dialog.InitialChar := #0; Observer.Key := VK_ESCAPE; Before := Observer.Calls;
    Check((Dialog.ShowModal(Owner.Handle) = mrCancel) and (Dialog.Edit.Text = '') and
      (Observer.Calls = Before + 1) and not Dialog.ModalRunning, 'empty modal Escape');
    Dialog.DestroyHandle; Dialog.InitialChar := 'R';
    Check((Dialog.ShowModal(Owner.Handle) = mrCancel) and (Dialog.Edit.Text = 'r') and
      IsWindowEnabled(Owner.Handle), 'modal recreation');
    Check((Dialog.CallbackErrors = 0) and (Dialog.Edit.CallbackErrors = 0), 'no callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Dialog.Free; Owner.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
