{ SPDX-License-Identifier: GPL-2.0-or-later
  Small native cursor dispatch ABI. No screen/component ownership lives here. }
unit native_cursors;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL Native cursors require Win16}{$ENDIF}
interface
uses WinTypes;
type
  TCursor = SmallInt;
  TNativeCursorProvider = function(Index: TCursor; Receiving, Target: HWND;
    HitTest: SmallInt; OverrideOnly: Boolean; var Value: HCURSOR): Boolean of object;
const
  crDefault = 0; crNone = -1; crArrow = -2; crCross = -3; crIBeam = -4;
  crSize = -5; crSizeNESW = -6; crSizeNS = -7; crSizeNWSE = -8;
  crSizeWE = -9; crUpArrow = -10; crHourGlass = -11;
  crDrag = -12; crNoDrop = -13; crHSplit = -14; crVSplit = -15;
  crMultiDrag = -16; crSQLWait = -17;
function StandardCursor(Index: TCursor; var Value: HCURSOR): Boolean;
function LookupNativeCursor(Index: TCursor; var Value: HCURSOR): Boolean;
function InstallCursorProvider(Owner: Pointer; Provider: TNativeCursorProvider): Boolean;
procedure RemoveCursorProvider(Owner: Pointer);
function ApplyNativeCursor(Receiving, Target: HWND; HitTest: SmallInt): Boolean;
function CursorTarget: HWND;
procedure RefreshNativeCursor(Target: HWND);
implementation
uses WinProcs;
var ProviderOwner: Pointer; ProviderTask: HTASK; Resolver: TNativeCursorProvider;
{ Match USER's four-byte POINT by value without the failing record ABI used by
  the stock Win16 declaration (the Controls PtInRect adapter has the same limit). }
function PackedWindowFromPoint(Value: LongInt): HWND; external 'USER' name 'WINDOWFROMPOINT';
function StandardCursor(Index: TCursor; var Value: HCURSOR): Boolean;
var Resource: PChar;
begin
  Value := 0; Result := True;
  if Index = crNone then Exit;
  case Index of
    crDefault, crArrow: Resource := IDC_ARROW;
    crCross: Resource := IDC_CROSS;
    crIBeam: Resource := IDC_IBEAM;
    crSize: Resource := IDC_SIZE;
    crSizeNESW: Resource := IDC_SIZENESW;
    crSizeNS: Resource := IDC_SIZENS;
    crSizeNWSE: Resource := IDC_SIZENWSE;
    crSizeWE: Resource := IDC_SIZEWE;
    crUpArrow: Resource := IDC_UPARROW;
    crHourGlass: Resource := IDC_WAIT;
  else Result := False; Exit; end;
  Value := LoadCursor(0, Resource); Result := Value <> 0;
end;
function LookupNativeCursor(Index: TCursor; var Value: HCURSOR): Boolean;
begin
  if Assigned(Resolver) and (ProviderTask = GetCurrentTask) then
    if Resolver(Index, 0, 0, 0, False, Value) then begin Result := True; Exit; end;
  Result := StandardCursor(Index, Value);
end;
function InstallCursorProvider(Owner: Pointer; Provider: TNativeCursorProvider): Boolean;
begin
  Result := (Owner <> nil) and Assigned(Provider) and
    ((ProviderOwner = nil) or (ProviderOwner = Owner));
  if not Result then Exit;
  ProviderOwner := Owner; ProviderTask := GetCurrentTask; Resolver := Provider;
end;
procedure RemoveCursorProvider(Owner: Pointer);
begin
  if (ProviderOwner = Owner) and (ProviderTask = GetCurrentTask) then
  begin Resolver := nil; ProviderOwner := nil; ProviderTask := 0; end;
end;
function ApplyNativeCursor(Receiving, Target: HWND; HitTest: SmallInt): Boolean;
var Value: HCURSOR;
begin
  Result := False;
  if not Assigned(Resolver) or (ProviderTask <> GetCurrentTask) then Exit;
  if Resolver(crDefault, Receiving, Target, HitTest, True, Value) then
  begin SetCursor(Value); Result := True; end;
end;
function CursorTarget: HWND;
var Position: TPoint; PackedPoint: LongInt;
begin
  Result := GetCapture;
  if Result = 0 then
  begin
    GetCursorPos(@Position);
    PackedPoint := LongInt(Word(Position.X)) or (LongInt(Word(Position.Y)) shl 16);
    Result := PackedWindowFromPoint(PackedPoint);
  end;
  if Result <> 0 then
    if GetWindowTask(Result) <> GetCurrentTask then Result := 0;
end;
procedure RefreshNativeCursor(Target: HWND);
var Position: TPoint; PackedPoint: LongInt; HitTest: SmallInt;
begin
  if (Target = 0) or not IsWindow(Target) then Exit;
  if GetWindowTask(Target) <> GetCurrentTask then Exit;
  GetCursorPos(@Position);
  PackedPoint := LongInt(Word(Position.X)) or (LongInt(Word(Position.Y)) shl 16);
  HitTest := SmallInt(SendMessage(Target, WM_NCHITTEST, 0, PackedPoint));
  if HitTest = HTCLIENT then
    SendMessage(Target, WM_SETCURSOR, Target, LongInt(HTCLIENT) or (LongInt(WM_MOUSEMOVE) shl 16));
end;
end.
