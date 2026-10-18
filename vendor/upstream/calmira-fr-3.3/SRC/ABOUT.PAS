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

unit About;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, Picbtn, Trad;

type
  TAboutBox = class(TForm)
    AppLogo: TImage;
    VersionLabel: TLabel;
    Copy1Label: TLabel;
    Copy2Label: TLabel;
    HomepageLabel: TLabel;
    Bevel1: TBevel;
    LicenceLabel: TLabel;
    LicenseBtn: TPicBtn;
    OKButton: TPicBtn;
    Bevel2: TBevel;
    Label3: TLabel;
    Label4: TLabel;
    MemLabel: TLabel;
    ResLabel: TLabel;
    AppTitle: TImage;
    Copy3Label: TLabel;
    TradLabel: TLabel;
    TradBtn: TPicBtn;
    FrenchLabel: TLabel;
    Site1Label: TLabel;
    Label2: TLabel;
    procedure LicenseBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure HomepageLabelClick(Sender: TObject);
    procedure AppLogoClick(Sender: TObject);
    procedure TradBtnClick(Sender: TObject);
    procedure TradLabelClick(Sender: TObject);
    procedure FrenchLabelClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

{
var
  AboutBox: TAboutBox;
}

implementation

{$R *.DFM}

uses Strings, SysUtils, Files, MiscUtil, Settings, Fileman,
  Dialogs, Locale, Desk;

procedure TAboutBox.LicenseBtnClick(Sender: TObject);
var
  license : TFilename;
begin
  license := ApplicationPath + 'license.txt';
  if not FileExists(license) then
    MsgDialogRes(SCannotFindLicense, mtError, [mbOK], 0)
  else
    if FileExecute('open', 'notepad.exe', license, '',
      SW_SHOWMAXIMIZED) <= 32 then
        MsgDialogRes(SCannotRunNotepad, mtError, [mbOK], 0);
end;

procedure TAboutBox.FormCreate(Sender: TObject);
begin
  MemLabel.Caption := FormatByte(GetFreeSpace(0), 2, 2) + ' libres';
  ResLabel.Caption := Format('Système %d%%  GDI %d%%  Utilisateur %d%%',
    [GetFreeSystemResources(GFSR_SYSTEMRESOURCES),
     GetFreeSystemResources(GFSR_GDIRESOURCES),
     GetFreeSystemResources(GFSR_USERRESOURCES)]);
  AppLogo.Picture.Bitmap.Handle := LoadBitmap(HInstance, 'LOGO');
  AppTitle.Picture.Bitmap.Handle := LoadBitmap(HInstance, 'TITLE');
  if FirstRun then
  begin
    Caption := LoadStr(SWelcome);
    FirstRun := False;
  end;
end;

procedure TAboutBox.HomepageLabelClick(Sender: TObject);
begin
  OKButton.Click;
  { 2.2 added http:// }
  OpenURL('http://www.calmira.org');
end;

procedure TAboutBox.AppLogoClick(Sender: TObject);
begin
  Desktop.Revert;
end;

procedure TAboutBox.TradBtnClick(Sender: TObject);
var a:TModalResult;
begin
  Application.CreateForm(TPageTraducteur, PageTraducteur);
  if PageTraducteur.ShowModal=mrOK Then OKButton.Click;
  PageTraducteur.Release;
end;

procedure TAboutBox.TradLabelClick(Sender: TObject);
begin
  OKButton.Click;
  OpenURL('mailto:jean@calmira.fr.st');
end;

procedure TAboutBox.FrenchLabelClick(Sender: TObject);
begin
  OKButton.Click;
  OpenURL('http://www.calmira.fr.st');
end;

end.

