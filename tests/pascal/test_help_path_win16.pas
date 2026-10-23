program TestHelpPath;
{$APPTYPE GUI}
{$mode delphi}{$H-}{$K+}
uses WinTypes, WinProcs, SysUtils, runtime_paths, help_service, language_catalog;

function WindowProc(Window: HWND; MessageId: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT; export;
begin
  WindowProc := DefWindowProc(Window, MessageId, WParam, LParam);
end;

var
  ClassInfo: TWndClass;
  Window: HWND;
  Message: TMsg;
  ModuleName, HelpName: array[0..255] of Char;
  Directory, HelpPath: string;
  Log: Text;
  Okay, HelpOkay, ExpectMissing: Boolean;
begin
  AssignFile(Log, 'C:\HLPATH.LOG');
  Rewrite(Log);
  GetModuleFileName(HInstance, ModuleName, SizeOf(ModuleName));
  Directory := RuntimeDirectory;
  InitializeLanguage(Directory + 'LANG', Directory + 'CALMIRA.INI');
  ExpectMissing := False;
  if CmdLine <> nil then ExpectMissing := Pos('MISSING', UpperCase(StrPas(CmdLine))) > 0;
  HelpPath := Directory + 'CALMIRA.HLP';
  if ExpectMissing then HelpPath := Directory + 'MISSING.HLP';
  WriteLn(Log, 'MODULE=', StrPas(ModuleName));
  WriteLn(Log, 'DIRECTORY=', Directory);
  WriteLn(Log, 'HELP=', HelpPath);
  Okay := (UpperCase(Directory) = 'C:\HELPPKG\') and
    (FileExists(HelpPath) <> ExpectMissing);
  FillChar(ClassInfo, SizeOf(ClassInfo), 0);
  ClassInfo.hInstance := HInstance;
  ClassInfo.lpfnWndProc := @WindowProc;
  ClassInfo.lpszClassName := 'CalmiraHelpPathTest';
  if not RegisterClass(ClassInfo) then Okay := False;
  Window := CreateWindow('CalmiraHelpPathTest', 'Help path test', WS_OVERLAPPEDWINDOW,
    0, 0, 100, 80, 0, 0, HInstance, nil);
  StrPCopy(HelpName, HelpPath);
  HelpOkay := False;
  if Window <> 0 then
    HelpOkay := LaunchHelp(Window, HelpPath, HELP_CONTENTS, 0);
  WriteLn(Log, 'HELP_CALL=', Ord(HelpOkay));
  if Okay and (HelpOkay <> ExpectMissing) then WriteLn(Log, 'RESULT PASS')
  else WriteLn(Log, 'RESULT FAIL');
  CloseFile(Log);
  if Window = 0 then Halt(1);
  while GetMessage(Message, 0, 0, 0) do
  begin
    TranslateMessage(Message);
    DispatchMessage(Message);
  end;
end.
