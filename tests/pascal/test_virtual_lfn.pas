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
  Fixture: Text;
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

  { Independently generated document mapping from the IFA 4.00 native test.
    This fixture contains no third-party executable or document data. }
  Assign(Fixture, 'tests/fixtures/ifa400_descript.ion');
  Reset(Fixture);
  ReadLn(Fixture, Line);
  Check(ParseDescriptionLine(Line, RoundTrip),
    'IFA describes DESCRIPT.ION using an ordinary mapping entry');
  Check(RoundTrip.AliasName = 'DESCRIPT.ION', 'IFA self-description alias');
  ReadLn(Fixture, Line);
  Close(Fixture);
  Check(ParseDescriptionLine(Line, RoundTrip), 'native IFA document mapping parses');
  Check(RoundTrip.LongName = 'calmira langer dateiname.cwk',
    'native IFA display name is preserved');
  Check(RoundTrip.AliasName = MakeDosAlias(RoundTrip.LongName, 1),
    'portable alias generation matches observed IFA alias');
  Check(ComposeDescriptionLine(RoundTrip) = Line,
    'native IFA document mapping round trips without changes');

  WriteLn('virtual LFN tests: OK');
end.
