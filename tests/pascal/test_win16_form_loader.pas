program TestWin16FormLoader;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Messages, Classes, SysUtils, Graphics, Controls, StdCtrls, ExtCtrls, Menus,
  Forms, form_loader_probe, form_loader_probe_dfm;
var Probe, Second: TProbeForm; Derived: TDerivedProbe; Orphan: TOrphanForm; Plain: TForm;
  Failed, Raised: Boolean; R: TRect;
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
procedure NoComponents(Form: TForm);
begin end;
function Page(Book: TNotebook; Index: Integer): TPage;
begin Result := TPage(Book.Pages.Objects[Index]); end;
begin
  LogLine('STEP form loader');
  try
    Probe := TProbeForm.Create(Application);
    with Probe do
    begin
      Check((Name = 'ProbeForm') and (FindComponent('NameEdit') = NameEdit) and (NameEdit.Owner = Probe),
        'components are named fields owned by the form');
      Check((Title.Parent = Probe) and (NameEdit.Left = 72) and (NameEdit.Top = 4) and
        (NameEdit.Width = 120) and (Choices.Height = 60), 'controls get their parent and bounds');
      Check((Caption = 'Loader probe') and (OkButton.Caption = 'OK') and (NameEdit.Text = 'Calmira') and
        (NameEdit.MaxLength = 20) and OkButton.Default and (OkButton.ModalResult = 1) and Agree.Checked,
        'values are assigned');
      Check((Choices.Items.Count = 3) and (Choices.Items[1] = 'Beta'), 'string lists are filled');
      Check((Agree.Font.Color = clRed) and (fsBold in Agree.Font.Style) and not Agree.ParentFont,
        'a control font is assigned');
      Check((Font.Name = 'MS Sans Serif') and (Font.Height = -11) and (Title.Font.Height = -11),
        'the form font reaches parent-font controls');
      Check(Line.Shape = bsBottomLine, 'enumeration values are assigned');
      Check((Book.Pages.Count = 2) and (Book.Pages[0] = 'First') and (PageEdit.Parent = Page(Book, 0)) and
        (PageCheck.Parent = Page(Book, 1)), 'notebook pages replace the default page and hold their controls');
      Check((Book.PageIndex = 1) and Page(Book, 1).Visible and not Page(Book, 0).Visible,
        'PageIndex read before the pages applies after loading');
      Check((Popup.Items.Count = 1) and (Popup.Items[0] = OpenItem) and (OpenItem.Count = 1) and
        (OpenItem[0] = SubItem), 'menu items nest under their menu');
      Check((Title.FocusControl = NameEdit) and (Choices.PopupMenu = Popup) and (InitialControl = NameEdit),
        'component references are resolved');
      Check((OkButton.TabOrder = 0) and (NameEdit.TabOrder = 1) and (Box.TabOrder = 5),
        'tab order is applied sorted');
      Check((Box.Value = 7) and (Box.LoadingWhenSet = 1), 'values are assigned while csLoading');
      Check((Box.LoadedCalls = 1) and not Box.LoadingAfterLoaded and not (csLoading in ComponentState),
        'Loaded runs once and clears csLoading');
      Check((CreateCount = 1) and CreateSawComponents, 'OnCreate runs after the components are loaded');
      Check(Changes = 0, 'loading does not fire change events');
      OkButton.Click; SubItem.Click; NameEdit.Text := 'Changed';
      Check((Clicks = 2) and (Changes = 1), 'events reach the form''s methods');
      Check((ClientWidth = 300) and (ClientHeight = 160), 'ClientWidth and ClientHeight before the window exists');
      Show;
      GetClientRect(Handle, R);
      Check((R.Right = 300) and (R.Bottom = 160), 'the window gets the designed client size');
      Check(GetWindowLong(Handle, GWL_STYLE) and WS_DLGFRAME <> 0, 'BorderStyle is applied');
      ClientWidth := 280;
      GetClientRect(Handle, R);
      Check((R.Right = 280) and (ClientWidth = 280), 'ClientWidth resizes a live window');
    end;

    Second := TProbeForm.Create(Application);
    Check((Second.Name = 'ProbeForm_1') and (Second.NameEdit <> Probe.NameEdit),
      'a second instance gets a unique name and its own components');
    Second.Free;
    Check(DestroyCount = 1, 'OnDestroy runs when the form is freed');

    Derived := TDerivedProbe.Create(nil);
    Check((Derived.NameEdit <> nil) and (Derived.CreateCount = 1), 'a descendant uses its ancestor''s loader');
    Derived.Free;

    Raised := False;
    try Orphan := TOrphanForm.Create(nil); Orphan.Free;
    except on EResNotFound do Raised := True; end;
    Check(Raised, 'a form class without a loader raises EResNotFound');
    Plain := TForm.Create(nil);
    Check(Plain.ComponentCount = 0, 'TForm itself needs no resource');
    Plain.Free;
    Plain := TOrphanForm.CreateNew(nil);
    Check(Plain.ComponentCount = 0, 'CreateNew needs no resource');
    Plain.Free;
    Raised := False;
    try RegisterFormLoader(TProbeForm, NoComponents);
    except on EComponentError do Raised := True; end;
    Check(Raised, 'a class cannot get two loaders');

    Probe.Free;
    Check(DestroyCount = 3, 'each loaded form calls OnDestroy');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.ClassName + ' ' + E.Message); end; end;
  if Application.WindowCallbackErrors <> 0 then
    LogLine('FAIL callback ' + Application.LastWindowCallbackError);
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
