{*********************************************************}
{                                                         }
{    Calmira System library 3.3                           }
{    by Li-Hsin Huang & Erwin Dokter                      }
{    released into the public domain may 2002             }
{                                                         }
{*********************************************************}

unit ExtForm;

{ Defines TExtForm, which is a TForm with facilities for saving its
  size and position.  The additional property MinPosition allows the
  form to appear as an icon at a specified position (i.e., setting
  it also shows the form).

  3.1 -- Moved from CalForm: The StretchShift method adjusts the controls
  on a form when it is resized.  Call it from the OnResize handler.

  Finally, ShowNormal is provided to make it easier to display a
  window, whatever state it is in. }

interface

uses Forms, Classes, Controls, WinTypes, Messages, IniFiles, Graphics;

type
  TStretchFlag = (stLeft, stTop, stWidth, stHeight);
  TStretchFlags = set of TStretchFlag;

type
  TExtForm = class(TForm)
  private
    FLastMinPosition: TPoint;
    FMinimumWidth: Integer;
    FMinimumHeight: Integer;
    OldClientWidth: Integer;
    OldClientHeight: Integer;
    SizeDelta: TPoint;
    tActive: Boolean;
    FNoDefNCPaint: Boolean;
    btn: Integer;
    FSmallIcon: TBitmap;
    procedure SetSmallIcon(AGlyph: TBitmap);
    function GetMinPosition: TPoint;
    procedure SetMinPosition(pt: TPoint);
    procedure WMGetMinMaxInfo(var Message: TWMGetMinMaxInfo); message WM_GETMINMAXINFO;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMNCPaint(var Message: TMessage); message WM_NCPAINT;
    procedure WMNCMouseMove(var Message: TMessage); message WM_NCMOUSEMOVE;
    procedure WMNCActivate(var Message: TMessage); message WM_NCACTIVATE;
    procedure WMNCLBtnDown(var Message: TMessage); message WM_NCLBUTTONDOWN;
    procedure WMNCLBtnUp(var Message: TMessage); message WM_NCLBUTTONUP;
    procedure WMNCRBtnDown(var Message: TMessage); message WM_NCRBUTTONDOWN;
    procedure WMNCRBtnUp(var Message: TMessage); message WM_NCRBUTTONUP;
    procedure WMNCLDblClick(var Message: TMessage); message WM_NCLBUTTONDBLCLK;
    procedure WMSetText(var Message: TMessage); message WM_SETTEXT;
  protected
    HelperWindow: hWnd;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure Loaded; override;
    procedure Resize; override;
    procedure SysMenuWndProc(var Message: TMessage);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowNormal;
    procedure EnableControls(Enable: Boolean);
    procedure UpdateIcon;
    property NoDefNCPaint: Boolean read FNoDefNCPaint write FNoDefNCPaint;
    property SmallIcon: TBitmap read FSmallIcon write SetSmallIcon;
    procedure StretchShift(const C: array of TControl; Flags: TStretchFlags);
    procedure LoadMinPosition(ini: TIniFile; const section: string);
    procedure LoadPosition(ini: TIniFile; const section: string);
    procedure SavePosition(ini: TIniFile; const section: string);
    property MinimumWidth: Integer read FMinimumWidth write FMinimumWidth;
    property MinimumHeight: Integer read FMinimumHeight write FMinimumHeight;
    property MinPosition: TPoint read GetMinPosition write SetMinPosition;
    property LastMinPosition: TPoint read FLastMinPosition;
  end;

const
  { some magic numbers! }
  SC_SIZELEFT        = SC_SIZE + 1;
  SC_SIZERIGHT       = SC_SIZE + 2;
  SC_SIZETOP         = SC_SIZE + 3;
  SC_SIZETOPLEFT     = SC_SIZE + 4;
  SC_SIZETOPRIGHT    = SC_SIZE + 5;
  SC_SIZEBOTTOM      = SC_SIZE + 6;
  SC_SIZEBOTTOMLEFT  = SC_SIZE + 7;
  SC_SIZEBOTTOMRIGHT = SC_SIZE + 8;
  SC_DRAGMOVE        = SC_SIZE + 9;

  btnClose: array [0..3] of Integer = (-18,2,-3,15);
  btnMinim: array [0..3] of Integer = (-52,2,-37,15);
  btnZoom:  array [0..3] of Integer = (-36,2,-21,15);

implementation

uses WinProcs, MiscUtil, LangUI{$IFDEF FPC}, Win31{$ENDIF};

function TExtForm.GetMinPosition: TPoint;
var
  place: TWindowPlacement;
begin
  place.Length := SizeOf(place);
  GetWindowPlacement(Handle, @place);
  Result := place.ptMinPosition;
end;

procedure TExtForm.SetMinPosition(pt: TPoint);
var
  place: TWindowPlacement;
begin
  with Screen do
  begin
    if pt.x >= Width then pt.x := Width - 48;
    if pt.y >= Height then pt.y := Height - 48;
  end;
  if Visible then Invalidate;
  place.Length := SizeOf(place);
  GetWindowPlacement(Handle, @place);
  place.ptMinPosition := pt;
  place.Flags := place.Flags or WPF_SETMINPOSITION;
  place.ShowCmd := SW_SHOWMINNOACTIVE;
  SetWindowPlacement(Handle, @place);
  Visible := True;
  FLastMinPosition := pt;
end;

