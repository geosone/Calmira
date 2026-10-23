{ SPDX-License-Identifier: GPL-2.0-or-later
  Explicit task-local screen/form view and opt-in cursor policy, not full Forms.Screen.
  Returned forms/controls are borrowed live references, not retained snapshots. }
unit native_screen;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This screen view requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Controls, native_application, native_form, native_cursor_policy;
type
  ENativeScreenError = class(Exception);
  TNativeScreen = class(TComponent)
  private
    FApplication: TNativeApplication;
    FTask: HTASK;
    FCursors: TNativeCursorPolicy;
    function CursorWindowAllowed(Window: HWND): Boolean;
    function GetCursor: TCursor;
    procedure SetCursor(Value: TCursor);
    function GetCursorHandle(Index: TCursor): HCURSOR;
    procedure SetCursorHandle(Index: TCursor; Value: HCURSOR);
    function GetCursorDepth: Integer;
    procedure CheckTask;
    function HasApplication: Boolean;
    procedure SetApplication(Value: TNativeApplication);
    procedure CollectForms(List: TList);
    function GetFormCount: Integer;
    function GetForm(Index: Integer): TNativeForm;
    function GetActiveForm: TNativeForm;
    function GetActiveControl: TCustomControl;
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetPixelsPerInch: Integer;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure PushCursor(Value: TCursor);
    procedure PopCursor;
    procedure DisableCursors;
    property Cursor: TCursor read GetCursor write SetCursor;
    property Cursors[Index: TCursor]: HCURSOR read GetCursorHandle write SetCursorHandle;
    property CursorDepth: Integer read GetCursorDepth;
    property Application: TNativeApplication read FApplication write SetApplication;
    property FormCount: Integer read GetFormCount;
    property Forms[Index: Integer]: TNativeForm read GetForm;
    property ActiveForm: TNativeForm read GetActiveForm;
    property ActiveControl: TCustomControl read GetActiveControl;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property PixelsPerInch: Integer read GetPixelsPerInch;
  end;
implementation
uses WinProcs;
constructor TNativeScreen.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); FTask := GetCurrentTask;
  FCursors := TNativeCursorPolicy.Create(CursorWindowAllowed);
end;
function TNativeScreen.CursorWindowAllowed(Window: HWND): Boolean;
var Index: Integer; Form: TNativeForm;
begin
  Result := False;
  if not HasApplication or (Window = 0) or not IsWindow(Window) then Exit;
  if not IsWindowVisible(Window) then Exit;
  if GetWindowTask(Window) <> FTask then Exit;
  for Index := 0 to FApplication.FormCount - 1 do
  begin
    Form := FApplication.Forms[Index];
    if (Form.Handle <> 0) and ((Window = Form.Handle) or IsChild(Form.Handle, Window)) then
    begin Result := True; Exit; end;
  end;
end;
function TNativeScreen.GetCursor: TCursor;
begin CheckTask; Result := FCursors.Cursor; end;
procedure TNativeScreen.SetCursor(Value: TCursor);
begin
  if not HasApplication then raise ENativeScreenError.Create('Invalid screen application');
  FCursors.Cursor := Value;
end;
function TNativeScreen.GetCursorHandle(Index: TCursor): HCURSOR;
begin CheckTask; Result := FCursors.Cursors[Index]; end;
procedure TNativeScreen.SetCursorHandle(Index: TCursor; Value: HCURSOR);
begin
  CheckTask;
  if Value <> 0 then
    if not HasApplication then raise ENativeScreenError.Create('Invalid screen application');
  FCursors.Cursors[Index] := Value;
end;
function TNativeScreen.GetCursorDepth: Integer;
begin CheckTask; Result := FCursors.CursorDepth; end;
procedure TNativeScreen.PushCursor(Value: TCursor);
begin
  if not HasApplication then raise ENativeScreenError.Create('Invalid screen application');
  FCursors.PushCursor(Value);
end;
procedure TNativeScreen.PopCursor;
begin
  if not HasApplication then raise ENativeScreenError.Create('Invalid screen application');
  FCursors.PopCursor;
end;
procedure TNativeScreen.DisableCursors;
begin CheckTask; FCursors.Reset; end;
procedure TNativeScreen.CheckTask;
begin
  if GetCurrentTask <> FTask then raise ENativeScreenError.Create('Invalid screen task');
end;
function TNativeScreen.HasApplication: Boolean;
begin
  CheckTask;
  Result := (FApplication <> nil) and FApplication.Initialized and not FApplication.ShuttingDown;
