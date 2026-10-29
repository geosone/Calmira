program ADTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Graphics, Controls, Buttons,
  PicBtn, Askdrop, askdrop_dfm, native_form;
{$IFDEF MODAL_PROBE}
type
  { A typed old-style object callback needs no class VMT in scarce DGROUP. }
  TD = object
    Mode: Integer;
    DisabledOwner, Created: Boolean;
    procedure Shown(Sender: TObject);
  end;
{$ENDIF}
var Dialog: TAskDropBox; Failed: Boolean;
{$IFDEF MODAL_PROBE}
  Owner: TNativeForm; Observer: TD;
{$ELSE}
  I, X, Y, Ink, PoolUSER, PoolGDI: Integer; DC: HDC; Area: TRect;
{$ENDIF}
procedure LogLine(const Text: string);
var F: HFILE; Line: string; Data: array[0..255] of Char;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; StrPCopy(Data, Line);
  _lwrite(F, @Data, Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
{$IFNDEF MODAL_PROBE}
procedure Pump;
var Message: TMsg; I: Integer;
begin
  for I := 1 to 100 do
    if PeekMessage(Message, 0, 0, 0, PM_REMOVE) then
    begin
      if Message.message = WM_QUIT then raise Exception.Create('quit');
      TranslateMessage(Message); DispatchMessage(Message);
    end;
end;
{$ENDIF}
{$IFDEF MODAL_PROBE}
procedure TD.Shown(Sender: TObject);
begin
  Dialog.FormShow(Sender);
  DisabledOwner := not IsWindowEnabled(Owner.Handle);
  Created := (Dialog.Icon.Picture.Icon.Width = 32) and (Dialog.BitBtn1.Handle <> 0);
  case Mode of
    1: PostMessage(Dialog.BitBtn1.Handle, WM_KEYDOWN, VK_RETURN, $001C0001);
    2: begin
      PostMessage(Dialog.BitBtn1.Handle, WM_KEYDOWN, VK_TAB, $000F0001);
      PostMessage(Dialog.BitBtn2.Handle, WM_KEYDOWN, VK_RETURN, $001C0001);
    end;
    3: PostMessage(Dialog.BitBtn1.Handle, WM_KEYDOWN, VK_ESCAPE, $00010001);
    4: begin
      PostMessage(Dialog.BitBtn2.Handle, WM_LBUTTONDOWN, MK_LBUTTON, $00080008);
      PostMessage(Dialog.BitBtn2.Handle, WM_LBUTTONUP, 0, $00080008);
    end;
    5: PostMessage(Dialog.Handle, WM_CLOSE, 0, 0);
  end;
end;
procedure Modal(Mode, Expected: Integer);
begin
  Observer.Mode := Mode;
  Check(Dialog.ShowModal(Owner.Handle) = Expected, 'result');
  Check(Observer.DisabledOwner and Observer.Created and IsWindowEnabled(Owner.Handle) and
    not Dialog.Visible and not Dialog.ModalRunning and not Dialog.TaskQuit, 'owner');
end;
{$ENDIF}
begin
  LogLine('STEP drop');
  try
{$IFNDEF MODAL_PROBE}
    PicBtnGlyphs := False; Dialog := TAskDropBox.Create(nil);
    Check(Dialog.BitBtn1.Glyph.Empty and Dialog.BitBtn2.Glyph.Empty and
      Dialog.BitBtn3.Glyph.Empty and (Dialog.BitBtn1.Height = 23), 'plain');
    Dialog.BitBtn1.FinishLoading;
    Check(Dialog.BitBtn1.Height = 23, 'Loaded once');
    Check(not Dialog.HandleAllocated and not Dialog.Icon.Picture.Empty and
      (Dialog.InitialControl = Dialog.BitBtn1), 'create');
    Dialog.Free; Dialog := nil;
    PicBtnGlyphs := True; Dialog := TAskDropBox.Create(nil);
    Check((Dialog.BitBtn1.Glyph.Width = 16) and (Dialog.BitBtn2.Glyph.Height = 16) and
      (Dialog.BitBtn1.Glyph.Canvas.Pixels[4, 4] = clBlack) and
      (Dialog.BitBtn2.Glyph.Canvas.Pixels[4, 4] = clGreen) and
      (Dialog.BitBtn2.Glyph.Canvas.Pixels[7, 4] = clNavy), 'pixels');
    Check((Dialog.BitBtn3.Glyph.Width = 32) and (Dialog.BitBtn3.NumGlyphs = 2) and
      (Dialog.BitBtn3.Glyph.Canvas.Pixels[20, 4] = clGray) and
      Dialog.BitBtn3.Cancel and (Dialog.BitBtn3.ModalResult = mrCancel), 'kind');
    Dialog.Show; SetActiveWindow(Dialog.Handle); BringWindowToTop(Dialog.Handle);
    Dialog.Repaint; Dialog.BitBtn2.Repaint;
    Pump;
    GetClientRect(Dialog.Handle, Area);
    Check((Area.Right = 320) and (Area.Bottom = 101) and Dialog.BitBtn1.Focused and
      (DWORD(GetWindowLong(Dialog.Handle, GWL_STYLE)) and (WS_MINIMIZEBOX or WS_MAXIMIZEBOX) = 0), 'frame/focus');
    Check((Dialog.CallbackErrors = 0) and (Dialog.BitBtn2.CallbackErrors = 0), 'paint callbacks');
    if Dialog.CallbackErrors <> 0 then LogLine('FAIL ' + Dialog.LastCallbackError);
    if Dialog.BitBtn2.CallbackErrors <> 0 then LogLine('FAIL ' + Dialog.BitBtn2.LastCallbackError);
    Ink := 0; DC := GetDC(Dialog.BitBtn2.Handle);
    if DC = 0 then raise Exception.Create('DC');
    try
      Check(DWORD(GetWindowLong(Dialog.BitBtn2.Handle, GWL_STYLE)) and $F = BS_OWNERDRAW, 'owner draw');
      for Y := 0 to 24 do for X := 0 to 79 do
        if GetPixel(DC, X, Y) = DWORD(clNavy) then Inc(Ink);
    finally ReleaseDC(Dialog.BitBtn2.Handle, DC); end;
    Check(Ink > 0, 'glyph');
    Dialog.Hide;
{$ELSE}
    PicBtnGlyphs := True; Dialog := TAskDropBox.Create(nil);
    Owner := TNativeForm.Create(nil); Owner.SetBounds(10, 10, 180, 100); Owner.Show;
    Dialog.OnShow := Observer.Shown;
    Modal(1, mrOK); Modal(2, mrYes); Modal(3, mrCancel); Modal(4, mrYes); Modal(5, mrCancel);
    Dialog.DestroyHandle; Modal(1, mrOK);
    Check((Dialog.CallbackErrors = 0) and (Dialog.BitBtn1.CallbackErrors = 0) and
      (Dialog.BitBtn2.CallbackErrors = 0), 'callbacks');
{$ENDIF}
    Dialog.Free; Dialog := nil;
{$IFNDEF MODAL_PROBE}
    PoolUSER := GetFreeSystemResources(GFSR_USERRESOURCES);
    PoolGDI := GetFreeSystemResources(GFSR_GDIRESOURCES);
    for I := 1 to 20 do
    begin
      PicBtnGlyphs := Odd(I); Dialog := TAskDropBox.Create(nil);
      Dialog.Show; Dialog.Update; Dialog.Free; Dialog := nil;
    end;
    Check((GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUSER - 2) and
      (GetFreeSystemResources(GFSR_GDIRESOURCES) >= PoolGDI - 2), 'resources');
{$ENDIF}
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Dialog.Free;
{$IFDEF MODAL_PROBE}
  Owner.Free;
{$ENDIF}
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
