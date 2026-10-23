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

unit Replace;

interface

uses
  Classes, SysUtils, Controls, Forms, StdCtrls, Buttons, ExtCtrls, Picbtn, LfnUtils;

type
  TReplaceBox = class(TForm)
    Label3: TLabel;
    Target1: TLabel;
    Target2: TLabel;
    Label4: TLabel;
    Source1: TLabel;
    Source2: TLabel;
    Image1: TImage;
    YesBtn: TPicBtn;
    NoBtn: TPicBtn;
    AllBtn: TPicBtn;
    CancelBtn: TPicBtn;
    Label1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    function Query(const Filename, Destname: TLfnFilename): Integer;
  end;

var
  ReplaceBox: TReplaceBox;

implementation

{$IFNDEF FPC}{$R *.dfm}{$ENDIF}

uses Strings, MiscUtil, WinProcs, WinTypes, Desk;

procedure AssignDetails(const fname: TLfnFilename; NameLabel, InfoLabel: TLabel);
var
  rec :TLfnSearchRec;
begin
  LFindFirst(fname, faAnyfile, rec);
  NameLabel.Caption := fname;
  InfoLabel.Caption := Format('%s  %s', [FormatByte(rec.Size, 2, 2),
    FormatDateTime('dddd d mmmm yyyy,  hh:mm am/pm',
    TimestampToDate(rec.Time))]);
  LFindClose(rec); { 3.11 }
end;

function TReplaceBox.Query(const Filename, Destname: TLfnFilename): Integer;
begin
  AssignDetails(Destname, Target1, Target2);
  AssignDetails(Filename, Source1, Source2);
  Desktop.SetCursor(crDefault);
  try
    Result := ShowModal;
  finally
    Desktop.ReleaseCursor;
  end;
end;

procedure TReplaceBox.FormCreate(Sender: TObject);
begin
{$IFDEF FPC}
  Image1.Picture.Icon.LoadFromResource(0, IDI_QUESTION);
{$ELSE}
  Image1.Picture.Icon.Handle := LoadIcon(0, IDI_QUESTION);
{$ENDIF}
end;

procedure TReplaceBox.FormShow(Sender: TObject);
begin
  if MsgDialogSounds then MessageBeep(MB_ICONQUESTION);
end;

end.

