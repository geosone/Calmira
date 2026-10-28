program TestWin16IncSearch;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Controls, Incsrch, incsrch_dfm, native_loop;
type
  TObserver = class
    Calls: Integer;
    Last: string;
    procedure Search(Sender: TObject; const Text: string);
  end;
var Dialog: TIncSearchDlg; Loop: TNativeMessageLoop; Observer: TObserver;
  Failed: Boolean; I, Before, PoolUser: Integer; Area: TRect;
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
  if Sender <> Dialog then raise Exception.Create('sender');
  Inc(Calls); Last := Text;
end;
procedure Key(Value: Word; Scan: LongInt);
begin
  PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, Value, Scan);
  PostMessage(Dialog.Edit.Handle, WM_KEYUP, Value, Scan or LongInt($C0000000));
  Loop.ProcessMessages(100);
end;
begin
  LogLine('STEP search');
  try
    Dialog := TIncSearchDlg.Create(nil); Observer := TObserver.Create;
    Loop := TNativeMessageLoop.Create; Loop.OnMessage := Dialog.ProcessDialogMessage;
    Dialog.OnSearch := Observer.Search; Dialog.Show;
    Check(Dialog.Visible and (Dialog.Edit.Text = '') and (Dialog.Edit.SelStart = 0) and
      (Observer.Calls = 0), 'empty');
    Dialog.Hide; Dialog.InitialChar := 'Q'; Dialog.Show;
    SetActiveWindow(Dialog.Handle); Loop.ProcessMessages(100);
    Check((Dialog.Edit.Text = 'q') and (Observer.Last = 'q') and (Observer.Calls = 1),
      'initial');
    Check(Dialog.Edit.Focused and (Dialog.Edit.SelStart = 1) and (Dialog.Edit.SelLength = 0),
      'focus');
    GetClientRect(Dialog.Handle, Area);
    Check((Area.Right = 171) and (Area.Bottom = 41) and
      (Dialog.Edit.Left = 40) and (Dialog.Edit.Top = 10) and (Dialog.Label1.Caption = 'Find:'),
      'bounds');
    Before := Observer.Calls; Key(Ord('W'), $00110001);
    Check((Dialog.Edit.Text = 'qw') and (Observer.Last = 'qw') and (Observer.Calls = Before + 1),
      'search');
    Key(VK_RETURN, $001C0001);
    Check(not Dialog.Visible and not Loop.Terminated, 'Enter');
    Dialog.InitialChar := 'Z'; Dialog.Show; Loop.ProcessMessages(100);
    Check((Dialog.Edit.Text = 'z') and (Observer.Last = 'z') and Dialog.Edit.Focused,
      'reuse');
    Key(VK_ESCAPE, $00010001);
    Check(not Dialog.Visible and not Loop.Terminated, 'Escape');
    Dialog.DestroyHandle; Before := Observer.Calls; Dialog.InitialChar := 'R'; Dialog.Show;
    Check((Dialog.Edit.Text = 'r') and (Observer.Last = 'r') and (Observer.Calls = Before + 1),
      'recreate');
    Dialog.Edit.Perform(WM_CHAR, Ord('T'), 1);
    Check((Dialog.Edit.Text = 'rt') and (Observer.Last = 'rt'), 'case');
    Dialog.Hide; PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 30 do
    begin Dialog.DestroyHandle; Dialog.InitialChar := 'S'; Dialog.Show; Dialog.Hide; end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2, 'resources');
    Check((Dialog.CallbackErrors = 0) and (Dialog.Edit.CallbackErrors = 0), 'callbacks');
    Dialog.Label1.FocusControl := Dialog.Edit;
    Dialog.Edit.Free;
    Check((Dialog.Edit = nil) and (Dialog.InitialControl = nil) and
      (Dialog.Label1.FocusControl = nil), 'field lifetime');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Loop <> nil then Loop.OnMessage := nil;
  Dialog.Free; Loop.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
