{ SPDX-License-Identifier: GPL-2.0-or-later
  Native LISTBOX with Delphi 1 TCustomListBox semantics. Items are kept in a
  TStringList (strings, objects, sorting) and mirrored into the window, so
  they survive handle recreation together with ItemIndex, TopIndex and a
  multi-selection. Owner-draw fixed lists paint through Canvas/DrawItem as in
  Delphi; lbOwnerDrawVariable is not provided yet and raises. }
unit native_listbox;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This list box requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls, control_base;
type
  TListBoxStyle = (lbStandard, lbOwnerDrawFixed, lbOwnerDrawVariable);
  { Bit order matches the ODS_* item state flags. }
  TOwnerDrawState = set of (odSelected, odGrayed, odDisabled, odChecked, odFocused);
  TDrawItemEvent = procedure(Control: TWinControl; Index: Integer;
    Rect: TRect; State: TOwnerDrawState) of object;
  TMeasureItemEvent = procedure(Control: TWinControl; Index: Integer;
    var Height: Integer) of object;
  TCustomListBox = class;
  TListBoxStrings = class(TStrings)
  private
    FListBox: TCustomListBox;
    FItems: TStringList;
  protected
    function Get(Index: Integer): AnsiString; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: AnsiString); override;
    procedure PutObject(Index: Integer; AObject: TObject); override;
    procedure SetUpdateState(Updating: Boolean); override;
  public
    constructor Create(ListBox: TCustomListBox);
    destructor Destroy; override;
    function Add(const S: AnsiString): Integer; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: AnsiString); override;
    function IndexOf(const S: AnsiString): Integer; override;
  end;
  TCustomListBox = class(TCustomControl)
  private
    FItems: TListBoxStrings;
    FStyle: TListBoxStyle;
    FBorderStyle: TBorderStyle;
    FColumns, FItemHeight, FItemIndex, FTopIndex: Integer;
    FMultiSelect, FExtendedSelect, FIntegralHeight, FSorted: Boolean;
    FSelection: TBits;
    FDrawing: Boolean;
    FOnDrawItem: TDrawItemEvent;
    FOnMeasureItem: TMeasureItemEvent;
    FOnClick, FOnDblClick: TNotifyEvent;
    function GetItems: TStrings;
    procedure SetItems(Value: TStrings);
    function GetItemIndex: Integer;
    procedure SetItemIndex(Value: Integer);
    function GetTopIndex: Integer;
    procedure SetTopIndex(Value: Integer);
    function GetSelCount: Integer;
    function GetSelected(Index: Integer): Boolean;
    procedure SetSelected(Index: Integer; Value: Boolean);
    function GetItemHeight: Integer;
    procedure SetItemHeight(Value: Integer);
    procedure SetStyle(Value: TListBoxStyle);
    procedure SetBorderStyle(Value: TBorderStyle);
    procedure SetColumns(Value: Integer);
    procedure SetMultiSelect(Value: Boolean);
    procedure SetExtendedSelect(Value: Boolean);
    procedure SetIntegralHeight(Value: Boolean);
    procedure SetSorted(Value: Boolean);
    function GetFont: TFont;
    procedure SetFont(Value: TFont);
    procedure FontChanged(Sender: TObject);
    procedure SetColumnWidth;
    procedure CheckIndex(Index: Integer);
    procedure SaveState;
    procedure LoadItems;
    procedure RequireLiveStyle;
    procedure WMSize(var M: TMessage); message WM_SIZE;
  protected
    function NativeClassName: PChar; override;
    procedure WndProc(var M: TMessage); override;
    function ControlCommand(Code: Word): Boolean; override;
    function ControlDrawItem(var Item: TDrawItemStruct): Boolean; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); virtual;
    procedure MeasureItem(Index: Integer; var Height: Integer); virtual;
    procedure Click; virtual;
    procedure DblClick; virtual;
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property Columns: Integer read FColumns write SetColumns default 0;
    property ExtendedSelect: Boolean read FExtendedSelect write SetExtendedSelect default True;
    property IntegralHeight: Boolean read FIntegralHeight write SetIntegralHeight default False;
    property ItemHeight: Integer read GetItemHeight write SetItemHeight;
    property MultiSelect: Boolean read FMultiSelect write SetMultiSelect default False;
    property Sorted: Boolean read FSorted write SetSorted default False;
    property Style: TListBoxStyle read FStyle write SetStyle default lbStandard;
    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnMeasureItem: TMeasureItemEvent read FOnMeasureItem write FOnMeasureItem;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DefaultHandler(var Message); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure Clear;
    function ItemAtPos(Pos: TPoint; Existing: Boolean): Integer;
    function ItemRect(Index: Integer): TRect;
    property Font: TFont read GetFont write SetFont;
    property Items: TStrings read GetItems write SetItems;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property SelCount: Integer read GetSelCount;
    property Selected[Index: Integer]: Boolean read GetSelected write SetSelected;
    property TopIndex: Integer read GetTopIndex write SetTopIndex;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
  end;
  TListBox = class(TCustomListBox)
  published
    property BorderStyle;
    property Columns;
    property ExtendedSelect;
    property IntegralHeight;
    property ItemHeight;
    property Items;
    property MultiSelect;
    property Sorted;
    property Style;
    property Font;
    property OnClick;
    property OnDblClick;
    property OnDrawItem;
    property OnMeasureItem;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
  end;
