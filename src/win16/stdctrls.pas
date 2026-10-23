{ SPDX-License-Identifier: GPL-2.0-or-later
  Public aliases to separately usable native Win16 controls. }
unit StdCtrls;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This StdCtrls subset requires Win16}{$ENDIF}
interface
uses native_label, native_button, native_edit, native_checkbox;
type
  TLabel = native_label.TLabel;
  TButton = native_button.TButton;
  TEdit = native_edit.TEdit;
  TEditCharCase = native_edit.TEditCharCase;
  TCheckBox = native_checkbox.TCheckBox;
  TCheckBoxState = native_checkbox.TCheckBoxState;
const
  ecNormal = native_edit.ecNormal;
  ecUpperCase = native_edit.ecUpperCase;
  ecLowerCase = native_edit.ecLowerCase;
  cbUnchecked = native_checkbox.cbUnchecked;
  cbChecked = native_checkbox.cbChecked;
  cbGrayed = native_checkbox.cbGrayed;
implementation
end.
