program TestGUIErrorBuffer;
{$mode delphi}{$H+}
{$IFDEF WIN16}{$APPTYPE GUI}{$M 4096,2048}{$ENDIF}
uses SysUtils{$IFDEF WIN16}, WinTypes, WinProcs{$ENDIF};
type HGLOBAL = Word; PFarChar = PAnsiChar;
const
  GMEM_FIXED = 0; GMEM_ZEROINIT = $40;
  ErrorBufferLength = 1024; ErrorMessageBoxFlags = $2010;
var
  Arena: array[0..1026] of AnsiChar;
  FailAllocation, FailLock, NoErrMsg: Boolean;
  Allocations, Locks, Unlocks, Frees, Boxes: Integer;
  Captured: AnsiString;

procedure Check(Okay: Boolean; const Context: string);
begin if not Okay then raise Exception.Create(Context); end;
function GlobalAlloc(Flags: Word; Count: LongWord): HGLOBAL;
begin
  Inc(Allocations);
  Check((Flags = GMEM_ZEROINIT) and (Count = 1025), 'allocation capacity/flags');
  if FailAllocation then Result := 0 else Result := 42;
end;
function GlobalLock(Handle: HGLOBAL): Pointer;
begin
  Check(Handle = 42, 'lock handle'); Inc(Locks);
  if FailLock then Result := nil else Result := @Arena[1];
end;
function GlobalUnlock(Handle: HGLOBAL): Boolean;
begin Check(Handle = 42, 'unlock handle'); Inc(Unlocks); Result := True; end;
function GlobalFree(Handle: HGLOBAL): HGLOBAL;
begin Check(Handle = 42, 'free handle'); Inc(Frees); Result := 0; end;
function MessageBox(Owner: Word; Text, Title: PAnsiChar; Flags: Word): Integer;
begin
  Check((Owner = 0) and (Title = nil) and (Flags = ErrorMessageBoxFlags), 'message flags');
  Check(StrLen(Text) <= 1024, 'bounded terminated message');
  Inc(Boxes); Captured := Captured + StrPas(Text); Result := 1;
end;

{$I ../../src/win16/rtl_gui_error.inc}

procedure Reset;
begin
  ReleaseGuiErrorBuffer;
  Allocations := 0; Locks := 0; Unlocks := 0; Frees := 0; Boxes := 0;
  FailAllocation := False; FailLock := False; NoErrMsg := False; Captured := '';
  FillChar(Arena, SizeOf(Arena), 55);
end;
procedure Send(const Text: AnsiString);
var F: TextRec;
begin
  FillChar(F, SizeOf(F), 0); F.BufPtr := Pointer(PAnsiChar(Text)); F.BufPos := Length(Text);
  ErrorWrite(F); Check(F.BufPos = 0, 'complete consumption');
  Check((Arena[0] = #55) and (Arena[1026] = #55), 'buffer canaries');
end;
var Prefix, Suffix, LongText: AnsiString; I: Integer;
{$IFDEF WIN16}
  Log: HFILE;
const Success: array[0..12] of AnsiChar = 'RESULT PASS'#13#10;
{$ENDIF}
begin
  Reset; Check(EnsureGuiErrorBuffer and EnsureGuiErrorBuffer, 'allocation');
  Check((Allocations = 1) and (Locks = 1), 'reuse');
  Send('partial'); Check((Boxes = 0) and (ErrorLen = 7), 'buffer partial');
  ShowErrMsg; Check((Captured = 'partial') and (ErrorLen = 0), 'flush partial');
  ReleaseGuiErrorBuffer; ReleaseGuiErrorBuffer;
  Check((Unlocks = 1) and (Frees = 1) and (ErrorBuf = nil), 'release once');
  Reset; Prefix := StringOfChar('a', 1000); Suffix := '';
  for I := 1 to 100 do Suffix := Suffix + AnsiChar(33 + I mod 90);
  Send(Prefix); Send(Suffix); Check((Boxes = 1) and (ErrorLen = 76), 'split boundary');
  ShowErrMsg; Check(Captured = Prefix + Suffix, 'no repeated prefix/lost suffix');
  Reset; LongText := '';
  for I := 1 to 2500 do LongText := LongText + AnsiChar(33 + I mod 90);
  Send(LongText); ShowErrMsg;
  Check((Captured = LongText) and (Boxes = 3), 'multiple complete buffers');
  Reset; Send(StringOfChar('x', 1024)); Check((Boxes = 1) and (ErrorLen = 0), 'exact full capacity');
  Reset; NoErrMsg := True; Send(LongText); ShowErrMsg;
  Check((Boxes = 0) and (ErrorLen = 0), 'suppress full and partial messages');
  Reset; FailAllocation := True; Send(Copy(LongText, 1, 700)); ShowErrMsg;
  Check((Captured = Copy(LongText, 1, 700)) and (Boxes = 3) and (Locks = 0) and
    (GuiErrorHandle = 0), 'allocation failure retains complete text');
  Reset; FailLock := True; Send(Copy(LongText, 1, 700));
  Check((Frees = 1) and (GuiErrorHandle = 0) and (ErrorBuf = nil) and
    (Captured = Copy(LongText, 1, 700)), 'lock failure releases allocation');
  Reset; FailAllocation := True; NoErrMsg := True; Send(LongText);
  Check((Boxes = 0) and (ErrorLen = 0), 'suppressed emergency output');
  Reset;
  for I := 1 to 100 do begin Check(EnsureGuiErrorBuffer, 'cycle'); ReleaseGuiErrorBuffer; end;
  Check((Allocations = 100) and (Locks = 100) and (Unlocks = 100) and (Frees = 100), 'balanced cycles');
{$IFDEF WIN16}
  Log := _lcreat('C:\GDITEST.LOG', 0);
  if Log <> HFILE_ERROR then begin _lwrite(Log, @Success, SizeOf(Success)); _lclose(Log); end;
{$ELSE}
  WriteLn('GUI diagnostic buffer tests: OK');
{$ENDIF}
end.
