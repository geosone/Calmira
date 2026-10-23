program TestWin16Handles;
{$mode delphi}{$H+}{$APPTYPE GUI}{$M 4096,4096}
uses WinTypes, WinProcs, Win31, SysUtils, Graphics;
var Bitmap, CopyBitmap: Graphics.TBitmap; Icon, CopyIconObject: Graphics.TIcon;
  RawBitmap, SavedBitmap, ReturnedBitmap: HBITMAP;
  RawIcon, SharedIcon, SavedIcon, ReturnedIcon: HICON;
  Brush: HBRUSH; BrushDescription: TLogBrush;
  CanvasBefore: TCanvas; Bad, Failed: Boolean; I, X, Y, PoolBefore, UserBefore: Integer;
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
var B: WinTypes.TBitmap;
begin Result := GetObject(Value, SizeOf(B), @B) = SizeOf(B); end;
begin
  LogLine('STEP bitmap and icon handle ownership');
  try
    Bitmap := Graphics.TBitmap.Create; CopyBitmap := Graphics.TBitmap.Create;
    Icon := Graphics.TIcon.Create; CopyIconObject := Graphics.TIcon.Create;
    CanvasBefore := Bitmap.Canvas;
    RawBitmap := LoadBitmap(HInstance, PChar(101));
    Bitmap.Handle := RawBitmap;
    Check((Bitmap.Handle = RawBitmap) and (Bitmap.Width = 16) and
      (Bitmap.Height = 16) and (Bitmap.Canvas = CanvasBefore), 'bitmap setter adopts native handle with stable canvas');
    RawBitmap := 0; SavedBitmap := Bitmap.Handle;
    Bitmap.Handle := Bitmap.Handle;
    Check(Bitmap.Handle = SavedBitmap, 'bitmap self-handle assignment is harmless');
    CopyBitmap.Assign(Bitmap);
    Bitmap.Handle := LoadBitmap(HInstance, 'PROBE');
    Check((Bitmap.Width = 24) and not IsBitmap(SavedBitmap) and
      (CopyBitmap.Width = 16), 'bitmap replacement frees old handle without affecting assigned copy');
    SavedBitmap := Bitmap.Handle;
    Brush := CreateSolidBrush(clRed); Bad := False;
    try Bitmap.Handle := Brush; except on Exception do Bad := True; end;
    Check(Bad and (Bitmap.Handle = SavedBitmap) and
      (GetObject(Brush, SizeOf(BrushDescription), @BrushDescription) = SizeOf(BrushDescription)),
      'failed bitmap transfer preserves old image and caller object');
    DeleteObject(Brush); Brush := 0;
    ReturnedBitmap := Bitmap.ReleaseHandle;
    Check((ReturnedBitmap = SavedBitmap) and Bitmap.Empty and
      (Bitmap.Canvas.Handle = 0) and IsBitmap(ReturnedBitmap), 'bitmap detach transfers a live unselected handle to caller');
    Bitmap.Handle := ReturnedBitmap; ReturnedBitmap := 0;
    SavedBitmap := Bitmap.Handle; Bitmap.Handle := 0;
    Check(Bitmap.Empty and not IsBitmap(SavedBitmap), 'bitmap setter zero deletes old bitmap rather than detaching');
    RawBitmap := LoadBitmap(HInstance, PChar(101));
    Bitmap.CopyFromHandle(RawBitmap);
    Check((Bitmap.Handle <> RawBitmap) and (Bitmap.Width = 16), 'borrowed bitmap gets a distinct private copy');
    CopyBitmap.LoadFromResourceID(HInstance, 101); Bad := False;
    for Y := 0 to 15 do for X := 0 to 15 do
      if Bitmap.Canvas.Pixels[X, Y] <> CopyBitmap.Canvas.Pixels[X, Y] then Bad := True;
    Check(not Bad, 'borrowed bitmap copy matches every native resource pixel');
    DeleteObject(RawBitmap); RawBitmap := 0;
    Check(Bitmap.Canvas.Pixels[0, 0] <> -1, 'private bitmap copy survives caller deletion');
    RawBitmap := LoadBitmap(HInstance, PChar(101));
    Bitmap.CopyFromHandle(RawBitmap); Bitmap.Clear;
    Check(IsBitmap(RawBitmap), 'destroying borrowed bitmap copy does not delete caller handle');
    DeleteObject(RawBitmap); RawBitmap := 0;
    RawBitmap := LoadBitmap(HInstance, PChar(101)); Bitmap.Handle := RawBitmap;
    RawBitmap := 0; SavedBitmap := Bitmap.Handle;
    Bitmap.Free; Bitmap := nil;
    Check(not IsBitmap(SavedBitmap), 'bitmap destructor deletes adopted handle');
    Bitmap := Graphics.TBitmap.Create;
    SharedIcon := LoadIcon(HInstance, PChar(201));
    Icon.CopyFromHandle(SharedIcon); SavedIcon := Icon.Handle;
    Check(SharedIcon <> SavedIcon, 'shared resource is copied rather than adopted');
    Icon.Clear;
    Bitmap.SetSize(32, 32);
    Check(WinProcs.DrawIcon(Bitmap.Canvas.Handle, 0, 0, SharedIcon), 'clearing resource copy keeps shared icon drawable');
    RawIcon := Win31.CopyIcon(HInstance, SharedIcon);
    Icon.Handle := RawIcon;
    Check(Icon.Handle = RawIcon, 'icon setter adopts a private handle');
    RawIcon := 0; SavedIcon := Icon.Handle;
    Icon.Handle := Icon.Handle;
    Check(Icon.Handle = SavedIcon, 'icon self-handle assignment is harmless');
    CopyIconObject.Assign(Icon); Icon.Clear;
    Bitmap.Canvas.Draw(0, 0, CopyIconObject);
    Check(not CopyIconObject.Empty, 'assigned icon copy survives deletion of adopted source');
    SavedIcon := CopyIconObject.Handle; Bad := False;
    try CopyIconObject.Handle := 1; except on Exception do Bad := True; end;
    Check(Bad and (CopyIconObject.Handle = SavedIcon), 'ExtractIcon sentinel is rejected without destroying old icon');
    Bad := False;
    try CopyIconObject.CopyFromHandle(1); except on Exception do Bad := True; end;
    Check(Bad and (CopyIconObject.Handle = SavedIcon), 'borrowed icon copy also rejects ExtractIcon sentinel');
    ReturnedIcon := CopyIconObject.ReleaseHandle;
    Check(CopyIconObject.Empty and (ReturnedIcon = SavedIcon) and
      WinProcs.DrawIcon(Bitmap.Canvas.Handle, 0, 0, ReturnedIcon), 'icon detach leaves caller with drawable private icon');
    Icon.Handle := ReturnedIcon; ReturnedIcon := 0;
    Icon.Handle := 0;
    Check(Icon.Empty, 'icon setter zero clears private ownership');
    PoolBefore := GetFreeSystemResources(GFSR_GDIRESOURCES);
    UserBefore := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 150 do
    begin
      Bitmap.Handle := LoadBitmap(HInstance, PChar(101));
      ReturnedBitmap := Bitmap.ReleaseHandle;
      CopyBitmap.CopyFromHandle(ReturnedBitmap);
      DeleteObject(ReturnedBitmap); ReturnedBitmap := 0;
      RawIcon := Win31.CopyIcon(HInstance, SharedIcon);
      Icon.Handle := RawIcon; RawIcon := 0;
      ReturnedIcon := Icon.ReleaseHandle;
      CopyIconObject.CopyFromHandle(ReturnedIcon);
      DestroyIcon(ReturnedIcon); ReturnedIcon := 0;
    end;
    Check(GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolBefore - 2,
      'repeated transfer copy detach cycles do not drain GDI pool');
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= UserBefore - 2,
      'repeated private icon transfers do not drain USER pool');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Bitmap.Free; CopyBitmap.Free; Icon.Free; CopyIconObject.Free;
  if RawBitmap <> 0 then DeleteObject(RawBitmap);
  if ReturnedBitmap <> 0 then DeleteObject(ReturnedBitmap);
  if Brush <> 0 then DeleteObject(Brush);
  if RawIcon > 1 then DestroyIcon(RawIcon);
  if ReturnedIcon > 1 then DestroyIcon(ReturnedIcon);
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
