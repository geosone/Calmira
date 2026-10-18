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

unit Runprog;

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, Dialogs, Settings,
  ExtCtrls, SysUtils, Picbtn, SysMenu;

type
  TRunDlg = class(TForm)
    Label1: TLabel;
    Combo: TComboBox;
    OpenDialog: TOpenDialog;
    Image: TImage;
    BrowseBtn: TPicBtn;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    Label2: TLabel;
    DosCommand: TCheckBox;
    DosSession: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure OKBtnClick(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
    procedure BrowseBtnClick(Sender: TObject);
    procedure DosSessionClick(Sender: TObject);
  private
    { Private declarations }
    Changed: Boolean;
    DefaultDir: TFilename;
  public
    { Public declarations }
  end;

procedure RunExecute(const command: string; const Dir: TFilename);

var
  RunDlg: TRunDlg; { 2.2 }

implementation

{$R *.DFM}

uses Files, WinProcs, WinTypes, MiscUtil, Resource, Environs,
  Strings, Fileman, Desk, Locale, Graphics;

procedure RunExecute(const command: string; const Dir: TFilename);
begin
  ShowHourglass;
  if RunDlg = nil then RunDlg := TRunDlg.Create(Application);
  with RunDlg do
  begin
    AssignHistoryText(Combo, command);
    if Dir > '' then DefaultDir := Dir
    else DefaultDir := Environment.Values['WINDIR'];
    Show;
  end;
end;

procedure TRunDlg.FormCreate(Sender: TObject);
begin
  Image.Picture.Icon.Assign(Icons.Get('RunDialog'));
  ini.ReadStrings('RunProgram', Combo.Items);
end;

procedure TRunDlg.FormDestroy(Sender: TObject);
begin
  if Changed then ini.WriteNewStrings('RunProgram', Combo.Items);
  RunDlg := nil;
end;

procedure TRunDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TRunDlg.OKBtnClick(Sender: TObject);
var
  filename, newdir: TFilename;
  params: string;
begin
  Changed := AddHistory(Combo) or Changed;
  with Combo do
    if Text > '' then
    begin
      newdir := '';
      if DosSession.Checked then
      begin
        filename := ApplicationPath + 'dosrun.exe';
        params := Text;
        if MsgDialogRes(SNotifyEndWindows, mtInformation,
          [mbOK, mbCancel], 0) = mrOK then
          begin
            if Changed then ini.WriteNewStrings('RunProgram', Combo.Items);
            ExitWindowsExec(StrPChar(filename), StrPChar(params));
          end
        else Exit
      end
      else if DosCommand.Checked then
      begin
        filename := Environment.Values['COMSPEC'];
        params := '/c ' + Text;
      end
      else
      begin
        filename := FirstWord(EnvironSubst(Text));
        newdir := ExtractFileDir(filename);
        params := '';
        if Length(filename) < Length(Text) then
          params := Copy(Text, Length(filename) + 2, 255);
      end;
      if newdir = '' then newdir := DefaultDir;
      if (Length(filename) = 2) and (filename[1] in Alphas) and (filename[2] = ':') then
        AppendStr(filename, '\');
      if HDirectoryExists(filename) then
      begin
        Desktop.OpenFolder(filename);
        if RunAutoClose then Close;
      end
      else if (DefaultExec(filename, params, newdir, SW_SHOWNORMAL) > 32) and
        RunAutoClose then Close;
    end;
end;

procedure TRunDlg.CancelBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TRunDlg.BrowseBtnClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    Combo.Text := Lowercase(OpenDialog.Filename);
end;

procedure TRunDlg.DosSessionClick(Sender: TObject);
begin
  DosCommand.Enabled := not DosSession.Checked;
end;

end.

