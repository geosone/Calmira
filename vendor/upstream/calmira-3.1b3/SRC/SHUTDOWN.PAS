{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-2000 Calmira Online!                               }
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
    SystemMenu: TSystemMenu;
    procedure OKBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure rbDOSDblClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ImageDblClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
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
  CompSys;

{
var
  QuitDlg: TQuitDlg;
}

procedure TQuitDlg.OKBtnClick(Sender: TObject);
var
  i: Integer;
begin
  i := GetRadioIndex([rbDOS, rbRestart, rbReboot, rbQuit]);
  Release;
  ShowHourglass;
  Desktop.Save;
  if (i < 3) and ShowShutDownBMP then DrawShutDownBMP;
  case i of
    0: ExitWindows(0, 0);
    1: ExitWindows(EW_RESTARTWINDOWS, 0);
    2: ExitWindows(EW_REBOOTSYSTEM, 0);
    3: begin
         if IsShell and MultipleProfiles then
         begin
           Restart := True;
           WinExec('calmira.exe Kgt7sT4q', SW_SHOW);
         end;
         Application.Terminate;
       end;
  end;
end;

procedure TQuitDlg.FormCreate(Sender: TObject);
begin
  with SystemMenu do
  begin
    DeleteCommand(SC_RESTORE);
    DeleteCommand(SC_SIZE);
    DeleteCommand(SC_MINIMIZE);
    DeleteCommand(SC_MAXIMIZE);
    DeleteCommand(SC_TASKLIST);
    Delete(1);
    Delete(2);
  end;
  Image.Picture.Icon.Assign(Icons.Get('ShutDownDialog'));
  rbQuit.Visible := not IsShell or MultipleProfiles;
  if IsShell and MultipleProfiles then
    rbQuit.Caption := 'Log on as another user?';
  rbQuit.Checked := not IsShell;
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

procedure TQuitDlg.FormPaint(Sender: TObject);
begin
  Border3D(Canvas, ClientWidth-1, ClientHeight-1);
end;

procedure TQuitDlg.DarkenScreen;
var
  pattern: HBitmap;
  brush, oldbrush: HBrush;
  dc: HDC;
begin
  pattern := LoadBitmap(HInstance, 'SCREENMESH');
  brush := CreatePatternBrush(pattern);
  dc := GetDC(0);
  oldbrush := SelectObject(dc, brush);
  PatBlt(dc, 0, 0, Screen.Width, Screen.Height, $A000C9);
  SelectObject(dc, oldbrush);
  ReleaseDC(0, dc);
  DeleteObject(brush);
  DeleteObject(pattern);
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

