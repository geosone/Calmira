{ SPDX-License-Identifier: GPL-2.0-or-later
  Native COMBOBOX with Delphi 1 Items/Text/ItemIndex semantics. Items are
  kept in a TStringList (strings, objects, sorting) and mirrored into the
  window, so they survive handle recreation. Owner-drawn styles paint through
  Canvas/DrawItem and size items through ItemHeight/MeasureItem. Keyboard
  events of the internal edit are not provided yet. }
unit native_combobox;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This combo box requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls, native_listbox;
type
  TComboBoxStyle = (csDropDown, csSimple, csDropDownList, csOwnerDrawFixed,
    csOwnerDrawVariable);
  TCustomComboBox = class;
  TComboBoxStrings = class(TStrings)
  private
    FCombo: TCustomComboBox;
    FItems: TStringList;
  protected
    function Get(Index: Integer): AnsiString; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: AnsiString); override;
    procedure PutObject(Index: Integer; AObject: TObject); override;
    procedure SetUpdateState(Updating: Boolean); override;
  public
    constructor Create(Combo: TCustomComboBox);
    destructor Destroy; override;
    function Add(const S: AnsiString): Integer; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: AnsiString); override;
    function IndexOf(const S: AnsiString): Integer; override;
  end;
  TCustomComboBox = class(TCustomControl)
  private
    FItems: TComboBoxStrings;
    FStyle: TComboBoxStyle;
    FText: string;
    FItemIndex: Integer;
    FMaxLength: Integer;
    FDropDownCount: Integer;
    FSorted: Boolean;
    FNotifying: Boolean;
    FDrawing: Boolean;
    FItemHeight: Integer;
    FOnChange, FOnClick, FOnDblClick, FOnDropDown: TNotifyEvent;
    FOnDrawItem: TDrawItemEvent;
    FOnMeasureItem: TMeasureItemEvent;
    function GetItemHeight: Integer;
    procedure SetItemHeight(Value: Integer);
    function GetItems: TStrings;
    procedure SetItems(Value: TStrings);
    function GetItemIndex: Integer;
    procedure SetItemIndex(Value: Integer);
    function GetText: string;
    procedure SetText(const Value: string);
    procedure SetStyle(Value: TComboBoxStyle);
    procedure SetMaxLength(Value: Integer);
    procedure SetDropDownCount(Value: Integer);
    procedure SetSorted(Value: Boolean);
    function GetDroppedDown: Boolean;
    procedure SetDroppedDown(Value: Boolean);
    function ListHeight: Integer;
    procedure SaveState;
    procedure LoadItems;
    procedure Notify(Event: TNotifyEvent);
  protected
    procedure FontChanged; override;
    function NativeClassName: PChar; override;
    procedure WndProc(var M: TMessage); override;
    function ControlCommand(Code: Word): Boolean; override;
    function OwnsNativeChild(Window: HWND): Boolean; override;
    function GetFocused: Boolean; override;
    procedure Change; virtual;
    procedure Click; override;
    procedure DropDown; virtual;
    { CBN_DBLCLK; USER sends it only for csSimple. }
    procedure DblClick; override;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
    function ControlDrawItem(var Item: TDrawItemStruct): Boolean; override;
    function ControlMeasureItem(var Item: TMeasureItemStruct): Boolean; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); virtual;
    procedure MeasureItem(Index: Integer; var Height: Integer); virtual;
    property ItemHeight: Integer read GetItemHeight write SetItemHeight;
    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnMeasureItem: TMeasureItemEvent read FOnMeasureItem write FOnMeasureItem;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DefaultHandler(var Message); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure SetBounds(X, Y, AWidth, AHeight: Integer); override;
    procedure Clear;
    procedure SelectAll;
    property DroppedDown: Boolean read GetDroppedDown write SetDroppedDown;
    property Items: TStrings read GetItems write SetItems;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property Text: string read GetText write SetText;
    property Style: TComboBoxStyle read FStyle write SetStyle default csDropDown;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 0;
    property DropDownCount: Integer read FDropDownCount write SetDropDownCount default 8;
    property Sorted: Boolean read FSorted write SetSorted default False;
    property Font;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
  end;
  TComboBox = class(TCustomComboBox)
  published
    property Style;
    property Items;
    property ItemIndex;
    property Text;
    property MaxLength;
    property DropDownCount;
    property Sorted;
    property ItemHeight;
    property OnDrawItem;
    property OnMeasureItem;
    property OnDblClick;
    property Font;
    property OnChange;
    property OnClick;
    property OnDropDown;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
  end;
