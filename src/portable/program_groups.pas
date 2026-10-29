{ Portable reader for Windows 3.x Program Manager .GRP files. }
unit program_groups;

{$IFDEF FPC}
  {$mode delphi}
  {$H-}
{$ENDIF}

interface

const
  MaxGroupPrograms = 64;

type
  TProgramGroupItem = record
    Caption: string[79];
    Command: string[79];
    IconFile: string[79];
    WorkDirectory: string[79];
    IconIndex: Integer;
    HotKey: Word;
    ShowCommand: Word;
  end;

  TProgramGroup = record
    Name: string[79];
    ProgramCount: Integer;
    Programs: array[0..MaxGroupPrograms - 1] of TProgramGroupItem;
  end;

function ParseProgramGroup(const Buffer; Size: Longint;
  var Group: TProgramGroup; var ErrorText: string): Boolean;
function LoadProgramGroup(const FileName: string;
  var Group: TProgramGroup; var ErrorText: string): Boolean;

implementation

type
  TGroupBytes = array[0..65520] of Byte;
  PGroupBytes = ^TGroupBytes;

function ReadWord(Data: PGroupBytes; Offset: Longint): Word;
begin
  ReadWord := Data^[Offset] or (Word(Data^[Offset + 1]) shl 8);
end;

function ReadString(Data: PGroupBytes; Size, Offset, Limit: Longint;
  var Value: string): Boolean;
var
  I: Longint;
begin
  Value := '';
  ReadString := False;
  if (Offset < 0) or (Offset >= Size) then
    Exit;
  if (Limit > Size) or (Limit <= Offset) then
    Limit := Size;
  I := Offset;
  while (I < Limit) and (Data^[I] <> 0) do
  begin
    if Length(Value) = 255 then
      Exit;
    Value := Value + Char(Data^[I]);
    Inc(I);
  end;
  ReadString := (I < Limit) and (Data^[I] = 0);
end;

function ValidChecksum(Data: PGroupBytes; Size: Longint): Boolean;
var
  I: Longint;
  Sum: Word;
begin
  Sum := 0;
  I := 0;
  while I + 1 < Size do
  begin
    Sum := Sum + ReadWord(Data, I);
    Inc(I, 2);
  end;
  ValidChecksum := Sum = 0;
end;

function ParseProgramGroup(const Buffer; Size: Longint;
  var Group: TProgramGroup; var ErrorText: string): Boolean;
var
  Data: PGroupBytes;
  ExtensionAt, ProgramAt, RecordEnd, P, NextP: Longint;
  I, J, Count, Sequence: Integer;
  SequenceMap: array[0..MaxGroupPrograms - 1] of Integer;
  ExtensionType, ExtensionProgram, ExtensionSize: Word;
  TextValue: string;
