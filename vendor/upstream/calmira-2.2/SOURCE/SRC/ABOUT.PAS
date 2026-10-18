{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.2                                                    }
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

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, Picbtn;

type
  TAboutBox = class(TForm)
    Image: TImage;
    ProductName: TLabel;
    VersionLabel: TLabel;
    Copyright: TLabel;
    Email: TLabel;
    MemLabel: TLabel;
    ResLabel: TLabel;
    Label2: TLabel;
    Bevel1: TBevel;
    HomePage: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    LicenseBtn: TPicBtn;
    OKButton: TPicBtn;
    procedure LicenseBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure HomePageClick(Sender: TObject);
    procedure ImageClick(Sender: TObject);
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
  license := ApplicationPath + 'LICENSE.TXT';

  if not FileExists(license) then
    MsgDialogRes(SCannotFindLicense, mtError, [mbOK], 0)
  else
    if ExecuteFile('notepad.exe', license, '', 'Open', SW_SHOWMAXIMIZED) <= 32 then
    MsgDialogRes(SCannotRunNotepad, mtError, [mbOK], 0);
end;


procedure TAboutBox.FormCreate(Sender: TObject);
begin
  OKButton.Cancel := True;

  MemLabel.Caption := FormatByte(GetFreeSpace(0), 2) + ' Free';
  ResLabel.Caption := Format('System %d%%    GDI %d%%    USER %d%%',
    [GetFreeSystemResources(GFSR_SYSTEMRESOURCES),
     GetFreeSystemResources(GFSR_GDIRESOURCES),
     GetFreeSystemResources(GFSR_USERRESOURCES)]);

  Image.Picture.Bitmap.Handle := LoadBitmap(HInstance, 'LOGO');

  if FirstRun then begin
    Caption := LoadStr(SWelcome);
    FirstRun := False;
  end;
end;

procedure TAboutBox.HomePageClick(Sender: TObject);
begin
  { 2.2 added http:// }
  DefaultExec('http://www.tribbles.demon.co.uk/calmira', '', '', SW_SHOW);
end;

procedure TAboutBox.ImageClick(Sender: TObject);
begin
  Desktop.Revert;
end;

end.

