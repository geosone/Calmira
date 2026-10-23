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

program CTaskMan;

{$IFDEF FPC}{$H-}{$ELSE}{$R *.res}{$ENDIF}
{$D Calmira Task Manager Launcher}

uses WinTypes, WinProcs, SysUtils, CalMsgs,
{$IFDEF FPC} language_catalog, runtime_paths; {$ELSE} IniFiles; {$ENDIF}

const
  DlgCpt = 'Calmira Task Manager';
  DlgMsg = 'The Calmira Task Manager is not available because Calmira ' +
           'has terminated abnormally.' + #13#10#13#10 +
           'Click ABORT to shut down windows (recommended),' + #13#10 +
           'click RETRY to restart Calmira or' + #13#10 +
           'click IGNORE to start the Windows Task Manager.';

var
  Calmira: HWnd;
  PShell: array[0..127] of char;
  Shell: string;
  Action: Integer;
{$IFDEF FPC}
  WindowsDir, TextBuffer, CaptionBuffer: array[0..255] of Char;
  Directory: string;
{$ENDIF}

begin
{$IFDEF FPC}
  Directory := RuntimeDirectory;
  InitializeLanguage(Directory + 'LANG', Directory + 'CALMIRA.INI');
{$ENDIF}
  Calmira := FindWindow('TApplication', 'Calmira');
  if Calmira > 0 then
    PostMessage(Calmira, WM_CALMIRA, CM_TASKMAN, 0)
{$IFDEF FPC}
  else
{$ELSE}
  else with TIniFile.Create('system.ini') do
{$ENDIF}
  begin
{$IFDEF FPC}
    GetWindowsDirectory(WindowsDir, SizeOf(WindowsDir));
    Shell := LowerCase(ReadConfiguration(StrPas(WindowsDir) + '\SYSTEM.INI',
      'boot', 'shell', ''));
{$ELSE}
    Shell := LowerCase(ReadString('boot', 'shell', ''));
{$ENDIF}
    if (Pos('calmira.exe', Shell) > 0) then
    begin
{$IFDEF FPC}
      StrPLCopy(TextBuffer, LanguageText('TaskManager', 'Unavailable',
        'Calmira stopped. Abort: shut down; Retry: restart; Ignore: Windows Task Manager.'), 255);
      StrPLCopy(CaptionBuffer, LanguageText('TaskManager', 'Title', DlgCpt), 255);
      Action := MessageBox(0, TextBuffer, CaptionBuffer, MB_ICONHAND or MB_ABORTRETRYIGNORE);
{$ELSE}
      Action := MessageBox(0, DlgMsg, DlgCpt, MB_ICONHAND or MB_ABORTRETRYIGNORE);
{$ENDIF}
      case Action of
        IDABORT : ExitWindows(0, 0);
        IDRETRY : WinExec(StrPCopy(PShell, Shell), SW_SHOW);
        IDIGNORE: WinExec('taskman.exe', SW_SHOW);
      end;
    end;
  end;
end.

