program TestProgramGroups;

{$mode delphi}
{$H-}

uses program_groups;

type
  TBuffer = array[0..255] of Byte;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn('FAIL: ', MessageText);
    Halt(1);
  end;
end;

procedure PutWord(var B: TBuffer; At: Integer; Value: Word);
begin
  B[At] := Value and $FF;
  B[At + 1] := Value shr 8;
end;

function PutText(var B: TBuffer; At: Integer; const Value: string): Integer;
var
  I: Integer;
begin
  for I := 1 to Length(Value) do
    B[At + I - 1] := Ord(Value[I]);
  B[At + Length(Value)] := 0;
  PutText := At + Length(Value) + 1;
end;

procedure SetChecksum(var B: TBuffer; Size: Integer);
var
  At: Integer;
  Sum: Word;
begin
  PutWord(B, 4, 0);
  Sum := 0;
  At := 0;
  while At + 1 < Size do
  begin
    Sum := Sum + Word(B[At] or (Word(B[At + 1]) shl 8));
    Inc(At, 2);
  end;
  PutWord(B, 4, Word(0 - Sum));
end;

var
  B: ^TBuffer;
  Group: ^TProgramGroup;
  ErrorText: string;
  P, ProgramAt, Size: Integer;
  {$IFNDEF WIN16}
  Arg: Integer;
  {$ENDIF}
begin
  New(B);
  New(Group);
  FillChar(B^, SizeOf(B^), 0);
  B^[0] := Ord('P'); B^[1] := Ord('M');
  B^[2] := Ord('C'); B^[3] := Ord('C');
  PutWord(B^, 22, 36);
  PutWord(B^, 32, 1);
  ProgramAt := 41;
  PutWord(B^, 34, ProgramAt);
  P := PutText(B^, 36, 'Main');
  Check(P = ProgramAt, 'fixture title position');
  PutWord(B^, ProgramAt + 4, 2);
  P := ProgramAt + 24;
  PutWord(B^, ProgramAt + 18, P);
  P := PutText(B^, P, 'File Manager');
  PutWord(B^, ProgramAt + 20, P);
  P := PutText(B^, P, 'WINFILE.EXE');
  PutWord(B^, ProgramAt + 22, P);
  P := PutText(B^, P, 'WINFILE.EXE');
  PutWord(B^, 6, P);
  PutWord(B^, P, $8101); PutWord(B^, P + 2, 0);
  PutWord(B^, P + 4, 17);
  P := PutText(B^, P + 6, 'C:\WINDOWS');
  PutWord(B^, P, $8103); PutWord(B^, P + 2, 0);
  PutWord(B^, P + 4, 8); PutWord(B^, P + 6, 3);
  Size := P + 8;
  SetChecksum(B^, Size);

  Check(ParseProgramGroup(B^, Size, Group^, ErrorText), ErrorText);
  Check(Group^.Name = 'Main', 'group title');
  Check(Group^.ProgramCount = 1, 'program count');
  Check(Group^.Programs[0].Caption = 'File Manager', 'program caption');
  Check(Group^.Programs[0].Command = 'WINFILE.EXE', 'program command');
  Check(Group^.Programs[0].IconIndex = 2, 'icon index');
  Check(Group^.Programs[0].WorkDirectory = 'C:\WINDOWS', 'working directory');
  Check(Group^.Programs[0].ShowCommand = 3, 'show command');

  B^[4] := B^[4] xor 1;
  Check(not ParseProgramGroup(B^, Size, Group^, ErrorText),
    'bad checksum must be rejected');
  Check(ErrorText = 'invalid group file checksum', 'checksum diagnostic');

  {$IFNDEF WIN16}
  for Arg := 1 to ParamCount do
  begin
    Check(LoadProgramGroup(ParamStr(Arg), Group^, ErrorText),
      ParamStr(Arg) + ': ' + ErrorText);
    WriteLn(Group^.Name, ': ', Group^.ProgramCount, ' program(s)');
  end;
  {$ENDIF}
  Dispose(Group);
  Dispose(B);
  WriteLn('program group tests: OK');
end.
