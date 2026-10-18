{*********************************************************}
{                                                         }
{    Calmira System Library 3.1                           }
{    by Li-Hsin Huang,                                    }
{    released into the public domain july 2000            }
{                                                         }
{*********************************************************}

unit ExtForm;

{ Defines TExtForm, which is a TForm with facilities for saving its
  size and position.  The additional property MinPosition allows the
  form to appear as an icon at a specified position (i.e., setting
  it also shows the form). }

interface

uses Forms, WinTypes, IniFiles, Messages;

type
  TExtForm = class(TForm)
  private
    FLastMinPosition: TPoint;
    function GetMinPosition: TPoint;
    procedure SetMinPosition(pt: TPoint);
  public
    procedure ShowNormal;
    procedure SavePosition(ini: TIniFile; const section: string);
    procedure LoadMinPosition(ini: TIniFile; const section: string);
    procedure LoadPosition(ini: TIniFile; const section: string);
    property MinPosition: TPoint read GetMinPosition write SetMinPosition;
    property LastMinPosition: TPoint read FLastMinPosition;
  end;

implementation

uses WinProcs, Classes;

function TExtForm.GetMinPosition: TPoint;
var
  place: TWindowPlacement;
begin
  place.Length := sizeof(place);
  GetWindowPlacement(Handle, @place);
  Result := place.ptMinPosition;
end;

procedure TExtForm.SetMinPosition(pt: TPoint);
var
  place: TWindowPlacement;
begin
  with Screen do
  begin
    if pt.x >= Width then pt.x := Width - 48;
    if pt.y >= Height then pt.y := Height - 48;
  end;
  if Visible then Invalidate;
  place.Length := sizeof(place);
  GetWindowPlacement(Handle, @place);
  place.ptMinPosition := pt;
  place.Flags := place.Flags or WPF_SETMINPOSITION;
  place.ShowCmd := SW_SHOWMINNOACTIVE;
  SetWindowPlacement(Handle, @place);
  Visible := True;
  FLastMinPosition := pt;
end;

procedure TExtForm.SavePosition(ini: TIniFile; const section: string);
begin
  with ini do
  begin
    WriteInteger(section, 'Left', Left);
    WriteInteger(section, 'Top', Top);
    WriteInteger(section, 'Width', Width);
    WriteInteger(section, 'Height', Height);
    with MinPosition do
    begin
      WriteInteger(section, 'MinLeft', X);
      WriteInteger(section, 'MinTop', Y);
    end;
  end;
end;

procedure TExtForm.LoadMinPosition(ini: TIniFile; const section: string);
begin
  MinPosition := Point(ini.ReadInteger(section, 'MinLeft', 128),
    ini.ReadInteger(section, 'MinTop', 128));
end;

procedure TExtForm.LoadPosition(ini: TIniFile; const section: string);
begin
  with ini do SetBounds(ReadInteger(section, 'Left', Left),
    ReadInteger(section, 'Top', Top),
    ReadInteger(section, 'Width', Width),
    ReadInteger(section, 'Height', Height));
end;

procedure TExtForm.ShowNormal;
begin
  WindowState := wsNormal;
  Show;
end;

end.

