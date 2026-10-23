program IdentityTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Messages, native_application,
  runtime_paths;
const ProbeMessage = WM_USER + 295;
type
  TD = object
    Calls: Integer;
    function Hook(var M: TMessage): Boolean;
    function Help(Command: Word; Data: LongInt; var CallHelp: Boolean): Boolean;
    procedure ExceptionRaised(Sender: TObject; E: Exception);
  end;
var App: TNativeApplication; Driver: TD; Failed, Rejected, IsPacked: Boolean;
  Expected, PackageName, Sidecar, PreviousDirectory: string;
  WindowBefore: HWND; I: Integer;
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
procedure ReadExpected;
var Buffer: array[0..256] of Char; Count: Integer;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  Count := GetModuleFileName(HInstance, Buffer, SizeOf(Buffer));
  if (Count <= 0) or (Count > 255) then raise Exception.Create('kernel module path');
  SetString(Expected, PChar(@Buffer[0]), Count);
end;
procedure CheckModuleFile;
var F: HFILE; Name: array[0..255] of Char; Header: array[0..63] of Byte;
  Offset: LongInt; Signature: array[0..1] of Char; Okay: Boolean;
begin
  StrPCopy(Name, App.ExeName); F := _lopen(Name, OF_READ);
  if F = HFILE_ERROR then raise Exception.Create('cannot open actual module');
  try
    Okay := _lread(F, @Header, SizeOf(Header)) = SizeOf(Header);
    if Okay then Okay := (Header[0] = Ord('M')) and (Header[1] = Ord('Z'));
    if Okay then
    begin
      Move(Header[$3C], Offset, SizeOf(Offset));
      Okay := _llseek(F, Offset, 0) = Offset;
      if Okay then Okay := _lread(F, @Signature, 2) = 2;
      if Okay then Okay := (Signature[0] = 'N') and (Signature[1] = 'E');
    end;
    Check(Okay, 'ExeName opens the real loaded NE file');
  finally _lclose(F); end;
  { LoadIcon returns a shared resource handle: do not destroy it. }
  Check(LoadIcon(HInstance, MakeIntResource(201)) <> 0, 'loaded module retains bound original icon resources');
end;
function TD.Hook(var M: TMessage): Boolean;
begin
  Result := M.Msg = ProbeMessage;
  if Result then
  begin
    Check((App.ExeName = Expected) and (RuntimePackageExecutableName = PackageName),
      'identity queries are safe inside sent transport callbacks');
    Inc(Calls); M.Result := 1;
  end;
end;
function TD.Help(Command: Word; Data: LongInt; var CallHelp: Boolean): Boolean;
begin
  Check(App.ExeName = Expected, 'identity query remains read only inside help callback');
  Inc(Calls); CallHelp := False; Result := True;
end;
procedure TD.ExceptionRaised(Sender: TObject; E: Exception);
begin
  Check(App.ExeName = Expected, 'identity query remains read only inside exception callback');
  Inc(Calls);
end;
procedure WriteSidecar(const Value: string; Extra: Word = 0);
var Name: array[0..255] of Char; F: HFILE; I: Word; Padding: Char;
begin
  StrPCopy(Name, Sidecar); F := _lcreat(Name, 0);
  if F = HFILE_ERROR then raise Exception.Create('sidecar write');
  try
    if Length(Value) <> 0 then
      if _lwrite(F, @Value[1], Length(Value)) <> Length(Value) then
        raise Exception.Create('short sidecar write');
    Padding := 'X';
    for I := 1 to Extra do
      if _lwrite(F, @Padding, 1) <> 1 then raise Exception.Create('sidecar padding');
  finally _lclose(F); end;
end;
procedure CheckPaths(const ExpectedPackage, Description: string);
var PackageValue, DirectoryValue, ExecutableValue, ExpectedDirectory: AnsiString;
begin
  PackageValue := RuntimePackageExecutableName;
  DirectoryValue := RuntimeDirectory;
  ExecutableValue := App.ExeName;
  ExpectedDirectory := ExtractFilePath(ExpectedPackage);
  Check((PackageValue = ExpectedPackage) and (DirectoryValue = ExpectedDirectory) and
    (ExecutableValue = Expected), Description);
end;
procedure Fallback(const Value, Description: string);
begin
  WriteSidecar(Value);
  CheckPaths(Expected, Description);
