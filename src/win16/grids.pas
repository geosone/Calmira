{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 Grids: TCustomGrid, TDrawGrid and TStringGrid. Layout, painting,
  selection, keyboard and mouse navigation and scrolling follow Delphi.
  The in-place editor and moving or resizing rows and columns with the mouse
  are not provided: their options raise, and their properties and events
  are absent. }
unit Grids;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Grids unit requires Win16}{$ENDIF}
interface
uses SysUtils, Classes, WinTypes, Messages, Graphics, Controls, StdCtrls, control_base;
const
  MaxCustomExtents = 65520 div SizeOf(Integer);
type
  EInvalidGridOperation = class(Exception);
  TGridOption = (goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
    goRangeSelect, goDrawFocusSelected, goRowSizing, goColSizing, goRowMoving,
    goColMoving, goEditing, goTabs, goRowSelect,
    goAlwaysShowEditor, goThumbTracking);
  TGridOptions = set of TGridOption;
  TGridDrawState = set of (gdSelected, gdFocused, gdFixed);
  TGridScrollDirection = set of (sdLeft, sdRight, sdUp, sdDown);
  TGridCoord = record
    X: Longint;
    Y: Longint;
  end;
  TGridRect = record
    case Integer of
      0: (Left, Top, Right, Bottom: Longint);
      1: (TopLeft, BottomRight: TGridCoord);
  end;
  TSelectCellEvent = procedure(Sender: TObject; Col, Row: Longint;
    var CanSelect: Boolean) of object;
  TDrawCellEvent = procedure(Sender: TObject; Col, Row: Longint;
    Rect: TRect; State: TGridDrawState) of object;
  PGridExtents = ^TGridExtents;
  TGridExtents = array[0..MaxCustomExtents - 1] of Integer;
  { One axis of the visible layout, as in Delphi's TGridAxisDrawInfo. }
  TGridAxisDrawInfo = record
    EffectiveLineWidth: Integer;
    FixedBoundary, GridBoundary, GridExtent, FullVisBoundary: Longint;
    LastFullVisibleCell, FixedCellCount, FirstGridCell, GridCellCount: Longint;
    Columns: Boolean;
  end;
  TGridDrawInfo = record
    Horz, Vert: TGridAxisDrawInfo;
  end;
  TGridState = (gsNormal, gsSelecting);

  TCustomGrid = class(TCustomControl)
  private
    FAnchor, FCurrent, FTopLeft: TGridCoord;
    FBorderStyle: TBorderStyle;
    FColCount, FRowCount: Longint;
    FColWidths, FRowHeights: PGridExtents;
    FDefaultColWidth, FDefaultRowHeight: Integer;
    FDefaultDrawing: Boolean;
    FFixedColor: TColor;
    FFixedCols, FFixedRows: Integer;
    FGridLineWidth: Integer;
    FOptions: TGridOptions;
    FScrollBars: TScrollStyle;
    FGridState: TGridState;
    FOnClick, FOnDblClick: TNotifyEvent;
    function Extent(const Axis: TGridAxisDrawInfo; Index: Longint): Integer;
    procedure CalcDrawInfo(var DrawInfo: TGridDrawInfo);
    procedure CalcDrawInfoXY(var DrawInfo: TGridDrawInfo; UseWidth, UseHeight: Integer);
    procedure CalcFixedInfo(var DrawInfo: TGridDrawInfo);
    function CalcCoordFromPoint(X, Y: Integer; const DrawInfo: TGridDrawInfo): TGridCoord;
    function CalcMaxTopLeft(const Coord: TGridCoord; const DrawInfo: TGridDrawInfo): TGridCoord;
    procedure GridRectToScreenRect(GridRect: TGridRect; var ScreenRect: TRect; IncludeLine: Boolean);
    procedure ChangeSize(NewColCount, NewRowCount: Longint);
    procedure ClampInView(const Coord: TGridCoord);
    procedure FocusCell(ACol, ARow: Longint; MoveAnchor: Boolean);
    procedure Initialize;
    procedure InvalidateGridRect(const ARect: TGridRect);
    procedure ModifyScrollBar(ScrollBar, ScrollCode, Pos: Word);
    procedure MoveAnchor(const NewAnchor: TGridCoord);
    procedure MoveCurrent(ACol, ARow: Longint; MoveAnchor, Show: Boolean);
    procedure MoveTopLeft(ALeft, ATop: Longint);
    procedure ResizeExtents(var Extents: PGridExtents; OldCount, NewCount: Longint; Default: Integer);
    procedure SelectionMoved(const OldSel: TGridRect);
    procedure TopLeftMoved(const OldTopLeft: TGridCoord);
    procedure UpdateScrollPos;
    procedure UpdateScrollRange;
    function GetColWidths(Index: Longint): Integer;
    function GetRowHeights(Index: Longint): Integer;
    function GetSelection: TGridRect;
    function GetVisibleColCount: Integer;
    function GetVisibleRowCount: Integer;
    procedure SetBorderStyle(Value: TBorderStyle);
    procedure SetCol(Value: Longint);
    procedure SetColCount(Value: Longint);
    procedure SetColWidths(Index: Longint; Value: Integer);
    procedure SetDefaultColWidth(Value: Integer);
    procedure SetDefaultDrawing(Value: Boolean);
    procedure SetDefaultRowHeight(Value: Integer);
    procedure SetFixedColor(Value: TColor);
    procedure SetFixedCols(Value: Integer);
    procedure SetFixedRows(Value: Integer);
    procedure SetGridLineWidth(Value: Integer);
    procedure SetLeftCol(Value: Longint);
    procedure SetOptions(Value: TGridOptions);
    procedure SetRow(Value: Longint);
    procedure SetRowCount(Value: Longint);
    procedure SetRowHeights(Index: Longint; Value: Integer);
    procedure SetScrollBars(Value: TScrollStyle);
    procedure SetSelection(Value: TGridRect);
    procedure SetTopRow(Value: Longint);
    procedure WMGetDlgCode(var Msg: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMHScroll(var Msg: TMessage); message WM_HSCROLL;
    procedure WMVScroll(var Msg: TMessage); message WM_VSCROLL;
    procedure WMSize(var Msg: TMessage); message WM_SIZE;
    procedure WMTimer(var Msg: TMessage); message WM_TIMER;
  protected
    FSaveCellExtents: Boolean;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure Click; virtual;
    procedure DblClick; virtual;
    function BoxRect(ALeft, ATop, ARight, ABottom: Longint): TRect;
    function CellRect(ACol, ARow: Longint): TRect;
    function CanGridAcceptKey(Key: Word; Shift: TShiftState): Boolean; virtual;
    function GetGridWidth: Integer;
    function GetGridHeight: Integer;
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect;
      AState: TGridDrawState); virtual; abstract;
    function MouseCoord(X, Y: Integer): TGridCoord;
    procedure MoveColRow(ACol, ARow: Longint; MoveAnchor, Show: Boolean);
    function SelectCell(ACol, ARow: Longint): Boolean; virtual;
    procedure SizeChanged(OldColCount, OldRowCount: Longint); virtual;
    procedure ScrollData(DX, DY: Integer);
    procedure InvalidateCell(ACol, ARow: Longint);
    procedure InvalidateRow(ARow: Longint);
    procedure TopLeftChanged; virtual;
    procedure TimedScroll(Direction: TGridScrollDirection); virtual;
    procedure Paint; override;
    procedure ColWidthsChanged; virtual;
    procedure RowHeightsChanged; virtual;
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property Col: Longint read FCurrent.X write SetCol;
    property ColCount: Longint read FColCount write SetColCount default 5;
    property ColWidths[Index: Longint]: Integer read GetColWidths write SetColWidths;
    property DefaultColWidth: Integer read FDefaultColWidth write SetDefaultColWidth default 64;
    property DefaultDrawing: Boolean read FDefaultDrawing write SetDefaultDrawing default True;
    property DefaultRowHeight: Integer read FDefaultRowHeight write SetDefaultRowHeight default 24;
    property FixedColor: TColor read FFixedColor write SetFixedColor default clBtnFace;
    property FixedCols: Integer read FFixedCols write SetFixedCols default 1;
    property FixedRows: Integer read FFixedRows write SetFixedRows default 1;
    property GridHeight: Integer read GetGridHeight;
    property GridLineWidth: Integer read FGridLineWidth write SetGridLineWidth default 1;
    property GridWidth: Integer read GetGridWidth;
    property LeftCol: Longint read FTopLeft.X write SetLeftCol;
    property Options: TGridOptions read FOptions write SetOptions
      default [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect];
    property Row: Longint read FCurrent.Y write SetRow;
    property RowCount: Longint read FRowCount write SetRowCount default 5;
    property RowHeights[Index: Longint]: Integer read GetRowHeights write SetRowHeights;
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars default ssBoth;
    property Selection: TGridRect read GetSelection write SetSelection;
    property TopRow: Longint read FTopLeft.Y write SetTopRow;
    property VisibleColCount: Integer read GetVisibleColCount;
    property VisibleRowCount: Integer read GetVisibleRowCount;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    property Color default clWindow;
    property ParentColor default False;
  published
    property TabStop default True;
  end;

  TDrawGrid = class(TCustomGrid)
  private
    FOnDrawCell: TDrawCellEvent;
    FOnSelectCell: TSelectCellEvent;
    FOnTopLeftChanged: TNotifyEvent;
  protected
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect;
      AState: TGridDrawState); override;
    function SelectCell(ACol, ARow: Longint): Boolean; override;
    procedure TopLeftChanged; override;
  public
    function CellRect(ACol, ARow: Longint): TRect;
    procedure MouseToCell(X, Y: Integer; var ACol, ARow: Longint);
    property Canvas;
    property Col;
    property ColWidths;
    property GridHeight;
    property GridWidth;
    property LeftCol;
    property Selection;
    property Row;
    property RowHeights;
    property TopRow;
  published
    property Align;
    property BorderStyle;
    property Color;
    property ColCount;
    property Ctl3D;
    property DefaultColWidth;
    property DefaultRowHeight;
    property DefaultDrawing;
    property DragCursor;
    property DragMode;
    property Enabled;
    property FixedColor;
    property FixedCols;
    property FixedRows;
    property Font;
    property GridLineWidth;
    property Options;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property RowCount;
    property ScrollBars;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property VisibleColCount;
    property VisibleRowCount;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawCell: TDrawCellEvent read FOnDrawCell write FOnDrawCell;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnSelectCell: TSelectCellEvent read FOnSelectCell write FOnSelectCell;
    property OnTopLeftChanged: TNotifyEvent read FOnTopLeftChanged write FOnTopLeftChanged;
  end;

  TStringGrid = class(TDrawGrid)
  private
    { One TStringList per row, ColCount entries each, created on demand. }
    FData: TList;
    FCols, FRows: TList;
    function RowData(ARow: Integer; Create: Boolean): TStringList;
    function GetCells(ACol, ARow: Integer): string;
    procedure SetCells(ACol, ARow: Integer; const Value: string);
    function GetObjects(ACol, ARow: Integer): TObject;
    procedure SetObjects(ACol, ARow: Integer; Value: TObject);
    function GetCols(Index: Integer): TStrings;
    procedure SetCols(Index: Integer; Value: TStrings);
    function GetRows(Index: Integer): TStrings;
    procedure SetRows(Index: Integer; Value: TStrings);
    function LineStrings(List: TList; Index: Integer; IsCol: Boolean): TStrings;
  protected
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect;
      AState: TGridDrawState); override;
    procedure SizeChanged(OldColCount, OldRowCount: Longint); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Cells[ACol, ARow: Integer]: string read GetCells write SetCells;
    property Cols[Index: Integer]: TStrings read GetCols write SetCols;
    property Objects[ACol, ARow: Integer]: TObject read GetObjects write SetObjects;
    property Rows[Index: Integer]: TStrings read GetRows write SetRows;
  end;

