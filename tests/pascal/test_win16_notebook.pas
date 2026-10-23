program TestWin16Notebook;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Classes, SysUtils, Controls, native_notebook, native_header, native_edit;
type
  TObserver = class
    Changes, Sizing, Sized, LastSection, LastWidth: Integer;
    procedure Changed(Sender: TObject);
    procedure OnSizing(Sender: TObject; ASection, AWidth: Integer);
    procedure OnSized(Sender: TObject; ASection, AWidth: Integer);
  end;
var Root: TCustomControl; Book: TNotebook; Header: THeader; Edit: TEdit; Observer: TObserver;
  Failed, Rejected: Boolean; I, PoolUser: Integer; Page: TPage;
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
procedure TObserver.OnSizing(Sender: TObject; ASection, AWidth: Integer);
begin Inc(Sizing); LastSection := ASection; LastWidth := AWidth; end;
procedure TObserver.OnSized(Sender: TObject; ASection, AWidth: Integer);
begin Inc(Sized); LastSection := ASection; LastWidth := AWidth; end;
function PageShown(Index: Integer): Boolean;
var P: TPage;
begin
  P := TPage(Book.Pages.Objects[Index]);
  Result := (P.Handle <> 0) and IsWindowVisible(P.Handle);
end;
procedure Mouse(Msg: Word; X: Integer);
begin Header.Perform(Msg, MK_LBUTTON, MakeLong(X, 5)); end;
begin
  LogLine('STEP notebook and header');
  Observer := TObserver.Create;
  try
    Root := TCustomControl.Create(nil);
    Root.CreateHandle(0, 'Notebook parent', WS_POPUP or WS_VISIBLE or WS_CLIPCHILDREN, 10, 10, 400, 260);
    Book := TNotebook.Create(nil);
    Check((Book.Pages.Count = 1) and (Book.ActivePage = 'Default'), 'Delphi default page');
    Book.Pages.Clear; Book.Pages.Add('General'); Book.Pages.Add('Advanced'); Book.Pages.Add('Help');
    Book.OnPageChanged := Observer.Changed;
    Book.SetBounds(5, 40, 300, 150); Book.Parent := Root;
    Edit := TEdit.Create(nil); Edit.SetBounds(10, 10, 100, 20);
    Edit.Parent := TPage(Book.Pages.Objects[1]); Edit.Text := 'kept';
    Check((Book.PageIndex = 0) and PageShown(0) and not PageShown(1) and not PageShown(2),
      'only the active page is visible');
    Page := TPage(Book.Pages.Objects[0]);
    Check((Page.Width = Book.ClientWidth) and (Page.Height = Book.ClientHeight) and
      (Page.Caption = 'General'), 'page fills the notebook');
    Book.PageIndex := 1;
    Check(PageShown(1) and not PageShown(0) and (Observer.Changes = 1) and
      (Book.ActivePage = 'Advanced') and IsWindowVisible(Edit.Handle), 'switch page');
    Book.ActivePage := 'help';
    Check((Book.PageIndex = 2) and (Observer.Changes = 2), 'ActivePage by caption');
    Book.ActivePage := 'missing';
    Check(Book.PageIndex = 2, 'unknown caption ignored');
    { Calmira frees inactive page handles; showing the page rebuilds its children. }
    Edit.Text := 'kept';
    TPage(Book.Pages.Objects[1]).DestroyHandle;
    Check((TPage(Book.Pages.Objects[1]).Handle = 0) and (Edit.Handle = 0), 'inactive page handle freed');
    Book.PageIndex := 1;
    Check(PageShown(1) and (Edit.Handle <> 0) and IsWindowVisible(Edit.Handle) and (Edit.Text = 'kept'),
      'page and children recreated');
    Book.SetBounds(5, 40, 340, 180);
    Check((TPage(Book.Pages.Objects[1]).Width = Book.ClientWidth) and
      (TPage(Book.Pages.Objects[2]).Height = Book.ClientHeight), 'resize fits all pages');
    Book.Pages.Delete(0);
    Check((Book.Pages.Count = 2) and (Book.PageIndex = 0) and (Book.ActivePage = 'Advanced') and PageShown(0),
      'deleting an earlier page keeps the active page');
    Rejected := False;
    try Book.PageIndex := 5; except on Exception do Rejected := True; end;
    Check(Rejected and (Book.PageIndex = 0), 'page index out of range');

    Header := THeader.Create(nil); Header.SetBounds(5, 5, 300, 20);
    Header.OnSizing := Observer.OnSizing; Header.OnSized := Observer.OnSized;
    Header.Sections.Add('Name'); Header.Sections.Add('Size');
    Header.SectionWidth[Header.Sections.Add('Type')] := 50;
    Header.Parent := Root;
    Check((Header.SectionWidth[0] = 64) and (Header.SectionWidth[2] = 50), 'default and explicit widths');
    Header.SectionWidth[0] := 100;
    Header.MouseCapture := False;
    Mouse(WM_MOUSEMOVE, 100);
    Check(Header.Cursor = crSizeWE, 'divider cursor');
    Mouse(WM_MOUSEMOVE, 40);
    Check(Header.Cursor = crDefault, 'normal cursor between dividers');
    Mouse(WM_LBUTTONDOWN, 101); Mouse(WM_MOUSEMOVE, 130); Mouse(WM_MOUSEMOVE, 140);
    Check((Header.SectionWidth[0] = 140) and (Observer.Sizing = 2) and (Observer.Sized = 0) and
      Header.MouseCapture, 'drag resizes live');
    Mouse(WM_MOUSEMOVE, 2);
    Check(Header.SectionWidth[0] = 8, 'minimum width');
    Mouse(WM_LBUTTONUP, 2);
    Check((Observer.Sized = 1) and (Observer.LastSection = 0) and (Observer.LastWidth = 8) and
      not Header.MouseCapture, 'release reports sized once');
    Header.AllowResize := False; Observer.Sizing := 0;
    Mouse(WM_LBUTTONDOWN, 8); Mouse(WM_MOUSEMOVE, 60); Mouse(WM_LBUTTONUP, 60);
    Check((Header.SectionWidth[0] = 8) and (Observer.Sizing = 0), 'AllowResize false');
    Rejected := False;
    try Header.SectionWidth[3] := 1; except on Exception do Rejected := True; end;
    Check(Rejected, 'section index out of range');
    PoolUser := GetFreeSystemResources(GFSR_USERRESOURCES);
    for I := 1 to 20 do begin Book.PageIndex := 1 - Book.PageIndex; TPage(Book.Pages.Objects[1 - Book.PageIndex]).DestroyHandle; end;
    Check(GetFreeSystemResources(GFSR_USERRESOURCES) >= PoolUser - 2, 'page handle cycling resource stability');
    Check((Root.CallbackErrors = 0) and (Header.CallbackErrors = 0) and (Book.CallbackErrors = 0), 'no native callback errors');
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  Edit.Free; Book.Free; Header.Free; Root.Free; Observer.Free;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
