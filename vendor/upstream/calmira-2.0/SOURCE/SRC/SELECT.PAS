{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.0                                                    }
{    Copyright (C) 1997  Li-Hsin Huang                                     }
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

unit Select;

interface

uses WinTypes, WinProcs, Classes, Graphics, Forms, Controls, Buttons,
  StdCtrls, ExtCtrls, StylSped;

type
  TSelectFileEvent = procedure(Sender : TObject; const FileSpec : string;
    select : Boolean) of object;

  TSelectFileDlg = class(TForm)
    Edit: TEdit;
    Bevel1: TBevel;
    Label1: TLabel;
    SelectBtn: TBitBtn;
    DeselectBtn: TBitBtn;
    CloseBtn: TBitBtn;
    Label2: TLabel;
    procedure SelectBtnClick(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    FSelectFiles : TSelectFileEvent;
  public
    { Public declarations }
    property OnSelectFiles : TSelectFileEvent read FSelectFiles write FSelectFiles;
  end;

var
  SelectFileDlg: TSelectFileDlg;

implementation

{$R *.DFM}

uses Strings;

procedure TSelectFileDlg.SelectBtnClick(Sender: TObject);
var
  s: string;
begin
  if Assigned(FSelectFiles) then begin
    s := Edit.Text;
    repeat
      FSelectFiles(self, GetWord(s, ';'), Sender = SelectBtn);
    until s = '';
  end;
end;


procedure TSelectFileDlg.CloseBtnClick(Sender: TObject);
begin
  Close;
end;


procedure TSelectFileDlg.FormCreate(Sender: TObject);
begin
  CloseBtn.Cancel := True;
end;

end.
