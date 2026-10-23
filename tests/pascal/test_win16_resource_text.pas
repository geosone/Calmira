program ResourceTextTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Locale, resource_text, form_catalog;
type TD = object
  function Invalid(Ident: Word; const DefaultText: string): string;
end;
var Catalog: TFormTextCatalog; Previous, Active: TResourceTextProvider; Driver: TD;
  Failed, Rejected: Boolean;
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
function TD.Invalid(Ident: Word; const DefaultText: string): string;
begin Result := 'a'#0'b'; end;
begin
  LogLine('STEP numeric resource catalogues'); FillChar(Driver, SizeOf(Driver), 0);
  try
    Check(LocalLoadStr(SCreateNewUser) = 'Create new user', 'bound string resource');
    Catalog := TFormTextCatalog.Create('C:\'); Previous := SetResourceTextProvider(Catalog.TranslateResource);
    try
      Check(Catalog.SelectLanguage('de') and (LocalLoadStr(SCreateNewUser) = 'Neuen Benutzer anlegen'), 'de');
      Check(Catalog.SelectLanguage('fr') and (LocalLoadStr(SCreateNewUser) = 'Cr'#233'er un nouvel utilisateur'), 'fr');
      Check(Catalog.SelectLanguage('probe'), 'probe');
      Check(LocalLoadStr(SCreateNewUser) = 'probe resource', 'provider overrides bound');
      Check(Catalog.TranslateResource(SUserName, '?') = 'User name:', 'English fallback');
      Check(Catalog.TranslateResource(60006, 'bound') = 'bound', 'caller fallback');
      Check(LocalLoadStr(60000) = '', 'explicit empty');
      Check((LocalLoadStr(60002) = '!missing1!') and (LocalLoadStr(60005) = '!missing2!'), 'markers');
      Check(LocalLoadStr(60001) = 'a'#13#10'b'#9'c\d\q', 'escapes');
      Rejected := False; try LocalLoadStr(60003); except on Exception do Rejected := True; end;
      Check(Rejected, 'truncation');
      Rejected := False; try LocalLoadStr(60004); except on Exception do Rejected := True; end;
      Check(Rejected, 'decoded overflow');
      Active := SetResourceTextProvider(Driver.Invalid);
      try
        Rejected := False; try LocalLoadStr(SUserName); except on Exception do Rejected := True; end;
        Check(Rejected, 'provider NUL');
      finally SetResourceTextProvider(Active); end;
    finally SetResourceTextProvider(Previous); end;
    Check(LocalLoadStr(SCreateNewUser) = 'Create new user', 'restored bound fallback');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Catalog.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
