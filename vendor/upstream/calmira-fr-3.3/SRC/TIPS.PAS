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

unit Tips;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Buttons, ExtCtrls;

type
  TTipDialog = class(TForm)
    CloseBtn: TBitBtn;
    NextTip: TBitBtn;
    cbShowDailyTips: TCheckBox;
    Label1: TLabel;
    Panel1: TPanel;
    Label4: TLabel;
    HomePage: TBitBtn;
    HelpBtn: TBitBtn;
    TipLabel: TLabel;
    Bevel1: TBevel;
    Image1: TImage;
    Title: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure NextTipClick(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure HelpBtnClick(Sender: TObject);
    procedure HomePageClick(Sender: TObject);
    procedure cbShowDailyTipsClick(Sender: TObject);
  private
    { Private declarations }
    function GetTip(const filename: string): string;
  public
    { Public declarations }
  end;

var
  TipDialog: TTipDialog;

implementation

{$R *.DFM}

uses FileMan, Settings, Strings, Files, MiscUtil;

function TTipDialog.GetTip(const filename: string): string;
var
  f: TextFile;
  Count, i: Integer;
begin
  if not FileExists(filename) then
  begin
    Result := TipLabel.Caption;
    Exit;
  end;
  ShowHourglass;
  AssignFile(f, filename);
  Reset(f);
  try
    Readln(f, Count);
    for i := 0 to Random(Count) do
    begin
      repeat
        Readln(f, Result);
      until Eof(f) or (not IsBlank(Result) and (Result[1] <> ';'));
      if Eof(f) then Break;
    end;
  finally
    CloseFile(f);
  end;
end;

procedure TTipDialog.FormCreate(Sender: TObject);
begin
  with Title.Picture do
    ReplaceBitmapColors(Bitmap, Bitmap.Canvas.Pixels[0, Height - 1], Color);
  cbShowDailyTips.Checked := ShowDailyTips;
  CloseBtn.Cancel := True;
end;

procedure TTipDialog.FormShow(Sender: TObject);
begin
  NextTip.Click;
end;

procedure TTipDialog.NextTipClick(Sender: TObject);
begin
  TipLabel.Caption := GetTip(ApplicationPath + 'tips.txt');
end;

procedure TTipDialog.CloseBtnClick(Sender: TObject);
begin
  Close;
  ini.WriteString('Calmira', 'DateLastRun', DateToStr(Date));
end;

procedure TTipDialog.HelpBtnClick(Sender: TObject);
begin
   Application.HelpJump('Contents');
end;

procedure TTipDialog.HomePageClick(Sender: TObject);
begin
  DefaultExec('http://www.calmira.org', '', '', SW_SHOWNORMAL);
end;

procedure TTipDialog.cbShowDailyTipsClick(Sender: TObject);
begin
  ShowDailyTips := cbShowDailyTips.Checked;
  ini.WriteBool('Preferences', 'ShowDailyTips', ShowDailyTips);
end;

initialization
  Randomize;
end.