implementation
uses WinProcs;
const
  { Delphi scales scroll positions to 0..127 so Longint counts fit. }
  ScrollMax = 127;
  SelectTimer = 1;
  UnsupportedOptions = [goRowSizing, goColSizing, goRowMoving, goColMoving,
    goEditing, goTabs, goAlwaysShowEditor];

procedure InvalidOp(const Text: string);
begin raise EInvalidGridOperation.Create(Text); end;
function GridRect(const A, B: TGridCoord): TGridRect;
begin
  if A.X < B.X then begin Result.Left := A.X; Result.Right := B.X; end
  else begin Result.Left := B.X; Result.Right := A.X; end;
  if A.Y < B.Y then begin Result.Top := A.Y; Result.Bottom := B.Y; end
  else begin Result.Top := B.Y; Result.Bottom := A.Y; end;
end;
function PointInGridRect(Col, Row: Longint; const Rect: TGridRect): Boolean;
begin
  Result := (Col >= Rect.Left) and (Col <= Rect.Right) and (Row >= Rect.Top) and
    (Row <= Rect.Bottom);
end;
function ScaleLong(Value, Numerator, Denominator: Longint): Longint;
begin
  if Denominator = 0 then Result := 0
  else Result := Value * Numerator div Denominator;
end;

{ TCustomGrid }

constructor TCustomGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FColCount := 5; FRowCount := 5;
  FFixedCols := 1; FFixedRows := 1;
  FGridLineWidth := 1;
  FOptions := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect];
  FDefaultColWidth := 64; FDefaultRowHeight := 24;
  FDefaultDrawing := True;
  FFixedColor := clBtnFace;
  FScrollBars := ssBoth;
  FBorderStyle := bsSingle;
  Color := clWindow;
  TabStop := True;
  SetBounds(Left, Top, FColCount * FDefaultColWidth, FRowCount * FDefaultRowHeight);
  Initialize;
end;
destructor TCustomGrid.Destroy;
begin
  inherited Destroy;
  ResizeExtents(FColWidths, FColCount, 0, 0);
  ResizeExtents(FRowHeights, FRowCount, 0, 0);
end;
procedure TCustomGrid.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  if FBorderStyle = bsSingle then Style := Style or WS_BORDER;
  if FScrollBars in [ssVertical, ssBoth] then Style := Style or WS_VSCROLL;
  if FScrollBars in [ssHorizontal, ssBoth] then Style := Style or WS_HSCROLL;
  inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);
  UpdateScrollRange;
end;
procedure TCustomGrid.Initialize;
begin
  FTopLeft.X := FFixedCols; FTopLeft.Y := FFixedRows;
  FCurrent := FTopLeft; FAnchor := FCurrent;
  if goRowSelect in FOptions then FAnchor.X := FColCount - 1;
end;
procedure TCustomGrid.ResizeExtents(var Extents: PGridExtents; OldCount, NewCount: Longint;
  Default: Integer);
var Fresh: PGridExtents; I: Longint;
begin
  if NewCount > MaxCustomExtents then InvalidOp('Too many rows or columns for custom sizes');
  Fresh := nil;
  if NewCount > 0 then
  begin
    GetMem(Fresh, NewCount * SizeOf(Integer));
    for I := 0 to NewCount - 1 do
      if (Extents <> nil) and (I < OldCount) then Fresh^[I] := Extents^[I]
      else Fresh^[I] := Default;
  end;
  if Extents <> nil then FreeMem(Extents, OldCount * SizeOf(Integer));
  Extents := Fresh;
end;
function TCustomGrid.Extent(const Axis: TGridAxisDrawInfo; Index: Longint): Integer;
begin
  if Axis.Columns then Result := GetColWidths(Index) else Result := GetRowHeights(Index);
end;
function TCustomGrid.GetColWidths(Index: Longint): Integer;
begin
  if (FColWidths = nil) or (Index < 0) or (Index >= FColCount) then Result := FDefaultColWidth
  else Result := FColWidths^[Index];
end;
function TCustomGrid.GetRowHeights(Index: Longint): Integer;
begin
  if (FRowHeights = nil) or (Index < 0) or (Index >= FRowCount) then Result := FDefaultRowHeight
  else Result := FRowHeights^[Index];
end;
procedure TCustomGrid.SetColWidths(Index: Longint; Value: Integer);
begin
  if (Index < 0) or (Index >= FColCount) then InvalidOp('Grid index out of range');
  if FColWidths = nil then ResizeExtents(FColWidths, 0, FColCount, FDefaultColWidth);
  if FColWidths^[Index] = Value then Exit;
  FColWidths^[Index] := Value;
  ColWidthsChanged;
end;
procedure TCustomGrid.SetRowHeights(Index: Longint; Value: Integer);
begin
  if (Index < 0) or (Index >= FRowCount) then InvalidOp('Grid index out of range');
  if FRowHeights = nil then ResizeExtents(FRowHeights, 0, FRowCount, FDefaultRowHeight);
  if FRowHeights^[Index] = Value then Exit;
  FRowHeights^[Index] := Value;
  RowHeightsChanged;
