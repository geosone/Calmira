{ SPDX-License-Identifier: GPL-2.0-or-later
  Initial windowed Controls subset for ported components, not a full VCL. }
unit Controls;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Controls adapter requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Messages, Graphics, native_input, native_cursors, control_base;
type
  TControl = control_base.TControl;
  TPoint = WinTypes.TPoint;
  TCursor = native_cursors.TCursor;
  TRect = WinTypes.TRect;
  TMouseButton = native_input.TMouseButton;
  TShiftState = native_input.TShiftState;
  TModalResult = SmallInt;
  TControlViewAction = (cvaShow, cvaHide, cvaFront, cvaBack);
  TGraphicControl = class;
  TCustomControl = class(TNativeInputWindow)
  private
    FGraphics: TList;
    FWindows: TList;
    FControls: TList;
    FParent: TCustomControl;
    FChanging: Boolean;
    FCompositing: Boolean;
    FLeft, FTop, FWidth, FHeight: Integer;
    FEnabled, FVisible: Boolean;
    FTabStop: Boolean;
    FHelpContext: LongInt;
    procedure SetHelpContext(Value: LongInt);
    function GetTabOrder: Integer;
    procedure SetTabOrder(Value: Integer);
    procedure SetTabStop(Value: Boolean);
    procedure CollectFocusControls(List: TList);
    function FindDialogKey(Key: Word): Boolean;
    function FindMnemonic(Key: Char; Root: TCustomControl): Boolean;
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetEnabled: Boolean;
    function GetVisible: Boolean;
    procedure ReadBounds;
    function GetBoundsRect: TRect;
    function GetClientRect: TRect;
    function GetClientWidth: Integer;
    function GetClientHeight: Integer;
    function GetLeft: Integer;
    function GetTop: Integer;
    procedure SetLeft(Value: Integer);
    procedure SetTop(Value: Integer);
    procedure SetBoundsRect(const Value: TRect);
    procedure SetParent(Value: TCustomControl);
    procedure SetWidth(Value: Integer);
    procedure SetHeight(Value: Integer);
    procedure SetEnabled(Value: Boolean);
    procedure SetVisible(Value: Boolean);
    function FindWindowedChild(Window: HWND): TCustomControl;
    function IsVisualChild(Child: TControl): Boolean;
    function GetControlCount: Integer;
    function GetControl(Index: Integer): TControl;
  protected
    procedure ControlOperation(Operation: TControlOperation; var Value: Boolean); override;
    procedure ChangeView(Action: TControlViewAction); virtual;
    { Model-only teardown restoration; never moves a live HWND. }
    procedure StoreBounds(const Area: TRect);
    function ControlDialogKey(Key: Word): Boolean; virtual;
    function ControlMnemonic(Key: Char): Boolean; virtual;
    function ControlCommand(Code: Word): Boolean; virtual;
    function ControlDrawItem(var Item: TDrawItemStruct): Boolean; virtual;
    { True for internal USER children (e.g. a combo box's edit) that act as Self. }
    function OwnsNativeChild(Window: HWND): Boolean; virtual;
    procedure WMCommand(var M: TWMCommand); message WM_COMMAND;
    procedure WMDrawItem(var M: TWMDrawItem); message WM_DRAWITEM;
    procedure WMGetDlgCode(var M: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure PaintOverlay; override;
    procedure WMMove(var M: TMessage); message WM_MOVE;
    procedure WMSize(var M: TMessage); message WM_SIZE;
    procedure WMNCDestroy(var M: TMessage); message WM_NCDESTROY;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    procedure CreateControl(ParentWindow: HWND);
    procedure SetBounds(X, Y, AWidth, AHeight: Integer); virtual;
    procedure Invalidate; override;
    procedure Update;
    procedure Show;
    procedure Hide;
    procedure BringToFront;
    procedure SendToBack;
    function ClientToScreen(const Position: TPoint): TPoint;
    function ScreenToClient(const Position: TPoint): TPoint;
    function FindControl(Window: HWND): TCustomControl;
    function ResolveHelpContext: LongInt;
    function FocusNext(Forward: Boolean): Boolean;
    function DispatchDialogKey(Key: Word): Boolean;
    function DispatchMnemonic(Key: Char): Boolean;
    procedure ApplyModalResult(Value: TModalResult); virtual;
    property TabStop: Boolean read FTabStop write SetTabStop;
    property HelpContext: LongInt read FHelpContext write SetHelpContext;
    property TabOrder: Integer read GetTabOrder write SetTabOrder;
    property Width: Integer read GetWidth write SetWidth;
    property Height: Integer read GetHeight write SetHeight;
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property Visible: Boolean read GetVisible write SetVisible;
    property Left: Integer read GetLeft write SetLeft;
    property Top: Integer read GetTop write SetTop;
    property BoundsRect: TRect read GetBoundsRect write SetBoundsRect;
    property ClientRect: TRect read GetClientRect;
    property ClientWidth: Integer read GetClientWidth;
    property ClientHeight: Integer read GetClientHeight;
    property Parent: TCustomControl read FParent write SetParent;
    property ControlCount: Integer read GetControlCount;
    property Controls[Index: Integer]: TControl read GetControl;
  end;
  TGraphicControl = class(TControl)
  private
    FParent: TCustomControl;
    FCanvas: TCanvas;
    FLeft, FTop, FWidth, FHeight: Integer;
    FColor: TColor;
    FVisible, FEnabled: Boolean;
    procedure SetParent(Value: TCustomControl);
    procedure SetLeft(Value: Integer);
    procedure SetTop(Value: Integer);
    procedure SetWidth(Value: Integer);
    procedure SetHeight(Value: Integer);
    procedure SetColor(Value: TColor);
    procedure SetVisible(Value: Boolean);
    procedure SetEnabled(Value: Boolean);
    function GetBoundsRect: TRect;
    function GetClientRect: TRect;
    procedure SetBoundsRect(const Value: TRect);
    procedure DirtyBounds;
    procedure PaintOn(DC: HDC);
    procedure ChangeOrder(Front: Boolean);
  protected
    procedure ControlOperation(Operation: TControlOperation; var Value: Boolean); override;
    procedure Paint; virtual;
    function DialogChar(Key: Char; Root: TCustomControl): Boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetBounds(X, Y, AWidth, AHeight: Integer); virtual;
    procedure Invalidate;
    procedure Show;
    procedure Hide;
    procedure Update;
    procedure Repaint;
    procedure BringToFront;
    procedure SendToBack;
    function ClientToScreen(const Position: TPoint): TPoint;
    function ScreenToClient(const Position: TPoint): TPoint;
    property Parent: TCustomControl read FParent write SetParent;
    property Canvas: TCanvas read FCanvas;
    property Left: Integer read FLeft write SetLeft;
    property Top: Integer read FTop write SetTop;
    property Width: Integer read FWidth write SetWidth;
    property Height: Integer read FHeight write SetHeight;
    property BoundsRect: TRect read GetBoundsRect write SetBoundsRect;
    property ClientRect: TRect read GetClientRect;
    property ClientWidth: Integer read FWidth;
    property ClientHeight: Integer read FHeight;
    property Color: TColor read FColor write SetColor;
    property Visible: Boolean read FVisible write SetVisible;
    property Enabled: Boolean read FEnabled write SetEnabled;
  end;
const
  crDefault = native_cursors.crDefault; crNone = native_cursors.crNone;
  crArrow = native_cursors.crArrow; crCross = native_cursors.crCross;
  crIBeam = native_cursors.crIBeam; crSize = native_cursors.crSize;
  crSizeNESW = native_cursors.crSizeNESW; crSizeNS = native_cursors.crSizeNS;
  crSizeNWSE = native_cursors.crSizeNWSE; crSizeWE = native_cursors.crSizeWE;
  crUpArrow = native_cursors.crUpArrow; crHourGlass = native_cursors.crHourGlass;
  crDrag = native_cursors.crDrag; crNoDrop = native_cursors.crNoDrop;
  crHSplit = native_cursors.crHSplit; crVSplit = native_cursors.crVSplit;
  crMultiDrag = native_cursors.crMultiDrag; crSQLWait = native_cursors.crSQLWait;
  mrNone = 0; mrOK = 1; mrCancel = 2; mrAbort = 3; mrRetry = 4;
  mrIgnore = 5; mrYes = 6; mrNo = 7; mrAll = 8;
  mbLeft = native_input.mbLeft; mbRight = native_input.mbRight; mbMiddle = native_input.mbMiddle;
  ssShift = native_input.ssShift; ssCtrl = native_input.ssCtrl; ssAlt = native_input.ssAlt;
  ssLeft = native_input.ssLeft; ssRight = native_input.ssRight;
  ssMiddle = native_input.ssMiddle; ssDouble = native_input.ssDouble;
function Point(X, Y: Integer): TPoint;
function PtInRect(const Area: TRect; const Position: TPoint): Boolean;
implementation
uses WinProcs, native_window;
function TranslatePosition(const Position, Origin: TPoint; Inverse: Boolean): TPoint;
var X, Y: LongInt;
begin
  if Inverse then
  begin X := LongInt(Position.X) - Origin.X; Y := LongInt(Position.Y) - Origin.Y; end
  else
  begin X := LongInt(Position.X) + Origin.X; Y := LongInt(Position.Y) + Origin.Y; end;
  if (X < -32768) or (X > 32767) or (Y < -32768) or (Y > 32767) then
    raise ENativeWindowError.Create('Coordinate overflow');
  Result.X := X; Result.Y := Y;
end;
function Point(X, Y: Integer): TPoint;
begin Result.X := X; Result.Y := Y; end;
function PtInRect(const Area: TRect; const Position: TPoint): Boolean;
begin
  { Avoid the failing foreign POINT-by-value call; right/bottom are exclusive. }
  Result := (Position.X >= Area.Left) and (Position.X < Area.Right) and
    (Position.Y >= Area.Top) and (Position.Y < Area.Bottom);
end;
constructor TCustomControl.Create(AOwner: TComponent);
begin inherited Create(AOwner); FEnabled := True; FVisible := True; end;
procedure TCustomControl.SetHelpContext(Value: LongInt);
begin
  if Value < 0 then raise ENativeWindowError.Create('Invalid help context');
  FHelpContext := Value;
end;
function TCustomControl.ResolveHelpContext: LongInt;
var Current: TCustomControl;
begin
  Result := 0; Current := Self;
  while Current <> nil do
  begin
    if Current.FHelpContext <> 0 then begin Result := Current.FHelpContext; Exit; end;
    Current := Current.FParent;
  end;
end;
function TCustomControl.GetTabOrder: Integer;
begin
  Result := 0;
  if FParent <> nil then Result := FParent.FWindows.IndexOf(Self);
end;
procedure TCustomControl.SetTabOrder(Value: Integer);
var List: TList; Current: TCustomControl;
begin
  if Value < 0 then raise ENativeWindowError.Create('Negative tab order');
  if FParent = nil then Exit;
  Current := Self;
  while Current <> nil do
  begin
    if Current.FChanging or Current.Painting or Current.FCompositing or
      (Current.Canvas.Handle <> 0) then
      raise ENativeWindowError.Create('Cannot reorder while drawing or changing');
    Current := Current.FParent;
  end;
  List := FParent.FWindows;
  if Value >= List.Count then Value := List.Count - 1;
  List.Move(List.IndexOf(Self), Value);
end;
procedure TCustomControl.SetTabStop(Value: Boolean);
var Style: LongInt;
begin
  FTabStop := Value;
  if Handle = 0 then Exit;
  Style := GetWindowLong(Handle, GWL_STYLE) and not LongInt(WS_TABSTOP);
  if Value then Style := Style or LongInt(WS_TABSTOP);
  SetWindowLong(Handle, GWL_STYLE, Style);
end;
function TCustomControl.OwnsNativeChild(Window: HWND): Boolean;
begin Result := False; end;
function TCustomControl.FindControl(Window: HWND): TCustomControl;
var I: Integer; Child: TCustomControl;
begin
  Result := nil;
  if (Handle = 0) or (Window = 0) then Exit;
  if (Window = Handle) or OwnsNativeChild(Window) then begin Result := Self; Exit; end;
  if FWindows = nil then Exit;
  for I := 0 to FWindows.Count - 1 do
  begin
    Child := TCustomControl(FWindows[I]);
    if FindWindowedChild(Child.Handle) <> Child then Continue;
    Result := Child.FindControl(Window);
    if Result <> nil then Exit;
  end;
end;
procedure TCustomControl.CollectFocusControls(List: TList);
var I: Integer; Child: TCustomControl;
begin
  if not CanFocus or (FWindows = nil) then Exit;
  for I := 0 to FWindows.Count - 1 do
  begin
    Child := TCustomControl(FWindows[I]);
    if (FindWindowedChild(Child.Handle) <> Child) or not Child.CanFocus then Continue;
    List.Add(Child);
    Child.CollectFocusControls(List);
  end;
end;
function TCustomControl.FocusNext(Forward: Boolean): Boolean;
var List: TList; Index, I: Integer; Candidate: TCustomControl;
begin
  Result := False; List := TList.Create;
  try
    CollectFocusControls(List);
    if List.Count = 0 then Exit;
    Index := List.IndexOf(FindControl(GetFocus));
    for I := 1 to List.Count do
    begin
      if Forward then begin Inc(Index); if Index >= List.Count then Index := 0; end
      else begin Dec(Index); if Index < 0 then Index := List.Count - 1; end;
      Candidate := TCustomControl(List[Index]);
      if not Candidate.TabStop then Continue;
      Candidate.SetFocus;
      Result := Candidate.Focused;
      Exit;
    end;
  finally List.Free; end;
end;
function TCustomControl.ControlDialogKey(Key: Word): Boolean;
begin Result := False; end;
function TCustomControl.ControlMnemonic(Key: Char): Boolean;
begin Result := False; end;
function TGraphicControl.DialogChar(Key: Char; Root: TCustomControl): Boolean;
begin Result := False; end;
function TCustomControl.FindMnemonic(Key: Char; Root: TCustomControl): Boolean;
var I: Integer; Child: TCustomControl; Graphic: TGraphicControl;
begin
  Result := False;
  if not CanFocus then Exit;
  if FGraphics <> nil then
    for I := 0 to FGraphics.Count - 1 do
    begin
      Graphic := TGraphicControl(FGraphics[I]);
      if (Graphic.Parent = Self) and Graphic.Visible and Graphic.Enabled then
        if Graphic.DialogChar(Key, Root) then begin Result := True; Exit; end;
    end;
  if ControlMnemonic(Key) then begin Result := True; Exit; end;
  if FWindows <> nil then
    for I := 0 to FWindows.Count - 1 do
    begin
      Child := TCustomControl(FWindows[I]);
      if FindWindowedChild(Child.Handle) = Child then
        if Child.FindMnemonic(Key, Root) then begin Result := True; Exit; end;
    end;
end;
function TCustomControl.DispatchMnemonic(Key: Char): Boolean;
begin
  Result := False;
  if Key <> #0 then Result := FindMnemonic(Key, Self);
end;
procedure TCustomControl.ApplyModalResult(Value: TModalResult);
begin if FParent <> nil then FParent.ApplyModalResult(Value); end;
function TCustomControl.FindDialogKey(Key: Word): Boolean;
var I: Integer; Child: TCustomControl;
begin
  Result := False;
  if not CanFocus then Exit;
  if ControlDialogKey(Key) then begin Result := True; Exit; end;
  if FWindows = nil then Exit;
  for I := 0 to FWindows.Count - 1 do
  begin
    Child := TCustomControl(FWindows[I]);
    if FindWindowedChild(Child.Handle) <> Child then Continue;
    if Child.FindDialogKey(Key) then begin Result := True; Exit; end;
  end;
end;
function TCustomControl.DispatchDialogKey(Key: Word): Boolean;
var Current: TCustomControl;
begin
  Result := False;
  if not CanFocus then Exit;
  Current := FindControl(GetFocus);
  if (Current <> nil) and Current.CanFocus then
    if Current.ControlDialogKey(Key) then begin Result := True; Exit; end;
  Result := FindDialogKey(Key);
end;
destructor TCustomControl.Destroy;
begin
  if FParent <> nil then
  begin FParent.FWindows.Remove(Self); FParent.FControls.Remove(Self); end;
  FParent := nil;
  if FWindows <> nil then
  begin
    while FWindows.Count <> 0 do TCustomControl(FWindows[FWindows.Count - 1]).Parent := nil;
    FWindows.Free; FWindows := nil;
  end;
  if FGraphics <> nil then
  begin
    while FGraphics.Count <> 0 do TGraphicControl(FGraphics[FGraphics.Count - 1]).Parent := nil;
    FGraphics.Free; FGraphics := nil;
  end;
  FControls.Free; FControls := nil;
  inherited Destroy;
end;
function TCustomControl.IsVisualChild(Child: TControl): Boolean;
begin
  { Allocation is staged before USER callbacks. Only the current model parent
    exposes a staged entry; rollback retains the old parent's original slot. }
  if Child is TCustomControl then Result := TCustomControl(Child).FParent = Self
  else if Child is TGraphicControl then Result := TGraphicControl(Child).FParent = Self
  else Result := False;
end;
function TCustomControl.GetControlCount: Integer;
var I: Integer;
begin
  Result := 0;
  if FControls <> nil then
    for I := 0 to FControls.Count - 1 do
      if IsVisualChild(TControl(FControls[I])) then Inc(Result);
end;
function TCustomControl.GetControl(Index: Integer): TControl;
var I: Integer; Child: TControl;
begin
  if (Index >= 0) and (FControls <> nil) then
    for I := 0 to FControls.Count - 1 do
    begin
      Child := TControl(FControls[I]);
      if not IsVisualChild(Child) then Continue;
      if Index = 0 then begin Result := Child; Exit; end;
      Dec(Index);
    end;
  raise ENativeWindowError.Create('Invalid control index');
end;
procedure TCustomControl.ControlOperation(Operation: TControlOperation; var Value: Boolean);
begin
  case Operation of
    coReadEnabled: Value := GetEnabled;
    coWriteEnabled: SetEnabled(Value);
    coReadVisible: Value := GetVisible;
    coWriteVisible: SetVisible(Value);
    coShow: ChangeView(cvaShow);
    coHide: ChangeView(cvaHide);
    coFront: ChangeView(cvaFront);
    coBack: ChangeView(cvaBack);
  end;
end;
procedure TCustomControl.PaintOverlay;
var I: Integer;
begin
  inherited PaintOverlay;
  if FCompositing then Exit;
  FCompositing := True;
  try
    if FGraphics <> nil then
      for I := 0 to FGraphics.Count - 1 do TGraphicControl(FGraphics[I]).PaintOn(Canvas.Handle);
  finally FCompositing := False; end;
end;
function TCustomControl.FindWindowedChild(Window: HWND): TCustomControl;
var I: Integer;
begin
  Result := nil;
  if (Window = 0) or (FWindows = nil) or not IsWindow(Window) then Exit;
  if WinProcs.GetParent(Window) <> Handle then Exit;
  for I := 0 to FWindows.Count - 1 do
    if TCustomControl(FWindows[I]).Handle = Window then
    begin Result := TCustomControl(FWindows[I]); Exit; end;
end;
function TCustomControl.ControlCommand(Code: Word): Boolean;
begin Result := False; end;
function TCustomControl.ControlDrawItem(var Item: TDrawItemStruct): Boolean;
begin Result := False; end;
procedure TCustomControl.WMCommand(var M: TWMCommand);
var Child: TCustomControl;
begin
  Child := FindWindowedChild(M.Ctl);
  if (Child <> nil) and (M.ItemID = Word(GetDlgCtrlID(M.Ctl))) and
    Child.ControlCommand(M.NotifyCode) then M.Result := 0
  else DefaultHandler(M);
end;
procedure TCustomControl.WMDrawItem(var M: TWMDrawItem);
var Child: TCustomControl; Previous: Boolean; Handled: Boolean;
begin
  if M.DrawItemStruct <> nil then
  begin
    Child := FindWindowedChild(M.DrawItemStruct^.hwndItem);
    if Child <> nil then
    begin
      Previous := FCompositing; FCompositing := True;
      try Handled := Child.ControlDrawItem(M.DrawItemStruct^);
      finally FCompositing := Previous; end;
      if Handled then begin M.Result := 1; Exit; end;
    end;
  end;
  DefaultHandler(M);
end;
procedure TCustomControl.CreateControl(ParentWindow: HWND);
var Style: DWORD;
begin
  Style := WS_CHILD or WS_CLIPSIBLINGS or WS_CLIPCHILDREN;
  if FTabStop then Style := Style or WS_TABSTOP;
  if FVisible then Style := Style or WS_VISIBLE;
  if not FEnabled then Style := Style or WS_DISABLED;
  CreateHandle(ParentWindow, '', Style, FLeft, FTop, FWidth, FHeight);
end;
procedure TCustomControl.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
var I: Integer;
begin
  if FChanging then raise ENativeWindowError.Create('Control lifecycle reentry');
  if (FParent <> nil) and ((Parent = 0) or (Parent <> FParent.Handle)) then
    raise ENativeWindowError.Create('Managed parent handle mismatch');
  if (Width < 0) or (Height < 0) or (LongInt(X) + Width > 32767) or
    (LongInt(Y) + Height > 32767) then raise ENativeWindowError.Create('Invalid control bounds');
  FChanging := True;
  try
    inherited CreateHandle(Parent, Caption, Style, X, Y, Width, Height);
    try
      ReadBounds;
      if FWindows <> nil then
        for I := 0 to FWindows.Count - 1 do
          if TCustomControl(FWindows[I]).Handle = 0 then
            TCustomControl(FWindows[I]).CreateControl(Handle);
    except DestroyHandle; raise; end;
  finally FChanging := False; end;
end;
procedure TCustomControl.Invalidate;
begin if Handle <> 0 then inherited Invalidate; end;
procedure TCustomControl.Update;
begin
  if Handle = 0 then Exit;
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  UpdateWindow(Handle);
end;
procedure TCustomControl.Show;
begin ChangeView(cvaShow); end;
procedure TCustomControl.Hide;
begin ChangeView(cvaHide); end;
procedure TCustomControl.BringToFront;
begin ChangeView(cvaFront); end;
procedure TCustomControl.SendToBack;
begin ChangeView(cvaBack); end;
procedure TCustomControl.ChangeView(Action: TControlViewAction);
var Current, Order: HWND;
begin
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  if FParent <> nil then
    if FParent.FChanging or FParent.Painting or FParent.FCompositing or (FParent.Canvas.Handle <> 0) then
      raise ENativeWindowError.Create('Control lifecycle reentry');
  FChanging := True;
  try
    case Action of
      cvaShow: SetVisible(True);
      cvaHide:
        begin
          if Handle <> 0 then
          begin
            Current := GetCapture;
            if (Current = Handle) or IsChild(Handle, Current) then ReleaseCapture;
            Current := GetFocus;
            if (Current = Handle) or IsChild(Handle, Current) then WinProcs.SetFocus(0);
          end;
          SetVisible(False);
        end;
      cvaFront, cvaBack:
        if Handle <> 0 then
        begin
          if Action = cvaFront then Order := HWND_TOP else Order := HWND_BOTTOM;
          if not SetWindowPos(Handle, Order, 0, 0, 0, 0,
            SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE) then
            raise ENativeWindowError.Create('Cannot reorder control');
        end;
    end;
  finally FChanging := False; end;
end;
function TCustomControl.GetWidth: Integer;
begin
  ReadBounds; Result := FWidth;
end;
function TCustomControl.GetHeight: Integer;
begin
  ReadBounds; Result := FHeight;
end;
procedure TCustomControl.SetWidth(Value: Integer);
begin
  SetBounds(GetLeft, GetTop, Value, GetHeight);
end;
procedure TCustomControl.SetHeight(Value: Integer);
begin
  SetBounds(GetLeft, GetTop, GetWidth, Value);
end;
procedure TCustomControl.ReadBounds;
var Area: TRect; Origin: TPoint; NativeParent: HWND;
begin
  if Handle = 0 then Exit;
  GetWindowRect(Handle, Area); Origin.X := Area.Left; Origin.Y := Area.Top;
  NativeParent := WinProcs.GetParent(Handle);
  if (DWORD(GetWindowLong(Handle, GWL_STYLE)) and WS_CHILD <> 0) and (NativeParent <> 0) then
    WinProcs.ScreenToClient(NativeParent, Origin);
  FLeft := Origin.X; FTop := Origin.Y;
  FWidth := Area.Right - Area.Left; FHeight := Area.Bottom - Area.Top;
end;
function TCustomControl.GetBoundsRect: TRect;
begin
  ReadBounds; Result.Left := FLeft; Result.Top := FTop;
  Result.Right := FLeft + FWidth; Result.Bottom := FTop + FHeight;
end;
function TCustomControl.GetClientRect: TRect;
var Area: TRect;
begin
  Area.Left := 0; Area.Top := 0; Area.Right := FWidth; Area.Bottom := FHeight;
  if Handle <> 0 then WinProcs.GetClientRect(Handle, Area);
  Result := Area;
end;
function TCustomControl.ClientToScreen(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if (Handle = 0) or not IsWindow(Handle) then
    raise ENativeWindowError.Create('Control has no window');
  Origin := Point(0, 0); WinProcs.ClientToScreen(Handle, Origin);
  Result := TranslatePosition(Position, Origin, False);
end;
function TCustomControl.ScreenToClient(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if (Handle = 0) or not IsWindow(Handle) then
    raise ENativeWindowError.Create('Control has no window');
  Origin := Point(0, 0); WinProcs.ClientToScreen(Handle, Origin);
  Result := TranslatePosition(Position, Origin, True);
end;
function TCustomControl.GetLeft: Integer;
begin ReadBounds; Result := FLeft; end;
function TCustomControl.GetClientWidth: Integer;
var Area: TRect;
begin Area := GetClientRect; Result := Area.Right - Area.Left; end;
function TCustomControl.GetClientHeight: Integer;
var Area: TRect;
begin Area := GetClientRect; Result := Area.Bottom - Area.Top; end;
function TCustomControl.GetTop: Integer;
begin ReadBounds; Result := FTop; end;
procedure TCustomControl.SetLeft(Value: Integer);
begin SetBounds(Value, GetTop, GetWidth, GetHeight); end;
procedure TCustomControl.SetTop(Value: Integer);
begin SetBounds(GetLeft, Value, GetWidth, GetHeight); end;
procedure TCustomControl.SetBoundsRect(const Value: TRect);
var W, H: LongInt;
begin
  W := LongInt(Value.Right) - Value.Left; H := LongInt(Value.Bottom) - Value.Top;
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then
    raise ENativeWindowError.Create('Invalid control bounds');
  SetBounds(Value.Left, Value.Top, W, H);
end;
procedure TCustomControl.SetBounds(X, Y, AWidth, AHeight: Integer);
begin
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  if (AWidth < 0) or (AHeight < 0) or (LongInt(X) + AWidth > 32767) or
    (LongInt(Y) + AHeight > 32767) then raise ENativeWindowError.Create('Invalid control bounds');
  FChanging := True;
  try
    if Handle <> 0 then
      if not SetWindowPos(Handle, 0, X, Y, AWidth, AHeight, SWP_NOZORDER or SWP_NOACTIVATE) then
        raise ENativeWindowError.Create('Cannot resize control');
    FLeft := X; FTop := Y; FWidth := AWidth; FHeight := AHeight;
  finally FChanging := False; end;
  Invalidate;
end;
procedure TCustomControl.WMMove(var M: TMessage);
begin ReadBounds; DefaultHandler(M); end;
procedure TCustomControl.WMSize(var M: TMessage);
begin ReadBounds; DefaultHandler(M); Invalidate; end;
procedure TCustomControl.WMNCDestroy(var M: TMessage);
begin ReadBounds; DefaultHandler(M); end;
procedure TCustomControl.StoreBounds(const Area: TRect);
begin
  FLeft := Area.Left; FTop := Area.Top;
  FWidth := Area.Right - Area.Left; FHeight := Area.Bottom - Area.Top;
end;
procedure TCustomControl.SetParent(Value: TCustomControl);
var Current, Previous: TCustomControl; PreviousWindow: HWND;
  X, Y, W, H: Integer;
begin
  if Value = FParent then Exit;
  if FChanging or Painting or FCompositing or (Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  if (FParent <> nil) and (FParent.FChanging or FParent.Painting or FParent.FCompositing) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  Current := Value;
  while Current <> nil do
  begin
    if Current = Self then raise ENativeWindowError.Create('Control parent cycle');
    if Current.FChanging or Current.Painting or Current.FCompositing then
      raise ENativeWindowError.Create('Control lifecycle reentry');
    Current := Current.FParent;
  end;
  if (Handle <> 0) and (DWORD(GetWindowLong(Handle, GWL_STYLE)) and WS_CHILD = 0) then
    raise ENativeWindowError.Create('Only child HWNDs can be reparented');
  if (Handle <> 0) and (Value <> nil) and (Value.Handle <> 0) then
    if IsChild(Handle, Value.Handle) then raise ENativeWindowError.Create('Native parent cycle');
  if Value <> nil then
  begin
    if Value.FWindows = nil then Value.FWindows := TList.Create;
    if Value.FControls = nil then Value.FControls := TList.Create;
    Value.FControls.Add(Self);
    try Value.FWindows.Add(Self);
    except Value.FControls.Remove(Self); raise; end;
  end;
  Previous := FParent;
  try
    FChanging := True;
    try
      ReadBounds; X := FLeft; Y := FTop; W := FWidth; H := FHeight;
      if Handle <> 0 then
      begin
        if (GetCapture = Handle) or IsChild(Handle, GetCapture) then ReleaseCapture;
        if (GetFocus = Handle) or IsChild(Handle, GetFocus) then WinProcs.SetFocus(0);
        if (Value = nil) or (Value.Handle = 0) then DestroyHandle
        else
        begin
          PreviousWindow := WinProcs.GetParent(Handle);
          WinProcs.SetParent(Handle, Value.Handle);
          if WinProcs.GetParent(Handle) <> Value.Handle then
            raise ENativeWindowError.Create('Cannot change native parent');
          if not SetWindowPos(Handle, 0, X, Y, W, H, SWP_NOZORDER or SWP_NOACTIVATE) then
          begin
            WinProcs.SetParent(Handle, PreviousWindow);
            if (WinProcs.GetParent(Handle) <> PreviousWindow) or
              not SetWindowPos(Handle, 0, X, Y, W, H, SWP_NOZORDER or SWP_NOACTIVATE) then
            begin
              DestroyHandle;
              FLeft := X; FTop := Y; FWidth := W; FHeight := H;
              raise ENativeWindowError.Create('Native reparent rollback failed; HWND detached');
            end;
            raise ENativeWindowError.Create('Cannot position reparented control');
          end;
        end;
      end;
      FParent := Value;
    finally FChanging := False; end;
    try
      if (Handle = 0) and (Value <> nil) and (Value.Handle <> 0) then CreateControl(Value.Handle);
    except FParent := Previous; raise; end;
    if Previous <> nil then
    begin Previous.FWindows.Remove(Self); Previous.FControls.Remove(Self); end;
  except
    if Value <> nil then
    begin Value.FWindows.Remove(Self); Value.FControls.Remove(Self); end;
    raise;
  end;
  Invalidate;
end;
function TCustomControl.GetEnabled: Boolean;
begin if Handle = 0 then Result := FEnabled else Result := IsWindowEnabled(Handle); end;
function TCustomControl.GetVisible: Boolean;
begin
  if Handle = 0 then Result := FVisible
  else Result := DWORD(GetWindowLong(Handle, GWL_STYLE)) and WS_VISIBLE <> 0;
end;
procedure TCustomControl.SetEnabled(Value: Boolean);
begin
  FEnabled := Value;
  if not Value then MouseCapture := False;
  if Handle <> 0 then EnableWindow(Handle, Value);
end;
procedure TCustomControl.SetVisible(Value: Boolean);
begin
  FVisible := Value;
  if not Value then MouseCapture := False;
  if Handle = 0 then Exit;
  if Value then ShowWindow(Handle, SW_SHOWNOACTIVATE) else ShowWindow(Handle, SW_HIDE);
end;
procedure TCustomControl.WMGetDlgCode(var M: TWMGetDlgCode);
begin DefaultHandler(M); end;

constructor TGraphicControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); FCanvas := TCanvas.Create;
  FVisible := True; FEnabled := True; FColor := clBtnFace;
end;
procedure TGraphicControl.ControlOperation(Operation: TControlOperation; var Value: Boolean);
begin
  case Operation of
    coReadEnabled: Value := FEnabled;
    coWriteEnabled: SetEnabled(Value);
    coReadVisible: Value := FVisible;
    coWriteVisible: SetVisible(Value);
    coShow: Show;
    coHide: Hide;
    coFront: BringToFront;
    coBack: SendToBack;
  end;
end;
destructor TGraphicControl.Destroy;
begin SetParent(nil); FCanvas.Free; inherited Destroy; end;
procedure TGraphicControl.Paint;
begin end;
function TGraphicControl.GetBoundsRect: TRect;
begin
  Result.Left := FLeft; Result.Top := FTop;
  Result.Right := FLeft + FWidth; Result.Bottom := FTop + FHeight;
end;
function TGraphicControl.GetClientRect: TRect;
begin
  Result.Left := 0; Result.Top := 0; Result.Right := FWidth; Result.Bottom := FHeight;
end;
procedure TGraphicControl.SetBoundsRect(const Value: TRect);
var W, H: LongInt;
begin
  W := LongInt(Value.Right) - Value.Left; H := LongInt(Value.Bottom) - Value.Top;
  if (W < 0) or (H < 0) or (W > 32767) or (H > 32767) then
    raise ENativeWindowError.Create('Invalid graphic bounds');
  SetBounds(Value.Left, Value.Top, W, H);
end;
function TGraphicControl.ClientToScreen(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if FParent = nil then raise ENativeWindowError.Create('Control has no window');
  Origin := FParent.ClientToScreen(Point(FLeft, FTop));
  Result := TranslatePosition(Position, Origin, False);
end;
function TGraphicControl.ScreenToClient(const Position: TPoint): TPoint;
var Origin: TPoint;
begin
  if FParent = nil then raise ENativeWindowError.Create('Control has no window');
  Origin := FParent.ClientToScreen(Point(FLeft, FTop));
  Result := TranslatePosition(Position, Origin, True);
end;
procedure TGraphicControl.DirtyBounds;
begin
  if (FParent <> nil) and (FParent.Handle <> 0) then FParent.InvalidateArea(GetBoundsRect);
end;
procedure TGraphicControl.Invalidate;
begin if FVisible then DirtyBounds; end;
procedure TGraphicControl.Show;
begin Visible := True; end;
procedure TGraphicControl.Hide;
begin Visible := False; end;
procedure TGraphicControl.ChangeOrder(Front: Boolean);
var Index, Target: Integer;
begin
  if FParent = nil then Exit;
  if (FCanvas.Handle <> 0) or FParent.FChanging or FParent.Painting or
    FParent.FCompositing or (FParent.Canvas.Handle <> 0) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  Index := FParent.FGraphics.IndexOf(Self);
  if Front then Target := FParent.FGraphics.Count - 1 else Target := 0;
  if Index = Target then Exit;
  FParent.FGraphics.Move(Index, Target); DirtyBounds;
end;
procedure TGraphicControl.BringToFront;
begin ChangeOrder(True); end;
procedure TGraphicControl.SendToBack;
begin ChangeOrder(False); end;
procedure TGraphicControl.Update;
begin
  if (FParent = nil) or (FParent.Handle = 0) then Exit;
  if FCanvas.Handle <> 0 then
    raise ENativeWindowError.Create('Cannot update during graphic paint');
  FParent.Update;
end;
procedure TGraphicControl.Repaint;
begin Invalidate; Update; end;
procedure TGraphicControl.SetParent(Value: TCustomControl);
var Previous: TCustomControl;
begin
  if Value = FParent then Exit;
  if (FCanvas.Handle <> 0) or
    ((FParent <> nil) and (FParent.FChanging or FParent.Painting or
      FParent.FCompositing or (FParent.Canvas.Handle <> 0))) or
    ((Value <> nil) and (Value.FChanging or Value.Painting or
      Value.FCompositing or (Value.Canvas.Handle <> 0))) then
    raise ENativeWindowError.Create('Cannot reparent during paint');
  if Value <> nil then
  begin
    if Value.FGraphics = nil then Value.FGraphics := TList.Create;
    if Value.FControls = nil then Value.FControls := TList.Create;
    Value.FControls.Add(Self);
    try Value.FGraphics.Add(Self);
    except Value.FControls.Remove(Self); raise; end;
  end;
  Previous := FParent;
  try DirtyBounds;
  except
    if Value <> nil then
    begin Value.FGraphics.Remove(Self); Value.FControls.Remove(Self); end;
    raise;
  end;
  FParent := Value;
  if Previous <> nil then
  begin Previous.FGraphics.Remove(Self); Previous.FControls.Remove(Self); end;
  Invalidate;
end;
procedure TGraphicControl.SetBounds(X, Y, AWidth, AHeight: Integer);
begin
  if (AWidth < 0) or (AHeight < 0) or
    (LongInt(X) + AWidth > 32767) or (LongInt(Y) + AHeight > 32767) then
    raise ENativeWindowError.Create('Invalid graphic bounds');
  if (X = FLeft) and (Y = FTop) and (AWidth = FWidth) and (AHeight = FHeight) then Exit;
  if (FCanvas <> nil) and (FCanvas.Handle <> 0) then
    raise ENativeWindowError.Create('Cannot resize during graphic paint');
  DirtyBounds; FLeft := X; FTop := Y; FWidth := AWidth; FHeight := AHeight; Invalidate;
end;
procedure TGraphicControl.SetLeft(Value: Integer);
begin SetBounds(Value, FTop, FWidth, FHeight); end;
procedure TGraphicControl.SetTop(Value: Integer);
begin SetBounds(FLeft, Value, FWidth, FHeight); end;
procedure TGraphicControl.SetWidth(Value: Integer);
begin SetBounds(FLeft, FTop, Value, FHeight); end;
procedure TGraphicControl.SetHeight(Value: Integer);
begin SetBounds(FLeft, FTop, FWidth, Value); end;
procedure TGraphicControl.SetColor(Value: TColor);
begin if Value <> FColor then begin FColor := Value; Invalidate; end; end;
procedure TGraphicControl.SetVisible(Value: Boolean);
begin
  if Value = FVisible then Exit;
  DirtyBounds; FVisible := Value; Invalidate;
end;
procedure TGraphicControl.SetEnabled(Value: Boolean);
begin
  if Value = FEnabled then Exit;
  if (FCanvas.Handle <> 0) or ((FParent <> nil) and
    (FParent.FChanging or FParent.Painting or FParent.FCompositing or
    (FParent.Canvas.Handle <> 0))) then
    raise ENativeWindowError.Create('Control lifecycle reentry');
  FEnabled := Value; Invalidate;
end;
procedure TGraphicControl.PaintOn(DC: HDC);
var State, Clip: SmallInt; Background: HBRUSH; Area: TRect; Surface: TBitmap;
begin
  if not FVisible or (FWidth = 0) or (FHeight = 0) then Exit;
  State := SaveDC(DC);
  if State = 0 then raise ENativeWindowError.Create('Cannot save graphic DC');
  try
    OffsetViewportOrg(DC, FLeft, FTop);
    Clip := IntersectClipRect(DC, 0, 0, FWidth, FHeight);
    if Clip = 0 then raise ENativeWindowError.Create('Cannot clip graphic DC');
    if Clip = NULLREGION then Exit;
    Area.Left := 0; Area.Top := 0; Area.Right := FWidth; Area.Bottom := FHeight;
    { Flood fills require full geometry, even when USER requests a tiny fragment. }
    Surface := TBitmap.Create;
    try
      Surface.SetSize(FWidth, FHeight);
      Background := CreateSolidBrush(ColorToRGB(FColor));
      if Background = 0 then raise ENativeWindowError.Create('Cannot create graphic brush');
      try
        if WinProcs.FillRect(Surface.Canvas.Handle, Area, Background) = 0 then
          raise ENativeWindowError.Create('Cannot fill graphic background');
      finally DeleteObject(Background); end;
      FCanvas.Handle := Surface.Canvas.Handle;
      try Paint; finally FCanvas.Handle := 0; end;
      if not BitBlt(DC, 0, 0, FWidth, FHeight, Surface.Canvas.Handle, 0, 0, SRCCOPY) then
        raise ENativeWindowError.Create('Cannot composite graphic pixels');
    finally Surface.Free; end;
  finally RestoreDC(DC, State); end;
end;
end.
