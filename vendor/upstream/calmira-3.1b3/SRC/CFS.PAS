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

unit Cfs;

{ Cfs Interim Version 0V3 -
  Starting to put File Functions into Explorer}

{ The CFS (Calmira File System) unit provides a framework for non-DOS
  filenames. The CfsDecls unit provides the base declarations for CFS
  which can be used in all CFS units to provide a unified system.

 Changes for 0V2 from 0V1
  1.Add CfsFindFirst/Next/Close
  2.Modify CfsDisplayName for a standard format for CfsNames:
    byte1 :Marker for name type
    byte2 :Length of Non display data
    byte3... : Non display data
    byte(ORD(byte2)+1)... :Name to Display

 Changes for 0V3 from 0V2
  1.Add 4DOS support to Explorer Pane }

interface

uses CfsDecls;

{CfsExploreFirst/Next - Directory Functions for Explorer}
function CfsExploreFirst(const Path: TCfsName; var SearchRec: TCfsSearchRec;
                         var HasSubdirs: Boolean): Integer;

function CfsExploreNext(const Path: TCfsName; var SearchRec: TCfsSearchRec;
                        var HasSubdirs: Boolean): Integer;

{CfsDisplayName extracts the name for display from a Cfs name}
function CfsDisplayName(name: TCfsName; var Marker: TCfsType): TCfsName;

{CfsFindFirst/Next/Close - as FindFirst/Next/Close but with Long Names}
function CfsFindFirst(const Path: TCfsName; Attr: Word;
  var Rec: TCfsSearchRec): Integer;

function CfsFindNext(const Path: TCfsName; Attr: Word;
  var Rec: TCfsSearchRec): Integer;

function CfsFindClose(var Rec: TCfsSearchRec):Integer;

function CfsParseName(name: TCfsName): TCFSName;

implementation

uses SysUtils, Settings, CfsCD, CfsNet, FourDOS;

var
  Descriptions: TDescriptions;

function DOSHasSubDirectories(const Dirname: string): Boolean;
var
  rec: TSearchRec;
  code: Integer;
begin
  code := FindFirst(Dirname + '\*.*', faDirectory or MaskFlags[ShowHidSys], rec);
  while code = 0 do
    if (rec.attr and faDirectory <> 0) and (rec.name[1] <> '.') then Break
    else code := FindNext(rec);
  Result := code = 0;
end;

function Add4DOSName(DOSName,FourDOSName:TCfsName):TCfsName;
var
  i: Byte;
begin
  Result := Chr(CfsConfig4DOS) + Chr(Ord(DOSName[0]) + 2);
  for i := 1 to Length(DOSName) do
    Result := Result + DOSName[i];
  Result := result + FourDOSName;
end;

function CfsExploreFirst(const Path: TCfsName; var SearchRec: TCfsSearchRec;
  var HasSubdirs: Boolean): Integer;
var
  Done: Boolean;
  code: Integer;
  ts:string;
begin
  {Determine how to handle the drive - a Cfs unit may return 128
   if it wishes the drive to be treated as a DOS drive}
  case CfsConfig(path[1]) of
    CfsConfigCD   : code:=CfsCDExploreFirst(Path,SearchRec,HasSubdirs);
   {CfsConfigBlock: code:=CfsBlockExploreFirst(Path,SearchRec,HasSubdirs);
    CfsConfigNet  : code:=CfsNetExploreFirst(Path,SearchRec,HasSubdirs);}
  else
    {code := 128;
  end;
  if code=128 then}
  {use DOS names}
    begin
      Done := False;
      ts := CfsParseName(path);
      code := FindFirst(ts + '*.*', faDirectory or MaskFlags[ShowHidSys],
        Searchrec.srec);
      while (code = 0) and not Done do
        if (SearchRec.srec.Attr and faDirectory <> 0)
          and (SearchRec.srec.Name[1] <> '.') then
          begin
            Done := True;
            SearchRec.Name := Searchrec.srec.name;
            SearchRec.CfsType := cfsDos;
            HasSubDirs := DOSHasSubDirectories(ts + Searchrec.srec.name);
          end
        else code := FindNext(Searchrec.srec);
      if (code = 0) and Drive4DOS(path[1]) then
      begin
        if Descriptions <> nil then Descriptions.Free;
        Descriptions := TDescriptions.Create;
        Descriptions.LoadfromPath(ts);
        ts := Descriptions.Get(SearchRec.Name, nil);
        if ts <> '' then
          SearchRec.Name:=Add4DOSName(SearchRec.Name,ts);
      end;
    end;
  end;
  Result := code;
end;

function CfsExploreNext(const Path: TCfsName; var SearchRec: TCfsSearchRec;
                        var HasSubdirs: Boolean): Integer;
