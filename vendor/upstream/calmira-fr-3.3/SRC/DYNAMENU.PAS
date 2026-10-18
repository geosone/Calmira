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

unit DynaMenu;

interface

uses Classes, Menus;

type
  TDynamicMenu = class(TPopupMenu)
  private
    function GetElement(ID: Integer): TMenuItem;
  public
    function AddItem(const Caption: string; Shortcut: TShortcut;
      Checked, Enabled: Boolean; ID: Integer): TMenuItem;
    procedure AddSeperator;
    procedure Attach(const Handlers: array of TNotifyEvent);
    procedure Detach;
    procedure Click(ID: Integer);
    property Element[ID: Integer]: TMenuItem read GetElement;
  end;

implementation

function TDynamicMenu.AddItem(const Caption: string; Shortcut: TShortcut;
  Checked, Enabled: Boolean; ID: Integer): TMenuItem;
var
  m: TMenuItem;
begin
  m := NewItem(Caption, Shortcut, Checked, Enabled, nil, 0, '');
  m.Tag := ID;
  Items.Add(m);
  Result := m;
end;

procedure TDynamicMenu.AddSeperator;
begin
  AddItem('-', 0, False, True, 0);
end;

procedure TDynamicMenu.Attach(const Handlers: array of TNotifyEvent);
var
  i, j: Integer;
begin
  i := 0;
  j := 0;
  while (i < Items.Count) and (j <= High(Handlers)) do
  begin
    if Items.Items[i].Tag <> 0 then
    begin
      Items.Items[i].OnClick := Handlers[j];
      Inc(j);
    end;
    Inc(i);
  end;
end;

procedure TDynamicMenu.Detach;
var
  i: Integer;
begin
  for i := 0 to Items.Count - 1 do Items[i].OnClick := nil;
end;

function TDynamicMenu.GetElement(ID: Integer): TMenuItem;
{ GetElement now searches one level deep }

  function GetSubElement(m: TMenuItem): TMenuItem;
  var
    i: Integer;
  begin
    result := nil;
    for i := 0 to m.Count - 1 do
    begin
      if m.Items[i].Tag = ID then
      begin
        Result := m.Items[i];
        Exit;
      end;
    end;
  end;

var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Items.Count - 1 do
  begin
    if Items[i].Count > 0 then
    begin
      Result := GetSubElement(Items[i]);
      if Result <> nil then Exit;
    end;
    if Items[i].Tag = ID then
    begin
      Result := Items[i];
      Exit;
    end;
  end;
end;

procedure TDynamicMenu.Click(ID: Integer);
var
  m: TMenuItem;
begin
  m := Element[ID];
  if m <> nil then m.Click;
end;

end.

