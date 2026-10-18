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

unit Runprog;

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, Dialogs, Settings,
  ExtCtrls, SysUtils, Picbtn;

type
  TRunDlg = class(TForm)
    Label1: TLabel;
    Combo: TComboBox;
    OpenDialog: TOpenDialog;
    Image: TImage;
    BrowseBtn: TPicBtn;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    Label2: TLabel;
    DosCommand: TCheckBox;
    DosSession: TCheckBox;
    procedure OKBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
    procedure BrowseBtnClick(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure DosSessionClick(Sender: TObject);
  private
    { Private declarations }
    Changed: Boolean;
    DefaultDir: TFilename;
  public
    { Public declarations }
  end;

var
  RunDlg: TRunDlg; { 2.2 }

procedure RunExecute(const command: string; const Dir: TFilename);

implementation

{$R *.DFM}

uses Files, WinProcs, WinTypes, MiscUtil, Resource, Environs,
  Strings, Fileman, Desk, Locale;

procedure RunExecute(const command: string; const Dir: TFilename);
begin
  ShowHourglass;
  if RunDlg = nil then RunDlg := TRunDlg.Create(Application);
  with RunDlg do
  begin
    AssignHistoryText(Combo, command);
    WindowState := wsNormal;
    if Dir > '' then DefaultDir := Dir
    else DefaultDir := Environment.Values['WinDir'];
    Show;
  end;
end;

procedure TRunDlg.OKBtnClick(Sender: TObject);
var
  filename, newdir: TFilename;
  params: string;
begin
  Changed := AddHistory(Combo) or Changed;
  with Combo do
    if Text > '' then
    begin
      newdir := '';
      if DosSession.Checked then
      begin
        filename := ApplicationPath + 'dosrun.exe';
        params := Text;
        if (not QueryQuit) or (MsgDialogRes(SNotifyEndWindows, mtInformation,
          [mbOK, mbCancel], 0) = mrOK) then
          begin
            if Changed then ini.RewriteSectionStrings('RunProgram', Combo.Items);
            ExitWindowsExec(StringAsPChar(filename), StringAsPchar(params));
          end
        else Exit
      end
      else if DosCommand.Checked then
      begin
        filename := Environment.Values['COMSPEC'];
        params := '/c ' + Text;
      end
      else
      begin
        filename := FirstWord(EnvironSubst(Text));
        newdir := ExtractFileDir(filename);
        params := '';
        if Length(filename) < Length(Text) then
          params := Copy(Text, Length(filename)+2, 255);
      end;
      if newdir = '' then newdir := DefaultDir;
      if (Length(filename) = 2) and (filename[1] in Alphas) and (filename[2] = ':') then
        AppendStr(filename, '\');
      if HDirectoryExists(filename) then
      begin
        Desktop.OpenFolder(filename);
        if RunAutoClose then Close;
      end
      else if (DefaultExec(filename, params, newdir, SW_SHOW) > 32) and
        RunAutoClose then Close;
    end;
end;

procedure TRunDlg.FormCreate(Sender: TObject);
begin
  Icon.Assign(Icons.Get('RunDialog'));
  Image.Picture.Icon.Assign(Icon);
  ini.ReadStrings('RunProgram', Combo.Items);
end;

procedure TRunDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TRunDlg.FormDestroy(Sender: TObject);
begin
  if Changed then ini.RewriteSectionStrings('RunProgram', Combo.Items);
  RunDlg := nil;
end;

procedure TRunDlg.CancelBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TRunDlg.BrowseBtnClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    Combo.Text := Lowercase(OpenDialog.Filename);
end;

procedure TRunDlg.FormPaint(Sender: TObject);
begin
  Border3D(Canvas, ClientWidth-1, ClientHeight-1);
end;

procedure TRunDlg.DosSessionClick(Sender: TObject);
begin
  DosCommand.Enabled := not DosSession.Checked;
end;

end.

