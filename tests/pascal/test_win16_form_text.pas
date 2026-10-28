program TestWin16FormText;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Incsrch, incsrch_dfm, form_text, form_catalog;
var Dialog: TIncSearchDlg; Catalog: TFormTextCatalog;
  Previous: TFormTextProvider; Failed, Rejected: Boolean;
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
procedure CheckDialog(const Title, LabelText: string);
var Buffer: array[0..255] of Char;
begin
  Dialog := TIncSearchDlg.Create(nil);
  try
    Check((Dialog.Caption = Title) and (Dialog.Label1.Caption = LabelText), 'captions');
    Dialog.Show; GetWindowText(Dialog.Handle, Buffer, SizeOf(Buffer));
    Check((StrPas(Buffer) = Title) and Dialog.Edit.Focused, 'title/focus');
    Dialog.Hide; Dialog.DestroyHandle; Dialog.Show;
    GetWindowText(Dialog.Handle, Buffer, SizeOf(Buffer));
    Check(StrPas(Buffer) = Title, 'recreate');
  finally Dialog.Free; Dialog := nil; end;
end;
begin
  LogLine('STEP DFM languages');
  try
    Catalog := TFormTextCatalog.Create('C:\');
    Previous := SetFormTextProvider(Catalog.Translate);
    try
      Check(Catalog.SelectLanguage('DE'), 'de');
      CheckDialog('Zus'#228'tzliche Suche', 'Suche:');
      Check(Catalog.SelectLanguage('fr'), 'fr');
      CheckDialog('Recherche incr'#233'mentale', 'Rechercher :');
      Check(Catalog.SelectLanguage('en'), 'en');
      CheckDialog('Incremental search', 'Find:');
      Check(not Catalog.SelectLanguage('../de'), 'path');
      Check(FormText('TIncSearchDlg', 'Label1', 'Caption', '?') = 'Find:', 'reset');
      Check(FormText('Missing', 'Missing', 'Caption', 'fallback') = 'fallback', 'missing');
      Check(Catalog.SelectLanguage('probe'), 'probe');
      Check(FormText('Probe', 'Empty', 'Caption', 'fallback') = '', 'empty');
      Check((FormText('Probe', 'Marker', 'Caption', '?') = '!missing1!') and
        (FormText('Probe', 'Marker2', 'Caption', '?') = '!missing2!'), 'markers');
      Check(FormText('Probe', 'Escapes', 'Caption', '?') = 'a'#13#10'b'#9'c\d\q', 'escapes');
      Check(FormText('TIncSearchDlg', 'Label1', 'Caption', '?') = 'Find:', 'fallback');
      Rejected := False;
      try FormText('Probe', 'Long', 'Caption', '?'); except on Exception do Rejected := True; end;
      Check(Rejected, 'truncation');
      Rejected := False;
      try FormText('Probe', 'Expand', 'Caption', '?'); except on Exception do Rejected := True; end;
      Check(Rejected, 'overflow');
    finally SetFormTextProvider(Previous); end;
    Check(FormText('Any', 'Any', 'Caption', 'plain') = 'plain', 'restored');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Catalog.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