implementation
uses SysUtils, WinProcs, Win31, native_window;
const ListClass = 'CalmiraNativeListBox';
var ListProcedure: WNDPROC;
procedure Fail(const Text: string);
begin raise ENativeWindowError.Create(Text); end;

{ TListBoxStrings }
constructor TListBoxStrings.Create(ListBox: TCustomListBox);
begin
  inherited Create;
  FListBox := ListBox;
  FItems := TStringList.Create;
end;
destructor TListBoxStrings.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;
function TListBoxStrings.Get(Index: Integer): AnsiString;
begin Result := FItems[Index]; end;
function TListBoxStrings.GetCount: Integer;
begin Result := FItems.Count; end;
function TListBoxStrings.GetObject(Index: Integer): TObject;
begin Result := FItems.Objects[Index]; end;
procedure TListBoxStrings.PutObject(Index: Integer; AObject: TObject);
begin FItems.Objects[Index] := AObject; end;
procedure TListBoxStrings.Put(Index: Integer; const S: AnsiString);
var Selected: Integer; AObject: TObject;
begin
  Selected := FListBox.ItemIndex; AObject := FItems.Objects[Index];
  Delete(Index);
  if FListBox.FSorted then Index := Add(S) else Insert(Index, S);
  FItems.Objects[Index] := AObject;
  if Selected = Index then FListBox.ItemIndex := Index;
end;
procedure TListBoxStrings.SetUpdateState(Updating: Boolean);
begin
  if FListBox.Handle = 0 then Exit;
  FListBox.Perform(WM_SETREDRAW, Ord(not Updating), 0);
  if not Updating then FListBox.Invalidate;
