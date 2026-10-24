{ SPDX-License-Identifier: GPL-2.0-or-later
  Initial Forms compatibility layer over the tested native application, screen
  and modal-form foundations. It supplies the global Application/Screen pair,
  typed TForm access, deferred Release and application hints; it is not the
  complete Delphi Forms unit. Instead of runtime DFM streaming, TForm.Create
  runs loaders generated from the DFM at build time (tools/dfm_loader.py).
  Form menus are absent and must fail to compile rather than be silently
  aliased. }
unit Forms;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Forms layer requires Win16}{$ENDIF}
interface
uses Classes, SysUtils, WinTypes, Messages, Graphics, Controls, control_base, native_form, native_modal,
  native_application, native_application_window, native_screen, native_loop;
type
  TCloseAction = TNativeCloseAction;
  TCloseEvent = TNativeCloseEvent;
  TCloseQueryEvent = TNativeCloseQueryEvent;
  TWindowState = native_form.TWindowState;
  { Declared here in Delphi 1 (FORMS.INT); Controls holds the same type. }
  TModalResult = Controls.TModalResult;
  TMessageEvent = procedure(var Msg: TMsg; var Handled: Boolean) of object;
  TExceptionEvent = TNativeExceptionEvent;
  TIdleEvent = TNativeIdleEvent;
  TWindowHook = TNativeWindowHook;
  THintInfo = record
    HintControl: TControl;
    HintPos: TPoint;
    HintMaxWidth: Integer;
    HintColor: TColor;
    CursorRect: TRect;
    CursorPos: TPoint;
  end;
  TShowHintEvent = procedure(var HintStr: string; var CanShow: Boolean;
    var HintInfo: THintInfo) of object;
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
    FOnCreate, FOnDestroy: TNotifyEvent;
    { Client size requested before the window exists, or -1. }
    FDesignClientWidth, FDesignClientHeight: Integer;
    FVisibleAfterCreate: Boolean;
    { CreateParams work area while the window is created. }
    FCreation: Pointer;
    procedure ApplyClientSize;
    procedure PrepareCreation(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt);
    function GetFormClientWidth: Integer;
    function GetFormClientHeight: Integer;
    procedure SetClientWidth(Value: Integer);
    procedure SetClientHeight(Value: Integer);
    procedure CheckFrameChange;
    procedure SetIcon(Value: TIcon);
    procedure IconChanged(Sender: TObject);
    function IconHandle: HICON;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMQueryDragIcon(var Message: TMessage); message WM_QUERYDRAGICON;
    procedure WMSysCommand(var Message: TWMSysCommand); message WM_SYSCOMMAND;
    procedure SetBorderStyle(Value: TFormBorderStyle);
    procedure SetBorderIcons(Value: TBorderIcons);
    procedure SetPosition(Value: TPosition);
    procedure SetFormStyle(Value: TFormStyle);
  protected
    procedure DoClose(var Action: TCloseAction); override;
    procedure DoActivate; override;
    { Called before the window is created. Caption, Style, the bounds and
      WndParent are honoured; WndParent may only be 0 or the desktop window,
      which both leave the form unowned. Changing ExStyle, Param or the
      window class raises ENativeWindowError. }
    procedure CreateParams(var Params: TCreateParams); virtual;
  public
    { Runs the loaders registered for this class and its ancestors, as Delphi
      reads the form's DFM resources, then OnCreate. EResNotFound if the
      class has none. }
    constructor Create(AOwner: TComponent); override;
    { A form without components from a resource. }
    constructor CreateNew(AOwner: TComponent);
    destructor Destroy; override;
    procedure CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
      X, Y, Width, Height: SmallInt); override;
    { Before the window exists, the size follows the current frame style. }
    property ClientWidth: Integer read GetFormClientWidth write SetClientWidth;
    property ClientHeight: Integer read GetFormClientHeight write SetClientHeight;
    property OnCreate: TNotifyEvent read FOnCreate write FOnCreate;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
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
  { Builds a form's components in place of Delphi's DFM streaming. Loaders
    are generated by tools/dfm_loader.py and register themselves. }
  TFormLoader = procedure(Form: TForm);
  TApplication = class(TNativeApplication)
  private
    FReleases: TList;
    FReleaseHooked: Boolean;
    FOnMessage: TMessageEvent;
    FIcon: TIcon;
    FHint: string;
    FShowHint, FHintActive, FHintHooked: Boolean;
    FHintColor: TColor;
    FHintPause: Integer;
    FHintWindow: THintWindow;
    { Compared by address only; the live control is found again at the cursor. }
    FHintControl, FMouseControl: TControl;
    FHintCursorRect: TRect;
    FOnHint: TNotifyEvent;
    FOnShowHint: TShowHintEvent;
    FMinimized, FMinimizeHooked: Boolean;
    FHiddenForms: TList;
    FRestoreWindow: HWND;
    FOnMinimize, FOnRestore: TNotifyEvent;
    function MinimizeHook(var Message: TMessage): Boolean;
    procedure SetHint(const Value: string);
    procedure SetShowHint(Value: Boolean);
    function HintHook(var Message: TMessage): Boolean;
    procedure HintMouseMove;
    procedure StartHintTimer(Pause: Integer);
    procedure ShowHintNow;
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
    procedure CancelHint;
    { The long hint of the control under the mouse; setting it calls OnHint. }
    property Hint: string read FHint write SetHint;
    { Pop-up hints for controls whose ShowHint is True; off by default. }
    property ShowHint: Boolean read FShowHint write SetShowHint;
    property HintColor: TColor read FHintColor write FHintColor;
    property HintPause: Integer read FHintPause write FHintPause;
    property OnHint: TNotifyEvent read FOnHint write FOnHint;
    property OnShowHint: TShowHintEvent read FOnShowHint write FOnShowHint;
    { Hides the visible forms and shows the application as a desktop icon;
      Restore (or opening the icon) shows them again. }
    procedure Minimize;
    procedure Restore;
    property OnMinimize: TNotifyEvent read FOnMinimize write FOnMinimize;
    property OnRestore: TNotifyEvent read FOnRestore write FOnRestore;
  end;
  TScreen = class(TNativeScreen)
  private
    { The last control and form reported, kept by FreeNotification. }
    FFocusedControl: TComponent;
    FFocusedForm: TForm;
    FOnActiveControlChange, FOnActiveFormChange: TNotifyEvent;
    function GetForm(Index: Integer): TForm;
    function GetActiveForm: TForm;
    procedure ControlEntered(Sender: TObject);
    procedure FormActivated(Form: TForm);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    { Called as a control gets the focus (before its OnEnter) and as a form
      is activated, when that differs from the last one reported. }
    property OnActiveControlChange: TNotifyEvent read FOnActiveControlChange
      write FOnActiveControlChange;
    property OnActiveFormChange: TNotifyEvent read FOnActiveFormChange
      write FOnActiveFormChange;
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
procedure RegisterFormLoader(FormClass: TFormClass; Loader: TFormLoader);
{ Loader helpers: mark a new component csLoading until the form is loaded,
  and show the form once OnCreate has run (a DFM Visible = True). }