end;
procedure TCustomGrid.ColWidthsChanged;
begin UpdateScrollRange; Invalidate; end;
procedure TCustomGrid.RowHeightsChanged;
begin UpdateScrollRange; Invalidate; end;

procedure TCustomGrid.CalcFixedInfo(var DrawInfo: TGridDrawInfo);
  procedure CalcFixedAxis(var Axis: TGridAxisDrawInfo; LineOptions: TGridOptions;
    FixedCount: Integer; FirstCell, CellCount: Longint; Columns: Boolean);
  var I: Integer;
  begin
    Axis.Columns := Columns;
    if LineOptions * FOptions = [] then Axis.EffectiveLineWidth := 0
    else Axis.EffectiveLineWidth := FGridLineWidth;
    Axis.FixedBoundary := 0;
    for I := 0 to FixedCount - 1 do
      Inc(Axis.FixedBoundary, Extent(Axis, I) + Axis.EffectiveLineWidth);
    Axis.FixedCellCount := FixedCount;
    Axis.FirstGridCell := FirstCell;
    Axis.GridCellCount := CellCount;
  end;
begin
  CalcFixedAxis(DrawInfo.Horz, [goFixedVertLine, goVertLine], FFixedCols, LeftCol, FColCount, True);
  CalcFixedAxis(DrawInfo.Vert, [goFixedHorzLine, goHorzLine], FFixedRows, TopRow, FRowCount, False);
end;
procedure TCustomGrid.CalcDrawInfoXY(var DrawInfo: TGridDrawInfo; UseWidth, UseHeight: Integer);
  procedure CalcAxis(var Axis: TGridAxisDrawInfo; UseExtent: Integer);
  var I: Longint;
  begin
    Axis.GridExtent := UseExtent;
    Axis.GridBoundary := Axis.FixedBoundary;
    Axis.FullVisBoundary := Axis.FixedBoundary;
    Axis.LastFullVisibleCell := Axis.FirstGridCell;
    for I := Axis.FirstGridCell to Axis.GridCellCount - 1 do
    begin
      Inc(Axis.GridBoundary, Extent(Axis, I) + Axis.EffectiveLineWidth);
      if Axis.GridBoundary > Axis.GridExtent + Axis.EffectiveLineWidth then
      begin
        Axis.GridBoundary := Axis.GridExtent;
        Break;
      end;
      Axis.LastFullVisibleCell := I;
      Axis.FullVisBoundary := Axis.GridBoundary;
    end;
  end;
begin
  CalcFixedInfo(DrawInfo);
  CalcAxis(DrawInfo.Horz, UseWidth);
  CalcAxis(DrawInfo.Vert, UseHeight);
end;
procedure TCustomGrid.CalcDrawInfo(var DrawInfo: TGridDrawInfo);
begin CalcDrawInfoXY(DrawInfo, ClientWidth, ClientHeight); end;
function TCustomGrid.CalcCoordFromPoint(X, Y: Integer; const DrawInfo: TGridDrawInfo): TGridCoord;
  function DoCalc(const Axis: TGridAxisDrawInfo; N: Integer): Longint;
  var I, Start, Stop, Line: Longint;
  begin
    if N < Axis.FixedBoundary then
    begin Start := 0; Stop := Axis.FixedCellCount - 1; Line := 0; end
    else
    begin Start := Axis.FirstGridCell; Stop := Axis.GridCellCount - 1; Line := Axis.FixedBoundary; end;
    Result := -1;
    for I := Start to Stop do
    begin
      Inc(Line, Extent(Axis, I) + Axis.EffectiveLineWidth);
      if N < Line then begin Result := I; Exit; end;
    end;
  end;
begin
  Result.X := DoCalc(DrawInfo.Horz, X);
  Result.Y := DoCalc(DrawInfo.Vert, Y);
end;
function TCustomGrid.CalcMaxTopLeft(const Coord: TGridCoord; const DrawInfo: TGridDrawInfo): TGridCoord;
  function CalcMaxCell(const Axis: TGridAxisDrawInfo; Start: Longint): Longint;
  var Line: Longint; I: Longint; Size: Integer;
  begin
    Result := Start;
    Line := Axis.GridExtent + Axis.EffectiveLineWidth;
    for I := Start downto Axis.FixedCellCount do
    begin
      Size := Extent(Axis, I);
      if Size > 0 then
      begin
        Dec(Line, Size + Axis.EffectiveLineWidth);
        if Line < Axis.FixedBoundary then Break;
        Result := I;
      end;
    end;
  end;
begin
  Result.X := CalcMaxCell(DrawInfo.Horz, Coord.X);
  Result.Y := CalcMaxCell(DrawInfo.Vert, Coord.Y);
end;
procedure TCustomGrid.GridRectToScreenRect(GridRect: TGridRect; var ScreenRect: TRect;
  IncludeLine: Boolean);
var DrawInfo: TGridDrawInfo; Left, Right, Top, Bottom: Integer;
  function LinePos(const Axis: TGridAxisDrawInfo; Line: Longint): Longint;
  var Start, I: Longint;
  begin
    Result := 0;
    if Line < Axis.FixedCellCount then Start := 0
    else
    begin
      if Line >= Axis.FirstGridCell then Result := Axis.FixedBoundary;
      Start := Axis.FirstGridCell;
    end;
    for I := Start to Line - 1 do
    begin
      Inc(Result, Extent(Axis, I) + Axis.EffectiveLineWidth);
      if Result > Axis.GridExtent then begin Result := 0; Exit; end;
    end;
  end;
  function CalcAxis(const Axis: TGridAxisDrawInfo; GridMin, GridMax: Longint;
    var ScreenMin, ScreenMax: Integer): Boolean;
  var Max: Longint;
  begin
    Result := False;
    if (GridMin >= Axis.FixedCellCount) and (GridMin < Axis.FirstGridCell) then
      if GridMax < Axis.FirstGridCell then Exit
      else GridMin := Axis.FirstGridCell;
    if GridMax > Axis.LastFullVisibleCell then
    begin
      GridMax := Axis.LastFullVisibleCell;
      if GridMax < Axis.GridCellCount - 1 then Inc(GridMax);
      if LinePos(Axis, GridMax) = 0 then Dec(GridMax);
    end;
    ScreenMin := LinePos(Axis, GridMin);
    Max := LinePos(Axis, GridMax);
    if Max = 0 then Max := ScreenMin + Extent(Axis, GridMin)
    else Inc(Max, Extent(Axis, GridMax));
    if Max > Axis.GridExtent then Max := Axis.GridExtent;
    if IncludeLine then Inc(Max, Axis.EffectiveLineWidth);
    ScreenMax := Max;
    Result := True;
  end;
begin
  FillChar(ScreenRect, SizeOf(ScreenRect), 0);
  if (GridRect.Left > GridRect.Right) or (GridRect.Top > GridRect.Bottom) then Exit;
  CalcDrawInfo(DrawInfo);
  if GridRect.Left > DrawInfo.Horz.LastFullVisibleCell + 1 then Exit;
  if GridRect.Top > DrawInfo.Vert.LastFullVisibleCell + 1 then Exit;
  if CalcAxis(DrawInfo.Horz, GridRect.Left, GridRect.Right, Left, Right) and
    CalcAxis(DrawInfo.Vert, GridRect.Top, GridRect.Bottom, Top, Bottom) then
    ScreenRect := Rect(Left, Top, Right, Bottom);
end;
function TCustomGrid.BoxRect(ALeft, ATop, ARight, ABottom: Longint): TRect;
var Area: TGridRect;
begin
  Area.Left := ALeft; Area.Top := ATop; Area.Right := ARight; Area.Bottom := ABottom;
  GridRectToScreenRect(Area, Result, False);
end;
function TCustomGrid.CellRect(ACol, ARow: Longint): TRect;
begin Result := BoxRect(ACol, ARow, ACol, ARow); end;
function TCustomGrid.MouseCoord(X, Y: Integer): TGridCoord;
var DrawInfo: TGridDrawInfo;
begin
  CalcDrawInfo(DrawInfo);
  Result := CalcCoordFromPoint(X, Y, DrawInfo);
  if Result.X < 0 then Result.Y := -1
  else if Result.Y < 0 then Result.X := -1;
