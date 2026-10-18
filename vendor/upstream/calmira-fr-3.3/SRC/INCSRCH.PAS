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

unit Incsrch;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls;

type
  TSearchEvent = procedure (Sender: TObject; const s: string) of object;

  TIncSearchDlg = class(TForm)
    Edit: TEdit;
    Label1: TLabel;
    procedure EditChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
    FOnSearch: TSearchEvent;
    FInitialChar: Char;
  public
    { Public declarations }
    property OnSearch: TSearchEvent read FOnSearch write FOnSearch;
    property InitialChar: Char read FInitialChar write FInitialChar;
  end;

{
var
  IncSearchDlg: TIncSearchDlg;
}

implementation

{$R *.DFM}

uses SysUtils;

procedure TIncSearchDlg.EditChange(Sender: TObject);
begin
  if Assigned(FOnSearch) then FOnSearch(self, Edit.Text);
end;

procedure TIncSearchDlg.FormShow(Sender: TObject);
begin
  with Edit do
  begin
    Text := Lowercase(InitialChar);
    SelLength := 0;
    SelStart := 1;
  end;
end;

procedure TIncSearchDlg.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) or (Key = VK_ESCAPE) then Close;
end;

end.

