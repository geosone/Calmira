{ SPDX-License-Identifier: GPL-2.0-or-later
  Bounded ANSI text for the native exception dialog, independent of the VCL. }
unit exception_text;
{$mode delphi}{$H+}
interface
const ExceptionTextLimit = 1024;
function ExceptionDisplayText(const MessageText, ClassName: AnsiString): AnsiString;
implementation
function ExceptionDisplayText(const MessageText, ClassName: AnsiString): AnsiString;
var Source: AnsiString; I: Integer;
begin
  Source := MessageText;
  if Source = '' then Source := ClassName;
  if Source = '' then Source := 'Exception';
  Result := Copy(Source, 1, ExceptionTextLimit);
  for I := 1 to Length(Result) do
    if Result[I] = #0 then Result[I] := ' ';
  if Length(Source) > ExceptionTextLimit then
  begin
    Result[ExceptionTextLimit - 2] := '.';
    Result[ExceptionTextLimit - 1] := '.';
    Result[ExceptionTextLimit] := '.';
  end;
end;
end.
