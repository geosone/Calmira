{$IFDEF FPC}
{ FPC's RTL builds the parameter list on the heap. }
{$M 4096,0,1024}
{$ELSE}
{$M 4096,0,0}
{$ENDIF}
program DirExist;

{ Note: this program is for MS-DOS Turbo Pascal, not Delphi }

uses {$IFDEF FPC} Dos; {$ELSE} WinDOS, Strings; {$ENDIF}

function IsRoot(s: string): Boolean;
begin
  s[1] := UpCase(s[1]);
  IsRoot := ((Length(s) = 3) and (s[1] >= 'A') and (s[1] <= 'Z') and
    (s[2] = ':') and (s[3] = '\'))
    or ((s[1] = '.') and (s[2] = '.'))
    or (s = '\');
end;

var
  filename: string;
{$IFDEF FPC}
  SR: SearchRec;
{$ELSE}
  buf: array[0..255] of Char;
  SR: TSearchRec;
{$ENDIF}

begin
  filename := ParamStr(1);
  if filename = '' then Halt(0);
  if IsRoot(filename) then Halt(1);
{$IFDEF FPC}
  FindFirst(filename, Directory, SR);
  if (DosError = 0) and (SR.Attr and Directory <> 0) then Halt(1)
{$ELSE}
  FindFirst(StrPCopy(buf, filename), faDirectory, SR);
  if (DosError = 0) and (SR.Attr and faDirectory <> 0) then Halt(1)
{$ENDIF}
  else Halt(0);
end.
