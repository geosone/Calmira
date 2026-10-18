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

unit Shutdown;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, Messages, Picbtn, Sysmenu;

type
  TQuitDlg = class(TForm)
    rbDOS: TRadioButton;
    rbRestart: TRadioButton;
    rbReboot: TRadioButton;
    rbQuit: TRadioButton;
    Image: TImage;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    Label1: TLabel;
    procedure OKBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure rbDOSDblClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ImageDblClick(Sender: TObject);
  private
    { Private declarations }
    procedure DarkenScreen;
    procedure DrawShutDownBMP;
  public
    { Public declarations }
  end;

implementation

{$R *.DFM}

uses SysUtils, MiscUtil, Settings, Desk, Task, IniFiles, Resource, Files,
  CompSys, Strings;

{
var
  QuitDlg: TQuitDlg;
}

procedure TQuitDlg.OKBtnClick(Sender: TObject);
var
  i: Integer;
begin
  i := GetRadioIndex([rbDOS, rbRestart, rbReboot, rbQuit]);
  ShowHourglass;
  Release;
  Desktop.Save;
  if (i < 3) and ShowShutDownBMP then DrawShutDownBMP;
  case i of
    0: ExitWindows(0, 0);
    1: ExitWindows(EW_RESTARTWINDOWS, 0);
    2: ExitWindows(EW_REBOOTSYSTEM, 0);
    3: Application.Terminate;
  end;
end;

procedure TQuitDlg.FormCreate(Sender: TObject);
begin
  Image.Picture.Icon.Assign(Icons.Get('ShutDownDialog'));
  with rbQuit do
  begin
    Visible := not IsShell;
    Checked := not IsShell;
  end;
end;

procedure TQuitDlg.FormShow(Sender: TObject);
begin
  SetSysModalWindow(Handle);
  { Prevent redrawing the active windows' caption }
  SetActiveWindow(Handle);
  if ShowShutDownBMP then DarkenScreen;
end;

procedure TQuitDlg.rbDOSDblClick(Sender: TObject);
begin
  OKBtn.Click;
end;

procedure TQuitDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Desktop.Repaint;
  Action := caFree;
end;

procedure TQuitDlg.ImageDblClick(Sender: TObject);
begin
  with TIniFile.Create('system.ini') do
  begin
    if IsShell then
      WriteString('Boot', 'Shell', 'progman.exe')
    else
      WriteString('Boot', 'Shell', Application.Exename);
    Free;
  end;
  OKBtn.Click;
end;

procedure TQuitDlg.DarkenScreen;
var
  Mesh: TBrush;
  oldbrush: HBrush;
  dc: HDC;
begin
  Mesh := TBrush.Create;
  Mesh.Bitmap := CreateBrushPattern(clWhite, clBlack);
  dc := GetDC(0);
  oldbrush := SelectObject(dc, Mesh.Handle);
  PatBlt(dc, 0, 0, Screen.Width, Screen.Height, $A000C9);
  SelectObject(dc, oldbrush);
  ReleaseDC(0, dc);
  Mesh.Free;
end;

procedure TQuitDlg.DrawShutDownBMP;
var
  bmpfile: TFileName;
  bmp: TBitmap;
  dc: HDC;
begin
  bmpfile := FileWritePath + 'shutdown.bmp';
  if not FileExists(bmpfile) then
    bmpfile := ApplicationPath + 'shutdown.bmp';
  if not FileExists(bmpfile) then exit;
  bmp := TBitmap.Create;
  bmp.LoadFromFile(bmpfile);
  dc := GetDC(0);
  StretchBlt(dc, 0, 0, Screen.Width, Screen.Height,
    bmp.Canvas.Handle, 0, 0, bmp.Width, bmp.Height, SRCCOPY);
  ReleaseDC(0, dc);
  bmp.Free;
end;

end.

