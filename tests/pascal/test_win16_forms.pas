program FormsTest;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, Win31, Messages, Classes, SysUtils, Graphics, Controls, Forms, StdCtrls, Buttons, Menus,
  native_form, native_window, native_application;
type
  TMainForm = class(TForm)
  protected
    procedure DoShow; override;
  public
    procedure UtilityProc(var Message: TMessage);
  end;
  TChildForm = class(TForm)
  public
    FreeMode: Boolean;
    Filled: TEdit; FilledCombo: TComboBox;
    Shows, Hides, Shortcuts: Integer;
    destructor Destroy; override;
    procedure CloseHandler(Sender: TObject; var Action: TCloseAction);
    procedure ModalShow(Sender: TObject);
    procedure DarkenShow(Sender: TObject);
    procedure FillShow(Sender: TObject);
    procedure CountShow(Sender: TObject);
    procedure CountHide(Sender: TObject);
    procedure CountShortcut(Sender: TObject);
    procedure EnableOthersHide(Sender: TObject);
    procedure WMBoom(var M: TMessage); message WM_USER + 77;
    procedure Caught(Sender: TObject; E: Exception);
    procedure MinimizeHandler(Sender: TObject; var Action: TCloseAction);
    procedure Filter(var Msg: TMsg; var Handled: Boolean);
  end;
  { Unowned, as Calmira's taskbar: WndParent := GetDesktopWindow. }
  TDesktopForm = class(TForm)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;
  TActiveProbe = class(TBitBtn)
  public
    property Active;
  end;
  TTeardownProbe = class(TComponent)
  public
    destructor Destroy; override;
  end;
var MainForm: TMainForm; Child, Modal, Loose: TChildForm; Foreign: TNativeForm;
  Freed, Rejected, Failed, ShownMain, TaskDisabled: Boolean; Count, ModalCode, Filtered, Utility: Integer; UtilityHandle: HWND;
{$I win16_stack_guard.inc}
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
procedure TMainForm.UtilityProc(var Message: TMessage);
begin
  if Message.Msg = WM_USER + 5 then
  begin Inc(Utility); Message.Result := Message.WParam * 7; end
  else Message.Result := DefWindowProc(UtilityHandle, Message.Msg, Message.WParam, Message.LParam);
end;
procedure TMainForm.DoShow;
begin
  inherited DoShow; ShownMain := True;
  PostMessage(Handle, WM_CLOSE, 0, 0);
end;
destructor TChildForm.Destroy;
begin
  Freed := True;
  if Self = Child then Child := nil;
  if Self = Modal then Modal := nil;
  if Self = Loose then Loose := nil;
  inherited Destroy;
end;
procedure TChildForm.CloseHandler(Sender: TObject; var Action: TCloseAction);
begin
  if FreeMode then Action := caFree;
end;
procedure TChildForm.MinimizeHandler(Sender: TObject; var Action: TCloseAction);
begin
  Action := caMinimize;
end;
procedure TChildForm.Filter(var Msg: TMsg; var Handled: Boolean);
begin
  if (Msg.hwnd = Handle) and (Msg.message = WM_CLOSE) then
  begin Inc(Filtered); Handled := True; end;
end;
procedure TDesktopForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.WndParent := GetDesktopWindow;
end;
{ As Calmira's shut-down dialog: OnShow darkens the whole screen. }
var CaughtText: string;
procedure TChildForm.WMBoom(var M: TMessage);
begin raise Exception.Create('Folder not found'); end;
procedure TChildForm.Caught(Sender: TObject; E: Exception);
begin CaughtText := E.Message; end;
{ Calmira reports an empty floppy drive by raising EScanError while a
  double-click is handled. As Delphi's MainWndProc, the exception goes to
  Application.HandleException and so to Calmira's OnException. }
function HandlerExceptionsReachApplication: Boolean;
var Form: TChildForm;
begin
  Form := TChildForm.Create(nil); Form.SetBounds(60, 60, 120, 80);
  CaughtText := ''; Application.OnException := Form.Caught;
  try
    SendMessage(Form.Handle, WM_USER + 77, 0, 0);
    Result := (CaughtText = 'Folder not found') and (Form.CallbackErrors = 0);
  finally Application.OnException := nil; Form.Free; end;
end;
procedure TChildForm.CountShow(Sender: TObject);
begin Inc(Shows); end;
procedure TChildForm.CountHide(Sender: TObject);
begin Inc(Hides); end;
procedure TChildForm.FillShow(Sender: TObject);
begin
  if Filled <> nil then Filled.Text := 'c:\calmira\calmira.exe';
  if FilledCombo <> nil then FilledCombo.Text := 'c:\calmira\calmira.exe';
end;
procedure TChildForm.DarkenShow(Sender: TObject);
var DC: HDC;
begin
  DC := GetDC(0); PatBlt(DC, 0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), BLACKNESS);
  ReleaseDC(0, DC);
end;
procedure TChildForm.ModalShow(Sender: TObject);
begin
  TaskDisabled := (Loose <> nil) and not IsWindowEnabled(Loose.Handle) and
    not IsWindowEnabled(Application.Handle) and IsWindowEnabled(Handle);
  ModalResult := mrOk;
end;
destructor TTeardownProbe.Destroy;
begin
  { Runs from the Forms finalization, after RESULT has been written; a FAIL
    line here still fails the native runner. }
  Check(Application.ShuttingDown and (Application.PendingReleases = nil),
    'finalization frees the global application and its owned components');
  inherited Destroy;
end;
procedure Globals;
begin
  Check((Application <> nil) and Application.Initialized and
    (Application.TaskHandle = GetCurrentTask), 'global application is initialized for this task');
  Check((Screen <> nil) and (Screen.Application = Application) and (Screen.FormCount = 0),
    'global screen is bound to the application without forms');
  Check(Application.MainForm = nil, 'no implicit main form');
  Application.Initialize;
  Check(Application.Initialized, 'repeated Initialize is accepted');
  Check((caNone = ncaNone) and (caHide = ncaHide), 'close actions share native values');
end;
{ These forms have no DFM; Create needs a registered loader, as Delphi
  needs a resource. }
procedure NoComponents(Form: TForm);
begin end;
procedure Creation;
begin
  RegisterFormLoader(TMainForm, NoComponents);
  RegisterFormLoader(TChildForm, NoComponents);
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TChildForm, Child);
  Check((Application.MainForm = MainForm) and (MainForm.Owner = Application) and
    (Child.Owner = Application), 'CreateForm publishes typed main form and application owner');
  MainForm.SetBounds(20, 20, 200, 120); Child.SetBounds(240, 20, 200, 120);
  Check((Screen.FormCount = 2) and (Screen.Forms[0] is TMainForm) and (Screen.Forms[1] is TChildForm),
    'typed screen forms before native handles');
  Child.Show; BringWindowToTop(Child.Handle); SetActiveWindow(Child.Handle);
  Check((Screen.ActiveForm = Child) and (Screen.Forms[0] = Child), 'typed active form follows USER');
end;
procedure ForeignForms;
begin
  Foreign := TNativeForm.Create(nil);
  Application.RegisterForm(Foreign);
  Foreign.SetBounds(60, 160, 160, 100); Foreign.Show;
  BringWindowToTop(Foreign.Handle); SetActiveWindow(Foreign.Handle);
  Check(Screen.ActiveForm = nil, 'foreign active native form reads as no TForm');
  Rejected := False;
  try if Screen.Forms[0] <> nil then ; except on Exception do Rejected := True; end;
  Check(Rejected, 'foreign form index is rejected rather than cast');
  Foreign.Free; Foreign := nil;
  Check(Screen.FormCount = 2, 'freed foreign form leaves the registry');
end;
procedure CloseFree;
begin
  Child.OnClose := Child.CloseHandler; Child.FreeMode := True; Freed := False;
  BringWindowToTop(Child.Handle); SetActiveWindow(Child.Handle);
  Child.Close;
  Check((Child <> nil) and not Freed and not Child.Visible and
    (Application.PendingReleases.Count = 1), 'caFree hides now and defers the free');
  Application.ProcessMessages;
  Check(Freed and (Child = nil) and (Application.PendingReleases.Count = 0) and
    (Screen.FormCount = 1), 'queued release frees the form outside its dispatch');
end;
procedure ReleaseEdges;
begin
  Loose := TChildForm.Create(nil); Loose.SetBounds(240, 160, 160, 100); Loose.Show;
  Freed := False; Loose.Release; Loose.Release;
  Check(Application.PendingReleases.Count = 1, 'repeated Release queues one free');
  Application.ProcessMessages;
  Check(Freed and (Loose = nil), 'unowned released form is freed');
  Loose := TChildForm.Create(nil); Freed := False; Loose.Release; Loose.Free;
  Check(Freed and (Loose = nil) and (Application.PendingReleases.Count = 0),
    'explicit free cancels the pending release');
  Application.ProcessMessages;
  Check(Application.PendingReleases.Count = 0, 'stale release message is harmless');
  Rejected := False;
  try Application.QueueRelease(nil); except on ENativeApplicationError do Rejected := True; end;
  Check(Rejected, 'nil release rejected');
end;
procedure MinimizeAndFilter;
begin
  Loose := TChildForm.Create(nil); Loose.SetBounds(240, 160, 160, 100); Loose.Show;
  Loose.OnClose := Loose.MinimizeHandler; Freed := False;
  Loose.Close;
  Check(Loose.Visible and IsIconic(Loose.Handle) and (Loose.WindowState = wsMinimized) and
    not Freed and (Application.PendingReleases.Count = 0), 'caMinimize minimizes instead of closing');
  Loose.WindowState := wsNormal; Loose.OnClose := nil; Filtered := 0;
  Application.OnMessage := Loose.Filter;
  PostMessage(Loose.Handle, WM_CLOSE, 0, 0); Application.ProcessMessages;
  Check((Filtered = 1) and Loose.Visible, 'Delphi 1 OnMessage sees the message and Handled stops it');
  Application.OnMessage := nil;
  PostMessage(Loose.Handle, WM_CLOSE, 0, 0); Application.ProcessMessages;
  Check((Filtered = 1) and not Loose.Visible, 'clearing OnMessage restores dispatch');
  Loose.Free;
end;
procedure FrameProperties;
var Style: LongInt; R: TRect;
begin
  Check(not NewStyleControls, 'NewStyleControls is False on Windows 3.1');
  Loose := TChildForm.Create(nil);
  Check((Loose.BorderStyle = bsSizeable) and (Loose.BorderIcons = [biSystemMenu, biMinimize, biMaximize]) and
    (Loose.Position = poDesigned) and (Loose.FormStyle = fsNormal), 'Delphi 1 frame defaults');
  Loose.BorderStyle := bsDialog; Loose.Position := poScreenCenter; Loose.FormStyle := fsStayOnTop;
  Loose.SetBounds(0, 0, 200, 100); Loose.Show;
  Style := GetWindowLong(Loose.Handle, GWL_STYLE);
  GetWindowRect(Loose.Handle, R);
  Check((Style and WS_DLGFRAME <> 0) and (Style and WS_THICKFRAME = 0) and (Style and WS_SYSMENU <> 0) and
    (Style and (WS_MINIMIZEBOX or WS_MAXIMIZEBOX) = 0), 'bsDialog keeps only the system menu');
  Check(Abs(R.Left - (GetSystemMetrics(SM_CXSCREEN) - 200) div 2) <= 1, 'poScreenCenter');
  Check(GetWindowLong(Loose.Handle, GWL_EXSTYLE) and WS_EX_TOPMOST <> 0, 'fsStayOnTop');
  Rejected := False;
  try Loose.BorderStyle := bsSingle; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected and (Loose.BorderStyle = bsDialog), 'live frame change is rejected');
  Loose.FormStyle := fsNormal;
  Check(GetWindowLong(Loose.Handle, GWL_EXSTYLE) and WS_EX_TOPMOST = 0, 'fsNormal clears topmost live');
  Loose.Free;
  Loose := TChildForm.Create(nil);
  Loose.BorderStyle := bsNone; Loose.SetBounds(10, 10, 80, 60); Loose.Show;
  Style := GetWindowLong(Loose.Handle, GWL_STYLE);
  Check((Style and WS_CAPTION = 0) and (Style and WS_THICKFRAME = 0), 'bsNone has no frame');
  Loose.Free;
  Rejected := False;
  try TForm(Application.MainForm).FormStyle := fsMDIChild; except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'MDI styles are rejected');
