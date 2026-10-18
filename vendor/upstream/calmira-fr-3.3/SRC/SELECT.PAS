{**************************************************************************}
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

unit Select;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, StylSped, Picbtn;

type
  TSelectFileEvent = procedure(Sender: TObject; const FileSpec: string;
    Select: Boolean) of object;

  TSelectFileDlg = class(TForm)
    Image: TImage;
    Edit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    SelectBtn: TPicBtn;
    DeselectBtn: TPicBtn;
    CloseBtn: TPicBtn;
    procedure FormCreate(Sender: TObject);
    procedure SelectBtnClick(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
  private
    { Private declarations }
    FSelectFiles: TSelectFileEvent;
  public
    { Public declarations }
    property OnSelectFiles: TSelectFileEvent read FSelectFiles write FSelectFiles;
  end;

var
  SelectFileDlg: TSelectFileDlg;

implementation

{$R *.DFM}

uses Strings, Resource;

procedure TSelectFileDlg.FormCreate(Sender: TObject);
begin
  Image.Picture.Icon.Assign(Icons.Get('MultiFile'));
end;

procedure TSelectFileDlg.SelectBtnClick(Sender: TObject);
var
  s: string;
begin
  if Assigned(FSelectFiles) then
  begin
    s := Edit.Text;
    repeat
      FSelectFiles(Self, GetWord(s, ';'), Sender = SelectBtn);
    until s = '';
  end;
end;

procedure TSelectFileDlg.CloseBtnClick(Sender: TObject);
begin
  Close;
end;

end.

