program TestWin16CommonDialogs;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, Forms, Dialogs, CommDlg;
type
  { Answers the next modal dialog from a timer, which the dialog's own
    message loop dispatches. }
  TDriver = class
    Window: HWND;
    Command: Word;
    FileText, Caption: string;
    OwnerDisabled: Boolean;
    procedure WndProc(var Msg: TMessage);
    procedure Arm(ACommand: Word; const AFileText: string);
  end;
var Driver: TDriver; Main: TForm; Open: TOpenDialog; Save: TSaveDialog; Color: TColorDialog;
  Font: TFontDialog; Failed, Raised, Okay: Boolean; Saved: string;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TDriver.Arm(ACommand: Word; const AFileText: string);
begin
  Command := ACommand; FileText := AFileText; Caption := ''; OwnerDisabled := False;
  SetTimer(Window, 1, 400, nil);
end;
procedure TDriver.WndProc(var Msg: TMessage);
var Dialog: HWND; Buf: array[0..255] of Char;
begin
  if Msg.Msg <> WM_TIMER then
  begin
    Msg.Result := DefWindowProc(Window, Msg.Msg, Msg.WParam, Msg.LParam); Exit;
  end;
  KillTimer(Window, 1);
  Dialog := GetActiveWindow;
  GetWindowText(Dialog, Buf, SizeOf(Buf)); Caption := StrPas(Buf);
  OwnerDisabled := not IsWindowEnabled(Main.Handle);
  if FileText <> '' then SetDlgItemText(Dialog, edt1, StrPCopy(Buf, FileText));
  PostMessage(Dialog, WM_COMMAND, Command, 0);
  Msg.Result := 0;
end;
begin
  LogLine('STEP common dialogs');
  Driver := TDriver.Create;
  try
    Driver.Window := AllocateHWnd(Driver.WndProc);
    Main := TForm.Create(nil); Main.SetBounds(10, 10, 200, 100); Main.Caption := 'Owner'; Main.Show;
    SetActiveWindow(Main.Handle);

    Open := TOpenDialog.Create(nil);
    Check((Open.FilterIndex = 1) and (Open.Options = []) and (Open.FileEditStyle = fsEdit) and Open.Ctl3D,
      'TOpenDialog has Delphi''s defaults');
    Open.Title := 'Pick a log'; Open.Filter := 'Logs|*.LOG|All files|*.*'; Open.FilterIndex := 2;
    Open.InitialDir := 'C:\'; Open.Options := [ofFileMustExist, ofHideReadOnly];
    Driver.Arm(IDOK, 'C:\GDITEST.LOG');
    Okay := Open.Execute;
    Check(Okay and (AnsiUpperCase(Open.FileName) = 'C:\GDITEST.LOG'), 'Execute returns the chosen file');
    Check((Driver.Caption = 'Pick a log') and Driver.OwnerDisabled, 'the dialog shows Title and is modal to the active form');
    Check(IsWindowEnabled(Main.Handle), 'the owner is enabled again');
    Check((Open.Files.Count = 1) and (Open.Files[0] = Open.FileName) and (Open.FilterIndex = 2),
      'Files holds the single file; FilterIndex is kept');

    Saved := Open.FileName;
    Driver.Arm(IDCANCEL, '');
    Check(not Open.Execute and (Open.FileName = Saved), 'Cancel returns False and keeps FileName');

    Open.Options := [ofAllowMultiSelect, ofHideReadOnly]; Open.FileName := '';
    Driver.Arm(IDOK, 'C:\GDITEST.LOG');
    Okay := Open.Execute;
    Check(Okay and (Open.Files.Count = 1) and (AnsiUpperCase(Open.Files[0]) = 'C:\GDITEST.LOG'),
      'a single file in a multiple selection is one full path');
    Open.Free; Open := nil;

    Save := TSaveDialog.Create(nil);
    Save.DefaultExt := 'TXT';
    Driver.Arm(IDOK, 'C:\NEWFILE');
    Okay := Save.Execute;
    Check(Okay and (AnsiUpperCase(Save.FileName) = 'C:\NEWFILE.TXT'), 'TSaveDialog appends DefaultExt');
    Save.Free; Save := nil;

    Color := TColorDialog.Create(nil);
    Check((Color.Color = clBlack) and not Color.Ctl3D, 'TColorDialog has Delphi''s defaults');
    Color.Color := clRed; Color.CustomColors.Add('ColorA=123456');
    Driver.Arm(IDOK, '');
    Okay := Color.Execute;
    Check(Okay and (Color.Color = TColor($0000FF)), 'the color dialog starts at Color');
    Check((Color.CustomColors.Count = 16) and (Color.CustomColors.Values['ColorA'] = '123456') and
      (Color.CustomColors.Values['ColorP'] = 'FFFFFF'), 'custom colors go in and come back');
    Color.Free; Color := nil;

    Font := TFontDialog.Create(nil);
    Check((Font.Options = [fdEffects]) and (Font.Device = fdScreen), 'TFontDialog has Delphi''s defaults');
    Font.Font.Name := 'Arial'; Font.Font.Height := -13; Font.Font.Style := [fsBold]; Font.Font.Color := clBlue;
    Font.MinFontSize := 8; Font.MaxFontSize := 24;
    Driver.Arm(IDOK, '');
    Okay := Font.Execute;
    Check(Okay and (Font.Font.Name = 'Arial') and (fsBold in Font.Font.Style) and (Font.Font.Color = clBlue) and
      (Font.Font.Height < 0), 'the font dialog starts at Font and returns it');
    Font.Device := fdPrinter; Raised := False;
    try Font.Execute; except on EInvalidOperation do Raised := True; end;
    Check(Raised, 'printer fonts raise');
    Font.Free; Font := nil;

    Open := TOpenDialog.Create(nil);
    Open.FileEditStyle := fsComboBox; Raised := False;
    try Open.Execute; except on EInvalidOperation do Raised := True; end;
    Check(Raised, 'the combo-box file edit raises');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Open.Free; Save.Free; Color.Free; Font.Free; Main.Free;
  if Driver.Window <> 0 then DeallocateHWnd(Driver.Window);
  Driver.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
