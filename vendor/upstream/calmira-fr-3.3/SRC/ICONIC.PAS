{**************************************************************************}
{                                                                          }
{    Calmira II shell pour Microsoft® Windows(TM) 3.1                      }
{    Version française 3.3                                                 }
{    Copyright (C) 2000-2002 Jean Blanchard                                }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ce programme est libre ; vous pouvez le redistribuer et/ou le         }
{    modifier selon les termes de la Licence Publique Générale GNU telle   }
{   que publiée par la Free Software Foundation ; version 2 de la licence  }
{    ou (au choix) n'importe quelle version plus récente.                  }
{                                                                          }
{    Ce programme est distibué dans l'espoir qu'il sera utile, mais SANS   }
{    AUCUNE GARANTIE ; sans même la garantie implicite de                  }
{    COMMERCIALISATION ou d'APTITUDE A UN USAGE PARTICULIER. Voir la       }
{    licence publique générale pour plus de détails.                                        }
{                                                                          }
{    Vous devriez avoir reçue une copie de la licence publique générale    }
{    avec ce programme; si ce n'est pas le cas, écrivez à la Free          }
{    Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.    }
{                                                                          }
{--------------------------------------------------------------------------}

unit Iconic;

interface

uses WinTypes, SysUtils, Graphics, Grids, Drives, Referenc, Shorts, Embed;

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
      procedure InternalDraw(Canvas: TCanvas; const Rect: TRect;
        const State: TGridDrawState; const Text: string);
    public
      procedure Draw(Canvas: TCanvas; const Rect: TRect;
        const State: TGridDrawState); virtual; abstract;
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
    procedure Draw(Canvas: TCanvas; const Rect: TRect;
      const State: TGridDrawState); override;
    property Caption: TShortCaption read FCaption write FCaption;
  end;

  { TDrive represents a disk drive in the system window.
    TProgram represents a Windows program in the system window.
    Their functionality is minimal. }

  TDrive = class(TComputerIcon)
  private
    FLetter: Char;
    FDriveType: TDriveType;
  public
    constructor Create(ADrive: Char);
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

uses Classes, Resource, Desk, WinProcs, ShellAPI, Forms, Settings,
  Alias, Strings, Files, Dialogs, Controls, Streamer, IconWin, MiscUtil,
  Locale;

procedure TComputerIcon.Draw(Canvas: TCanvas; const Rect: TRect;
  const State: TGridDrawState);
begin
  InternalDraw(Canvas, Rect, State, Caption);
end;

procedure TIconic.InternalDraw(Canvas: TCanvas; const Rect: TRect;
  const State: TGridDrawState; const Text: string);
{ 3.2 -- enhanced drawing }
var
  l, w: Integer;
  r: TRect;
begin
  with Canvas, Rect do
  begin
    Brush.Color := Colors[ccIconBack];
    FillRect(Rect);
    w := WidthOf(Rect);
    l := Left + ((w - 32) div 2);
    Draw(l, Top + 2, FIcon);
    if DrawShadedIcons and (gdSelected in State) then
      ShadeIcon(Canvas, FIcon, l, Top + 2, Colors[ccIconSel]);
    r := Rect;
    Inc(r.Top, 36);
    { calculate caption area }
    InflateRect(r, -2, -1);
    DrawText(Handle, @Text[1], Ord(Text[0]), r,
      DT_CALCRECT or DT_CENTER or DT_NOCLIP or DT_NOPREFIX or DT_WORDBREAK);
    { center the returned rect }
    InflateRect(r, 2, 1);
    OffsetRect(r, (w - WidthOf(r)) div 2, 0);
    { fill text area if selected }
    if gdSelected in State then
    begin
      Brush.Color := Colors[ccIconSel];
      FillRect(r);
    end;
    if gdFocused in State then DrawFocusRect(r);
    { draw caption }
    InflateRect(r, -2, -1);
    DrawText(Handle, @Text[1], Ord(Text[0]), r,
      DT_CENTER or DT_NOCLIP or DT_NOPREFIX or DT_WORDBREAK);
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
  title: string[31];
begin
  Letter := Upcase(Letter);
  title := GlobalCaptions.Values[Letter];
  (*
  if DriveType <> dtNoDrive then
  begin
    case DriveType of
      dtFloppy,
      dtCDROM  : {if ShowRemovableVolume then
                   title := GetVolumeLabel(Letter)
                 else} title := '';
      dtFixed,
      dtNetwork: title := GetNetworkVolume(Letter);
      dtRAM    : title := GetVolumeLabel(Letter);
    end;
    if title = '' then
      title := MakeDriveName(DriveType, Letter)
    else
      title := Format('%s (%s:)', [title, Letter]);
    DriveCaptions.AddObject(title, node);
  end;
  *)
  if title > '' then
    Result := Format(title, [Letter])
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
  Icon.Handle := ExtractIcon(HInstance, StrPChar(FFilename), 0);
end;

destructor TProgram.Destroy;
begin
  Icon.Free;
  inherited Destroy;
end;

procedure TProgram.Open;
begin
  WinExec(StrPChar(FFilename), SW_SHOWNORMAL);
end;

procedure TProgram.AssignRef(ref: TReference);
begin
  ref.Kind := rkFile;
  ref.Target := FFilename;
  ref.Caption := Caption;
end;

end.

