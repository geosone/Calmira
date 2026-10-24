program TestWin16RadioGroup;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, ExtCtrls;
type
  TEvents = class
    Clicks: Integer;
    procedure Click(Sender: TObject);
  end;
  { A DFM-loaded form: ItemIndex is streamed before Items. }
  TRadioForm = class(TForm)
  published
    Group: TRadioGroup;
  end;
var Events: TEvents; Main: TForm; Box: TGroupBox; Child: TPanel; Group: TRadioGroup; Loaded: TRadioForm;
  Failed: Boolean; DC: HDC; Area: TRect; Second: TRadioButton;
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
procedure Pump;
var Msg: TMsg; Start: LongInt;
begin
  Start := WinProcs.GetTickCount;
  while WinProcs.GetTickCount - Start < 150 do
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
procedure TEvents.Click(Sender: TObject); begin Inc(Clicks); end;
function PixelAt(Control: TWinControl; X, Y: Integer): TColorRef;
begin
  DC := GetDC(Control.Handle);
  Result := GetPixel(DC, X, Y);
  ReleaseDC(Control.Handle, DC);
end;
function HasTextPixel(Control: TWinControl; const R: TRect): Boolean;
var X, Y: Integer; Face: TColorRef;
begin
  Result := False;
  DC := GetDC(Control.Handle);
  Face := GetPixel(DC, R.Left, R.Top);
  for Y := R.Top to R.Bottom - 1 do
    for X := R.Left to R.Right - 1 do
      if GetPixel(DC, X, Y) <> Face then begin Result := True; Break; end;
  ReleaseDC(Control.Handle, DC);
end;
function Button(Index: Integer): TRadioButton;
begin Result := Group.Controls[Index] as TRadioButton; end;
procedure LoadRadioForm(Form: TForm);
var F: TRadioForm;
begin
  F := TRadioForm(Form);
  F.SetBounds(20, 20, 200, 150);
  F.Group := TRadioGroup.Create(F);
  ComponentLoading(F.Group); F.Group.Name := 'Group';
  F.Group.Parent := F; F.Group.SetBounds(5, 5, 180, 100);
  F.Group.ItemIndex := 2;
  F.Group.Items.Clear;
  F.Group.Items.Add('One'); F.Group.Items.Add('Two'); F.Group.Items.Add('Three');
end;
begin
  LogLine('STEP radio group');
  Events := TEvents.Create;
  try
    Main := TForm.Create(nil); Main.SetBounds(10, 10, 420, 320); Main.Caption := 'Groups';
    Box := TGroupBox.Create(Main);
    Check((Box.Width = 185) and (Box.Height = 105) and Box.Ctl3D, 'TGroupBox has Delphi''s defaults');
    Box.Parent := Main; Box.SetBounds(10, 10, 180, 120); Box.Caption := 'Frame';
    Child := TPanel.Create(Main); Child.Parent := Box; Child.Align := alClient; Child.BevelOuter := bvNone;
    Main.Show; Pump;
    Area := Child.BoundsRect;
    Check((Area.Left = 2) and (Area.Right = 178) and (Area.Bottom = 118) and (Area.Top > 8) and (Area.Top < 30),
      'aligned children stay inside the frame and below the caption');
    Child.Free; Child := nil; Pump;
    Check((PixelAt(Box, 0, 80) = ColorToRGB(clBtnShadow)) and (PixelAt(Box, 1, 80) = ColorToRGB(clBtnHighlight)) and
      (PixelAt(Box, 178, 80) = ColorToRGB(clBtnShadow)) and (PixelAt(Box, 179, 80) = ColorToRGB(clBtnHighlight)),
      'the 3-D frame is a shadow line with a highlight beside it');
    Check(HasTextPixel(Box, Rect(8, 0, 40, 12)), 'the caption is drawn in the top edge');
    Box.Ctl3D := False; Box.Invalidate; Pump;
    Check(PixelAt(Box, 0, 80) = ColorToRGB(clWindowFrame), 'without Ctl3D the frame is one line');

    Group := TRadioGroup.Create(Main);
    Check((Group.ItemIndex = -1) and (Group.Columns = 1) and (Group.Items.Count = 0) and (Group.ControlCount = 0),
      'TRadioGroup has Delphi''s defaults');
    Group.Parent := Main; Group.SetBounds(200, 10, 200, 120); Group.Caption := 'Sorting';
    Group.OnClick := Events.Click;
    Group.Items.Add('Name'); Group.Items.Add('Type'); Group.Items.Add('Size');
    Pump;
    Check((Group.ControlCount = 3) and (Button(2).Caption = 'Size') and not Button(0).Checked,
      'each item gets a radio button');
    Check((Button(1).Top > Button(0).Top) and (Button(0).Left = 8) and (Button(0).Top > 8) and
      (Button(2).Top + Button(2).Height <= 120), 'one column stacks the buttons inside the frame');
    Group.ItemIndex := 1;
    Check(Button(1).Checked and not Button(0).Checked and (Events.Clicks = 0),
      'ItemIndex checks a button without OnClick');
    Group.ItemIndex := 10;
    Check((Group.ItemIndex = 2) and Button(2).Checked and not Button(1).Checked, 'ItemIndex is clamped to the items');
    Group.ItemIndex := -1;
    Check(not Button(2).Checked, 'ItemIndex -1 checks nothing');

    SendMessage(Button(0).Handle, WM_LBUTTONDOWN, MK_LBUTTON, MakeLong(4, 4));
    SendMessage(Button(0).Handle, WM_LBUTTONUP, 0, MakeLong(4, 4));
    Pump;
    Check((Group.ItemIndex = 0) and Button(0).Checked and (Events.Clicks = 1), 'clicking a button selects it with OnClick');

    Group.Items.Add('Date'); Group.Columns := 2; Pump;
    Check((Group.ControlCount = 4) and (Button(2).Left > Button(0).Left) and (Button(2).Top = Button(0).Top) and
      (Button(3).Top = Button(1).Top), 'Columns fills each column top to bottom');
    Group.ItemIndex := 3;
    Group.Items.Delete(3);
    Check((Group.ItemIndex = 2) and (Group.ControlCount = 3) and Button(2).Checked,
      'removing the checked item moves ItemIndex to the last item');
    Group.Items[0] := 'Renamed';
    Check(Button(0).Caption = 'Renamed', 'changed items rename their buttons');
    Group.Enabled := False;
    Check(not Button(0).Enabled and not Button(2).Enabled, 'disabling the group disables its buttons');
    Group.Enabled := True;
    Check(Button(1).Enabled, 'enabling the group enables its buttons');
    Second := Button(1);
    Check(not Second.TabStop and Button(2).TabStop, 'only the checked button is a tab stop');

    RegisterFormLoader(TRadioForm, LoadRadioForm);
    Loaded := TRadioForm.Create(nil);
    Check((Loaded.Group.ItemIndex = 2) and (Loaded.Group.ControlCount = 3) and
      (Loaded.Group.Controls[2] as TRadioButton).Checked, 'a streamed ItemIndex applies after Items load');
    Loaded.Free; Loaded := nil;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  Loaded.Free;
  Main.Free;
  Events.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
