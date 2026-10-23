{ SPDX-License-Identifier: GPL-2.0-or-later
  Known-failing pinned-compiler diagnostic, NOT an accepted regression suite.
  glbheap direct allocation can return segment:0000. The generated constructor
  checks only the offset and wrongly skips the body for this non-nil pointer. }
program LargeConstructorProbe;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs;
type TBig = class
  Pad: array[0..1099] of Byte;
  constructor Create;
end;
var Instance: TBig; Called: Boolean; F: HFILE;
const Hit: array[0..12] of Char = 'RESULT PASS'#13#10;
  Miss: array[0..12] of Char = 'RESULT FAIL'#13#10;
constructor TBig.Create;
begin Called := True; end;
begin
  F := _lcreat('C:\GDITEST.LOG', 0);
  Instance := TBig.Create;
  if F <> HFILE_ERROR then
  begin
    if Called then _lwrite(F, @Hit, 13) else _lwrite(F, @Miss, 13);
    _lclose(F);
  end;
  Instance.Free;
end.
