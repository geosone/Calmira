{ SPDX-License-Identifier: GPL-2.0-or-later
  Links the generated form loaders (tools/dfm_loader.py) into CALMIRA.EXE.
  Delphi streams each form's DFM resource at run time; under Free Pascal
  each loader unit registers its form's components in its initialization. }
unit calmira_forms;
{$mode delphi}{$H-}

interface

uses
  about_dfm,
  askdrop_dfm,
  binprop_dfm,
  compsys_dfm,
  deskprop_dfm,
  diskprop_dfm,
  filefind_dfm,
  fileprop_dfm,
  filter_dfm,
  fsysprop_dfm,
  gotofld_dfm,
  iconwin_dfm,
  incsrch_dfm,
  logon_dfm,
  menuedit_dfm,
  mydocs_dfm,
  opendlg_dfm,
  openfile_dfm,
  password_dfm,
  progconv_dfm,
  progress_dfm,
  refedit_dfm,
  replace_dfm,
  runprog_dfm,
  select_dfm,
  shorts_dfm,
  shutdown_dfm,
  splash_dfm,
  strtprop_dfm,
  sysprop_dfm,
  sysrefed_dfm,
  task_dfm,
  taskman_dfm,
  taskprop_dfm,
  tips_dfm,
  tree_dfm,
  wastebin_dfm,
  icondlg_dfm;

implementation

end.
