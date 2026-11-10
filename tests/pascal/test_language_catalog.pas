program TestLanguageCatalog;
{$mode delphi}{$H-}
uses language_catalog, header_sections;
var Before: LongInt; I: Integer;
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
  Check(ReadConfiguration('tests/fixtures/catalog_sections.ini', 'first', 'key', '') = 'one',
    'key in the first section');
  Check(ReadConfiguration('tests/fixtures/catalog_sections.ini', 'second', 'later', '') = 'two',
    'key in a later section');
  { As GetPrivateProfileString: the first section of a name counts, so a
    lookup stops reading where that section ends. }
  Check(ReadConfiguration('tests/fixtures/catalog_sections.ini', 'first', 'later', 'none') = 'none',
    'a lookup ends with its section');
  { A catalogue is read once into an index; lookups follow it with the same
    rules: the first section of a name and the first key in it count. }
  Check(ConfigureLanguage('build/tests/fpc/lang', 'xx'), 'load the fixture catalogue');
  Before := CatalogueScans;
  for I := 1 to 50 do
    Check(LanguageText('first', 'KEY', '') = 'one', 'the first key counts, in any case');
  Check(CatalogueScans - Before <= 1, 'a catalogue is read once for many lookups');
  Check(LanguageText('first', 'later', 'none') = 'none', 'a repeated section is ignored');
  Check(LanguageText('second', 'later', '') = 'two', 'a line ending in LF alone');
  Check(LanguageText('second', 'unix', '') = 'lf', 'the line after it');
  Check(LanguageText('first', 'Escaped', '') = 'a'#13#10'b', 'escapes are decoded');
  Check(LanguageText('last', 'end', '') = 'no newline', 'the last line without an end');
  Check(LanguageText('missing', 'key', 'default') = 'default', 'an unknown section');
  Check(HeaderSectionAt(10, [40, 80], 3) = 0, 'first header');
  Check(HeaderSectionAt(50, [40, 80], 3) = 1, 'second header');
  Check(HeaderSectionAt(40, [40, 80], 3) = -1, 'divider is not a click');
  Check(HeaderSectionAt(-1, [40, 80], 3) = -1, 'negative coordinate');
  WriteLn('language/header tests: OK');
end.
