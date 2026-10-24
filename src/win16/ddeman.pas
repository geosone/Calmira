{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 DdeMan subset over DDEML: the DdeMgr service name, client
  conversations (open, request, execute) and server conversations whose
  topic is the component name and which take execute macros. Client and
  server items, advise loops, pokes and paste links are not provided. }
unit DdeMan;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL DdeMan requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, DDEML;
type
  TDataMode = (ddeAutomatic, ddeManual);
  TMacroEvent = procedure(Sender: TObject; Msg: TStrings) of object;
  EDdeError = class(Exception);
  { A client conversation with DdeService|DdeTopic. }
  TDdeClientConv = class(TComponent)
  private
    FConv: HConv;
    FDdeService, FDdeTopic, FServiceApplication: string;
    FConnectMode: TDataMode;
    FDdeFmt: Integer;
    FFormatChars, FWaitStat: Boolean;
    FOnOpen, FOnClose: TNotifyEvent;
    procedure SetConnectMode(Value: TDataMode);
    procedure SetDdeService(const Value: string);
    procedure SetDdeTopic(const Value: string);
    function Connect: Boolean;
    function Transact(Data: PChar; XType: Word; const Item: string): HDDEData;
  protected
    procedure Loaded; override;
    procedure Open; virtual;
    procedure Close; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { If no server answers and ServiceApplication is set, it is started
      once and the connection retried. }
    function OpenLink: Boolean;
    { Closes the link; in ddeAutomatic mode it then opens the new one. }
    function SetLink(const Service, Topic: string): Boolean;
    procedure CloseLink;
    { Synchronous with a 10 s timeout, also when WaitFlg is False; True when
      the server acknowledged the command. }
    function ExecuteMacro(Cmd: PChar; WaitFlg: Boolean): Boolean;
    function ExecuteMacroLines(Cmd: TStrings; WaitFlg: Boolean): Boolean;
    { Text of Item in a StrAlloc buffer (free it with StrDispose), or nil. }
    function RequestData(const Item: string): PChar;
    property DdeFmt: Integer read FDdeFmt write FDdeFmt;
    property WaitStat: Boolean read FWaitStat;
    property Conv: HConv read FConv;
    property DataMode: TDataMode read FConnectMode write SetConnectMode;
  published
    property ServiceApplication: string read FServiceApplication write FServiceApplication;
    property DdeService: string read FDdeService write SetDdeService;
    property DdeTopic: string read FDdeTopic write SetDdeTopic;
    property ConnectMode: TDataMode read FConnectMode write SetConnectMode default ddeAutomatic;
    { Kept for DFMs; macros and data are passed unchanged. }
    property FormatChars: Boolean read FFormatChars write FFormatChars default False;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnOpen: TNotifyEvent read FOnOpen write FOnOpen;
  end;
  { Answers connections to DdeMgr.AppName with its Name as topic. }
  TDdeServerConv = class(TComponent)
  private
    FOnOpen, FOnClose: TNotifyEvent;
    FOnExecuteMacro: TMacroEvent;
  protected
    procedure Connect; virtual;
    procedure Disconnect; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Splits the command at line breaks for OnExecuteMacro; DDE_FACK when
      it is assigned, else DDE_FNOTPROCESSED. }
    function ExecuteMacro(Data: HDDEData): LongInt;
  published
    property OnOpen: TNotifyEvent read FOnOpen write FOnOpen;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnExecuteMacro: TMacroEvent read FOnExecuteMacro write FOnExecuteMacro;
  end;
  TDdeMgr = class(TComponent)
  private
    FInst: LongInt;
    FCallback: TFarProc;
    FAppName: string;
    FHszApp: HSZ;
    FClients, FServers: TList;
    { Server conversation handles and their TDdeServerConv. }
    FServerConvs, FServerOwners: TList;
    procedure SetAppName(const Value: string);
    function Callback(CallType: Word; Conv: HConv; hsz1, hsz2: HSZ; Data: HDDEData): HDDEData;
    function FindServer(Topic: HSZ): TDdeServerConv;
    function ServerOf(Conv: HConv): TDdeServerConv;
    function ClientOf(Conv: HConv): TDdeClientConv;
    procedure ForgetServer(Server: TDdeServerConv);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { The module name without extension, Delphi's default AppName. }
    function GetExeName: string;
    function StringHandle(const Text: string): HSZ;
    function QueryString(Handle: HSZ): string;
    property Instance: LongInt read FInst;
    { The DDE service name this task registers for its TDdeServerConv. }
    property AppName: string read FAppName write SetAppName;
  end;
var
  DdeMgr: TDdeMgr;
implementation
uses WinProcs, Forms;
const
  TransactionTimeout = 10000;
  { Attempts to reach a ServiceApplication that was just started. }
  StartRetries = 20;

function DdeCallback(CallType, Fmt: Word; Conv: HConv; hsz1, hsz2: HSZ;
  Data: HDDEData; Data1, Data2: LongInt): HDDEData; export;
begin
  Result := 0;
  if DdeMgr = nil then Exit;
  try
    Result := DdeMgr.Callback(CallType, Conv, hsz1, hsz2, Data);
  except
    Application.HandleException(DdeMgr);
    Result := 0;
  end;
end;

{ TDdeMgr }
constructor TDdeMgr.Create(AOwner: TComponent);
var Code: Word;
begin
  inherited Create(AOwner);
  FClients := TList.Create; FServers := TList.Create;
  FServerConvs := TList.Create; FServerOwners := TList.Create;
  FCallback := MakeProcInstance(@DdeCallback, HInstance);
  Code := DdeInitialize(FInst, FCallback, APPCLASS_STANDARD or CBF_FAIL_ADVISES or CBF_FAIL_POKES or
    CBF_SKIP_REGISTRATIONS or CBF_SKIP_UNREGISTRATIONS, 0);
  if Code <> DMLERR_NO_ERROR then
    raise EDdeError.CreateFmt('DDEML initialization failed (%d)', [Code]);
  AppName := GetExeName;
end;
destructor TDdeMgr.Destroy;
var I: Integer;
begin
  { At shutdown links are dropped without OnClose/OnOpen events. }
  for I := 0 to FClients.Count - 1 do
    with TDdeClientConv(FClients[I]) do
      if FConv <> 0 then begin DdeDisconnect(FConv); FConv := 0; end;
  if FInst <> 0 then
  begin
    AppName := '';
    DdeUninitialize(FInst);
    FInst := 0;
  end;
  if FCallback <> nil then FreeProcInstance(FCallback);
  FServerOwners.Free; FServerConvs.Free; FServers.Free; FClients.Free;
  inherited Destroy;
end;
function TDdeMgr.GetExeName: string;
var Buffer: array[0..143] of Char;
begin
  GetModuleFileName(HInstance, Buffer, SizeOf(Buffer));
  Result := ChangeFileExt(ExtractFileName(StrPas(Buffer)), '');
end;
function TDdeMgr.StringHandle(const Text: string): HSZ;
var Buffer: array[0..255] of Char;
begin
  Result := DdeCreateStringHandle(FInst, StrPCopy(Buffer, Text), CP_WINANSI);
end;
function TDdeMgr.QueryString(Handle: HSZ): string;
var Buffer: array[0..255] of Char;
begin
  Result := '';
  if (Handle <> 0) and (DdeQueryString(FInst, Handle, Buffer, SizeOf(Buffer), CP_WINANSI) > 0) then
    Result := StrPas(Buffer);
end;
procedure TDdeMgr.SetAppName(const Value: string);
begin
  if FHszApp <> 0 then
  begin
    DdeNameService(FInst, FHszApp, 0, DNS_UNREGISTER);
    DdeFreeStringHandle(FInst, FHszApp);
    FHszApp := 0;
  end;
  FAppName := Value;
  if Value = '' then Exit;
  FHszApp := StringHandle(Value);
  if DdeNameService(FInst, FHszApp, 0, DNS_REGISTER) = 0 then
    raise EDdeError.CreateFmt('Cannot register DDE service %s', [Value]);
end;
function TDdeMgr.FindServer(Topic: HSZ): TDdeServerConv;
var I: Integer; Name: string;
begin
  Result := nil;
  Name := QueryString(Topic);
  for I := 0 to FServers.Count - 1 do
    if AnsiCompareText(TDdeServerConv(FServers[I]).Name, Name) = 0 then
    begin Result := TDdeServerConv(FServers[I]); Exit; end;
end;
function TDdeMgr.ServerOf(Conv: HConv): TDdeServerConv;
var I: Integer;
begin
  Result := nil;
  for I := 0 to FServerConvs.Count - 1 do
    if LongInt(FServerConvs[I]) = Conv then begin Result := TDdeServerConv(FServerOwners[I]); Exit; end;
end;
function TDdeMgr.ClientOf(Conv: HConv): TDdeClientConv;
var I: Integer;
begin
  Result := nil;
  if Conv = 0 then Exit;
  for I := 0 to FClients.Count - 1 do
    if TDdeClientConv(FClients[I]).FConv = Conv then begin Result := TDdeClientConv(FClients[I]); Exit; end;
end;
procedure TDdeMgr.ForgetServer(Server: TDdeServerConv);
var I: Integer;
begin
  FServers.Remove(Server);
  for I := FServerOwners.Count - 1 downto 0 do
    if FServerOwners[I] = Server then
    begin
      DdeDisconnect(LongInt(FServerConvs[I]));
      FServerConvs.Delete(I); FServerOwners.Delete(I);
    end;
end;
function TDdeMgr.Callback(CallType: Word; Conv: HConv; hsz1, hsz2: HSZ; Data: HDDEData): HDDEData;
var Server: TDdeServerConv; Client: TDdeClientConv; I: Integer;
begin
  Result := 0;
  case CallType of
    XTYP_CONNECT:
      { hsz1 is the topic, hsz2 the service. }
      if (FHszApp <> 0) and (AnsiCompareText(QueryString(hsz2), FAppName) = 0) and
        (FindServer(hsz1) <> nil) then Result := 1;
    XTYP_CONNECT_CONFIRM:
      begin
        Server := FindServer(hsz1);
        if Server <> nil then
        begin
          FServerConvs.Add(Pointer(Conv)); FServerOwners.Add(Server);
          Server.Connect;
        end;
      end;
    XTYP_EXECUTE:
      begin
        Server := ServerOf(Conv);
        if Server <> nil then Result := Server.ExecuteMacro(Data)
        else Result := DDE_FNOTPROCESSED;
      end;
    XTYP_DISCONNECT:
      begin
        Server := ServerOf(Conv);
        if Server <> nil then
        begin
          I := FServerConvs.IndexOf(Pointer(Conv));
          FServerConvs.Delete(I); FServerOwners.Delete(I);
          Server.Disconnect;
        end;
        Client := ClientOf(Conv);
        { The server went away: the link is closed as in CloseLink. }
        if Client <> nil then begin Client.FConv := 0; Client.Close; end;
      end;
  end;
end;

{ TDdeClientConv }
constructor TDdeClientConv.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDdeFmt := CF_TEXT;
  DdeMgr.FClients.Add(Self);
end;
destructor TDdeClientConv.Destroy;
begin
  CloseLink;
  if DdeMgr <> nil then DdeMgr.FClients.Remove(Self);
  inherited Destroy;
end;
procedure TDdeClientConv.Loaded;
begin
  inherited Loaded;
  if (FConnectMode = ddeAutomatic) and (FDdeService <> '') then OpenLink;
end;
procedure TDdeClientConv.SetConnectMode(Value: TDataMode);
begin
  if Value = FConnectMode then Exit;
  CloseLink;
  FConnectMode := Value;
end;
procedure TDdeClientConv.SetDdeService(const Value: string);
begin
  if Value <> FDdeService then begin CloseLink; FDdeService := Value; end;
end;
procedure TDdeClientConv.SetDdeTopic(const Value: string);
begin
  if Value <> FDdeTopic then begin CloseLink; FDdeTopic := Value; end;
end;
function TDdeClientConv.Connect: Boolean;
var Service, Topic: HSZ;
begin
  Service := DdeMgr.StringHandle(FDdeService);
  Topic := DdeMgr.StringHandle(FDdeTopic);
  try
    FConv := DdeConnect(DdeMgr.Instance, Service, Topic, nil);
  finally
    DdeFreeStringHandle(DdeMgr.Instance, Topic);
    DdeFreeStringHandle(DdeMgr.Instance, Service);
  end;
  Result := FConv <> 0;
end;
function TDdeClientConv.OpenLink: Boolean;
var Buffer: array[0..255] of Char; Attempt: Integer; Start: LongInt;
begin
  Result := FConv <> 0;
  if Result or (FDdeService = '') then Exit;
  Result := Connect;
  if not Result and (FServiceApplication <> '') and
    (WinExec(StrPCopy(Buffer, FServiceApplication), SW_SHOWMINNOACTIVE) >= 32) then
    for Attempt := 1 to StartRetries do
    begin
      Start := WinProcs.GetTickCount;
      while WinProcs.GetTickCount - Start < 100 do Application.ProcessMessages;
      Result := Connect;
      if Result then Break;
    end;
  if Result then Open;
end;
function TDdeClientConv.SetLink(const Service, Topic: string): Boolean;
begin
  CloseLink;
  FDdeService := Service;
  FDdeTopic := Topic;
  if FConnectMode = ddeAutomatic then Result := OpenLink else Result := True;
end;
procedure TDdeClientConv.CloseLink;
var Old: HConv;
begin
  if FConv = 0 then Exit;
  Old := FConv; FConv := 0;
  DdeDisconnect(Old);
  Close;
end;
procedure TDdeClientConv.Open;
begin if Assigned(FOnOpen) then FOnOpen(Self); end;
procedure TDdeClientConv.Close;
begin if Assigned(FOnClose) then FOnClose(Self); end;
function TDdeClientConv.Transact(Data: PChar; XType: Word; const Item: string): HDDEData;
var Handle: HSZ; Size: LongInt;
begin
  Result := 0;
  if (FConv = 0) or FWaitStat then Exit;
  Handle := 0; Size := 0;
  if Item <> '' then Handle := DdeMgr.StringHandle(Item);
  if Data <> nil then Size := StrLen(Data) + 1;
  FWaitStat := True;
  try
    Result := DdeClientTransaction(Data, Size, FConv, Handle, FDdeFmt, XType, TransactionTimeout, nil);
  finally
    FWaitStat := False;
    if Handle <> 0 then DdeFreeStringHandle(DdeMgr.Instance, Handle);
  end;
end;
function TDdeClientConv.ExecuteMacro(Cmd: PChar; WaitFlg: Boolean): Boolean;
begin
  Result := (Cmd <> nil) and (Transact(Cmd, XTYP_EXECUTE, '') <> 0);
end;
function TDdeClientConv.ExecuteMacroLines(Cmd: TStrings; WaitFlg: Boolean): Boolean;
var Text: PChar; Size, I: Integer; P: PChar; Line: array[0..255] of Char;
begin
  Size := 1;
  for I := 0 to Cmd.Count - 1 do Inc(Size, Length(Cmd[I]) + 2);
  Text := StrAlloc(Size);
  try
    P := Text;
    for I := 0 to Cmd.Count - 1 do
    begin
      P := StrECopy(P, StrPCopy(Line, Cmd[I]));
      if I < Cmd.Count - 1 then P := StrECopy(P, #13#10);
    end;
    P^ := #0;
    Result := ExecuteMacro(Text, WaitFlg);
  finally StrDispose(Text); end;
end;
function TDdeClientConv.RequestData(const Item: string): PChar;
var Data: HDDEData; Source: PChar; Size: LongInt; Count: Word;
begin
  Result := nil;
  Data := Transact(nil, XTYP_REQUEST, Item);
  if Data = 0 then Exit;
  try
    Source := DdeAccessData(Data, @Size);
    if Source = nil then Exit;
    try
      Count := 0;
      while (Count < Size) and (Count < $FFF0) and (Source[Count] <> #0) do Inc(Count);
      Result := StrAlloc(Count + 1);
      Move(Source^, Result^, Count);
      Result[Count] := #0;
    finally DdeUnaccessData(Data); end;
  finally DdeFreeDataHandle(Data); end;
end;

{ TDdeServerConv }
constructor TDdeServerConv.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DdeMgr.FServers.Add(Self);
end;
destructor TDdeServerConv.Destroy;
begin
  if DdeMgr <> nil then DdeMgr.ForgetServer(Self);
  inherited Destroy;
end;
procedure TDdeServerConv.Connect;
begin if Assigned(FOnOpen) then FOnOpen(Self); end;
procedure TDdeServerConv.Disconnect;
begin if Assigned(FOnClose) then FOnClose(Self); end;
function TDdeServerConv.ExecuteMacro(Data: HDDEData): LongInt;
var Lines: TStringList; P: PChar; Size, Index, Start: LongInt;
  procedure AddLine(Stop: LongInt);
  var Line: string;
  begin
    if Stop - Start > 255 then Stop := Start + 255;
    SetString(Line, P + Start, Stop - Start);
    Lines.Add(Line);
  end;
begin
  Result := DDE_FNOTPROCESSED;
  if not Assigned(FOnExecuteMacro) then Exit;
  Lines := TStringList.Create;
  try
    P := DdeAccessData(Data, @Size);
    if P = nil then Exit;
    try
      Index := 0; Start := 0;
      while (Index < Size) and (P[Index] <> #0) do
      begin
        if P[Index] = #10 then
        begin
          if (Index > Start) and (P[Index - 1] = #13) then AddLine(Index - 1) else AddLine(Index);
          Start := Index + 1;
        end;
        Inc(Index);
      end;
      if Index > Start then AddLine(Index);
    finally DdeUnaccessData(Data); end;
    FOnExecuteMacro(Self, Lines);
    Result := DDE_FACK;
  finally Lines.Free; end;
end;

initialization
  DdeMgr := TDdeMgr.Create(nil);
finalization
  DdeMgr.Free;
  DdeMgr := nil;
end.
