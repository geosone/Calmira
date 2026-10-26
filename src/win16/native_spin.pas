{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 Spin unit: TSpinButton (up/down arrows with auto-repeat) and
  TSpinEdit (a numeric edit with an embedded spin button, as in Delphi the
  button is a child window of the EDIT and the edit rectangle is narrowed). }
unit native_spin;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This spin unit requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls, native_edit;
type
  TSpinButton = class(TCustomControl)
  private
    FPressed: (spNone, spUp, spDown);
    FInside: Boolean;
    FFocusControl: TCustomControl;
    FOnUpClick, FOnDownClick: TNotifyEvent;
    procedure Step;
    procedure StopRepeat;
    procedure WMTimer(var M: TMessage); message WM_TIMER;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    property FocusControl: TCustomControl read FFocusControl write FFocusControl;
    property OnUpClick: TNotifyEvent read FOnUpClick write FOnUpClick;
    property OnDownClick: TNotifyEvent read FOnDownClick write FOnDownClick;
    property Enabled;
    property Visible;
  end;
  TSpinEdit = class(TEdit)
  private
    FMinValue, FMaxValue, FIncrement: LongInt;
    FEditorEnabled: Boolean;
    FButton: TSpinButton;
    function GetValue: LongInt;
    procedure SetValue(NewValue: LongInt);
    function CheckValue(NewValue: LongInt): LongInt;
    procedure SetEditRect;
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
    procedure WMSize(var M: TMessage); message WM_SIZE;
    procedure WMGetDlgCode(var M: TWMGetDlgCode); message WM_GETDLGCODE;
  protected
    function ExtraStyle: DWORD; override;
    function IsValidChar(Key: Char): Boolean; virtual;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    property Button: TSpinButton read FButton;
  published
    property EditorEnabled: Boolean read FEditorEnabled write FEditorEnabled default True;
    property Increment: LongInt read FIncrement write FIncrement default 1;
    property MaxValue: LongInt read FMaxValue write FMaxValue;
    property MinValue: LongInt read FMinValue write FMinValue;
    property Value: LongInt read GetValue write SetValue;
  end;
implementation
uses SysUtils, WinProcs, native_window;
const
  { Delphi 1 timings: first repeat after 400 ms, then every 100 ms. }
  InitRepeatPause = 400;
  RepeatPause = 100;
  RepeatTimer = 1;
  ButtonWidth = 15;

{ TSpinButton }
constructor TSpinButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := clBtnFace;
  SetBounds(0, 0, 20, 25);
end;
procedure TSpinButton.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FFocusControl) then FFocusControl := nil;
end;
procedure TSpinButton.Step;
begin
  if not FInside then Exit;
  if FPressed = spUp then begin if Assigned(FOnUpClick) then FOnUpClick(Self); end
  else if FPressed = spDown then begin if Assigned(FOnDownClick) then FOnDownClick(Self); end;
end;
procedure TSpinButton.StopRepeat;
begin
  if Handle <> 0 then KillTimer(Handle, RepeatTimer);
end;
procedure TSpinButton.WMTimer(var M: TMessage);
begin
  if (M.WParam <> RepeatTimer) or (FPressed = spNone) then Exit;
  KillTimer(Handle, RepeatTimer);
  SetTimer(Handle, RepeatTimer, RepeatPause, nil);
  Step;
end;
procedure TSpinButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not Enabled then Exit;
  if (FFocusControl <> nil) and FFocusControl.CanFocus and not FFocusControl.Focused then
    FFocusControl.SetFocus;
  if Y < ClientHeight div 2 then FPressed := spUp else FPressed := spDown;
  FInside := True;
  MouseCapture := True;
  Invalidate;
  SetTimer(Handle, RepeatTimer, InitRepeatPause, nil);
  Step;
end;
procedure TSpinButton.MouseMove(Shift: TShiftState; X, Y: Integer);
var Inside: Boolean;
begin
  inherited MouseMove(Shift, X, Y);
  if FPressed = spNone then Exit;
  Inside := (X >= 0) and (X < ClientWidth) and (Y >= 0) and (Y < ClientHeight);
  if FPressed = spUp then Inside := Inside and (Y < ClientHeight div 2)
  else Inside := Inside and (Y >= ClientHeight div 2);
  if Inside <> FInside then begin FInside := Inside; Invalidate; end;
end;
procedure TSpinButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FPressed = spNone) then Exit;
  StopRepeat;
  FPressed := spNone;
  MouseCapture := False;
  Invalidate;
