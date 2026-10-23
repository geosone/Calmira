program ApplicationHelpTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, native_application, language_catalog;
type TD = object
  Calls, Guards: Integer;
  Command: Word; Data: LongInt; Macro: AnsiString;
  Suppress, Answer, RaiseError, ProbeGuards: Boolean;
  function Help(C: Word; D: LongInt; var CallHelp: Boolean): Boolean;
end;
var App: TNativeApplication; Driver: TD; Failed, Rejected: Boolean;
  Timer: UINT; Boxes, DialogGuards, I, Before: Integer;
  HelpWindow: HWND; Caption: string;
{$I win16_stack_guard.inc}
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
function TD.Help(C: Word; D: LongInt; var CallHelp: Boolean): Boolean;
begin
  Inc(Calls); Command := C; Data := D;
  Check(CallHelp, 'help event defaults to native dispatch');
  if C = HELP_COMMAND then Macro := StrPas(PChar(D));
  if ProbeGuards then
  begin
    try App.HelpContext(21); except on ENativeApplicationError do Inc(Guards); end;
    try App.HelpFile := 'changed.hlp'; except on ENativeApplicationError do Inc(Guards); end;
    try App.OnHelp := nil; except on ENativeApplicationError do Inc(Guards); end;
    try App.ProcessMessages(1); except on ENativeApplicationError do Inc(Guards); end;
    try App.Run; except on ENativeApplicationError do Inc(Guards); end;
  end;
  if RaiseError then raise Exception.Create('help handler failure');
  CallHelp := not Suppress; Result := Answer;
end;
procedure Tick(Window: HWND; Message, Event: UINT; Time: DWORD); export;
var Box, Child: HWND; Name: array[0..255] of Char;
begin
  try
    Box := GetActiveWindow;
    if (Box = 0) or (GetWindowTask(Box) <> GetCurrentTask) then Exit;
    GetClassName(Box, Name, SizeOf(Name));
    if StrComp(Name, '#32770') <> 0 then Exit;
    GetWindowText(Box, Name, SizeOf(Name));
    Check((StrPas(Name) = Caption) and (GetParent(Box) = App.Handle),
      'localized missing-help dialog has native application owner');
    try App.HelpContext(21); except on ENativeApplicationError do Inc(DialogGuards); end;
    try App.ProcessMessages(1); except on ENativeApplicationError do Inc(DialogGuards); end;
    Child := GetWindow(Box, GW_CHILD);
    while Child <> 0 do
    begin
      GetClassName(Child, Name, SizeOf(Name));
      if StrIComp(Name, 'Button') = 0 then
      begin Inc(Boxes); SendMessage(Box, WM_COMMAND, GetDlgCtrlID(Child), LongInt(Child)); Exit; end;
      Child := GetWindow(Child, GW_HWNDNEXT);
    end;
    Failed := True;
  except Failed := True; end;
end;
procedure Pump(Milliseconds: DWORD);
var Started: DWORD;
begin
  Started := WinProcs.GetTickCount;
  repeat App.ProcessMessages(500); WinProcs.Yield;
  until WinProcs.GetTickCount - Started >= Milliseconds;
end;
function FindHelp: HWND;
var W: HWND; Text: array[0..255] of Char;
begin
  Result := 0; W := GetWindow(GetDesktopWindow, GW_CHILD);
  while W <> 0 do
  begin
    GetWindowText(W, Text, SizeOf(Text));
    if IsWindowVisible(W) and (GetWindowTask(W) <> GetCurrentTask) and
      (Pos('Calmira Reloaded', StrPas(Text)) <> 0) then begin Result := W; Exit; end;
    W := GetWindow(W, GW_HWNDNEXT);
  end;
end;
function HelpHasDialog: Boolean;
var W: HWND; Name: array[0..31] of Char;
begin
  Result := False;
  if HelpWindow = 0 then Exit;
  W := GetWindow(GetDesktopWindow, GW_CHILD);
  while W <> 0 do
  begin
    if IsWindowVisible(W) and (GetWindowTask(W) = GetWindowTask(HelpWindow)) then
    begin
      GetClassName(W, Name, SizeOf(Name));
      if StrComp(Name, '#32770') = 0 then begin Result := True; Exit; end;
    end;
    W := GetWindow(W, GW_HWNDNEXT);
  end;