procedure ComponentLoading(Component: TComponent);
procedure ShowAfterCreate(Form: TForm);
{ The DFM name, made unique among the owner's components as Delphi does. }
procedure SetLoadedName(Form: TForm; const Name: string);
const
  HintWindowClass: THintWindowClass = THintWindow;
var
  Application: TApplication;
  Screen: TScreen;
implementation
uses WinProcs, native_window, native_input;
type
  { Kept off the stack: forms are created deep in small (4 KB) task stacks. }
  PFormCreation = ^TFormCreation;
  TFormCreation = record
    Params: TCreateParams;
    OriginalClass: TWndClass;
    Text: array[0..255] of Char;
    Title: string;
    Length: Word;
  end;
var ReleaseMessage: Word;
const
  HintTimer = $7E02;
  HintShortPause = 50;
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
type
  TComponentAccess = class(TComponent);
  TLoaderEntry = record
    FormClass: TFormClass;
    Loader: TFormLoader;
  end;
var Loaders: array of TLoaderEntry;
procedure RegisterFormLoader(FormClass: TFormClass; Loader: TFormLoader);
var I: Integer;
begin
  for I := 0 to High(Loaders) do
    if Loaders[I].FormClass = FormClass then
      raise EComponentError.CreateFmt('A loader for %s is already registered', [FormClass.ClassName]);
  I := Length(Loaders); SetLength(Loaders, I + 1);
  Loaders[I].FormClass := FormClass; Loaders[I].Loader := Loader;
end;
procedure ComponentLoading(Component: TComponent);
begin TComponentAccess(Component).Loading; end;
procedure ShowAfterCreate(Form: TForm);
begin Form.FVisibleAfterCreate := True; end;
procedure SetLoadedName(Form: TForm; const Name: string);
var Candidate: string; Number: Integer; Found: TComponent;
begin
  Candidate := Name; Number := 0;
  while Form.Owner <> nil do
  begin
    Found := Form.Owner.FindComponent(Candidate);
    if (Found = nil) or (Found = Form) then Break;
    Inc(Number); Candidate := Name + '_' + IntToStr(Number);
  end;
  Form.Name := Candidate;
end;
{ Ancestors first, as Delphi's InitInheritedComponent reads inherited forms. }
function RunLoaders(Form: TForm; AClass: TClass): Boolean;
var I: Integer;
begin
  Result := False;
  if (AClass = TForm) or (AClass = nil) then Exit;
  Result := RunLoaders(Form, AClass.ClassParent);
  for I := 0 to High(Loaders) do
    if Loaders[I].FormClass = AClass then
    begin
      Loaders[I].Loader(Form); Result := True;
    end;
end;
constructor TForm.Create(AOwner: TComponent);
var I: Integer;
begin
  CreateNew(AOwner);
  if ClassType = TForm then Exit;
  TComponentAccess(TComponent(Self)).Loading;
  if not RunLoaders(Self, ClassType) then
    raise EResNotFound.CreateFmt('Resource %s not found', [ClassName]);
  TComponentAccess(TComponent(Self)).Loaded;
  for I := 0 to ComponentCount - 1 do
    if csLoading in Components[I].ComponentState then
      TComponentAccess(Components[I]).Loaded;
  try
    if Assigned(FOnCreate) then FOnCreate(Self);
  except Application.HandleException(Self); end;
  if FVisibleAfterCreate then Visible := True;
end;
constructor TForm.CreateNew(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIcon := TIcon.Create; FIcon.OnChange := IconChanged;
  FBorderStyle := bsSizeable;
  FBorderIcons := [biSystemMenu, biMinimize, biMaximize];
  FDesignClientWidth := -1; FDesignClientHeight := -1;
end;
destructor TForm.Destroy;
begin
  if Assigned(FOnDestroy) then
    try FOnDestroy(Self);
    except if Application <> nil then Application.HandleException(Self); end;
  inherited Destroy;
  FIcon.Free;
  if FCreation <> nil then FreeMem(FCreation, SizeOf(TFormCreation));
end;
procedure TForm.ApplyClientSize;
var Area: TRect;
begin
  Area := Rect(0, 0, 0, 0);
  AdjustWindowRect(Area, FrameStyle, False);
  if FDesignClientWidth >= 0 then Width := FDesignClientWidth + Area.Right - Area.Left;
  if FDesignClientHeight >= 0 then Height := FDesignClientHeight + Area.Bottom - Area.Top;
end;
function TForm.GetFormClientWidth: Integer;
begin
  if (Handle = 0) and (FDesignClientWidth >= 0) then Result := FDesignClientWidth
  else Result := inherited ClientWidth;
end;
function TForm.GetFormClientHeight: Integer;
begin
  if (Handle = 0) and (FDesignClientHeight >= 0) then Result := FDesignClientHeight
  else Result := inherited ClientHeight;
end;
procedure TForm.SetClientWidth(Value: Integer);
begin
  if Handle <> 0 then Width := Width - inherited ClientWidth + Value
  else begin FDesignClientWidth := Value; ApplyClientSize; end;
end;
procedure TForm.SetClientHeight(Value: Integer);
begin
  if Handle <> 0 then Height := Height - inherited ClientHeight + Value
  else begin FDesignClientHeight := Value; ApplyClientSize; end;
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
procedure TForm.WMSysCommand(var Message: TWMSysCommand);
begin
  { Delphi 1: minimizing the main form minimizes the application. }
  if (Message.CmdType and $FFF0 = SC_MINIMIZE) and (Application <> nil) and
    (Application.MainForm = Self) then
  begin Message.Result := 0; Application.Minimize; end
  else inherited;
end;
procedure TForm.DoActivate;
begin
  if Screen <> nil then Screen.FormActivated(Self);
  inherited DoActivate;
end;
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
  CheckFrameChange; FBorderStyle := Value; ApplyClientSize;
end;
procedure TForm.SetBorderIcons(Value: TBorderIcons);
begin
  if Value = FBorderIcons then Exit;
  CheckFrameChange; FBorderIcons := Value; ApplyClientSize;
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
procedure TForm.CreateParams(var Params: TCreateParams);
begin end;
{ Fills FCreation; kept out of CreateHandle so that its frame is gone
  before CreateWindow sends the creation messages. }
procedure TForm.PrepareCreation(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  { No exception frame here: a failure leaves FCreation to Destroy. }
  if FCreation = nil then GetMem(FCreation, SizeOf(TFormCreation));
  with PFormCreation(FCreation)^ do
  begin
    FillChar(Params, SizeOf(Params), 0);
    Params.Caption := StrPCopy(Text, Caption);
    Params.Style := LongInt((Style and not DWORD(WS_OVERLAPPEDWINDOW or WS_DLGFRAME or WS_BORDER or WS_POPUP)) or
      FrameStyle);
    Params.X := X; Params.Y := Y; Params.Width := Width; Params.Height := Height;
    Params.WndParent := Parent;
    StrPLCopy(Params.WinClassName, NativeClassName, High(Params.WinClassName));
    GetClassInfo(HInstance, NativeClassName, Params.WindowClass);
    OriginalClass := Params.WindowClass;
    CreateParams(Params);
    if (Params.ExStyle <> 0) or (Params.Param <> nil) or
      (StrComp(Params.WinClassName, NativeClassName) <> 0) or
      not CompareMem(@OriginalClass, @Params.WindowClass, SizeOf(OriginalClass)) then
      raise ENativeWindowError.Create('Only Caption, Style, bounds and WndParent can change in CreateParams');
    if Params.WndParent = GetDesktopWindow then Params.WndParent := 0;
    if Params.WndParent <> 0 then raise ENativeWindowError.Create('Owned forms are not provided');
    Length := StrLen(Params.Caption);
    if Length > 255 then Length := 255;
    Move(Params.Caption^, Title[1], Length);
    Title[0] := Chr(Length);
    case FPosition of
      poDesigned: ;
      poScreenCenter:
        begin
          Params.X := (GetSystemMetrics(SM_CXSCREEN) - Params.Width) div 2;
          Params.Y := (GetSystemMetrics(SM_CYSCREEN) - Params.Height) div 2;
        end;
    else raise ENativeWindowError.Create('Only poDesigned and poScreenCenter are provided');
    end;
  end;
end;
procedure TForm.CreateHandle(Parent: HWND; const Caption: string; Style: DWORD;
  X, Y, Width, Height: SmallInt);
begin
  PrepareCreation(Parent, Caption, Style, X, Y, Width, Height);
  inherited CreateHandle(0, PFormCreation(FCreation)^.Title, DWORD(PFormCreation(FCreation)^.Params.Style),
    PFormCreation(FCreation)^.Params.X, PFormCreation(FCreation)^.Params.Y,
    PFormCreation(FCreation)^.Params.Width, PFormCreation(FCreation)^.Params.Height);
  FreeMem(FCreation, SizeOf(TFormCreation)); FCreation := nil;
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
  FHintColor := $80FFFF; FHintPause := 800;
  FHiddenForms := TList.Create;
  { Always filtered: Hint and OnHint follow the mouse even without pop-ups. }
  TNativeApplication(Self).OnMessage := MessageFilter;
end;
function ControlParent(Control: TControl): TControl;
begin
  if Control is TCustomControl then Result := TCustomControl(Control).Parent
  else if Control is TGraphicControl then Result := TGraphicControl(Control).Parent
  else Result := nil;
end;
function ControlToScreen(Control: TControl; const P: TPoint): TPoint;
begin
  if Control is TCustomControl then Result := TCustomControl(Control).ClientToScreen(P)
  else Result := TGraphicControl(Control).ClientToScreen(P);
end;
function ScreenToControl(Control: TControl; const P: TPoint): TPoint;
begin
  if Control is TCustomControl then Result := TCustomControl(Control).ScreenToClient(P)
  else Result := TGraphicControl(Control).ScreenToClient(P);
end;
function ControlClientRect(Control: TControl): TRect;
begin
  if Control is TCustomControl then Result := TCustomControl(Control).ClientRect
  else Result := TGraphicControl(Control).ClientRect;
end;
function ControlHeight(Control: TControl): Integer;
begin
  if Control is TCustomControl then Result := TCustomControl(Control).Height
  else Result := TGraphicControl(Control).Height;
end;
{ The control's own hint, or its nearest parent's. }
function ControlHint(Control: TControl): string;
begin
  Result := '';
  while (Control <> nil) and (Result = '') do
  begin Result := Control.Hint; Control := ControlParent(Control); end;
end;
{ The control that shows a pop-up hint at P: the nearest with ShowHint. }
function HintControlAt(const P: TPoint): TControl;
begin
  Result := FindDragTarget(P, True);
  while (Result <> nil) and not Result.ShowHint do Result := ControlParent(Result);
end;
procedure TApplication.Minimize;
var I: Integer; Window: HWND;
begin
  if FMinimized then Exit;
  if not FMinimizeHooked then begin HookMainWindow(MinimizeHook); FMinimizeHooked := True; end;
  CancelHint;
  FRestoreWindow := GetActiveWindow;
  FHiddenForms.Clear;
  { Every visible form of this task, registered or not; in Delphi they are
    all owned by the application window and hidden with it. }
  Window := GetTopWindow(0);
  while Window <> 0 do
  begin
    if (GetWindowTask(Window) = GetCurrentTask) and IsWindowVisible(Window) and
      (FindNativeWindow(Window) is TNativeForm) then FHiddenForms.Add(Pointer(Window));
    Window := GetWindow(Window, GW_HWNDNEXT);
  end;
  FMinimized := True;
  for I := 0 to FHiddenForms.Count - 1 do
  begin
    Window := HWND(FHiddenForms[I]);
    ShowWindow(Window, SW_HIDE);
  end;
  ShowWindow(Handle, SW_MINIMIZE);
  if Assigned(FOnMinimize) then FOnMinimize(Self);
end;
procedure TApplication.Restore;
var I: Integer; Window: HWND;
begin
  if not FMinimized then Exit;
  FMinimized := False;
  { The application window is only the icon; it stays hidden otherwise. }
  ShowWindow(Handle, SW_SHOWNOACTIVATE);
  ShowWindow(Handle, SW_HIDE);
  for I := 0 to FHiddenForms.Count - 1 do
  begin
    Window := HWND(FHiddenForms[I]);
    { A form freed meanwhile leaves a stale handle behind. }
    if IsWindow(Window) and (FindNativeWindow(Window) <> nil) then ShowWindow(Window, SW_SHOWNA);
  end;
  if (FRestoreWindow <> 0) and (FHiddenForms.IndexOf(Pointer(FRestoreWindow)) >= 0) and
    IsWindowVisible(FRestoreWindow) then SetActiveWindow(FRestoreWindow)
  else if (MainForm <> nil) and (MainForm.Handle <> 0) and IsWindowVisible(MainForm.Handle) then
    SetActiveWindow(MainForm.Handle);
  FHiddenForms.Clear; FRestoreWindow := 0;
  if Assigned(FOnRestore) then FOnRestore(Self);
end;
function TApplication.MinimizeHook(var Message: TMessage): Boolean;
var PS: TPaintStruct; DC: HDC; Icon: HICON;
begin
  Result := False;
  Icon := FIcon.Handle;
  if Icon = 0 then Icon := LoadIcon(0, IDI_APPLICATION);
  case Message.Msg of
    WM_SYSCOMMAND:
      case Message.WParam and $FFF0 of
        SC_MINIMIZE: begin Minimize; Result := True; end;
        SC_RESTORE: if FMinimized then begin Restore; Result := True; end;
      end;
    WM_QUERYOPEN:
      if FMinimized then
      begin
        { Opening the icon restores the forms, not this hidden window. }
        PostMessage(Handle, WM_SYSCOMMAND, SC_RESTORE, 0);
        Message.Result := 0; Result := True;
      end;
    WM_PAINT:
      if IsIconic(Handle) then
      begin
        DC := BeginPaint(Handle, PS);
        try DrawIcon(DC, 0, 0, Icon); finally EndPaint(Handle, PS); end;
        Message.Result := 0; Result := True;
      end;
    WM_QUERYDRAGICON: begin Message.Result := Icon; Result := True; end;
  end;
  if Result and (Message.Msg = WM_SYSCOMMAND) then Message.Result := 0;
end;
procedure TApplication.SetHint(const Value: string);
begin
  if FHint = Value then Exit;
  FHint := Value;
  if Assigned(FOnHint) then FOnHint(Self);
end;
procedure TApplication.SetShowHint(Value: Boolean);
begin
  if FShowHint = Value then Exit;
  FShowHint := Value;
  if Value then FHintWindow := HintWindowClass.Create(Self)
  else begin CancelHint; FHintWindow.Free; FHintWindow := nil; end;
end;
procedure TApplication.CancelHint;
begin
  if FHintHooked and (Handle <> 0) then KillTimer(Handle, HintTimer);
  if (FHintWindow <> nil) and (FHintWindow.Handle <> 0) then
    ShowWindow(FHintWindow.Handle, SW_HIDE);
  FHintActive := False; FHintControl := nil;
end;
procedure TApplication.StartHintTimer(Pause: Integer);
begin
  if not FHintHooked then begin HookMainWindow(HintHook); FHintHooked := True; end;
  KillTimer(Handle, HintTimer);
  if SetTimer(Handle, HintTimer, Pause, nil) = 0 then CancelHint;
end;
function TApplication.HintHook(var Message: TMessage): Boolean;
begin
  Result := (Message.Msg = WM_TIMER) and (Message.WParam = HintTimer);
  if not Result then Exit;
  Message.Result := 0;
  KillTimer(Handle, HintTimer);
  ShowHintNow;
end;
procedure TApplication.HintMouseMove;
var P: TPoint; Control: TControl;
begin
  GetCursorPos(P);
  Control := FindDragTarget(P, True);
  if Control <> FMouseControl then
  begin
    FMouseControl := Control;
    Hint := GetLongHint(ControlHint(Control));
  end;
  if not FShowHint then Exit;
  Control := HintControlAt(P);
  if Control = nil then CancelHint
  else if (Control <> FHintControl) or
    not Controls.PtInRect(FHintCursorRect, ScreenToControl(Control, P)) then
  begin
    FHintControl := Control;
    { Further moves inside the control do not restart the pause. }
    FHintCursorRect := ControlClientRect(Control);
    { Moving on while a hint shows replaces it almost at once. }
    if FHintActive then StartHintTimer(HintShortPause) else StartHintTimer(FHintPause);
  end;
end;
procedure TApplication.ShowHintNow;
var P: TPoint; Control: TControl; Info: THintInfo; HintStr: string; CanShow: Boolean;
  R: TRect; Text: array[0..255] of Char;
begin
  GetCursorPos(P);
  Control := HintControlAt(P);
  { The control may have gone since the timer started. }
  if (FHintWindow = nil) or (Control = nil) or (Control <> FHintControl) then
  begin CancelHint; Exit; end;
  Info.HintControl := Control;
  Info.HintPos := ControlToScreen(Control, Point(0, ControlHeight(Control)));
  Info.HintMaxWidth := Screen.Width;
  Info.HintColor := FHintColor;
  Info.CursorRect := ControlClientRect(Control);
  Info.CursorPos := ScreenToControl(Control, P);
  HintStr := GetShortHint(ControlHint(Control));
  CanShow := True;
  if Assigned(FOnShowHint) then FOnShowHint(HintStr, CanShow, Info);
  if not CanShow or (HintStr = '') then
  begin
    { Keep the control but let the next move ask again (Calmira's file grid
      shows a hint only over a file). }
    CancelHint; FHintControl := Control; SetRectEmpty(FHintCursorRect); Exit;
  end;
  FHintCursorRect := Info.CursorRect;
  R := Rect(0, 0, Info.HintMaxWidth, 0);
  DrawText(FHintWindow.Canvas.ContextHandle, StrPCopy(Text, HintStr), -1, R,
    DT_CALCRECT or DT_LEFT or DT_WORDBREAK or DT_NOPREFIX);
  OffsetRect(R, Info.HintPos.X, Info.HintPos.Y);
  Inc(R.Right, 6); Inc(R.Bottom, 2);
  FHintWindow.Color := Info.HintColor;
  FHintWindow.ActivateHint(R, HintStr);
  FHintActive := True;
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
  if not ShuttingDown then
    if FHintActive and FHintWindow.IsHintMsg(Message) then CancelHint
    else if Message.Message = WM_MOUSEMOVE then HintMouseMove;
  if Assigned(FOnMessage) then FOnMessage(Message, Result);
end;
procedure TApplication.SetOnMessage(Value: TMessageEvent);
begin FOnMessage := Value; end;
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
  if FHintHooked and Initialized and not ShuttingDown then
  begin KillTimer(Handle, HintTimer); UnhookMainWindow(HintHook); end;
  FHintHooked := False;
  if FMinimizeHooked and Initialized and not ShuttingDown then UnhookMainWindow(MinimizeHook);
  FMinimizeHooked := False;
  FHiddenForms.Free; FHiddenForms := nil;
  TNativeApplication(Self).OnMessage := nil;
  FHintWindow.Free; FHintWindow := nil;
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
procedure BroadcastFocusChanged(Control, Focused: TCustomControl);
var I: Integer;
begin
  Control.Perform(CM_FOCUSCHANGED, 0, LongInt(Focused));
  for I := 0 to Control.ControlCount - 1 do
    if Control.Controls[I] is TCustomControl then
      BroadcastFocusChanged(TCustomControl(Control.Controls[I]), Focused);
end;
procedure TScreen.ControlEntered(Sender: TObject);
var Form: TForm;
begin
  if Sender = FFocusedControl then Exit;
  { Delphi's SetFocusedControl tells the whole form, e.g. to move a default
    button frame or repaint a focus rectangle. }
  if Sender is TCustomControl then
  begin
    Form := GetParentForm(TCustomControl(Sender));
    if Form <> nil then BroadcastFocusChanged(Form, TCustomControl(Sender));
  end;
  if FFocusedControl <> nil then FFocusedControl.RemoveFreeNotification(Self);
  FFocusedControl := nil;
  if Sender is TComponent then
  begin FFocusedControl := TComponent(Sender); FFocusedControl.FreeNotification(Self); end;
  if Assigned(FOnActiveControlChange) then FOnActiveControlChange(Self);
end;
procedure TScreen.FormActivated(Form: TForm);
begin
  if Form = FFocusedForm then Exit;
  if FFocusedForm <> nil then FFocusedForm.RemoveFreeNotification(Self);
  FFocusedForm := Form; Form.FreeNotification(Self);
  if Assigned(FOnActiveFormChange) then FOnActiveFormChange(Self);
end;
procedure TScreen.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if Operation = opRemove then
  begin
    if AComponent = FFocusedControl then FFocusedControl := nil;
    if AComponent = FFocusedForm then FFocusedForm := nil;
  end;
  inherited Notification(AComponent, Operation);
end;
destructor TScreen.Destroy;
begin
  if TMethod(EnterNotify).Data = Pointer(Self) then EnterNotify := nil;
  if FFocusedControl <> nil then FFocusedControl.RemoveFreeNotification(Self);
  if FFocusedForm <> nil then FFocusedForm.RemoveFreeNotification(Self);
  FFocusedControl := nil; FFocusedForm := nil;
  inherited Destroy;
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
  EnterNotify := Screen.ControlEntered;
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
