unit CfsNet;
{Version 0v1, by Erwin Dokter}

interface

uses CfsDecls;

function CfsNetExploreFirst(const Path: TCfsName; var SearchRec: TCfsSearchRec;
  var HasSubdirs: Boolean; var DirHandle: THandle): Integer;

function CfsNetExploreNext(const Path: TCfsName; var SearchRec: TCfsSearchRec;
  var HasSubdirs: Boolean; const DirHandle: THandle): Integer;

function CfsNetFindFirst(const Path: TCfsName; Attr: Word;
  var Rec: TCfsSearchRec; var DirHandle: THandle): Integer;

function CfsNetFindNext(const Path: TCfsName; Attr: Word;
  var Rec: TCfsSearchRec; const DirHandle: THandle): Integer;

function CfsNetFindClose(const DirHandle: THandle): Integer;

implementation

uses LanLfn, Strings;

function CfsNetExploreFirst(const Path: TCfsName; var SearchRec: TCfsSearchRec;
  var HasSubdirs: Boolean; var DirHandle: THandle): Integer;
var
  cb: Word;
  FindBuf; TFileFindBuf2
begin
  cb := 0;
  Result := LFNFindFirst(StrPChar(Path), faDirectory or faHidden or faSysFile,
    @cb, @DirHandle, SizeOf(TFileFindBuf2), @FindBuf);
  if (Result = 0) and (FindBuf.Attr and faDirectory > 0) then with SearchRec do
  begin
    SRec.Attr := FindBuf.Attr;
    SRec.Time := ($FFFF * FindBuf.fDateCreation) + FindBuf.fTimeCreation;
    SRec.Size := FindBuf.cbFile; { I hope }
    SRec.Name := {shortname};
    Name := FindBuf.Name;
  end;
end;

function CfsNetExploreNext(const Path: TCfsName; var SearchRec: TCfsSearchRec;
  var HasSubdirs: Boolean; const DirHandle: THandle): Integer;
begin

end;

function CfsNetFindFirst(const Path: TCfsName; Attr: Word;
  var Rec: TCfsSearchRec; var DirHandle: THandle):Integer;
begin

end;

function CfsNetFindNext(const Path: TCfsName; Attr: Word;
  var Rec: TCfsSearchRec; const DirHandle: THandle):Integer;
begin

end;

function CfsNetFindClose(const DirHandle: THandle): Integer;
begin

end;

end.

