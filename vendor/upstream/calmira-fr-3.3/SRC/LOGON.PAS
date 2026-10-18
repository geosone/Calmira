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

unit Logon;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, ExtCtrls, StdCtrls, Buttons, Picbtn, Sysmenu;

type
  TLogonDlg = class(TForm)
    PasswordEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    Image1: TImage;
    Label3: TLabel;
    UserCombo: TComboBox;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

procedure CheckForLogon;

implementation

{$R *.DFM}

uses Files, FileMan, MiscUtil, Profile, Password, Settings, Locale, IniFiles;

var
  LogonForm: TLogonDlg;
  UserIni: TProfile;
  UserList: TStringList;
  User: string[8];

procedure CheckForLogon;
var
  NewWritePath: TFilename;

procedure EnsureExistence(const filename: TFilename);
begin
  if FileExists(FileWritePath + filename) and not FileExists(NewWritePath + filename) then
    CopyFile(FileWritePath + filename, NewWritePath + filename);
end;

begin
  UserIni := TProfile.Create(BasePath + 'calusers.ini');
  MultipleProfiles := UserIni.ReadBool('Settings', 'MultipleProfiles', False);
  if MultipleProfiles then
  begin
    With TInifile.Create(BasePath + 'calmira.ini') do
    begin { 3.0 }
      PicBtnGlyphs := ReadBool('Preferences', 'PicBtnGlyphs', False);
      PicBtnGlyphsChanged;
      Free;
    end;
    UserList := TStringList.Create;
    UserIni.ReadSection('Users', UserList);
    with TLogonDlg.Create(Application) do
    try
      ShowModal;
      if ModalResult = mrOK then
      begin
        NewWritePath := BasePath + 'profiles\' + User;
        if not HDirectoryExists(NewWritePath) then ForceDirectories(NewWritePath);
        AppendStr(NewWritePath, '\');
        EnsureExistence('calmira.ini');
        EnsureExistence('start.ini');
        FileWritePath := NewWritePath;
        UserIni.WriteString('Settings', 'LastUser', User);
      end
      { 3.01 }
      else if UserIni.ReadBool('Settings', 'NoAnonUser', False) then
        if IsShell then ExitWindows(0, 0)
        else Halt;
    finally
      Free;
    end;
    UserList.Free;
  end;
  UserIni.Free;
end;

procedure TLogonDlg.FormCreate(Sender: TObject);
begin
  Left := Screen.Width div 2 - Width div 2;
  Top := Screen.Height div 2 - Height;
  Image1.Picture.Icon.Handle := LoadIcon(HInstance, 'LOGONICON');
  with UserCombo do
  begin
    Items.Assign(UserList);
    Text := UserIni.ReadString('Settings', 'LastUser', '');
  end;
end;

procedure TLogonDlg.FormShow(Sender: TObject);
begin
  if UserCombo.Text > '' then PasswordEdit.SetFocus;
end;

procedure TLogonDlg.OKBtnClick(Sender: TObject);
begin
  User := UserCombo.Text;
  if not IsValidLogin(User) then
    MsgDialogRes(SInvalidUserName, mtError, [mbOK], 0)
  else if UserIni = nil then
    ModalResult := mrCancel
  else if (UserList.IndexOf(User) >= 0) and
    (DecryptPassword(UserIni.ReadString('Users', User, '')) = PasswordEdit.Text) then
      ModalResult := mrOK
  else begin
    PasswordEdit.Clear;
    MsgDialogRes(SInvalidPassword, mtError, [mbOK], 0);
  end;
end;

end.

