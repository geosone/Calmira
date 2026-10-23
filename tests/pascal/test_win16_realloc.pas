program ReallocTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils;
type TBytes = array[0..4095] of Byte; PBytes = ^TBytes;
var Block, Hole, Guard, HoleAddress: Pointer;
  Failed, Intact, PrefixIntact: Boolean; I: Integer;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10;
  _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure ResizeCase(OldSize, NewSize: Word);
var Data, Neighbor: Pointer; J, Kept: Word;
  DataOkay, NeighborOkay: Boolean; OldText, NewText: string;
begin
  Str(OldSize, OldText); Str(NewSize, NewText);
  LogLine('STEP resize ' + OldText + ' -> ' + NewText);
  GetMem(Data, OldSize); FillChar(Data^, OldSize, $C3);
  GetMem(Neighbor, 128); FillChar(Neighbor^, 128, $69);
  ReAllocMem(Data, NewSize);
  Kept := OldSize;
  if Kept > NewSize then Kept := NewSize;
  DataOkay := Data <> nil;
  if DataOkay then
    for J := 0 to Kept - 1 do
      if PBytes(Data)^[J] <> $C3 then DataOkay := False;
  NeighborOkay := True;
  for J := 0 to 127 do
    if PBytes(Neighbor)^[J] <> $69 then NeighborOkay := False;
  Check(DataOkay, 'resized allocation preserves minimum-size prefix');
  Check(NeighborOkay, 'resize preserves live neighbor');
  if DataOkay and NeighborOkay then
  begin FreeMem(Data); FreeMem(Neighbor); end;
end;
procedure ResizeBranches;
var Data: Pointer; J: Integer; Okay: Boolean;
begin
  LogLine('STEP nil allocation and zero-size release');
  Data := nil; ReAllocMem(Data, 0);
  Check(Data = nil, 'nil zero-size resize remains nil');
  ReAllocMem(Data, 31);
  Check(Data <> nil, 'nil resize allocates');
  if Data = nil then Exit;
  FillChar(Data^, 31, $96);
  ReAllocMem(Data, 31);
  Okay := True;
  for J := 0 to 30 do if PBytes(Data)^[J] <> $96 then Okay := False;
  Check(Okay, 'same-size resize preserves bytes');
  ReAllocMem(Data, 0);
  Check(Data = nil, 'zero-size resize frees and clears pointer');
  ResizeCase(511, 1);
  ResizeCase(255, 15);
  ResizeCase(1021, 255);
  ResizeCase(16, 511);
  ResizeCase(511, 2048);
  ResizeCase(2048, 32);
  ResizeCase(2048, 4096);
end;
begin
  FillChar(StackBottom^, 64, $A5);
  LogLine('STEP native suballocated shrink bounds');
  GetMem(Block, 128); FillChar(Block^, 128, $A5);
  GetMem(Hole, 16);
  GetMem(Guard, 128); FillChar(Guard^, 128, $5A);
  Check((Seg(Hole^) = Seg(Guard^)) and (Ofs(Guard^) = Ofs(Hole^) + 20),
    'small destination immediately precedes live guard');
  HoleAddress := Hole; FreeMem(Hole); Hole := nil;
  ReAllocMem(Block, 16);
  Check(Block = HoleAddress, 'shrinking allocation reuses controlled small hole');
  Intact := True;
  for I := 0 to 127 do if PBytes(Guard)^[I] <> $5A then Intact := False;
  Check(Intact, 'shrink does not overwrite neighboring live allocation');
  PrefixIntact := True;
  for I := 0 to 15 do
    if PBytes(Block)^[I] <> $A5 then PrefixIntact := False;
  Check(PrefixIntact, 'shrunk block preserves requested prefix');
  if Intact then begin FreeMem(Block); FreeMem(Guard); end;
  { Do not walk a known-corrupted heap merely to clean up a failing diagnostic. }
  if Intact and PrefixIntact then ResizeBranches;
  Check(StackGuardIntact, 'realloc stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
