{ Private Win16 GUI diagnostics, based on FPC rtl/win16/system.pp.
  Same RTL license and linking exception: docs/licenses/fpc-rtl-*.txt.
  Keep the full 1024-byte diagnostic capacity outside automatic DGROUP.
  Windows allocation failures use bounded stack chunks, not the Pascal heap. }
var
  ErrorBuf: PFarChar;
  ErrorLen: SizeInt;
  GuiErrorHandle: HGLOBAL;

function EnsureGuiErrorBuffer: Boolean;
begin
  if ErrorBuf = nil then
  begin
    GuiErrorHandle := GlobalAlloc(GMEM_FIXED or GMEM_ZEROINIT, ErrorBufferLength + 1);
    if GuiErrorHandle <> 0 then
    begin
      ErrorBuf := PFarChar(GlobalLock(GuiErrorHandle));
      if ErrorBuf = nil then
      begin GlobalFree(GuiErrorHandle); GuiErrorHandle := 0; end;
    end;
  end;
  EnsureGuiErrorBuffer := ErrorBuf <> nil;
end;

procedure ReleaseGuiErrorBuffer;
var Previous: HGLOBAL;
begin
  Previous := GuiErrorHandle;
  ErrorBuf := nil; ErrorLen := 0; GuiErrorHandle := 0;
  if Previous <> 0 then
  begin GlobalUnlock(Previous); GlobalFree(Previous); end;
end;

procedure ShowErrMsg;
begin
  if ErrorLen > 0 then
  begin
    if not NoErrMsg then MessageBox(0, ErrorBuf, nil, ErrorMessageBoxFlags);
    ErrorLen := 0;
  end;
end;

procedure ErrorWrite(var F: TextRec);
var Count, Consumed: SizeInt; Emergency: array[0..256] of AnsiChar;
begin
  Consumed := 0;
  if F.BufPos = 0 then Exit;
  if not EnsureGuiErrorBuffer then
  begin
    while F.BufPos > 0 do
    begin
      Count := F.BufPos; if Count > 256 then Count := 256;
      Move(PFarChar(F.BufPtr)[Consumed], Emergency[0], Count);
      Emergency[Count] := #0;
      if not NoErrMsg then MessageBox(0, @Emergency[0], nil, ErrorMessageBoxFlags);
      Inc(Consumed, Count); Dec(F.BufPos, Count);
    end;
    Exit;
  end;
  while F.BufPos > 0 do
  begin
    Count := F.BufPos;
    if Count > ErrorBufferLength - ErrorLen then Count := ErrorBufferLength - ErrorLen;
    Move(PFarChar(F.BufPtr)[Consumed], ErrorBuf[ErrorLen], Count);
    Inc(ErrorLen, Count); Inc(Consumed, Count); Dec(F.BufPos, Count);
    ErrorBuf[ErrorLen] := #0;
    if ErrorLen = ErrorBufferLength then ShowErrMsg;
  end;
end;
