{ SPDX-License-Identifier: GPL-2.0-or-later
  COMMDLG.DLL bindings for the Windows 3.1 common dialogs used by Dialogs:
  open/save, color and font. Record layouts follow the Win16 SDK (16-bit
  HWND/UINT, far pointers, packed). }
unit CommDlg;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL COMMDLG.DLL requires Win16}{$ENDIF}
interface
uses WinTypes;
type
  TOpenFilename = packed record
    lStructSize: LongInt;
    hwndOwner: HWND;
    hInstance: THandle;
    lpstrFilter: PChar;
    lpstrCustomFilter: PChar;
    nMaxCustFilter: LongInt;
    nFilterIndex: LongInt;
    lpstrFile: PChar;
    nMaxFile: LongInt;
    lpstrFileTitle: PChar;
    nMaxFileTitle: LongInt;
    lpstrInitialDir: PChar;
    lpstrTitle: PChar;
    Flags: LongInt;
    nFileOffset: Word;
    nFileExtension: Word;
    lpstrDefExt: PChar;
    lCustData: LongInt;
    lpfnHook: Pointer;
    lpTemplateName: PChar;
  end;
  TChooseColor = packed record
    lStructSize: LongInt;
    hwndOwner: HWND;
    hInstance: HWND;
    rgbResult: LongInt;
    lpCustColors: PLongInt;
    Flags: LongInt;
    lCustData: LongInt;
    lpfnHook: Pointer;
    lpTemplateName: PChar;
  end;
  TChooseFont = packed record
    lStructSize: LongInt;
    hwndOwner: HWND;
    hDC: HDC;
    lpLogFont: LPLOGFONT;
    iPointSize: SmallInt;
    Flags: LongInt;
    rgbColors: LongInt;
    lCustData: LongInt;
    lpfnHook: Pointer;
    lpTemplateName: PChar;
    hInstance: THandle;
    lpszStyle: PChar;
    nFontType: Word;
    nSizeMin: SmallInt;
    nSizeMax: SmallInt;
  end;
const
  OFN_READONLY = $00000001;
  OFN_OVERWRITEPROMPT = $00000002;
  OFN_HIDEREADONLY = $00000004;
  OFN_NOCHANGEDIR = $00000008;
  OFN_SHOWHELP = $00000010;
  OFN_NOVALIDATE = $00000100;
  OFN_ALLOWMULTISELECT = $00000200;
  OFN_EXTENSIONDIFFERENT = $00000400;
  OFN_PATHMUSTEXIST = $00000800;
  OFN_FILEMUSTEXIST = $00001000;
  OFN_CREATEPROMPT = $00002000;
  OFN_SHAREAWARE = $00004000;
  OFN_NOREADONLYRETURN = $00008000;
  OFN_NOTESTFILECREATE = $00010000;
  CC_RGBINIT = $00000001;
  CC_FULLOPEN = $00000002;
  CC_PREVENTFULLOPEN = $00000004;
  CC_SHOWHELP = $00000008;
  CF_SCREENFONTS = $00000001;
  CF_PRINTERFONTS = $00000002;
  CF_SHOWHELP = $00000004;
  CF_INITTOLOGFONTSTRUCT = $00000040;
  CF_EFFECTS = $00000100;
  CF_ANSIONLY = $00000400;
  CF_NOVECTORFONTS = $00000800;
  CF_NOOEMFONTS = CF_NOVECTORFONTS;
  CF_NOSIMULATIONS = $00001000;
  CF_LIMITSIZE = $00002000;
  CF_FIXEDPITCHONLY = $00004000;
  CF_WYSIWYG = $00008000;
  CF_FORCEFONTEXIST = $00010000;
  CF_SCALABLEONLY = $00020000;
  CF_TTONLY = $00040000;
  CF_NOFACESEL = $00080000;
  CF_NOSTYLESEL = $00100000;
  CF_NOSIZESEL = $00200000;
  { Open/save dialog controls. }
  edt1 = $0480;
  lst1 = $0460;
function GetOpenFileName(var OpenFile: TOpenFilename): Bool; external 'COMMDLG';
function GetSaveFileName(var OpenFile: TOpenFilename): Bool; external 'COMMDLG';
function ChooseColor(var Color: TChooseColor): Bool; external 'COMMDLG';
function ChooseFont(var Font: TChooseFont): Bool; external 'COMMDLG';
function CommDlgExtendedError: LongInt; external 'COMMDLG';
implementation
end.
