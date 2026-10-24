{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 FileCtrl subset: the filter combo box Calmira's open dialog uses.
  The file, directory and drive list controls, FileList linking and the
  directory helpers are not provided and must fail to compile. }
unit FileCtrl;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This FileCtrl subset requires Win16}{$ENDIF}
interface
uses Classes, Controls, StdCtrls;
type
  { A drop-down list of filter descriptions; Mask is the selected pattern. }
  TFilterComboBox = class(TCustomComboBox)
  private
    FFilter: string;
    FMasks: TStringList;
    procedure SetFilter(const Value: string);
    function GetMask: string;
    procedure BuildList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Mask: string read GetMask;
    property Text;
  published
    { 'Text files (*.TXT)|*.TXT|All files (*.*)|*.*': description and mask
      pairs. A description without a mask is its own mask. }
    property Filter: string read FFilter write SetFilter;
    property Color;
    property Ctl3D;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange;
    property OnClick;
    property OnDropDown;
  end;
implementation
constructor TFilterComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMasks := TStringList.Create;
  Style := csDropDownList;
  SetFilter('All files (*.*)|*.*');
end;
destructor TFilterComboBox.Destroy;
begin
  inherited Destroy;
  FMasks.Free;
end;
procedure TFilterComboBox.SetFilter(const Value: string);
begin
  FFilter := Value;
  BuildList;
end;
procedure TFilterComboBox.BuildList;
var Rest, Description, Pattern: string; Bar: Integer;
  function NextPart: string;
  begin
    Bar := Pos('|', Rest);
    if Bar = 0 then begin Result := Rest; Rest := ''; end
    else begin Result := Copy(Rest, 1, Bar - 1); Delete(Rest, 1, Bar); end;
  end;
begin
  Items.Clear;
  FMasks.Clear;
  Rest := FFilter;
  while Rest <> '' do
  begin
    Description := NextPart;
    Pattern := NextPart;
    if Pattern = '' then Pattern := Description;
    Items.Add(Description);
    FMasks.Add(Pattern);
  end;
  if Items.Count > 0 then ItemIndex := 0;
end;
function TFilterComboBox.GetMask: string;
var Index: Integer;
begin
  Index := ItemIndex;
  if (Index >= 0) and (Index < FMasks.Count) then Result := FMasks[Index] else Result := '*.*';
end;
end.
