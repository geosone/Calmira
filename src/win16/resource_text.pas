{ SPDX-License-Identifier: GPL-2.0-or-later
  Optional numeric-string provider with bound Win16 STRINGTABLE fallback.
  Does not initialize the full portable catalogue or Forms application. }
unit resource_text;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This resource adapter requires Win16}{$ENDIF}
interface
type TResourceTextProvider = function(Ident: Word; const DefaultText: string): string of object;
function SetResourceTextProvider(Value: TResourceTextProvider): TResourceTextProvider;
function LocalLoadStr(Ident: Word): string;
implementation
uses SysUtils, WinTypes, WinProcs;
var Provider: TResourceTextProvider;
function SetResourceTextProvider(Value: TResourceTextProvider): TResourceTextProvider;
begin Result := Provider; Provider := Value; end;
procedure ApplyProvider(Ident: Word; var Value: string);
begin
  { Keep the provider's separate 256-byte return temporary off the bound-only
    LoadString path. Never return directly into its aliased default argument. }
  Value := Provider(Ident, Value);
end;
function LocalLoadStr(Ident: Word): string;
var Buffer: array[0..255] of Char; Count: Integer;
begin
  Result := '';
  Count := LoadString(HInstance, Ident, Buffer, SizeOf(Buffer));
  if Count > 0 then SetString(Result, PChar(@Buffer), Count);
  if Assigned(Provider) then ApplyProvider(Ident, Result);
  if Pos(#0, Result) <> 0 then raise Exception.Create('Invalid string catalogue');
end;
end.
