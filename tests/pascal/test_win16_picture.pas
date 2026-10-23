program TestWin16Picture;
{$mode delphi}{$H+}{$APPTYPE GUI}{$M 4096,4096}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics;
type
  TObserver = class
    Picture: TPicture;
    Count: Integer;
    LastWidth, LastHeight: SmallInt;
    LastGraphic: TGraphic;
    RaiseEvent, TryReplace, ReplacementRejected: Boolean;
    procedure Change(Sender: TObject);
  end;
  TUnsupportedGraphic = class(TGraphic)
  protected
    function GetWidth: SmallInt; override;
    function GetHeight: SmallInt; override;
    function GetEmpty: Boolean; override;
  public procedure DrawTo(Destination: HDC; X, Y: SmallInt); override;
  end;
var P, Q: TPicture; Observer: TObserver; Source, Output: Graphics.TBitmap;
  SourceIcon: Graphics.TIcon; Font: TFont; Unsupported: TUnsupportedGraphic;
  Child: Graphics.TBitmap; OldGraphic: TGraphic; SavedHandle: HBITMAP;
  CountBefore, I, GDIBefore, UserBefore: Integer; Failed, Rejected: Boolean;
procedure LogLine(const Text: string);
var F: HFILE; Buffer: array[0..255] of Char; Line: ShortString;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Buffer, Line);
  _lwrite(F, @Buffer, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
function IsBitmap(Value: HBITMAP): Boolean;
var Description: WinTypes.TBitmap;
begin Result := GetObject(Value, SizeOf(Description), @Description) = SizeOf(Description); end;
procedure TObserver.Change(Sender: TObject);
begin
  if Sender <> Picture then raise Exception.Create('Wrong picture event sender');
  Inc(Count); LastGraphic := Picture.Graphic;
  LastWidth := Picture.Width; LastHeight := Picture.Height;
  if TryReplace then
    try Picture.Assign(nil); except on Exception do ReplacementRejected := True; end;
  if RaiseEvent then raise EConvertError.Create('Expected notification failure');
end;
function TUnsupportedGraphic.GetWidth: SmallInt;
begin Result := 0; end;
function TUnsupportedGraphic.GetHeight: SmallInt;
begin Result := 0; end;
function TUnsupportedGraphic.GetEmpty: Boolean;
begin Result := True; end;
procedure TUnsupportedGraphic.DrawTo(Destination: HDC; X, Y: SmallInt);
begin raise Exception.Create('Unsupported graphic must not be drawn'); end;
begin
  LogLine('STEP picture ownership and notifications');
  try
    P := TPicture.Create; Q := TPicture.Create;
    Observer := TObserver.Create; Observer.Picture := P; P.OnChange := Observer.Change;
    Check((P.Graphic = nil) and P.Empty and (P.Width = 0) and (P.Height = 0),
      'new picture metadata does not create a graphic');
    Child := P.Bitmap;
    Check((Observer.Count = 1) and (Observer.LastGraphic = Child) and P.Empty,
      'bitmap getter creates one owned empty child and one event');
    CountBefore := Observer.Count;
    Check((P.Bitmap = Child) and (Observer.Count = CountBefore), 'repeated getter keeps child identity without notification');
    Child.SetSize(4, 4);
    Check((Observer.Count = CountBefore + 1) and (Observer.LastWidth = 4) and (Observer.LastHeight = 4),
      'child resize notifies after complete dimensions are committed');
    CountBefore := Observer.Count; Child.Canvas.Pixels[0, 0] := clRed;
    Check((Observer.Count = CountBefore + 1) and (P.Bitmap.Canvas.Pixels[0, 0] = clRed),
      'child canvas pixel write forwards picture event');
    CountBefore := Observer.Count; Child.Canvas.Pixels[-1, -1] := clRed;
    Check(Observer.Count = CountBefore, 'clipped pixel write does not report a change');
    Child.Canvas.Brush.Color := clBlue;
    Child.Canvas.FillRect(Rect(0, 0, 4, 4));
    Check(Observer.Count = CountBefore + 1, 'child canvas fill forwards picture event');
    CountBefore := Observer.Count;
    Child.Transparent := True; Child.TransparentColor := clRed;
    Check(Observer.Count = CountBefore + 2, 'transparency changes forward picture events');
    Source := Graphics.TBitmap.Create; Source.SetSize(4, 4);
    Source.Canvas.Brush.Color := clBlue; Source.Canvas.FillRect(Rect(0, 0, 4, 4));
    CountBefore := Observer.Count;
    Child.Canvas.MoveTo(0, 0); Child.Canvas.TextWidth('Test');
    Check(Observer.Count = CountBefore, 'canvas positioning and measurement do not change picture');
    Child.Canvas.LineTo(3, 0);
    Child.Canvas.Rectangle(0, 0, 3, 3);
    Child.Canvas.TextOut(0, 0, 'T');
    Child.Canvas.CopyRect(Rect(0, 0, 2, 2), Source.Canvas, Rect(0, 0, 2, 2));
    Child.Canvas.CopyTransparent(Rect(0, 0, 2, 2), Source.Canvas, Rect(0, 0, 2, 2), clWhite);
    Child.Canvas.BrushCopy(Rect(0, 0, 2, 2), Source, Rect(0, 0, 2, 2), clWhite);
    Child.Canvas.Draw(0, 0, Source);
    Check(Observer.Count = CountBefore + 7, 'all canvas drawing operations forward one picture event');
    CountBefore := Observer.Count;
    Child.Canvas.CopyRect(Rect(0, 0, 0, 2), Source.Canvas, Rect(0, 0, 2, 2));
    Child.Canvas.CopyTransparent(Rect(0, 0, 0, 2), Source.Canvas, Rect(0, 0, 2, 2), clWhite);
    Check(Observer.Count = CountBefore, 'zero-area copies do not emit picture events');
    CountBefore := Observer.Count; P.Bitmap := Source;
    Check((Observer.Count = CountBefore + 1) and (P.Bitmap.Handle <> Source.Handle),
      'bitmap property assignment copies rather than takes caller object');
    Source.Canvas.Pixels[0, 0] := clRed;
    Check(P.Bitmap.Canvas.Pixels[0, 0] = clBlue, 'picture bitmap is independent of source edits');
    Source.Free; Source := nil;
    Check(P.Bitmap.Canvas.Pixels[0, 0] = clBlue, 'picture bitmap survives source destruction');
    Q.Assign(P); Q.Bitmap.Canvas.Pixels[0, 0] := clRed;
    Check((Q.Graphic <> P.Graphic) and (P.Bitmap.Canvas.Pixels[0, 0] = clBlue), 'picture Assign deep-copies contained graphic');
    CountBefore := Observer.Count; P.Assign(P); P.Graphic := P.Graphic;
    Check(Observer.Count = CountBefore, 'self picture and graphic assignments are no-ops');
    SavedHandle := P.Bitmap.Handle;
    SourceIcon := Graphics.TIcon.Create; SourceIcon.LoadFromResource(HInstance, PChar(201));
    CountBefore := Observer.Count; P.Icon := SourceIcon;
    Check((Observer.Count = CountBefore + 1) and (P.Graphic is Graphics.TIcon) and
      (P.Width = GetSystemMetrics(SM_CXICON)) and not IsBitmap(SavedHandle),
      'icon property switch frees old bitmap and publishes complete icon dimensions');
    SourceIcon.Free; SourceIcon := nil;
    Output := Graphics.TBitmap.Create; Output.SetSize(32, 32);
    CountBefore := Observer.Count;
    Output.Canvas.Draw(0, 0, P.Graphic);
    Check(not P.Empty and (Observer.Count = CountBefore), 'drawing picture graphic does not mutate source notifications');
    CountBefore := Observer.Count; P.Icon.LoadFromResource(HInstance, 'ICONPROBE');
    Check((Observer.Count = CountBefore + 1) and (Observer.LastWidth > 0), 'icon resource replacement emits one final-state event');
    CountBefore := Observer.Count; Child := P.Bitmap;
    Check((Observer.Count = CountBefore + 1) and Child.Empty and (P.Width = 0), 'bitmap getter switches from icon to owned empty bitmap');
    OldGraphic := P.Graphic; CountBefore := Observer.Count;
    Font := TFont.Create; Rejected := False;
    try P.Assign(Font); except on EConvertError do Rejected := True; end;
    Check(Rejected and (P.Graphic = OldGraphic) and (Observer.Count = CountBefore), 'incompatible persistent assignment preserves picture and events');
    Unsupported := TUnsupportedGraphic.Create; Rejected := False;
    try P.Graphic := Unsupported; except on EConvertError do Rejected := True; end;
    Check(Rejected and (P.Graphic = OldGraphic) and (Observer.Count = CountBefore), 'unsupported graphic assignment preserves old picture');
    Rejected := False;
    try P.LoadFromFile('C:\BAD.BMP'); except on Exception do Rejected := True; end;
    Check(Rejected and (P.Graphic = OldGraphic) and (Observer.Count = CountBefore), 'failed file load preserves old picture without event');
    P.LoadFromFile('C:\PROBE.BMP');
    Check((Observer.Count = CountBefore + 1) and (P.Width = 16) and (Observer.LastHeight = 16), 'BMP file load commits one complete picture event');
    CountBefore := Observer.Count;
    P.Bitmap.Assign(Q.Bitmap);
    Check((Observer.Count = CountBefore + 1) and (P.Width = 4), 'direct child Assign forwards exactly one event');
    P.Bitmap.Transparent := True; Q.Bitmap.Transparent := False;
    CountBefore := Observer.Count; P.Bitmap.Assign(Q.Bitmap);
    Check((Observer.Count = CountBefore + 1) and not P.Bitmap.Transparent, 'child Assign publishes final transparency settings');
    Observer.TryReplace := True; Observer.ReplacementRejected := False;
    P.Bitmap.SetSize(8, 8); Observer.TryReplace := False;
    Check(Observer.ReplacementRejected and (P.Width = 8), 'notification cannot replace and free its active child');
    CountBefore := Observer.Count; Observer.RaiseEvent := True; Rejected := False;
    try P.Bitmap := Q.Bitmap; except on EConvertError do Rejected := True; end;
    Observer.RaiseEvent := False;
    Check(Rejected and (Observer.Count = CountBefore + 1) and (P.Width = 4), 'notification exception leaves committed replacement owned by picture');
    P.Bitmap.SetSize(6, 6);
    Check(Observer.Count = CountBefore + 2, 'notification guard recovers after callback exception');
    SavedHandle := P.Bitmap.Handle; Observer.RaiseEvent := True; Rejected := False;
    try P.Bitmap.ReleaseHandle; except on EConvertError do Rejected := True; end;
    Observer.RaiseEvent := False;
    Check(Rejected and P.Empty and not IsBitmap(SavedHandle), 'failed release notification does not orphan returned bitmap handle');
    P.Icon.LoadFromResource(HInstance, PChar(201)); Observer.RaiseEvent := True; Rejected := False;
    try P.Icon.ReleaseHandle; except on EConvertError do Rejected := True; end;
    Observer.RaiseEvent := False;
    Check(Rejected and P.Empty, 'failed release notification leaves icon empty without transferring a lost handle');
    GDIBefore := GetFreeSystemResources(GFSR_GDIRESOURCES);
    UserBefore := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 150 do
    begin
      P.Bitmap.LoadFromResourceID(HInstance, 101);
      Q.Assign(P);
      P.Icon.LoadFromResource(HInstance, PChar(201));
      Q.Assign(P); P.Assign(nil); Q.Assign(nil);
    end;
    Check(GetFreeSystemResources(GFSR_GDIRESOURCES) >= GDIBefore - 2, 'picture switch copy clear cycles do not drain GDI pool');
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= UserBefore - 2, 'picture icon switches do not drain USER pool');
    P.Bitmap.LoadFromResourceID(HInstance, 101); SavedHandle := P.Bitmap.Handle;
    CountBefore := Observer.Count; P.Free; P := nil;
    Check((Observer.Count = CountBefore) and not IsBitmap(SavedHandle), 'picture destructor frees child without teardown callbacks');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Unsupported.Free; Font.Free; Output.Free; Source.Free; SourceIcon.Free;
  Q.Free; P.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
