{ Host-only recording Windows API substitute for help-service error tests. }
unit WinProcs;
{$mode delphi}{$H+}
interface
uses WinTypes;
const HELP_QUIT = 2; MB_OK = 0; MB_ICONEXCLAMATION = $30;
var
  HelpCalls, MessageCalls: Integer;
  HelpResult: Boolean;
  LastFile, LastMessage, LastCaption: AnsiString;
  LastOwner: HWND;
  LastCommand: Word;
  LastData: LongInt;
function WinHelp(Owner: HWND; FileName: PChar; Command: Word; Data: LongInt): Boolean;
function MessageBox(Owner: HWND; Text, Caption: PChar; Flags: Word): Integer;
procedure ResetCalls;
implementation
procedure ResetCalls;
begin
  HelpCalls := 0; MessageCalls := 0; HelpResult := True;
  LastFile := ''; LastMessage := ''; LastCaption := '';
end;
function WinHelp(Owner: HWND; FileName: PChar; Command: Word; Data: LongInt): Boolean;
begin
  Inc(HelpCalls); LastFile := FileName; LastOwner := Owner;
  LastCommand := Command; LastData := Data; Result := HelpResult;
end;
function MessageBox(Owner: HWND; Text, Caption: PChar; Flags: Word): Integer;
begin
  Inc(MessageCalls); LastMessage := Text; LastCaption := Caption; Result := 1;
end;
end.
