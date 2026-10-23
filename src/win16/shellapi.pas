{ SPDX-License-Identifier: GPL-2.0-or-later
  Windows 3.1 SHELL.DLL imports with the Delphi 1 ShellAPI signatures: the
  registration database, file drag-and-drop, icon extraction and execution. }
unit ShellAPI;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This ShellAPI unit requires Win16}{$ENDIF}
interface
uses WinTypes;
type
  HKEY = LongInt;
  PHKEY = ^HKEY;
  HDROP = THandle;
const
  HKEY_CLASSES_ROOT = 1;
  { Registration database results; not the DOS error numbers. }
  ERROR_SUCCESS = 0;
  ERROR_BADDB = 1;
  ERROR_BADKEY = 2;
  ERROR_CANTOPEN = 3;
  ERROR_CANTREAD = 4;
  ERROR_CANTWRITE = 5;
  ERROR_OUTOFMEMORY = 6;
  ERROR_INVALID_PARAMETER = 7;
  ERROR_ACCESS_DENIED = 8;
  REG_SZ = 1;
  { ShellExecute/FindExecutable results below 32 that are not DOS errors. }
  SE_ERR_SHARE = 26;
  SE_ERR_ASSOCINCOMPLETE = 27;
  SE_ERR_DDETIMEOUT = 28;
  SE_ERR_DDEFAIL = 29;
  SE_ERR_DDEBUSY = 30;
  SE_ERR_NOASSOC = 31;
function RegOpenKey(Key: HKEY; SubKey: PChar; var Result: HKEY): LongInt; external 'SHELL';
function RegCreateKey(Key: HKEY; SubKey: PChar; var Result: HKEY): LongInt; external 'SHELL';
function RegCloseKey(Key: HKEY): LongInt; external 'SHELL';
function RegDeleteKey(Key: HKEY; SubKey: PChar): LongInt; external 'SHELL';
function RegSetValue(Key: HKEY; SubKey: PChar; ValType: LongInt; Data: PChar;
  cb: LongInt): LongInt; external 'SHELL';
function RegQueryValue(Key: HKEY; SubKey: PChar; Value: PChar;
  var cb: LongInt): LongInt; external 'SHELL';
function RegEnumKey(Key: HKEY; Index: LongInt; Buffer: PChar; cb: LongInt): LongInt; external 'SHELL';
function DragQueryFile(Drop: HDROP; FileIndex: Word; FileName: PChar; cb: Word): Word; external 'SHELL';
function DragQueryPoint(Drop: HDROP; var Pt: TPoint): Bool; external 'SHELL';
procedure DragFinish(Drop: HDROP); external 'SHELL';
procedure DragAcceptFiles(Wnd: HWND; Accept: Bool); external 'SHELL';
function ExtractIcon(Inst: THandle; ExeFileName: PChar; IconIndex: Word): HICON; external 'SHELL';
function ShellExecute(Wnd: HWND; Operation, FileName, Parameters, Directory: PChar;
  ShowCmd: Integer): THandle; external 'SHELL';
function FindExecutable(FileName, Directory, Result: PChar): THandle; external 'SHELL';
implementation
end.
