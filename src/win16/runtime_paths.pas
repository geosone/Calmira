{ Locate data beside the original EXE, including our UPX extraction wrapper. }
unit runtime_paths;
{$mode delphi}{$H-}
interface
{ Actual loaded NE path, usable for file-based resources; never the wrapper. }
function RuntimeExecutableName: string;
{ Stable installed wrapper path when its valid UPX sidecar is available. }
function RuntimePackageExecutableName: string;
function RuntimeDirectory: string;
implementation
uses WinTypes, WinProcs, SysUtils, runtime_path_text;
{$IFDEF TRACE_RUNTIME_PATHS}
procedure Trace(const Value: string);
var Log: Text;
begin
  AssignFile(Log, 'C:\RTPATH.LOG');
  {$I-} Append(Log); if IOResult <> 0 then Rewrite(Log);
  WriteLn(Log, Value); CloseFile(Log); if IOResult <> 0 then ; {$I+}
end;
{$ENDIF}

function RuntimeExecutableName: string;
var ModuleName: array[0..256] of Char; Count: Integer;
begin
  { The extra byte distinguishes a complete 255-byte name from truncation.
    Never scan an unchecked/uninitialized foreign buffer with StrPas. }
  FillChar(ModuleName, SizeOf(ModuleName), 0);
  Count := GetModuleFileName(HInstance, ModuleName, SizeOf(ModuleName));
  Result := DecodeModulePath(@ModuleName[0], Count, SizeOf(ModuleName));
  if Result = '' then raise EInvalidOp.Create('Cannot resolve runtime executable');
end;
function ReadWrapperSource(const FileName: string): string;
var Buffer: array[0..257] of Char; Source: HFILE; Count: Integer;
begin
  Result := '';
  if FileName = '' then Exit;
  Move(FileName[1], Buffer[0], Length(FileName)); Buffer[Length(FileName)] := #0;
  Source := _lopen(@Buffer[0], OF_READ or OF_SHARE_DENY_NONE);
  if Source = HFILE_ERROR then Exit;
  try Count := _lread(Source, @Buffer[0], SizeOf(Buffer));
  finally _lclose(Source); end;
  Result := DecodeSourcePath(@Buffer[0], Count, SizeOf(Buffer));
end;
function ReadableWrapperFile(const FileName: string): Boolean;
var Name: array[0..255] of Char; Source: HFILE;
begin
  { Use a native Windows file handle, not a DOS attribute query. The installed
    wrapper must be an actually readable file. }
  Result := False; if FileName = '' then Exit;
  Move(FileName[1], Name[0], Length(FileName)); Name[Length(FileName)] := #0;
  Source := _lopen(@Name[0], OF_READ or OF_SHARE_DENY_NONE);
  Result := Source <> HFILE_ERROR;
  if Result then _lclose(Source);
end;
function RuntimePackageExecutableName: string;
var Name, Sidecar, Original: string;
begin
  Name := RuntimeExecutableName;
{$IFDEF TRACE_RUNTIME_PATHS} Trace('Module=' + Name); {$ENDIF}
  Result := Name;
  { The pinned wrapper writes UPX*.SRC next to its temporary UPX*.EXE. }
  if not IsWrapperModuleName(Name) then Exit;
  Sidecar := WrapperSidecarFileName(Name);
  Original := ReadWrapperSource(Sidecar);
{$IFDEF TRACE_RUNTIME_PATHS} Trace('Source=' + Original); {$ENDIF}
  if not IsRootedDriveFileName(Original) then Exit;
  if ReadableWrapperFile(Original) then
    Result := Original;
{$IFDEF TRACE_RUNTIME_PATHS} Trace('Package=' + Result); {$ENDIF}
end;
function RuntimeDirectory: string;
var Name: string;
begin
  Name := RuntimePackageExecutableName;
  Result := ExecutableDirectory(Name);
end;
end.