procedure TExtForm.WMGetMinMaxInfo(var Message: TWMGetMinMaxInfo);
begin
  inherited;
  with Message.MinMaxInfo^ do
  begin
    { 3.11 added ptMaxSize }
    if BorderStyle = bsSingle then
    begin
      ptMaxSize.X := Screen.Width + 2;
      ptMaxSize.Y := Screen.Height + 2;
    end;
    ptMinTrackSize.X := FMinimumWidth;
    ptMinTrackSize.Y := FMinimumHeight;
  end;
end;

procedure TExtForm.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  inherited;
  message.Result := DLGC_WANTTAB;
end;

procedure TExtForm.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Cmd: Word;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (WindowState <> wsNormal) or (Button = mbRight) then Exit;
  if (BorderStyle=bsSizeable) then
  begin
  if (x >= ClientWidth - 16 + GetSystemMetrics(SM_CXFRAME)) and
     (y >= ClientHeight - 16 + GetSystemMetrics(SM_CYFRAME)) then
    begin
    ReleaseCapture;
    Perform(WM_SYSCOMMAND, SC_SIZEBOTTOMRIGHT, 0);
    end;
  Exit;
  end;
  ReleaseCapture;
  if (x <= 16) and (y <= 16) then Cmd := SC_SIZETOPLEFT
  else if (x <= 16) and (y >= ClientHeight - 16) then Cmd := SC_SIZEBOTTOMLEFT
  else if (x >= ClientWidth - 16) and (y <= 16) then Cmd := SC_SIZETOPRIGHT
  else if (x >= ClientWidth - 16) and (y >= ClientHeight - 16) then Cmd := SC_SIZEBOTTOMRIGHT
  else if (x <= 4) then Cmd := SC_SIZELEFT
  else if (y <= 4) then Cmd := SC_SIZETOP
  else if (x >= ClientWidth - 4) then Cmd := SC_SIZERIGHT
  else if (y >= ClientHeight - 4) then Cmd := SC_SIZEBOTTOM
  else Cmd := 0;
  Perform(WM_SYSCOMMAND, Cmd, 0);
end;

procedure TExtForm.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  Cursor := crDefault;
  if WindowState <> wsNormal then Exit;
  if (BorderStyle=bsSizeable) then
    begin
    if ((x >= ClientWidth - 16 + GetSystemMetrics(SM_CXFRAME)) and
      (y >= ClientHeight - 16 + GetSystemMetrics(SM_CYFRAME))) then Cursor := crSizeNWSE;
    Exit;
    end;
  if ((x <= 16) and (y <= 16)) or ((x >= ClientWidth - 16) and
    (y >= ClientHeight - 16)) then Cursor := crSizeNWSE
  else if ((x >= ClientWidth - 16) and (y <= 16)) or ((x <= 16) and
    (y >= ClientHeight - 16)) then Cursor := crSizeNESW
  else if (x <= 4) or (x >= ClientWidth - 4) then Cursor := crSizeWE
  else if (y <= 4) or (y >= ClientHeight - 4) then Cursor := crSizeNS;
end;

procedure TExtForm.Loaded;
begin
  inherited Loaded;
  ApplyComponentLanguage(Self);
  FMinimumWidth := Width;
  FMinimumHeight := Height;
  OldClientWidth := ClientWidth;
  OldClientHeight := ClientHeight;
end;

procedure TExtForm.Resize;
begin
  if WindowState <> wsMinimized { 3.0 } then
  begin
    SizeDelta.X := ClientWidth - OldClientWidth;
    SizeDelta.Y := ClientHeight - OldClientHeight;
    OldClientWidth := ClientWidth;
    OldClientHeight := ClientHeight;
  end;
  inherited Resize;
end;

procedure TExtForm.ShowNormal;
begin
  WindowState := wsNormal;
  Show;
end;

procedure TExtForm.EnableControls(Enable: Boolean);
var
  i: Integer;
begin
  for i := 0 to ControlCount - 1 do Controls[i].Enabled := Enable;
end;

procedure TExtForm.StretchShift(const C: array of TControl;
  Flags: TStretchFlags);
var
  i, L, T, W, H: Integer;
begin
  for i := 0 to High(C) do with C[i] do
  begin
    L := Left;
    T := Top;
    W := Width;
    H := Height;
    if stLeft in Flags then Inc(L, SizeDelta.x);
    if stTop in Flags then Inc(T, SizeDelta.y);
    if stWidth in Flags then Inc(W, SizeDelta.x);
    if stHeight in Flags then Inc(H, SizeDelta.y);
    SetBounds(L, T, W, H);
  end;
end;

procedure TExtForm.LoadMinPosition(ini: TIniFile; const section: string);
begin
  MinPosition := Point(ini.ReadInteger(section, 'MinLeft', 128),
    ini.ReadInteger(section, 'MinTop', 128));
end;

procedure TExtForm.LoadPosition(ini: TIniFile; const section: string);
begin
  with ini do SetBounds(
    ReadInteger(section, 'Left', Left),
    ReadInteger(section, 'Top', Top),
    ReadInteger(section, 'Width', Width),
    ReadInteger(section, 'Height', Height));
end;

procedure TExtForm.SavePosition(ini: TIniFile; const section: string);
begin
  with ini do
  begin
    WriteInteger(section, 'Left', Left);
    WriteInteger(section, 'Top', Top);
    WriteInteger(section, 'Width', Width);
    WriteInteger(section, 'Height', Height);
    with MinPosition do
    begin
      WriteInteger(section, 'MinLeft', X);
      WriteInteger(section, 'MinTop', Y);
    end;
  end;