end;
procedure MinimizedIcon;
begin
  Check(Application.Icon.Empty, 'Application.Icon is empty without a MAINICON resource');
  Loose := TChildForm.Create(nil); Loose.SetBounds(30, 30, 160, 100);
  Loose.Icon.CopyFromHandle(LoadIcon(0, IDI_HAND));
  Loose.Show; Loose.WindowState := wsMinimized; UpdateWindow(Loose.Handle);
  Check(IsIconic(Loose.Handle) and
    (HICON(SendMessage(Loose.Handle, WM_QUERYDRAGICON, 0, 0)) = Loose.Icon.Handle),
    'a minimized form drags and draws its Icon');
  Loose.Icon.Clear; UpdateWindow(Loose.Handle);
  Check(HICON(SendMessage(Loose.Handle, WM_QUERYDRAGICON, 0, 0)) = LoadIcon(0, IDI_APPLICATION),
    'without icons the stock application icon is used');
  Check(Loose.CallbackErrors = 0, 'iconic painting raised nothing');
  Loose.Free;
end;
{ Calmira's TExtForm.StretchShift moves controls through TControl, and sizes
  them by the client size read in Loaded, before the window exists. }
procedure DelphiBounds;
var Area: TRect; W, H: Integer; Button: TButton; Text: TLabel; C: TControl;
begin
  Loose := TChildForm.Create(nil); Loose.SetBounds(20, 20, 240, 160);
  W := Loose.ClientWidth; H := Loose.ClientHeight;
  Check(not Loose.HandleAllocated, 'client size read without creating the window');
  Area := Rect(0, 0, 0, 0); AdjustWindowRect(Area, WS_OVERLAPPEDWINDOW, False);
  Check((W = 240 - (Area.Right - Area.Left)) and (H = 160 - (Area.Bottom - Area.Top)),
    'client size without a window is net of the frame, as Delphi');
  Loose.Handle;
  Check((Loose.ClientWidth = W) and (Loose.ClientHeight = H), 'client size unchanged by creating the window');
  Button := TButton.Create(Loose); Button.Parent := Loose;
  Text := TLabel.Create(Loose); Text.Parent := Loose;
  C := Button; C.SetBounds(5, 6, 70, 20);
  Check((Button.Left = 5) and (Button.Top = 6) and (Button.Width = 70) and (Button.Height = 20) and
    (C.Width = 70), 'TControl.SetBounds and bounds properties reach a windowed control');
  C.Width := 80; C.Top := 9;
  Check((Button.Width = 80) and (Button.Top = 9) and (Loose.Width = 240), 'TControl bounds do not touch the form');
  C := Text; C.SetBounds(3, 40, 50, 13); C.Left := 4;
  Check((Text.Left = 4) and (Text.Top = 40) and (Text.Width = 50) and (C.Height = 13),
    'TControl bounds reach a graphic control');
  Loose.Free;
  Loose := TChildForm.Create(nil); Loose.SetBounds(20, 20, 240, 160);
  Loose.WindowState := wsMinimized;
  ShowWindow(Loose.Handle, SW_SHOWNORMAL);
  Check(Loose.WindowState = wsNormal, 'a pending state yields to the shown window state');
  Loose.Free;
  Loose := TChildForm.Create(nil); Loose.SetBounds(40, 40, 200, 120);
  SetActiveWindow(Application.MainForm.Handle);
  Loose.Show;
  Check(GetActiveWindow = Loose.Handle, 'Show activates a normal form, as Delphi''s SW_SHOWNORMAL');
  Loose.Free;
