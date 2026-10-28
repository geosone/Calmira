library DllProbe;
{ A Free Pascal Win16 library: test_win16_dll.pas loads it statically and
  with LoadLibrary. }
{$mode delphi}{$H-}
uses WinTypes, WinProcs, SysUtils, Dll_Probe_Unit;
var
  MainRan: Boolean;
  Calls: Integer;

function ProbeTwice(X: Integer): Integer; export;
begin
  Inc(Calls);
  Result := X * 2;
end;

function ProbeState: Integer; export;
{ Bit 0: the main block ran; bit 1: IsLibrary; bit 2: HInstance is this
  module; bit 3: the units were initialized. }
var Name: array[0..143] of Char;
begin
  Result := 0;
  if MainRan then Result := Result or 1;
  if IsLibrary then Result := Result or 2;
  GetModuleFileName(HInstance, Name, SizeOf(Name));
  if Pos('DLLPROBE.DLL', UpperCase(StrPas(Name))) > 0 then Result := Result or 4;
  if UnitInitialized then Result := Result or 8;
end;

function ProbeHeap(const S: string): Integer; export;
{ Heap, long strings and exceptions inside the library. }
var P: PChar; L: AnsiString;
begin
  GetMem(P, 1000);
  StrPCopy(P, S);
  L := StrPas(P) + StrPas(P);
  FreeMem(P, 1000);
  try
    raise Exception.Create(L);
  except
    on E: Exception do Result := Length(E.Message);
  end;
end;

exports ProbeTwice, ProbeState, ProbeHeap;

begin
  MainRan := True;
end.
