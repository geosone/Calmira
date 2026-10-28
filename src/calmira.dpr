{**************************************************************************}
{                                                                          }
{    Calmira Reborn shell for Microsoft(R) Windows(TM) 3.1                 }
{    Version 5.0                                                           }
{    Copyright (C) 2022-2023 Hunter Turcin                                      }
{    Copyright (C) 2004-2007 Alexandre Rodrigues de Sousa                  }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    This program is free software; you can redistribute it and/or modify  }
{    it under the terms of the GNU General Public License as published by  }
{    the Free Software Foundation; either version 2 of the License, or     }
{    (at your option) any later version.                                   }
{                                                                          }
{    This program is distributed in the hope that it will be useful,       }
{    but WITHOUT ANY WARRANTY; without even the implied warranty of        }
{    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         }
{    GNU General Public License for more details.                          }
{                                                                          }
{    You should have received a copy of the GNU General Public License     }
{    along with this program; if not, write to the Free Software           }
{    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.             }
{                                                                          }
{**************************************************************************}

program Calmira;

uses
  Forms,
  Files,
  LangUI,
  language_catalog in 'portable\language_catalog.pas',
  WinProcs,
  WinTypes,
  SysUtils,
  Controls,
  Dialogs,
  MiscUtil,
  Classes,
  Buttons,
  IniFiles,
  Graphics,
  Strings,    
  About in 'about.pas' {About Dialog},
  FileProp in 'fileprop.pas' {File Properties},
  DiskProp in 'diskprop.pas' {Disk Properties},
  Progress in 'progress.pas' {Progress Dialog},
  Replace in 'replace.pas' {Replace Dialog},
  Splash in 'splash.pas' {Splash Form},
  OpenFile in 'openfile.pas' {OpenFileDlg},
  RunProg in 'runprog.pas' {Run Dialog},
  Desk in 'desk.pas' {Desktop},
  CompSys in 'compsys.pas' {Computer Window},
  Shorts in 'shorts.pas' {Shortcuts},
  Filter in 'filter.pas' {Filter},
  WasteBin in 'wastebin.pas' {Bin Window},
  FileFind in 'filefind.pas' {Find Form},
  Iconic in 'iconic.pas' {Iconic Classes},
  FileMan in 'fileman.pas' {File Management},
  Resource in 'resource.pas' {Resources},
  Directry in 'directry.pas' {Directories},
  Settings in 'settings.pas' {Settings},
  IconWin in 'iconwin.pas' {Icon Window},
  Start in 'start.pas' {Start Menu},
  GrpSync in 'grpsync.pas',
  program_groups in 'portable\program_groups.pas',
  ProgConv in 'progconv.pas' {Convert Dialog},
  Referenc in 'referenc.pas' {References},
  Alias in 'alias.pas' {Aliases},
  Tree in 'tree.pas' {Explorer Tree},
  Shutdown in 'shutdown.pas' {Shutdown dialog},
  CalForm in 'calform.pas' {Modeless windows},
  FourDos in 'fourdos.pas' {4DOS Descriptions},
  RefEdit in 'refedit.pas' {Reference Editor},
  MenuEdit in 'menuedit.pas' {Menu Editor},
  StrtProp in 'strtprop.pas' {Start Properties},
  DeskProp in 'deskprop.pas' {Desktop Properties},
  BinProp in 'binprop.pas' {Bin Properties},
  TaskProp in 'taskprop.pas' {Taskbar Properties},
  SysProp in 'sysprop.pas' {System Properties},
  FSysProp in 'fsysprop.pas' {File System Properties},
  AskDrop in 'askdrop.pas' {Drop Dialog},
  Select in 'select.pas' {Select File Dialog},
  Tips in 'tips.pas' {Tips of the Day},
  Locale in 'locale.pas' {Localized strings},
  Task in 'task.pas' {Taskbar},
  IncSrch in 'incsrch.pas' {Incremental Search},
  Hooks in 'hooks.pas' {Windows Hooks},
  CalMsgs in 'calmsgs.pas' {Calmira Messages},
  DynaMenu in 'dynamenu.pas' {Dynamic Menu's},
  Taskman in 'taskman.pas' {Task Manager},
  Password in 'password.pas' {Password Dialog},
  Logon in 'logon.pas' {Logon Dialog},
  GotoFld in 'gotofld.pas' {Goto Dialog},
  Lfnutils in '..\vcl\lfnutils.pas' {Long file names},
  Opendlg in 'opendlg.pas' {OpenDialogExFrm},
  Mydocs in 'mydocs.pas' {My Document Window},
  Sysrefer in 'sysrefer.pas',
  Sysrefed in 'sysrefed.pas' {System Reference Editor};

{$IFNDEF FPC}{$R *.res}{$ENDIF}
{$D Calmira LFN Beta Release}

procedure LoadAndRun;
var
  s: string;
begin
  { Reads and processes the Load= and Run= lines in WIN.INI.
    Each "word" on the line represents a program, which should be
    executed by the shell }
  with TIniFile.Create('win.ini') do
  try
    s := ReadString('Windows', 'Load', '');
    while s > '' do DefaultExec(GetWord(s, ' '), '', '%windir%\system', SW_SHOWMINNOACTIVE);
    s := ReadString('Windows', 'Run', '');
    while s > '' do DefaultExec(GetWord(s, ' '), '', '%windir%\system', SW_SHOWNORMAL);
  finally
    Free;
  end;
end;

procedure RunCmdLine;
var
  s: string;
  i: Integer;
begin
  { Execute command line parameter }
  if ParamCount >= 1 then
  begin
    s := '';
    for i := 2 to ParamCount do AppendStr(s, ParamStr(i) + ' ');
    DefaultExec(ParamStr(1), s, '', SW_SHOW);
  end;
end;

begin { Calmira }
  if (HPrevInst <> 0) then
  begin
    { Only run one instance of Calmira }
    PostMessage(FindWindow('TApplication', 'Calmira'),
      WM_CALMIRA, CM_PREVINSTANCE, 0);
    Exit;
  end;
  NewStyleControls := false;
  InitializeLanguage(ApplicationPath + 'LANG',
    ApplicationPath + 'CALMIRA.INI');

  { 2.3 -- Show logon dialog if MultiUser enabled }
  CheckForLogon;
  WritePathDetermined;

  { Disable Windows error messages }
  LastErrorMode := SetErrorMode(SEM_FAILCRITICALERRORS);
  Screen.Cursor := crHourGlass;

  LoadSettings;
  AutoSyncProgramGroups;
  SetLfn(EnableLFN);
  LoadResources;

  { The Splash form is the main form (!!!) }
  Application.CreateForm(TSplashForm, SplashForm);
  with SplashForm do
    if ShowSplash then
    begin
      Show;
      Update;
    end;

  { Reset the cursor because TDesktop takes it over now }
  Screen.Cursor := crDefault;

  { Create and initialize main application components
    -- the ordering is significant! }
  Desktop := TDesktop.Create(Application);
  Desktop.SetCursor(crHourGlass);
  StartMenu := TStartMenu.Create(Application);
  Application.CreateForm(TComputer, Computer);
  Application.CreateForm(TBin, Bin);
  Application.CreateForm(TProgressBox, ProgressBox);
  Application.CreateForm(TTaskbar, Taskbar);
  ApplyComponentLanguage(SplashForm);
  ApplyComponentLanguage(Computer);
  ApplyComponentLanguage(Bin);
  ApplyComponentLanguage(ProgressBox);
  ApplyComponentLanguage(Taskbar);

  TIconWindow.CalcColWidths;
  Desktop.Load;
  StartMenu.Load;
  SetErrorMode(LastErrorMode);
  
  SplashForm.TotalHide;
  {ShowMessage(IntToStr(GetWindowsColorDepht)+'bpp');}
  Desktop.ReleaseCursor;

  { Load programs in win.ini's Load= and Run= lines, Startup folder
    and command line }
  if IsShell then LoadAndRun;
  if (IsShell or not ShellStartup) and
    (GetAsyncKeyState(VK_SHIFT) >= 0) then StartMenu.RunStartup;
  RunCmdLine;

  { Show About box the first time Calmira is run }
  if FirstRun then ShowModalDialog(TAboutBox);
  if ShowDailyTips and
    (DateToStr(Date) <> ini.ReadString('Calmira', 'DateLastRun', '')) then
      ShowModalDialog(TTipDialog);
  if RestoreSys then Computer.ShowNormal;

  Application.Run;
  if IsShell then ExitWindows(0, 0);
end.
