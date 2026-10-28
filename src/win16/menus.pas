{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 Menus over USER menu handles. Handles are created on demand and
  rebuilt from the item tree when an item changes, so callers may customize a
  live handle (for example with ModifyMenu) until the next change. Menu hints
  and menu merging are not provided. }
unit Menus;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Menus unit requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Messages, native_input, native_window;
type
  EMenuError = class(Exception);
  TShortCut = Low(Word)..High(Word);
  TMenuBreak = (mbNone, mbBreak, mbBarBreak);
  TFindItemKind = (fkCommand, fkHandle, fkShortCut);
  TPopupAlignment = (paLeft, paRight, paCenter);
  TMenu = class;
  TMenuItem = class(TComponent)
  private
    FCaption: string;
    FHandle: HMENU;
    FChecked, FEnabled, FVisible: Boolean;
    FBreak: TMenuBreak;
    FGroupIndex: Byte;
    FCommand: Word;
    FShortCut: TShortCut;
    FShortCutText: string;
    FHelpContext: LongInt;
    FHint: string;
    FItems: TList;
    FParent: TMenuItem;
    FMenu: TMenu;
    FDestroying: Boolean;
    FOnClick: TNotifyEvent;
    function GetCount: Integer;
    function GetItem(Index: Integer): TMenuItem;
    function GetHandle: HMENU;
    function GetMenuIndex: Integer;
    procedure SetMenuIndex(Value: Integer);
    procedure SetCaption(const Value: string);
    procedure SetChecked(Value: Boolean);
    procedure SetEnabled(Value: Boolean);
    procedure SetVisible(Value: Boolean);
    procedure SetBreak(Value: TMenuBreak);
    procedure SetShortCut(Value: TShortCut);
    procedure SetShortCutText(const Value: string);
    procedure SetGroupIndex(Value: Byte);
    procedure ClearHandle;
    procedure PopulateMenu;
    procedure RebuildHandle;
    procedure MenuChanged;
    function AppendFlags: Word;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Insert(Index: Integer; Item: TMenuItem);
    procedure Add(Item: TMenuItem);
    procedure Delete(Index: Integer);
    procedure Remove(Item: TMenuItem);
    function IndexOf(Item: TMenuItem): Integer;
    procedure Click; virtual;
    property Command: Word read FCommand;
    property Handle: HMENU read GetHandle;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TMenuItem read GetItem; default;
    property MenuIndex: Integer read GetMenuIndex write SetMenuIndex;
    property Parent: TMenuItem read FParent;
  published
    property Break: TMenuBreak read FBreak write SetBreak default mbNone;
    property Caption: string read FCaption write SetCaption;
    property Checked: Boolean read FChecked write SetChecked default False;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property GroupIndex: Byte read FGroupIndex write SetGroupIndex default 0;
    property HelpContext: LongInt read FHelpContext write FHelpContext default 0;
    property Hint: string read FHint write FHint;
    property ShortCut: TShortCut read FShortCut write SetShortCut default 0;
    { Calmira's Menus: text shown after the caption for a key the program
      handles itself; it takes precedence over ShortCut's text and is not a
      shortcut. }
    property ShortCutText: string read FShortCutText write SetShortCutText;
    property Visible: Boolean read FVisible write SetVisible default True;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;
  TMenu = class(TComponent)
  private
    FItems: TMenuItem;
    FWindowHandle: HWND;
    function GetHandle: HMENU;
    procedure SetWindowHandle(Value: HWND);
  protected
    function MenuBar: Boolean; virtual;
    procedure MenuChanged; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DispatchCommand(ACommand: Word): Boolean;
    function DispatchPopup(AHandle: HMENU): Boolean;
    { Clicks the enabled item whose ShortCut matches the key message. }
    function IsShortCut(var Message: TWMKey): Boolean;
    function FindItem(Value: Word; Kind: TFindItemKind): TMenuItem;
    { The help context of the item with this command (or submenu handle), or
      of its nearest parent with one; a popup menu's own context is last. }
    function GetHelpContext(Value: Word; ByCommand: Boolean): LongInt;
    property Handle: HMENU read GetHandle;
    { The window that owns this menu bar; set by the form that shows it. }
    property WindowHandle: HWND read FWindowHandle write SetWindowHandle;
  published
    property Items: TMenuItem read FItems;
  end;
  TMainMenu = class(TMenu)
  protected
    function MenuBar: Boolean; override;
  end;
  TPopupMenu = class(TMenu)
  private
    FAlignment: TPopupAlignment;
    FAutoPopup: Boolean;
    FPopupComponent: TComponent;
    FOnPopup: TNotifyEvent;
    function GetPopupHelpContext: LongInt;
    procedure SetPopupHelpContext(Value: LongInt);
  protected
    procedure DoPopup(Sender: TObject); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Popup(X, Y: Integer); virtual;
    property PopupComponent: TComponent read FPopupComponent write FPopupComponent;
  published
    property Alignment: TPopupAlignment read FAlignment write FAlignment default paLeft;
    property AutoPopup: Boolean read FAutoPopup write FAutoPopup default True;
    { Stored on the root item, as in Delphi 1. }
    property HelpContext: LongInt read GetPopupHelpContext write SetPopupHelpContext default 0;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
  end;
const
  scShift = $2000;
  scCtrl = $4000;
  scAlt = $8000;
  scNone = 0;
function ShortCut(Key: Word; Shift: TShiftState): TShortCut;
procedure ShortCutToKey(ShortCut: TShortCut; var Key: Word; var Shift: TShiftState);
function ShortCutToText(ShortCut: TShortCut): string;
function TextToShortCut(Text: string): TShortCut;
function NewMenu(Owner: TComponent; const AName: string; Items: array of TMenuItem): TMainMenu;
function NewPopupMenu(Owner: TComponent; const AName: string;
  Alignment: TPopupAlignment; AutoPopup: Boolean; Items: array of TMenuItem): TPopupMenu;
function NewSubMenu(const ACaption: string; hCtx: Word; const AName: string;
  Items: array of TMenuItem): TMenuItem;
function NewItem(const ACaption: string; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
  AOnClick: TNotifyEvent; hCtx: Word; const AName: string): TMenuItem;
function NewLine: TMenuItem;
{ The hidden window that receives WM_COMMAND from TPopupMenu.Popup; 0 until used. }
function PopupListWindow: HWND;
implementation
uses WinProcs, Win31;
type
  TPopupList = class(TNativeWindow)
  private
    FMenus: TList;
  protected
    procedure WndProc(var Message: TMessage); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;
var
  CommandPool: TBits;
  PopupList: TPopupList;
function UniqueCommand: Word;
begin
  if CommandPool = nil then
  begin
    CommandPool := TBits.Create;
    CommandPool[0] := True; { 0 is not a menu command }
  end;
  Result := CommandPool.OpenBit;
  if Result >= $F000 then raise EMenuError.Create('Out of menu commands');
  CommandPool[Result] := True;
end;
function PopupListWindow: HWND;
begin
  if PopupList = nil then Result := 0 else Result := PopupList.Handle;
end;
{ TPopupList }
constructor TPopupList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMenus := TList.Create;
  CreateHandle(0, '', WS_POPUP, 0, 0, 0, 0);
end;
destructor TPopupList.Destroy;
begin
  DestroyHandle;
  FMenus.Free;
  inherited Destroy;
end;
procedure TPopupList.WndProc(var Message: TMessage);
var I: Integer;
begin
  case Message.Msg of
    WM_COMMAND:
      for I := FMenus.Count - 1 downto 0 do
        if TPopupMenu(FMenus[I]).DispatchCommand(Message.WParam) then Exit;
    WM_INITMENUPOPUP:
      for I := FMenus.Count - 1 downto 0 do
        if TPopupMenu(FMenus[I]).DispatchPopup(Message.WParam) then Exit;
  end;
  inherited WndProc(Message);
end;
{ TMenuItem }
constructor TMenuItem.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEnabled := True;
  FVisible := True;
  FCommand := UniqueCommand;
end;
destructor TMenuItem.Destroy;
begin
  FDestroying := True;
  if FParent <> nil then FParent.Remove(Self);
  { Detach submenus before they destroy their own handles. }
  ClearHandle;
  if FItems <> nil then
  begin
    while FItems.Count > 0 do TMenuItem(FItems.Last).Free;
    FItems.Free;
  end;
  if FHandle <> 0 then DestroyMenu(FHandle);
  if CommandPool <> nil then CommandPool[FCommand] := False;
  inherited Destroy;
end;
function TMenuItem.GetCount: Integer;
begin
  if FItems = nil then Result := 0 else Result := FItems.Count;
end;
function TMenuItem.GetItem(Index: Integer): TMenuItem;
begin
  if (FItems = nil) or (Index < 0) or (Index >= FItems.Count) then
    raise EMenuError.Create('Menu index out of range');
  Result := TMenuItem(FItems[Index]);
end;
function TMenuItem.GetHandle: HMENU;
begin
  if FHandle = 0 then
  begin
    if (FMenu <> nil) and FMenu.MenuBar then FHandle := CreateMenu
    else FHandle := CreatePopupMenu;
    if FHandle = 0 then raise EMenuError.Create('Cannot create menu');
    PopulateMenu;
  end;
  Result := FHandle;
end;
function TMenuItem.AppendFlags: Word;
const
  Breaks: array[TMenuBreak] of Word = (0, MF_MENUBREAK, MF_MENUBARBREAK);
  Checks: array[Boolean] of Word = (MF_UNCHECKED, MF_CHECKED);
  Enables: array[Boolean] of Word = (MF_GRAYED, MF_ENABLED);
begin
  Result := Breaks[FBreak] or Checks[FChecked] or Enables[FEnabled];
  if FCaption = '-' then Result := Result or MF_SEPARATOR
  else if Count > 0 then Result := Result or MF_POPUP
  else Result := Result or MF_STRING;
end;
procedure TMenuItem.PopulateMenu;
var I: Integer; Item: TMenuItem; Text: array[0..255] of Char; Caption: string;
begin
  for I := 0 to Count - 1 do
  begin
    Item := TMenuItem(FItems[I]);
    if not Item.FVisible then Continue;
    Caption := Item.FCaption;
    if Item.FShortCutText <> '' then Caption := Caption + #9 + Item.FShortCutText
    else if Item.FShortCut <> scNone then Caption := Caption + #9 + ShortCutToText(Item.FShortCut);
    StrPCopy(Text, Caption);
    if Item.FCaption = '-' then
      AppendMenu(FHandle, Item.AppendFlags, 0, nil)
    else if Item.Count > 0 then
      AppendMenu(FHandle, Item.AppendFlags, Item.Handle, Text)
    else
      AppendMenu(FHandle, Item.AppendFlags, Item.FCommand, Text);
  end;
end;
procedure TMenuItem.ClearHandle;
begin
  { RemoveMenu, unlike DeleteMenu, keeps submenu handles alive. }
  if FHandle <> 0 then
    while GetMenuItemCount(FHandle) > 0 do RemoveMenu(FHandle, 0, MF_BYPOSITION);
end;
procedure TMenuItem.RebuildHandle;
begin
  if FDestroying or (FHandle = 0) then Exit;
  ClearHandle;
  PopulateMenu;
  if (FParent = nil) and (FMenu <> nil) then FMenu.MenuChanged;
end;
procedure TMenuItem.MenuChanged;
begin
  if FParent <> nil then FParent.RebuildHandle
  else RebuildHandle;
end;
procedure TMenuItem.Insert(Index: Integer; Item: TMenuItem);
begin
  if Item.FParent <> nil then raise EMenuError.Create('Menu item is already inserted');
  if FItems = nil then FItems := TList.Create;
  if (Index < 0) or (Index > FItems.Count) then raise EMenuError.Create('Menu index out of range');
  FItems.Insert(Index, Item);
  Item.FParent := Self;
  RebuildHandle;
  { A former leaf gains a submenu: its parent must append it as MF_POPUP. }
  if (FItems.Count = 1) and (FParent <> nil) then FParent.RebuildHandle;
end;
procedure TMenuItem.Add(Item: TMenuItem);
begin
  Insert(Count, Item);
end;
procedure TMenuItem.Delete(Index: Integer);
var Item: TMenuItem;
begin
  Item := GetItem(Index);
  FItems.Delete(Index);
  Item.FParent := nil;
  RebuildHandle;
  if (FItems.Count = 0) and (FParent <> nil) then FParent.RebuildHandle;
end;
procedure TMenuItem.Remove(Item: TMenuItem);
var Index: Integer;
begin
  Index := IndexOf(Item);
  if Index < 0 then raise EMenuError.Create('Menu item not found');
  Delete(Index);
end;
function TMenuItem.IndexOf(Item: TMenuItem): Integer;
begin
  if FItems = nil then Result := -1 else Result := FItems.IndexOf(Item);
end;
function TMenuItem.GetMenuIndex: Integer;
begin
  if FParent = nil then Result := -1 else Result := FParent.IndexOf(Self);
end;
procedure TMenuItem.SetMenuIndex(Value: Integer);
var Parent: TMenuItem;
begin
  Parent := FParent;
  if Parent = nil then Exit;
  if Value < 0 then Value := 0;
  if Value >= Parent.Count then Value := Parent.Count - 1;
  if Value = MenuIndex then Exit;
  Parent.FItems.Move(MenuIndex, Value);
  Parent.RebuildHandle;
end;
procedure TMenuItem.Click;
begin
  if FEnabled and Assigned(FOnClick) then FOnClick(Self);
end;
procedure TMenuItem.SetCaption(const Value: string);
begin
  if FCaption = Value then Exit;
  FCaption := Value;
  MenuChanged;
end;
procedure TMenuItem.SetChecked(Value: Boolean);
const Checks: array[Boolean] of Word = (MF_UNCHECKED, MF_CHECKED);
begin
  if FChecked = Value then Exit;
  FChecked := Value;
  { Like Delphi 1, update in place so a customized live handle survives. }
  if Count > 0 then MenuChanged
  else if (FParent <> nil) and (FParent.FHandle <> 0) then
    CheckMenuItem(FParent.FHandle, FCommand, MF_BYCOMMAND or Checks[Value]);
end;
procedure TMenuItem.SetEnabled(Value: Boolean);
const Enables: array[Boolean] of Word = (MF_GRAYED, MF_ENABLED);
begin
  if FEnabled = Value then Exit;
  FEnabled := Value;
  if Count > 0 then MenuChanged
  else if (FParent <> nil) and (FParent.FHandle <> 0) then
  begin
    EnableMenuItem(FParent.FHandle, FCommand, MF_BYCOMMAND or Enables[Value]);
    if (FParent.FParent = nil) and (FParent.FMenu <> nil) then FParent.FMenu.MenuChanged;
  end;
end;
procedure TMenuItem.SetVisible(Value: Boolean);
begin
  if FVisible = Value then Exit;
  FVisible := Value;
  MenuChanged;
end;
procedure TMenuItem.SetBreak(Value: TMenuBreak);
begin
  if FBreak = Value then Exit;
  FBreak := Value;
  MenuChanged;
end;
procedure TMenuItem.SetShortCut(Value: TShortCut);
begin
  if FShortCut = Value then Exit;
  FShortCut := Value;
  MenuChanged;
end;
procedure TMenuItem.SetShortCutText(const Value: string);
begin
  if FShortCutText = Value then Exit;
  FShortCutText := Value;
  MenuChanged;
end;
procedure TMenuItem.SetGroupIndex(Value: Byte);
begin
  { Delphi 1 uses GroupIndex only to merge menus, which is not provided yet. }
  FGroupIndex := Value;
end;
{ TMenu }
constructor TMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TMenuItem.Create(nil);
  FItems.FMenu := Self;
end;
destructor TMenu.Destroy;
begin
  if FWindowHandle <> 0 then SetWindowHandle(0);
  FItems.Free;
  inherited Destroy;
end;
function TMenu.MenuBar: Boolean;
begin
  Result := False;
end;
procedure TMenu.MenuChanged;
begin
  if MenuBar and (FWindowHandle <> 0) then DrawMenuBar(FWindowHandle);
end;
function TMenu.GetHandle: HMENU;
begin
  Result := FItems.Handle;
end;
procedure TMenu.SetWindowHandle(Value: HWND);
begin
  if FWindowHandle = Value then Exit;
  { Detach first: DestroyWindow would otherwise destroy the menu handle. }
  if MenuBar and (FWindowHandle <> 0) and IsWindow(FWindowHandle) and
    (GetMenu(FWindowHandle) = FItems.FHandle) then SetMenu(FWindowHandle, 0);
  FWindowHandle := Value;
  if MenuBar and (Value <> 0) then SetMenu(Value, Handle);
end;
function FindIn(Item: TMenuItem; Value: Word; Kind: TFindItemKind): TMenuItem;
var I: Integer;
begin
  for I := 0 to Item.Count - 1 do
  begin
    Result := TMenuItem(Item.FItems[I]);
    case Kind of
      fkCommand: if Result.FCommand = Value then Exit;
      fkHandle: if (Result.FHandle <> 0) and (Result.FHandle = Value) then Exit;
      fkShortCut: if (Result.FShortCut <> scNone) and (Result.FShortCut = Value) then Exit;
    end;
    Result := FindIn(Result, Value, Kind);
    if Result <> nil then Exit;
  end;
  Result := nil;
end;
function TMenu.FindItem(Value: Word; Kind: TFindItemKind): TMenuItem;
begin
  Result := FindIn(FItems, Value, Kind);
end;
function TMenu.GetHelpContext(Value: Word; ByCommand: Boolean): LongInt;
var Item: TMenuItem;
begin
  if ByCommand then Item := FindItem(Value, fkCommand) else Item := FindItem(Value, fkHandle);
  if Item = nil then Item := FItems;
  while (Item <> nil) and (Item.FHelpContext = 0) do Item := Item.FParent;
  if Item = nil then Result := 0 else Result := Item.FHelpContext;
end;
function TMenu.DispatchCommand(ACommand: Word): Boolean;
var Item: TMenuItem;
begin
  Item := FindItem(ACommand, fkCommand);
  Result := Item <> nil;
  if Result then Item.Click;
end;
function TMenu.DispatchPopup(AHandle: HMENU): Boolean;
var Item: TMenuItem;
begin
  { Delphi 1 fires the submenu item's OnClick just before the submenu opens. }
  if AHandle = FItems.FHandle then begin Result := True; Exit; end;
  Item := FindItem(AHandle, fkHandle);
  Result := Item <> nil;
  if Result then Item.Click;
end;
function TMenu.IsShortCut(var Message: TWMKey): Boolean;
var Shift: TShiftState; Item, Parent: TMenuItem;
begin
  Result := False;
  Shift := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Shift, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Shift, ssCtrl);
  if Message.KeyData and $20000000 <> 0 then Include(Shift, ssAlt);
  Item := FindItem(ShortCut(Message.CharCode, Shift), fkShortCut);
  if Item = nil then Exit;
  Parent := Item;
  while Parent <> nil do
  begin
    if not Parent.Enabled then Exit;
    Parent := Parent.Parent;
  end;
  Item.Click;
  Result := True;
end;
{ TMainMenu }
function TMainMenu.MenuBar: Boolean;
begin
  Result := True;
end;
{ TPopupMenu }
constructor TPopupMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoPopup := True;
  if PopupList = nil then PopupList := TPopupList.Create(nil);
  PopupList.FMenus.Add(Self);
end;
destructor TPopupMenu.Destroy;
begin
  if PopupList <> nil then PopupList.FMenus.Remove(Self);
  inherited Destroy;
end;
function TPopupMenu.GetPopupHelpContext: LongInt;
begin Result := Items.FHelpContext; end;
procedure TPopupMenu.SetPopupHelpContext(Value: LongInt);
begin Items.FHelpContext := Value; end;
procedure TPopupMenu.DoPopup(Sender: TObject);
begin
  if Assigned(FOnPopup) then FOnPopup(Sender);
end;
procedure TPopupMenu.Popup(X, Y: Integer);
const Flags: array[TPopupAlignment] of Word = (TPM_LEFTALIGN, TPM_RIGHTALIGN, TPM_CENTERALIGN);
begin
  DoPopup(Self);
  TrackPopupMenu(Items.Handle, Flags[FAlignment] or TPM_RIGHTBUTTON, X, Y, 0,
    PopupList.Handle, nil);
end;
{ Shortcuts }
function ShortCut(Key: Word; Shift: TShiftState): TShortCut;
begin
  Result := 0;
  if WordRec(Key).Hi <> 0 then Exit;
  Result := Key;
  if ssShift in Shift then Inc(Result, scShift);
  if ssCtrl in Shift then Inc(Result, scCtrl);
  if ssAlt in Shift then Inc(Result, scAlt);
end;
procedure ShortCutToKey(ShortCut: TShortCut; var Key: Word; var Shift: TShiftState);
begin
  Key := ShortCut and $1FFF; { without scShift, scCtrl and scAlt }
  Shift := [];
  if ShortCut and scShift <> 0 then Include(Shift, ssShift);
  if ShortCut and scCtrl <> 0 then Include(Shift, ssCtrl);
  if ShortCut and scAlt <> 0 then Include(Shift, ssAlt);
end;
type
  TKeyName = record Key: Byte; Name: string[6]; end;
const
  KeyNames: array[0..14] of TKeyName = (
    (Key: VK_BACK; Name: 'BkSp'), (Key: VK_TAB; Name: 'Tab'), (Key: VK_RETURN; Name: 'Enter'),
    (Key: VK_ESCAPE; Name: 'Esc'), (Key: VK_SPACE; Name: 'Space'), (Key: VK_PRIOR; Name: 'PgUp'),
    (Key: VK_NEXT; Name: 'PgDn'), (Key: VK_END; Name: 'End'), (Key: VK_HOME; Name: 'Home'),
    (Key: VK_LEFT; Name: 'Left'), (Key: VK_UP; Name: 'Up'), (Key: VK_RIGHT; Name: 'Right'),
    (Key: VK_DOWN; Name: 'Down'), (Key: VK_INSERT; Name: 'Ins'), (Key: VK_DELETE; Name: 'Del'));
function KeyText(Key: Word): string;
var I: Integer;
begin
  case Key of
    Ord('0')..Ord('9'), Ord('A')..Ord('Z'): Result := Chr(Key);
    VK_F1..VK_F12: Result := 'F' + IntToStr(Key - VK_F1 + 1);
  else
    Result := '';
    for I := Low(KeyNames) to High(KeyNames) do
      if KeyNames[I].Key = Key then begin Result := KeyNames[I].Name; Exit; end;
  end;
end;
function ShortCutToText(ShortCut: TShortCut): string;
var Name: string;
begin
  Result := '';
  Name := KeyText(ShortCut and $FF);
  if Name = '' then Exit;
  if ShortCut and scShift <> 0 then Result := Result + 'Shift+';
  if ShortCut and scCtrl <> 0 then Result := Result + 'Ctrl+';
  if ShortCut and scAlt <> 0 then Result := Result + 'Alt+';
  Result := Result + Name;
end;
function TextToShortCut(Text: string): TShortCut;
  function Take(const Prefix: string): Boolean;
  begin
    Result := CompareText(Copy(Text, 1, Length(Prefix)), Prefix) = 0;
    if Result then System.Delete(Text, 1, Length(Prefix));
  end;
var Shift: Word; Key: Word;
begin
  Result := 0; Shift := 0;
  while True do
    if Take('Shift+') then Shift := Shift or scShift
    else if Take('Ctrl+') then Shift := Shift or scCtrl
    else if Take('Alt+') then Shift := Shift or scAlt
    else System.Break;
  if Text = '' then Exit;
  for Key := 1 to $FF do
    if CompareText(KeyText(Key), Text) = 0 then
    begin
      Result := Key or Shift;
      Exit;
    end;
end;
{ Construction helpers }
procedure AddItems(Parent: TMenuItem; const Items: array of TMenuItem);
var I: Integer;
begin
  for I := Low(Items) to High(Items) do Parent.Add(Items[I]);
end;
function NewMenu(Owner: TComponent; const AName: string; Items: array of TMenuItem): TMainMenu;
begin
  Result := TMainMenu.Create(Owner);
  Result.Name := AName;
  AddItems(Result.Items, Items);
end;
function NewPopupMenu(Owner: TComponent; const AName: string;
  Alignment: TPopupAlignment; AutoPopup: Boolean; Items: array of TMenuItem): TPopupMenu;
begin
  Result := TPopupMenu.Create(Owner);
  Result.Name := AName;
  Result.Alignment := Alignment;
  Result.AutoPopup := AutoPopup;
  AddItems(Result.Items, Items);
end;
function NewSubMenu(const ACaption: string; hCtx: Word; const AName: string;
  Items: array of TMenuItem): TMenuItem;
begin
  Result := TMenuItem.Create(nil);
  Result.Caption := ACaption;
  Result.HelpContext := hCtx;
  Result.Name := AName;
  AddItems(Result, Items);
end;
function NewItem(const ACaption: string; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
  AOnClick: TNotifyEvent; hCtx: Word; const AName: string): TMenuItem;
begin
  Result := TMenuItem.Create(nil);
  Result.Caption := ACaption;
  Result.ShortCut := AShortCut;
  Result.Checked := AChecked;
  Result.Enabled := AEnabled;
  Result.OnClick := AOnClick;
  Result.HelpContext := hCtx;
  Result.Name := AName;
end;
function NewLine: TMenuItem;
begin
  Result := NewItem('-', 0, False, True, nil, 0, '');
end;
initialization
finalization
  PopupList.Free;
  PopupList := nil;
  CommandPool.Free;
  CommandPool := nil;
end.
