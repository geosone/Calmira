{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-1999 Calmira Online!                               }
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

unit Explrwin;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, Menus, Calform, ExtCtrls;

type
  TNewExplorer = class(TCalForm)
    MainMenu: TMainMenu;
    File1: TMenuItem;
    Edit1: TMenuItem;
    View1: TMenuItem;
    Help1: TMenuItem;
    TreePanel: TPanel;
    IconWinPanel: TPanel;
    DragPanel: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure DragPanelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DragPanelMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure DragPanelMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
    MouseDownOnDragPanel : Boolean;
    SliderPanel : TPanel;
  public
    { Public declarations }
    Explorer : TCalForm;
    IconWindow : TCalForm;
  end;

var
  NewExplorer: TNewExplorer;

implementation

{$R *.DFM}

uses Drives, MiscUtil, Settings, Tree, IconWin;

procedure TNewExplorer.FormCreate(Sender: TObject);
begin
  Explorer := TExplorer.Create(Application);
  Explorer.Parent := TreePanel;
  with TreePanel do Explorer.SetBounds(Left, Top, Width, Height);
  IconWindow := TIconWindow.Create(Application);
  IconWindow.Parent := IconWinPanel;
  with IconWinPanel do IconWindow.SetBounds(Left, Top, Width, Height);
  MouseDownOnDragPanel := False;
end;

procedure TNewExplorer.DragPanelMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    SliderPanel := TPanel.Create(Self);
    with SliderPanel do
    begin
      Parent := Self;
      BevelInner := bvNone;
      BevelOuter := bvNone;
      Caption := '';
      Color := clBlack;
      BevelWidth := 1;
      Cursor := crHSplit;
      Top := DragPanel.Top;
      Left := DragPanel.Left;
      Height := DragPanel.Height;
      Width := DragPanel.Width;
      Visible := True;
      Update;
    end;
    MouseDownOnDragPanel := True;
  end;
end;

procedure TNewExplorer.DragPanelMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  ALeft : Integer;
begin
  if MouseDownOnDragPanel then
    begin
      ALeft := DragPanel.Left + X;
      if ALeft < (TreePanel.Left + 20) then
        ALeft := TreePanel.Left + 20
      else if ALeft > (IconWinPanel.Left + IconWinPanel.Width - 20) then
        ALeft := IconWinPanel.Left + IconWinPanel.Width - 20;
      SliderPanel.Left := ALeft;
      Update;
    end;
end;

procedure TNewExplorer.DragPanelMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if MouseDownOnDragPanel then
    begin
      MouseDownOnDragPanel := False;
      SliderPanel.Visible := False;
      TreePanel.Width := SliderPanel.Left - 1;
      Update;
    end;
end;

procedure TNewExplorer.FormShow(Sender: TObject);
begin
  Explorer.Show;
  IconWindow.Show;
end;

end.

