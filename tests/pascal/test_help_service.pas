program TestHelpService;
{$mode delphi}{$H-}
uses SysUtils, WinProcs, help_service, language_catalog;
var
  Fixture: Text;
  FileName, Missing: string;
  Code: string[2];
  I: Integer;
procedure Check(Okay: Boolean; const Description: string);
begin
  if not Okay then begin WriteLn('FAIL ', Description); Halt(1); end;
end;
begin
  FileName := 'build/tests/help-service/fixture.hlp';
  AssignFile(Fixture, FileName); Rewrite(Fixture);
  WriteLn(Fixture, 'Host API fixture, not a real HLP.'); CloseFile(Fixture);
  try
    for I := 0 to 2 do
    begin
      case I of 0: Code := 'en'; 1: Code := 'de'; 2: Code := 'fr'; end;
      Check(ConfigureLanguage('build/lang', Code), 'configure language');
      ResetCalls;
      Missing := StringOfChar('x', 240);
      Check(not LaunchHelp(7, Missing, 1, 21), 'missing file fails');
      Check((HelpCalls = 0) and (MessageCalls = 1), 'missing file does not invoke WinHelp');
      Check(LastCaption = LanguageText('Help', 'Title', ''), 'localized caption');
      Check(Pos(LanguageText('Help', 'Missing', ''), LastMessage) = 1, 'localized missing text');
      Check(Copy(LastMessage, Length(LastMessage) - Length(Missing) + 1, Length(Missing)) = Missing,
        'complete long path survives message formatting');
      ResetCalls; HelpResult := False;
      Check(not LaunchHelp(7, FileName, 1, 21), 'failed Windows launch fails');
      Check((HelpCalls = 1) and (MessageCalls = 1), 'launch failure reported once');
      Check(Pos(LanguageText('Help', 'CannotOpen', ''), LastMessage) = 1, 'localized launch error');
    end;
    ResetCalls;
    Check(LaunchHelp(7, FileName, 1, 12345), 'successful launch');
    Check((HelpCalls = 1) and (MessageCalls = 0), 'successful launch has no error UI');
    Check((LastFile = FileName) and (LastOwner = 7) and (LastCommand = 1) and
      (LastData = 12345), 'request arguments forwarded unchanged');
    ResetCalls; HelpResult := False;
    Check(not LaunchHelp(7, '', HELP_QUIT, 0), 'quit return value preserved');
    Check((HelpCalls = 1) and (MessageCalls = 0), 'quit is silent and needs no file');
    ResetCalls;
    Check(not LaunchHelp(7, '', 1, 0), 'empty path fails');
    Check((HelpCalls = 0) and (MessageCalls = 1), 'empty path handled locally');
    WriteLn('help-service tests: OK');
  finally DeleteFile(FileName); end;
end.
