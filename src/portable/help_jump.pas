{ SPDX-License-Identifier: GPL-2.0-or-later
  WinHelp JumpID macro construction, independent of the Windows API. }
unit help_jump;
{$mode delphi}{$H+}
interface
uses SysUtils;
function HelpJumpMacro(const FileName, Context: AnsiString): AnsiString;
implementation
function HelpJumpMacro(const FileName, Context: AnsiString): AnsiString;
var I: Integer; Escaped: AnsiString;
begin
  if (Context = '') or (Length(Context) > 255) or (Length(FileName) > 255) then
    raise EConvertError.Create('Invalid help request');
  for I := 1 to Length(Context) do
    if not (Context[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_', '.']) then
      raise EConvertError.Create('Invalid help request');
  Escaped := '';
  for I := 1 to Length(FileName) do
  begin
    if (FileName[I] < #32) or (FileName[I] = '"') then
      raise EConvertError.Create('Invalid help request');
    if FileName[I] = '\' then Escaped := Escaped + '\';
    Escaped := Escaped + FileName[I];
  end;
  Result := 'JumpID("' + Escaped + '","' + Context + '")';
end;
end.
