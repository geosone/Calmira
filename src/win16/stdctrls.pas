{ SPDX-License-Identifier: GPL-2.0-or-later
  Public aliases to separately usable native Win16 controls, and Delphi 1's
  self-drawn group box. }
unit StdCtrls;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This StdCtrls subset requires Win16}{$ENDIF}
interface
uses Classes, WinTypes, Graphics, Controls, native_label, native_button, native_edit,
  native_checkbox, native_radio, native_combobox, native_listbox;
type
  TLabel = native_label.TLabel;
  TButton = native_button.TButton;
  TEdit = native_edit.TEdit;
  TEditCharCase = native_edit.TEditCharCase;
  TCheckBox = native_checkbox.TCheckBox;
  TCheckBoxState = native_checkbox.TCheckBoxState;
  TRadioButton = native_radio.TRadioButton;
  TComboBoxStyle = native_combobox.TComboBoxStyle;
  TCustomComboBox = native_combobox.TCustomComboBox;
  TComboBox = native_combobox.TComboBox;
  TListBoxStyle = native_listbox.TListBoxStyle;
  TOwnerDrawState = native_listbox.TOwnerDrawState;
  TDrawItemEvent = native_listbox.TDrawItemEvent;
  TMeasureItemEvent = native_listbox.TMeasureItemEvent;
  TCustomListBox = native_listbox.TCustomListBox;
  TListBox = native_listbox.TListBox;
  TScrollStyle = (ssNone, ssHorizontal, ssVertical, ssBoth);
  { Delphi 1 group box: a frame with the caption in its top edge, drawn by the
    control itself; aligned children stay inside the frame. A mnemonic in the
    caption is drawn but does not move the focus. }
  TCustomGroupBox = class(TCustomControl)
  private
    FCaption: string;
    procedure SetCaption(const Value: string);
  protected
    procedure AlignControls(AControl: TControl; var Rect: TRect); override;
    procedure Paint; override;
    function CaptionHeight: Integer;
    property Caption: string read FCaption write SetCaption;
  public
    constructor Create(AOwner: TComponent); override;
  end;
  TGroupBox = class(TCustomGroupBox)
  published
    property Align;
    property Caption;
    property Color;
    property Ctl3D;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;
const
  ecNormal = native_edit.ecNormal;
  ecUpperCase = native_edit.ecUpperCase;
  ecLowerCase = native_edit.ecLowerCase;
  cbUnchecked = native_checkbox.cbUnchecked;
  cbChecked = native_checkbox.cbChecked;
  cbGrayed = native_checkbox.cbGrayed;
  csDropDown = native_combobox.csDropDown;
  csSimple = native_combobox.csSimple;
  csDropDownList = native_combobox.csDropDownList;
  csOwnerDrawFixed = native_combobox.csOwnerDrawFixed;
  csOwnerDrawVariable = native_combobox.csOwnerDrawVariable;
  lbStandard = native_listbox.lbStandard;
  lbOwnerDrawFixed = native_listbox.lbOwnerDrawFixed;
  lbOwnerDrawVariable = native_listbox.lbOwnerDrawVariable;
  odSelected = native_listbox.odSelected; odGrayed = native_listbox.odGrayed;
  odDisabled = native_listbox.odDisabled; odChecked = native_listbox.odChecked;
  odFocused = native_listbox.odFocused;
implementation
uses SysUtils, WinProcs;
constructor TCustomGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetBounds(0, 0, 185, 105);
end;
procedure TCustomGroupBox.SetCaption(const Value: string);
begin
  if Value = FCaption then Exit;
  FCaption := Value;
  Invalidate;
end;
function TCustomGroupBox.CaptionHeight: Integer;
var DC: HDC; Old: HFONT; Metrics: TTextMetric;
begin
  { Also needed outside Paint, where the control canvas has no DC. }
  DC := GetDC(0);
  Old := SelectObject(DC, Font.Handle);
  GetTextMetrics(DC, Metrics);
  SelectObject(DC, Old);
  ReleaseDC(0, DC);
  Result := Metrics.tmHeight;
end;
procedure TCustomGroupBox.AlignControls(AControl: TControl; var Rect: TRect);
begin
  Inc(Rect.Top, CaptionHeight);
  InflateRect(Rect, -1, -1);
  if Ctl3D then InflateRect(Rect, -1, -1);
  inherited AlignControls(AControl, Rect);
end;
procedure TCustomGroupBox.Paint;
var H: Integer; R: TRect; DC: HDC; Text: array[0..255] of Char;
  procedure Frame(const Area: TRect; Color: TColor);
  begin
    Canvas.Pen.Color := Color;
    Canvas.PolyLine([Point(Area.Left, Area.Top), Point(Area.Right - 1, Area.Top),
      Point(Area.Right - 1, Area.Bottom - 1), Point(Area.Left, Area.Bottom - 1), Point(Area.Left, Area.Top)]);
  end;
begin
  H := CaptionHeight;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  Canvas.Pen.Width := 1;
  R := Rect(0, H div 2 - 1, Width, Height);
  if Ctl3D then
  begin
    Inc(R.Left); Inc(R.Top);
    Frame(R, clBtnHighlight);
    OffsetRect(R, -1, -1);
    Frame(R, clBtnShadow);
  end
  else Frame(R, clWindowFrame);
  if FCaption = '' then Exit;
  DC := Canvas.ContextHandle;
  StrPCopy(Text, FCaption);
  R := Rect(8, 0, 0, H);
  DrawText(DC, Text, -1, R, DT_LEFT or DT_SINGLELINE or DT_CALCRECT);
  SetBkMode(DC, OPAQUE);
  SetBkColor(DC, ColorToRGB(Color));
  SetTextColor(DC, ColorToRGB(Font.Color));
  DrawText(DC, Text, -1, R, DT_LEFT or DT_SINGLELINE);
end;
end.