var code:Integer; Done:Boolean; ts:TCfsName;
begin
 case CfsConfig(path[1]) of
    CfsConfigCD : code:=CfsCDExploreNext(Path,SearchRec,HasSubdirs);
  {  CfsConfigBlock: code:=CfsBlockExploreNext(Path,SearchRec,HasSubdirs);
     CfsConfigNet : code:=CfsNetExploreNext(Path,SearchRec,HasSubdirs);
  }
 else code:=128;
 end;
{DOS names}
 if code=128 then
 begin
    Done:=false;
    code := FindNext(Searchrec.srec);
    while (code=0) and not Done do
      if (SearchRec.srec.Attr and faDirectory <> 0)
          and (SearchRec.srec.Name[1] <> '.') then
        begin Done:=true;
              SearchRec.Name:=Searchrec.srec.name;
              SearchRec.CfsType:=cfsDos;
              HasSubDirs:=DOSHasSubDirectories(CfsParseName(path) + Searchrec.srec.name);
        end
      else code:=FindNext(Searchrec.srec);

      if (Descriptions<>nil)then
       begin
        if (code<>0) then
         begin Descriptions.Free; Descriptions:=nil; end
        else
         begin
          ts:=Descriptions.Get(SearchRec.Name,nil);
          if ts<>'' then
            SearchRec.Name:=Add4DOSName(SearchRec.Name,ts);
         end;
       end;
 end;
 result:=code;
end;

function CfsDisplayName( name:TCfsName; var Marker:TCfsType):TCfsName;
{Cfs2:now modified for a universal function by using byte following
 marker as a size byte for non display name info}
begin
  if ORD(name[1])<16 then
  begin
   result:=Copy(name,ORD(name[2])+1,255);
   if ORD(name[2])>7 then Marker:=cfs4DOS
   else if ORD(name[2])>3 then Marker:=CfsNetwork
        else if ORD(name[2])>1 then Marker:=cfsBlock
             else Marker:=cfsCDLfn;
  end
  else
   begin
      result := name;
      Marker := cfsDOS;
   end;
end;

function CfsFindFirst(const Path: TCfsName; Attr: Word;
                      var Rec: TCfsSearchRec):Integer;
var code:Integer;
begin
 {Determine how to handle the drive - a Cfs unit may return 128
  if it wishes the drive to be treated as a DOS drive}
 case CfsConfig(path[1]) of
    CfsConfigCD : code:=CfsCDFindFirst(Path,Attr,rec);
  {  CfsConfigBlock: code:=CfsBlockFindFirst(Path,Attr,rec);
     CfsConfigNet : code:=CfsNetFindFirst(Path,Attr,rec);
  }
 else code:=128;
 end;

 if code=128 then {use DOS names}
  begin
    code := FindFirst(path ,attr, rec.srec);
    rec.name:= rec.srec.name;
    rec.CfsType:=cfsDos;
  end;

 result:=code;
end;

function CfsFindNext(const Path: TCfsName; Attr: Word;
                     var Rec: TCfsSearchRec):Integer;
var code:Integer;
begin
 case CfsConfig(path[1]) of
    CfsConfigCD : code:=CfsCDFindNext(Path,Attr,Rec);
  {  CfsConfigBlock: code:=CfsBlockFindNext(Path,Attr,rec);
     CfsConfigNet : code:=CfsNetFindNext(Path,Attr,rec);
  }
 else code:=128;
 end;
{DOS names}
 if code=128 then
  begin
    code := FindNext(rec.srec);
    rec.name := rec.srec.name;
    rec.CfsType:=cfsDos;
  end;
 result:=code;
end;

function CfsFindClose(var Rec: TCfsSearchRec):Integer;
begin
 case rec.CfsType of
  CfsCDLfn:result:=CfsCDFindClose(Rec);
 else
  result:=0;
 end;
end;

function CfsParseName(name:TCfsName):TCfsName;
var ts:string; i,j,k:byte;
begin
 case CfsConfig(name[1]) of
    CfsConfigCD : result:=CfsCDParseName(name);
 else
  if Drive4DOS(name[1]) then
   begin
    i:=1; ts:='';
    repeat
      if name[i]<> Chr(cfsConfig4DOS) then
        begin ts:=ts + name[i];
              inc(i);
        end
      else
       begin
         j:=ORD(name[i+1]);
         for k:=2 to j-1 do ts:=ts + name[i+k];
         i:=i + j;
         while (name[i]<>'\') and (i<>Length(name)+1) do inc(i);
       end;
    until i>Length(Name);
    result:=ts;
   end
  else result:=name;

 end;
end;

initialization
 Descriptions:= nil;
end.

