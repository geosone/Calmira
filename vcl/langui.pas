{ Shared runtime text/form localization for the existing GUI and FPC port. }
unit LangUI;
{$IFDEF FPC}{$mode delphi}{$H-}{$ENDIF}
{$IFNDEF FPC}{$DEFINE USE_WINDOWS_RESOURCES}{$ENDIF}
{$IFDEF WIN16}{$DEFINE USE_WINDOWS_RESOURCES}{$ENDIF}
interface
uses Classes;
procedure ApplyComponentLanguage(Root: TComponent);
function LocalLoadStr(Ident: Word): string;
function LocalFmtLoadStr(Ident: Word; const Args: array of const): string;
implementation
uses SysUtils, TypInfo, language_catalog
{$IFDEF USE_WINDOWS_RESOURCES}, WinTypes, WinProcs{$ENDIF};

procedure ApplyOne(const RootClass: string; Item: TComponent);
const Names: array[0..1] of string[7] = ('Caption', 'Hint');
  Lists: array[0..2] of string[5] = ('Items', 'Tabs', 'Pages');
var
  I, J: Integer;
  Prop: PPropInfo;
  Key, Value: string;
  ListObject: TObject;
  Texts: TStrings;
begin
  for I := 0 to 1 do
  begin
    Prop := GetPropInfo(Item.ClassInfo, Names[I]);
    if Prop <> nil then
    begin
      Key := RootClass + '.' + Item.Name + '.' + Names[I];
      Value := GetStrProp(Item, Prop);
      Value := LanguageText('Forms', Key, Value);
      SetStrProp(Item, Prop, Value);
    end;
  end;
  for I := 0 to 2 do
  begin
    Prop := GetPropInfo(Item.ClassInfo, Lists[I]);
    if (Prop <> nil) and (Prop^.PropType^.Kind = tkClass) then
    begin
{$IFDEF FPC}
      ListObject := GetObjectProp(Item, Prop);
{$ELSE}
      ListObject := TObject(GetOrdProp(Item, Prop));
{$ENDIF}
      if ListObject is TStrings then
      begin
        Texts := TStrings(ListObject);
        for J := 0 to Texts.Count - 1 do
          Texts[J] := LanguageText('Forms', RootClass + '.' + Item.Name +
            '.' + Lists[I] + '.Strings.' + IntToStr(J), Texts[J]);
      end;
    end;
  end;
  for J := 0 to Item.ComponentCount - 1 do
    ApplyOne(RootClass, Item.Components[J]);
end;

procedure ApplyComponentLanguage(Root: TComponent);
begin
  if Root <> nil then ApplyOne(Root.ClassName, Root);
end;

function LocalLoadStr(Ident: Word): string;
var Value: string;
{$IFDEF USE_WINDOWS_RESOURCES} Buffer: array[0..255] of Char; {$ENDIF}
begin
  Value := '';
{$IFDEF USE_WINDOWS_RESOURCES}
  if LoadString(HInstance, Ident, Buffer, SizeOf(Buffer)) <> 0 then
    Value := StrPas(Buffer);
{$ENDIF}
  LocalLoadStr := LanguageText('Strings', IntToStr(Ident), Value);
end;

function LocalFmtLoadStr(Ident: Word; const Args: array of const): string;
begin
  LocalFmtLoadStr := Format(LocalLoadStr(Ident), Args);
end;
end.
