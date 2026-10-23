{ SPDX-License-Identifier: GPL-2.0-or-later
  Public aliases to separately usable native Win16 controls. }
unit StdCtrls;
{$mode delphi}{$H-}
{$IFNDEF WIN16}{$FATAL This StdCtrls subset requires Win16}{$ENDIF}
interface
uses native_label, native_button, native_edit, native_checkbox, native_radio,
  native_combobox, native_listbox;
type
  TLabel = native_label.TLabel;
  TButton = native_button.TButton;
  TEdit = native_edit.TEdit;
  TEditCharCase = native_edit.TEditCharCase;
  TCheckBox = native_checkbox.TCheckBox;
  TCheckBoxState = native_checkbox.TCheckBoxState;
  TRadioButton = native_radio.TRadioButton;
  TComboBoxStyle = native_combobox.TComboBoxStyle;
  TCustomComboBox = native_combobox.TCustomComboBox;
  TComboBox = native_combobox.TComboBox;
  TListBoxStyle = native_listbox.TListBoxStyle;
  TOwnerDrawState = native_listbox.TOwnerDrawState;
  TDrawItemEvent = native_listbox.TDrawItemEvent;
  TMeasureItemEvent = native_listbox.TMeasureItemEvent;
  TCustomListBox = native_listbox.TCustomListBox;
  TListBox = native_listbox.TListBox;
  TScrollStyle = (ssNone, ssHorizontal, ssVertical, ssBoth);
const
  ecNormal = native_edit.ecNormal;
  ecUpperCase = native_edit.ecUpperCase;
  ecLowerCase = native_edit.ecLowerCase;
  cbUnchecked = native_checkbox.cbUnchecked;
  cbChecked = native_checkbox.cbChecked;
  cbGrayed = native_checkbox.cbGrayed;
  csDropDown = native_combobox.csDropDown;
  csSimple = native_combobox.csSimple;
  csDropDownList = native_combobox.csDropDownList;
  csOwnerDrawFixed = native_combobox.csOwnerDrawFixed;
  csOwnerDrawVariable = native_combobox.csOwnerDrawVariable;
  lbStandard = native_listbox.lbStandard;
  lbOwnerDrawFixed = native_listbox.lbOwnerDrawFixed;
  lbOwnerDrawVariable = native_listbox.lbOwnerDrawVariable;
  odSelected = native_listbox.odSelected; odGrayed = native_listbox.odGrayed;
  odDisabled = native_listbox.odDisabled; odChecked = native_listbox.odChecked;
  odFocused = native_listbox.odFocused;
implementation
end.
