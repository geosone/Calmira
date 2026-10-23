{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 Outline unit over the native TCustomGrid. Nodes are indexed 1..n
  in pre-order over all nodes, collapsed or not; grid rows show the visible
  ones. Not provided: the tree-line styles draw like the picture styles,
  there are no built-in default pictures (Delphi's come from a Borland
  resource), and streamed outline data must be empty. }
unit Outline;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Outline unit requires Win16}{$ENDIF}
interface
uses WinTypes, Messages, Classes, SysUtils, Graphics, Controls, StdCtrls, Grids;
type
  OutlineError = class(TObject);
  EOutlineError = class(Exception);
  TAttachMode = (oaAdd, oaAddChild, oaInsert);
  TChangeRange = -1..1;
  TCustomOutline = class;
  TOutlineNode = class(TPersistent)
  private
    FOutline: TCustomOutline;
    FParent: TOutlineNode;
    FList: TList;
    FText: string;
    FData: Pointer;
    FExpanded: Boolean;
    function GetChild(Index: LongInt): TOutlineNode;
    function GetCount: Integer;
    procedure SetExpanded(Value: Boolean);
    procedure SetText(const Value: string);
    function GetIndex: LongInt;
    function GetLevel: Cardinal;
    function GetHasItems: Boolean;
    function GetIsVisible: Boolean;
    function GetTopItem: LongInt;
    function GetFullPath: string;
    procedure Attach(Parent: TOutlineNode; Position: Integer);
    procedure Detach;
    function SiblingIndex(Value: LongInt): Integer;
  protected
    constructor Create(AOwner: TCustomOutline);
    function HasAsParent(Value: TOutlineNode): Boolean;
    property Outline: TCustomOutline read FOutline;
    property List: TList read FList;
    property Items[Index: LongInt]: TOutlineNode read GetChild; default;
  public
    destructor Destroy; override;
    procedure ChangeLevelBy(Value: TChangeRange);
    procedure Collapse;
    procedure Expand;
    procedure FullExpand;
    function GetDisplayWidth: Integer;
    { Indexes of children, or -1 (Delphi's InvalidIndex). }
    function GetFirstChild: LongInt;
    function GetLastChild: LongInt;
    function GetNextChild(Value: LongInt): LongInt;
    function GetPrevChild(Value: LongInt): LongInt;
    procedure MoveTo(Destination: LongInt; AttachMode: TAttachMode);
    property Parent: TOutlineNode read FParent;
    property Expanded: Boolean read FExpanded write SetExpanded;
    property Text: string read FText write SetText;
    property Data: Pointer read FData write FData;
    property Index: LongInt read GetIndex;
    property Level: Cardinal read GetLevel;
    property HasItems: Boolean read GetHasItems;
    property IsVisible: Boolean read GetIsVisible;
    property TopItem: LongInt read GetTopItem;
    property FullPath: string read GetFullPath;
  end;
  TBitmapArrayRange = 0..4;
  EOutlineChange = procedure(Sender: TObject; Index: LongInt) of object;
  TOutlineStyle = (osText, osPlusMinusText, osPictureText,
    osPlusMinusPictureText, osTreeText, osTreePictureText);
  TOutlineBitmap = (obPlus, obMinus, obOpen, obClose, obLeaf);
  TBitmapArray = array[TBitmapArrayRange] of TBitmap;
  TOutlineType = (otStandard, otOwnerDraw);
  TOutlineOption = (ooDrawTreeRoot, ooDrawFocusRect, ooStretchBitmaps);
  TOutlineOptions = set of TOutlineOption;
  TCustomOutline = class(TCustomGrid)
  private
    FRoot: TOutlineNode;
    FAll, FRows: TList;
    FIndexValid, FRowsValid: Boolean;
    FUpdateCount: Integer;
    FSelected: TOutlineNode;
    FLines: TStrings;
    FPictures: TBitmapArray;
    FOutlineStyle: TOutlineStyle;
    FOptions: TOutlineOptions;
    FStyle: TOutlineType;
    FItemSeparator: string;
    FOnExpand, FOnCollapse: EOutlineChange;
    FOnDrawItem: TDrawItemEvent;
    function GetNode(Index: LongInt): TOutlineNode;
    function GetItemCount: LongInt;
    function GetSelectedItem: LongInt;
    procedure SetSelectedItem(Value: LongInt);
    function GetItemHeight: Integer;
    procedure SetItemHeight(Value: Integer);
    procedure SetOutlineStyle(Value: TOutlineStyle);
    procedure SetOptions(Value: TOutlineOptions);
    procedure SetStyle(Value: TOutlineType);
    function GetPicture(Index: Integer): TBitmap;
    procedure SetPicture(Index: Integer; Value: TBitmap);
    procedure SetLines(Value: TStrings);
    function NodeOf(Index: LongInt): TOutlineNode;
    procedure BuildIndex;
    procedure BuildRows;
    function RowOf(Node: TOutlineNode): LongInt;
    function NodeAtRow(ARow: LongInt): TOutlineNode;
    function Indent(Node: TOutlineNode): Integer;
    function NodePicture(Node: TOutlineNode): TBitmap;
    function PlusMinusPicture(Node: TOutlineNode): TBitmap;
    function NewNode(Parent: TOutlineNode; Position: Integer; const Text: string; Data: Pointer): LongInt;
    procedure WMSize(var Msg: TMessage); message WM_SIZE;
  protected
    { Indexes and rows are stale; repaint once updating ends. }
    procedure StructureChanged;
    procedure Loaded; override;
    procedure DblClick; override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DrawCell(ACol, ARow: LongInt; ARect: TRect; AState: TGridDrawState); override;
    function SelectCell(ACol, ARow: LongInt): Boolean; override;
    procedure Expand(Index: LongInt); virtual;
    procedure Collapse(Index: LongInt); virtual;
    procedure Move(Destination, Source: LongInt; AttachMode: TAttachMode);
    property Lines: TStrings read FLines write SetLines;
    property OutlineStyle: TOutlineStyle read FOutlineStyle write SetOutlineStyle default osTreePictureText;
    property OnExpand: EOutlineChange read FOnExpand write FOnExpand;
    property OnCollapse: EOutlineChange read FOnCollapse write FOnCollapse;
    property Options: TOutlineOptions read FOptions write SetOptions default [ooDrawTreeRoot, ooDrawFocusRect];
    property Style: TOutlineType read FStyle write SetStyle default otStandard;
    property ItemHeight: Integer read GetItemHeight write SetItemHeight;
    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property ItemSeparator: string read FItemSeparator write FItemSeparator;
    property PicturePlus: TBitmap index 0 read GetPicture write SetPicture;
    property PictureMinus: TBitmap index 1 read GetPicture write SetPicture;
    property PictureOpen: TBitmap index 2 read GetPicture write SetPicture;
    property PictureClosed: TBitmap index 3 read GetPicture write SetPicture;
    property PictureLeaf: TBitmap index 4 read GetPicture write SetPicture;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Add(Index: LongInt; const Text: string): LongInt;
    function AddChild(Index: LongInt; const Text: string): LongInt;
    function AddChildObject(Index: LongInt; const Text: string; const Data: Pointer): LongInt;
    function AddObject(Index: LongInt; const Text: string; const Data: Pointer): LongInt;
    function Insert(Index: LongInt; const Text: string): LongInt;
    function InsertObject(Index: LongInt; const Text: string; const Data: Pointer): LongInt;
    procedure Delete(Index: LongInt);
    function GetDataItem(Value: Pointer): LongInt;
    function GetNodeDisplayWidth(Node: TOutlineNode): Integer;
    function GetTextItem(const Value: string): LongInt;
    { The node on the row at Y, clamped to the visible rows; 0 if empty. }
    function GetItem(X, Y: Integer): LongInt;
    procedure FullExpand;
    procedure FullCollapse;
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure SaveToStream(Stream: TStream);
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure SetUpdateState(Value: Boolean);
    procedure Clear;
    property ItemCount: LongInt read GetItemCount;
    property Items[Index: LongInt]: TOutlineNode read GetNode; default;
    property SelectedItem: LongInt read GetSelectedItem write SetSelectedItem;
    property Row;
    property Canvas;
  end;
  TOutline = class(TCustomOutline)
  published
    property Lines;
    property OutlineStyle;
    property OnExpand;
    property OnCollapse;
    property Options;
    property Style;
    property ItemHeight;
    property OnDrawItem;
    property Align;
    property Enabled;
    property Font;
    property Color;
    property ParentColor;
    property ParentCtl3D;
    property Ctl3D;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property DragMode;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnDblClick;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property BorderStyle;
    property ItemSeparator;
    property PicturePlus;
    property PictureMinus;
    property PictureOpen;
    property PictureClosed;
    property PictureLeaf;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property PopupMenu;
    property ScrollBars;
  end;
implementation
uses WinProcs;
const
  InvalidIndex = -1;
  PictureGap = 2;
type
  TOutlineStrings = class(TStrings)
  private
    FOutline: TCustomOutline;
  protected
    function Get(Index: Integer): AnsiString; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: AnsiString); override;
    procedure PutObject(Index: Integer; AObject: TObject); override;
  public
    function Add(const S: AnsiString): Integer; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: AnsiString); override;
  end;
