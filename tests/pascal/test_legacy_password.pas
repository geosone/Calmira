program TestLegacyPassword;
{$mode delphi}{$H-}
uses SysUtils, legacy_password;
procedure Check(Okay: Boolean);
begin if not Okay then raise Exception.Create('legacy compatibility check'); end;
function Reference(const S: string): string;
var I: Integer; C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      'A'..'M', 'a'..'m': C := Chr(Ord(C) + 13);
      'N'..'Z', 'n'..'z': C := Chr(Ord(C) - 13);
    end;
    Result := Result + IntToHex(Ord(C), 2);
  end;
end;
var S, Encoded: string; I, N: Integer; Rejected: Boolean;
begin
  Check(EncryptPassword('aA0') = '6E4E30'); Check(DecryptPassword('6e4e30') = 'aA0');
  Check((EncryptPassword('') = '') and (DecryptPassword('') = ''));
  for I := 0 to 255 do begin S := Chr(I); Check(DecryptPassword(EncryptPassword(S)) = S); end;
  for N := 0 to 127 do
  begin
    S := ''; for I := 1 to N do S := S + Chr((I * 23) mod 256);
    Encoded := EncryptPassword(S); Check(Length(Encoded) = N * 2);
    Check(Encoded = Reference(S)); Check(DecryptPassword(Encoded) = S);
  end;
  S := ''; for I := 1 to 128 do S := S + 'x'; Rejected := False;
  try EncryptPassword(S); except on EConvertError do Rejected := True; end; Check(Rejected);
  for S in ['0', '123', 'ZZ', '-1', '+1', ' 0', '0 ', '$1', 'G0'] do
  begin
    Rejected := False; try DecryptPassword(S); except on EConvertError do Rejected := True; end;
    Check(Rejected);
  end;
  Check(IsValidLogin('A1') and IsValidLogin('12345678'));
  Check(not IsValidLogin('') and not IsValidLogin('123456789') and
    not IsValidLogin('two words') and not IsValidLogin('a_b') and not IsValidLogin(#228));
  WriteLn('legacy credential compatibility: OK (not encryption)');
end.
