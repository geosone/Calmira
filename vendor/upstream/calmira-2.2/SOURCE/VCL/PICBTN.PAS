{*********************************************************}
{                                                         }
{    Calmira Visual Component Library 2.2                 }
{    by Li-Hsin Huang,                                    }
{    released into the public domain July 1998            }
{                                                         }
{*********************************************************}

unit Picbtn;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Buttons;

type
  TPicBtn = class(TBitBtn)
  private
    { Private declarations }
  protected
    { Protected declarations }
    procedure Loaded; override;
  public
    { Public declarations }
  published
    { Published declarations }
  end;

const
  PicBtnGlyphs : Boolean = False;
  PicBtnHeightDelta : Integer = 3;

procedure PicBtnGlyphsChanged;

procedure Register;

implementation

procedure TPicBtn.Loaded;
begin
  inherited Loaded;
  if not PicBtnGlyphs and not (csDesigning in ComponentState) and (Glyph <> nil) then begin
    Glyph := nil;
    Margin := -1;
    Height := Height - PicBtnHeightDelta;
  end;
end;

procedure PicBtnGlyphsChanged;
begin
  MsgDlgGlyphs := PicBtnGlyphs;
  if MsgDlgGlyphs then MsgDlgBtnSize.Y := 27 else MsgDlgBtnSize.Y := 24;
end;


procedure Register;
begin
  RegisterComponents('Samples', [TPicBtn]);
end;

end.
