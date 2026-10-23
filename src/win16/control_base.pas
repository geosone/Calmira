{ SPDX-License-Identifier: GPL-2.0-or-later
  Shared visual-control identity and operations; not the complete VCL TControl. }
unit control_base;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This control base requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, gdi_canvas, native_cursors;
type
  TControlOperation = (coReadEnabled, coWriteEnabled, coReadVisible,
    coWriteVisible, coShow, coHide, coFront, coBack);
  { Delphi 1 Forms types, shared here so controls need not use Forms. }
  TFormBorderStyle = (bsNone, bsSingle, bsSizeable, bsDialog);
  TBorderStyle = bsNone..bsSingle;
  TAlign = (alNone, alTop, alBottom, alLeft, alRight, alClient);
  TDragMode = (dmManual, dmAutomatic);
  TDragState = (dsDragEnter, dsDragLeave, dsDragMove);
  TDragDropEvent = procedure(Sender, Source: TObject; X, Y: Integer) of object;
  TDragOverEvent = procedure(Sender, Source: TObject; X, Y: Integer;
    State: TDragState; var Accept: Boolean) of object;
  TEndDragEvent = procedure(Sender, Target: TObject; X, Y: Integer) of object;
  TControl = class;
  { Implemented by Controls, which knows windows, graphic children and capture. }
  TDragManager = class
  public
    procedure Start(Control: TControl; Immediate: Boolean); virtual; abstract;
    procedure Finish(Drop: Boolean); virtual; abstract;
    procedure Forget(Control: TControl); virtual; abstract;
  end;
  TControl = class(TComponent)
  private
    FAlign: TAlign;
    FColor: TColor;
    FFont: TGDIFont;
    FParentColor, FParentFont, FShowHint, FParentShowHint: Boolean;
    FInheriting: Boolean;
    FHint: string;
    FDragMode: TDragMode;
    FDragCursor: TCursor;
    FOnDragDrop: TDragDropEvent;
    FOnDragOver: TDragOverEvent;
    FOnEndDrag: TEndDragEvent;
    function GetDragging: Boolean;
    function GetEnabled: Boolean;
    procedure SetEnabled(Value: Boolean);
    function GetVisible: Boolean;
    procedure SetVisible(Value: Boolean);
    procedure SetAlign(Value: TAlign);
    procedure SetColor(Value: TColor);
    procedure SetFont(Value: TGDIFont);
    procedure SetParentColor(Value: Boolean);
    procedure SetParentFont(Value: Boolean);
    procedure SetShowHint(Value: Boolean);
    procedure SetParentShowHint(Value: Boolean);
    procedure FontObjectChanged(Sender: TObject);
  protected
    { Asks the parent to lay out its aligned children again. }
    procedure RequestAlign; virtual;
    { The control whose Font/Color/ShowHint the Parent* properties follow. }
    function ParentControl: TControl; virtual;
    { Calls ParentPropertiesChanged on each child; Controls implements it. }
    procedure NotifyChildren; virtual;
    { Font changed: ApplyFont copies it to the drawing canvas, then FontChanged
      reacts (repaint, WM_SETFONT). Color changed: ColorChanged. }
    procedure ApplyFont; virtual;
    procedure FontChanged; virtual;
    procedure ColorChanged; virtual;
    { True while a value is being copied from the parent, so the Parent*
      flag that caused it stays set. }
    property Inheriting: Boolean read FInheriting write FInheriting;
    { One policy slot, rather than a virtual slot per property/view method. }
    procedure ControlOperation(Operation: TControlOperation; var Value: Boolean); virtual; abstract;
    procedure DoEndDrag(Target: TObject; X, Y: Integer); virtual;
    function GetControlBounds: TRect; virtual; abstract;
    procedure SetControlBounds(const Value: TRect); virtual; abstract;
    procedure DragOver(Source: TObject; X, Y: Integer; State: TDragState;
      var Accept: Boolean); virtual;
    property DragMode: TDragMode read FDragMode write FDragMode default dmManual;
    property DragCursor: TCursor read FDragCursor write FDragCursor default crDrag;
    property OnDragDrop: TDragDropEvent read FOnDragDrop write FOnDragDrop;
    property OnDragOver: TDragOverEvent read FOnDragOver write FOnDragOver;
    property OnEndDrag: TEndDragEvent read FOnEndDrag write FOnEndDrag;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginDrag(Immediate: Boolean);
    procedure EndDrag(Drop: Boolean);
    procedure DragDrop(Source: TObject; X, Y: Integer); virtual;
    { Re-reads the Parent* properties from ParentControl; called after
      reparenting and when the parent's values change. }
    procedure ParentPropertiesChanged; virtual;
    property Align: TAlign read FAlign write SetAlign default alNone;
    { As in Delphi, assigning Color or Font clears ParentColor/ParentFont. }
    property Color: TColor read FColor write SetColor;
    property Font: TGDIFont read FFont write SetFont;
    property ParentColor: Boolean read FParentColor write SetParentColor default True;
    property ParentFont: Boolean read FParentFont write SetParentFont default True;
    property ShowHint: Boolean read FShowHint write SetShowHint;
    property ParentShowHint: Boolean read FParentShowHint write SetParentShowHint default True;
    property Hint: string read FHint write FHint;
    property Dragging: Boolean read GetDragging;
    { Position in the parent's client area. }
    property BoundsRect: TRect read GetControlBounds write SetControlBounds;
    procedure Show;
    procedure Hide;
    procedure BringToFront;
    procedure SendToBack;
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property Visible: Boolean read GetVisible write SetVisible;
  end;
var
  DragManager: TDragManager;
  { The control being dragged, or nil. }
  DragSource: TControl;
implementation
uses SysUtils;
procedure TControl.SetAlign(Value: TAlign);
begin
  if Value = FAlign then Exit;
  FAlign := Value;
  RequestAlign;
end;
procedure TControl.RequestAlign;
begin end;
function TControl.ParentControl: TControl;
begin Result := nil; end;
procedure TControl.NotifyChildren;
begin end;
procedure TControl.ApplyFont;
begin end;
procedure TControl.FontChanged;
begin end;
procedure TControl.ColorChanged;
begin end;
procedure TControl.SetColor(Value: TColor);
begin
  if Value = FColor then Exit;
  FColor := Value;
  if not FInheriting then FParentColor := False;
  ColorChanged;
  NotifyChildren;
end;
procedure TControl.SetFont(Value: TGDIFont);
begin
  if Value = nil then raise Exception.Create('Control font cannot be nil');
  FFont.Assign(Value);
end;
procedure TControl.FontObjectChanged(Sender: TObject);
begin
  if not FInheriting then FParentFont := False;
  ApplyFont;
  FontChanged;
  NotifyChildren;
end;
procedure TControl.SetParentColor(Value: Boolean);
begin
  if Value = FParentColor then Exit;
  FParentColor := Value;
  if Value then ParentPropertiesChanged;
end;
procedure TControl.SetParentFont(Value: Boolean);
begin
  if Value = FParentFont then Exit;
  FParentFont := Value;
  if Value then ParentPropertiesChanged;
end;
procedure TControl.SetShowHint(Value: Boolean);
begin
  if not FInheriting then FParentShowHint := False;
  if Value = FShowHint then Exit;
  FShowHint := Value;
  NotifyChildren;
end;
procedure TControl.SetParentShowHint(Value: Boolean);
begin
  if Value = FParentShowHint then Exit;
  FParentShowHint := Value;
  if Value then ParentPropertiesChanged;
end;
procedure TControl.ParentPropertiesChanged;
var Parent: TControl;
begin
  Parent := ParentControl;
  if Parent = nil then Exit;
  FInheriting := True;
  try
    if FParentFont then FFont.Assign(Parent.FFont);
    if FParentColor then SetColor(Parent.FColor);
    if FParentShowHint then SetShowHint(Parent.FShowHint);
  finally FInheriting := False; end;
end;
constructor TControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDragCursor := crDrag;
  { Delphi uses clWindow; every control here starts as a button-face surface. }
  FColor := clBtnFace;
  FParentColor := True; FParentFont := True; FParentShowHint := True;
  FFont := TGDIFont.Create; FFont.OnChange := FontObjectChanged;
end;
destructor TControl.Destroy;
begin
  if DragManager <> nil then DragManager.Forget(Self);
  inherited Destroy;
  if FFont <> nil then FFont.OnChange := nil;
  FFont.Free; FFont := nil;
end;
function TControl.GetDragging: Boolean;
begin Result := DragSource = Self; end;
procedure TControl.BeginDrag(Immediate: Boolean);
begin
  if DragManager = nil then raise Exception.Create('Drag and drop needs the Controls unit');
  DragManager.Start(Self, Immediate);
end;
procedure TControl.EndDrag(Drop: Boolean);
begin
  if Dragging then DragManager.Finish(Drop);
end;
procedure TControl.DragOver(Source: TObject; X, Y: Integer; State: TDragState;
  var Accept: Boolean);
begin
  Accept := Assigned(FOnDragOver);
  if Accept then FOnDragOver(Self, Source, X, Y, State, Accept);
end;
procedure TControl.DragDrop(Source: TObject; X, Y: Integer);
begin
  if Assigned(FOnDragDrop) then FOnDragDrop(Self, Source, X, Y);
end;
procedure TControl.DoEndDrag(Target: TObject; X, Y: Integer);
begin
  if Assigned(FOnEndDrag) then FOnEndDrag(Self, Target, X, Y);
end;
function TControl.GetEnabled: Boolean;
begin Result := False; ControlOperation(coReadEnabled, Result); end;
procedure TControl.SetEnabled(Value: Boolean);
begin ControlOperation(coWriteEnabled, Value); end;
function TControl.GetVisible: Boolean;
begin Result := False; ControlOperation(coReadVisible, Result); end;
procedure TControl.SetVisible(Value: Boolean);
begin ControlOperation(coWriteVisible, Value); end;
procedure TControl.Show;
var Value: Boolean;
begin Value := True; ControlOperation(coShow, Value); end;
procedure TControl.Hide;
var Value: Boolean;
begin Value := False; ControlOperation(coHide, Value); end;
procedure TControl.BringToFront;
var Value: Boolean;
begin Value := False; ControlOperation(coFront, Value); end;
procedure TControl.SendToBack;
var Value: Boolean;
begin Value := False; ControlOperation(coBack, Value); end;
end.
