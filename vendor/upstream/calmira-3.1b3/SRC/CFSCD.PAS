unit CfsCD;
{Version 0v2
 Changes from Ov1:
  1. Removed CfsCDDisplayName by creating a universal function
     CfsDisplayName in Cfs Unit.
  2. Added Directory Sector Number to OS data within CD version
     of CfsName to speed up access.
  3. Added CfsCdFindFirst/next/close;

 }

interface
uses CfsDecls;

function CfsCDExploreFirst(const Path: TCfsName; var SearchRec: TCfsSearchRec;
                           var HasSubdirs: Boolean): Integer;

function CfsCDExploreNext(const Path: TCfsName; var SearchRec: TCfsSearchRec;
                          var HasSubdirs: Boolean): Integer;

function CfsCDFindFirst(const Path: TCfsName; Attr: Word;
                        var Rec: TCfsSearchRec):Integer;

function CfsCDFindNext(const Path: TCfsName; Attr: Word;
                     var Rec: TCfsSearchRec):Integer;

function CfsCDFindClose(var Rec: TCfsSearchRec):Integer;

function CfsCDParseName(name:TCfsName): TCfsName;

implementation
uses WinProcs,SysUtils,Dialogs,Files;

type  RMCS = record
           EDI,ESI,EBP,Reserved,EBX,EDX,ECX,EAX:longInt;
           Flags,ES,DS,FS,GS,IP,CS,SP,SS:word;
         end;
  ShortBuffer = array [0..2047] of byte;
{  pShortBuffer = ^ShortBuffer;}
  SecBuffer   = array [0..4095] of byte;
  pSecBuffer  = ^SecBuffer;
  FileMatchRequired=byte;

  {use the fill field of TSearchrec to store LFN data for dirs}
  TLfnDirFill = record
      Extent:Longint; {where the dir is}
      Segment:Longint; {segment containing directory record}
      Offset:word;  {offset of next dir record}
      Parent:word; {parent index in dir Table}
      Span:Longint;   {number of stop sector }
      Index:word;  {index of this entry in table}
      drive:byte;
      SearchParent:word; {Parent to search for if searching}
      end;

  {use the fill field of Tsearchrec to store LFN data for files}
  TLfnFileFill = record
      Extent:Longint; {where the file is}
      Segment:Longint; {segment containing directory}
      Offset:Word;  {offset of next file record}
      Searchptr:Pointer; {search string}
      Span:word;         {number of sectors left}
      Matchtype:FileMatchRequired;
      drive:byte;
      AttrRequired:word;
      lfnFill:byte;
      end;


var     DirBuffer : SecBuffer;
        SectorInDirBuffer : Longint;

        FilesBuffer:ShortBuffer;
        SectorInFilesBuffer:Longint;

{***********************************************}
{**  The CD Memory Resource Allocation        **}
{***********************************************}
var gdaBuffer:LongInt;

procedure CDInit;
begin
 gdabuffer:= GlobalDOSAlloc(2048);
{ SectorInDirBuffer:=0;
 SectorInFilesBuffer:=0;
 SectorInSfnFBuffer:=0;
 SectorInSfnDBuffer:=0;
 sfnCache.lfnPath:='It cant possibly match this';
 lfnCache.foundpath:='It cant possibly match this';}
end;

procedure CDFree;
begin
 if gdabuffer<>0 then GlobalDOSFree(word(gdabuffer AND $0000ffff));
end;

procedure DoneLFN; far;
begin
  CDFree;
end;

{******************************************************************************}
{**  The CD Sector Read by MSCDEX interrupts                                **}
{******************************************************************************}

function DPMI_Intr(Int:byte;var RealCallStruct:RMCS):boolean;
var fnResult:byte; lpRCS:pointer;
begin fnResult:=0;
      lpRCS:=@RealCallStruct;
 asm  push di;
      mov ax,$0300
      mov bl,Int
      mov bh,0;
      xor cx,cx
      les di,lpRCS;
      int $31
      jc @end
      mov fnResult,1
@end: pop di
 end;
 DPMI_Intr:= fnResult=1;
end;

