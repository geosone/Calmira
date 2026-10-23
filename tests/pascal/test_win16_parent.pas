program TestWin16Parent;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, StdCtrls, native_window;
var Root, Panel: TCustomControl; Text: TLabel; Button: TButton; Edit: TEdit;
  Failed: Boolean;
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
begin
  LogLine('STEP parent properties');
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Parent properties', WS_POPUP or WS_VISIBLE, 10, 10, 300, 200);
    Root.Font.Height := -16; Root.Color := clWhite;
    Panel := TCustomControl.Create(nil); Panel.SetBounds(0, 0, 200, 100); Panel.Parent := Root;
    Text := TLabel.Create(nil); Text.Parent := Panel; Text.Caption := 'Inherited';
    Button := TButton.Create(nil); Button.SetBounds(0, 40, 75, 23); Button.Parent := Panel;
    Edit := TEdit.Create(nil); Edit.SetBounds(0, 70, 100, 23); Edit.Parent := Panel;
    Check(Panel.ParentFont and (Panel.Font.Height = -16) and (Panel.Canvas.Font.Height = -16),
      'a new child takes the parent font and keeps ParentFont');
    Check((Text.Font.Height = -16) and (Button.Font.Height = -16), 'grandchildren inherit too');
    Check((Panel.Color = clWhite) and Panel.ParentColor and (Text.Color = clWhite),
      'ParentColor copies the parent colour');
    Check(not Edit.ParentColor and (Edit.Color = clWindow), 'TEdit starts with clWindow, ParentColor False');
    Root.Font.Height := -20;
    Check((Text.Font.Height = -20) and
      (HFONT(SendMessage(Button.Handle, WM_GETFONT, 0, 0)) = Button.Font.Handle),
      'a parent font change reaches native grandchildren');
    Panel.Font.Height := -9;
    Check(not Panel.ParentFont and (Text.Font.Height = -9), 'assigning Font clears ParentFont');
    Root.Font.Height := -22;
    Check((Panel.Font.Height = -9) and (Text.Font.Height = -9), 'an own font is kept');
    Panel.ParentFont := True;
    Check((Panel.Font.Height = -22) and (Text.Font.Height = -22), 'ParentFont := True re-inherits');
    Panel.Color := clRed;
    Check(not Panel.ParentColor and (Text.Color = clRed), 'assigning Color clears ParentColor');
    Panel.ParentColor := True;
    Check((Panel.Color = clWhite) and (Text.Color = clWhite), 'ParentColor := True re-inherits');
    Root.Ctl3D := False;
    Check(not Panel.Ctl3D and Panel.ParentCtl3D and not Button.Ctl3D, 'Ctl3D follows ParentCtl3D');
    Panel.Ctl3D := True;
    Check(not Panel.ParentCtl3D and Button.Ctl3D, 'assigning Ctl3D clears ParentCtl3D');
    Root.ShowHint := True; Text.Hint := 'Tip';
    Check(Text.ShowHint and Text.ParentShowHint and (Text.Hint = 'Tip'), 'ShowHint follows ParentShowHint');
    Text.Parent := nil; Root.Font.Height := -11; Text.Parent := Root;
    Check(Text.Font.Height = -11, 'reparenting re-reads the new parent');
    Check((Root.CallbackErrors = 0) and (Panel.CallbackErrors = 0), 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Edit.Free; Button.Free; Text.Free; Panel.Free; Root.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
