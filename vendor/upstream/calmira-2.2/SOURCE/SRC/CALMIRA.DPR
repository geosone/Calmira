{**************************************************************************}
{                                                                          }
{    Calmira shell for Microsoft® Windows(TM) 3.1                          }
{    Source Release 2.2                                                    }
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
  WinProcs,
  WinTypes,
  SysUtils,
  Controls,
  Dialogs,
  MiscUtil,
  Classes,
  Buttons,
  IniFiles,
  Files,
  Strings,
  Profile,
  Graphics,
  About in 'ABOUT.PAS' {About box},
  Fileprop in 'FILEPROP.PAS' {File Properties},
  Diskprop in 'DISKPROP.PAS' {Disk Properties},
  Progress in 'PROGRESS.PAS' {Progress Box},
  Replace in 'REPLACE.PAS' {Replace Box},
  Splash in 'SPLASH.PAS' {Splash Form},
  Openfile in 'OPENFILE.PAS' {Open File},
  Runprog in 'RUNPROG.PAS' {Run},
  Desk in 'DESK.PAS' {Desktop},
  Compsys in 'COMPSYS.PAS' {Computer},
  Shorts in 'SHORTS.PAS' {Shortcuts},
  Filter in 'FILTER.PAS' {Filter},
  Wastebin in 'WASTEBIN.PAS' {Bin},
  Filefind in 'FILEFIND.PAS' {Find form},
  Iconic in 'ICONIC.PAS' {Iconic classes},
  FileMan in 'FILEMAN.PAS' {File management},
  Resource in 'RESOURCE.PAS' {Resources},
  Directry in 'DIRECTRY.PAS' {Directories},
  Settings in 'SETTINGS.PAS' {Settings},
  Iconwin in 'ICONWIN.PAS' {Icon Windows},
  Start in 'START.PAS' {Start Menu},
  Progconv in 'PROGCONV.PAS' {Convert Dialog},
  Referenc in 'REFERENC.PAS' {References},
  Alias in 'ALIAS.PAS' {Aliases},
  Tree in 'TREE.PAS' {Explorer},
  Shutdown in 'SHUTDOWN.PAS' {Shutdown dialog},
  Calform in 'CALFORM.PAS' {Modeless windows},
  Fourdos in 'FOURDOS.PAS' {4DOS descriptions},
  Refedit in 'REFEDIT.PAS' {Reference editor},
  Menuedit in 'MENUEDIT.PAS' {Menu editor},
  Strtprop in 'STRTPROP.PAS' {Start Properties},
  Deskprop in 'DESKPROP.PAS' {Desktop Properties},
  Binprop in 'BINPROP.PAS' {Bin Properties},
  Taskprop in 'TASKPROP.PAS' {Taskbar Properties},
  Sysprop in 'SYSPROP.PAS' {System Properties},
  Fsysprop in 'FSYSPROP.PAS' {File System Props},
  Askdrop in 'ASKDROP.PAS' {Ask Drop},
  Select in 'SELECT.PAS' {Select File Dialog},
  Tips in 'TIPS.PAS' {Tips of the Day},
  Locale in 'LOCALE.PAS',
  Task in 'TASK.PAS' {Taskbar},
  Incsrch in 'INCSRCH.PAS' {Incremental Search},
  Hooks in 'HOOKS.PAS' {Windows hooks},
  CalMsgs in 'CALMSGS.PAS',
  Taskman in 'TASKMAN.PAS' {Task Manager},
  Debug in 'DEBUG.PAS' {Console};

{$R *.RES}

{$D Calmira Source Release 2.2}

procedure LoadAndRun;
var
  s : string;
  i : Integer;
begin
  { Reads and processes the Load= and Run= lines in WIN.INI.
    Each "word" on the line represents a program, which should be
    executed by the shell }

  with TIniFile.Create('win.ini') do
  try
    s := ReadString('Windows', 'Load', '');
    while s > '' do
      DefaultExec(GetWord(s, ' '), '', '', SW_SHOWMINNOACTIVE);

    s := ReadString('Windows', 'Run', '');
    while s > '' do
      DefaultExec(GetWord(s, ' '), '', '', SW_SHOWNORMAL);
  finally
    Free;
  end;

  if ParamCount >= 1 then begin
    s := '';
    for i := 2 to ParamCount do AppendStr(s, ParamStr(i));
    DefaultExec(ParamStr(1), s, '', SW_SHOW);
  end;
end;


begin
  { Only run one instance of Calmira }
  if HPrevInst <> 0 then begin
    PostMessage(HWND_BROADCAST, WM_CALMIRA, CM_PREVINSTANCE, 0);
    Exit;
  end;

  { Disable Windows error messages }
  LastErrorMode := SetErrorMode(SEM_FAILCRITICALERRORS);
  Screen.Cursor := crHourGlass;

  LoadSettings;
  LoadResources;

  { The Splash form is the main form (!!!) }
  Application.CreateForm(TSplashForm, SplashForm);
  with SplashForm do
  if ShowSplash then begin
    Show;
    Update;
  end
  else TotalHide;

  { Reset the cursor because TDesktop takes it over now }
  Screen.Cursor := crDefault;

  { Create main application components -- the ordering is significant! }
  Desktop := TDesktop.Create(Application);
  Desktop.SetCursor(crHourGlass);
  StartMenu := TStartMenu.Create(Application);
  Application.CreateForm(TComputer, Computer);
  Application.CreateForm(TBin, Bin);
  Application.CreateForm(TProgressBox, ProgressBox);
  Application.CreateForm(TTaskbar, Taskbar);
  Taskbar.Update;

  MsgDlgButtonStyle := bsNew;

  Desktop.Load;
  StartMenu.Load;

  SetErrorMode(LastErrorMode);

  SplashForm.TotalHide;

  Desktop.ReleaseCursor;

  ModulesLoaded;

  if IsShell then LoadAndRun;

  if (IsShell or (not ShellStartup)) and
    (GetAsyncKeyState(VK_SHIFT) >= 0) then StartMenu.RunStartup;

  { Show About box the first time Calmira is run }
  if FirstRun then Computer.About.Click;

  Application.HintColor :=
    StringToColor(ini.ReadString('Calmira', 'HintColor', '$00F0FBFF')); { 2.2 }

  if ShowDailyTips and
    (DateToStr(Date) <> ini.ReadString('Calmira', 'DateLastRun', '')) then
    ShowModalDialog(TTipDialog);

  if RestoreSys then Computer.WindowState := wsNormal;

  Application.Run;

  if IsShell then ExitWindows(0, 0);
end.
