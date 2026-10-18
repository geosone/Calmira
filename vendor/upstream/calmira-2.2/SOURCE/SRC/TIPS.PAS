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

unit Tips;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Buttons, ExtCtrls;

type
  TTipDialog = class(TForm)
    CloseBtn: TBitBtn;
    NextTip: TBitBtn;
    cbShowDailyTips: TCheckBox;
    Label1: TLabel;
    Panel1: TPanel;
    Label2: TLabel;
    HomePage: TBitBtn;
    BitBtn4: TBitBtn;
    TipLabel: TLabel;
    Bevel1: TBevel;
    Image1: TImage;
    procedure FormShow(Sender: TObject);
    procedure NextTipClick(Sender: TObject);
    procedure CloseBtnClick(Sender: TObject);
    procedure BitBtn4Click(Sender: TObject);
    procedure HomePageClick(Sender: TObject);
    procedure cbShowDailyTipsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    function GetTip(const filename: string): string;
  public
    { Public declarations }
  end;

var
  TipDialog: TTipDialog;

implementation

{$R *.DFM}

uses FileMan, Settings, Strings, Files, MiscUtil;

function TTipDialog.GetTip(const filename: string): string;
var
  f: TextFile;
  Count, i : Integer;
begin
  if not FileExists(filename) then begin
    Result := TipLabel.Caption;
    Exit;
  end;

  ShowHourglass;
  FileMode := 0;
  AssignFile(f, filename);
  Reset(f);
  try
    Readln(f, Count);
    for i := 0 to Random(Count) do begin
      repeat
        Readln(f, Result);
      until Eof(f) or (not Blank(Result) and (Result[1] <> ';'));
      if Eof(f) then Break;
    end;
  finally
    CloseFile(f);
  end;
end;


procedure TTipDialog.FormShow(Sender: TObject);
begin
  NextTip.Click;
end;

procedure TTipDialog.NextTipClick(Sender: TObject);
begin
  TipLabel.Caption := GetTip(ApplicationPath + 'tips.txt');
end;

procedure TTipDialog.CloseBtnClick(Sender: TObject);
begin
  Close;
  ini.WriteString('Calmira', 'DateLastRun', DateToStr(Date));
end;

procedure TTipDialog.BitBtn4Click(Sender: TObject);
begin
   Application.HelpJump('Contents');
end;

procedure TTipDialog.HomePageClick(Sender: TObject);
begin
  DefaultExec('http://www.tribbles.demon.co.uk/calmira/', '', '', SW_SHOW);
end;

procedure TTipDialog.cbShowDailyTipsClick(Sender: TObject);
begin
  ShowDailyTips := cbShowDailyTips.Checked;
  ini.WriteBool('Preferences', 'ShowDailyTips', ShowDailyTips);
end;

procedure TTipDialog.FormCreate(Sender: TObject);
begin
  cbShowDailyTips.Checked := ShowDailyTips;
  CloseBtn.Cancel := True;
  Panel1.Color := Application.HintColor;
end;

initialization
  Randomize;
end.
