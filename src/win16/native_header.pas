{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 THeader: painted column sections with mouse-resizable dividers.
  Widths live in Sections.Objects. Dragging resizes live (OnSizing on every
  move, OnSized once at release) rather than drawing Delphi's XOR track line. }
unit native_header;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This header requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls;
type
  TSectionEvent = procedure(Sender: TObject; ASection, AWidth: Integer) of object;
  THeader = class(TCustomControl)
  private
    FSections: TStringList;
    FAllowResize: Boolean;
    FResizing, FMinWidth: Integer;
    FDragging: Boolean;
    FOnSizing, FOnSized: TSectionEvent;
    function GetSections: TStrings;
    procedure SetSections(Value: TStrings);
    function GetWidth(Index: Integer): Integer;
    procedure SetWidth(Index: Integer; Value: Integer);
    procedure SectionsChanged(Sender: TObject);
    function DividerAt(X: Integer): Integer;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Sizing(ASection, AWidth: Integer); virtual;
    procedure Sized(ASection, AWidth: Integer); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property SectionWidth[Index: Integer]: Integer read GetWidth write SetWidth;
  published
    property AllowResize: Boolean read FAllowResize write FAllowResize default True;
    property Font;
    property Sections: TStrings read GetSections write SetSections;
    property OnSizing: TSectionEvent read FOnSizing write FOnSizing;
    property OnSized: TSectionEvent read FOnSized write FOnSized;
    property Enabled;
    property Visible;
    property TabStop;
    property TabOrder;
  end;
implementation
uses SysUtils, WinProcs, native_window, native_cursors;
const
  DefaultWidth = 64;
  { Pixels either side of a divider that grab it. }
  GripWidth = 2;
constructor THeader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSections := TStringList.Create;
  FSections.OnChange := SectionsChanged;
  FAllowResize := True;
  FResizing := -1;
  FMinWidth := 8;
  Color := clBtnFace;
  SetBounds(0, 0, 250, 25);
end;
destructor THeader.Destroy;
begin
  inherited Destroy;
  FSections.Free;
end;
function THeader.GetSections: TStrings;
begin Result := FSections; end;
procedure THeader.SetSections(Value: TStrings);
begin FSections.Assign(Value); end;
procedure THeader.SectionsChanged(Sender: TObject);
var I: Integer;
begin
  { New sections start with the Delphi default width. }
  FSections.OnChange := nil;
  try
    for I := 0 to FSections.Count - 1 do
      if FSections.Objects[I] = nil then FSections.Objects[I] := TObject(Pointer(LongInt(DefaultWidth)));
  finally FSections.OnChange := SectionsChanged; end;
  Invalidate;
end;
function THeader.GetWidth(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= FSections.Count) then
    raise ENativeWindowError.Create('Header section index out of range');
  Result := LongInt(Pointer(FSections.Objects[Index]));
end;
procedure THeader.SetWidth(Index: Integer; Value: Integer);
begin
  GetWidth(Index);
  if Value < 0 then Value := 0;
  FSections.OnChange := nil;
  try FSections.Objects[Index] := TObject(Pointer(LongInt(Value)));
  finally FSections.OnChange := SectionsChanged; end;
  Invalidate;
end;
function THeader.DividerAt(X: Integer): Integer;
var I, Right: Integer;
begin
  Right := 0;
  for I := 0 to FSections.Count - 1 do
  begin
    Inc(Right, GetWidth(I));
    if Abs(X - Right) <= GripWidth then begin Result := I; Exit; end;
  end;
  Result := -1;
end;
procedure THeader.Paint;
var I, X, W: Integer; R: TRect; Buffer: array[0..255] of Char;
begin
  X := 0;
  Canvas.Brush.Style := bsSolid;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  for I := 0 to FSections.Count do
  begin
    if I < FSections.Count then W := GetWidth(I) else W := ClientWidth - X;
    if W <= 0 then Continue;
    R := Graphics.Rect(X, 0, X + W, ClientHeight);
    Canvas.Brush.Color := clBtnFace; Canvas.FillRect(R);
    Canvas.Brush.Color := clBtnHighlight;
    Canvas.FillRect(Graphics.Rect(R.Left, R.Top, R.Right - 1, R.Top + 1));
    Canvas.FillRect(Graphics.Rect(R.Left, R.Top, R.Left + 1, R.Bottom - 1));
    Canvas.Brush.Color := clBtnShadow;
    Canvas.FillRect(Graphics.Rect(R.Left, R.Bottom - 1, R.Right, R.Bottom));
    Canvas.FillRect(Graphics.Rect(R.Right - 1, R.Top, R.Right, R.Bottom));
    if I < FSections.Count then
    begin
      InflateRect(R, -4, 0);
      SelectObject(Canvas.Handle, Font.Handle);
      SetTextColor(Canvas.Handle, ColorToRGB(Font.Color));
      StrPCopy(Buffer, FSections[I]);
      DrawText(Canvas.Handle, Buffer, -1, R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    end;
    Inc(X, W);
  end;
end;
procedure THeader.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button <> mbLeft) or not FAllowResize then Exit;
  FResizing := DividerAt(X);
  if FResizing < 0 then Exit;
  FDragging := True;
  MouseCapture := True;
end;
procedure THeader.MouseMove(Shift: TShiftState; X, Y: Integer);
var Left, I, W: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if not FDragging then
  begin
    if FAllowResize and (DividerAt(X) >= 0) then Cursor := crSizeWE else Cursor := crDefault;
    Exit;
  end;
  Left := 0;
  for I := 0 to FResizing - 1 do Inc(Left, GetWidth(I));
  W := X - Left;
  if W < FMinWidth then W := FMinWidth;
  if W <> GetWidth(FResizing) then
  begin
    SetWidth(FResizing, W);
    Sizing(FResizing, W);
  end;
end;
procedure THeader.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if not FDragging or (Button <> mbLeft) then Exit;
  FDragging := False;
  MouseCapture := False;
  Sized(FResizing, GetWidth(FResizing));
  FResizing := -1;
end;
procedure THeader.Sizing(ASection, AWidth: Integer);
begin if Assigned(FOnSizing) then FOnSizing(Self, ASection, AWidth); end;
procedure THeader.Sized(ASection, AWidth: Integer);
begin if Assigned(FOnSized) then FOnSized(Self, ASection, AWidth); end;
end.