end;

procedure TExtForm.WMNCPaint(var Message: TMessage);

  procedure SelectNCUpdateRgn(Wnd: HWND; DC: HDC; Rgn: HRGN);
  var
    R: TRect;
    NewClipRgn: HRGN;
  begin
    if (Rgn <> 0) and (Rgn <> 1) then begin
      GetWindowRect(Wnd, R);
      if SelectClipRgn(DC, Rgn) = ERROR then begin
        NewClipRgn := CreateRectRgnIndirect(R);
        SelectClipRgn(DC, NewClipRgn);
        DeleteObject(NewClipRgn);
      end;
      OffsetClipRgn(DC, -R.Left, -R.Top);
    end;
  end;

const
  BorderColors: array [Boolean] of TColor= (clInactiveBorder,clActiveBorder);
  CaptionColors: array [Boolean] of TColor= (clInactiveCaption,clActiveCaption);
  TitleColors: array [Boolean] of TColor= (clInactiveCaptionText,clCaptionText);
var
  cnv: TCanvas;
  pos,btn: TRect;
  BWid, i, fTop: Integer;
  Glyph: TBitmap;
  tZoomed: Boolean;
  Style, ExStyle: LongInt;
  orig: TPoint;
  tIcon: HIcon;
begin
if (not (FNoDefNCPaint or (Message.LParam=1))) or NewStyleControls or IsIconic(Handle) then
 inherited;
if NewStyleControls or IsIconic(Handle) then Exit;
if csDestroying in ComponentState then Exit;
cnv := TCanvas.Create;
cnv.Handle := GetWindowDC(Handle);
SelectNCUpdateRgn(Handle,cnv.Handle,Message.WParam);
tZoomed := IsZoomed(Handle);
GetWindowRect(Handle,pos);
fTop := pos.Top;
pos := Rect(0,0,pos.Right-pos.Left-1,pos.Bottom-pos.Top-1);
Style := GetWindowLong(Handle,GWL_STYLE);
ExStyle := GetWindowLong(Handle,GWL_EXSTYLE);
if ((Style and WS_THICKFRAME)<>0) or
   ((ExStyle and WS_EX_DLGMODALFRAME)<>0) then
  begin
  cnv.Pen.Color := clBtnFace;
  cnv.MoveTo(0,0);
  cnv.LineTo(pos.Right,0);
  cnv.MoveTo(0,0);
  cnv.LineTo(0,pos.Bottom);
  cnv.Pen.Color := clBtnHighLight;
  cnv.MoveTo(1,1);
  cnv.LineTo(pos.Right-1,1);
  cnv.MoveTo(1,1);
  cnv.LineTo(1,pos.Bottom-1);
  cnv.Pen.Color := clBtnText;
  cnv.MoveTo(pos.Right,pos.Bottom);
  cnv.LineTo(pos.Right,-1);
  cnv.MoveTo(pos.Right,pos.Bottom);
  cnv.LineTo(-1,pos.Bottom);
  cnv.Pen.Color := clBtnShadow;
  cnv.MoveTo(pos.Right-1,pos.Bottom-1);
  cnv.LineTo(pos.Right-1,0);
  cnv.MoveTo(pos.Right-1,pos.Bottom-1);
  cnv.LineTo(0,pos.Bottom-1);
  end
else if (Style and WS_BORDER) <> 0 then
  begin
  cnv.Pen.Color := clWindowFrame;
  cnv.MoveTo(0,0);
  cnv.LineTo(0,pos.Bottom);
  cnv.LineTo(pos.Right,pos.Bottom);
  cnv.LineTo(pos.Right,0);
  cnv.LineTo(0,0);
  end;
cnv.Pen.Color := BorderColors[tActive];
if (Style and WS_THICKFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXFRAME)
else if (ExStyle and WS_EX_DLGMODALFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXDLGFRAME)+1
else
  BWid := 1;
for i:=2 to BWid-1 do
  begin
  cnv.MoveTo(i,i);
  cnv.LineTo(pos.Right-i,i);
  cnv.LineTo(pos.Right-i, pos.Bottom-i);
  cnv.LineTo(i, pos.Bottom-i);
  cnv.LineTo(i,i);
  end;
cnv.Brush.Color := CaptionColors[tActive];
{cnv.FloodFill(pos.Right-BWid,BWid,
              clNavy,fsSurface);}
tIcon := Icon.Handle;
if (tIcon=0) then
  tIcon := Application.Icon.Handle;
Glyph := TBitmap.Create;
cnv.Brush.Color := CaptionColors[tActive];
if (Style and WS_CAPTION)<> 0 then
  i := GetSystemMetrics(SM_CYCAPTION)-GetSystemMetrics(SM_CYBORDER)
else
  i := 0;
