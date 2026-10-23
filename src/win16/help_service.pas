{ WinHelp launch with localized errors; no VCL dependency. }
unit help_service;
{$mode delphi}{$H-}
interface
uses WinTypes;
function LaunchHelp(Owner: HWND; const HelpFile: string;
  Command: Word; Data: LongInt): Boolean;
implementation
uses WinProcs, SysUtils, language_catalog;

procedure ShowHelpError(Owner: HWND; const Key, DefaultText, HelpFile: string);
var
  MessageText: array[0..515] of Char;
  CaptionText: array[0..255] of Char;
begin
  StrPCopy(CaptionText, LanguageText('Help', 'Title', 'Calmira Reloaded Help'));
  StrPCopy(MessageText, LanguageText('Help', Key, DefaultText));
  StrCat(MessageText, #13#10#13#10);
  StrPCopy(@MessageText[StrLen(MessageText)], HelpFile);
  MessageBox(Owner, MessageText, CaptionText, MB_OK or MB_ICONEXCLAMATION);
end;

function LaunchHelp(Owner: HWND; const HelpFile: string;
  Command: Word; Data: LongInt): Boolean;
var FileName: array[0..255] of Char;
begin
  Result := False;
  { Cleanup must neither require a file nor display a shutdown error. }
  if (Command <> HELP_QUIT) and ((HelpFile = '') or not FileExists(HelpFile)) then
  begin
    ShowHelpError(Owner, 'Missing',
      'The help file was not found. Restore it from the matching installation package.', HelpFile);
    Exit;
  end;
  StrPCopy(FileName, HelpFile);
  Result := WinHelp(Owner, FileName, Command, Data);
  if not Result and (Command <> HELP_QUIT) then
    ShowHelpError(Owner, 'CannotOpen',
      'Windows could not open the help. Check WinHelp and the matching installation files.', HelpFile);
end;
end.
