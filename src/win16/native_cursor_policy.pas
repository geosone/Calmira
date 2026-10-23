{ SPDX-License-Identifier: GPL-2.0-or-later
  One opt-in cursor controller per task/module. Registry handles are borrowed. }
unit native_cursor_policy;
{$mode delphi}{$H-}
interface
uses Classes, SysUtils, WinTypes, native_cursors;
type
  ENativeCursorError = class(Exception);
  TCursorWindowScope = function(Window: HWND): Boolean of object;
  TNativeCursorPolicy = class
  private
    FTask: HTASK;
    FCursor: TCursor;
    FRegistry, FStack: TList;
    FEnabled, FChanging: Boolean;
    FLastWindow: HWND;
    FScope: TCursorWindowScope;
    procedure CheckMutable;
    procedure EnsureEnabled;
    function Resolve(Index: TCursor; Receiving, Target: HWND; HitTest: SmallInt;
      OverrideOnly: Boolean; var Value: HCURSOR): Boolean;
    function FindEntry(Index: TCursor): Integer;
    function RequiredCursor(Index: TCursor): HCURSOR;
    function GetCursorHandle(Index: TCursor): HCURSOR;
    procedure SetCursorHandle(Index: TCursor; Value: HCURSOR);
    procedure SetCursor(Value: TCursor);
    function GetDepth: Integer;
    procedure Refresh;
  public
    constructor Create(Scope: TCursorWindowScope);
    destructor Destroy; override;
    procedure Enable;
    procedure Disable;
    procedure Reset;
    procedure PushCursor(Value: TCursor);
    procedure PopCursor;
    property Cursor: TCursor read FCursor write SetCursor;
    property Cursors[Index: TCursor]: HCURSOR read GetCursorHandle write SetCursorHandle;
    property CursorDepth: Integer read GetDepth;
  end;
implementation
uses WinProcs;
type
  PCursorEntry = ^TCursorEntry;
  TCursorEntry = record Index: TCursor; Handle: HCURSOR; end;
  PSavedCursor = ^TCursor;
constructor TNativeCursorPolicy.Create(Scope: TCursorWindowScope);
begin
  inherited Create; FTask := GetCurrentTask; FScope := Scope;
  FRegistry := TList.Create; FStack := TList.Create;
end;
procedure TNativeCursorPolicy.CheckMutable;
begin
  if (FTask <> GetCurrentTask) or FChanging then
    raise ENativeCursorError.Create('Invalid cursor operation');
end;
function TNativeCursorPolicy.FindEntry(Index: TCursor): Integer;
begin
  for Result := 0 to FRegistry.Count - 1 do
    if PCursorEntry(FRegistry[Result])^.Index = Index then Exit;
  Result := -1;
end;
function TNativeCursorPolicy.RequiredCursor(Index: TCursor): HCURSOR;
var Entry: Integer;
begin
  Entry := FindEntry(Index);
  if Entry >= 0 then Result := PCursorEntry(FRegistry[Entry])^.Handle
  else if not StandardCursor(Index, Result) then
    raise ENativeCursorError.Create('Unknown cursor');
end;
function TNativeCursorPolicy.GetCursorHandle(Index: TCursor): HCURSOR;
begin
  if FTask <> GetCurrentTask then raise ENativeCursorError.Create('Invalid cursor operation');
  Result := RequiredCursor(Index);
end;
function TNativeCursorPolicy.GetDepth: Integer;
begin Result := FStack.Count; end;
procedure TNativeCursorPolicy.SetCursorHandle(Index: TCursor; Value: HCURSOR);
var Entry, I: Integer; Item: PCursorEntry;
begin
  CheckMutable; FChanging := True;
  try
    if (Index = crDefault) or (Index = crNone) or (FCursor = Index) then
      raise ENativeCursorError.Create('Invalid cursor operation');
    for I := 0 to FStack.Count - 1 do
      if PSavedCursor(FStack[I])^ = Index then raise ENativeCursorError.Create('Cursor is saved');
    Entry := FindEntry(Index);
    if Value = 0 then
    begin
      if Entry >= 0 then begin Item := PCursorEntry(FRegistry[Entry]); FRegistry.Delete(Entry); Dispose(Item); end;
      Exit;
    end;
    EnsureEnabled;
    if Entry >= 0 then PCursorEntry(FRegistry[Entry])^.Handle := Value
    else
    begin
      New(Item); Item^.Index := Index; Item^.Handle := Value;
      try FRegistry.Add(Item); except Dispose(Item); raise; end;
    end;
  finally FChanging := False; end;