procedure Fail(const Text: string);
begin raise EOutlineError.Create(Text); end;
{ TOutlineNode }
constructor TOutlineNode.Create(AOwner: TCustomOutline);
begin
  inherited Create;
  FOutline := AOwner;
end;
destructor TOutlineNode.Destroy;
var I: Integer;
begin
  if FList <> nil then
  begin
    for I := FList.Count - 1 downto 0 do TOutlineNode(FList[I]).Free;
    FList.Free;
  end;
  inherited Destroy;
end;
function TOutlineNode.GetChild(Index: LongInt): TOutlineNode;
begin Result := TOutlineNode(FList[Index]); end;
function TOutlineNode.GetCount: Integer;
begin if FList = nil then Result := 0 else Result := FList.Count; end;
procedure TOutlineNode.Attach(Parent: TOutlineNode; Position: Integer);
begin
  if Parent.FList = nil then Parent.FList := TList.Create;
  if (Position < 0) or (Position > Parent.FList.Count) then Position := Parent.FList.Count;
  Parent.FList.Insert(Position, Self);
  FParent := Parent;
  FOutline.StructureChanged;
end;
procedure TOutlineNode.Detach;
begin
  if FParent = nil then Exit;
  FParent.FList.Remove(Self);
  if FParent.FList.Count = 0 then begin FParent.FList.Free; FParent.FList := nil; end;
  FParent := nil;
  FOutline.StructureChanged;