end;
function TCustomGrid.GetGridWidth: Integer;
var DrawInfo: TGridDrawInfo;
begin CalcDrawInfo(DrawInfo); Result := DrawInfo.Horz.GridBoundary; end;
function TCustomGrid.GetGridHeight: Integer;
var DrawInfo: TGridDrawInfo;
begin CalcDrawInfo(DrawInfo); Result := DrawInfo.Vert.GridBoundary; end;
function TCustomGrid.GetVisibleColCount: Integer;
var DrawInfo: TGridDrawInfo;
begin CalcDrawInfo(DrawInfo); Result := DrawInfo.Horz.LastFullVisibleCell - LeftCol + 1; end;
function TCustomGrid.GetVisibleRowCount: Integer;
var DrawInfo: TGridDrawInfo;
begin CalcDrawInfo(DrawInfo); Result := DrawInfo.Vert.LastFullVisibleCell - TopRow + 1; end;
function TCustomGrid.GetSelection: TGridRect;
begin
  Result := GridRect(FCurrent, FAnchor);
  if goRowSelect in FOptions then
  begin Result.Left := FFixedCols; Result.Right := FColCount - 1; end;
end;
procedure TCustomGrid.SetSelection(Value: TGridRect);
var OldSel: TGridRect;
begin
  OldSel := Selection;
  FAnchor := Value.TopLeft;
  FCurrent := Value.BottomRight;
  SelectionMoved(OldSel);
end;

procedure TCustomGrid.InvalidateGridRect(const ARect: TGridRect);
var Area: TRect;
begin
  if Handle = 0 then Exit;
  GridRectToScreenRect(ARect, Area, True);
  InvalidateRect(Handle, @Area, False);
end;
procedure TCustomGrid.InvalidateCell(ACol, ARow: Longint);
var Area: TGridRect;
begin
  Area.Left := ACol; Area.Right := ACol; Area.Top := ARow; Area.Bottom := ARow;
  InvalidateGridRect(Area);
end;
procedure TCustomGrid.InvalidateRow(ARow: Longint);
var Area: TGridRect;
begin
  Area.Left := 0; Area.Right := FColCount - 1; Area.Top := ARow; Area.Bottom := ARow;
  InvalidateGridRect(Area);
end;
procedure TCustomGrid.SelectionMoved(const OldSel: TGridRect);
begin
  InvalidateGridRect(OldSel);
  InvalidateGridRect(Selection);
end;

function TCustomGrid.SelectCell(ACol, ARow: Longint): Boolean;
begin Result := True; end;
procedure TCustomGrid.SizeChanged(OldColCount, OldRowCount: Longint);
begin end;
procedure TCustomGrid.TopLeftChanged;
begin end;
procedure TCustomGrid.Click;
begin if Assigned(FOnClick) then FOnClick(Self); end;
procedure TCustomGrid.DblClick;
begin if Assigned(FOnDblClick) then FOnDblClick(Self); end;

procedure TCustomGrid.MoveCurrent(ACol, ARow: Longint; MoveAnchor, Show: Boolean);
var OldSel: TGridRect;
begin
  if (ACol < 0) or (ARow < 0) or (ACol >= FColCount) or (ARow >= FRowCount) then
    InvalidOp('Grid index out of range');
  if not SelectCell(ACol, ARow) then Exit;
  OldSel := Selection;
  FCurrent.X := ACol; FCurrent.Y := ARow;
  if MoveAnchor or not (goRangeSelect in FOptions) then
  begin
    FAnchor := FCurrent;
    if goRowSelect in FOptions then FAnchor.X := FColCount - 1;
  end;
  if goRowSelect in FOptions then FCurrent.X := FFixedCols;
  if Show then ClampInView(FCurrent);
  SelectionMoved(OldSel);
end;
procedure TCustomGrid.MoveAnchor(const NewAnchor: TGridCoord);
var OldSel: TGridRect;
begin
  if [goRangeSelect, goEditing] * FOptions = [goRangeSelect] then
  begin
    OldSel := Selection;
    FAnchor := NewAnchor;
    if goRowSelect in FOptions then FAnchor.X := FColCount - 1;
    ClampInView(NewAnchor);
    SelectionMoved(OldSel);
  end
  else MoveCurrent(NewAnchor.X, NewAnchor.Y, True, True);
end;
procedure TCustomGrid.MoveColRow(ACol, ARow: Longint; MoveAnchor, Show: Boolean);
begin MoveCurrent(ACol, ARow, MoveAnchor, Show); end;
procedure TCustomGrid.FocusCell(ACol, ARow: Longint; MoveAnchor: Boolean);
begin
  MoveCurrent(ACol, ARow, MoveAnchor, True);
  Click;
end;
procedure TCustomGrid.ClampInView(const Coord: TGridCoord);
var DrawInfo: TGridDrawInfo; MaxTopLeft, OldTopLeft: TGridCoord;
begin
  if Handle = 0 then Exit;
  CalcDrawInfo(DrawInfo);
  if (Coord.X > DrawInfo.Horz.LastFullVisibleCell) or (Coord.Y > DrawInfo.Vert.LastFullVisibleCell) or
    (Coord.X < LeftCol) or (Coord.Y < TopRow) then
  begin
    OldTopLeft := FTopLeft;
    MaxTopLeft := CalcMaxTopLeft(Coord, DrawInfo);
    Update;
    if Coord.X < LeftCol then FTopLeft.X := Coord.X
    else if Coord.X > DrawInfo.Horz.LastFullVisibleCell then FTopLeft.X := MaxTopLeft.X;
    if Coord.Y < TopRow then FTopLeft.Y := Coord.Y
    else if Coord.Y > DrawInfo.Vert.LastFullVisibleCell then FTopLeft.Y := MaxTopLeft.Y;
    TopLeftMoved(OldTopLeft);
  end;
end;
procedure TCustomGrid.MoveTopLeft(ALeft, ATop: Longint);
var OldTopLeft: TGridCoord;
begin
  if (ALeft = FTopLeft.X) and (ATop = FTopLeft.Y) then Exit;
  Update;
  OldTopLeft := FTopLeft;
  FTopLeft.X := ALeft; FTopLeft.Y := ATop;
  TopLeftMoved(OldTopLeft);
end;
procedure TCustomGrid.TopLeftMoved(const OldTopLeft: TGridCoord);
var DrawInfo: TGridDrawInfo; DX, DY: Longint;
  { The pixel distance between two first cells, or False when it is more
    than the scrolling area and everything is repainted instead. }
  function CalcScroll(const Axis: TGridAxisDrawInfo; OldPos, CurrentPos: Longint;
    var Amount: Longint): Boolean;
  var Start, Stop, I: Longint;
  begin
    Result := False;
    if OldPos < CurrentPos then begin Start := OldPos; Stop := CurrentPos; end
    else begin Start := CurrentPos; Stop := OldPos; end;
    Amount := 0;
    for I := Start to Stop - 1 do
    begin
      Inc(Amount, Extent(Axis, I) + Axis.EffectiveLineWidth);
      if Amount > Axis.GridBoundary - Axis.FixedBoundary then begin Invalidate; Exit; end;
    end;
    if OldPos < CurrentPos then Amount := -Amount;
    Result := True;
  end;
begin
  UpdateScrollPos;
  CalcDrawInfo(DrawInfo);
  if CalcScroll(DrawInfo.Horz, OldTopLeft.X, FTopLeft.X, DX) and
    CalcScroll(DrawInfo.Vert, OldTopLeft.Y, FTopLeft.Y, DY) then
    ScrollData(DX, DY);
  TopLeftChanged;
end;
procedure TCustomGrid.ScrollData(DX, DY: Integer);
var DrawInfo: TGridDrawInfo; Area: TRect;
begin
  if (Handle = 0) or ((DX = 0) and (DY = 0)) then Exit;
  CalcDrawInfo(DrawInfo);
  if DY = 0 then
    Area := Rect(DrawInfo.Horz.FixedBoundary, 0, DrawInfo.Horz.GridExtent, DrawInfo.Vert.GridExtent)
  else if DX = 0 then
    Area := Rect(0, DrawInfo.Vert.FixedBoundary, DrawInfo.Horz.GridExtent, DrawInfo.Vert.GridExtent)
  else
    Area := Rect(DrawInfo.Horz.FixedBoundary, DrawInfo.Vert.FixedBoundary,
      DrawInfo.Horz.GridExtent, DrawInfo.Vert.GridExtent);
  ScrollWindow(Handle, DX, DY, @Area, @Area);
end;

