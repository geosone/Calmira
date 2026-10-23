{ SPDX-License-Identifier: GPL-2.0-or-later
  Single-line ANSI Win16 EDIT, bounded to the Delphi 1 short-string interface. }
unit native_edit;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This edit control requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls, control_base;
type
  TEditCharCase = (ecNormal, ecUpperCase, ecLowerCase);
  TEdit = class(TCustomControl)
  private
    FText: string;
    FMaxLength, FSelStart, FSelLength: Integer;
    FPasswordChar: Char;
    FCharCase: TEditCharCase;
    FReadOnly, FModified, FInitializing, FNotifying: Boolean;
    FAutoSelect: Boolean;
    FBorderStyle: TBorderStyle;
    FOnChange: TNotifyEvent;
    procedure SetBorderStyle(Value: TBorderStyle);
    function GetText: string;
    procedure SetText(const Value: string);
    procedure ReadText;
    procedure ReadChangedText;
    procedure ReadSelection;
    procedure WriteSelection;
    function GetSelStart: Integer;
    procedure SetSelStart(Value: Integer);
    function GetSelLength: Integer;
    procedure SetSelLength(Value: Integer);
    function GetSelText: string;
    procedure SetSelText(const Value: string);
    function GetModified: Boolean;
    procedure SetModified(Value: Boolean);
    procedure SetMaxLength(Value: Integer);
    function NativeLimit: Integer;
    procedure SetReadOnly(Value: Boolean);
    procedure SetPasswordChar(Value: Char);
    procedure SetCharCase(Value: TEditCharCase);
  protected
    procedure FontChanged; override;
    function NativeClassName: PChar; override;
    procedure WndProc(var M: TMessage); override;
    function ControlCommand(Code: Word): Boolean; override;
    procedure Change; virtual;
    { AutoSelect: entering the edit other than by mouse selects all text. }
    procedure DoEnter; override;
    { Extra ES_* bits for descendants (TSpinEdit needs ES_MULTILINE). }
    function ExtraStyle: DWORD; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure DefaultHandler(var Message); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure Clear;
    procedure SelectAll;
    procedure ClearSelection;
    procedure CopyToClipboard;
    procedure CutToClipboard;
    procedure PasteFromClipboard;
    procedure Undo;
    function CanUndo: Boolean;
    property SelStart: Integer read GetSelStart write SetSelStart;
    property SelLength: Integer read GetSelLength write SetSelLength;
    property SelText: string read GetSelText write SetSelText;
    property Modified: Boolean read GetModified write SetModified;
  published
    property Text: string read GetText write SetText;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 0;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property PasswordChar: Char read FPasswordChar write SetPasswordChar;
    property CharCase: TEditCharCase read FCharCase write SetCharCase default ecNormal;
    property AutoSelect: Boolean read FAutoSelect write FAutoSelect default True;
    { Fixed once the window exists. }
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property Font;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
  end;
implementation
uses SysUtils, WinProcs, Win31, native_window;
const EditClass = 'CalmiraNativeEdit';
var EditProcedure: WNDPROC;
constructor TEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); TabStop := True;
  Color := clWindow; ParentColor := False;
  FAutoSelect := True; FBorderStyle := bsSingle;
  SetBounds(0, 0, 121, 23);
end;
function TEdit.NativeClassName: PChar;
begin RegisterNativeSuperclass('EDIT', EditClass, EditProcedure); Result := EditClass; end;
procedure TEdit.DefaultHandler(var Message);
begin
  with TMessage(Message) do
    Result := CallWindowProc(EditProcedure, Handle, Msg, WParam, LParam);
end;
procedure TEdit.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  if (Parent = 0) or (Style and WS_CHILD = 0) then
    raise ENativeWindowError.Create('Edit requires a child window');
  Style := (Style and not DWORD($FFFF or WS_TABSTOP or WS_BORDER)) or ES_AUTOHSCROLL or ExtraStyle;
  if FBorderStyle = bsSingle then Style := Style or WS_BORDER;
  if TabStop then Style := Style or WS_TABSTOP;
  if FReadOnly then Style := Style or ES_READONLY;
  if FCharCase = ecUpperCase then Style := Style or ES_UPPERCASE;
  if FCharCase = ecLowerCase then Style := Style or ES_LOWERCASE;
  FInitializing := True;
  try
    inherited CreateHandle(Parent, FText, Style, X, Y, Width, Height);
    try
      Perform(EM_LIMITTEXT, NativeLimit, 0);
      Perform(EM_SETPASSWORDCHAR, Ord(FPasswordChar), 0);
      FontChanged; WriteSelection; SetModified(FModified);
    except DestroyHandle; raise; end;
  finally FInitializing := False; end;