begin
  Data := @Buffer;
  FillChar(Group, SizeOf(Group), 0);
  ErrorText := '';
  ParseProgramGroup := False;
  if (Size < 34) or (Size > SizeOf(TGroupBytes)) then
  begin
    ErrorText := 'invalid group file size';
    Exit;
  end;
  if (Data^[0] <> Ord('P')) or (Data^[1] <> Ord('M')) or
    (Data^[2] <> Ord('C')) or (Data^[3] <> Ord('C')) then
  begin
    ErrorText := 'missing PMCC signature';
    Exit;
  end;
  if not ValidChecksum(Data, Size) then
  begin
    ErrorText := 'invalid group file checksum';
    Exit;
  end;
  ExtensionAt := ReadWord(Data, 6);
  if (ExtensionAt < 34) or (ExtensionAt > Size) then
  begin
    ErrorText := 'invalid extension offset';
    Exit;
  end;
  Count := ReadWord(Data, 32);
  if (Count > MaxGroupPrograms) or (34 + Count * 2 > Size) then
  begin
    ErrorText := 'too many programs or a truncated program table';
    Exit;
  end;
  if not ReadString(Data, Size, ReadWord(Data, 22), ExtensionAt,
    TextValue) then
  begin
    ErrorText := 'invalid group name';
    Exit;
  end;
  Group.Name := TextValue;
  for I := 0 to MaxGroupPrograms - 1 do
    SequenceMap[I] := -1;

  for I := 0 to Count - 1 do
  begin
    ProgramAt := ReadWord(Data, 34 + I * 2);
    if ProgramAt = 0 then
      Continue;
    if (ProgramAt < 34 + Count * 2) or (ProgramAt + 24 > ExtensionAt) then
    begin
      ErrorText := 'invalid program record offset';
      Exit;
    end;
    RecordEnd := ExtensionAt;
    for J := I + 1 to Count - 1 do
    begin
      NextP := ReadWord(Data, 34 + J * 2);
      if (NextP > ProgramAt) and (NextP < RecordEnd) then
        RecordEnd := NextP;
    end;
    SequenceMap[I] := Group.ProgramCount;
    with Group.Programs[Group.ProgramCount] do
    begin
      IconIndex := Integer(ReadWord(Data, ProgramAt + 4));
      HotKey := 0;
      ShowCommand := 1;
      WorkDirectory := '';
      if not ReadString(Data, Size, ReadWord(Data, ProgramAt + 18),
        RecordEnd, TextValue) then
      begin
        ErrorText := 'invalid program caption';
        Exit;
      end;
      Caption := TextValue;
      if not ReadString(Data, Size, ReadWord(Data, ProgramAt + 20),
        RecordEnd, TextValue) then
      begin
        ErrorText := 'invalid program command';
        Exit;
      end;
      Command := TextValue;
      if not ReadString(Data, Size, ReadWord(Data, ProgramAt + 22),
        RecordEnd, TextValue) then
      begin
        ErrorText := 'invalid program icon file';
        Exit;
      end;
      IconFile := TextValue;
    end;
    Inc(Group.ProgramCount);
  end;

  P := ExtensionAt;
  while P < Size do
  begin
    if P + 6 > Size then
    begin
      ErrorText := 'truncated group extension';
      Exit;
    end;
    ExtensionType := ReadWord(Data, P);
    ExtensionProgram := ReadWord(Data, P + 2);
    ExtensionSize := ReadWord(Data, P + 4);
    { Program Manager ends the tags with $FFFF/$FFFF and size 0. }
    if (ExtensionType = $FFFF) and (ExtensionProgram = $FFFF) then
      Break;
    if (ExtensionSize < 6) or (P + ExtensionSize > Size) then
    begin
      ErrorText := 'invalid group extension size';
      Exit;
    end;
    if ExtensionProgram <> $FFFF then
    begin
      Sequence := ExtensionProgram;
      if (Sequence >= 0) and (Sequence < Count) and
        (SequenceMap[Sequence] >= 0) then
      begin
        I := SequenceMap[Sequence];
        case ExtensionType of
          $8101:
            begin
              if not ReadString(Data, Size, P + 6, P + ExtensionSize,
                TextValue) then
              begin
                ErrorText := 'invalid working-directory extension';
                Exit;
              end;
              Group.Programs[I].WorkDirectory := TextValue;
            end;
          $8102:
            if ExtensionSize >= 8 then
              Group.Programs[I].HotKey := ReadWord(Data, P + 6);
          $8103:
            if ExtensionSize >= 8 then
              Group.Programs[I].ShowCommand := ReadWord(Data, P + 6);
        end;
      end;
    end;
    Inc(P, ExtensionSize);
  end;
  ParseProgramGroup := True;
end;

function LoadProgramGroup(const FileName: string;
  var Group: TProgramGroup; var ErrorText: string): Boolean;
var
  Source: File;
  Buffer: PGroupBytes;
  Size: Longint;
  ReadCount: Word;
  ErrorCode: Integer;
begin
  LoadProgramGroup := False;
  ErrorText := '';
  Buffer := nil;
  AssignFile(Source, FileName);
  {$I-}
  Reset(Source, 1);
  ErrorCode := IOResult;
  {$I+}
  if ErrorCode <> 0 then
  begin
    ErrorText := 'cannot read group file';
    Exit;
  end;
  Size := FileSize(Source);
  if (Size < 1) or (Size > SizeOf(TGroupBytes)) then
  begin
    CloseFile(Source);
    ErrorText := 'invalid group file size';
    Exit;
  end;
  GetMem(Buffer, Size);
  {$I-}
  BlockRead(Source, Buffer^, Word(Size), ReadCount);
  CloseFile(Source);
  ErrorCode := IOResult;
  {$I+}
  if (ErrorCode <> 0) or (ReadCount <> Size) then
    ErrorText := 'cannot read group file'
  else
    LoadProgramGroup := ParseProgramGroup(Buffer^, Size, Group, ErrorText);
  FreeMem(Buffer, Size);
end;

end.
