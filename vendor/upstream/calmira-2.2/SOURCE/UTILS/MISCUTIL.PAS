{*********************************************************}
{                                                         }
{    Calmira System Library 2.2                           }
{    by Li-Hsin Huang,                                    }
{    released into the public domain July 1998            }
{                                                         }
{*********************************************************}
                                     
unit MiscUtil;

{ Some useful Delphi and Windows routines }

interface

uses Classes, SysUtils, Forms, WinTypes, IniFiles, Menus,
  StdCtrls, Dialogs, ExtCtrls, Graphics, TabNotBk, Controls;

const
  MsgDialogSounds : Boolean = False;
  MaxHistorySize  : Integer = 24;

function Min(a, b: Integer): Integer;
function Max(a, b: Integer): Integer;
{ Returns the smaller and larger of two values respectively }

function Range(n, lower, upper: Integer): Integer;
{ Constrains n to a lower and upper limit }

function Sign(x: Integer) : Integer;
{ Returns 1 if x > 0, -1 if x < 0 and 0 if x = 0 }

procedure Border3d(Canvas : TCanvas; Width, Height: Integer);
{ Draws a raised 3D border on a canvas, typically used in an
  OnPaint method of a TForm }

procedure ErrorMsg(const msg: string);
{ Displays a message dialog box indicating an error }

procedure ErrorMsgRes(Ident: Word);

procedure ErrorMsgResFmt(Ident: Word; const Args : array of const);

procedure PlaySound(const filename: TFilename);
{ Plays the specified WAV file as a sound effect.  If the filename
  is <None>, nothing is played }

function Intersects(const R, S: TRect): Boolean;
{ Returns True if the two rectangles intersect }

function NormalizeRect(p, q: TPoint): TRect;
{ Returns a rectangle defined by any two points.  When dragging a
  selection box with a mouse, the fixed corner and the moving
  corner may not always be top left and bottom right respectively.
  This function creates a valid TRect out of them }

function TimeStampToDate(FileDate: Longint): TDateTime;
{ Converts a DOS timestamp to TDateTime.  If the timestamp is invalid
  (some programs use invalid stamps as markers), the current date
  is returned instead of raising EConvertError }

function GetRegValue(key : string): string;
{ Returns a value from the Windows registration database, with the
  specified key from HKEY_CLASSES_ROOT }

function GetRadioIndex(const R: array of TRadioButton): Integer;
procedure SetRadioIndex(const R: array of TRadioBUtton; index: Integer);
function GetMenuCheck(const M: array of TMenuItem): Integer;
procedure SetMenuCheck(const M: array of TMenuItem; index: Integer);
{ These routines are useful for setting and querying the state of
  several controls.  Use them to simulate arrays and as an alternative
  to TRadioGroup. }

procedure RefreshCursor;
{ Updates the cursor image when you have changed the Cursor or DragCursor
  property of a control }

procedure UpdateScreen;

procedure ShowHourGlass;
{ Displays the hourglass cursor immediately }

procedure ShowArrow;
{ Displays the standard arrow }

function AddHistory(Combo : TComboBox): Boolean;
{ Adds a combo box's Text string to its listbox, but only if the
  string is not empty and not already present in the list.  The item is
  inserted at the top of the list, and if there are more than 24 items,
  the bottom one is removed.  Returns true if the list is modified }

procedure AssignHistoryText(Combo : TCombobox; const NewText: string);

function MsgDialog(const Msg: string; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons; HelpCtx: Longint): Word;
{ Calls the MessageDialog function, but also plays a suitable sound
  effect from the Control Panel settings.  The MsgDialogSounds variable
  enables the sounds }

function MsgDialogRes(Ident : Word; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons; HelpCtx: Longint): Word;

function MsgDialogResFmt(Ident : Word; const Args: array of const;
  AType: TMsgDlgType; AButtons: TMsgDlgButtons; HelpCtx: Longint): Word;

function ShowModalDialog(FormClass : TFormClass): TModalResult;
{ A very simple way of displaying a dynamic modal form -- just pass the
  form's class name e.g. TForm1, and an instance will be created,
  shown as a modal dialog and then destroyed. }