procedure TCustomGrid.UpdateScrollPos;
var DrawInfo: TGridDrawInfo; MaxTopLeft: TGridCoord;
  procedure SetScroll(Code: Word; Value: Integer);
  begin
    if GetScrollPos(Handle, Code) <> Value then SetScrollPos(Handle, Code, Value, True);
  end;
begin
  if (Handle = 0) or (FScrollBars = ssNone) then Exit;
  CalcDrawInfo(DrawInfo);
  MaxTopLeft.X := FColCount - 1; MaxTopLeft.Y := FRowCount - 1;
  MaxTopLeft := CalcMaxTopLeft(MaxTopLeft, DrawInfo);
  if (FScrollBars in [ssHorizontal, ssBoth]) and (MaxTopLeft.X > FFixedCols) then
    SetScroll(SB_HORZ, ScaleLong(FTopLeft.X - FFixedCols, ScrollMax, MaxTopLeft.X - FFixedCols));
  if (FScrollBars in [ssVertical, ssBoth]) and (MaxTopLeft.Y > FFixedRows) then
    SetScroll(SB_VERT, ScaleLong(FTopLeft.Y - FFixedRows, ScrollMax, MaxTopLeft.Y - FFixedRows));
end;
procedure TCustomGrid.UpdateScrollRange;
var DrawInfo: TGridDrawInfo; MaxTopLeft, OldTopLeft: TGridCoord; Bars: TScrollStyle;
  Width, Height: Integer;
  function BarVisible(Code: Word): Boolean;
  var Min, Max: SmallInt;
  begin
    GetScrollRange(Handle, Code, Min, Max);
    Result := Min <> Max;
  end;
  procedure SetRange(Code: Word; Fixeds: Integer; Max: Longint; var Current: Longint);
  begin
    if Fixeds < Max then SetScrollRange(Handle, Code, 0, ScrollMax, True)
    else SetScrollRange(Handle, Code, 0, 0, True);
    if Current > Max then Current := Max;
  end;
begin
  if (FScrollBars = ssNone) or (Handle = 0) then Exit;
  { Measure as if no scroll bar were shown. }
  Width := ClientWidth; Height := ClientHeight;
  if BarVisible(SB_HORZ) then Inc(Height, GetSystemMetrics(SM_CYHSCROLL));
  if BarVisible(SB_VERT) then Inc(Width, GetSystemMetrics(SM_CXVSCROLL));
  OldTopLeft := FTopLeft;
  { Showing a bar resizes the window; ssNone stops the WM_SIZE recursion. }
  Bars := FScrollBars; FScrollBars := ssNone;
  try
    CalcDrawInfoXY(DrawInfo, Width, Height);
    MaxTopLeft.X := FColCount - 1; MaxTopLeft.Y := FRowCount - 1;
    MaxTopLeft := CalcMaxTopLeft(MaxTopLeft, DrawInfo);
    if Bars in [ssHorizontal, ssBoth] then SetRange(SB_HORZ, FFixedCols, MaxTopLeft.X, FTopLeft.X);
    if Bars in [ssVertical, ssBoth] then SetRange(SB_VERT, FFixedRows, MaxTopLeft.Y, FTopLeft.Y);
  finally FScrollBars := Bars; end;
  if (OldTopLeft.X <> FTopLeft.X) or (OldTopLeft.Y <> FTopLeft.Y) then TopLeftMoved(OldTopLeft)
  else UpdateScrollPos;
end;
procedure TCustomGrid.ModifyScrollBar(ScrollBar, ScrollCode, Pos: Word);
var DrawInfo: TGridDrawInfo; NewTopLeft, MaxTopLeft, PageTopLeft: TGridCoord;
  Value, Min, Max, Page: Longint;
begin
  if Visible and CanFocus and TabStop then SetFocus;
  CalcDrawInfo(DrawInfo);
  MaxTopLeft.X := FColCount - 1; MaxTopLeft.Y := FRowCount - 1;
  MaxTopLeft := CalcMaxTopLeft(MaxTopLeft, DrawInfo);
  NewTopLeft := FTopLeft;
  if ScrollBar = SB_HORZ then
  begin Value := NewTopLeft.X; Min := FFixedCols; Max := MaxTopLeft.X; end
  else begin Value := NewTopLeft.Y; Min := FFixedRows; Max := MaxTopLeft.Y; end;
  case ScrollCode of
    SB_LINEUP: Dec(Value);
    SB_LINEDOWN: Inc(Value);
    SB_PAGEUP:
      begin
        PageTopLeft := CalcMaxTopLeft(FTopLeft, DrawInfo);
        if ScrollBar = SB_HORZ then Page := FTopLeft.X - PageTopLeft.X
        else Page := FTopLeft.Y - PageTopLeft.Y;
        if Page < 1 then Page := 1;
        Dec(Value, Page);
      end;
    SB_PAGEDOWN:
      begin
        if ScrollBar = SB_HORZ then Page := DrawInfo.Horz.LastFullVisibleCell - FTopLeft.X
        else Page := DrawInfo.Vert.LastFullVisibleCell - FTopLeft.Y;
        if Page < 1 then Page := 1;
        Inc(Value, Page);
      end;
    SB_THUMBPOSITION, SB_THUMBTRACK:
      if (goThumbTracking in FOptions) or (ScrollCode = SB_THUMBPOSITION) then
        Value := Min + ScaleLong(Pos, Max - Min, ScrollMax);
    SB_BOTTOM: Value := Max;
    SB_TOP: Value := Min;
  end;
  if Value < Min then Value := Min else if Value > Max then Value := Max;
  if ScrollBar = SB_HORZ then NewTopLeft.X := Value else NewTopLeft.Y := Value;
  MoveTopLeft(NewTopLeft.X, NewTopLeft.Y);
end;
procedure TCustomGrid.WMHScroll(var Msg: TMessage);
begin ModifyScrollBar(SB_HORZ, Msg.WParam, LoWord(Msg.LParam)); Msg.Result := 0; end;
procedure TCustomGrid.WMVScroll(var Msg: TMessage);
begin ModifyScrollBar(SB_VERT, Msg.WParam, LoWord(Msg.LParam)); Msg.Result := 0; end;
procedure TCustomGrid.WMSize(var Msg: TMessage);
begin inherited; UpdateScrollRange; end;
procedure TCustomGrid.WMGetDlgCode(var Msg: TWMGetDlgCode);
begin Msg.Result := DLGC_WANTARROWS; end;

procedure TCustomGrid.Paint;
var DrawInfo: TGridDrawInfo; Sel: TGridRect; LineColor: TColor; FocusArea: TRect;
  procedure DrawLines(DoHorz, DoVert: Boolean; Col, Row: Longint; Left, Top, Right, Bottom: Longint;
    Color: TColor);
  var Pos: Longint; Index: Longint;
  begin
    Canvas.Brush.Color := Color;
    if DoVert and (DrawInfo.Horz.EffectiveLineWidth > 0) then
    begin
      Pos := Left; Index := Col;
      while (Index < FColCount) and (Pos < Right) do
      begin
        Inc(Pos, GetColWidths(Index));
        Canvas.FillRect(Rect(Pos, Top, Pos + DrawInfo.Horz.EffectiveLineWidth, Bottom));
        Inc(Pos, DrawInfo.Horz.EffectiveLineWidth); Inc(Index);
      end;
    end;
    if DoHorz and (DrawInfo.Vert.EffectiveLineWidth > 0) then
    begin
      Pos := Top; Index := Row;
      while (Index < FRowCount) and (Pos < Bottom) do
      begin
        Inc(Pos, GetRowHeights(Index));
        Canvas.FillRect(Rect(Left, Pos, Right, Pos + DrawInfo.Vert.EffectiveLineWidth));
        Inc(Pos, DrawInfo.Vert.EffectiveLineWidth); Inc(Index);
      end;
    end;
  end;
  procedure DrawCells(ACol, ARow: Longint; StartX, StartY, StopX, StopY: Longint;
    CellColor: TColor; IncludeState: TGridDrawState);
  var CurCol, CurRow: Longint; Where: TRect; State: TGridDrawState;
  begin
    CurRow := ARow;
    Where.Top := StartY;
    while (Where.Top < StopY) and (CurRow < FRowCount) do
    begin
      CurCol := ACol;
      Where.Left := StartX;
      Where.Bottom := Where.Top + GetRowHeights(CurRow);
      while (Where.Left < StopX) and (CurCol < FColCount) do
      begin
        Where.Right := Where.Left + GetColWidths(CurCol);
        if RectVisible(Canvas.Handle, Where) then
        begin
          State := IncludeState;
          if Focused and (CurRow = Row) and (CurCol = Col) then Include(State, gdFocused);
          if PointInGridRect(CurCol, CurRow, Sel) then Include(State, gdSelected);
          if FDefaultDrawing then
          begin
            Canvas.Font := Font;
            if (gdSelected in State) and (not (gdFocused in State) or
              ([goDrawFocusSelected, goRowSelect] * FOptions <> [])) then
            begin
              Canvas.Brush.Color := clHighlight;
              Canvas.Font.Color := clHighlightText;
            end
            else Canvas.Brush.Color := CellColor;
            Canvas.FillRect(Where);
          end;
          DrawCell(CurCol, CurRow, Where, State);
          if FDefaultDrawing and (gdFocused in State) and not (goRowSelect in FOptions) then
            Canvas.DrawFocusRect(Where);
        end;
        Where.Left := Where.Right + DrawInfo.Horz.EffectiveLineWidth;
        Inc(CurCol);
      end;
      Where.Top := Where.Bottom + DrawInfo.Vert.EffectiveLineWidth;
      Inc(CurRow);
    end;
  end;
