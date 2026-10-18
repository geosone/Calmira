{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.2                                                    }
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

unit Splash;

{ This is actually the program's main form.  The Computer window can't
  be used because we need to see it minimized while the rest of the
  forms are on screen.

  Delphi insists on displaying the main form, so to allow the user
  to avoid the splash screen, the project source calls TotalHide
  to make sure that it cannot be seen }


interface

uses
  Classes, Controls, Forms, ExtCtrls, StdCtrls;

type
  TSplashForm = class(TForm)
    Panel: TPanel;
    Image: TImage;
    Label1: TLabel;
    VersionLabel: TLabel;
    Label3: TLabel;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure TotalHide;
  end;

var
  SplashForm: TSplashForm;

implementation

{$R *.DFM}

uses Settings, WinProcs;

procedure TSplashForm.TotalHide;
begin
  { Placing the form off the desktop is usually a good bet, but
    some utilities will drag it back on screen again so setting
    the height to zero is needed too }

  Position := poDesigned;
  Left := - Width;
  Height := 0;
  Panel.Free;
end;

procedure TSplashForm.FormCreate(Sender: TObject);
begin
  Image.Picture.Icon.Handle := LoadIcon(HInstance, 'MAINICON');
end;

end.
