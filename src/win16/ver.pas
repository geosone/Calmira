{ SPDX-License-Identifier: GPL-2.0-or-later
  VER.DLL file version information with the Delphi 1 Ver signatures. }
unit Ver;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Ver unit requires Win16}{$ENDIF}
interface
uses WinTypes;
type
  PVS_FIXEDFILEINFO = ^TVS_FIXEDFILEINFO;
  TVS_FIXEDFILEINFO = record
    dwSignature, dwStrucVersion: LongInt;
    dwFileVersionMS, dwFileVersionLS: LongInt;
    dwProductVersionMS, dwProductVersionLS: LongInt;
    dwFileFlagsMask, dwFileFlags: LongInt;
    dwFileOS, dwFileType, dwFileSubtype: LongInt;
    dwFileDateMS, dwFileDateLS: LongInt;
  end;
const
  VS_FFI_SIGNATURE = $FEEF04BD;
  VOS_UNKNOWN = $00000000;
  VOS_DOS = $00010000;
  VOS_OS216 = $00020000;
  VOS_OS232 = $00030000;
  VOS_NT = $00040000;
  VOS__BASE = $00000000;
  VOS__WINDOWS16 = $00000001;
  VOS__PM16 = $00000002;
  VOS__PM32 = $00000003;
  VOS__WINDOWS32 = $00000004;
  VOS_DOS_WINDOWS16 = $00010001;
  VOS_DOS_WINDOWS32 = $00010004;
  VOS_OS216_PM16 = $00020002;
  VOS_OS232_PM32 = $00030003;
  VOS_NT_WINDOWS32 = $00040004;
  VFT_UNKNOWN = 0;
  VFT_APP = 1;
  VFT_DLL = 2;
  VFT_DRV = 3;
  VFT_FONT = 4;
  VFT_VXD = 5;
  VFT_STATIC_LIB = 7;
  VFT2_UNKNOWN = 0;
  VFT2_DRV_PRINTER = 1;
  VFT2_DRV_KEYBOARD = 2;
  VFT2_DRV_LANGUAGE = 3;
  VFT2_DRV_DISPLAY = 4;
  VFT2_DRV_MOUSE = 5;
  VFT2_DRV_NETWORK = 6;
  VFT2_DRV_SYSTEM = 7;
  VFT2_DRV_INSTALLABLE = 8;
  VFT2_DRV_SOUND = 9;
  VFT2_DRV_COMM = 10;
  VFT2_FONT_RASTER = 1;
  VFT2_FONT_VECTOR = 2;
  VFT2_FONT_TRUETYPE = 3;
function GetFileVersionInfoSize(lpszFileName: PChar; var lpdwHandle: LongInt): LongInt; external 'VER';
function GetFileVersionInfo(lpszFileName: PChar; dwHandle, cbBuf: LongInt;
  lpvData: Pointer): Bool; external 'VER';
function VerQueryValue(lpvBlock: Pointer; lpszSubBlock: PChar; var lplpBuffer: Pointer;
  var lpcb: Word): Bool; external 'VER';
implementation
end.