implementation
uses SysUtils, WinProcs, Win31, native_window;
const ComboClass = 'CalmiraNativeComboBox';
var ComboProcedure: WNDPROC;
procedure Fail(const Text: string);
begin raise ENativeWindowError.Create(Text); end;
{ TComboBoxStrings }
constructor TComboBoxStrings.Create(Combo: TCustomComboBox);
begin
  inherited Create;
  FCombo := Combo;
  FItems := TStringList.Create;
end;
destructor TComboBoxStrings.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;
function TComboBoxStrings.Get(Index: Integer): AnsiString;
begin Result := FItems[Index]; end;
function TComboBoxStrings.GetCount: Integer;
begin Result := FItems.Count; end;
function TComboBoxStrings.GetObject(Index: Integer): TObject;
begin Result := FItems.Objects[Index]; end;
procedure TComboBoxStrings.PutObject(Index: Integer; AObject: TObject);
begin FItems.Objects[Index] := AObject; end;
procedure TComboBoxStrings.Put(Index: Integer; const S: AnsiString);
var Selected: Integer; AObject: TObject;
begin
  Selected := FCombo.ItemIndex; AObject := FItems.Objects[Index];
  Delete(Index);
  { A sorted list places the new string itself. }
  if FCombo.FSorted then Index := Add(S) else Insert(Index, S);
  FItems.Objects[Index] := AObject;
  if Selected >= 0 then FCombo.ItemIndex := Index;
end;
procedure TComboBoxStrings.SetUpdateState(Updating: Boolean);
begin
  if FCombo.Handle = 0 then Exit;
  FCombo.Perform(WM_SETREDRAW, Ord(not Updating), 0);
  if not Updating then FCombo.Invalidate;
end;
function TComboBoxStrings.Add(const S: AnsiString): Integer;
begin
  if FCombo.FSorted then
  begin
    Result := FItems.Add(S);
    Insert(-1 - Result, S);
  end
  else
  begin
    Result := FItems.Count;
    Insert(Result, S);
  end;
end;
procedure TComboBoxStrings.Insert(Index: Integer; const S: AnsiString);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, S) <> 0 then Fail('NUL in combo box item');
  { A negative index marks a string that Add already placed in FItems. }
  if Index >= 0 then
  begin
    if FCombo.FSorted then Fail('Cannot insert into a sorted combo box');
    FItems.Insert(Index, S);
  end
  else Index := -1 - Index;
  if FCombo.Handle <> 0 then
    if FCombo.Perform(CB_INSERTSTRING, Index, LongInt(StrPCopy(Buffer, S))) < 0 then
    begin
      FItems.Delete(Index);
      Fail('Cannot add combo box item');
    end;
end;
procedure TComboBoxStrings.Delete(Index: Integer);
begin
  FItems.Delete(Index);
  if FCombo.Handle <> 0 then FCombo.Perform(CB_DELETESTRING, Index, 0)
  else if FCombo.FItemIndex >= FItems.Count then FCombo.FItemIndex := -1;
end;
procedure TComboBoxStrings.Clear;
begin
  FItems.Clear;
  FCombo.FItemIndex := -1;
  if FCombo.Handle <> 0 then FCombo.Perform(CB_RESETCONTENT, 0, 0);
end;
function TComboBoxStrings.IndexOf(const S: AnsiString): Integer;
begin Result := FItems.IndexOf(S); end;
{ TCustomComboBox }
constructor TCustomComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TComboBoxStrings.Create(Self);
  FItemIndex := -1;
  FDropDownCount := 8;
  FItemHeight := 16;
  TabStop := True;
  Color := clWindow; ParentColor := False;
  SetBounds(0, 0, 145, 21);
 
