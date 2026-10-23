{ SPDX-License-Identifier: GPL-2.0-or-later
  Shared visual-control identity and operations; not the complete VCL TControl. }
unit control_base;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This control base requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, native_cursors;
type
  TControlOperation = (coReadEnabled, coWriteEnabled, coReadVisible,
    coWriteVisible, coShow, coHide, coFront, coBack);
  { Delphi 1 Forms types, shared here so controls need not use Forms. }
  TFormBorderStyle = (bsNone, bsSingle, bsSizeable, bsDialog);
  TBorderStyle = bsNone..bsSingle;
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
  protected
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
constructor TControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDragCursor := crDrag;
end;
destructor TControl.Destroy;
begin
  if DragManager <> nil then DragManager.Forget(Self);
  inherited Destroy;
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
