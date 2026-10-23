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

unit SysRefed;

interface

uses Classes, Forms, Controls, Buttons, StdCtrls, ExtCtrls, Dialogs,
  StylSped, Icondlg, SysUtils, TabNotBk, SysRefer, TabPanel, Picbtn, LfnUtils;

type
  TSysRefEditDlg = class(TForm)
    IconDialog: TIconDialog;
    OpenDialog: TOpenDialog;
    TabPanel: TTabPanel;
    Notebook: TNotebook;
    CapEdit: TEdit;
    Label1: TLabel;
    TargetEdit: TEdit;
    OKBtn: TPicBtn;
    CancelBtn: TPicBtn;
    HelpBtn: TPicBtn;
    BrowseTarget: TStyleSpeed;
    Bevel1: TBevel;
    CaptionLabel: TLabel;
    TargetIcon: TImage;
    TargetLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure BrowseTargetClick(Sender: TObject);
    procedure BrowseFolderClick(Sender: TObject);
    procedure BrowseIconClick(Sender: TObject);
    procedure TargetLabelMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TargetLabelMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    { 3.1 }
    procedure CapEditExit(Sender: TObject);
    procedure TargetEditExit(Sender: TObject);
  private
    { Private declarations }
    SaveHistory: Boolean;
    FSystemString: string;
    procedure SetSystemString(str:string);
    {FReference: TReference;}
    {FRefKind: TReferenceKind;}
    procedure AdjustTargetBevel;
    {procedure SetRefKind(Value: TReferenceKind);}
    procedure AssignTargetIcon; { 3.1 }
  public
    { Public declarations }
    property SystemString: string Read FSystemString write SetSystemString;
    {property Reference: TReference read FReference write FReference;}
    {property RefKind: TReferenceKind read FRefKind write SetRefKind;}
  end;

var
  SysRefEditDlg: TSysRefEditDlg;

function ExtractIconFile(const s: string): TLfnFileName;
function ExtractIconIndex(const s: string): Integer;

implementation

{$IFNDEF FPC}{$R *.dfm}{$ENDIF}

uses Graphics, ShellAPI, Strings, Settings, WinProcs, WinTypes,
  Resource, Tree, MiscUtil, Locale, Environs;

function ExtractIconFile(const s: string): TLfnFileName;
begin
  Result := '';
  Unformat(s, '%s(', [@Result, 79]);
end;

function ExtractIconIndex(const s: string): Integer;
begin
  Result := 0;
  Unformat(s, '%S(%d)', [@Result]);
end;

procedure TSysRefEditDlg.FormCreate(Sender: TObject);
begin
  Notebook.PageIndex := 0;
  ini.ReadStrings('IconSources', IconDialog.HistoryList);
  { 3.1 }
  BrowseTarget.Glyph.Handle := LoadBitmap(HInstance, 'BBBROWSE');
  {BrowseIcon.Glyph.Handle := LoadBitmap(HInstance, 'BBBROWSE');}
  {BrowseFolder.Glyph.Handle := LoadBitmap(HInstance, 'BBBROWSE');}
  SystemString := '_default';
end;

procedure TSysRefEditDlg.FormDestroy(Sender: TObject);
begin
  if SaveHistory then
    ini.WriteNewStrings('IconSources', IconDialog.HistoryList);
end;

procedure TSysRefEditDlg.FormShow(Sender: TObject);
begin
  AdjustTargetBevel;
  ActiveControl := CapEdit;
end;

procedure TSysRefEditDlg.BrowseTargetClick(Sender: TObject);
var
 s: string;
begin
  s := SelectFolder(TargetEdit.Text);
  if Pos(' ',s) > 0 then
   s := '"'+s+'"';
  TargetEdit.Text := s;
  AssignTargetIcon; { 3.1 }
  AdjustTargetBevel;
end;

procedure TSysRefEditDlg.BrowseFolderClick(Sender: TObject);
begin
  {FolderEdit.Text := SelectFolder(FolderEdit.Text);}
end;

procedure TSysRefEditDlg.BrowseIconClick(Sender: TObject);
begin
(*  with IconDialog do
  begin
    if IconEdit.Text > '' then Filename := ExtractIconFile(IconEdit.Text)
    else Filename := FirstWord(TargetEdit.Text);
    Index := ExtractIconIndex(IconEdit.Text);
    if Execute then
    begin
      IconEdit.Text := Format('%s(%d)', [Filename, Index]);
      SaveHistory := True;
      AssignTargetIcon; { 3.1 }
    end;
  end;*)
end;

procedure TSysRefEditDlg.TargetLabelMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  {RefKind := TReferenceKind((Ord(RefKind) + 1) mod
    (Ord(High(TReferenceKind)) + 1));}
  AssignTargetIcon;
  {TargetBevel.Style := bsLowered;}
end;

procedure TSysRefEditDlg.TargetLabelMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  {TargetBevel.Style := bsRaised;}
end;

procedure TSysRefEditDlg.CapEditExit(Sender: TObject); { 3.1 }
begin
  CaptionLabel.Caption := CapEdit.Text;
end;

procedure TSysRefEditDlg.TargetEditExit(Sender: TObject); { 3.1 }
begin
  AssignTargetIcon;
end;

procedure TSysRefEditDlg.AdjustTargetBevel; { 3.12 }
begin
{  with TargetLabel do
    TargetBevel.SetBounds(Left - 2, Top - 2, 46, Height + 4);}
end;

procedure TSysRefEditDlg.AssignTargetIcon; { 3.1 }
{var
  LastKind: TReferenceKind;
  TempRef: TSystemReference;}
begin
  (*TempRef := TSystemReference.Create;
  { Use a reference object to do the icon searching}
  TempRef.Target := FirstWord(Lowercase(TargetEdit.Text));
  {TempRef.{IconFile := ExtractIconFile(IconEdit.Text);
  TempRef.IconIndex := ExtractIconIndex(IconEdit.Text);}*)
  TargetIcon.Picture.Icon.Assign(icons.Get(FSystemString));
  (*TempRef.Destroy;*)
end;

procedure TSysRefEditDlg.SetSystemString(str:string);
begin
FSystemString := str;
AssignTargetIcon;
end;

end.