end;
procedure TOutlineNode.SetExpanded(Value: Boolean);
begin
  if Value = FExpanded then Exit;
  FExpanded := Value;
  FOutline.StructureChanged;
  if Value then FOutline.Expand(Index) else FOutline.Collapse(Index);
end;
procedure TOutlineNode.SetText(const Value: string);
begin
  FText := Value;
  if IsVisible then FOutline.Invalidate;
end;
function TOutlineNode.GetIndex: LongInt;
begin
  FOutline.BuildIndex;
  Result := FOutline.FAll.IndexOf(Self);
end;
function TOutlineNode.GetLevel: Cardinal;
var Node: TOutlineNode;
begin
  Result := 0; Node := FParent;
  while Node <> nil do begin Inc(Result); Node := Node.FParent; end;
end;
function TOutlineNode.GetHasItems: Boolean;
begin Result := GetCount > 0; end;
function TOutlineNode.GetIsVisible: Boolean;
var Node: TOutlineNode;
begin
  Result := FParent <> nil; Node := FParent;
  while Result and (Node <> FOutline.FRoot) do
  begin
    Result := Node.FExpanded; Node := Node.FParent;
  end;
end;
function TOutlineNode.GetTopItem: LongInt;
var Node: TOutlineNode;
begin
  Node := Self;
  while (Node.FParent <> nil) and (Node.FParent <> FOutline.FRoot) do Node := Node.FParent;
  Result := Node.Index;
end;
function TOutlineNode.GetFullPath: string;
begin
  if (FParent = nil) or (FParent = FOutline.FRoot) then Result := FText
  else Result := FParent.FullPath + FOutline.FItemSeparator + FText;
