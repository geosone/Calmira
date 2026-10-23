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

unit Askdrop;
{$IFDEF FPC}{$mode delphi}{$H-}{$ENDIF}

interface

uses
{$IFDEF FPC}
  WinTypes, native_modal, native_label,
{$ELSE}
  Forms, StdCtrls,
{$ENDIF}
  Classes, Picbtn, ExtCtrls, Controls, Buttons;

type
  TAskDropBox = class({$IFDEF FPC}TNativeModalForm{$ELSE}TForm{$ENDIF})
    Label1: TLabel;
    BitBtn1: TPicBtn;
    BitBtn2: TPicBtn;
    BitBtn3: TPicBtn;
    Icon: TImage;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
{$IFDEF FPC}
    { The shell supplies its sound preference; no unported MiscUtil dependency. }
    SoundEnabled: Boolean;
    constructor Create(AOwner: TComponent); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
{$ENDIF}
  end;

var
  AskDropBox: TAskDropBox;

implementation

{$IFNDEF FPC}{$R *.dfm}{$ENDIF}

uses WinProcs, Graphics,
{$IFDEF FPC}
  form_text;
{$ELSE}
  WinTypes, MiscUtil;
{$ENDIF}

{$IFDEF FPC}
{$I askdrop_form.inc}
{$ENDIF}

procedure TAskDropBox.FormCreate(Sender: TObject);
begin
{$IFDEF FPC}
  Icon.Picture.Icon.LoadFromResource(0, IDI_QUESTION);
  InitialControl := BitBtn1;
{$ELSE}
  Icon.Picture.Icon.Handle := LoadIcon(0, IDI_QUESTION);
{$ENDIF}
end;

procedure TAskDropBox.FormShow(Sender: TObject);
begin
{$IFDEF FPC}
  if SoundEnabled then MessageBeep(MB_ICONQUESTION);
{$ELSE}
  if MsgDialogSounds then MessageBeep(MB_ICONQUESTION);
{$ENDIF}
end;

end.

