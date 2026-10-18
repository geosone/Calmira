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

unit Replace;

interface

uses
  Classes, SysUtils, Controls, Forms, StdCtrls, Buttons, ExtCtrls, Picbtn;

type
  TReplaceBox = class(TForm)
    Label3: TLabel;
    Target1: TLabel;
    Target2: TLabel;
    Label4: TLabel;
    Source1: TLabel;
    Source2: TLabel;
    Image1: TImage;
    YesBtn: TPicBtn;
    NoBtn: TPicBtn;
    AllBtn: TPicBtn;
    CancelBtn: TPicBtn;
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    function Query(const Filename, Destname: TFilename): Integer;
  end;

var
  ReplaceBox: TReplaceBox;

implementation

{$R *.DFM}

uses Strings, MiscUtil, WinProcs, WinTypes, Desk;

procedure AssignDetails(const fname: TFilename; NameLabel, InfoLabel: TLabel);
var
  rec: TSearchRec;
begin
  FindFirst(fname, faAnyfile, rec);
  NameLabel.Caption := fname;
  InfoLabel.Caption := Format('%s  %s', [FormatByte(rec.Size, 2, 2),
    FormatDateTime('dddd d mmmm yyyy,  hh:mm',
    TimestampToDate(rec.Time))]);
  FindClose(rec); { 3.11 }
end;

function TReplaceBox.Query(const Filename, Destname: TFilename): Integer;
begin
  AssignDetails(Destname, Target1, Target2);
  AssignDetails(Filename, Source1, Source2);
  Desktop.SetCursor(crDefault);
  try
    Result := ShowModal;
  finally
    Desktop.ReleaseCursor;
  end;
end;

procedure TReplaceBox.FormCreate(Sender: TObject);
begin
  Image1.Picture.Icon.Handle := LoadIcon(0, IDI_QUESTION);
end;

procedure TReplaceBox.FormShow(Sender: TObject);
begin
  if MsgDialogSounds then MessageBeep(MB_ICONQUESTION);
end;

end.

