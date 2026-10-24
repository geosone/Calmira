{ SPDX-License-Identifier: GPL-2.0-or-later
  DDEML.DLL bindings used by DdeMan: instances, string handles, data
  handles, conversations and client transactions (Windows 3.1 SDK). }
unit DDEML;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL DDEML.DLL requires Win16}{$ENDIF}
interface
uses WinTypes;
type
  HConv = LongInt;
  HSZ = LongInt;
  HDDEData = LongInt;
  { Far pascal callback; pass it through MakeProcInstance. }
  TFNCallback = function(CallType, Fmt: Word; Conv: HConv; hsz1, hsz2: HSZ;
    Data: HDDEData; Data1, Data2: LongInt): HDDEData;
  PConvContext = Pointer;
const
  XTYPF_NOBLOCK = $0002;
  XCLASS_BOOL = $1000;
  XCLASS_DATA = $2000;
  XCLASS_FLAGS = $4000;
  XCLASS_NOTIFICATION = $8000;
  XTYP_ERROR = $0000 or XCLASS_NOTIFICATION or XTYPF_NOBLOCK;
  XTYP_ADVDATA = $0010 or XCLASS_FLAGS;
  XTYP_ADVREQ = $0020 or XCLASS_DATA or XTYPF_NOBLOCK;
  XTYP_ADVSTART = $0030 or XCLASS_BOOL;
  XTYP_ADVSTOP = $0040 or XCLASS_NOTIFICATION;
  XTYP_EXECUTE = $0050 or XCLASS_FLAGS;
  XTYP_CONNECT = $0060 or XCLASS_BOOL or XTYPF_NOBLOCK;
  XTYP_CONNECT_CONFIRM = $0070 or XCLASS_NOTIFICATION or XTYPF_NOBLOCK;
  XTYP_XACT_COMPLETE = $0080 or XCLASS_NOTIFICATION;
  XTYP_POKE = $0090 or XCLASS_FLAGS;
  XTYP_REGISTER = $00A0 or XCLASS_NOTIFICATION or XTYPF_NOBLOCK;
  XTYP_REQUEST = $00B0 or XCLASS_DATA;
  XTYP_DISCONNECT = $00C0 or XCLASS_NOTIFICATION or XTYPF_NOBLOCK;
  XTYP_UNREGISTER = $00D0 or XCLASS_NOTIFICATION or XTYPF_NOBLOCK;
  XTYP_WILDCONNECT = $00E0 or XCLASS_DATA or XTYPF_NOBLOCK;
  DDE_FACK = $8000;
  DDE_FBUSY = $4000;
  DDE_FNOTPROCESSED = $0000;
  APPCLASS_STANDARD = $00000000;
  CBF_FAIL_ADVISES = $00004000;
  CBF_FAIL_POKES = $00010000;
  CBF_SKIP_REGISTRATIONS = $00080000;
  CBF_SKIP_UNREGISTRATIONS = $00100000;
  DNS_REGISTER = $0001;
  DNS_UNREGISTER = $0002;
  CP_WINANSI = 1004;
  TIMEOUT_ASYNC = LongInt($FFFFFFFF);
  DMLERR_NO_ERROR = 0;
function DdeInitialize(var Inst: LongInt; Callback: TFarProc; Cmd, Res: LongInt): Word; external 'DDEML';
function DdeUninitialize(Inst: LongInt): Bool; external 'DDEML';
function DdeConnect(Inst: LongInt; Service, Topic: HSZ; Context: PConvContext): HConv; external 'DDEML';
function DdeDisconnect(Conv: HConv): Bool; external 'DDEML';
function DdeClientTransaction(Data: Pointer; Size: LongInt; Conv: HConv; Item: HSZ;
  Fmt, XType: Word; Timeout: LongInt; Result: PLongInt): HDDEData; external 'DDEML';
function DdeCreateDataHandle(Inst: LongInt; Source: Pointer; Size, Offset: LongInt;
  Item: HSZ; Fmt, Cmd: Word): HDDEData; external 'DDEML';
function DdeAccessData(Data: HDDEData; Size: PLongInt): Pointer; external 'DDEML';
function DdeUnaccessData(Data: HDDEData): Bool; external 'DDEML';
function DdeFreeDataHandle(Data: HDDEData): Bool; external 'DDEML';
function DdeCreateStringHandle(Inst: LongInt; Text: PChar; CodePage: Integer): HSZ; external 'DDEML';
function DdeFreeStringHandle(Inst: LongInt; Handle: HSZ): Bool; external 'DDEML';
function DdeQueryString(Inst: LongInt; Handle: HSZ; Text: PChar; Size: LongInt;
  CodePage: Integer): LongInt; external 'DDEML';
function DdeNameService(Inst: LongInt; Name, Reserved: HSZ; Cmd: Word): HDDEData; external 'DDEML';
function DdeGetLastError(Inst: LongInt): Word; external 'DDEML';
implementation
end.
