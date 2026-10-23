program ClassPointerTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, Classes;
type
  TLarge = class
    Pad: array[0..1099] of Byte;
    Marker: Word;
    constructor Create; virtual;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  end;
  TDerived = class(TLarge)
    Extra: array[0..1099] of Byte;
    constructor Create; override;
  end;
  TLargeClass = class of TLarge;
  TLargeComponent = class(TComponent)
  public
    Pad: array[0..1099] of Byte;
    destructor Destroy; override;
  end;
var Instance, AliasValue, Fake, Other: TLarge; Kind, OtherKind: TLargeClass;
  Failed, ThrowNow, Rejected: Boolean; Constructors, Destructors, Afters, Befores, I: Integer;
  OwnerNode, ChildNode: TLargeComponent; ComponentDeaths: Integer;
{$I win16_stack_guard.inc}
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
constructor TLarge.Create;
begin
  inherited Create; Inc(Constructors); Marker := $1357;
  Pad[0] := $A5; Pad[High(Pad)] := $5A;
  if ThrowNow then raise Exception.Create('constructor failure');
end;
destructor TLarge.Destroy;
begin Inc(Destructors); inherited Destroy; end;
procedure TLarge.AfterConstruction;
begin Inc(Afters); inherited AfterConstruction; end;
procedure TLarge.BeforeDestruction;
begin Inc(Befores); inherited BeforeDestruction; end;
constructor TDerived.Create;
begin
  inherited Create; Extra[0] := 17; Extra[High(Extra)] := 29;
end;
destructor TLargeComponent.Destroy;
begin Inc(ComponentDeaths); inherited Destroy; end;
procedure Components;
begin
  OwnerNode := TLargeComponent.Create(nil);
  try
    ChildNode := TLargeComponent.Create(OwnerNode); ChildNode.Name := 'Child';
    ChildNode.Pad[0] := 41; ChildNode.Pad[High(ChildNode.Pad)] := 73;
    Check((Word(LongInt(Pointer(OwnerNode))) = 0) and
      (Word(LongInt(Pointer(ChildNode))) = 0), 'component zero-offset allocation');
    Check((ChildNode.Owner = OwnerNode) and (OwnerNode.ComponentCount = 1) and
      (OwnerNode.Components[0] = ChildNode) and (OwnerNode.FindComponent('Child') = ChildNode) and
      (ChildNode.Pad[0] = 41) and (ChildNode.Pad[High(ChildNode.Pad)] = 73), 'RTL component initialization and ownership');
  finally OwnerNode.Free; OwnerNode := nil; ChildNode := nil; end;
  Check(ComponentDeaths = 2, 'RTL owned component destruction');
end;
procedure CompareSynthetic;
begin
  { Never dereference or free these synthetic pointers. Read HInstance at run
    time so constant folding cannot conceal a broken class comparison. }
  Fake := TLarge(Ptr(HInstance, 0)); Other := TLarge(Ptr(HInstance + 8, 0));
  Check((Fake <> nil) and (nil <> Fake) and Assigned(Fake) and not (Fake = nil), 'class segment participates');
  Check((Fake <> Other) and not (Fake = Other), 'same offset different segments');
  AliasValue := Fake; Check((AliasValue = Fake) and not (AliasValue <> Fake), 'class alias equality');
  Fake := TLarge(Ptr(0, 17)); Check((Fake <> nil) and Assigned(Fake), 'class offset participates');
  Fake := nil; Check((Fake = nil) and (nil = Fake) and not Assigned(Fake), 'class nil');
  Kind := TLargeClass(Ptr(HInstance, 0)); OtherKind := TLargeClass(Ptr(HInstance + 8, 0));
  Check((Kind <> nil) and (nil <> Kind) and Assigned(Kind) and not (Kind = nil), 'classref segment participates');
  Check((Kind <> OtherKind) and not (Kind = OtherKind), 'classref different segments');
  OtherKind := Kind; Check((Kind = OtherKind) and not (Kind <> OtherKind), 'classref alias equality');
  Kind := nil; Check((Kind = nil) and not Assigned(Kind), 'classref nil');
  Fake := nil; Other := nil; AliasValue := nil; OtherKind := nil;
end;
procedure Construct;
begin
  Kind := TDerived; Instance := Kind.Create;
  try
    Check(Word(LongInt(Pointer(Instance))) = 0, 'direct allocation has zero offset');
    Check((Constructors = 1) and (Afters = 1) and (Instance.Marker = $1357) and
      (Instance.Pad[0] = $A5) and (Instance.Pad[High(Instance.Pad)] = $5A), 'constructor and afterconstruction');
    Check((Instance is TDerived) and (TDerived(Instance).Extra[0] = 17) and
      (TDerived(Instance).Extra[High(TDerived(Instance).Extra)] = 29), 'inherited constructor and payload');
    AliasValue := Instance; Check((AliasValue = Instance) and Assigned(Instance), 'allocated class equality');
  finally Instance.Free; Instance := nil; AliasValue := nil; end;
  Check((Destructors = 1) and (Befores = 1), 'destructor and beforedestruction');
  ThrowNow := True; Rejected := False;
  try Instance := TLarge.Create; except on Exception do Rejected := True; end;
  ThrowNow := False;
  Check(Rejected and (Instance = nil) and (Constructors = 2) and
    (Destructors = 2) and (Afters = 1) and (Befores = 1), 'failed constructor cleanup');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP far class pointers');
  try
    CompareSynthetic; Construct; Components;
    for I := 1 to 40 do begin Instance := TLarge.Create; Instance.Free; Instance := nil; end;
    Check((Constructors = 42) and (Destructors = 42) and (Afters = 41) and
      (Befores = 41), 'repeated lifetime balance');
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Instance.Free; Check(StackGuardIntact, 'stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