end;
procedure BasicCases;
begin
  App := TNativeApplication.Create(nil); Rejected := False;
  try App.OnHelp := Driver.Help; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'help registration requires initialized application'); App.Initialize;
  App.HelpFile := 'C:\HELPDOCS\CALMIRA.HLP'; App.OnHelp := Driver.Help;
  Driver.Suppress := True; Driver.Answer := True; Driver.ProbeGuards := True;
  Check(App.HelpContext(-12345) and (Driver.Command = HELP_CONTEXT) and
    (Driver.Data = -12345) and (Driver.Guards = 5), 'help event preserves signed context and rejects reentry');
  Driver.ProbeGuards := False; Driver.Answer := False;
  Check(not App.HelpCommand(HELP_PARTIALKEY, 0), 'suppressed help preserves false event result');
  Check(App.HelpJump('Contents') = False, 'suppressed jump returns event result');
  Check((Driver.Command = HELP_COMMAND) and
    (Driver.Macro = 'JumpID("C:\\HELPDOCS\\CALMIRA.HLP","Contents")') and
    (FindWindow('TApplication', 'Calmira') = 0), 'jump macro pointer is live and interception creates no HWND');
  Before := Driver.Calls; Rejected := False;
  try App.HelpJump('bad");ExecFile("bad")'); except on EConvertError do Rejected := True; end;
  Check(Rejected and (Driver.Calls = Before), 'invalid jump rejected before event');
  Rejected := False;
  try App.HelpFile := 'a'#0'b'; except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected and (App.HelpFile = 'C:\HELPDOCS\CALMIRA.HLP'), 'NUL help path preserves previous value');
  Driver.RaiseError := True; Rejected := False;
  try App.HelpContext(21); except on E: Exception do Rejected := E.Message = 'help handler failure'; end;
  Driver.RaiseError := False; App.OnHelp := nil; App.OnHelp := Driver.Help;
  Check(Rejected and not App.HelpContext(21), 'direct help exception propagates and releases guard');
end;
procedure NativeCases;
begin
  Driver.Suppress := False; Driver.Answer := False;
  Check(SetCurrentDir('C:\WINDOWS'), 'help test changes working directory');
  Check(App.HelpCommand(HELP_CONTENTS, 0), 'default WinHelp result overrides event result'); Pump(1800);
  HelpWindow := FindHelp;
  Check(HelpWindow <> 0, 'real WinHelp displays installed help from explicit path');
  Check(App.HelpContext(900), 'native numeric help context accepted'); Pump(500);
  Check(App.HelpJump('ReloadedStatus'), 'native JumpID request accepted'); Pump(1200);
  Check(FindHelp <> 0, 'native help remains visible after context and macro requests');
  Check(not HelpHasDialog, 'native topic jump has no WinHelp error dialog');
  App.HelpCommand(HELP_QUIT, 0); Pump(500);
  Check(not IsWindow(HelpWindow) or not IsWindowVisible(HelpWindow), 'HELP_QUIT releases native help window');
  App.OnHelp := nil;
  for I := 0 to 2 do
  begin
    case I of
      0: Check(ConfigureLanguage('C:\', 'en'), 'English help catalogue');
      1: Check(ConfigureLanguage('C:\', 'de'), 'German help catalogue');
      2: Check(ConfigureLanguage('C:\', 'fr'), 'French help catalogue');
    end;
    Caption := LanguageText('Help', 'Title', ''); App.HelpFile := 'C:\MISSING.HLP';
    Check(not App.HelpContext(21), 'missing help returns false without launching WinHelp');
  end;
  Check((Boxes = 3) and (DialogGuards = 6), 'localized dialogs preserve help and pump guards');
  App.HelpFile := ''; Before := Boxes; App.HelpCommand(HELP_QUIT, 0);
  Check(Boxes = Before, 'HELP_QUIT without file is silent');
  App.HelpFile := 'C:\HELPDOCS\CALMIRA.HLP';
  Check(App.HelpContext(21), 'help can reopen after errors and quit'); Pump(1200);
  HelpWindow := FindHelp; Check(HelpWindow <> 0, 'reopened native help visible');
  App.OnHelp := Driver.Help; Before := Driver.Calls;
  App.Free; App := TNativeApplication.Create(nil); App.Initialize; Pump(500);
  Check((Driver.Calls = Before) and (not IsWindow(HelpWindow) or not IsWindowVisible(HelpWindow)),
    'application teardown silently quits its native help');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP native application help');
  try
    Timer := SetTimer(0, 0, 55, TFarProc(@Tick));
    if Timer = 0 then raise Exception.Create('timer');
    BasicCases; NativeCases;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  if Timer <> 0 then KillTimer(0, Timer);
  App.Free;
  Check(StackGuardIntact, 'application help stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
