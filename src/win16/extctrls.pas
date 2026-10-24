{ SPDX-License-Identifier: GPL-2.0-or-later
  Image, timer, panel, notebook and header subset; not the complete Delphi ExtCtrls framework. }
unit ExtCtrls;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This ExtCtrls subset requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, Controls, control_base, native_notebook, native_header, native_bevel;
type
  TBevel = native_bevel.TBevel;
  TBevelStyle = native_bevel.TBevelStyle;
  TBevelShape = native_bevel.TBevelShape;
  TNotebook = native_notebook.TNotebook;
  TPage = native_notebook.TPage;
  THeader = native_header.THeader;
  TSectionEvent = native_header.TSectionEvent;
  TImage = class(TGraphicControl)
  private
    FPicture: TPicture;
    FStretch, FCenter, FAutoSize: Boolean;
    function GetPictureCanvas: TCanvas;
    procedure SetPicture(Value: TPicture);
    procedure SetStretch(Value: Boolean);
    procedure SetCenter(Value: Boolean);
    procedure SetAutoSize(Value: Boolean);
    procedure PictureChanged(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Canvas: TCanvas read GetPictureCanvas;
  published
    property Picture: TPicture read FPicture write SetPicture;
    property Stretch: Boolean read FStretch write SetStretch default False;
    property Center: Boolean read FCenter write SetCenter default False;
    property AutoSize: Boolean read FAutoSize write SetAutoSize default False;
    property Color;
    property Visible;
  end;
  { Delphi 1 timer: a WM_TIMER on a utility window, running while Enabled,
    Interval <> 0 and OnTimer is assigned. }
  TTimer = class(TComponent)
  private
    FEnabled: Boolean;
    FInterval: Word;
    FOnTimer: TNotifyEvent;
    FWindow: HWND;
    procedure SetEnabled(Value: Boolean);
    procedure SetInterval(Value: Word);
    procedure SetOnTimer(Value: TNotifyEvent);
    procedure UpdateTimer;
    procedure WndProc(var Msg: TMessage);
  protected
    procedure Timer; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Interval: Word read FInterval write SetInterval default 1000;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
  end;
  TPanelBevel = (bvNone, bvLowered, bvRaised);
  TBevelWidth = 1..MaxInt;
  TBorderWidth = 0..MaxInt;
  { Delphi 1 panel: outer bevel, BorderWidth gap, inner bevel, then the
    caption; aligned children stay inside all three. }
  TCustomPanel = class(TCustomControl)
  private
    FAlignment: TAlignment;
    FBevelInner, FBevelOuter: TPanelBevel;
    FBevelWidth: TBevelWidth;
    FBorderWidth: TBorderWidth;
    FBorderStyle: TBorderStyle;
    FCaption: string;
    FLocked: Boolean;
    FClicked: Boolean;
    FOnResize, FOnClick, FOnDblClick: TNotifyEvent;
    procedure SetAlignment(Value: TAlignment);
    procedure SetBevelInner(Value: TPanelBevel);
    procedure SetBevelOuter(Value: TPanelBevel);
    procedure SetBevelWidth(Value: TBevelWidth);
    procedure SetBorderWidth(Value: TBorderWidth);
    procedure SetBorderStyle(Value: TBorderStyle);
    procedure SetCaption(const Value: string);
    procedure WMSize(var Message: TMessage); message WM_SIZE;
  protected
    procedure AlignControls(AControl: TControl; var Rect: TRect); override;
    procedure Paint; override;
    procedure Resize; virtual;
    { As Delphi's csClickEvents: a left press released inside ClientRect. }
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Click; virtual;
    procedure DblClick; virtual;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
    property Alignment: TAlignment read FAlignment write SetAlignment default taCenter;
    property BevelInner: TPanelBevel read FBevelInner write SetBevelInner default bvNone;
    property BevelOuter: TPanelBevel read FBevelOuter write SetBevelOuter default bvRaised;
    property BevelWidth: TBevelWidth read FBevelWidth write SetBevelWidth default 1;
    property BorderWidth: TBorderWidth read FBorderWidth write SetBorderWidth default 0;
    { bsSingle adds WS_BORDER; it cannot change once the window exists. }
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsNone;
    property Caption: string read FCaption write SetCaption;
    { Only meaningful for OLE in-place activation; kept for DFMs. }
    property Locked: Boolean read FLocked write FLocked default False;
    property OnResize: TNotifyEvent read FOnResize write FOnResize;
  public
    constructor Create(AOwner: TComponent); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    property Color default clBtnFace;
  end;
  TPanel = class(TCustomPanel)
  published
    property Align;
    property Alignment;
    property BevelInner;
    property BevelOuter;
    property BevelWidth;
    property BorderWidth;
    property BorderStyle;
    property Enabled;
    property Caption;
    property Color;
    property Ctl3D;
    property Font;
    property Locked;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
  end;
{ Delphi 1 bevel: Width nested frames, top/left in TopColor; Rect shrinks by Width. }
const
  bsLowered = native_bevel.bsLowered; bsRaised = native_bevel.bsRaised;
  bsBox = native_bevel.bsBox; bsFrame = native_bevel.bsFrame;
  bsTopLine = native_bevel.bsTopLine; bsBottomLine = native_bevel.bsBottomLine;
  bsLeftLine = native_bevel.bsLeftLine; bsRightLine = native_bevel.bsRightLine;
procedure Frame3D(Canvas: TCanvas; var Rect: TRect; TopColor, BottomColor: TColor;
  Width: Integer);
implementation
uses SysUtils, WinProcs, native_window, Forms;
constructor TImage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPicture := TPicture.Create; FPicture.OnChange := PictureChanged;
  SetBounds(0, 0, 105, 105);
end;
destructor TImage.Destroy;
begin
  if FPicture <> nil then begin FPicture.OnChange := nil; FPicture.Free; end;
  inherited Destroy;
end;
procedure TImage.SetPicture(Value: TPicture);
begin FPicture.Assign(Value); end;
function TImage.GetPictureCanvas: TCanvas;
begin
  if FPicture.Graphic = nil then FPicture.Bitmap.SetSize(Width, Height);
  if not (FPicture.Graphic is TBitmap) then
    raise ENativeWindowError.Create('Image canvas requires a bitmap picture');
  Result := FPicture.Bitmap.Canvas;
end;
procedure TImage.SetStretch(Value: Boolean);
begin if Value <> FStretch then begin FStretch := Value; Invalidate; end; end;
procedure TImage.SetCenter(Value: Boolean);
begin if Value <> FCenter then begin FCenter := Value; Invalidate; end; end;
procedure TImage.SetAutoSize(Value: Boolean);
begin
  if Value = FAutoSize then Exit;
  if Value and not FPicture.Empty then SetBounds(Left, Top, FPicture.Width, FPicture.Height);
  FAutoSize := Value; Invalidate;
end;
procedure TImage.PictureChanged(Sender: TObject);
begin
  { Picture changes are already committed before its OnChange notification. }
  Invalidate;
  if FAutoSize and not FPicture.Empty then
    SetBounds(Left, Top, FPicture.Width, FPicture.Height);
end;
procedure TImage.Paint;
var X, Y: Integer; Surface: TBitmap; Painter: TCanvas;
begin
  Painter := TGraphicControl(Self).Canvas;
  if Painter.Handle = 0 then begin Invalidate; Exit; end;
  if FPicture.Empty then Exit;
  if FStretch then
  begin
    if (FPicture.Graphic is TIcon) and
      ((Width <> FPicture.Width) or (Height <> FPicture.Height)) then
    begin
      { Win16 DrawIcon has no scaled variant. Flatten its native mask against
        this opaque image's background before scaling the temporary bitmap. }
      Surface := TBitmap.Create;
      try
        Surface.SetSize(FPicture.Width, FPicture.Height);
        Surface.Canvas.Brush.Color := Color;
        Surface.Canvas.FillRect(Rect(0, 0, Surface.Width, Surface.Height));
        Surface.Canvas.Draw(0, 0, FPicture.Graphic);
        Painter.StretchDraw(Rect(0, 0, Width, Height), Surface);
      finally Surface.Free; end;
    end
    else Painter.StretchDraw(Rect(0, 0, Width, Height), FPicture.Graphic);
  end
  else
  begin
    X := 0; Y := 0;
    if FCenter then
    begin X := (Width - FPicture.Width) div 2; Y := (Height - FPicture.Height) div 2; end;
    Painter.Draw(X, Y, FPicture.Graphic);
  end;
end;
procedure Frame3D(Canvas: TCanvas; var Rect: TRect; TopColor, BottomColor: TColor;
  Width: Integer);
begin
  Canvas.Pen.Width := 1;
  Dec(Rect.Bottom); Dec(Rect.Right);
  while Width > 0 do
  begin
    Dec(Width);
    Canvas.Pen.Color := TopColor;
    Canvas.PolyLine([Point(Rect.Left, Rect.Bottom), Point(Rect.Left, Rect.Top),
      Point(Rect.Right, Rect.Top)]);
    Canvas.Pen.Color := BottomColor;
    Canvas.PolyLine([Point(Rect.Right, Rect.Top), Point(Rect.Right, Rect.Bottom),
      Point(Rect.Left - 1, Rect.Bottom)]);
    InflateRect(Rect, -1, -1);
  end;
  Inc(Rect.Bottom); Inc(Rect.Right);
end;
{ TTimer }
constructor TTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEnabled := True;
  FInterval := 1000;
  FWindow := AllocateHWnd(WndProc);
end;
destructor TTimer.Destroy;
begin
  FEnabled := False;
  UpdateTimer;
  DeallocateHWnd(FWindow);
  inherited Destroy;
end;
procedure TTimer.UpdateTimer;
begin
  KillTimer(FWindow, 1);
  if (FInterval <> 0) and FEnabled and Assigned(FOnTimer) then
    if SetTimer(FWindow, 1, FInterval, nil) = 0 then
      raise EOutOfResources.Create('Not enough timers available');
end;
procedure TTimer.SetEnabled(Value: Boolean);
begin if Value <> FEnabled then begin FEnabled := Value; UpdateTimer; end; end;
procedure TTimer.SetInterval(Value: Word);
begin if Value <> FInterval then begin FInterval := Value; UpdateTimer; end; end;
procedure TTimer.SetOnTimer(Value: TNotifyEvent);
begin FOnTimer := Value; UpdateTimer; end;
procedure TTimer.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_TIMER then
  begin
    { As in Delphi, a failing handler is reported and the timer goes on. }
    try Timer; except Application.HandleException(Self); end;
    Msg.Result := 0;
  end
  else Msg.Result := DefWindowProc(FWindow, Msg.Msg, Msg.WParam, Msg.LParam);
end;
procedure TTimer.Timer;
begin if Assigned(FOnTimer) then FOnTimer(Self); end;
{ TCustomPanel }
constructor TCustomPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetBounds(0, 0, 185, 41);
  FAlignment := taCenter;
  FBevelOuter := bvRaised;
  FBevelWidth := 1;
  Color := clBtnFace;
end;
procedure TCustomPanel.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  if FBorderStyle = bsSingle then Style := Style or WS_BORDER;
  inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);
end;
procedure TCustomPanel.SetAlignment(Value: TAlignment);
begin if Value <> FAlignment then begin FAlignment := Value; Invalidate; end; end;
procedure TCustomPanel.SetBevelInner(Value: TPanelBevel);
begin if Value <> FBevelInner then begin FBevelInner := Value; Realign; Invalidate; end; end;
procedure TCustomPanel.SetBevelOuter(Value: TPanelBevel);
begin if Value <> FBevelOuter then begin FBevelOuter := Value; Realign; Invalidate; end; end;
procedure TCustomPanel.SetBevelWidth(Value: TBevelWidth);
begin if Value <> FBevelWidth then begin FBevelWidth := Value; Realign; Invalidate; end; end;
procedure TCustomPanel.SetBorderWidth(Value: TBorderWidth);
begin if Value <> FBorderWidth then begin FBorderWidth := Value; Realign; Invalidate; end; end;
procedure TCustomPanel.SetBorderStyle(Value: TBorderStyle);
begin
  if Value = FBorderStyle then Exit;
  if Handle <> 0 then raise ENativeWindowError.Create('Panel border cannot change while the window exists');
  FBorderStyle := Value;
end;
procedure TCustomPanel.SetCaption(const Value: string);
begin if Value <> FCaption then begin FCaption := Value; Invalidate; end; end;
procedure TCustomPanel.AlignControls(AControl: TControl; var Rect: TRect);
var BevelSize: Integer;
begin
  BevelSize := FBorderWidth;
  if FBevelOuter <> bvNone then Inc(BevelSize, FBevelWidth);
  if FBevelInner <> bvNone then Inc(BevelSize, FBevelWidth);
  InflateRect(Rect, -BevelSize, -BevelSize);
  inherited AlignControls(AControl, Rect);
end;
procedure TCustomPanel.Paint;
var Area: TRect; TopColor, BottomColor: TColor; Text: array[0..255] of Char; DC: HDC;
const Alignments: array[TAlignment] of Word = (DT_LEFT, DT_RIGHT, DT_CENTER);
  procedure Colors(Bevel: TPanelBevel);
  begin
    TopColor := clBtnHighlight; BottomColor := clBtnShadow;
    if Bevel = bvLowered then begin TopColor := clBtnShadow; BottomColor := clBtnHighlight; end;
  end;
begin
  Area := ClientRect;
  if FBevelOuter <> bvNone then
  begin
    Colors(FBevelOuter); Frame3D(Canvas, Area, TopColor, BottomColor, FBevelWidth);
  end;
  Frame3D(Canvas, Area, Color, Color, FBorderWidth);
  if FBevelInner <> bvNone then
  begin
    Colors(FBevelInner); Frame3D(Canvas, Area, TopColor, BottomColor, FBevelWidth);
  end;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(Area);
  if FCaption = '' then Exit;
  Canvas.Font := Font;
  DC := Canvas.ContextHandle;
  SetBkMode(DC, TRANSPARENT);
  DrawText(DC, StrPCopy(Text, FCaption), -1, Area,
    DT_SINGLELINE or DT_VCENTER or Alignments[FAlignment]);
end;
procedure TCustomPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    MouseCapture := True;
    if ssDouble in Shift then DblClick else FClicked := True;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;
procedure TCustomPanel.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var Area: TRect;
begin
  if Button = mbLeft then
  begin
    MouseCapture := False;
    if FClicked then
    begin
      FClicked := False;
      { Not WinProcs.PtInRect: its POINT-by-value call fails on Win16. }
      Area := ClientRect;
      if (X >= Area.Left) and (X < Area.Right) and (Y >= Area.Top) and (Y < Area.Bottom) then Click;
    end;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;
procedure TCustomPanel.Click;
begin if Assigned(FOnClick) then FOnClick(Self); end;
procedure TCustomPanel.DblClick;
begin if Assigned(FOnDblClick) then FOnDblClick(Self); end;
procedure TCustomPanel.Resize;
begin if Assigned(FOnResize) then FOnResize(Self); end;
procedure TCustomPanel.WMSize(var Message: TMessage);
begin
  inherited;
  Resize;
end;
end.