end;
function TOutlineNode.HasAsParent(Value: TOutlineNode): Boolean;
var Node: TOutlineNode;
begin
  Result := False; Node := FParent;
  while (Node <> nil) and not Result do begin Result := Node = Value; Node := Node.FParent; end;
end;
procedure TOutlineNode.Collapse;
begin Expanded := False; end;
procedure TOutlineNode.Expand;
begin Expanded := True; end;
procedure TOutlineNode.FullExpand;
var I: Integer;
begin
  Expanded := True;
  { OnExpand may add children; walk the list as it is now. }
  I := 0;
  while I < GetCount do begin GetChild(I).FullExpand; Inc(I); end;
end;
function TOutlineNode.GetDisplayWidth: Integer;
begin Result := FOutline.GetNodeDisplayWidth(Self); end;
function TOutlineNode.SiblingIndex(Value: LongInt): Integer;
var Node: TOutlineNode;
begin
  Node := FOutline.NodeOf(Value);
  if Node.FParent <> Self then Fail('Outline index is not a child of this node');
  Result := FList.IndexOf(Node);
end;
function TOutlineNode.GetFirstChild: LongInt;
begin
  if GetCount = 0 then Result := InvalidIndex else Result := GetChild(0).Index;
end;
function TOutlineNode.GetLastChild: LongInt;
begin
  if GetCount = 0 then Result := InvalidIndex else Result := GetChild(GetCount - 1).Index;
end;
function TOutlineNode.GetNextChild(Value: LongInt): LongInt;
var I: Integer;
begin
  I := SiblingIndex(Value) + 1;
  if I >= GetCount then Result := InvalidIndex else Result := GetChild(I).Index;
end;
function TOutlineNode.GetPrevChild(Value: LongInt): LongInt;
var I: Integer;
begin
  I := SiblingIndex(Value) - 1;
  if I < 0 then Result := InvalidIndex else Result := GetChild(I).Index;
end;
procedure TOutlineNode.MoveTo(Destination: LongInt; AttachMode: TAttachMode);
var Target, NewParent: TOutlineNode; Position: Integer;
begin
  Target := FOutline.NodeOf(Destination);
  if (Target = Self) or Target.HasAsParent(Self) then Fail('Cannot move an outline item into itself');
  if (Target = FOutline.FRoot) and (AttachMode <> oaAddChild) then AttachMode := oaAddChild;
  Detach;
  case AttachMode of
    oaAddChild: begin NewParent := Target; Position := -1; end;
    oaInsert: begin NewParent := Target.FParent; Position := NewParent.FList.IndexOf(Target); end;
  else begin NewParent := Target.FParent; Position := -1; end;
  end;
  Attach(NewParent, Position);
end;
procedure TOutlineNode.ChangeLevelBy(Value: TChangeRange);
var Siblings: TList; Position: Integer; Target: TOutlineNode;
begin
  case Value of
    1:
      begin
        Siblings := FParent.FList; Position := Siblings.IndexOf(Self);
        if Position = 0 then Fail('Outline item has no previous sibling');
        Target := TOutlineNode(Siblings[Position - 1]);
        Detach; Attach(Target, -1);
      end;
    -1:
      begin
        if FParent = FOutline.FRoot then Fail('Outline item is already at the top level');
        Target := FParent;
        Detach; Attach(Target.FParent, Target.FParent.FList.IndexOf(Target) + 1);
      end;
  end;