end;
destructor TCustomComboBox.Destroy;
begin
  inherited Destroy;
  FItems.Free;
end;
function TCustomComboBox.NativeClassName: PChar;
begin RegisterNativeSuperclass('COMBOBOX', ComboClass, ComboProcedure); Result := ComboClass; end;
procedure TCustomComboBox.DefaultHandler(var Message);
begin
  with TMessage(Message) do
    Result := CallWindowProc(ComboProcedure, Handle, Msg, WParam, LParam);
end;
function TCustomComboBox.ListHeight: Integer;
begin
  Result := FDropDownCount * (Abs(Font.Height) + 4) + 2;
end;
procedure TCustomComboBox.WndProc(var M: TMessage);
begin
  case M.Msg of
    WM_PAINT, WM_ERASEBKGND: DefaultHandler(M);
    { The combo box or its edit owns focus; CBN_SETFOCUS/KILLFOCUS report it once. }
    WM_SETFOCUS, WM_KILLFOCUS: DefaultHandler(M);
    WM_DESTROY: begin SaveState; inherited WndProc(M); end;
  else inherited WndProc(M);
  end;
end;
function TCustomComboBox.OwnsNativeChild(Window: HWND): Boolean;
begin
  Result := (Handle <> 0) and (Window <> 0) and (WinProcs.GetParent(Window) = Handle);
end;
function TCustomComboBox.GetFocused: Boolean;
var Focus: HWND;
begin
  Focus := GetFocus;
  Result := (Handle <> 0) and ((Focus = Handle) or OwnsNativeChild(Focus));
end;
procedure TCustomComboBox.SaveState;
begin
  if Handle = 0 then Exit;
  FItemIndex := Perform(CB_GETCURSEL, 0, 0);
  if FStyle in [csDropDown, csSimple] then FText := GetText;
end;
procedure TCustomComboBox.LoadItems;
var I: Integer; Buffer: array[0..255] of Char;
begin
  for I := 0 to FItems.Count - 1 do
    if Perform(CB_ADDSTRING, 0, LongInt(StrPCopy(Buffer, FItems.FItems[I]))) < 0 then
      Fail('Cannot add combo box item');
end;
procedure TCustomComboBox.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
const Styles: array[TComboBoxStyle] of DWORD = (CBS_DROPDOWN, CBS_SIMPLE,
  CBS_DROPDOWNLIST, CBS_DROPDOWNLIST or CBS_OWNERDRAWFIXED or CBS_HASSTRINGS,
  CBS_DROPDOWNLIST or CBS_OWNERDRAWVARIABLE or CBS_HASSTRINGS);
