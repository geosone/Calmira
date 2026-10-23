{ SPDX-License-Identifier: GPL-2.0-or-later
  Optional caption provider. The concrete INI backend is in form_catalog so
  English-only forms do not pull its class metadata into Win16 DGROUP. }
unit form_text;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This caption adapter requires Win16}{$ENDIF}
interface
type
  TFormTextProvider = function(const RootClass, ComponentName, PropertyName,
    DefaultText: string): string of object;
function SetFormTextProvider(Value: TFormTextProvider): TFormTextProvider;
function FormText(const RootClass, ComponentName, PropertyName, DefaultText: string): string;
implementation
uses SysUtils;
var Provider: TFormTextProvider;
function SetFormTextProvider(Value: TFormTextProvider): TFormTextProvider;
begin Result := Provider; Provider := Value; end;
function FormText(const RootClass, ComponentName, PropertyName, DefaultText: string): string;
begin
  if Assigned(Provider) then Result := Provider(RootClass, ComponentName, PropertyName, DefaultText)
  else Result := DefaultText;
  if Pos(#0, Result) <> 0 then raise Exception.Create('Invalid form catalogue');
end;
end.