function ReadCDSector(DriveNum:byte;Sector:Longint;Extended:Boolean;
                      var Buffer:array of byte):Boolean;
{the 'extended' flag loads the upper part of the buffer}
type pSecBuffer= ^ShortBuffer;
var fnResult:byte;
    R:RMCS;
    PMBuffer:pSecBuffer;
    i:integer;
begin fnResult:=1;
 if gdabuffer<>0 then
  begin PMBuffer:=Ptr( word(gdabuffer AND $0000ffff),0);
        FillChar(R,SizeOf(RMCS),0);
        with R do
         begin eax:=$1508;
               ebx:=0;
               es:=word((gdabuffer SHR 16) AND $0000ffff);
               ecx:=DriveNum;
               edx:=1;
               esi:=HiWord(Sector);
               edi:=LoWord(Sector);
         end;
         if not(DPMI_Intr($2F,R)) OR (R.Flags AND $0001<>0)
         then fnResult:=0
         else
          begin if Extended
                then for i:=0 to 2047 do Buffer[i+2048]:=PMBuffer^[i]
                else for i:=0 to 2047 do Buffer[i]:=PMBuffer^[i];
          end;
  end
 else fnResult:=0;
  ReadCDSector:= fnResult=1;
end;

function MediaIsLfn(drive:char;var lfnDirsegment:longint;
                              var lfnDirSize:longint):Boolean;
{assumes that device is known to be CD drive}
var DescBuffer:ShortBuffer;
    SecNum,lfnSector:LongInt;
    ts:string;
    i,DriveN:byte;
function LL(ind:word):Longint; {Extract a longint}
begin
  LL:=DescBuffer[ind] + ( DescBuffer[ind+1]*256)+
      ((DescBuffer[ind+2] + ( DescBuffer[ind+3]*256))*65536);
end;
begin
  result:=false;
  DriveN:=ORD(Upcase(Drive)) - ORD('A');
  SecNum:=17;
  lfnSector:=0;
  while ReadCDSector(DriveN,SecNum,false,DescBuffer)
       and (DescBuffer[0]<>255) and (SecNum<32) and (lfnSector=0) do
   begin
    ts:='';
    for i:=1 to 5 do
    ts:=ts + chr(DescBuffer[i]);
    if (ts='CD001') and  (DescBuffer[0]=2)
    then {This is the LFN Descriptor}
    begin LfnSector:=SecNum;
          LfnDirSegment:=LL(140);
          LfnDirSize:=LL(132);
          if (LfnDirSize MOD 2048)=0
          then LfnDirSize:=(LfnDirSize DIV 2048)+ LfnDirSegment
          else LfnDirSize:=(LfnDirSize DIV 2048)+ LfnDirSegment+1;
          result:=true;
    end
    else inc(SecNum);
   end;
end;

{******************************************************************************}
{**  The LFN Directory Table Routines                                        **}
{******************************************************************************}

function GetDirEntry(var Dir:TCfsSearchRec):Boolean;
{Read a directory entry from the Directory Table}
var i:word; Drive:byte; Sector:Longint; index:word;
 function WL(ind:word):word;
  begin WL:=DirBuffer[ind] + ( DirBuffer[ind+1]*256); end;
 function LL(ind:word):Longint;
  begin LL:=WL(ind) + (WL(ind+2)*65536); end;
