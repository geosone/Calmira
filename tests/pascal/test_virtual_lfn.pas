program TestVirtualLFN;

{$mode delphi}
{$H-}

uses virtual_lfn;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
  begin
    WriteLn('FAIL: ', MessageText);
    Halt(1);
  end;
end;

var
  Entry, RoundTrip: TVirtualLFNEntry;
  Line: string;
begin
  Check(IsDos83Name('README.TXT'), 'ordinary 8.3 name');
  Check(not IsDos83Name('My Report.txt'), 'spaces require an alias');
  Check(not IsDos83Name('CON'), 'DOS device names are reserved');
  Check(MakeDosAlias('My Report Final.docx', 1) = 'MYREPO~1.DOC',
    'Win9x-style alias stem and extension');
  Check(MakeDosAlias('Another.long.extension', 12) = 'ANOTH~12.EXT',
    'alias serial leaves room in the eight-character stem');
  Check(MakeDosAlias('readme.txt', 1) = 'README.TXT',
    'an existing safe 8.3 name remains stable');

  Entry.AliasName := 'MYREPO~1.DOC';
  Entry.LongName := 'My Report Final.docx';
  Entry.Metadata := 'owner=Calmira';
  Line := ComposeDescriptionLine(Entry);
  Check(ParseDescriptionLine(Line, RoundTrip), 'mapping line parses');
  Check(RoundTrip.AliasName = Entry.AliasName, 'alias round trip');
  Check(RoundTrip.LongName = Entry.LongName, 'long name round trip');
  Check(RoundTrip.Metadata = Entry.Metadata, 'Ctrl-D metadata round trip');
  Check(not ParseDescriptionLine('not-a-mapping', RoundTrip),
    'a line without a display name is rejected');

  WriteLn('virtual LFN tests: OK');
end.