if (i>0) then
  begin
  if ((ExStyle and WS_EX_DLGMODALFRAME)=0) then
    begin
    cnv.FillRect(Rect(BWid,BWid,BWid+i,BWid+i));
    if FSmallIcon.Empty then
      ShrinkIcon(tIcon,Glyph,CaptionColors[tActive])
    else
      begin
      {InitBitmap(Glyph,16,16,CaptionColors[tActive]);}
      Glyph.Width := 16;
      Glyph.Height := 16;
      Glyph.Canvas.Brush.Color := CaptionColors[tActive];
      Glyph.Canvas.BrushCopy(Rect(0,0,16,16),FSmallIcon,Rect(0,0,16,16),FSmallIcon.Canvas.Pixels[0,0]);
      {ShrinkIcon(FSmallIcon.Handle,Glyph,CaptionColors[tActive])
      InitBitmap(Glyph,16,16,CaptionColors[tActive]);
      DrawIconEx(Glyph.Canvas.Handle,0,0,FSmallIcon.Handle,16,16,0,0,DI_NORMAL);}
      end;
    cnv.Draw(BWid+1,BWid+1,Glyph);
    cnv.Font.Color := TitleColors[tActive];
    Glyph.Free;
    cnv.FillRect(Rect(BWid+1+16,BWid,pos.Right-BWid+1,BWid+i));
    cnv.Font.Name := 'MS Sans Serif';
    cnv.Font.Size := 8;
    cnv.Font.Style := [fsBold];
    cnv.TextOut(BWid+4+16,BWid+3,Caption);
    end
  else
    begin
    cnv.Font.Color := TitleColors[tActive];
    cnv.FillRect(Rect(BWid,BWid,pos.Right-BWid+1,BWid+i));
    cnv.Font.Name := 'MS Sans Serif';
    cnv.Font.Size := 8;
    cnv.Font.Style := [fsBold];
    cnv.TextOut(BWid+4,BWid+3,Caption);
    end;
  if GetMenu(Handle)<>0 then
    begin
    orig := Point(0,0);
    WinProcs.ClientToScreen(Handle,orig);
    WinProcs.ScreenToClient(GetParent(Handle),orig);
    Dec(orig.y,fTop+1);
    cnv.Pen.Color := clMenu;
    cnv.MoveTo(BWid,{BWid+2*i-1} orig.y);
    cnv.LineTo(pos.Right-BWid,{BWid+2*i-1} orig.y);
    end;
  cnv.Brush.Color := clBtnFace;
  cnv.Font.Color := clBtnText;
  Glyph := TBitmap.Create;
  Glyph.Handle := LoadBitmap(HInstance,'btnClose');
  btn := Rect(pos.Right-BWid+btnClose[0],
            BWid+btnClose[1],
            pos.Right-BWid+btnClose[2],
            BWid+btnClose[3]);
  cnv.FillRect(btn);
  cnv.Pen.Color := clBtnText;
  cnv.Draw(btn.Left+1,btn.Top+1,Glyph);
  Glyph.Free;
  cnv.Pen.Color := clBtnHighLight;
  cnv.MoveTo(btn.Right-1,btn.Top);
  cnv.LineTo(btn.Left,btn.Top);
  cnv.LineTo(btn.Left,btn.Bottom);
  cnv.Pen.Color := clBtnText;
  cnv.MoveTo(btn.Right,btn.Top);
  cnv.LineTo(btn.Right,btn.Bottom);
  cnv.LineTo(btn.Left,btn.Bottom);
  cnv.Pen.Color := clBtnShadow;
  cnv.MoveTo(btn.Right-1,btn.Top+1);
  cnv.LineTo(btn.Right-1,btn.Bottom-1);
  cnv.LineTo(btn.Left+1,btn.Bottom-1);
  if ((ExStyle and WS_EX_DLGMODALFRAME)=0) then
    begin
    btn := Rect(pos.Right-BWid+btnZoom[0],
              BWid+btnZoom[1],
              pos.Right-BWid+btnZoom[2],
              BWid+btnZoom[3]);
    Glyph := TBitmap.Create;
    if (tZoomed) then
      Glyph.Handle := LoadBitmap(HInstance,'btnRestore')
    else
      Glyph.Handle := LoadBitmap(HInstance,'btnZoom');
    cnv.FillRect(btn);
    cnv.Draw(btn.Left+1,btn.Top+1,Glyph);
    Glyph.Free;
    cnv.Pen.Color := clBtnHighLight;
    cnv.MoveTo(btn.Right-1,btn.Top);
    cnv.LineTo(btn.Left,btn.Top);
    cnv.LineTo(btn.Left,btn.Bottom);
    cnv.Pen.Color := clBtnText;
    cnv.MoveTo(btn.Right,btn.Top);
    cnv.LineTo(btn.Right,btn.Bottom);
    cnv.LineTo(btn.Left,btn.Bottom);
    cnv.Pen.Color := clBtnShadow;
    cnv.MoveTo(btn.Right-1,btn.Top+1);
    cnv.LineTo(btn.Right-1,btn.Bottom-1);
    cnv.LineTo(btn.Left+1,btn.Bottom-1);

    btn := Rect(pos.Right-BWid+btnMinim[0],
              BWid+btnMinim[1],
              pos.Right-BWid+btnMinim[2],
              BWid+btnMinim[3]);
    Glyph := TBitmap.Create;
    Glyph.Handle := LoadBitmap(HInstance,'btnMinimize');
    cnv.FillRect(btn);
    cnv.Draw(btn.Left+1,btn.Top+1,Glyph);
    Glyph.Free;
    cnv.Pen.Color := clBtnHighLight;
    cnv.MoveTo(btn.Right-1,btn.Top);
    cnv.LineTo(btn.Left,btn.Top);
    cnv.LineTo(btn.Left,btn.Bottom);
    cnv.Pen.Color := clBtnText;
    cnv.MoveTo(btn.Right,btn.Top);
    cnv.LineTo(btn.Right,btn.Bottom);
    cnv.LineTo(btn.Left,btn.Bottom);
    cnv.Pen.Color := clBtnShadow;
    cnv.MoveTo(btn.Right-1,btn.Top+1);
    cnv.LineTo(btn.Right-1,btn.Bottom-1);
    cnv.LineTo(btn.Left+1,btn.Bottom-1);
  end;