begin
   Result:=false;
   inc(TLFNDirFill(Dir.srec.fill).index);
   Sector:=TLFNDirFill(Dir.srec.fill).Segment;
   drive:=TLFNDirFill(Dir.srec.fill).drive;
   index:=TLFNDirFill(Dir.srec.fill).offset;

   if Sector<>SectorInDirBuffer
   then
    begin
     SectorInDirBuffer:=0;
     if ReadCDSector(Drive,Sector,false,DirBuffer)
       and ReadCDSector(Drive,Sector+1,true,DirBuffer)
     then {SectorInDirBuffer:=Sector}
     else exit;
    end;
   if DirBuffer[Index]=0 then exit;
   if Index >2047 then {restructure buffer}
    begin
     if Sector + 1 = TLFNDirFill(Dir.srec.fill).span then exit; {At end of DirTable}
     for i:=0 to 2047 do DirBuffer[i]:=DirBuffer[i+2048];
     Index:=Index-2048;
     inc(Sector);
     if not ReadCDSector(Drive,Sector+1,true,DirBuffer) then exit;
    end;
   TLfnDirFill(Dir.srec.fill).Extent:=LL(Index+2);
   TLfnDirFill(Dir.srec.fill).Parent:= DirBuffer[Index+6] + (DirBuffer[Index+7]*256);
   Dir.Name:='';
   i:=0;
   if DirBuffer[Index+i+8]=0 then inc(i);
   while i<DirBuffer[Index] do
    begin Dir.name:=Dir.Name + Chr(DirBuffer[Index+i+8]);
          inc(i,2);
    end;
  if Odd(Dirbuffer[Index])
  then Index:=Index + Dirbuffer[Index] +9
  else Index:=Index + Dirbuffer[Index] +8;
  TLfnDirFill(Dir.srec.fill).offset:=Index;
  TLfnDirFill(Dir.srec.fill).segment:=sector;
  SectorInDirBuffer:=sector;
  Result:=true;
 end;

function LfnHasSubDirectories(fEntry:word;Drive:byte;Index:word;
                                   TableEnd:Longint):Boolean;
type FnResult=(NoMore,Continue,Found);
var i:word; TBuffer:SecBuffer; TIndex:word; SecInTBuffer:Longint;
    cv:FnResult;
