unit Lfn_fns;

interface

uses SysUtils,
  WinTypes;
const
  DosTimeFormat : Boolean = true;
const
 MAX_PATH = 260;
  fmOpenRead       = $0000;
  fmOpenWrite      = $0001;
  fmOpenReadWrite  = $0002;

  fmShareCompat    = $0000; {// DOS compatibility mode is not portable}
  fmShareExclusive = $0010;
  fmShareDenyWrite = $0020;
  fmShareDenyRead  = $0030; {// write-only not supported on all platforms}
  fmShareDenyNone  = $0040;

 DELIM_NoTrimLeft=$100;
 DELIM_NoTrimRight=$200;
 DELIM_NilWhenNone=$400;	{liefert NIL, wenn KEIN Element mehr da ist}
 DELIM_Whitespace=$800;
 progexts: array [0..3] of string = ('PIF','EXE','COM','BAT'); { If you wish to cange remember that
                                         exts listed first have higher
                                         priority }

type
  TLfnFileName = string;
  TLfnFileExt = string;
  PSearchRec = ^TSearchRec;
  DWORD = LongInt;
  AnsiChar = Char;

  TFileTime = record
    dwLowDateTime: DWORD;
    dwHighDateTime: DWORD;
  end;
  TWin32FindData = record
    dwFileAttributes: DWORD;
    ftCreationTime: TFileTime;
    ftLastAccessTime: TFileTime;
    ftLastWriteTime: TFileTime;
    nFileSizeHigh, nFileSizeLow: DWORD;
    dwReserved0: DWORD;
    dwReserved1: DWORD;
    cFileName: array[0..MAX_PATH - 1] of AnsiChar;
    cAlternateFileName: array[0..13] of AnsiChar;
  end;
  TLfnSearchRec = record
    Time: LongInt;	{Time contains the time stamp of the file.}
    Size: LongInt;	{Size contains the size of the file in bytes.}
    Attr: Word; 	{Attr represents the file attributes of the file.}
    Name: TLfnFileName;	{Name contains the filename and extension.}
    ExcludeAttr: Integer;
    FindHandle: Word;
    FindData: TWin32FindData;	{FindData contains additional information such as
                      file creation time, last access time, long and short filenames.}
    ShortData: TSearchRec;
  end;

function LFindFirst(const Path: string; Attr: Word; var SearchRec: TLfnSearchRec): Integer; export;
function LFindNext(var SearchRec: TLfnSearchRec): Integer;export;
procedure LFindClose(var SearchRec: TLfnSearchRec);export;
procedure LChDir(S: String);export;
function LFileOpen(const FileName: string; Mode: Word): Integer;export;
function LFileCreate(const FileName: string): Integer;export;
function LFileGetAttr(const F: TLfnFileName): LongInt;export;
function LFileGetDate(const Handle: Integer): LongInt;export;
function LFileSetAttr(const F: TLfnFileName; Attr: LongInt): Integer;export;
procedure LFileSetDate(const Handle: Integer; Date: LongInt);export;
function LRenameFile(const OldName, NewName: string): Boolean;export;
function LDeleteFile(const FileName: string): Boolean;export;
procedure LMkDir(const FileName: string);export;
procedure LRmDir(const FileName: string);export;
function NextItemStr(var s: PChar; escap, delim:Word):PChar;export;
function NextItem(var s: string; escap, delim:Word):string;export;
function OneItem(d,s: PChar; escap, delim:Word):PChar;export;
function GetShortName(const LongName: string): string;export;
function GetLongName(const ShortName: string): string;export;
procedure LGetDir(D: Byte; var S: string);export;
function IsProgExt(Ext: string): Boolean;export;
function SearchProgPath(prog, dirs: string): string;export;
function LExpandFileName(FilePath: string):string;export;
function LGetVolumeInfo(RootName: string; var FileSystem: string; var Flags: Word): Boolean;export;
procedure SetLFN(Enabled:boolean);export;
function GetLFN: Boolean;export;

implementation

uses dialogs,
  winprocs;
var
  UnicodeConversion:Byte;
  LfnEnabled: Boolean;
  DosError: Integer;

procedure Doscall_Type_DSDX(_ax,_bx,_cx,_si:Word; esdi:Pointer; arg: PChar);
{Aufrufe mit DS:DX=Name (arg) und weiteren Registern}
 begin
  asm	push	ds
	 lds	dx,[arg]
	 les	di,[esdi]
	 mov	si,[_si]
	 mov	cx,[_cx]
	 mov	bx,[_bx]
	 mov	ax,[_ax]
	 stc
	 {int	21h}
         call Dos3Call
	pop	ds
	jnc	@@e
	mov	[DosError],ax
@@e:
  end;
 end;

procedure Doscall_Type_DSSI_ESDI(_ax,_bx,_cx,_dx:Word; arg, s: PChar);
{Aufrufe mit DS:SI=Name und ES:DI=Ergebnispuffer}
 begin
  asm	push	ds
	 push	ds
	 pop	es
	 lds	si,[arg]
	 lea	di,[s]
	 mov	dx,[_dx]
	 mov	cx,[_cx]
	 mov	bx,[_bx]
	 mov	ax,[_ax]
	 stc
	 {int	21h}
         call Dos3Call
	pop	ds
	jnc	@@e
	mov	[DosError],ax
@@e:
  end;
{  if DosError=0 then WriteLn(s);}
 end;

function __getvolinfo(rootname, fsystem: PChar;fsyssize:Word; var _flags_: Word): Word;
label
 final;
var
 _bx_:word;
begin
asm;
	mov	[DosError], 0
	mov	ax, 71A0h
	les	di, [fsystem]
	mov	cx, [fsyssize]
	lds	dx, [rootname]
	{int	21h}
        call Dos3Call
	jnc	@@e
	mov	DosError, ax
	jmp	final
@@e:
	mov	_bx_,bx
end;
_flags_ := _bx_;
final:
asm
	mov	ax, [DosError]
end;
end;

function LGetVolumeInfo(RootName: string; var FileSystem: string; var Flags: Word): Boolean;
var
 _rootname, _fsystem: array [0..255] of Char;
begin
StrPCopy(@_rootname[0],RootName);
if __getvolinfo(_rootname,_fsystem,255,Flags) = 0 then
  begin
  FileSystem := StrPas(@_fsystem[0]);
  LGetVolumeInfo := True;
  end
else
  begin
  FileSystem := EmptyStr;
  Flags := 0;
  LGetVolumeInfo := False;
  end;
end;

function DetectLfn: Boolean;
var
 fsys: string;
 flags: Word;
begin
DetectLfn := false;
if LGetVolumeInfo('c:\',fsys,flags) then
 begin
 if (flags and $4000) = $4000 then
  DetectLfn := true;
 end;
end;

procedure SetLFN(Enabled:boolean);
begin
LfnEnabled := Enabled;
end;

function GetLFN: Boolean;
begin
GetLFN := LfnEnabled;
end;

procedure __fnexpand(Source,Dest: PChar);
assembler;asm;
  push ds
  les di, dest
  lds si, source
  mov ax, 7160h
  mov cx, 8000h
  {int 21h}
  call Dos3Call
  jnc @@1
  mov [DosError], ax
  cmp ax,ax
  je @@e
@@1:
  mov ax, 7160h
  mov cx, 8002h
  {int 21h}
  call Dos3Call
  jnc @@e
  mov [DosError], ax
@@e:
  pop ds
end;

procedure __renamefile(Old,New: PChar);
assembler;
asm         push  ds
            mov DosError, 0
            mov   ax,$7156                     { LFN - Rename File          }
            lds   dx,[Old]                      { DS:DX = @Old_name          }
            les   di,[New]
            {int   21h}
            call Dos3Call
            pop   ds
            jnc   @@Exit
            mov   DosError, ax
@@Exit:
end;

procedure __mkdir(dir: PChar);
 begin
  DosCall_Type_DSDX($7139,0,0,0,nil,dir);
 end;

procedure __rmdir(dir: PChar);
 begin
  DosCall_Type_DSDX($713A,0,0,0,nil,dir);
 end;

procedure __deletefile(FName: PChar);
assembler;
asm
            push  ds
            mov   [DosError],0
            mov   ax,$7141             { LFN - delete file                  }
            xor   si,si                { No wildcards allowed               }
            xor   cx,cx
            lds   dx,[FName]        { DS:DX = @FileName                  }
            {int   21h}
            call Dos3Call
            pop   ds
            jnc   @@Exit
            mov   [DosError],ax
@@Exit:
end;

procedure __getshortname(Long, Short: Pchar);
assembler;asm
  push ds
  push ds
  pop  es
  lds si, Long
  les di, Short
  mov cx, 8001h
  mov ax, 7160h
  stc
  {int 21h}
  call Dos3Call
  pop ds
  jnc @@Exit
  mov [DosError], ax
@@Exit:
end;

procedure __getlongname(Short,Long: Pchar);
assembler;asm
  push ds
  push ds
  pop  es
  lds si, Short
  les di, Long
  mov cx, 8002h
  mov ax, 7160h
  stc
  {int 21h}
  call Dos3Call
  pop ds
  jnc @@Exit
  mov [DosError], ax
@@Exit:
end;

procedure __getdir(d: byte;fname:PChar);
begin
if(d=0)then
   asm	mov	ah,19h
	{int	21h}
        call Dos3Call
	add	al,'A'
	mov	byte ptr [fname],al
	mov	word ptr [fname+1],'\:'
   end
else
   asm
        mov     al,d
	add	al,'A'
	mov	byte ptr [fname],al
	mov	word ptr [fname+1],'\:'
   end;
   asm
	mov	dl,d
	mov	si,offset fname+3
	mov	ax,7147h
	{int	21h}
	jnc	@@e
	mov	[DosError],ax
@@e:
   end;
end;

function __fileopen(const path: PSTR; OpMode, Action: Word): Word;
var
 h: Word;
label
 error;
begin
__fileopen := $FFFF;
DosError := 0;
asm
 mov ax, 716Ch
 mov bx, OpMode
 mov cx, 0
 mov dx, Action
 push ds
 lds si, path
 {int 21h}
 pop	ds
 jnc	@@e
 mov	[DosError],cx
 cmp ax,ax
 je error
@@e:
  mov h, ax
 end;
__fileopen := h;
error:
end;

function __findfirst(const path: PSTR; Attr: Word; var SearchRec: TWin32FindData): Word;
 assembler; asm
	push	ds
	 lds	dx,[path]
	 mov	cx,[attr]
	 les	di,[SearchRec]
	 mov	al,[DosTimeFormat]
	 cbw
	 xchg	si,ax
	 stc
	 mov	ax,714Eh
	 {int	21h}
         call Dos3Call
	pop	ds
	mov	[UnicodeConversion],cl
	jnc	@@e
	mov	[DosError],ax
	xor	ax,ax
@@e: end;

function __findnext(handler: Word; var SearchRec: TWin32FindData): Word;
begin
 asm	mov	bx,[handler]
	mov	si,1
	les	di,[SearchRec]
	mov	al,[DosTimeFormat]
	cbw
	xchg	si,ax
	stc
	mov	ax,714fh
	{int	21h}
        call Dos3Call
	mov	[UnicodeConversion],cl
	jnc	@@e
	mov	[DosError],ax
	xor	ax,ax
@@e: end;
end;

function __findclose(handler: Word): Word;
 assembler;asm	mov	bx,[handler]
	stc
	mov	ax,71A1h
	{int	21h}
        call Dos3Call
	jnc	@@e
	mov	[DosError],ax
	xor	ax,ax
@@e: end;

procedure __chdir(dir: PChar);assembler;
asm
    	push	ds
        lds	dx,[dir]
	mov	ax,713Bh
	{int	21h}
        call Dos3Call
	pop	ds
	jnc	@@e
	mov	[DosError],ax
@@e:
end;

function LFindFirst(const Path: string; Attr: Word; var SearchRec: TLfnSearchRec): Integer;
var
  filter : array [0..MAX_PATH] of char;
  Handler : Word;
begin
if LfnEnabled then
  begin
  DosError := 0;
  StrPCopy(filter,Path);
  AnsiToOem(filter,filter);
  Handler := __findfirst(filter,Attr,SearchRec.FindData);
  OemToAnsi(SearchRec.FindData.cFileName,SearchRec.FindData.cFileName);
  SearchRec.Attr := SearchRec.FindData.dwFileAttributes;
  SearchRec.Size := SearchRec.FindData.nFileSizeLow;
  SearchRec.Time := SearchRec.FindData.ftLastWriteTime.dwLowDateTime;
  SearchRec.Name := StrPas(SearchRec.FindData.cFileName);
  SearchRec.ShortData.Name := StrPas(SearchRec.FindData.cAlternateFileName);
  SearchRec.ShortData.Time := SearchRec.Time;
  SearchRec.ShortData.Size := SearchRec.Size;
  SearchRec.ShortData.Attr := SearchRec.Attr;
  SearchRec.FindHandle := Handler;
  LFindFirst := DosError;
  end
else
  begin
  LFindFirst := FindFirst(Path,Attr,SearchRec.ShortData);
  SearchRec.Attr := SearchRec.ShortData.Attr;
  SearchRec.Size := SearchRec.ShortData.Size;
  SearchRec.Time := SearchRec.ShortData.Time;
  SearchRec.Name := SearchRec.ShortData.Name;
  {StrPCopy(SearchRec.FindData.cFileName,SearchRec.Name);
  StrPCopy(SearchRec.FindData.cAlternateFileName,SearchRec.Name);}
  SearchRec.FindData.dwFileAttributes := SearchRec.Attr;
  SearchRec.FindData.nFileSizeLow := SearchRec.Size;
  SearchRec.FindData.ftLastWriteTime.dwLowDateTime := SearchRec.Time;
  SearchRec.FindHandle := 0;
  end;
end;

function LFindNext(var SearchRec: TLfnSearchRec): Integer;
begin
if LfnEnabled then
  begin
  DosError := 0;
  __findnext(SearchRec.FindHandle,SearchRec.FindData);
  OemToAnsi(SearchRec.FindData.cFileName,SearchRec.FindData.cFileName);
  SearchRec.Attr := SearchRec.FindData.dwFileAttributes;
  SearchRec.Size := SearchRec.FindData.nFileSizeLow;
  SearchRec.Time := SearchRec.FindData.ftLastWriteTime.dwLowDateTime;
  SearchRec.Name := StrPas(SearchRec.FindData.cFileName);
  SearchRec.ShortData.Name := StrPas(SearchRec.FindData.cAlternateFileName);
  SearchRec.ShortData.Time := SearchRec.Time;
  SearchRec.ShortData.Size := SearchRec.Size;
  SearchRec.ShortData.Attr := SearchRec.Attr;
  LFindNext := DosError;
  end
else
  begin
  LFindNext := FindNext(SearchRec.ShortData);
  SearchRec.Attr := SearchRec.ShortData.Attr;
  SearchRec.Size := SearchRec.ShortData.Size;
  SearchRec.Time := SearchRec.ShortData.Time;
  SearchRec.Name := SearchRec.ShortData.Name;
  {StrPCopy(SearchRec.FindData.cFileName,SearchRec.Name);
  StrPCopy(SearchRec.FindData.cAlternateFileName,SearchRec.Name);}
  SearchRec.FindData.dwFileAttributes := SearchRec.Attr;
  SearchRec.FindData.nFileSizeLow := SearchRec.Size;
  SearchRec.FindData.ftLastWriteTime.dwLowDateTime := SearchRec.Time;
  end;
end;

procedure LFindClose(var SearchRec: TLfnSearchRec);
begin
if LfnEnabled then
 __findclose(SearchRec.FindHandle);
end;

procedure LChDir(S: string);
var
 dir: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
 begin
 StrPCopy(dir,S);
 AnsiToOem(dir,dir);
 __chdir(dir);
 end
else
 ChDir(S);
end;

function LFileOpen(const FileName: string; Mode: Word): Integer;
var
 path: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
 begin
 StrPCopy(path,FileName);
 AnsiToOem(path,path);
 LFileOpen := __fileopen(path,Mode,$01);
 end
else
 LFileOpen := FileOpen(FileName,Mode);
end;

function LFileCreate(const FileName: string): Integer;
var
 path: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
 begin
 StrPCopy(path,FileName);
 AnsiToOem(path,path);
 LFileCreate := __fileopen(path,fmOpenWrite or fmShareExclusive, $12);
 end
else
 LFileCreate := FileCreate(FileName);
end;

function LFileGetAttr(const F: TLfnFileName): LongInt;
begin
if LfnEnabled then
  begin
  LFileGetAttr := FileGetAttr(GetShortName(F));
  end
else
  LFileGetAttr := FileGetAttr(F);
end;

function LFileGetDate(const Handle: Integer): LongInt;
begin
  LFileGetDate := FileGetDate(Handle);
end;

function LFileSetAttr(const F: TLfnFileName; Attr: LongInt): Integer;
begin
if LfnEnabled then
  begin
  LFileSetAttr := FileSetAttr(GetShortName(F),Attr);
  end
else
  LFileSetAttr := FileSetAttr(F,Attr);
end;

procedure LFileSetDate(const Handle: Integer; Date: LongInt);
begin
  FileSetDate(Handle,Date);
end;

function LRenameFile(const OldName, NewName: string): Boolean;
var
 Old,New: array [0..MAX_PATH] of Char;
 s: string;
begin
if LfnEnabled then
  begin
  {Old := StrAlloc(MAX_PATH+1);
  if (Old=nil) then
   OutOfMemoryError;
  New := StrAlloc(MAX_PATH+1);
  if (New=nil) then
   OutOfMemoryError;}
  s := LExpandFileName(NewName);
  StrPCopy(Old,OldName);
  StrPCopy(New,s);
  AnsiToOem(Old,Old);
  AnsiToOem(New,New);
  __renamefile(Old,New);
  {StrDispose(Old);
  StrDispose(New);}
  LRenameFile := (DosError=0);
  end
else
  LRenameFile := RenameFile(OldName,NewName);
end;

function LDeleteFile(const FileName: string): Boolean;
var
 FName: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
  begin
  StrPCopy(FName,FileName);
  AnsiToOem(FName,FName);
  __deletefile(FName);
  LDeleteFile := (DosError=0);
  end
else
  LDeleteFile := DeleteFile(FileName);
end;

procedure LMkDir(const FileName: string);
var
 FName: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
  begin
  StrPCopy(FName,FileName);
  AnsiToOem(FName,FName);
  __mkdir(FName);
  end
else
  MkDir(FileName);
end;

procedure LRmDir(const FileName: string);
var
 Dir: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
  begin
  StrPCopy(Dir,FileName);
  AnsiToOem(Dir,Dir);
  __rmdir(Dir);
  end
else
  MkDir(FileName);
end;

function GetShortName(const LongName: string): string;
var
  Long, Short : PChar;
  temp: string;
begin
if LfnEnabled then
  begin
  DosError := 0;
  Long := StrAlloc(MAX_PATH+1);
  Short := StrAlloc(MAX_PATH+1);
  if (Long=nil) or (Short=nil) then
    OutOfmemoryError;
  StrPCopy(Long, LongName);
  AnsiToOem(Long,Long);
  __getshortname(Long,Short);
  if (DosError=0) then
   begin
   OemToAnsi(Short,Short);
   Result := StrPas(Short);
   end
  else
   Result := LongName;
  StrDispose(Long);
  StrDispose(Short);
  end
else
  GetShortName := LongName;
end;

procedure LGetDir(D: Byte; var S: string);
var
 dir: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
  begin
  __getdir(D,dir);
  OemToAnsi(dir,dir);
  S := StrPas(dir);
  end
else
  GetDir(D,S);
end;

function GetLongName(const ShortName: string): string;
var
  Long, Short : PChar;
begin
if LfnEnabled then
  begin
  Long := StrAlloc(MAX_PATH+1);
  Short := StrAlloc(MAX_PATH+1);
  if (Long=nil) or (Short=nil) then
    OutOfmemoryError;
  StrPCopy(Short, ShortName);
  AnsiToOem(Short,Short);
  __getlongname(Short,Long);
  if (DosError=0) then
   begin
   OemToAnsi(Long,Long);
   GetLongName := StrPas(Long);
   end
  else
   GetLongName := ShortName;
  StrDispose(Long);
  StrDispose(Short);
  end
else
  GetLongName := ShortName;
end;

procedure IsWS; assembler;
{testet AL auf Wei·raum, d.h. $09, $0A, $0D, $20}
 asm	cmp	al,09h
	jz	@@e
	cmp	al,0Ah
	jz	@@e
	cmp	al,0Dh
	jz	@@e
	cmp	al,' '
@@e:	end;

function NextItemStr(var s: PChar; escap, delim:Word):PChar;assembler;
 asm	les	di,[s]
	les	di,es:[di]
	push	es
	push	di
	 push	es
	 push	di
	 push	es
	 push	di
	 push	[escap]
	 push	[delim]
	 push	cs
	 call	near ptr OneItem
	 les	di,[s]
	 stosw
	 xchg	dx,ax
	 stosw
	pop	ax
	pop	dx
 end;

function NextItem(var s: string; escap, delim:Word):string;
var
 __s: array [0..MAX_PATH] of Char;
 _s,_res: PChar;
begin
 _s := @__s[0];
 StrPCopy(_s,s);
 _res :=  NextItemStr(_s,escap,delim);
 s := StrPas(@_s[0]);
 NextItem := StrPas(_res);
end;

function OneItem(d,s: PChar; escap, delim:Word):PChar;
 assembler;
 asm	push	ds
	 cld
	 lds	si,[s]
	 les	di,[d]
	 mov	cx,ds
	 jcxz	@@e	{wenn da NIL drinsteht, immer durchreichen!}

	 mov	cx,[escap]
	 or	ch,ch
	 jnz	@@1
	 or	cl,cl
	 jz	@@1
	 mov	ch,cl	{gleich machen wenn CH=0 und CL<>0}
@@1:
	 mov	dx,[delim]
	 mov	bx,di	{Abhack-Zeiger fÅr TrimRight}
	 test	dh,1	{NoTrimLeft?}
	 jnz	@@outquoteloop
@@trimleft:
	 lodsb; or al,al; jz @@raus
	 call	IsWS
	 jz	@@trimleft
	 jmp	@@oq1

@@oq3:	 mov	bx,di	{Abhackposition vorrÅcken}
@@outquoteloop:
	 lodsb; or al,al; jz @@raus
@@oq1:	 cmp	al,cl
	 je	@@inquoteloop
	 test	dh,8	{Whitespace als Trennzeichen?}
	 jnz	@@oq2
	 cmp	al,dl
	 je	@@raus_sep
	 push	cx
	  mov	cx,es
	  jcxz	@@no1
	  stosb
@@no1:	 pop	cx
	 test	dh,2	{NoTrimRight?}
	 jnz	@@oq3
	 call	IsWS
	 jz	@@outquoteloop
	 jmp	@@oq3
@@oq2:
	 call	IsWS
	 jz	@@raus_sep
	 push	cx
	  mov	cx,es
	  jcxz	@@no2
	  stosb
@@no2:	 pop	cx
	 jmp	@@oq3

@@inquoteloop:
	 lodsb; or al,al; jz @@raus
	 cmp	al,ch
	 je	@@outquoteloop
	 push	cx
	  mov	cx,es
	  jcxz	@@no3
	  stosb
@@no3:	 pop	cx
	 mov	bx,di	{hier jeden Wei·raum mitnehmen!}
	 jmp	@@inquoteloop

@@raus:		{ohne Separator: NIL in S einspeichern lassen!}
	 dec	si	{wieder AUF DIE NULL zurÅckstellen}
	 test	dh,4
	 jz	@@raus_sep
	 xor	si,si
	 mov	ds,si		{DS:SI=0}
@@raus_sep:
	{Rechts-Trimmung ausfÅhren, gleichzeitig terminieren}
	 mov	byte ptr es:[bx],0
	{vorgerÅcktes S zurÅckliefern}
@@e:	 xchg	si,ax
	 mov	dx,ds
	pop	ds
end;

function IsProgExt(Ext: string): Boolean;
var
 s: string;
 i: integer;
begin
s := uppercase(ext);
IsProgExt := false;
if(s='')then Exit;
for i:=0 to 3 do
 if (s=ProgExts[i]) then
  begin
  Result := true;
  Exit;
  end;
end;

function GuessExt(path: string): string;
var
 rec : TLfnSearchRec;
 ret,i : integer;
 temp : string;
begin
GuessExt := '';
{first try as is}
ret := LFindFirst(path,faAnyFile and (not faVolumeID),rec);
LFindClose(rec);
if (ret=0) then { if it has been found }
 begin
 GuessExt := path;
 Exit;
 end;
if Path[Length(path)] <> '.' then
 Path := Path + '.';
for i:=0 to 3 do
 begin
 temp := Path + ProgExts[i];
ret := LFindFirst(temp,faAnyFile and (not faVolumeID),rec);
LFindClose(rec);
if (ret=0) then { if it has been found }
 begin
 GuessExt := temp;
 Exit;
 end;
 end;
end;

function SearchProgPath(prog, dirs: string): string;
var
 testdir, tmp: string;
 p : integer;
begin
while (Length(dirs)>0) and (dirs[1]=';') do
  Delete(dirs,1,1);
while (Length(dirs)>0) and (dirs[Length(dirs)]=';') do
  Delete(dirs,Length(dirs),1);
SearchProgPath := prog;
if prog='' then exit;
if (ExtractFilePath(prog) <> '')or(prog[1]='\')or(dirs='') then
 begin
 tmp := GuessExt(prog);
 if tmp <> '' then {could not find}
   SearchProgPath := tmp;
 Exit;
 end;
while dirs <> '' do
 begin
 p := Pos(';',dirs);
 if (p>0) then
  begin
  testdir := Copy(dirs,1,p-1);
  Delete(dirs,1,p);
  end
 else
  begin
  testdir := dirs;
  dirs := '';
  end;
 if(testdir[Length(testdir)] <> '\')and(testdir[Length(testdir)] <> '/') then
   testdir := testdir + '\';
 tmp := GuessExt(testdir+prog);
 if tmp <> '' then {found}
   begin
   SearchProgPath := tmp;
   Exit;
   end;
 end;
end;

function LExpandFileName(FilePath: string):string;
var
 orig, new: PChar;
 _orig, _new: array [0..MAX_PATH] of Char;
begin
if LfnEnabled then
 begin
 orig := _orig;
 new := _new;
 StrPCopy(orig,FilePath);
 AnsiToOem(orig,orig);
 __fnexpand(orig,new);
 if (DosError=0) then
  begin
  OemToAnsi(new,new);
  LExpandFileName := StrPas(new);
  end
 else
  LExpandFileName := FilePath;
 end
else
 LExpandFileName := ExpandFileName(FilePath);
end;

begin
LfnEnabled := DetectLfn;
end.
 