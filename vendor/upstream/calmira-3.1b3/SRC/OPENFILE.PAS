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

unit Openfile;

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, Dialogs, Picbtn, StylSped,
  Registry;

type
  TOpenFileDlg = class(TForm)
    Combo: TComboBox;
    Label1: TLabel;
    Listbox: TListBox;
    OpenDialog: TOpenDialog;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    BrowseBtn: TStyleSpeed;
    Label2: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure BrowseBtnClick(Sender: TObject);
    procedure ListboxClick(Sender: TObject);
    procedure ListboxDblClick(Sender: TObject);
  private
    { Private declarations }
    Changed: Boolean;
    reg: TRegistry;
  public
    { Public declarations }
    class function Execute: string;
  end;

implementation

{$R *.DFM}

uses WinProcs, SysUtils, Settings, Start, MiscUtil, Strings;

var
  OpenFileDlg: TOpenFileDlg;

procedure TOpenFileDlg.FormCreate(Sender: TObject);
var
  key, command: string[79];
  i: Integer;
begin
  BrowseBtn.Glyph.Handle := LoadBitmap(HInstance, 'BROWSEBMP');
  reg := TRegistry.Create;
  ini.ReadStrings('OpenFileWith', Combo.Items);
  if Combo.Items.Count > 0 then Combo.Text := Combo.Items[0];
  i := 0;
  while reg.EnumKey('', i, key) do
  begin
    if key[1] <> '.' then
    begin
      command := reg.ReadString(key + '\shell\open\command');
      if command > '' then ListBox.Items.Add(format('%s  (' + key + ')',
        [FirstWord(ExtractFilename(command))]));
    end;
    Inc(i);
  end;
end;

class function TOpenFileDlg.Execute: string;
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
  reg.Free;
end;

procedure TOpenFileDlg.OKBtnClick(Sender: TObject);
begin
  Changed := AddHistory(Combo) or Changed;
end;

procedure TOpenFileDlg.BrowseBtnClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    Combo.Text := Lowercase(OpenDialog.Filename);
end;

procedure TOpenFileDlg.ListboxClick(Sender: TObject);
var
  s: string;
begin
  with Listbox do
  Unformat(Items[ItemIndex], '%S  (%s)', [@s, 79]);
  Combo.Text := FirstWord(reg.ReadString(s + '\shell\open\command'));
end;

procedure TOpenFileDlg.ListboxDblClick(Sender: TObject);
begin
  OKBtn.Click;
end;

end.

