{ SPDX-License-Identifier: GPL-2.0-or-later
  Compatibility codec derived from src/password.pas, NOT secure encryption.
  Copyright 1997-1998 Li-Hsin Huang; 1998-2002 Calmira Online!;
  2004-2007 Alexandre Rodrigues de Sousa; 2022-2023 Hunter Turcin.
  Preserve ROT13 followed by uppercase hex for representable legacy values. }
unit legacy_password;
{$mode delphi}{$H-}
interface
const MaxLegacyPasswordLength = 127;
function EncryptPassword(const S: string): string;
function DecryptPassword(const S: string): string;
function IsValidLogin(const S: string): Boolean;
implementation
uses SysUtils;
function Rotate(C: Char): Char;
begin
  case C of
    'A'..'M', 'a'..'m': Result := Chr(Ord(C) + 13);
    'N'..'Z', 'n'..'z': Result := Chr(Ord(C) - 13);
  else Result := C;
  end;
end;
function EncryptPassword(const S: string): string;
const Hex: string[16] = '0123456789ABCDEF';
var I, Value: Integer;
begin
  if Length(S) > MaxLegacyPasswordLength then raise EConvertError.Create('Legacy password too long');
  Result := ''; Result[0] := Chr(Length(S) * 2);
  for I := 1 to Length(S) do
  begin
    Value := Ord(Rotate(S[I]));
    Result[I * 2 - 1] := Hex[(Value shr 4) + 1]; Result[I * 2] := Hex[(Value and 15) + 1];
  end;
end;
function Nibble(C: Char): Byte;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
  else raise EConvertError.Create('Invalid legacy password encoding');
  end;
end;
function DecryptPassword(const S: string): string;
var I: Integer;
begin
  if Odd(Length(S)) then raise EConvertError.Create('Invalid legacy password encoding');
  Result := ''; Result[0] := Chr(Length(S) div 2);
  for I := 1 to Length(Result) do Result[I] := Rotate(Chr((Nibble(S[I * 2 - 1]) shl 4) or Nibble(S[I * 2])));
end;
function IsValidLogin(const S: string): Boolean;
var I: Integer;
begin
  Result := False;
  if (Length(S) = 0) or (Length(S) > 8) then Exit;
  for I := 1 to Length(S) do if not (S[I] in ['a'..'z', 'A'..'Z', '0'..'9']) then Exit;
  Result := True;
end;
end.
