program DdeSender;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
{ Peer task of test_win16_dde. Without arguments it is a client of
  CALTEST|Probe in the test task; with SERVE it is the HELPER|Echo server
  that ServiceApplication starts, and it exits after [Quit]. }
uses WinTypes, WinProcs, Classes, SysUtils, Forms, DdeMan;
type
  TEcho = class
    Quit: Boolean;
    procedure Macro(Sender: TObject; Msg: TStrings);
  end;
var Client: TDdeClientConv; Lines: TStringList; Data: PChar; NoTopic: Boolean;
  Echo: TEcho; Server: TDdeServerConv; Msg: TMsg;
procedure TEcho.Macro(Sender: TObject; Msg: TStrings);
begin
  if (Msg.Count = 1) and (Msg[0] = '[Quit]') then Quit := True;
end;
begin
  { ParamStr is not linked in the Win16 RTL; CmdLine holds the arguments. }
  if (CmdLine <> nil) and (StrPos(CmdLine, 'SERVE') <> nil) then
  begin
    DdeMgr.AppName := 'HELPER';
    Echo := TEcho.Create;
    Server := TDdeServerConv.Create(nil);
    Server.Name := 'Echo';
    Server.OnExecuteMacro := Echo.Macro;
    { Ends the conversation from the server side once [Quit] is acknowledged. }
    while not Echo.Quit and GetMessage(Msg, 0, 0, 0) do
    begin TranslateMessage(Msg); DispatchMessage(Msg); end;
    Server.Free; Echo.Free;
    Exit;
  end;
  DdeMgr.AppName := '';
  Client := TDdeClientConv.Create(nil);
  Lines := TStringList.Create;
  try
    Client.ConnectMode := ddeManual;
    Client.SetLink('CALTEST', 'Nothing');
    NoTopic := not Client.OpenLink;
    Client.SetLink('CALTEST', 'Probe');
    if Client.OpenLink then
    begin
      Client.ExecuteMacro('[One][Two]', False);
      Lines.Add('A'); Lines.Add('B');
      Client.ExecuteMacroLines(Lines, False);
      Data := Client.RequestData('Info');
      if Data = nil then Client.ExecuteMacro('[RequestNil]', False) else StrDispose(Data);
      if NoTopic then Client.ExecuteMacro('[NoTopic]', False);
      Client.ExecuteMacro('[Done]', False);
      Client.CloseLink;
    end;
  finally
    Lines.Free;
    Client.Free;
  end;
end.
