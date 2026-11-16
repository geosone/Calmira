program LangUITest;
{ The form loaders take their texts from the selected catalogue while they
  load (form_language), before OnCreate sets run-time values. LangUI
  translates through RTTI, so Caption and Hint are published, as in Delphi. }
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Controls, Forms, StdCtrls, Buttons, LangUI, language_catalog, form_text, form_language;
type
  TAboutBox = class(TForm);
  TFileSysPropDlg = class(TForm);
var
  About: TAboutBox; FileSys: TFileSysPropDlg; Memory, Licence: TLabel; Filter: TEdit; Yes, Close: TBitBtn;
  Title, MemoryText, FilterHint: string; Buffer: array[0..255] of Char; Failed: Boolean;
{$I win16_stack_guard.inc}

const
  Codes: array[0..6] of string[2] = ('en', 'de', 'fr', 'nl', 'it', 'es', 'pl');
var
  Code: Integer;

{ The width of a text in a font, as Windows draws it on the screen. }
function TextPixels(const Text, Face: string; Height, Weight: Integer): Integer;
var DC: HDC; Font, Old: HFONT; Z: array[0..255] of Char; F: array[0..31] of Char;
begin
  DC := GetDC(0);
  Font := CreateFont(Height, 0, 0, 0, Weight, 0, 0, 0, ANSI_CHARSET, OUT_DEFAULT_PRECIS,
    CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH, StrPCopy(F, Face));
  Old := SelectObject(DC, Font);
  StrPCopy(Z, Text);
  TextPixels := LoWord(GetTextExtent(DC, Z, StrLen(Z)));
  SelectObject(DC, Old); DeleteObject(Font); ReleaseDC(0, DC);
