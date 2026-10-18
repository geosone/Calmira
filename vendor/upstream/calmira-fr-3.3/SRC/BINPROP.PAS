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

unit Binprop;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, Spin, TabNotBk, ExtCtrls, Chklist, TabPanel, Picbtn;

type
  TBinPropDlg = class(TForm)
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    Bevel1: TBevel;
    Label4: TLabel;
    Label2: TLabel;
    CapEdit: TEdit;
    cbIcons: TCheckBox;
    Label3: TLabel;
    Bevel2: TBevel;
    rbUseBin: TRadioButton;
    TrashPanel: TPanel;
    Label1: TLabel;
    rbLeave: TRadioButton;
    rbEmpty: TRadioButton;
    rbCollect: TRadioButton;
    cbDeleteToBin: TCheckBox;
    SizeEdit: TSpinEdit;
    rbDelete: TRadioButton;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    procedure rbCollectClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure rbUseBinClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

{
var
  BinPropDlg: TBinPropDlg;
}

implementation

uses WasteBin, MiscUtil, Settings;

{$R *.DFM}

procedure TBinPropDlg.rbCollectClick(Sender: TObject);
begin
  SizeEdit.Enabled := rbCollect.Checked;
end;

procedure TBinPropDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;
  CapEdit.Text := BinCaption;
  if BinAction = baDelete then rbDelete.Checked := True
  else
  begin
    rbUseBin.Checked := True;
    case BinAction of
      baLeave   : rbLeave.Checked := True;
      baEmpty   : rbEmpty.Checked := True;
      baCollect : rbCollect.Checked := True;
    end;
  end;
  SizeEdit.Value := BinCapacity;
  cbDeleteToBin.Checked := DeleteToBin;
  cbIcons.Checked := BinIcons;
  EnableControlList([OKBtn, Notebook], CanEditSettings); { 2.2 }
end;

procedure TBinPropDlg.OKBtnClick(Sender: TObject);
const
  Actions : array[0..2] of TBinAction = (baLeave, baEmpty, baCollect);
begin
  BinCaption := CapEdit.Text;
  if rbDelete.Checked then BinAction := baDelete
  else BinAction := Actions[GetRadioIndex([rbLeave, rbEmpty, rbCollect])];
  BinCapacity := SizeEdit.Value;
  DeleteToBin := cbDeleteToBin.Checked;
  BinIcons := cbIcons.Checked;
  SaveBinProp;
  Bin.Configure;
  AnnounceSettingsChanged([scBin]);
end;

procedure TBinPropDlg.rbUseBinClick(Sender: TObject);
const
  TextColors : array[Boolean] of TColor = (clGray, clBlack);
begin
  TrashPanel.Enabled := rbUseBin.Checked;
  TrashPanel.Font.Color := TextColors[rbUseBin.Checked];
end;

end.

