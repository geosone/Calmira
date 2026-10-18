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

unit Password;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Buttons, Picbtn;

type
  TPasswordDlg = class(TForm)
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    procedure OKBtnClick(Sender: TObject);
  private
    { Private declarations }
    previous: string;
  public
    { Public declarations }
    procedure InitNewUser;
    procedure InitChangePassword(const OldPassword: string);
  end;

var
  PasswordDlg: TPasswordDlg;

function EncryptPassword(const s: string): string;
function DecryptPassword(const s: string): string;
function IsValidLogin(const s: string): Boolean;

implementation

{$R *.DFM}

uses MiscUtil, Strings, Locale;

function Rotate(const s: string): string;
var
  i: Integer;
begin
  Result[0] := s[0];
  for i := 1 to Length(s) do
  case s[i] of
    'A'..'M',
    'a'..'m': Result[i] := Chr(Ord(s[i]) + 13);
    'N'..'Z',
    'n'..'z': Result[i] := Chr(Ord(s[i]) - 13);
  else
    Result[i] := s[i];
  end;
end;

function EncryptPassword(const s: string): string;
var
  i: Integer;
  t: string;
begin
  Result := '';
  t := Rotate(s);
  for i := 1 to Length(t) do AppendStr(Result, IntToHex(Ord(t[i]), 2));
end;

function DecryptPassword(const s: string): string;
var
  i: Integer;
begin
  Result := '';
  i := 1;
  while i < Length(s) do
  begin
    AppendStr(Result, Chr(StrToInt('$' + Copy(s, i, 2))));
    Inc(i, 2);
  end;
  Result := Rotate(Result);
end;

function IsValidLogin(const s: string): Boolean;
var
  i: Integer;
begin
  Result := True;
  if (Length(s) = 0) or (Length(s) > 8) then Result := False;
  for i := 1 to Length(s) do
    if not (s[i] in AlphaDigits) then Result := False;
end;

procedure TPasswordDlg.InitNewUser;
begin
  previous := '';
  Caption := LoadStr(SCreateNewUser);
  Label1.Caption := LoadStr(SUserName);
  Label2.Caption := LoadStr(SEnterPassword);
  Label3.Caption := LoadStr(SConfirmPassword);
  Edit1.PasswordChar := #0;
end;

procedure TPasswordDlg.InitChangePassword(const OldPassword: string);
begin
  previous := OldPassword;
  Caption := LoadStr(SChangePassword);
  Label1.Caption := LoadStr(SEnterOldPassword);
  Label2.Caption := LoadStr(SEnterNewPassword);
  Label3.Caption := LoadStr(SConfirmNewPassword);
  Edit1.PasswordChar := '*';
end;

procedure TPasswordDlg.OKBtnClick(Sender: TObject);
begin
  if not IsValidLogin(Edit1.Text) and (Caption = LoadStr(SCreateNewUser)) then
    MsgDialogRes(SInvalidUserName, mtError, [mbOK], 0)
  else if ((previous = '') or (Edit1.Text = previous)) and (Edit2.Text = Edit3.Text) then
    ModalResult := mrOK
  else if (previous > '') and (Edit1.Text <> previous) then
    MsgDialogRes(SInvalidOldPassword, mtError, [mbOK], 0)
  else
    MsgDialogRes(SPasswordMismatch, mtError, [mbOK], 0);
end;

end.

