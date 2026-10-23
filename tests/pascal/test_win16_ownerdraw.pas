program TestWin16OwnerDraw;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Messages, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls,
  native_window;
type
  TReflectCombo = class(TComboBox)
  private
    procedure CNDrawItem(var M: TWMDrawItem); message CN_DRAWITEM;
    procedure CNMeasureItem(var M: TWMMeasureItem); message CN_MEASUREITEM;
  end;
  THookList = class(TListBox)
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
  end;
  THandler = class
    DblClicks: Integer;
    procedure DblClick(Sender: TObject);
    procedure Draw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure Measure(Control: TWinControl; Index: Integer; var Height: Integer);
  end;
var Root: TCustomControl; Fixed, Variable: TListBox; Combo, VarCombo: TComboBox;
  Reflect: TReflectCombo; Handler: THandler;
  Drawn, Reflected, Failed: Boolean; Measured, CreatedCount, DestroyedCount: Integer;
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
procedure TReflectCombo.CNDrawItem(var M: TWMDrawItem);
begin Reflected := True; inherited; end;
procedure TReflectCombo.CNMeasureItem(var M: TWMMeasureItem);
begin inherited; M.MeasureItemStruct^.itemHeight := 30; end;
procedure THandler.Draw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin Drawn := True; Control.Canvas.FillRect(Rect); end;
procedure THandler.Measure(Control: TWinControl; Index: Integer; var Height: Integer);
begin Inc(Measured); Height := 10 + Index * 2; end;
procedure THookList.CreateWnd;
begin inherited CreateWnd; CreatedCount := Perform(LB_GETCOUNT, 0, 0); end;
procedure THookList.DestroyWnd;
begin DestroyedCount := Perform(LB_GETCOUNT, 0, 0); inherited DestroyWnd; end;
procedure THandler.DblClick(Sender: TObject);
begin Inc(DblClicks); end;
procedure Fill(Items: TStrings);
begin Items.Add('Alpha'); Items.Add('Beta'); Items.Add('Gamma'); end;
function ListHeights(List: TListBox): Boolean;
var I: Integer;
begin
  Result := True;
  for I := 0 to 2 do
    Result := Result and (List.Perform(LB_GETITEMHEIGHT, I, 0) = 10 + I * 2);
end;
function ComboHeights(Box: TComboBox): Boolean;
var I: Integer;
begin
  Result := True;
  for I := 0 to 2 do
    Result := Result and (Box.Perform(CB_GETITEMHEIGHT, I, 0) = 10 + I * 2);
end;
procedure HooksAndEdits;
var Hook: THookList; Auto, Plain: TEdit; Simple: TComboBox; Raised: Boolean;
  AutoArea, PlainArea: TRect;
