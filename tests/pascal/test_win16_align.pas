program TestWin16Align;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Controls, ExtCtrls, native_window;
type
  TPanel = class(TCustomControl)
  public
    property Align;
  end;
  TBox = class(TGraphicControl)
  public
    property Align;
  end;
var Root: TCustomControl; Top1, Top2, Bottom, Client: TPanel; Left: TBox; Right: TPanel;
  Book: TNotebook; Failed: Boolean;
procedure LogLine(const Text: string);
var F: HFILE; Line: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); Line := Text + #13#10; _lwrite(F, @Line[1], Length(Line)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
function At(C: TControl; L, T, R, B: Integer): Boolean;
var X: TRect;
begin
  X := C.BoundsRect;
  Result := (X.Left = L) and (X.Top = T) and (X.Right = R) and (X.Bottom = B);
  if not Result then
    LogLine(Format('INFO %s is %d,%d,%d,%d want %d,%d,%d,%d',
      [C.ClassName, X.Left, X.Top, X.Right, X.Bottom, L, T, R, B]));
end;
function Panel(Al: TAlign; X, Y, W, H: Integer): TPanel;
begin
  Result := TPanel.Create(nil); Result.SetBounds(X, Y, W, H);
  Result.Align := Al; Result.Parent := Root;
end;
begin
  LogLine('STEP align');
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Align parent', WS_POPUP or WS_VISIBLE, 10, 10, 300, 200);
    Top1 := Panel(alTop, 50, 50, 10, 20);
    Check(At(Top1, 0, 0, 300, 20), 'alTop spans the width and keeps its height');
    Bottom := Panel(alBottom, 0, 0, 10, 30);
    Check(At(Bottom, 0, 170, 300, 200), 'alBottom');
    Left := TBox.Create(nil); Left.SetBounds(0, 0, 50, 5); Left.Align := alLeft; Left.Parent := Root;
    Check(At(Left, 0, 20, 50, 170), 'graphic alLeft fills between top and bottom');
    Right := Panel(alRight, 0, 0, 40, 5);
    Check(At(Right, 260, 20, 300, 170), 'alRight');
    Client := Panel(alClient, 0, 0, 1, 1);
    Check(At(Client, 50, 20, 260, 170), 'alClient takes the rest');
    Top2 := Panel(alTop, 0, 100, 10, 10);
    Check(At(Top1, 0, 0, 300, 20) and At(Top2, 0, 20, 300, 30) and At(Client, 50, 30, 260, 170),
      'a second alTop stacks below the first by position');
    SetWindowPos(Root.Handle, 0, 0, 0, 400, 250, SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
    Check(At(Bottom, 0, 220, 400, 250) and At(Right, 360, 30, 400, 220) and At(Client, 50, 30, 360, 220),
      'resizing the parent realigns');
    Top1.Visible := False;
    Check(At(Top2, 0, 0, 400, 10) and At(Client, 50, 10, 360, 220), 'hiding a control realigns');
    Top1.Visible := True;
    Top2.Height := 40;
    Check(At(Top2, 0, 20, 400, 60) and At(Client, 50, 60, 360, 220), 'resizing an aligned control realigns');
    Root.DisableAlign;
    Bottom.Parent := nil;
    Check(At(Client, 50, 60, 360, 220), 'DisableAlign defers layout');
    Root.EnableAlign;
    Check(At(Client, 50, 60, 360, 250), 'EnableAlign applies the pending layout');
    Right.Align := alNone; Right.SetBounds(5, 5, 10, 10);
    Check(At(Right, 5, 5, 15, 15) and At(Client, 50, 60, 400, 250), 'alNone releases a control');
    Client.Free; Client := nil;
    Book := TNotebook.Create(nil); Book.Align := alClient; Book.Parent := Root;
    Check(At(Book, 50, 60, 400, 250), 'a published Align on TNotebook fills the client area');
    Book.Free;
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Client.Free; Top2.Free; Right.Free; Left.Free; Bottom.Free; Top1.Free; Root.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