end;

ReleaseDC(Handle,cnv.Handle);
cnv.Handle := 0;
cnv.Free;
end;

procedure BevelCapButton(button: Integer; d: Boolean; window: HWnd);
var
  cnv: TCanvas;
  btn, pos: TRect;
  BWid: Integer;
  Style,ExStyle: Longint;
  Glyph: TBitmap;
begin
Style := GetWindowLong(window,GWL_STYLE);
ExStyle := GetWindowLong(window,GWL_EXSTYLE);
cnv := TCanvas.Create;
cnv.Handle := GetWindowDC(window);
GetWindowRect(window,pos);
pos := Rect(0,0,pos.Right-pos.Left-1,pos.Bottom-pos.Top-1);
Glyph:= TBitmap.Create;
if (Style and WS_THICKFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXFRAME)
else if (ExStyle and WS_EX_DLGMODALFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXDLGFRAME)+1
else
  BWid := 1;
if (button=0) then
  begin
  btn := Rect(pos.Right-BWid+btnClose[0],
            BWid+btnClose[1],
            pos.Right-BWid+btnClose[2],
            BWid+btnClose[3]);
  Glyph.Handle := LoadBitmap(HInstance,'btnClose');
  end
else if (button=1) then
  begin
  btn := Rect(pos.Right-BWid+btnZoom[0],
            BWid+btnZoom[1],
            pos.Right-BWid+btnZoom[2],
            BWid+btnZoom[3]);
  if (IsZoomed(Window)) then
      Glyph.Handle := LoadBitmap(HInstance,'btnRestore')
  else
      Glyph.Handle := LoadBitmap(HInstance,'btnZoom');
  end
else if (button=2) then
  begin
  btn := Rect(pos.Right-BWid+btnMinim[0],
            BWid+btnMinim[1],
            pos.Right-BWid+btnMinim[2],
            BWid+btnMinim[3]);
  Glyph.Handle := LoadBitmap(HInstance,'btnMinimize');
  end;
if (d) then cnv.Pen.Color := clBtnText
else cnv.Pen.Color := clBtnHighLight;
cnv.MoveTo(btn.Right-1,btn.Top);
cnv.LineTo(btn.Left,btn.Top);
cnv.LineTo(btn.Left,btn.Bottom);
if (d) then cnv.Pen.Color := clBtnHighLight
else cnv.Pen.Color := clBtnText;
cnv.MoveTo(btn.Right,btn.Top);
cnv.LineTo(btn.Right,btn.Bottom);
cnv.LineTo(btn.Left,btn.Bottom);
if (d) then cnv.Pen.Color := clBtnFace
else cnv.Pen.Color := clBtnShadow;
cnv.MoveTo(btn.Right-1,btn.Top+1);
cnv.LineTo(btn.Right-1,btn.Bottom-1);
cnv.LineTo(btn.Left+1,btn.Bottom-1);
if (d) then cnv.Pen.Color := clBtnShadow
else cnv.Pen.Color := clBtnFace;
cnv.MoveTo(btn.Left+1,btn.Bottom-2);
cnv.LineTo(btn.Left+1,btn.Top+1);
cnv.LineTo(btn.Right-2,btn.Top+1);
if (d) then
  begin
  Inc(btn.Left);
  Inc(btn.Top);
  end;
cnv.Brush.Color := clBtnFace;
cnv.Font.Color := clBtnText;
cnv.Draw(btn.Left+1,btn.Top+1,Glyph);
Glyph.Free;
ReleaseDC(window,cnv.Handle);
cnv.Handle := 0;
cnv.Free;
end;

procedure TExtForm.WMNCActivate(var Message: TMessage);
begin
inherited;
if NewStyleControls then Exit;
if csDestroying in ComponentState then Exit;
tActive := Message.WParam<>0;
{WMNCPaint(Message);}
Perform(WM_NCPAINT,0,0);
end;

procedure TExtForm.WMNCLBtnUp(var Message: TMessage);
const
  EnableFlags: array[Boolean] of Word = (MF_GRAYED, MF_ENABLED);
var
  BWid, IWid: Integer;
  x,y: Word;
  i: HMenu;
  Style: Longint;
  Zoomed, Iconic, E: Boolean;
  pos: TRect;
  ExStyle: Longint;
begin
if NewStyleControls or IsIconic(Handle) or (csDestroying in ComponentState) then
  begin
  inherited;
  Exit;
  end;
Style := GetWindowLong(Handle,GWL_STYLE);
ExStyle := GetWindowLong(Handle,GWL_EXSTYLE);
x := LoWord(Message.LParam)-Left;
y := HiWord(Message.LParam)-Top;
GetWindowRect(Handle,pos);
pos := Rect(0,0,pos.Right-pos.Left-1,pos.Bottom-pos.Top-1);
if (Style and WS_THICKFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXFRAME)
else if (ExStyle and WS_EX_DLGMODALFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXDLGFRAME)+1
else
  BWid := 1;
if (Style and WS_CAPTION)<> 0 then
  IWid := GetSystemMetrics(SM_CYCAPTION)-GetSystemMetrics(SM_CYBORDER)
else
  IWid := 0;
