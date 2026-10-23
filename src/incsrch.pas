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

unit Incsrch;
{$IFDEF FPC}{$mode delphi}{$H-}{$ENDIF}

interface

uses WinTypes, WinProcs, Classes, Graphics,
{$IFDEF FPC}
  native_modal,
{$ELSE}
  Forms, Buttons,
{$ENDIF}
  Controls,
  StdCtrls;

type
  TSearchEvent = procedure (Sender: TObject; const s: string) of object;

  TIncSearchDlg = class({$IFDEF FPC}TNativeModalForm{$ELSE}TForm{$ENDIF})
    Edit: TEdit;
    Label1: TLabel;
    procedure EditChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
    FOnSearch: TSearchEvent;
    FInitialChar: Char;
  public
    { Public declarations }
{$IFDEF FPC}
    constructor Create(AOwner: TComponent); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
{$ENDIF}
    property OnSearch: TSearchEvent read FOnSearch write FOnSearch;
    property InitialChar: Char read FInitialChar write FInitialChar;
  end;

{
var
  IncSearchDlg: TIncSearchDlg;
}

implementation

{$IFNDEF FPC}{$R *.dfm}{$ENDIF}

uses SysUtils
{$IFDEF FPC}, form_text{$ENDIF};

{$IFDEF FPC}
{$I incsrch_form.inc}
{$ENDIF}

procedure TIncSearchDlg.EditChange(Sender: TObject);
begin
  if Assigned(FOnSearch) then FOnSearch(self, Edit.Text);
end;

procedure TIncSearchDlg.FormShow(Sender: TObject);
begin
  with Edit do
  begin
{$IFDEF FPC}
    { The '.' command opens this dialog without setting InitialChar. Native
      short-string edits reject embedded NULs, so preserve the old empty input. }
    if InitialChar = #0 then Text := '' else
{$ENDIF}
    Text := Lowercase(InitialChar);
    SelLength := 0;
    SelStart := 1;
  end;
end;

procedure TIncSearchDlg.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) or (Key = VK_ESCAPE) then Close;
end;

end.