begin
   Result:=false;
   TIndex:=Index; SecInTBuffer:=SectorInDirBuffer;
   if not ReadCDSector(Drive,SecInTBuffer,false,TBuffer)
   or not ReadCDSector(Drive,SecInTBuffer+1,true,TBuffer)then exit;
   cv:=continue;
   repeat
    if TBuffer[TIndex]=0
    then cv:=NoMore
    else
     begin if TIndex >2047 then {restructure buffer}
           begin
             if SecInTBuffer + 1 = {LFnD}TableEnd then cv:=NoMore{At end of DirTable}
             else
               begin
                 for i:=0 to 2047 do TBuffer[i]:=TBuffer[i+2048];
                 TIndex:=TIndex-2048;
                 inc(SecInTBuffer);
                 if not ReadCDSector(Drive,SecInTBuffer+1,true,TBuffer)
                 then cv:=NoMore;
               end;
           end;
          if cv<>NoMore then
           begin
                if (TBuffer[TIndex+6] + (TBuffer[TIndex+7]*256))=fEntry
                then cv:=Found;
                if Odd(Tbuffer[TIndex])
                then TIndex:=TIndex + Tbuffer[TIndex] +9
                else TIndex:=TIndex + Tbuffer[TIndex] +8;
           end;
     end;
   until cv<>Continue;
   result:= cv=found;
 end;

 function NextPath(var Dpath:TCfsName):TCfsName;
{Extract the next dir name from Dpath}
var i:byte;
begin
  i:=POS('\',DPath);
  if i<>0  then begin Result:=Copy(DPath,1,i-1);
                       DPath:=Copy(DPath,i+1,255);
                end
  else begin Result:=DPath;
             DPath:='';
       end;
end;

function LfnFindDir(path:TCfsName;var founddir:TCfsSearchRec;
                         LfnDirSeg,LfnDirSize:longint):Boolean;
var spath,NextDir,startpath:TCfsName;
    Valid:Boolean;  Parent:word;  DriveN:byte;
begin Valid:=false;
 DriveN:=ORD(Upcase(path[1])) - ORD('A');
 Spath:=Copy(path,POS('\',path)+1,255);{Remove drive details}
 if Spath[length(Spath)]='\' then
    Spath:=Copy(spath,1,Length(Spath)-1);{Remove final \ from path}
 startpath:=spath;
 {first find parent directory index}
 SectorInDirBuffer:=0;
 Parent:=1;
 TLfnDirFill(FoundDir.srec.fill).offset:=0;
 TLfnDirFill(FoundDir.srec.fill).Index:=0;
 TLfnDirFill(FoundDir.srec.fill).Segment:=LfnDirSeg{Table};
 TLfnDirFill(FoundDir.srec.fill).Drive:=DriveN;
 TLfnDirFill(FoundDir.srec.fill).Span:=LfnDirSize;
 Valid:=GetDirEntry(FoundDir);{Root Dir}
 if Spath<>'' then
   repeat
     NextDir:=NextPath(Spath);
     repeat
       Valid:=GetDirEntry(FoundDir);
     until ((FoundDir.Name=NextDir)
           and ( TLFNDirFill(FoundDir.srec.fill).Parent=Parent ))
           or not Valid;
     if Valid then Parent:=TLFNDirFill(FoundDir.srec.fill).Index;
   until not Valid or (sPath='');
{  if valid then
   with lfnCache do
    begin foundpath:=startpath; foundrec:=founddir end;} {cache}
  result:= Valid;
end;

{function LocateDir(path:TCfsName;var Extent:Longint):Boolean;
var  DriveChar:Char;     founddir:TCfsSearchRec;
     lfnDirSeg, LfnDirSize:longint;
begin
 DriveChar:=UpCase(path[1]);
 if (gdabuffer<>0) and MediaIsLfn(path[1],lfnDirSeg,lfnDirSize)
 then
    begin
     result:=LfnFindDir(path,founddir,lfnDirSeg,LfnDirSize);
     Extent:=TLfnDirFill(founddir.srec.fill).extent;
    end
 else result:=false;
end;}



{*******************************************************}
{**  The Cfs name functions                           **}
{*******************************************************}

function CfsCDParseName(name:TCfsName): TCfsName;
var n:TCfsName; posmarker:byte;
begin
 n:=name;
 posmarker:=POS(#1,n);
 while posmarker<>0 do
  begin
     n:=Copy(n,1,Posmarker-1) + Copy(n,Posmarker+ORD(n[Posmarker+1]),255);
     posmarker:=POS(#1,n);
 end;
 result:=n;
end;

type LongIntString = string[4];

function LongIntToChars(value:longint): LongIntString;
{For embedding directory extent into Cfs name}
begin
 result:=Chr(value and $000000ff);
 result:=result + Chr((value SHR 8)and $000000ff);
 result:=result + Chr((value SHR 16)and $000000ff);
 result:=result + Chr((value SHR 24)and $000000ff);
end;

function CharsToLongInt(value:String): LongInt;
{For embedding directory extent into Cfs name}
begin
 result:=ORD(value[3]);
 result:=result + (ORD(value[4]) SHL 8);
 result:=result + (ORD(value[5]) SHL 16);
 result:=result + (ORD(value[6]) SHL 24);
end;

function ExtractExtent(path:TCfsName):LongInt;
var i:byte;
begin
  i:=Length(path);
  while (path[i]<>#1) and (i<>0) do dec(i);
  if i<>0 then result:=CharsToLongInt(Copy(path,i,255))
  else result:=0;
end;

{*******************************************************}
{**  The Cfs file functions                           **}
{*******************************************************}
function GetLfnFile(var Files:TCfsSearchRec):integer;
var i:word; ts,ts2:TCfsName; TargetSegment:longint;
    Filesoffset:word;  TargetDrive:Byte;
 function WL(ind:word):word;
  begin  WL:=FilesBuffer[ind] + ( FilesBuffer[ind+1]*256);end;
 function LL(ind:word):Longint;
  begin LL:=WL(ind) + (WL(ind+2)*65536); end;
begin
  result:=-18;
  TargetSegment:=TLfnFileFill(Files.srec.fill).Segment;
  if TargetSegment<>SectorinFilesBuffer
  then begin SectorInFilesBuffer:=0; {in case it fails}
             TargetDrive:=TLfnFileFill(Files.srec.fill).Drive;
             if ReadCDSector(TargetDrive,TargetSegment,false,FilesBuffer)
             then SectorinFilesBuffer:=TargetSegment
             else exit;
       end;
  FilesOffset:=TLfnFileFill(Files.srec.fill).offset;

  if  (FilesBuffer[FilesOffset]=0) {possible end of file records}
  then
  begin
    if TLfnFileFill(Files.srec.fill).Span<2 then exit
    else
    begin
      TargetDrive:=TLfnFileFill(Files.srec.fill).Drive;
      if  ReadCDSector(TargetDrive,SectorinFilesBuffer+1,false,FilesBuffer)
      then begin inc(SectorinFilesBuffer);
                 FilesOffset:=0;
                 dec(TLfnFileFill(Files.srec.fill).Span);
           end
      else exit;
    end;
  end;

  with files do begin TLfnFileFill(srec.fill).Extent:=LL(FilesOffset +2);
                      srec.Size:=LL(FilesOffset+10);
                      srec.Attr:=FilesBuffer[FilesOffset+25];
                      Name:='';
                end;
  i:=0;
  if FilesBuffer[FilesOffset+32]=1 then
  begin
    case FilesBuffer[Filesoffset+33] of
           0:files.name:='.';
           1:files.Name:='..';
    else files.Name:='$?';
    end;
  end
  else
  begin
    if FilesBuffer[FilesOffset+33+i]=0 then inc(i);
    while i<FilesBuffer[Filesoffset+32] do
      begin
        files.name:=files.name + Chr(filesBuffer[filesOffset+i+33]);
        inc(i,2);
      end;
  end;
 {Remove any version info}
 if POS(';',files.name)<>0
 then files.name:=Copy(files.name,1,POS(';',files.name)-1);
  { reformat attribute}
 with Files do
  srec.Attr:=$01   {Always Read Only}
        OR ( (srec.Attr AND $01) SHL 1) {Hidden}
        OR ( (srec.Attr AND $02) SHL 3) {Directory};
{Convert DateTimeFormat
  NB The original code failed with exceptions depending on machine/OS etc -
  Don't be tempted to use Delphi routines here - they are country dependent!!
  Fields coded as per Ralf Browns's Interrupt list}

  if FilesBuffer[Filesoffset+18]<80 then Files.srec.Time:=0
  else
   with Files.srec do
   begin
    Time:=FilesBuffer[FilesOffset+18]-80; {year}
    Time:=(Time SHL 4) OR (FilesBuffer[FilesOffset+19]);{month}
    Time:=(Time SHL 5) OR (FilesBuffer[Filesoffset+20]);{day}
    Time:=(Time SHL 5) OR (FilesBuffer[FilesOffset+21]);{hour}
    Time:=(Time SHL 6) OR (FilesBuffer[FilesOffset+22]); {min}
    Time:=(Time SHL 5) OR (FilesBuffer[FilesOffset+23] DIV 2);{sec}
   end;
  Filesoffset:=Filesoffset + Filesbuffer[Filesoffset];
  with TLfnFileFill(files.srec.fill) do
   begin Segment:=SectorinFilesBuffer;
         Offset:=Filesoffset;
   end;

  if Files.Name='.' then
  {root entry, so pick up info on this directory}
   if (Files.srec.Size) MOD 2048<>0 then
      TLfnFileFill(files.srec.fill).Span:=(Files.srec.Size) DIV 2048 +1
   else  TLfnFileFill(files.srec.fill).Span:=(Files.srec.Size) DIV 2048;
  {put a modified filename in sr.name - if we don't then there will be no
   icons in the filelist}
  ts:=files.name;
  while pos(' ',ts)<>0 do
   begin ts2:=Copy(ts,1,pos(' ',ts)-1);
         ts:=ts2 + Copy(ts,pos(' ',ts)+1,255);
   end;
  if Length(ts)>12 then
   ts:=Copy(ts,Length(ts)-11,12);
  files.srec.name:=ts;
  result:=0;
end;

function ExtractRight(findchar:char;var within:string):string;
var i:byte; found:boolean;
begin
 i:=Length(within); result:='';
 if within[Length(within)]='.' then within:=Copy(within,1,Length(within)-1);
 if (POS('.',within)=0) then exit;
 repeat
   if within[i]=findchar then
    begin result:=Copy(within,i+1,255);
          within:=Copy(within,1,i-1);
    end;
   dec(i);
 until (i=0) or (ORD(result[0])<>0);

end;

procedure SetUpSearchParameters(filespec:TCfsname;attr:word;var rec:TCfsSearchRec);
var i:byte; found:boolean; ts:pchar; fAttrReqd:word;
    FileMatch:FileMatchRequired; fNameReqd,fExtReqd:TCfsname;
begin
 {create a copy of filespec as a pchar}
 filespec[length(filespec)+1]:=#0;
 ts:=@filespec[1];
 TLfnFileFill(rec.srec.fill).searchptr:= StrNew(ts);
 fAttrReqd:=Attr or faReadOnly or faArchive;
 TLfnFileFill(rec.srec.fill).AttrRequired:=byte(fAttrReqd);

 if filespec='*.*' then FileMatch:=fmAnyFile
 else
   begin
    {Extract extension and filename}
     fnamereqd:=filespec;
     fextreqd:=ExtractRight('.',filespec);
    {now how to handle the file}
     if (fNameReqd='*') then FileMatch:=fmMatchExt
     else if fExtReqd='*'
          then FileMatch:=fmMatchName
          else FileMatch:=fmMatchFile;
   end;
 TLfnFileFill(rec.srec.fill).Matchtype:=FileMatch;
 end;

function MatchFile(Files:TCfsSearchRec):Boolean;
var fname,fext,Fullname,SearchName,SearchExt:TCfsname; AttrReqd:word;
 begin
 result:=false;
 if TLfnFileFill(files.srec.fill).searchptr=nil then
 begin
  MessageDlg('Error in File pointer', mtInformation, [mbOK], 0);
 end;
 Fullname:=StrPAS(TLfnFileFill(files.srec.fill).searchptr);
 SearchName:=Fullname;
 SearchExt:=ExtractRight('.',SearchName);
 AttrReqd:=TLfnFileFill(files.srec.fill).AttrRequired;

 case TLfnFileFill(files.srec.fill).Matchtype of
     fmAnyFile:result:=(Files.srec.attr and AttrReqd)<>0;
    fmMatchExt:begin
                fname:=files.name;
                fext:=ExtractRight('.',fname);
                result:= (fext=SearchExt) and ((Files.srec.attr and AttrReqd)<>0)
              end;
  fmMatchName:begin
                fname:=files.name;
                fext:=ExtractRight('.',fname);
                result:= (Searchname=fname) and ((Files.srec.attr and AttrReqd)<>0)
              end;
  fmMatchFile:result:= WildCardmatch(fullname,files.name)
                        and ((Files.srec.attr and AttrReqd)<>0);
 end;
end;

{*******************************************************}
{**  The Cfs functions                                **}
{*******************************************************}

function CfsCDExploreFirst(const Path: TCfsName; var SearchRec: TCfsSearchRec;
                         var HasSubdirs: Boolean): Integer;
var code:Integer; spath:TCfsName;
    {ts:TCfsName;}
    Valid:Boolean;
    DriveN:byte;
    lfnDirSeg:longint; lfnDirSize:longint;
begin
 code:=128;
 spath:=CfsCDParseName(path);
 {rec.IsLfn:=false;}
  HasSubdirs:=false;
 {FindPath:=path;}
 DriveN:=ORD(UpCase(spath[1])) - ORD('A');
 if (gdabuffer<>0) and MediaIsLfn(spath[1],lfnDirSeg,lfnDirSize)
 then
  begin
    SearchRec.CfsType:=CfsCDLfn;
    Valid:=LfnFindDir(spath,SearchRec,LfnDirSeg,LfnDirSize);
    if Valid then
     with TlfnDirFill(Searchrec.srec.fill) do
      begin
        SearchParent:=Index;
        repeat
          Valid:=GetDirEntry(SearchRec);
        until not Valid or (Parent = SearchParent);
        if Valid then
          begin code:=0;
                HasSubdirs:=LfnHasSubDirectories(Index,DriveN,offset,lfnDirSize);
                SearchRec.name:= Chr(CfsConfigCD)+ #6
                                 + LongIntToChars(TLfnDirFill(SearchRec.srec.fill).Extent)
                                 + SearchRec.name;
          end;
      end;
  end;
 result:=code;
end;

function CfsCDExploreNext(const Path: TCfsName; var SearchRec: TCfsSearchRec;
                         var HasSubdirs: Boolean): Integer;
var code:Integer; {spath:TCfsName;} Valid:boolean;
begin
   code:=128;
   HasSubdirs:=false;
   if Searchrec.Cfstype=CfsCDLfn then
   begin repeat
          Valid:=GetDirEntry(Searchrec);
        until (TLfnDirFill(SearchRec.srec.fill).Parent=
               TLfnDirFill(SearchRec.srec.fill).SearchParent) or not Valid;
        if Valid
        then
          begin
            code:=0;
            with TLfnDirFill(SearchRec.srec.fill) do
             HasSubdirs:=LfnHasSubDirectories(Index,Drive,Offset,Span);
            SearchRec.name:= Chr(CfsConfigCD) + #6
                      + LongIntToChars(TLfnDirFill(SearchRec.srec.fill).Extent)
                      + SearchRec.name;
          end
        else
        code:= -18;
 end;
 result:=code;
end;

function CfsCDFindFirst(const Path: TCfsName; Attr: Word;
                        var Rec: TCfsSearchRec):Integer;
var code,tc:integer; Spath,filespec:TCfsname;
    founddir:TCfsSearchRec;
    i:byte; done:boolean;
    lfnDirSeg,lfnDirSize:longint;
begin
 code:=128;{try FindFirst/Next if all else fails!}
 if (gdabuffer<>0) and MediaIsLfn(path[1],lfnDirSeg,lfnDirSize)
 then
  begin
    spath:=CfsCDParseName(path);
   i:=length(Spath); done:=false;
   {remove file spec}
   repeat
    if Spath[i] ='\' then
     begin done:=true;
           filespec:=Copy(spath,i+1,256);
           if i=3 then Spath:=Copy(spath,1,i)
           else Spath:=Copy(spath,1,i-1);
     end
    else dec(i);
   until (i=0) or done;
  {Find directory extent and first file}
   with TLFNFileFill(rec.srec.fill) do
    begin
     {if POS(Chr(cfsConfigCD),spath)<>0
     then segment:=ExtractExtent(spath)
     else begin }if LfnFindDir(spath,founddir,LfnDirSeg,LfnDirSize)
                then Segment:=TlfnDirFill(founddir.srec.fill).Extent
                else Segment:=0;
          {end;}
     if segment<>0 then
     begin
     {Decide how to handle the file}
      SetUpSearchParameters(filespec,attr,rec);
      {Load the Files Buffer}
      SectorInFilesBuffer:=0;
      {Initialise the record}
      offset:=0;
      {the actual value of span is determined by the root entry}
      Span:=1;
      Drive:=ORD(Upcase(Path[1])) - ORD('A');
        {Ignore the first two entries - the directory itself and its parent}
      if (GetLfnFile(rec)=0) and (GetLfnFile(rec)=0)
      then
      repeat
      {read until a file is matched or end of directory}
           tc:=GetLfnFile(rec);
      {if a file is matched then output}
            if (tc=0) and MatchFile(rec) then code:=0;
      until (tc<>0) or (code=0);
      rec.Cfstype:=CfsCDLfn; {** LFN2**}
    end;
  end;
  end;
  result:=code;
end;


function CfsCDFindNext(const Path: TCfsName; Attr: Word;
                     var Rec: TCfsSearchRec):Integer;
var code:integer; ts:pchar;
begin
  code:=128;
  if GetLfnFile(rec)=0 then code:=0
  else begin code:=-18;
             ts:=TLfnFileFill(rec.srec.fill).searchptr;
             if ts<>nil then StrDispose(ts);   {stop}
       end;
{Normal FindNext}
  result:=code;
end;

function CfsCDFindClose(var Rec: TCfsSearchRec):Integer;
var code:integer; ts:pchar;
begin
  ts:=TLfnFileFill(rec.srec.fill).searchptr;
  if ts<>nil then StrDispose(ts);
  result:=0;
end;


initialization
 AddExitProc(DoneLFN); {make sure we dispose DOS memory on finishing}
 gdabuffer:=0;
 CDInit;
end.
