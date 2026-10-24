program TestWin16FileFilter;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, FileCtrl;
type
  EProbeError = class(Exception);
var Main: TForm; Filter: TFilterComboBox; Saved, Loaded: TBitmap; Failed: Boolean;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
function RaisedMessage(Ident: Word; Formatted: Boolean): string;
begin
  Result := '';
  try
    if Formatted then raise EProbeError.CreateResFmt(Ident, ['A.TXT'])
    else raise EProbeError.CreateRes(Ident);
  except on E: EProbeError do Result := E.Message; end;
end;
procedure CheckBitmaps;
begin
  Saved := TBitmap.Create;
  Saved.Width := 5; Saved.Height := 3;
  Saved.Canvas.Brush.Color := clWhite; Saved.Canvas.FillRect(Rect(0, 0, 5, 3));
  Saved.Canvas.Pixels[0, 0] := clRed; Saved.Canvas.Pixels[4, 2] := clBlue; Saved.Canvas.Pixels[2, 1] := clLime;
  Saved.SaveToFile('C:\SAVED.BMP');
  Saved.FreeImage;
  Check(Saved.Canvas.Pixels[0, 0] = clRed, 'saving keeps the bitmap drawable');
  Loaded := TBitmap.Create;
  Loaded.LoadFromFile('C:\SAVED.BMP');
  Check((Loaded.Width = 5) and (Loaded.Height = 3), 'a saved bitmap loads with its size');
  Check((Loaded.Canvas.Pixels[0, 0] = clRed) and (Loaded.Canvas.Pixels[4, 2] = clBlue) and
    (Loaded.Canvas.Pixels[2, 1] = clLime) and (Loaded.Canvas.Pixels[1, 1] = clWhite),
    'a saved bitmap keeps its pixels and row order');
end;
begin
  LogLine('STEP file filter');
  try
    Main := TForm.Create(nil); Main.SetBounds(10, 10, 300, 200);
    Filter := TFilterComboBox.Create(Main);
    Check((Filter.Style = csDropDownList) and (Filter.Mask = '*.*'), 'TFilterComboBox has Delphi''s defaults');
    Filter.Parent := Main; Filter.SetBounds(10, 10, 200, 100);
    Main.Show;
    Check((Filter.Items.Count = 1) and (Filter.Items[0] = 'All files (*.*)') and (Filter.ItemIndex = 0),
      'the default filter lists all files');
    Filter.Filter := 'Programs (*.EXE)|*.EXE;*.COM|Text|All files (*.*)|*.*';
    Check((Filter.Items.Count = 3) and (Filter.Items[1] = 'Text') and (Filter.ItemIndex = 0) and
      (Filter.Mask = '*.EXE;*.COM'), 'Filter pairs descriptions with masks');
    Filter.ItemIndex := 2;
    Check(Filter.Mask = '*.*', 'Mask follows the selected filter');
    Filter.ItemIndex := 1;
    Check(Filter.Mask = 'All files (*.*)', 'a description without a mask is its own mask');
    Filter.Filter := '';
    Check((Filter.Items.Count = 0) and (Filter.Mask = '*.*'), 'an empty filter falls back to *.*');

    CheckBitmaps;

    Check(IsAccel(Ord('F'), '&File') and IsAccel(Ord('X'), 'E&xit') and not IsAccel(Ord('F'), 'File') and
      not IsAccel(Ord('A'), 'Save && &Quit') and IsAccel(Ord('Q'), 'Save && &Quit') and not IsAccel(300, '&File'),
      'IsAccel matches the mnemonic character');

    Check(LoadStr(1090) = 'Plain resource text', 'LoadStr reads the module string table');
    Check(FmtLoadStr(1089, ['B.TXT']) = 'Cannot copy B.TXT to itself', 'FmtLoadStr formats a string resource');
    Check(LoadStr(4000) = '', 'a missing string resource is empty');
    Check(RaisedMessage(1089, True) = 'Cannot copy A.TXT to itself', 'CreateResFmt takes a string-table identifier');
    Check(RaisedMessage(1090, False) = 'Plain resource text', 'CreateRes takes a string-table identifier');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Loaded.Free;
  Saved.Free;
  Main.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
