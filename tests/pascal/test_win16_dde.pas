program TestWin16Dde;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Forms, DdeMan;
type
  TEvents = class
    ServerOpens, ServerCloses, ClientOpens, ClientCloses: Integer;
    Macros: TStringList;
    Done: Boolean;
    procedure ServerOpen(Sender: TObject);
    procedure ServerClose(Sender: TObject);
    procedure ClientOpen(Sender: TObject);
    procedure ClientClose(Sender: TObject);
    procedure Macro(Sender: TObject; Msg: TStrings);
  end;
var Events: TEvents; Server: TDdeServerConv; Prog, Auto: TDdeClientConv; Failed: Boolean;
  Data: PChar; Macro: array[0..127] of Char; Text: string; Start: LongInt;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure Pump(Duration: LongInt);
var Msg: TMsg; Start: LongInt;
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < Duration do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure TEvents.ServerOpen(Sender: TObject); begin Inc(ServerOpens); end;
procedure TEvents.ServerClose(Sender: TObject); begin Inc(ServerCloses); end;
procedure TEvents.ClientOpen(Sender: TObject); begin Inc(ClientOpens); end;
procedure TEvents.ClientClose(Sender: TObject); begin Inc(ClientCloses); end;
procedure TEvents.Macro(Sender: TObject; Msg: TStrings);
var I: Integer;
begin
  Macros.Add(IntToStr(Msg.Count));
  for I := 0 to Msg.Count - 1 do Macros.Add(Msg[I]);
  if (Msg.Count = 1) and (Msg[0] = '[Done]') then Done := True;
end;
begin
  LogLine('STEP dde');
  Events := TEvents.Create;
  Events.Macros := TStringList.Create;
  try
    Check(AnsiCompareText(DdeMgr.AppName, 'GDITEST') = 0, 'AppName defaults to the module name');
    DdeMgr.AppName := 'CALTEST';
    Server := TDdeServerConv.Create(nil);
    Server.Name := 'Probe';
    Server.OnOpen := Events.ServerOpen; Server.OnClose := Events.ServerClose;
    Server.OnExecuteMacro := Events.Macro;

    Check(WinExec('C:\APPSEND.EXE', SW_SHOWNORMAL) >= 32, 'the client task starts');
    Start := WinProcs.GetTickCount;
    while not Events.Done and (WinProcs.GetTickCount - Start < 15000) do Pump(50);
    Pump(500);
    Check(Events.Done and (Events.ServerOpens = 1), 'another task connects to AppName|Name');
    Check((Events.Macros.Count >= 5) and (Events.Macros[0] = '1') and (Events.Macros[1] = '[One][Two]'),
      'OnExecuteMacro gets a one-line command');
    Check((Events.Macros.Count >= 5) and (Events.Macros[2] = '2') and (Events.Macros[3] = 'A') and
      (Events.Macros[4] = 'B'), 'ExecuteMacroLines arrives as one line per string');
    Check(Events.Macros.IndexOf('[RequestNil]') > 0, 'requests to a server conversation return nil');
    Check(Events.Macros.IndexOf('[NoTopic]') > 0, 'an unknown topic is refused');
    Check(Events.ServerCloses = 1, 'the server sees the client disconnect');

    Prog := TDdeClientConv.Create(nil);
    Check((Prog.ConnectMode = ddeAutomatic) and (Prog.DdeFmt = CF_TEXT) and (Prog.Conv = 0),
      'TDdeClientConv has Delphi''s defaults');
    Prog.ConnectMode := ddeManual;
    Prog.OnOpen := Events.ClientOpen; Prog.OnClose := Events.ClientClose;
    { PROGMAN is the shell of the test image, so it is already running. }
    Check(Prog.SetLink('PROGMAN', 'PROGMAN') and (Prog.Conv = 0), 'a manual SetLink does not connect');
    Check(not Prog.ExecuteMacro('[ShowGroup(Main,1)]', False) and (Prog.RequestData('Groups') = nil),
      'without a link nothing is sent');
    Check(Prog.OpenLink and (Prog.Conv <> 0) and (Events.ClientOpens = 1), 'OpenLink connects and fires OnOpen');
    Data := Prog.RequestData('Groups');
    Text := '';
    if Data <> nil then begin Text := StrPas(Data); StrDispose(Data); end;
    { The image is a German Windows: the first group is not called Main. }
    Check((Text <> '') and (Text[1] <> #13), 'RequestData returns the server''s text');
    if Pos(#13, Text) > 0 then Text := Copy(Text, 1, Pos(#13, Text) - 1);
    Check(Prog.ExecuteMacro(StrPCopy(Macro, '[ShowGroup(' + Text + ',1)]'), False), 'ExecuteMacro is acknowledged');
    Check(not Prog.ExecuteMacro('[NoSuchCommand]', False), 'a refused command returns False');
    Prog.CloseLink;
    Check((Prog.Conv = 0) and (Events.ClientCloses = 1), 'CloseLink ends the link with OnClose');

    Events.ClientOpens := 0; Events.ClientCloses := 0;
    Prog.ServiceApplication := 'C:\APPSEND.EXE SERVE';
    Prog.SetLink('HELPER', 'Echo');
    Check(Prog.OpenLink and (Prog.Conv <> 0) and (Events.ClientOpens = 1),
      'OpenLink starts ServiceApplication and connects');
    Check(Prog.ExecuteMacro('[Quit]', False), 'the started server takes a command');
    Start := WinProcs.GetTickCount;
    while (Prog.Conv <> 0) and (WinProcs.GetTickCount - Start < 5000) do Pump(50);
    Check((Prog.Conv = 0) and (Events.ClientCloses = 1), 'a server that exits ends the link with OnClose');
    Prog.Free; Prog := nil;

    Auto := TDdeClientConv.Create(nil);
    Check(not Auto.SetLink('NOSUCHAPP', 'NOTOPIC') and (Auto.Conv = 0),
      'an automatic SetLink connects and reports failure');
    Auto.Free; Auto := nil;

    DdeMgr.AppName := 'OTHER';
    Check(DdeMgr.AppName = 'OTHER', 'AppName can be changed');
    Server.Free; Server := nil;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Server.Free; Prog.Free; Auto.Free;
  Events.Macros.Free; Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