begin
  CalcDrawInfo(DrawInfo);
  if (DrawInfo.Horz.EffectiveLineWidth > 0) or (DrawInfo.Vert.EffectiveLineWidth > 0) then
  begin
    LineColor := clSilver;
    if ColorToRGB(Color) = ColorToRGB(clSilver) then LineColor := clGray;
    DrawLines(goFixedHorzLine in FOptions, goFixedVertLine in FOptions, 0, 0,
      0, 0, DrawInfo.Horz.FixedBoundary, DrawInfo.Vert.FixedBoundary, clBlack);
    DrawLines(goFixedHorzLine in FOptions, goFixedVertLine in FOptions, LeftCol, 0,
      DrawInfo.Horz.FixedBoundary, 0, DrawInfo.Horz.GridBoundary, DrawInfo.Vert.FixedBoundary, clBlack);
    DrawLines(goFixedHorzLine in FOptions, goFixedVertLine in FOptions, 0, TopRow,
      0, DrawInfo.Vert.FixedBoundary, DrawInfo.Horz.FixedBoundary, DrawInfo.Vert.GridBoundary, clBlack);
    DrawLines(goHorzLine in FOptions, goVertLine in FOptions, LeftCol, TopRow,
      DrawInfo.Horz.FixedBoundary, DrawInfo.Vert.FixedBoundary, DrawInfo.Horz.GridBoundary,
      DrawInfo.Vert.GridBoundary, LineColor);
  end;
  Sel := Selection;
  DrawCells(0, 0, 0, 0, DrawInfo.Horz.FixedBoundary, DrawInfo.Vert.FixedBoundary, FFixedColor, [gdFixed]);
  DrawCells(LeftCol, 0, DrawInfo.Horz.FixedBoundary, 0, DrawInfo.Horz.GridBoundary,
    DrawInfo.Vert.FixedBoundary, FFixedColor, [gdFixed]);
  DrawCells(0, TopRow, 0, DrawInfo.Vert.FixedBoundary, DrawInfo.Horz.FixedBoundary,
    DrawInfo.Vert.GridBoundary, FFixedColor, [gdFixed]);
  DrawCells(LeftCol, TopRow, DrawInfo.Horz.FixedBoundary, DrawInfo.Vert.FixedBoundary,
    DrawInfo.Horz.GridBoundary, DrawInfo.Vert.GridBoundary, Color, []);
  if (goRowSelect in FOptions) and FDefaultDrawing and Focused then
  begin
    GridRectToScreenRect(Sel, FocusArea, False);
    Canvas.DrawFocusRect(FocusArea);
  end;
end;

function TCustomGrid.CanGridAcceptKey(Key: Word; Shift: TShiftState): Boolean;
begin Result := True; end;
procedure TCustomGrid.KeyDown(var Key: Word; Shift: TShiftState);
var NewTopLeft, NewCurrent, MaxTopLeft: TGridCoord; DrawInfo: TGridDrawInfo;
  PageWidth, PageHeight: Longint;
  procedure Restrict(var Coord: TGridCoord; MinX, MinY, MaxX, MaxY: Longint);
  begin
    if Coord.X > MaxX then Coord.X := MaxX else if Coord.X < MinX then Coord.X := MinX;
    if Coord.Y > MaxY then Coord.Y := MaxY else if Coord.Y < MinY then Coord.Y := MinY;
  end;
begin
  inherited KeyDown(Key, Shift);
  if not CanGridAcceptKey(Key, Shift) then Key := 0;
  if Key = 0 then Exit;
  NewCurrent := FCurrent; NewTopLeft := FTopLeft;
  CalcDrawInfo(DrawInfo);
  PageWidth := DrawInfo.Horz.LastFullVisibleCell - LeftCol;
  if PageWidth < 1 then PageWidth := 1;
  PageHeight := DrawInfo.Vert.LastFullVisibleCell - TopRow;
  if PageHeight < 1 then PageHeight := 1;
  if ssCtrl in Shift then
    case Key of
      VK_UP: Dec(NewTopLeft.Y);
      VK_DOWN: Inc(NewTopLeft.Y);
      VK_LEFT:
        if not (goRowSelect in FOptions) then
        begin Dec(NewCurrent.X, PageWidth); Dec(NewTopLeft.X, PageWidth); end;
      VK_RIGHT:
        if not (goRowSelect in FOptions) then
        begin Inc(NewCurrent.X, PageWidth); Inc(NewTopLeft.X, PageWidth); end;
      VK_PRIOR: NewCurrent.Y := TopRow;
      VK_NEXT: NewCurrent.Y := DrawInfo.Vert.LastFullVisibleCell;
      VK_HOME: begin NewCurrent.X := FFixedCols; NewCurrent.Y := FFixedRows; end;
      VK_END: begin NewCurrent.X := FColCount - 1; NewCurrent.Y := FRowCount - 1; end;
    end
  else
    case Key of
      VK_UP: Dec(NewCurrent.Y);
      VK_DOWN: Inc(NewCurrent.Y);
      VK_LEFT: if goRowSelect in FOptions then Dec(NewCurrent.Y) else Dec(NewCurrent.X);
      VK_RIGHT: if goRowSelect in FOptions then Inc(NewCurrent.Y) else Inc(NewCurrent.X);
      VK_NEXT: begin Inc(NewCurrent.Y, PageHeight); Inc(NewTopLeft.Y, PageHeight); end;
      VK_PRIOR: begin Dec(NewCurrent.Y, PageHeight); Dec(NewTopLeft.Y, PageHeight); end;
      VK_HOME: if goRowSelect in FOptions then NewCurrent.Y := FFixedRows else NewCurrent.X := FFixedCols;
      VK_END: if goRowSelect in FOptions then NewCurrent.Y := FRowCount - 1 else NewCurrent.X := FColCount - 1;
    end;
  MaxTopLeft.X := FColCount - 1; MaxTopLeft.Y := FRowCount - 1;
  MaxTopLeft := CalcMaxTopLeft(MaxTopLeft, DrawInfo);
  Restrict(NewTopLeft, FFixedCols, FFixedRows, MaxTopLeft.X, MaxTopLeft.Y);
  if (NewTopLeft.X <> LeftCol) or (NewTopLeft.Y <> TopRow) then
    MoveTopLeft(NewTopLeft.X, NewTopLeft.Y);
  Restrict(NewCurrent, FFixedCols, FFixedRows, FColCount - 1, FRowCount - 1);
  if (NewCurrent.X <> Col) or (NewCurrent.Y <> Row) then
    FocusCell(NewCurrent.X, NewCurrent.Y, not (ssShift in Shift));
end;
procedure TCustomGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var DrawInfo: TGridDrawInfo; CellHit: TGridCoord;
begin
  if CanFocus then
  begin
    if not Focused then SetFocus;
    if not Focused then begin MouseCapture := False; Exit; end;
  end;
  if (Button = mbLeft) and (ssDouble in Shift) then DblClick
  else if Button = mbLeft then
  begin
    CalcDrawInfo(DrawInfo);
    CellHit := CalcCoordFromPoint(X, Y, DrawInfo);
    if (CellHit.X >= FFixedCols) and (CellHit.Y >= FFixedRows) then
    begin
      if (ssShift in Shift) and (goRangeSelect in FOptions) then MoveAnchor(CellHit)
      else MoveCurrent(CellHit.X, CellHit.Y, True, True);
      FGridState := gsSelecting;
      MouseCapture := True;
      SetTimer(Handle, SelectTimer, 60, nil);
    end;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;