end;
procedure SidecarCases;
begin
  Sidecar := ChangeFileExt(Expected, '.SRC');
  Check(FileExists(Sidecar), 'packed module has real wrapper source sidecar');
  try
    WriteSidecar(PackageName + #13#10);
    CheckPaths(PackageName, 'wrapper sidecar accepts optional CRLF');
    WriteSidecar(PackageName, 300);
    CheckPaths(Expected, 'overlong sidecar is rejected without reading unbounded data');
    Fallback(PackageName + #13#10 + PackageName, 'multiline sidecar cannot redirect through its first line');
    Fallback('C:IDENTITY.EXE', 'drive relative sidecar never redirects package lookup');
    Fallback('..\IDENTITY.EXE', 'relative sidecar never redirects package lookup');
    Fallback('C:\NOFILE.EXE', 'nonexistent sidecar target falls back to actual module');
    Fallback(PackageName + #0 + 'ignored', 'embedded NUL sidecar cannot redirect through truncated filename');
    Fallback('', 'empty sidecar falls back to actual module');
    if not DeleteFile(Sidecar) then raise Exception.Create('sidecar delete');
    CheckPaths(Expected,
      'missing sidecar falls back without changing executable identity');
  finally WriteSidecar(PackageName); end;
  CheckPaths(PackageName,
    'restored wrapper sidecar recovers package data location but not ExeName');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP actual executable and wrapper package identity');
  try
    IsPacked := False;
    if CmdLine <> nil then IsPacked := Pos('PACKED', UpperCase(StrPas(CmdLine))) <> 0;
    ReadExpected; PackageName := RuntimePackageExecutableName;
    LogLine('ACTUAL=' + Expected); LogLine('PACKAGE=' + PackageName);
    LogLine('DIRECTORY=' + RuntimeDirectory);
    if IsPacked then
      Check((UpperCase(PackageName) = 'C:\IDENTPKG\IDENTITY.EXE') and
        (UpperCase(ExtractFilePath(Expected)) = 'C:\TEMPPATH\'),
        'packed identity separates loaded temporary module and installed wrapper')
    else Check(PackageName = Expected, 'plain identity uses same module and package executable');
    App := TNativeApplication.Create(nil); Rejected := False;
    try PackageName := App.ExeName; except on ENativeApplicationError do Rejected := True; end;
    Check(Rejected, 'ExeName requires initialized task application');
    App.Initialize; WindowBefore := FindWindow('TApplication', 'Calmira');
    Check((App.ExeName = Expected) and (RuntimeExecutableName = Expected), 'ExeName matches current KERNEL module path');
    for I := 1 to 20 do
      if App.ExeName <> Expected then Failed := True;
    Check((FindWindow('TApplication', 'Calmira') = WindowBefore) and
      (App.MainForm = nil) and (App.FormCount = 0) and not App.Running,
      'repeated identity queries do not create transport forms or start application');
    PreviousDirectory := GetCurrentDir;
    try
      if not SetCurrentDir('C:\') then raise Exception.Create('change directory');
      Check((App.ExeName = Expected) and (RuntimePackageExecutableName = PackageName),
        'executable and package paths do not follow current directory');
    finally SetCurrentDir(PreviousDirectory); end;
    CheckModuleFile;
    if IsPacked then SidecarCases;
    App.HookMainWindow(Driver.Hook); SendMessage(App.Handle, ProbeMessage, 0, 0);
    App.UnhookMainWindow(Driver.Hook);
    App.OnHelp := Driver.Help; App.HelpContext(1); App.OnHelp := nil;
    App.OnException := Driver.ExceptionRaised;
    try raise Exception.Create('identity exception'); except on Exception do App.HandleException(nil); end;
    App.OnException := nil;
    Check((Driver.Calls = 3) and (App.WindowCallbackErrors = 0), 'callback identity queries complete without swallowed errors');
    App.Terminate(-19); App.ProcessMessages;
    Check(App.Terminated and (App.ExitCode = -19) and (App.ExeName = Expected),
      'terminated application retains read only executable identity');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  { Retain a diagnostic even if a failure exhausted the declared stack. }
  if StackGuardIntact then App.Free else begin Failed := True; LogLine('FAIL identity stack before teardown'); end;
  Check(StackGuardIntact, 'identity stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
