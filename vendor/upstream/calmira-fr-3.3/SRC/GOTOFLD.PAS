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

unit GotoFld;

interface

uses WinTypes, Messages, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls,
  Buttons, PicBtn, ExtCtrls, SysMenu;

type
  TGotoDlg = class(TForm)
    Image: TImage;
    Label1: TLabel;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    Combo: TComboBox;
    Label2: TLabel;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

function GotoFolder(var folder: string): Boolean;

var
  GotoDlg: TGotoDlg;

implementation

uses SysUtils, Environs, Files, MiscUtil, Resource, Locale, Settings;

{$R *.DFM}

var
  Changed: Boolean;

function GotoFolder(var folder: string): Boolean;
var
  s: string[79];
begin
  Result := False;
  ShowHourglass;
  if GotoDlg = nil then GotoDlg := TGotoDlg.Create(Application);
  with GotoDlg do
  begin
    AssignHistoryText(Combo, folder);
    repeat
      ShowModal;
      if ModalResult = mrOK then
      begin
        s := LowerCase(ExpandFoldername(EnvironSubst(Combo.Text), Winpath[1]));
        if HDirectoryExists(s) then
        begin
          Changed := AddHistory(Combo) or Changed;
          Result := True;
          folder := s;
        end
        else
          ErrorMsgResFmt(SCannotOpenFolder, [Combo.Text]);
      end;
    until (ModalResult = mrCancel) or Result;
    Close;
  end;
end;

procedure TGotoDlg.FormCreate(Sender: TObject);
begin
  Image.Picture.Icon.Assign(Icons.Get('GotoDialog'));
  ini.ReadStrings('GotoFolder', Combo.Items);
end;

procedure TGotoDlg.FormDestroy(Sender: TObject);
begin
  if Changed then ini.WriteNewStrings('GotoFolder', Combo.Items);
  GotoDlg := nil;
end;

procedure TGotoDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

end.

