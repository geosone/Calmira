{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 Tabs unit types. Calmira's TTabPanel uses TTabChangeEvent; the
  TTabSet control itself is not provided, so code that needs it fails to
  compile rather than getting a stand-in. }
unit Tabs;
{$mode delphi}{$H-}
interface
uses WinTypes, Graphics;
type
  TScrollBtn = (sbLeft, sbRight);
  TEdgePart = (epSelectedLeft, epUnselectedLeft, epSelectedRight, epUnselectedRight);
  TEdgeType = (etNone, etFirstIsSel, etFirstNotSel, etLastIsSel, etLastNotSel,
    etNotSelToSel, etSelToNotSel, etNotSelToNotSel);
  TTabStyle = (tsStandard, tsOwnerDraw);
  TMeasureTabEvent = procedure(Sender: TObject; Index: Integer;
    var TabWidth: Integer) of object;
  TDrawTabEvent = procedure(Sender: TObject; TabCanvas: TCanvas; R: TRect;
    Index: Integer; Selected: Boolean) of object;
  TTabChangeEvent = procedure(Sender: TObject; NewTab: Integer;
    var AllowChange: Boolean) of object;
implementation
end.
