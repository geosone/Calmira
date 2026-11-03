unit native_ctl3d;
{ CTL3D support as in Delphi 1's Forms unit. When CTL3DV2.DLL (or the older
  CTL3D.DLL) can be loaded, the program registers with it. Dialog frames
  (bsDialog) are then painted by Ctl3DDlgFramePaint, and check boxes and
  radio buttons run through Ctl3DBtnWndProc. Without the DLL everything
  draws as plain Windows 3.1 does. }
interface
uses WinTypes;

type
  TCtl3DFramePaint = function(Wnd: HWND; Msg: Word; WParam: Word; LParam: LongInt): LongInt;
  TCtl3DCtlColorEx = function(Msg: Word; WParam: Word; LParam: LongInt): HBRUSH;

var
  Ctl3DBtnWndProc: Pointer;
  Ctl3DDlgFramePaint: TCtl3DFramePaint;
  Ctl3DCtlColorEx: TCtl3DCtlColorEx;

{ Loads and registers CTL3D once; later calls do nothing. }
procedure InitCtl3D;
procedure DoneCtl3D;
function Ctl3DLoaded: Boolean;
procedure Subclass3DWnd(Wnd: HWND);
procedure Subclass3DDlg(Wnd: HWND; Flags: Word);
procedure SetAutoSubClass(Enable: Boolean);

implementation
uses WinProcs;

type
  TCtl3DInstance = function(Instance: THandle): Bool;
  TCtl3DWindow = function(Wnd: HWND): Bool;
  TCtl3DDialog = function(Wnd: HWND; Flags: Word): Bool;

const
  { Export ordinals of CTL3DV2.DLL; CTL3D.DLL uses the same numbers. }
  OrdRegister = 12; OrdUnregister = 13; OrdSubclassCtl = 3; OrdSubclassDlg = 2;
  OrdBtnWndProc = 7; OrdAutoSubclass = 16; OrdCtlColorEx = 18;
  OrdDlgFramePaint = 20; OrdUnAutoSubclass = 24;

var
  Ctl3DHandle: THandle;
  Tried, Registered: Boolean;

function Entry(Ordinal: Word): Pointer;
begin
  { KERNEL's GetProcAddress; the RTL names it WinGetProcAddress. }
  Result := WinGetProcAddress(Ctl3DHandle, MakeIntResource(Ordinal));
end;

procedure InitCtl3D;
var ErrorMode: Word; Register: TCtl3DInstance;
begin
  if Tried then Exit;
  Tried := True;
  ErrorMode := SetErrorMode(SEM_NOOPENFILEERRORBOX);
  try
    Ctl3DHandle := LoadLibrary('CTL3DV2.DLL');
    if Ctl3DHandle < HINSTANCE_ERROR then Ctl3DHandle := LoadLibrary('CTL3D.DLL');
  finally SetErrorMode(ErrorMode); end;
  if Ctl3DHandle < HINSTANCE_ERROR then begin Ctl3DHandle := 0; Exit; end;
  @Register := Entry(OrdRegister);
  if (not Assigned(Register)) or not Register(HInstance) then
  begin
    FreeLibrary(Ctl3DHandle); Ctl3DHandle := 0; Exit;
  end;
  Registered := True;
  Ctl3DBtnWndProc := Entry(OrdBtnWndProc);
  @Ctl3DDlgFramePaint := Entry(OrdDlgFramePaint);
  @Ctl3DCtlColorEx := Entry(OrdCtlColorEx);
end;

procedure DoneCtl3D;
var Unregister: TCtl3DInstance;
begin
  if Ctl3DHandle <> 0 then
  begin
    if Registered then
    begin
      @Unregister := Entry(OrdUnregister);
      if Assigned(Unregister) then Unregister(HInstance);
    end;
    FreeLibrary(Ctl3DHandle);
  end;
  Ctl3DHandle := 0; Registered := False;
  Ctl3DBtnWndProc := nil; Ctl3DDlgFramePaint := nil; Ctl3DCtlColorEx := nil;
end;

function Ctl3DLoaded: Boolean;
begin
  Result := Registered;
end;

procedure Subclass3DWnd(Wnd: HWND);
var Subclass: TCtl3DWindow;
begin
  InitCtl3D;
  if not Registered then Exit;
  @Subclass := Entry(OrdSubclassCtl);
  if Assigned(Subclass) then Subclass(Wnd);
end;

procedure Subclass3DDlg(Wnd: HWND; Flags: Word);
var Subclass: TCtl3DDialog;
begin
  InitCtl3D;
  if not Registered then Exit;
  @Subclass := Entry(OrdSubclassDlg);
  if Assigned(Subclass) then Subclass(Wnd, Flags);
end;

procedure SetAutoSubClass(Enable: Boolean);
var Change: TCtl3DInstance;
begin
  InitCtl3D;
  if not Registered then Exit;
  if Enable then @Change := Entry(OrdAutoSubclass)
  else @Change := Entry(OrdUnAutoSubclass);
  if Assigned(Change) then Change(HInstance);
end;

end.