end;
procedure TNativeCursorPolicy.Enable;
begin CheckMutable; EnsureEnabled; end;
procedure TNativeCursorPolicy.EnsureEnabled;
begin
  if FEnabled then Exit;
  if not Assigned(FScope) or not InstallCursorProvider(Pointer(Self), Resolve) then
    raise ENativeCursorError.Create('Cursor controller already active');
  FEnabled := True;
end;
procedure TNativeCursorPolicy.Refresh;
var Target: HWND;
begin
  Target := CursorTarget;
  if (Target <> 0) and Assigned(FScope) then
    if FScope(Target) then RefreshNativeCursor(Target);
end;
procedure TNativeCursorPolicy.SetCursor(Value: TCursor);
begin
  CheckMutable; FChanging := True;
  try RequiredCursor(Value); EnsureEnabled; FCursor := Value; Refresh;
  finally FChanging := False; end;
end;
procedure TNativeCursorPolicy.PushCursor(Value: TCursor);
var Saved: PSavedCursor;
begin
  CheckMutable; FChanging := True;
  try
    RequiredCursor(Value); EnsureEnabled;
    New(Saved); Saved^ := FCursor;
    try FStack.Add(Saved); except Dispose(Saved); raise; end;
    FCursor := Value; Refresh;
  finally FChanging := False; end;
end;
procedure TNativeCursorPolicy.PopCursor;
var Saved: PSavedCursor;
begin
  CheckMutable; FChanging := True;
  try
    if FStack.Count = 0 then raise ENativeCursorError.Create('Empty cursor stack');
    Saved := PSavedCursor(FStack.Last); RequiredCursor(Saved^); EnsureEnabled;
    FCursor := Saved^; FStack.Delete(FStack.Count - 1); Dispose(Saved); Refresh;
  finally FChanging := False; end;
end;
function TNativeCursorPolicy.Resolve(Index: TCursor; Receiving, Target: HWND; HitTest: SmallInt;
  OverrideOnly: Boolean; var Value: HCURSOR): Boolean;
var Entry: Integer;
begin
  Result := False;
  if FTask <> GetCurrentTask then Exit;
  if OverrideOnly then
  begin
    if not FEnabled or (FCursor = crDefault) or (HitTest <> HTCLIENT) then Exit;
    if not Assigned(FScope) or not FScope(Receiving) or not FScope(Target) then Exit;
    Value := RequiredCursor(FCursor); FLastWindow := Target; Result := True;
  end
  else
  begin
    Entry := FindEntry(Index);
    if Entry >= 0 then begin Value := PCursorEntry(FRegistry[Entry])^.Handle; Result := True; end;
  end;
end;
procedure TNativeCursorPolicy.Disable;
var Target: HWND;
begin
  CheckMutable;
  if not FEnabled then Exit;
  FChanging := True;
  try
    RemoveCursorProvider(Pointer(Self)); FEnabled := False;
    Target := CursorTarget;
    if Target <> 0 then
      if (Target = FLastWindow) or (Assigned(FScope) and FScope(Target)) then RefreshNativeCursor(Target);
    FLastWindow := 0;
  finally FChanging := False; end;
end;
procedure TNativeCursorPolicy.Reset;
var Saved: PSavedCursor;
begin
  CheckMutable; Disable; FChanging := True;
  try
    if FStack <> nil then
      while FStack.Count > 0 do
      begin Saved := PSavedCursor(FStack.Last); FStack.Delete(FStack.Count - 1); Dispose(Saved); end;
    FCursor := crDefault;
  finally FChanging := False; end;
end;
destructor TNativeCursorPolicy.Destroy;
var Entry: PCursorEntry; Saved: PSavedCursor;
begin
  Disable;
  if FRegistry <> nil then
    while FRegistry.Count > 0 do
    begin Entry := PCursorEntry(FRegistry.Last); FRegistry.Delete(FRegistry.Count - 1); Dispose(Entry); end;
  if FStack <> nil then
    while FStack.Count > 0 do
    begin Saved := PSavedCursor(FStack.Last); FStack.Delete(FStack.Count - 1); Dispose(Saved); end;
  FRegistry.Free; FStack.Free; inherited Destroy;
end;
end.