end;
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
begin
  Failed := False;
  FillChar(StackBottom^, 64, $A5);
  try
    Check(ConfigureLanguage('C:\', 'de'), 'German catalogue');
    Title := LanguageText('Forms', 'TAboutBox.AboutBox.Caption', '');
    MemoryText := LanguageText('Forms', 'TAboutBox.Label3.Caption', '');
    FilterHint := LanguageText('Forms', 'TFileSysPropDlg.FilterEdit.Hint', '');
    Check((Title = 'Info') and (MemoryText = 'Arbeitsspeicher:') and (FilterHint <> ''),
      'catalogue has the German title, label and hint');
    Check(FormText('TAboutBox', 'Label3', 'Caption', 'Memory:') = MemoryText,
      'a loader gets the translated label caption');
    Check(FormText('TFileSysPropDlg', 'FilterEdit', 'Hint', 'List') = FilterHint,
      'a loader gets the translated hint');
    Check(FormText('TAboutBox', 'NoSuchLabel', 'Caption', 'Keep') = 'Keep',
      'a loader keeps texts the catalogue lacks');
    Check(FormText('TDeskPropDlg', 'TabPanel', 'Tabs.Strings.0', 'General') =
      LanguageText('Forms', 'TDeskPropDlg.TabPanel.Tabs.Strings.0', ''),
      'a loader gets translated list entries');
    Check(Format(LanguageText('Memory', 'Free', '%s free'), ['78,46 MB']) = '78,46 MB frei',
      'free memory is told in the catalogue language');
    Check(LanguageText('Desktop', 'MyDocuments', 'My Documents') = 'Eigene Dateien',
      'My Documents has its Windows XP name');
    Check((FormText('TTaskManager', 'Header', 'Sections.Strings.0', 'Task') = 'Programm') and
      (FormText('TTaskManager', 'Header', 'Sections.Strings.1', 'Module') = 'Dateiname'),
      'a loader gets the translated column titles of a header');
    Check((Format(LanguageText('TaskManager', 'OneTask', '%d task'), [1]) = '1 Prozess') and
      (Format(LanguageText('TaskManager', 'Tasks', '%d tasks'), [3]) = '3 Prozesse'),
      'the Task Manager counts its tasks in the catalogue language');
    Check((LanguageText('Menu', 'MS-DOS Prompt', '') = 'MS-DOS-Eingabeaufforderung') and
      (LanguageText('Menu', 'Auto start your', '') = 'Programme hier') and
      (LanguageText('Menu', 'programs here.', '') = 'automatisch starten.'),
      'the entries of the default Start menu are translated');
    About := TAboutBox.CreateNew(nil);
    try
      About.Name := 'AboutBox'; About.Caption := 'About'; About.SetBounds(40, 40, 200, 120);
      Memory := TLabel.Create(About); Memory.Name := 'Label3'; Memory.Parent := About;
      Memory.Caption := 'Memory:';
      { The About box's licence note: a German text needs a third line. }
      Licence := TLabel.Create(About); Licence.Name := 'LicenceLabel'; Licence.Parent := About;
      Licence.Font.Name := 'MS Sans Serif'; Licence.Font.Height := -11;
      Licence.AutoSize := False; Licence.WordWrap := True;
      Licence.SetBounds(16, 176, 309, 27);
      Licence.Caption := LanguageText('Forms', 'TAboutBox.LicenceLabel.Caption', '');
      Licence.AutoSize := True;
      Check((Licence.Height >= 39) and (Licence.Width <= 309) and (Licence.Left = 16),
        'a wrapped label grows to the lines of its translated text');
      { Shut Down's Yes/No and every OK, Help and Close take their kind's text. }
      Yes := TBitBtn.Create(About); Yes.Parent := About; Yes.Kind := bkYes;
      Close := TBitBtn.Create(About); Close.Parent := About; Close.Kind := bkClose;
      Check((Yes.Caption = '&Ja') and (Close.Caption = '&Schlie'#223'en'),
        'standard buttons take the catalogue text of their kind');
      About.Show;
      ApplyComponentLanguage(About);
      Check(About.Caption = Title, 'a form title is translated');
      GetWindowText(About.Handle, Buffer, SizeOf(Buffer));
      Check(StrPas(Buffer) = Title, 'the window shows the translated title');
      Check(Memory.Caption = MemoryText, 'a label caption is translated');
    finally About.Free; end;
    FileSys := TFileSysPropDlg.CreateNew(nil);
    try
      FileSys.Name := 'FileSysPropDlg'; FileSys.SetBounds(40, 40, 200, 120);
      Filter := TEdit.Create(FileSys); Filter.Name := 'FilterEdit'; Filter.Parent := FileSys;
      Filter.Hint := 'List of wildcards';
      ApplyComponentLanguage(FileSys);
      Check(Filter.Hint = FilterHint, 'a control hint is translated');
    finally FileSys.Free; end;
    { The default Start menu in the other catalogues. }
    Check(ConfigureLanguage('C:\', 'fr') and (LanguageText('Menu', 'Accessories', '') = 'Accessoires') and
      (LanguageText('Menu', 'Notepad', '') = 'Bloc-notes'), 'the French Start menu is translated');
    Check(ConfigureLanguage('C:\', 'nl') and (LanguageText('Menu', 'Control Panel', '') = 'Configuratiescherm') and
      (LanguageText('Menu', 'Notepad', '') = 'Kladblok'), 'the Dutch Start menu is translated');
    Check(ConfigureLanguage('C:\', 'it') and (LanguageText('Menu', 'Accessories', '') = 'Accessori') and
      (LanguageText('Menu', 'Notepad', '') = 'Blocco note'), 'the Italian Start menu is translated');
    Check(ConfigureLanguage('C:\', 'es') and (LanguageText('Menu', 'Control Panel', '') = 'Panel de control') and
      (LanguageText('Menu', 'Notepad', '') = 'Bloc de notas'), 'the Spanish Start menu is translated');
    Check(ConfigureLanguage('C:\', 'pl') and (LanguageText('Menu', 'Control Panel', '') = 'Panel sterowania') and
      (LanguageText('Menu', 'Notepad', '') = 'Notatnik'), 'the Polish Start menu is translated');
    { The Tip of the Day's check box is 309 pixels wide; Windows 3.1
      cannot wrap it, so every catalogue's text must fit beside the box. }
    for Code := 0 to 6 do
    begin
      Check(ConfigureLanguage('C:\', Codes[Code]), Codes[Code] + ' catalogue');
      Check(TextPixels(LanguageText('Forms', 'TTipDialog.cbShowDailyTips.Caption', ''),
        'MS Sans Serif', -11, FW_NORMAL) + 20 <= 309,
        'the Tip of the Day check box shows its whole text in ' + Codes[Code]);
    end;
    Check(StackGuardIntact, 'stack guard');
  except
    on E: Exception do Check(False, 'exception ' + E.Message);
  end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
