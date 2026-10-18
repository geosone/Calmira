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

unit Iconic;

interface

uses WinTypes, SysUtils, Graphics, FileCtrl, Referenc, Shorts, Embed;

type
  TSmallStr = string[15];

  { TIconic is the base class for all objects which are shown as
    icons in a window.  This includes disk drives, files, folders
    and aliases.

    FName - a string to hold a short caption or filename
    FIcon - a pointer which descandants should maintain themselves.

    Draw - provides a simple way to display the object by drawing
      the icon with the caption underneath.  Descandants override
      this for more complex drawing.

    InternalDraw - does the actual drawing (called by Draw).

    Open - abstract method that determines what happens when you
      double click on the object

    AssignRef - abstract method that fills the fields of a
      TReference object with information about the TIconic object

    CreateShortcut - returns a new shortcut to the object.
      This uses AssignRef so it must be called from descandants.

    WriteAlias - creates and alias file for the object, and
      if necessary, updates the window which should display the
      alias. }

  TIconic = class
    protected
      FIcon: TIcon;
      procedure InternalDraw(Canvas: TCanvas; const Rect: TRect; const Text: string);
    public
      procedure Draw(Canvas: TCanvas; const Rect: TRect); virtual; abstract;
      procedure Open; virtual; abstract;
      procedure AssignRef(ref: TReference); virtual; abstract;
      function CreateShortcut : TShort;
      procedure WriteAlias(filename: TFilename);
      property Icon: TIcon read FIcon write FIcon;
    end;

const
  DefaultDriveNames : array[TDriveType] of string[15] =
    (SSUnknownDrive, SSNoDrive, SSFloppyDrive, SSFixedDrive,
     SSNetworkDrive, SSCDROMDrive, SSRamDrive);

type
  TShortCaption = string[31];

  TComputerIcon = class(TIconic)
  private
    FCaption: TShortCaption;
  public
    procedure Draw(Canvas: TCanvas; const Rect: TRect); override;
    property Caption: TShortCaption read FCaption write FCaption;
  end;

  { TDrive represents a disk drive in the system window.
    TProgram represents a Windows program in the system window.
    Their functionality is minimal. }

  TDrive = class(TComputerIcon)
  private
    FLetter : Char;
    FDriveType : TDriveType;
  public
    constructor Create(ADrive : Char);
    procedure Open; override;
    procedure AssignRef(ref: TReference); override;
    function Root : TFilename;
    property Letter: Char read FLetter;
  end;

  TProgram = class(TComputerIcon)
  private
    FFilename : TFilename;
  public
    property Filename : TFilename read FFilename;
    constructor Create(const progname: TFilename);
    destructor Destroy; override;
    procedure AssignRef(ref: TReference); override;
    procedure Open; override;
  end;

function MakeDriveName(DriveType: TDriveType; Letter: Char): string;

implementation

uses Classes, Drives, Resource, Desk, WinProcs, ShellAPI, Forms, Settings,
  Alias, Strings, Files, Dialogs, Controls, Streamer, IconWin, MiscUtil, Locale;

procedure TComputerIcon.Draw(Canvas: TCanvas; const Rect: TRect);
begin
  InternalDraw(Canvas, Rect, Caption);
end;

procedure TIconic.InternalDraw(Canvas: TCanvas;
  const Rect: TRect; const Text: string);
var
  w, tw, iconleft: Integer;
  r: TRect;
begin
  with Canvas, Rect do
  begin
    w := Right - Left;
    Draw(Left + ((w - 32) div 2), Top + 1, FIcon);
    tw := TextWidth(Text);
    if tw > w then
    begin
      r := Rect;
      Inc(r.Top, 33);
      DrawText(Handle, @Text[1], Ord(Text[0]), r,
        DT_CENTER or DT_WORDBREAK or DT_NOCLIP or DT_NOPREFIX)
    end
    else
      TextOut(Left + ((w - tw) div 2), Top + 33, Text);
  end;
end;

function TIconic.CreateShortcut: TShort;
begin
  Result := TShort.Create(Application);
  AssignRef(Result.Ref);
end;

procedure TIconic.WriteAlias(filename: TFilename);
var
  Reference: TReference;
begin
  if (ConfirmNewAlias or not (dfWriteable in GetDriveFlags(filename[1]))) and
    not InputQuery(LoadStr(SCreateAlias), LoadStr(SAliasFilename), filename) then
      Abort;
  if FFileExists(filename) and (MsgDialogResFmt(SQueryReplaceAlias,
    [filename], mtInformation, [mbYes, mbNo], 0) <> mrYes) then Abort;
  Reference := TReference.Create;
  try
    AssignRef(Reference);
    TAlias.Store(filename, Reference, Icon);
    Desktop.UpdateFileWindow(filename);
  finally
    Reference.Free;
  end;
end;

function MakeDriveName(DriveType: TDriveType; Letter: Char): string;
var
  fmt: string[31];
begin
  Letter := Upcase(Letter);
  fmt := GlobalCaptions.Values[Letter];
  if fmt > '' then
    Result := Format(fmt, [Letter])
  else
    Result := Format(DefaultDriveNames[DriveType], [Letter]);
end;

constructor TDrive.Create(ADrive: Char);
begin
  inherited Create;
  FLetter := Lowcase(ADrive);
  FDriveType := GuessDriveType(FLetter);
  FCaption := MakeDriveName(FDriveType, FLetter);
  Icon := icons.Drive[FDriveType];
end;

function TDrive.Root: TFilename;
begin
  Result := Letter + ':\';
end;

procedure TDrive.Open;
begin
   Desktop.OpenFolder(Root);
end;

procedure TDrive.AssignRef(ref: TReference);
begin
  with Ref do
  begin
    Kind := rkDrive;
    Target := Root;
    Caption := FCaption;
  end;
end;

constructor TProgram.Create(const progname: TFilename);
begin
  FFilename := progname;
  FCaption := ExtractFilename(FFilename);
  Icon := TIcon.Create;
  Icon.Handle := ExtractIcon(HInstance, StringAsPChar(FFilename), 0);
end;

destructor TProgram.Destroy;
begin
  Icon.Free;
  inherited Destroy;
end;

procedure TProgram.Open;
begin
  WinExec(StringAsPChar(FFilename), SW_SHOW);
end;

procedure TProgram.AssignRef(ref: TReference);
begin
  ref.Kind := rkFile;
  ref.Target := FFilename;
  ref.Caption := Caption;
end;

end.