if (x>=BWid) and (x<=BWid+IWid) and
   (y>=BWid) and (y<=BWid+IWid) then
   begin
   i := GetSystemMenu(Handle,False);
   Zoomed := IsZoomed(Handle);
   Iconic := IsIconic(Handle);
   E := IsWindowEnabled(Handle);
   EnableMenuItem(i, SC_RESTORE, MF_BYCOMMAND or EnableFlags[E and (Zoomed or Iconic)]);
   EnableMenuItem(i, SC_MOVE, MF_BYCOMMAND or EnableFlags[E and not Zoomed]);
   EnableMenuItem(i, SC_SIZE, MF_BYCOMMAND or EnableFlags[E and not (Zoomed
              or Iconic or (Style and WS_THICKFRAME = 0))]);
   EnableMenuItem(i, SC_MINIMIZE, MF_BYCOMMAND or EnableFlags[E and not Iconic
              and (Style and WS_MINIMIZEBOX <> 0)]);
   EnableMenuItem(i, SC_MAXIMIZE, MF_BYCOMMAND or EnableFlags[E and not Zoomed
              and (Style and WS_MAXIMIZEBOX <> 0)]);
   EnableMenuItem(i, SC_CLOSE, MF_BYCOMMAND or EnableFlags[E]);
   SendMessage(Handle, WM_INITMENUPOPUP, i, MakeLong(0, 1));
   TrackPopupMenu(i,0,{x+}Left+BWid,{y+}Top+BWid+IWid,0,HelperWindow,nil);
   Exit;
   end;
if (btn<>-1) then
   BevelCapButton(btn,false,Handle);
if (x>=pos.Right-BWid+btnClose[0]) and (x<=pos.Right-BWid+btnClose[2]) and
   (y>=BWid+btnClose[1]) and (y<=BWid+btnClose[3]) then
   begin
   if (btn=0) then PostMessage(Handle,WM_SYSCOMMAND,SC_CLOSE,0);
   Exit;
   end;
if ((ExStyle and WS_EX_DLGMODALFRAME)=0) then
  begin
  if (x>=pos.Right-BWid+btnMinim[0]) and (x<=pos.Right-BWid+btnMinim[2]) and
     (y>=BWid+btnMinim[1]) and (y<=BWid+btnMinim[3]) then
     begin
     if (btn=2) then PostMessage(Handle,WM_SYSCOMMAND,SC_MINIMIZE,0);
     Exit;
     end;
  if (x>=pos.Right-BWid+btnZoom[0]) and (x<=pos.Right-BWid+btnZoom[2]) and
     (y>=BWid+btnZoom[1]) and (y<=BWid+btnZoom[3]) then
     begin
     if (btn<>1) then Exit;
     if IsZoomed(Handle) then
       PostMessage(Handle,WM_SYSCOMMAND,SC_RESTORE,0)
     else
       PostMessage(Handle,WM_SYSCOMMAND,SC_MAXIMIZE,0);
     Exit;
     end;
  end;
