{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.1                                                   }
{    Copyright (C) 1998-2000 Calmira Online!                               }
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

unit Cfsdecls;

interface

uses SysUtils;

type
  TCfsName = string;
  TCfsType = (cfsDOS, cfsCDLfn, cfsBlock, cfsNetwork, cfs4DOS);
  TCfsSearchRec = record
    srec: TSearchRec;
    name: TCfsName;
    CfsType: TCfsType;
  end;

const
  MaskFlags: array[Boolean] of Word = (0, faHidden or faSysFile);
  CfsConfigDOS   = 0;
  CfsConfigCD    = 1;
  CfsConfigBlock = 2;
  CfsConfigNet   = 4;
  CfsConfig4DOS  = 8;
  {File Matching Constants}
  fmAnyFile   = 1;
  fmMatchExt  = 2;
  fmMatchName = 3;
  fmMatchFile = 4;

var
  CfsConfigData: array [0..25] of Byte;

function CfsConfig(Drive: Char): Byte;
function Drive4DOS(Drive: Char): Boolean;
procedure CfsInit;

implementation

uses FileCtrl, Settings, Drives;

function CfsConfig(Drive: Char): Byte;
begin
  Result := CfsConfigData[Ord(Upcase(Drive)) - Ord('A')] and $07;
end;

function Drive4DOS(Drive: Char): Boolean;
begin
  Result := (CfsConfigData[Ord(Upcase(Drive)) - Ord('A')] and $08) <> 0;
end;

procedure CfsInit;
var
  i: Byte;
begin
  for i := 0 to 25 do
  begin
    CfsConfigData[i]:= CfsConfigDOS;
    case GuessDriveType(Chr(i + Ord('A'))) of
     {dtFloppy,
      dtFixed,
      dtRAM    : if UseBlockLFN then CfsConfigData[i] := CfsConfigBlock;}
      dtCDROM  : if UseCDROMLFN then CfsConfigData[i] := CfsConfigCD;
     {dtNetwork: if UseNetworkLFN then CfsConfigData[i] := CfsConfigNet;}
    end;
  end;
  (*
  for i:=0 to 25 do CfsConfigData[i] := CfsConfigDOS;
  {a=0, b=1, c=2, d=3, e=4, etc}
  CfsConfigData[2] := CfsConfig4DOS;
  CfsConfigData[3] := CfsConfig4DOS;
  CfsConfigData[5] := CfsConfigCD;
  *)
end;

end.

