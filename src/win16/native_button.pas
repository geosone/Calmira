{ SPDX-License-Identifier: GPL-2.0-or-later
  Private Win16 BUTTON superclass with managed command/owner-draw routing. }
unit native_button;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This button requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls;
type
  TButton = class(TCustomControl)
  private
    FCaption: string;
    FOnClick: TNotifyEvent;
    FDrawing: Boolean;
    FDefault, FCancel: Boolean;
    FModalResult: TModalResult;
    procedure SetDefault(Value: Boolean);
    procedure SetCaption(const Value: string);
  protected
    procedure FontChanged; override;
    function NativeClassName: PChar; override;
    function ButtonStyle: Word; virtual;
    function ControlDialogKey(Key: Word): Boolean; override;
    function ControlMnemonic(Key: Char): Boolean; override;
    procedure WndProc(var M: TMessage); override;
    function ControlCommand(Code: Word): Boolean; override;
    function ControlDrawItem(var Item: TDrawItemStruct): Boolean; override;
    procedure DrawButton(var Item: TDrawItemStruct); virtual;
    property Drawing: Boolean read FDrawing;
  public
    constructor Create(AOwner: TComponent); override;
    procedure DefaultHandler(var Message); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure Click; override;
  published
    property Caption: string read FCaption write SetCaption;
    property Font;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
    property Default: Boolean read FDefault write SetDefault;
    property Cancel: Boolean read FCancel write FCancel;
    property ModalResult: TModalResult read FModalResult write FModalResult default 0;
  end;
implementation
uses SysUtils, WinProcs, native_window, native_mnemonic;
const ButtonClass = 'CalmiraNativeButton';
var ButtonProcedure: WNDPROC;
constructor TButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); TabStop := True; SetBounds(0, 0, 75, 23);
 
end;
function TButton.NativeClassName: PChar;
begin RegisterNativeSuperclass('BUTTON', ButtonClass, ButtonProcedure); Result := ButtonClass; end;
function TButton.ButtonStyle: Word;
begin if FDefault then Result := BS_DEFPUSHBUTTON else Result := BS_PUSHBUTTON; end;
procedure TButton.SetDefault(Value: Boolean);
begin
  if Value = FDefault then Exit;
  FDefault := Value;
  if Handle <> 0 then Perform(BM_SETSTYLE, ButtonStyle, 1);
end;
function TButton.ControlDialogKey(Key: Word): Boolean;
begin
  Result := CanFocus and (((Key = VK_RETURN) and (FDefault or Focused)) or
    ((Key = VK_ESCAPE) and FCancel));
  if Result then Click;
end;
function TButton.ControlMnemonic(Key: Char): Boolean;
begin
  Result := CanFocus and CaptionMatches(Caption, Key);
  if Result then
  begin
    SetFocus;
    if CanFocus and Focused then Click;
  end;
end;
procedure TButton.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  if (Parent = 0) or (Style and WS_CHILD = 0) then
    raise ENativeWindowError.Create('Button requires a child window');
  Style := Style and not DWORD(WS_TABSTOP);
  if TabStop then Style := Style or WS_TABSTOP;
  inherited CreateHandle(Parent, FCaption, (Style and not DWORD($F)) or ButtonStyle,
    X, Y, Width, Height);
  try FontChanged; except DestroyHandle; raise; end;
end;
procedure TButton.DefaultHandler(var Message);
begin
  with TMessage(Message) do
    Result := CallWindowProc(ButtonProcedure, Handle, Msg, WParam, LParam);
end;
procedure TButton.WndProc(var M: TMessage);
begin
  { USER owns native button painting; owner-draw uses WM_DRAWITEM on its parent. }
  if (M.Msg = WM_PAINT) or (M.Msg = WM_ERASEBKGND) then DefaultHandler(M)
  else inherited WndProc(M);
end;
procedure TButton.FontChanged;
var NativeFont: HFONT;
begin
  if Handle <> 0 then
  begin
    try NativeFont := Font.Handle;
    except
      { A font setter may already have released the old HFONT. Never leave
        USER holding that stale handle if allocation of its replacement fails. }
      Perform(WM_SETFONT, GetStockObject(SYSTEM_FONT), 0); Invalidate; raise;
    end;
    Perform(WM_SETFONT, NativeFont, 0); Invalidate;
  end;
end;
procedure TButton.SetCaption(const Value: string);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('Embedded NUL in button caption');
  if Handle <> 0 then begin StrPCopy(Buffer, Value); SetWindowText(Handle, Buffer); end;
  FCaption := Value; Invalidate;
end;
procedure TButton.Click;
begin
  if FDrawing then raise ENativeWindowError.Create('Cannot activate button while drawing');
  if not Enabled then Exit;
  { Match VCL ordering: an OnClick handler may reset the form result to veto. }
  if Parent <> nil then Parent.ApplyModalResult(FModalResult);
  if Assigned(FOnClick) then FOnClick(Self);
end;
function TButton.ControlCommand(Code: Word): Boolean;
begin
  Result := Code = BN_CLICKED;
  if Result and Enabled and Visible then Click;
end;
function TButton.ControlDrawItem(var Item: TDrawItemStruct): Boolean;
var State: SmallInt; Previous: HDC;
begin
  Result := Item.CtlType = ODT_BUTTON;
  if not Result or FDrawing then Exit;
  if Item.hDC = 0 then raise ENativeWindowError.Create('Missing button draw DC');
  State := SaveDC(Item.hDC);
  if State = 0 then raise ENativeWindowError.Create('Cannot save button DC');
  Previous := Canvas.Handle; FDrawing := True;
  try
    Canvas.Handle := Item.hDC; DrawButton(Item);
  finally Canvas.Handle := Previous; FDrawing := False; RestoreDC(Item.hDC, State); end;
end;
procedure TButton.DrawButton(var Item: TDrawItemStruct);
begin raise ENativeWindowError.Create('This button has no owner-draw implementation'); end;
end.
