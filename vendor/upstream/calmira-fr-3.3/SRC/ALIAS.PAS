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

unit Alias;

{ TAlias is a descendant of TFileItem that has it's own reference object.
  It overrides many of TFileItem's methods so that operations are
  performed using the reference object instead of the alias file.

  Notice that there isn't much code here because all the functionality
  is already handled by TReference.  TAlias just interacts through icon
  windows. }

interface

uses Classes, Grids, Directry, Referenc, Shorts, SysUtils, Graphics,
  Streamer, WinTypes;

const
  AliasSignature: array[0..3] of Char = 'CMSR';

var
  AliasSigValue: Longint absolute AliasSignature;

type
  TAlias = class(TFileItem)
  private
    FRef: TReference;
    procedure RefChange(Sender: TObject);
  public
    constructor Create(const details: TSearchRec;
      ADir: TDirectory; Stream: TStreamer);
    destructor Destroy; override;
    procedure Draw(Canvas: TCanvas; const Rect: TRect;
      const State: TGridDrawState); override;
    procedure Open; override;
    procedure DragDrop(Source: TObject); override;
    procedure Edit;
    function AcceptsDrops: Boolean; override;
    function GetStartInfo: string; override;
    procedure AssignRef(ref: TReference); override;
    function GetTitle: string; override;
    class procedure Store(const filename: TFilename;
      ARef: TReference; AnIcon: TIcon);
    property Ref : TReference read FRef;
  end;

implementation

uses Controls, Settings, WinProcs, MiscUtil, Resource, Start;

{ The constructor assumes that the stream is a valid alias and has
  already been verified by reading off the signature.

  FRef.OnChange is only assigned after loading is complete,
  otherwise it would be triggered before the icon is created,
  causing a GPF. }

constructor TAlias.Create(const details: TSearchRec;
  ADir: TDirectory; Stream: TStreamer);
begin
  inherited Create(details, ADir);
  FIsProgram := True;
  FRef := TAliasReference.Create;
  FRef.LoadFromStream(Stream);
  Icon := TIcon.Create;
  Icon.LoadFromStream(Stream);
  FRef.OnChange := RefChange;
end;

{ This is a class procedure so that the format of an alias only needs to
  be defined in one place.  TIconic needs to write an alias without
  creating a TAlias instance so it uses this procedure. }

class procedure TAlias.Store(const filename: TFilename;
  ARef: TReference; AnIcon: TIcon);
var
  s: TStreamer;
begin
  s := TStreamer.Create(filename, fmCreate);
  try
    s.WriteString(AliasSignature);
    ARef.SaveToStream(s);
    AnIcon.SaveToStream(s);
  finally
    s.Free;
  end;
end;

destructor TAlias.Destroy;
begin
  Icon.Free;
  FRef.Free;
  inherited Destroy;
end;

procedure TAlias.Open;
begin
  Ref.Open;
end;

procedure TAlias.RefChange(Sender: TObject);
begin
  Ref.AssignIcon(Icon);
  Dir.Update;
end;

procedure TAlias.Draw(Canvas: TCanvas; const Rect: TRect;
  const State: TGridDrawState);
begin
  InternalDraw(Canvas, Rect, State, Ref.Caption);
  if AliasArrows then with Rect do
    Canvas.Draw(Left + ((WidthOf(Rect) - 32) div 2),
      Top + 34 - AliasArrow.Height, AliasArrow);
end;

procedure TAlias.Edit;
begin
  if Ref.Edit = mrOK then Store(Fullname, Ref, Icon);
end;

function TAlias.AcceptsDrops: Boolean;
begin
  Result := True;
end;

procedure TAlias.DragDrop(Source: TObject);
begin
  Ref.DragDrop(Source);
end;

procedure TAlias.AssignRef(ref: TReference);
begin
  { This just copies the reference fields across }
  with ref do begin
    BeginUpdate;
    Kind := FRef.Kind;
    Target := FRef.Target;
    Caption := FRef.Caption;
    Params := FRef.Params;
    IconFile := FRef.IconFile;
    IconIndex := FRef.IconIndex;
    WorkingFolder := FRef.WorkingFolder;
    ShowMode := FRef.ShowMode;
    EndUpdate;
  end;
end;

function TAlias.GetStartInfo: string;
begin
  with Ref do
  begin
    if Kind = rkFile then
      Result := PackStartInfo(Target, WorkingFolder, IconFile,
        ShowMode, IconIndex)
    else
      Result := PackStartInfo('$Dossier '+Target, '', IconFile,
        0, IconIndex)
  end;
end;

{ Since aliases always draw their own caption, GetTitle
  returns this so that TDirectory's sorting will work correctly }

function TAlias.GetTitle: string;
begin
  Result := Ref.Caption;
end;

end.

