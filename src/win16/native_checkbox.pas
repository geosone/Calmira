{ SPDX-License-Identifier: GPL-2.0-or-later
  Native three-state BUTTON with managed VCL-style checkbox transitions. }
unit native_checkbox;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This checkbox requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls;
type
  TCheckBoxState = (cbUnchecked, cbChecked, cbGrayed);
  TCheckBox = class(TCustomControl)
  private
    FCaption: string;
    FState: TCheckBoxState;
    FAllowGrayed, FNotifying: Boolean;
    FAlignment: TLeftRight;
    FOnClick: TNotifyEvent;
    procedure SetAlignment(Value: TLeftRight);
    function GetState: TCheckBoxState;
    procedure SetState(Value: TCheckBoxState);
    function GetChecked: Boolean;
    procedure SetChecked(Value: Boolean);
    procedure SetCaption(const Value: string);
  protected
    procedure FontChanged; override;
    function NativeClassName: PChar; override;
    procedure WndProc(var M: TMessage); override;
    function ControlCommand(Code: Word): Boolean; override;
    function ControlMnemonic(Key: Char): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure DefaultHandler(var Message); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure Click; override;
  published
    property Caption: string read FCaption write SetCaption;
    property Checked: Boolean read GetChecked write SetChecked;
    property State: TCheckBoxState read GetState write SetState default cbUnchecked;
    property AllowGrayed: Boolean read FAllowGrayed write FAllowGrayed default False;
    { taLeftJustify puts the caption left of the box (BS_LEFTTEXT). }
    property Alignment: TLeftRight read FAlignment write SetAlignment default taRightJustify;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property Font;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
  end;
implementation
uses SysUtils, WinProcs, native_window, native_mnemonic;
function TCheckBox.ControlMnemonic(Key: Char): Boolean;
begin
  Result := CanFocus and CaptionMatches(Caption, Key);
  if Result then
  begin
    SetFocus;
    if CanFocus and Focused then Click;
  end;
end;
const CheckClass = 'CalmiraNativeCheckBox';
var CheckProcedure: WNDPROC;
constructor TCheckBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); TabStop := True; SetBounds(0, 0, 97, 17);
  FAlignment := taRightJustify;
end;
procedure TCheckBox.SetAlignment(Value: TLeftRight);
var Style: LongInt;
begin
  if Value = FAlignment then Exit;
  FAlignment := Value;
  if Handle = 0 then Exit;
  { BUTTON reads the style bit when it paints. }
  Style := GetWindowLong(Handle, GWL_STYLE);
  if Value = taLeftJustify then Style := Style or BS_LEFTTEXT else Style := Style and not LongInt(BS_LEFTTEXT);
  SetWindowLong(Handle, GWL_STYLE, Style);
  InvalidateRect(Handle, nil, True);
end;
function TCheckBox.NativeClassName: PChar;
begin RegisterNativeSuperclass('BUTTON', CheckClass, CheckProcedure); Result := CheckClass; end;
procedure TCheckBox.DefaultHandler(var Message);
begin
  with TMessage(Message) do
    Result := CallWindowProc(CheckProcedure, Handle, Msg, WParam, LParam);
end;
procedure TCheckBox.WndProc(var M: TMessage);
begin
  if M.Msg = WM_DESTROY then FState := GetState;
  if (M.Msg = WM_PAINT) or (M.Msg = WM_ERASEBKGND) then DefaultHandler(M)
  else inherited WndProc(M);
end;
procedure TCheckBox.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  if (Parent = 0) or (Style and WS_CHILD = 0) then
    raise ENativeWindowError.Create('Checkbox requires a child window');
  Style := (Style and not DWORD($F or WS_TABSTOP or BS_LEFTTEXT)) or BS_3STATE;
  if FAlignment = taLeftJustify then Style := Style or BS_LEFTTEXT;
  if TabStop then Style := Style or WS_TABSTOP;
  inherited CreateHandle(Parent, FCaption, Style, X, Y, Width, Height);
  try
    Perform(BM_SETCHECK, Ord(FState), 0); FontChanged;
  except DestroyHandle; raise; end;
end;
function TCheckBox.GetState: TCheckBoxState;
var Value: LongInt;
begin
  if Handle <> 0 then
  begin
    Value := Perform(BM_GETCHECK, 0, 0);
    if (Value < 0) or (Value > 2) then raise ENativeWindowError.Create('Invalid checkbox state');
    FState := TCheckBoxState(Value);
  end;
  Result := FState;
end;
procedure TCheckBox.SetState(Value: TCheckBoxState);
begin
  if (Ord(Value) < 0) or (Ord(Value) > 2) then
    raise ENativeWindowError.Create('Invalid checkbox state');
  if Value = GetState then Exit;
  FState := Value;
  if Handle <> 0 then Perform(BM_SETCHECK, Ord(Value), 0);
  if FNotifying then Exit;
  FNotifying := True;
  try if Assigned(FOnClick) then FOnClick(Self);
  finally FNotifying := False; end;
end;
function TCheckBox.GetChecked: Boolean;
begin Result := GetState = cbChecked; end;
procedure TCheckBox.SetChecked(Value: Boolean);
begin if Value then State := cbChecked else State := cbUnchecked; end;
procedure TCheckBox.Click;
begin
  if not Enabled then Exit;
  case State of
    cbUnchecked: if FAllowGrayed then State := cbGrayed else State := cbChecked;
    cbGrayed: State := cbChecked;
    cbChecked: State := cbUnchecked;
  end;
end;
function TCheckBox.ControlCommand(Code: Word): Boolean;
begin
  Result := Code = BN_CLICKED;
  if Result and Enabled and Visible then Click;
end;
procedure TCheckBox.SetCaption(const Value: string);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('NUL in checkbox caption');
  if Handle <> 0 then begin StrPCopy(Buffer, Value); SetWindowText(Handle, Buffer); end;
  FCaption := Value; Invalidate;
end;
procedure TCheckBox.FontChanged;
var NativeFont: HFONT;
begin
  if Handle = 0 then Exit;
  try NativeFont := Font.Handle;
  except Perform(WM_SETFONT, GetStockObject(SYSTEM_FONT), 0); Invalidate; raise; end;
  Perform(WM_SETFONT, NativeFont, 0); Invalidate;
end;
end.
