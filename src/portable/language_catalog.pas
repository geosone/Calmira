{ Runtime language catalogues: one executable, external Windows ANSI data. }
unit language_catalog;
{$IFDEF FPC}{$mode delphi}{$H-}{$ENDIF}
interface
function ConfigureLanguage(const Directory, Code: string): Boolean;
function LanguageText(const Section, Key, Default: string): string;
function SelectedLanguage: string;
procedure InitializeLanguage(const Directory, ConfigFile: string);
function ReadConfiguration(const FileName, Section, Key, Default: string): string;
{ How often a catalogue was read from start to end, for the tests. }
function CatalogueScans: LongInt;
implementation
uses SysUtils;
const ReadBufferSize = 4096;
type TReadBuffer = array[0..ReadBufferSize - 1] of Char;
var
  LanguageDirectory: string;
  LanguageCode: string;
  { Every lookup reads the catalogue again; with Text's 128-byte buffer that
    is a DOS read for each 128 bytes, so a dialog with long lists took
    seconds to open. Kept on the heap: Calmira's task stacks are small. }
  ReadBuffer: ^TReadBuffer;

{ A form loads with a lookup for each caption and hint, and each lookup read
  the catalogue up to its key: a folder window took seconds to open. A
  catalogue is now read once into an index of its keys (hash, section and
  file position); a lookup reads only the line of its key. As
  GetPrivateProfileString, the first section of a name counts, and the first
  key in it. }
const
  MaxEntries = 8000;
  MaxSections = 48;
  MaxIndexes = 3;
type
  TIndexEntry = packed record
    Hash: Word;
    Section: Byte;
    Offset: LongInt;
  end;
  TIndexEntries = array[0..MaxEntries - 1] of TIndexEntry;
  TSectionName = string[63];
  TCatalogueIndex = record
    FileName: string;
    Usable: Boolean;
    Count: Integer;
    Entries: ^TIndexEntries;
    SectionCount: Integer;
    Sections: array[1..MaxSections] of TSectionName;
  end;
  PCatalogueIndex = ^TCatalogueIndex;
var
  Indexes: array[0..MaxIndexes - 1] of PCatalogueIndex;
  NextIndex: Integer;
  Scans: LongInt;

function SafeCode(const Code: string): Boolean;
var I: Integer;
begin
  SafeCode := False;
  if (Length(Code) < 2) or (Length(Code) > 8) then Exit;
  for I := 1 to Length(Code) do
    if not (Code[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-']) then Exit;
  SafeCode := True;
end;

function DecodeValue(const Value: string): string;
var I: Integer; ResultText: string;
begin
  ResultText := '';
  I := 1;
  while I <= Length(Value) do
  begin
    if (Value[I] = '\') and (I < Length(Value)) then
    begin
      Inc(I);
      case Value[I] of
        'n': ResultText := ResultText + #13#10;
        't': ResultText := ResultText + #9;
        '\': ResultText := ResultText + '\';
      else ResultText := ResultText + '\' + Value[I];
      end;
    end
    else ResultText := ResultText + Value[I];
    Inc(I);
  end;
  DecodeValue := ResultText;
end;

function ReadIniValue(const FileName, Section, Key: string;
  var Value: string): Boolean;
var
  Source: Text;
  Line, ActiveSection: string;
  P, ErrorCode: Integer;
begin
  ReadIniValue := False;
  ActiveSection := '';
  AssignFile(Source, FileName);
  if ReadBuffer = nil then New(ReadBuffer);
  SetTextBuf(Source, ReadBuffer^, ReadBufferSize);
  {$I-} Reset(Source); ErrorCode := IOResult; {$I+}
  if ErrorCode <> 0 then Exit;
  try
    while not Eof(Source) do
    begin
      ReadLn(Source, Line);
      if (Line <> '') and (Line[1] = '[') and
        (Line[Length(Line)] = ']') then
      begin
        { As GetPrivateProfileString, the first section of that name counts;
          the rest of the file need not be read once it has ended. }
        if CompareText(ActiveSection, Section) = 0 then Exit;
        ActiveSection := Copy(Line, 2, Length(Line) - 2);
      end
      else if CompareText(ActiveSection, Section) = 0 then
      begin
        P := Pos('=', Line);
        if (P > 0) and
          (CompareText(Copy(Line, 1, P - 1), Key) = 0) then
        begin
          Value := Copy(Line, P + 1, 255);
          ReadIniValue := True;
          Exit;
        end;
      end;
    end;
  finally
    CloseFile(Source);
  end;
end;

function CatalogueScans: LongInt;
begin CatalogueScans := Scans; end;

function KeyHash(const Key: string): Word;
var I: Integer; H: Word;
begin
  H := 0;
  for I := 1 to Length(Key) do
    H := Word(H * 31 + Ord(UpCase(Key[I])));
  KeyHash := H;
end;

function OpenCatalogue(var Source: File; const FileName: string): Boolean;
var SavedMode: Byte;
begin
  AssignFile(Source, FileName);
  SavedMode := FileMode;
  FileMode := 0;
  {$I-} Reset(Source, 1); {$I+}
  FileMode := SavedMode;
  OpenCatalogue := IOResult = 0;
end;

{ Reads the catalogue once, line by line as ReadLn into a short string would
  see it, and records where each key of a first-named section is. }
procedure BuildIndex(Index: PCatalogueIndex);
var
  Source: File;
  Got, I, P: Integer;
  Position, LineStart: LongInt;
  Line: string;
  LineLength: Integer;
  Active: Integer;
  SkipLF, Usable: Boolean;
  Name: string;

  procedure EndLine;
  var K: Integer;
  begin
    Line[0] := Chr(LineLength);
    if (LineLength > 0) and (Line[1] = '[') and (Line[LineLength] = ']') then
    begin
      Name := Copy(Line, 2, LineLength - 2);
      Active := 0;
      for K := 1 to Index^.SectionCount do
        if CompareText(Index^.Sections[K], Name) = 0 then Active := -1;
      if Active = 0 then
      begin
        if (Length(Name) > High(TSectionName)) or
          (Index^.SectionCount = MaxSections) then Usable := False
        else
        begin
          Inc(Index^.SectionCount);
          Index^.Sections[Index^.SectionCount] := Name;
          Active := Index^.SectionCount;
        end;
      end;
    end
    else if Active > 0 then
    begin
      P := Pos('=', Line);
      if P > 0 then
        if Index^.Count = MaxEntries then Usable := False
        else
        begin
          Index^.Entries^[Index^.Count].Hash := KeyHash(Copy(Line, 1, P - 1));
          Index^.Entries^[Index^.Count].Section := Active;
          Index^.Entries^[Index^.Count].Offset := LineStart;
          Inc(Index^.Count);
        end;
    end;
    LineLength := 0;
  end;

begin
  Index^.Usable := False;
  Index^.Count := 0;
  Index^.SectionCount := 0;
  if not OpenCatalogue(Source, Index^.FileName) then Exit;
  Inc(Scans);
  if ReadBuffer = nil then New(ReadBuffer);
  if Index^.Entries = nil then New(Index^.Entries);
  Usable := True;
  Active := 0;
  LineLength := 0;
  LineStart := 0;
  Position := 0;
  SkipLF := False;
  try
    repeat
      {$I-} BlockRead(Source, ReadBuffer^, ReadBufferSize, Got); {$I+}
      if IOResult <> 0 then begin Usable := False; Got := 0; end;
      for I := 0 to Got - 1 do
      begin
        if SkipLF and (ReadBuffer^[I] = #10) then
        begin
          SkipLF := False;
          LineStart := Position + I + 1;
          Continue;
        end;
        SkipLF := False;
        case ReadBuffer^[I] of
          #13, #10:
            begin
              EndLine;
              SkipLF := ReadBuffer^[I] = #13;
              LineStart := Position + I + 1;
            end;
        else
          if LineLength < 255 then
          begin
            Inc(LineLength);
            Line[LineLength] := ReadBuffer^[I];
          end;
        end;
      end;
      Inc(Position, Got);
    until Got < ReadBufferSize;
    if LineLength > 0 then EndLine;
  finally
    CloseFile(Source);
  end;
  Index^.Usable := Usable;
end;

function FindIndex(const FileName: string): PCatalogueIndex;
var I: Integer; Index: PCatalogueIndex;
begin
  for I := 0 to MaxIndexes - 1 do
    if (Indexes[I] <> nil) and (Indexes[I]^.FileName = FileName) then
    begin
      FindIndex := Indexes[I];
      Exit;
    end;
  Index := Indexes[NextIndex];
  if Index = nil then
  begin
    New(Index);
    Index^.Entries := nil;
    Indexes[NextIndex] := Index;
  end;
  NextIndex := (NextIndex + 1) mod MaxIndexes;
  Index^.FileName := FileName;
  BuildIndex(Index);
  FindIndex := Index;
end;

{ The line of a key, as ReadLn into a short string reads it. }
function ReadLineAt(var Source: File; Offset: LongInt; var Line: string): Boolean;
var Buffer: array[0..255] of Char; Got, I: Integer;
begin
  ReadLineAt := False;
  {$I-} Seek(Source, Offset); {$I+}
  if IOResult <> 0 then Exit;
  {$I-} BlockRead(Source, Buffer, SizeOf(Buffer), Got); {$I+}
  if IOResult <> 0 then Exit;
  I := 0;
  while (I < Got) and (I < 255) and not (Buffer[I] in [#13, #10]) do
  begin
    Line[I + 1] := Buffer[I];
    Inc(I);
  end;
  Line[0] := Chr(I);
  ReadLineAt := True;
end;

function ReadIndexedValue(const FileName, Section, Key: string;
  var Value: string; var Handled: Boolean): Boolean;
var
  Index: PCatalogueIndex;
  Source: File;
  Section_, I, P: Integer;
  Hash: Word;
  Line: string;
  Opened: Boolean;
begin
  ReadIndexedValue := False;
  Handled := False;
  Index := FindIndex(FileName);
  if not Index^.Usable then Exit;
  Handled := True;
  Section_ := 0;
  for I := 1 to Index^.SectionCount do
    if (Section_ = 0) and (CompareText(Index^.Sections[I], Section) = 0) then
      Section_ := I;
  if Section_ = 0 then Exit;
  Hash := KeyHash(Key);
  Opened := False;
  try
    for I := 0 to Index^.Count - 1 do
      if (Index^.Entries^[I].Hash = Hash) and
        (Index^.Entries^[I].Section = Section_) then
      begin
        if not Opened then
        begin
          if not OpenCatalogue(Source, FileName) then
          begin
            Handled := False;
            Exit;
          end;
          Opened := True;
        end;
        if not ReadLineAt(Source, Index^.Entries^[I].Offset, Line) then
        begin
          Handled := False;
          Exit;
        end;
        P := Pos('=', Line);
        if (P > 0) and (CompareText(Copy(Line, 1, P - 1), Key) = 0) then
        begin
          Value := Copy(Line, P + 1, 255);
          ReadIndexedValue := True;
          Exit;
        end;
      end;
  finally
    if Opened then CloseFile(Source);
  end;
end;

function ReadValue(const Code, Section, Key: string;
  var Value: string): Boolean;
var Handled: Boolean;
begin
  Value := '';
  ReadValue := ReadIndexedValue(LanguageDirectory + Code + '.LNG',
    Section, Key, Value, Handled);
  if not Handled then
    ReadValue := ReadIniValue(LanguageDirectory + Code + '.LNG',
      Section, Key, Value);
  Value := DecodeValue(Value);
end;

function ReadConfiguration(const FileName, Section, Key, Default: string): string;
var Value: string;
begin
  Value := Default;
  ReadIniValue(FileName, Section, Key, Value);
  ReadConfiguration := Value;
end;

function ConfigureLanguage(const Directory, Code: string): Boolean;
var Probe: string;
begin
  LanguageDirectory := Directory;
  if (LanguageDirectory <> '') and
    not (LanguageDirectory[Length(LanguageDirectory)] in ['\', '/']) then
    LanguageDirectory := LanguageDirectory + PathDelim;
  LanguageCode := 'en';
  ConfigureLanguage := False;
  if not SafeCode(Code) then Exit;
  if ReadValue(LowerCase(Code), 'Language', 'Code', Probe) and
    (CompareText(Probe, Code) = 0) then
  begin
    LanguageCode := LowerCase(Code);
    ConfigureLanguage := True;
  end;
end;

function LanguageText(const Section, Key, Default: string): string;
var Value: string;
begin
  if ReadValue(LanguageCode, Section, Key, Value) or
    ((LanguageCode <> 'en') and ReadValue('en', Section, Key, Value)) then
    LanguageText := Value
  else LanguageText := Default;
end;

function SelectedLanguage: string;
begin SelectedLanguage := LanguageCode; end;
procedure InitializeLanguage(const Directory, ConfigFile: string);
var Code: string;
begin
  Code := 'en';
  ReadIniValue(ConfigFile, 'Language', 'Selected', Code);
  ConfigureLanguage(Directory, Code);
end;
initialization
  LanguageCode := 'en';
end.
