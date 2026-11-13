program TestWin16LfnFuncs;
{$mode delphi}{$H-}{$APPTYPE GUI}{$M 4096,2048}
uses WinTypes, WinProcs, SysUtils, Lfnutils;
var Failed: Boolean;
procedure LogLine(const Text: string);
var F: HFILE; S: string;
begin
  F := _lopen('C:\GDITEST.LOG', OF_WRITE);
  if F = HFILE_ERROR then F := _lcreat('C:\GDITEST.LOG', 0);
  if F = HFILE_ERROR then begin Failed := True; Exit; end;
  _llseek(F, 0, 2); S := Text + #13#10; _lwrite(F, @S[1], Length(S)); _lclose(F);
end;
procedure Check(Okay: Boolean; const Text: string);
begin
  if Okay then LogLine('PASS ' + Text)
  else begin Failed := True; LogLine('FAIL ' + Text); end;
end;
procedure CheckItems;
var S, A, B, C: string; Buffer: array[0..63] of Char; P, Rest: PChar;
begin
  S := 'one, two ,three';
  A := NextItem(S, 0, Ord(',')); B := NextItem(S, 0, Ord(',')); C := NextItem(S, 0, Ord(','));
  Check((A = 'one') and (B = 'two') and (C = 'three') and (S = ''), 'NextItem splits and trims');
  S := '"a,b",c';
  A := NextItem(S, Ord('"'), Ord(','));
  Check((A = 'a,b') and (S = 'c'), 'NextItem keeps quoted separators');
  StrPCopy(Buffer, 'x;y'); P := Buffer;
  Rest := NextItemStr(P, 0, Ord(';'));
  Check((StrPas(Rest) = 'x') and (StrPas(P) = 'y'), 'NextItemStr returns the item and advances');
end;
procedure CheckFiles;
var Rec: TLfnSearchRec; Found: Integer; H: Integer;
begin
  SetLFN(False);
  Check(not GetLFN, 'SetLFN and GetLFN');
  Check(IsProgExt('exe') and IsProgExt('COM') and not IsProgExt('txt'), 'IsProgExt');
  Found := LFindFirst('C:\GDITEST.EXE', faAnyFile, Rec);
  Check((Found = 0) and (CompareText(Rec.Name, 'GDITEST.EXE') = 0) and (Rec.Size > 0),
    'LFindFirst without long names finds a file');
  Check(LFindNext(Rec) <> 0, 'LFindNext ends the search');
  LFindClose(Rec);
  H := LFileOpen('C:\GDITEST.EXE', fmOpenRead);
  Check(H > 0, 'LFileOpen without long names');
  if H > 0 then FileClose(H);
  { As Delphi 1, the DOS error itself: Calmira reports an empty floppy
    drive as a missing folder when FindFirst fails with path not found. }
  SetErrorMode(SEM_FAILCRITICALERRORS);
  Found := FindFirst('A:\*.*', faAnyFile, Rec.ShortData);
  LogLine('FindFirst on an empty drive ' + IntToStr(Found));
  Check(Found = -3, 'FindFirst on a drive without a disk fails with path not found');
end;
procedure hmemcpy(Dest, Source: Pointer; Count: LongInt); far; pascal; external 'KERNEL' index 348;
procedure CheckVolumeInfoKeepsCallerData;
{ LGetVolumeInfo loads DS from the caller's stack for INT 21h/71A0h. It must
  restore it before it touches its error variable: Calmira's startup read and
  wrote at that offset in the caller's segment, and a small one faulted. }
var FileSystem: string; Flags: Word; StackSeg, Top, Limit, I: Word;
  Saved: THandle; Copy, Live: PChar; Same: Boolean;
begin
  FileSystem := ''; Flags := 0;
  asm
    mov Top, sp
    mov ax, ss
    mov StackSeg, ax
    db $0F, $03, $C0  { lsl ax, ax }
    mov Limit, ax
  end;
  Saved := GlobalAlloc(GMEM_FIXED, LongInt(Limit) + 1);
  Copy := GlobalLock(Saved);
  Live := Ptr(StackSeg, 0);
  hmemcpy(Copy, Live, LongInt(Limit) + 1);
  { No drive ?: exists, with or without a long-filename driver. }
  Check(not LGetVolumeInfo('?:\', FileSystem, Flags), 'LGetVolumeInfo fails on a drive that does not exist');
  Same := True;
  for I := 0 to Limit do
    { The calls below the frame and this frame itself may change. }
    if ((I < Top - 2048) or (I > Top + 256)) and (Copy[I] <> Live[I]) then Same := False;
  GlobalUnlock(Saved); GlobalFree(Saved);
  Check(Same, 'LGetVolumeInfo keeps the data segment of its caller');
end;
begin
  LogLine('STEP LFNFUNCS.DLL');
  try
    CheckItems;
    CheckFiles;
    CheckVolumeInfoKeepsCallerData;
  except on E: Exception do begin Failed := True; LogLine('FAIL exception ' + E.Message); end; end;
  if Failed then LogLine('RESULT FAIL') else LogLine('RESULT PASS');
end.
