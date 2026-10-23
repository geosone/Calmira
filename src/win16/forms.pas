{ SPDX-License-Identifier: GPL-2.0-or-later
  Initial Forms compatibility layer over the tested native application, screen
  and modal-form foundations. It supplies the global Application/Screen pair,
  typed TForm access and deferred Release; it is not the complete Delphi Forms
  unit. Runtime DFM streaming, menus, hints, Icon and form styles
  are absent and must fail to compile rather than be silently aliased. }
unit Forms;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Forms layer requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Messages, Graphics, Controls, control_base, native_form, native_modal,
  native_application, native_screen;
type
  TCloseAction = TNativeCloseAction;
  TCloseEvent = TNativeCloseEvent;
  TCloseQueryEvent = TNativeCloseQueryEvent;
  TWindowState = native_form.TWindowState;
  TMessageEvent = procedure(var Msg: TMsg; var Handled: Boolean) of object;
  TFormBorderStyle = control_base.TFormBorderStyle;
  TBorderStyle = control_base.TBorderStyle;
  TBorderIcon = (biSystemMenu, biMinimize, biMaximize);
  TBorderIcons = set of TBorderIcon;
  TPosition = (poDesigned, poDefault, poDefaultPosOnly, poDefaultSizeOnly, poScreenCenter);
  { MDI is not provided; fsMDIChild/fsMDIForm raise when the window is created. }
  TFormStyle = (fsNormal, fsMDIChild, fsMDIForm, fsStayOnTop);
  { Delphi's form designer interface; there is no designer at run time. }
  TDesigner = class
  public
    procedure Modified; virtual; abstract;
  end;
  TForm = class(TNativeModalForm)
  private
    FBorderStyle: TFormBorderStyle;
    FBorderIcons: TBorderIcons;
    FPosition: TPosition;
    FFormStyle: TFormStyle;
    FIcon: TIcon;
    procedure CheckFrameChange;
    procedure SetIcon(Value: TIcon);
    procedure IconChanged(Sender: TObject);
    function IconHandle: HICON;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMQueryDragIcon(var Message: TMessage); message WM_QUERYDRAGICON;
    procedure SetBorderStyle(Value: TFormBorderStyle);
    procedure SetBorderIcons(Value: TBorderIcons);
    procedure SetPosition(Value: TPosition);
    procedure SetFormStyle(Value: TFormStyle);
  protected
    procedure DoClose(var Action: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    { Drawn while minimized; an empty Icon falls back to Application.Icon. }
    property Icon: TIcon read FIcon write SetIcon;
    { Always nil: forms are never edited by a designer at run time. }
    function Designer: TDesigner;
    { The WS_* frame bits that BorderStyle and BorderIcons select. }
    function FrameStyle: DWORD;
    property BorderStyle: TFormBorderStyle read FBorderStyle write SetBorderStyle default bsSizeable;
    property BorderIcons: TBorderIcons read FBorderIcons write SetBorderIcons
      default [biSystemMenu, biMinimize, biMaximize];
    property Position: TPosition read FPosition write SetPosition default poDesigned;
    property FormStyle: TFormStyle read FFormStyle write SetFormStyle default fsNormal;
    { Deferred free through the application window, never inside this form's
      own dispatch. The caller must not touch the form after the next pump. }
    procedure Release;
  end;
  TFormClass = class of TForm;
  TApplication = class(TNativeApplication)
  private
    FReleases: TList;
    FReleaseHooked: Boolean;
    FOnMessage: TMessageEvent;
    FIcon: TIcon;
    procedure SetIcon(Value: TIcon);
    function ReleaseHook(var Message: TMessage): Boolean;
    procedure FreeReleases;
    function GetMainForm: TForm;
    procedure SetMainForm(Value: TForm);
    function MessageFilter(var Message: TMsg): Boolean;
    procedure SetOnMessage(Value: TMessageEvent);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure QueueRelease(Form: TForm);
    property MainForm: TForm read GetMainForm write SetMainForm;
    property PendingReleases: TList read FReleases;
    { Delphi 1 signature over the native Boolean filter. }
    property OnMessage: TMessageEvent read FOnMessage write SetOnMessage;
    { Delphi 1 loads the MAINICON resource; empty if the program has none. }
    property Icon: TIcon read FIcon write SetIcon;
  end;
  TScreen = class(TNativeScreen)
  private
    function GetForm(Index: Integer): TForm;
    function GetActiveForm: TForm;
  public
    { Registered forms that are not TForm descendants are rejected, not cast. }
    property Forms[Index: Integer]: TForm read GetForm;
    { A foreign active native form reads as nil, as no TForm is active. }
    property ActiveForm: TForm read GetActiveForm;
  end;
const
  caNone = ncaNone; caHide = ncaHide; caFree = ncaDestroy; caMinimize = ncaMinimize;
  wsNormal = native_form.wsNormal; wsMinimized = native_form.wsMinimized;
  wsMaximized = native_form.wsMaximized;
  bsNone = control_base.bsNone; bsSingle = control_base.bsSingle;
  bsSizeable = control_base.bsSizeable; bsDialog = control_base.bsDialog;
{ Delphi 1 utility windows: every message goes to Method, which calls
  DefWindowProc itself for anything it does not handle. }
type
  TWndMethod = procedure(var Message: TMessage) of object;
function AllocateHWnd(Method: TWndMethod): HWND;
procedure DeallocateHWnd(Wnd: HWND);
{ The TForm that (indirectly) contains Control, or nil. }
function GetParentForm(Control: TControl): TForm;
var
  Application: TApplication;
  Screen: TScreen;
implementation
uses WinProcs, native_window;
var ReleaseMessage: Word;
type
  TUtilityWindow = class(TNativeWindow)
  private
    FMethod: TWndMethod;
  protected
    procedure WndProc(var Message: TMessage); override;
  end;
var UtilityWindows: TList;
procedure TUtilityWindow.WndProc(var Message: TMessage);
begin
  { As in Delphi, creation messages go to DefWindowProc: the caller learns
    the handle only when AllocateHWnd returns. }
  if Assigned(FMethod) then FMethod(Message) else DefaultHandler(Message);
end;
function AllocateHWnd(Method: TWndMethod): HWND;
var Window: TUtilityWindow;
begin
  if not Assigned(Method) then raise ENativeWindowError.Create('AllocateHWnd needs a method');
  Window := TUtilityWindow.Create(nil);
  try
    Window.CreateHandle(0, '', WS_POPUP, 0, 0, 0, 0);
    Window.FMethod := Method;
    UtilityWindows.Add(Window);
  except Window.Free; raise; end;
  Result := Window.Handle;
end;
procedure DeallocateHWnd(Wnd: HWND);
var I: Integer; Window: TUtilityWindow;
begin
  for I := 0 to UtilityWindows.Count - 1 do
  begin
    Window := TUtilityWindow(UtilityWindows[I]);
    if Window.Handle = Wnd then
    begin
      UtilityWindows.Delete(I);
      Window.Free;
      Exit;
    end;
  end;
  raise ENativeWindowError.Create('DeallocateHWnd: not an AllocateHWnd window');
end;
constructor TForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIcon := TIcon.Create; FIcon.OnChange := IconChanged;
  FBorderStyle := bsSizeable;
  FBorderIcons := [biSystemMenu, biMinimize, biMaximize];
end;
destructor TForm.Destroy;
begin
  inherited Destroy;
  FIcon.Free;
end;
procedure TForm.SetIcon(Value: TIcon);
begin FIcon.Assign(Value); end;
procedure TForm.IconChanged(Sender: TObject);
begin
  if (Handle <> 0) and IsIconic(Handle) then InvalidateRect(Handle, nil, True);
end;
function TForm.IconHandle: HICON;
begin
  Result := FIcon.Handle;
  if (Result = 0) and (Application <> nil) then Result := Application.Icon.Handle;
  if Result = 0 then Result := LoadIcon(0, IDI_APPLICATION);
end;
procedure TForm.WMPaint(var Message: TWMPaint);
var PS: TPaintStruct; DC: HDC;
begin
  if not IsIconic(Handle) then begin inherited; Exit; end;
  { No class icon: USER asks the window to draw its minimized image. }
  DC := BeginPaint(Handle, PS);
  try DrawIcon(DC, 0, 0, IconHandle);
  finally EndPaint(Handle, PS); end;
  Message.Result := 0;
end;
procedure TForm.WMQueryDragIcon(var Message: TMessage);
begin Message.Result := IconHandle; end;
function TForm.Designer: TDesigner;
begin Result := nil; end;
function GetParentForm(Control: TControl): TForm;
var Current: TCustomControl;
begin
  Result := nil;
  if Control is TGraphicControl then Current := TGraphicControl(Control).Parent
  else if Control is TCustomControl then Current := TCustomControl(Control)
  else Exit;
  while (Current <> nil) and not (Current is TForm) do Current := Current.Parent;
  if Current <> nil then Result := TForm(Current);
end;
procedure TForm.CheckFrameChange;
begin
  { USER 3.1 cannot rebuild a live frame; Delphi recreated the window instead. }
  if Handle <> 0 then raise ENativeWindowError.Create('Form frame cannot change while the window exists');
end;
procedure TForm.SetBorderStyle(Value: TFormBorderStyle);
begin
  if Value = FBorderStyle then Exit;
  CheckFrameChange; FBorderStyle := Value;
end;
procedure TForm.SetBorderIcons(Value: TBorderIcons);
begin
  if Value = FBorderIcons then Exit;
  CheckFrameChange; FBorderIcons := Value;
end;
procedure TForm.SetPosition(Value: TPosition);
begin FPosition := Value; end;
procedure TForm.SetFormStyle(Value: TFormStyle);
begin
  if Value = FFormStyle then Exit;
  if Value in [fsMDIChild, fsMDIForm] then raise ENativeWindowError.Create('MDI forms are not provided');
  FFormStyle := Value;
  if Handle = 0 then Exit;
  if Value = fsStayOnTop then
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE)
  else SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;
function TForm.FrameStyle: DWORD;
var Icons: TBorderIcons;
begin
  case FBorderStyle of
    { An overlapped window always gets a caption; a bare frame must be a popup. }
    bsNone: Result := WS_POPUP;
    bsSingle: Result := WS_CAPTION or WS_BORDER;
    bsDialog: Result := WS_CAPTION or WS_DLGFRAME;
  else Result := WS_CAPTION or WS_THICKFRAME;
  end;
  Icons := FBorderIcons;
  { As in Delphi 1, a dialog frame keeps only the system menu. }
  if FBorderStyle = bsDialog then Icons := Icons * [biSystemMenu];
  if FBorderStyle <> bsNone then
  begin
    if biSystemMenu in Icons then Result := Result or WS_SYSMENU;
    if biMinimize in Icons then Result := Result or WS_MINIMIZEBOX;
    if biMaximize in Icons then Result := Result or WS_MAXIMIZEBOX;
  end;
end;
procedure TForm.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  case FPosition of
    poDesigned: ;
    poScreenCenter:
      begin
        X := (GetSystemMetrics(SM_CXSCREEN) - Width) div 2;
        Y := (GetSystemMetrics(SM_CYSCREEN) - Height) div 2;
      end;
  else raise ENativeWindowError.Create('Only poDesigned and poScreenCenter are provided');
  end;
  inherited CreateHandle(Parent, Caption,
    (Style and not DWORD(WS_OVERLAPPEDWINDOW or WS_DLGFRAME or WS_BORDER or WS_POPUP)) or FrameStyle,
    X, Y, Width, Height);
  if FFormStyle = fsStayOnTop then
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;
procedure TForm.DoClose(var Action: TCloseAction);
begin
  inherited DoClose(Action);
  { Delphi's caFree hides now and frees later; the native destroy-handle
    action would keep a dead model object instead. }
  if Action = caFree then begin Action := caHide; Release; end;
end;
procedure TForm.Release;
begin
  if Application = nil then raise ENativeApplicationError.Create('Invalid form release');
  Application.QueueRelease(Self);
end;
constructor TApplication.Create(AOwner: TComponent);
var Main: HICON;
begin
  inherited Create(AOwner); FReleases := TList.Create;
  FIcon := TIcon.Create;
  Main := LoadIcon(HInstance, 'MAINICON');
  if Main <> 0 then FIcon.CopyFromHandle(Main);
end;
procedure TApplication.SetIcon(Value: TIcon);
begin FIcon.Assign(Value); end;
procedure TApplication.QueueRelease(Form: TForm);
begin
  if (Form = nil) or ShuttingDown then raise ENativeApplicationError.Create('Invalid form release');
  if FReleases.IndexOf(Form) >= 0 then Exit;
  if not FReleaseHooked then begin HookMainWindow(ReleaseHook); FReleaseHooked := True; end;
  FReleases.Add(Form);
  try
    Form.FreeNotification(Self);
    if not PostMessage(Handle, ReleaseMessage, 0, 0) then
      raise ENativeApplicationError.Create('Cannot queue form release');
  except FReleases.Remove(Form); raise; end;
end;
procedure TApplication.FreeReleases;
var Form: TForm;
begin
  { Notification removes each entry as its form is freed; take the last one
    first so a destructor that releases another form cannot skip an entry. }
  while FReleases.Count <> 0 do
  begin
    Form := TForm(FReleases.Last); FReleases.Delete(FReleases.Count - 1);
    Form.RemoveFreeNotification(Self); Form.Free;
  end;
end;
function TApplication.ReleaseHook(var Message: TMessage): Boolean;
begin
  Result := Message.Msg = ReleaseMessage;
  if Result then begin Message.Result := 0; FreeReleases; end;
end;
procedure TApplication.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if (Operation = opRemove) and (FReleases <> nil) then FReleases.Remove(AComponent);
  inherited Notification(AComponent, Operation);
end;
function TApplication.MessageFilter(var Message: TMsg): Boolean;
begin
  Result := False;
  if Assigned(FOnMessage) then FOnMessage(Message, Result);
end;
procedure TApplication.SetOnMessage(Value: TMessageEvent);
begin
  FOnMessage := Value;
  if Assigned(Value) then TNativeApplication(Self).OnMessage := MessageFilter
  else TNativeApplication(Self).OnMessage := nil;
end;
function TApplication.GetMainForm: TForm;
begin Result := TNativeApplication(Self).MainForm as TForm; end;
procedure TApplication.SetMainForm(Value: TForm);
begin TNativeApplication(Self).MainForm := Value; end;
destructor TApplication.Destroy;
begin
  { Pending releases are freed before the owned forms, so unowned released
    forms do not leak when the queued message is never dispatched. }
  if FReleases <> nil then FreeReleases;
  if FReleaseHooked and Initialized and not ShuttingDown then
    UnhookMainWindow(ReleaseHook);
  FReleaseHooked := False;
  FReleases.Free; FReleases := nil;
  inherited Destroy;
  FIcon.Free; FIcon := nil;
end;
function TScreen.GetForm(Index: Integer): TForm;
var Form: TNativeForm;
begin
  Form := TNativeScreen(Self).Forms[Index];
  if not (Form is TForm) then raise ENativeScreenError.Create('Invalid screen form');
  Result := TForm(Form);
end;
function TScreen.GetActiveForm: TForm;
var Form: TNativeForm;
begin
  Form := TNativeScreen(Self).ActiveForm; Result := nil;
  if Form is TForm then Result := TForm(Form);
end;
initialization
  ReleaseMessage := RegisterWindowMessage('CalmiraFormRelease');
  UtilityWindows := TList.Create;
  Application := TApplication.Create(nil); Application.Initialize;
  Screen := TScreen.Create(nil); Screen.Application := Application;
finalization
  { Windows the program never deallocated go before the application. }
  while UtilityWindows.Count > 0 do
  begin
    TObject(UtilityWindows.Last).Free;
    UtilityWindows.Delete(UtilityWindows.Count - 1);
  end;
  UtilityWindows.Free; UtilityWindows := nil;
  Application.Free; Application := nil;
  Screen.Free; Screen := nil;
end.
