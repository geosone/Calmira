unit far_import_probe;
{$mode delphi}
interface
{ Declared here and bound to DLL imports below, as vcl/lfnutils.pas binds
  LFNFUNCS.DLL: FPC reaches each import through a wrapper. }
function ProbeTickCount: LongInt;
function ProbeWindowsVersion: LongInt;
{ objpas's ParamStr, which every MSWINDOWS target links as _FPC_ParamStrA. }
function ProbeParamStr(Index: Integer): string;
implementation
function ProbeTickCount: LongInt; external 'USER' name 'GetTickCount';
function ProbeWindowsVersion: LongInt; external 'KERNEL' name 'GetVersion';
function ProbeParamStr(Index: Integer): string;
begin
  Result := ParamStr(Index);
end;
end.