inherited;
{ShowMessage(Format('X: %d'#13'Y: %d',[x,y]));}
end;

procedure TExtForm.WMNCLBtnDown(var Message: TMessage);
var
  BWid, IWid: Integer;
  x,y: Word;
  pos: TRect;
  Style,ExStyle: Longint;
  cmd: Word;
begin
if NewStyleControls or IsIconic(Handle) or (csDestroying in ComponentState) then
  begin
  inherited;
  Exit;
  end;
Style := GetWindowLong(Handle,GWL_STYLE);
ExStyle := GetWindowLong(Handle,GWL_EXSTYLE);
x := LoWord(Message.LParam)-Left;
y := HiWord(Message.LParam)-Top;
GetWindowRect(Handle,pos);
pos := Rect(0,0,pos.Right-pos.Left-1,pos.Bottom-pos.Top-1);
if (Style and WS_THICKFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXFRAME)-GetSystemMetrics(SM_CYBORDER)
else if (ExStyle and WS_EX_DLGMODALFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXDLGFRAME)
else
  BWid := 0;
if (Style and WS_CAPTION)<> 0 then
  IWid := GetSystemMetrics(SM_CYCAPTION)
else
  IWid := 0;
if (x>=BWid) and (x<=BWid+IWid) and
   (y>=BWid) and (y<=BWid+IWid) then
   Exit;
if {(y>=BWid+IWid) or (y<=BWid) or
   (x<=BWid) or (x>=Width-BWid)}
   {WM_NCRBUTTONDOWN}
   Message.WParam in [HTBOTTOM,HTBOTTOMLEFT,HTBOTTOMRIGHT,HTLEFT,HTRIGHT,HTTOP,HTTOPLEFT,HTTOPRIGHT] then
   begin
   case Message.WParam of
     HTBOTTOM: Cmd := SC_SIZEBOTTOM;
     HTBOTTOMLEFT: Cmd := SC_SIZEBOTTOMLEFT;
     HTBOTTOMRIGHT: Cmd := SC_SIZEBOTTOMRIGHT;
     HTLEFT: Cmd := SC_SIZELEFT;
     HTRIGHT: Cmd := SC_SIZERIGHT;
     HTTOP: Cmd := SC_SIZETOP;
     HTTOPLEFT: Cmd := SC_SIZETOPLEFT;
     HTTOPRIGHT: Cmd := SC_SIZETOPRIGHT;
     else Cmd := 0;
   end;
   Perform(WM_SYSCOMMAND, Cmd, 0);
   Exit;
   end;
if (y>BWid+IWid) and (y<Height-BWid) and
   (x>BWid) and (x<Width-BWid) then
  begin
  inherited;
  Exit;
  end;
if (x>=pos.Right-BWid+btnClose[0]) and (x<=pos.Right-BWid+btnClose[2]) and
   (y>=BWid+btnClose[1]) and (y<=BWid+btnClose[3]) then
   begin
   BevelCapButton(0,true,Handle);
   btn := 0;
   Exit;
   end;
if ((ExStyle and WS_EX_DLGMODALFRAME)=0) then
  begin
  if (x>=pos.Right-BWid+btnMinim[0]) and (x<=pos.Right-BWid+btnMinim[2]) and
     (y>=BWid+btnMinim[1]) and (y<=BWid+btnMinim[3]) then
     begin
     BevelCapButton(2,true,Handle);
     btn := 2;
     Exit;
     end;
  if (x>=pos.Right-BWid+btnZoom[0]) and (x<=pos.Right-BWid+btnZoom[2]) and
     (y>=BWid+btnZoom[1]) and (y<=BWid+btnZoom[3]) then
     begin
     BevelCapButton(1,true,Handle);
     btn := 1;
     Exit;
     end;
  end;
if not IsZoomed(Handle) then
  PostMessage(Handle,WM_SYSCOMMAND,SC_DRAGMOVE,
            (((x+Left)and $FFFF)shl 16) or ((y+Top)and $FFFF) );
end;

procedure TExtForm.WMNCRBtnDown(var Message: TMessage);
begin
inherited;
end;

procedure TExtForm.WMNCMouseMove(var Message: TMessage);
var
  BWid, IWid: Integer;
  x,y: Word;
  pos: TRect;
  Style,ExStyle: Longint;
begin
if NewStyleControls or IsIconic(Handle) or (csDestroying in ComponentState) then
  begin
  inherited;
  Exit;
  end;
Style := GetWindowLong(Handle,GWL_STYLE);
ExStyle := GetWindowLong(Handle,GWL_EXSTYLE);
x := LoWord(Message.LParam)-Left;
y := HiWord(Message.LParam)-Top;
GetWindowRect(Handle,pos);
pos := Rect(0,0,pos.Right-pos.Left-1,pos.Bottom-pos.Top-1);
if (Style and WS_THICKFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXFRAME)
else if (ExStyle and WS_EX_DLGMODALFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXDLGFRAME)+1
else
  BWid := 1;
if (Style and WS_CAPTION)<> 0 then
  IWid := GetSystemMetrics(SM_CYCAPTION)-GetSystemMetrics(SM_CYBORDER)
else
  IWid := 0;
if (x>=BWid) and (x<=BWid+IWid) and
   (y>=BWid) and (y<=BWid+IWid) then
   begin
   if (btn<>-1) then
    begin
    BevelCapButton(btn,false,Handle);
    btn := -1;
    end;
   Message.WParam := HTSYSMENU;
   Exit;
   end;
if (y>=BWid+IWid) or (y<=BWid) or
   (x<=BWid) or (x>=Width-BWid) then
   begin
   if (btn<>-1) then
    begin
    BevelCapButton(btn,false,Handle);
    btn := -1;
    end;
   inherited;
   Exit;
   end;
if (x>=pos.Right-BWid+btnClose[0]) and (x<=pos.Right-BWid+btnClose[2]) and
   (y>=BWid+btnClose[1]) and (y<=BWid+btnClose[3]) then
   begin
   if (btn<>0) and (btn<>-1) then
    begin
    BevelCapButton(btn,false,Handle);
    btn := -1;
    end;
   Message.WParam := HTSYSMENU;
   Exit;
   end;
if ((ExStyle and WS_EX_DLGMODALFRAME)=0) then
  begin
  if (x>=pos.Right-BWid+btnMinim[0]) and (x<=pos.Right-BWid+btnMinim[2]) and
     (y>=BWid+btnMinim[1]) and (y<=BWid+btnMinim[3]) then
     begin
     if (btn<>2) and (btn<>-1) then
      begin
      BevelCapButton(btn,false,Handle);
      btn := -1;
      end;
     Message.WParam := HTMINBUTTON;
     Exit;
     end;
  if (x>=pos.Right-BWid+btnZoom[0]) and (x<=pos.Right-BWid+btnZoom[2]) and
     (y>=BWid+btnZoom[1]) and (y<=BWid+btnZoom[3]) then
     begin
     if (btn<>1) and (btn<>-1) then
         begin
      BevelCapButton(btn,false,Handle);
      btn := -1;
      end;
     Message.WParam := HTMAXBUTTON;
     Exit;
     end;
  end;
Message.WParam := HTCAPTION;
if (btn<>-1) then
    begin
    BevelCapButton(btn,false,Handle);
    btn := -1;
    end;
end;

procedure TExtForm.WMNCRBtnUp(var Message: TMessage);
const
  EnableFlags: array[Boolean] of Word = (MF_GRAYED, MF_ENABLED);
var
  BWid, IWid: Integer;
  x,y: Word;
  i: HMenu;
  Zoomed, Iconic, E: Boolean;
  pos: TRect;
  Style,ExStyle: Longint;
begin
if NewStyleControls or IsIconic(Handle) or (csDestroying in ComponentState) then
  begin
  inherited;
  Exit;
  end;
Style := GetWindowLong(Handle,GWL_STYLE);
ExStyle := GetWindowLong(Handle,GWL_EXSTYLE);
x := LoWord(Message.LParam)-Left;
y := HiWord(Message.LParam)-Top;
GetWindowRect(Handle,pos);
pos := Rect(0,0,pos.Right-pos.Left-1,pos.Bottom-pos.Top-1);
if (Style and WS_THICKFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXFRAME)
else if (ExStyle and WS_EX_DLGMODALFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXDLGFRAME)+1
else
  BWid := 1;
IWid := GetSystemMetrics(SM_CYCAPTION)-GetSystemMetrics(SM_CYBORDER);
if (x>=pos.Right-BWid+btnClose[0]) and (x<=pos.Right-BWid+btnClose[2]) and
   (y>=BWid+btnClose[1]) and (y<=BWid+btnClose[3]) then
   Exit;
if ((ExStyle and WS_EX_DLGMODALFRAME)=0) then
  begin
  if (x>=pos.Right-BWid+btnMinim[0]) and (x<=pos.Right-BWid+btnMinim[2]) and
     (y>=BWid+btnMinim[1]) and (y<=BWid+btnMinim[3]) then
     Exit;
  if (x>=pos.Right-BWid+btnZoom[0]) and (x<=pos.Right-BWid+btnZoom[2]) and
     (y>=BWid+btnZoom[1]) and (y<=BWid+btnZoom[3]) then
     Exit;
  end;
if (x<BWid) or (x>pos.Right-BWid) then
   Exit;
if (y<BWid) or (y>BWid+IWid) then
   Exit;
{if (x>BWid) and (x<=BWid+IWid) and
   (y>BWid) and (y<=BWid+IWid) then}
   begin
   i := GetSystemMenu(Handle,False);
   Zoomed := IsZoomed(Handle);
   Iconic := IsIconic(Handle);
   E := IsWindowEnabled(Handle);
   EnableMenuItem(i, SC_RESTORE, MF_BYCOMMAND or EnableFlags[E and (Zoomed or Iconic)]);
   EnableMenuItem(i, SC_MOVE, MF_BYCOMMAND or EnableFlags[E and not Zoomed]);
   EnableMenuItem(i, SC_SIZE, MF_BYCOMMAND or EnableFlags[E and not (Zoomed
              or Iconic or (Style and WS_THICKFRAME = 0))]);
   EnableMenuItem(i, SC_MINIMIZE, MF_BYCOMMAND or EnableFlags[E and not Iconic
              and (Style and WS_MINIMIZEBOX <> 0)]);
   EnableMenuItem(i, SC_MAXIMIZE, MF_BYCOMMAND or EnableFlags[E and not Zoomed
              and (Style and WS_MAXIMIZEBOX <> 0)]);
   EnableMenuItem(i, SC_CLOSE, MF_BYCOMMAND or EnableFlags[E]);
   SendMessage(Handle, WM_INITMENUPOPUP, i, MakeLong(0, 1));
   TrackPopupMenu(i,0,x+Left,y+Top,0,HelperWindow,nil);
   Exit;
   end;
inherited;
end;

procedure TExtForm.WMNCLDblClick(var Message: TMessage);
var
  BWid, IWid: Integer;
  x,y: Word;
begin
if NewStyleControls or IsIconic(Handle) or (csDestroying in ComponentState) then
  begin
  inherited;
  Exit;
  end;
x := LoWord(Message.LParam)-Left;
y := HiWord(Message.LParam)-Top;
if (GetWindowLong(Handle,GWL_STYLE) and WS_THICKFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXFRAME)
else if (GetWindowLong(Handle,GWL_EXSTYLE) and WS_EX_DLGMODALFRAME) <> 0 then
  BWid := GetSystemMetrics(SM_CXDLGFRAME)+1
else
  BWid := 1;
IWid := GetSystemMetrics(SM_CYCAPTION)-GetSystemMetrics(SM_CYBORDER);
if (x>BWid) and (x<=BWid+IWid) and
   (y>BWid) and (y<=BWid+IWid) then
   begin
   PostMessage(Handle,WM_CLOSE,0,0);
   Exit;
   end;
inherited;
end;

procedure TExtForm.WMSetText(var Message: TMessage);
begin
inherited;
if NewStyleControls or (csDestroying in ComponentState) then
  Exit;
Perform(WM_NCPAINT,0,1);
end;

{$R capbtns.res}

constructor TExtForm.Create(AOwner: TComponent);
begin
btn := -1;
FNoDefNCPaint := false;
FSmallIcon := TBitmap.Create;
inherited Create(AOwner);
HelperWindow := AllocateHWnd(SysMenuWndProc);
end;

destructor TExtForm.Destroy;
begin
DeallocateHWnd(HelperWindow);
FSmallIcon.Free;
inherited Destroy;
end;

procedure TExtForm.UpdateIcon;
var
  Message: TMEssage;
begin
{Perform(WM_NCPAINT,0,1);}
Message.Msg := WM_NCPAINT;
Message.WParam := 0;
Message.LParam := 1;
WMNCPaint(Message);
end;

procedure TExtForm.SetSmallIcon(AGlyph: TBitmap);
begin
FSmallIcon.Assign(AGlyph);
if NewStyleControls then
  begin
  SendMessage(Handle,$80{WM_SETICON}, {ICON_SMALL}0, FSmallIcon.Handle);
  Exit;
  end;
UpdateIcon;
end;

procedure TExtForm.SysMenuWndProc(var Message: TMessage);
begin
  with Message do
    if (Msg = WM_COMMAND) then
    begin
      PostMessage(Handle, WM_SYSCOMMAND, wParam, lParam);
      Result := 0;
    end
    else Result := DefWindowProc(HelperWindow, Msg, wParam, lParam);
end;

end.