end;
{ TOutlineStrings }
function TOutlineStrings.Get(Index: Integer): AnsiString;
var Node: TOutlineNode;
begin
  Node := FOutline.Items[Index + 1];
  Result := StringOfChar(#9, Node.Level - 1) + Node.Text;
end;
function TOutlineStrings.GetCount: Integer;
begin Result := FOutline.ItemCount; end;
function TOutlineStrings.GetObject(Index: Integer): TObject;
begin Result := TObject(FOutline.Items[Index + 1].Data); end;
procedure TOutlineStrings.Put(Index: Integer; const S: AnsiString);
begin FOutline.Items[Index + 1].Text := S; end;
procedure TOutlineStrings.PutObject(Index: Integer; AObject: TObject);
begin FOutline.Items[Index + 1].Data := AObject; end;
{ Leading tabs give the level; a line may go at most one level deeper than
  the line before it. }
function TOutlineStrings.Add(const S: AnsiString): Integer;
var Level: Integer; Parent: TOutlineNode;
begin
  Level := 0;
  while (Level < Length(S)) and (S[Level + 1] = #9) do Inc(Level);
  Parent := FOutline.FRoot;
  while (Level > 0) and Parent.HasItems do
  begin
    Parent := Parent.GetChild(Parent.GetCount - 1); Dec(Level);
  end;
  if Level > 0 then Fail('Outline line is indented too far');
  Result := FOutline.NewNode(Parent, -1, Copy(S, Length(S) - Length(TrimLeft(S)) + 1, 255), nil) - 1;
end;
procedure TOutlineStrings.Clear;
begin FOutline.Clear; end;
procedure TOutlineStrings.Delete(Index: Integer);
begin FOutline.Delete(Index + 1); end;
procedure TOutlineStrings.Insert(Index: Integer; const S: AnsiString);
begin
  if Index <> Count then Fail('Outline lines can only be added at the end');
  Add(S);
end;
{ TCustomOutline }
constructor TCustomOutline.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited Create(AOwner);
  FRoot := TOutlineNode.Create(Self);
  FRoot.FExpanded := True;
  FAll := TList.Create; FRows := TList.Create;
  FLines := TOutlineStrings.Create; TOutlineStrings(FLines).FOutline := Self;
  for I := Low(FPictures) to High(FPictures) do FPictures[I] := TBitmap.Create;
  FOutlineStyle := osTreePictureText;
  FOptions := [ooDrawTreeRoot, ooDrawFocusRect];
  FItemSeparator := '\';
  { As in Delphi 1: one column, no fixed cells, no grid lines. }
  inherited Options := [];
  FixedCols := 0; FixedRows := 0; ColCount := 1; RowCount := 1;
  DefaultRowHeight := 16;
end;
destructor TCustomOutline.Destroy;
var I: Integer;
begin
  inherited Destroy;
  FRoot.Free; FAll.Free; FRows.Free; FLines.Free;
  for I := Low(FPictures) to High(FPictures) do FPictures[I].Free;
end;
procedure TCustomOutline.StructureChanged;
begin
  FIndexValid := False; FRowsValid := False;
  if FUpdateCount = 0 then BuildRows;
end;
procedure TCustomOutline.BuildIndex;
  procedure Walk(Node: TOutlineNode);
  var I: Integer;
  begin
    FAll.Add(Node);
    for I := 0 to Node.GetCount - 1 do Walk(Node.GetChild(I));
  end;
begin
  if FIndexValid then Exit;
  FAll.Clear; Walk(FRoot); FIndexValid := True;
end;
procedure TCustomOutline.BuildRows;
  procedure Walk(Node: TOutlineNode);
  var I: Integer;
  begin
    for I := 0 to Node.GetCount - 1 do
    begin
      FRows.Add(Node.GetChild(I));
      if Node.GetChild(I).FExpanded then Walk(Node.GetChild(I));
    end;
  end;
var Selected: TOutlineNode; Target: LongInt;
begin
  Selected := FSelected;
  FRows.Clear; Walk(FRoot); FRowsValid := True;
  if FRows.Count > 0 then RowCount := FRows.Count else RowCount := 1;
  { The selection stays on its node, or moves to the nearest visible
    ancestor when the node is hidden or gone. }
  while (Selected <> nil) and (Selected <> FRoot) and not Selected.IsVisible do Selected := Selected.FParent;
  if Selected = FRoot then Selected := nil;
  Target := RowOf(Selected);
  if Target < 0 then
    if Row < FRows.Count then Target := Row else Target := FRows.Count - 1;
  if Target < 0 then Target := 0;
  if Target <> Row then MoveColRow(0, Target, True, False);
  FSelected := NodeAtRow(Row);
  Invalidate;
end;
function TCustomOutline.RowOf(Node: TOutlineNode): LongInt;
begin
  if not FRowsValid then BuildRows;
  if Node = nil then Result := -1 else Result := FRows.IndexOf(Node);
end;
function TCustomOutline.NodeAtRow(ARow: LongInt): TOutlineNode;
begin
  if (ARow >= 0) and (ARow < FRows.Count) then Result := TOutlineNode(FRows[ARow]) else Result := nil;
end;
function TCustomOutline.NodeOf(Index: LongInt): TOutlineNode;
begin
  BuildIndex;
  if (Index < 0) or (Index >= FAll.Count) then
    raise EOutlineError.CreateFmt('Invalid outline index %d', [Index]);
  Result := TOutlineNode(FAll[Index]);
end;
function TCustomOutline.GetNode(Index: LongInt): TOutlineNode;
begin
  if Index = 0 then raise EOutlineError.Create('Invalid outline index 0');
  Result := NodeOf(Index);
end;
function TCustomOutline.GetItemCount: LongInt;
begin BuildIndex; Result := FAll.Count - 1; end;
function TCustomOutline.NewNode(Parent: TOutlineNode; Position: Integer; const Text: string;
  Data: Pointer): LongInt;
var Node: TOutlineNode;
begin
  Node := TOutlineNode.Create(Self);
  Node.FText := Text; Node.FData := Data;
  Node.Attach(Parent, Position);
  Result := Node.Index;
end;
function TCustomOutline.AddObject(Index: LongInt; const Text: string; const Data: Pointer): LongInt;
var Node: TOutlineNode;
begin
  Node := NodeOf(Index);
  if Node <> FRoot then Node := Node.FParent;
  Result := NewNode(Node, -1, Text, Data);
end;
function TCustomOutline.AddChildObject(Index: LongInt; const Text: string; const Data: Pointer): LongInt;
begin Result := NewNode(NodeOf(Index), -1, Text, Data); end;
function TCustomOutline.InsertObject(Index: LongInt; const Text: string; const Data: Pointer): LongInt;
var Node: TOutlineNode;
begin
  Node := NodeOf(Index);
  if Node = FRoot then Result := NewNode(FRoot, -1, Text, Data)
  else Result := NewNode(Node.FParent, Node.FParent.FList.IndexOf(Node), Text, Data);
end;
function TCustomOutline.Add(Index: LongInt; const Text: string): LongInt;
begin Result := AddObject(Index, Text, nil); end;
function TCustomOutline.AddChild(Index: LongInt; const Text: string): LongInt;
begin Result := AddChildObject(Index, Text, nil); end;
function TCustomOutline.Insert(Index: LongInt; const Text: string): LongInt;
begin Result := InsertObject(Index, Text, nil); end;
procedure TCustomOutline.Delete(Index: LongInt);
var Node: TOutlineNode;
begin
  Node := Items[Index];
  { The row stays; BuildRows selects whatever is now on it. }
  if (FSelected = Node) or ((FSelected <> nil) and FSelected.HasAsParent(Node)) then FSelected := nil;
  Node.Detach;
  Node.Free;
end;
procedure TCustomOutline.Clear;
begin
  BeginUpdate;
  try
    while FRoot.HasItems do Delete(1);
  finally EndUpdate; end;
end;
procedure TCustomOutline.Move(Destination, Source: LongInt; AttachMode: TAttachMode);
begin Items[Source].MoveTo(Destination, AttachMode); end;
function TCustomOutline.GetDataItem(Value: Pointer): LongInt;
begin
  BuildIndex;
  for Result := 1 to FAll.Count - 1 do
    if TOutlineNode(FAll[Result]).FData = Value then Exit;
  Result := 0;
end;
function TCustomOutline.GetTextItem(const Value: string): LongInt;
begin
  BuildIndex;
  for Result := 1 to FAll.Count - 1 do
    if TOutlineNode(FAll[Result]).FText = Value then Exit;
  Result := 0;
end;
function TCustomOutline.GetItem(X, Y: Integer): LongInt;
var ARow: LongInt;
begin
  if not FRowsValid then BuildRows;
  Result := 0;
  if FRows.Count = 0 then Exit;
  if Y < 0 then Y := 0;
  ARow := TopRow + Y div DefaultRowHeight;
  if ARow >= FRows.Count then ARow := FRows.Count - 1;
  Result := NodeAtRow(ARow).Index;
end;
function TCustomOutline.GetSelectedItem: LongInt;
begin
  if not FRowsValid then BuildRows;
  if FSelected = nil then Result := 0 else Result := FSelected.Index;
end;
procedure TCustomOutline.SetSelectedItem(Value: LongInt);
var Node: TOutlineNode;
begin
  if Value = 0 then Exit;
  Node := Items[Value];
  while not Node.IsVisible do Node := Node.FParent;
  Row := RowOf(Node);
end;
function TCustomOutline.SelectCell(ACol, ARow: LongInt): Boolean;
begin
  Result := inherited SelectCell(ACol, ARow);
  if Result and FRowsValid then FSelected := NodeAtRow(ARow);
end;
procedure TCustomOutline.FullExpand;
var I: Integer;
begin
  BeginUpdate;
  try
    I := 0;
    while I < FRoot.GetCount do begin FRoot.GetChild(I).FullExpand; Inc(I); end;
  finally EndUpdate; end;
end;
procedure TCustomOutline.FullCollapse;
var I: LongInt;
begin
  BeginUpdate;
  try
    BuildIndex;
    for I := FAll.Count - 1 downto 1 do TOutlineNode(FAll[I]).Collapse;
  finally EndUpdate; end;
end;
procedure TCustomOutline.BeginUpdate;
begin Inc(FUpdateCount); end;
procedure TCustomOutline.EndUpdate;
begin
  if FUpdateCount = 0 then Exit;
  Dec(FUpdateCount);
  if FUpdateCount = 0 then BuildRows;
end;
procedure TCustomOutline.SetUpdateState(Value: Boolean);
begin if Value then BeginUpdate else EndUpdate; end;
procedure TCustomOutline.LoadFromFile(const FileName: string);
begin FLines.LoadFromFile(FileName); end;
procedure TCustomOutline.LoadFromStream(Stream: TStream);
begin
  BeginUpdate;
  try FLines.LoadFromStream(Stream);
  finally EndUpdate; end;
end;
procedure TCustomOutline.SaveToFile(const FileName: string);
begin FLines.SaveToFile(FileName); end;
procedure TCustomOutline.SaveToStream(Stream: TStream);
begin FLines.SaveToStream(Stream); end;
procedure TCustomOutline.SetLines(Value: TStrings);
begin
  BeginUpdate;
  try FLines.Assign(Value);
  finally EndUpdate; end;
end;
procedure TCustomOutline.Expand(Index: LongInt);
begin if Assigned(FOnExpand) then FOnExpand(Self, Index); end;
procedure TCustomOutline.Collapse(Index: LongInt);
begin if Assigned(FOnCollapse) then FOnCollapse(Self, Index); end;
function TCustomOutline.GetItemHeight: Integer;
begin Result := DefaultRowHeight; end;
procedure TCustomOutline.SetItemHeight(Value: Integer);
begin DefaultRowHeight := Value; end;
procedure TCustomOutline.SetOutlineStyle(Value: TOutlineStyle);
begin
  if Value = FOutlineStyle then Exit;
  FOutlineStyle := Value; Invalidate;
end;
procedure TCustomOutline.SetOptions(Value: TOutlineOptions);
begin
  if Value = FOptions then Exit;
  FOptions := Value; Invalidate;
end;
procedure TCustomOutline.SetStyle(Value: TOutlineType);
begin
  if Value = FStyle then Exit;
  FStyle := Value; Invalidate;
end;
function TCustomOutline.GetPicture(Index: Integer): TBitmap;
begin Result := FPictures[Index]; end;
procedure TCustomOutline.SetPicture(Index: Integer; Value: TBitmap);
begin FPictures[Index].Assign(Value); Invalidate; end;
procedure TCustomOutline.Loaded;
begin
  inherited Loaded;
  StructureChanged;
end;
procedure TCustomOutline.WMSize(var Msg: TMessage);
begin
  inherited;
  if ClientWidth > 0 then DefaultColWidth := ClientWidth;
end;
function TCustomOutline.PlusMinusPicture(Node: TOutlineNode): TBitmap;
begin
  Result := nil;
  if not (FOutlineStyle in [osPlusMinusText, osPlusMinusPictureText, osTreeText, osTreePictureText]) or
    not Node.HasItems then Exit;
  if Node.FExpanded then Result := FPictures[1] else Result := FPictures[0];
  if Result.Empty then Result := nil;
end;
function TCustomOutline.NodePicture(Node: TOutlineNode): TBitmap;
begin
  Result := nil;
  if not (FOutlineStyle in [osPictureText, osPlusMinusPictureText, osTreePictureText]) then Exit;
  if not Node.HasItems then Result := FPictures[4]
  else if Node.FExpanded then Result := FPictures[2]
  else Result := FPictures[3];
  if Result.Empty then Result := nil;
end;
function TCustomOutline.Indent(Node: TOutlineNode): Integer;
begin Result := (Integer(Node.Level) - 1) * DefaultRowHeight + PictureGap; end;
function TCustomOutline.GetNodeDisplayWidth(Node: TOutlineNode): Integer;
var Picture: TBitmap;
begin
  Result := Indent(Node);
  Picture := PlusMinusPicture(Node);
  if Picture <> nil then Inc(Result, Picture.Width + PictureGap);
  Picture := NodePicture(Node);
  if Picture <> nil then Inc(Result, Picture.Width + PictureGap);
  Canvas.Font := Font;
  Inc(Result, Canvas.TextWidth(Node.FText) + PictureGap);
end;
procedure TCustomOutline.DrawCell(ACol, ARow: LongInt; ARect: TRect; AState: TGridDrawState);
var Node: TOutlineNode; State: TOwnerDrawState; X: Integer; Picture: TBitmap;
  procedure DrawPicture;
  begin
    if Picture = nil then Exit;
    Canvas.Draw(X, (ARect.Top + ARect.Bottom - Picture.Height) div 2, Picture);
    Inc(X, Picture.Width + PictureGap);
  end;
begin
  if not FRowsValid then BuildRows;
  if FStyle = otOwnerDraw then
  begin
    { As in Delphi, Index is the grid row, not the item index. }
    State := [];
    if gdSelected in AState then Include(State, odSelected);
    if gdFocused in AState then Include(State, odFocused);
    if Assigned(FOnDrawItem) then FOnDrawItem(Self, ARow, ARect, State);
    Exit;
  end;
  Canvas.Font := Font;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ARect);
  Node := NodeAtRow(ARow);
  if Node = nil then Exit;
  X := ARect.Left + Indent(Node);
  Picture := PlusMinusPicture(Node); DrawPicture;
  Picture := NodePicture(Node); DrawPicture;
  if gdSelected in AState then
  begin
    Canvas.Brush.Color := clHighlight; Canvas.Font.Color := clHighlightText;
  end;
  ARect.Left := X;
  ARect.Right := X + Canvas.TextWidth(Node.FText) + PictureGap;
  Canvas.TextRect(ARect, X + 1, ARect.Top + (ARect.Bottom - ARect.Top - Canvas.TextHeight('X')) div 2, Node.FText);
  if (gdFocused in AState) and (ooDrawFocusRect in FOptions) then Canvas.DrawFocusRect(ARect);
end;
procedure TCustomOutline.DblClick;
var Node: TOutlineNode;
begin
  Node := FSelected;
  if Node <> nil then Node.Expanded := not Node.Expanded;
  inherited DblClick;
end;
procedure TCustomOutline.KeyPress(var Key: Char);
var Node: TOutlineNode;
begin
  inherited KeyPress(Key);
  Node := FSelected;
  if Node = nil then Exit;
  case Key of
    '+': Node.Expand;
    '-': Node.Collapse;
    '*': begin BeginUpdate; try Node.FullExpand; finally EndUpdate; end; end;
  else Exit;
  end;
  Key := #0;
end;
procedure TCustomOutline.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var Node: TOutlineNode; Picture: TBitmap; Left: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or (FStyle = otOwnerDraw) then Exit;
  Node := NodeAtRow(MouseCoord(X, Y).Y);
  if Node = nil then Exit;
  Picture := PlusMinusPicture(Node);
  if Picture = nil then Exit;
  Left := CellRect(0, MouseCoord(X, Y).Y).Left + Indent(Node);
  if (X >= Left) and (X < Left + Picture.Width) then Node.Expanded := not Node.Expanded;
end;
end.
