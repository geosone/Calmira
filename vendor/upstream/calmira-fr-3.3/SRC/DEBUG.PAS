{**************************************************************************}
{                                                                          }
{    Calmira II shell pour Microsoft® Windows(TM) 3.1                      }
{    Version française 3.3                                                 }
{    Copyright (C) 2000-2002 Jean Blanchard                                }
{    Copyright (C) 1998-2002 Calmira Online!                               }
{    Copyright (C) 1997-1998 Li-Hsin Huang                                 }
{                                                                          }
{    Ce programme est libre ; vous pouvez le redistribuer et/ou le         }
{    modifier selon les termes de la Licence Publique Générale GNU telle   }
{   que publiée par la Free Software Foundation ; version 2 de la licence  }
{    ou (au choix) n'importe quelle version plus récente.                  }
{                                                                          }
{    Ce programme est distibué dans l'espoir qu'il sera utile, mais SANS   }
{    AUCUNE GARANTIE ; sans même la garantie implicite de                  }
{    COMMERCIALISATION ou d'APTITUDE A UN USAGE PARTICULIER. Voir la       }
{    licence publique générale pour plus de détails.                                        }
{                                                                          }
{    Vous devriez avoir reçue une copie de la licence publique générale    }
{    avec ce programme; si ce n'est pas le cas, écrivez à la Free          }
{    Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.    }
{                                                                          }
{--------------------------------------------------------------------------}

unit Debug;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Menus, CalForm;

type
  TConsole = class(TForm)
    Listbox: TListBox;
    procedure ListboxKeyPress(Sender: TObject; var Key: Char);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    { Private declarations }
    TimeMark: Longint;
  public
    { Public declarations }
    function StartTimer: Longint;
    function StopTimer: Longint;
    procedure Print(const s: string);
    procedure PrintStrings(s: TStrings);
  end;

var
  Console: TConsole;

implementation

{$R *.DFM}

uses MiscUtil;

procedure TConsole.ListboxKeyPress(Sender: TObject; var Key: Char);
begin
  if UpCase(Key) = 'C' then Listbox.Items.Clear;
  if UpCase(Key) = 'S' then Listbox.Items.SaveToFile(ChangeFileExt(ParamStr(0), '.DBG'));
end;

procedure TConsole.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
 CanClose := False;
end;

function TConsole.StartTimer: Longint;
begin
  TimeMark := GetTimerCount;
  Result := TimeMark;
end;

function TConsole.StopTimer: Longint;
begin
  Result := GetTimerCount;
  Print(IntToStr(Result - TimeMark));
end;

procedure TConsole.Print(const s: string);
begin
  with Listbox do
  begin
    Items.Add(s);
    ItemIndex := Items.Count - 1;
  end;
end;

procedure TConsole.PrintStrings(s: TStrings); { 2.2 }
begin
  with Listbox do begin
    Items.AddStrings(s);
    ItemIndex := Items.Count - 1;
  end;
end;

initialization
  Console := TConsole.Create(Application);
  Console.Show;
end.

