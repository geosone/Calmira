program TestWin16ComboBox;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Controls, native_combobox, native_edit;
type
  TObserver = class
    Changes, Clicks, Drops, Enters, Exits: Integer;
    procedure Changed(Sender: TObject);
    procedure Clicked(Sender: TObject);
    procedure Dropped(Sender: TObject);
    procedure Entered(Sender: TObject);
    procedure Exited(Sender: TObject);
  end;
var Root: TCustomControl; Edit: TComboBox; List: TComboBox; Other: TEdit;
  Observer: TObserver; Failed, Rejected: Boolean; I, PoolUser: Integer; Child: HWND;
  Marker: TObject;
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
procedure TObserver.Changed(Sender: TObject); begin Inc(Changes); end;
procedure TObserver.Clicked(Sender: TObject); begin Inc(Clicks); end;
procedure TObserver.Dropped(Sender: TObject); begin Inc(Drops); end;
procedure TObserver.Entered(Sender: TObject); begin Inc(Enters); end;
procedure TObserver.Exited(Sender: TObject); begin Inc(Exits); end;
function NativeText(Combo: TComboBox; Index: Integer): string;
var Buffer: array[0..255] of Char;
begin
  Combo.Perform(CB_GETLBTEXT, Index, LongInt(@Buffer));
  Result := StrPas(Buffer);
end;
function NativeItems(Combo: TComboBox): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to Combo.Perform(CB_GETCOUNT, 0, 0) - 1 do
  begin
    if I > 0 then Result := Result + ',';
    Result := Result + NativeText(Combo, I);
  end;
end;
procedure Pump;
var Msg: TMsg;
begin
  while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin TranslateMessage(Msg); DispatchMessage(Msg); end;
end;
begin
  LogLine('STEP native combo box');
  Observer := TObserver.Create; Marker := TObject.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Combo parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 10, 10, 360, 200);
    Edit := TComboBox.Create(nil); Edit.OnChange := Observer.Changed; Edit.OnClick := Observer.Clicked;
    Edit.OnDropDown := Observer.Dropped; Edit.OnEnter := Observer.Entered; Edit.OnExit := Observer.Exited;
    Edit.Items.Add('*.txt'); Edit.Items.AddObject('*.ini', Marker); Edit.Text := '*.*';
    Edit.SetBounds(5, 5, 150, 21);
    Check((Edit.Handle = 0) and (Edit.Text = '*.*') and (Edit.ItemIndex = -1), 'detached state');
    Edit.Parent := Root;
    Check((NativeItems(Edit) = '*.txt,*.ini') and (Edit.Text = '*.*') and (Edit.Items.Objects[1] = Marker) and
      (Observer.Changes = 0), 'creation loads items and text quietly');
    Check((Edit.Height < 40) and (Edit.Width = 150), 'closed height, list height kept by USER');
    Edit.ItemIndex := 1;
    Check((Edit.Text = '*.ini') and (Edit.Perform(CB_GETCURSEL, 0, 0) = 1) and (Observer.Changes = 0),
      'programmatic ItemIndex is quiet');
    Edit.Items.Insert(0, '*.bat');
    Check((NativeItems(Edit) = '*.bat,*.txt,*.ini') and (Edit.Items.Objects[2] = Marker), 'insert keeps objects');
    Edit.Items[1] := '*.doc';
    Check(NativeItems(Edit) = '*.bat,*.doc,*.ini', 'replace item');
    Edit.Items.Delete(0);
    Check((NativeItems(Edit) = '*.doc,*.ini') and (Edit.Items.Count = 2), 'delete item');
    Edit.SetFocus;
    Child := GetFocus;
    Check((Child <> Edit.Handle) and (WinProcs.GetParent(Child) = Edit.Handle) and
      (Root.FindControl(Child) = Edit) and Edit.Focused, 'edit child resolves to the combo box');
    Check(Observer.Enters = 1, 'enter once through CBN_SETFOCUS');
    SendMessage(Child, WM_CHAR, Ord('x'), 0);
    Check((Observer.Changes = 1) and (Pos('x', Edit.Text) > 0), 'typing reports a change');
    Edit.ItemIndex := -1; Observer.Changes := 0; Observer.Clicks := 0;
    SendMessage(Child, WM_KEYDOWN, VK_DOWN, 0); Pump;
    Check((Edit.ItemIndex = 0) and (Edit.Text = '*.doc') and (Observer.Clicks = 1) and
      (Observer.Changes = 1), 'keyboard selection copies item text and notifies');
    Edit.DroppedDown := True;
    Check(Edit.DroppedDown and (Observer.Drops = 1), 'drop down');
    Edit.DroppedDown := False;
    List := TComboBox.Create(nil); List.Style := csDropDownList; List.Sorted := True;
    List.OnChange := Observer.Changed; List.OnEnter := Observer.Entered; List.OnExit := Observer.Exited;
    List.Items.Add('Gamma'); List.Items.Add('Alpha'); List.Items.Add('Beta');
    List.SetBounds(170, 5, 150, 21); List.Parent := Root;
    Check(NativeItems(List) = 'Alpha,Beta,Gamma', 'sorted items');
    Check((List.Items.Add('Aardvark') = 0) and (NativeItems(List) = 'Aardvark,Alpha,Beta,Gamma'), 'sorted add');
    Rejected := False;
    try List.Items.Insert(0, 'Zulu'); except on Exception do Rejected := True; end;
    Check(Rejected and (List.Items.Count = 4), 'insert into sorted list rejected');
    List.Text := 'beta';
    Check((List.ItemIndex = 2) and (List.Text = 'Beta'), 'drop-down list text selects an item');
    List.Text := 'Missing';
    Check((List.ItemIndex = -1) and (List.Text = ''), 'unknown text clears the selection');
    Edit.OnEnter := nil; Edit.OnExit := nil; Observer.Enters := 0; Observer.Exits := 0;
    List.SetFocus;
    Check((GetFocus = List.Handle) and (Observer.Enters = 1) and (Observer.Exits = 0), 'list focus once');
    Check(Observer.Exits = 0, 'no spurious exit');
    Observer.Changes := 0;
    List.Perform(WM_KEYDOWN, VK_DOWN, 0); Pump;
    Check((List.ItemIndex = 0) and (Observer.Changes = 1), 'list keyboard selection');
    Other := TEdit.Create(nil); Other.SetBounds(5, 60, 100, 20); Other.Parent := Root;
    Other.SetFocus;
    Check(Observer.Exits = 1, 'exit once');
    List.ItemIndex := 3; List.DestroyHandle; List.CreateControl(Root.Handle);
    Check((NativeItems(List) = 'Aardvark,Alpha,Beta,Gamma') and (List.ItemIndex = 3), 'recreation keeps list');
    Edit.Text := 'typed'; Edit.DestroyHandle; Edit.CreateControl(Root.Handle);
    Check((Edit.Text = 'typed') and (Edit.Items.Count = 2), 'recreation keeps edit text');
    Edit.Clear;
    Check((Edit.Items.Count = 0) and (Edit.Text = '') and (Edit.Perform(CB_GETCOUNT, 0, 0) = 0), 'clear');
    Rejected := False;
    try Edit.ItemIndex := 5; except on Exception do Rejected := True; end;
    Check(Rejected, 'index out of range rejected');
    PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 30 do begin List.DestroyHandle; List.CreateControl(Root.Handle); end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2, 'recreation resource stability');
    Check(Root.CallbackErrors = 0, 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Edit.Free; List.Free; Other.Free; Root.Free; Observer.Free; Marker.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
