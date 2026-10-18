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

unit Filter;

interface

uses
  Classes, Controls, Forms, StdCtrls, Buttons, ExtCtrls, Directry, Picbtn;

type
  TFilterDialog = class(TForm)
    Label1: TLabel;
    FilterEdit: TComboBox;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    cbHidSys: TCheckBox;
    Label2: TLabel;
    Image: TImage;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    function Execute(Dir : TDirectory): TModalResult;
  end;

{
var
  FilterDialog: TFilterDialog;
}

implementation

{$R *.DFM}

uses SysUtils, Settings, MiscUtil, Strings, Resource;

function TFilterDialog.Execute(Dir: TDirectory): TModalResult;
var
  details: TFileDetails;
  i: Integer;
  b: array[0..4] of Boolean;
  hidsys: Boolean;
begin
  FilterEdit.Text := Dir.Filter;
  cbHidSys.Checked := Dir.Mask and faHidden <> 0;
  Result := ShowModal;
  if Result = mrOK then
  begin
    Dir.Filter := FilterEdit.Text;
    Dir.Mask := DirectoryMasks[cbHidSys.Checked];
  end;
end;

procedure TFilterDialog.FormCreate(Sender: TObject);
begin
  Image.Picture.Icon.Assign(Icons.Get('MultiFile'));
  ini.ReadStrings('Browser Filters', FilterEdit.Items);
end;

procedure TFilterDialog.OKBtnClick(Sender: TObject);
begin
  with FilterEdit do
  begin
    Text := RemoveSpaces(Text);
    if Text = '' then Text := DefaultFilter;
  end;
  if AddHistory(FilterEdit) then
    ini.WriteNewStrings('Browser Filters', FilterEdit.Items);
end;

end.

