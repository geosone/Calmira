{*********************************************************}
{                                                         }
{    Calmira System library 3.3                           }
{    by Li-Hsin Huang & Erwin Dokter                      }
{    released into the public domain may 2002             }
{                                                         }
{*********************************************************}

unit PicBtn;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
{$IFNDEF FPC}
  Forms, Dialogs, StdCtrls,
{$ELSE}
  Dialogs,
{$ENDIF}
  Buttons;

type
  TPicBtn = class(TBitBtn)
  private
    { Private declarations }
{$IFDEF FPC}
    FResourceLoaded: Boolean;
{$ENDIF}
  protected
    { Protected declarations }
    procedure Loaded; override;
  public
    { Public declarations }
{$IFDEF FPC}
    procedure FinishLoading;
{$ENDIF}
  published
    { Published declarations }
  end;

const
  PicBtnGlyphs: Boolean = False;
  PicBtnHeightDelta: Integer = 2;

procedure PicBtnGlyphsChanged;
procedure Register;

implementation

procedure TPicBtn.Loaded;
begin
{$IFDEF FPC}
  if FResourceLoaded then Exit;
{$ENDIF}
  inherited Loaded;
  if not PicBtnGlyphs and not (csDesigning in ComponentState) and (Glyph <> nil) then
  begin
    Glyph := nil;
    Margin := -1;
    Height := Height - PicBtnHeightDelta;
  end
  else
    Margin := 4;
  Spacing := -1;
{$IFDEF FPC}
  FResourceLoaded := True;
{$ENDIF}
end;

{$IFDEF FPC}
procedure TPicBtn.FinishLoading;
begin
  Loaded;
end;
{$ENDIF}

procedure PicBtnGlyphsChanged;
begin
  MsgDlgGlyphs := PicBtnGlyphs;
  if MsgDlgGlyphs then MsgDlgBtnSize.Y := 25 else MsgDlgBtnSize.Y := 23;
end;

procedure Register;
begin
  RegisterComponents('Calmira', [TPicBtn]);
end;

end.

