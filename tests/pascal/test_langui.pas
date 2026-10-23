program TestLangUI;
{$mode delphi}{$H-}
uses Classes, LangUI, language_catalog;
type
  TAboutBox = class(TComponent)
  private FCaption: string;
  published property Caption: string read FCaption write FCaption;
  end;
var Item: TAboutBox;
begin
  ConfigureLanguage('build/lang', 'de');
  Item := TAboutBox.Create(nil);
  Item.Name := 'AboutBox';
  Item.Caption := 'About';
  ApplyComponentLanguage(Item);
  if Item.Caption = 'About' then Halt(1);
  Item.Free;
  WriteLn('component localization: OK');
end.
