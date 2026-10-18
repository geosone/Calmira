{**************************************************************************}
{                                                                          }
{    Calmira II shell for Microsoft® Windows(TM) 3.1                       }
{    Online! Release 3.3                                                  }
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

{$R *.RES}
{$D Calmira Task Manager Launcher}

uses WinTypes, WinProcs, SysUtils, IniFiles, CalMsgs;

const
  DlgCpt = 'Gestionnaire de tâches de Calmira';
  DlgMsg = 'Le Gestionnaire de tâches de Calmira n''est pas disponible car ' +
           'Calmira n''a pas terminé normalement.' + #13#10#13#10 +
           'Cliquez sur Abandonner pour fermer Windows (recommandé),' + #13#10 +
           'cliquez sur Réessayer pour redémarrer Calmira ou' + #13#10 +
           'cliquez sur Ignorer pour démarrer le Gestionnaire de tâches de Windows.';

var
  Calmira: HWnd;
  PShell: array[0..127] of char;
  Shell: string;
  Action: Integer;

begin
  Calmira := FindWindow('TApplication', 'Calmira');
  if Calmira > 0 then
    PostMessage(Calmira, WM_CALMIRA, CM_TASKMAN, 0)
  else with TIniFile.Create('system.ini') do
  begin
    Shell := LowerCase(ReadString('boot', 'shell', ''));
    if (Pos('calmira.exe', Shell) > 0) then
    begin
      Action := MessageBox(0, DlgMsg, DlgCpt, MB_ICONHAND or MB_ABORTRETRYIGNORE);
      case Action of
        IDABORT : ExitWindows(0, 0);
        IDRETRY : WinExec(StrPCopy(PShell, Shell), SW_SHOW);
        IDIGNORE: WinExec('taskman.exe', SW_SHOW);
      end;
    end;
  end;
end.