end;
procedure TNativeScreen.SetApplication(Value: TNativeApplication);
begin
  CheckTask;
  if Value <> nil then
    if (Value.TaskHandle <> FTask) or not Value.Initialized or Value.ShuttingDown then
      raise ENativeScreenError.Create('Invalid screen application');
  if Value = FApplication then Exit;
  { Register first: allocation failure must preserve the previous binding. }
  if Value <> nil then Value.FreeNotification(Self);
  try FCursors.Reset;
  except
    if Value <> nil then Value.RemoveFreeNotification(Self);
    raise;
  end;
  if FApplication <> nil then FApplication.RemoveFreeNotification(Self);
  FApplication := Value;
end;
procedure TNativeScreen.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FApplication) then
  begin FCursors.Reset; FApplication := nil; end;
  inherited Notification(AComponent, Operation);
end;
function TNativeScreen.GetFormCount: Integer;
begin
  Result := 0;
  if HasApplication then Result := FApplication.FormCount;
end;
procedure TNativeScreen.CollectForms(List: TList);
var Window: HWND; Index: Integer; Form: TNativeForm;
begin
  if not HasApplication then Exit;
  { USER is authoritative for native front-to-back order. Do not create handles,
    activate windows, pump messages or call user events while collecting. }
  Window := GetTopWindow(0);
  while Window <> 0 do
  begin
    if GetWindowTask(Window) = FTask then
      for Index := 0 to FApplication.FormCount - 1 do
      begin
        Form := FApplication.Forms[Index];
        if Form.Handle = Window then begin List.Add(Form); Break; end;
      end;
    Window := GetWindow(Window, GW_HWNDNEXT);
  end;
  { Retain every registered model exactly once, even without a top-level HWND. }
  for Index := 0 to FApplication.FormCount - 1 do
  begin
    Form := FApplication.Forms[Index];
    if List.IndexOf(Form) < 0 then List.Add(Form);
  end;
end;
function TNativeScreen.GetForm(Index: Integer): TNativeForm;
var Ordered: TList;
begin
  if (Index < 0) or (Index >= GetFormCount) then
    raise ENativeScreenError.Create('Invalid screen form');
  Ordered := TList.Create;
  try
    CollectForms(Ordered);
    if Index >= Ordered.Count then raise ENativeScreenError.Create('Invalid screen form');
    Result := TNativeForm(Ordered[Index]);
  finally Ordered.Free; end;
end;
function TNativeScreen.GetActiveForm: TNativeForm;
var Window: HWND; Index: Integer; Form: TNativeForm;
begin
  Result := nil;
  if not HasApplication then Exit;
  Window := GetActiveWindow;
  if (Window = 0) or not IsWindow(Window) then Exit;
  if (GetWindowTask(Window) <> FTask) or not IsWindowVisible(Window) or
    not IsWindowEnabled(Window) then Exit;
  for Index := 0 to FApplication.FormCount - 1 do
  begin
    Form := FApplication.Forms[Index];
    if Form.Handle = Window then begin Result := Form; Exit; end;
  end;
end;
function TNativeScreen.GetActiveControl: TCustomControl;
var Form: TNativeForm;
begin
  Result := nil; Form := GetActiveForm;
  if Form = nil then Exit;
  Result := Form.FindControl(GetFocus);
  if Result = Form then Result := nil;
  if Result <> nil then
    if not Result.CanFocus then Result := nil;
end;
function TNativeScreen.GetWidth: Integer;
begin CheckTask; Result := GetSystemMetrics(SM_CXSCREEN); end;
function TNativeScreen.GetHeight: Integer;
begin CheckTask; Result := GetSystemMetrics(SM_CYSCREEN); end;
function TNativeScreen.GetPixelsPerInch: Integer;
var Display: HDC;
begin
  CheckTask; Display := GetDC(0);
  if Display = 0 then raise ENativeScreenError.Create('Cannot acquire screen DC');
  try Result := GetDeviceCaps(Display, LOGPIXELSY);
  finally ReleaseDC(0, Display); end;
  if Result <= 0 then raise ENativeScreenError.Create('Invalid screen resolution');
end;
destructor TNativeScreen.Destroy;
begin
  FCursors.Free; FCursors := nil;
  if FApplication <> nil then FApplication.RemoveFreeNotification(Self);
  FApplication := nil; inherited Destroy;
end;
end.