end;
function TListBoxStrings.Add(const S: AnsiString): Integer;
begin
  if FListBox.FSorted then
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
procedure TListBoxStrings.Insert(Index: Integer; const S: AnsiString);
var Buffer: array[0..255] of Char;
begin
  if Pos(#0, S) <> 0 then Fail('NUL in list box item');
  { A negative index marks a string that Add already placed in FItems. }
  if Index >= 0 then
  begin
    if FListBox.FSorted then Fail('Cannot insert into a sorted list box');
    FItems.Insert(Index, S);
  end
  else Index := -1 - Index;
  if FListBox.Handle <> 0 then
    if FListBox.Perform(LB_INSERTSTRING, Index, LongInt(StrPCopy(Buffer, S))) < 0 then
    begin
      FItems.Delete(Index);
      Fail('Cannot add list box item');
    end;
end;
procedure TListBoxStrings.Delete(Index: Integer);
begin
  FItems.Delete(Index);
  if FListBox.Handle <> 0 then FListBox.Perform(LB_DELETESTRING, Index, 0)
  else if FListBox.FItemIndex >= FItems.Count then FListBox.FItemIndex := -1;
end;
procedure TListBoxStrings.Clear;
begin
  FItems.Clear;
  FListBox.FItemIndex := -1; FListBox.FTopIndex := 0;
  FListBox.FSelection.Size := 0;
  if FListBox.Handle <> 0 then FListBox.Perform(LB_RESETCONTENT, 0, 0);
end;
function TListBoxStrings.IndexOf(const S: AnsiString): Integer;
begin Result := FItems.IndexOf(S); end;

{ TCustomListBox }
constructor TCustomListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TListBoxStrings.Create(Self);
  FSelection := TBits.Create;
  FItemIndex := -1;
  FItemHeight := 16;
  FBorderStyle := bsSingle;
  FExtendedSelect := True;
  TabStop := True;
  Color := clWindow;
  SetBounds(0, 0, 121, 97);
  Canvas.Font.OnChange := FontChanged;
end;
destructor TCustomListBox.Destroy;
begin
  if Canvas <> nil then Canvas.Font.OnChange := nil;
  inherited Destroy;
  FSelection.Free;
  FItems.Free;
end;
function TCustomListBox.NativeClassName: PChar;
begin RegisterNativeSuperclass('LISTBOX', ListClass, ListProcedure); Result := ListClass; end;
procedure TCustomListBox.DefaultHandler(var Message);
begin
  with TMessage(Message) do
    Result := CallWindowProc(ListProcedure, Handle, Msg, WParam, LParam);
end;
procedure TCustomListBox.WndProc(var M: TMessage);
begin
  case M.Msg of
    WM_PAINT, WM_ERASEBKGND: DefaultHandler(M);
    WM_DESTROY: begin SaveState; inherited WndProc(M); end;
  else inherited WndProc(M);
  end;
end;
procedure TCustomListBox.SaveState;
var I: Integer;
begin
  if Handle = 0 then Exit;
  FItemIndex := Perform(LB_GETCURSEL, 0, 0);
  FTopIndex := Perform(LB_GETTOPINDEX, 0, 0);
  FSelection.Size := 0;
  if FMultiSelect then
    for I := 0 to FItems.Count - 1 do
      if Perform(LB_GETSEL, I, 0) > 0 then FSelection[I] := True;
end;
procedure TCustomListBox.LoadItems;
var I: Integer; Buffer: array[0..255] of Char;
begin
  for I := 0 to FItems.Count - 1 do
    if Perform(LB_ADDSTRING, 0, LongInt(StrPCopy(Buffer, FItems.FItems[I]))) < 0 then
      Fail('Cannot add list box item');
end;
procedure TCustomListBox.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
const
  Styles: array[TListBoxStyle] of DWORD = (0, LBS_OWNERDRAWFIXED, LBS_OWNERDRAWVARIABLE);
var I: Integer;
begin
  if (Parent = 0) or (Style and WS_CHILD = 0) then Fail('List box requires a child window');
  if FStyle = lbOwnerDrawVariable then Fail('Variable owner-draw list boxes are not provided yet');
  Style := (Style and not DWORD($FFFF or WS_TABSTOP)) or WS_VSCROLL or WS_HSCROLL or
    LBS_HASSTRINGS or LBS_NOTIFY or Styles[FStyle];
  if FSorted then Style := Style or LBS_SORT;
  if FMultiSelect then
    if FExtendedSelect then Style := Style or LBS_EXTENDEDSEL
    else Style := Style or LBS_MULTIPLESEL;
  if not FIntegralHeight then Style := Style or LBS_NOINTEGRALHEIGHT;
  if FColumns <> 0 then Style := Style or LBS_MULTICOLUMN;
  if FBorderStyle = bsSingle then Style := Style or WS_BORDER;
  if TabStop then Style := Style or WS_TABSTOP;
  inherited CreateHandle(Parent, '', Style, X, Y, Width, Height);
  try
    FontChanged(Self);
    if FStyle = lbOwnerDrawFixed then Perform(LB_SETITEMHEIGHT, 0, FItemHeight);
    LoadItems;
    SetColumnWidth;
    if FItemIndex >= FItems.Count then FItemIndex := -1;
    if FMultiSelect then
    begin
      for I := 0 to FItems.Count - 1 do
        if (I < FSelection.Size) and FSelection[I] then Perform(LB_SETSEL, 1, I);
      if FItemIndex >= 0 then Perform(LB_SETCARETINDEX, FItemIndex, 0);
    end
    else Perform(LB_SETCURSEL, FItemIndex, 0);
    Perform(LB_SETTOPINDEX, FTopIndex, 0);
  except DestroyHandle; raise; end;
end;
procedure TCustomListBox.RequireLiveStyle;
begin
  if Handle <> 0 then Fail('List box style cannot change after creation');
end;
procedure TCustomListBox.CheckIndex(Index: Integer);
begin
  if (Index < 0) or (Index >= FItems.Count) then Fail('List box index out of range');
end;
function TCustomListBox.GetItems: TStrings;
begin Result := FItems; end;
procedure TCustomListBox.SetItems(Value: TStrings);
begin FItems.Assign(Value); end;
function TCustomListBox.GetItemIndex: Integer;
begin
  if Handle <> 0 then
    if FMultiSelect then FItemIndex := Perform(LB_GETCARETINDEX, 0, 0)
    else FItemIndex := Perform(LB_GETCURSEL, 0, 0);
  if FItemIndex >= FItems.Count then FItemIndex := -1;
  Result := FItemIndex;
end;
procedure TCustomListBox.SetItemIndex(Value: Integer);
begin
  if (Value < -1) or (Value >= FItems.Count) then Fail('List box index out of range');
  FItemIndex := Value;
  if Handle = 0 then Exit;
  if FMultiSelect then Perform(LB_SETCARETINDEX, Value, 0)
  else Perform(LB_SETCURSEL, Value, 0);
end;
function TCustomListBox.GetTopIndex: Integer;
begin
  if Handle <> 0 then FTopIndex := Perform(LB_GETTOPINDEX, 0, 0);
  Result := FTopIndex;
end;
procedure TCustomListBox.SetTopIndex(Value: Integer);
begin
  if Value < 0 then Value := 0;
  FTopIndex := Value;
  if Handle <> 0 then Perform(LB_SETTOPINDEX, Value, 0);
end;
function TCustomListBox.GetSelCount: Integer;
var I: Integer;
begin
  if not FMultiSelect then
  begin
    { Delphi 1 asks USER, which answers LB_ERR for single-selection lists. }
    Result := LB_ERR; Exit;
  end;
  if Handle <> 0 then begin Result := Perform(LB_GETSELCOUNT, 0, 0); Exit; end;
  Result := 0;
  for I := 0 to FItems.Count - 1 do
    if (I < FSelection.Size) and FSelection[I] then Inc(Result);
end;
function TCustomListBox.GetSelected(Index: Integer): Boolean;
begin
  CheckIndex(Index);
  if Handle <> 0 then Result := Perform(LB_GETSEL, Index, 0) > 0
  else if FMultiSelect then Result := (Index < FSelection.Size) and FSelection[Index]
  else Result := Index = FItemIndex;
end;
procedure TCustomListBox.SetSelected(Index: Integer; Value: Boolean);
begin
  CheckIndex(Index);
  if FMultiSelect then
  begin
    FSelection[Index] := Value;
    if Handle <> 0 then Perform(LB_SETSEL, Ord(Value), Index);
  end
  else if Value then ItemIndex := Index
  else if ItemIndex = Index then ItemIndex := -1;
end;
function TCustomListBox.GetItemHeight: Integer;
var R: TRect;
begin
  Result := FItemHeight;
  if (FStyle = lbStandard) and (Handle <> 0) then
  begin
    Perform(LB_GETITEMRECT, 0, LongInt(@R));
    Result := R.Bottom - R.Top;
  end;
end;
procedure TCustomListBox.SetItemHeight(Value: Integer);
begin
  if (Value <= 0) or (Value > 255) then Fail('Invalid list box item height');
  FItemHeight := Value;
  if (Handle <> 0) and (FStyle = lbOwnerDrawFixed) then
  begin
    Perform(LB_SETITEMHEIGHT, 0, Value);
    Invalidate;
  end;
end;
procedure TCustomListBox.SetStyle(Value: TListBoxStyle);
begin
  if FStyle = Value then Exit;
  RequireLiveStyle; FStyle := Value;
end;
procedure TCustomListBox.SetBorderStyle(Value: TBorderStyle);
begin
  if FBorderStyle = Value then Exit;
  RequireLiveStyle; FBorderStyle := Value;
end;
procedure TCustomListBox.SetColumns(Value: Integer);
begin
  if Value < 0 then Fail('Invalid list box column count');
  if (FColumns = 0) <> (Value = 0) then RequireLiveStyle;
  FColumns := Value;
  SetColumnWidth;
end;
procedure TCustomListBox.SetMultiSelect(Value: Boolean);
begin
  if FMultiSelect = Value then Exit;
  RequireLiveStyle; FMultiSelect := Value; FSelection.Size := 0;
end;
procedure TCustomListBox.SetExtendedSelect(Value: Boolean);
begin
  if FExtendedSelect = Value then Exit;
  RequireLiveStyle; FExtendedSelect := Value;
end;
procedure TCustomListBox.SetIntegralHeight(Value: Boolean);
begin
  if FIntegralHeight = Value then Exit;
  RequireLiveStyle; FIntegralHeight := Value;
end;
procedure TCustomListBox.SetSorted(Value: Boolean);
var Selected: string; Index: Integer;
begin
  if FSorted = Value then Exit;
  Index := ItemIndex;
  if Index >= 0 then Selected := FItems[Index];
  FSorted := Value;
  FItems.FItems.Sorted := Value;
  if Handle <> 0 then
  begin
    { LBS_SORT is fixed at creation; the mirror decides the order instead. }
    Perform(LB_RESETCONTENT, 0, 0);
    LoadItems;
  end;
  if Index >= 0 then ItemIndex := FItems.IndexOf(Selected);
end;
procedure TCustomListBox.SetColumnWidth;
begin
  if (FColumns <> 0) and (Handle <> 0) then
    Perform(LB_SETCOLUMNWIDTH, (Width + FColumns - 3) div FColumns, 0);
end;
procedure TCustomListBox.WMSize(var M: TMessage);
begin
  inherited;
  SetColumnWidth;
end;
procedure TCustomListBox.Clear;
begin FItems.Clear; end;
function TCustomListBox.ItemRect(Index: Integer): TRect;
begin
  FillChar(Result, SizeOf(Result), 0);
  if Handle <> 0 then Perform(LB_GETITEMRECT, Index, LongInt(@Result));
end;
{ Inside methods the Controls[] property hides the unit name. }
function HitTest(const Area: TRect; const Position: TPoint): Boolean;
begin Result := Controls.PtInRect(Area, Position); end;
function TCustomListBox.ItemAtPos(Pos: TPoint; Existing: Boolean): Integer;
var Area, Item: TRect;
begin
  Area := ClientRect;
  if (Handle <> 0) and HitTest(Area, Pos) then
  begin
    Result := TopIndex;
    while Result < FItems.Count do
    begin
      Perform(LB_GETITEMRECT, Result, LongInt(@Item));
      if HitTest(Item, Pos) then Exit;
      Inc(Result);
    end;
    if not Existing then Exit;
  end;
  Result := -1;
end;
function TCustomListBox.ControlCommand(Code: Word): Boolean;
begin
  Result := True;
  case Code of
    LBN_SELCHANGE: Click;
    LBN_DBLCLK: DblClick;
    LBN_SETFOCUS: DoEnter;
    LBN_KILLFOCUS: DoExit;
  else Result := False;
  end;
end;
function TCustomListBox.ControlDrawItem(var Item: TDrawItemStruct): Boolean;
var State: TOwnerDrawState; Saved: SmallInt; Previous: HDC; TextColor: TColor;
begin
  Result := Item.CtlType = ODT_LISTBOX;
  if not Result or FDrawing then Exit;
  if Item.hDC = 0 then Fail('Missing list box draw DC');
  State := TOwnerDrawState(Byte(Lo(Item.itemState)));
  Saved := SaveDC(Item.hDC);
  if Saved = 0 then Fail('Cannot save list box DC');
  Previous := Canvas.Handle; FDrawing := True;
  try
    Canvas.Handle := Item.hDC;
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := Color;
    { The highlight colour is for this item only; keep the published Font. }
    Canvas.Font.OnChange := nil; TextColor := Canvas.Font.Color;
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
    finally Canvas.Font.Color := TextColor; Canvas.Font.OnChange := FontChanged; end;
  finally
    Canvas.Handle := Previous; FDrawing := False; RestoreDC(Item.hDC, Saved);
  end;
end;
procedure TCustomListBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  if Assigned(FOnDrawItem) then FOnDrawItem(Self, Index, Rect, State)
  else
  begin
    Canvas.FillRect(Rect);
    Canvas.TextOut(Rect.Left + 2, Rect.Top, FItems[Index]);
  end;
end;
procedure TCustomListBox.MeasureItem(Index: Integer; var Height: Integer);
begin
  if Assigned(FOnMeasureItem) then FOnMeasureItem(Self, Index, Height);
end;
procedure TCustomListBox.Click;
begin if Assigned(FOnClick) then FOnClick(Self); end;
procedure TCustomListBox.DblClick;
begin if Assigned(FOnDblClick) then FOnDblClick(Self); end;
function TCustomListBox.GetFont: TFont;
begin Result := Canvas.Font; end;
procedure TCustomListBox.SetFont(Value: TFont);
begin
  if Value = nil then Fail('List box font cannot be nil');
  Font.Assign(Value);
end;
procedure TCustomListBox.FontChanged(Sender: TObject);
var NativeFont: HFONT;
begin
  if Handle = 0 then Exit;
  try NativeFont := Font.Handle;
  except Perform(WM_SETFONT, GetStockObject(SYSTEM_FONT), 0); Invalidate; raise; end;
  Perform(WM_SETFONT, NativeFont, 0); Invalidate;
end;
end.