procedure TCustomGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
var DrawInfo: TGridDrawInfo; CellHit: TGridCoord;
begin
  if FGridState = gsSelecting then
  begin
    CalcDrawInfo(DrawInfo);
    CellHit := CalcCoordFromPoint(X, Y, DrawInfo);
    if (CellHit.X >= FFixedCols) and (CellHit.Y >= FFixedRows) and
      (CellHit.X <= DrawInfo.Horz.LastFullVisibleCell + 1) and
      (CellHit.Y <= DrawInfo.Vert.LastFullVisibleCell + 1) then
      if (CellHit.X <> FCurrent.X) or (CellHit.Y <> FCurrent.Y) then MoveAnchor(CellHit);
  end;
  inherited MouseMove(Shift, X, Y);
end;
procedure TCustomGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  try
    if FGridState = gsSelecting then
    begin
      MouseMove(Shift, X, Y);
      KillTimer(Handle, SelectTimer);
      MouseCapture := False;
      FGridState := gsNormal;
      Click;
    end;
    inherited MouseUp(Button, Shift, X, Y);
  finally FGridState := gsNormal; end;
end;
procedure TCustomGrid.WMTimer(var Msg: TMessage);
var P: TPoint; DrawInfo: TGridDrawInfo; Direction: TGridScrollDirection;
begin
  if (Msg.WParam <> SelectTimer) or (FGridState <> gsSelecting) then begin inherited; Exit; end;
  GetCursorPos(P); P := ScreenToClient(P);
  CalcDrawInfo(DrawInfo);
  Direction := [];
  if P.X < DrawInfo.Horz.FixedBoundary then Include(Direction, sdLeft)
  else if P.X > DrawInfo.Horz.FullVisBoundary then Include(Direction, sdRight);
  if P.Y < DrawInfo.Vert.FixedBoundary then Include(Direction, sdUp)
  else if P.Y > DrawInfo.Vert.FullVisBoundary then Include(Direction, sdDown);
  if Direction <> [] then TimedScroll(Direction);
end;
procedure TCustomGrid.TimedScroll(Direction: TGridScrollDirection);
var NewAnchor: TGridCoord;
begin
  NewAnchor := FAnchor;
  if (sdLeft in Direction) and (FAnchor.X > FFixedCols) then Dec(NewAnchor.X);
  if (sdRight in Direction) and (FAnchor.X < FColCount - 1) then Inc(NewAnchor.X);
  if (sdUp in Direction) and (FAnchor.Y > FFixedRows) then Dec(NewAnchor.Y);
  if (sdDown in Direction) and (FAnchor.Y < FRowCount - 1) then Inc(NewAnchor.Y);
  if (FAnchor.X <> NewAnchor.X) or (FAnchor.Y <> NewAnchor.Y) then MoveAnchor(NewAnchor);
end;
procedure TCustomGrid.DoEnter;
begin
  inherited DoEnter;
  InvalidateGridRect(Selection);
end;
procedure TCustomGrid.DoExit;
begin
  inherited DoExit;
  InvalidateGridRect(Selection);
end;

procedure TCustomGrid.ChangeSize(NewColCount, NewRowCount: Longint);
var OldColCount, OldRowCount: Longint;
  procedure DoChange;
  var Coord: TGridCoord;
  begin
    if FColWidths <> nil then ResizeExtents(FColWidths, OldColCount, FColCount, FDefaultColWidth);
    if FRowHeights <> nil then ResizeExtents(FRowHeights, OldRowCount, FRowCount, FDefaultRowHeight);
    Coord := FCurrent;
    if Row >= FRowCount then Coord.Y := FRowCount - 1;
    if Col >= FColCount then Coord.X := FColCount - 1;
    if (FCurrent.X <> Coord.X) or (FCurrent.Y <> Coord.Y) then MoveCurrent(Coord.X, Coord.Y, True, True);
    if (FAnchor.X <> Coord.X) or (FAnchor.Y <> Coord.Y) then MoveAnchor(Coord);
    Invalidate;
    UpdateScrollRange;
    SizeChanged(OldColCount, OldRowCount);
  end;
begin
  OldColCount := FColCount; OldRowCount := FRowCount;
  FColCount := NewColCount; FRowCount := NewRowCount;
  if FFixedCols > NewColCount then FFixedCols := NewColCount - 1;
  if FFixedRows > NewRowCount then FFixedRows := NewRowCount - 1;
  DoChange;
end;
procedure TCustomGrid.SetColCount(Value: Longint);
begin
  if FColCount = Value then Exit;
  if Value < 1 then Value := 1;
  if Value <= FFixedCols then FixedCols := Value - 1;
  ChangeSize(Value, FRowCount);
  if goRowSelect in FOptions then
  begin FAnchor.X := FColCount - 1; Invalidate; end;
end;
procedure TCustomGrid.SetRowCount(Value: Longint);
begin
  if FRowCount = Value then Exit;
  if Value < 1 then Value := 1;
  if Value <= FFixedRows then FixedRows := Value - 1;
  ChangeSize(FColCount, Value);
end;
procedure TCustomGrid.SetFixedCols(Value: Integer);
begin
  if FFixedCols = Value then Exit;
  if Value < 0 then InvalidOp('Grid index out of range');
  if Value >= FColCount then InvalidOp('Fixed column count must be less than column count');
  FFixedCols := Value;
  Initialize; Invalidate; UpdateScrollRange;
end;
procedure TCustomGrid.SetFixedRows(Value: Integer);
begin
  if FFixedRows = Value then Exit;
  if Value < 0 then InvalidOp('Grid index out of range');
  if Value >= FRowCount then InvalidOp('Fixed row count must be less than row count');
  FFixedRows := Value;
  Initialize; Invalidate; UpdateScrollRange;
end;
procedure TCustomGrid.SetDefaultColWidth(Value: Integer);
begin
  if FColWidths <> nil then ResizeExtents(FColWidths, FColCount, 0, 0);
  FDefaultColWidth := Value;
  ColWidthsChanged;
end;
procedure TCustomGrid.SetDefaultRowHeight(Value: Integer);
begin
  if FRowHeights <> nil then ResizeExtents(FRowHeights, FRowCount, 0, 0);
  FDefaultRowHeight := Value;
  RowHeightsChanged;
end;
procedure TCustomGrid.SetDefaultDrawing(Value: Boolean);
begin
  if FDefaultDrawing = Value then Exit;
  FDefaultDrawing := Value; Invalidate;
end;
procedure TCustomGrid.SetFixedColor(Value: TColor);
begin
  if FFixedColor = Value then Exit;
  FFixedColor := Value; Invalidate;
end;
procedure TCustomGrid.SetGridLineWidth(Value: Integer);
begin
  if FGridLineWidth = Value then Exit;
  FGridLineWidth := Value; ColWidthsChanged;
end;
procedure TCustomGrid.SetOptions(Value: TGridOptions);
begin
  if FOptions = Value then Exit;
  if Value * UnsupportedOptions <> [] then
    InvalidOp('Grid editing, tabbing, sizing and moving are not supported');
  FOptions := Value;
  if goRowSelect in Value then MoveCurrent(Col, Row, True, False);
  Invalidate;
end;
procedure TCustomGrid.SetScrollBars(Value: TScrollStyle);
begin
  if FScrollBars = Value then Exit;
  if Handle <> 0 then
  begin
    { Drop the bars this style no longer allows; UpdateScrollRange sets the others. }
    if not (Value in [ssHorizontal, ssBoth]) then SetScrollRange(Handle, SB_HORZ, 0, 0, True);
    if not (Value in [ssVertical, ssBoth]) then SetScrollRange(Handle, SB_VERT, 0, 0, True);
  end;
  FScrollBars := Value;
  UpdateScrollRange;
end;
procedure TCustomGrid.SetBorderStyle(Value: TBorderStyle);
begin
  if FBorderStyle = Value then Exit;
  if Handle <> 0 then InvalidOp('BorderStyle cannot change after the grid window exists');
  FBorderStyle := Value;
end;
procedure TCustomGrid.SetCol(Value: Longint);
begin if Col <> Value then FocusCell(Value, Row, True); end;
procedure TCustomGrid.SetRow(Value: Longint);
begin if Row <> Value then FocusCell(Col, Value, True); end;
procedure TCustomGrid.SetLeftCol(Value: Longint);
begin if FTopLeft.X <> Value then MoveTopLeft(Value, TopRow); end;
procedure TCustomGrid.SetTopRow(Value: Longint);
begin if FTopLeft.Y <> Value then MoveTopLeft(LeftCol, Value); end;

