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

unit Shutdown;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, Messages, Picbtn;

type
  TQuitDlg = class(TForm)
    rbDOS: TRadioButton;
    rbQuit: TRadioButton;
    rbRestart: TRadioButton;
    rbReboot: TRadioButton;
    Bevel1: TBevel;
    Image1: TImage;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    procedure OKBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure rbDOSDblClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Image1DblClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;


implementation

{$R *.DFM}

uses MiscUtil, Settings, Desk, Task, IniFiles;

{var QuitDlg: TQuitDlg;}


procedure TQuitDlg.OKBtnClick(Sender: TObject);
begin
  ShowHourglass;
  Desktop.Save;
  case GetRadioIndex([rbDOS, rbQuit, rbRestart, rbReboot]) of
   0: ExitWindows(0, 0);
   1: Application.Terminate;
   2: ExitWindows(EW_RESTARTWINDOWS, 0);
   3: ExitWindows(EW_REBOOTSYSTEM, 0);
  end;
end;

procedure TQuitDlg.FormCreate(Sender: TObject);
begin
  rbQuit.Enabled := not IsShell;
end;

procedure TQuitDlg.FormShow(Sender: TObject);
begin
  SetSysModalWindow(Handle);
end;

procedure TQuitDlg.rbDOSDblClick(Sender: TObject);
begin
  OKBtn.Click;
end;


procedure TQuitDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  { After the system modal state, the taskbar needs a nudge to its
    message queue to repaint.  Previously, this was provided naturally
    by the mouse hook, but a bug fix changed PostMessage to SendMessage
    which doesn't have the same effect.  WM_GETTEXTLENGTH is relatively
    harmless! }

  PostMessage(TaskBar.Handle, WM_GETTEXTLENGTH, 0, 0);
end;

procedure TQuitDlg.Image1DblClick(Sender: TObject);
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

end.
