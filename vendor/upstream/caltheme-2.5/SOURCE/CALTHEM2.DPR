{ --- CALTHEME v2.5 ---

  Theme and INI editor for Calmira - see CTHEME25.TXT.
  Freeware with open source under the GPL licence - see
  LICENCE.TXT enclosed with the source.

  Copyright © David Burgess, December 2000. }


program Calthem2;

uses
  Forms,
  Dialogs,
  Buttons,
  WinProcs,
  Main in 'MAIN.PAS' {CalThemeForm},
  Finder in 'FINDER.PAS' {FolderFinder};

{$R *.RES}

begin
  MsgDlgButtonStyle := bsNew;
  MsgDlgGlyphs := False;
  if (HPrevInst <> 0) then exit; { only run one copy of CalTheme at a time -
                                   won't work in 32-bit Windows }
  Application.CreateForm(TCalThemeForm, CalThemeForm);
  Application.CreateForm(TFolderFinder, FolderFinder);
  Application.Run;
end.