end;
procedure TEdit.SetBorderStyle(Value: TBorderStyle);
begin
  if Value = FBorderStyle then Exit;
  if Handle <> 0 then raise ENativeWindowError.Create('Edit border cannot change after creation');
  FBorderStyle := Value;
end;
procedure TEdit.DoEnter;
begin
  if FAutoSelect and (GetKeyState(VK_LBUTTON) >= 0) then SelectAll;
  inherited DoEnter;
end;
function TEdit.ExtraStyle: DWORD;
begin Result := 0; end;
procedure TEdit.ReadText;
var Buffer: array[0..255] of Char; Count: Integer;
begin
  if Handle = 0 then Exit;
  if GetWindowTextLength(Handle) > 255 then
    raise ENativeWindowError.Create('Edit text exceeds 255 bytes');
  Count := GetWindowText(Handle, Buffer, SizeOf(Buffer));
  SetString(FText, PChar(@Buffer), Count);
end;
function TEdit.GetText: string;
begin ReadText; Result := FText; end;
procedure TEdit.SetText(const Value: string);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('NUL in edit text');
  ReadText;
  if FText = Value then Exit;
  if Handle <> 0 then
  begin
    StrPCopy(Buffer, Value);
    if Perform(WM_SETTEXT, 0, LongInt(Pointer(@Buffer))) = 0 then
      raise ENativeWindowError.Create('Cannot set edit text');
  end
  else
  begin FText := Value; FSelStart := 0; FSelLength := 0; FModified := False; Change; end;
end;
procedure TEdit.Change;
begin
  if FInitializing or FNotifying then Exit;
  FNotifying := True;
  try if Assigned(FOnChange) then FOnChange(Self);
  finally FNotifying := False; end;
end;
procedure TEdit.ReadChangedText;
var Previous: string;
begin
  Previous := FText; ReadText;
  if Previous <> FText then Change;
end;
function TEdit.ControlCommand(Code: Word): Boolean;
begin
  Result := Code = EN_CHANGE;
  if Result then ReadChangedText;
