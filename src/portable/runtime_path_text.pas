{ SPDX-License-Identifier: GPL-2.0-or-later
  Bounded Win16 module-name decoding; no platform or filesystem dependencies. }
unit runtime_path_text;
{$mode delphi}{$H-}
interface
function DecodeModulePath(Buffer: PChar; Count, Capacity: Integer): string;
function IsRootedDriveFileName(const Value: string): Boolean;
function DecodeSourcePath(Buffer: PChar; Count, Capacity: Integer): string;
function ExecutableDirectory(const Value: string): string;
function WrapperSidecarFileName(const Value: string): string;
function IsWrapperModuleName(const Value: string): Boolean;
implementation
function LastSeparator(const Value: string): Integer;
begin
  Result := Length(Value);
  while Result > 0 do
  begin
    if Value[Result] = '\' then Exit;
    Dec(Result);
  end;
end;
function ExecutableDirectory(const Value: string): string;
begin Result := Copy(Value, 1, LastSeparator(Value)); end;
function WrapperSidecarFileName(const Value: string): string;
var Dot: Integer;
begin
  Result := ''; if Value = '' then Exit; Dot := Length(Value);
  while Dot > 0 do
  begin
    if Value[Dot] in ['.', '\'] then Break;
    Dec(Dot);
  end;
  if Dot > 0 then
    if Value[Dot] = '.' then
    begin
      if Dot > 252 then Exit;
      Result := Copy(Value, 1, Dot) + 'SRC'; Exit;
    end;
  if Length(Value) <= 251 then Result := Value + '.SRC';
end;
function IsWrapperModuleName(const Value: string): Boolean;
var Start: Integer;
begin
  Result := False; Start := LastSeparator(Value) + 1;
  if Start > Length(Value) then Exit;
  if Value[Start] = '~' then Inc(Start);
  if Length(Value) - Start < 2 then Exit;
  Result := (UpCase(Value[Start]) = 'U') and (UpCase(Value[Start + 1]) = 'P') and
    (UpCase(Value[Start + 2]) = 'X');
end;
function DecodeModulePath(Buffer: PChar; Count, Capacity: Integer): string;
begin
  Result := '';
  if (Buffer = nil) or (Count <= 0) or (Count > 255) or
    (Count >= Capacity) then Exit;
  if Buffer[Count] <> #0 then Exit;
  SetString(Result, Buffer, Count);
  if Pos(#0, Result) <> 0 then Result := '';
end;
function IsRootedDriveFileName(const Value: string): Boolean;
begin
  Result := False;
  if Length(Value) < 4 then Exit;
  Result := (UpCase(Value[1]) in ['A'..'Z']) and (Value[2] = ':') and
    (Value[3] = '\') and (Value[Length(Value)] <> '\') and
    (Pos(#0, Value) = 0) and (Pos(#13, Value) = 0) and (Pos(#10, Value) = 0);
end;
function DecodeSourcePath(Buffer: PChar; Count, Capacity: Integer): string;
begin
  Result := '';
  if (Buffer = nil) or (Count <= 0) or (Count >= Capacity) then Exit;
  if Buffer[Count - 1] = #10 then Dec(Count);
  if Count > 0 then if Buffer[Count - 1] = #13 then Dec(Count);
  if (Count <= 0) or (Count > 255) then Exit;
  SetString(Result, Buffer, Count);
  if not IsRootedDriveFileName(Result) then Result := '';
end;
end.
