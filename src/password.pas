{**************************************************************************}
{                                                                          }
{    Calmira Reborn shell for Microsoft(R) Windows(TM) 3.1                 }
{    Version 5.0                                                           }
{    Copyright (C) 2022-2023 Hunter Turcin                                      }
{    Copyright (C) 2004-2007 Alexandre Rodrigues de Sousa                  }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    This program is free software; you can redistribute it and/or modify  }
{    it under the terms of the GNU General Public License as published by  }
{    the Free Software Foundation; either version 2 of the License, or     }
{    (at your option) any later version.                                   }
{                                                                          }
{    This program is distributed in the hope that it will be useful,       }
{    but WITHOUT ANY WARRANTY; without even the implied warranty of        }
{    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         }
{    GNU General Public License for more details.                          }
{                                                                          }
{    You should have received a copy of the GNU General Public License     }
{    along with this program; if not, write to the Free Software           }
{    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.             }
{                                                                          }
{**************************************************************************}

unit Password;
{$IFDEF FPC}{$mode delphi}{$H-}{$ENDIF}

interface

uses
{$IFDEF FPC}
  Forms, StdCtrls,
{$ELSE}
  LangUI, Forms, Dialogs, StdCtrls,
{$ENDIF}
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Buttons, Picbtn;

type
{$IFDEF FPC}
  TPasswordErrorEvent = procedure(Sender: TObject; Ident: Word) of object;
{$ENDIF}
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
    { Keep the FPC instance below the Win16 direct-allocation threshold. }
    previous: {$IFDEF FPC}AnsiString{$ELSE}string{$ENDIF};
{$IFDEF FPC}
    FNewUser, FInitialized: Boolean;
    FOnValidationError: TPasswordErrorEvent;
    procedure ValidationError(Ident: Word);
    procedure ResetInput;
{$ENDIF}
  public
    { Public declarations }
{$IFDEF FPC}
    property OnValidationError: TPasswordErrorEvent read FOnValidationError write FOnValidationError;
{$ENDIF}
    procedure InitNewUser;
    procedure InitChangePassword(const OldPassword: string);
  end;

var
  PasswordDlg: TPasswordDlg;

function EncryptPassword(const s: string): string;
function DecryptPassword(const s: string): string;
function IsValidLogin(const s: string): Boolean;

implementation

{$IFNDEF FPC}{$R *.dfm}{$ENDIF}

uses
{$IFDEF FPC}
  legacy_password, resource_text,
{$ELSE}
  MiscUtil, Strings,
{$ENDIF}
  Locale;

{$IFDEF FPC}
procedure TPasswordDlg.ResetInput;
begin
  if Visible or ModalRunning then raise Exception.Create('Cannot reinitialize visible dialog');
  FInitialized := False;
  Edit1.Clear; Edit2.Clear; Edit3.Clear;
  Edit2.MaxLength := MaxLegacyPasswordLength; Edit3.MaxLength := MaxLegacyPasswordLength;
  InitialControl := Edit1; ModalResult := mrNone;
end;
procedure TPasswordDlg.ValidationError(Ident: Word);
var Text, Title: array[0..255] of Char;
begin
  if Assigned(FOnValidationError) then FOnValidationError(Self, Ident)
  else
  begin
    StrPCopy(Text, LocalLoadStr(Ident)); StrPCopy(Title, Caption);
    MessageBox(Handle, Text, Title, MB_OK or MB_ICONHAND);
  end;
end;
function EncryptPassword(const s: string): string;
begin Result := legacy_password.EncryptPassword(s); end;
function DecryptPassword(const s: string): string;
begin Result := legacy_password.DecryptPassword(s); end;
function IsValidLogin(const s: string): Boolean;
begin Result := legacy_password.IsValidLogin(s); end;
{$ELSE}

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
{$ENDIF}

procedure TPasswordDlg.InitNewUser;
begin
{$IFDEF FPC}
  ResetInput; FNewUser := True; Edit1.MaxLength := 8;
{$ENDIF}
  previous := '';
  Caption := LocalLoadStr(SCreateNewUser);
  Label1.Caption := LocalLoadStr(SUserName);
  Label2.Caption := LocalLoadStr(SEnterPassword);
  Label3.Caption := LocalLoadStr(SConfirmPassword);
  Edit1.PasswordChar := #0;
{$IFDEF FPC}
  FInitialized := True;
{$ENDIF}
end;

procedure TPasswordDlg.InitChangePassword(const OldPassword: string);
begin
{$IFDEF FPC}
  if Length(OldPassword) > MaxLegacyPasswordLength then
    raise EConvertError.Create('Legacy password too long');
  ResetInput; FNewUser := False; Edit1.MaxLength := MaxLegacyPasswordLength;
{$ENDIF}
  previous := OldPassword;
  Caption := LocalLoadStr(SChangePassword);
  Label1.Caption := LocalLoadStr(SEnterOldPassword);
  Label2.Caption := LocalLoadStr(SEnterNewPassword);
  Label3.Caption := LocalLoadStr(SConfirmNewPassword);
  Edit1.PasswordChar := '*';
{$IFDEF FPC}
  FInitialized := True;
{$ENDIF}
end;

procedure TPasswordDlg.OKBtnClick(Sender: TObject);
begin
{$IFDEF FPC}
  { Validation mode is state, never a translated/window-edited caption. }
  ModalResult := mrNone;
  if not FInitialized then raise Exception.Create('Password mode not initialized');
  if (Length(Edit2.Text) > MaxLegacyPasswordLength) or (Length(Edit3.Text) > MaxLegacyPasswordLength) then
    raise EConvertError.Create('Legacy password too long');
  if FNewUser and not IsValidLogin(Edit1.Text) then ValidationError(SInvalidUserName)
  else if not FNewUser and (Edit1.Text <> previous) then ValidationError(SInvalidOldPassword)
  else if Edit2.Text <> Edit3.Text then ValidationError(SPasswordMismatch)
  else ModalResult := mrOK;
{$ELSE}
  if not IsValidLogin(Edit1.Text) and (Caption = LocalLoadStr(SCreateNewUser)) then
    MsgDialogRes(SInvalidUserName, mtError, [mbOK], 0)
  else if ((previous = '') or (Edit1.Text = previous)) and (Edit2.Text = Edit3.Text) then
    ModalResult := mrOK
  else if (previous > '') and (Edit1.Text <> previous) then
    MsgDialogRes(SInvalidOldPassword, mtError, [mbOK], 0)
  else
    MsgDialogRes(SPasswordMismatch, mtError, [mbOK], 0);
{$ENDIF}
end;

end.