end;
procedure TSpinButton.Paint;
var Half: Integer;
  procedure Part(Top, Bottom: Integer; Up, Down: Boolean);
  var R: TRect; CX, CY, I, Size: Integer; Arrow: TColor;
  begin
    R := Graphics.Rect(0, Top, ClientWidth, Bottom);
    Canvas.Brush.Color := clBtnFace; Canvas.FillRect(R);
    if Down then begin Canvas.Brush.Color := clBtnShadow; end
    else begin Canvas.Brush.Color := clBtnHighlight; end;
    Canvas.FillRect(Graphics.Rect(R.Left, R.Top, R.Right - 1, R.Top + 1));
    Canvas.FillRect(Graphics.Rect(R.Left, R.Top, R.Left + 1, R.Bottom - 1));
    if Down then Canvas.Brush.Color := clBtnFace else Canvas.Brush.Color := clBtnShadow;
    Canvas.FillRect(Graphics.Rect(R.Left, R.Bottom - 1, R.Right, R.Bottom));
    Canvas.FillRect(Graphics.Rect(R.Right - 1, R.Top, R.Right, R.Bottom));
    if Enabled then Arrow := clBtnText else Arrow := clBtnShadow;
    Size := (Bottom - Top) div 4;
    if Size > (ClientWidth - 4) div 2 then Size := (ClientWidth - 4) div 2;
    if Size < 1 then Size := 1;
    CX := ClientWidth div 2 + Ord(Down); CY := (Top + Bottom) div 2 + Ord(Down);
    Canvas.Brush.Color := Arrow;
    { A filled triangle, one scan line at a time. }
    for I := 0 to Size - 1 do
      if Up then
        Canvas.FillRect(Graphics.Rect(CX - I, CY - Size div 2 + I, CX + I + 1, CY - Size div 2 + I + 1))
      else
        Canvas.FillRect(Graphics.Rect(CX - I, CY + Size div 2 - I, CX + I + 1, CY + Size div 2 - I + 1));
  end;
begin
  Half := ClientHeight div 2;
  Part(0, Half, True, (FPressed = spUp) and FInside);
  Part(Half, ClientHeight, False, (FPressed = spDown) and FInside);
end;

{ TSpinEdit }
constructor TSpinEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIncrement := 1;
  FEditorEnabled := True;
  FButton := TSpinButton.Create(Self);
  FButton.FocusControl := Self;
  FButton.OnUpClick := UpClick;
  FButton.OnDownClick := DownClick;
  FButton.Parent := Self;
  Text := '0';
  SetBounds(0, 0, 47, 25);
end;
function TSpinEdit.ExtraStyle: DWORD;
begin
  { EM_SETRECTNP, which keeps text clear of the button, needs a multiline edit. }
  Result := inherited ExtraStyle or ES_MULTILINE;
end;
procedure TSpinEdit.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);
  SetEditRect;
end;
procedure TSpinEdit.SetEditRect;
var R: TRect;
begin
  if FButton <> nil then
    FButton.SetBounds(ClientWidth - ButtonWidth, 0, ButtonWidth, ClientHeight);
  if Handle = 0 then Exit;
  R := Graphics.Rect(0, 0, ClientWidth - ButtonWidth - 2, ClientHeight);
  Perform(EM_SETRECTNP, 0, LongInt(@R));
end;
procedure TSpinEdit.WMSize(var M: TMessage);
begin
  inherited;
  SetEditRect;
end;
procedure TSpinEdit.WMGetDlgCode(var M: TWMGetDlgCode);
begin
  inherited;
  { Multiline EDITs claim every key; Tab and Enter still belong to the dialog. }
  M.Result := M.Result and not DLGC_WANTALLKEYS;
end;
function TSpinEdit.CheckValue(NewValue: LongInt): LongInt;
begin
  Result := NewValue;
  if FMaxValue <> FMinValue then
  begin
    if NewValue < FMinValue then Result := FMinValue
    else if NewValue > FMaxValue then Result := FMaxValue;
  end;
end;
function TSpinEdit.GetValue: LongInt;
var Code: Integer;
begin
  Val(Text, Result, Code);
  if Code <> 0 then Result := FMinValue;
end;
procedure TSpinEdit.SetValue(NewValue: LongInt);
begin
  Text := IntToStr(CheckValue(NewValue));
end;
procedure TSpinEdit.UpClick(Sender: TObject);
begin
  if ReadOnly then MessageBeep(0) else Value := Value + FIncrement;
end;
procedure TSpinEdit.DownClick(Sender: TObject);
begin
  if ReadOnly then MessageBeep(0) else Value := Value - FIncrement;
end;
function TSpinEdit.IsValidChar(Key: Char): Boolean;
begin
  Result := (Key in ['+', '-', '0'..'9']) or ((Key < #32) and (Key <> #13));
  if not FEditorEnabled and Result and ((Key >= #32) or (Key = #8) or (Key = #127)) then
    Result := False;
end;
procedure TSpinEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Key = VK_UP then begin UpClick(Self); Key := 0; end
  else if Key = VK_DOWN then begin DownClick(Self); Key := 0; end;
  inherited KeyDown(Key, Shift);
end;
procedure TSpinEdit.KeyPress(var Key: Char);
begin
  if not IsValidChar(Key) then
  begin
    Key := #0;
    MessageBeep(0);
  end;
  if Key <> #0 then inherited KeyPress(Key);
end;
procedure TSpinEdit.DoExit;
begin
  if CheckValue(Value) <> Value then SetValue(Value);
  inherited DoExit;
end;
end.
