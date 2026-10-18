{**************************************************************************}
{                                                                          }
{    Calmira II shell pour Microsoft® Windows(TM) 3.1                      }
{    Version française 3.3                                                 }
{    Copyright (C) 2000-2002 Jean Blanchard                                }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ce programme est libre ; vous pouvez le redistribuer et/ou le         }
{    modifier selon les termes de la Licence Publique Générale GNU telle   }
{   que publiée par la Free Software Foundation ; version 2 de la licence  }
{    ou (au choix) n'importe quelle version plus récente.                  }
{                                                                          }
{    Ce programme est distibué dans l'espoir qu'il sera utile, mais SANS   }
{    AUCUNE GARANTIE ; sans même la garantie implicite de                  }
{    COMMERCIALISATION ou d'APTITUDE A UN USAGE PARTICULIER. Voir la       }
{    licence publique générale pour plus de détails.                                        }
{                                                                          }
{    Vous devriez avoir reçue une copie de la licence publique générale    }
{    avec ce programme; si ce n'est pas le cas, écrivez à la Free          }
{    Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.    }
{                                                                          }
{--------------------------------------------------------------------------}

unit Trad;

interface

uses SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, ExtCtrls, StdCtrls, Buttons, Picbtn, StylSped, LabelSel;

type
  TPageTraducteur = class(TForm)
    Texte1: TLabel;
    Image1: TImage;
    OKButton: TStyleSpeed;
    Shape1: TShape;
    Texte2: TLabel;
    LabelSelect1: TLabelSelect;
    AddressLabel: TLabel;
    SiteLabel: TLabel;
    procedure OKButtonClick(Sender: TObject);
    procedure SiteLabelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure AddressLabelClick(Sender: TObject);
    procedure SiteLabelClick(Sender: TObject);
  private
    { Private-déclarations }
  public
    { Public-déclarations }
  end;

var
  PageTraducteur: TPageTraducteur;

implementation

{$R *.DFM}

uses Fileman, About;

procedure TPageTraducteur.OKButtonClick(Sender: TObject);
begin
  Close;
end;

procedure TPageTraducteur.SiteLabelMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
 if Button = mbLeft then LabelSelect1.Overlay(Sender as TLabel);
end;

procedure TPageTraducteur.AddressLabelClick(Sender: TObject);
begin
  ModalResult := mrOK;
  OpenURL('mailto:jean@calmira.fr.st');
end;

procedure TPageTraducteur.SiteLabelClick(Sender: TObject);
begin
  ModalResult := mrOK;
  OpenURL('http://www.calmira.fr.st');
end;

end.