function InitBitmap(ABitmap: TBitmap;
  AWidth, AHeight : Integer; Color : TColor) : TBitmap;
{ Initialises the bitmap's dimensions and fills it with the chosen colour }

procedure ShrinkIcon(H : HIcon; Glyph : TBitmap);
{ Shrinks a 32 x 32 icon down to a 16 x 16 bitmap }

procedure CopyStringsToClipboard(strings : TStrings);

function ShortTimeToStr(Time : TDateTime) : string;

procedure FreePageHandles(Notebook : TNotebook);

function GetTimerCount : Longint;

procedure RecessBevel(Canvas: TCanvas; R: TRect);

function GetMinPosition(Wnd: HWND): TPoint;

procedure MoveDesktopIcon(Wnd: HWND; pt: TPoint);

procedure GetHeaderDivisions(H: THeader; A: array of PInteger);

procedure Beep;

procedure EnableControlList(C: array of TControl; Enable : Boolean);

const
  RepaintBeforeHourglass : Integer = 1;
  DarkIconStretch : Boolean = False;

implementation

uses WinProcs, MMSystem, ShellAPI, Strings, FileCtrl, Clipbrd, ToolHelp;


function Min(a, b: Integer): Integer; assembler;
asm
  MOV	AX, a
  CMP	AX, b
  JLE	@@1
  MOV	AX, b
@@1:
end;


function Max(a, b: Integer): Integer; assembler;
asm
  MOV	AX, a
  CMP	AX, b
  JGE	@@1
  MOV	AX, b
@@1:
end;

function Range(n, lower, upper: Integer): Integer; assembler;
asm
   MOV  AX, n
   CMP  AX, lower
   JGE  @@1
   MOV  AX, lower
   JMP  @finish
@@1:
   CMP  AX, upper
   JLE  @finish
   MOV  AX, upper
   JMP  @finish
@@2:
   MOV  AX, lower
@finish:
end;


function Sign(x: Integer) : Integer; assembler;
asm
   MOV  AX, X
   CMP  AX, 0
   JL   @@1
   JG   @@2
   XOR  AX, AX
   JMP  @finish
@@1:
   MOV  AX, -1
   JMP  @finish
@@2:
   MOV  AX, 1
@finish:
end;



procedure Border3d(Canvas : TCanvas; Width, Height: Integer);
begin
  with Canvas do begin
    Pen.Color := clBtnHighLight;
    MoveTo(0, Height);
    LineTo(0, 0);
    LineTo(Width, 0);
    Pen.Color := clBtnShadow;
    LineTo(Width, Height);
    LineTo(0, Height);
  end;
end;


procedure ErrorMsg(const msg: string);
begin
  MsgDialog(msg, mtError, [mbOK], 0);
end;

procedure ErrorMsgRes(Ident: Word);
begin
  MsgDialog(LoadStr(Ident), mtError, [mbOK], 0);
end;

procedure ErrorMsgResFmt(Ident: Word; const Args : array of const);
begin
  MsgDialog(FmtLoadStr(Ident, Args), mtError, [mbOK], 0);
end;





procedure PlaySound(const filename: TFilename);
var s: TFilename;
begin
  if CompareText(filename, '<None>') <> 0 then
    SndPlaySound(StrPCopy(@s, filename), SND_ASYNC or SND_NODEFAULT);
end;



function Intersects(const R, S: TRect): Boolean;
var dummy: TRect;
begin
  Result := IntersectRect(dummy, R, S) <> 0;
end;

function NormalizeRect(p, q: TPoint): TRect; assembler;
asm
  MOV  AX, p.x
  MOV  BX, p.y
  MOV  CX, q.x
  MOV  DX, q.y
  CMP  AX, CX
  JLE  @@1
  XCHG AX, CX
@@1:
  CMP  BX, DX
  JLE  @@2
  XCHG BX, DX
@@2:
  LES  DI, @Result
  MOV  TRect(ES:[DI]).Left, AX
  MOV  TRect(ES:[DI]).Top, BX
  MOV  TRect(ES:[DI]).Right, CX
  MOV  TRect(ES:[DI]).Bottom, DX
end;



function TimeStampToDate(FileDate: Longint): TDateTime;
begin
  try Result := FileDateToDateTime(FileDate)
  except on EConvertError do Result := Date;
  end;
end;

function GetRegValue(key : string): string;
var cb : Longint;
begin
  cb := 255;
  if RegQueryValue(HKEY_CLASSES_ROOT, StringAsPChar(key),
     @Result[1], cb) = ERROR_SUCCESS then
    Result[0] := Chr(cb-1)
  else
    Result := '';
end;


function GetRadioIndex(const R: array of TRadioButton): Integer;
var i: Integer;
begin
  for i := 0 to High(R) do
    if R[i].Checked then begin
      Result := i;
      exit;
    end;
  Result := 0;
end;


procedure SetRadioIndex(const R: array of TRadioBUtton; index: Integer);
var i: Integer;
begin
  for i := 0 to High(R) do R[i].Checked := i = index;
end;


function GetMenuCheck(const M: array of TMenuItem): Integer;
begin
  for Result := 0 to High(M) do if M[Result].Checked then Exit;
  Result := 0;
end;


procedure SetMenuCheck(const M: array of TMenuItem; index: Integer);
var i: Integer;
begin
  for i := 0 to High(M) do M[i].Checked := i = index;
end;


procedure RefreshCursor;
var p: TPoint;
begin
  GetCursorPos(p);
  SetCursorPos(p.x, p.y);
end;


function DoUpdateWindow(Wnd: HWND; lParam : Longint): Bool ; export;
begin
  UpdateWindow(Wnd);
  Result := True;
end;

procedure UpdateScreen;
begin
  case RepaintBeforeHourglass of
    1: EnumTaskWindows(GetCurrentTask, @DoUpdateWindow, 0);
    2: EnumWindows(@DoUpdateWindow, 0);
  end;
end;


procedure ShowHourGlass;
begin
  UpdateScreen;
  SetCursor(LoadCursor(0, IDC_WAIT));
end;

procedure ShowArrow;
begin
  SetCursor(LoadCursor(0, IDC_ARROW));
end;



function AddHistory(Combo : TComboBox): Boolean;
var
  i : Integer;
  s : string;
begin
  Result := False;
  with Combo, Combo.Items do
    if Text <> '' then begin
      i := IndexOf(Text);
      if i = -1 then begin
        Result := True;
        Insert(0, Text)
      end
      else if i > 0 then begin
        Result := True;
        s := Text;
        Delete(i);
        Insert(0, s);
        Text := s;
        { same as Exchange(i, 0), but Exchange can clear the
          Text property if the text is the string at i }
      end;

      while (Count > 0) and (Count > MaxHistorySize) do begin
        Result := True;
        Delete(Count-1);
      end;
    end;
end;

procedure AssignHistoryText(Combo : TCombobox; const NewText: string);
begin
  with Combo do begin
    if NewText > '' then Text := NewText;
    if (Text = '') and (Items.Count >= 1) then Text := Items[0];
  end;
end;


function MsgDialog(const Msg: string; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons; HelpCtx: Longint): Word;
const
  Sound : array[TMsgDlgType] of Word =
    (MB_ICONEXCLAMATION, MB_ICONHAND, MB_OK, MB_ICONQUESTION, 0);
begin
  if MsgDialogSounds and (AType < mtCustom) then MessageBeep(Sound[AType]);
  Result := MessageDlg(Msg, AType, AButtons, HelpCtx);
end;

function MsgDialogRes(Ident : Word; AType: TMsgDlgType;
  AButtons: TMsgDlgButtons; HelpCtx: Longint): Word;
begin
  Result := MsgDialog(LoadStr(Ident), AType, AButtons, HelpCtx);
end;

function MsgDialogResFmt(Ident : Word; const Args: array of const;
  AType: TMsgDlgType; AButtons: TMsgDlgButtons; HelpCtx: Longint): Word;
begin
  Result := MsgDialog(FmtLoadStr(Ident, Args), AType, AButtons, HelpCtx);
end;



function ShowModalDialog(FormClass : TFormClass): TModalResult;
begin
  ShowHourGlass;
  with FormClass.Create(Application) do
  try
    Result := ShowModal;
  finally
    Free;
  end;
end;


function InitBitmap(ABitmap: TBitmap;
  AWidth, AHeight : Integer; Color : TColor) : TBitmap;
begin
  { initializes a bitmap with width, height and background colour }

  with ABitmap do begin
    Width := AWidth;
    Height := AHeight;
    Canvas.Brush.Color := Color;
    Canvas.FillRect(Rect(0, 0, Width, Height));
  end;
  Result := ABitmap;
end;


procedure ShrinkIcon(H : HIcon; Glyph : TBitmap);
const
  DarkStretch : array[Boolean] of Integer =
    (STRETCH_DELETESCANS, STRETCH_ANDSCANS);
var
  bmp : TBitmap;
  i, j : Integer;
  src, dest : HDC;
  OldStretch : Integer;
begin
  bmp := InitBitmap(TBitmap.Create, 32, 32, clSilver);
  DrawIcon(bmp.Canvas.Handle, 0, 0, H);

  try
    with Glyph do begin
      Width := 16;
      Height := 16;

      src := bmp.Canvas.Handle;
      dest := Canvas.Handle;

      OldStretch := SetStretchBltMode(dest, DarkStretch[DarkIconStretch]);
      StretchBlt(dest, 0, 0, 16, 16, src, 0, 0, 32, 32, SRCCOPY);

      for i := 0 to 15 do
        for j := 0 to 15 do
         if GetPixel(dest, i, j) = clSilver then
           SetPixel(dest, i, j, GetPixel(src, i shl 1, j shl 1));

      Canvas.Pixels[0, 15] := clBtnFace;
      SetStretchBltMode(dest, OldStretch);
    end;
  finally
    bmp.Free;
  end;
end;

procedure CopyStringsToClipboard(strings : TStrings);
var
  P: PChar;
begin
  P := strings.GetText;
  Clipboard.SetTextBuf(P);
  StrDispose(P);
end;

function ShortTimeToStr(Time : TDateTime) : string;
begin
  DateTimeToString(Result, ShortTimeFormat, Time);
end;


type
  TSurfaceWin = class(TWinControl);

procedure FreePageHandles(Notebook : TNotebook);
begin
  with Notebook do begin
    LockWindowUpdate(Handle);
    try
      TSurfaceWin(Pages.Objects[PageIndex]).DestroyHandle;
    finally
      LockWindowUpdate(0);
    end;
  end;
end;


function GetTimerCount : Longint;
var
  TI : TTimerInfo;
begin
  TI.dwSize := SizeOf(TI);
  TimerCount(@TI);
  Result := TI.dwmsThisVM;
end;

procedure RecessBevel(Canvas: TCanvas; R: TRect);
begin
  Frame3D(Canvas, R, clBtnShadow, clBtnHighlight, 1);
end;

{ Returns minimized icon coordinates.  Those which haven't been minimized
  before can have -1 values, in which case Windows picks a suitable
  position when required }

function GetMinPosition(Wnd: HWND): TPoint;
var place: TWindowPlacement;
begin
  place.Length := sizeof(place);
  GetWindowPlacement(Wnd, @place);
  Result := place.ptMinPosition;
end;


procedure MoveDesktopIcon(Wnd: HWND; pt: TPoint);
var
  place: TWindowPlacement;
begin
  { Repositions a window's icon.  If the window is minimized,
    it must be hidden before being moved to ensure that the
    desktop background is updated }

  place.Length := sizeof(place);
  GetWindowPlacement(Wnd, @place);
  with place.ptMinPosition do
    if (x = pt.x) and (y = pt.y) then Exit;
  place.ptMinPosition := pt;
  place.Flags := place.Flags or WPF_SETMINPOSITION;

  if IsIconic(Wnd) then begin
    ShowWindow(Wnd, SW_HIDE);
    place.ShowCmd := SW_SHOWMINNOACTIVE;
  end
  else
    place.ShowCmd := SW_SHOWNA;
  SetWindowPlacement(Wnd, @place);
end;

procedure GetHeaderDivisions(H: THeader; A: array of PInteger);
var
  i, w: Integer;
begin
  with H do begin
    i := 0;
    w := 0;
    while (i <= High(A)) and (i < Sections.Count) do begin
      Inc(w, SectionWidth[i]);
      if A[i] <> nil then A[i]^ := w;
      Inc(i);
    end;
  end;
end;


procedure Beep;
begin
  MessageBeep($FFFF);
end;

procedure EnableControlList(C: array of TControl; Enable : Boolean);
var i: Integer;
begin
  for i := 0 to High(C) do C[i].Enabled := Enable;
end;

end.
