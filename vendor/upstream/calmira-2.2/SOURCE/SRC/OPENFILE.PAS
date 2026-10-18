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

unit Openfile;

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, Dialogs, Picbtn;

type
  TOpenFileDlg = class(TForm)
    Combo: TComboBox;
    Label1: TLabel;
    Listbox: TListBox;
    OpenDialog: TOpenDialog;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    procedure OKBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ComboDblClick(Sender: TObject);
    procedure ListboxClick(Sender: TObject);
    procedure ListboxDblClick(Sender: TObject);
  private
    { Private declarations }
    Changed : Boolean;
  public
    { Public declarations }
    class function Execute : string;
  end;


implementation

{$R *.DFM}

uses Settings, Start, MiscUtil, Menus, SysUtils;

var
  OpenFileDlg: TOpenFileDlg;

procedure TOpenFileDlg.OKBtnClick(Sender: TObject);
begin
  Changed := AddHistory(Combo) or Changed;
end;

procedure TOpenFileDlg.FormCreate(Sender: TObject);
var
  i: Integer;
  item : TMenuItem;
begin
  ini.ReadStrings('OpenFileWith', Combo.Items);
  if Combo.Items.Count > 0 then Combo.Text := Combo.Items[0];
  ini.ReadSection('File Viewers', Listbox.Items);
end;

class function TOpenFileDlg.Execute : string;
begin
  OpenFileDlg := TOpenFileDlg.Create(Application);
  try
    if OpenFileDlg.ShowModal = mrOK then
      Result := OpenFileDlg.Combo.Text
    else Result := '';
  finally
    OpenFileDlg.Free;
    OpenFileDlg := nil;
  end;
end;

procedure TOpenFileDlg.FormDestroy(Sender: TObject);
begin
  if Changed then
    ini.RewriteSectionStrings('OpenFileWith', Combo.Items);
end;

procedure TOpenFileDlg.ComboDblClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    Combo.Text := Lowercase(OpenDialog.Filename);
end;

procedure TOpenFileDlg.ListboxClick(Sender: TObject);
begin
  with Listbox do
  Combo.Text := ini.ReadString('File Viewers', Items[ItemIndex], '');
end;

procedure TOpenFileDlg.ListboxDblClick(Sender: TObject);
begin
  OKBtn.Click;
end;

end.