end;
{ Delphi behaviour Calmira's forms rely on in OnCreate and for desktop icons. }
procedure DelphiWindows;
var Wnd: HWND; R: TRect;
begin
  Loose := TChildForm.Create(nil); Loose.SetBounds(20, 20, 150, 90);
  Check(not Loose.HandleAllocated, 'a new form has no window yet');
  Wnd := Loose.Handle;
  Check((Wnd <> 0) and Loose.HandleAllocated and IsWindow(Wnd) and not IsWindowVisible(Wnd) and
    not Loose.Visible, 'reading Handle creates the hidden window, as in Delphi');
  Loose.Show;
  Check((Loose.Handle = Wnd) and IsWindowVisible(Wnd), 'Show uses the window Handle created');
  Loose.WindowState := wsMinimized; Loose.Visible := True;
  Check(IsIconic(Wnd) and IsWindowVisible(Wnd), 'showing a visible icon again keeps it minimized');
  Loose.Free;
  Loose := TChildForm.Create(nil); Loose.Position := poDefault; Loose.SetBounds(0, 0, 10, 10);
  Loose.Show; GetWindowRect(Loose.Handle, R);
  Check(IsWindowVisible(Loose.Handle) and (R.Right - R.Left > 10) and (Loose.Width = R.Right - R.Left),
    'poDefault lets USER place and size the window');
  Loose.Free;
  Loose := TChildForm.Create(nil); Loose.Position := poDefault; Loose.BorderStyle := bsNone;
  Loose.SetBounds(0, 0, 150, 30); Loose.Show; GetWindowRect(Loose.Handle, R);
  Check((R.Right - R.Left = 150) and (R.Bottom - R.Top = 30), 'poDefault keeps the size of an unsizeable form');
  Loose.Free;
  Loose := TChildForm.Create(nil); Loose.Position := poDefaultPosOnly; Loose.SetBounds(0, 0, 150, 90);
  Loose.Show; GetWindowRect(Loose.Handle, R);
  Check((R.Right - R.Left = 150) and (R.Bottom - R.Top = 90), 'poDefaultPosOnly keeps the size');
  Loose.Free;
end;
{ Calmira's Select Icon puts the file name into its combo box in OnShow;
  Delphi enters the focused control afterwards, so the text is selected. }
function ShowSelects(UseCombo: Boolean): Boolean;
var Sel: LongInt; Form: TChildForm;
begin
  Form := TChildForm.Create(nil); Form.SetBounds(60, 60, 220, 100);
  if UseCombo then
  begin
    Form.FilledCombo := TComboBox.Create(Form); Form.FilledCombo.SetBounds(8, 8, 180, 21);
    Form.FilledCombo.Parent := Form;
  end
  else
  begin
    Form.Filled := TEdit.Create(Form); Form.Filled.SetBounds(8, 8, 180, 21); Form.Filled.Parent := Form;
  end;
  Form.OnShow := Form.FillShow; Form.Show; Application.ProcessMessages;
  if UseCombo then Sel := Form.FilledCombo.Perform(CB_GETEDITSEL, 0, 0)
  else Sel := Form.Filled.Perform(EM_GETSEL, 0, 0);
  Result := (LoWord(Sel) = 0) and (HiWord(Sel) = 22);
  Form.Free;
end;
{ As Delphi's CMShowingChanged: Calmira's taskbar is shown by its DFM's
  Visible = True and makes its system-menu helper window in OnShow. }
function VisibleShowsAndHides: Boolean;
var Form: TChildForm;
begin
  Form := TChildForm.Create(nil); Form.SetBounds(60, 60, 200, 100);
  Form.OnShow := Form.CountShow; Form.OnHide := Form.CountHide;
  Form.Visible := True; Application.ProcessMessages;
  Result := (Form.Shows = 1) and IsWindowVisible(Form.Handle);
  Form.Visible := True;
  Result := Result and (Form.Shows = 1) and (Form.Hides = 0);
  Form.Visible := False;
  Result := Result and (Form.Hides = 1) and not IsWindowVisible(Form.Handle);
  Form.Visible := False;
  Result := Result and (Form.Hides = 1) and (Form.Shows = 1);
  Form.Free;
end;
procedure TChildForm.CountShortcut(Sender: TObject);
begin Inc(Shortcuts); end;
var HideBelow: TChildForm;
procedure TChildForm.EnableOthersHide(Sender: TObject);
begin if HideBelow <> nil then EnableWindow(HideBelow.Handle, True); end;
{ As Delphi's CMShowingChanged: OnHide runs first, then the topmost other
  window is activated. Calmira's progress box disables the other forms while
  shown and enables them in OnHide; the folder below must become active. }
function HideActivatesTopmost: Boolean;
var Top: TChildForm;
begin
  HideBelow := TChildForm.Create(nil); HideBelow.SetBounds(40, 40, 200, 100);
  HideBelow.Show; Application.ProcessMessages;
  Top := TChildForm.Create(nil); Top.SetBounds(80, 80, 200, 100);
  Top.OnHide := Top.EnableOthersHide;
  Top.Show; SetActiveWindow(Top.Handle); EnableWindow(HideBelow.Handle, False);
  Application.ProcessMessages;
  Top.Hide;
  Result := GetActiveWindow = HideBelow.Handle;
  Application.ProcessMessages;
  Result := Result and (GetActiveWindow = HideBelow.Handle);
  Top.Free; HideBelow.Free; HideBelow := nil;
end;
{ As Delphi's key handling: Calmira's folder and Explorer windows are made
  with Create, and Del or F2 in their file pane are File menu shortcuts. }
function ShortcutReachesCreatedForm: Boolean;
var Form: TChildForm; Edit: TEdit; Item: TMenuItem; Popup: TPopupMenu;
begin
  Form := TChildForm.Create(nil); Form.SetBounds(60, 60, 200, 120);
  Item := NewItem('&Delete', ShortCut(VK_DELETE, []), False, True, Form.CountShortcut, 0, 'DeleteItem');
  Form.Menu := NewMenu(Form, 'Bar', [NewSubMenu('&File', 0, 'FileItem', [Item])]);
  Edit := TEdit.Create(Form); Edit.SetBounds(8, 8, 100, 24); Edit.Parent := Form;
  { Delphi's IsMenuKey asks the focused control's pop-up menu first. }
  Popup := NewPopupMenu(Form, 'Popup', paLeft, False,
    [NewItem('&Rename', ShortCut(VK_F2, []), False, True, Form.CountShortcut, 0, 'RenameItem')]);
  Edit.PopupMenu := Popup;
  Form.Show; Edit.SetFocus; Application.ProcessMessages;
  PostMessage(Edit.Handle, WM_KEYDOWN, VK_DELETE, 1); Application.ProcessMessages;
  Result := Form.Shortcuts = 1;
  PostMessage(Edit.Handle, WM_KEYDOWN, VK_F2, 1); Application.ProcessMessages;
  Result := Result and (Form.Shortcuts = 2);
  Form.Free;
end;
{ Calmira's desktop icons are minimized forms; uncovering one erases it
  like a client area, as Delphi's TWinControl.WMEraseBkgnd does. }
function IconErasesWithColor: Boolean;
var Form: TChildForm; DC: HDC; Black: HBRUSH; Area: TRect;
begin
  Form := TChildForm.Create(nil); Form.SetBounds(60, 60, 200, 100);
  Form.Color := clRed; Form.Show; Application.ProcessMessages;
  ShowWindow(Form.Handle, SW_SHOWMINNOACTIVE); Application.ProcessMessages;
  DC := GetDC(Form.Handle);
  Black := GetStockObject(BLACK_BRUSH); SetRect(Area, 0, 0, 8, 8);
  FillRect(DC, Area, Black);
  Result := IsIconic(Form.Handle) and (Form.Perform(WM_ERASEBKGND, DC, 0) <> 0) and
    (GetPixel(DC, 2, 2) = ColorToRGB(clRed));
  ReleaseDC(Form.Handle, DC);
  Form.Free;
end;
{ As Delphi's Screen: Calmira creates its folder windows with Create, not
  CreateForm, and cascades a new one from Screen.ActiveForm. }
function ScreenListsEveryForm: Boolean;
var Form: TChildForm; I, Before: Integer; Listed: Boolean;
begin
  Before := Screen.FormCount;
  Form := TChildForm.Create(nil); Form.SetBounds(60, 60, 200, 100);
  Form.Show; SetActiveWindow(Form.Handle); Application.ProcessMessages;
  Listed := False;
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I] = Form then Listed := True;
  Result := Listed and (Screen.FormCount = Before + 1) and (Screen.ActiveForm = Form);
  Form.Free;
  Result := Result and (Screen.FormCount = Before);
end;
procedure ShowOverPaint;
var Button: TButton; DC: HDC; Face, Caption: TColorRef;
begin
  Loose := TChildForm.Create(nil); Loose.SetBounds(60, 60, 200, 100);
  Button := TButton.Create(Loose); Button.SetBounds(8, 8, 75, 23); Button.Parent := Loose;
  Loose.OnShow := Loose.DarkenShow; Loose.Show; Application.ProcessMessages;
  DC := GetDC(Button.Handle); Face := GetPixel(DC, 4, 4); ReleaseDC(Button.Handle, DC);
  DC := GetWindowDC(Loose.Handle);
  Caption := GetPixel(DC, 30, GetSystemMetrics(SM_CYFRAME) + 2); ReleaseDC(Loose.Handle, DC);
  Check((Face = DWORD(ColorToRGB(clBtnFace))) and (Caption <> 0),
    'what OnShow draws over the screen is painted over by the frame and children');
  Loose.Free;
end;
{ Delphi 1: the visible, zero-sized TApplication window in the middle of the
  screen owns every form; each form class is a window class of its name. }
procedure WindowHierarchy;
var App: HWND; R: TRect; Name: array[0..31] of Char; Desk: TDesktopForm; Other: TChildForm;
begin
  App := Application.Handle; GetWindowRect(App, R);
  Check(IsWindowVisible(App) and (R.Left = GetSystemMetrics(SM_CXSCREEN) div 2) and
    (R.Top = GetSystemMetrics(SM_CYSCREEN) div 2) and (R.Right = R.Left) and (R.Bottom = R.Top),
    'the application window is visible and zero-sized in the middle of the screen');
  Loose := TChildForm.Create(nil);
  Check((GetWindow(Loose.Handle, GW_OWNER) = App) and (GetParent(Loose.Handle) = 0) and
    (GetWindowLong(Loose.Handle, GWL_STYLE) and WS_POPUP = 0),
    'a form is an overlapped window owned by the application window, as in the original');
  GetClassName(Loose.Handle, Name, SizeOf(Name));
  Check(StrComp(Name, 'TChildForm') = 0, 'the window class is the form class name');
  Other := TChildForm.Create(nil);
  GetClassName(Other.Handle, Name, SizeOf(Name));
  Check(StrComp(Name, 'TChildForm') = 0, 'a second form of the class shares its window class');
  Other.Free;
  Loose.SetBounds(30, 40, 150, 90); Loose.Show;
  Check((Loose.Left = 30) and (Loose.Top = 40), 'an owned form keeps screen coordinates');
  SetActiveWindow(Loose.Handle); SetActiveWindow(App);
  Application.ProcessMessages;
  Check(GetActiveWindow = Loose.Handle, 'the focused application window hands the focus on to its top form');
  Loose.Free;
  RegisterFormLoader(TDesktopForm, NoComponents);
  Desk := TDesktopForm.Create(nil);
  GetClassName(Desk.Handle, Name, SizeOf(Name));
  Check((GetParent(Desk.Handle) = 0) and (StrComp(Name, 'TDesktopForm') = 0),
    'WndParent := GetDesktopWindow leaves a form unowned, as Calmira''s taskbar');
  Desk.Free;
end;
{ Calmira's buttons are bsNew TBitBtns; its Buttons.dcu drew them as Win95
  buttons, and the active one (focused, or Default) bold. }
procedure DefaultButtons;
var First, Second: TActiveProbe; Edit: TEdit; DC: HDC; Outer, Inner, Corner: TColorRef;
begin
  Loose := TChildForm.Create(nil); Loose.SetBounds(40, 40, 260, 120);
  First := TActiveProbe.Create(Loose); First.Parent := Loose; First.SetBounds(10, 10, 100, 25);
  First.Style := bsNew; First.Caption := 'First'; First.TabOrder := 0;
  Second := TActiveProbe.Create(Loose); Second.Parent := Loose; Second.SetBounds(120, 10, 100, 25);
  Second.Style := bsNew; Second.Caption := 'Second'; Second.Default := True;
  Edit := TEdit.Create(Loose); Edit.Parent := Loose; Edit.SetBounds(10, 50, 100, 22);
  Loose.Show; SetActiveWindow(Loose.Handle); UpdateWindow(Loose.Handle);
  Check(First.Focused, 'an activated form without ActiveControl focuses its first tab stop, as in Delphi');
  Check(First.Active and not Second.Active, 'the focused button is the active one');
  Edit.SetFocus; UpdateWindow(Loose.Handle);
  Check(Second.Active and not First.Active, 'with focus off the buttons, the Default button is active');
  SetActiveWindow(GetDesktopWindow); SetActiveWindow(Loose.Handle);
  Check(Edit.Focused, 'reactivation restores the last focused control, as in Delphi');
  DC := GetDC(First.Handle);
  Outer := GetPixel(DC, 99, 24); Inner := GetPixel(DC, 98, 23); Corner := GetPixel(DC, 0, 0);
  ReleaseDC(First.Handle, DC);
  Check((Outer = ColorToRGB(clWindowFrame)) and (Inner = ColorToRGB(clBtnShadow)) and
    (Corner = ColorToRGB(clBtnShadow)), 'bsNew draws the Win95 frame of Calmira''s Buttons unit');
  First.SetFocus; UpdateWindow(Loose.Handle);
  DC := GetDC(First.Handle); Corner := GetPixel(DC, 4, 3); Inner := GetPixel(DC, 5, 3); ReleaseDC(First.Handle, DC);
  Check((Corner = 0) or (Inner = 0), 'the focus rectangle of a button is black dots on the face, as in Delphi');
  Loose.Free;
end;
procedure ParentForm;
var Panel: TCustomControl; Child: TCustomControl;
begin
  Loose := TChildForm.Create(nil);
  Panel := TCustomControl.Create(Loose); Panel.Parent := Loose;
  Child := TCustomControl.Create(Loose); Child.Parent := Panel;
  Check((GetParentForm(Child) = Loose) and (GetParentForm(Loose) = Loose) and (Loose.Designer = nil),
    'GetParentForm walks up to the form; no run-time designer');
  Child.Parent := nil;
  Check(GetParentForm(Child) = nil, 'an orphan control has no form');
  Loose.Free;
end;
procedure UtilityWindow;
var Wnd: HWND;
begin
  Utility := 0;
  Wnd := AllocateHWnd(MainForm.UtilityProc); UtilityHandle := Wnd;
  Check((Wnd <> 0) and IsWindow(Wnd) and not IsWindowVisible(Wnd), 'AllocateHWnd creates a hidden window');
  Check((SendMessage(Wnd, WM_USER + 5, 7, 0) = 49) and (Utility = 1), 'the method receives every message');
  Check(SendMessage(Wnd, WM_GETTEXTLENGTH, 0, 0) = 0, 'unhandled messages reach DefWindowProc');
  DeallocateHWnd(Wnd);
  Check(not IsWindow(Wnd), 'DeallocateHWnd destroys it');
  Rejected := False;
  try DeallocateHWnd(Wnd); except on ENativeWindowError do Rejected := True; end;
  Check(Rejected, 'unknown windows are rejected');
  Rejected := False;
  try DeallocateHWnd(0); except on Exception do Rejected := True; end;
  Check(not Rejected, 'DeallocateHWnd(0) is harmless, as Delphi (TExtForm.Destroy after a failed create)');
end;
procedure ModalFree;
begin
  Application.CreateForm(TChildForm, Modal);
  Modal.SetBounds(100, 100, 200, 120); Modal.OnShow := Modal.ModalShow;
  Modal.OnClose := Modal.CloseHandler; Modal.FreeMode := True; Freed := False;
  Loose := TChildForm.Create(nil); Loose.SetBounds(20, 20, 150, 90); Loose.Show; TaskDisabled := False;
  ModalCode := Modal.ShowModal;
  Check(TaskDisabled and IsWindowEnabled(Loose.Handle) and IsWindowEnabled(Application.Handle),
    'a modal form disables the task''s other windows while it runs, as Delphi''s DisableTaskWindows');
  Loose.Free; Freed := False;
  Check((ModalCode = mrOk) and not Freed and (Modal <> nil) and not Modal.Visible,
    'modal caFree returns the result before the deferred free');
  Application.ProcessMessages;
  Check(Freed and (Modal = nil) and (Screen.FormCount = 1), 'modal form freed by the next pump');
end;
procedure RunMain;
begin
  TTeardownProbe.Create(Application);
  ShownMain := False; Count := Application.Run;
  Check(ShownMain and Application.Terminated and (Count = 0) and (MainForm <> nil) and
    not MainForm.Visible, 'Run shows the main form and closing it ends the task loop');
end;
begin
  FillChar(StackBottom^, 64, $A5); LogLine('STEP global Forms layer');
  try Globals; Creation; ForeignForms; CloseFree; ReleaseEdges; MinimizeAndFilter; FrameProperties; MinimizedIcon; DelphiBounds; DelphiWindows; WindowHierarchy; ShowOverPaint;
    Check(ShowSelects(False) and ShowSelects(True), 'text OnShow puts into the focused edit or combo box is selected');
    Check(ScreenListsEveryForm, 'Screen lists and activates forms not made by CreateForm');
    Check(HideActivatesTopmost, 'hiding the active form activates the topmost window after OnHide');
    Check(IconErasesWithColor, 'a minimized form erases its icon area with Color');
    Check(ShortcutReachesCreatedForm, 'menu and pop-up shortcuts reach a form not made by CreateForm');
    Check(VisibleShowsAndHides, 'setting Visible shows and hides a form with OnShow and OnHide');
    Check(HandlerExceptionsReachApplication, 'an exception in a message handler reaches Application.OnException');
    DefaultButtons; ParentForm; UtilityWindow; ModalFree; RunMain;
  except on E: Exception do begin Failed := True; LogLine('FAIL ' + E.Message); end; end;
  Check(StackGuardIntact, 'forms stack boundary');
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
