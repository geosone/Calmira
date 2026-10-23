{ SPDX-License-Identifier: GPL-2.0-or-later
  Native radio BUTTON with Delphi 1 sibling grouping: checking one radio
  button unchecks the other radio buttons with the same parent, and only the
  checked button is a tab stop. Arrow-key movement within a group is not
  provided yet. }
unit native_radio;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This radio button requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls;
type
  TRadioButton = class(TCustomControl)
  private
    FCaption: string;
    FChecked: Boolean;
    FAlignment: TAlignment;
    FOnClick: TNotifyEvent;
    procedure SetChecked(Value: Boolean);
    procedure SetAlignment(Value: TAlignment);
    procedure SetCaption(const Value: string);
    procedure TurnSiblingsOff;
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
    procedure Click; virtual;
  published
    property Alignment: TAlignment read FAlignment write SetAlignment default taRightJustify;
    property Caption: string read FCaption write SetCaption;
    property Checked: Boolean read FChecked write SetChecked default False;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property Font;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
  end;
implementation
uses SysUtils, WinProcs, native_window, native_mnemonic;
const RadioClass = 'CalmiraNativeRadioButton';
var RadioProcedure: WNDPROC;
constructor TRadioButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAlignment := taRightJustify;
  SetBounds(0, 0, 113, 17);
 
end;
function TRadioButton.NativeClassName: PChar;
begin RegisterNativeSuperclass('BUTTON', RadioClass, RadioProcedure); Result := RadioClass; end;
procedure TRadioButton.DefaultHandler(var Message);
begin
  with TMessage(Message) do
    Result := CallWindowProc(RadioProcedure, Handle, Msg, WParam, LParam);
end;
procedure TRadioButton.WndProc(var M: TMessage);
begin
  if (M.Msg = WM_PAINT) or (M.Msg = WM_ERASEBKGND) then DefaultHandler(M)
  else inherited WndProc(M);
end;
procedure TRadioButton.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  if (Parent = 0) or (Style and WS_CHILD = 0) then
    raise ENativeWindowError.Create('Radio button requires a child window');
  { BS_RADIOBUTTON, not BS_AUTORADIOBUTTON: the group logic is Delphi's. }
  Style := (Style and not DWORD($F or BS_LEFTTEXT or WS_TABSTOP)) or BS_RADIOBUTTON;
  if FAlignment = taLeftJustify then Style := Style or BS_LEFTTEXT;
  if TabStop then Style := Style or WS_TABSTOP;
  inherited CreateHandle(Parent, FCaption, Style, X, Y, Width, Height);
  try
    Perform(BM_SETCHECK, Ord(FChecked), 0); FontChanged;
  except DestroyHandle; raise; end;
end;
procedure TRadioButton.TurnSiblingsOff;
var I: Integer; Sibling: TControl;
begin
  if Parent = nil then Exit;
  for I := 0 to Parent.ControlCount - 1 do
  begin
    Sibling := Parent.Controls[I];
    if (Sibling <> Self) and (Sibling is TRadioButton) then
      TRadioButton(Sibling).SetChecked(False);
  end;
end;
procedure TRadioButton.SetChecked(Value: Boolean);
begin
  if FChecked = Value then Exit;
  FChecked := Value;
  TabStop := Value;
  if Handle <> 0 then Perform(BM_SETCHECK, Ord(Value), 0);
  if Value then
  begin
    TurnSiblingsOff;
    if Assigned(FOnClick) then FOnClick(Self);
  end;
end;
procedure TRadioButton.SetAlignment(Value: TAlignment);
begin
  if Value = taCenter then raise ENativeWindowError.Create('Radio button cannot center');
  if FAlignment = Value then Exit;
  FAlignment := Value;
  if Handle <> 0 then
  begin
    if Value = taLeftJustify then
      SetWindowLong(Handle, GWL_STYLE, GetWindowLong(Handle, GWL_STYLE) or BS_LEFTTEXT)
    else
      SetWindowLong(Handle, GWL_STYLE, GetWindowLong(Handle, GWL_STYLE) and not BS_LEFTTEXT);
    Invalidate;
  end;
end;
procedure TRadioButton.Click;
begin
  if Enabled then Checked := True;
end;
function TRadioButton.ControlCommand(Code: Word): Boolean;
begin
  Result := Code = BN_CLICKED;
  if Result and Enabled and Visible then Click;
end;
function TRadioButton.ControlMnemonic(Key: Char): Boolean;
begin
  Result := CanFocus and CaptionMatches(Caption, Key);
  if Result then
  begin
    SetFocus;
    if CanFocus and Focused then Click;
  end;
end;
procedure TRadioButton.SetCaption(const Value: string);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('NUL in radio button caption');
  if Handle <> 0 then begin StrPCopy(Buffer, Value); SetWindowText(Handle, Buffer); end;
  FCaption := Value; Invalidate;
end;
procedure TRadioButton.FontChanged;
var NativeFont: HFONT;
begin
  if Handle = 0 then Exit;
  try NativeFont := Font.Handle;
  except Perform(WM_SETFONT, GetStockObject(SYSTEM_FONT), 0); Invalidate; raise; end;
  Perform(WM_SETFONT, NativeFont, 0); Invalidate;
end;
end.
