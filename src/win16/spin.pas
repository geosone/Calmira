{ SPDX-License-Identifier: GPL-2.0-or-later
  Delphi 1 Spin unit facade over the native spin controls. }
unit Spin;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This Spin unit requires Win16}{$ENDIF}
interface
uses native_spin;
type
  TSpinButton = native_spin.TSpinButton;
  TSpinEdit = native_spin.TSpinEdit;
implementation
end.
