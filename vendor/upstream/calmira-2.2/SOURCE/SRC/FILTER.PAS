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

unit Filter;

interface

uses
  Classes, Controls, Forms, StdCtrls, Buttons, ExtCtrls, Directry, Chklist,
  Picbtn;

type
  TFilterDialog = class(TForm)
    Label1: TLabel;
    Label2: TLabel;
    Bevel1: TBevel;
    CheckList: TCheckList;
    Label3: TLabel;
    FilterEdit: TComboBox;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    function Execute(Dir : TDirectory): TModalResult;
  end;

{
var
  FilterDialog: TFilterDialog;
}

implementation

{$R *.DFM}

uses SysUtils, Settings, MiscUtil, Strings;

function TFilterDialog.Execute(Dir : TDirectory): TModalResult;
var
  details : TFileDetails;
  i: Integer;
  b: array[0..4] of Boolean;
  hidsys : Boolean;
begin
  FilterEdit.Text := Dir.Filter;
  details := Dir.Columns;

  CheckList.SetData([Dir.Mask and faHidden <> 0, fdSize in details,
    fdDate in details, fdTime in details, fdAttr in details, fdDesc in details]);

  Result := ShowModal;

  if Result = mrOK then begin
    Dir.Filter := FilterEdit.Text;
    CheckList.GetData([@hidsys, @b[0], @b[1], @b[2], @b[3], @b[4]]);
    Dir.Mask := DirectoryMasks[hidsys];

    details := [];
    for i := 0 to 4 do if b[i] then Include(details, TFileDetail(i));
    Dir.Columns := details;
  end;
end;

procedure TFilterDialog.FormCreate(Sender: TObject);
begin
  ini.ReadStrings('Browser Filters', FilterEdit.Items);
end;

procedure TFilterDialog.OKBtnClick(Sender: TObject);
begin
  with FilterEdit do begin
    Text := RemoveSpaces(Text);
    if Text = '' then Text := DefaultFilter;
  end;

  if AddHistory(FilterEdit) then
    ini.RewriteSectionStrings('Browser Filters', FilterEdit.Items);
end;

end.
