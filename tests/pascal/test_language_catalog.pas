program TestLanguageCatalog;
{$mode delphi}{$H-}
uses language_catalog, header_sections;
procedure Check(Value: Boolean; const Text: string);
begin
  if not Value then begin WriteLn('FAIL: ', Text); Halt(1); end;
end;
begin
  InitializeLanguage('build/lang', 'tests/fixtures/language_settings.ini');
  Check(SelectedLanguage = 'fr', 'load selection from installed configuration');
  Check(ReadConfiguration('tests/fixtures/language_settings.ini', 'boot', 'shell', '') =
    'C:\tools\new\calmira.exe', 'INI paths are not catalogue escapes');
  Check(ConfigureLanguage('build/lang', 'de'), 'load German');
  Check(LanguageText('FileManager', 'Refresh', '') = 'Aktualisieren', 'German text');
  Check(ConfigureLanguage('build/lang', 'fr'), 'load French');
  Check(LanguageText('FileManager', 'Refresh', '') = 'Actualiser', 'French text');
  Check(not ConfigureLanguage('build/lang', '../de'), 'reject path traversal');
  Check(SelectedLanguage = 'en', 'English fallback');
  Check(LanguageText('FileManager', 'Refresh', '') = 'Refresh', 'English text');
  Check(LanguageText('Unknown', 'missing', 'default') = 'default', 'caller fallback');
  Check(HeaderSectionAt(10, [40, 80], 3) = 0, 'first header');
  Check(HeaderSectionAt(50, [40, 80], 3) = 1, 'second header');
  Check(HeaderSectionAt(40, [40, 80], 3) = -1, 'divider is not a click');
  Check(HeaderSectionAt(-1, [40, 80], 3) = -1, 'negative coordinate');
  WriteLn('language/header tests: OK');
end.