begin
  Hook := THookList.Create(nil); Fill(Hook.Items); CreatedCount := -1; DestroyedCount := -1;
  Hook.SetBounds(0, 160, 100, 60); Hook.Parent := Root;
  Check(CreatedCount = 3, 'CreateWnd runs after the window and its items exist');
  Hook.Free;
  Check(DestroyedCount = 3, 'DestroyWnd runs while the window still holds its items');
  Auto := TEdit.Create(nil); Auto.Text := 'hello'; Auto.SetBounds(120, 160, 100, 23); Auto.Parent := Root;
  Plain := TEdit.Create(nil); Plain.Text := 'world'; Plain.AutoSelect := False;
  Plain.BorderStyle := bsNone; Plain.SetBounds(120, 190, 100, 23); Plain.Parent := Root;
  Auto.SetFocus;
  Check(Auto.SelLength = 5, 'AutoSelect selects the text on entry');
  Plain.SetFocus;
  Check(Plain.SelLength = 0, 'without AutoSelect the text stays unselected');
  { USER's EDIT takes WS_BORDER off its style and insets the text itself. }
  Auto.Perform(EM_GETRECT, 0, LongInt(@AutoArea)); Plain.Perform(EM_GETRECT, 0, LongInt(@PlainArea));
  Check(AutoArea.Left > PlainArea.Left, 'BorderStyle bsNone drops the edit border');
  Raised := False;
  try Plain.BorderStyle := bsSingle; except on ENativeWindowError do Raised := True; end;
  Check(Raised, 'a live BorderStyle change is rejected');
  Simple := TComboBox.Create(nil); Simple.Style := csSimple; Fill(Simple.Items);
  Simple.OnDblClick := Handler.DblClick; Simple.SetBounds(240, 160, 100, 80); Simple.Parent := Root;
  SendMessage(Root.Handle, WM_COMMAND, GetDlgCtrlID(Simple.Handle), MakeLong(Simple.Handle, CBN_DBLCLK));
  Check(Handler.DblClicks = 1, 'CBN_DBLCLK fires OnDblClick');
  Simple.Free; Plain.Free; Auto.Free;
end;
begin
  LogLine('STEP owner draw');
  Handler := THandler.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Owner draw', WS_POPUP or WS_VISIBLE, 10, 10, 400, 300);
    Fixed := TListBox.Create(nil); Fixed.Style := lbOwnerDrawFixed; Fixed.ItemHeight := 18;
    Fill(Fixed.Items); Fixed.SetBounds(0, 0, 100, 100); Fixed.Parent := Root;
    Check(Fixed.Perform(LB_GETITEMHEIGHT, 0, 0) = 18, 'a fixed list box is measured with ItemHeight');
    Variable := TListBox.Create(nil); Variable.Style := lbOwnerDrawVariable;
    Variable.OnMeasureItem := Handler.Measure; Fill(Variable.Items);
    Variable.SetBounds(100, 0, 100, 100); Variable.Parent := Root;
    Check(ListHeights(Variable) and (Measured >= 3), 'lbOwnerDrawVariable asks OnMeasureItem per item');
    Combo := TComboBox.Create(nil); Combo.Style := csOwnerDrawFixed; Combo.ItemHeight := 20;
    Combo.OnDrawItem := Handler.Draw; Fill(Combo.Items);
    Combo.SetBounds(0, 120, 120, 24); Combo.Parent := Root;
    Check((Combo.Perform(CB_GETITEMHEIGHT, 0, 0) = 20) and (Combo.ItemHeight = 20),
      'csOwnerDrawFixed items use ItemHeight');
    Combo.ItemIndex := 1; UpdateWindow(Combo.Handle);
    Check(Drawn, 'the selection field is drawn through OnDrawItem');
    VarCombo := TComboBox.Create(nil); VarCombo.Style := csOwnerDrawVariable;
    VarCombo.OnMeasureItem := Handler.Measure; Fill(VarCombo.Items);
    VarCombo.SetBounds(130, 120, 120, 24); VarCombo.Parent := Root;
    Check(ComboHeights(VarCombo), 'csOwnerDrawVariable asks OnMeasureItem per item');
    Reflect := TReflectCombo.Create(nil); Reflect.Style := csOwnerDrawFixed; Fill(Reflect.Items);
    Reflect.SetBounds(260, 120, 120, 24); Reflect.Parent := Root;
    Check(Reflect.Perform(CB_GETITEMHEIGHT, 0, 0) = 30, 'a CN_MEASUREITEM handler sees and overrides the item');
    Reflect.ItemIndex := 0; UpdateWindow(Reflect.Handle);
    Check(Reflected, 'WM_DRAWITEM is reflected to the child as CN_DRAWITEM');
    Check((GetDlgCtrlID(Combo.Handle) >= $100) and (GetDlgCtrlID(Combo.Handle) <> GetDlgCtrlID(VarCombo.Handle)),
      'child windows get distinct control IDs');
    HooksAndEdits;
    Check((Root.CallbackErrors = 0) and (Combo.CallbackErrors = 0) and (Reflect.CallbackErrors = 0),
      'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Reflect.Free; VarCombo.Free; Combo.Free; Variable.Free; Fixed.Free; Root.Free; Handler.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
