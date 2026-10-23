program ADLanguage;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Askdrop, form_text, form_catalog;
var Dialog: TAskDropBox; Catalog: TFormTextCatalog; Previous: TFormTextProvider; Failed: Boolean;
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
procedure Language(const Code, Title, CancelText: string);
var Buffer: array[0..255] of Char;
begin
  Check(Catalog.SelectLanguage(Code), Code);
  Dialog := TAskDropBox.Create(nil);
  try
    Check((Dialog.Caption = Title) and (Dialog.BitBtn3.Caption = CancelText) and
      (FormText('TStandardButtons', 'Cancel', 'Caption', '?') = CancelText), 'captions');
    Dialog.Show; GetWindowText(Dialog.Handle, Buffer, SizeOf(Buffer));
    Check((StrPas(Buffer) = Title) and Dialog.BitBtn1.Focused, 'native');
    Dialog.Hide; Dialog.DestroyHandle; Dialog.Show;
    Check((Dialog.Caption = Title) and (Dialog.BitBtn3.Caption = CancelText), 'recreate');
  finally Dialog.Free; Dialog := nil; end;
end;
begin
  LogLine('STEP drop languages');
  try
    Catalog := TFormTextCatalog.Create('C:\'); Previous := SetFormTextProvider(Catalog.Translate);
    try
      Language('de', 'Objekte verschieben', 'Abbrechen');
      Language('fr', 'Glisser - D'#233'poser', 'Annuler');
      Language('en', 'Drag and Drop', 'Cancel');
    finally SetFormTextProvider(Previous); end;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Catalog.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
