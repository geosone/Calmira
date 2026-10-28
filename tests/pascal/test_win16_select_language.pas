program SelectLanguageTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Select, select_dfm, form_text, form_catalog;
type TD = object
  Calls: Integer;
  Valid: Boolean;
  procedure Selection(Sender: TObject; const Mask: string; Selecting: Boolean);
end;
var Dialog: TSelectFileDlg; Catalog: TFormTextCatalog; Previous: TFormTextProvider;
  Driver: TD; Failed: Boolean;
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10;
  _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure TD.Selection(Sender: TObject; const Mask: string; Selecting: Boolean);
begin
  Inc(Calls); Valid := Valid and (Sender = Dialog) and Selecting and
    ((Mask = '*.pas') or (Mask = '*.txt'));
end;
procedure Pump;
var M: TMsg; I: Integer;
begin
  for I := 1 to 100 do
    if PeekMessage(M, 0, 0, 0, PM_REMOVE) then
    begin
      if M.message = WM_QUIT then raise Exception.Create('quit');
      if not Dialog.ProcessDialogMessage(M) then begin TranslateMessage(M); DispatchMessage(M); end;
    end;
end;
procedure Alt(Key: Char);
begin PostMessage(GetFocus, WM_SYSCHAR, Ord(Key), $20000001); Pump; end;
procedure Language(const Code, Title, LabelText, SelectText, DeselectText, CloseText: string;
  LabelKey, SelectKey: Char);
var Buffer: array[0..255] of Char;
begin
  Check(Catalog.SelectLanguage(Code), Code);
  Dialog := TSelectFileDlg.Create(nil);
  try
    Check((Dialog.Caption = Title) and (Dialog.Label1.Caption = LabelText) and
      (Dialog.SelectBtn.Caption = SelectText) and (Dialog.DeselectBtn.Caption = DeselectText) and
      (Dialog.CloseBtn.Caption = CloseText), 'captions');
    Dialog.Show; SetActiveWindow(Dialog.Handle); GetWindowText(Dialog.Handle, Buffer, SizeOf(Buffer));
    Check((StrPas(Buffer) = Title) and Dialog.Edit.Focused, 'native');
    Dialog.SelectBtn.SetFocus; Alt(LabelKey); Check(Dialog.Edit.Focused, 'localized label');
    Dialog.Edit.Text := '*.PAS;*.TXT'; Driver.Calls := 0; Driver.Valid := True;
    Dialog.OnSelectFiles := Driver.Selection; Alt(SelectKey);
    Check((Driver.Calls = 2) and Driver.Valid and Dialog.Visible, 'localized action');
    PostMessage(Dialog.Edit.Handle, WM_KEYDOWN, VK_ESCAPE, 1); Pump;
    Check(not Dialog.Visible, 'Escape');
    Dialog.DestroyHandle; Dialog.Show; Alt(SelectKey);
    Check((Driver.Calls = 4) and Driver.Valid, 'recreate');
    Dialog.Hide; Dialog.Edit.Free;
    Check((Dialog.Edit = nil) and (Dialog.InitialControl = nil) and
      (Dialog.Label1.FocusControl = nil), 'public field lifetime');
  finally Dialog.Free; Dialog := nil; end;
end;
begin
  LogLine('STEP select languages'); FillChar(Driver, SizeOf(Driver), 0);
  try
    Catalog := TFormTextCatalog.Create('C:\'); Previous := SetFormTextProvider(Catalog.Translate);
    try
      Language('de', 'Dateien ausw'#228'hlen', '&Datei(en):', '&Ausw'#228'hlen', '&Aufheben',
        '&Schlie'#223'en', 'd', 'a');
      Language('fr', 'S'#233'lection de fichiers', '&Fichier(s) :', '&S'#233'lect.', '&D'#233'select.',
        '&Fermer', 'f', 's');
      Language('en', 'Select Files', '&File(s):', '&Select', '&Deselect', '&Close', 'f', 's');
    finally SetFormTextProvider(Previous); end;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Catalog.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
