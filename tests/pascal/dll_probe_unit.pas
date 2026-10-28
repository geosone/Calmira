unit Dll_Probe_Unit;
{ Initialized when DLLPROBE.DLL loads, finalized from its WEP. }
{$mode delphi}{$H-}
interface
var UnitInitialized: Boolean;
procedure LogLine(const Text: string);
implementation
uses WinTypes, WinProcs;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then Exit;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
initialization
  UnitInitialized := True;
finalization
  LogLine('NOTE library finalization ran');
end.
