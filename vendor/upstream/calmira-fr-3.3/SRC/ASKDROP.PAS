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

unit Askdrop;

interface

uses Forms, StdCtrls, Classes, Picbtn, ExtCtrls, Controls, Buttons;

type
  TAskDropBox = class(TForm)
    Label1: TLabel;
    BitBtn1: TPicBtn;
    BitBtn2: TPicBtn;
    BitBtn3: TPicBtn;
    Icon: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  AskDropBox: TAskDropBox;

implementation

{$R *.DFM}

uses WinProcs, WinTypes, MiscUtil;

procedure TAskDropBox.FormCreate(Sender: TObject);
begin
  Icon.Picture.Icon.Handle := LoadIcon(0, IDI_QUESTION);
end;

procedure TAskDropBox.FormShow(Sender: TObject);
begin
  if MsgDialogSounds then MessageBeep(MB_ICONQUESTION);
end;

end.

