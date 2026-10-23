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

unit About;

interface

uses LangUI, WinTypes, WinProcs, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, Picbtn, LfnUtils;

type
  TAboutBox = class(TForm)
    AppLogo: TImage;
    VersionLabel: TLabel;
    Copy1Label: TLabel;
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
    Label1: TLabel;
    labWinVer: TLabel;
    Label2: TLabel;
    labDosVer: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    procedure LicenseBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure HomepageLabelClick(Sender: TObject);
    procedure AppLogoClick(Sender: TObject);
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

{$R *.dfm}

uses Strings, SysUtils, Files, MiscUtil, Settings, Fileman,
  Dialogs, Locale, Desk, VerInfo;

procedure TAboutBox.LicenseBtnClick(Sender: TObject);
var
  license : TLfnFileName;
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
var
 tmp: LongInt;
 WinVer, DosVer: Word;
 DosMinor, DosMajor, WinMinor,WinMajor: Byte;
begin
  MemLabel.Caption := FormatByte(GetFreeSpace(0), 2, 2) + ' free';
  ResLabel.Caption := Format('System %d%%  GDI %d%%  User %d%%',
    [GetFreeSystemResources(GFSR_SYSTEMRESOURCES),
     GetFreeSystemResources(GFSR_GDIRESOURCES),
     GetFreeSystemResources(GFSR_USERRESOURCES)]);
  AppLogo.Picture.Bitmap.Handle := LoadBitmap(HInstance, 'LOGO');
  AppTitle.Picture.Bitmap.Handle := LoadBitmap(HInstance, 'TITLE');
  Tmp := GetVersion;
  WinVer := tmp and $FFFF;
  DosVer := (tmp shr 16) and $FFFF;
  WinMajor := WinVer and $ff;
  WinMinor := (WinVer shr 8) and $ff;
  { Check for Win 3.11 }
  if (WinMajor = 3) and (WinMinor = 10) then
    with TVersion.Create('user.exe') do
    begin
      if FileVersion = '3.11' then
        WinMinor := 11;
      Free;
    end;
  DosMinor := DosVer and $ff;
  DosMajor := (DosVer shr 8) and $ff;
  labWinVer.Caption := Format('Windows %d.%d',[Integer(WinMajor),Integer(WinMinor)]);
  labDosVer.Caption := Format('MS-DOS %d.%d',[Integer(DosMajor),Integer(DosMinor)]);
  if FirstRun then
  begin
    Caption := LocalLoadStr(SWelcome);
    FirstRun := False;
  end;
{  with AppLogo.Picture do
    ReplaceBitmapColors(Bitmap, clWhite, Color);
  with AppTitle.Picture do
    ReplaceBitmapColors(Bitmap, clWhite, Color);}
end;

procedure TAboutBox.HomepageLabelClick(Sender: TObject);
begin
  OKButton.Click;
  OpenURL('http://huntertur.net/calmirar.html');
end;

procedure TAboutBox.AppLogoClick(Sender: TObject);
begin
  Desktop.Revert;
end;

end.

