{*********************************************************}
{                                                         }
{    Librairie Système Calmira 3.3 version française      }
{    par Jean Blanchard                                   }
{    publié dans le domaine public en Juillet 2002        }
{                                                         }
{*********************************************************}

unit Nheader;

interface

uses
  Classes, Controls, ExtCtrls;

type
  TSClickEvent = procedure (Sender: TObject; Section: Integer) of object;
  TNewHeader = class(THeader)
  private
    { Private declarations }
    FOnSectionClick: TSClickEvent;
    procedure MD(Sender: TObject; Button: TMouseButton;
         Shift: TShiftState; X, Y: Integer);
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
  published
    { Published declarations }
    property OnSectionClick: TSClickEvent read FOnSectionClick write FOnSectionClick;
  end;

procedure Register;

implementation

constructor TNewHeader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  OnMouseDown := MD;
end;

procedure TNewHeader.MD(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Integer);
var i, L: Integer;
begin
  L := 0;
  for i := 0 to Sections.count - 1 do begin
    if (X > L + 3) and (X < L + SectionWidth[i] - 3) and Assigned(FOnSectionClick)
      then OnSectionClick(Sender, i);
    L := L + SectionWidth[i];
  end;
end;

procedure Register;
begin
  RegisterComponents('Calmira', [TNewHeader]);
end;

end.
 