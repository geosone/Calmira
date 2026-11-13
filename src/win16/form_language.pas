{ SPDX-License-Identifier: GPL-2.0-or-later
  Gives the generated form loaders the texts of the selected catalogue.
  Delphi read a translated DFM before OnCreate; the loaders ask for each text
  while they load, so the values OnCreate sets (free memory, versions) stay. }
unit form_language;
{$mode delphi}{$H-}
interface
implementation
uses form_text, language_catalog;
type
  TCatalogueText = class
    function Text(const RootClass, ComponentName, PropertyName,
      DefaultText: string): string;
  end;
var CatalogueText: TCatalogueText;

function TCatalogueText.Text(const RootClass, ComponentName, PropertyName,
  DefaultText: string): string;
begin
  Result := LanguageText('Forms', RootClass + '.' + ComponentName + '.' +
    PropertyName, DefaultText);
end;

initialization
  CatalogueText := TCatalogueText.Create;
  SetFormTextProvider(CatalogueText.Text);
finalization
  SetFormTextProvider(nil);
  CatalogueText.Free;
end.
