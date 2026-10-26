{
  Win16 adaptation of Free Pascal rtl/win/wininc/messages.inc.
  Copyright (c) 1999-2000 Florian Klaempfl, Free Pascal development team.
  Original Windows32 API definitions copyright (C) 1996 Free Software
  Foundation, Inc.; author Scott Christley <scottc@net-community.com>.

  GNU Library General Public License version 2 or later, with the FPC RTL
  linking exception. See docs/licenses/fpc-rtl-copying.txt and
  docs/licenses/fpc-rtl-exception.txt. No warranty is provided.

  Only the message records needed by the maintained Calmira components are
  ported. Win16 WPARAM is 16-bit; command/scroll/activate LPARAM word ordering
  is NOT the Win32 ordering. This is not a replacement Forms/Controls library.
}
unit Messages;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Messages adapter requires the Win16 target}{$ENDIF}
{$packrecords 2}
interface
uses WinTypes;
type
  PMessage = ^TMessage;
  TMessage = record
    Msg: Word;
    case Integer of
      0: (WParam: Word; LParam, Result: LongInt);
      1: (WParamLo, WParamHi: Byte; LParamLo, LParamHi, ResultLo, ResultHi: Word);
  end;
  TWMNoParams = record
    Msg, UnusedW: Word;
    UnusedL, Result: LongInt;
  end;
  TWMGetDlgCode = TWMNoParams;
  TWMQueryOpen = TWMNoParams;
  TWMSysColorChange = TWMNoParams;
  TWMPaint = record
    Msg: Word;
    DC: HDC;
    Unused, Result: LongInt;
  end;
  TWMKey = record
    Msg, CharCode: Word;
    KeyData, Result: LongInt;
  end;
  TWMKeyDown = TWMKey;
  TWMKeyUp = TWMKey;
  TWMChar = TWMKey;
  TWMSysKeyDown = TWMKey;
  TWMSysChar = TWMKey;
  TWMCommand = record
    Msg, ItemID: Word;
    Ctl: HWND;
    NotifyCode: Word;
    Result: LongInt;
  end;
  TWMScroll = record
    Msg, ScrollCode: Word;
    Pos: SmallInt;
    ScrollBar: HWND;
    Result: LongInt;
  end;
  TWMVScroll = TWMScroll;
  TWMHScroll = TWMScroll;
  TWMActivate = record
    Msg, Active: Word;
    ActiveWindow: HWND;
    Minimized: WordBool;
    Result: LongInt;
  end;
  TWMEnable = record
    Msg: Word;
    Enabled: WordBool;
    Unused, Result: LongInt;
  end;
  TWMMouse = record
    Msg, Keys: Word;
    case Integer of
      0: (XPos, YPos: SmallInt; Result: LongInt);
      1: (Pos: TPoint);
  end;
  TWMLButtonDown = TWMMouse;
  TWMLButtonUp = TWMMouse;
  TWMLButtonDblClk = TWMMouse;
  TWMRButtonDown = TWMMouse;
  TWMRButtonUp = TWMMouse;
  TWMMouseMove = TWMMouse;
  TWMNCHitMessage = record
    Msg: Word;
    HitTest: SmallInt;
    XCursor, YCursor: SmallInt;
    Result: LongInt;
  end;
  TWMNCLButtonDown = TWMNCHitMessage;
  TWMNCRButtonDown = TWMNCHitMessage;
  TWMSysCommand = record
    Msg, CmdType: Word;
    XPos, YPos: SmallInt;
    Result: LongInt;
  end;
  TWMMouseActivate = record
    Msg: Word;
    TopLevel: HWND;
    HitTestCode, MouseMsg: Word;
    Result: LongInt;
  end;
  TWMGetMinMaxInfo = record
    Msg, Unused: Word;
    MinMaxInfo: LPMinMaxInfo;
    Result: LongInt;
  end;
  TWMDrawItem = record
    Msg, Ctl: Word;
    DrawItemStruct: LPDrawItemStruct;
    Result: LongInt;
  end;
  TWMMeasureItem = record
    Msg, IDCtl: Word;
    MeasureItemStruct: LPMeasureItemStruct;
    Result: LongInt;
  end;
  TWMDropFiles = record
    Msg: Word;
    Drop: THandle;
    Unused, Result: LongInt;
  end;
implementation
end.
