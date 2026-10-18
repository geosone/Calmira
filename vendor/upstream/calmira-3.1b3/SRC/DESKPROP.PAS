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

unit Deskprop;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, Chklist, TabNotBk, TabPanel, Picbtn, StylSped;

type
  TDeskPropDlg = class(TForm)
    TabPanel1: TTabPanel;
    Notebook: TNotebook;
    Placement: TRadioGroup;
    Label1: TLabel;
    CheckList: TCheckList;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    WinDesktop: TStyleSpeed;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure WinDesktopClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

{
var
  DeskPropDlg: TDeskPropDlg;
}

implementation

{$R *.DFM}

uses SysUtils, Settings, Desk, Environs, MiscUtil;

procedure TDeskPropDlg.FormCreate(Sender: TObject);
begin
  CheckList.Color := Colors[ccChecklist];
  Notebook.PageIndex := 0;
  Placement.ItemIndex := Integer(WindowOpen);
  CheckList.SetData([SingleStatus, SaveWindows,
    ShortArrows, AnimCursor, ShowDeskMenu, ExploreLastFolder,
    ConfirmDelShort, StickyShorts, OneClickShorts, BrowseSame,
    RightClose, RunAutoClose, DesktopParent]);
  CheckList.Hints.Assign(CheckList.Items); { 3.1 }
  EnableControlList([OKBtn, Notebook], CanEditSettings); { 2.2 }
end;

procedure TDeskPropDlg.OKBtnClick(Sender: TObject);
begin
  WindowOpen := TWindowOpen(Placement.ItemIndex);
  CheckList.GetData([@SingleStatus, @SaveWindows,
    @ShortArrows, @AnimCursor, @ShowDeskMenu, @ExploreLastFolder,
    @ConfirmDelShort, @StickyShorts, @OneClickShorts, @BrowseSame,
    @RightClose, @RunAutoClose, @DesktopParent]);
  SaveDeskProp;
  AnnounceSettingsChanged([scDesktop]);
end;

{ 3.1 }
procedure TDeskPropDlg.WinDesktopClick(Sender: TObject);
var
  buf: array[0..255] of Char;
begin
  WinExec(StrPCopy(buf, EnvironSubst(ini.ReadString('Desktop', 'WinDesktop',
    'control.exe main.cpl Desktop'))), SW_SHOW);
end;

end.

