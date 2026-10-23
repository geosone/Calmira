program TestWin16Classes;
{$mode delphi}{$H-}
uses Classes, SysUtils, LangUI, language_catalog;
type
  TAboutBox = class(TComponent)
  private FCaption: string;
  published property Caption: string read FCaption write FCaption;
  end;
var
  Log: Text;
  Component: TAboutBox;
  Items: TStringList;
  Stream: TMemoryStream;
  I, CaughtCount, CleanupCount: Integer;
  Failed: Boolean;
  Expected, Value: string;
procedure Check(Condition: Boolean; const Description: string);
begin
  if Condition then WriteLn(Log, 'PASS ', Description)
  else begin WriteLn(Log, 'FAIL ', Description); Failed := True; end;
  Flush(Log);
end;
begin
  AssignFile(Log, 'C:\RTLTEST.LOG');
  Rewrite(Log);
  try
    Check(ConfigureLanguage('C:\LANG', 'de'), 'load catalogue');
    Component := TAboutBox.Create(nil);
    try
      Component.Name := 'AboutBox';
      Component.Caption := 'About';
      Expected := LanguageText('Forms', 'TAboutBox.AboutBox.Caption', '');
      ApplyComponentLanguage(Component);
      Check((Expected <> '') and (Component.Caption = Expected),
        'native component RTTI and translated caption');
    finally Component.Free; end;
    Items := TStringList.Create;
    try
      for I := 1 to 1000 do Items.Add('Item ' + IntToStr(I));
      Check((Items.Count = 1000) and (Items[999] = 'Item 1000'),
        'native TStringList allocation and indexing');
    finally Items.Free; end;
    Stream := TMemoryStream.Create;
    try
      Value := 'Calmira component stream';
      Stream.WriteBuffer(Value, SizeOf(Value));
      Stream.Position := 0;
      Expected := '';
      Stream.ReadBuffer(Expected, SizeOf(Expected));
      Check(Expected = Value, 'native component stream storage');
    finally Stream.Free; end;
    CaughtCount := 0; CleanupCount := 0;
    try
      try
        try
          raise Exception.Create('Native exception round trip');
        except
          on E: Exception do begin Inc(CaughtCount); raise; end;
        end;
      finally Inc(CleanupCount); end;
    except
      on E: Exception do
      begin
        Inc(CaughtCount);
        Check(E.Message = 'Native exception round trip', 'native exception message');
      end;
    end;
    Check((CaughtCount = 2) and (CleanupCount = 1), 'native raise reraise and finally');
  except
    on E: Exception do begin WriteLn(Log, 'FAIL exception: ', E.Message); Failed := True; end;
  end;
  if Failed then WriteLn(Log, 'RESULT FAIL') else WriteLn(Log, 'RESULT PASS');
  CloseFile(Log);
  if Failed then Halt(1);
end.
