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

program Explorer;
{$IFDEF FPC}{$H-}{$ENDIF}

{$IFNDEF FPC}{$R *.res}{$ENDIF}
{$D Calmira Explorer Launcher}

uses SysUtils, WinTypes, WinProcs, CalMsgs;

var
  Calmira: HWnd;
  Atom: TAtom;
  buf: array[0..79] of Char;
  path: string[79];

function ExplorerParam(Index: Integer): string;
{$IFDEF FPC}
var P: PChar; Number: Integer; Quoted: Boolean; Value: string;
begin
  P := CmdLine;
  Number := 0;
  ExplorerParam := '';
  if P = nil then Exit;
  while P^ <> #0 do
  begin
    while P^ in [' ', #9] do Inc(P);
    if P^ = #0 then Exit;
    Inc(Number);
    Value := '';
    Quoted := False;
    while (P^ <> #0) and (Quoted or not (P^ in [' ', #9])) do
    begin
      if P^ = '"' then Quoted := not Quoted
      else if Length(Value) < 255 then Value := Value + P^;
      Inc(P);
    end;
    if Number = Index then begin ExplorerParam := Value; Exit; end;
  end;
end;
{$ELSE}
begin ExplorerParam := ParamStr(Index); end;
{$ENDIF}

begin
  Calmira := FindWindow('TApplication', 'Calmira');
  if Calmira = 0 then Exit;
  if (ExplorerParam(1) > '') and (Calmira > 0) then
  begin
    if LowerCase(ExplorerParam(1)) = '/e' then
      path := '*' + ExplorerParam(2)
    else
      path := ExplorerParam(1);
    Atom := GlobalAddAtom(StrLower(StrPCopy(buf, path)));
    PostMessage(Calmira, WM_CALMIRA, CM_EXPLORER, Atom);
  end
  else PostMessage(Calmira, WM_CALMIRA, CM_EXPLORER, 0);
end.

