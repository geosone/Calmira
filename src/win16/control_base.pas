{ SPDX-License-Identifier: GPL-2.0-or-later
  Shared visual-control identity and operations; not the complete VCL TControl. }
unit control_base;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This control base requires Win16}{$ENDIF}
interface
uses Classes;
type
  TControlOperation = (coReadEnabled, coWriteEnabled, coReadVisible,
    coWriteVisible, coShow, coHide, coFront, coBack);
  TControl = class(TComponent)
  private
    function GetEnabled: Boolean;
    procedure SetEnabled(Value: Boolean);
    function GetVisible: Boolean;
    procedure SetVisible(Value: Boolean);
  protected
    { One policy slot, rather than a virtual slot per property/view method. }
    procedure ControlOperation(Operation: TControlOperation; var Value: Boolean); virtual; abstract;
  public
    procedure Show;
    procedure Hide;
    procedure BringToFront;
    procedure SendToBack;
    property Enabled: Boolean read GetEnabled write SetEnabled;
    property Visible: Boolean read GetVisible write SetVisible;
  end;
implementation
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
