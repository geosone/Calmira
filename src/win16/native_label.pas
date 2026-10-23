{ SPDX-License-Identifier: GPL-2.0-or-later
  Separately usable windowless label, also exported through StdCtrls. }
unit native_label;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This label subset requires Win16}{$ENDIF}
interface
uses Classes, Graphics, Controls;
type
  TLabel = class(TGraphicControl)
  private
    FCaption: string;
    FAlignment: TAlignment;
    FWordWrap, FShowAccelChar: Boolean;
    FFocusControl: TCustomControl;
    procedure SetFocusControl(Value: TCustomControl);
    procedure SetCaption(const Value: string);
    procedure SetAlignment(Value: TAlignment);
    procedure SetWordWrap(Value: Boolean);
    procedure SetShowAccelChar(Value: Boolean);
  protected
    procedure FontChanged; override;
    procedure Paint; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function DialogChar(Key: Char; Root: TCustomControl): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    { Typed resource binding; not a general runtime published-property streamer. }
    property FocusControl: TCustomControl read FFocusControl write SetFocusControl;
    { These properties use typed DFM binding, not runtime property RTTI. }
    property Enabled;
    property Caption: string read FCaption write SetCaption;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default False;
    property ShowAccelChar: Boolean read FShowAccelChar write SetShowAccelChar default True;
    property Font;
    property Color;
    property Visible;
  end;
implementation
uses SysUtils, WinTypes, WinProcs, native_window, native_mnemonic;
procedure TLabel.SetFocusControl(Value: TCustomControl);
begin
  if Value = FFocusControl then Exit;
  if FFocusControl <> nil then FFocusControl.RemoveFreeNotification(Self);
  FFocusControl := Value;
  if Value <> nil then Value.FreeNotification(Self);
end;
procedure TLabel.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FFocusControl) then FFocusControl := nil;
  inherited Notification(AComponent, Operation);
end;
function TLabel.DialogChar(Key: Char; Root: TCustomControl): Boolean;
var Target: TCustomControl;
begin
  Result := False; Target := FFocusControl;
  if not ShowAccelChar or not CaptionMatches(Caption, Key) or (Target = nil) then Exit;
  if (Target = Root) or not Target.CanFocus then Exit;
  if Root.FindControl(Target.Handle) <> Target then Exit;
  { A matching request is consumed even if focus callbacks change the tree. }
  Result := True;
  Target.SetFocus;
end;
constructor TLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FShowAccelChar := True;
 
  SetBounds(0, 0, 65, 17);
end;
procedure TLabel.FontChanged;
begin Invalidate; end;
procedure TLabel.SetCaption(const Value: string);
begin
  if Pos(#0, Value) <> 0 then raise ENativeWindowError.Create('Embedded NUL in label caption');
  if FCaption = Value then Exit;
  FCaption := Value; Invalidate;
end;
procedure TLabel.SetAlignment(Value: TAlignment);
begin if Value <> FAlignment then begin FAlignment := Value; Invalidate; end; end;
procedure TLabel.SetWordWrap(Value: Boolean);
begin if Value <> FWordWrap then begin FWordWrap := Value; Invalidate; end; end;
procedure TLabel.SetShowAccelChar(Value: Boolean);
begin if Value <> FShowAccelChar then begin FShowAccelChar := Value; Invalidate; end; end;
procedure TLabel.Paint;
var Area: TRect; Buffer: array[0..255] of Char; Flags: Word; State: SmallInt;
begin
  if Canvas.Handle = 0 then begin Invalidate; Exit; end;
  if FCaption = '' then Exit;
  Area := Graphics.Rect(0, 0, Width, Height); Flags := DT_TOP or DT_EXPANDTABS;
  case FAlignment of
    taLeftJustify: ;
    taRightJustify: Flags := Flags or DT_RIGHT;
    taCenter: Flags := Flags or DT_CENTER;
  end;
  if FWordWrap then Flags := Flags or DT_WORDBREAK;
  if not FShowAccelChar then Flags := Flags or DT_NOPREFIX;
  StrPCopy(Buffer, FCaption);
  State := SaveDC(Canvas.Handle);
  if State = 0 then raise ENativeWindowError.Create('Cannot save label DC');
  try
    if SelectObject(Canvas.Handle, Font.Handle) = 0 then
      raise ENativeWindowError.Create('Cannot select label font');
    SetBkMode(Canvas.Handle, TRANSPARENT);
    if Enabled then SetTextColor(Canvas.Handle, ColorToRGB(Font.Color))
    else SetTextColor(Canvas.Handle, GetSysColor(COLOR_GRAYTEXT));
    if DrawText(Canvas.Handle, Buffer, Length(FCaption), Area, Flags) = 0 then
      raise ENativeWindowError.Create('Cannot draw label text');
  finally RestoreDC(Canvas.Handle, State); end;
end;
end.