end;
procedure TEdit.WndProc(var M: TMessage);
var I: Integer; Source: PChar;
begin
  if (M.Msg = WM_SETTEXT) and (M.LParam <> 0) then
  begin
    { Inspect at most 256 bytes: never scan an unbounded foreign string. }
    Source := PChar(Pointer(M.LParam)); I := 0;
    while (I < 255) and (Source[I] <> #0) do Inc(I);
    if Source[I] <> #0 then
      raise ENativeWindowError.Create('Edit text exceeds 255 bytes');
  end;
  if M.Msg = WM_DESTROY then
  begin ReadText; ReadSelection; FModified := GetModified; end;
  { USER owns EDIT painting and its local edit buffer. }
  if (M.Msg = WM_PAINT) or (M.Msg = WM_ERASEBKGND) then DefaultHandler(M)
  else inherited WndProc(M);
  case M.Msg of
    WM_SETTEXT, WM_CHAR, WM_CUT, WM_PASTE, WM_CLEAR, WM_UNDO, EM_UNDO, EM_REPLACESEL:
      begin
        { Fallback for CreateControl(HWND) without a managed command parent.
          A synchronously routed EN_CHANGE already updated FText: no duplicate. }
        ReadChangedText;
      end;
  end;
end;
procedure TEdit.ReadSelection;
var Selection: LongInt;
begin
  if Handle = 0 then Exit;
  Selection := Perform(EM_GETSEL, 0, 0);
  FSelStart := Word(Selection); FSelLength := Word(Selection shr 16) - FSelStart;
end;
procedure TEdit.WriteSelection;
begin
  if Handle <> 0 then Perform(EM_SETSEL, 0,
    LongInt(FSelStart) or (LongInt(FSelStart + FSelLength) shl 16));
end;
function TEdit.GetSelStart: Integer;
begin ReadSelection; Result := FSelStart; end;
function TEdit.GetSelLength: Integer;
begin ReadSelection; Result := FSelLength; end;
procedure TEdit.SetSelStart(Value: Integer);
begin
  if Value < 0 then Value := 0;
  ReadText; if Value > Length(FText) then Value := Length(FText);
  FSelStart := Value; FSelLength := 0; WriteSelection;
end;
procedure TEdit.SetSelLength(Value: Integer);
begin
  ReadText; ReadSelection;
  if Value < 0 then Value := 0;
  if Value > Length(FText) - FSelStart then Value := Length(FText) - FSelStart;
  FSelLength := Value; WriteSelection;
end;
function TEdit.GetSelText: string;
begin ReadText; ReadSelection; Result := Copy(FText, FSelStart + 1, FSelLength); end;
procedure TEdit.SetSelText(const Value: string);
var Buffer: array[0..255] of Char; Position: Integer; Previous: string;
begin
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('NUL in edit text');
  ReadText; ReadSelection;
  if Length(FText) - FSelLength + LongInt(Length(Value)) > 255 then
    raise ENativeWindowError.Create('Edit text exceeds 255 bytes');
  if Handle <> 0 then
  begin StrPCopy(Buffer, Value); Perform(EM_REPLACESEL, 0, LongInt(Pointer(@Buffer))); end
  else
  begin
    Previous := FText; Position := FSelStart;
    Delete(FText, Position + 1, FSelLength); Insert(Value, FText, Position + 1);
    FSelStart := Position + Length(Value); FSelLength := 0; FModified := True;
    if Previous <> FText then Change;
  end;
end;
procedure TEdit.SelectAll;
begin ReadText; FSelStart := 0; FSelLength := Length(FText); WriteSelection; end;
procedure TEdit.Clear;
begin Text := ''; end;
procedure TEdit.ClearSelection;
begin Perform(WM_CLEAR, 0, 0); end;
procedure TEdit.CopyToClipboard;
begin Perform(WM_COPY, 0, 0); end;
procedure TEdit.CutToClipboard;
begin Perform(WM_CUT, 0, 0); end;
procedure TEdit.PasteFromClipboard;
begin Perform(WM_PASTE, 0, 0); end;
procedure TEdit.Undo;
begin Perform(EM_UNDO, 0, 0); end;
function TEdit.CanUndo: Boolean;
begin Result := (Handle <> 0) and (Perform(EM_CANUNDO, 0, 0) <> 0); end;
function TEdit.GetModified: Boolean;
begin
  if Handle <> 0 then FModified := Perform(EM_GETMODIFY, 0, 0) <> 0;
  Result := FModified;
end;
procedure TEdit.SetModified(Value: Boolean);
begin FModified := Value; if Handle <> 0 then Perform(EM_SETMODIFY, Ord(Value), 0); end;
function TEdit.NativeLimit: Integer;
begin
  if FMaxLength = 0 then Result := 255 else Result := FMaxLength;
end;
procedure TEdit.SetMaxLength(Value: Integer);
begin
  if (Value < 0) or (Value > 255) then raise ENativeWindowError.Create('Edit limit must be 0..255');
  FMaxLength := Value; if Handle <> 0 then Perform(EM_LIMITTEXT, NativeLimit, 0);
end;
procedure TEdit.SetReadOnly(Value: Boolean);
begin
  if Handle <> 0 then
    if Perform(EM_SETREADONLY, Ord(Value), 0) = 0 then
      raise ENativeWindowError.Create('Cannot set edit read-only state');
  FReadOnly := Value;
end;
procedure TEdit.SetPasswordChar(Value: Char);
begin
  FPasswordChar := Value;
  if Handle <> 0 then begin Perform(EM_SETPASSWORDCHAR, Ord(Value), 0); Invalidate; end;
end;
procedure TEdit.SetCharCase(Value: TEditCharCase);
var Style: LongInt;
begin
  if (Ord(Value) < 0) or (Ord(Value) > 2) then
    raise ENativeWindowError.Create('Invalid edit character case');
  FCharCase := Value;
  if Handle = 0 then Exit;
  Style := GetWindowLong(Handle, GWL_STYLE) and not LongInt(ES_UPPERCASE or ES_LOWERCASE);
  if Value = ecUpperCase then Style := Style or ES_UPPERCASE;
  if Value = ecLowerCase then Style := Style or ES_LOWERCASE;
  SetWindowLong(Handle, GWL_STYLE, Style);
end;
procedure TEdit.FontChanged;
var NativeFont: HFONT;
begin
  if Handle = 0 then Exit;
  try NativeFont := Font.Handle;
  except Perform(WM_SETFONT, GetStockObject(SYSTEM_FONT), 0); Invalidate; raise; end;
  Perform(WM_SETFONT, NativeFont, 0); Invalidate;
end;
end.