var Buffer: array[0..255] of Char;
begin
  if (Parent = 0) or (Style and WS_CHILD = 0) then Fail('Combo box requires a child window');
  Style := (Style and not DWORD($FFFF or WS_TABSTOP)) or Styles[FStyle] or
    WS_VSCROLL or CBS_AUTOHSCROLL;
  if TabStop then Style := Style or WS_TABSTOP;
  { USER sizes the closed box itself; the requested height is the list's. }
  if FStyle <> csSimple then Height := Height + ListHeight;
  inherited CreateHandle(Parent, '', Style, X, Y, Width, Height);
  try
    FontChanged;
    LoadItems;
    if FMaxLength > 0 then Perform(CB_LIMITTEXT, FMaxLength, 0);
    if FItemIndex >= FItems.Count then FItemIndex := -1;
    Perform(CB_SETCURSEL, FItemIndex, 0);
    { The edit may hold typed text that differs from the selected item. }
    if FStyle in [csDropDown, csSimple] then SetWindowText(Handle, StrPCopy(Buffer, FText));
  except DestroyHandle; raise; end;
end;
procedure TCustomComboBox.SetBounds(X, Y, AWidth, AHeight: Integer);
begin
  inherited SetBounds(X, Y, AWidth, AHeight);
  if (Handle <> 0) and (FStyle <> csSimple) then
    SetWindowPos(Handle, 0, 0, 0, AWidth, AHeight + ListHeight,
      SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
end;
function TCustomComboBox.GetItemHeight: Integer;
begin
  if (FStyle in [csOwnerDrawFixed, csOwnerDrawVariable]) or (Handle = 0) then
    Result := FItemHeight
  else Result := Perform(CB_GETITEMHEIGHT, 0, 0);
end;
procedure TCustomComboBox.SetItemHeight(Value: Integer);
begin
  { Like Delphi 1, the height reaches USER only when the window is created. }
  if Value > 0 then FItemHeight := Value;
end;
function TCustomComboBox.ControlMeasureItem(var Item: TMeasureItemStruct): Boolean;
var Height: Integer;
begin
  Result := Item.CtlType = ODT_COMBOBOX;
  if not Result then Exit;
  Height := FItemHeight;
  if FStyle = csOwnerDrawVariable then MeasureItem(Integer(Item.itemID), Height);
  Item.itemHeight := Height;
end;
function TCustomComboBox.ControlDrawItem(var Item: TDrawItemStruct): Boolean;
var State: TOwnerDrawState; Saved: SmallInt; Previous: HDC; TextColor: TColor;
begin
  Result := Item.CtlType = ODT_COMBOBOX;
  if not Result or FDrawing then Exit;
  if Item.hDC = 0 then Fail('Missing combo box draw DC');
  State := TOwnerDrawState(Byte(Lo(Item.itemState)));
  Saved := SaveDC(Item.hDC);
  if Saved = 0 then Fail('Cannot save combo box DC');
  Previous := Canvas.Handle; FDrawing := True;
  try
    Canvas.Handle := Item.hDC;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Color;
    { The highlight colour is for this item only. }
    TextColor := Canvas.Font.Color;
    try
      if (Integer(Item.itemID) >= 0) and (odSelected in State) then
      begin
        Canvas.Brush.Color := clHighlight;
        Canvas.Font.Color := clHighlightText;
      end;
      if (Integer(Item.itemID) >= 0) and (Integer(Item.itemID) < FItems.Count) then
        DrawItem(Item.itemID, Item.rcItem, State)
      else Canvas.FillRect(Item.rcItem);
      if odFocused in State then DrawFocusRect(Item.hDC, Item.rcItem);
    finally Canvas.Font.Color := TextColor; end;
  finally
    Canvas.Handle := Previous; FDrawing := False; RestoreDC(Item.hDC, Saved);
  end;
end;
procedure TCustomComboBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  if Assigned(FOnDrawItem) then FOnDrawItem(Self, Index, Rect, State)
  else
  begin
    Canvas.FillRect(Rect);
    Canvas.TextOut(Rect.Left + 2, Rect.Top, FItems[Index]);
  end;
end;
procedure TCustomComboBox.MeasureItem(Index: Integer; var Height: Integer);
begin
  if Assigned(FOnMeasureItem) then FOnMeasureItem(Self, Index, Height);
end;
function TCustomComboBox.GetItems: TStrings;
begin Result := FItems; end;
procedure TCustomComboBox.SetItems(Value: TStrings);
begin FItems.Assign(Value); end;
function TCustomComboBox.GetItemIndex: Integer;
begin
  if Handle <> 0 then FItemIndex := Perform(CB_GETCURSEL, 0, 0);
  Result := FItemIndex;
end;
procedure TCustomComboBox.SetItemIndex(Value: Integer);
begin
  if (Value < -1) or (Value >= FItems.Count) then Fail('Combo box index out of range');
  FItemIndex := Value;
  if Value >= 0 then FText := FItems[Value];
  if Handle <> 0 then Perform(CB_SETCURSEL, Value, 0);
end;
function TCustomComboBox.GetText: string;
var Buffer: array[0..255] of Char;
begin
  if Handle = 0 then
  begin
    if FStyle in [csDropDown, csSimple] then Result := FText
    else if FItemIndex >= 0 then Result := FItems[FItemIndex]
    else Result := '';
    Exit;
  end;
  GetWindowText(Handle, Buffer, SizeOf(Buffer));
  Result := StrPas(Buffer);
end;
procedure TCustomComboBox.SetText(const Value: string);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, Value) <> 0 then Fail('NUL in combo box text');
  if FStyle in [csDropDown, csSimple] then
  begin
    FText := Value;
    if Handle <> 0 then SetWindowText(Handle, StrPCopy(Buffer, Value));
  end
  else
    { A drop-down list can only show one of its items. }
    ItemIndex := FItems.IndexOf(Value);
end;
procedure TCustomComboBox.SetStyle(Value: TComboBoxStyle);
begin
  if FStyle = Value then Exit;
  if Handle <> 0 then Fail('Combo box style cannot change after creation');
  FStyle := Value;
end;
procedure TCustomComboBox.SetMaxLength(Value: Integer);
begin
  if (Value < 0) or (Value > 255) then Fail('Invalid combo box text limit');
  FMaxLength := Value;
  if Handle <> 0 then Perform(CB_LIMITTEXT, Value, 0);
end;
procedure TCustomComboBox.SetDropDownCount(Value: Integer);
begin
  if (Value < 1) or (Value > 100) then Fail('Invalid drop-down count');
  FDropDownCount := Value;
  if Handle <> 0 then SetBounds(Left, Top, Width, Height);
end;
procedure TCustomComboBox.SetSorted(Value: Boolean);
var Selected: string; Index: Integer;
begin
  if FSorted = Value then Exit;
  Index := ItemIndex;
  if Index >= 0 then Selected := FItems[Index];
  FSorted := Value;
  FItems.FItems.Sorted := Value;
  if Handle <> 0 then
  begin
    Perform(CB_RESETCONTENT, 0, 0);
    LoadItems;
  end;
  if Index >= 0 then ItemIndex := FItems.IndexOf(Selected);
end;
function TCustomComboBox.GetDroppedDown: Boolean;
begin Result := (Handle <> 0) and (Perform(CB_GETDROPPEDSTATE, 0, 0) <> 0); end;
procedure TCustomComboBox.SetDroppedDown(Value: Boolean);
begin if Handle <> 0 then Perform(CB_SHOWDROPDOWN, Ord(Value), 0); end;
procedure TCustomComboBox.Clear;
begin
  FItems.Clear;
  SetText('');
end;
procedure TCustomComboBox.SelectAll;
begin if Handle <> 0 then Perform(CB_SETEDITSEL, 0, MakeLong(0, $FFFF)); end;
procedure TCustomComboBox.Notify(Event: TNotifyEvent);
begin
  if FNotifying or not Assigned(Event) then Exit;
  FNotifying := True;
  try Event(Self);
  finally FNotifying := False; end;
end;
procedure TCustomComboBox.Change;
begin Notify(FOnChange); end;
procedure TCustomComboBox.Click;
begin Notify(FOnClick); end;
procedure TCustomComboBox.DropDown;
begin Notify(FOnDropDown); end;
procedure TCustomComboBox.DblClick;
begin Notify(FOnDblClick); end;
function TCustomComboBox.ControlCommand(Code: Word): Boolean;
var Index: Integer; Buffer: array[0..255] of Char;
begin
  Result := True;
  case Code of
    CBN_EDITCHANGE: Change;
    CBN_SELCHANGE:
      begin
        { Delphi 1 copies the new item into the edit before notifying. }
        Index := Perform(CB_GETCURSEL, 0, 0);
        if (Index >= 0) and (FStyle in [csDropDown, csSimple]) then
          SetWindowText(Handle, StrPCopy(Buffer, FItems[Index]));
        Click;
        Change;
      end;
    CBN_DROPDOWN: DropDown;
    CBN_DBLCLK: DblClick;
    CBN_SETFOCUS: DoEnter;
    CBN_KILLFOCUS: DoExit;
  else Result := False;
  end;
end;
procedure TCustomComboBox.FontChanged;
var NativeFont: HFONT;
begin
  if Handle = 0 then Exit;
  try NativeFont := Font.Handle;
  except Perform(WM_SETFONT, GetStockObject(SYSTEM_FONT), 0); Invalidate; raise; end;
  Perform(WM_SETFONT, NativeFont, 0); Invalidate;
end;
end.