{ TDrawGrid }

function TDrawGrid.CellRect(ACol, ARow: Longint): TRect;
begin Result := inherited CellRect(ACol, ARow); end;
procedure TDrawGrid.MouseToCell(X, Y: Integer; var ACol, ARow: Longint);
var Coord: TGridCoord;
begin
  Coord := MouseCoord(X, Y);
  ACol := Coord.X; ARow := Coord.Y;
end;
procedure TDrawGrid.DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
begin
  if Assigned(FOnDrawCell) then FOnDrawCell(Self, ACol, ARow, ARect, AState);
end;
function TDrawGrid.SelectCell(ACol, ARow: Longint): Boolean;
begin
  Result := True;
  if Assigned(FOnSelectCell) then FOnSelectCell(Self, ACol, ARow, Result);
end;
procedure TDrawGrid.TopLeftChanged;
begin
  inherited TopLeftChanged;
  if Assigned(FOnTopLeftChanged) then FOnTopLeftChanged(Self);
end;

{ TStringGrid }

type
  { A row or column of a TStringGrid as TStrings, as Delphi's Rows/Cols. }
  TGridLineStrings = class(TStrings)
  private
    FGrid: TStringGrid;
    FIndex: Integer;
    FIsCol: Boolean;
  protected
    function Get(Index: Integer): AnsiString; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: AnsiString); override;
    procedure PutObject(Index: Integer; AObject: TObject); override;
  public
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: AnsiString); override;
    function Add(const S: AnsiString): Integer; override;
  end;
function TGridLineStrings.GetCount: Integer;
begin
  if FIsCol then Result := FGrid.RowCount else Result := FGrid.ColCount;
end;
function TGridLineStrings.Get(Index: Integer): AnsiString;
begin
  if FIsCol then Result := FGrid.Cells[FIndex, Index] else Result := FGrid.Cells[Index, FIndex];
end;
function TGridLineStrings.GetObject(Index: Integer): TObject;
begin
  if FIsCol then Result := FGrid.Objects[FIndex, Index] else Result := FGrid.Objects[Index, FIndex];
end;
procedure TGridLineStrings.Put(Index: Integer; const S: AnsiString);
begin
  if FIsCol then FGrid.Cells[FIndex, Index] := S else FGrid.Cells[Index, FIndex] := S;
end;
procedure TGridLineStrings.PutObject(Index: Integer; AObject: TObject);
begin
  if FIsCol then FGrid.Objects[FIndex, Index] := AObject
  else FGrid.Objects[Index, FIndex] := AObject;
end;
procedure TGridLineStrings.Clear;
var I: Integer;
begin
  for I := 0 to GetCount - 1 do begin Put(I, ''); PutObject(I, nil); end;
end;
procedure TGridLineStrings.Delete(Index: Integer);
begin raise EInvalidGridOperation.Create('Grid rows and columns have a fixed size'); end;
procedure TGridLineStrings.Insert(Index: Integer; const S: AnsiString);
begin raise EInvalidGridOperation.Create('Grid rows and columns have a fixed size'); end;
function TGridLineStrings.Add(const S: AnsiString): Integer;
begin raise EInvalidGridOperation.Create('Grid rows and columns have a fixed size'); end;

constructor TStringGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FData := TList.Create; FCols := TList.Create; FRows := TList.Create;
end;
destructor TStringGrid.Destroy;
var I: Integer;
begin
  inherited Destroy;
  for I := 0 to FData.Count - 1 do TObject(FData[I]).Free;
  for I := 0 to FCols.Count - 1 do TObject(FCols[I]).Free;
  for I := 0 to FRows.Count - 1 do TObject(FRows[I]).Free;
  FData.Free; FCols.Free; FRows.Free;
end;
function TStringGrid.RowData(ARow: Integer; Create: Boolean): TStringList;
begin
  Result := nil;
  if (ARow < 0) or (ARow >= RowCount) then InvalidOp('Grid index out of range');
  if ARow < FData.Count then Result := TStringList(FData[ARow]);
  if (Result <> nil) or not Create then Exit;
  while FData.Count <= ARow do FData.Add(nil);
  Result := TStringList.Create;
  while Result.Count < ColCount do Result.Add('');
  FData[ARow] := Result;
end;
function TStringGrid.GetCells(ACol, ARow: Integer): string;
var Data: TStringList;
begin
  if (ACol < 0) or (ACol >= ColCount) then InvalidOp('Grid index out of range');
  Data := RowData(ARow, False);
  if Data = nil then Result := '' else Result := Data[ACol];
end;
procedure TStringGrid.SetCells(ACol, ARow: Integer; const Value: string);
begin
  if (ACol < 0) or (ACol >= ColCount) then InvalidOp('Grid index out of range');
  RowData(ARow, True)[ACol] := Value;
  InvalidateCell(ACol, ARow);
end;
function TStringGrid.GetObjects(ACol, ARow: Integer): TObject;
var Data: TStringList;
begin
  if (ACol < 0) or (ACol >= ColCount) then InvalidOp('Grid index out of range');
  Data := RowData(ARow, False);
  if Data = nil then Result := nil else Result := Data.Objects[ACol];
end;
procedure TStringGrid.SetObjects(ACol, ARow: Integer; Value: TObject);
begin
  if (ACol < 0) or (ACol >= ColCount) then InvalidOp('Grid index out of range');
  RowData(ARow, True).Objects[ACol] := Value;
end;
function TStringGrid.LineStrings(List: TList; Index: Integer; IsCol: Boolean): TStrings;
var Line: TGridLineStrings;
begin
  while List.Count <= Index do List.Add(nil);
  if List[Index] = nil then
  begin
    Line := TGridLineStrings.Create;
    Line.FGrid := Self; Line.FIndex := Index; Line.FIsCol := IsCol;
    List[Index] := Line;
  end;
  Result := TStrings(List[Index]);
end;
function TStringGrid.GetCols(Index: Integer): TStrings;
begin
  if (Index < 0) or (Index >= ColCount) then InvalidOp('Grid index out of range');
  Result := LineStrings(FCols, Index, True);
end;
function TStringGrid.GetRows(Index: Integer): TStrings;
begin
  if (Index < 0) or (Index >= RowCount) then InvalidOp('Grid index out of range');
  Result := LineStrings(FRows, Index, False);
end;
procedure TStringGrid.SetCols(Index: Integer; Value: TStrings);
var I: Integer; Line: TStrings;
begin
  Line := GetCols(Index);
  for I := 0 to RowCount - 1 do
    if I < Value.Count then
    begin Line[I] := Value[I]; Line.Objects[I] := Value.Objects[I]; end
    else begin Line[I] := ''; Line.Objects[I] := nil; end;
end;
procedure TStringGrid.SetRows(Index: Integer; Value: TStrings);
var I: Integer; Line: TStrings;
begin
  Line := GetRows(Index);
  for I := 0 to ColCount - 1 do
    if I < Value.Count then
    begin Line[I] := Value[I]; Line.Objects[I] := Value.Objects[I]; end
    else begin Line[I] := ''; Line.Objects[I] := nil; end;
end;
procedure TStringGrid.SizeChanged(OldColCount, OldRowCount: Longint);
var I: Integer; Data: TStringList;
begin
  inherited SizeChanged(OldColCount, OldRowCount);
  while FData.Count > RowCount do
  begin
    TObject(FData[FData.Count - 1]).Free; FData.Delete(FData.Count - 1);
  end;
  for I := 0 to FData.Count - 1 do
  begin
    Data := TStringList(FData[I]);
    if Data = nil then Continue;
    while Data.Count > ColCount do Data.Delete(Data.Count - 1);
    while Data.Count < ColCount do Data.Add('');
  end;
  while FCols.Count > ColCount do
  begin TObject(FCols[FCols.Count - 1]).Free; FCols.Delete(FCols.Count - 1); end;
  while FRows.Count > RowCount do
  begin TObject(FRows[FRows.Count - 1]).Free; FRows.Delete(FRows.Count - 1); end;
end;
procedure TStringGrid.DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState);
begin
  if DefaultDrawing then
    Canvas.TextRect(ARect, ARect.Left + 2, ARect.Top + 2, Cells[ACol, ARow]);
  inherited DrawCell(ACol, ARow, ARect, AState);
end;
end.
