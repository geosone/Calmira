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

unit Diskprop;

interface

uses
  Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, Buttons, ExtCtrls,
  TabNotBk, BarGauge, LabelSel, TabPanel, Picbtn, Drives, FileCtrl;

type
  TDiskDialog = class(TForm)
    LabelSel: TLabelSelect;
    TabPanel1: TTabPanel;
    Notebook: TNotebook;
    DriveImage: TImage;
    Label10: TLabel;
    DriveLetter: TLabel;
    Label1: TLabel;
    Label11: TLabel;
    DriveTypeLabel: TLabel;
    Label12: TLabel;
    DriveSize: TLabel;
    DriveFree: TLabel;
    Bevel1: TBevel;
    Label13: TLabel;
    Label14: TLabel;
    UsedLabel: TLabel;
    Gauge: TWin95Gauge;
    OKBtn: TPicBtn;
    VolLabel: TEdit;
    procedure FormShow(Sender: TObject);
    procedure DriveImageClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure DriveTypeLabelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure VolLabelKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure VolLabelKeyPress(Sender: TObject; var Key: Char);
    procedure VolLabelKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
    DriveType: TDriveType; { 2.2 }
    Drive: Char;           { 2.2 }
    procedure DetectLabel;  { 2.2 }
  end;

procedure DiskPropExecute(DriveChar: Char);

implementation

{$R *.DFM}

uses Strings, Resource, Settings, Files, Environs, WinTypes, FileMan, MiscUtil;

{
var
  DiskDialog: TDiskDialog;
}

procedure TDiskDialog.FormShow(Sender: TObject);
var
  dnum: Integer;
  size, free: Longint;
begin
  { 2.2 }
  DriveLetter.Caption := Drive + ':';
  dnum := DriveNumber(Drive);
  DriveType := GuessDriveType(Drive);
  DriveTypeLabel.Caption := DriveDesc[DriveType];
  DriveImage.Picture.Icon := icons.Drive[DriveType];
  DetectLabel;
  size := DiskSize(dnum);
  if size <> -1 then free := DiskFree(dnum);
  if size <> -1 then
  begin
    DriveSize.Caption := FormatByte(size, 2);
    if size > 1024 then DriveSize.Hint := FormatByteLong(size);
    DriveFree.Caption := FormatByte(free, 2);
    if free > 1024 then DriveFree.Hint := FormatByteLong(free);
    if size > 1024 then
    begin
      size := size div 1024;
      free := free div 1024;
    end;
    Gauge.MaxValue := size;
    Gauge.Progress := size - free;
    UsedLabel.Caption := Format('%d%%', [Gauge.GetPercentDone]);
  end;
  with Gauge do
  begin
    ForeColor := Colors[ccPercent];
    BackColor := Colors[ccPercentBack];
  end;
  if not (dfWriteable in GetDriveFlags(Drive)) then
  begin
    { 3.0 }
    VolLabel.Color := clSilver;
    VolLabel.ReadOnly := True;
  end;
end;

procedure TDiskDialog.DriveImageClick(Sender: TObject);
begin
  { 2.12 }
  Environment.Values['CURRENTDRIVE'] := DriveLetter.Caption[1];
  DefaultExecCommand(DiskProg, '', SW_SHOW);
end;

procedure TDiskDialog.DetectLabel;
begin
  { 2.2 }
  ShowHourglass;
  if DriveType = dtNetwork then VolLabel.Text := GetNetworkVolume(drive)
  else VolLabel.Text := GetExactVolumeLabel(drive);
  ShowArrow;
end;

procedure DiskPropExecute(DriveChar: Char);
begin
  ShowHourglass;
  with TDiskDialog.Create(Application) do
  try
    Drive := UpCase(DriveChar);
    ShowModal;
  finally
    Free;
  end;
end;

procedure TDiskDialog.FormCreate(Sender: TObject);
begin
  OKBtn.Cancel := True;
  Notebook.PageIndex := 0;
end;

procedure TDiskDialog.DriveTypeLabelMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then LabelSel.Overlay(Sender as TLabel);
end;

procedure TDiskDialog.VolLabelKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  { 2.2 }
  if (Key = VK_RETURN) and (dfWriteable in GetDriveFlags(Drive)) and
    not (dfNetwork in GetDriveFlags(Drive)) then
    begin
      ShowHourglass;
      SetVolumeLabel(VolLabel.Text, Drive);
      Key := 0;
      DetectLabel;
    end;
end;

procedure TDiskDialog.VolLabelKeyPress(Sender: TObject; var Key: Char);
begin
  { 2.2 }
  if Key = #13 then Key := #0;
end;

procedure TDiskDialog.VolLabelKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  { 2.2 }
  if Key = VK_RETURN then Key := 0;
end;

end.

